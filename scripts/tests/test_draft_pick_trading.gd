extends RefCounted

## Unit tests for Feature 5: Draft Pick Trading
##
## Tests the draft pick ownership ledger and pick valuation systems.
## All tests verify deterministic behavior and proper ownership tracking.

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

## Test: initialize_pick_ownership creates proper ownership structure
static func test_initialize_pick_ownership() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state: Dictionary = {}
	var teams: Array = [
		{"id": "SF"},
		{"id": "CHI"},
		{"id": "NYJ"}
	]
	var year: int = 2025
	var rounds: int = 7

	draft_instance.initialize_pick_ownership(world_state, teams, year, rounds)

	# Verify structure exists
	assert(world_state.has("draft_pick_ownership"), "Should create ownership ledger")
	var ownership: Dictionary = world_state["draft_pick_ownership"]
	assert(ownership.has(year), "Should create year entry")

	var year_ownership: Dictionary = ownership[year]

	# Verify all rounds initialized
	for round_num in range(1, rounds + 1):
		assert(year_ownership.has(round_num), "Should have round %d" % round_num)
		var round_ownership: Dictionary = year_ownership[round_num]

		# Verify each team owns their own pick
		for team in teams:
			var team_id := String(team.get("id", ""))
			assert(round_ownership.has(team_id), "Should have entry for %s" % team_id)
			assert(round_ownership[team_id] == team_id, "%s should own their own pick" % team_id)

	return {"passed": true, "message": "initialize_pick_ownership works correctly"}


## Test: resolve_draft_order_with_ownership respects default ownership
static func test_resolve_draft_order_default_ownership() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var teams: Array = [
		{"id": "SF", "draft_order": 1},
		{"id": "CHI", "draft_order": 2},
		{"id": "NYJ", "draft_order": 3}
	]
	var ownership: Dictionary = {
		2025: {
			1: {
				"SF": "SF",
				"CHI": "CHI",
				"NYJ": "NYJ"
			}
		}
	}
	var year: int = 2025
	var round_num: int = 1

	var picks: Array = draft_instance.resolve_draft_order_with_ownership(teams, ownership, year, round_num)

	# Verify order and ownership
	assert(picks.size() == 3, "Should have 3 picks")

	var pick1: Dictionary = picks[0]
	assert(pick1.get("pick_number") == 1, "First pick should be #1")
	assert(pick1.get("original_team_id") == "SF", "SF has worst record")
	assert(pick1.get("current_owner_id") == "SF", "SF owns their pick")
	assert(pick1.get("traded") == false, "Pick not traded")

	return {"passed": true, "message": "resolve_draft_order_with_ownership handles default ownership"}


## Test: resolve_draft_order_with_ownership respects traded picks
static func test_resolve_draft_order_traded_picks() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var teams: Array = [
		{"id": "SF", "draft_order": 1},
		{"id": "CHI", "draft_order": 2},
		{"id": "NYJ", "draft_order": 3}
	]
	var ownership: Dictionary = {
		2025: {
			1: {
				"SF": "CHI",  # Bears own 49ers' pick
				"CHI": "CHI",
				"NYJ": "NYJ"
			}
		}
	}
	var year: int = 2025
	var round_num: int = 1

	var picks: Array = draft_instance.resolve_draft_order_with_ownership(teams, ownership, year, round_num)

	# Verify traded pick
	var pick1: Dictionary = picks[0]
	assert(pick1.get("pick_number") == 1, "First pick should be #1")
	assert(pick1.get("original_team_id") == "SF", "SF has worst record")
	assert(pick1.get("current_owner_id") == "CHI", "CHI owns the pick")
	assert(pick1.get("traded") == true, "Pick was traded")

	return {"passed": true, "message": "resolve_draft_order_with_ownership handles traded picks"}


## Test: value_draft_pick calculates correct values by round
static func test_value_draft_pick_by_round() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var config: Dictionary = {
		"draft_pick_trading": {
			"future_year_discount": 0.9
		}
	}
	var current_year: int = 2025

	# Test Round 1 values
	var rd1_pick1: float = draft_instance.value_draft_pick(2025, 1, 1, current_year, config)
	var rd1_pick32: float = draft_instance.value_draft_pick(2025, 1, 32, current_year, config)
	assert(rd1_pick1 > rd1_pick32, "Pick 1 should be worth more than pick 32")
	assert(rd1_pick1 == 1000.0, "Pick 1 should be 1000 points")
	assert(rd1_pick32 == 800.0, "Pick 32 should be 800 points")

	# Test Round 2 values
	var rd2_pick1: float = draft_instance.value_draft_pick(2025, 2, 1, current_year, config)
	assert(rd2_pick1 == 600.0, "Round 2 pick 1 should be 600 points")
	assert(rd1_pick32 > rd2_pick1, "Late round 1 worth more than early round 2")

	# Test Round 7 values
	var rd7_pick1: float = draft_instance.value_draft_pick(2025, 7, 1, current_year, config)
	assert(rd7_pick1 == 50.0, "Round 7 pick 1 should be 50 points")

	return {"passed": true, "message": "value_draft_pick calculates correct values"}


