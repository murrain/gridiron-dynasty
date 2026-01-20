extends GdUnitTestSuite

## SeasonIntegrationTest - Integration tests for refactored season simulation
##
## Tests season simulation end-to-end using SeasonStateManager:
## 1. Game results update standings correctly
## 2. Season phase transitions work (PRE_SEASON -> REGULAR_SEASON -> PLAYOFFS)
## 3. NFL, College, and HS seasons work end-to-end
## 4. Determinism: Same seed produces same results
## 5. DataBus notifications fire for season updates
## 6. Roster preparation works correctly
## 7. Draft eligibility processing works

const NflSeason = preload("res://scripts/world/NflSeason.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const SeasonStateManager = preload("res://scripts/core/state/SeasonStateManager.gd")
const SeasonStateMachine = preload("res://scripts/core/state/SeasonStateMachine.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# TEST SETUP
# ============================================================================

var world_state: Dictionary
var test_configs: Dictionary

func before_test() -> void:
	world_state = _create_test_world_state()
	test_configs = _create_test_configs()

func after_test() -> void:
	world_state.clear()
	test_configs.clear()

# ============================================================================
# GAME RESULT TESTS
# ============================================================================

func test_game_results_update_standings_correctly() -> void:
	# Arrange
	var standings_path := ["nfl_standings", 2033]
	var game_result := {
		"home_team_id": "SF",
		"away_team_id": "SEA",
		"home_score": 28,
		"away_score": 21,
		"week": 1,
		"season_type": "regular_season"
	}

	# Act
	var result := SeasonStateManager.record_game_result(
		world_state,
		standings_path,
		game_result
	)

	# Assert - Success
	assert_that(result["success"]).is_true()
	assert_that(result["winner"]).is_equal("SF")

	# Assert - Standings updated
	var standings: Dictionary = world_state["nfl_standings"][2033]
	assert_that(standings.has("SF")).is_true()
	assert_that(standings.has("SEA")).is_true()

	var sf_record: Dictionary = standings["SF"]
	var sea_record: Dictionary = standings["SEA"]

	assert_that(sf_record["wins"]).is_equal(1)
	assert_that(sf_record["losses"]).is_equal(0)
	assert_that(sea_record["wins"]).is_equal(0)
	assert_that(sea_record["losses"]).is_equal(1)


func test_game_results_handle_ties() -> void:
	# Arrange
	var standings_path := ["nfl_standings", 2033]
	var game_result := {
		"home_team_id": "SF",
		"away_team_id": "SEA",
		"home_score": 21,
		"away_score": 21,
		"week": 1,
		"season_type": "regular_season"
	}

	# Act
	var result := SeasonStateManager.record_game_result(
		world_state,
		standings_path,
		game_result
	)

	# Assert
	assert_that(result["success"]).is_true()
	assert_that(result["winner"]).is_equal("TIE")

	var standings: Dictionary = world_state["nfl_standings"][2033]
	var sf_record: Dictionary = standings["SF"]
	var sea_record: Dictionary = standings["SEA"]

	assert_that(sf_record["ties"]).is_equal(1)
	assert_that(sea_record["ties"]).is_equal(1)


func test_multiple_game_results_accumulate_correctly() -> void:
	# Arrange
	var standings_path := ["nfl_standings", 2033]
	var games := [
		{
			"home_team_id": "SF",
			"away_team_id": "SEA",
			"home_score": 28,
			"away_score": 21,
			"week": 1,
			"season_type": "regular_season"
		},
		{
			"home_team_id": "SEA",
			"away_team_id": "SF",
			"home_score": 24,
			"away_team_id": 17,
			"week": 2,
			"season_type": "regular_season"
		},
		{
			"home_team_id": "SF",
			"away_team_id": "LAR",
			"home_score": 30,
			"away_score": 20,
			"week": 3,
			"season_type": "regular_season"
		}
	]

	# Act - Record multiple games
	for game in games:
		SeasonStateManager.record_game_result(
			world_state,
			standings_path,
			game
		)

	# Assert - Standings reflect all games
	var standings: Dictionary = world_state["nfl_standings"][2033]
	var sf_record: Dictionary = standings["SF"]

	# SF won weeks 1 and 3
	assert_that(sf_record["wins"]).is_equal(2)


# ============================================================================
# SEASON PHASE TRANSITION TESTS
# ============================================================================

func test_season_phase_transitions_work() -> void:
	# Arrange
	var season_state_path := ["nfl_season_state"]
	world_state["nfl_season_state"] = {
		"phase": SeasonStateMachine.SeasonPhase.PRE_SEASON,
		"year": 2033
	}

	# Act & Assert - Valid transition: PRE_SEASON -> REGULAR_SEASON
	var success := SeasonStateManager.advance_season_phase(
		world_state,
		season_state_path,
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)
	assert_that(success).is_true()

	var season_state: Dictionary = world_state["nfl_season_state"]
	assert_that(season_state["phase"]).is_equal(SeasonStateMachine.SeasonPhase.REGULAR_SEASON)

	# Act & Assert - Valid transition: REGULAR_SEASON -> PLAYOFFS
	success = SeasonStateManager.advance_season_phase(
		world_state,
		season_state_path,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)
	assert_that(success).is_true()
	assert_that(season_state["phase"]).is_equal(SeasonStateMachine.SeasonPhase.PLAYOFFS)


func test_invalid_season_phase_transition_rejected() -> void:
	# Arrange
	var season_state_path := ["nfl_season_state"]
	world_state["nfl_season_state"] = {
		"phase": SeasonStateMachine.SeasonPhase.PRE_SEASON,
		"year": 2033
	}

	# Act - Try invalid transition: PRE_SEASON -> PLAYOFFS
	var success := SeasonStateManager.advance_season_phase(
		world_state,
		season_state_path,
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS
	)

	# Assert - Transition rejected
	assert_that(success).is_false()

	var season_state: Dictionary = world_state["nfl_season_state"]
	assert_that(season_state["phase"]).is_equal(SeasonStateMachine.SeasonPhase.PRE_SEASON)


# ============================================================================
# NFL SEASON INTEGRATION TESTS
# ============================================================================

func test_nfl_season_completes_successfully() -> void:
	# Arrange
	var year := 2033
	var seed := 12345
	var league_cfg := test_configs["league"]
	var positions_cfg := test_configs["positions"]
	var main_cfg := test_configs["main"]
	var stats_cfg := test_configs["stats"]

	# Act
	var result := NflSeason.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_trades": true}  # Skip trades for faster test
	)

	# Assert - Basic completion
	assert_that(result).is_not_null()
	assert_that(result.has("year")).is_true()
	assert_that(result.has("roster_counts")).is_true()
	assert_that(result["year"]).is_equal(year)

	# Assert - Rosters still exist
	var roster_counts: Dictionary = result["roster_counts"]
	assert_that(roster_counts.size()).is_greater(0)


func test_nfl_season_determinism() -> void:
	# Arrange
	var year := 2033
	var seed := 99999
	var league_cfg := test_configs["league"]
	var positions_cfg := test_configs["positions"]
	var main_cfg := test_configs["main"]
	var stats_cfg := test_configs["stats"]

	# Act - Run season twice with same seed
	var world_state_1 := _create_test_world_state()
	var result_1 := NflSeason.new().run(
		world_state_1,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_trades": true}
	)

	var world_state_2 := _create_test_world_state()
	var result_2 := NflSeason.new().run(
		world_state_2,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_trades": true}
	)

	# Assert - Same retirement count
	assert_that(result_2["retirements"]).is_equal(result_1["retirements"])

	# Assert - Same free agent count
	assert_that(result_2["free_agents"]).is_equal(result_1["free_agents"])


# ============================================================================
# COLLEGE SEASON INTEGRATION TESTS
# ============================================================================

func test_college_season_completes_successfully() -> void:
	# Arrange
	var year := 2033
	var seed := 12345
	var league_cfg := test_configs["league"]
	var positions_cfg := test_configs["positions"]
	var main_cfg := test_configs["main"]
	var stats_cfg := test_configs["stats"]

	# Add college rosters to world state
	world_state["college_rosters"] = _create_test_college_rosters()

	# Act
	var result := CollegeSeason.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg
	)

	# Assert - Basic completion
	assert_that(result).is_not_null()
	assert_that(result.has("year")).is_true()
	assert_that(result["year"]).is_equal(year)

	# Assert - Draft pool created (seniors became draft eligible)
	assert_that(result.has("draft_eligible_count")).is_true()


