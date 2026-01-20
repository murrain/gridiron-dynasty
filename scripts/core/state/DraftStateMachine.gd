extends RefCounted
class_name DraftStateMachine

## DraftStateMachine - Formal state machine for draft lifecycle transitions
##
## Single source of truth for valid draft state transitions and lifecycle management.
## Ensures all transitions follow defined rules and provides clear lifecycle path.
##
## Usage:
##   # Check if transition is valid
##   if DraftStateMachine.can_transition(current_state, DraftStateMachine.State.RUNNING):
##       DraftStateMachine.transition_state(draft_state, DraftStateMachine.State.RUNNING)
##
##   # Get valid next states
##   var next_states = DraftStateMachine.get_valid_next_states(current_state)
##
##   # Validate operation for current state
##   if DraftStateMachine.can_execute_pick(draft_state["state"]):
##       # Execute pick...

## Draft lifecycle states
enum State {
	NOT_STARTED,    ## Draft has not been initialized (no picks allocated)
	INITIALIZING,   ## Draft is being set up (allocating picks, generating scouting)
	RUNNING,        ## Draft is actively in progress (picks being made)
	PAUSED,         ## Draft is temporarily paused (can be resumed)
	COMPLETED       ## Draft has finished (all picks made or exhausted)
}

## Valid state transitions map
## Each state maps to array of states it can transition to
const VALID_TRANSITIONS := {
	State.NOT_STARTED: [
		State.INITIALIZING
	],
	State.INITIALIZING: [
		State.RUNNING,       # Start draft after initialization
		State.NOT_STARTED    # Abort initialization (reset)
	],
	State.RUNNING: [
		State.PAUSED,        # Pause draft mid-execution
		State.COMPLETED      # Finish draft normally
	],
	State.PAUSED: [
		State.RUNNING,       # Resume draft
		State.COMPLETED      # End draft early while paused
	],
	State.COMPLETED: []      # Terminal state - no transitions
}

## Operations allowed in each state
## Maps state to allowed operations
const ALLOWED_OPERATIONS := {
	State.NOT_STARTED: ["initialize"],
	State.INITIALIZING: ["allocate_picks", "generate_scouting"],
	State.RUNNING: ["execute_pick", "pause", "complete"],
	State.PAUSED: ["resume", "complete"],
	State.COMPLETED: ["record_history", "cleanup"]
}

## Primary lifecycle path (standard progression)
const PRIMARY_LIFECYCLE_PATH := [
	State.NOT_STARTED,
	State.INITIALIZING,
	State.RUNNING,
	State.COMPLETED
]

# ============================================================================
# TRANSITION VALIDATION
# ============================================================================

## Check if a transition from one state to another is valid
##
## @param from: Current draft state
## @param to: Desired target state
## @return bool: True if transition is valid, false otherwise
static func can_transition(from: State, to: State) -> bool:
	if not VALID_TRANSITIONS.has(from):
		return false

	var valid_next: Array = VALID_TRANSITIONS.get(from, [])
	return to in valid_next


## Get valid next states from current state
##
## @param current: Current draft state
## @return Array: Array of valid next State values
static func get_valid_next_states(current: State) -> Array:
	if not VALID_TRANSITIONS.has(current):
		return []

	return VALID_TRANSITIONS.get(current, []).duplicate()


## Check if a state is a terminal state (no valid transitions out)
##
## @param state: State to check
## @return bool: True if state is terminal (no valid next states)
static func is_terminal_state(state: State) -> bool:
	var valid_next := get_valid_next_states(state)
	return valid_next.is_empty()


## Get the primary lifecycle path as array of states
##
## Returns the standard progression path most drafts follow:
## NOT_STARTED -> INITIALIZING -> RUNNING -> COMPLETED
##
## @return Array: Array of State values in order
static func get_lifecycle_path() -> Array:
	return PRIMARY_LIFECYCLE_PATH.duplicate()


# ============================================================================
# OPERATION VALIDATION
# ============================================================================

## Check if an operation is allowed in the current state
##
## @param current_state: Current draft state
## @param operation: Operation to validate (e.g., "execute_pick", "pause")
## @return bool: True if operation is allowed, false otherwise
static func can_perform_operation(current_state: State, operation: String) -> bool:
	if not ALLOWED_OPERATIONS.has(current_state):
		return false

	var allowed: Array = ALLOWED_OPERATIONS.get(current_state, [])
	return operation in allowed


## Check if draft can execute a pick (convenience method)
##
## @param current_state: Current draft state
## @return bool: True if picks can be executed
static func can_execute_pick(current_state: State) -> bool:
	return can_perform_operation(current_state, "execute_pick")


## Check if draft can be initialized (convenience method)
##
## @param current_state: Current draft state
## @return bool: True if draft can be initialized
static func can_initialize(current_state: State) -> bool:
	return can_perform_operation(current_state, "initialize")


## Check if draft can be paused (convenience method)
##
## @param current_state: Current draft state
## @return bool: True if draft can be paused
static func can_pause(current_state: State) -> bool:
	return can_perform_operation(current_state, "pause")


