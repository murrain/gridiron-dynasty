class_name TransitionFunctionsTest
extends GdUnitTestSuite

## GdUnit4 test suite for TransitionFunctions.gd
## Tests pure functional stage transitions.

const TransitionFunctions = preload("res://scripts/core/transformations/TransitionFunctions.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player(stage: int = TransitionFunctions.PlayerStage.COLLEGE) -> Dictionary:
	return {
		"id": "test_player_123",
		"age": 20,
		"position": "QB",
		"stage": stage,
		"years_in_stage": 2,
		"class_year": 2,
		"declared_for_draft": false
	}

func _create_test_configs() -> Dictionary:
	return {
		"main": {
			"draft_eligibility": {
				"min_class_year": 3
			}
		}
	}

# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_transition_to_stage_does_not_mutate_player() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	var player_copy := player.duplicate(true)

	TransitionFunctions.transition_to_stage(player, TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE)

	assert_dict(player).is_equal(player_copy)

func test_reset_years_in_stage_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	TransitionFunctions.reset_years_in_stage(player)

	assert_dict(player).is_equal(player_copy)

func test_increment_years_in_stage_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	TransitionFunctions.increment_years_in_stage(player)

	assert_dict(player).is_equal(player_copy)

# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_transition_to_stage_is_deterministic() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)

	var result1 := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
	)
	var result2 := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
	)

	assert_dict(result1).is_equal(result2)

func test_can_declare_for_draft_is_deterministic() -> void:
	var player := _create_test_player()
	player["class_year"] = 3
	var configs := _create_test_configs()

	var result1 := TransitionFunctions.can_declare_for_draft(player, configs)
	var result2 := TransitionFunctions.can_declare_for_draft(player, configs)

	assert_bool(result1).is_equal(result2)

# ============================================================================
# FUNCTIONALITY TESTS - transition_to_stage
# ============================================================================

func test_transition_to_stage_updates_stage() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)

	var result := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
	)

	# Original unchanged
	assert_int(player["stage"]).is_equal(TransitionFunctions.PlayerStage.COLLEGE)
	# New player updated
	assert_int(result["stage"]).is_equal(TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE)

func test_transition_to_stage_resets_years_in_stage() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	player["years_in_stage"] = 3

	var result := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
	)

	assert_int(result["years_in_stage"]).is_equal(0)

func test_transition_to_stage_valid_transitions() -> void:
	# Test valid transition: COLLEGE -> DRAFT_ELIGIBLE
	var player1 := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	var result1 := TransitionFunctions.transition_to_stage(
		player1,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
	)
	assert_int(result1["stage"]).is_equal(TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE)

	# Test valid transition: DRAFT_ELIGIBLE -> NFL_ROOKIE
	var player2 := _create_test_player(TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE)
	var result2 := TransitionFunctions.transition_to_stage(
		player2,
		TransitionFunctions.PlayerStage.NFL_ROOKIE
	)
	assert_int(result2["stage"]).is_equal(TransitionFunctions.PlayerStage.NFL_ROOKIE)

	# Test valid transition: NFL_VETERAN -> RETIRED
	var player3 := _create_test_player(TransitionFunctions.PlayerStage.NFL_VETERAN)
	var result3 := TransitionFunctions.transition_to_stage(
		player3,
		TransitionFunctions.PlayerStage.RETIRED
	)
	assert_int(result3["stage"]).is_equal(TransitionFunctions.PlayerStage.RETIRED)

func test_transition_to_stage_invalid_transition_returns_unchanged() -> void:
	# Invalid transition: HIGH_SCHOOL -> NFL_ROOKIE
	var player := _create_test_player(TransitionFunctions.PlayerStage.HIGH_SCHOOL)

	var result := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.NFL_ROOKIE
	)

	# Should return player unchanged
	assert_int(result["stage"]).is_equal(TransitionFunctions.PlayerStage.HIGH_SCHOOL)

func test_transition_to_stage_retired_is_terminal() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.RETIRED)

	# Try to transition from RETIRED (should fail)
	var result := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.NFL_VETERAN
	)

	# Should remain RETIRED (terminal state)
	assert_int(result["stage"]).is_equal(TransitionFunctions.PlayerStage.RETIRED)

