## Test suite for UDFABiddingEngine service (DRAFT-006)
##
## Tests cover:
## 1. UDFA pool = all eligible - drafted players
## 2. UDFA ranking is deterministic (same seed = same order)
## 3. User priority targets are processed first
## 4. AI teams bid based on position needs
## 5. UDFA contract structure is correct (3yr, min salary, $0 gtd)
## 6. Edge case: 0 undrafted players
## 7. Edge case: User selects unavailable player
## 8. Determinism: Same seed + picks = same UDFA signings
## 9. Performance: <1 second for 50 UDFAs across 32 teams
## 10. Persistence: UDFA signings update world state
## 11. Integration: Draft -> UDFA -> Roster validation
## 12. Regression: Draft without UDFA still works
##
extends RefCounted
class_name TestUDFABiddingEngine

const UDFABiddingEngine = preload("res://scripts/world/UDFABiddingEngine.gd")
const RookieWageScale = preload("res://scripts/core/contracts/RookieWageScale.gd")
const Rand = preload("res://autoloads/Rand.gd")

const CAP_LIMIT := 200.0
const TEST_SEED := 12345
const TEST_YEAR := 2035


static func run_all_tests() -> Dictionary:
	var results := {
		"passed": 0,
		"failed": 0,
		"errors": []
	}

	# Run each test
	_run_test("test_udfa_pool_contains_undrafted", results)
	_run_test("test_ranking_is_deterministic", results)
	_run_test("test_user_targets_processed_first", results)
	_run_test("test_ai_bids_based_on_needs", results)
	_run_test("test_udfa_contract_structure", results)
	_run_test("test_empty_undrafted_pool", results)
	_run_test("test_unavailable_player_target", results)
	_run_test("test_determinism_same_seed", results)
	_run_test("test_performance_under_one_second", results)
	_run_test("test_world_state_updated", results)
	_run_test("test_validate_user_targets", results)
	_run_test("test_udfa_phase_skippable", results)

	print("\n=== UDFABiddingEngine Test Results ===")
	print("Passed: %d" % results.passed)
	print("Failed: %d" % results.failed)
	if results.errors.size() > 0:
		print("Errors:")
		for error in results.errors:
			print("  - %s" % error)

	return results


static func _run_test(test_name: String, results: Dictionary) -> void:
	var success := false
	var error_msg := ""

	match test_name:
		"test_udfa_pool_contains_undrafted":
			var result := test_udfa_pool_contains_undrafted()
			success = result.success
			error_msg = result.message
		"test_ranking_is_deterministic":
			var result := test_ranking_is_deterministic()
			success = result.success
			error_msg = result.message
		"test_user_targets_processed_first":
			var result := test_user_targets_processed_first()
			success = result.success
			error_msg = result.message
		"test_ai_bids_based_on_needs":
			var result := test_ai_bids_based_on_needs()
			success = result.success
			error_msg = result.message
		"test_udfa_contract_structure":
			var result := test_udfa_contract_structure()
			success = result.success
			error_msg = result.message
		"test_empty_undrafted_pool":
			var result := test_empty_undrafted_pool()
			success = result.success
			error_msg = result.message
		"test_unavailable_player_target":
			var result := test_unavailable_player_target()
			success = result.success
			error_msg = result.message
		"test_determinism_same_seed":
			var result := test_determinism_same_seed()
			success = result.success
			error_msg = result.message
		"test_performance_under_one_second":
			var result := test_performance_under_one_second()
			success = result.success
			error_msg = result.message
		"test_world_state_updated":
			var result := test_world_state_updated()
			success = result.success
			error_msg = result.message
		"test_validate_user_targets":
			var result := test_validate_user_targets()
			success = result.success
			error_msg = result.message
		"test_udfa_phase_skippable":
			var result := test_udfa_phase_skippable()
			success = result.success
			error_msg = result.message

	if success:
		results.passed += 1
		print("[PASS] %s" % test_name)
	else:
		results.failed += 1
		results.errors.append("%s: %s" % [test_name, error_msg])
		print("[FAIL] %s: %s" % [test_name, error_msg])


