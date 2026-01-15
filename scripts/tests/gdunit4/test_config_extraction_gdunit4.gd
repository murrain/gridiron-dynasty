## GdUnit4 test suite for Task F6: Configuration Access Optimization
##
## Verifies that config extraction helpers correctly extract and pre-compute
## configuration values, maintaining:
## 1. Correctness: Extracted values match source configs
## 2. Performance: O(1) access instead of O(log n) dictionary lookups
## 3. Completeness: All required config values extracted
##
## Migrated from test_config_extraction.gd
extends GdUnitTestSuite

const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")
const WearConfig = preload("res://scripts/support/config/WearConfig.gd")
const Config = preload("res://autoloads/Config.gd")


func test_development_config_extraction() -> void:
	var positions_cfg := {
		"QB": {
			"development": {
				"peak_age": 27,
				"decline_start": 32,
				"curve": "mid"
			}
		},
		"RB": {
			"development": {
				"peak_age": 24,
				"decline_start": 28,
				"curve": "fast"
			}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {
				"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0},
				"fast": {"growth": 1.2, "prime": 0.25, "decline": 1.2}
			},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0
	}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	assert_that(dev_config).is_not_null()


func test_development_config_peak_ages() -> void:
	var positions_cfg := {
		"QB": {"development": {"peak_age": 27}},
		"RB": {"development": {"peak_age": 24}},
		"WR": {"development": {"peak_age": 26}}
	}
	var main_cfg := {"development": {"curve_multipliers": {}}}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	assert_int(dev_config.peak_age("QB")).is_equal(27)
	assert_int(dev_config.peak_age("RB")).is_equal(24)
	assert_int(dev_config.peak_age("WR")).is_equal(26)
	assert_int(dev_config.peak_age("UNKNOWN")).is_equal(26)


func test_development_config_decline_starts() -> void:
	var positions_cfg := {
		"QB": {"development": {"decline_start": 32}},
		"RB": {"development": {"decline_start": 28}},
		"OL": {"development": {"decline_start": 33}}
	}
	var main_cfg := {"development": {"curve_multipliers": {}}}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	assert_int(dev_config.decline_start("QB")).is_equal(32)
	assert_int(dev_config.decline_start("RB")).is_equal(28)
	assert_int(dev_config.decline_start("OL")).is_equal(33)
	assert_int(dev_config.decline_start("UNKNOWN")).is_equal(30)


func test_development_config_curves() -> void:
	var positions_cfg := {
		"QB": {"development": {"curve": "mid"}},
		"RB": {"development": {"curve": "fast"}}
	}
	var main_cfg := {"development": {"curve_multipliers": {}}}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	assert_str(dev_config.curve_name("QB")).is_equal("mid")
	assert_str(dev_config.curve_name("RB")).is_equal("fast")
	assert_str(dev_config.curve_name("UNKNOWN")).is_equal("mid")


func test_development_config_progress_ranges() -> void:
	var positions_cfg := {}
	var main_cfg := {
		"annual_base_progress_min": 1.5,
		"annual_base_progress_max": 4.5,
		"annual_progress_cap": 7.0,
		"development": {
			"curve_multipliers": {},
			"prime_growth_min": 0.3,
			"prime_growth_max": 0.9,
			"decline_min": 0.5,
			"decline_max": 1.8
		}
	}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	var base_range: Vector2 = dev_config.base_progress_range()
	assert_float(base_range.x).is_equal_approx(1.5, 0.01)
	assert_float(base_range.y).is_equal_approx(4.5, 0.01)

	var prime_range: Vector2 = dev_config.prime_growth_range()
	assert_float(prime_range.x).is_equal_approx(0.3, 0.01)
	assert_float(prime_range.y).is_equal_approx(0.9, 0.01)

	var decline_range: Vector2 = dev_config.decline_range()
	assert_float(decline_range.x).is_equal_approx(0.5, 0.01)
	assert_float(decline_range.y).is_equal_approx(1.8, 0.01)

	assert_float(dev_config.progress_cap()).is_equal_approx(7.0, 0.01)


func test_retirement_config_extraction() -> void:
	var main_cfg := {
		"retirement": {
			"min_age": 35,
			"soft_cap_age": 38,
			"max_age": 45,
			"base_chance": 0.02,
			"age_chance_per_year": 0.04,
			"low_rating_threshold": 55.0,
			"low_rating_boost": 0.08
		}
	}

	var ret_config := RetirementConfig.new(main_cfg)
	assert_that(ret_config).is_not_null()


func test_retirement_config_age_thresholds() -> void:
	var main_cfg := {
		"retirement": {
			"min_age": 36,
			"soft_cap_age": 39,
			"max_age": 46
		}
	}

	var ret_config := RetirementConfig.new(main_cfg)

	assert_int(ret_config.min_age()).is_equal(36)
	assert_int(ret_config.soft_cap_age()).is_equal(39)
	assert_int(ret_config.max_age()).is_equal(46)


func test_retirement_config_chances() -> void:
	var main_cfg := {
		"retirement": {
			"base_chance": 0.03,
			"age_chance_per_year": 0.05,
			"low_rating_threshold": 60.0,
			"low_rating_boost": 0.10
		}
	}

	var ret_config := RetirementConfig.new(main_cfg)

	assert_float(ret_config.base_chance()).is_equal_approx(0.03, 0.001)
	assert_float(ret_config.age_chance_per_year()).is_equal_approx(0.05, 0.001)
	assert_float(ret_config.low_rating_threshold()).is_equal_approx(60.0, 0.01)
	assert_float(ret_config.low_rating_boost()).is_equal_approx(0.10, 0.001)


func test_wear_config_extraction() -> void:
	var main_cfg := {
		"wear": {
			"snaps_per_year": 700,
			"collisions_per_year": 250,
			"position_multipliers": {},
			"decline_snaps_scale": 9000.0,
			"decline_collisions_scale": 3000.0,
			"decline_injuries_scale": 7.0,
			"decline_per_wear": 0.25,
			"decline_min_multiplier": 0.9,
			"decline_max_multiplier": 1.8
		}
	}

	var wear_config := WearConfig.new(main_cfg)
	assert_that(wear_config).is_not_null()


func test_wear_config_base_values() -> void:
	var main_cfg := {
		"wear": {
			"snaps_per_year": 700,
			"collisions_per_year": 250,
			"position_multipliers": {"RB": 1.2, "OL": 0.9}
		}
	}

	var wear_config := WearConfig.new(main_cfg)

	assert_int(wear_config.snaps_per_year()).is_equal(700)
	assert_int(wear_config.collisions_per_year()).is_equal(250)

	var pos_mults := wear_config.position_multipliers()
	assert_float(float(pos_mults.get("RB", 0.0))).is_equal_approx(1.2, 0.01)
	assert_float(float(pos_mults.get("OL", 0.0))).is_equal_approx(0.9, 0.01)


func test_wear_config_decline_scales() -> void:
	var main_cfg := {
		"wear": {
			"decline_snaps_scale": 9000.0,
			"decline_collisions_scale": 3000.0,
			"decline_injuries_scale": 7.0,
			"decline_per_wear": 0.25,
			"decline_min_multiplier": 0.9,
			"decline_max_multiplier": 1.8
		}
	}

	var wear_config := WearConfig.new(main_cfg)

	assert_float(wear_config.decline_snaps_scale()).is_equal_approx(9000.0, 0.1)
	assert_float(wear_config.decline_collisions_scale()).is_equal_approx(3000.0, 0.1)
	assert_float(wear_config.decline_injuries_scale()).is_equal_approx(7.0, 0.01)
	assert_float(wear_config.decline_per_wear()).is_equal_approx(0.25, 0.001)
	assert_float(wear_config.decline_min_multiplier()).is_equal_approx(0.9, 0.01)
	assert_float(wear_config.decline_max_multiplier()).is_equal_approx(1.8, 0.01)


func test_wear_config_decline_multiplier_no_wear() -> void:
	var main_cfg := {
		"wear": {
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}

	var wear_config := WearConfig.new(main_cfg)

	var player_no_wear := {
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		}
	}
	assert_float(wear_config.decline_multiplier(player_no_wear)).is_equal_approx(1.0, 0.01)


func test_wear_config_decline_multiplier_moderate_wear() -> void:
	var main_cfg := {
		"wear": {
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}

	var wear_config := WearConfig.new(main_cfg)

	var player_moderate_wear := {
		"wear": {
			"snaps": 4000,  # 4000/8000 = 0.5
			"collisions": 1300,  # 1300/2600 = 0.5
			"injury_count": 3  # 3/6 = 0.5
		}
	}
	# Total wear = 0.5 + 0.5 + 0.5 = 1.5
	# Multiplier = 1.0 + (1.5 * 0.2) = 1.3
	assert_float(wear_config.decline_multiplier(player_moderate_wear)).is_equal_approx(1.3, 0.01)


func test_wear_config_decline_multiplier_clamped_at_max() -> void:
	var main_cfg := {
		"wear": {
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}

	var wear_config := WearConfig.new(main_cfg)

	var player_high_wear := {
		"wear": {
			"snaps": 16000,  # 16000/8000 = 2.0
			"collisions": 5200,  # 5200/2600 = 2.0
			"injury_count": 12  # 12/6 = 2.0
		}
	}
	# Total wear = 2.0 + 2.0 + 2.0 = 6.0
	# Multiplier = 1.0 + (6.0 * 0.2) = 2.2, clamped to 1.6
	assert_float(wear_config.decline_multiplier(player_high_wear)).is_equal_approx(1.6, 0.01)


func test_config_with_real_data() -> void:
	var config := Config.new()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	var ret_config := RetirementConfig.new(main_cfg)
	var wear_config := WearConfig.new(main_cfg)

	# Verify some known positions exist
	assert_int(dev_config.peak_age("QB")).is_greater(0)
	assert_int(dev_config.decline_start("QB")).is_greater(dev_config.peak_age("QB"))

	assert_int(ret_config.min_age()).is_greater(0)
	assert_int(ret_config.max_age()).is_greater(ret_config.min_age())

	assert_int(wear_config.snaps_per_year()).is_greater(0)
	assert_int(wear_config.collisions_per_year()).is_greater(0)


func test_config_access_performance() -> void:
	var config := Config.new()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	# Test performance characteristic: O(1) access
	var start := Time.get_ticks_usec()
	for i in range(1000):
		var _peak := dev_config.peak_age("QB")
		var _decline := dev_config.decline_start("RB")
		var _curve := dev_config.curve_name("WR")
	var elapsed := Time.get_ticks_usec() - start

	# 3000 accesses should be very fast with O(1) pre-extracted values
	assert_int(elapsed).is_less(2000)
