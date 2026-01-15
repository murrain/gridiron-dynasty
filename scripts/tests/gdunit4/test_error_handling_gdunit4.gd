## GdUnit4 test suite for Error Handling
##
## Tests system behavior with invalid inputs, missing data, and boundary violations.
## Verifies graceful degradation and appropriate error handling.
##
## Migrated from test_error_handling.gd
extends GdUnitTestSuite

const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _config: ConfigService
var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _stats_cfg: Dictionary
var _class_rules: Dictionary
var _scouts_cfg: Dictionary


func before() -> void:
	_config = ConfigService.new()
	_positions_cfg = _config.get_config("positions")
	_main_cfg = _config.get_config("main")
	_stats_cfg = _config.get_config("stats")
	_class_rules = _main_cfg.get("class_rules", {})
	_scouts_cfg = _config.get_config("scouts")


func _configure_generator(gen: PlayerGenerator) -> void:
	gen.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	gen.positions_data = {
		"QB": {
			"physicals": {"height_in": {"mu": 72, "sigma": 1, "min": 70, "max": 76}},
			"distributions": {"speed": {"mu": 50, "sigma": 5, "min": 40, "max": 60}}
		}
	}
	gen.stats_cfg = {"stats": [
		{"name": "speed", "mu": 50, "sigma": 5, "min": 40, "max": 60},
		{"name": "strength", "mu": 60, "sigma": 5, "min": 50, "max": 70}
	]}
	gen.class_rules = {"position_weights": {"QB": 1.0}}
	gen.combine_tests = {}
	gen.combine_tuning = {}
	gen.main_cfg = {}


func _make_recruit(player_id: String, position: String, region: String, composite: float) -> Dictionary:
	return {
		"player_id": player_id,
		"position": position,
		"region": region,
		"composite_rating": composite,
		"stats": {
			"speed": composite * 0.9,
			"strength": composite * 0.95,
			"awareness": composite * 0.85
		},
		"bias": 0.5
	}


func _create_recruiting_config() -> Dictionary:
	return {
		"recruiting": {
			"offer_limit": 30,
			"board_limit": 120,
			"class_size_min": 15,
			"class_size_max": 25,
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


func test_player_generator_zero_count_returns_empty() -> void:
	var gen := PlayerGenerator.new()
	_configure_generator(gen)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := gen.generate_class(0, 0.75, rng)

	assert_int(result.size()).is_equal(0)


func test_hs_generator_validates_bad_config() -> void:
	var gen := HighSchoolGenerator.new()
	var bad_config := {
		"school_count": 0,
		"regions": [],
		"eliteness_tiers": [],
		"program_quality": {}
	}

	var is_valid := gen._validate_config(bad_config, false)

	assert_bool(is_valid).is_false()


func test_recruiting_empty_recruits_produces_zero_commitments() -> void:
	var pipeline := CollegeRecruiting.new()
	var colleges := [
		{"id": "c1", "name": "Test College", "region": "north", "eliteness": 75.0}
	]

	var result := pipeline.run(
		[],
		colleges,
		_create_recruiting_config(),
		_positions_cfg,
		_stats_cfg,
		_class_rules,
		_scouts_cfg,
		12345,
		2025
	)

	var commitments := result.get("commitments", []) as Array
	assert_int(commitments.size()).is_equal(0)


func test_recruiting_empty_colleges_produces_zero_commitments() -> void:
	var pipeline := CollegeRecruiting.new()
	var recruits := [_make_recruit("p1", "QB", "north", 80.0)]

	var result := pipeline.run(
		recruits,
		[],
		_create_recruiting_config(),
		_positions_cfg,
		_stats_cfg,
		_class_rules,
		_scouts_cfg,
		12345,
		2025
	)

	var commitments := result.get("commitments", []) as Array
	assert_int(commitments.size()).is_equal(0)


func test_recruiting_both_empty_returns_valid_structure() -> void:
	var pipeline := CollegeRecruiting.new()

	var result := pipeline.run(
		[],
		[],
		_create_recruiting_config(),
		_positions_cfg,
		_stats_cfg,
		_class_rules,
		_scouts_cfg,
		12345,
		2025
	)

	assert_bool(result.has("commitments")).is_true()


func test_lifecycle_handles_negative_age_without_crash() -> void:
	var invalid_player := {
		"player_id": "INVALID_NEG_AGE",
		"position": "QB",
		"age": -5,
		"stats": {"speed": 50.0, "strength": 50.0},
		"potential": {"speed": 60.0, "strength": 60.0}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerLifecycle.advance_one_year(
		[invalid_player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng
	)

	var players := result.get("players", []) as Array
	assert_int(players.size()).is_greater_equal(0)


func test_lifecycle_handles_extreme_age_without_crash() -> void:
	var extreme_player := {
		"player_id": "EXTREME_AGE",
		"position": "QB",
		"age": 150,
		"stats": {"speed": 50.0, "strength": 50.0},
		"potential": {"speed": 60.0, "strength": 60.0}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerLifecycle.advance_one_year(
		[extreme_player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng
	)

	var players := result.get("players", []) as Array
	var retired := result.get("retired", []) as Array
	assert_int(players.size() + retired.size()).is_greater_equal(0)


func test_lifecycle_handles_missing_position_without_crash() -> void:
	var no_position_player := {
		"player_id": "NO_POS",
		"age": 20,
		"stats": {"speed": 50.0, "strength": 50.0},
		"potential": {"speed": 60.0, "strength": 60.0}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerLifecycle.advance_one_year(
		[no_position_player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng
	)

	assert_bool(result.has("players")).is_true()


func test_lifecycle_handles_empty_stats_without_crash() -> void:
	var no_stats_player := {
		"player_id": "NO_STATS",
		"position": "QB",
		"age": 20,
		"stats": {},
		"potential": {"speed": 60.0}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerLifecycle.advance_one_year(
		[no_stats_player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng
	)

	assert_bool(result.has("players")).is_true()


func test_lifecycle_empty_player_array_returns_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerLifecycle.advance_one_year(
		[],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng
	)

	var players := result.get("players", []) as Array
	var retired := result.get("retired", []) as Array
	assert_int(players.size()).is_equal(0)
	assert_int(retired.size()).is_equal(0)


func test_recruiting_handles_invalid_player_ids_without_crash() -> void:
	var pipeline := CollegeRecruiting.new()
	var recruits := [
		_make_recruit("", "QB", "north", 80.0),
		{"position": "WR", "region": "south"}
	]
	var colleges := [
		{"id": "c1", "name": "Test College", "region": "north", "eliteness": 75.0}
	]

	var result := pipeline.run(
		recruits,
		colleges,
		_create_recruiting_config(),
		_positions_cfg,
		_stats_cfg,
		_class_rules,
		_scouts_cfg,
		12345,
		2025
	)

	assert_bool(result.has("commitments")).is_true()


func test_recruiting_handles_mismatched_regions_without_crash() -> void:
	var pipeline := CollegeRecruiting.new()
	var recruits := [
		_make_recruit("p1", "QB", "undefined_region", 80.0),
		_make_recruit("p2", "WR", "", 75.0)
	]
	var colleges := [
		{"id": "c1", "name": "Test College", "region": "also_undefined", "eliteness": 75.0}
	]

	var result := pipeline.run(
		recruits,
		colleges,
		_create_recruiting_config(),
		_positions_cfg,
		_stats_cfg,
		_class_rules,
		_scouts_cfg,
		12345,
		2025
	)

	assert_bool(result.has("commitments")).is_true()