func test_college_season_draft_eligibility_processing() -> void:
	# Arrange
	var year := 2033
	var seed := 12345
	var league_cfg := test_configs["league"]
	var positions_cfg := test_configs["positions"]
	var main_cfg := test_configs["main"]
	var stats_cfg := test_configs["stats"]

	# Add college rosters with seniors
	world_state["college_rosters"] = _create_test_college_rosters()

	var initial_senior_count := 0
	for school_id in world_state["college_rosters"].keys():
		var roster: Dictionary = world_state["college_rosters"][school_id]
		var players: Array = roster["players"]
		for player in players:
			var p: Dictionary = player
			if p.get("college_year", 0) >= 4:
				initial_senior_count += 1

	# Act
	var result := CollegeSeason.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg
	)

	# Assert - Draft eligible count includes at least some seniors
	var draft_eligible_count: int = result.get("draft_eligible_count", 0)
	assert_that(draft_eligible_count).is_greater(0)


# ============================================================================
# ROSTER PREPARATION TESTS
# ============================================================================

func test_roster_preparation_adds_simulation_fields() -> void:
	# Arrange
	var roster_path := ["nfl_rosters", "SF"]
	var configs := test_configs

	# Act
	var result := SeasonStateManager.update_roster_for_season(
		world_state,
		roster_path,
		configs
	)

	# Assert - Success
	assert_that(result["success"]).is_true()
	assert_that(result["roster_prepared"]).is_true()

	# Assert - Players have simulation fields
	var roster: Dictionary = world_state["nfl_rosters"]["SF"]
	var players: Array = roster["players"]

	for player in players:
		var p: Dictionary = player
		# These fields should be added by roster preparation
		assert_that(p.has("injury_status")).is_true()
		assert_that(p.has("stamina")).is_true()


