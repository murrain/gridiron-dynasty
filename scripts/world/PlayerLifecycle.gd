extends RefCounted
class_name PlayerLifecycle

const INJURY_SUPPRESSION_PER_SEVERITY := 0.25

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

	var development_report := _apply_development(p, positions_cfg, main_cfg, stats_cfg, rng)
	var injury_report := _apply_injury(p, main_cfg, rng)
	p["development_report"] = development_report
	p["injury_report"] = injury_report

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
		return {"skipped": true}

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
	var injuries := _normalized_injuries(player)
	var decline_mults := _injury_decline_multipliers(injuries)
	var report_entry := {
		"age": age,
		"stat_deltas": {},
		"injury_impacts": {"active": [], "recovered": []}
	}

	var phase := "growth"
	if age < peak_age:
		phase = "growth"
	elif age < decline_start:
		phase = "prime"
	else:
		phase = "decline"

	var report := {
		"age": age,
		"phase": phase,
		"modifiers": {
			"growth_mult": growth_mult,
			"prime_mult": prime_mult,
			"decline_mult": decline_mult,
			"base_min": base_min,
			"base_max": base_max,
			"prime_min": prime_min,
			"prime_max": prime_max,
			"decline_min": decline_min,
			"decline_max": decline_max,
			"cap": cap
		},
		"stat_entries": []
	}

	for key in stats.keys():
		var stat_name := String(key)
		var val := float(stats.get(stat_name, 0.0))
		var pot := float(potential.get(stat_name, val))
		if stat_defs.has(stat_name) and stat_defs[stat_name].get("type", "base") != "base":
			continue

		var delta := 0.0
		var raw_draw := 0.0
		var applied_mult := 0.0
		if phase == "growth":
			raw_draw = rng.randf_range(base_min, base_max)
			applied_mult = growth_mult
			delta = raw_draw * applied_mult
		elif phase == "prime":
			raw_draw = rng.randf_range(prime_min, prime_max)
			applied_mult = prime_mult
			delta = raw_draw * applied_mult
		else:
			delta = -rng.randf_range(decline_min, decline_max) * decline_mult
			var injury_decline_mult := float(decline_mults.get(stat_name, 1.0))
			if injury_decline_mult != 1.0:
				delta *= injury_decline_mult
			raw_draw = rng.randf_range(decline_min, decline_max)
			applied_mult = decline_mult
			delta = -raw_draw * applied_mult

		var unclamped := delta
		delta = clamp(delta, -cap, cap)
		var was_clamped := not is_equal_approx(unclamped, delta)
		var next_val: float = float(clamp(val + delta, 0.0, 100.0))
		var capped_by_potential := false
		if delta > 0.0:
			var limited := min(next_val, pot)
			capped_by_potential = not is_equal_approx(limited, next_val)
			next_val = limited
		stats[stat_name] = next_val
		(report_entry["stat_deltas"] as Dictionary)[stat_name] = delta

	_apply_active_injury_suppression(stats, injuries, report_entry)
	_apply_recovery_updates(injuries, report_entry)
	_apply_long_term_penalties(stats, potential, injuries, report_entry)

		report["stat_entries"].append({
			"stat": stat_name,
			"before": val,
			"potential": pot,
			"raw_draw": raw_draw,
			"multiplier": applied_mult,
			"delta_unclamped": unclamped,
			"delta": delta,
			"clamped": was_clamped,
			"capped_by_potential": capped_by_potential,
			"after": next_val
		})

	player["stats"] = stats
	player["potential"] = potential
	player["injuries"] = injuries
	_append_development_report(player, report_entry)
	return report

