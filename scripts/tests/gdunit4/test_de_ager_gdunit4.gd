extends GdUnitTestSuite
class_name TestDeAgerGdUnit4

const DeAger = preload("res://scripts/generation/helpers/DeAger.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

var _positions_cfg: Dictionary = {}
var _stats_cfg: Dictionary = {}
var _deage_cfg: Dictionary = {}

func before_test() -> void:
	var loader = ConfigLoader.new()
	loader.configure("res://configs/sports/american_football", "", false)
	_positions_cfg = loader.get_config("positions")
	_stats_cfg = loader.get_config("stats")
	var main_cfg = loader.get_config("main")
	_deage_cfg = main_cfg.get("deage", {})

	# Set up test deage config if not present
	if _deage_cfg.is_empty():
		_deage_cfg = {
			"core_stats": ["speed", "strength", "acceleration", "agility"],
			"secondary_stats": ["awareness", "reaction_time"],
			"core_pct_min": 0.65,
			"core_pct_max": 0.75,
			"core_var": 0.08,
			"secondary_pct_min": 0.55,
			"secondary_pct_max": 0.70,
			"secondary_var": 0.12,
			"other_pct_min": 0.45,
			"other_pct_max": 0.65,
			"other_var": 0.15,
			"noise_min": -2.0,
			"noise_max": 2.0,
			"floor": 20.0,
			"ceil": 100.0,
			"target_age": 18
		}


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_de_age_is_deterministic() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {
			"speed": 80.0,
			"strength": 75.0,
			"awareness": 85.0,
			"route_running": 70.0
		}
	}

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng),
		0xDEAGE1,
		"de-age should be deterministic"
	)


# ============================================================================
# DE-AGING LOGIC TESTS
# ============================================================================

func test_de_age_reduces_stats() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {
			"speed": 85.0,
			"strength": 80.0,
			"awareness": 88.0
		}
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0001)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	# De-aged stats should be lower than original (on average)
	var deaged_stats: Dictionary = deaged["stats"]
	assert_float(deaged_stats["speed"]).is_less(85.0)
	assert_float(deaged_stats["strength"]).is_less(80.0)

func test_de_age_sets_target_age() -> void:
	var player := {
		"position": "RB",
		"age": 23,
		"stats": {"speed": 80.0}
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0002)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	assert_int(deaged["age"]).is_equal(18)

func test_de_age_preserves_position() -> void:
	var player := {
		"position": "WR",
		"age": 22,
		"stats": {"speed": 88.0, "catching": 82.0}
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0003)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	assert_str(deaged["position"]).is_equal("WR")

func test_de_age_respects_floor() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {"speed": 25.0}  # Very low stat
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0004)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	var deaged_stats: Dictionary = deaged["stats"]
	assert_float(deaged_stats["speed"]).is_greater_equal(20.0)  # Floor

func test_de_age_respects_ceiling() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {"speed": 98.0}  # Very high stat
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0005)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	var deaged_stats: Dictionary = deaged["stats"]
	assert_float(deaged_stats["speed"]).is_less_equal(100.0)  # Ceiling

func test_de_age_maintains_stat_structure() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {
			"speed": 80.0,
			"strength": 75.0,
			"awareness": 85.0,
			"accuracy": 88.0
		}
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0006)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	var deaged_stats: Dictionary = deaged["stats"]
	assert_that(deaged_stats).contains_key("speed")
	assert_that(deaged_stats).contains_key("strength")
	assert_that(deaged_stats).contains_key("awareness")
	assert_that(deaged_stats).contains_key("accuracy")


# ============================================================================
# CATEGORY SCALING TESTS
# ============================================================================

