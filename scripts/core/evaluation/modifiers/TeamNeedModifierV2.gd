## TeamNeedModifierV2 - Additive team need evaluation modifier
##
## Replaces PositionNeedModifier with additive OVR bonuses instead of multiplicative.
## Implements a 5-level need system based on roster composition and starter quality.
##
## Need Levels (from config - Phase 1 conservative values):
##   - critical: No starter at position (0 players), +4.0 OVR base
##   - high: Starter below threshold OR only 1 player, +2.5 OVR base
##   - moderate: Starter 65-72 OVR OR below ideal depth, +1.5 OVR base
##   - low: Starter adequate but weak backup depth, +0.5 OVR base
##   - none: Position is well-stocked, +0.0 OVR
##
## Round scaling prevents early-round reaches:
##   - Round 1: 60% of bonus (critical need)
##   - Round 2: 75% of bonus
##   - Round 3-4: 90% of bonus
##   - Round 5+: 100% of bonus
##
## Position importance multipliers adjust need value:
##   - QB: 1.5x (most important need)
##   - EDGE: 1.2x
##   - CB: 1.1x
##   - OL/WR: 1.0x (baseline)
##   - RB: 0.7x (replaceable position)
##   - K/P: 0.3x (specialists rarely drafted for need)
##
## Reach prevention floors prevent bad picks:
##   - Round 1: Player must be 70+ OVR to receive bonus
##   - Round 2: 65+ OVR minimum
##   - Round 3-4: 60+ OVR minimum
##   - Round 5+: 50+ OVR minimum
##
## RNG Usage: None (deterministic calculation based on roster state)
##
## Maximum bonus: ~6 OVR (4.0 base * 1.5 position importance = 6.0 OVR for critical QB need)
## With round scaling: ~3.6 OVR in Round 1 (4.0 * 0.6 * 1.5)
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Path to draft evaluation config file
const DRAFT_EVALUATION_CONFIG_PATH := "res://configs/sports/american_football/draft_evaluation.json"

## Cached config for performance (loaded once)
static var _config_cache: Dictionary = {}
static var _config_loaded: bool = false

## Need level enum for clarity
enum NeedLevel {
	CRITICAL,
	HIGH,
	MODERATE,
	LOW,
	NONE
}


func get_id() -> String:
	return "team_need_v2"


func get_display_name() -> String:
	return "Team Need (V2)"


func get_description() -> String:
	return "Additive OVR bonus based on team roster needs at position"


func get_priority() -> int:
	# Run after position tier/value but before scheme fit
	return 25


## Bounds for additive bonus: 0 to +12 OVR points (critical QB need)
func get_bounds() -> Dictionary:
	return {"min": 0.0, "max": 12.0}


