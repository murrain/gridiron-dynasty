## HypeModifier - Additive bonus/penalty based on media hype and awards
##
## Applies adjustments based on player hype level and verified awards.
## Teams with higher hype susceptibility are more influenced by media narratives.
##
## Base Hype Formula:
##   hype_delta = (player_hype - 50) / 50  # Range: -1.0 to +1.0
##   raw_bonus = hype_delta * max_bonus_ovr * team_susceptibility * round_scale
##
## Award Signal Bonuses (independent of susceptibility):
##   - Heisman Winner: +3.0 OVR
##   - All-American 1st Team: +2.0 OVR
##   - All-American 2nd/3rd Team: +1.0 OVR
##   - Conference POY: +1.0 OVR
##   - Combine Standout: +0.5 OVR
##   - Maximum award bonus: +4.0 OVR (cap on stacking)
##
## Round Scaling:
##   - Round 1-2: 1.2x (media pressure highest)
##   - Round 3: 1.0x (neutral)
##   - Round 4+: 0.5x (late rounds less affected)
##
## Team Susceptibility Ranges:
##   - Analytics-focused: 0.15 to 0.35 (largely ignore hype)
##   - Balanced: 0.40 to 0.60 (moderate influence)
##   - Narrative-driven: 0.65 to 0.85 (chase names and stories)
##
## Example Scenarios:
##   - Heisman winner (hype 95), balanced team (0.5), R1:
##     Hype: (95-50)/50 * 5.0 * 0.5 * 1.2 = +2.7 OVR
##     Award: +3.0 OVR
##     Total: +5.7 OVR
##
##   - 5-star bust (hype 80), narrative team (0.8), R1:
##     Hype: (80-50)/50 * 5.0 * 0.8 * 1.2 = +2.88 OVR
##     Award: +0.0 OVR
##     Total: +2.88 OVR
##
##   - Small school stud (hype 35), balanced team (0.5), R1:
##     Hype: (35-50)/50 * 3.0 * 0.5 * 1.2 = -0.54 OVR
##     Award: +0.0 OVR
##     Total: -0.54 OVR
##
## RNG Usage: None (deterministic calculation based on player hype and awards)
##
## Range: -3.0 to +9.0 OVR
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

## Path to draft evaluation config file
const DRAFT_EVALUATION_CONFIG_PATH := "res://configs/sports/american_football/draft_evaluation.json"

## Cached config for performance (loaded once)
static var _config_cache: Dictionary = {}
static var _config_loaded: bool = false


func get_id() -> String:
	return "hype"


func get_display_name() -> String:
	return "Media Hype"


func get_description() -> String:
	return "Additive OVR adjustment based on media hype and verified awards"


func get_priority() -> int:
	# Run after team need and scouting knowledge, before scheme fit
	return 40


## Bounds for additive bonus: -3 to +9 OVR points
func get_bounds() -> Dictionary:
	return {"min": -3.0, "max": 9.0}


func get_tags() -> Array:
	return ["hype", "evaluation", "team_specific", "additive", "draft"]


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
	if not bool(flags.get("enable_hype_modifier", true)):
		return false
	return true


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var config := _get_config()
	var hype_cfg: Dictionary = config.get("hype", {})

	var player := ctx.player
	var team := ctx.team
	var round_num := ctx.draft_round

	# Get player hype (0-100, neutral is 50)
	var hype := float(player.get("hype", 50.0))

	# Get team's hype susceptibility
	var susceptibility := float(team.get("hype_susceptibility", 0.5))

	# Step 1: Calculate raw hype bonus
	var base_effect: Dictionary = hype_cfg.get("base_effect", {})
	var neutral_hype := float(base_effect.get("neutral_hype", 50.0))
	var max_bonus := float(base_effect.get("max_bonus_ovr", 5.0))
	var max_penalty := float(base_effect.get("max_penalty_ovr", -3.0))

	var hype_delta := (hype - neutral_hype) / 50.0  # Range: -1.0 to +1.0

	var raw_hype_bonus := 0.0
	if hype_delta >= 0.0:
		raw_hype_bonus = hype_delta * max_bonus
	else:
		raw_hype_bonus = hype_delta * absf(max_penalty)

	# Step 2: Apply team susceptibility
	var hype_bonus := raw_hype_bonus * susceptibility

	# Step 3: Apply round scaling
	var round_scale := _get_round_scaling(round_num, hype_cfg)
	hype_bonus *= round_scale

	# Step 4: Calculate award signal bonuses (independent of susceptibility)
	var awards: Array = player.get("awards", [])
	var award_bonus := _calculate_award_bonus(awards, hype_cfg)

	# Step 5: Calculate total adjustment
	var total_adjustment := hype_bonus + award_bonus

	# Build explanation
	var reason := ""
	if absf(total_adjustment) < 0.01:
		reason = "Neutral hype effect"
	elif total_adjustment > 0:
		reason = "Positive hype/awards (+%.1f OVR)" % total_adjustment
	else:
		reason = "Low-profile prospect (%.1f OVR)" % total_adjustment

	return ModifierResult.create_additive(total_adjustment, reason, {
		"player_hype": hype,
		"hype_delta": hype_delta,
		"team_susceptibility": susceptibility,
		"raw_hype_bonus": raw_hype_bonus,
		"round": round_num,
		"round_scale": round_scale,
		"hype_bonus_after_scale": hype_bonus,
		"awards": awards,
		"award_bonus": award_bonus,
		"total_adjustment": total_adjustment
	})


