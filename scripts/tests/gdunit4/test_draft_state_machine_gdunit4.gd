extends GdUnitTestSuite
class_name TestDraftStateMachine

const DraftStateMachine = preload("res://scripts/core/state/DraftStateMachine.gd")

# ============================================================================
# STATE TRANSITION TESTS
# ============================================================================

func test_not_started_valid_transitions() -> void:
	# NOT_STARTED can transition to INITIALIZING
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.INITIALIZING
	)).is_true()


func test_not_started_invalid_transitions() -> void:
	# NOT_STARTED cannot skip to RUNNING
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.RUNNING
	)).is_false()

	# NOT_STARTED cannot skip to COMPLETED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.COMPLETED
	)).is_false()


func test_initializing_valid_transitions() -> void:
	# INITIALIZING can transition to RUNNING
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING
	)).is_true()

	# INITIALIZING can transition back to NOT_STARTED (abort)
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.NOT_STARTED
	)).is_true()


func test_initializing_invalid_transitions() -> void:
	# INITIALIZING cannot skip to COMPLETED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.COMPLETED
	)).is_false()

	# INITIALIZING cannot go to PAUSED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.PAUSED
	)).is_false()


func test_running_valid_transitions() -> void:
	# RUNNING can transition to PAUSED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.PAUSED
	)).is_true()

	# RUNNING can transition to COMPLETED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.COMPLETED
	)).is_true()


func test_running_invalid_transitions() -> void:
	# RUNNING cannot go back to INITIALIZING
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.INITIALIZING
	)).is_false()

	# RUNNING cannot go back to NOT_STARTED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.NOT_STARTED
	)).is_false()


func test_paused_valid_transitions() -> void:
	# PAUSED can transition to RUNNING (resume)
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.RUNNING
	)).is_true()

	# PAUSED can transition to COMPLETED (end early)
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.COMPLETED
	)).is_true()


func test_paused_invalid_transitions() -> void:
	# PAUSED cannot go to INITIALIZING
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.INITIALIZING
	)).is_false()


func test_completed_is_terminal() -> void:
	# COMPLETED has no valid transitions
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.COMPLETED,
		DraftStateMachine.State.NOT_STARTED
	)).is_false()

	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.COMPLETED,
		DraftStateMachine.State.RUNNING
	)).is_false()


# ============================================================================
# GET VALID NEXT STATES TESTS
# ============================================================================

func test_get_valid_next_states_not_started() -> void:
	var next_states = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.NOT_STARTED
	)
	assert_array(next_states).contains([DraftStateMachine.State.INITIALIZING])
	assert_int(next_states.size()).is_equal(1)


func test_get_valid_next_states_initializing() -> void:
	var next_states = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.INITIALIZING
	)
	assert_array(next_states).contains([
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.NOT_STARTED
	])
	assert_int(next_states.size()).is_equal(2)


func test_get_valid_next_states_running() -> void:
	var next_states = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.RUNNING
	)
	assert_array(next_states).contains([
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.COMPLETED
	])
	assert_int(next_states.size()).is_equal(2)


func test_get_valid_next_states_completed() -> void:
	var next_states = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.COMPLETED
	)
	assert_array(next_states).is_empty()


func test_get_valid_next_states_returns_copy() -> void:
	var next_states1 = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.RUNNING
	)
	var next_states2 = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.RUNNING
	)

	# Modify first array
	next_states1.append(DraftStateMachine.State.NOT_STARTED)

	# Second array should be unchanged
	assert_int(next_states2.size()).is_equal(2)


# ============================================================================
# TERMINAL STATE TESTS
# ============================================================================

func test_is_terminal_state() -> void:
	# NOT_STARTED is not terminal
	assert_bool(DraftStateMachine.is_terminal_state(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()

	# RUNNING is not terminal
	assert_bool(DraftStateMachine.is_terminal_state(
		DraftStateMachine.State.RUNNING
	)).is_false()

	# COMPLETED is terminal
	assert_bool(DraftStateMachine.is_terminal_state(
		DraftStateMachine.State.COMPLETED
	)).is_true()


# ============================================================================
# LIFECYCLE PATH TESTS
# ============================================================================

func test_get_lifecycle_path() -> void:
	var path = DraftStateMachine.get_lifecycle_path()
	assert_array(path).contains([
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.COMPLETED
	])
	assert_int(path.size()).is_equal(4)


func test_get_lifecycle_path_returns_copy() -> void:
	var path1 = DraftStateMachine.get_lifecycle_path()
	var path2 = DraftStateMachine.get_lifecycle_path()

	# Modify first array
	path1.append(DraftStateMachine.State.PAUSED)

	# Second array should be unchanged
	assert_int(path2.size()).is_equal(4)


# ============================================================================
# OPERATION VALIDATION TESTS
# ============================================================================

func test_can_perform_operation_not_started() -> void:
	# Can initialize from NOT_STARTED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.NOT_STARTED,
		"initialize"
	)).is_true()

	# Cannot execute pick from NOT_STARTED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.NOT_STARTED,
		"execute_pick"
	)).is_false()


