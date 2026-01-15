## GdUnit4 test suite for FreeAgency
##
## Tests free agency simulation, franchise tags, and contract signings.
## Migrated from test_free_agency.gd
extends GdUnitTestSuite

const FreeAgency = preload("res://scripts/world/FreeAgency.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _league_cfg: Dictionary


func before() -> void:
	var config_service := ConfigService.new()
	_positions_cfg = config_service.get_config("positions")
	_main_cfg = config_service.get_config("main")
	_league_cfg = config_service.get_config("league")


func test_collect_free_agents_finds_expired() -> void:
	var world_state := _create_test_world()

	var player := _create_test_player("player-fa-1", "WR", 26, 75.0)
	player["contract"] = {
		"status": "expired",
		"years_remaining": 0
	}

	world_state["nfl_rosters"]["NYJ"]["players"].append(player)

	var free_agents := FreeAgency.collect_free_agents(world_state, 2024, _positions_cfg, _main_cfg)

	assert_int(free_agents.size()).is_greater_equal(1)

	var found: bool = false
	for fa in free_agents:
		var fa_dict: Dictionary = fa as Dictionary
		if fa_dict.get("player_id", "") == "player-fa-1":
			found = true
			assert_str(String(fa_dict.get("position", ""))).is_equal("WR")
			assert_int(int(fa_dict.get("age", 0))).is_equal(26)
			assert_bool(fa_dict.has("minimum_demand")).is_true()
			assert_bool(fa_dict.has("priority_tier")).is_true()
			break

	assert_bool(found).is_true()


func test_collect_free_agents_calculates_demand() -> void:
	var world_state := _create_test_world()

	var qb := _create_test_player("player-qb-elite", "QB", 27, 88.0)
	qb["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["KC"]["players"].append(qb)

	var rb := _create_test_player("player-rb-depth", "RB", 24, 62.0)
	rb["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["SF"]["players"].append(rb)

	var free_agents := FreeAgency.collect_free_agents(world_state, 2024, _positions_cfg, _main_cfg)

	var qb_demand: float = 0.0
	var rb_demand: float = 0.0

	for fa in free_agents:
		var fa_dict: Dictionary = fa as Dictionary
		var player_id: String = String(fa_dict.get("player_id", ""))
		if player_id == "player-qb-elite":
			qb_demand = float(fa_dict.get("minimum_demand", 0.0))
			assert_str(String(fa_dict.get("priority_tier", ""))).is_equal("elite")
		elif player_id == "player-rb-depth":
			rb_demand = float(fa_dict.get("minimum_demand", 0.0))
			assert_str(String(fa_dict.get("priority_tier", ""))).is_equal("depth")

	assert_float(qb_demand).is_greater(rb_demand)
	assert_float(qb_demand).is_greater(5.0)


func test_generate_team_interest_prioritizes_needs() -> void:
	var world_state := _create_test_world()

	var fa_profile: Dictionary = {
		"player_id": "player-qb",
		"position": "QB",
		"age": 26,
		"overall_rating": 78.0,
		"minimum_demand": 12.0,
		"priority_tier": "starter"
	}

	var free_agents: Array = [fa_profile]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	world_state["nfl_rosters"]["CAR"]["players"] = []

	var team_interest: Dictionary = FreeAgency.generate_team_interest(
		world_state,
		2024,
		free_agents,
		rng,
		_league_cfg
	)

	assert_bool(team_interest.has("CAR")).is_true()

	var car_interest: float = float(team_interest.get("CAR", {}).get("player-qb", 0.0))
	assert_float(car_interest).is_greater(1.0)


func test_player_chooses_highest_offer() -> void:
	var player_id: String = "player-wr"
	var team_interest: Dictionary = {
		"NYJ": {"player-wr": 1.5},
		"KC": {"player-wr": 1.2},
		"BUF": {"player-wr": 1.0}
	}

	var offers: Array = [
		{"team_id": "NYJ", "annual_value": 10.0, "offer_quality": 0.9},
		{"team_id": "KC", "annual_value": 12.0, "offer_quality": 1.1},
		{"team_id": "BUF", "annual_value": 9.0, "offer_quality": 0.8}
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var chosen_team: String = FreeAgency.player_chooses_team(player_id, team_interest, offers, rng)

	assert_str(chosen_team).is_equal("KC")


func test_player_chooses_familiarity_bonus() -> void:
	var player_id: String = "player-lb"
	var team_interest: Dictionary = {
		"BAL": {"player-lb": 1.3},
		"PIT": {"player-lb": 1.3}
	}

	var offers: Array = [
		{
			"team_id": "BAL",
			"annual_value": 8.0,
			"offer_quality": 1.0,
			"previous_team_id": "BAL"
		},
		{
			"team_id": "PIT",
			"annual_value": 8.0,
			"offer_quality": 1.0,
			"previous_team_id": "BAL"
		}
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var chosen_team: String = FreeAgency.player_chooses_team(player_id, team_interest, offers, rng)

	assert_str(chosen_team).is_equal("BAL")


func test_franchise_tag_calculates_salary() -> void:
	var world_state := _create_test_world()

	var qb_salaries: Array = [25.0, 22.0, 20.0, 18.0, 16.0, 14.0, 12.0]

	for i in range(qb_salaries.size()):
		var qb: Dictionary = _create_test_player("qb-%d" % i, "QB", 27, 80.0)
		qb["contract"] = {
			"status": "signed",
			"annual_value": qb_salaries[i]
		}
		world_state["nfl_rosters"]["TEAM_%d" % i] = {"players": [qb]}

	var target: Dictionary = _create_test_player("player-tag-qb", "QB", 26, 85.0)
	target["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["SF"]["players"] = [target]

	var tag: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"SF",
		"player-tag-qb",
		"non_exclusive",
		2024,
		_league_cfg
	)

	assert_bool(not tag.is_empty()).is_true()

	var salary: float = float(tag.get("salary", 0.0))
	var expected_avg: float = (25.0 + 22.0 + 20.0 + 18.0 + 16.0) / 5.0

	assert_float(salary).is_equal_approx(expected_avg, 0.5)


func test_franchise_tag_stored_in_world_state() -> void:
	var world_state: Dictionary = _create_test_world()
	var year: int = 2024

	var player: Dictionary = _create_test_player("player-tag", "EDGE", 25, 82.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["NYJ"]["players"] = [player]
	world_state["nfl_teams"][0]["cap_space"] = 50.0

	var tag: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"NYJ",
		"player-tag",
		"exclusive",
		year,
		_league_cfg
	)

	assert_bool(not tag.is_empty()).is_true()

	assert_bool(world_state.has("franchise_tags")).is_true()
	assert_bool(world_state["franchise_tags"].has(year)).is_true()
	assert_bool(world_state["franchise_tags"][year].has("NYJ")).is_true()

	var stored_tag: Dictionary = world_state["franchise_tags"][year]["NYJ"]
	assert_str(String(stored_tag.get("player_id", ""))).is_equal("player-tag")


func test_franchise_tag_prevents_free_agency() -> void:
	var world_state: Dictionary = _create_test_world()
	var year: int = 2024

	var player: Dictionary = _create_test_player("player-tagged", "CB", 26, 84.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["DAL"]["players"] = [player]
	world_state["nfl_teams"][0]["cap_space"] = 50.0

	var free_agents_before: Array = FreeAgency.collect_free_agents(
		world_state,
		year,
		_positions_cfg,
		_main_cfg
	)

	var found_before: bool = false
	for fa in free_agents_before:
		if fa.get("player_id", "") == "player-tagged":
			found_before = true
			break

	assert_bool(found_before).is_true()

	FreeAgency.apply_franchise_tag(
		world_state,
		"DAL",
		"player-tagged",
		"non_exclusive",
		year,
		_league_cfg
	)

	var contract_status: String = String(player.get("contract", {}).get("status", ""))
	assert_str(contract_status).is_equal("signed")

	var years_remaining: int = int(player.get("contract", {}).get("years_remaining", 0))
	assert_int(years_remaining).is_equal(1)


func test_franchise_tag_one_per_team() -> void:
	var world_state: Dictionary = _create_test_world()
	var year: int = 2024

	var player1: Dictionary = _create_test_player("player-1", "WR", 26, 82.0)
	player1["contract"] = {"status": "expired", "years_remaining": 0}

	var player2: Dictionary = _create_test_player("player-2", "EDGE", 25, 80.0)
	player2["contract"] = {"status": "expired", "years_remaining": 0}

	world_state["nfl_rosters"]["MIA"]["players"] = [player1, player2]
	world_state["nfl_teams"][0]["cap_space"] = 100.0

	var tag1: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"MIA",
		"player-1",
		"non_exclusive",
		year,
		_league_cfg
	)

	assert_bool(not tag1.is_empty()).is_true()

	var tag2: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"MIA",
		"player-2",
		"non_exclusive",
		year,
		_league_cfg
	)

	assert_bool(tag2.is_empty()).is_true()


func test_franchise_tag_consecutive_penalty() -> void:
	var world_state: Dictionary = _create_test_world()

	var player: Dictionary = _create_test_player("player-consecutive", "OL", 27, 78.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["GB"]["players"] = [player]
	world_state["nfl_teams"][0]["cap_space"] = 100.0

	for i in range(5):
		var ol: Dictionary = _create_test_player("ol-%d" % i, "OL", 28, 75.0)
		ol["contract"] = {"status": "signed", "annual_value": 10.0}
		world_state["nfl_rosters"]["TEAM_OL_%d" % i] = {"players": [ol]}

	var tag1: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"GB",
		"player-consecutive",
		"non_exclusive",
		2023,
		_league_cfg
	)

	var salary_year_1: float = float(tag1.get("salary", 0.0))

	player["contract"] = {"status": "expired", "years_remaining": 0}

	var tag2: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"GB",
		"player-consecutive",
		"non_exclusive",
		2024,
		_league_cfg
	)

	var salary_year_2: float = float(tag2.get("salary", 0.0))

	assert_float(salary_year_2 / salary_year_1).is_equal_approx(1.2, 0.05)


func test_run_free_agency_signs_players() -> void:
	var world_state: Dictionary = _create_test_world()
	var year: int = 2024
	var seed: int = 88888

	var player: Dictionary = _create_test_player("player-sign", "TE", 25, 72.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["CHI"]["players"] = [player]

	for team in world_state["nfl_teams"]:
		team["cap_space"] = 30.0

	var result: Dictionary = FreeAgency.run_free_agency(
		world_state,
		year,
		seed,
		_positions_cfg,
		_main_cfg,
		{},
		_league_cfg
	)

	assert_bool(result.has("signings")).is_true()
	assert_bool(result.has("unsigned")).is_true()

	var total_participants: int = result["signings"].size() + result["unsigned"].size()
	assert_int(total_participants).is_greater_equal(1)


func test_run_free_agency_deterministic() -> void:
	var seed: int = 123456

	var world_state_1: Dictionary = _create_test_world()
	_add_test_free_agents(world_state_1, 5)

	var result1: Dictionary = FreeAgency.run_free_agency(
		world_state_1,
		2024,
		seed,
		_positions_cfg,
		_main_cfg,
		{},
		_league_cfg
	)

	var world_state_2: Dictionary = _create_test_world()
	_add_test_free_agents(world_state_2, 5)

	var result2: Dictionary = FreeAgency.run_free_agency(
		world_state_2,
		2024,
		seed,
		_positions_cfg,
		_main_cfg,
		{},
		_league_cfg
	)

	assert_int(result1["signings"].size()).is_equal(result2["signings"].size())
	assert_int(result1["unsigned"].size()).is_equal(result2["unsigned"].size())

	if result1["signings"].size() > 0:
		var signing1: Dictionary = result1["signings"][0] as Dictionary
		var signing2: Dictionary = result2["signings"][0] as Dictionary

		assert_str(String(signing1.get("player_id", ""))).is_equal(String(signing2.get("player_id", "")))
		assert_str(String(signing1.get("team_id", ""))).is_equal(String(signing2.get("team_id", "")))


# --- Helper functions ---

func _create_test_world() -> Dictionary:
	return {
		"nfl_rosters": {
			"NYJ": {"players": []},
			"KC": {"players": []},
			"SF": {"players": []},
			"BUF": {"players": []},
			"CAR": {"players": []},
			"DAL": {"players": []},
			"MIA": {"players": []},
			"GB": {"players": []},
			"CHI": {"players": []}
		},
		"nfl_teams": [
			{"id": "NYJ", "cap_space": 40.0},
			{"id": "KC", "cap_space": 35.0},
			{"id": "SF", "cap_space": 50.0},
			{"id": "BUF", "cap_space": 30.0},
			{"id": "CAR", "cap_space": 60.0},
			{"id": "DAL", "cap_space": 25.0},
			{"id": "MIA", "cap_space": 45.0},
			{"id": "GB", "cap_space": 40.0},
			{"id": "CHI", "cap_space": 38.0}
		],
		"franchise_tags": {},
		"free_agent_pool": {},
		"contract_negotiation_history": {}
	}


func _create_test_player(id: String, position: String, age: int, eval_score: float) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"age": age,
		"eval_score": eval_score,
		"contract": {}
	}


func _add_test_free_agents(world_state: Dictionary, count: int) -> void:
	var positions: Array = ["QB", "WR", "RB", "TE", "OL"]
	var teams: Array = world_state["nfl_teams"]

	for i in range(count):
		var pos: String = positions[i % positions.size()]
		var team_idx: int = i % teams.size()
		var team_id: String = String(teams[team_idx].get("id", ""))

		var player: Dictionary = _create_test_player("fa-player-%d" % i, pos, 25, 70.0)
		player["contract"] = {"status": "expired", "years_remaining": 0}

		world_state["nfl_rosters"][team_id]["players"].append(player)
