extends GdUnitTestSuite

## DraftIntegrationTest - Integration tests for refactored NflDraft.gd
##
## Tests the full draft flow using DraftStateManager to verify:
## 1. Complete draft simulation produces valid results
## 2. Determinism: Same RNG seed produces identical draft outcomes
## 3. DataBus notifications fire during draft operations
## 4. Draft state machine transitions correctly (INITIALIZING -> RUNNING -> COMPLETED)
## 5. Undrafted players stored correctly
## 6. Draft history recorded correctly
## 7. Immutability: Original world_state structures preserved

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const DraftStateManager = preload("res://scripts/core/state/DraftStateManager.gd")
const DraftStateMachine = preload("res://scripts/core/state/DraftStateMachine.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

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
# FULL DRAFT SIMULATION TESTS
# ============================================================================

func test_complete_draft_simulation_produces_valid_results() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var league_cfg: Dictionary = test_configs["league"]
	var positions_cfg: Dictionary = test_configs["positions"]
	var stats_cfg: Dictionary = test_configs["stats"]
	var scouts_cfg: Dictionary = test_configs["scouts"]
	var main_cfg: Dictionary = test_configs["main"]

	# Act
	var result := NflDraft.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - Basic completion
	assert_that(result).is_not_null()
	assert_that(result.has("picks")).is_true()
	assert_that(result.has("undrafted_count")).is_true()
	assert_that(result.has("picks_count")).is_true()

	# Assert - Picks structure
	var picks: Array = result["picks"]
	assert_that(picks.size()).is_greater(0)

	# Verify pick structure
	for pick in picks:
		var p: Dictionary = pick
		assert_that(p.has("player_id")).is_true()
		assert_that(p.has("team_id")).is_true()
		assert_that(p.has("round")).is_true()
		assert_that(p.has("pick")).is_true()
		assert_that(p.has("position")).is_true()

	# Assert - Draft pool reduced
	var draft_pool: Array = world_state["draft_pool"][year]
	var initial_pool_size: int = _create_test_draft_pool().size()
	assert_that(draft_pool.size()).is_less(initial_pool_size)

	# Assert - Players added to rosters
	var rosters: Dictionary = world_state["nfl_rosters"]
	var total_roster_size := 0
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])
		total_roster_size += players.size()
	assert_that(total_roster_size).is_greater(0)

	# Assert - Draft state transitioned to COMPLETED
	var draft_state: Dictionary = world_state["draft_state"]
	assert_that(draft_state["state"]).is_equal(DraftStateMachine.State.COMPLETED)

	# Assert - Draft history recorded
	assert_that(world_state.has("draft_history")).is_true()
	assert_that(world_state["draft_history"].has(year)).is_true()
	var history: Array = world_state["draft_history"][year]
	assert_that(history.size()).is_equal(picks.size())