func test_can_perform_operation_initializing() -> void:
	# Can allocate picks during INITIALIZING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.INITIALIZING,
		"allocate_picks"
	)).is_true()

	# Can generate scouting during INITIALIZING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.INITIALIZING,
		"generate_scouting"
	)).is_true()

	# Cannot execute pick during INITIALIZING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.INITIALIZING,
		"execute_pick"
	)).is_false()


func test_can_perform_operation_running() -> void:
	# Can execute pick during RUNNING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.RUNNING,
		"execute_pick"
	)).is_true()

	# Can pause during RUNNING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.RUNNING,
		"pause"
	)).is_true()

	# Can complete during RUNNING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.RUNNING,
		"complete"
	)).is_true()

	# Cannot initialize during RUNNING
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.RUNNING,
		"initialize"
	)).is_false()


func test_can_perform_operation_paused() -> void:
	# Can resume from PAUSED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.PAUSED,
		"resume"
	)).is_true()

	# Can complete from PAUSED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.PAUSED,
		"complete"
	)).is_true()

	# Cannot execute pick while PAUSED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.PAUSED,
		"execute_pick"
	)).is_false()


func test_can_perform_operation_completed() -> void:
	# Can record history after COMPLETED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.COMPLETED,
		"record_history"
	)).is_true()

	# Can cleanup after COMPLETED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.COMPLETED,
		"cleanup"
	)).is_true()

	# Cannot execute pick after COMPLETED
	assert_bool(DraftStateMachine.can_perform_operation(
		DraftStateMachine.State.COMPLETED,
		"execute_pick"
	)).is_false()


# ============================================================================
# CONVENIENCE METHOD TESTS
# ============================================================================

func test_can_execute_pick() -> void:
	# Can execute pick only during RUNNING
	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()

	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.PAUSED
	)).is_false()


func test_can_initialize() -> void:
	# Can initialize only from NOT_STARTED
	assert_bool(DraftStateMachine.can_initialize(
		DraftStateMachine.State.NOT_STARTED
	)).is_true()

	assert_bool(DraftStateMachine.can_initialize(
		DraftStateMachine.State.RUNNING
	)).is_false()


