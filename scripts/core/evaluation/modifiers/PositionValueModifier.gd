## PositionValueModifier - Adjusts evaluation based on positional market value
##
## Applies market value as an ADDITIVE bonus in OVR points.
## This represents the general scarcity/value of a position in the NFL.
##
## Conversion from old multiplicative values:
## - Old 1.55x QB  -> +5 OVR (quarterback premium)
## - Old 1.20x EDGE -> +2 OVR (pass rusher premium)
## - Old 1.05x WR  -> +0.5 OVR (slight bump)
## - Old 0.98x RB  -> 0 OVR (neutral, RBs are replaceable)
## - Old 0.60x K/P -> -5 OVR (specialists devalued)
##
## The conversion formula was: bonus = (multiplier - 1.0) * 10, then rounded
## This keeps bonuses modest (+/- 5 OVR max) so player quality dominates.
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

## Additive position value bonuses (in OVR points)
## These replace the old multiplicative values from config
## Positive = more valuable position, Negative = less valuable
const POSITION_VALUE_BONUSES := {
	"QB": 5.0,    # Quarterback premium - most important position
	"EDGE": 2.0,  # Pass rushers are premium
	"OL": 1.0,    # Offensive line premium
	"CB": 0.5,    # Cornerbacks slightly premium
	"WR": 0.5,    # Wide receivers slightly premium
	"DL": 0.5,    # Interior D-line slightly premium
	"LB": 0.0,    # Linebackers neutral
	"TE": 0.0,    # Tight ends neutral
	"RB": 0.0,    # Running backs neutral (replaceable)
	"S": 0.0,     # Safeties neutral
	"K": -5.0,    # Kickers significantly devalued
	"P": -5.0,    # Punters significantly devalued
}


func get_id() -> String:
	return "position_value"


func get_display_name() -> String:
	return "Position Market Value"


func get_description() -> String:
	return "Adjusts evaluation based on position's market value (additive OVR bonus)"


func get_priority() -> int:
	return 20


## Bounds for additive bonus: -5 to +5 OVR points
func get_bounds() -> Dictionary:
	return {"min": -5.0, "max": 5.0}


func get_tags() -> Array:
	return ["position", "market", "value", "additive"]


func is_applicable(ctx: EvaluationContext) -> bool:
	return not ctx.position.is_empty()


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var position := ctx.position

	# Get additive bonus from constant map
	var bonus := float(POSITION_VALUE_BONUSES.get(position, 0.0))

	var reason := ""
	if bonus >= 2.0:
		reason = "%s has high market value (+%.1f OVR)" % [position, bonus]
	elif bonus >= 0.5:
		reason = "%s has above-average market value (+%.1f OVR)" % [position, bonus]
	elif bonus <= -2.0:
		reason = "%s has low market value (%.1f OVR)" % [position, bonus]
	else:
		reason = "Standard market value"

	# Return additive modifier result
	return ModifierResult.create_additive(bonus, reason, {
		"position": position,
		"bonus_ovr": bonus
	})
