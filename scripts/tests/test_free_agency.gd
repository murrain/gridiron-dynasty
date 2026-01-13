extends RefCounted
## Unit tests for FreeAgency module
##
## Tests free agency simulation, franchise tags, and contract signings.

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")


func run(helper: TestHelpers) -> void:
	print("\n=== FreeAgency Unit Tests ===\n")

	test_collect_free_agents_finds_expired(helper)
	test_collect_free_agents_calculates_demand(helper)
	test_generate_team_interest_prioritizes_needs(helper)
	test_player_chooses_highest_offer(helper)
	test_player_chooses_familiarity_bonus(helper)
	test_franchise_tag_calculates_salary(helper)
	test_franchise_tag_stored_in_world_state(helper)
	test_franchise_tag_prevents_free_agency(helper)
	test_franchise_tag_one_per_team(helper)
	test_franchise_tag_consecutive_penalty(helper)
	test_run_free_agency_signs_players(helper)
	test_run_free_agency_deterministic(helper)

	var passed := 0 if helper.failures.size() > 0 else 12
	var failed := helper.failures.size()

	print("\n=== Test Summary ===")
	print("PASSED: %d" % passed)
	print("FAILED: %d" % failed)


func test_collect_free_agents_finds_expired(helper: TestHelpers) -> void:
	print("[TEST] collect_free_agents finds expired contracts")

	var world_state := _create_test_world()
	var year := 2024

	# Add player with expired contract
	var player := _create_test_player("player-fa-1", "WR", 26, 75.0)
	player["contract"] = {
		"status": "expired",
		"years_remaining": 0
	}

	world_state["nfl_rosters"]["NYJ"]["players"].append(player)

	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()

	var free_agents := FreeAgency.collect_free_agents(world_state, year, positions_cfg, main_cfg)

	helper.assert_gte(free_agents.size(), 1, "Should find at least 1 free agent")

	# Find our test player
	var found: bool = false
	for fa in free_agents:
		var fa_dict: Dictionary = fa as Dictionary
		if fa_dict.get("player_id", "") == "player-fa-1":
			found = true
			helper.assert_eq(fa_dict.get("position", ""), "WR", "FA profile has correct position")
			helper.assert_eq(fa_dict.get("age", 0), 26, "FA profile has correct age")
			helper.assert_true(fa_dict.has("minimum_demand"), "FA profile has minimum_demand")
			helper.assert_true(fa_dict.has("priority_tier"), "FA profile has priority_tier")
			break

	helper.assert_true(found, "Found test player in free agent pool")