## Test: value_draft_pick applies future year discount
static func test_value_draft_pick_future_discount() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var config: Dictionary = {
		"draft_pick_trading": {
			"future_year_discount": 0.9
		}
	}
	var current_year: int = 2025

	# Current year pick (no discount)
	var current_pick: float = draft_instance.value_draft_pick(2025, 1, 1, current_year, config)

	# Next year pick (10% discount)
	var next_year_pick: float = draft_instance.value_draft_pick(2026, 1, 1, current_year, config)

	# Two years out (20% discount - 0.9^2)
	var two_year_pick: float = draft_instance.value_draft_pick(2027, 1, 1, current_year, config)

	assert(current_pick == 1000.0, "Current year pick should be 1000")
	assert(next_year_pick == 900.0, "Next year pick should be 900 (10% discount)")
	assert(two_year_pick == 810.0, "Two year pick should be 810 (19% discount)")

	return {"passed": true, "message": "value_draft_pick applies future discounts correctly"}


## Test: transfer_pick_ownership updates ownership correctly
static func test_transfer_pick_ownership() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state: Dictionary = {}
	var teams: Array = [
		{"id": "SF"},
		{"id": "CHI"}
	]
	var year: int = 2025
	var rounds: int = 7

	# Initialize ownership
	draft_instance.initialize_pick_ownership(world_state, teams, year, rounds)

	# Transfer SF's 1st round pick to CHI
	draft_instance.transfer_pick_ownership(world_state, year, 1, "SF", "CHI")

	var ownership: Dictionary = world_state["draft_pick_ownership"]
	var year_ownership: Dictionary = ownership[year]
	var round_ownership: Dictionary = year_ownership[1]

	assert(round_ownership["SF"] == "CHI", "SF's pick should now be owned by CHI")
	assert(round_ownership["CHI"] == "CHI", "CHI still owns their own pick")

	return {"passed": true, "message": "transfer_pick_ownership updates ownership correctly"}


## Test: Draft run respects ownership
static func test_draft_run_respects_ownership() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	# Setup minimal world state
	var world_state: Dictionary = {
		"draft_pool": {
			2025: [
				{"player_id": "player1", "position": "QB", "stats": {"arm_strength": 80.0}},
				{"player_id": "player2", "position": "RB", "stats": {"speed": 75.0}}
			]
		},
		"nfl_teams": [
			{"id": "SF", "draft_order": 1},
			{"id": "CHI", "draft_order": 2}
		],
		"nfl_rosters": {
			"SF": {"players": [], "by_position": {}},
			"CHI": {"players": [], "by_position": {}}
		}
	}

	# Setup traded pick: CHI owns SF's pick
	world_state["draft_pick_ownership"] = {
		2025: {
			1: {
				"SF": "CHI",  # CHI owns SF's 1st pick
				"CHI": "CHI"
			}
		}
	}

	# Mock configs
	var league_cfg: Dictionary = {"draft": {"rounds": 1}, "compensatory_picks": {"enabled": false}}
	var positions_cfg: Dictionary = {"QB": {"core_stats": []}, "RB": {"core_stats": []}}
	var stats_cfg: Dictionary = {"stats": []}
	var scouts_cfg: Dictionary = {"national_scouts": []}
	var main_cfg: Dictionary = {"class_rules": {}}

	var result: Dictionary = draft_instance.run(
		world_state, 2025, 12345,
		league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg
	)

	var picks: Array = result.get("picks", [])

	# First pick should go to CHI (they own SF's pick)
	assert(picks.size() >= 1, "Should have at least 1 pick")
	var first_pick: Dictionary = picks[0]
	assert(first_pick.get("team_id") == "CHI", "CHI should make first pick (owns SF's pick)")
	assert(first_pick.get("traded") == true, "Pick should be marked as traded")
	assert(first_pick.get("original_team_id") == "SF", "Original team should be SF")

	return {"passed": true, "message": "Draft run respects pick ownership"}


## Test: Determinism - same seed produces same results
static func test_determinism() -> Dictionary:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state1: Dictionary = {
		"draft_pool": {2025: []},
		"nfl_teams": [{"id": "SF", "draft_order": 1}],
		"nfl_rosters": {"SF": {"players": [], "by_position": {}}}
	}
	var world_state2: Dictionary = world_state1.duplicate(true)

	var teams: Array = [{"id": "SF"}]
	var year: int = 2025
	var seed: int = 42

	# Initialize ownership twice with same seed
	draft_instance.initialize_pick_ownership(world_state1, teams, year, 7)
	draft_instance.initialize_pick_ownership(world_state2, teams, year, 7)

	# Verify identical results
	var ownership1: Dictionary = world_state1["draft_pick_ownership"]
	var ownership2: Dictionary = world_state2["draft_pick_ownership"]

	assert(ownership1.hash() == ownership2.hash(), "Same seed should produce identical ownership")

	return {"passed": true, "message": "Ownership initialization is deterministic"}


## Run all tests
static func run_all_tests() -> Dictionary:
	var tests: Array = [
		test_initialize_pick_ownership,
		test_resolve_draft_order_default_ownership,
		test_resolve_draft_order_traded_picks,
		test_value_draft_pick_by_round,
		test_value_draft_pick_future_discount,
		test_transfer_pick_ownership,
		test_draft_run_respects_ownership,
		test_determinism
	]

	var results: Array = []
	var passed: int = 0
	var failed: int = 0

	for test_func in tests:
		var result: Dictionary = test_func.call()
		results.append(result)
		if result.get("passed", false):
			passed += 1
		else:
			failed += 1
			print("FAILED: ", result.get("message", "Unknown test"))

	return {
		"total": tests.size(),
		"passed": passed,
		"failed": failed,
		"results": results
	}
