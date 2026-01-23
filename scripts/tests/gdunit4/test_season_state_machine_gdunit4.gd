extends GdUnitTestSuite
class_name TestSeasonStateMachine

const SeasonStateMachine = preload("res://scripts/core/state/SeasonStateMachine.gd")

# ============================================================================
# PHASE TRANSITION TESTS
# ============================================================================

func test_pre_season_transitions() -> void:
	# PRE_SEASON can transition to REGULAR_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)).is_true()

	# PRE_SEASON cannot skip to PLAYOFFS
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_false()


func test_regular_season_transitions() -> void:
	# REGULAR_SEASON can transition to PLAYOFFS
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_true()

	# REGULAR_SEASON can transition to POST_SEASON (if no playoffs)
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_true()

	# REGULAR_SEASON cannot skip to OFF_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_false()


func test_playoffs_transitions() -> void:
	# PLAYOFFS can transition to POST_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.PLAYOFFS,
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_true()

	# PLAYOFFS cannot skip to OFF_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.PLAYOFFS,
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_false()


func test_post_season_transitions() -> void:
	# POST_SEASON can transition to OFF_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.POST_SEASON,
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_true()

	# POST_SEASON cannot skip to DRAFT
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.POST_SEASON,
		SeasonStateMachine.SeasonPhase.DRAFT
	)).is_false()


func test_off_season_transitions() -> void:
	# OFF_SEASON can transition to DRAFT_PREP
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.OFF_SEASON,
		SeasonStateMachine.SeasonPhase.DRAFT_PREP
	)).is_true()

	# OFF_SEASON can transition to FREE_AGENCY (alternate path)
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.OFF_SEASON,
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	)).is_true()


func test_draft_prep_transitions() -> void:
	# DRAFT_PREP can transition to DRAFT
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.DRAFT_PREP,
		SeasonStateMachine.SeasonPhase.DRAFT
	)).is_true()

	# DRAFT_PREP cannot skip to PRE_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.DRAFT_PREP,
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_false()


func test_draft_transitions() -> void:
	# DRAFT can transition to FREE_AGENCY
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.DRAFT,
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	)).is_true()

	# DRAFT can transition to PRE_SEASON (alternate path)
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.DRAFT,
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_true()


func test_free_agency_transitions() -> void:
	# FREE_AGENCY can transition to PRE_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.FREE_AGENCY,
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_true()

	# FREE_AGENCY cannot skip to REGULAR_SEASON
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.FREE_AGENCY,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)).is_false()


# ============================================================================
# GET VALID TRANSITIONS TESTS
# ============================================================================

func test_get_valid_transitions_pre_season() -> void:
	var transitions = SeasonStateMachine.get_valid_transitions(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)
	assert_array(transitions).contains([SeasonStateMachine.SeasonPhase.REGULAR_SEASON])
	assert_int(transitions.size()).is_equal(1)


func test_get_valid_transitions_regular_season() -> void:
	var transitions = SeasonStateMachine.get_valid_transitions(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)
	assert_array(transitions).contains([
		SeasonStateMachine.SeasonPhase.PLAYOFFS,
		SeasonStateMachine.SeasonPhase.POST_SEASON
	])
	assert_int(transitions.size()).is_equal(2)


func test_get_valid_transitions_off_season() -> void:
	var transitions = SeasonStateMachine.get_valid_transitions(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)
	assert_array(transitions).contains([
		SeasonStateMachine.SeasonPhase.DRAFT_PREP,
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	])
	assert_int(transitions.size()).is_equal(2)


func test_get_valid_transitions_returns_copy() -> void:
	var transitions1 = SeasonStateMachine.get_valid_transitions(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)
	var transitions2 = SeasonStateMachine.get_valid_transitions(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)

	# Modify first array
	transitions1.append(SeasonStateMachine.SeasonPhase.PRE_SEASON)

	# Second array should be unchanged
	assert_int(transitions2.size()).is_equal(2)


# ============================================================================
# TERMINAL STATE TESTS
# ============================================================================

func test_no_terminal_phases() -> void:
	# All phases should have valid transitions (cyclical system)
	assert_bool(SeasonStateMachine.is_terminal_phase(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_false()

	assert_bool(SeasonStateMachine.is_terminal_phase(
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	)).is_false()

	assert_bool(SeasonStateMachine.is_terminal_phase(
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_false()


# ============================================================================
# PHASE NAME TESTS
# ============================================================================

func test_get_phase_name() -> void:
	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_equal("PRE_SEASON")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)).is_equal("REGULAR_SEASON")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_equal("PLAYOFFS")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_equal("POST_SEASON")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_equal("OFF_SEASON")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.DRAFT_PREP
	)).is_equal("DRAFT_PREP")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.DRAFT
	)).is_equal("DRAFT")

	assert_str(SeasonStateMachine.get_phase_name(
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	)).is_equal("FREE_AGENCY")


# ============================================================================
# LIFECYCLE PATH TESTS
# ============================================================================

func test_get_standard_lifecycle() -> void:
	var lifecycle = SeasonStateMachine.get_standard_lifecycle()
	assert_array(lifecycle).contains([
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS,
		SeasonStateMachine.SeasonPhase.POST_SEASON,
		SeasonStateMachine.SeasonPhase.OFF_SEASON,
		SeasonStateMachine.SeasonPhase.DRAFT_PREP,
		SeasonStateMachine.SeasonPhase.DRAFT,
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	])
	assert_int(lifecycle.size()).is_equal(8)


