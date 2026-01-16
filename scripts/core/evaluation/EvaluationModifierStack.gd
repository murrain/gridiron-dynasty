## EvaluationModifierStack - Manages and applies evaluation modifiers
##
## Collects modifiers and applies them to player evaluations.
## Provides logging, configuration, and extensibility.
##
## Usage:
##   var stack := EvaluationModifierStack.new()
##   stack.register(SchemeFitModifier.new())
##   stack.register(CoachMindsetModifier.new())
##   stack.register(PositionNeedModifier.new())
##
##   var result := stack.evaluate(context)
##   print("Final multiplier: ", result.final_multiplier)
##   print("Applied modifiers: ", result.applied_modifiers)
extends RefCounted
class_name EvaluationModifierStack

const EvaluationModifier = preload("res://scripts/core/evaluation/EvaluationModifier.gd")

## Registered modifiers (sorted by priority after registration)
var _modifiers: Array = []

## Configuration for enabling/disabling modifiers
var _config: Dictionary = {}

## Whether to track detailed modifier applications
var _verbose: bool = false


## Result of applying all modifiers
class StackResult:
	## Final combined multiplier
	var final_multiplier: float = 1.0

	## List of applied modifier results
	## Each entry: {id, name, multiplier, reason, details}
	var applied_modifiers: Array = []

	## List of skipped modifiers (not applicable or disabled)
	var skipped_modifiers: Array = []

	## Summary string for logging
	func get_summary() -> String:
		var parts: Array = []
		for mod in applied_modifiers:
			var m: Dictionary = mod
			if abs(float(m.get("multiplier", 1.0)) - 1.0) >= 0.001:
				parts.append("%s: %.2fx" % [m.get("id", "?"), m.get("multiplier", 1.0)])
		if parts.is_empty():
			return "No modifiers applied"
		return " × ".join(parts) + " = %.2fx" % final_multiplier

	## Get only modifiers that had an effect (multiplier != 1.0)
	func get_active_modifiers() -> Array:
		var active: Array = []
		for mod in applied_modifiers:
			var m: Dictionary = mod
			if abs(float(m.get("multiplier", 1.0)) - 1.0) >= 0.001:
				active.append(m)
		return active


## Register a modifier to be applied during evaluation
func register(modifier: EvaluationModifier) -> void:
	_modifiers.append(modifier)
	_sort_by_priority()


## Register multiple modifiers at once
func register_all(modifiers: Array) -> void:
	for mod in modifiers:
		if mod is EvaluationModifier:
			_modifiers.append(mod)
	_sort_by_priority()


## Unregister a modifier by ID
func unregister(modifier_id: String) -> bool:
	for i in range(_modifiers.size() - 1, -1, -1):
		var mod: EvaluationModifier = _modifiers[i]
		if mod.get_id() == modifier_id:
			_modifiers.remove_at(i)
			return true
	return false


## Get a modifier by ID
func get_modifier(modifier_id: String) -> EvaluationModifier:
	for mod in _modifiers:
		var m: EvaluationModifier = mod
		if m.get_id() == modifier_id:
			return m
	return null


## Get all registered modifiers
func get_modifiers() -> Array:
	return _modifiers.duplicate()


## Get modifiers with a specific tag
func get_modifiers_by_tag(tag: String) -> Array:
	var result: Array = []
	for mod in _modifiers:
		var m: EvaluationModifier = mod
		if tag in m.get_tags():
			result.append(m)
	return result


## Configure the stack (enable/disable modifiers, set parameters)
func configure(config: Dictionary) -> void:
	_config = config


## Set verbose mode for detailed logging
func set_verbose(verbose: bool) -> void:
	_verbose = verbose


## Check if a modifier is enabled
func is_modifier_enabled(modifier_id: String) -> bool:
	var mod_config: Dictionary = _config.get(modifier_id, {}) as Dictionary
	return bool(mod_config.get("enabled", true))