## Get round scaling factor from config
func _get_round_scaling(round_num: int, config: Dictionary) -> float:
	var scaling: Dictionary = config.get("round_scaling", {})

	if round_num <= 2:
		return float(scaling.get("round_1", 1.2))
	elif round_num == 3:
		return float(scaling.get("round_3", 0.8))
	else:
		return float(scaling.get("round_4_plus", 0.5))


## Calculate total award bonus from player's awards
##
## Award bonuses are independent of team susceptibility because
## awards represent verified talent signals, not media narrative.
func _calculate_award_bonus(awards: Array, config: Dictionary) -> float:
	var award_bonuses: Dictionary = config.get("award_signal_bonuses", {})
	var max_award_bonus := float(config.get("max_award_bonus", 4.0))

	var total := 0.0

	for award in awards:
		var award_name := String(award)

		# Try to find matching award in config
		var bonus := 0.0

		# Check for exact match first
		if award_bonuses.has(award_name):
			var award_data = award_bonuses[award_name]
			if award_data is Dictionary:
				bonus = float(award_data.get("bonus_ovr", 0.0))
			else:
				bonus = float(award_data)
		else:
			# Try normalized name (lowercase, underscores)
			var normalized := _normalize_award_name(award_name)
			if award_bonuses.has(normalized):
				var award_data = award_bonuses[normalized]
				if award_data is Dictionary:
					bonus = float(award_data.get("bonus_ovr", 0.0))
				else:
					bonus = float(award_data)

		total += bonus

	# Cap total award bonus to prevent stacking
	return minf(total, max_award_bonus)


## Normalize award name for config lookup
func _normalize_award_name(award_name: String) -> String:
	# Convert to lowercase and replace spaces with underscores
	var normalized := award_name.to_lower()
	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace("-", "_")
	return normalized


## Load and cache configuration using direct file access
func _get_config() -> Dictionary:
	if _config_loaded:
		return _config_cache

	var config := _load_config_file()
	if config.is_empty():
		push_warning("HypeModifier: Could not load draft_evaluation config, using defaults")
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
		push_warning("HypeModifier: Could not open %s (error: %d)" % [
			DRAFT_EVALUATION_CONFIG_PATH, FileAccess.get_open_error()])
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_warning("HypeModifier: JSON parse error in %s at line %d: %s" % [
			DRAFT_EVALUATION_CONFIG_PATH, json.get_error_line(), json.get_error_message()])
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("HypeModifier: Config file did not contain a dictionary")
		return {}

	return json.data


## Default configuration if config file not found
static func _get_default_config() -> Dictionary:
	return {
		"feature_flags": {
			"enable_hype_modifier": true
		},
		"hype": {
			"base_effect": {
				"neutral_hype": 50.0,
				"max_bonus_ovr": 5.0,
				"max_penalty_ovr": -3.0
			},
			"round_scaling": {
				"round_1": 1.2,
				"round_2": 1.0,
				"round_3": 0.8,
				"round_4_plus": 0.5
			},
			"award_signal_bonuses": {
				"heisman_winner": {"bonus_ovr": 3.0},
				"heisman_finalist": {"bonus_ovr": 1.5},
				"all_american_first": {"bonus_ovr": 2.0},
				"all_american_second": {"bonus_ovr": 1.0},
				"all_american_third": {"bonus_ovr": 0.0},
				"conference_poy": {"bonus_ovr": 1.0},
				"combine_standout": {"bonus_ovr": 0.5},
				"senior_bowl_mvp": {"bonus_ovr": 0.5}
			},
			"max_award_bonus": 4.0,
			"team_susceptibility": {
				"generation_weights": {
					"analytics_focused": 0.20,
					"balanced": 0.55,
					"narrative_driven": 0.25
				},
				"ranges": {
					"analytics_focused": {"min": 0.15, "max": 0.35},
					"balanced": {"min": 0.40, "max": 0.60},
					"narrative_driven": {"min": 0.65, "max": 0.85}
				}
			}
		}
	}


## Clear config cache (for testing)
static func clear_cache() -> void:
	_config_cache.clear()
	_config_loaded = false


## Generate a random hype susceptibility for a team based on config weights
##
## This is a helper for team generation. Teams can be:
##   - analytics_focused (20% of teams): 0.15-0.35 susceptibility
##   - balanced (55% of teams): 0.40-0.60 susceptibility
##   - narrative_driven (25% of teams): 0.65-0.85 susceptibility
##
## RNG Usage: 2 calls - one for category selection, one for value within range
static func generate_team_susceptibility(rng: RandomNumberGenerator) -> Dictionary:
	var config := _get_default_config()
	var susc_cfg: Dictionary = config.get("hype", {}).get("team_susceptibility", {})
	var weights: Dictionary = susc_cfg.get("generation_weights", {})
	var ranges: Dictionary = susc_cfg.get("ranges", {})

	# RNG Call 1: Select category based on weights
	var roll := rng.randf()
	var cumulative := 0.0
	var category := "balanced"

	for cat in weights.keys():
		if cat == "description":
			continue
		cumulative += float(weights[cat])
		if roll <= cumulative:
			category = cat
			break

	# RNG Call 2: Generate value within category range
	var range_data: Dictionary = ranges.get(category, {"min": 0.4, "max": 0.6})
	var min_val := float(range_data.get("min", 0.4))
	var max_val := float(range_data.get("max", 0.6))
	var susceptibility := rng.randf_range(min_val, max_val)

	return {
		"category": category,
		"susceptibility": susceptibility
	}