# ============================================================================
# FUNCTIONALITY TESTS - reset_years_in_stage
# ============================================================================

func test_reset_years_in_stage_sets_to_zero() -> void:
	var player := _create_test_player()
	player["years_in_stage"] = 5

	var result := TransitionFunctions.reset_years_in_stage(player)

	assert_int(result["years_in_stage"]).is_equal(0)

func test_reset_years_in_stage_preserves_other_fields() -> void:
	var player := _create_test_player()

	var result := TransitionFunctions.reset_years_in_stage(player)

	assert_str(result["id"]).is_equal("test_player_123")
	assert_int(result["stage"]).is_equal(TransitionFunctions.PlayerStage.COLLEGE)

# ============================================================================
# FUNCTIONALITY TESTS - increment_years_in_stage
# ============================================================================

func test_increment_years_in_stage_adds_one() -> void:
	var player := _create_test_player()
	player["years_in_stage"] = 2

	var result := TransitionFunctions.increment_years_in_stage(player)

	assert_int(result["years_in_stage"]).is_equal(3)

func test_increment_years_in_stage_from_zero() -> void:
	var player := _create_test_player()
	player["years_in_stage"] = 0

	var result := TransitionFunctions.increment_years_in_stage(player)

	assert_int(result["years_in_stage"]).is_equal(1)

func test_increment_years_in_stage_preserves_other_fields() -> void:
	var player := _create_test_player()

	var result := TransitionFunctions.increment_years_in_stage(player)

	assert_str(result["id"]).is_equal("test_player_123")
	assert_int(result["stage"]).is_equal(TransitionFunctions.PlayerStage.COLLEGE)

# ============================================================================
# FUNCTIONALITY TESTS - can_declare_for_draft
# ============================================================================

func test_can_declare_for_draft_eligible_junior() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	player["class_year"] = 3  # Junior
	player["declared_for_draft"] = false
	var configs := _create_test_configs()

	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	assert_bool(result).is_true()

func test_can_declare_for_draft_eligible_senior() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	player["class_year"] = 4  # Senior
	player["declared_for_draft"] = false
	var configs := _create_test_configs()

	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	assert_bool(result).is_true()

func test_can_declare_for_draft_ineligible_freshman() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	player["class_year"] = 1  # Freshman
	player["declared_for_draft"] = false
	var configs := _create_test_configs()

	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	assert_bool(result).is_false()

func test_can_declare_for_draft_ineligible_sophomore() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	player["class_year"] = 2  # Sophomore
	player["declared_for_draft"] = false
	var configs := _create_test_configs()

	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	assert_bool(result).is_false()

func test_can_declare_for_draft_not_in_college() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.HIGH_SCHOOL)
	player["class_year"] = 4
	player["declared_for_draft"] = false
	var configs := _create_test_configs()

	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	# Must be in COLLEGE stage
	assert_bool(result).is_false()

func test_can_declare_for_draft_already_declared() -> void:
	var player := _create_test_player(TransitionFunctions.PlayerStage.COLLEGE)
	player["class_year"] = 3
	player["declared_for_draft"] = true  # Already declared
	var configs := _create_test_configs()

	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	# Can't declare twice
	assert_bool(result).is_false()

# ============================================================================
# FUNCTIONALITY TESTS - apply_draft_declaration
# ============================================================================

func test_apply_draft_declaration_sets_flag() -> void:
	var player := _create_test_player()
	player["declared_for_draft"] = false

	var result := TransitionFunctions.apply_draft_declaration(player)

	# Original unchanged
	assert_bool(player["declared_for_draft"]).is_false()
	# New player has flag set
	assert_bool(result["declared_for_draft"]).is_true()

func test_apply_draft_declaration_preserves_other_fields() -> void:
	var player := _create_test_player()

	var result := TransitionFunctions.apply_draft_declaration(player)

	assert_str(result["id"]).is_equal("test_player_123")
	assert_int(result["stage"]).is_equal(TransitionFunctions.PlayerStage.COLLEGE)

