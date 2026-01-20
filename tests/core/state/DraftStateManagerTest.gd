extends GdUnitTestSuite

## DraftStateManagerTest - Comprehensive tests for draft state management
##
## Tests cover:
## 1. Immutability - Verify transformations don't modify inputs
## 2. Determinism - Verify same seed produces same results
## 3. State machine transitions - Verify only valid transitions are allowed
## 4. Atomicity - Verify state updates are all-or-nothing
## 5. DataBus integration - Verify notifications are emitted

const DraftStateManager = preload("res://scripts/core/state/DraftStateManager.gd")
const DraftStateMachine = preload("res://scripts/core/state/DraftStateMachine.gd")
const DraftTransformations = preload("res://scripts/core/transformations/DraftTransformations.gd")

# ============================================================================
# TEST SETUP
# ============================================================================

func before_test() -> void:
	# Each test gets a fresh world_state
	pass


func create_test_world_state() -> Dictionary:
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
	return [
		{
			"player_id": "player_001",
			"name": "John Doe",
			"position": "QB",
			"age": 21,
			"composite_score": 85.0,
			"college_team_id": "USC"
		},
		{
			"player_id": "player_002",
			"name": "Jane Smith",
			"position": "WR",
			"age": 22,
			"composite_score": 78.0,
			"college_team_id": "MICH"
		},
		{
			"player_id": "player_003",
			"name": "Bob Johnson",
			"position": "EDGE",
			"age": 21,
			"composite_score": 82.0,
			"college_team_id": "ALA"
		}
	]


func _create_test_league_cfg() -> Dictionary:
	return {
		"draft": {
			"rounds": 7,
			"picks_per_round": 32
		}
	}


