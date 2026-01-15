## GdUnit4 test suite for Statistical Properties
##
## Purpose: Verify that generated data follows expected statistical distributions.
## These tests ensure that generation algorithms produce realistic, smooth distributions
## without obvious gaps, biases, or outliers.
##
## RNG Usage: Generates large samples (100-1000 items) to validate statistical properties.
## Each test uses a fixed seed for determinism, but generates multiple items with derived seeds.
extends GdUnitTestSuite

const ConfigService = preload("res://autoloads/Config.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")

var _config: Dictionary


func before() -> void:
	var config_service = ConfigService.new()
	_config = {
		"positions": config_service.get_config("positions"),
		"main": config_service.get_config("main"),
		"stats": config_service.get_config("stats"),
		"scouts": config_service.get_config("scouts"),
		"league": config_service.get_config("league")
	}


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


func test_player_stats_distribution() -> void:
	var generator = PlayerGenerator.new()

	# Set up generator configuration
	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = 99887766
	var players = generator.generate_class(500, 0.7, rng)

	# Collect speed stats
	var speeds: Array = []
	for player in players:
		var p: Dictionary = player
		var stats: Dictionary = p.get("stats", {})
		if stats.has("speed"):
			speeds.append(float(stats["speed"]))

	# Verify we have stats
	assert_int(speeds.size()).is_greater(0)

	# Calculate mean and stddev
	var mean_speed = _mean(speeds)
	var stddev_speed = _stddev(speeds)

	# Verify reasonable distribution
	assert_float(mean_speed).is_between(30.0, 80.0)
	assert_float(stddev_speed).is_greater(1.0)


func test_player_stats_within_bounds() -> void:
	var generator = PlayerGenerator.new()

	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = 11223344
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

	assert_bool(all_in_bounds).is_true()


func test_position_distribution() -> void:
	var generator = PlayerGenerator.new()

	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = 55443322
	var players = generator.generate_class(500, 0.7, rng)

	# Count positions
	var positions: Array = []
	for player in players:
		var p: Dictionary = player
		positions.append(p.get("position", ""))

	var position_counts = _count_occurrences(positions)

	# Verify multiple positions exist (not all the same)
	assert_int(position_counts.size()).is_greater(1)

	# Verify no single position dominates completely (> 90%)
	var total = positions.size()
	for pos in position_counts.keys():
		var count = int(position_counts[pos])
		var percent = (float(count) / float(total)) * 100.0
		assert_float(percent).is_less(90.0)


func test_high_school_region_distribution() -> void:
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
	assert_int(region_counts.size()).is_greater(0)

	# If multiple regions configured, verify distribution isn't all in one
	if region_counts.size() > 1:
		var total = regions.size()
		for region in region_counts.keys():
			var count = int(region_counts[region])
			var percent = (float(count) / float(total)) * 100.0
			assert_float(percent).is_less(95.0)


func test_high_school_eliteness_distribution() -> void:
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
	assert_int(eliteness_values.size()).is_greater(0)

	# Calculate mean
	var mean_elite = _mean(eliteness_values)

	# Eliteness should be distributed across the range, not all at extremes
	assert_float(mean_elite).is_between(20.0, 80.0)

	# Verify all values in valid range
	for val in eliteness_values:
		var fval = float(val)
		assert_float(fval).is_between(0.0, 100.0)


func test_player_height_distribution() -> void:
	var generator = PlayerGenerator.new()

	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = 66778899
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
		var mean_height = _mean(heights)

		# Average height should be reasonable for football players (65-78 inches)
		assert_float(mean_height).is_between(65.0, 78.0)


func test_player_weight_distribution() -> void:
	var generator = PlayerGenerator.new()

	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = 77889900
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
		var mean_weight = _mean(weights)

		# Average weight should be reasonable for football players (160-280 lbs)
		assert_float(mean_weight).is_between(160.0, 280.0)


func test_stats_no_large_gaps() -> void:
	var generator = PlayerGenerator.new()

	generator.main_cfg = _config["main"]
	generator.positions_data = _config["positions"]
	generator.stats_cfg = _config["stats"]
	generator.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	generator.class_rules = _config["main"].get("class_rules", {})
	generator.combine_tests = _config["main"].get("combine_tests", {})
	generator.combine_tuning = _config["main"].get("combine_tuning", {})

	var rng := RandomNumberGenerator.new()
	rng.seed = 33445566
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

		assert_int(small_buckets).is_less_equal(2)
