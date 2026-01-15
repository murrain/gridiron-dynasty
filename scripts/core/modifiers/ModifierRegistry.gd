## ModifierRegistry - Central registry for all game modifiers
##
## Manages global modifiers and entity-attached modifiers.
## Provides querying, filtering, and application utilities.
##
## Usage:
##   # Register global modifier (affects all entities)
##   ModifierRegistry.register_global(SchemeFitModifier.new())
##
##   # Attach modifier to specific entity
##   ModifierRegistry.attach("player", player_id, InjuryModifier.new())
##
##   # Query modifiers for evaluation
##   var result := ModifierRegistry.evaluate(
##       Modifier.Target.TEAM_EVALUATION,
##       Modifier.Context.DRAFT,
##       context_data
##   )
##   final_score = base_score * result.multiplier + result.flat_bonus
extends RefCounted
class_name ModifierRegistry

const Modifier = preload("res://scripts/core/modifiers/Modifier.gd")

## Global modifiers that apply to all entities
var _global_modifiers: Array = []

## Entity-attached modifiers: {entity_type: {entity_id: [modifiers]}}
var _entity_modifiers: Dictionary = {}

## Modifier configuration (enable/disable, parameters)
var _config: Dictionary = {}

## Verbose logging
var _verbose: bool = false


## Combined result of applying multiple modifiers
class CombinedResult:
	var multiplier: float = 1.0
	var flat_bonus: float = 0.0
	var applied: Array = []  # [{id, name, mult, flat, reason}]
	var skipped: Array = []  # [{id, reason}]

	## Apply all modifiers to a value
	func apply_to(value: float) -> float:
		return (value * multiplier) + flat_bonus

	## Get human-readable summary
	func get_summary() -> String:
		var active: Array = []
		for mod in applied:
			var m: Dictionary = mod
			var mult := float(m.get("multiplier", 1.0))
			var flat := float(m.get("flat_bonus", 0.0))
			if abs(mult - 1.0) >= 0.001 or abs(flat) >= 0.001:
				var parts: Array = []
				if abs(mult - 1.0) >= 0.001:
					parts.append("×%.2f" % mult)
				if abs(flat) >= 0.001:
					parts.append("%+.1f" % flat)
				active.append("%s(%s)" % [m.get("id", "?"), "".join(parts)])
		if active.is_empty():
			return "No active modifiers"
		return ", ".join(active)


# =============================================================================
# REGISTRATION
# =============================================================================

## Register a global modifier (applies to all entities)
func register_global(modifier: Modifier) -> void:
	_global_modifiers.append(modifier)
	_sort_global_by_priority()


## Register multiple global modifiers
func register_global_all(modifiers: Array) -> void:
	for mod in modifiers:
		if mod is Modifier:
			_global_modifiers.append(mod)
	_sort_global_by_priority()


## Unregister a global modifier by ID
func unregister_global(modifier_id: String) -> bool:
	for i in range(_global_modifiers.size() - 1, -1, -1):
		var mod: Modifier = _global_modifiers[i]
		if mod.get_id() == modifier_id:
			_global_modifiers.remove_at(i)
			return true
	return false


## Attach a modifier to a specific entity
func attach(entity_type: String, entity_id: String, modifier: Modifier) -> void:
	if not _entity_modifiers.has(entity_type):
		_entity_modifiers[entity_type] = {}

	var type_mods: Dictionary = _entity_modifiers[entity_type]
	if not type_mods.has(entity_id):
		type_mods[entity_id] = []

	(type_mods[entity_id] as Array).append(modifier)
	modifier.on_attach(entity_id, entity_type)
	_sort_entity_by_priority(entity_type, entity_id)


## Detach a modifier from an entity by ID
func detach(entity_type: String, entity_id: String, modifier_id: String) -> bool:
	if not _entity_modifiers.has(entity_type):
		return false

	var type_mods: Dictionary = _entity_modifiers[entity_type]
	if not type_mods.has(entity_id):
		return false

	var mods: Array = type_mods[entity_id]
	for i in range(mods.size() - 1, -1, -1):
		var mod: Modifier = mods[i]
		if mod.get_id() == modifier_id:
			mod.on_detach(entity_id, entity_type)
			mods.remove_at(i)
			return true
	return false


