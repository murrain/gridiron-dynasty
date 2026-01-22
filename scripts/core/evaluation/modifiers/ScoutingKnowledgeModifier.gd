## ScoutingKnowledgeModifier - Additive penalty based on scouting knowledge
##
## Applies penalties to unknown/poorly-scouted players to simulate the risk
## of drafting players without thorough evaluation.
##
## Knowledge Levels (based on scouting hours invested):
##   - comprehensive (40+ hours): 0.0 OVR penalty - full confidence
##   - solid (20+ hours): 0.0 OVR penalty - good confidence
##   - moderate (8+ hours): -1.0 OVR base penalty
##   - limited (2+ hours): -2.0 OVR base penalty
##   - unknown (0 hours): -4.0 OVR base penalty
##
## Round amplification (high picks require certainty):
##   - Round 1: 2.0x penalty multiplier
##   - Round 2-3: 1.5x penalty multiplier
##   - Round 4+: 0.8x penalty multiplier (late rounds tolerate risk)
##
## Team philosophy tolerance (inverse penalty scaling):
##   - analytics_heavy (0.7 tolerance): Penalty / 0.7 = 1.43x penalty
##   - traditional (0.5 tolerance): Penalty / 0.5 = 2.0x penalty
##   - aggressive (1.2 tolerance): Penalty / 1.2 = 0.83x penalty
##
## Final formula:
##   adjustment = base_penalty * round_multiplier * (1.0 / philosophy_tolerance)
##
## Example scenarios:
##   - Unknown player, Round 1, Traditional: -4.0 * 2.0 * 2.0 = -16.0 OVR
##   - Unknown player, Round 1, Analytics: -4.0 * 2.0 * 1.43 = -11.4 OVR
##   - Unknown player, Round 5, Aggressive: -4.0 * 0.8 * 0.83 = -2.7 OVR
##   - Limited player, Round 2, Traditional: -2.0 * 1.5 * 2.0 = -6.0 OVR
##
## RNG Usage: None (deterministic calculation based on scouting data)
##
## Maximum penalty: -16 OVR (unknown player in R1 with traditional philosophy)
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

## Path to draft evaluation config file
const DRAFT_EVALUATION_CONFIG_PATH := "res://configs/sports/american_football/draft_evaluation.json"

## Cached config for performance (loaded once)
static var _config_cache: Dictionary = {}
static var _config_loaded: bool = false

## Knowledge level enum for clarity
enum KnowledgeLevel {
	COMPREHENSIVE,
	SOLID,
	MODERATE,
	LIMITED,
	UNKNOWN
}


func get_id() -> String:
	return "scouting_knowledge"


func get_display_name() -> String:
	return "Scouting Knowledge"


func get_description() -> String:
	return "Additive OVR penalty based on scouting uncertainty for prospect"


func get_priority() -> int:
	# Run after team need, before scheme fit and hype
	return 35


## Bounds for additive penalty: -16 to 0 OVR points
func get_bounds() -> Dictionary:
	return {"min": -16.0, "max": 0.0}