func test_collect_free_agents_calculates_demand(helper: TestHelpers) -> void:
	print("[TEST] collect_free_agents calculates demand correctly")

	var world_state := _create_test_world()
	var year := 2024

	# Add elite QB
	var qb := _create_test_player("player-qb-elite", "QB", 27, 88.0)
	qb["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["KC"]["players"].append(qb)

	# Add depth RB
	var rb := _create_test_player("player-rb-depth", "RB", 24, 62.0)
	rb["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["SF"]["players"].append(rb)

	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()

	var free_agents := FreeAgency.collect_free_agents(world_state, year, positions_cfg, main_cfg)

	var qb_demand: float = 0.0
	var rb_demand: float = 0.0

	for fa in free_agents:
		var fa_dict: Dictionary = fa as Dictionary
		var player_id: String = String(fa_dict.get("player_id", ""))
		if player_id == "player-qb-elite":
			qb_demand = float(fa_dict.get("minimum_demand", 0.0))
			helper.assert_eq(fa_dict.get("priority_tier", ""), "elite", "Elite QB is elite tier")
		elif player_id == "player-rb-depth":
			rb_demand = float(fa_dict.get("minimum_demand", 0.0))
			helper.assert_eq(fa_dict.get("priority_tier", ""), "depth", "Depth RB is depth tier")

	helper.assert_gt(qb_demand, rb_demand, "Elite QB demand > depth RB demand")
	helper.assert_gt(qb_demand, 5.0, "Elite QB demand > 5M")


func test_generate_team_interest_prioritizes_needs(helper: TestHelpers) -> void:
	print("[TEST] generate_team_interest prioritizes positional needs")

	var world_state := _create_test_world()
	var year := 2024

	# Create FA QB
	var qb: Dictionary = _create_test_player("player-qb", "QB", 26, 78.0)
	var fa_profile: Dictionary = {
		"player_id": "player-qb",
		"position": "QB",
		"age": 26,
		"overall_rating": 78.0,
		"minimum_demand": 12.0,
		"priority_tier": "starter"
	}

	var free_agents: Array = [fa_profile]
	var rng: RandomNumberGenerator = helper.create_seeded_rng(12345)
	var league_cfg: Dictionary = _load_league_config()

	# Remove QB from one team to create need
	world_state["nfl_rosters"]["CAR"]["players"] = []

	var team_interest: Dictionary = FreeAgency.generate_team_interest(
		world_state,
		year,
		free_agents,
		rng,
		league_cfg
	)

	helper.assert_true(team_interest.has("CAR"), "CAR team has interest dict")

	var car_interest: float = float(team_interest.get("CAR", {}).get("player-qb", 0.0))
	helper.assert_gt(car_interest, 1.0, "Team with QB need shows interest")


func test_player_chooses_highest_offer(helper: TestHelpers) -> void:
	print("[TEST] player_chooses_team selects highest offer")

	var player_id: String = "player-wr"
	var team_interest: Dictionary = {
		"NYJ": {"player-wr": 1.5},
		"KC": {"player-wr": 1.2},
		"BUF": {"player-wr": 1.0}
	}

	var offers: Array = [
		{"team_id": "NYJ", "annual_value": 10.0, "offer_quality": 0.9},  # Fair offer
		{"team_id": "KC", "annual_value": 12.0, "offer_quality": 1.1},   # Best offer
		{"team_id": "BUF", "annual_value": 9.0, "offer_quality": 0.8}    # Low offer
	]

	var rng: RandomNumberGenerator = helper.create_seeded_rng(54321)

	var chosen_team: String = FreeAgency.player_chooses_team(player_id, team_interest, offers, rng)

	# KC has best offer, should be chosen most of the time
	# (variance means not 100%, but high probability)
	helper.assert_eq(chosen_team, "KC", "Player chooses team with best offer")


func test_player_chooses_familiarity_bonus(helper: TestHelpers) -> void:
	print("[TEST] player_chooses_team considers familiarity bonus")

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
			"previous_team_id": "BAL"  # Current team
		},
		{
			"team_id": "PIT",
			"annual_value": 8.0,
			"offer_quality": 1.0,
			"previous_team_id": "BAL"  # Not current team
		}
	]

	var rng: RandomNumberGenerator = helper.create_seeded_rng(99999)

	var chosen_team: String = FreeAgency.player_chooses_team(player_id, team_interest, offers, rng)

	# With equal offers, familiarity bonus should favor BAL
	# (10% weight can tip the scales)
	helper.assert_eq(chosen_team, "BAL", "Player gets familiarity bonus for previous team")


func test_franchise_tag_calculates_salary(helper: TestHelpers) -> void:
	print("[TEST] franchise_tag calculates top 5 position average")

	var world_state := _create_test_world()

	# Add QB contracts at various salaries
	var qb_salaries: Array = [25.0, 22.0, 20.0, 18.0, 16.0, 14.0, 12.0]  # Top 5 avg = 20.2

	for i in range(qb_salaries.size()):
		var qb: Dictionary = _create_test_player("qb-%d" % i, "QB", 27, 80.0)
		qb["contract"] = {
			"status": "signed",
			"annual_value": qb_salaries[i]
		}
		world_state["nfl_rosters"]["TEAM_%d" % i] = {"players": [qb]}

	# Add target player
	var target: Dictionary = _create_test_player("player-tag-qb", "QB", 26, 85.0)
	target["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["SF"]["players"] = [target]

	var league_cfg: Dictionary = _load_league_config()

	var tag: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"SF",
		"player-tag-qb",
		"non_exclusive",
		2024,
		league_cfg
	)

	helper.assert_true(not tag.is_empty(), "Franchise tag applied successfully")

	var salary: float = float(tag.get("salary", 0.0))
	var expected_avg: float = (25.0 + 22.0 + 20.0 + 18.0 + 16.0) / 5.0  # 20.2

	helper.assert_approx(salary, expected_avg, 0.5, "Tag salary is top 5 average")


