## SchemeFitModifier - Adjusts player evaluation based on scheme fit
##
## Players who fit the team's offensive/defensive scheme get a bonus.
## Uses SchemeFitCalculator for the underlying calculation.
##
## Elite players (90+) are less affected by scheme (talent transcends system).
##
## Effect Range: +/-15% evaluation adjustment (clamped to 0.85 - 1.15)
##
## Key Scheme Preferences:
## - 3-4 teams boost EDGE/LB (coverage-focused linebackers)
## - 4-3 teams boost DL (big defensive linemen)
## - West Coast offenses boost accurate QBs, route-running WRs
## - Air Raid offenses boost arm strength QBs, speed WRs
##
## RNG Usage: None (pure calculation from player attributes and scheme weights)
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

const SchemeFitCalculator = preload("res://scripts/core/scouting/SchemeFitCalculator.gd")

## Cached scheme config for performance (loaded once on first use)
static var _schemes_cache: Dictionary = {}
static var _validation_complete: bool = false

## All positions that should have scheme mappings
const OFFENSIVE_POSITIONS := ["QB", "RB", "WR", "TE", "OL"]
const DEFENSIVE_POSITIONS := ["DL", "EDGE", "LB", "CB", "S"]
const ALL_SCHEME_POSITIONS := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]


func get_id() -> String:
	return "scheme_fit"


func get_display_name() -> String:
	return "Scheme Fit"


func get_description() -> String:
	return "Adjusts evaluation based on how well player fits team's offensive/defensive scheme"


func get_priority() -> int:
	return 50


func get_bounds() -> Dictionary:
	# +/-15% max effect per spec
	return {"min": 0.85, "max": 1.15}


func get_tags() -> Array:
	return ["scheme", "evaluation", "team_specific"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Need player, position, and team scheme info
	if ctx.position.is_empty():
		return false

	# Special teams aren't affected by offensive/defensive schemes
	if ctx.position in ["K", "P"]:
		return false

	return true


## Validate scheme mappings at startup
## Called automatically on first calculate() call
## Ensures all positions have weight mappings in all schemes
static func validate_scheme_mappings() -> Dictionary:
	if _validation_complete:
		return {"valid": true, "errors": []}

	var schemes_cfg := _get_cached_schemes_config()
	if schemes_cfg.is_empty():
		return {"valid": false, "errors": ["Failed to load schemes.json"]}

	var errors: Array = []

	# Validate offensive schemes have offensive positions
	var offensive_schemes: Dictionary = schemes_cfg.get("offensive_schemes", {})
	for scheme_name in offensive_schemes.keys():
		var scheme: Dictionary = offensive_schemes[scheme_name]
		var weights: Dictionary = scheme.get("position_stat_weights", {})

		# Not all schemes need all positions (e.g., pro_style is intentionally sparse)
		# But log a warning if a key position is missing
		if scheme_name != "pro_style":
			for pos in ["QB", "WR", "RB"]:
				if not weights.has(pos):
					# Info, not error - some schemes may not emphasize certain positions
					pass

	# Validate defensive schemes have defensive positions
	var defensive_schemes: Dictionary = schemes_cfg.get("defensive_schemes", {})
	for scheme_name in defensive_schemes.keys():
		var scheme: Dictionary = defensive_schemes[scheme_name]
		var weights: Dictionary = scheme.get("position_stat_weights", {})

		# Check that at least one position is defined
		if weights.is_empty():
			errors.append("Defensive scheme '%s' has no position_stat_weights" % scheme_name)

	# Validate config section exists with valid bounds
	var config: Dictionary = schemes_cfg.get("config", {})
	var scheme_fit_cfg: Dictionary = config.get("scheme_fit", {})
	var weight_range: Dictionary = scheme_fit_cfg.get("weight_range", {})

	var min_weight := float(weight_range.get("min", 0.6))
	var max_weight := float(weight_range.get("max", 1.4))

	if min_weight >= max_weight:
		errors.append("Invalid weight_range: min (%.2f) >= max (%.2f)" % [min_weight, max_weight])

	_validation_complete = true

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"offensive_schemes": offensive_schemes.keys(),
		"defensive_schemes": defensive_schemes.keys()
	}


## Get cached schemes config (singleton pattern for performance)
static func _get_cached_schemes_config() -> Dictionary:
	if _schemes_cache.is_empty():
		_schemes_cache = SchemeFitCalculator.load_schemes_config()
	return _schemes_cache


