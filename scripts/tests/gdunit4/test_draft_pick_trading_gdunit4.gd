## GdUnit4 test suite for Draft Pick Trading
##
## Validates draft pick ownership ledger and pick valuation systems.
## Migrated from test_draft_pick_trading.gd
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")


func test_initialize_pick_ownership_creates_structure() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state: Dictionary = {}
	var teams: Array = [{"id": "SF"}, {"id": "CHI"}, {"id": "NYJ"}]
	var year: int = 2025
	var rounds: int = 7

	draft_instance.initialize_pick_ownership(world_state, teams, year, rounds)

	assert_bool(world_state.has("draft_pick_ownership")).is_true()
	var ownership: Dictionary = world_state["draft_pick_ownership"]
	assert_bool(ownership.has(year)).is_true()


func test_initialize_pick_ownership_all_rounds() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state: Dictionary = {}
	var teams: Array = [{"id": "SF"}, {"id": "CHI"}]
	var year: int = 2025
	var rounds: int = 7

	draft_instance.initialize_pick_ownership(world_state, teams, year, rounds)

	var year_ownership: Dictionary = world_state["draft_pick_ownership"][year]

	for round_num in range(1, rounds + 1):
		assert_bool(year_ownership.has(round_num)).is_true()


func test_initialize_pick_ownership_teams_own_their_picks() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state: Dictionary = {}
	var teams: Array = [{"id": "SF"}, {"id": "CHI"}]
	var year: int = 2025
	var rounds: int = 7

	draft_instance.initialize_pick_ownership(world_state, teams, year, rounds)

	var year_ownership: Dictionary = world_state["draft_pick_ownership"][year]
	var round_ownership: Dictionary = year_ownership[1]

	assert_str(String(round_ownership["SF"])).is_equal("SF")
	assert_str(String(round_ownership["CHI"])).is_equal("CHI")


func test_resolve_draft_order_default_ownership() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var teams: Array = [
		{"id": "SF", "draft_order": 1},
		{"id": "CHI", "draft_order": 2},
		{"id": "NYJ", "draft_order": 3}
	]
	var ownership: Dictionary = {
		2025: {
			1: {"SF": "SF", "CHI": "CHI", "NYJ": "NYJ"}
		}
	}
	var year: int = 2025
	var round_num: int = 1

	var picks: Array = draft_instance.resolve_draft_order_with_ownership(teams, ownership, year, round_num)

	assert_int(picks.size()).is_equal(3)

	var pick1: Dictionary = picks[0]
	assert_int(int(pick1.get("pick_number"))).is_equal(1)
	assert_str(String(pick1.get("original_team_id"))).is_equal("SF")
	assert_str(String(pick1.get("current_owner_id"))).is_equal("SF")
	assert_bool(bool(pick1.get("traded"))).is_false()


func test_resolve_draft_order_traded_picks() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var teams: Array = [
		{"id": "SF", "draft_order": 1},
		{"id": "CHI", "draft_order": 2},
		{"id": "NYJ", "draft_order": 3}
	]
	var ownership: Dictionary = {
		2025: {
			1: {"SF": "CHI", "CHI": "CHI", "NYJ": "NYJ"}  # Bears own 49ers' pick
		}
	}
	var year: int = 2025
	var round_num: int = 1

	var picks: Array = draft_instance.resolve_draft_order_with_ownership(teams, ownership, year, round_num)

	var pick1: Dictionary = picks[0]
	assert_int(int(pick1.get("pick_number"))).is_equal(1)
	assert_str(String(pick1.get("original_team_id"))).is_equal("SF")
	assert_str(String(pick1.get("current_owner_id"))).is_equal("CHI")
	assert_bool(bool(pick1.get("traded"))).is_true()