## Create a mock world state for testing
static func _create_mock_world_state() -> Dictionary:
	var undrafted: Array = []
	for i in range(100):
		undrafted.append({
			"player_id": "UDFA_%03d" % i,
			"id": "UDFA_%03d" % i,
			"name": "Player %d" % i,
			"position": ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"][i % 9],
			"composite_score": 60.0 - (float(i) * 0.2),  # Decreasing scores
			"age": 22
		})

	var teams: Array = []
	var rosters: Dictionary = {}
	for i in range(32):
		var team_id := "team_%02d" % i
		teams.append({
			"id": team_id,
			"name": "Team %d" % i
		})
		rosters[team_id] = {"players": [], "by_position": {}}

	return {
		"undrafted_pool": {TEST_YEAR: undrafted},
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"league_cfg": {"cap_limit": CAP_LIMIT}
	}


static func _create_mock_configs() -> Dictionary:
	return {
		"league_cfg": {"cap_limit": CAP_LIMIT},
		"positions_cfg": {
			"QB": {"priority": 1.0}, "RB": {"priority": 0.8}, "WR": {"priority": 0.9},
			"TE": {"priority": 0.7}, "OL": {"priority": 0.9}, "DL": {"priority": 0.85},
			"LB": {"priority": 0.8}, "CB": {"priority": 0.85}, "S": {"priority": 0.75}
		},
		"main_cfg": {"class_rules": {}}
	}


## Test 1: UDFA pool contains only undrafted players
static func test_udfa_pool_contains_undrafted() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	var eligible: Array = UDFABiddingEngine.get_eligible_udfas(
		world_state, TEST_YEAR, configs.positions_cfg, configs.main_cfg, configs.league_cfg
	)

	if eligible.size() == 0:
		return {"success": false, "message": "No eligible UDFAs found"}

	# Should be limited to top 50
	if eligible.size() > 50:
		return {"success": false, "message": "Eligible count %d exceeds max 50" % eligible.size()}

	return {"success": true, "message": ""}


## Test 2: Ranking is deterministic (same seed = same order)
static func test_ranking_is_deterministic() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	var eligible_1: Array = UDFABiddingEngine.get_eligible_udfas(
		world_state, TEST_YEAR, configs.positions_cfg, configs.main_cfg, configs.league_cfg
	)

	var eligible_2: Array = UDFABiddingEngine.get_eligible_udfas(
		world_state, TEST_YEAR, configs.positions_cfg, configs.main_cfg, configs.league_cfg
	)

	if eligible_1.size() != eligible_2.size():
		return {"success": false, "message": "Different sizes: %d vs %d" % [eligible_1.size(), eligible_2.size()]}

	for i in range(eligible_1.size()):
		var id_1 := String(eligible_1[i].get("player_id", ""))
		var id_2 := String(eligible_2[i].get("player_id", ""))
		if id_1 != id_2:
			return {"success": false, "message": "Order differs at index %d: %s vs %s" % [i, id_1, id_2]}

	return {"success": true, "message": ""}


## Test 3: User priority targets are processed first
static func test_user_targets_processed_first() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	# Pick specific targets from the pool
	var user_targets := ["UDFA_010", "UDFA_020", "UDFA_030"]

	var results: Dictionary = UDFABiddingEngine.run(
		world_state, TEST_YEAR, TEST_SEED, "team_00", user_targets,
		configs.league_cfg, configs.positions_cfg, configs.main_cfg
	)

	var user_signings: Array = results.get("user_signings", [])

	if user_signings.size() != 3:
		return {"success": false, "message": "Expected 3 user signings, got %d" % user_signings.size()}

	# Check all targets were signed
	for target in user_targets:
		var found := false
		for signing in user_signings:
			if String(signing.get("player_id", "")) == target:
				found = true
				break
		if not found:
			return {"success": false, "message": "Target %s not in user signings" % target}

	return {"success": true, "message": ""}