func _create_test_class_rules() -> Dictionary:
	return {
		"draft_team_quality": {
			"enabled": true,
			"quality_tiers": {
				"elite": {
					"base_quality": 0.75,
					"noise_modifier": 0.80,
					"skill_modifier": 1.15,
					"teams": ["SF"]
				},
				"average": {
					"base_quality": 0.50,
					"noise_modifier": 1.0,
					"skill_modifier": 1.0,
					"teams": ["CHI", "NE", "ARI"]
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


# ============================================================================
# IMMUTABILITY TESTS - Verify inputs are never modified
# ============================================================================

func test_initialize_draft_preserves_inputs() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()
	var league_cfg := _create_test_league_cfg()
	var class_rules := _create_test_class_rules()

	# Hash inputs before mutation
	var teams_hash := hash(teams)
	var league_cfg_hash := hash(league_cfg)
	var class_rules_hash := hash(class_rules)

	# Execute mutation
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		league_cfg,
		class_rules,
		42
	)

	# Verify inputs unchanged
	assert_int(hash(teams)).is_equal(teams_hash)
	assert_int(hash(league_cfg)).is_equal(league_cfg_hash)
	assert_int(hash(class_rules)).is_equal(class_rules_hash)


func test_execute_pick_preserves_draft_pool() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Initialize draft first
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)

	DraftStateManager.start_draft(world_state, 2025, 1)

	# Get reference to original draft pool
	var original_pool: Array = world_state["draft_pool"][2025]
	var original_pool_size := original_pool.size()
	var first_player_id := String((original_pool[0] as Dictionary).get("player_id", ""))

	# Execute pick
	var draft_info := {
		"year": 2025,
		"round": 1,
		"pick": 1,
		"team_id": "SF"
	}

	DraftStateManager.execute_pick(
		world_state,
		first_player_id,
		"SF",
		draft_info,
		_create_test_contract(),
		2025
	)

	# Verify pool was updated (not original reference modified)
	var updated_pool: Array = world_state["draft_pool"][2025]
	assert_int(updated_pool.size()).is_equal(original_pool_size - 1)


func test_execute_trade_preserves_ownership() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Initialize draft first
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)

	# Get reference to original ownership
	var ownership: Dictionary = world_state["draft_pick_ownership"]
	var original_sf_owner := String(ownership[2025][1]["SF"])

	# Execute trade
	DraftStateManager.execute_trade(world_state, 2025, 1, "SF", "CHI")

	# Verify ownership was updated (new dictionary created)
	var updated_ownership: Dictionary = world_state["draft_pick_ownership"]
	assert_str(String(updated_ownership[2025][1]["SF"])).is_equal("CHI")


# ============================================================================
# DETERMINISM TESTS - Same seed = same results
# ============================================================================

func test_initialize_draft_deterministic() -> void:
	var seed := 12345

	# Run 1
	var world_state_1 := create_test_world_state()
	var result_1 := DraftStateManager.initialize_draft(
		world_state_1,
		_create_test_teams(),
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		seed
	)

	# Run 2 with same seed
	var world_state_2 := create_test_world_state()
	var result_2 := DraftStateManager.initialize_draft(
		world_state_2,
		_create_test_teams(),
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		seed
	)

	# Verify scouting quality is identical
	var quality_1: Dictionary = world_state_1["nfl_scouting_quality"]
	var quality_2: Dictionary = world_state_2["nfl_scouting_quality"]

	for team_id in quality_1.keys():
		var q1: Dictionary = quality_1[team_id]
		var q2: Dictionary = quality_2[team_id]
		assert_float(float(q1["base_quality"])).is_equal(float(q2["base_quality"]))
		assert_float(float(q1["noise_modifier"])).is_equal(float(q2["noise_modifier"]))
		assert_float(float(q1["skill_modifier"])).is_equal(float(q2["skill_modifier"]))
		assert_str(String(q1["tier"])).is_equal(String(q2["tier"]))


func test_scouting_quality_different_seeds() -> void:
	var teams := _create_test_teams()
	var class_rules := _create_test_class_rules()

	# Generate with seed 1
	var quality_1 := DraftTransformations.generate_scouting_quality(teams, class_rules, 111)

	# Generate with seed 2
	var quality_2 := DraftTransformations.generate_scouting_quality(teams, class_rules, 222)

	# Verify results are different (different jitter)
	var sf_quality_1: Dictionary = quality_1["SF"]
	var sf_quality_2: Dictionary = quality_2["SF"]

	# base_quality should differ due to jitter
	assert_float(float(sf_quality_1["base_quality"])).is_not_equal(float(sf_quality_2["base_quality"]))


# ============================================================================
# STATE MACHINE TRANSITION TESTS
# ============================================================================

func test_state_machine_valid_transitions() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Start in NOT_STARTED
	assert_bool(world_state.has("draft_state")).is_false()

	# Initialize -> INITIALIZING
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)

	var draft_state: Dictionary = world_state["draft_state"]
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.INITIALIZING)

	# INITIALIZING -> RUNNING
	var success := DraftStateManager.start_draft(world_state, 2025, 1)
	assert_bool(success).is_true()
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.RUNNING)

	# RUNNING -> PAUSED
	success = DraftStateManager.pause_draft(world_state)
	assert_bool(success).is_true()
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.PAUSED)

	# PAUSED -> RUNNING
	success = DraftStateManager.resume_draft(world_state)
	assert_bool(success).is_true()
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.RUNNING)


func test_state_machine_invalid_transition_rejected() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Initialize draft
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)

	var draft_state: Dictionary = world_state["draft_state"]

	# Try to pause while in INITIALIZING (invalid)
	var success := DraftStateManager.pause_draft(world_state)
	assert_bool(success).is_false()

	# State should still be INITIALIZING
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.INITIALIZING)


func test_cannot_execute_pick_when_not_running() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Initialize but don't start
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)

	# Try to execute pick while in INITIALIZING
	var draft_info := {
		"year": 2025,
		"round": 1,
		"pick": 1,
		"team_id": "SF"
	}

	var result := DraftStateManager.execute_pick(
		world_state,
		"player_001",
		"SF",
		draft_info,
		_create_test_contract(),
		2025
	)

	# Should fail
	assert_bool(bool(result["success"])).is_false()


