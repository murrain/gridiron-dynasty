## SchemeFitModifier - Adjusts player evaluation based on scheme fit
##
## Players who fit the team's offensive/defensive scheme get a bonus.
## Uses SchemeFitCalculator for the underlying calculation.
##
## Elite players (90+) are less affected by scheme (talent transcends system).
extends "res://scripts/core/modifiers/Modifier.gd"

const SchemeFitCalculator = preload("res://scripts/core/scouting/SchemeFitCalculator.gd")


func get_id() -> String:
	return "scheme_fit"


func get_display_name() -> String:
	return "Scheme Fit"


func get_description() -> String:
	return "Adjusts evaluation based on how well player fits team's offensive/defensive scheme"


func get_target() -> Target:
	return Target.TEAM_EVALUATION


func get_contexts() -> Array:
	return [Context.DRAFT, Context.FREE_AGENCY, Context.TRADE]


func get_priority() -> int:
	return 50  # Core modifier, applies early


func get_tags() -> Array:
	return ["scheme", "evaluation", "team_specific"]


func is_applicable(context_data: Dictionary) -> bool:
	# Need player, position, and team scheme info
	var position := String(context_data.get("position", ""))
	if position.is_empty():
		return false

	# Special teams aren't affected by offensive/defensive schemes
	if position in ["K", "P"]:
		return false

	return true


func calculate(context_data: Dictionary) -> ModifierResult:
	var player: Dictionary = context_data.get("player", {}) as Dictionary
	var position := String(context_data.get("position", ""))
	var base_rating := float(context_data.get("base_rating", 50.0))
	var offensive_scheme := String(context_data.get("offensive_scheme", "pro_style"))
	var defensive_scheme := String(context_data.get("defensive_scheme", "cover_2"))

	# Get coach rigidity if available
	var coach: Dictionary = context_data.get("coach", {}) as Dictionary
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
		# Clamp to reasonable range
		multiplier = clampf(multiplier, 0.8, 1.2)

	# Build reason string
	var reason := ""
	if multiplier > 1.01:
		reason = "Good fit for %s/%s scheme" % [offensive_scheme, defensive_scheme]
	elif multiplier < 0.99:
		reason = "Poor fit for %s/%s scheme" % [offensive_scheme, defensive_scheme]
	else:
		reason = "Neutral scheme fit"

	return ModifierResult.new(multiplier, 0.0, reason, {
		"offensive_scheme": offensive_scheme,
		"defensive_scheme": defensive_scheme,
		"coach_rigidity": coach_rigidity,
		"scheme_adjusted_rating": scheme_adjusted
	})
