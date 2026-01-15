## GdUnit4 test suite for Generation Helper Utilities
##
## Tests NamesHelper, PositionHelper, PhysicalsHelper, and StatsHelper utilities.
extends GdUnitTestSuite

const NamesHelper = preload("res://scripts/generation/helpers/NamesHelper.gd")
const PositionHelper = preload("res://scripts/generation/helpers/PositionHelper.gd")
const PhysicalsHelper = preload("res://scripts/generation/helpers/PhysicalsHelper.gd")
const StatsHelper = preload("res://scripts/generation/helpers/StatsHelper.gd")


func test_names_helper_random_full() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var names_cfg := {"first_names": ["Chris"], "last_names": ["Carter"]}
	var name := NamesHelper.random_full(names_cfg, rng)

	assert_str(name).is_equal("Chris Carter")


func test_position_helper_respects_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var positions := {"QB": {}, "RB": {}}
	var weights := {"position_weights": {"QB": 1.0, "RB": 0.0}}

	var pos := PositionHelper.pick_position(positions, weights, rng)

	assert_str(pos).is_equal("QB")


func test_physicals_helper_clamps_zero_sigma() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var positions_cfg := {
		"QB": {
			"physicals": {
				"height_in": {"mu": 72, "sigma": 0, "min": 70, "max": 76}
			}
		}
	}

	var phys := PhysicalsHelper.roll_for_position("QB", positions_cfg, rng)

	assert_float(float(phys.get("height_in", 0.0))).is_equal(72.0)


func test_stats_helper_uses_position_override() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var stats_cfg := {
		"stats": [
			{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60, "default": 55},
			{"name": "awareness", "mu": 40, "sigma": 0, "min": 30, "max": 70}
		]
	}
	var positions_data := {
		"QB": {
			"distributions": {
				"speed": {"mu": 52, "sigma": 0, "min": 45, "max": 55}
			}
		}
	}

	var rolled := StatsHelper.roll_all(stats_cfg, "QB", positions_data, 1.0, rng)

	assert_float(float(rolled.get("speed", 0.0))).is_equal(52.0)


func test_stats_helper_defaults_do_not_overwrite() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var stats_cfg := {
		"stats": [
			{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60, "default": 55}
		]
	}
	var positions_data := {
		"QB": {
			"distributions": {
				"speed": {"mu": 52, "sigma": 0, "min": 45, "max": 55}
			}
		}
	}

	var rolled := StatsHelper.roll_all(stats_cfg, "QB", positions_data, 1.0, rng)
	var applied := StatsHelper.apply_defaults(rolled, stats_cfg, true)

	assert_int(applied).is_equal(0)


func test_stats_helper_fills_missing_defaults() -> void:
	var stats_cfg := {
		"stats": [
			{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60, "default": 55}
		]
	}

	var rolled := {}
	var applied := StatsHelper.apply_defaults(rolled, stats_cfg, true)

	assert_int(applied).is_equal(1)
	assert_float(float(rolled.get("speed", 0.0))).is_equal(55.0)