func test_get_standard_lifecycle_returns_copy() -> void:
	var lifecycle1 = SeasonStateMachine.get_standard_lifecycle()
	var lifecycle2 = SeasonStateMachine.get_standard_lifecycle()

	# Modify first array
	lifecycle1.append(SeasonStateMachine.SeasonPhase.PRE_SEASON)

	# Second array should be unchanged
	assert_int(lifecycle2.size()).is_equal(8)


# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_validate_transition_success() -> void:
	var result = SeasonStateMachine.validate_transition(
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		"team_id: SF"
	)

	assert_bool(result["valid"]).is_true()
	assert_str(result["error"]).is_equal("")


func test_validate_transition_invalid() -> void:
	var result = SeasonStateMachine.validate_transition(
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS,  # Invalid: must go through REGULAR_SEASON
		"team_id: SF"
	)

	assert_bool(result["valid"]).is_false()
	assert_str(result["error"]).contains("Invalid transition")
	assert_str(result["error"]).contains("PRE_SEASON")
	assert_str(result["error"]).contains("PLAYOFFS")


func test_validate_transition_without_context() -> void:
	var result = SeasonStateMachine.validate_transition(
		SeasonStateMachine.SeasonPhase.DRAFT,
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	)

	assert_bool(result["valid"]).is_true()


# ============================================================================
# STANDINGS CALCULATION TESTS
# ============================================================================

func test_requires_standings_calculation() -> void:
	# PLAYOFFS requires standings
	assert_bool(SeasonStateMachine.requires_standings_calculation(
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_true()

	# POST_SEASON requires standings
	assert_bool(SeasonStateMachine.requires_standings_calculation(
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_true()

	# PRE_SEASON does not require standings
	assert_bool(SeasonStateMachine.requires_standings_calculation(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_false()

	# OFF_SEASON does not require standings
	assert_bool(SeasonStateMachine.requires_standings_calculation(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_false()


# ============================================================================
# GAME SIMULATION TESTS
# ============================================================================

func test_allows_game_simulation() -> void:
	# PRE_SEASON allows games
	assert_bool(SeasonStateMachine.allows_game_simulation(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_true()

	# REGULAR_SEASON allows games
	assert_bool(SeasonStateMachine.allows_game_simulation(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)).is_true()

	# PLAYOFFS allows games
	assert_bool(SeasonStateMachine.allows_game_simulation(
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_true()

	# POST_SEASON does not allow games
	assert_bool(SeasonStateMachine.allows_game_simulation(
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_false()

	# OFF_SEASON does not allow games
	assert_bool(SeasonStateMachine.allows_game_simulation(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_false()

	# DRAFT does not allow games
	assert_bool(SeasonStateMachine.allows_game_simulation(
		SeasonStateMachine.SeasonPhase.DRAFT
	)).is_false()


# ============================================================================
# ACTIVE SEASON TESTS
# ============================================================================

func test_is_active_season() -> void:
	# PRE_SEASON is active
	assert_bool(SeasonStateMachine.is_active_season(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_true()

	# REGULAR_SEASON is active
	assert_bool(SeasonStateMachine.is_active_season(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)).is_true()

	# PLAYOFFS is active
	assert_bool(SeasonStateMachine.is_active_season(
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_true()

	# POST_SEASON is not active
	assert_bool(SeasonStateMachine.is_active_season(
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_false()

	# OFF_SEASON is not active
	assert_bool(SeasonStateMachine.is_active_season(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_false()

	# DRAFT is not active
	assert_bool(SeasonStateMachine.is_active_season(
		SeasonStateMachine.SeasonPhase.DRAFT
	)).is_false()


# ============================================================================
# OFF-SEASON TESTS
# ============================================================================

func test_is_off_season() -> void:
	# POST_SEASON is off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_true()

	# OFF_SEASON is off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.OFF_SEASON
	)).is_true()

	# DRAFT_PREP is off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.DRAFT_PREP
	)).is_true()

	# DRAFT is off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.DRAFT
	)).is_true()

	# FREE_AGENCY is off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.FREE_AGENCY
	)).is_true()

	# PRE_SEASON is not off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_false()

	# REGULAR_SEASON is not off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)).is_false()

	# PLAYOFFS is not off-season
	assert_bool(SeasonStateMachine.is_off_season(
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)).is_false()


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_cyclical_nature_complete_cycle() -> void:
	# Verify a complete cycle is valid
	var phases := [
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS,
		SeasonStateMachine.SeasonPhase.POST_SEASON,
		SeasonStateMachine.SeasonPhase.OFF_SEASON,
		SeasonStateMachine.SeasonPhase.DRAFT_PREP,
		SeasonStateMachine.SeasonPhase.DRAFT,
		SeasonStateMachine.SeasonPhase.FREE_AGENCY,
		SeasonStateMachine.SeasonPhase.PRE_SEASON  # Back to start
	]

	for i in range(phases.size() - 1):
		var from_phase = phases[i]
		var to_phase = phases[i + 1]
		assert_bool(SeasonStateMachine.can_transition(from_phase, to_phase)).is_true()


func test_alternate_path_regular_to_post() -> void:
	# Verify alternate path without playoffs is valid
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.POST_SEASON
	)).is_true()


func test_alternate_path_draft_to_pre_season() -> void:
	# Verify alternate path skipping FA is valid
	assert_bool(SeasonStateMachine.can_transition(
		SeasonStateMachine.SeasonPhase.DRAFT,
		SeasonStateMachine.SeasonPhase.PRE_SEASON
	)).is_true()
