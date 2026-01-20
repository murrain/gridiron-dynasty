extends RefCounted
class_name StagePipeline

## Pure function pipeline for player lifecycle transformations.
## All functions are side-effect-free and deterministic.
##
## CRITICAL: All functions are PURE - they never modify input dictionaries.
## They always return NEW dictionaries with the updated values.
##
## This is the main orchestration layer that composes individual transformation
## functions (age, growth, injury, retirement) into a complete lifecycle step.

const AgeFunctions = preload("res://scripts/core/transformations/AgeFunctions.gd")
const GrowthFunctions = preload("res://scripts/core/transformations/GrowthFunctions.gd")
const InjuryFunctions = preload("res://scripts/core/transformations/InjuryFunctions.gd")
const RetirementFunctions = preload("res://scripts/core/transformations/RetirementFunctions.gd")

# ============================================================================
# PURE FUNCTIONS - Stage Transformations
# ============================================================================

## Advance a single player by one year (pure function).
##
## This is the main entry point for player lifecycle progression. It orchestrates
## all transformations in the correct order:
##   1. Age increment
##   2. Stat development (growth/decline)
##   3. Injury simulation
##   4. Retirement check
##
## RNG consumption pattern:
##   - ~15-20 calls for stat development (one per base stat)
##   - 1 call for injury occurrence roll
##   - 2-4 additional calls if injured (type, severity, recovery)
##   - 1 call for retirement check
##   Total: ~20-30 calls per player per year (deterministic for given seed)
##
## @param player: Player dictionary (unchanged)
## @param context: Development context (program quality, scheme fit, etc.)
## @param configs: Configuration dictionaries (development, positions, stats, etc.)
## @param rng: RandomNumberGenerator instance (state advanced by ~20-30 calls)
## @return: Dictionary with {player: Dictionary, retired: bool, report: Dictionary}
##
## Algorithm:
##   1. Create immutable copy of player
##   2. Increment age by 1 year
##   3. Apply stat development (growth/prime/decline)
##   4. Apply injury simulation
##   5. Check retirement eligibility
##   6. Return new state (original player unchanged!)
##
## Example:
##   var result := StagePipeline.advance_one_year(player, context, configs, rng)
##   assert(player["age"] == 22)  # Original unchanged
##   assert(result.player["age"] == 23)  # New copy modified
##   assert(result.retired == false)
##   print(result.report)  # {"development": {...}, "injury": {...}}
static func advance_one_year(
	player: Dictionary,
	context: Dictionary,
	configs: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Step 1: Create immutable copy (prevents accidental mutation)
	var new_player := _immutable_copy(player)

	# Step 2: Apply age increment
	new_player = AgeFunctions.increment_age(new_player)

	# Step 3: Apply development based on lifecycle stage
	# RNG Calls: ~15-20 (one per base stat)
	var development_result := GrowthFunctions.apply_development(
		new_player,
		context,
		configs,
		rng
	)
	new_player = development_result.player
	var dev_report: Dictionary = development_result.report

	# Step 4: Apply injury simulation
	# RNG Calls: 1 for occurrence, +2-4 if injured
	var injury_result := InjuryFunctions.simulate_injuries(new_player, configs, rng)
	new_player = injury_result.player
	var injury_report: Dictionary = injury_result.report

	# Step 5: Check retirement eligibility
	# RNG Call: 1 for retirement chance
	var should_retire := RetirementFunctions.should_retire(new_player, configs, rng)

	# Step 6: Build comprehensive report
	var report := {
		"development": dev_report,
		"injury": injury_report,
		"age": int(new_player.get("age", 0)),
		"phase": dev_report.get("phase", "unknown")
	}

	# Step 7: Return new state (original player unchanged!)
	return {
		"player": new_player,
		"retired": should_retire,
		"report": report
	}


## Transition a player to a new lifecycle stage (pure function).
##
## This is a simple transformation that updates the player's stage field.
## Validation of valid transitions should be done by the caller (helper layer).
##
## RNG consumption: NONE (deterministic state update)
##
## @param player: Player dictionary (unchanged)
## @param to_stage: Target stage (Player.PlayerStage enum value)
## @return: NEW player dictionary with updated stage
##
## Example:
##   var p2 := StagePipeline.transition_stage(player, Player.PlayerStage.DRAFT_ELIGIBLE)
##   assert(player["stage"] == Player.PlayerStage.COLLEGE)  # Original unchanged
##   assert(p2["stage"] == Player.PlayerStage.DRAFT_ELIGIBLE)  # New copy modified
static func transition_stage(player: Dictionary, to_stage: int) -> Dictionary:
	var new_player := _immutable_copy(player)
	new_player["stage"] = to_stage
	return new_player


## Compose multiple transformation functions into a pipeline (pure function).
##
## This is a functional programming utility that allows chaining transformations.
##
## @param functions: Array of Callable functions to compose
## @return: Callable that applies all functions in sequence
##
## Example:
##   var pipeline := StagePipeline.compose([
##       func(p): return AgeFunctions.increment_age(p),
##       func(p): return GrowthFunctions.apply_development(p, ctx, cfg, rng).player
##   ])
##   var result := pipeline.call(player)
static func compose(functions: Array[Callable]) -> Callable:
	return func(input):
		var result = input
		for fn in functions:
			result = fn.call(result)
		return result


# ============================================================================
# IMMUTABILITY HELPERS - Pure Function Utilities
# ============================================================================

## Create a deep immutable copy of a player dictionary.
##
## This prevents accidental mutation of input by creating a completely
## independent copy of all nested structures.
##
## Uses GDScript's duplicate(true) which performs recursive deep copy
## of all nested dictionaries and arrays.
##
## @param player: Player dictionary to copy
## @return: NEW player dictionary (completely independent)
static func _immutable_copy(player: Dictionary) -> Dictionary:
	# Deep copy entire structure (recursive)
	return player.duplicate(true)


# ============================================================================
# NOTE: Injury and retirement logic delegated to separate modules
# ============================================================================
# - InjuryFunctions.simulate_injuries() handles injury simulation
# - RetirementFunctions.should_retire() handles retirement checks
# This separation ensures better modularity and testability.