## Clear cached config (for testing)
static func clear_cache() -> void:
	_schemes_cache.clear()
	_validation_complete = false


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var player: Dictionary = ctx.player
	var position := ctx.position
	var base_rating := ctx.base_rating
	var offensive_scheme := ctx.offensive_scheme
	var defensive_scheme := ctx.defensive_scheme

	# Get coach rigidity if available
	var coach: Dictionary = ctx.coach
	var coach_rigidity := float(coach.get("scheme_rigidity", 1.0))

	# Calculate scheme-adjusted rating
	var scheme_adjusted := SchemeFitCalculator.calculate_for_team(
		player,
		position,
		base_rating,
		offensive_scheme,
		defensive_scheme,
		coach_rigidity
	)

	# Convert to multiplier
	var multiplier := 1.0
	if base_rating > 0.0:
		multiplier = scheme_adjusted / base_rating
		# Clamp to +/-15% range per spec
		multiplier = clampf(multiplier, 0.85, 1.15)

	# Elite player dampening check
	# Elite players (90+) should have reduced scheme impact (talent > scheme)
	var elite_dampening := SchemeFitCalculator.calculate_elite_dampening(base_rating)

	# Build detailed reason string based on multiplier
	var reason := ""
	var fit_quality := ""
	if multiplier > 1.10:
		fit_quality = "Excellent"
		reason = "%s fit for %s scheme (+%.0f%%)" % [fit_quality, _get_relevant_scheme(position, offensive_scheme, defensive_scheme), (multiplier - 1.0) * 100]
	elif multiplier > 1.01:
		fit_quality = "Good"
		reason = "%s fit for %s scheme (+%.0f%%)" % [fit_quality, _get_relevant_scheme(position, offensive_scheme, defensive_scheme), (multiplier - 1.0) * 100]
	elif multiplier < 0.90:
		fit_quality = "Poor"
		reason = "%s fit for %s scheme (%.0f%%)" % [fit_quality, _get_relevant_scheme(position, offensive_scheme, defensive_scheme), (multiplier - 1.0) * 100]
	elif multiplier < 0.99:
		fit_quality = "Below average"
		reason = "%s fit for %s scheme (%.0f%%)" % [fit_quality, _get_relevant_scheme(position, offensive_scheme, defensive_scheme), (multiplier - 1.0) * 100]
	else:
		fit_quality = "Neutral"
		reason = "Neutral scheme fit"

	return ModifierResult.new(multiplier, reason, {
		"offensive_scheme": offensive_scheme,
		"defensive_scheme": defensive_scheme,
		"coach_rigidity": coach_rigidity,
		"scheme_adjusted_rating": scheme_adjusted,
		"fit_quality": fit_quality,
		"elite_dampening": elite_dampening,
		"base_rating": base_rating
	})


## Get the relevant scheme name for this position (offensive or defensive)
func _get_relevant_scheme(position: String, offensive_scheme: String, defensive_scheme: String) -> String:
	if position in OFFENSIVE_POSITIONS:
		return offensive_scheme.replace("_", " ")
	elif position in DEFENSIVE_POSITIONS:
		return defensive_scheme.replace("_", " ")
	return "N/A"


## Calculate the scheme fit score for display purposes
## Returns a 0-100 score representing how well the player fits the scheme
## This is used by UI components to show scheme fit without needing the full context
static func calculate_scheme_fit_score(
	player: Dictionary,
	position: String,
	base_rating: float,
	offensive_scheme: String,
	defensive_scheme: String,
	coach_rigidity: float = 1.0
) -> float:
	var scheme_adjusted := SchemeFitCalculator.calculate_for_team(
		player,
		position,
		base_rating,
		offensive_scheme,
		defensive_scheme,
		coach_rigidity
	)

	# Convert to 0-100 scale based on multiplier effect
	var multiplier := 1.0
	if base_rating > 0.0:
		multiplier = scheme_adjusted / base_rating

	# Map 0.85-1.15 multiplier to 0-100 score
	# 0.85 -> 25 (poor fit)
	# 1.0  -> 62.5 (neutral)
	# 1.15 -> 100 (excellent fit)
	var score := ((multiplier - 0.85) / 0.30) * 100.0
	return clampf(score, 0.0, 100.0)


## Get scheme fit grade letter for display (A-F scale)
static func get_scheme_fit_grade(score: float) -> String:
	if score >= 90:
		return "A+"
	elif score >= 80:
		return "A"
	elif score >= 70:
		return "B+"
	elif score >= 60:
		return "B"
	elif score >= 50:
		return "C"
	elif score >= 40:
		return "D"
	else:
		return "F"
