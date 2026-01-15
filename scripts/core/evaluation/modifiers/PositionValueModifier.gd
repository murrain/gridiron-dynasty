## PositionValueModifier - Adjusts evaluation based on positional market value
##
## Applies market value multiplier from position configuration.
## This represents the general value of a position in the NFL.
extends "res://scripts/core/evaluation/EvaluationModifier.gd"


func get_id() -> String:
	return "position_value"


func get_display_name() -> String:
	return "Position Market Value"


func get_description() -> String:
	return "Adjusts evaluation based on position's market value"


func get_priority() -> int:
	return 20


func get_bounds() -> Dictionary:
	return {"min": 0.8, "max": 1.2}


func get_tags() -> Array:
	return ["position", "market", "value"]


func is_applicable(ctx: EvaluationContext) -> bool:
	return not ctx.position.is_empty() and not ctx.positions_cfg.is_empty()


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var position := ctx.position
	var positions_cfg: Dictionary = ctx.positions_cfg

	# Get position config
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var value := float(pos_cfg.get("value", 1.0))

	var reason := ""
	if value > 1.05:
		reason = "%s has high market value" % position
	elif value < 0.95:
		reason = "%s has low market value" % position
	else:
		reason = "Standard market value"

	return ModifierResult.new(value, reason, {
		"position": position,
		"value": value
	})
