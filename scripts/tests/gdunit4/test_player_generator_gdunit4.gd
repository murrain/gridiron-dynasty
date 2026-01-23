extends GdUnitTestSuite
class_name TestPlayerGeneratorGdUnit4

const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

var _loader: ConfigLoader = null
var _positions_cfg: Dictionary = {}
var _stats_cfg: Dictionary = {}
var _names_cfg: Dictionary = {}
var _main_cfg: Dictionary = {}
var _combine_tests_cfg: Dictionary = {}

## Setup runs before each test
func before_test() -> void:
	_loader = ConfigLoader.new()
	_loader.configure("res://configs/sports/american_football", "", false)
	_positions_cfg = _loader.get_config("positions")
	_stats_cfg = _loader.get_config("stats")
	_names_cfg = _loader.get_config("names")
	_main_cfg = _loader.get_config("main")
	_combine_tests_cfg = _loader.get_config("combine_tests")

## Cleanup after each test
func after_test() -> void:
	_loader = null


# ============================================================================
# DETERMINISM TESTS - CRITICAL FOR SIMULATION INTEGRITY
# ============================================================================

func test_single_player_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			var gen = _create_generator()
			return gen._make_single_player(0.75, rng),
		0xDEADBEEF,
		"single player generation should be deterministic"
	)

func test_generate_class_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			var gen = _create_generator()
			return gen.generate_class(100, 0.75, rng),
		0x12345678,
		"class generation should be deterministic"
	)

func test_freak_assignment_is_deterministic() -> void:
	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xABCDEF)
	var gen1 = _create_generator()
	var players1 = gen1.generate_class(50, 0.75, rng1)
	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0x999888)
	gen1.assign_dynamic_freaks(players1, 3, 0.80, 0.90, rng2)

	var rng3 = TestHelpersGdUnit4.create_seeded_rng(0xABCDEF)
	var gen2 = _create_generator()
	var players2 = gen2.generate_class(50, 0.75, rng3)
	var rng4 = TestHelpersGdUnit4.create_seeded_rng(0x999888)
	gen2.assign_dynamic_freaks(players2, 3, 0.80, 0.90, rng4)

	assert_that(players1).is_equal(players2)

func test_de_age_is_deterministic() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x555666)
	var gen = _create_generator()
	var players = gen.generate_class(20, 0.75, rng)

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(test_rng):
			var test_players = players.duplicate(true)
			var test_gen = _create_generator()
			test_gen.de_age_players(
				test_players,
				_positions_cfg,
				_main_cfg.get("deage", {}),
				_stats_cfg,
				test_rng
			)
			return test_players,
		0x777888,
		"de-age should be deterministic"
	)


# ============================================================================
# GENERATED DATA VALIDITY TESTS
# ============================================================================

func test_generated_player_has_required_fields() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x11111)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	var required_fields := ["name", "position", "stats", "physicals", "tags", "wear", "generation_mode"]
	TestHelpersGdUnit4.assert_schema(self, player, required_fields, "generated player")

func test_generated_player_has_valid_position() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x22222)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	assert_that(player).contains_key("position")
	var position = String(player["position"])
	assert_bool(position.length() > 0).is_true()
	# Position should be in positions config
	assert_bool(_positions_cfg.has(position)).is_true()

func test_generated_player_stats_are_numeric() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x33333)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	var stats: Dictionary = player.get("stats", {})
	assert_that(stats.size()).is_greater(0)

	for stat_name in stats.keys():
		var stat_value = stats[stat_name]
		var value_type = typeof(stat_value)
		assert_bool(value_type == TYPE_FLOAT or value_type == TYPE_INT).override_failure_message(
			"Stat '%s' should be numeric, got type %d" % [stat_name, value_type]
		).is_true()

func test_generated_player_stats_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x44444)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	var stats: Dictionary = player.get("stats", {})
	for stat_name in stats.keys():
		var value = float(stats[stat_name])
		# Stats should typically be 0-100 range
		assert_float(value).is_greater_equal(0.0)
		assert_float(value).is_less_equal(120.0)  # Allow some wiggle room for boosted stats

func test_generated_class_has_correct_count() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x55555)
	var gen = _create_generator()
	var class_size = 250
	var players = gen.generate_class(class_size, 0.75, rng)

	assert_int(players.size()).is_equal(class_size)

func test_generated_class_has_position_distribution() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x66666)
	var gen = _create_generator()
	var players = gen.generate_class(200, 0.75, rng)

	var position_counts := {}
	for player in players:
		var pos = String((player as Dictionary).get("position", ""))
		position_counts[pos] = position_counts.get(pos, 0) + 1

	# Should have multiple positions represented
	assert_that(position_counts.size()).is_greater(5)

func test_generated_player_has_wear_tracking() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x77777)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	assert_that(player).contains_key("wear")
	var wear: Dictionary = player["wear"]
	assert_that(wear).contains_key("snaps")
	assert_that(wear).contains_key("collisions")
	assert_that(wear).contains_key("injury_count")
	assert_int(wear["snaps"]).is_equal(0)
	assert_int(wear["collisions"]).is_equal(0)
	assert_int(wear["injury_count"]).is_equal(0)

