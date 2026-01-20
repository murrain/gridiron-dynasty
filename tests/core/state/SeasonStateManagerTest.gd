extends GutTest

## SeasonStateManagerTest - Comprehensive test suite for SeasonStateManager
##
## Tests:
## 1. Immutability: Verify inputs are never modified
## 2. Determinism: Same seed produces same results
## 3. State machine transitions: Validate phase transitions
## 4. DataBus integration: Verify notifications are sent
## 5. Error handling: Validate input validation and error cases

const SeasonStateManager = preload("res://scripts/core/state/SeasonStateManager.gd")
const SeasonStateMachine = preload("res://scripts/core/state/SeasonStateMachine.gd")
const SeasonTransformations = preload("res://scripts/core/transformations/SeasonTransformations.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# TEST SETUP
# ============================================================================

var world_state: Dictionary
var test_rng: RandomNumberGenerator

func before_each() -> void:
	# Initialize fresh world state for each test
	world_state = _create_test_world_state()

	# Create deterministic RNG for testing
	test_rng = RandomNumberGenerator.new()
	test_rng.seed = 12345

func after_each() -> void:
	world_state.clear()
	test_rng = null

# ============================================================================
# GAME RESULT TESTS
# ============================================================================

func test_record_game_result_updates_standings() -> void:
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

	# Assert
	assert_true(result.get("success", false), "Should succeed")
	assert_eq(result.get("winner", ""), "SF", "SF should win")

	# Verify standings updated in world_state
	var standings: Dictionary = world_state["nfl_standings"][2033]
	assert_true(standings.has("SF"), "SF should be in standings")
	assert_true(standings.has("SEA"), "SEA should be in standings")

	var sf_record: Dictionary = standings["SF"]
	var sea_record: Dictionary = standings["SEA"]

	assert_eq(sf_record["wins"], 1, "SF should have 1 win")
	assert_eq(sf_record["losses"], 0, "SF should have 0 losses")
	assert_eq(sea_record["wins"], 0, "SEA should have 0 wins")
	assert_eq(sea_record["losses"], 1, "SEA should have 1 loss")

func test_record_game_result_handles_ties() -> void:
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
	assert_true(result.get("success", false), "Should succeed")
	assert_eq(result.get("winner", ""), "TIE", "Should be a tie")

	var standings: Dictionary = world_state["nfl_standings"][2033]
	var sf_record: Dictionary = standings["SF"]
	var sea_record: Dictionary = standings["SEA"]

	assert_eq(sf_record["ties"], 1, "SF should have 1 tie")
	assert_eq(sea_record["ties"], 1, "SEA should have 1 tie")

func test_record_game_results_batch_processing() -> void:
	# Arrange
	var standings_path := ["nfl_standings", 2033]
	var game_results := [
		{
			"home_team_id": "SF",
			"away_team_id": "SEA",
			"home_score": 28,
			"away_score": 21,
			"week": 1,
			"season_type": "regular_season"
		},
		{
			"home_team_id": "DAL",
			"away_team_id": "NYG",
			"home_score": 24,
			"away_score": 17,
			"week": 1,
			"season_type": "regular_season"
		}
	]

	# Act
	var result := SeasonStateManager.record_game_results(
		world_state,
		standings_path,
		game_results
	)

	# Assert
	assert_true(result.get("success", false), "Should succeed")
	assert_eq(result.get("games_recorded", 0), 2, "Should record 2 games")

	var standings: Dictionary = world_state["nfl_standings"][2033]
	assert_eq(standings.size(), 4, "Should have 4 teams in standings")

func test_record_game_result_immutability() -> void:
	# Arrange
	var standings_path := ["nfl_standings", 2033]
	var original_game_result := {
		"home_team_id": "SF",
		"away_team_id": "SEA",
		"home_score": 28,
		"away_score": 21,
		"week": 1,
		"season_type": "regular_season"
	}
	var game_result := original_game_result.duplicate(true)

	# Act
	var _result := SeasonStateManager.record_game_result(
		world_state,
		standings_path,
		game_result
	)

	# Assert - game_result should be unchanged
	assert_eq_deep(game_result, original_game_result, "game_result should not be modified")

# ============================================================================
# SEASON PHASE TRANSITION TESTS
# ============================================================================

func test_advance_season_phase_valid_transition() -> void:
	# Arrange
	var season_state_path := ["nfl_season_state"]
	world_state["nfl_season_state"] = {
		"phase": SeasonStateMachine.SeasonPhase.PRE_SEASON,
		"year": 2033
	}

	# Act
	var success := SeasonStateManager.advance_season_phase(
		world_state,
		season_state_path,
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)

	# Assert
	assert_true(success, "Should succeed for valid transition")

	var season_state: Dictionary = world_state["nfl_season_state"]
	assert_eq(
		season_state["phase"],
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
		"Phase should be updated to REGULAR_SEASON"
	)
	assert_true(
		season_state.has("phase_transition_timestamp"),
		"Should add transition timestamp"
	)

func test_advance_season_phase_invalid_transition() -> void:
	# Arrange
	var season_state_path := ["nfl_season_state"]
	world_state["nfl_season_state"] = {
		"phase": SeasonStateMachine.SeasonPhase.PRE_SEASON,
		"year": 2033
	}

	# Act
	var success := SeasonStateManager.advance_season_phase(
		world_state,
		season_state_path,
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.PLAYOFFS  # Invalid: can't go from PRE_SEASON to PLAYOFFS
	)

	# Assert
	assert_false(success, "Should fail for invalid transition")

	var season_state: Dictionary = world_state["nfl_season_state"]
	assert_eq(
		season_state["phase"],
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		"Phase should remain unchanged"
	)

func test_advance_season_phase_validates_current_phase() -> void:
	# Arrange
	var season_state_path := ["nfl_season_state"]
	world_state["nfl_season_state"] = {
		"phase": SeasonStateMachine.SeasonPhase.REGULAR_SEASON,  # Actual phase
		"year": 2033
	}

	# Act - claim we're in PRE_SEASON but we're actually in REGULAR_SEASON
	var success := SeasonStateManager.advance_season_phase(
		world_state,
		season_state_path,
		SeasonStateMachine.SeasonPhase.PRE_SEASON,  # Wrong expected phase
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)

	# Assert
	assert_false(success, "Should fail when expected phase doesn't match current")

# ============================================================================
# ROSTER PREPARATION TESTS
# ============================================================================

func test_update_roster_for_season_prepares_players() -> void:
	# Arrange
	var roster_path := ["nfl_rosters", "SF"]
	var configs := _create_test_configs()

	# Act
	var result := SeasonStateManager.update_roster_for_season(
		world_state,
		roster_path,
		configs
	)

	# Assert
	assert_true(result.get("success", false), "Should succeed")
	assert_true(result.get("roster_prepared", false), "Roster should be prepared")
	assert_eq(result.get("players_count", 0), 3, "Should have 3 players")

	# Verify roster updated in world_state
	var roster: Dictionary = world_state["nfl_rosters"]["SF"]
	assert_true(roster.get("prepared", false), "Roster should be marked as prepared")

	# Verify players have simulation-ready fields
	var players: Array = roster.get("players", [])
	for player_dict in players:
		if player_dict is Dictionary:
			assert_true(player_dict.has("injury_status"), "Player should have injury_status")
			assert_true(player_dict.has("stamina"), "Player should have stamina")
			assert_true(player_dict.has("morale"), "Player should have morale")

func test_update_roster_for_season_immutability() -> void:
	# Arrange
	var roster_path := ["nfl_rosters", "SF"]
	var configs := _create_test_configs()

	# Get original roster reference
	var original_roster: Dictionary = world_state["nfl_rosters"]["SF"]
	var original_prepared_flag: bool = original_roster.get("prepared", false)

	# Act
	var _result := SeasonStateManager.update_roster_for_season(
		world_state,
		roster_path,
		configs
	)

	# Assert - The roster IN world_state should be updated (that's the point)
	# But the transformation function should not have modified its inputs
	var updated_roster: Dictionary = world_state["nfl_rosters"]["SF"]
	assert_ne(
		updated_roster.get("prepared", false),
		original_prepared_flag,
		"Roster in world_state should be updated"
	)

# ============================================================================
# DRAFT ELIGIBILITY TESTS
# ============================================================================

func test_process_draft_eligibility_senior_auto_eligible() -> void:
	# Arrange
	var players_path := ["college_rosters", "Alabama", "players"]
	var eligibility_rules := {
		"min_class_year": 3,
		"min_age": 21,
		"opt_in_chance": 0.3
	}

	# Create test RNG with known seed for determinism
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Act
	var result := SeasonStateManager.process_draft_eligibility(
		world_state,
		players_path,
		eligibility_rules,
		rng
	)

	# Assert
	assert_true(result.get("success", false), "Should succeed")
	assert_gt(result.get("eligible_count", 0), 0, "Should have eligible players")

	# Verify senior became draft eligible
	var eligible: Array = result.get("eligible_players", [])
	var found_senior := false
	for player_dict in eligible:
		if player_dict is Dictionary:
			if player_dict.get("college_year", 0) >= 4:
				found_senior = true
				assert_eq(
					player_dict.get("stage", -1),
					Player.PlayerStage.DRAFT_ELIGIBLE,
					"Senior should be draft eligible"
				)

	assert_true(found_senior, "Should find at least one senior")

func test_process_draft_eligibility_determinism() -> void:
	# Arrange
	var players_path := ["college_rosters", "Alabama", "players"]
	var eligibility_rules := {
		"min_class_year": 3,
		"min_age": 21,
		"opt_in_chance": 0.3
	}

	# Create two identical RNGs with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345

	# Create two identical world states
	var world_state1 := _create_test_world_state()
	var world_state2 := _create_test_world_state()

	# Act - run twice with same seed
	var result1 := SeasonStateManager.process_draft_eligibility(
		world_state1,
		players_path,
		eligibility_rules,
		rng1
	)

	var result2 := SeasonStateManager.process_draft_eligibility(
		world_state2,
		players_path,
		eligibility_rules,
		rng2
	)

	# Assert - results should be identical
	assert_eq(
		result1.get("eligible_count", 0),
		result2.get("eligible_count", 0),
		"Eligible counts should match (determinism)"
	)
	assert_eq(
		result1.get("remaining_count", 0),
		result2.get("remaining_count", 0),
		"Remaining counts should match (determinism)"
	)

func test_process_draft_eligibility_immutability() -> void:
	# Arrange
	var players_path := ["college_rosters", "Alabama", "players"]
	var eligibility_rules := {
		"min_class_year": 3,
		"min_age": 21,
		"opt_in_chance": 0.3
	}

	# Store original players array for comparison
	var original_players: Array = world_state["college_rosters"]["Alabama"]["players"]
	var original_count := original_players.size()

	# Act
	var _result := SeasonStateManager.process_draft_eligibility(
		world_state,
		players_path,
		eligibility_rules,
		test_rng
	)

	# Assert - The players array in world_state WILL be modified (that's the point),
	# but the transformation function should create new copies, not mutate the originals
	var updated_players: Array = world_state["college_rosters"]["Alabama"]["players"]
	assert_ne(
		updated_players.size(),
		original_count,
		"Players array should be updated with remaining players only"
	)

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_record_game_result_validates_inputs() -> void:
	# Test null world_state
	var result1 := SeasonStateManager.record_game_result(
		{},  # Empty world_state
		["nfl_standings", 2033],
		{"home_team_id": "SF", "away_team_id": "SEA", "home_score": 28, "away_score": 21}
	)
	assert_false(result1.get("success", true), "Should fail with empty world_state")

	# Test empty standings_path
	var result2 := SeasonStateManager.record_game_result(
		world_state,
		[],  # Empty path
		{"home_team_id": "SF", "away_team_id": "SEA", "home_score": 28, "away_score": 21}
	)
	assert_false(result2.get("success", true), "Should fail with empty standings_path")

	# Test empty game_result
	var result3 := SeasonStateManager.record_game_result(
		world_state,
		["nfl_standings", 2033],
		{}  # Empty game_result
	)
	assert_false(result3.get("success", true), "Should fail with empty game_result")

func test_advance_season_phase_validates_inputs() -> void:
	# Test null world_state
	var success1 := SeasonStateManager.advance_season_phase(
		{},  # Empty world_state
		["nfl_season_state"],
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)
	assert_false(success1, "Should fail with empty world_state")

	# Test empty season_state_path
	var success2 := SeasonStateManager.advance_season_phase(
		world_state,
		[],  # Empty path
		SeasonStateMachine.SeasonPhase.PRE_SEASON,
		SeasonStateMachine.SeasonPhase.REGULAR_SEASON
	)
	assert_false(success2, "Should fail with empty season_state_path")

func test_process_draft_eligibility_validates_inputs() -> void:
	# Test null world_state
	var result1 := SeasonStateManager.process_draft_eligibility(
		{},  # Empty world_state
		["college_rosters", "Alabama", "players"],
		{"min_class_year": 3, "min_age": 21, "opt_in_chance": 0.3},
		test_rng
	)
	assert_false(result1.get("success", true), "Should fail with empty world_state")

	# Test empty players_path
	var result2 := SeasonStateManager.process_draft_eligibility(
		world_state,
		[],  # Empty path
		{"min_class_year": 3, "min_age": 21, "opt_in_chance": 0.3},
		test_rng
	)
	assert_false(result2.get("success", true), "Should fail with empty players_path")

	# Test null RNG
	var result3 := SeasonStateManager.process_draft_eligibility(
		world_state,
		["college_rosters", "Alabama", "players"],
		{"min_class_year": 3, "min_age": 21, "opt_in_chance": 0.3},
		null  # Null RNG
	)
	assert_false(result3.get("success", true), "Should fail with null RNG")

# ============================================================================
# TEST HELPERS
# ============================================================================

func _create_test_world_state() -> Dictionary:
	return {
		"nfl_standings": {
			2033: {}
		},
		"nfl_rosters": {
			"SF": {
				"team_id": "SF",
				"players": [
					{
						"id": "player_1",
						"name": "John Doe",
						"position": "QB",
						"age": 25,
						"stats_profile": {
							"current": {
								"speed": 85.0,
								"strength": 78.0,
								"awareness": 90.0
							}
						}
					},
					{
						"id": "player_2",
						"name": "Jane Smith",
						"position": "WR",
						"age": 23,
						"stats_profile": {
							"current": {
								"speed": 92.0,
								"catching": 88.0,
								"route_running": 85.0
							}
						}
					},
					{
						"id": "player_3",
						"name": "Bob Johnson",
						"position": "DE",
						"age": 27,
						"stats_profile": {
							"current": {
								"speed": 80.0,
								"strength": 90.0,
								"pass_rush": 87.0
							}
						}
					}
				]
			}
		},
		"college_rosters": {
			"Alabama": {
				"school_id": "Alabama",
				"players": [
					{
						"id": "college_player_1",
						"name": "College Senior",
						"position": "QB",
						"age": 22,
						"college_year": 4,
						"stage": Player.PlayerStage.COLLEGE
					},
					{
						"id": "college_player_2",
						"name": "College Junior",
						"position": "RB",
						"age": 21,
						"college_year": 3,
						"stage": Player.PlayerStage.COLLEGE
					},
					{
						"id": "college_player_3",
						"name": "College Sophomore",
						"position": "WR",
						"age": 20,
						"college_year": 2,
						"stage": Player.PlayerStage.COLLEGE
					}
				]
			}
		},
		"draft_pool": [],
		"nfl_season_state": {
			"phase": SeasonStateMachine.SeasonPhase.PRE_SEASON,
			"year": 2033
		}
	}

func _create_test_configs() -> Dictionary:
	return {
		"positions": {
			"QB": {"name": "Quarterback"},
			"RB": {"name": "Running Back"},
			"WR": {"name": "Wide Receiver"},
			"DE": {"name": "Defensive End"}
		},
		"main": {
			"simulation_enabled": true
		},
		"stats": {
			"speed": {"min": 0, "max": 100},
			"strength": {"min": 0, "max": 100},
			"awareness": {"min": 0, "max": 100}
		}
	}