func test_can_pause() -> void:
	# Can pause only during RUNNING
	assert_bool(DraftStateMachine.can_pause(
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.can_pause(
		DraftStateMachine.State.PAUSED
	)).is_false()

	assert_bool(DraftStateMachine.can_pause(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()


func test_can_resume() -> void:
	# Can resume only from PAUSED
	assert_bool(DraftStateMachine.can_resume(
		DraftStateMachine.State.PAUSED
	)).is_true()

	assert_bool(DraftStateMachine.can_resume(
		DraftStateMachine.State.RUNNING
	)).is_false()


func test_can_complete() -> void:
	# Can complete from RUNNING or PAUSED
	assert_bool(DraftStateMachine.can_complete(
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.can_complete(
		DraftStateMachine.State.PAUSED
	)).is_true()

	assert_bool(DraftStateMachine.can_complete(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()


# ============================================================================
# TRANSITION EXECUTION TESTS
# ============================================================================

func test_transition_state_success() -> void:
	var draft_state := {
		"state": DraftStateMachine.State.NOT_STARTED
	}

	var success := DraftStateMachine.transition_state(
		draft_state,
		DraftStateMachine.State.INITIALIZING,
		"starting initialization"
	)

	assert_bool(success).is_true()
	assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.INITIALIZING)


func test_transition_state_invalid_transition() -> void:
	var draft_state := {
		"state": DraftStateMachine.State.NOT_STARTED
	}

	var success := DraftStateMachine.transition_state(
		draft_state,
		DraftStateMachine.State.RUNNING,  # Invalid: must go through INITIALIZING
		"trying to skip initialization"
	)

	assert_bool(success).is_false()
	# State should remain unchanged
	assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.NOT_STARTED)


func test_transition_state_null_draft_state() -> void:
	var success := DraftStateMachine.transition_state(
		{},  # Empty dict
		DraftStateMachine.State.INITIALIZING,
		"testing empty state"
	)

	assert_bool(success).is_false()


func test_validate_operation_allowed() -> void:
	var valid := DraftStateMachine.validate_operation(
		DraftStateMachine.State.RUNNING,
		"execute_pick"
	)
	assert_bool(valid).is_true()


func test_validate_operation_not_allowed() -> void:
	var valid := DraftStateMachine.validate_operation(
		DraftStateMachine.State.PAUSED,
		"execute_pick"
	)
	assert_bool(valid).is_false()


# ============================================================================
# STATE INFORMATION QUERIES
# ============================================================================

func test_get_allowed_operations() -> void:
	var ops = DraftStateMachine.get_allowed_operations(
		DraftStateMachine.State.RUNNING
	)
	assert_array(ops).contains(["execute_pick", "pause", "complete"])
	assert_int(ops.size()).is_equal(3)


func test_get_allowed_operations_returns_copy() -> void:
	var ops1 = DraftStateMachine.get_allowed_operations(
		DraftStateMachine.State.RUNNING
	)
	var ops2 = DraftStateMachine.get_allowed_operations(
		DraftStateMachine.State.RUNNING
	)

	# Modify first array
	ops1.append("invalid_op")

	# Second array should be unchanged
	assert_int(ops2.size()).is_equal(3)


func test_get_reachable_states_from_not_started() -> void:
	var reachable = DraftStateMachine.get_reachable_states(
		DraftStateMachine.State.NOT_STARTED
	)

	# From NOT_STARTED, all states are reachable
	assert_array(reachable).contains([
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.COMPLETED
	])


func test_get_reachable_states_from_completed() -> void:
	var reachable = DraftStateMachine.get_reachable_states(
		DraftStateMachine.State.COMPLETED
	)

	# From COMPLETED (terminal), no states are reachable
	assert_array(reachable).is_empty()


func test_is_active_state() -> void:
	# RUNNING is active
	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.RUNNING
	)).is_true()

	# PAUSED is active
	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.PAUSED
	)).is_true()

	# NOT_STARTED is not active
	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()

	# COMPLETED is not active
	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.COMPLETED
	)).is_false()


func test_is_completed_state() -> void:
	# Only COMPLETED returns true
	assert_bool(DraftStateMachine.is_completed_state(
		DraftStateMachine.State.COMPLETED
	)).is_true()

	assert_bool(DraftStateMachine.is_completed_state(
		DraftStateMachine.State.RUNNING
	)).is_false()

	assert_bool(DraftStateMachine.is_completed_state(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()


# ============================================================================
# STRING CONVERSION TESTS
# ============================================================================

func test_state_to_string() -> void:
	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.NOT_STARTED
	)).is_equal("NOT_STARTED")

	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.INITIALIZING
	)).is_equal("INITIALIZING")

	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.RUNNING
	)).is_equal("RUNNING")

	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.PAUSED
	)).is_equal("PAUSED")

	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.COMPLETED
	)).is_equal("COMPLETED")


func test_string_to_state() -> void:
	assert_int(DraftStateMachine.string_to_state("NOT_STARTED")).is_equal(
		DraftStateMachine.State.NOT_STARTED
	)

	assert_int(DraftStateMachine.string_to_state("RUNNING")).is_equal(
		DraftStateMachine.State.RUNNING
	)

	assert_int(DraftStateMachine.string_to_state("COMPLETED")).is_equal(
		DraftStateMachine.State.COMPLETED
	)


func test_string_to_state_case_insensitive() -> void:
	assert_int(DraftStateMachine.string_to_state("running")).is_equal(
		DraftStateMachine.State.RUNNING
	)

	assert_int(DraftStateMachine.string_to_state("Paused")).is_equal(
		DraftStateMachine.State.PAUSED
	)


func test_string_to_state_unknown_defaults_to_not_started() -> void:
	assert_int(DraftStateMachine.string_to_state("INVALID")).is_equal(
		DraftStateMachine.State.NOT_STARTED
	)

	assert_int(DraftStateMachine.string_to_state("")).is_equal(
		DraftStateMachine.State.NOT_STARTED
	)


func test_state_string_round_trip() -> void:
	var states := [
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.COMPLETED
	]

	for state in states:
		var state_str := DraftStateMachine._state_to_string(state)
		var state_back := DraftStateMachine.string_to_state(state_str)
		assert_int(state_back).is_equal(state)
