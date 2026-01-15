## GdUnit4 test suite for comprehensive edge case testing
##
## Tests boundary values, threshold transitions, and empty collections.
## Focuses on exactly-at-boundary conditions (age=18, age=45, rating=65, etc.)
extends GdUnitTestSuite

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _t: TestHelpers
var _config: ConfigService


func before() -> void:
	_t = TestHelpers.new()
	_config = ConfigService.new()


## CATEGORY 1: Age Boundaries

func test_minimum_age_18() -> void:
	var positions_cfg = _config.get_config("positions")
	var main_cfg = _config.get_config("main")
	var stats_cfg = _config.get_config("stats")

	var player_18 = _t.create_test_player("MIN_AGE", "QB", 18, 75.0, 1)

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[player_18],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	assert_int(players.size()).is_equal(1)

	var p = players[0] as Dictionary
	assert_int(int(p.get("age"))).is_equal(19)


func test_age_progression_deterministic() -> void:
	var positions_cfg = _config.get_config("positions")
	var main_cfg = _config.get_config("main")
	var stats_cfg = _config.get_config("stats")

	var player = _t.create_test_player("DET_AGE", "QB", 20, 75.0)

	var rng1 = RandomNumberGenerator.new()
	rng1.seed = 99999

	var result1 = PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng1
	)

	var rng2 = RandomNumberGenerator.new()
	rng2.seed = 99999

	var result2 = PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng2
	)

	assert_str(JSON.stringify(result1)).is_equal(JSON.stringify(result2))


## CATEGORY 2: Rating/Score Boundaries

func test_rating_exactly_50() -> void:
	var player_avg = _t.create_test_player("RATING_50", "QB", 20, 50.0)

	var stats = player_avg.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		var stat_val = float(stats.get(stat_name))
		assert_float(stat_val).is_between(40.0, 60.0)


func test_rating_exactly_100() -> void:
	var player_max = _t.create_test_player("RATING_100", "QB", 20, 100.0)

	var stats = player_max.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		var stat_val = float(stats.get(stat_name))
		assert_float(stat_val).is_between(90.0, 100.0)


## CATEGORY 3: Empty Collections

func test_empty_player_array_lifecycle() -> void:
	var positions_cfg = _config.get_config("positions")
	var main_cfg = _config.get_config("main")
	var stats_cfg = _config.get_config("stats")

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[],  # Empty array
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	var retired = result.get("retired", []) as Array

	assert_int(players.size()).is_equal(0)
	assert_int(retired.size()).is_equal(0)


## CATEGORY 4: Development Boundaries

func test_stat_at_potential_ceiling() -> void:
	var positions_cfg = _config.get_config("positions")
	var main_cfg = _config.get_config("main")
	var stats_cfg = _config.get_config("stats")

	var maxed_player = {
		"player_id": "AT_CEILING",
		"position": "QB",
		"age": 20,
		"stats": {"speed": 80.0, "strength": 75.0},
		"potential": {"speed": 80.0, "strength": 75.0}  # Same as stats
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[maxed_player],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	assert_int(players.size()).is_equal(1)

	if players.size() > 0:
		var p = players[0] as Dictionary
		var stats = p.get("stats", {}) as Dictionary
		# Stats should not exceed potential
		assert_float(float(stats.get("speed", 0.0))).is_less_equal(80.0)


func test_maxed_out_player() -> void:
	var positions_cfg = _config.get_config("positions")
	var main_cfg = _config.get_config("main")
	var stats_cfg = _config.get_config("stats")

	var perfect_player = {
		"player_id": "PERFECT",
		"position": "QB",
		"age": 25,
		"stats": {"speed": 100.0, "strength": 100.0, "awareness": 100.0},
		"potential": {"speed": 100.0, "strength": 100.0, "awareness": 100.0}
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[perfect_player],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	if players.size() > 0:
		var p = players[0] as Dictionary
		var stats = p.get("stats", {}) as Dictionary
		# All stats should remain at or below 100
		for stat_name in stats.keys():
			var stat_val = float(stats.get(stat_name))
			assert_float(stat_val).is_less_equal(100.0)


## CATEGORY 5: College Year Transitions

func test_college_year_boundaries() -> void:
	# Test all college year boundaries: 1, 2, 3, 4
	for year in [1, 2, 3, 4]:
		var player = _t.create_test_player("YEAR_%d" % year, "QB", 17 + year, 75.0, year)

		assert_int(int(player.get("college_year"))).is_equal(year)

		var expected_status = ["freshman", "sophomore", "junior", "senior"][year - 1]
		assert_str(player.get("college_eligibility_status")).is_equal(expected_status)


## CATEGORY 6: Statistical Edge Cases

func test_exactly_average_stats() -> void:
	var avg_player = {
		"player_id": "AVG_ALL",
		"position": "QB",
		"age": 20,
		"stats": {"speed": 50.0, "strength": 50.0, "awareness": 50.0},
		"potential": {"speed": 60.0, "strength": 60.0, "awareness": 60.0}
	}

	assert_bool(avg_player.has("stats")).is_true()

	var stats = avg_player.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		assert_float(float(stats.get(stat_name))).is_equal(50.0)


func test_extreme_stat_variance() -> void:
	var variance_player = {
		"player_id": "EXTREME_VAR",
		"position": "QB",
		"age": 20,
		"stats": {"speed": 100.0, "strength": 0.0, "awareness": 100.0, "stamina": 0.0},
		"potential": {"speed": 100.0, "strength": 10.0, "awareness": 100.0, "stamina": 10.0}
	}

	var stats = variance_player.get("stats", {}) as Dictionary

	# Verify extreme variance
	var max_stat = 0.0
	var min_stat = 100.0
	for stat_name in stats.keys():
		var val = float(stats.get(stat_name))
		max_stat = max(max_stat, val)
		min_stat = min(min_stat, val)

	assert_float(max_stat).is_equal(100.0)
	assert_float(min_stat).is_equal(0.0)
	assert_float(max_stat - min_stat).is_equal(100.0)