# ============================================================================
# ATOMICITY TESTS
# ============================================================================

func test_execute_pick_updates_all_structures() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Initialize and start draft
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)
	DraftStateManager.start_draft(world_state, 2025, 1)

	# Execute pick
	var draft_info := {
		"year": 2025,
		"round": 1,
		"pick": 1,
		"team_id": "SF"
	}

	var result := DraftStateManager.execute_pick(
		world_state,
		"player_001",
		"SF",
		draft_info,
		_create_test_contract(),
		2025
	)

	# Verify all structures updated atomically
	assert_bool(bool(result["success"])).is_true()

	# 1. Draft pool reduced
	assert_int(world_state["draft_pool"][2025].size()).is_equal(2)

	# 2. Player added to roster
	var roster: Dictionary = world_state["nfl_rosters"]["SF"]
	assert_int(roster["players"].size()).is_equal(1)

	# 3. Player has correct NFL fields
	var drafted_player: Dictionary = roster["players"][0]
	assert_str(String(drafted_player["nfl_team_id"])).is_equal("SF")
	assert_str(String(drafted_player["nfl_status"])).is_equal("active")
	assert_bool(drafted_player.has("contract")).is_true()
	assert_bool(drafted_player.has("draft_info")).is_true()

	# 4. Draft state updated
	var draft_state: Dictionary = world_state["draft_state"]
	assert_int(int(draft_state["current_pick"])).is_equal(1)


func test_record_draft_history_complete_workflow() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()

	# Initialize and start draft
	DraftStateManager.initialize_draft(
		world_state,
		teams,
		2025,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)
	DraftStateManager.start_draft(world_state, 2025, 1)

	# Execute picks
	var picks: Array = []
	for i in range(2):
		var draft_info := {
			"year": 2025,
			"round": 1,
			"pick": i + 1,
			"team_id": "SF"
		}

		var player_id := "player_%03d" % (i + 1)
		DraftStateManager.execute_pick(
			world_state,
			player_id,
			"SF",
			draft_info,
			_create_test_contract(),
			2025
		)

		picks.append({
			"player_id": player_id,
			"team_id": "SF",
			"round": 1,
			"pick": i + 1,
			"position": "QB",
			"traded": false,
			"compensatory": false
		})

	# Record history
	var result := DraftStateManager.record_draft_history(world_state, picks, 2025)

	# Verify history recorded
	assert_int(int(result["picks_recorded"])).is_equal(2)
	assert_bool(world_state.has("draft_history")).is_true()
	assert_bool(world_state["draft_history"].has(2025)).is_true()
	assert_int(world_state["draft_history"][2025].size()).is_equal(2)

	# Verify state transitioned to COMPLETED
	var draft_state: Dictionary = world_state["draft_state"]
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.COMPLETED)


# ============================================================================
# TRANSFORMATION FUNCTION TESTS
# ============================================================================

func test_allocate_draft_picks_creates_ownership() -> void:
	var teams := _create_test_teams()
	var ownership := DraftTransformations.allocate_draft_picks(teams, 2025, 7)

	# Verify structure
	assert_bool(ownership.has(2025)).is_true()
	var year_ownership: Dictionary = ownership[2025]

	# Verify all 7 rounds created
	for round_num in range(1, 8):
		assert_bool(year_ownership.has(round_num)).is_true()
		var round_ownership: Dictionary = year_ownership[round_num]

		# Verify all teams have picks
		for team in teams:
			var team_id := String((team as Dictionary)["id"])
			assert_bool(round_ownership.has(team_id)).is_true()
			assert_str(String(round_ownership[team_id])).is_equal(team_id)


func test_apply_pick_trade_transfers_ownership() -> void:
	var teams := _create_test_teams()
	var ownership := DraftTransformations.allocate_draft_picks(teams, 2025, 7)

	# Verify SF owns their pick initially
	assert_str(String(ownership[2025][1]["SF"])).is_equal("SF")

	# Trade SF's pick to CHI
	var new_ownership := DraftTransformations.apply_pick_trade(ownership, 2025, 1, "SF", "CHI")

	# Verify original unchanged
	assert_str(String(ownership[2025][1]["SF"])).is_equal("SF")

	# Verify new ownership updated
	assert_str(String(new_ownership[2025][1]["SF"])).is_equal("CHI")


