extends GdUnitTestSuite

## CrossSystemIntegrationTest - Integration tests for cross-system interactions
##
## Tests interactions between refactored systems:
## 1. Draft → Free Agency flow (UDFAs)
## 2. Season → Contract flow (contract expirations)
## 3. Full year cycle: Season → Draft → Free Agency
## 4. Data consistency across system boundaries
## 5. Determinism across full simulation cycles

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const FreeAgency = preload("res://scripts/world/FreeAgency.gd")
const DraftStateManager = preload("res://scripts/core/state/DraftStateManager.gd")
const SeasonStateManager = preload("res://scripts/core/state/SeasonStateManager.gd")
const ContractStateManager = preload("res://scripts/core/state/ContractStateManager.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# TEST SETUP
# ============================================================================

var world_state: Dictionary
var test_configs: Dictionary

func before_test() -> void:
	world_state = _create_comprehensive_world_state()
	test_configs = _create_test_configs()

func after_test() -> void:
	world_state.clear()
	test_configs.clear()

# ============================================================================
# DRAFT → FREE AGENCY FLOW
# ============================================================================

func test_undrafted_players_flow_to_free_agency() -> void:
	# Arrange
	var year := 2025
	var seed := 12345

	# Run draft first
	var draft_result := NflDraft.new().run(
		world_state,
		year,
		seed,
		test_configs["league"],
		test_configs["positions"],
		test_configs["stats"],
		test_configs["scouts"],
		test_configs["main"]
	)

	# Verify UDFAs created
	assert_that(world_state.has("undrafted_pool")).is_true()
	assert_that(world_state["undrafted_pool"].has(year)).is_true()

	var undrafted_count: int = draft_result["undrafted_count"]
	assert_that(undrafted_count).is_greater(0)

	# Act - Run free agency
	var fa_result := FreeAgency.run_free_agency(
		world_state,
		year,
		seed + 1000,  # Different seed
		test_configs["positions"],
		test_configs["main"],
		test_configs["stats"],
		test_configs["league"]
	)

	# Assert - Some UDFAs should be available to sign
	# (May or may not be signed depending on team needs)
	var signings: Array = fa_result["signings"]
	assert_that(fa_result).is_not_null()
	assert_that(signings).is_not_null()


func test_drafted_players_have_valid_contracts_for_fa() -> void:
	# Arrange
	var year := 2025
	var seed := 12345

	# Run draft
	var draft_result := NflDraft.new().run(
		world_state,
		year,
		seed,
		test_configs["league"],
		test_configs["positions"],
		test_configs["stats"],
		test_configs["scouts"],
		test_configs["main"]
	)

	var picks: Array = draft_result["picks"]
	assert_that(picks.size()).is_greater(0)

	# Verify drafted players have contracts that will eventually expire
	for pick in picks:
		var p: Dictionary = pick
		var player_id: String = p["player_id"]
		var team_id: String = p["team_id"]

		var roster: Dictionary = world_state["nfl_rosters"][team_id]
		var player := _find_player_in_roster(roster, player_id)

		assert_that(player).is_not_empty()
		assert_that(player.has("contract")).is_true()

		var contract: Dictionary = player["contract"]
		assert_that(contract["type"]).is_equal("rookie")
		assert_that(contract["years_total"]).is_equal(4)
		assert_that(contract["years_remaining"]).is_equal(4)


# ============================================================================
# SEASON → CONTRACT FLOW
# ============================================================================

func test_season_expiration_creates_free_agents() -> void:
	# Arrange
	var year := 2033
	var seed := 12345

	# Add players with expiring contracts
	var roster: Dictionary = world_state["nfl_rosters"]["SF"]
	roster["players"].append({
		"player_id": "expiring_player_1",
		"name": "Expiring Player 1",
		"position": "RB",
		"age": 28,
		"stats": {"speed": 80.0, "strength": 75.0},
		"contract": {
			"status": "signed",
			"years_remaining": 1,  # Will expire this season
			"annual_value": 8.0
		}
	})

	# Act - Run season
	var season_result := NflSeason.new().run(
		world_state,
		year,
		seed,
		test_configs["league"],
		test_configs["positions"],
		test_configs["main"],
		test_configs["stats"],
		{"skip_trades": true}
	)

	# Assert - Player became free agent
	var free_agents_count: int = season_result["free_agents"]
	assert_that(free_agents_count).is_greater(0)

	# Verify free agents stored
	assert_that(world_state.has("free_agents")).is_true()
	assert_that(world_state["free_agents"].has(year)).is_true()


# ============================================================================
# FULL YEAR CYCLE
# ============================================================================

func test_full_year_cycle_season_draft_free_agency() -> void:
	# This test simulates a complete year cycle:
	# 1. College Season (generates draft-eligible players)
	# 2. NFL Draft (drafts players, creates UDFAs)
	# 3. Free Agency (signs veterans and UDFAs)

	# Arrange
	var year := 2025
	var base_seed := 42

	# Step 1: College Season
	var college_result := CollegeSeason.new().run(
		world_state,
		year,
		base_seed,
		test_configs["league"],
		test_configs["positions"],
		test_configs["main"],
		test_configs["stats"]
	)

	assert_that(college_result).is_not_null()
	var draft_eligible_count: int = college_result.get("draft_eligible_count", 0)
	assert_that(draft_eligible_count).is_greater(0)

	# Verify draft pool created
	assert_that(world_state.has("draft_pool")).is_true()
	assert_that(world_state["draft_pool"].has(year)).is_true()
	var draft_pool: Array = world_state["draft_pool"][year]
	assert_that(draft_pool.size()).is_greater(0)

	# Step 2: NFL Draft
	var draft_result := NflDraft.new().run(
		world_state,
		year,
		base_seed + 1000,
		test_configs["league"],
		test_configs["positions"],
		test_configs["stats"],
		test_configs["scouts"],
		test_configs["main"]
	)

	assert_that(draft_result).is_not_null()
	var picks_count: int = draft_result["picks_count"]
	var undrafted_count: int = draft_result["undrafted_count"]
	assert_that(picks_count).is_greater(0)
	assert_that(undrafted_count).is_greater(0)

	# Verify draft history recorded
	assert_that(world_state.has("draft_history")).is_true()
	assert_that(world_state["draft_history"].has(year)).is_true()

	# Step 3: Free Agency
	var fa_result := FreeAgency.run_free_agency(
		world_state,
		year,
		base_seed + 2000,
		test_configs["positions"],
		test_configs["main"],
		test_configs["stats"],
		test_configs["league"]
	)

	assert_that(fa_result).is_not_null()
	var signings: Array = fa_result["signings"]
	assert_that(signings.size()).is_greater(0)

	# Assert - Full cycle completed successfully
	# All three major systems executed without errors
	assert_that(college_result["year"]).is_equal(year)
	assert_that(draft_result["year"]).is_equal(year)
	assert_that(fa_result["year"]).is_equal(year)


func test_full_year_cycle_determinism() -> void:
	# Test that running the full cycle with same seed produces identical results

	# Arrange
	var year := 2025
	var base_seed := 99999

	# Run cycle 1
	var world_state_1 := _create_comprehensive_world_state()
	var _college_1 := CollegeSeason.new().run(
		world_state_1, year, base_seed,
		test_configs["league"], test_configs["positions"],
		test_configs["main"], test_configs["stats"]
	)
	var draft_1 := NflDraft.new().run(
		world_state_1, year, base_seed + 1000,
		test_configs["league"], test_configs["positions"],
		test_configs["stats"], test_configs["scouts"], test_configs["main"]
	)
	var fa_1 := FreeAgency.run_free_agency(
		world_state_1, year, base_seed + 2000,
		test_configs["positions"], test_configs["main"],
		test_configs["stats"], test_configs["league"]
	)

	# Run cycle 2 with same seeds
	var world_state_2 := _create_comprehensive_world_state()
	var _college_2 := CollegeSeason.new().run(
		world_state_2, year, base_seed,
		test_configs["league"], test_configs["positions"],
		test_configs["main"], test_configs["stats"]
	)
	var draft_2 := NflDraft.new().run(
		world_state_2, year, base_seed + 1000,
		test_configs["league"], test_configs["positions"],
		test_configs["stats"], test_configs["scouts"], test_configs["main"]
	)
	var fa_2 := FreeAgency.run_free_agency(
		world_state_2, year, base_seed + 2000,
		test_configs["positions"], test_configs["main"],
		test_configs["stats"], test_configs["league"]
	)

	# Assert - Draft results identical
	assert_that(draft_2["picks_count"]).is_equal(draft_1["picks_count"])
	assert_that(draft_2["undrafted_count"]).is_equal(draft_1["undrafted_count"])

	var picks_1: Array = draft_1["picks"]
	var picks_2: Array = draft_2["picks"]
	assert_that(picks_2.size()).is_equal(picks_1.size())

	for i in range(picks_1.size()):
		var p1: Dictionary = picks_1[i]
		var p2: Dictionary = picks_2[i]
		assert_that(p2["player_id"]).is_equal(p1["player_id"])
		assert_that(p2["team_id"]).is_equal(p1["team_id"])

	# Assert - FA results identical
	var signings_1: Array = fa_1["signings"]
	var signings_2: Array = fa_2["signings"]
	assert_that(signings_2.size()).is_equal(signings_1.size())


# ============================================================================
# DATA CONSISTENCY TESTS
# ============================================================================

func test_player_ids_consistent_across_systems() -> void:
	# Test that player IDs remain consistent as players move through systems

	# Arrange
	var year := 2025
	var seed := 12345

	# Run college season to create draft pool
	var _college_result := CollegeSeason.new().run(
		world_state,
		year,
		seed,
		test_configs["league"],
		test_configs["positions"],
		test_configs["main"],
		test_configs["stats"]
	)

	# Get player IDs from draft pool
	var draft_pool: Array = world_state["draft_pool"][year]
	var original_player_ids: Array = []
	for player in draft_pool:
		var p: Dictionary = player
		original_player_ids.append(p["player_id"])

	# Run draft
	var draft_result := NflDraft.new().run(
		world_state,
		year,
		seed + 1000,
		test_configs["league"],
		test_configs["positions"],
		test_configs["stats"],
		test_configs["scouts"],
		test_configs["main"]
	)

	# Verify drafted players have same IDs
	var picks: Array = draft_result["picks"]
	for pick in picks:
		var p: Dictionary = pick
		var player_id: String = p["player_id"]

		# Player ID should be from original pool
		assert_that(original_player_ids.has(player_id)).is_true()

		# Player should exist in roster with same ID
		var team_id: String = p["team_id"]
		var roster: Dictionary = world_state["nfl_rosters"][team_id]
		var player := _find_player_in_roster(roster, player_id)
		assert_that(player).is_not_empty()
		assert_that(player["player_id"]).is_equal(player_id)


func test_world_state_structure_maintained_across_systems() -> void:
	# Test that world_state structure remains valid after all operations

	# Arrange
	var year := 2025
	var seed := 12345

	# Run full cycle
	var _college := CollegeSeason.new().run(
		world_state, year, seed,
		test_configs["league"], test_configs["positions"],
		test_configs["main"], test_configs["stats"]
	)
	var _draft := NflDraft.new().run(
		world_state, year, seed + 1000,
		test_configs["league"], test_configs["positions"],
		test_configs["stats"], test_configs["scouts"], test_configs["main"]
	)
	var _fa := FreeAgency.run_free_agency(
		world_state, year, seed + 2000,
		test_configs["positions"], test_configs["main"],
		test_configs["stats"], test_configs["league"]
	)

	# Assert - All expected keys present
	assert_that(world_state.has("nfl_teams")).is_true()
	assert_that(world_state.has("nfl_rosters")).is_true()
	assert_that(world_state.has("college_rosters")).is_true()
	assert_that(world_state.has("draft_pool")).is_true()
	assert_that(world_state.has("undrafted_pool")).is_true()
	assert_that(world_state.has("draft_history")).is_true()
	assert_that(world_state.has("free_agents")).is_true()

	# Assert - Rosters are dictionaries
	assert_that(world_state["nfl_rosters"] is Dictionary).is_true()
	assert_that(world_state["college_rosters"] is Dictionary).is_true()

	# Assert - Arrays are arrays
	assert_that(world_state["nfl_teams"] is Array).is_true()


# ============================================================================
# ROSTER CONTINUITY TESTS
# ============================================================================

func test_roster_sizes_remain_valid_across_cycle() -> void:
	# Test that roster sizes stay within valid bounds throughout full cycle

	# Arrange
	var year := 2025
	var seed := 12345
	var roster_limit := 53

	# Record initial roster sizes
	var initial_sizes: Dictionary = {}
	for team_id in world_state["nfl_rosters"].keys():
		var roster: Dictionary = world_state["nfl_rosters"][team_id]
		initial_sizes[team_id] = roster["players"].size()

	# Run full cycle
	var _college := CollegeSeason.new().run(
		world_state, year, seed,
		test_configs["league"], test_configs["positions"],
		test_configs["main"], test_configs["stats"]
	)
	var _draft := NflDraft.new().run(
		world_state, year, seed + 1000,
		test_configs["league"], test_configs["positions"],
		test_configs["stats"], test_configs["scouts"], test_configs["main"]
	)
	var _fa := FreeAgency.run_free_agency(
		world_state, year, seed + 2000,
		test_configs["positions"], test_configs["main"],
		test_configs["stats"], test_configs["league"]
	)

	# Assert - Roster sizes valid
	for team_id in world_state["nfl_rosters"].keys():
		var roster: Dictionary = world_state["nfl_rosters"][team_id]
		var current_size := roster["players"].size()

		# Should not exceed roster limit
		assert_that(current_size).is_less_equal(roster_limit)

		# Should have at least some players
		assert_that(current_size).is_greater(0)


# ============================================================================
# STATE MACHINE COORDINATION TESTS
# ============================================================================

func test_state_machines_coordinate_correctly() -> void:
	# Test that different state machines (Draft, Season, Contract) don't conflict

	# Arrange
	var year := 2025
	var seed := 12345

	# Initialize draft state
	DraftStateManager.initialize_draft(
		world_state,
		world_state["nfl_teams"],
		year,
		test_configs["league"],
		test_configs["main"],
		seed
	)

	# Initialize season state
	world_state["nfl_season_state"] = {
		"phase": 0,  # PRE_SEASON
		"year": year
	}

	# Run draft
	var _draft := NflDraft.new().run(
		world_state, year, seed,
		test_configs["league"], test_configs["positions"],
		test_configs["stats"], test_configs["scouts"], test_configs["main"]
	)

	# Run FA
	var _fa := FreeAgency.run_free_agency(
		world_state, year, seed + 1000,
		test_configs["positions"], test_configs["main"],
		test_configs["stats"], test_configs["league"]
	)

	# Assert - Both state machines in valid states
	var draft_state: Dictionary = world_state["draft_state"]
	assert_that(draft_state["state"]).is_equal(2)  # COMPLETED

	# Season state unchanged (FA doesn't modify it)
	var season_state: Dictionary = world_state["nfl_season_state"]
	assert_that(season_state.has("phase")).is_true()


# ============================================================================
# TEST HELPERS
# ============================================================================

func _create_comprehensive_world_state() -> Dictionary:
	return {
		"nfl_teams": _create_test_nfl_teams(),
		"nfl_rosters": _create_test_nfl_rosters(),
		"college_rosters": _create_test_college_rosters(),
		"high_school_rosters": {},
		"draft_pool": {},
		"undrafted_pool": {},
		"draft_history": {},
		"free_agents": {},
		"franchise_tags": {},
		"retired_players": [],
		"nfl_standings": {
			2025: {}
		}
	}


func _create_test_nfl_teams() -> Array:
	return [
		{"id": "SF", "name": "49ers", "cap_space": 50.0},
		{"id": "KC", "name": "Chiefs", "cap_space": 45.0},
		{"id": "BUF", "name": "Bills", "cap_space": 40.0},
		{"id": "DAL", "name": "Cowboys", "cap_space": 38.0}
	]


func _create_test_nfl_rosters() -> Dictionary:
	return {
		"SF": {
			"team_id": "SF",
			"roster_limit": 53,
			"players": _create_test_nfl_players("SF", 3)
		},
		"KC": {
			"team_id": "KC",
			"roster_limit": 53,
			"players": _create_test_nfl_players("KC", 3)
		},
		"BUF": {
			"team_id": "BUF",
			"roster_limit": 53,
			"players": _create_test_nfl_players("BUF", 3)
		},
		"DAL": {
			"team_id": "DAL",
			"roster_limit": 53,
			"players": _create_test_nfl_players("DAL", 3)
		}
	}


func _create_test_nfl_players(team_id: String, count: int) -> Array:
	var players: Array = []
	for i in range(count):
		players.append({
			"player_id": "%s_player_%d" % [team_id, i],
			"name": "Player %d" % i,
			"position": ["QB", "RB", "WR"][i % 3],
			"age": 25 + i,
			"stats": {"speed": 75.0, "strength": 70.0},
			"contract": {
				"status": "signed",
				"years_remaining": 2,
				"annual_value": 8.0
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
					"name": "Senior QB",
					"position": "QB",
					"age": 22,
					"college_year": 4,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 78.0, "strength": 72.0},
					"composite_score": 75.0
				},
				{
					"player_id": "college_senior_2",
					"name": "Senior RB",
					"position": "RB",
					"age": 22,
					"college_year": 4,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 82.0, "strength": 75.0},
					"composite_score": 73.0
				},
				{
					"player_id": "college_junior_1",
					"name": "Junior WR",
					"position": "WR",
					"age": 21,
					"college_year": 3,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 85.0, "strength": 68.0},
					"composite_score": 72.0
				}
			]
		},
		"Ohio_State": {
			"school_id": "Ohio_State",
			"players": [
				{
					"player_id": "college_senior_3",
					"name": "Senior TE",
					"position": "TE",
					"age": 22,
					"college_year": 4,
					"stage": Player.PlayerStage.COLLEGE,
					"stats": {"speed": 76.0, "strength": 80.0},
					"composite_score": 71.0
				}
			]
		}
	}


