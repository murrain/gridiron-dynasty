extends RefCounted
class_name PlayerLifecycle

static func advance_years(
	players: Array,
	years: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var active: Array = players.duplicate()
	var retired_all: Array = []
	var rng_use := rng

	for _year in range(max(0, years)):
		var result := advance_one_year(active, positions_cfg, main_cfg, stats_cfg, rng_use)
		retired_all.append_array(result.get("retired", []))
		active = (result.get("players", []) as Array).filter(func(p): return p != null)

	return {"players": active, "retired": retired_all}

static func advance_one_year(
	players: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var rng_use := rng

	var updated: Array = []
	var retired: Array = []
	updated.resize(players.size())

	for i in players.size():
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			continue
		var evolved := _advance_player_one_year(p, positions_cfg, main_cfg, stats_cfg, rng_use)
		if evolved.get("retired", false):
			retired.append(evolved.get("player", p))
			updated[i] = null
		else:
			updated[i] = evolved.get("player", p)

	return {"players": updated, "retired": retired}

static func _advance_player_one_year(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var p := player.duplicate(true)
	p["age"] = int(p.get("age", 18)) + 1

	var wear_snapshot := _update_wear(p, positions_cfg, main_cfg)
	var dev_report := _apply_development(p, positions_cfg, main_cfg, stats_cfg, rng)
	_append_development_report(p, wear_snapshot, dev_report)

	if _should_retire(p, positions_cfg, main_cfg, rng):
		return {"player": p, "retired": true}

	return {"player": p, "retired": false}

static func _apply_development(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if not player.has("stats"):
		return {"decline_multiplier": 1.0}

	var age := int(player.get("age", 18))
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary
	var peak_age := int(dev_cfg.get("peak_age", 26))
	var decline_start := int(dev_cfg.get("decline_start", 30))
	var curve := String(dev_cfg.get("curve", "mid"))

	var dev_global: Dictionary = main_cfg.get("development", {}) as Dictionary
	var curve_mults: Dictionary = dev_global.get("curve_multipliers", {}) as Dictionary
	var curve_cfg: Dictionary = curve_mults.get(curve, {}) as Dictionary
	var growth_mult := float(curve_cfg.get("growth", 1.0))
	var prime_mult := float(curve_cfg.get("prime", 0.35))
	var decline_mult := float(curve_cfg.get("decline", 1.0))

	var base_min := float(main_cfg.get("annual_base_progress_min", 1.0))
	var base_max := float(main_cfg.get("annual_base_progress_max", 4.0))
	var cap := float(main_cfg.get("annual_progress_cap", 6.0))
	var prime_min := float(dev_global.get("prime_growth_min", 0.2))
	var prime_max := float(dev_global.get("prime_growth_max", 0.8))
	var decline_min := float(dev_global.get("decline_min", 0.4))
	var decline_max := float(dev_global.get("decline_max", 1.6))

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var potential: Dictionary = player.get("potential", stats) as Dictionary
	var stat_defs: Dictionary = _stat_defs(stats_cfg)
	var wear_multiplier := 1.0
	if age >= decline_start:
		wear_multiplier = _wear_decline_multiplier(player, main_cfg)

	for key in stats.keys():
		var stat_name := String(key)
		var val := float(stats.get(stat_name, 0.0))
		var pot := float(potential.get(stat_name, val))
		if stat_defs.has(stat_name) and stat_defs[stat_name].get("type", "base") != "base":
			continue

		var delta := 0.0
		if age < peak_age:
			delta = rng.randf_range(base_min, base_max) * growth_mult
		elif age < decline_start:
			delta = rng.randf_range(prime_min, prime_max) * prime_mult
		else:
			delta = -rng.randf_range(decline_min, decline_max) * decline_mult * wear_multiplier

		delta = clamp(delta, -cap, cap)
		var next_val: float = float(clamp(val + delta, 0.0, 100.0))
		if delta > 0.0:
			next_val = min(next_val, pot)
		stats[stat_name] = next_val

	player["stats"] = stats
	return {"decline_multiplier": wear_multiplier}

static func _update_wear(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var wear_cfg: Dictionary = main_cfg.get("wear", {}) as Dictionary
	var base_snaps := int(wear_cfg.get("snaps_per_year", 0))
	var base_collisions := int(wear_cfg.get("collisions_per_year", 0))
	var position_mults: Dictionary = wear_cfg.get("position_multipliers", {}) as Dictionary
	var position := String(player.get("position", ""))
	var position_mult := float(position_mults.get(position, 1.0))

	var snaps_add := int(round(base_snaps * position_mult))
	var collisions_add := int(round(base_collisions * position_mult))
	var injuries_last_year := int(player.get("injuries_last_year", 0))

	var wear := _ensure_wear(player)
	wear["snaps"] = int(wear.get("snaps", 0)) + max(0, snaps_add)
	wear["collisions"] = int(wear.get("collisions", 0)) + max(0, collisions_add)
	wear["injury_count"] = int(wear.get("injury_count", 0)) + max(0, injuries_last_year)

	player["wear"] = wear
	return wear

static func _ensure_wear(player: Dictionary) -> Dictionary:
	var wear: Dictionary = player.get("wear", {}) as Dictionary
	return {
		"snaps": int(wear.get("snaps", 0)),
		"collisions": int(wear.get("collisions", 0)),
		"injury_count": int(wear.get("injury_count", 0))
	}

static func _wear_decline_multiplier(player: Dictionary, main_cfg: Dictionary) -> float:
	var wear_cfg: Dictionary = main_cfg.get("wear", {}) as Dictionary
	var wear := _ensure_wear(player)

	var snaps_scale := float(wear_cfg.get("decline_snaps_scale", 8000.0))
	var collisions_scale := float(wear_cfg.get("decline_collisions_scale", 2600.0))
	var injuries_scale := float(wear_cfg.get("decline_injuries_scale", 6.0))
	var per_unit := float(wear_cfg.get("decline_per_wear", 0.2))
	var min_mult := float(wear_cfg.get("decline_min_multiplier", 1.0))
	var max_mult := float(wear_cfg.get("decline_max_multiplier", 1.6))

	var snaps := float(wear.get("snaps", 0))
	var collisions := float(wear.get("collisions", 0))
	var injuries := float(wear.get("injury_count", 0))

	var wear_score := 0.0
	wear_score += snaps / max(1.0, snaps_scale)
	wear_score += collisions / max(1.0, collisions_scale)
	wear_score += injuries / max(1.0, injuries_scale)

	var multiplier := 1.0 + (wear_score * per_unit)
	return clamp(multiplier, min_mult, max_mult)

static func _append_development_report(
	player: Dictionary,
	wear_snapshot: Dictionary,
	dev_report: Dictionary
) -> void:
	var report: Array = player.get("development_report", []) as Array
	report.append({
		"age": int(player.get("age", 0)),
		"wear": wear_snapshot.duplicate(true),
		"decline_multiplier": float(dev_report.get("decline_multiplier", 1.0))
	})
	player["development_report"] = report

static func _should_retire(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	var cfg: Dictionary = main_cfg.get("retirement", {}) as Dictionary
	var age := int(player.get("age", 18))
	var min_age := int(cfg.get("min_age", 27))
	var soft_cap_age := int(cfg.get("soft_cap_age", 33))
	var max_age := int(cfg.get("max_age", 40))
	if age < min_age:
		return false
	if age >= max_age:
		return true

	var chance := float(cfg.get("base_chance", 0.02))
	var age_slope := float(cfg.get("age_chance_per_year", 0.04))
	chance += max(0, age - soft_cap_age) * age_slope

	var low_rating_threshold := float(cfg.get("low_rating_threshold", 55.0))
	var low_rating_boost := float(cfg.get("low_rating_boost", 0.08))
	if _core_rating(player, positions_cfg) < low_rating_threshold:
		chance += low_rating_boost

	chance = clamp(chance, 0.0, 0.95)
	return rng.randf() < chance

static func _core_rating(player: Dictionary, positions_cfg: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = (pos_cfg.get("core_stats", []) as Array)
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	if core_stats.is_empty():
		return _mean_of_stats(stats)
	var total := 0.0
	var count := 0
	for stat in core_stats:
		if stats.has(stat):
			total += float(stats.get(stat, 0.0))
			count += 1
	if count == 0:
		return _mean_of_stats(stats)
	return total / float(count)

static func _mean_of_stats(stats: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for v in stats.values():
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			total += float(v)
			count += 1
	return (total / float(count)) if count > 0 else 0.0

static func _stat_defs(stats_cfg: Dictionary) -> Dictionary:
	var out := {}
	for row in stats_cfg.get("stats", []):
		var d: Dictionary = row
		var name := String(d.get("name", ""))
		if name != "":
			out[name] = d
	return out