## Check if draft can be resumed (convenience method)
##
## @param current_state: Current draft state
## @return bool: True if draft can be resumed
static func can_resume(current_state: State) -> bool:
	return can_perform_operation(current_state, "resume")


## Check if draft can be completed (convenience method)
##
## @param current_state: Current draft state
## @return bool: True if draft can be completed
static func can_complete(current_state: State) -> bool:
	return can_perform_operation(current_state, "complete")


# ============================================================================
# STATE TRANSITION EXECUTION
# ============================================================================

## Transition draft state to a new state with validation
##
## Validates the transition is legal, updates the state field,
## and logs the transition for audit trail.
##
## @param draft_state: Draft state dictionary to modify (contains "state" field)
## @param to_state: Target state to transition to
## @param reason: Reason for transition (for logging)
## @return bool: True if transition succeeded, false if invalid
static func transition_state(
	draft_state: Dictionary,
	to_state: State,
	reason: String = ""
) -> bool:
	if draft_state == null or draft_state.is_empty():
		push_error("DraftStateMachine.transition_state: draft_state is null or empty")
		return false

	var from_state: State = int(draft_state.get("state", State.NOT_STARTED))

	# Validate transition is legal
	if not can_transition(from_state, to_state):
		push_warning("Invalid draft state transition attempted: %s -> %s (reason: %s)" % [
			_state_to_string(from_state),
			_state_to_string(to_state),
			reason
		])
		return false

	# Perform transition
	var old_state_name := _state_to_string(from_state)
	var new_state_name := _state_to_string(to_state)

	draft_state["state"] = to_state

	# Log transition for debugging and audit trail
	print_verbose("Draft state transition: %s -> %s (reason: %s)" % [
		old_state_name,
		new_state_name,
		reason
	])

	return true


## Validate that operation is allowed in current state
##
## Checks if the operation can be performed in the current state.
## Useful for catching bugs where operations happen in wrong state.
##
## @param current_state: Current draft state
## @param operation: Operation being attempted
## @return bool: True if operation is allowed
static func validate_operation(
	current_state: State,
	operation: String
) -> bool:
	if not can_perform_operation(current_state, operation):
		push_warning("Operation '%s' attempted in state '%s' but not allowed" % [
			operation,
			_state_to_string(current_state)
		])
		return false

	return true


# ============================================================================
# STATE INFORMATION QUERIES
# ============================================================================

## Get all operations allowed in a state
##
## @param state: State to query
## @return Array: Array of allowed operation strings
static func get_allowed_operations(state: State) -> Array:
	if not ALLOWED_OPERATIONS.has(state):
		return []

	return ALLOWED_OPERATIONS.get(state, []).duplicate()


## Get all possible states a draft could reach from current state
## (including multi-hop paths)
##
## @param current: Current state
## @param max_depth: Maximum number of transitions to explore (default 10)
## @return Array: Array of reachable State values
static func get_reachable_states(current: State, max_depth: int = 10) -> Array:
	var reachable: Dictionary = {}
	var to_explore: Array = [{"state": current, "depth": 0}]

	while not to_explore.is_empty():
		var item: Dictionary = to_explore.pop_front()
		var state: State = item["state"]
		var depth: int = item["depth"]

		if depth >= max_depth:
			continue

		var next_states := get_valid_next_states(state)
		for next_state in next_states:
			if not reachable.has(next_state):
				reachable[next_state] = true
				to_explore.append({"state": next_state, "depth": depth + 1})

	return reachable.keys()


## Check if draft is in an active state (can make picks or be resumed)
##
## @param state: State to check
## @return bool: True if draft is active or can be made active
static func is_active_state(state: State) -> bool:
	return state in [State.RUNNING, State.PAUSED]


## Check if draft is in a terminal state (cannot proceed further)
##
## @param state: State to check
## @return bool: True if draft is completed
static func is_completed_state(state: State) -> bool:
	return state == State.COMPLETED


# ============================================================================
# STRING UTILITIES
# ============================================================================

## Convert State enum to readable string
##
## @param state: State enum value
## @return String: Human-readable state name
static func _state_to_string(state: State) -> String:
	match state:
		State.NOT_STARTED:
			return "NOT_STARTED"
		State.INITIALIZING:
			return "INITIALIZING"
		State.RUNNING:
			return "RUNNING"
		State.PAUSED:
			return "PAUSED"
		State.COMPLETED:
			return "COMPLETED"
		_:
			return "UNKNOWN"


## Parse string to State enum (inverse of _state_to_string)
##
## @param state_str: String representation of state
## @return State: Corresponding State enum value, or NOT_STARTED if invalid
static func string_to_state(state_str: String) -> State:
	match state_str.to_upper():
		"NOT_STARTED":
			return State.NOT_STARTED
		"INITIALIZING":
			return State.INITIALIZING
		"RUNNING":
			return State.RUNNING
		"PAUSED":
			return State.PAUSED
		"COMPLETED":
			return State.COMPLETED
		_:
			push_warning("Unknown draft state string: %s" % state_str)
			return State.NOT_STARTED