func _create_test_configs() -> Dictionary:
	return {
		"league": {
			"draft": {
				"rounds": 7,
				"picks_per_round": 4
			},
			"season": {
				"regular_season_weeks": 17
			},
			"cap_limit": 180.0,
			"franchise_tag": {
				"exclusive_multiplier": 1.2
			}
		},
		"positions": {
			"QB": {"name": "Quarterback", "group": "offense"},
			"RB": {"name": "Running Back", "group": "offense"},
			"WR": {"name": "Wide Receiver", "group": "offense"},
			"TE": {"name": "Tight End", "group": "offense"},
			"OL": {"name": "Offensive Line", "group": "offense"}
		},
		"stats": {
			"stats": [
				{"name": "speed", "min": 0, "max": 100, "measurement_difficulty": 0.85},
				{"name": "strength", "min": 0, "max": 100, "measurement_difficulty": 0.80}
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
			"simulation_enabled": true,
			"free_agency": {
				"enabled": true
			},
			"class_rules": {
				"draft_team_quality": {
					"enabled": true,
					"quality_tiers": {
						"average": {
							"base_quality": 0.50,
							"noise_modifier": 1.0,
							"skill_modifier": 1.0,
							"teams": ["SF", "KC", "BUF", "DAL"]
						}
					}
				},
				"draft_position_strategy": {
					"generational_threshold": 78.0,
					"position_tiers": {}
				},
				"draft_eligibility": {
					"min_class_year": 3,
					"min_age": 21,
					"opt_in_chance": 0.3
				}
			}
		}
	}


func _find_player_in_roster(roster: Dictionary, player_id: String) -> Dictionary:
	var players: Array = roster.get("players", [])
	for player in players:
		var p: Dictionary = player
		if p.get("player_id", "") == player_id:
			return p
	return {}