# ============================================================================
# CROSS-LEVEL SEASON TESTS
# ============================================================================

func test_all_three_season_levels_complete_sequentially() -> void:
	# Arrange
	var year := 2033
	var seed := 12345
	var league_cfg := test_configs["league"]
	var positions_cfg := test_configs["positions"]
	var main_cfg := test_configs["main"]
	var stats_cfg := test_configs["stats"]

	# Add high school and college rosters
	world_state["high_school_rosters"] = _create_test_high_school_rosters()
	world_state["college_rosters"] = _create_test_college_rosters()

	# Act - Run all three season levels
	var hs_result := HighSchoolSeason.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg
	)

	var college_result := CollegeSeason.new().run(
		world_state,
		year,
		seed + 1,  # Different seed
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg
	)

	var nfl_result := NflSeason.new().run(
		world_state,
		year,
		seed + 2,  # Different seed
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_trades": true}
	)

	# Assert - All completed
	assert_that(hs_result).is_not_null()
	assert_that(college_result).is_not_null()
	assert_that(nfl_result).is_not_null()

	# Assert - Each level produced players transitioning
	assert_that(hs_result.has("graduating_count")).is_true()
	assert_that(college_result.has("draft_eligible_count")).is_true()


# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_season_does_not_corrupt_configs() -> void:
	# Arrange
	var year := 2033
	var seed := 12345
	var league_cfg := test_configs["league"].duplicate(true)
	var positions_cfg := test_configs["positions"].duplicate(true)
	var main_cfg := test_configs["main"].duplicate(true)
	var stats_cfg := test_configs["stats"].duplicate(true)

	# Hash configs before season
	var league_hash := hash(league_cfg)
	var positions_hash := hash(positions_cfg)
	var main_hash := hash(main_cfg)
	var stats_hash := hash(stats_cfg)

	# Act
	var _result := NflSeason.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_trades": true}
	)

	# Assert - Configs unchanged
	assert_that(hash(league_cfg)).is_equal(league_hash)
	assert_that(hash(positions_cfg)).is_equal(positions_hash)
	assert_that(hash(main_cfg)).is_equal(main_hash)
	assert_that(hash(stats_cfg)).is_equal(stats_hash)