func get_tags() -> Array:
	return ["roster", "evaluation", "team_specific", "additive", "draft"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Only applies during draft phase
	if ctx.phase != "draft":
		return false
	# Need valid position
	if ctx.position.is_empty():
		return false
	# Need draft round
	if ctx.draft_round <= 0:
		return false
	return true


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var config := _get_config()
	var team_need_cfg: Dictionary = config.get("team_need", {})

	var position := ctx.position
	var roster := ctx.roster
	var round_num := ctx.draft_round
	var player_rating := ctx.base_rating

	# Step 1: Check reach prevention floor
	var min_ovr := _get_reach_prevention_floor(round_num, team_need_cfg)
	if player_rating < min_ovr:
		return ModifierResult.create_additive(0.0,
			"Below round %d minimum OVR (%.0f < %.0f)" % [round_num, player_rating, min_ovr],
			{
				"round": round_num,
				"player_rating": player_rating,
				"min_required": min_ovr,
				"need_level": "blocked",
				"blocked_by_reach_prevention": true
			})

	# Step 2: Assess need level for this position
	var need_level := _assess_need_level(position, roster, ctx.positions_cfg, ctx.class_rules)

	# Step 3: Get base bonus for need level
	var base_bonus := _get_need_bonus(need_level, team_need_cfg)

	# Step 4: Apply round scaling (prevents early-round reaches)
	var round_scale := _get_round_scaling(round_num, need_level, team_need_cfg)

	# Step 5: Apply position importance multiplier
	var position_mult := _get_position_importance(position, team_need_cfg)

	# Calculate final bonus
	var final_bonus := base_bonus * round_scale * position_mult

	# Build explanation
	var level_name := _need_level_to_string(need_level)
	var reason := ""
	if need_level == NeedLevel.NONE:
		reason = "No need at %s - position well-stocked" % position
	else:
		reason = "%s need for %s (+%.1f OVR)" % [level_name.capitalize(), position, final_bonus]

	return ModifierResult.create_additive(final_bonus, reason, {
		"position": position,
		"need_level": level_name,
		"base_bonus": base_bonus,
		"round": round_num,
		"round_scale": round_scale,
		"position_importance": position_mult,
		"final_bonus": final_bonus,
		"player_rating": player_rating
	})


## Assess the need level for a position based on roster composition
##
## Criteria:
##   - CRITICAL: 0 players at position
##   - HIGH: 1 player OR starter below threshold (65 OVR)
##   - MODERATE: Starter 65-72 OVR OR below ideal depth
##   - LOW: Starter adequate but weak backup depth
##   - NONE: Position is well-stocked with quality depth
func _assess_need_level(
	position: String,
	roster: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> NeedLevel:
	var by_position: Dictionary = roster.get("by_position", {})
	var players: Array = roster.get("players", [])
	var position_ids: Array = by_position.get(position, [])
	var player_count := position_ids.size()

	var config := _get_config()
	var need_cfg: Dictionary = config.get("team_need", {}).get("need_levels", {})

	# CRITICAL: No players at position
	if player_count == 0:
		return NeedLevel.CRITICAL

	# Get starter rating
	var starter_rating := _get_starter_rating(position_ids, players, positions_cfg, class_rules)
	var ideal_depth := RosterComposition.get_ideal_depth(position)

	# Get thresholds from config
	var high_starter_threshold := float(need_cfg.get("high", {}).get("starter_rating_threshold", 65.0))
	var moderate_range: Array = need_cfg.get("moderate", {}).get("starter_rating_range", [65.0, 72.0])
	var low_starter_min := float(need_cfg.get("low", {}).get("starter_rating_min", 72.0))
	var backup_quality_threshold := float(need_cfg.get("low", {}).get("backup_quality_threshold", 60.0))

	# HIGH: Only 1 player OR starter below threshold
	if player_count == 1:
		return NeedLevel.HIGH
	if starter_rating < high_starter_threshold:
		return NeedLevel.HIGH

	# MODERATE: Starter in 65-72 range OR below ideal depth
	var moderate_min := float(moderate_range[0]) if not moderate_range.is_empty() else 65.0
	var moderate_max := float(moderate_range[1]) if moderate_range.size() > 1 else 72.0
	if starter_rating >= moderate_min and starter_rating < moderate_max:
		return NeedLevel.MODERATE
	if player_count < ideal_depth:
		return NeedLevel.MODERATE

	# LOW: Starter adequate but backup depth is weak
	if starter_rating >= low_starter_min:
		var backup_avg := _get_backup_average_rating(position_ids, players, positions_cfg, class_rules)
		if backup_avg < backup_quality_threshold:
			return NeedLevel.LOW

	# NONE: Position is well-stocked
	return NeedLevel.NONE


## Get the rating of the best player at a position (the starter)
func _get_starter_rating(
	position_ids: Array,
	players: Array,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> float:
	var best_rating := 0.0

	for player in players:
		var p: Dictionary = player
		var pid := String(p.get("player_id", p.get("id", "")))
		if pid in position_ids:
			var rating := PlayerRatingCalculator.calculate_overall_rating(
				p, positions_cfg, class_rules
			)
			best_rating = maxf(best_rating, rating)

	return best_rating


## Get the average rating of backup players at a position
func _get_backup_average_rating(
	position_ids: Array,
	players: Array,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> float:
	if position_ids.size() <= 1:
		return 0.0  # No backups

	# Get all ratings
	var ratings: Array[float] = []
	for player in players:
		var p: Dictionary = player
		var pid := String(p.get("player_id", p.get("id", "")))
		if pid in position_ids:
			var rating := PlayerRatingCalculator.calculate_overall_rating(
				p, positions_cfg, class_rules
			)
			ratings.append(rating)

	# Sort descending, skip the starter
	ratings.sort_custom(func(a, b): return a > b)

	if ratings.size() <= 1:
		return 0.0

	# Average of non-starters
	var total := 0.0
	for i in range(1, ratings.size()):
		total += ratings[i]

	return total / float(ratings.size() - 1)


## Get the base OVR bonus for a need level from config
func _get_need_bonus(level: NeedLevel, config: Dictionary) -> float:
	var levels_cfg: Dictionary = config.get("need_levels", {})

	match level:
		NeedLevel.CRITICAL:
			return float(levels_cfg.get("critical", {}).get("bonus_ovr", 8.0))
		NeedLevel.HIGH:
			return float(levels_cfg.get("high", {}).get("bonus_ovr", 5.0))
		NeedLevel.MODERATE:
			return float(levels_cfg.get("moderate", {}).get("bonus_ovr", 3.0))
		NeedLevel.LOW:
			return float(levels_cfg.get("low", {}).get("bonus_ovr", 1.0))
		_:
			return 0.0


## Get round scaling factor for a need level
func _get_round_scaling(round_num: int, level: NeedLevel, config: Dictionary) -> float:
	var scaling_cfg: Dictionary = config.get("round_scaling", {})
	var level_name := _need_level_to_string(level)

	# Determine which round key to use
	var round_key := ""
	if round_num == 1:
		round_key = "round_1"
	elif round_num == 2:
		round_key = "round_2"
	elif round_num == 3:
		round_key = "round_3"
	else:
		round_key = "round_4_plus"

	var round_scaling: Dictionary = scaling_cfg.get(round_key, {})
	return float(round_scaling.get(level_name, 1.0))


## Get position importance multiplier from config
func _get_position_importance(position: String, config: Dictionary) -> float:
	var importance_cfg: Dictionary = config.get("position_importance_multipliers", {})
	return float(importance_cfg.get(position, 1.0))


## Get reach prevention floor for a round
func _get_reach_prevention_floor(round_num: int, config: Dictionary) -> float:
	var reach_cfg: Dictionary = config.get("reach_prevention", {})

	if round_num == 1:
		return float(reach_cfg.get("round_1_min_ovr", 70.0))
	elif round_num == 2:
		return float(reach_cfg.get("round_2_min_ovr", 65.0))
	elif round_num <= 4:
		return float(reach_cfg.get("round_3_min_ovr", 60.0))
	else:
		return float(reach_cfg.get("round_4_plus_min_ovr", 50.0))


## Convert need level enum to string for config lookup
func _need_level_to_string(level: NeedLevel) -> String:
	match level:
		NeedLevel.CRITICAL:
			return "critical"
		NeedLevel.HIGH:
			return "high"
		NeedLevel.MODERATE:
			return "moderate"
		NeedLevel.LOW:
			return "low"
		_:
			return "none"


## Load and cache configuration using direct file access
func _get_config() -> Dictionary:
	if _config_loaded:
		return _config_cache

	var config := _load_config_file()
	if config.is_empty():
		push_warning("TeamNeedModifierV2: Could not load draft_evaluation config, using defaults")
		_config_cache = _get_default_config()
	else:
		_config_cache = config

	_config_loaded = true
	return _config_cache


## Load config file directly using FileAccess
## Returns empty dictionary on failure
static func _load_config_file() -> Dictionary:
	var file := FileAccess.open(DRAFT_EVALUATION_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("TeamNeedModifierV2: Could not open %s (error: %d)" % [
			DRAFT_EVALUATION_CONFIG_PATH, FileAccess.get_open_error()])
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_warning("TeamNeedModifierV2: JSON parse error in %s at line %d: %s" % [
			DRAFT_EVALUATION_CONFIG_PATH, json.get_error_line(), json.get_error_message()])
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("TeamNeedModifierV2: Config file did not contain a dictionary")
		return {}

	return json.data


## Default configuration if config file not found
static func _get_default_config() -> Dictionary:
	# Default values match configs/sports/american_football/draft_evaluation.json
	# Phase 1 conservative reduction: 50% reduction from original values
	return {
		"team_need": {
			"need_levels": {
				"critical": {"bonus_ovr": 4.0},
				"high": {"starter_rating_threshold": 65.0, "bonus_ovr": 2.5},
				"moderate": {"starter_rating_range": [65.0, 72.0], "bonus_ovr": 1.5},
				"low": {"starter_rating_min": 72.0, "backup_quality_threshold": 60.0, "bonus_ovr": 0.5},
				"none": {"bonus_ovr": 0.0}
			},
			"round_scaling": {
				"round_1": {"critical": 0.6, "high": 0.5, "moderate": 0.4, "low": 0.3},
				"round_2": {"critical": 0.75, "high": 0.7, "moderate": 0.6, "low": 0.5},
				"round_3": {"critical": 0.9, "high": 0.85, "moderate": 0.8, "low": 0.7},
				"round_4_plus": {"critical": 1.0, "high": 1.0, "moderate": 1.0, "low": 1.0}
			},
			"position_importance_multipliers": {
				"QB": 1.5, "EDGE": 1.2, "CB": 1.1, "OL": 1.0, "WR": 1.0,
				"DL": 0.9, "LB": 0.9, "TE": 0.8, "S": 0.8, "RB": 0.7,
				"K": 0.3, "P": 0.3
			},
			"reach_prevention": {
				"round_1_min_ovr": 70.0,
				"round_2_min_ovr": 65.0,
				"round_3_min_ovr": 60.0,
				"round_4_plus_min_ovr": 50.0
			}
		}
	}


## Clear config cache (for testing)
static func clear_cache() -> void:
	_config_cache.clear()
	_config_loaded = false
