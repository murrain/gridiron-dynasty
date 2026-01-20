extends RefCounted
class_name PlayerLifecycleStateMachine

## PlayerLifecycleStateMachine - Formal state machine for player lifecycle transitions
##
## Single source of truth for valid player stage transitions and lifecycle management.
## Ensures all transitions follow defined rules and provides clear lifecycle path.
##
## Usage:
##   # Check if transition is valid
##   if PlayerLifecycleStateMachine.can_transition(player.stage, Player.PlayerStage.DRAFT_ELIGIBLE):
##       PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.DRAFT_ELIGIBLE, "pre_draft")
##
##   # Get lifecycle path
##   var path = PlayerLifecycleStateMachine.get_lifecycle_path()
##
##   # Get valid next stages
##   var next_stages = PlayerLifecycleStateMachine.get_valid_next_stages(player.stage)

const Player = preload("res://scripts/core/models/Player.gd")

## Valid stage transitions map
## Each stage maps to array of stages it can transition to
const VALID_TRANSITIONS := {
	Player.PlayerStage.HIGH_SCHOOL: [
		Player.PlayerStage.COLLEGE
	],
	Player.PlayerStage.COLLEGE: [
		Player.PlayerStage.DRAFT_ELIGIBLE,  # Declare for draft
		Player.PlayerStage.COLLEGE           # Stay in college (year-to-year)
	],
	Player.PlayerStage.DRAFT_ELIGIBLE: [
		Player.PlayerStage.NFL_ROOKIE,       # Drafted
		Player.PlayerStage.NFL_FREE_AGENT    # Undrafted free agent
	],
	Player.PlayerStage.NFL_ROOKIE: [
		Player.PlayerStage.NFL_VETERAN,      # Progress after first season
		Player.PlayerStage.NFL_FREE_AGENT,   # Contract expires
		Player.PlayerStage.RETIRED           # Early retirement
	],
	Player.PlayerStage.NFL_VETERAN: [
		Player.PlayerStage.NFL_FREE_AGENT,   # Contract expires
		Player.PlayerStage.RETIRED           # Retirement
	],
	Player.PlayerStage.NFL_FREE_AGENT: [
		Player.PlayerStage.NFL_ROOKIE,       # Signed as rookie (unusual but possible)
		Player.PlayerStage.NFL_VETERAN,      # Signed as veteran
		Player.PlayerStage.RETIRED           # Retirement while unsigned
	],
	Player.PlayerStage.RETIRED: []           # Terminal state - no transitions
}

## Transition phase mapping
## Maps transition types to the phase ID that handles them
## Phase IDs correspond to simulation phases in the world state
const TRANSITION_PHASES := {
	"high_school_to_college": "college_recruiting",
	"college_to_draft_eligible": "pre_draft",
	"draft_eligible_to_nfl_rookie": "nfl_draft",
	"draft_eligible_to_nfl_free_agent": "post_draft_udfa",
	"nfl_rookie_to_nfl_veteran": "nfl_season_end",
	"nfl_veteran_to_nfl_free_agent": "nfl_contract_expiry",
	"nfl_rookie_to_nfl_free_agent": "nfl_contract_expiry",
	"nfl_free_agent_to_nfl_rookie": "free_agency",
	"nfl_free_agent_to_nfl_veteran": "free_agency",
	"nfl_rookie_to_retired": "retirement",
	"nfl_veteran_to_retired": "retirement",
	"nfl_free_agent_to_retired": "retirement",
	"college_to_college": "college_season_end"  # Year-to-year progression
}

## Primary lifecycle path (standard progression)
## Most players follow this path through their career
const PRIMARY_LIFECYCLE_PATH := [
	Player.PlayerStage.HIGH_SCHOOL,
	Player.PlayerStage.COLLEGE,
	Player.PlayerStage.DRAFT_ELIGIBLE,
	Player.PlayerStage.NFL_ROOKIE,
	Player.PlayerStage.NFL_VETERAN,
	Player.PlayerStage.RETIRED
]

## Check if a transition from one stage to another is valid
##
## @param from: Current player stage
## @param to: Desired target stage
## @return bool: True if transition is valid, false otherwise
static func can_transition(from: Player.PlayerStage, to: Player.PlayerStage) -> bool:
	if not VALID_TRANSITIONS.has(from):
		return false

	var valid_next: Array = VALID_TRANSITIONS.get(from, [])
	return to in valid_next