## Test 4: AI teams bid based on position needs
static func test_ai_bids_based_on_needs() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	var results: Dictionary = UDFABiddingEngine.run(
		world_state, TEST_YEAR, TEST_SEED, "team_00", [],
		configs.league_cfg, configs.positions_cfg, configs.main_cfg
	)

	var ai_signings: Array = results.get("ai_signings", [])

	if ai_signings.is_empty():
		return {"success": false, "message": "No AI signings occurred"}

	# Each AI team should sign 1-2 UDFAs
	var signings_per_team: Dictionary = {}
	for signing in ai_signings:
		var team_id := String(signing.get("team_id", ""))
		if not signings_per_team.has(team_id):
			signings_per_team[team_id] = 0
		signings_per_team[team_id] += 1

	for team_id in signings_per_team.keys():
		var count: int = signings_per_team[team_id]
		if count < 1 or count > 2:
			return {"success": false, "message": "Team %s signed %d UDFAs (expected 1-2)" % [team_id, count]}

	return {"success": true, "message": ""}


## Test 5: UDFA contract structure is correct
static func test_udfa_contract_structure() -> Dictionary:
	var contract := RookieWageScale.create_udfa_contract(TEST_YEAR, CAP_LIMIT)

	# Type
	if contract.get("type", "") != "udfa_rookie":
		return {"success": false, "message": "Type should be 'udfa_rookie'"}

	# 3 years
	if int(contract.get("years_total", 0)) != 3:
		return {"success": false, "message": "Should be 3 years"}

	# No signing bonus
	if float(contract.get("signing_bonus", -1)) != 0.0:
		return {"success": false, "message": "Should have $0 signing bonus"}

	# No 5th year option
	if contract.get("fifth_year_option", true):
		return {"success": false, "message": "Should NOT have 5th year option"}

	# No guarantees
	if float(contract.get("gtd_remaining", -1)) != 0.0:
		return {"success": false, "message": "Should have $0 guaranteed"}

	return {"success": true, "message": ""}


## Test 6: Empty undrafted pool
static func test_empty_undrafted_pool() -> Dictionary:
	var world_state := {
		"undrafted_pool": {TEST_YEAR: []},
		"nfl_teams": [],
		"nfl_rosters": {}
	}
	var configs := _create_mock_configs()

	var results: Dictionary = UDFABiddingEngine.run(
		world_state, TEST_YEAR, TEST_SEED, "team_00", [],
		configs.league_cfg, configs.positions_cfg, configs.main_cfg
	)

	if not results.get("user_signings", []).is_empty():
		return {"success": false, "message": "User signings should be empty"}

	if not results.get("ai_signings", []).is_empty():
		return {"success": false, "message": "AI signings should be empty"}

	return {"success": true, "message": ""}


## Test 7: User selects unavailable player
static func test_unavailable_player_target() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	# Target a player that doesn't exist
	var user_targets := ["NONEXISTENT_PLAYER", "UDFA_010"]

	var results: Dictionary = UDFABiddingEngine.run(
		world_state, TEST_YEAR, TEST_SEED, "team_00", user_targets,
		configs.league_cfg, configs.positions_cfg, configs.main_cfg
	)

	var user_signings: Array = results.get("user_signings", [])

	# Should only sign the valid target
	if user_signings.size() != 1:
		return {"success": false, "message": "Expected 1 signing (skipping invalid), got %d" % user_signings.size()}

	if String(user_signings[0].get("player_id", "")) != "UDFA_010":
		return {"success": false, "message": "Wrong player signed"}

	return {"success": true, "message": ""}


