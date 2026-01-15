## GdUnit4 POC Test 4: Schema Validation Test
##
## Verifies that major simulation APIs return data structures with expected fields
## and types. These tests validate function signatures and return contracts to catch
## breaking changes early.
## Migrated from test_api_contracts.gd.
##
## POC Category: Schema Validation Test
extends GdUnitTestSuite

const ConfigService = preload("res://autoloads/Config.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


var _config: Dictionary


func before() -> void:
	var config_service := ConfigService.new()
	_config = {
		"positions": config_service.get_config("positions"),
		"main": config_service.get_config("main"),
		"stats": config_service.get_config("stats"),
		"scouts": config_service.get_config("scouts"),
		"league": config_service.get_config("league")
	}


## Test: PlayerLifecycle.advance_one_year return contract
func test_player_lifecycle_return_contract() -> void:
	var players := [_create_test_player()]
	var rng := _create_seeded_rng(12345)

	var result := PlayerLifecycle.advance_one_year(
		players,
		_config["positions"],
		_config["main"],
		_config["stats"],
		rng,
		{}
	)

	# Verify return structure using custom helper
	TestHelpersGdUnit4.assert_schema(
		self,
		result,
		["players", "retired"],
		"PlayerLifecycle.advance_one_year return contract"
	)

	# Verify types with GdUnit4 fluent assertions
	assert_bool(result["players"] is Array).is_true()
	assert_bool(result["retired"] is Array).is_true()

	# Verify each player has required fields
	if result["players"].size() > 0:
		var player: Dictionary = result["players"][0]
		TestHelpersGdUnit4.assert_schema(
			self,
			player,
			["player_id", "age", "stats", "potential"],
			"Player return contract"
		)
		assert_bool(player["stats"] is Dictionary).is_true()
		assert_bool(player["potential"] is Dictionary).is_true()


## Test: PlayerLifecycle.advance_one_year_parallel return contract
func test_player_lifecycle_parallel_return_contract() -> void:
	var players: Array = []
	# Create 100 players to trigger parallel processing
	for i in range(100):
		players.append(_create_test_player("P%03d" % i, "QB", 19, 70.0 + float(i % 20)))

	var rng := _create_seeded_rng(12345)

	var result := PlayerLifecycle.advance_one_year_parallel(
		players,
		_config["positions"],
		_config["main"],
		_config["stats"],
		rng,
		{},
		0  # Auto-detect threads
	)

	# Verify return structure (same as serial version)
	TestHelpersGdUnit4.assert_schema(
		self,
		result,
		["players", "retired"],
		"PlayerLifecycle.advance_one_year_parallel return contract"
	)

	# Verify player count matches (no players lost)
	var total_output: int = result["players"].size() + result["retired"].size()
	assert_int(total_output).is_equal(100)


## Test: PlayerLifecycle.advance_years return contract
func test_player_lifecycle_multi_year_return_contract() -> void:
	var players := [_create_test_player()]
	var rng := _create_seeded_rng(12345)

	var result := PlayerLifecycle.advance_years(
		players,
		3,  # 3 years
		_config["positions"],
		_config["main"],
		_config["stats"],
		rng,
		{}
	)

	# Verify return structure
	TestHelpersGdUnit4.assert_schema(
		self,
		result,
		["players", "retired"],
		"PlayerLifecycle.advance_years return contract"
	)

	# Verify age progression
	if result["players"].size() > 0:
		var player: Dictionary = result["players"][0]
		assert_int(int(player.get("age", 0))).is_equal(22)  # 19 + 3


## Test: HighSchoolSeason.run return contract
func test_high_school_season_return_contract() -> void:
	var hs_season := HighSchoolSeason.new()

	var players := [
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

	var schools := [
		{"id": "SCHOOL1", "name": "Test High School", "region": "north"}
	]

	var result := hs_season.run(
		players,
		schools,
		_config["positions"],
		_config["main"],
		_config["stats"],
		{"eligibility": {"hs_years": 4, "underclass_years": 2}},
		12345,
		2025
	)

	# Verify return structure
	TestHelpersGdUnit4.assert_schema(
		self,
		result,
		["players", "graduates", "transitions"],
		"HighSchoolSeason.run return contract"
	)

	# Verify types
	assert_bool(result["players"] is Array).is_true()
	assert_bool(result["graduates"] is Array).is_true()
	assert_bool(result["transitions"] is Array).is_true()

	# Verify transition structure
	if result["transitions"].size() > 0:
		var transition: Dictionary = result["transitions"][0]
		TestHelpersGdUnit4.assert_schema(
			self,
			transition,
			["player_id", "name", "old_hs_year", "new_hs_year", "old_status", "new_status", "graduated"],
			"Transition structure"
		)


## Test: PlayerGenerator.generate_class return contract
func test_player_generator_return_contract() -> void:
	var generator := PlayerGenerator.new()

	# Set up generator configuration
	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := _create_seeded_rng(12345)
	var result := generator.generate_class(10, 0.7, rng)

	# Verify returns an array
	assert_bool(result is Array).is_true()
	assert_int(result.size()).is_less_equal(10)

	# Verify each player has required fields
	if result.size() > 0:
		var player: Dictionary = result[0]
		TestHelpersGdUnit4.assert_schema(
			self,
			player,
			["name", "position", "stats", "physicals"],
			"Generated player structure"
		)
		assert_bool(player["stats"] is Dictionary).is_true()
		assert_bool(player["physicals"] is Dictionary).is_true()


## Test: CollegeRecruiting.run return contract
func test_college_recruiting_return_contract() -> void:
	var recruiting := CollegeRecruiting.new()

	var recruits := [
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

	var colleges := [
		{"id": "C1", "name": "Test College", "region": "north", "eliteness": 75.0}
	]

	var pipeline_cfg := {
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

	var class_rules: Dictionary = _config["main"].get("class_rules", {})

	var result := recruiting.run(
		recruits,
		colleges,
		pipeline_cfg,
		_config["positions"],
		_config["stats"],
		class_rules,
		_config["scouts"],
		12345,
		2025
	)

	# Verify return structure
	TestHelpersGdUnit4.assert_schema(
		self,
		result,
		["year", "commitments", "uncommitted", "college_classes", "offers"],
		"CollegeRecruiting.run return contract"
	)

	# Verify types
	assert_bool(typeof(result["year"]) == TYPE_INT).is_true()
	assert_bool(result["commitments"] is Array).is_true()
	assert_bool(result["uncommitted"] is Array).is_true()
	assert_bool(result["college_classes"] is Dictionary).is_true()
	assert_bool(typeof(result["offers"]) == TYPE_INT).is_true()


## Test using assert_schema_typed for stricter validation
func test_player_structure_with_typed_schema() -> void:
	var player := _create_test_player()

	TestHelpersGdUnit4.assert_schema_typed(
		self,
		player,
		{
			"player_id": TYPE_STRING,
			"name": TYPE_STRING,
			"position": TYPE_STRING,
			"age": TYPE_INT,
			"college_year": TYPE_INT,
			"stats": TYPE_DICTIONARY,
			"potential": TYPE_DICTIONARY
		},
		"Test player structure with types"
	)


# ============================================================================
# HELPERS
# ============================================================================

func _create_seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


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
		"college_year": 1,
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
