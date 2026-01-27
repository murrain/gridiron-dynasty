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
## Contains either a multiplier value or an additive bonus, plus an explanation
##
## Modifier Types:
## - MULTIPLICATIVE: Traditional percentage modifier (default). final = base * multiplier
## - ADDITIVE: OVR point bonus/penalty. final = base + additive_bonus
##
## Additive modifiers are applied BEFORE multiplicative modifiers:
##   final_score = (base_ovr + sum(additive)) * product(multiplicative)
##
## This ensures player quality (OVR) dominates over position bonuses while
## still allowing multiplicative factors like scheme fit and coach mindset.
class ModifierResult:
	## Type of modifier effect
	enum ModifierType {
		MULTIPLICATIVE,  ## result *= modifier (default, for scheme fit, coach mindset)
		ADDITIVE         ## result += modifier (for position tier, position value)
	}

	## The multiplier value (used when modifier_type == MULTIPLICATIVE)
	var multiplier: float = 1.0

	## The additive bonus value in OVR points (used when modifier_type == ADDITIVE)
	var additive_bonus: float = 0.0

	## Whether this is an additive or multiplicative modifier
	var modifier_type: ModifierType = ModifierType.MULTIPLICATIVE

	## Human-readable explanation for this modifier effect
	var reason: String = ""

	## Additional metadata about the calculation
	var details: Dictionary = {}

	## Create a multiplicative modifier result (default behavior)
	## @param p_mult: Multiplier value (1.0 = neutral, >1 = boost, <1 = penalty)
	## @param p_reason: Human-readable explanation
	## @param p_details: Additional metadata
	func _init(p_mult: float = 1.0, p_reason: String = "", p_details: Dictionary = {}) -> void:
		multiplier = p_mult
		modifier_type = ModifierType.MULTIPLICATIVE
		additive_bonus = 0.0
		reason = p_reason
		details = p_details

	## Create an additive modifier result
	## @param p_bonus: Additive bonus in OVR points (positive = boost, negative = penalty)
	## @param p_reason: Human-readable explanation
	## @param p_details: Additional metadata
	## @return: A new ModifierResult configured as additive
	static func create_additive(p_bonus: float, p_reason: String = "", p_details: Dictionary = {}) -> ModifierResult:
		var result := ModifierResult.new(1.0, p_reason, p_details)
		result.modifier_type = ModifierType.ADDITIVE
		result.additive_bonus = p_bonus
		result.multiplier = 1.0  # Neutral multiplier for additive modifiers
		return result

	## Check if this modifier has no effect
	## For multiplicative: multiplier ~= 1.0
	## For additive: bonus ~= 0.0
	func is_neutral() -> bool:
		if modifier_type == ModifierType.ADDITIVE:
			return absf(additive_bonus) < 0.001
		return absf(multiplier - 1.0) < 0.001

	## Check if this is an additive modifier
	func is_additive() -> bool:
		return modifier_type == ModifierType.ADDITIVE

	## Get the effective value for display/logging
	## Returns the multiplier for multiplicative, or the bonus for additive
	func get_effective_value() -> float:
		if modifier_type == ModifierType.ADDITIVE:
			return additive_bonus
		return multiplier

	## Get a formatted string representation of the modifier effect
	func get_effect_string() -> String:
		if modifier_type == ModifierType.ADDITIVE:
			if additive_bonus >= 0:
				return "+%.1f OVR" % additive_bonus
			else:
				return "%.1f OVR" % additive_bonus
		else:
			return "%.2fx" % multiplier


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