## Detach all modifiers from an entity
func detach_all(entity_type: String, entity_id: String) -> void:
	if not _entity_modifiers.has(entity_type):
		return

	var type_mods: Dictionary = _entity_modifiers[entity_type]
	if not type_mods.has(entity_id):
		return

	var mods: Array = type_mods[entity_id]
	for mod in mods:
		(mod as Modifier).on_detach(entity_id, entity_type)
	type_mods.erase(entity_id)


## Convenience: Attach to player
func attach_to_player(player_id: String, modifier: Modifier) -> void:
	attach("player", player_id, modifier)


## Convenience: Attach to team
func attach_to_team(team_id: String, modifier: Modifier) -> void:
	attach("team", team_id, modifier)


# =============================================================================
# QUERYING
# =============================================================================

## Get all modifiers for a target/context combination
## entity_type/entity_id are optional for entity-specific queries
func get_modifiers(
	target: Modifier.Target,
	context: Modifier.Context,
	entity_type: String = "",
	entity_id: String = ""
) -> Array:
	var result: Array = []

	# Global modifiers
	for mod in _global_modifiers:
		var m: Modifier = mod
		if m.get_target() == target and m.applies_to_context(context):
			if m.is_active() and _is_modifier_enabled(m.get_id()):
				result.append(m)

	# Entity-specific modifiers
	if entity_type != "" and entity_id != "":
		var entity_mods := _get_entity_modifiers(entity_type, entity_id)
		for mod in entity_mods:
			var m: Modifier = mod
			if m.get_target() == target and m.applies_to_context(context):
				if m.is_active() and _is_modifier_enabled(m.get_id()):
					result.append(m)

	return result


## Get all modifiers attached to an entity
func get_entity_modifiers(entity_type: String, entity_id: String) -> Array:
	return _get_entity_modifiers(entity_type, entity_id).duplicate()


## Get all global modifiers
func get_global_modifiers() -> Array:
	return _global_modifiers.duplicate()


## Get modifiers by tag
func get_modifiers_by_tag(tag: String) -> Array:
	var result: Array = []

	for mod in _global_modifiers:
		var m: Modifier = mod
		if m.has_tag(tag):
			result.append(m)

	for entity_type in _entity_modifiers.keys():
		var type_mods: Dictionary = _entity_modifiers[entity_type]
		for entity_id in type_mods.keys():
			var mods: Array = type_mods[entity_id]
			for mod in mods:
				var m: Modifier = mod
				if m.has_tag(tag):
					result.append(m)

	return result


# =============================================================================
# EVALUATION
# =============================================================================

## Evaluate all applicable modifiers and return combined result
func evaluate(
	target: Modifier.Target,
	context: Modifier.Context,
	context_data: Dictionary,
	entity_type: String = "",
	entity_id: String = ""
) -> CombinedResult:
	var result := CombinedResult.new()

	var modifiers := get_modifiers(target, context, entity_type, entity_id)

	for mod in modifiers:
		var m: Modifier = mod

		# Check applicability
		if not m.is_applicable(context_data):
			result.skipped.append({
				"id": m.get_id(),
				"reason": "not_applicable"
			})
			continue

		# Calculate effect
		var mod_result: Modifier.ModifierResult = m.calculate(context_data)

		# Apply multiplicatively for multipliers, additively for flat bonuses
		result.multiplier *= mod_result.multiplier
		result.flat_bonus += mod_result.flat_bonus

		result.applied.append({
			"id": m.get_id(),
			"name": m.get_display_name(),
			"multiplier": mod_result.multiplier,
			"flat_bonus": mod_result.flat_bonus,
			"reason": mod_result.reason,
			"details": mod_result.details
		})

	return result


## Convenience: Evaluate and apply to a value in one call
func apply_modifiers(
	value: float,
	target: Modifier.Target,
	context: Modifier.Context,
	context_data: Dictionary,
	entity_type: String = "",
	entity_id: String = ""
) -> float:
	var result := evaluate(target, context, context_data, entity_type, entity_id)
	return result.apply_to(value)


# =============================================================================
# CONFIGURATION
# =============================================================================

## Configure the registry (enable/disable modifiers)
func configure(config: Dictionary) -> void:
	_config = config


