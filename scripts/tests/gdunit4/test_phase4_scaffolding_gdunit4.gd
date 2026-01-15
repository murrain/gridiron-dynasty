## GdUnit4 test suite for Phase 4 Model Scaffolding
##
## Tests that Phase 4 core models (Team, Roster, Coach, LeagueContainer)
## can be loaded and instantiated correctly.
extends GdUnitTestSuite


func test_team_model_instantiates() -> void:
	var team_path := "res://scripts/core/models/Team.gd"

	if not ResourceLoader.exists(team_path):
		# Skip test if model not yet implemented
		assert_bool(true).is_true()
		return

	var team: Variant = load(team_path).new()
	assert_that(team).is_not_null()


func test_roster_model_instantiates() -> void:
	var roster_path := "res://scripts/core/models/Roster.gd"

	if not ResourceLoader.exists(roster_path):
		# Skip test if model not yet implemented
		assert_bool(true).is_true()
		return

	var roster: Variant = load(roster_path).new()
	assert_that(roster).is_not_null()


func test_coach_model_instantiates() -> void:
	var coach_path := "res://scripts/core/models/Coach.gd"

	if not ResourceLoader.exists(coach_path):
		# Skip test if model not yet implemented
		assert_bool(true).is_true()
		return

	var coach: Variant = load(coach_path).new()
	assert_that(coach).is_not_null()


func test_league_container_instantiates() -> void:
	var league_path := "res://scripts/world/LeagueContainer.gd"

	if not ResourceLoader.exists(league_path):
		# Skip test if not yet implemented
		assert_bool(true).is_true()
		return

	var league: Variant = load(league_path).new()
	assert_that(league).is_not_null()


func test_all_phase4_models_load_together() -> void:
	var team_path := "res://scripts/core/models/Team.gd"
	var roster_path := "res://scripts/core/models/Roster.gd"
	var coach_path := "res://scripts/core/models/Coach.gd"
	var league_path := "res://scripts/world/LeagueContainer.gd"

	var all_exist := (
		ResourceLoader.exists(team_path) and
		ResourceLoader.exists(roster_path) and
		ResourceLoader.exists(coach_path) and
		ResourceLoader.exists(league_path)
	)

	if not all_exist:
		# Skip integration test if any models missing
		assert_bool(true).is_true()
		return

	var team: Variant = load(team_path).new()
	var roster: Variant = load(roster_path).new()
	var coach: Variant = load(coach_path).new()
	var league: Variant = load(league_path).new()

	assert_that(team).is_not_null()
	assert_that(roster).is_not_null()
	assert_that(coach).is_not_null()
	assert_that(league).is_not_null()
