extends RefCounted
class_name TransitionFunctions

## Pure functions for stage transitions.
## All functions are side-effect-free and deterministic.
##
## CRITICAL RNG MANAGEMENT:
## - None of these functions consume RNG
## - All transitions are deterministic based on rules and player state
## - No probabilistic logic in stage transitions

# Player lifecycle stages (from Player.gd)
enum PlayerStage {
	HIGH_SCHOOL = 0,
	COLLEGE = 1,
	DRAFT_ELIGIBLE = 2,
	NFL_ROOKIE = 3,
	NFL_VETERAN = 4,
	NFL_FREE_AGENT = 5,
	RETIRED = 6
}

# ============================================================================
# PUBLIC API - Pure Transition Functions
# ============================================================================

## Transition a player to a new lifecycle stage (pure function).
##
## Validates transition against allowed state machine rules.
## Updates stage field and resets years_in_stage counter.
##
## Valid transitions:
##   HIGH_SCHOOL -> COLLEGE
##   COLLEGE -> DRAFT_ELIGIBLE, COLLEGE (repeat year)
##   DRAFT_ELIGIBLE -> NFL_ROOKIE, NFL_FREE_AGENT
##   NFL_ROOKIE -> NFL_VETERAN, NFL_FREE_AGENT, RETIRED
##   NFL_VETERAN -> NFL_FREE_AGENT, RETIRED
##   NFL_FREE_AGENT -> NFL_ROOKIE, NFL_VETERAN, RETIRED
##   RETIRED -> (none - terminal state)
##
## Input: player dict, target stage (int from PlayerStage enum)
## Output: new player dict with updated stage and years_in_stage = 0
##
## Note: Returns input player unchanged if transition is invalid
##       (caller should check return value or use can_transition_to() first)
static func transition_to_stage(
	player: Dictionary,
	to_stage: int
) -> Dictionary:
	var current_stage := int(player.get("stage", 0))

	# Validate transition
	if not _is_valid_transition(current_stage, to_stage):
		push_warning("Invalid stage transition: %d -> %d for player %s" % [
			current_stage,
			to_stage,
			player.get("player_id", "unknown")
		])
		return player  # Return unchanged if invalid

	# Create new player with updated stage
	var new_player := player.duplicate(true)
	new_player["stage"] = to_stage
	new_player["years_in_stage"] = 0  # Reset counter on transition

	return new_player

## Reset years_in_stage counter to 0 (pure function).
##
## Used when a player enters a new stage or when resetting lifecycle tracking.
##
## Input: player dict
## Output: new player dict with years_in_stage = 0
static func reset_years_in_stage(player: Dictionary) -> Dictionary:
	var new_player := player.duplicate(true)
	new_player["years_in_stage"] = 0
	return new_player

## Increment years_in_stage counter by 1 (pure function).
##
## Used during annual lifecycle advancement to track time in current stage.
##
## Input: player dict
## Output: new player dict with years_in_stage incremented
static func increment_years_in_stage(player: Dictionary) -> Dictionary:
	var new_player := player.duplicate(true)
	var current_years := int(new_player.get("years_in_stage", 0))
	new_player["years_in_stage"] = current_years + 1
	return new_player

## Check if a player can declare for the NFL draft (pure function).
##
## Rules for draft eligibility:
##   1. Player must be in COLLEGE stage
##   2. Player must be at least 3 years removed from high school (class_year >= 3)
##      OR be an underclassman willing to declare early (class_year < 4)
##   3. Player must not already be declared (declared_for_draft == false)
##
## Input: player dict, configs dict
## Output: bool (true if player can declare)
##
## No RNG consumption - deterministic rule check.
static func can_declare_for_draft(
	player: Dictionary,
	configs: Dictionary
) -> bool:
	var stage := int(player.get("stage", 0))
	var class_year := int(player.get("class_year", 4))
	var already_declared := bool(player.get("declared_for_draft", false))

	# Must be in college
	if stage != PlayerStage.COLLEGE:
		return false

	# Must not already be declared
	if already_declared:
		return false

	# Must meet class year requirement (3 years removed from HS)
	# Juniors (class_year 3) and Seniors (class_year 4) are automatically eligible
	# Freshmen (1) and Sophomores (2) are not eligible
	var main_cfg := configs.get("main", {}) as Dictionary
	var draft_cfg: Dictionary = main_cfg.get("draft_eligibility", {}) as Dictionary
	var min_class_year := int(draft_cfg.get("min_class_year", 3))

	return class_year >= min_class_year

## Apply draft declaration to a player (pure function).
##
## Sets declared_for_draft flag to true and optionally transitions to DRAFT_ELIGIBLE stage.
##
## Input: player dict
## Output: new player dict with declared_for_draft = true
##
## Note: Caller should check can_declare_for_draft() before calling this.
static func apply_draft_declaration(player: Dictionary) -> Dictionary:
	var new_player := player.duplicate(true)
	new_player["declared_for_draft"] = true
	return new_player

## Check if a transition from one stage to another is valid (pure function).
##
## Validates against state machine rules defined in Player.gd.
##
## Input: current stage (int), target stage (int)
## Output: bool (true if transition is valid)
static func can_transition_to(from_stage: int, to_stage: int) -> bool:
	return _is_valid_transition(from_stage, to_stage)

# ============================================================================
# INTERNAL HELPERS - Private Pure Functions
# ============================================================================

## Validate stage transition against state machine rules (pure function).
##
## Defines allowed transitions for each lifecycle stage.
##
## Input: current stage (int), target stage (int)
## Output: bool (true if transition is valid)
static func _is_valid_transition(from_stage: int, to_stage: int) -> bool:
	# Define valid transitions for each stage
	var valid_transitions := {
		PlayerStage.HIGH_SCHOOL: [PlayerStage.COLLEGE],
		PlayerStage.COLLEGE: [PlayerStage.DRAFT_ELIGIBLE, PlayerStage.COLLEGE],
		PlayerStage.DRAFT_ELIGIBLE: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_FREE_AGENT],
		PlayerStage.NFL_ROOKIE: [PlayerStage.NFL_VETERAN, PlayerStage.NFL_FREE_AGENT, PlayerStage.RETIRED],
		PlayerStage.NFL_VETERAN: [PlayerStage.NFL_FREE_AGENT, PlayerStage.RETIRED],
		PlayerStage.NFL_FREE_AGENT: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_VETERAN, PlayerStage.RETIRED],
		PlayerStage.RETIRED: []  # Terminal state - no transitions allowed
	}

	var allowed: Array = valid_transitions.get(from_stage, [])
	return to_stage in allowed
