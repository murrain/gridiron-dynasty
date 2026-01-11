extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const ConfigService = preload("res://autoloads/Config.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const NflTeamGenerator = preload("res://scripts/world/NflTeamGenerator.gd")

## API Contract Tests
##
## Purpose: Verify that major simulation APIs return data structures with expected fields
## and types. These tests validate function signatures and return contracts to catch
## breaking changes early.
##
## RNG Usage: Minimal - only to generate valid test inputs for the APIs

func run(t: TestHelpers) -> void:
	test_player_lifecycle_contract(t)
	test_player_lifecycle_parallel_contract(t)
	test_player_lifecycle_multi_year_contract(t)
	test_college_recruiting_contract(t)
	test_high_school_season_contract(t)
	test_college_season_contract(t)
	test_nfl_season_contract(t)
	test_nfl_draft_contract(t)
	test_player_generator_contract(t)
	test_high_school_generator_contract(t)
	test_nfl_team_generator_contract(t)

## Helper: Load test configuration
func _load_test_config() -> Dictionary:
	var config_service = ConfigService.new()
	return {
		"positions": config_service.get_config("positions"),
		"main": config_service.get_config("main"),
		"stats": config_service.get_config("stats"),
		"scouts": config_service.get_config("scouts"),
		"league": config_service.get_config("league")
	}

## Helper: Create minimal test player
func _create_test_player(
	player_id: String = "TEST001",
	position: String = "QB",
	age: int = 19,
	rating: float = 75.0
) -> Dictionary:
	return {
		"player_id": player_id,
		"name": "Test Player",
		"position": position,
		"age": age,
		"stats": {
			"speed": rating,
			"strength": rating - 5.0,
			"accuracy": rating + 5.0,
			"awareness": rating
		},
		"potential": {
			"speed": rating + 10.0,
			"strength": rating + 5.0,
			"accuracy": rating + 15.0,
			"awareness": rating + 10.0
		},
		"physicals": {
			"height_in": 72.0,
			"weight_lb": 200.0
		}
	}

## Helper: Create minimal world state
func _create_minimal_world_state(year: int = 2025) -> Dictionary:
	return {
		"current_year": year,
		"nfl_teams": [],
		"nfl_rosters": {},
		"colleges": [],
		"college_rosters": {},
		"hs_schools": [],
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}

## Helper: Create seeded RNG
func _create_seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	return rng

## Helper: Verify dictionary has required fields
func _assert_schema(t: TestHelpers, obj: Dictionary, required_fields: Array, message: String) -> void:
	for field in required_fields:
		t.assert_true(obj.has(field), "%s: missing field '%s'" % [message, field])

## Test: PlayerLifecycle.advance_one_year return contract
func test_player_lifecycle_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var players = [_create_test_player()]
	var rng = _create_seeded_rng(12345)

	var result = PlayerLifecycle.advance_one_year(
		players,
		config["positions"],
		config["main"],
		config["stats"],
		rng,
		{}
	)

	# Verify return structure
	_assert_schema(t, result, ["players", "retired"], "PlayerLifecycle.advance_one_year return contract")

	# Verify types
	t.assert_true(result["players"] is Array, "players is Array")
	t.assert_true(result["retired"] is Array, "retired is Array")

	# Verify each player has required fields
	if result["players"].size() > 0:
		var player = result["players"][0]
		_assert_schema(t, player, ["player_id", "age", "stats", "potential"], "Player return contract")
		t.assert_true(player["stats"] is Dictionary, "player stats is Dictionary")
		t.assert_true(player["potential"] is Dictionary, "player potential is Dictionary")

## Test: PlayerLifecycle.advance_one_year_parallel return contract
func test_player_lifecycle_parallel_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var players = []
	# Create 100 players to trigger parallel processing
	for i in range(100):
		players.append(_create_test_player("P%03d" % i, "QB", 19, 70.0 + float(i % 20)))

	var rng = _create_seeded_rng(12345)

	var result = PlayerLifecycle.advance_one_year_parallel(
		players,
		config["positions"],
		config["main"],
		config["stats"],
		rng,
		{},
		0  # Auto-detect threads
	)

	# Verify return structure (same as serial version)
	_assert_schema(t, result, ["players", "retired"], "PlayerLifecycle.advance_one_year_parallel return contract")

	# Verify types
	t.assert_true(result["players"] is Array, "players is Array")
	t.assert_true(result["retired"] is Array, "retired is Array")

	# Verify player count matches (no players lost)
	var total_output = result["players"].size() + result["retired"].size()
	t.assert_eq(total_output, 100, "parallel processing preserves player count")

## Test: PlayerLifecycle.advance_years return contract
func test_player_lifecycle_multi_year_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var players = [_create_test_player()]
	var rng = _create_seeded_rng(12345)

	var result = PlayerLifecycle.advance_years(
		players,
		3,  # 3 years
		config["positions"],
		config["main"],
		config["stats"],
		rng,
		{}
	)

	# Verify return structure
	_assert_schema(t, result, ["players", "retired"], "PlayerLifecycle.advance_years return contract")

	# Verify types
	t.assert_true(result["players"] is Array, "players is Array")
	t.assert_true(result["retired"] is Array, "retired is Array")

	# Verify age progression
	if result["players"].size() > 0:
		var player = result["players"][0]
		t.assert_eq(int(player.get("age", 0)), 22, "advance_years progresses age correctly (19 + 3)")

## Test: CollegeRecruiting.run return contract
func test_college_recruiting_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var recruiting = CollegeRecruiting.new()

	var recruits = [
		{
			"player_id": "R001",
			"name": "Recruit 1",
			"position": "QB",
			"home_region": "north",
			"proximity_bias": 0.7,
			"hs_school_id": "HS1",
			"stats": {"speed": 70.0, "accuracy": 75.0},
			"potential": {"speed": 80.0, "accuracy": 85.0},
			"physicals": {"weight_lb": 200.0},
			"ratings": {"composite_score": 80.0}
		}
	]

	var colleges = [
		{"id": "C1", "name": "Test College", "region": "north", "eliteness": 75.0}
	]

	var pipeline_cfg = {
		"recruiting": {
			"offer_limit": 3,
			"board_limit": 10,
			"class_size_min": 1,
			"class_size_max": 2,
			"rating_weight": 0.55,
			"eliteness_weight": 0.25,
			"proximity_weight": 0.20,
			"region_match_multiplier": 1.35,
			"scout_weight": 0.7,
			"baseline_weight": 0.3,
			"visit_chance": 0.0,
			"visit_bonus": 0.06
		}
	}

	var class_rules = config["main"].get("class_rules", {})

	var result = recruiting.run(
		recruits,
		colleges,
		pipeline_cfg,
		config["positions"],
		config["stats"],
		class_rules,
		config["scouts"],
		12345,
		2025
	)

	# Verify return structure
	_assert_schema(t, result, ["year", "commitments", "uncommitted", "college_classes", "offers"],
		"CollegeRecruiting.run return contract")

	# Verify types
	t.assert_true(typeof(result["year"]) == TYPE_INT, "year is int")
	t.assert_true(result["commitments"] is Array, "commitments is Array")
	t.assert_true(result["uncommitted"] is Array, "uncommitted is Array")
	t.assert_true(result["college_classes"] is Dictionary, "college_classes is Dictionary")
	t.assert_true(typeof(result["offers"]) == TYPE_INT, "offers is int")

	# Verify commitment structure if any exist
	if result["commitments"].size() > 0:
		var commitment = result["commitments"][0]
		_assert_schema(t, commitment, ["player_id", "college_id"], "Commitment structure")

## Test: HighSchoolSeason.run return contract
func test_high_school_season_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var hs_season = HighSchoolSeason.new()

	var players = [
		{
			"player_id": "HS001",
			"name": "HS Player",
			"position": "QB",
			"age": 15,
			"hs_year": 1,
			"eligibility_status": "hs_underclass",
			"hs_school_id": "SCHOOL1",
			"stats": {"speed": 60.0, "accuracy": 65.0},
			"potential": {"speed": 75.0, "accuracy": 80.0},
			"physicals": {"weight_lb": 180.0}
		}
	]

	var schools = [
		{"id": "SCHOOL1", "name": "Test High School", "region": "north"}
	]

	var result = hs_season.run(
		players,
		schools,
		config["positions"],
		config["main"],
		config["stats"],
		{"eligibility": {"hs_years": 4, "underclass_years": 2}},
		12345,
		2025
	)

	# Verify return structure
	_assert_schema(t, result, ["players", "graduates", "transitions"],
		"HighSchoolSeason.run return contract")

	# Verify types
	t.assert_true(result["players"] is Array, "players is Array")
	t.assert_true(result["graduates"] is Array, "graduates is Array")
	t.assert_true(result["transitions"] is Array, "transitions is Array")

	# Verify transition structure
	if result["transitions"].size() > 0:
		var transition = result["transitions"][0]
		_assert_schema(t, transition,
			["player_id", "name", "old_hs_year", "new_hs_year", "old_status", "new_status", "graduated"],
			"Transition structure")

## Test: CollegeSeason.run return contract
func test_college_season_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var college_season = CollegeSeason.new()

	var world_state = _create_minimal_world_state()
	world_state["colleges"] = [
		{"id": "C1", "name": "Test College", "region": "north"}
	]
	world_state["college_rosters"] = {
		"C1": {
			"players": [
				{
					"player_id": "CP001",
					"name": "College Player",
					"position": "QB",
					"age": 19,
					"college_year": 1,
					"college_eligibility_status": "freshman",
					"college_id": "C1",
					"stats": {"speed": 70.0, "accuracy": 75.0},
					"potential": {"speed": 80.0, "accuracy": 85.0},
					"physicals": {"weight_lb": 200.0}
				}
			]
		}
	}

	var result = college_season.run(
		world_state,
		2025,
		12345,
		{"early_declaration": {}},
		config["positions"],
		config["main"],
		config["stats"]
	)

	# Verify return structure
	_assert_schema(t, result, ["year", "rosters_updated", "graduates", "draft_eligible_count", "early_declares", "step_seeds"],
		"CollegeSeason.run return contract")

	# Verify types
	t.assert_true(result["year"] is int, "year is int")
	t.assert_true(result["rosters_updated"] is int, "rosters_updated is int")
	t.assert_true(result["graduates"] is int, "graduates is int")
	t.assert_true(result["draft_eligible_count"] is int, "draft_eligible_count is int")
	t.assert_true(result["early_declares"] is int, "early_declares is int")
	t.assert_true(result["step_seeds"] is Dictionary, "step_seeds is Dictionary")

## Test: NflSeason.run return contract
func test_nfl_season_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var nfl_season = NflSeason.new()

	var world_state = _create_minimal_world_state()
	world_state["nfl_teams"] = [
		{"id": "KC", "name": "Kansas City Chiefs", "abbrev": "KC"}
	]
	world_state["nfl_rosters"] = {
		"KC": {
			"players": [
				{
					"player_id": "NFL001",
					"name": "NFL Player",
					"position": "QB",
					"age": 25,
					"stats": {"speed": 80.0, "accuracy": 85.0},
					"potential": {"speed": 85.0, "accuracy": 90.0},
					"physicals": {"weight_lb": 220.0},
					"contract": {"years_remaining": 2}
				}
			]
		}
	}

	var result = nfl_season.run(
		world_state,
		2025,
		12345,
		config["league"],
		config["positions"],
		config["main"],
		config["stats"]
	)

	# Verify return structure
	_assert_schema(t, result, ["year", "roster_counts", "retirements", "free_agents", "step_seeds"],
		"NflSeason.run return contract")

	# Verify types
	t.assert_true(result["year"] is int, "year is int")
	t.assert_true(result["roster_counts"] is Dictionary, "roster_counts is Dictionary")
	t.assert_true(result["retirements"] is int, "retirements is int")
	t.assert_true(result["free_agents"] is int, "free_agents is int")
	t.assert_true(result["step_seeds"] is Dictionary, "step_seeds is Dictionary")

## Test: NflDraft.run return contract
func test_nfl_draft_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var nfl_draft = NflDraft.new()

	var world_state = _create_minimal_world_state()
	world_state["nfl_teams"] = [
		{"id": "KC", "name": "Kansas City Chiefs", "abbrev": "KC", "draft_order": 1}
	]
	world_state["nfl_rosters"] = {
		"KC": {"players": [], "by_position": {}}
	}
	world_state["draft_pool"] = {
		2025: [
			{
				"player_id": "DRAFT001",
				"name": "Draft Prospect",
				"position": "QB",
				"age": 21,
				"college_year": 3,
				"stats": {"speed": 75.0, "accuracy": 80.0},
				"potential": {"speed": 85.0, "accuracy": 90.0},
				"physicals": {"weight_lb": 215.0}
			}
		]
	}

	var result = nfl_draft.run(
		world_state,
		2025,
		12345,
		config["league"],
		config["positions"],
		config["stats"],
		config["scouts"],
		config["main"]
	)

	# Verify return structure
	_assert_schema(t, result, ["year", "picks", "undrafted_count", "step_seeds"],
		"NflDraft.run return contract")

	# Verify types
	t.assert_true(result["year"] is int, "year is int")
	t.assert_true(result["picks"] is Array, "picks is Array")
	t.assert_true(result["undrafted_count"] is int, "undrafted_count is int")
	t.assert_true(result["step_seeds"] is Dictionary, "step_seeds is Dictionary")

	# Verify pick structure if any exist
	if result["picks"].size() > 0:
		var pick = result["picks"][0]
		_assert_schema(t, pick, ["round", "pick", "team_id", "player_id"], "Draft pick structure")

## Test: PlayerGenerator.generate_class return contract
func test_player_generator_contract(t: TestHelpers) -> void:
	var config = _load_test_config()
	var generator = PlayerGenerator.new()

	# Set up generator configuration
	generator.main_cfg = config["main"]
	generator.positions_data = config["positions"]
	generator.stats_cfg = config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = config["main"].get("class_rules", {})
	generator.combine_tests = config["main"].get("combine_tests", {})
	generator.combine_tuning = config["main"].get("combine_tuning", {})

	var rng = _create_seeded_rng(12345)
	var result = generator.generate_class(10, 0.7, rng)

	# Verify returns an array
	t.assert_true(result is Array, "generate_class returns Array")
	t.assert_between(float(result.size()), 0.0, 10.0, "generate_class returns <= max_players")

	# Verify each player has required fields
	if result.size() > 0:
		var player = result[0]
		_assert_schema(t, player,
			["name", "position", "stats", "physicals"],
			"Generated player structure")
		t.assert_true(player["stats"] is Dictionary, "player stats is Dictionary")
		t.assert_true(player["physicals"] is Dictionary, "player physicals is Dictionary")

## Test: HighSchoolGenerator.generate return contract
func test_high_school_generator_contract(t: TestHelpers) -> void:
	var config_service = ConfigService.new()
	var generator = HighSchoolGenerator.new()

	var result = generator.generate(12345, HighSchoolGenerator.DEFAULT_CONFIG_KEY, config_service)

	# Verify returns a dictionary with schools array
	t.assert_true(result is Dictionary, "generate returns Dictionary")
	t.assert_true(result.has("schools"), "result has schools field")

	var schools = result.get("schools", [])
	t.assert_true(schools is Array, "schools is Array")

	# Verify each school has required fields
	if schools.size() > 0:
		var school = schools[0]
		_assert_schema(t, school, ["id", "name", "region"], "Generated school structure")

## Test: NflTeamGenerator.generate return contract
func test_nfl_team_generator_contract(t: TestHelpers) -> void:
	var generator = NflTeamGenerator.new()

	var result = generator.generate(12345)

	# Verify returns a dictionary with teams array
	t.assert_true(result is Dictionary, "generate returns Dictionary")
	t.assert_true(result.has("teams"), "result has teams field")

	var teams = result.get("teams", [])
	t.assert_true(teams is Array, "teams is Array")
	t.assert_true(teams.size() > 0, "generate returns NFL teams")

	# Verify each team has required fields
	if teams.size() > 0:
		var team = teams[0]
		_assert_schema(t, team, ["id", "name"], "Generated team structure")
