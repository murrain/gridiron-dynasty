extends GdUnitTestSuite
class_name TestEvaluationContextGdUnit4

## Tests for EvaluationContext data container
##
## Validates:
## - Factory methods create valid contexts
## - Helper methods return correct values
## - Position classification works correctly
## - Scheme selection logic is correct

const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# FACTORY METHOD TESTS
# =============================================================================

func test_for_draft_creates_valid_context() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 80.0, 4)
	var team := {"team_id": "T001", "offensive_scheme": "air_raid", "defensive_scheme": "cover_3"}
	var roster := {"by_position": {"QB": [{"player_id": "QB1"}]}}
	var positions_cfg := {}
	var stats_cfg := {}
	var class_rules := {}
	var draft_strategy := {"tier_1": ["QB", "EDGE"]}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, 1, 2025,
		positions_cfg, stats_cfg, class_rules, draft_strategy
	)

	assert_object(ctx).is_not_null()
	assert_that(ctx.player).is_equal(player)
	assert_string(ctx.position).is_equal("QB")
	assert_that(ctx.team).is_equal(team)
	assert_that(ctx.roster).is_equal(roster)
	assert_string(ctx.phase).is_equal("draft")
	assert_int(ctx.draft_round).is_equal(1)
	assert_int(ctx.year).is_equal(2025)
	assert_string(ctx.offensive_scheme).is_equal("air_raid")
	assert_string(ctx.defensive_scheme).is_equal("cover_3")
	assert_that(ctx.draft_strategy).is_equal(draft_strategy)


func test_for_free_agency_creates_valid_context() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "EDGE", 25, 75.0, 4)
	var team := {"team_id": "T001", "offensive_scheme": "west_coast", "defensive_scheme": "3_4_two_gap"}
	var roster := {"by_position": {"EDGE": []}}
	var positions_cfg := {}
	var class_rules := {}

	var ctx := EvaluationContext.for_free_agency(
		player, team, roster, 2025, positions_cfg, class_rules
	)

	assert_object(ctx).is_not_null()
	assert_string(ctx.position).is_equal("EDGE")
	assert_string(ctx.phase).is_equal("free_agency")
	assert_int(ctx.draft_round).is_equal(0)  # Not applicable for FA
	assert_string(ctx.defensive_scheme).is_equal("3_4_two_gap")


func test_for_trade_creates_valid_context() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "CB", 23, 82.0, 4)
	var team := {"team_id": "T001", "offensive_scheme": "pro_style", "defensive_scheme": "cover_2"}
	var roster := {"by_position": {"CB": [{"player_id": "CB1"}, {"player_id": "CB2"}]}}
	var positions_cfg := {}
	var class_rules := {}

	var ctx := EvaluationContext.for_trade(
		player, team, roster, 2025, positions_cfg, class_rules
	)

	assert_object(ctx).is_not_null()
	assert_string(ctx.phase).is_equal("trade")
	assert_string(ctx.position).is_equal("CB")


# =============================================================================
# POSITION CLASSIFICATION TESTS
# =============================================================================

func test_is_offensive_position_recognizes_all_offensive_positions() -> void:
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]

	for pos in offensive_positions:
		var player := {"position": pos}
		var ctx := EvaluationContext.new()
		ctx.player = player
		ctx.position = pos

		assert_bool(ctx.is_offensive_position()).override_failure_message(
			"Position %s should be recognized as offensive" % pos
		).is_true()
		assert_bool(ctx.is_defensive_position()).is_false()
		assert_bool(ctx.is_special_teams_position()).is_false()


func test_is_defensive_position_recognizes_all_defensive_positions() -> void:
	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	for pos in defensive_positions:
		var player := {"position": pos}
		var ctx := EvaluationContext.new()
		ctx.player = player
		ctx.position = pos

		assert_bool(ctx.is_defensive_position()).override_failure_message(
			"Position %s should be recognized as defensive" % pos
		).is_true()
		assert_bool(ctx.is_offensive_position()).is_false()
		assert_bool(ctx.is_special_teams_position()).is_false()


