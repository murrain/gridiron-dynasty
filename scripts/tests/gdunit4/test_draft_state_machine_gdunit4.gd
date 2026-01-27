extends GdUnitTestSuite
class_name TestDraftStateMachineGdUnit4

## Test suite for DraftStateMachine
##
## Validates state transitions, operation validation, and multi-year draft support.
## The key feature tested is the COMPLETED -> NOT_STARTED transition that enables
## year-over-year draft resets.

const DraftStateMachine = preload("res://scripts/core/state/DraftStateMachine.gd")

# ============================================================================
# MULTI-YEAR DRAFT TRANSITION TESTS (Critical Bug Fix)
# ============================================================================

func test_completed_to_not_started_transition_allowed() -> void:
	## Critical test: COMPLETED -> NOT_STARTED must be valid for multi-year drafts
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.COMPLETED,
		DraftStateMachine.State.NOT_STARTED
	)).is_true()


func test_completed_state_is_not_terminal() -> void:
	## COMPLETED is NOT terminal - it can transition to NOT_STARTED for next year
	assert_bool(DraftStateMachine.is_terminal_state(
		DraftStateMachine.State.COMPLETED
	)).is_false()


func test_get_valid_next_states_completed_includes_not_started() -> void:
	## COMPLETED should have NOT_STARTED as a valid next state
	var next_states = DraftStateMachine.get_valid_next_states(
		DraftStateMachine.State.COMPLETED
	)
	assert_array(next_states).contains([DraftStateMachine.State.NOT_STARTED])
	assert_int(next_states.size()).is_equal(1)


func test_multi_year_draft_lifecycle_simulation() -> void:
	## Test complete multi-year draft lifecycle: Year 1 -> Year 2 -> Year 3
	var draft_state := {
		"state": DraftStateMachine.State.NOT_STARTED,
		"year": 2024
	}

	var years_completed := 0

	for year in range(3):
		# Year N: Initialize
		var init_ok := DraftStateMachine.transition_state(
			draft_state,
			DraftStateMachine.State.INITIALIZING,
			"Year %d: initializing draft" % (2024 + year)
		)
		assert_bool(init_ok).is_true()
		assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.INITIALIZING)

		# Year N: Start running
		var run_ok := DraftStateMachine.transition_state(
			draft_state,
			DraftStateMachine.State.RUNNING,
			"Year %d: starting draft" % (2024 + year)
		)
		assert_bool(run_ok).is_true()
		assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.RUNNING)

		# Year N: Complete
		var complete_ok := DraftStateMachine.transition_state(
			draft_state,
			DraftStateMachine.State.COMPLETED,
			"Year %d: draft completed" % (2024 + year)
		)
		assert_bool(complete_ok).is_true()
		assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.COMPLETED)

		years_completed += 1

		# CRITICAL: Reset for next year (except after final year)
		if year < 2:
			var reset_ok := DraftStateMachine.transition_state(
				draft_state,
				DraftStateMachine.State.NOT_STARTED,
				"Year %d: resetting for next year's draft" % (2024 + year)
			)
			assert_bool(reset_ok).is_true()
			assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.NOT_STARTED)

	# Verify all 3 years completed successfully
	assert_int(years_completed).is_equal(3)


func test_transition_state_completed_to_not_started() -> void:
	## Test the actual transition_state method works for year-over-year reset
	var draft_state := {
		"state": DraftStateMachine.State.COMPLETED
	}

	var success := DraftStateMachine.transition_state(
		draft_state,
		DraftStateMachine.State.NOT_STARTED,
		"resetting for new year's draft"
	)

	assert_bool(success).is_true()
	assert_int(draft_state["state"]).is_equal(DraftStateMachine.State.NOT_STARTED)


func test_reachable_states_from_completed_includes_all_via_reset() -> void:
	## From COMPLETED, all states should be reachable via NOT_STARTED reset
	var reachable = DraftStateMachine.get_reachable_states(
		DraftStateMachine.State.COMPLETED
	)

	# All states should be reachable through the reset path
	assert_array(reachable).contains([
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.COMPLETED
	])


