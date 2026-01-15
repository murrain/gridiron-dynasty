## CoachMindsetModifier - Adjusts evaluation based on coach's philosophy
##
## Defensive-minded coaches prefer defensive players.
## Offensive-minded coaches prefer offensive players.
## Position specialists heavily favor their specialty.
##
## Examples:
##   - Rex Ryan (Defense) → Boosts EDGE, LB, CB
##   - Sean McVay (Offense) → Boosts WR, RB, OL
##   - Andy Reid (QB) → Heavily boosts QB prospects
extends "res://scripts/core/modifiers/Modifier.gd"

## Boost for matching side of ball (non-elite)
var _base_boost: float = 1.08

## Boost for elite prospects on matching side
var _elite_boost: float = 1.15

## Penalty for opposite side of ball
var _opposite_penalty: float = 0.97

## Boost for position specialist match
var _specialist_boost: float = 1.12

## Boost for elite prospects matching specialist
var _specialist_elite_boost: float = 1.18

## Elite threshold (78+ = elite prospect)
var _elite_threshold: float = 78.0

## Phase multiplier (FA is more need-driven, less coach preference)
var _phase_dampening: Dictionary = {
	"draft": 1.0,
	"free_agency": 0.6,  # Dampened for FA
	"trade": 0.8,
}


func get_id() -> String:
	return "coach_mindset"


func get_display_name() -> String:
	return "Coach Mindset"


func get_description() -> String:
	return "Adjusts evaluation based on coach's offensive/defensive philosophy"


func get_target() -> Target:
	return Target.TEAM_EVALUATION


func get_contexts() -> Array:
	return [Context.DRAFT, Context.FREE_AGENCY, Context.TRADE]


func get_priority() -> int:
	return 60  # After scheme fit


func get_tags() -> Array:
	return ["coach", "evaluation", "team_specific"]


## Configure for dampened FA effect
func configure_for_fa() -> void:
	_base_boost = 1.05
	_elite_boost = 1.08
	_opposite_penalty = 0.98
	_specialist_boost = 1.06
	_specialist_elite_boost = 1.10


func is_applicable(context_data: Dictionary) -> bool:
	var coach: Dictionary = context_data.get("coach", {}) as Dictionary
	var specialty := String(coach.get("specialty_position", ""))

	# No specialty = no effect
	return not specialty.is_empty()


func calculate(context_data: Dictionary) -> ModifierResult:
	var position := String(context_data.get("position", ""))
	var rating := float(context_data.get("base_rating", 50.0))
	var phase := String(context_data.get("phase", "draft"))
	var coach: Dictionary = context_data.get("coach", {}) as Dictionary
	var specialty := String(coach.get("specialty_position", ""))

	# Get phase dampening
	var dampening := float(_phase_dampening.get(phase, 1.0))

	# Calculate raw multiplier
	var raw_mult := _calculate_multiplier(position, rating, specialty)

	# Apply dampening (move toward 1.0 based on phase)
	var multiplier := 1.0 + (raw_mult - 1.0) * dampening

	# Build reason
	var reason := _build_reason(position, specialty, multiplier)

	return ModifierResult.new(multiplier, 0.0, reason, {
		"specialty": specialty,
		"position": position,
		"is_elite": rating >= _elite_threshold,
		"phase": phase,
		"dampening": dampening
	})


func _calculate_multiplier(position: String, rating: float, specialty: String) -> float:
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]
	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	var is_offensive := position in offensive_positions
	var is_defensive := position in defensive_positions
	var is_elite := rating >= _elite_threshold

	if specialty == "Defense":
		if is_defensive:
			return _elite_boost if is_elite else _base_boost
		elif is_offensive:
			return _opposite_penalty

	elif specialty == "Offense":
		if is_offensive:
			return _elite_boost if is_elite else _base_boost
		elif is_defensive:
			return _opposite_penalty

	else:
		# Position-specific specialty (e.g., "QB", "EDGE")
		if position == specialty:
			return _specialist_elite_boost if is_elite else _specialist_boost
		elif specialty in offensive_positions and is_offensive:
			return 1.03  # Slight boost to same side
		elif specialty in defensive_positions and is_defensive:
			return 1.03

	return 1.0


func _build_reason(position: String, specialty: String, multiplier: float) -> String:
	if multiplier > 1.01:
		if position == specialty:
			return "Coach specializes in %s development" % position
		elif specialty == "Defense":
			return "Defensive-minded coach values %s" % position
		elif specialty == "Offense":
			return "Offensive-minded coach values %s" % position
		else:
			return "Coach preference for %s side of ball" % ("offense" if position in ["QB", "RB", "WR", "TE", "OL"] else "defense")
	elif multiplier < 0.99:
		return "Not coach's priority (%s-focused)" % specialty
	return "Neutral coach preference"