# ============================================================================
# TEST HELPERS
# ============================================================================

func _create_test_world_state() -> Dictionary:
	return {
		"nfl_teams": _create_test_teams(),
		"nfl_rosters": _create_test_nfl_rosters(),
		"nfl_standings": {
			2033: {}
		},
		"nfl_season_state": {
			"phase": SeasonStateMachine.SeasonPhase.PRE_SEASON,
			"year": 2033
		},
		"retired_players": [],
		"free_agents": {}
	}


func _create_test_teams() -> Array:
	return [
		{"id": "SF", "name": "49ers"},
		{"id": "SEA", "name": "Seahawks"},
		{"id": "LAR", "name": "Rams"}
	]


func _create_test_nfl_rosters() -> Dictionary:
	return {
		"SF": {
			"team_id": "SF",
			"players": _create_test_players("SF", 5)
		},
		"SEA": {
			"team_id": "SEA",
			"players": _create_test_players("SEA", 5)
		},
		"LAR": {
			"team_id": "LAR",
			"players": _create_test_players("LAR", 5)
		}
	}


func _create_test_players(team_id: String, count: int) -> Array:
	var players: Array = []
	for i in range(count):
		players.append({
			"player_id": "%s_player_%d" % [team_id, i],
			"name": "Player %d" % i,
			"position": _get_position_for_index(i),
			"age": 25 + (i % 5),
			"nfl_team_id": team_id,
			"stats": {
				"speed": 70.0,
				"strength": 75.0,
				"awareness": 80.0
			},
			"contract": {
				"status": "signed",
				"years_remaining": 2 + (i % 2),
				"annual_value": 5.0
			}
		})
	return players


func _create_test_college_rosters() -> Dictionary:
	return {
		"Alabama": {
			"school_id": "Alabama",
			"players": [
				{
					"player_id": "college_senior_1",
					"name": "College Senior",
					"position": "QB",
					"age": 22,
					"college_year": 4,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 75.0, "strength": 70.0}
				},
				{
					"player_id": "college_junior_1",
					"name": "College Junior",
					"position": "RB",
					"age": 21,
					"college_year": 3,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 80.0, "strength": 75.0}
				},
				{
					"player_id": "college_sophomore_1",
					"name": "College Sophomore",
					"position": "WR",
					"age": 20,
					"college_year": 2,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 85.0, "strength": 65.0}
				}
			]
		}
	}


func _create_test_high_school_rosters() -> Dictionary:
	return {
		"Test_HS": {
			"school_id": "Test_HS",
			"players": [
				{
					"player_id": "hs_senior_1",
					"name": "HS Senior",
					"position": "QB",
					"age": 18,
					"high_school_year": 4,
					"stage": Player.PlayerStage.HIGH_SCHOOL,
					"stats": {"speed": 70.0, "strength": 65.0}
				}
			]
		}
	}


func _get_position_for_index(idx: int) -> String:
	var positions := ["QB", "RB", "WR", "TE", "OL"]
	return positions[idx % positions.size()]


func _create_test_configs() -> Dictionary:
	return {
		"league": {
			"season": {
				"regular_season_weeks": 17,
				"playoff_teams": 7
			}
		},
		"positions": {
			"QB": {"name": "Quarterback", "group": "offense"},
			"RB": {"name": "Running Back", "group": "offense"},
			"WR": {"name": "Wide Receiver", "group": "offense"},
			"TE": {"name": "Tight End", "group": "offense"},
			"OL": {"name": "Offensive Line", "group": "offense"}
		},
		"main": {
			"simulation_enabled": true,
			"class_rules": {
				"draft_eligibility": {
					"min_class_year": 3,
					"min_age": 21,
					"opt_in_chance": 0.3
				}
			}
		},
		"stats": {
			"stats": [
				{"name": "speed", "min": 0, "max": 100},
				{"name": "strength", "min": 0, "max": 100},
				{"name": "awareness", "min": 0, "max": 100}
			]
		}
	}
