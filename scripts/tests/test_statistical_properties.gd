extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const ConfigService = preload("res://autoloads/Config.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")

## Statistical Property Tests
##
## Purpose: Verify that generated data follows expected statistical distributions.
## These tests ensure that generation algorithms produce realistic, smooth distributions
## without obvious gaps, biases, or outliers.
##
## RNG Usage: Generates large samples (100-1000 items) to validate statistical properties.
## Each test uses a fixed seed for determinism, but generates multiple items with derived seeds.

func run(t: TestHelpers) -> void:
	test_player_stats_distribution(t)
	test_player_stats_within_bounds(t)
	test_position_distribution(t)
	test_high_school_region_distribution(t)
	test_high_school_eliteness_distribution(t)
	test_player_height_distribution(t)
	test_player_weight_distribution(t)
	test_stats_no_large_gaps(t)

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

## Helper: Create seeded RNG
func _create_seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	return rng

## Helper: Calculate mean of an array of floats
func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum = 0.0
	for v in values:
		sum += float(v)
	return sum / float(values.size())

## Helper: Calculate standard deviation of an array of floats
func _stddev(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var mean_val = _mean(values)
	var sum_sq_diff = 0.0
	for v in values:
		var diff = float(v) - mean_val
		sum_sq_diff += diff * diff
	return sqrt(sum_sq_diff / float(values.size()))

## Helper: Create histogram with specified number of buckets
## Returns array of counts per bucket
func _create_histogram(values: Array, num_buckets: int) -> Array:
	if values.is_empty():
		var empty: Array = []
		empty.resize(num_buckets)
		for i in range(num_buckets):
			empty[i] = 0
		return empty

	var histogram: Array = []
	histogram.resize(num_buckets)
	for i in range(num_buckets):
		histogram[i] = 0

	var min_val = values[0]
	var max_val = values[0]
	for v in values:
		var fv = float(v)
		if fv < float(min_val):
			min_val = fv
		if fv > float(max_val):
			max_val = fv

	var range_size = float(max_val) - float(min_val)
	if range_size < 0.001:  # All values are the same
		histogram[0] = values.size()
		return histogram

	for v in values:
		var fv = float(v)
		var normalized = (fv - float(min_val)) / range_size
		var bucket = int(floor(normalized * float(num_buckets - 1)))
		bucket = clampi(bucket, 0, num_buckets - 1)
		histogram[bucket] += 1

	return histogram

## Helper: Count occurrences of each unique value
func _count_occurrences(values: Array) -> Dictionary:
	var counts := {}
	for v in values:
		var key = String(v)
		if not counts.has(key):
			counts[key] = 0
		counts[key] = int(counts[key]) + 1
	return counts

## Test: Player stats follow expected distribution
## RNG consumption: 500 players × ~20 RNG calls per player = ~10,000 calls
func test_player_stats_distribution(t: TestHelpers) -> void:
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

	var rng = _create_seeded_rng(99887766)
	var players = generator.generate_class(500, 0.7, rng)

	# Collect speed stats
	var speeds: Array = []
	for player in players:
		var p: Dictionary = player
		var stats: Dictionary = p.get("stats", {})
		if stats.has("speed"):
			speeds.append(float(stats["speed"]))

	# Verify we have stats
	t.assert_true(speeds.size() > 0, "players have speed stats")

	# Calculate mean and stddev
	var mean = _mean(speeds)
	var stddev = _stddev(speeds)

	# Verify reasonable distribution
	# Mean should be somewhere in middle range (not all at extremes)
	t.assert_between(mean, 30.0, 80.0, "speed mean is reasonable (%.2f)" % mean)

	# Stddev should show variation (not all identical)
	t.assert_true(stddev > 1.0, "speed stddev shows variation (%.2f)" % stddev)

## Test: All player stats are within valid bounds [0, 100]
## RNG consumption: 500 players × ~20 RNG calls per player = ~10,000 calls
func test_player_stats_within_bounds(t: TestHelpers) -> void:
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

	var rng = _create_seeded_rng(11223344)
	var players = generator.generate_class(500, 0.7, rng)

	# Check all stats are in bounds
	var all_in_bounds = true
	var out_of_bounds_count = 0

	for player in players:
		var p: Dictionary = player
		var stats: Dictionary = p.get("stats", {})
		for stat_name in stats.keys():
			var stat_value = float(stats[stat_name])
			if stat_value < 0.0 or stat_value > 100.0:
				all_in_bounds = false
				out_of_bounds_count += 1

	t.assert_true(all_in_bounds, "all stats within [0, 100] bounds (found %d out of bounds)" % out_of_bounds_count)

## Test: Position distribution is reasonable
## RNG consumption: 500 players × ~5 RNG calls per player = ~2,500 calls
func test_position_distribution(t: TestHelpers) -> void:
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

	var rng = _create_seeded_rng(55443322)
	var players = generator.generate_class(500, 0.7, rng)

	# Count positions
	var positions: Array = []
	for player in players:
		var p: Dictionary = player
		positions.append(p.get("position", ""))

	var position_counts = _count_occurrences(positions)

	# Verify multiple positions exist (not all the same)
	t.assert_true(position_counts.size() > 1, "multiple positions generated (%d unique)" % position_counts.size())

	# Verify no single position dominates completely (> 90%)
	var total = positions.size()
	for pos in position_counts.keys():
		var count = int(position_counts[pos])
		var percent = (float(count) / float(total)) * 100.0
		t.assert_true(percent < 90.0, "position %s not over-represented (%.1f%%)" % [pos, percent])

## Test: High school region distribution is reasonable
## RNG consumption: ~1000 schools × ~5 RNG calls per school = ~5,000 calls
func test_high_school_region_distribution(t: TestHelpers) -> void:
	var config_service = ConfigService.new()
	var generator = HighSchoolGenerator.new()

	var result = generator.generate(12345, HighSchoolGenerator.DEFAULT_CONFIG_KEY, config_service)
	var schools = result.get("schools", [])

	# Collect regions
	var regions: Array = []
	for school in schools:
		var s: Dictionary = school
		regions.append(s.get("region", ""))

	var region_counts = _count_occurrences(regions)

	# Verify multiple regions exist
	t.assert_true(region_counts.size() > 0, "schools have regions (%d unique)" % region_counts.size())

	# If multiple regions configured, verify distribution isn't all in one
	if region_counts.size() > 1:
		var total = regions.size()
		for region in region_counts.keys():
			var count = int(region_counts[region])
			var percent = (float(count) / float(total)) * 100.0
			t.assert_true(percent < 95.0, "region %s not over-represented (%.1f%%)" % [region, percent])

## Test: High school eliteness follows reasonable distribution
## RNG consumption: ~1000 schools × ~5 RNG calls per school = ~5,000 calls
func test_high_school_eliteness_distribution(t: TestHelpers) -> void:
	var config_service = ConfigService.new()
	var generator = HighSchoolGenerator.new()

	var result = generator.generate(98765, HighSchoolGenerator.DEFAULT_CONFIG_KEY, config_service)
	var schools = result.get("schools", [])

	# Collect eliteness values
	var eliteness_values: Array = []
	for school in schools:
		var s: Dictionary = school
		eliteness_values.append(float(s.get("eliteness", 50.0)))

	# Verify we have values
	t.assert_true(eliteness_values.size() > 0, "schools have eliteness values")

	# Calculate mean
	var mean = _mean(eliteness_values)

	# Eliteness should be distributed across the range, not all at extremes
	t.assert_between(mean, 20.0, 80.0, "eliteness mean is reasonable (%.2f)" % mean)

	# Verify all values in valid range
	for val in eliteness_values:
		var fval = float(val)
		t.assert_between(fval, 0.0, 100.0, "eliteness within [0, 100]")

## Test: Player height distribution follows reasonable pattern
## RNG consumption: 200 players × ~20 RNG calls per player = ~4,000 calls
func test_player_height_distribution(t: TestHelpers) -> void:
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

	var rng = _create_seeded_rng(66778899)
	var players = generator.generate_class(200, 0.7, rng)

	# Collect height values
	var heights: Array = []
	for player in players:
		var p: Dictionary = player
		var physicals: Dictionary = p.get("physicals", {})
		if physicals.has("height_in"):
			heights.append(float(physicals["height_in"]))

	# Verify we have heights
	if heights.size() > 0:
		# Calculate mean
		var mean = _mean(heights)

		# Average height should be reasonable for football players (65-78 inches)
		t.assert_between(mean, 65.0, 78.0, "height mean is reasonable (%.2f inches)" % mean)

## Test: Player weight distribution follows reasonable pattern
## RNG consumption: 200 players × ~20 RNG calls per player = ~4,000 calls
func test_player_weight_distribution(t: TestHelpers) -> void:
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

	var rng = _create_seeded_rng(77889900)
	var players = generator.generate_class(200, 0.7, rng)

	# Collect weight values
	var weights: Array = []
	for player in players:
		var p: Dictionary = player
		var physicals: Dictionary = p.get("physicals", {})
		if physicals.has("weight_lb"):
			weights.append(float(physicals["weight_lb"]))

	# Verify we have weights
	if weights.size() > 0:
		# Calculate mean
		var mean = _mean(weights)

		# Average weight should be reasonable for football players (160-280 lbs)
		t.assert_between(mean, 160.0, 280.0, "weight mean is reasonable (%.2f lbs)" % mean)

## Test: Stats distribution has no large gaps (histogram analysis)
## RNG consumption: 500 players × ~20 RNG calls per player = ~10,000 calls
func test_stats_no_large_gaps(t: TestHelpers) -> void:
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

	var rng = _create_seeded_rng(33445566)
	var players = generator.generate_class(500, 0.7, rng)

	# Collect speed stats
	var speeds: Array = []
	for player in players:
		var p: Dictionary = player
		var stats: Dictionary = p.get("stats", {})
		if stats.has("speed"):
			speeds.append(float(stats["speed"]))

	if speeds.size() > 100:  # Only test if we have enough samples
		# Create histogram with 10 buckets
		var histogram = _create_histogram(speeds, 10)

		# Calculate average bucket count
		var total = 0
		for count in histogram:
			total += int(count)
		var average = float(total) / float(histogram.size())

		# Verify no bucket is completely empty (would indicate a gap)
		# Allow up to 2 buckets to be small (< 5% of average) due to edge effects
		var small_buckets = 0
		for count in histogram:
			if int(count) < (average * 0.05):
				small_buckets += 1

		t.assert_true(small_buckets <= 2, "distribution has no large gaps (found %d small buckets)" % small_buckets)