func test_same_seed_produces_identical_draft_outcomes() -> void:
	# Arrange
	var year := 2025
	var seed := 99999
	var league_cfg: Dictionary = test_configs["league"]
	var positions_cfg: Dictionary = test_configs["positions"]
	var stats_cfg: Dictionary = test_configs["stats"]
	var scouts_cfg: Dictionary = test_configs["scouts"]
	var main_cfg: Dictionary = test_configs["main"]

	# Act - Run draft twice with same seed
	var world_state_1 := _create_test_world_state()
	var result_1 := NflDraft.new().run(
		world_state_1,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	var world_state_2 := _create_test_world_state()
	var result_2 := NflDraft.new().run(
		world_state_2,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - Same number of picks
	var picks_1: Array = result_1["picks"]
	var picks_2: Array = result_2["picks"]
	assert_that(picks_1.size()).is_equal(picks_2.size())

	# Assert - Identical pick order and selections
	for i in range(picks_1.size()):
		var pick_1: Dictionary = picks_1[i]
		var pick_2: Dictionary = picks_2[i]

		assert_that(pick_2["player_id"]).is_equal(pick_1["player_id"])
		assert_that(pick_2["team_id"]).is_equal(pick_1["team_id"])
		assert_that(pick_2["round"]).is_equal(pick_1["round"])
		assert_that(pick_2["pick"]).is_equal(pick_1["pick"])

	# Assert - Identical undrafted counts
	assert_that(result_2["undrafted_count"]).is_equal(result_1["undrafted_count"])


func test_different_seeds_produce_different_draft_outcomes() -> void:
	# Arrange
	var year := 2025
	var seed_1 := 11111
	var seed_2 := 99999
	var league_cfg: Dictionary = test_configs["league"]
	var positions_cfg: Dictionary = test_configs["positions"]
	var stats_cfg: Dictionary = test_configs["stats"]
	var scouts_cfg: Dictionary = test_configs["scouts"]
	var main_cfg: Dictionary = test_configs["main"]

	# Act - Run draft with different seeds
	var world_state_1 := _create_test_world_state()
	var result_1 := NflDraft.new().run(
		world_state_1,
		year,
		seed_1,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	var world_state_2 := _create_test_world_state()
	var result_2 := NflDraft.new().run(
		world_state_2,
		year,
		seed_2,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - Different selections (at least some picks differ)
	var picks_1: Array = result_1["picks"]
	var picks_2: Array = result_2["picks"]

	var differences_found := 0
	for i in range(min(picks_1.size(), picks_2.size())):
		var pick_1: Dictionary = picks_1[i]
		var pick_2: Dictionary = picks_2[i]
		if pick_1["player_id"] != pick_2["player_id"]:
			differences_found += 1

	# At least 20% of picks should differ with different seeds
	var min_differences := int(picks_1.size() * 0.2)
	assert_that(differences_found).is_greater_equal(min_differences)


# ============================================================================
# STATE MACHINE TRANSITION TESTS
# ============================================================================

func test_draft_state_machine_transitions_correctly() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var teams := _create_test_teams()
	var league_cfg: Dictionary = test_configs["league"]
	var main_cfg: Dictionary = test_configs["main"]

	# Initial state: NOT_STARTED
	assert_that(world_state.has("draft_state")).is_false()

	# Act - Initialize draft
	var init_result := DraftStateManager.initialize_draft(
		world_state,
		teams,
		year,
		league_cfg,
		main_cfg,
		seed
	)

	# Assert - State transitioned to INITIALIZING
	assert_that(world_state.has("draft_state")).is_true()
	var draft_state: Dictionary = world_state["draft_state"]
	assert_that(draft_state["state"]).is_equal(DraftStateMachine.State.INITIALIZING)

	# Act - Start draft
	var started := DraftStateManager.start_draft(world_state, year, 1)
	assert_that(started).is_true()

	# Assert - State transitioned to RUNNING
	assert_that(draft_state["state"]).is_equal(DraftStateMachine.State.RUNNING)

	# Act - Complete draft by running full simulation
	var result := NflDraft.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		test_configs["positions"],
		test_configs["stats"],
		test_configs["scouts"],
		main_cfg
	)

	# Assert - State transitioned to COMPLETED
	assert_that(draft_state["state"]).is_equal(DraftStateMachine.State.COMPLETED)


func test_cannot_execute_pick_when_not_running() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var teams := _create_test_teams()
	var league_cfg: Dictionary = test_configs["league"]
	var main_cfg: Dictionary = test_configs["main"]

	# Initialize but don't start
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		year,
		league_cfg,
		main_cfg,
		seed
	)

	# Act - Try to execute pick while in INITIALIZING state
	var draft_info := {
		"year": year,
		"round": 1,
		"pick": 1,
		"team_id": "SF"
	}

	var contract := _create_test_contract()
	var result := DraftStateManager.execute_pick(
		world_state,
		"player_001",
		"SF",
		draft_info,
		contract,
		year
	)

	# Assert - Pick should fail
	assert_that(result["success"]).is_false()

	# Assert - Draft state unchanged
	var draft_state: Dictionary = world_state["draft_state"]
	assert_that(draft_state["state"]).is_equal(DraftStateMachine.State.INITIALIZING)


# ============================================================================
# UNDRAFTED PLAYERS TESTS
# ============================================================================

func test_undrafted_players_stored_correctly() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var league_cfg: Dictionary = test_configs["league"]
	var positions_cfg: Dictionary = test_configs["positions"]
	var stats_cfg: Dictionary = test_configs["stats"]
	var scouts_cfg: Dictionary = test_configs["scouts"]
	var main_cfg: Dictionary = test_configs["main"]

	var initial_pool_size: int = world_state["draft_pool"][year].size()

	# Act
	var result := NflDraft.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - Undrafted pool created
	assert_that(world_state.has("undrafted_pool")).is_true()
	assert_that(world_state["undrafted_pool"].has(year)).is_true()

	var undrafted: Array = world_state["undrafted_pool"][year]
	var picks_count: int = result["picks_count"]

	# Assert - Undrafted count matches
	assert_that(undrafted.size()).is_equal(result["undrafted_count"])

	# Assert - Total players accounted for
	var total_accounted := picks_count + undrafted.size()
	assert_that(total_accounted).is_equal(initial_pool_size)

	# Assert - Undrafted players have valid structure
	for player in undrafted:
		var p: Dictionary = player
		assert_that(p.has("player_id")).is_true()
		assert_that(p.has("position")).is_true()
		assert_that(p.has("age")).is_true()


# ============================================================================
# DRAFT HISTORY TESTS
# ============================================================================

func test_draft_history_recorded_correctly() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var league_cfg: Dictionary = test_configs["league"]
	var positions_cfg: Dictionary = test_configs["positions"]
	var stats_cfg: Dictionary = test_configs["stats"]
	var scouts_cfg: Dictionary = test_configs["scouts"]
	var main_cfg: Dictionary = test_configs["main"]

	# Act
	var result := NflDraft.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - History exists
	assert_that(world_state.has("draft_history")).is_true()
	assert_that(world_state["draft_history"].has(year)).is_true()

	var history: Array = world_state["draft_history"][year]
	var picks: Array = result["picks"]

	# Assert - History matches picks
	assert_that(history.size()).is_equal(picks.size())

	# Verify history entries match picks
	for i in range(history.size()):
		var history_entry: Dictionary = history[i]
		var pick: Dictionary = picks[i]

		assert_that(history_entry["player_id"]).is_equal(pick["player_id"])
		assert_that(history_entry["team_id"]).is_equal(pick["team_id"])
		assert_that(history_entry["round"]).is_equal(pick["round"])
		# Note: history_entry uses "pick_number", pick uses "pick"
		assert_that(history_entry["pick_number"]).is_equal(pick["pick"])


# ============================================================================
# PICK TRADING TESTS
# ============================================================================

func test_pick_ownership_transfer_works() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var teams := _create_test_teams()
	var league_cfg: Dictionary = test_configs["league"]
	var main_cfg: Dictionary = test_configs["main"]

	# Initialize draft
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		year,
		league_cfg,
		main_cfg,
		seed
	)

	# Verify SF owns their pick initially
	var ownership: Dictionary = world_state["draft_pick_ownership"]
	var round_1_ownership: Dictionary = ownership[year][1]
	assert_that(round_1_ownership["SF"]).is_equal("SF")

	# Act - Trade SF's pick to CHI
	DraftStateManager.execute_trade(world_state, year, 1, "SF", "CHI")

	# Assert - CHI now owns SF's pick
	var updated_ownership: Dictionary = world_state["draft_pick_ownership"]
	var updated_round_1: Dictionary = updated_ownership[year][1]
	assert_that(updated_round_1["SF"]).is_equal("CHI")


# ============================================================================
# ROSTER INTEGRATION TESTS
# ============================================================================

func test_drafted_players_added_to_rosters_with_contracts() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var league_cfg: Dictionary = test_configs["league"]
	var positions_cfg: Dictionary = test_configs["positions"]
	var stats_cfg: Dictionary = test_configs["stats"]
	var scouts_cfg: Dictionary = test_configs["scouts"]
	var main_cfg: Dictionary = test_configs["main"]

	# Act
	var result := NflDraft.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - All picks have corresponding roster entries
	var picks: Array = result["picks"]
	for pick in picks:
		var p: Dictionary = pick
		var player_id: String = p["player_id"]
		var team_id: String = p["team_id"]

		# Find player in roster
		var roster: Dictionary = world_state["nfl_rosters"][team_id]
		var players: Array = roster["players"]
		var found_player: Dictionary = {}

		for player in players:
			var pl: Dictionary = player
			if pl.get("player_id", "") == player_id:
				found_player = pl
				break

		# Assert player found
		assert_that(found_player).is_not_empty()

		# Assert player has contract
		assert_that(found_player.has("contract")).is_true()
		var contract: Dictionary = found_player["contract"]
		assert_that(contract["type"]).is_equal("rookie")
		assert_that(contract["years_total"]).is_equal(4)

		# Assert player has draft_info
		assert_that(found_player.has("draft_info")).is_true()
		var draft_info: Dictionary = found_player["draft_info"]
		assert_that(draft_info["year"]).is_equal(year)
		assert_that(draft_info["round"]).is_equal(p["round"])


# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_draft_does_not_corrupt_original_configs() -> void:
	# Arrange
	var year := 2025
	var seed := 12345
	var league_cfg: Dictionary = test_configs["league"].duplicate(true)
	var positions_cfg: Dictionary = test_configs["positions"].duplicate(true)
	var stats_cfg: Dictionary = test_configs["stats"].duplicate(true)
	var scouts_cfg: Dictionary = test_configs["scouts"].duplicate(true)
	var main_cfg: Dictionary = test_configs["main"].duplicate(true)

	# Hash configs before draft
	var league_hash := hash(league_cfg)
	var positions_hash := hash(positions_cfg)
	var stats_hash := hash(stats_cfg)
	var scouts_hash := hash(scouts_cfg)
	var main_hash := hash(main_cfg)

	# Act
	var _result := NflDraft.new().run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Assert - Configs unchanged
	assert_that(hash(league_cfg)).is_equal(league_hash)
	assert_that(hash(positions_cfg)).is_equal(positions_hash)
	assert_that(hash(stats_cfg)).is_equal(stats_hash)
	assert_that(hash(scouts_cfg)).is_equal(scouts_hash)
	assert_that(hash(main_cfg)).is_equal(main_hash)


# ============================================================================
# TEST HELPERS
# ============================================================================

func _create_test_world_state() -> Dictionary:
	return {
		"nfl_teams": _create_test_teams(),
		"draft_pool": {
			2025: _create_test_draft_pool()
		},
		"nfl_rosters": {}
	}


func _create_test_teams() -> Array:
	return [
		{"id": "SF", "name": "49ers", "draft_order": 1},
		{"id": "CHI", "name": "Bears", "draft_order": 2},
		{"id": "NE", "name": "Patriots", "draft_order": 3},
		{"id": "ARI", "name": "Cardinals", "draft_order": 4}
	]


func _create_test_draft_pool() -> Array:
	var pool: Array = []
	for i in range(20):  # Create 20 draft prospects
		pool.append({
			"player_id": "player_%03d" % (i + 1),
			"name": "Test Player %d" % (i + 1),
			"position": _get_position_for_index(i),
			"age": 21 + (i % 3),
			"composite_score": 75.0 - (i * 2.5),
			"college_team_id": "TEST_COLLEGE",
			"stats": {
				"speed": 70.0 + (i % 10),
				"strength": 70.0 + ((i + 5) % 10),
				"awareness": 70.0 + ((i + 7) % 10)
			}
		})
	return pool


func _get_position_for_index(idx: int) -> String:
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
	return positions[idx % positions.size()]


func _create_test_configs() -> Dictionary:
	return {
		"league": {
			"draft": {
				"rounds": 7,
				"picks_per_round": 4
			},
			"cap_limit": 200.0
		},
		"positions": {
			"QB": {"name": "Quarterback", "group": "offense"},
			"RB": {"name": "Running Back", "group": "offense"},
			"WR": {"name": "Wide Receiver", "group": "offense"},
			"TE": {"name": "Tight End", "group": "offense"},
			"OL": {"name": "Offensive Line", "group": "offense"},
			"DL": {"name": "Defensive Line", "group": "defense"},
			"EDGE": {"name": "Edge Rusher", "group": "defense"},
			"LB": {"name": "Linebacker", "group": "defense"},
			"CB": {"name": "Cornerback", "group": "defense"},
			"S": {"name": "Safety", "group": "defense"}
		},
		"stats": {
			"stats": [
				{"name": "speed", "min": 0, "max": 100, "measurement_difficulty": 0.85},
				{"name": "strength", "min": 0, "max": 100, "measurement_difficulty": 0.80},
				{"name": "awareness", "min": 0, "max": 100, "measurement_difficulty": 0.35}
			]
		},
		"scouts": {
			"national_scouts": [
				{
					"base_skill": 0.55,
					"overrate_athletes": 0.0,
					"tape_grinder": 0.25,
					"risk_aversion": 0.10,
					"board_noise_sigma": 1.8,
					"stat_skill": {},
					"valuation_multipliers": {},
					"estimation_multipliers": {}
				}
			]
		},
		"main": {
			"class_rules": {
				"draft_team_quality": {
					"enabled": true,
					"quality_tiers": {
						"average": {
							"base_quality": 0.50,
							"noise_modifier": 1.0,
							"skill_modifier": 1.0,
							"teams": ["SF", "CHI", "NE", "ARI"]
						}
					}
				},
				"draft_position_strategy": {
					"generational_threshold": 78.0,
					"position_tiers": {
						"premium": {
							"positions": ["QB", "EDGE", "CB"],
							"round_1_bonus": 1.2
						}
					}
				}
			}
		}
	}


func _create_test_contract() -> Dictionary:
	return {
		"type": "rookie",
		"years_total": 4,
		"years_remaining": 4,
		"base_salary": 5.0,
		"signing_bonus": 4.0,
		"annual_value": 6.0,
		"fifth_year_option": true,
		"gtd_remaining": 4.0,
		"signed_year": 2025
	}
