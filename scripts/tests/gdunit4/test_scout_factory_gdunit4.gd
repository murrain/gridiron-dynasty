## GdUnit4 test suite for ScoutFactory
##
## Validates scout generation with deterministic seeds and stat coverage.
## Migrated from test_scout_factory.gd
extends GdUnitTestSuite

const ConfigService = preload("res://autoloads/Config.gd")
const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")

var _stats_cfg: Dictionary
var _scouts_cfg: Dictionary
var _factory: ScoutFactory


func before() -> void:
	var config_service := ConfigService.new()
	_stats_cfg = config_service.get_config("stats")
	_scouts_cfg = config_service.get_config("scouts")

	_factory = ScoutFactory.new()
	_factory.setup(_stats_cfg, _scouts_cfg)


func test_deterministic_scout_creation() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var scout_a := _factory.create_random_scout("Test Scout", rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var scout_b := _factory.create_random_scout("Test Scout", rng_b)

	assert_float(scout_a.base_skill).is_equal_approx(scout_b.base_skill, 0.0001)


func test_tape_grinder_matches_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var scout_a := _factory.create_random_scout("Test Scout", rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var scout_b := _factory.create_random_scout("Test Scout", rng_b)

	assert_float(scout_a.tape_grinder).is_equal_approx(scout_b.tape_grinder, 0.0001)


func test_stat_skill_matches_for_same_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var scout_a := _factory.create_random_scout("Test Scout", rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var scout_b := _factory.create_random_scout("Test Scout", rng_b)

	var stat_name := String(((_stats_cfg.get("stats", []) as Array)[0] as Dictionary).get("name", ""))
	assert_float(float(scout_a.stat_skill.get(stat_name, 0.0))).is_equal_approx(float(scout_b.stat_skill.get(stat_name, 0.0)), 0.0001)


func test_stat_skills_cover_all_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var scout := _factory.create_random_scout("Test Scout", rng)

	var stat_count := (_stats_cfg.get("stats", []) as Array).size()
	assert_int((scout.stat_skill as Dictionary).size()).is_equal(stat_count)


func test_create_team_scouts_returns_requested_count() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var team_scouts := _factory.create_team_scouts("Dragons", 2, rng)

	assert_int(team_scouts.size()).is_equal(2)


func test_team_scouts_use_team_role() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var team_scouts := _factory.create_team_scouts("Dragons", 2, rng)

	for scout in team_scouts:
		assert_str(String((scout as Resource).get("role"))).is_equal("Team")


func test_different_seeds_produce_different_scouts() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1111
	var scout_a := _factory.create_random_scout("Scout A", rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 9999
	var scout_b := _factory.create_random_scout("Scout B", rng_b)

	# With very different seeds, base_skill should differ
	var diff := absf(scout_a.base_skill - scout_b.base_skill)
	assert_float(diff).is_greater(0.0)