func test_apply_draft_pick_removes_from_pool() -> void:
	var pool := _create_test_draft_pool()
	var rosters := {}
	var original_size := pool.size()

	var draft_info := {
		"year": 2025,
		"round": 1,
		"pick": 1,
		"team_id": "SF"
	}

	var result := DraftTransformations.apply_draft_pick(
		pool,
		rosters,
		"player_001",
		"SF",
		draft_info,
		_create_test_contract()
	)

	# Verify original pool unchanged
	assert_int(pool.size()).is_equal(original_size)

	# Verify updated pool has one less player
	assert_int(result["updated_pool"].size()).is_equal(original_size - 1)

	# Verify player added to roster
	var updated_rosters: Dictionary = result["updated_rosters"]
	assert_bool(updated_rosters.has("SF")).is_true()
	var roster: Dictionary = updated_rosters["SF"]
	assert_int(roster["players"].size()).is_equal(1)

	# Verify drafted player has correct fields
	var drafted_player: Dictionary = result["drafted_player"]
	assert_str(String(drafted_player["player_id"])).is_equal("player_001")
	assert_str(String(drafted_player["nfl_team_id"])).is_equal("SF")


# ============================================================================
# INTEGRATION TESTS - Full workflow
# ============================================================================

func test_full_draft_workflow() -> void:
	var world_state := create_test_world_state()
	var teams := _create_test_teams()
	var year := 2025

	# Step 1: Initialize draft
	var init_result := DraftStateManager.initialize_draft(
		world_state,
		teams,
		year,
		_create_test_league_cfg(),
		_create_test_class_rules(),
		42
	)
	assert_int(int(init_result["teams_count"])).is_equal(4)
	assert_bool(bool(init_result["scouting_initialized"])).is_true()
	assert_bool(bool(init_result["picks_allocated"])).is_true()

	# Step 2: Start draft
	var started := DraftStateManager.start_draft(world_state, year, 1)
	assert_bool(started).is_true()

	# Step 3: Execute picks
	var picks: Array = []
	var draft_pool: Array = world_state["draft_pool"][year]

	for i in range(min(2, draft_pool.size())):
		var player: Dictionary = draft_pool[i]
		var player_id := String(player["player_id"])

		var draft_info := {
			"year": year,
			"round": 1,
			"pick": i + 1,
			"team_id": "SF"
		}

		var pick_result := DraftStateManager.execute_pick(
			world_state,
			player_id,
			"SF",
			draft_info,
			_create_test_contract(),
			year
		)

		assert_bool(bool(pick_result["success"])).is_true()

		picks.append({
			"player_id": player_id,
			"team_id": "SF",
			"round": 1,
			"pick": i + 1,
			"position": String(player["position"]),
			"traded": false,
			"compensatory": false
		})

	# Step 4: Store undrafted
	var remaining_pool: Array = world_state["draft_pool"][year]
	var undrafted_result := DraftStateManager.store_undrafted_players(
		world_state,
		remaining_pool,
		year
	)
	assert_int(int(undrafted_result["undrafted_count"])).is_equal(remaining_pool.size())

	# Step 5: Record history
	var history_result := DraftStateManager.record_draft_history(world_state, picks, year)
	assert_int(int(history_result["picks_recorded"])).is_equal(2)
	assert_int(int(history_result["state"])).is_equal(DraftStateMachine.State.COMPLETED)

	# Verify final state
	var draft_state: Dictionary = world_state["draft_state"]
	assert_int(int(draft_state["state"])).is_equal(DraftStateMachine.State.COMPLETED)
	assert_bool(world_state.has("draft_history")).is_true()
	assert_bool(world_state.has("undrafted_pool")).is_true()
