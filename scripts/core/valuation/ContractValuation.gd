## Contract valuation helper built around scouting composite scores.
##
## Evaluation source:
## - ScoutRuntime.score_player(...) in scripts/core/scouting/ScoutRuntime.gd.
## - Inputs: scout Dictionary, player Dictionary, positions_data Dictionary,
##   stats_cfg Dictionary, class_rules Dictionary, rng RandomNumberGenerator.
## - Output: composite-like 0..100 score (eval_score) used here as input_eval_score.
##
## Determinism: if jitter is enabled, callers MUST pass an RNG seeded from
## stable lineage (e.g., hash(player_id + season_year)). The chosen seed should
## be persisted in valuation_seed for traceability.
extends RefCounted
class_name ContractValuation

const DEFAULT_VERSION := "v1"

static func build_payload(
	eval_score: float,
	player: Dictionary,
	stats_cfg: Dictionary,
	valuation_cfg: Dictionary,
	rng: RandomNumberGenerator,
	valuation_seed: int
) -> Dictionary:
	var version := String(valuation_cfg.get("version", DEFAULT_VERSION))
	var pos_mult := _position_multiplier(String(player.get("position", "ATH")), valuation_cfg)
	var age_mult := _age_multiplier(int(player.get("age", 0)), valuation_cfg)
	var blend_mult := _current_potential_multiplier(player, stats_cfg, valuation_cfg)
	var base_value := _score_to_value(eval_score, valuation_cfg)

	var est_value := base_value * pos_mult * age_mult * blend_mult
	var jitter_sigma := float(valuation_cfg.get("jitter_sigma_pct", 0.0))
	if jitter_sigma > 0.0:
		if rng == null:
			push_error("ContractValuation: RNG required when jitter_sigma_pct > 0.")
		else:
			est_value *= clamp(1.0 + rng.randfn(0.0, jitter_sigma), 0.5, 1.5)

	var spread := float(valuation_cfg.get("range_spread_pct", 0.15))
	var range_min := est_value * (1.0 - spread)
	var range_max := est_value * (1.0 + spread)

	return {
		"range_min": range_min,
		"range_max": range_max,
		"est_value": est_value,
		"input_eval_score": eval_score,
		"valuation_seed": valuation_seed,
		"valuation_version": version
	}

## Storage target: player["contract"]["valuation"].
## Payload format: range_min, range_max, est_value, input_eval_score,
## valuation_seed, valuation_version.
static func write_to_player_contract(player: Dictionary, payload: Dictionary) -> void:
	var contract: Dictionary = player.get("contract", {}) as Dictionary
	contract["valuation"] = payload.duplicate(true)
	player["contract"] = contract

static func _position_multiplier(position: String, valuation_cfg: Dictionary) -> float:
	var premiums: Dictionary = valuation_cfg.get("position_premiums", {}) as Dictionary
	return float(premiums.get(position, premiums.get("DEFAULT", 1.0)))

static func _age_multiplier(age: int, valuation_cfg: Dictionary) -> float:
	var table: Array = valuation_cfg.get("age_multipliers", []) as Array
	for row in table:
		var entry: Dictionary = row
		var min_age := int(entry.get("min", -1))
		var max_age := int(entry.get("max", -1))
		if age >= min_age and age <= max_age:
			return float(entry.get("mult", 1.0))
	return 1.0

static func _current_potential_multiplier(
	player: Dictionary,
	stats_cfg: Dictionary,
	valuation_cfg: Dictionary
) -> float:
	var weights: Dictionary = valuation_cfg.get("current_vs_potential", {}) as Dictionary
	var current_weight := float(weights.get("current_weight", 0.7))
	var potential_weight := float(weights.get("potential_weight", 0.3))
	var current_avg := _avg_stats(player.get("stats", {}) as Dictionary, stats_cfg)
	var potential_stats: Dictionary = player.get("potential", {}) as Dictionary
	if potential_stats.is_empty():
		potential_stats = player.get("stats", {}) as Dictionary
	var potential_avg := _avg_stats(potential_stats, stats_cfg)
	var blended := current_avg * current_weight + potential_avg * potential_weight
	return clamp(blended / 100.0, 0.5, 1.5)

static func _score_to_value(eval_score: float, valuation_cfg: Dictionary) -> float:
	var curve: Dictionary = valuation_cfg.get("score_to_value", {}) as Dictionary
	var base := float(curve.get("base", 0.0))
	var per_point := float(curve.get("per_point", 1.0))
	return base + eval_score * per_point

static func _avg_stats(stats: Dictionary, stats_cfg: Dictionary) -> float:
	var list: Array = stats_cfg.get("stats", []) as Array
	if list.is_empty():
		if stats.is_empty():
			return 50.0
		var sum := 0.0
		for v in stats.values():
			sum += float(v)
		return sum / float(stats.size())

	var total := 0.0
	for row in list:
		var entry: Dictionary = row
		var key := String(entry.get("name", ""))
		if key == "":
			continue
		total += float(stats.get(key, 50.0))
	return total / float(max(1, list.size()))