func test_value_draft_pick_round_1() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var config: Dictionary = {"draft_pick_trading": {"future_year_discount": 0.9}}
	var current_year: int = 2025

	var rd1_pick1: float = draft_instance.value_draft_pick(2025, 1, 1, current_year, config)
	var rd1_pick32: float = draft_instance.value_draft_pick(2025, 1, 32, current_year, config)

	assert_float(rd1_pick1).is_greater(rd1_pick32)
	assert_float(rd1_pick1).is_equal(1000.0)
	assert_float(rd1_pick32).is_equal(800.0)


func test_value_draft_pick_round_2() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var config: Dictionary = {"draft_pick_trading": {"future_year_discount": 0.9}}
	var current_year: int = 2025

	var rd1_pick32: float = draft_instance.value_draft_pick(2025, 1, 32, current_year, config)
	var rd2_pick1: float = draft_instance.value_draft_pick(2025, 2, 1, current_year, config)

	assert_float(rd2_pick1).is_equal(600.0)
	assert_float(rd1_pick32).is_greater(rd2_pick1)


func test_value_draft_pick_round_7() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var config: Dictionary = {"draft_pick_trading": {"future_year_discount": 0.9}}
	var current_year: int = 2025

	var rd7_pick1: float = draft_instance.value_draft_pick(2025, 7, 1, current_year, config)

	assert_float(rd7_pick1).is_equal(50.0)


func test_value_draft_pick_future_discount() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var config: Dictionary = {"draft_pick_trading": {"future_year_discount": 0.9}}
	var current_year: int = 2025

	var current_pick: float = draft_instance.value_draft_pick(2025, 1, 1, current_year, config)
	var next_year_pick: float = draft_instance.value_draft_pick(2026, 1, 1, current_year, config)
	var two_year_pick: float = draft_instance.value_draft_pick(2027, 1, 1, current_year, config)

	assert_float(current_pick).is_equal(1000.0)
	assert_float(next_year_pick).is_equal(900.0)
	assert_float(two_year_pick).is_equal(810.0)


func test_transfer_pick_ownership() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state: Dictionary = {}
	var teams: Array = [{"id": "SF"}, {"id": "CHI"}]
	var year: int = 2025
	var rounds: int = 7

	draft_instance.initialize_pick_ownership(world_state, teams, year, rounds)
	draft_instance.transfer_pick_ownership(world_state, year, 1, "SF", "CHI")

	var ownership: Dictionary = world_state["draft_pick_ownership"]
	var year_ownership: Dictionary = ownership[year]
	var round_ownership: Dictionary = year_ownership[1]

	assert_str(String(round_ownership["SF"])).is_equal("CHI")
	assert_str(String(round_ownership["CHI"])).is_equal("CHI")


func test_draft_run_respects_ownership() -> void:
	var draft_instance: NflDraft = NflDraft.new()
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

	# CHI owns SF's pick
	world_state["draft_pick_ownership"] = {
		2025: {
			1: {"SF": "CHI", "CHI": "CHI"}
		}
	}

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

	assert_int(picks.size()).is_greater_equal(1)

	var first_pick: Dictionary = picks[0]
	assert_str(String(first_pick.get("team_id"))).is_equal("CHI")
	assert_bool(bool(first_pick.get("traded"))).is_true()
	assert_str(String(first_pick.get("original_team_id"))).is_equal("SF")


func test_ownership_initialization_determinism() -> void:
	var draft_instance: NflDraft = NflDraft.new()
	var world_state1: Dictionary = {
		"draft_pool": {2025: []},
		"nfl_teams": [{"id": "SF", "draft_order": 1}],
		"nfl_rosters": {"SF": {"players": [], "by_position": {}}}
	}
	var world_state2: Dictionary = world_state1.duplicate(true)

	var teams: Array = [{"id": "SF"}]
	var year: int = 2025

	draft_instance.initialize_pick_ownership(world_state1, teams, year, 7)
	draft_instance.initialize_pick_ownership(world_state2, teams, year, 7)

	var ownership1: Dictionary = world_state1["draft_pick_ownership"]
	var ownership2: Dictionary = world_state2["draft_pick_ownership"]

	assert_int(ownership1.hash()).is_equal(ownership2.hash())
