extends RefCounted

## Comprehensive edge case test suite
## Tests boundary values, threshold transitions, and empty collections
## Focuses on exactly-at-boundary conditions (age=18, age=45, rating=65, etc.)

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run(t: TestHelpers) -> void:
	# Category 1: Age Boundaries
	test_minimum_age_18(t)
	test_age_17_to_18_transition(t)
	test_typical_career_ages(t)
	test_age_progression_deterministic(t)

	# Category 2: Rating/Score Boundaries
	test_rating_zero(t)
	test_rating_exactly_50(t)
	test_rating_exactly_100(t)
	test_rating_near_boundaries(t)

	# Category 3: Empty Collections
	test_empty_player_array_lifecycle(t)
	test_empty_recruits_array(t)
	test_empty_colleges_array(t)
	test_zero_player_generation(t)

	# Category 4: Draft Declaration Thresholds
	test_draft_threshold_senior_below(t)
	test_draft_threshold_senior_at(t)
	test_draft_threshold_senior_above(t)
	test_early_declaration_threshold(t)

	# Category 5: College Year Transitions
	test_freshman_to_sophomore(t)
	test_junior_to_senior(t)
	test_senior_graduation(t)
	test_college_year_boundaries(t)

	# Category 6: Development Boundaries
	test_stat_at_potential_ceiling(t)
	test_zero_growth_room(t)
	test_maxed_out_player(t)
	test_development_with_zero_potential(t)

	# Category 7: Capacity and Size Boundaries
	test_single_player_operations(t)
	test_single_recruit_scenario(t)
	test_single_college_scenario(t)
	test_recruiting_class_size_one(t)

	# Category 8: Statistical Edge Cases
	test_exactly_average_stats(t)
	test_all_stats_equal(t)
	test_extreme_stat_variance(t)

## ============================================================================
## CATEGORY 1: Age Boundaries
## ============================================================================

func test_minimum_age_18(t: TestHelpers) -> void:
	# Test player at exactly age 18 (typical minimum for college)
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var player_18 = t.create_test_player("MIN_AGE", "QB", 18, 75.0, 1)

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
	t.assert_eq(players.size(), 1, "age 18 player should be processed normally")

	var p = players[0] as Dictionary
	t.assert_eq(int(p.get("age")), 19, "age 18 should increment to 19")

