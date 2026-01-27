## EvaluationModifier - Base class for player evaluation modifiers
##
## Each modifier represents a single factor that affects how a team
## evaluates a player. Modifiers are composable and can be added/removed
## from an EvaluationModifierStack.
##
## Inspired by Caves of Qud's item modifier system where each mod is
## a self-contained unit that knows how to apply itself.
##
## To create a new modifier:
##   1. Extend this class
##   2. Override get_id(), get_display_name(), get_description()
##   3. Override is_applicable() to define when modifier applies
##   4. Override calculate() to return the multiplier value
##
## Example:
##   class_name SchemeFitModifier extends EvaluationModifier
##   func get_id() -> String: return "scheme_fit"
##   func calculate(ctx: EvaluationContext) -> ModifierResult:
##       var mult := _calculate_scheme_fit(ctx)
##       return ModifierResult.new(mult, "Player fits %s scheme" % ctx.offensive_scheme)
extends RefCounted
class_name EvaluationModifier


## Result of a modifier calculation
## Contains both the multiplier value and an explanation
## Supports both multiplicative (multiplier) and additive (additive_bonus) modifiers
class ModifierResult:
	var multiplier: float = 1.0
	var additive_bonus: float = 0.0
	var modifier_type: String = "multiplicative"  # "multiplicative" or "additive"
	var reason: String = ""
	var details: Dictionary = {}

	func _init(p_mult: float = 1.0, p_reason: String = "", p_details: Dictionary = {}) -> void:
		multiplier = p_mult
		reason = p_reason
		details = p_details

	func is_neutral() -> bool:
		if modifier_type == "additive":
			return abs(additive_bonus) < 0.001
		return abs(multiplier - 1.0) < 0.001

	## Create an additive modifier result (bonus OVR points)
	static func create_additive(bonus: float, p_reason: String = "", p_details: Dictionary = {}) -> ModifierResult:
		var result := ModifierResult.new(1.0, p_reason, p_details)
		result.additive_bonus = bonus
		result.modifier_type = "additive"
		return result

	## Create a multiplicative modifier result (scaling factor)
	static func create_multiplicative(mult: float, p_reason: String = "", p_details: Dictionary = {}) -> ModifierResult:
		var result := ModifierResult.new(mult, p_reason, p_details)
		result.modifier_type = "multiplicative"
		return result


## Unique identifier for this modifier type
## Used for configuration, logging, and enabling/disabling
func get_id() -> String:
	return "base_modifier"


## Human-readable name for display
func get_display_name() -> String:
	return "Base Modifier"


## Description of what this modifier does
func get_description() -> String:
	return "Base evaluation modifier"


## Priority for application order (lower = earlier)
## Modifiers with same priority are applied in registration order
func get_priority() -> int:
	return 100


## Tags for categorizing modifiers
## Examples: ["scheme", "coach", "roster", "draft_only"]
func get_tags() -> Array:
	return []


## Get the valid bounds for this modifier's multiplier
## Override in subclasses to specify custom ranges
## Returns: Dictionary with "min" and "max" keys
func get_bounds() -> Dictionary:
	return {"min": 0.6, "max": 1.4}


## Whether this modifier should be applied given the context
## Override to add conditions (e.g., draft-only modifiers)
func is_applicable(ctx: EvaluationContext) -> bool:
	return true


## Calculate the modifier value
## Returns a ModifierResult with multiplier and explanation
## Override this in subclasses
func calculate(ctx: EvaluationContext) -> ModifierResult:
	return ModifierResult.new(1.0, "No effect")


## Whether this modifier can be disabled via configuration
func is_configurable() -> bool:
	return true


## Get configuration schema for this modifier
## Used to generate UI or validate config
func get_config_schema() -> Dictionary:
	return {
		"enabled": {"type": "bool", "default": true},
	}