## Enable a specific modifier
func enable_modifier(modifier_id: String) -> void:
	if not _config.has(modifier_id):
		_config[modifier_id] = {}
	(_config[modifier_id] as Dictionary)["enabled"] = true


## Disable a specific modifier
func disable_modifier(modifier_id: String) -> void:
	if not _config.has(modifier_id):
		_config[modifier_id] = {}
	(_config[modifier_id] as Dictionary)["enabled"] = false


## Set verbose logging
func set_verbose(verbose: bool) -> void:
	_verbose = verbose


# =============================================================================
# LIFECYCLE
# =============================================================================

## Tick all modifiers (for duration tracking, state updates)
func tick(days_passed: int = 1) -> void:
	# Tick global modifiers
	for mod in _global_modifiers:
		(mod as Modifier).on_tick(days_passed)

	# Tick entity modifiers and remove expired ones
	for entity_type in _entity_modifiers.keys():
		var type_mods: Dictionary = _entity_modifiers[entity_type]
		for entity_id in type_mods.keys():
			var mods: Array = type_mods[entity_id]
			var to_remove: Array = []

			for i in range(mods.size()):
				var mod: Modifier = mods[i]
				mod.on_tick(days_passed)

				# Check for expiration (duration > 0 means temporary)
				var duration := mod.get_duration()
				if duration > 0 and not mod.is_active():
					to_remove.append(i)

			# Remove expired (reverse order)
			for i in range(to_remove.size() - 1, -1, -1):
				var idx: int = to_remove[i]
				var mod: Modifier = mods[idx]
				mod.on_detach(entity_id, entity_type)
				mods.remove_at(idx)


## Clear all modifiers (for testing or reset)
func clear() -> void:
	_global_modifiers.clear()
	_entity_modifiers.clear()


# =============================================================================
# SERIALIZATION
# =============================================================================

## Serialize registry state to dictionary
func to_dict() -> Dictionary:
	var entity_data := {}

	for entity_type in _entity_modifiers.keys():
		entity_data[entity_type] = {}
		var type_mods: Dictionary = _entity_modifiers[entity_type]

		for entity_id in type_mods.keys():
			var mods: Array = type_mods[entity_id]
			var mod_list: Array = []
			for mod in mods:
				mod_list.append((mod as Modifier).to_dict())
			entity_data[entity_type][entity_id] = mod_list

	return {
		"global": _global_modifiers.map(func(m): return (m as Modifier).to_dict()),
		"entity": entity_data,
		"config": _config
	}


## Restore registry state from dictionary
## Note: Requires a factory function to recreate modifier instances
func from_dict(data: Dictionary, modifier_factory: Callable) -> void:
	clear()
	_config = data.get("config", {}) as Dictionary

	# Restore global modifiers
	var global_data: Array = data.get("global", []) as Array
	for mod_data in global_data:
		var mod := modifier_factory.call(mod_data as Dictionary)
		if mod is Modifier:
			_global_modifiers.append(mod)

	# Restore entity modifiers
	var entity_data: Dictionary = data.get("entity", {}) as Dictionary
	for entity_type in entity_data.keys():
		var type_mods: Dictionary = entity_data[entity_type]
		for entity_id in type_mods.keys():
			var mod_list: Array = type_mods[entity_id]
			for mod_data in mod_list:
				var mod := modifier_factory.call(mod_data as Dictionary)
				if mod is Modifier:
					attach(entity_type, entity_id, mod)


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _is_modifier_enabled(modifier_id: String) -> bool:
	var mod_cfg: Dictionary = _config.get(modifier_id, {}) as Dictionary
	return bool(mod_cfg.get("enabled", true))


func _get_entity_modifiers(entity_type: String, entity_id: String) -> Array:
	if not _entity_modifiers.has(entity_type):
		return []
	var type_mods: Dictionary = _entity_modifiers[entity_type]
	if not type_mods.has(entity_id):
		return []
	return type_mods[entity_id] as Array


func _sort_global_by_priority() -> void:
	_global_modifiers.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		return a.get_priority() < b.get_priority()
	)


func _sort_entity_by_priority(entity_type: String, entity_id: String) -> void:
	var mods := _get_entity_modifiers(entity_type, entity_id)
	mods.sort_custom(func(a: Modifier, b: Modifier) -> bool:
		return a.get_priority() < b.get_priority()
	)