## Apply all applicable modifiers and return combined result
func evaluate(ctx: EvaluationContext) -> StackResult:
	var result := StackResult.new()
	result.final_multiplier = 1.0

	for mod in _modifiers:
		var m: EvaluationModifier = mod
		var mod_id := m.get_id()

		# Check if modifier is enabled
		if not is_modifier_enabled(mod_id):
			result.skipped_modifiers.append({
				"id": mod_id,
				"reason": "disabled"
			})
			continue

		# Check if modifier is applicable
		if not m.is_applicable(ctx):
			result.skipped_modifiers.append({
				"id": mod_id,
				"reason": "not_applicable"
			})
			continue

		# Calculate modifier value
		var mod_result: EvaluationModifier.ModifierResult = m.calculate(ctx)

		# Defensive null check - if calculate() returns null, skip this modifier
		if mod_result == null:
			result.skipped_modifiers.append({
				"id": mod_id,
				"reason": "calculate_returned_null"
			})
			push_warning("EvaluationModifierStack: Modifier '%s' returned null from calculate()" % mod_id)
			continue

		# Apply per-modifier bounds enforcement
		var bounds := m.get_bounds()
		var min_bound := float(bounds.get("min", 0.0))
		var max_bound := float(bounds.get("max", 10.0))
		mod_result.multiplier = clampf(mod_result.multiplier, min_bound, max_bound)

		# Apply multiplier
		result.final_multiplier *= mod_result.multiplier

		# Intermediate clamping checkpoints
		var priority := m.get_priority()
		if priority == 30:
			# After PositionNeedModifier - cap at 2.0x
			result.final_multiplier = minf(result.final_multiplier, 2.0)
		elif priority == 60:
			# After CoachMindsetModifier - cap at 3.0x
			result.final_multiplier = minf(result.final_multiplier, 3.0)

		# Record application
		result.applied_modifiers.append({
			"id": mod_id,
			"name": m.get_display_name(),
			"multiplier": mod_result.multiplier,
			"reason": mod_result.reason,
			"details": mod_result.details
		})

	# Apply cumulative cap - maximum 4.0x total
	result.final_multiplier = minf(result.final_multiplier, 4.0)

	return result


## Apply modifiers and return just the final multiplier (convenience method)
func get_multiplier(ctx: EvaluationContext) -> float:
	return evaluate(ctx).final_multiplier


## Create a new stack with the standard draft modifiers
static func create_draft_stack() -> EvaluationModifierStack:
	var stack := EvaluationModifierStack.new()
	# Modifiers are registered in order, priority sorts them
	stack.register_all(_get_standard_draft_modifiers())
	return stack


## Create a new stack with the standard free agency modifiers
static func create_free_agency_stack() -> EvaluationModifierStack:
	var stack := EvaluationModifierStack.new()
	stack.register_all(_get_standard_fa_modifiers())
	return stack


## Create a new stack with the standard trade modifiers
static func create_trade_stack() -> EvaluationModifierStack:
	var stack := EvaluationModifierStack.new()
	stack.register_all(_get_standard_trade_modifiers())
	return stack


## Get the standard set of draft modifiers
## Override or extend this to customize draft evaluation
static func _get_standard_draft_modifiers() -> Array:
	# Import modifiers - these will be created as separate files
	var mods: Array = []

	# Try to load each modifier if it exists
	var modifier_classes := [
		"res://scripts/core/evaluation/modifiers/PositionTierModifier.gd",
		"res://scripts/core/evaluation/modifiers/PositionValueModifier.gd",
		"res://scripts/core/evaluation/modifiers/PositionNeedModifier.gd",
		"res://scripts/core/evaluation/modifiers/QBUrgencyModifier.gd",
		"res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd",
		"res://scripts/core/evaluation/modifiers/CoachMindsetModifier.gd",
		"res://scripts/core/evaluation/modifiers/RosterMoveModifier.gd",
	]

	for path in modifier_classes:
		if ResourceLoader.exists(path):
			var mod_class = load(path)
			if mod_class:
				mods.append(mod_class.new())

	return mods


## Get the standard set of free agency modifiers
static func _get_standard_fa_modifiers() -> Array:
	var mods: Array = []

	var modifier_classes := [
		"res://scripts/core/evaluation/modifiers/PositionValueModifier.gd",
		"res://scripts/core/evaluation/modifiers/PositionNeedModifier.gd",
		"res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd",
		"res://scripts/core/evaluation/modifiers/CoachMindsetModifier.gd",
	]

	for path in modifier_classes:
		if ResourceLoader.exists(path):
			var mod_class = load(path)
			if mod_class:
				var instance = mod_class.new()
				# Configure for FA context if method exists
				if instance.has_method("configure_for_fa"):
					instance.configure_for_fa()
				mods.append(instance)

	return mods


## Get the standard set of trade modifiers
static func _get_standard_trade_modifiers() -> Array:
	var mods: Array = []

	var modifier_classes := [
		"res://scripts/core/evaluation/modifiers/PositionNeedModifier.gd",
		"res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd",
		"res://scripts/core/evaluation/modifiers/CoachMindsetModifier.gd",
		"res://scripts/core/evaluation/modifiers/RosterMoveModifier.gd",
	]

	for path in modifier_classes:
		if ResourceLoader.exists(path):
			var mod_class = load(path)
			if mod_class:
				mods.append(mod_class.new())

	return mods


## Sort modifiers by priority
func _sort_by_priority() -> void:
	_modifiers.sort_custom(func(a: EvaluationModifier, b: EvaluationModifier) -> bool:
		return a.get_priority() < b.get_priority()
	)
