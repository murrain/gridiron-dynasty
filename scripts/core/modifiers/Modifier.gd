## Modifier - Universal base class for all game modifiers
##
## Modifiers can affect anything in the game: player stats, team evaluations,
## contract negotiations, game performance, etc. They're composable and can
## be attached to entities or registered globally.
##
## Inspired by Caves of Qud where items, mutations, and effects all use
## a unified modifier system.
##
## Target Types (what the modifier affects):
##   - player_stats: Individual stat values (speed, strength, etc.)
##   - player_rating: Overall player rating calculation
##   - player_performance: In-game stat generation
##   - team_evaluation: How teams evaluate players (draft/FA/trade)
##   - team_performance: Team-wide game bonuses
##   - contract: Contract value calculations
##
## Context (when the modifier applies):
##   - always: Always active
##   - game: During game simulation
##   - draft: During draft evaluation
##   - free_agency: During FA evaluation
##   - trade: During trade evaluation
##   - offseason: During offseason processing
##
## Usage:
##   # Global modifier (affects all teams)
##   var mod := SchemeFitModifier.new()
##   ModifierRegistry.register_global(mod)
##
##   # Entity modifier (affects specific player)
##   var injury := HandInjuryModifier.new()
##   ModifierRegistry.attach_to_player(player_id, injury)
##
##   # Query and apply modifiers
##   var mods := ModifierRegistry.get_modifiers_for("team_evaluation", "draft", team_id)
##   for mod in mods:
##       score *= mod.calculate(context).multiplier
extends RefCounted
class_name Modifier


## Target types - what the modifier affects
enum Target {
	PLAYER_STATS,      ## Individual stat values
	PLAYER_RATING,     ## Overall rating calculation
	PLAYER_PERFORMANCE,## In-game stat generation
	TEAM_EVALUATION,   ## How teams evaluate players
	TEAM_PERFORMANCE,  ## Team-wide game effects
	CONTRACT,          ## Contract calculations
	DRAFT_POSITION,    ## Draft position value
	MORALE,            ## Player morale
	DEVELOPMENT,       ## Player development rate
}


## Context - when the modifier applies
enum Context {
	ALWAYS,      ## Always active
	GAME,        ## During games
	DRAFT,       ## During draft
	FREE_AGENCY, ## During FA
	TRADE,       ## During trades
	OFFSEASON,   ## During offseason
	PRESEASON,   ## During preseason
}


## Result of calculating a modifier's effect
class ModifierResult:
	var multiplier: float = 1.0
	var flat_bonus: float = 0.0
	var reason: String = ""
	var details: Dictionary = {}

	func _init(
		p_mult: float = 1.0,
		p_flat: float = 0.0,
		p_reason: String = "",
		p_details: Dictionary = {}
	) -> void:
		multiplier = p_mult
		flat_bonus = p_flat
		reason = p_reason
		details = p_details

	## Check if this result has no effect
	func is_neutral() -> bool:
		return abs(multiplier - 1.0) < 0.001 and abs(flat_bonus) < 0.001

	## Apply this result to a value
	func apply_to(value: float) -> float:
		return (value * multiplier) + flat_bonus


# =============================================================================
# MODIFIER PROPERTIES - Override these in subclasses
# =============================================================================

## Unique identifier for this modifier type
func get_id() -> String:
	return "base_modifier"


## Human-readable name
func get_display_name() -> String:
	return "Base Modifier"


## Short description of what this modifier does
func get_description() -> String:
	return "A base modifier with no effect"


## What this modifier affects
func get_target() -> Target:
	return Target.PLAYER_RATING


## When this modifier applies (can return multiple)
func get_contexts() -> Array:
	return [Context.ALWAYS]


## Priority for application order (lower = earlier)
## 0-50: Core mechanics
## 50-100: Standard modifiers
## 100-150: Situational modifiers
## 150+: Late adjustments
func get_priority() -> int:
	return 100


## Tags for filtering and categorization
## Examples: ["scheme", "injury", "personality", "temporary"]
func get_tags() -> Array:
	return []


## Whether this modifier stacks with others of the same type
func is_stackable() -> bool:
	return false


## Duration in game days (0 = permanent)
func get_duration() -> int:
	return 0


## Whether this modifier is currently active
## Can be overridden for conditional modifiers
func is_active() -> bool:
	return true


# =============================================================================
# MODIFIER LOGIC - Override these in subclasses
# =============================================================================

## Check if this modifier applies to the given context
## context_data contains relevant info (player, team, phase, etc.)
func is_applicable(context_data: Dictionary) -> bool:
	return true


## Calculate the modifier's effect
## context_data contains all relevant information
func calculate(context_data: Dictionary) -> ModifierResult:
	return ModifierResult.new()


## Called when modifier is first attached to an entity
func on_attach(entity_id: String, entity_type: String) -> void:
	pass


## Called when modifier is removed from an entity
func on_detach(entity_id: String, entity_type: String) -> void:
	pass


## Called each day/tick to update modifier state
func on_tick(days_passed: int) -> void:
	pass


# =============================================================================
# SERIALIZATION - For save/load
# =============================================================================

## Serialize modifier state to dictionary
func to_dict() -> Dictionary:
	return {
		"id": get_id(),
		"active": is_active(),
	}


## Restore modifier state from dictionary
func from_dict(data: Dictionary) -> void:
	pass


# =============================================================================
# HELPERS
# =============================================================================

## Check if modifier applies to a specific context
func applies_to_context(ctx: Context) -> bool:
	return ctx in get_contexts() or Context.ALWAYS in get_contexts()


## Check if modifier has a specific tag
func has_tag(tag: String) -> bool:
	return tag in get_tags()