# ============================================================================
# FUNCTIONALITY TESTS - can_transition_to
# ============================================================================

func test_can_transition_to_valid_transitions() -> void:
	# HIGH_SCHOOL -> COLLEGE
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.HIGH_SCHOOL,
			TransitionFunctions.PlayerStage.COLLEGE
		)
	).is_true()

	# COLLEGE -> DRAFT_ELIGIBLE
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.COLLEGE,
			TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
		)
	).is_true()

	# DRAFT_ELIGIBLE -> NFL_ROOKIE
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE,
			TransitionFunctions.PlayerStage.NFL_ROOKIE
		)
	).is_true()

	# NFL_VETERAN -> RETIRED
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.NFL_VETERAN,
			TransitionFunctions.PlayerStage.RETIRED
		)
	).is_true()

func test_can_transition_to_invalid_transitions() -> void:
	# HIGH_SCHOOL -> NFL_ROOKIE (invalid)
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.HIGH_SCHOOL,
			TransitionFunctions.PlayerStage.NFL_ROOKIE
		)
	).is_false()

	# RETIRED -> anything (terminal)
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.RETIRED,
			TransitionFunctions.PlayerStage.NFL_VETERAN
		)
	).is_false()

	# COLLEGE -> NFL_VETERAN (must go through draft/rookie)
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.COLLEGE,
			TransitionFunctions.PlayerStage.NFL_VETERAN
		)
	).is_false()

func test_can_transition_to_self_transitions() -> void:
	# COLLEGE -> COLLEGE (valid, repeating year)
	assert_bool(
		TransitionFunctions.can_transition_to(
			TransitionFunctions.PlayerStage.COLLEGE,
			TransitionFunctions.PlayerStage.COLLEGE
		)
	).is_true()

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_transition_to_stage_with_missing_years_in_stage() -> void:
	var player := _create_test_player()
	player.erase("years_in_stage")

	var result := TransitionFunctions.transition_to_stage(
		player,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE
	)

	# Should set years_in_stage to 0
	assert_int(result["years_in_stage"]).is_equal(0)

func test_increment_years_in_stage_with_missing_field() -> void:
	var player := _create_test_player()
	player.erase("years_in_stage")

	var result := TransitionFunctions.increment_years_in_stage(player)

	# Should default to 0 and increment to 1
	assert_int(result["years_in_stage"]).is_equal(1)

func test_can_declare_for_draft_with_missing_fields() -> void:
	var player := {"stage": TransitionFunctions.PlayerStage.COLLEGE}
	var configs := _create_test_configs()

	# Should use defaults and handle gracefully
	var result := TransitionFunctions.can_declare_for_draft(player, configs)

	# Default class_year is 4, declared_for_draft is false, so should be true
	assert_bool(result).is_true()

func test_can_transition_to_with_same_stage() -> void:
	# Test all stages with themselves
	for stage in [
		TransitionFunctions.PlayerStage.HIGH_SCHOOL,
		TransitionFunctions.PlayerStage.COLLEGE,
		TransitionFunctions.PlayerStage.DRAFT_ELIGIBLE,
		TransitionFunctions.PlayerStage.NFL_ROOKIE,
		TransitionFunctions.PlayerStage.NFL_VETERAN,
		TransitionFunctions.PlayerStage.NFL_FREE_AGENT,
		TransitionFunctions.PlayerStage.RETIRED
	]:
		var can_self_transition := TransitionFunctions.can_transition_to(stage, stage)

		# Only COLLEGE can self-transition (repeating year)
		if stage == TransitionFunctions.PlayerStage.COLLEGE:
			assert_bool(can_self_transition).is_true()
		else:
			assert_bool(can_self_transition).is_false()

func test_apply_draft_declaration_idempotent() -> void:
	var player := _create_test_player()
	player["declared_for_draft"] = false

	var result1 := TransitionFunctions.apply_draft_declaration(player)
	var result2 := TransitionFunctions.apply_draft_declaration(result1)

	# Both should have declared_for_draft = true
	assert_bool(result1["declared_for_draft"]).is_true()
	assert_bool(result2["declared_for_draft"]).is_true()