func test_core_stats_have_less_reduction() -> void:
	# Core stats should be reduced less than other stats
	var player := {
		"position": "RB",
		"age": 22,
		"stats": {
			"speed": 85.0,          # Core
			"strength": 80.0,       # Core
			"route_running": 70.0   # Other
		}
	}

	var total_core_reduction := 0.0
	var total_other_reduction := 0.0
	var count := 20

	for i in count:
		var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0000 + i)
		var test_player = player.duplicate(true)
		var deaged = DeAger.de_age(test_player, _positions_cfg, _deage_cfg, _stats_cfg, rng)
		var deaged_stats: Dictionary = deaged["stats"]

		total_core_reduction += (85.0 - deaged_stats["speed"]) + (80.0 - deaged_stats["strength"])
		total_other_reduction += (70.0 - deaged_stats["route_running"])

	var avg_core_reduction := total_core_reduction / float(count * 2)  # 2 core stats
	var avg_other_reduction := total_other_reduction / float(count)

	# Core stats should have smaller reduction percentage
	var core_pct := avg_core_reduction / 82.5  # Average of 85 and 80
	var other_pct := avg_other_reduction / 70.0

	assert_float(core_pct).is_less(other_pct)


# ============================================================================
# EDGE CASES AND ERROR HANDLING
# ============================================================================

func test_de_age_handles_empty_stats() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {}
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0007)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	assert_that(deaged).contains_key("stats")
	assert_int((deaged["stats"] as Dictionary).size()).is_equal(0)

func test_de_age_handles_missing_stats_field() -> void:
	var player := {
		"position": "QB",
		"age": 22
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0008)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	# Should not crash
	assert_that(deaged).is_not_null()

func test_de_age_ignores_non_numeric_stats() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {
			"speed": 80.0,
			"name": "Test Player",  # String stat (invalid)
			"strength": 75.0
		}
	}

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0009)
	var deaged = DeAger.de_age(player, _positions_cfg, _deage_cfg, _stats_cfg, rng)

	var deaged_stats: Dictionary = deaged["stats"]
	# Numeric stats should be processed
	assert_float(deaged_stats["speed"]).is_less(80.0)
	assert_float(deaged_stats["strength"]).is_less(75.0)
	# String stat should be unchanged
	assert_str(deaged_stats["name"]).is_equal("Test Player")


# ============================================================================
# CONFIGURATION TESTS
# ============================================================================

func test_de_age_without_target_age_preserves_age() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {"speed": 80.0}
	}

	var cfg_no_age := _deage_cfg.duplicate()
	cfg_no_age.erase("target_age")

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0010)
	var deaged = DeAger.de_age(player, _positions_cfg, cfg_no_age, _stats_cfg, rng)

	assert_int(deaged["age"]).is_equal(22)

func test_de_age_with_custom_floor() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {"speed": 30.0}
	}

	var cfg_custom := _deage_cfg.duplicate()
	cfg_custom["floor"] = 40.0

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0011)
	var deaged = DeAger.de_age(player, _positions_cfg, cfg_custom, _stats_cfg, rng)

	var deaged_stats: Dictionary = deaged["stats"]
	assert_float(deaged_stats["speed"]).is_greater_equal(40.0)

func test_de_age_with_custom_ceiling() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {"speed": 95.0}
	}

	var cfg_custom := _deage_cfg.duplicate()
	cfg_custom["ceil"] = 85.0

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xD0012)
	var deaged = DeAger.de_age(player, _positions_cfg, cfg_custom, _stats_cfg, rng)

	var deaged_stats: Dictionary = deaged["stats"]
	assert_float(deaged_stats["speed"]).is_less_equal(85.0)


# ============================================================================
# MULTIPLE DE-AGE RUNS
# ============================================================================

func test_de_age_produces_variation() -> void:
	var player := {
		"position": "QB",
		"age": 22,
		"stats": {"speed": 85.0}
	}

	var speeds := []
	for i in 50:
		var rng = TestHelpersGdUnit4.create_seeded_rng(0xV0000 + i)
		var test_player = player.duplicate(true)
		var deaged = DeAger.de_age(test_player, _positions_cfg, _deage_cfg, _stats_cfg, rng)
		var deaged_stats: Dictionary = deaged["stats"]
		speeds.append(deaged_stats["speed"])

	# Should have variation (not all the same)
	var unique_speeds := {}
	for speed in speeds:
		unique_speeds[speed] = true

	assert_int(unique_speeds.size()).is_greater(10)