func test_franchise_tag_stored_in_world_state(helper: TestHelpers) -> void:
	print("[TEST] franchise_tag stored in world_state, NOT Team.gd")

	var world_state: Dictionary = _create_test_world()
	var year: int = 2024

	# Add player to tag
	var player: Dictionary = _create_test_player("player-tag", "EDGE", 25, 82.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["NYJ"]["players"] = [player]
	world_state["nfl_teams"][0]["cap_space"] = 50.0

	var league_cfg: Dictionary = _load_league_config()

	var tag: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"NYJ",
		"player-tag",
		"exclusive",
		year,
		league_cfg
	)

	helper.assert_true(not tag.is_empty(), "Tag applied")

	# Verify stored in world_state["franchise_tags"]
	helper.assert_true(world_state.has("franchise_tags"), "world_state has franchise_tags")
	helper.assert_true(world_state["franchise_tags"].has(year), "franchise_tags has year")
	helper.assert_true(
		world_state["franchise_tags"][year].has("NYJ"),
		"franchise_tags[year] has team"
	)

	var stored_tag: Dictionary = world_state["franchise_tags"][year]["NYJ"]
	helper.assert_eq(
		stored_tag.get("player_id", ""),
		"player-tag",
		"Stored tag has correct player_id"
	)


func test_franchise_tag_prevents_free_agency(helper: TestHelpers) -> void:
	print("[TEST] franchise_tag prevents player from entering FA")

	var world_state: Dictionary = _create_test_world()
	var year: int = 2024

	# Add player
	var player: Dictionary = _create_test_player("player-tagged", "CB", 26, 84.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["DAL"]["players"] = [player]
	world_state["nfl_teams"][0]["cap_space"] = 50.0

	var positions_cfg: Dictionary = _load_positions_config()
	var main_cfg: Dictionary = _load_main_config()
	var league_cfg: Dictionary = _load_league_config()

	# Collect FAs before tag
	var free_agents_before: Array = FreeAgency.collect_free_agents(
		world_state,
		year,
		positions_cfg,
		main_cfg
	)

	var found_before: bool = false
	for fa in free_agents_before:
		if fa.get("player_id", "") == "player-tagged":
			found_before = true
			break

	helper.assert_true(found_before, "Player in FA pool before tag")

	# Apply franchise tag
	FreeAgency.apply_franchise_tag(
		world_state,
		"DAL",
		"player-tagged",
		"non_exclusive",
		year,
		league_cfg
	)

	# Player now has active contract (tag = 1-year deal)
	var tagged_player: Dictionary = player  # Reference should be same
	var contract_status: String = String(tagged_player.get("contract", {}).get("status", ""))

	helper.assert_eq(contract_status, "signed", "Tagged player has signed contract")

	var years_remaining: int = int(tagged_player.get("contract", {}).get("years_remaining", 0))
	helper.assert_eq(years_remaining, 1, "Tagged player has 1-year contract")


func test_franchise_tag_one_per_team(helper: TestHelpers) -> void:
	print("[TEST] franchise_tag enforces one tag per team per year")

	var world_state: Dictionary = _create_test_world()
	var year: int = 2024

	# Add two players
	var player1: Dictionary = _create_test_player("player-1", "WR", 26, 82.0)
	player1["contract"] = {"status": "expired", "years_remaining": 0}

	var player2: Dictionary = _create_test_player("player-2", "EDGE", 25, 80.0)
	player2["contract"] = {"status": "expired", "years_remaining": 0}

	world_state["nfl_rosters"]["MIA"]["players"] = [player1, player2]
	world_state["nfl_teams"][0]["cap_space"] = 100.0

	var league_cfg: Dictionary = _load_league_config()

	# Tag first player
	var tag1: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"MIA",
		"player-1",
		"non_exclusive",
		year,
		league_cfg
	)

	helper.assert_true(not tag1.is_empty(), "First tag applied")

	# Try to tag second player (should fail)
	var tag2: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"MIA",
		"player-2",
		"non_exclusive",
		year,
		league_cfg
	)

	helper.assert_true(tag2.is_empty(), "Second tag rejected (one per team)")


func test_franchise_tag_consecutive_penalty(helper: TestHelpers) -> void:
	print("[TEST] franchise_tag applies consecutive year penalty")

	var world_state: Dictionary = _create_test_world()

	# Add player
	var player: Dictionary = _create_test_player("player-consecutive", "OL", 27, 78.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["GB"]["players"] = [player]
	world_state["nfl_teams"][0]["cap_space"] = 100.0

	# Add OL contracts for salary calculation
	for i in range(5):
		var ol: Dictionary = _create_test_player("ol-%d" % i, "OL", 28, 75.0)
		ol["contract"] = {"status": "signed", "annual_value": 10.0}
		world_state["nfl_rosters"]["TEAM_OL_%d" % i] = {"players": [ol]}

	var league_cfg: Dictionary = _load_league_config()

	# Apply tag in year 1
	var tag1: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"GB",
		"player-consecutive",
		"non_exclusive",
		2023,
		league_cfg
	)

	var salary_year_1: float = float(tag1.get("salary", 0.0))

	# Simulate year passing
	player["contract"] = {"status": "expired", "years_remaining": 0}

	# Apply tag in year 2 (consecutive)
	var tag2: Dictionary = FreeAgency.apply_franchise_tag(
		world_state,
		"GB",
		"player-consecutive",
		"non_exclusive",
		2024,
		league_cfg
	)

	var salary_year_2: float = float(tag2.get("salary", 0.0))

	# Year 2 should be 20% higher (1.2x penalty)
	helper.assert_approx(
		salary_year_2 / salary_year_1,
		1.2,
		0.05,
		"Consecutive tag has 20% penalty"
	)