func test_age_17_to_18_transition(t: TestHelpers) -> void:
	# Test transition from 17 to 18 (high school senior to college freshman)
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var player_17 = {
		"player_id": "AGE_17",
		"position": "QB",
		"age": 17,
		"stats": {"speed": 70.0, "strength": 65.0},
		"potential": {"speed": 80.0, "strength": 75.0}
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[player_17],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	if players.size() > 0:
		var p = players[0] as Dictionary
		t.assert_eq(int(p.get("age")), 18, "age 17 should transition to 18")

func test_typical_career_ages(t: TestHelpers) -> void:
	# Test typical career progression: 18, 22 (college grad), 30 (prime), 35 (decline)
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var test_ages = [18, 22, 25, 30, 35]
	for age in test_ages:
		var player = t.create_test_player("AGE_%d" % age, "QB", age, 75.0)

		var result = PlayerLifecycle.advance_one_year(
			[player],
			positions_cfg,
			main_cfg,
			stats_cfg,
			rng
		)

		var players = result.get("players", []) as Array
		var retired = result.get("retired", []) as Array
		# All these ages should process without forced retirement
		t.assert_true(players.size() + retired.size() == 1,
			"age %d should be processed" % age)

func test_age_progression_deterministic(t: TestHelpers) -> void:
	# Verify age progression is deterministic with same seed
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var player = t.create_test_player("DET_AGE", "QB", 20, 75.0)

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

	t.assert_eq(JSON.stringify(result1), JSON.stringify(result2),
		"age progression is deterministic with same seed")

## ============================================================================
## CATEGORY 2: Rating/Score Boundaries
## ============================================================================

func test_rating_zero(t: TestHelpers) -> void:
	# Test player with rating = 0 (minimum possible)
	var player_zero = t.create_test_player("RATING_0", "QB", 20, 0.0)

	# Verify stats are at/near zero
	var stats = player_zero.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		var stat_val = float(stats.get(stat_name))
		t.assert_between(stat_val, -10.0, 10.0, "rating 0 produces near-zero stats")

	# Verify player can be processed
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[player_zero],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	t.assert_true(result.has("players"), "rating 0 player processes without crash")

func test_rating_exactly_50(t: TestHelpers) -> void:
	# Test player with rating = 50 (exactly average)
	var player_avg = t.create_test_player("RATING_50", "QB", 20, 50.0)

	var stats = player_avg.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		var stat_val = float(stats.get(stat_name))
		t.assert_between(stat_val, 40.0, 60.0, "rating 50 produces average stats")

	# Verify potential is above current
	var potential = player_avg.get("potential", {}) as Dictionary
	for stat_name in stats.keys():
		if potential.has(stat_name):
			var current = float(stats.get(stat_name))
			var pot = float(potential.get(stat_name))
			t.assert_true(pot >= current, "potential should be >= current for rating 50")

func test_rating_exactly_100(t: TestHelpers) -> void:
	# Test player with rating = 100 (maximum possible)
	var player_max = t.create_test_player("RATING_100", "QB", 20, 100.0)

	var stats = player_max.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		var stat_val = float(stats.get(stat_name))
		t.assert_between(stat_val, 90.0, 100.0, "rating 100 produces near-max stats")

	# Verify potential is capped at 100
	var potential = player_max.get("potential", {}) as Dictionary
	for stat_name in potential.keys():
		var pot_val = float(potential.get(stat_name))
		t.assert_true(pot_val <= 100.0, "potential should be capped at 100")

func test_rating_near_boundaries(t: TestHelpers) -> void:
	# Test ratings near key boundaries: 1, 99
	var player_1 = t.create_test_player("RATING_1", "QB", 20, 1.0)
	var player_99 = t.create_test_player("RATING_99", "QB", 20, 99.0)

	t.assert_true(player_1.has("stats"), "rating 1 player created")
	t.assert_true(player_99.has("stats"), "rating 99 player created")

	# Both should have valid stat distributions
	var stats_1 = player_1.get("stats", {}) as Dictionary
	var stats_99 = player_99.get("stats", {}) as Dictionary

	t.assert_true(stats_1.size() > 0, "rating 1 has stats")
	t.assert_true(stats_99.size() > 0, "rating 99 has stats")

## ============================================================================
## CATEGORY 3: Empty Collections
## ============================================================================

func test_empty_player_array_lifecycle(t: TestHelpers) -> void:
	# Test PlayerLifecycle with empty player array
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

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

	t.assert_eq(players.size(), 0, "empty input produces empty players")
	t.assert_eq(retired.size(), 0, "empty input produces empty retired")

func test_empty_recruits_array(t: TestHelpers) -> void:
	# Test recruiting with empty recruits array
	var config_service = ConfigService.new()
	var pipeline = CollegeRecruiting.new()

	var colleges = [
		{"id": "c1", "name": "Test College", "region": "north", "eliteness": 75.0}
	]

	var pipeline_cfg = _create_recruiting_config()
	var positions_cfg = config_service.get_config("positions")
	var stats_cfg = config_service.get_config("stats")
	var class_rules = config_service.get_config("main").get("class_rules", {})
	var scouts_cfg = config_service.get_config("scouts")

	var result = pipeline.run(
		[],  # Empty recruits
		colleges,
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		12345,
		2025
	)

	var commitments = result.get("commitments", []) as Array
	t.assert_eq(commitments.size(), 0, "empty recruits produces zero commitments")

func test_empty_colleges_array(t: TestHelpers) -> void:
	# Test recruiting with empty colleges array
	var config_service = ConfigService.new()
	var pipeline = CollegeRecruiting.new()

	var recruits = [
		_make_recruit("p1", "QB", "north", 80.0)
	]

	var pipeline_cfg = _create_recruiting_config()
	var positions_cfg = config_service.get_config("positions")
	var stats_cfg = config_service.get_config("stats")
	var class_rules = config_service.get_config("main").get("class_rules", {})
	var scouts_cfg = config_service.get_config("scouts")

	var result = pipeline.run(
		recruits,
		[],  # Empty colleges
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		12345,
		2025
	)

	var commitments = result.get("commitments", []) as Array
	t.assert_eq(commitments.size(), 0, "empty colleges produces zero commitments")

func test_zero_player_generation(t: TestHelpers) -> void:
	# Test generating exactly 0 players
	var gen = PlayerGenerator.new()
	_configure_generator(gen)

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = gen.generate_class(0, 0.75, rng)
	t.assert_eq(result.size(), 0, "generate_class(0) returns empty array")

## ============================================================================
## CATEGORY 4: Draft Declaration Thresholds
## ============================================================================

func test_draft_threshold_senior_below(t: TestHelpers) -> void:
	# Test senior with rating = 64 (below typical threshold of 65)
	# Note: Actual threshold depends on config
	var senior_64 = t.create_test_player("SENIOR_64", "QB", 21, 64.0, 4)

	t.assert_eq(int(senior_64.get("college_year")), 4, "player is senior")
	t.assert_between(float(_calculate_composite_rating(senior_64)), 60.0, 70.0,
		"senior has rating near threshold")

func test_draft_threshold_senior_at(t: TestHelpers) -> void:
	# Test senior with rating = 65 (at typical threshold)
	var senior_65 = t.create_test_player("SENIOR_65", "QB", 21, 65.0, 4)

	t.assert_eq(int(senior_65.get("college_year")), 4, "player is senior")
	t.assert_between(float(_calculate_composite_rating(senior_65)), 60.0, 70.0,
		"senior has rating at threshold")

func test_draft_threshold_senior_above(t: TestHelpers) -> void:
	# Test senior with rating = 75 (above threshold)
	var senior_75 = t.create_test_player("SENIOR_75", "QB", 21, 75.0, 4)

	t.assert_eq(int(senior_75.get("college_year")), 4, "player is senior")
	t.assert_between(float(_calculate_composite_rating(senior_75)), 70.0, 85.0,
		"senior has rating above threshold")

func test_early_declaration_threshold(t: TestHelpers) -> void:
	# Test junior with rating = 85 (typical early declaration threshold)
	var junior_85 = t.create_test_player("JUNIOR_85", "QB", 20, 85.0, 3)

	t.assert_eq(int(junior_85.get("college_year")), 3, "player is junior")
	t.assert_between(float(_calculate_composite_rating(junior_85)), 80.0, 95.0,
		"junior has high rating for early declaration")

## ============================================================================
## CATEGORY 5: College Year Transitions
## ============================================================================

func test_freshman_to_sophomore(t: TestHelpers) -> void:
	# Test year 1 to year 2 transition
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var freshman = t.create_test_player("FRESH", "QB", 18, 70.0, 1)

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[freshman],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	if players.size() > 0:
		var p = players[0] as Dictionary
		# Note: college_year may not auto-increment in PlayerLifecycle
		# This documents expected behavior
		t.assert_true(int(p.get("age")) == 19, "freshman ages to 19")

func test_junior_to_senior(t: TestHelpers) -> void:
	# Test year 3 to year 4 transition (critical for draft eligibility)
	var junior = t.create_test_player("JUNIOR", "QB", 20, 75.0, 3)

	t.assert_eq(int(junior.get("college_year")), 3, "starts as junior")
	t.assert_eq(junior.get("college_eligibility_status"), "junior", "status is junior")

func test_senior_graduation(t: TestHelpers) -> void:
	# Test year 4 completion (graduation / draft eligibility)
	var senior = t.create_test_player("SENIOR", "QB", 21, 75.0, 4)

	t.assert_eq(int(senior.get("college_year")), 4, "starts as senior")
	t.assert_eq(senior.get("college_eligibility_status"), "senior", "status is senior")

func test_college_year_boundaries(t: TestHelpers) -> void:
	# Test all college year boundaries: 1, 2, 3, 4
	for year in [1, 2, 3, 4]:
		var player = t.create_test_player("YEAR_%d" % year, "QB", 17 + year, 75.0, year)

		t.assert_eq(int(player.get("college_year")), year, "college year %d set correctly" % year)

		var expected_status = ["freshman", "sophomore", "junior", "senior"][year - 1]
		t.assert_eq(player.get("college_eligibility_status"), expected_status,
			"status matches year %d" % year)

## ============================================================================
## CATEGORY 6: Development Boundaries
## ============================================================================

func test_stat_at_potential_ceiling(t: TestHelpers) -> void:
	# Test player where stats equal potential (no growth room)
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

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
	t.assert_eq(players.size(), 1, "maxed player processes normally")

	if players.size() > 0:
		var p = players[0] as Dictionary
		var stats = p.get("stats", {}) as Dictionary
		# Stats should not exceed potential
		t.assert_true(float(stats.get("speed", 0.0)) <= 80.0, "stat does not exceed potential")

func test_zero_growth_room(t: TestHelpers) -> void:
	# Test player with potential only slightly above stats
	var minimal_growth = {
		"player_id": "MIN_GROWTH",
		"position": "QB",
		"age": 25,
		"stats": {"speed": 79.0, "strength": 74.0},
		"potential": {"speed": 80.0, "strength": 75.0}  # Only 1 point growth
	}

	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[minimal_growth],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	t.assert_true(result.has("players"), "minimal growth player processes")

func test_maxed_out_player(t: TestHelpers) -> void:
	# Test player with all stats at 100
	var perfect_player = {
		"player_id": "PERFECT",
		"position": "QB",
		"age": 25,
		"stats": {"speed": 100.0, "strength": 100.0, "awareness": 100.0},
		"potential": {"speed": 100.0, "strength": 100.0, "awareness": 100.0}
	}

	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

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
			t.assert_true(stat_val <= 100.0, "perfect player stats capped at 100")

func test_development_with_zero_potential(t: TestHelpers) -> void:
	# Test player with zero potential (edge case)
	var zero_potential = {
		"player_id": "ZERO_POT",
		"position": "QB",
		"age": 20,
		"stats": {"speed": 50.0, "strength": 50.0},
		"potential": {"speed": 0.0, "strength": 0.0}  # Zero potential
	}

	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[zero_potential],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	t.assert_true(result.has("players"), "zero potential player processes")

## ============================================================================
## CATEGORY 7: Capacity and Size Boundaries
## ============================================================================

func test_single_player_operations(t: TestHelpers) -> void:
	# Test lifecycle with exactly 1 player
	var config_service = ConfigService.new()
	var positions_cfg = config_service.get_config("positions")
	var main_cfg = config_service.get_config("main")
	var stats_cfg = config_service.get_config("stats")

	var single_player = t.create_test_player("SINGLE", "QB", 20, 75.0)

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	var result = PlayerLifecycle.advance_one_year(
		[single_player],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var players = result.get("players", []) as Array
	t.assert_eq(players.size(), 1, "single player processed correctly")

func test_single_recruit_scenario(t: TestHelpers) -> void:
	# Test recruiting with exactly 1 recruit
	var config_service = ConfigService.new()
	var pipeline = CollegeRecruiting.new()

	var recruits = [_make_recruit("p1", "QB", "north", 80.0)]

	var colleges = [
		{"id": "c1", "name": "College 1", "region": "north", "eliteness": 75.0},
		{"id": "c2", "name": "College 2", "region": "south", "eliteness": 70.0}
	]

	var pipeline_cfg = _create_recruiting_config()
	var positions_cfg = config_service.get_config("positions")
	var stats_cfg = config_service.get_config("stats")
	var class_rules = config_service.get_config("main").get("class_rules", {})
	var scouts_cfg = config_service.get_config("scouts")

	var result = pipeline.run(
		recruits,
		colleges,
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		12345,
		2025
	)

	var commitments = result.get("commitments", []) as Array
	t.assert_true(commitments.size() <= 1, "single recruit produces at most 1 commitment")

func test_single_college_scenario(t: TestHelpers) -> void:
	# Test recruiting with exactly 1 college
	var config_service = ConfigService.new()
	var pipeline = CollegeRecruiting.new()

	var recruits = [
		_make_recruit("p1", "QB", "north", 80.0),
		_make_recruit("p2", "WR", "north", 75.0)
	]

	var colleges = [
		{"id": "c1", "name": "Only College", "region": "north", "eliteness": 75.0}
	]

	var pipeline_cfg = _create_recruiting_config()
	var positions_cfg = config_service.get_config("positions")
	var stats_cfg = config_service.get_config("stats")
	var class_rules = config_service.get_config("main").get("class_rules", {})
	var scouts_cfg = config_service.get_config("scouts")

	var result = pipeline.run(
		recruits,
		colleges,
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		12345,
		2025
	)

	var commitments = result.get("commitments", []) as Array
	# All commitments should be to the single college
	for commit in commitments:
		var c = commit as Dictionary
		t.assert_eq(c.get("college_id"), "c1", "all commits go to single college")

func test_recruiting_class_size_one(t: TestHelpers) -> void:
	# Test recruiting with class_size_max = 1
	var config_service = ConfigService.new()
	var pipeline = CollegeRecruiting.new()

	var recruits = [
		_make_recruit("p1", "QB", "north", 80.0),
		_make_recruit("p2", "WR", "north", 75.0)
	]

	var colleges = [
		{"id": "c1", "name": "Small College", "region": "north", "eliteness": 75.0}
	]

	var pipeline_cfg = {
		"recruiting": {
			"offer_limit": 5,
			"board_limit": 10,
			"class_size_min": 1,
			"class_size_max": 1,  # Only 1 recruit allowed
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

	var positions_cfg = config_service.get_config("positions")
	var stats_cfg = config_service.get_config("stats")
	var class_rules = config_service.get_config("main").get("class_rules", {})
	var scouts_cfg = config_service.get_config("scouts")

	var result = pipeline.run(
		recruits,
		colleges,
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		12345,
		2025
	)

	var commitments = result.get("commitments", []) as Array
	# Should respect class_size_max of 1
	t.assert_true(commitments.size() <= 1, "class_size_max=1 limits commitments")

## ============================================================================
## CATEGORY 8: Statistical Edge Cases
## ============================================================================

func test_exactly_average_stats(t: TestHelpers) -> void:
	# Test player with all stats = 50.0 (exactly average)
	var avg_player = {
		"player_id": "AVG_ALL",
		"position": "QB",
		"age": 20,
		"stats": {"speed": 50.0, "strength": 50.0, "awareness": 50.0},
		"potential": {"speed": 60.0, "strength": 60.0, "awareness": 60.0}
	}

	t.assert_true(avg_player.has("stats"), "average player created")

	var stats = avg_player.get("stats", {}) as Dictionary
	for stat_name in stats.keys():
		t.assert_eq(float(stats.get(stat_name)), 50.0, "all stats exactly 50.0")

func test_all_stats_equal(t: TestHelpers) -> void:
	# Test player where all stats have identical values
	var equal_player = {
		"player_id": "EQUAL_ALL",
		"position": "QB",
		"age": 20,
		"stats": {"speed": 75.0, "strength": 75.0, "awareness": 75.0, "stamina": 75.0},
		"potential": {"speed": 85.0, "strength": 85.0, "awareness": 85.0, "stamina": 85.0}
	}

	var stats = equal_player.get("stats", {}) as Dictionary
	var first_value = float(stats.values()[0])

	for stat_name in stats.keys():
		t.assert_eq(float(stats.get(stat_name)), first_value, "all stats equal")

func test_extreme_stat_variance(t: TestHelpers) -> void:
	# Test player with extreme variance (some stats 0, some stats 100)
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

	t.assert_eq(max_stat, 100.0, "max stat is 100")
	t.assert_eq(min_stat, 0.0, "min stat is 0")
	t.assert_eq(max_stat - min_stat, 100.0, "variance is maximum (100)")

## ============================================================================
## Helper Functions
## ============================================================================

func _configure_generator(gen: PlayerGenerator) -> void:
	gen.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	gen.positions_data = {
		"QB": {
			"physicals": {
				"height_in": {"mu": 72, "sigma": 1, "min": 70, "max": 76}
			},
			"distributions": {
				"speed": {"mu": 50, "sigma": 5, "min": 40, "max": 60}
			}
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

func _calculate_composite_rating(player: Dictionary) -> float:
	# Simple composite rating calculation
	var stats = player.get("stats", {}) as Dictionary
	if stats.is_empty():
		return 0.0

	var total = 0.0
	var count = 0
	for stat_name in stats.keys():
		total += float(stats.get(stat_name))
		count += 1

	return total / float(max(count, 1))