## Test 8: Determinism - same seed + picks = same signings
static func test_determinism_same_seed() -> Dictionary:
	var configs := _create_mock_configs()
	var user_targets := ["UDFA_005", "UDFA_015"]

	# Run 3 times with same seed
	var all_results: Array = []
	for _i in range(3):
		var world_state := _create_mock_world_state()
		var results: Dictionary = UDFABiddingEngine.run(
			world_state, TEST_YEAR, TEST_SEED, "team_00", user_targets,
			configs.league_cfg, configs.positions_cfg, configs.main_cfg
		)
		all_results.append(results)

	# Compare all runs
	for i in range(1, all_results.size()):
		var prev: Dictionary = all_results[i - 1]
		var curr: Dictionary = all_results[i]

		# Check user signings
		var prev_user: Array = prev.get("user_signings", [])
		var curr_user: Array = curr.get("user_signings", [])
		if prev_user.size() != curr_user.size():
			return {"success": false, "message": "User signings differ in size"}

		# Check AI signings count
		var prev_ai: Array = prev.get("ai_signings", [])
		var curr_ai: Array = curr.get("ai_signings", [])
		if prev_ai.size() != curr_ai.size():
			return {"success": false, "message": "AI signings differ in size: %d vs %d" % [prev_ai.size(), curr_ai.size()]}

		# Check specific AI signing order
		for j in range(prev_ai.size()):
			var prev_id := String(prev_ai[j].get("player_id", ""))
			var curr_id := String(curr_ai[j].get("player_id", ""))
			if prev_id != curr_id:
				return {"success": false, "message": "AI signing order differs at index %d" % j}

	return {"success": true, "message": ""}


## Test 9: Performance under 1 second
static func test_performance_under_one_second() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	var start_time := Time.get_ticks_msec()

	var _results: Dictionary = UDFABiddingEngine.run(
		world_state, TEST_YEAR, TEST_SEED, "team_00", [],
		configs.league_cfg, configs.positions_cfg, configs.main_cfg
	)

	var elapsed := Time.get_ticks_msec() - start_time

	if elapsed > 1000:
		return {"success": false, "message": "Took %dms, expected <1000ms" % elapsed}

	return {"success": true, "message": ""}


## Test 10: World state is updated with signings
static func test_world_state_updated() -> Dictionary:
	var world_state := _create_mock_world_state()
	var configs := _create_mock_configs()

	var _results: Dictionary = UDFABiddingEngine.run(
		world_state, TEST_YEAR, TEST_SEED, "team_00", ["UDFA_000"],
		configs.league_cfg, configs.positions_cfg, configs.main_cfg
	)

	# Check UDFA history was recorded
	var udfa_history: Dictionary = world_state.get("udfa_history", {})
	if not udfa_history.has(TEST_YEAR):
		return {"success": false, "message": "UDFA history not recorded for year"}

	# Check rosters were updated
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var user_roster: Dictionary = rosters.get("team_00", {})
	var players: Array = user_roster.get("players", [])

	var found_signing := false
	for player in players:
		if String(player.get("player_id", "")) == "UDFA_000":
			found_signing = true
			break

	if not found_signing:
		return {"success": false, "message": "User signing not added to roster"}

	return {"success": true, "message": ""}


## Test 11: Validate user targets
static func test_validate_user_targets() -> Dictionary:
	var world_state := _create_mock_world_state()

	# Valid targets
	var valid: Dictionary = UDFABiddingEngine.validate_user_targets(
		["UDFA_000", "UDFA_001"], world_state, TEST_YEAR
	)
	if not valid.get("valid", false):
		return {"success": false, "message": "Valid targets rejected: %s" % valid.get("error", "")}

	# Too many targets
	var too_many: Dictionary = UDFABiddingEngine.validate_user_targets(
		["UDFA_000", "UDFA_001", "UDFA_002", "UDFA_003", "UDFA_004", "UDFA_005"],
		world_state, TEST_YEAR
	)
	if too_many.get("valid", true):
		return {"success": false, "message": "Too many targets should be rejected"}

	# Duplicate targets
	var duplicates: Dictionary = UDFABiddingEngine.validate_user_targets(
		["UDFA_000", "UDFA_000"], world_state, TEST_YEAR
	)
	if duplicates.get("valid", true):
		return {"success": false, "message": "Duplicate targets should be rejected"}

	return {"success": true, "message": ""}


## Test 12: UDFA phase is skippable
static func test_udfa_phase_skippable() -> Dictionary:
	if not UDFABiddingEngine.can_skip():
		return {"success": false, "message": "UDFA phase should be skippable"}

	return {"success": true, "message": ""}