func test_run_free_agency_signs_players(helper: TestHelpers) -> void:
	print("[TEST] run_free_agency signs players and updates rosters")

	var world_state: Dictionary = _create_test_world()
	var year: int = 2024
	var seed: int = 88888

	# Add free agent
	var player: Dictionary = _create_test_player("player-sign", "TE", 25, 72.0)
	player["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["CHI"]["players"] = [player]

	# Give other teams cap space
	for team in world_state["nfl_teams"]:
		team["cap_space"] = 30.0

	var positions_cfg: Dictionary = _load_positions_config()
	var main_cfg: Dictionary = _load_main_config()
	var stats_cfg: Dictionary = {}
	var league_cfg: Dictionary = _load_league_config()

	var result: Dictionary = FreeAgency.run_free_agency(
		world_state,
		year,
		seed,
		positions_cfg,
		main_cfg,
		stats_cfg,
		league_cfg
	)

	helper.assert_true(result.has("signings"), "Result has signings")
	helper.assert_true(result.has("unsigned"), "Result has unsigned")

	var total_participants: int = result["signings"].size() + result["unsigned"].size()
	helper.assert_gte(total_participants, 1, "At least one FA processed")


func test_run_free_agency_deterministic(helper: TestHelpers) -> void:
	print("[TEST] run_free_agency is deterministic with same seed")

	var seed: int = 123456

	# Run 1
	var world_state_1: Dictionary = _create_test_world()
	_add_test_free_agents(world_state_1, 5)

	var positions_cfg: Dictionary = _load_positions_config()
	var main_cfg: Dictionary = _load_main_config()
	var stats_cfg: Dictionary = {}
	var league_cfg: Dictionary = _load_league_config()

	var result1: Dictionary = FreeAgency.run_free_agency(
		world_state_1,
		2024,
		seed,
		positions_cfg,
		main_cfg,
		stats_cfg,
		league_cfg
	)

	# Run 2 with same seed
	var world_state_2: Dictionary = _create_test_world()
	_add_test_free_agents(world_state_2, 5)

	var result2: Dictionary = FreeAgency.run_free_agency(
		world_state_2,
		2024,
		seed,
		positions_cfg,
		main_cfg,
		stats_cfg,
		league_cfg
	)

	# Compare results
	helper.assert_eq(
		result1["signings"].size(),
		result2["signings"].size(),
		"Same number of signings"
	)

	helper.assert_eq(
		result1["unsigned"].size(),
		result2["unsigned"].size(),
		"Same number of unsigned"
	)

	# Check that same players signed with same teams
	if result1["signings"].size() > 0:
		var signing1: Dictionary = result1["signings"][0] as Dictionary
		var signing2: Dictionary = result2["signings"][0] as Dictionary

		helper.assert_eq(
			signing1.get("player_id", ""),
			signing2.get("player_id", ""),
			"Same player signed"
		)

		helper.assert_eq(
			signing1.get("team_id", ""),
			signing2.get("team_id", ""),
			"Signed with same team"
		)


## Helper: Create test world state
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


## Helper: Create test player
func _create_test_player(id: String, position: String, age: int, eval_score: float) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"age": age,
		"eval_score": eval_score,
		"contract": {}
	}


## Helper: Add test free agents to world
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


## Helper: Load positions config
func _load_positions_config() -> Dictionary:
	var path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/positions.json"
	return _load_json_file(path)


## Helper: Load main config
func _load_main_config() -> Dictionary:
	var path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/main.json"
	return _load_json_file(path)


## Helper: Load league config
func _load_league_config() -> Dictionary:
	var path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/world/league.json"
	return _load_json_file(path)


## Helper: Load JSON file
func _load_json_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("ERROR: Cannot load %s" % path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: int = json.parse(json_text)
	if error != OK:
		print("ERROR: Cannot parse %s" % path)
		return {}

	return json.data