func get_tags() -> Array:
	return ["scouting", "evaluation", "team_specific", "additive", "draft"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Only applies during draft phase
	if ctx.phase != "draft":
		return false
	# Need draft round
	if ctx.draft_round <= 0:
		return false
	# Feature flag check (from config)
	var config := _get_config()
	var flags: Dictionary = config.get("feature_flags", {})
	if not bool(flags.get("enable_scouting_knowledge_modifier", true)):
		return false
	return true


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var config := _get_config()
	var scouting_cfg: Dictionary = config.get("scouting_knowledge", {})

	var player := ctx.player
	var team := ctx.team
	var round_num := ctx.draft_round
	var player_id := String(player.get("player_id", player.get("id", "")))
	var team_id := String(team.get("id", ""))

	# Step 1: Determine knowledge level based on scouting hours
	var knowledge_level := _determine_knowledge_level(player, team, ctx, scouting_cfg)

	# Step 2: Get base penalty for knowledge level
	var base_penalty := _get_base_penalty(knowledge_level, scouting_cfg)

	# If no penalty (comprehensive/solid scouting), return neutral
	if absf(base_penalty) < 0.001:
		return ModifierResult.create_additive(0.0,
			"Well-scouted prospect - full confidence",
			{
				"knowledge_level": _level_to_string(knowledge_level),
				"scouting_hours": _get_scouting_hours(player, team, ctx),
				"round": round_num,
				"adjustment": 0.0
			})

	# Step 3: Apply round-based risk multiplier
	var round_multiplier := _get_round_multiplier(round_num, scouting_cfg)

	# Step 4: Apply team philosophy tolerance
	var philosophy := String(team.get("scouting_philosophy", "traditional"))
	var tolerance := _get_philosophy_tolerance(philosophy, scouting_cfg)

	# Calculate final adjustment (penalties are negative, amplified by low tolerance)
	var adjustment := base_penalty * round_multiplier * (1.0 / tolerance)

	# Build explanation
	var level_name := _level_to_string(knowledge_level)
	var reason := "%s knowledge of prospect (%.1f OVR)" % [level_name.capitalize(), adjustment]

	return ModifierResult.create_additive(adjustment, reason, {
		"knowledge_level": level_name,
		"scouting_hours": _get_scouting_hours(player, team, ctx),
		"base_penalty": base_penalty,
		"round": round_num,
		"round_multiplier": round_multiplier,
		"philosophy": philosophy,
		"tolerance": tolerance,
		"adjustment": adjustment
	})


## Determine knowledge level based on scouting hours invested
##
## Scouting data structure expected in world_state:
##   world_state["scouting_data"][team_id][player_id] = {
##     "hours": float,
##     "evaluations": int,
##     "last_scouted": year
##   }
##
## If no scouting data exists, uses player hype as a proxy:
##   - High hype (75+) = "limited" (public info available)
##   - Medium hype (50-74) = "minimal"
##   - Low hype (<50) = "unknown"
func _determine_knowledge_level(
	player: Dictionary,
	team: Dictionary,
	ctx: EvaluationContext,
	config: Dictionary
) -> KnowledgeLevel:
	var hours := _get_scouting_hours(player, team, ctx)
	var levels_cfg: Dictionary = config.get("levels", {})

	# Check from highest to lowest
	var comp_hours := float(levels_cfg.get("comprehensive", {}).get("min_scouting_hours", 40.0))
	if hours >= comp_hours:
		return KnowledgeLevel.COMPREHENSIVE

	var solid_hours := float(levels_cfg.get("solid", {}).get("min_scouting_hours", 20.0))
	if hours >= solid_hours:
		return KnowledgeLevel.SOLID

	var moderate_hours := float(levels_cfg.get("moderate", {}).get("min_scouting_hours", 8.0))
	if hours >= moderate_hours:
		return KnowledgeLevel.MODERATE

	var limited_hours := float(levels_cfg.get("limited", {}).get("min_scouting_hours", 2.0))
	if hours >= limited_hours:
		return KnowledgeLevel.LIMITED

	return KnowledgeLevel.UNKNOWN


## Get scouting hours invested by this team for this player
##
## Falls back to hype-based estimation if no explicit scouting data exists.
## High-hype players have more public information available.
func _get_scouting_hours(player: Dictionary, team: Dictionary, ctx: EvaluationContext) -> float:
	var team_id := String(team.get("id", ""))
	var player_id := String(player.get("player_id", player.get("id", "")))

	# Try to get actual scouting data
	# Note: Scouting data would be tracked in world_state["scouting_data"]
	# This is the data structure for future expansion when team scouting
	# time allocation is fully implemented.
	#
	# For now, we use a heuristic based on player hype:
	# - High hype players have more public info (combine, media coverage)
	# - This translates to implicit "scouting hours" from public sources
	#
	# In the future, this will read from:
	#   ctx.team.get("scouting_investments", {}).get(player_id, {}).get("hours", 0.0)

	# Get team's scouting investments if available
	var team_scouting: Dictionary = team.get("scouting_investments", {})
	var player_scouting: Dictionary = team_scouting.get(player_id, {})
	var explicit_hours := float(player_scouting.get("hours", 0.0))

	if explicit_hours > 0.0:
		return explicit_hours

	# Fall back to hype-based estimation
	# High-profile players are inherently more "known" due to media coverage
	var hype := float(player.get("hype", 50.0))

	# Convert hype to implicit scouting hours:
	#   - Hype 100: ~15 hours of public info (combine, interviews, game film)
	#   - Hype 75: ~8 hours (solid coverage)
	#   - Hype 50: ~4 hours (average coverage)
	#   - Hype 25: ~1 hour (minimal coverage)
	#   - Hype 0: 0 hours (completely unknown)
	var implicit_hours := (hype / 100.0) * 15.0

	return implicit_hours


## Get base penalty for a knowledge level from config
func _get_base_penalty(level: KnowledgeLevel, config: Dictionary) -> float:
	var levels_cfg: Dictionary = config.get("levels", {})

	match level:
		KnowledgeLevel.COMPREHENSIVE:
			return float(levels_cfg.get("comprehensive", {}).get("confidence_bonus_ovr", 0.0))
		KnowledgeLevel.SOLID:
			return float(levels_cfg.get("solid", {}).get("confidence_bonus_ovr", 0.0))
		KnowledgeLevel.MODERATE:
			return float(levels_cfg.get("moderate", {}).get("confidence_bonus_ovr", -1.0))
		KnowledgeLevel.LIMITED:
			return float(levels_cfg.get("limited", {}).get("confidence_bonus_ovr", -2.0))
		KnowledgeLevel.UNKNOWN:
			return float(levels_cfg.get("unknown", {}).get("confidence_bonus_ovr", -4.0))
		_:
			return 0.0


## Get round-based risk multiplier
func _get_round_multiplier(round_num: int, config: Dictionary) -> float:
	var multipliers: Dictionary = config.get("round_risk_multipliers", {})

	if round_num == 1:
		return float(multipliers.get("round_1", 2.0))
	elif round_num <= 3:
		return float(multipliers.get("round_2", 1.5))
	else:
		return float(multipliers.get("round_4_plus", 0.8))


## Get philosophy tolerance from config
func _get_philosophy_tolerance(philosophy: String, config: Dictionary) -> float:
	var tolerance_cfg: Dictionary = config.get("team_philosophy_tolerance", {})
	var philosophy_data: Dictionary = tolerance_cfg.get(philosophy, {})
	return float(philosophy_data.get("tolerance", 0.5))


## Convert knowledge level enum to string
func _level_to_string(level: KnowledgeLevel) -> String:
	match level:
		KnowledgeLevel.COMPREHENSIVE:
			return "comprehensive"
		KnowledgeLevel.SOLID:
			return "solid"
		KnowledgeLevel.MODERATE:
			return "moderate"
		KnowledgeLevel.LIMITED:
			return "limited"
		KnowledgeLevel.UNKNOWN:
			return "unknown"
		_:
			return "unknown"


## Load and cache configuration using direct file access
func _get_config() -> Dictionary:
	if _config_loaded:
		return _config_cache

	var config := _load_config_file()
	if config.is_empty():
		push_warning("ScoutingKnowledgeModifier: Could not load draft_evaluation config, using defaults")
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
		push_warning("ScoutingKnowledgeModifier: Could not open %s (error: %d)" % [
			DRAFT_EVALUATION_CONFIG_PATH, FileAccess.get_open_error()])
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_warning("ScoutingKnowledgeModifier: JSON parse error in %s at line %d: %s" % [
			DRAFT_EVALUATION_CONFIG_PATH, json.get_error_line(), json.get_error_message()])
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("ScoutingKnowledgeModifier: Config file did not contain a dictionary")
		return {}

	return json.data


## Default configuration if config file not found
static func _get_default_config() -> Dictionary:
	return {
		"feature_flags": {
			"enable_scouting_knowledge_modifier": true
		},
		"scouting_knowledge": {
			"levels": {
				"comprehensive": {"min_scouting_hours": 40.0, "confidence_bonus_ovr": 0.0},
				"solid": {"min_scouting_hours": 20.0, "confidence_bonus_ovr": 0.0},
				"moderate": {"min_scouting_hours": 8.0, "confidence_bonus_ovr": -1.0},
				"limited": {"min_scouting_hours": 2.0, "confidence_bonus_ovr": -2.0},
				"unknown": {"min_scouting_hours": 0.0, "confidence_bonus_ovr": -4.0}
			},
			"round_risk_multipliers": {
				"round_1": 2.0,
				"round_2": 1.5,
				"round_3": 1.2,
				"round_4_plus": 0.8
			},
			"team_philosophy_tolerance": {
				"analytics_heavy": {"tolerance": 0.7},
				"traditional": {"tolerance": 0.5},
				"aggressive": {"tolerance": 1.2}
			}
		}
	}


## Clear config cache (for testing)
static func clear_cache() -> void:
	_config_cache.clear()
	_config_loaded = false