static func _apply_injury(
	player: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary
	var base_chance := float(cfg.get("base_chance", 0.0))
	var proneness_slope := float(cfg.get("proneness_slope", 0.0))
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var proneness := float(stats.get("injury_proneness", 50.0))
	var chance := base_chance + ((proneness - 50.0) / 100.0) * proneness_slope
	chance = clamp(chance, 0.0, 0.95)

	var roll := rng.randf()
	var injured := roll < chance
	return {
		"base_chance": base_chance,
		"proneness": proneness,
		"proneness_slope": proneness_slope,
		"chance": chance,
		"roll": roll,
		"injured": injured
	}

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

static func _normalized_injuries(player: Dictionary) -> Array:
	var injuries: Array = player.get("injuries", []) as Array
	var normalized: Array = []
	normalized.resize(injuries.size())
	for i in range(injuries.size()):
		normalized[i] = _normalize_injury(injuries[i] as Dictionary)
	return normalized

static func _normalize_injury(injury: Dictionary) -> Dictionary:
	var normalized := injury.duplicate(true)
	normalized["type"] = String(injury.get("type", ""))
	normalized["severity"] = float(injury.get("severity", 0.0))
	normalized["affected_stats"] = (injury.get("affected_stats", []) as Array).duplicate()
	var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
	var years_total := int(timeline.get("years_total", 0))
	var years_remaining := int(timeline.get("years_remaining", years_total))
	var status := String(timeline.get("status", "active"))
	if years_remaining <= 0:
		years_remaining = 0
		status = "recovered"
	normalized["recovery_timeline"] = {
		"years_total": years_total,
		"years_remaining": years_remaining,
		"status": status
	}
	var long_term: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
	var stat_caps: Dictionary = (long_term.get("stat_caps", {}) as Dictionary).duplicate(true)
	var decline_multipliers: Dictionary = (long_term.get("decline_multipliers", {}) as Dictionary).duplicate(true)
	normalized["long_term_penalty"] = {
		"stat_caps": stat_caps,
		"decline_multipliers": decline_multipliers
	}
	return normalized

static func _injury_decline_multipliers(injuries: Array) -> Dictionary:
	var combined := {}
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "recovered":
			continue
		var long_term: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
		var multipliers: Dictionary = long_term.get("decline_multipliers", {}) as Dictionary
		for stat_name in multipliers.keys():
			var existing := float(combined.get(stat_name, 1.0))
			combined[stat_name] = existing * float(multipliers.get(stat_name, 1.0))
	return combined

static func _apply_active_injury_suppression(
	stats: Dictionary,
	injuries: Array,
	report_entry: Dictionary
) -> void:
	var active_reports: Array = report_entry["injury_impacts"]["active"] as Array
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "active":
			continue
		var years_remaining := int(timeline.get("years_remaining", 0))
		if years_remaining <= 0:
			continue
		var severity := float(injury.get("severity", 0.0))
		var suppression_mult := clamp(1.0 - (severity * INJURY_SUPPRESSION_PER_SEVERITY), 0.4, 1.0)
		var suppressed := {}
		for stat in (injury.get("affected_stats", []) as Array):
			var stat_name := String(stat)
			if not stats.has(stat_name):
				continue
			var before := float(stats.get(stat_name, 0.0))
			var after := float(clamp(before * suppression_mult, 0.0, 100.0))
			if after == before:
				continue
			stats[stat_name] = after
			suppressed[stat_name] = {"before": before, "after": after}
		if not suppressed.is_empty():
			active_reports.append({
				"type": injury.get("type", ""),
				"severity": severity,
				"affected_stats": (injury.get("affected_stats", []) as Array).duplicate(),
				"suppressed_stats": suppressed,
				"recovery_timeline": timeline.duplicate(true)
			})

static func _apply_recovery_updates(injuries: Array, report_entry: Dictionary) -> void:
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "active":
			continue
		var years_remaining := int(timeline.get("years_remaining", 0))
		if years_remaining <= 0:
			continue
		years_remaining = max(0, years_remaining - 1)
		timeline["years_remaining"] = years_remaining
		if years_remaining == 0:
			timeline["status"] = "recovered"
		injury["recovery_timeline"] = timeline

static func _apply_long_term_penalties(
	stats: Dictionary,
	potential: Dictionary,
	injuries: Array,
	report_entry: Dictionary
) -> void:
	var recovered_reports: Array = report_entry["injury_impacts"]["recovered"] as Array
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "recovered":
			continue
		var long_term: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
		var stat_caps: Dictionary = long_term.get("stat_caps", {}) as Dictionary
		var decline_multipliers: Dictionary = long_term.get("decline_multipliers", {}) as Dictionary
		var applied_caps := {}
		for stat_name in stat_caps.keys():
			var cap := float(stat_caps.get(stat_name, 100.0))
			if stats.has(stat_name):
				var before := float(stats.get(stat_name, 0.0))
				var after := min(before, cap)
				if after != before:
					stats[stat_name] = after
					applied_caps[stat_name] = {"before": before, "after": after, "cap": cap}
			if potential.has(stat_name):
				var pot_before := float(potential.get(stat_name, 0.0))
				var pot_after := min(pot_before, cap)
				if pot_after != pot_before:
					potential[stat_name] = pot_after
		if not applied_caps.is_empty() or not decline_multipliers.is_empty():
			recovered_reports.append({
				"type": injury.get("type", ""),
				"severity": float(injury.get("severity", 0.0)),
				"stat_caps_applied": applied_caps,
				"decline_multipliers": decline_multipliers.duplicate(true),
				"recovery_timeline": timeline.duplicate(true)
			})

static func _append_development_report(player: Dictionary, report_entry: Dictionary) -> void:
	var report: Array = player.get("development_report", []) as Array
	report.append(report_entry)
	player["development_report"] = report