func test_is_special_teams_position_recognizes_special_teams() -> void:
	var special_teams_positions := ["K", "P"]

	for pos in special_teams_positions:
		var player := {"position": pos}
		var ctx := EvaluationContext.new()
		ctx.player = player
		ctx.position = pos

		assert_bool(ctx.is_special_teams_position()).override_failure_message(
			"Position %s should be recognized as special teams" % pos
		).is_true()
		assert_bool(ctx.is_offensive_position()).is_false()
		assert_bool(ctx.is_defensive_position()).is_false()


# =============================================================================
# SCHEME SELECTION TESTS
# =============================================================================

func test_get_scheme_for_position_returns_offensive_scheme_for_offensive_positions() -> void:
	var ctx := EvaluationContext.new()
	ctx.offensive_scheme = "air_raid"
	ctx.defensive_scheme = "cover_2"

	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]
	for pos in offensive_positions:
		ctx.position = pos
		assert_string(ctx.get_scheme_for_position()).is_equal("air_raid")


func test_get_scheme_for_position_returns_defensive_scheme_for_defensive_positions() -> void:
	var ctx := EvaluationContext.new()
	ctx.offensive_scheme = "west_coast"
	ctx.defensive_scheme = "3_4_two_gap"

	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]
	for pos in defensive_positions:
		ctx.position = pos
		assert_string(ctx.get_scheme_for_position()).is_equal("3_4_two_gap")


func test_get_scheme_for_position_returns_empty_for_special_teams() -> void:
	var ctx := EvaluationContext.new()
	ctx.offensive_scheme = "air_raid"
	ctx.defensive_scheme = "cover_2"

	var special_teams := ["K", "P"]
	for pos in special_teams:
		ctx.position = pos
		assert_string(ctx.get_scheme_for_position()).is_empty()


# =============================================================================
# POSITION GROUP TESTS
# =============================================================================

func test_get_position_group_classifies_all_positions_correctly() -> void:
	var test_cases := [
		{"position": "QB", "group": "offense"},
		{"position": "RB", "group": "offense"},
		{"position": "WR", "group": "offense"},
		{"position": "TE", "group": "offense"},
		{"position": "OL", "group": "offense"},
		{"position": "DL", "group": "defense"},
		{"position": "EDGE", "group": "defense"},
		{"position": "LB", "group": "defense"},
		{"position": "CB", "group": "defense"},
		{"position": "S", "group": "defense"},
		{"position": "K", "group": "special_teams"},
		{"position": "P", "group": "special_teams"},
		{"position": "UNKNOWN", "group": "unknown"},
	]

	for case in test_cases:
		var ctx := EvaluationContext.new()
		ctx.position = case["position"]
		assert_string(ctx.get_position_group()).override_failure_message(
			"Position %s should have group %s" % [case["position"], case["group"]]
		).is_equal(case["group"])


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_context_handles_missing_coach_gracefully() -> void:
	var player := TestHelpersGdUnit4.create_test_player()
	var team := {"team_id": "T001"}  # No coach
	var roster := {}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, 1, 2025, {}, {}, {}, {}
	)

	assert_that(ctx.coach).is_not_null()
	assert_that(ctx.coach).is_equal({})


func test_context_handles_missing_schemes_gracefully() -> void:
	var player := TestHelpersGdUnit4.create_test_player()
	var team := {"team_id": "T001"}  # No schemes specified
	var roster := {}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, 1, 2025, {}, {}, {}, {}
	)

	# Should default to standard schemes
	assert_string(ctx.offensive_scheme).is_equal("pro_style")
	assert_string(ctx.defensive_scheme).is_equal("cover_2")


func test_context_extracts_position_from_player() -> void:
	var player := {"position": "EDGE", "stats": {"speed": 85.0}}
	var team := {"team_id": "T001"}
	var roster := {}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, 1, 2025, {}, {}, {}, {}
	)

	assert_string(ctx.position).is_equal("EDGE")


func test_context_handles_missing_position_gracefully() -> void:
	var player := {"stats": {"speed": 85.0}}  # No position field
	var team := {"team_id": "T001"}
	var roster := {}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, 1, 2025, {}, {}, {}, {}
	)

	assert_string(ctx.position).is_empty()