# ============================================================================
# BASIC STATE TRANSITION TESTS
# ============================================================================

func test_not_started_valid_transitions() -> void:
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.INITIALIZING
	)).is_true()


func test_not_started_invalid_transitions() -> void:
	# Cannot skip to RUNNING
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.RUNNING
	)).is_false()

	# Cannot skip to COMPLETED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.COMPLETED
	)).is_false()


func test_initializing_valid_transitions() -> void:
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.NOT_STARTED
	)).is_true()


func test_running_valid_transitions() -> void:
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.PAUSED
	)).is_true()

	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.COMPLETED
	)).is_true()


func test_paused_valid_transitions() -> void:
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.PAUSED,
		DraftStateMachine.State.COMPLETED
	)).is_true()


func test_completed_invalid_transitions() -> void:
	# Cannot skip to RUNNING directly
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.COMPLETED,
		DraftStateMachine.State.RUNNING
	)).is_false()

	# Cannot skip to INITIALIZING directly
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.COMPLETED,
		DraftStateMachine.State.INITIALIZING
	)).is_false()

	# Cannot go to PAUSED
	assert_bool(DraftStateMachine.can_transition(
		DraftStateMachine.State.COMPLETED,
		DraftStateMachine.State.PAUSED
	)).is_false()


# ============================================================================
# OPERATION VALIDATION TESTS
# ============================================================================

func test_can_execute_pick_only_in_running() -> void:
	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()

	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.PAUSED
	)).is_false()

	assert_bool(DraftStateMachine.can_execute_pick(
		DraftStateMachine.State.COMPLETED
	)).is_false()


func test_can_initialize_only_from_not_started() -> void:
	assert_bool(DraftStateMachine.can_initialize(
		DraftStateMachine.State.NOT_STARTED
	)).is_true()

	assert_bool(DraftStateMachine.can_initialize(
		DraftStateMachine.State.RUNNING
	)).is_false()

	assert_bool(DraftStateMachine.can_initialize(
		DraftStateMachine.State.COMPLETED
	)).is_false()


# ============================================================================
# STATE INFORMATION QUERIES
# ============================================================================

func test_is_active_state() -> void:
	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.RUNNING
	)).is_true()

	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.PAUSED
	)).is_true()

	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.NOT_STARTED
	)).is_false()

	assert_bool(DraftStateMachine.is_active_state(
		DraftStateMachine.State.COMPLETED
	)).is_false()


func test_is_completed_state() -> void:
	assert_bool(DraftStateMachine.is_completed_state(
		DraftStateMachine.State.COMPLETED
	)).is_true()

	assert_bool(DraftStateMachine.is_completed_state(
		DraftStateMachine.State.RUNNING
	)).is_false()


func test_get_lifecycle_path() -> void:
	var path = DraftStateMachine.get_lifecycle_path()
	assert_array(path).contains([
		DraftStateMachine.State.NOT_STARTED,
		DraftStateMachine.State.INITIALIZING,
		DraftStateMachine.State.RUNNING,
		DraftStateMachine.State.COMPLETED
	])
	assert_int(path.size()).is_equal(4)


# ============================================================================
# STRING CONVERSION TESTS
# ============================================================================

func test_state_to_string() -> void:
	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.NOT_STARTED
	)).is_equal("NOT_STARTED")

	assert_str(DraftStateMachine._state_to_string(
		DraftStateMachine.State.COMPLETED
	)).is_equal("COMPLETED")


func test_string_to_state() -> void:
	assert_int(DraftStateMachine.string_to_state("NOT_STARTED")).is_equal(
		DraftStateMachine.State.NOT_STARTED
	)

	assert_int(DraftStateMachine.string_to_state("COMPLETED")).is_equal(
		DraftStateMachine.State.COMPLETED
	)


func test_string_to_state_case_insensitive() -> void:
	assert_int(DraftStateMachine.string_to_state("running")).is_equal(
		DraftStateMachine.State.RUNNING
	)

	assert_int(DraftStateMachine.string_to_state("Completed")).is_equal(
		DraftStateMachine.State.COMPLETED
	)