func test_generated_player_has_development_report() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x88888)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	assert_that(player).contains_key("development_report")
	var report = player["development_report"]
	assert_that(report).is_instanceof(Array)
	assert_int((report as Array).size()).is_equal(0)

func test_generated_player_has_generation_mode() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x99999)
	var gen = _create_generator()
	var player = gen._make_single_player(0.75, rng)

	assert_that(player).contains_key("generation_mode")
	var mode = String(player["generation_mode"])
	assert_bool(mode == "templated" or mode == "chaos").is_true()

func test_chaos_vs_templated_distribution() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xAAAAA)
	var gen = _create_generator()
	var players = gen.generate_class(500, 0.75, rng)

	var chaos_count := 0
	var templated_count := 0

	for player in players:
		var mode = String((player as Dictionary).get("generation_mode", ""))
		if mode == "chaos":
			chaos_count += 1
		elif mode == "templated":
			templated_count += 1

	# Should be roughly 80/20 split (templated/chaos)
	# With 500 players, expect ~100 chaos (allow 50-150 range for variance)
	assert_int(chaos_count).is_greater(50)
	assert_int(chaos_count).is_less(150)
	assert_int(templated_count).is_greater(350)


# ============================================================================
# FREAK ASSIGNMENT TESTS
# ============================================================================

func test_freak_assignment_adds_tag() -> void:
	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xBBBBB)
	var gen = _create_generator()
	var players = gen.generate_class(100, 0.75, rng1)

	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xCCCCC)
	gen.assign_dynamic_freaks(players, 5, 0.80, 0.90, rng2)

	var freak_count := 0
	for player in players:
		var tags = (player as Dictionary).get("tags", [])
		if "PotentialSuperstar" in tags:
			freak_count += 1

	assert_int(freak_count).is_greater(0)
	assert_int(freak_count).is_less_equal(5)

func test_freak_assignment_boosts_athletic_stats() -> void:
	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xDDDDD)
	var gen = _create_generator()
	var players = gen.generate_class(50, 0.75, rng1)

	# Store original stats
	var original_stats := []
	for player in players:
		original_stats.append((player as Dictionary).get("stats", {}).duplicate(true))

	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xEEEEE)
	gen.assign_dynamic_freaks(players, 3, 0.80, 0.90, rng2)

	# Find freaks and verify boost
	var found_freak := false
	for i in players.size():
		var player: Dictionary = players[i]
		var tags = player.get("tags", [])
		if "PotentialSuperstar" in tags:
			found_freak = true
			var new_stats: Dictionary = player.get("stats", {})
			var old_stats: Dictionary = original_stats[i]

			# At least one athletic stat should be boosted
			var speed_boosted = new_stats.get("speed", 0.0) > old_stats.get("speed", 0.0)
			var strength_boosted = new_stats.get("strength", 0.0) > old_stats.get("strength", 0.0)
			var agility_boosted = new_stats.get("agility", 0.0) > old_stats.get("agility", 0.0)

			assert_bool(speed_boosted or strength_boosted or agility_boosted).is_true()

	assert_bool(found_freak).override_failure_message(
		"Should have assigned at least one freak"
	).is_true()


# ============================================================================
# EDGE CASES AND ERROR HANDLING
# ============================================================================

func test_generate_class_with_zero_size() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xFFFFF)
	var gen = _create_generator()
	var players = gen.generate_class(0, 0.75, rng)

	assert_int(players.size()).is_equal(0)

func test_freak_assignment_with_zero_max() -> void:
	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0x10101)
	var gen = _create_generator()
	var players = gen.generate_class(50, 0.75, rng1)

	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0x20202)
	gen.assign_dynamic_freaks(players, 0, 0.80, 0.90, rng2)

	# Should not crash, no freaks assigned
	var freak_count := 0
	for player in players:
		var tags = (player as Dictionary).get("tags", [])
		if "PotentialSuperstar" in tags:
			freak_count += 1

	assert_int(freak_count).is_equal(0)

func test_freak_assignment_with_empty_array() -> void:
	var gen = _create_generator()
	var players: Array = []
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x30303)

	# Should not crash
	gen.assign_dynamic_freaks(players, 5, 0.80, 0.90, rng)
	assert_int(players.size()).is_equal(0)


# ============================================================================
# COMBINE DATA TESTS
# ============================================================================

func test_generated_class_has_combine_data() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0x40404)
	var gen = _create_generator()
	var players = gen.generate_class(10, 0.75, rng)

	for player in players:
		var p: Dictionary = player
		assert_that(p).contains_key("combine")
		var combine: Dictionary = p["combine"]
		assert_that(combine.size()).is_greater(0)


# ============================================================================
# HELPER METHODS
# ============================================================================

func _create_generator() -> PlayerGenerator:
	var gen = PlayerGenerator.new()
	gen.main_cfg = _main_cfg
	gen.positions_data = _positions_cfg
	gen.stats_cfg = _stats_cfg
	gen.names_cfg = _names_cfg
	gen.class_rules = _main_cfg.get("class_rules", {})
	gen.combine_tests = _combine_tests_cfg
	gen.combine_tuning = _combine_tests_cfg.get("defaults", {})
	return gen