## Transition a player to a new stage with validation
##
## Validates the transition is legal, updates the player's stage,
## and logs the transition. In the future, this will emit DataBus events
## for other systems to react to lifecycle changes.
##
## @param player: Player object to transition
## @param to_stage: Target stage to transition to
## @param phase_id: Phase ID that is triggering this transition (for logging)
## @return bool: True if transition succeeded, false if invalid
static func transition_player(
	player: Player,
	to_stage: Player.PlayerStage,
	phase_id: String
) -> bool:
	if player == null:
		push_error("PlayerLifecycleStateMachine.transition_player: player is null")
		return false

	var from_stage := player.stage

	# Validate transition is legal
	if not can_transition(from_stage, to_stage):
		push_warning("Invalid player lifecycle transition attempted: %s -> %s for player %s (phase: %s)" % [
			_stage_to_string(from_stage),
			_stage_to_string(to_stage),
			player.get_full_name(),
			phase_id
		])
		return false

	# Perform transition
	var old_stage_name := _stage_to_string(from_stage)
	var new_stage_name := _stage_to_string(to_stage)

	player.stage = to_stage

	# Log transition for debugging and audit trail
	print_verbose("Player lifecycle transition: %s (%s) %s -> %s (phase: %s)" % [
		player.get_full_name(),
		player.id,
		old_stage_name,
		new_stage_name,
		phase_id
	])

	# TODO: Emit DataBus signal for other systems to react
	# When DataBus is implemented, emit:
	#   DataBus.emit_signal("player_stage_changed", {
	#       "player_id": player.id,
	#       "from_stage": from_stage,
	#       "to_stage": to_stage,
	#       "phase_id": phase_id,
	#       "timestamp": Time.get_ticks_msec()
	#   })

	return true

## Get the primary lifecycle path as array of stages
##
## Returns the standard progression path most players follow:
## HIGH_SCHOOL -> COLLEGE -> DRAFT_ELIGIBLE -> NFL_ROOKIE -> NFL_VETERAN -> RETIRED
##
## @return Array: Array of PlayerStage values in order
static func get_lifecycle_path() -> Array:
	return PRIMARY_LIFECYCLE_PATH.duplicate()

## Get valid next stages from current stage
##
## @param current: Current player stage
## @return Array: Array of valid next PlayerStage values
static func get_valid_next_stages(current: Player.PlayerStage) -> Array:
	if not VALID_TRANSITIONS.has(current):
		return []

	return VALID_TRANSITIONS.get(current, []).duplicate()

## Get the phase ID that handles a specific transition
##
## @param from_stage: Source stage
## @param to_stage: Target stage
## @return String: Phase ID that handles this transition, or empty string if not found
static func get_transition_phase(from_stage: Player.PlayerStage, to_stage: Player.PlayerStage) -> String:
	var transition_key := "%s_to_%s" % [
		_stage_to_string(from_stage).to_lower(),
		_stage_to_string(to_stage).to_lower()
	]
	return TRANSITION_PHASES.get(transition_key, "")

## Check if a stage is a terminal stage (no valid transitions out)
##
## @param stage: Stage to check
## @return bool: True if stage is terminal (no valid next stages)
static func is_terminal_stage(stage: Player.PlayerStage) -> bool:
	var valid_next := get_valid_next_stages(stage)
	return valid_next.is_empty()

## Get all possible stages a player could reach from current stage
## (including multi-hop paths)
##
## @param current: Current stage
## @param max_depth: Maximum number of transitions to explore (default 10)
## @return Array: Array of reachable PlayerStage values
static func get_reachable_stages(current: Player.PlayerStage, max_depth: int = 10) -> Array:
	var reachable: Dictionary = {}
	var to_explore: Array = [{"stage": current, "depth": 0}]

	while not to_explore.is_empty():
		var item: Dictionary = to_explore.pop_front()
		var stage: Player.PlayerStage = item["stage"]
		var depth: int = item["depth"]

		if depth >= max_depth:
			continue

		var next_stages := get_valid_next_stages(stage)
		for next_stage in next_stages:
			if not reachable.has(next_stage):
				reachable[next_stage] = true
				to_explore.append({"stage": next_stage, "depth": depth + 1})

	return reachable.keys()

## Validate that transition follows expected phase
##
## Checks if the transition is being performed by the expected phase.
## Useful for catching bugs where transitions happen in wrong phase.
##
## @param from_stage: Source stage
## @param to_stage: Target stage
## @param phase_id: Phase ID attempting the transition
## @return bool: True if phase matches expected phase for this transition
static func validate_transition_phase(
	from_stage: Player.PlayerStage,
	to_stage: Player.PlayerStage,
	phase_id: String
) -> bool:
	var expected_phase := get_transition_phase(from_stage, to_stage)
	if expected_phase.is_empty():
		# No expected phase defined - allow any phase
		return true

	if phase_id != expected_phase:
		push_warning("Transition %s -> %s performed by phase '%s' but expected phase '%s'" % [
			_stage_to_string(from_stage),
			_stage_to_string(to_stage),
			phase_id,
			expected_phase
		])
		return false

	return true

## Convert PlayerStage enum to readable string
##
## @param stage: PlayerStage enum value
## @return String: Human-readable stage name
static func _stage_to_string(stage: Player.PlayerStage) -> String:
	match stage:
		Player.PlayerStage.HIGH_SCHOOL:
			return "HIGH_SCHOOL"
		Player.PlayerStage.COLLEGE:
			return "COLLEGE"
		Player.PlayerStage.DRAFT_ELIGIBLE:
			return "DRAFT_ELIGIBLE"
		Player.PlayerStage.NFL_ROOKIE:
			return "NFL_ROOKIE"
		Player.PlayerStage.NFL_VETERAN:
			return "NFL_VETERAN"
		Player.PlayerStage.NFL_FREE_AGENT:
			return "NFL_FREE_AGENT"
		Player.PlayerStage.RETIRED:
			return "RETIRED"
		_:
			return "UNKNOWN"
