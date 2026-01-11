extends RefCounted
## Test suite for Task F6: Configuration Access Optimization
##
## Verifies that config extraction helpers correctly extract and pre-compute
## configuration values, maintaining:
## 1. Correctness: Extracted values match source configs
## 2. Performance: O(1) access instead of O(log n) dictionary lookups
## 3. Completeness: All required config values extracted

const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")
const WearConfig = preload("res://scripts/support/config/WearConfig.gd")
const Config = preload("res://autoloads/Config.gd")

func run(t) -> void:
	_test_development_config_extraction(t)
	_test_development_config_peak_ages(t)
	_test_development_config_decline_starts(t)
	_test_development_config_curves(t)
	_test_development_config_progress_ranges(t)
	_test_retirement_config_extraction(t)
	_test_retirement_config_age_thresholds(t)
	_test_retirement_config_chances(t)
	_test_wear_config_extraction(t)
	_test_wear_config_base_values(t)
	_test_wear_config_decline_scales(t)
	_test_wear_config_decline_multiplier(t)
	_test_config_with_real_data(t)

## Test that DevelopmentConfig correctly extracts from dictionaries
func _test_development_config_extraction(t) -> void:
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

	# Verify extraction didn't crash
	t.assert_true(dev_config != null, "DevelopmentConfig created successfully")

## Test that peak ages are correctly extracted
func _test_development_config_peak_ages(t) -> void:
	var positions_cfg := {
		"QB": {"development": {"peak_age": 27}},
		"RB": {"development": {"peak_age": 24}},
		"WR": {"development": {"peak_age": 26}}
	}
	var main_cfg := {"development": {"curve_multipliers": {}}}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	t.assert_eq(dev_config.peak_age("QB"), 27, "QB peak age extracted")
	t.assert_eq(dev_config.peak_age("RB"), 24, "RB peak age extracted")
	t.assert_eq(dev_config.peak_age("WR"), 26, "WR peak age extracted")
	t.assert_eq(dev_config.peak_age("UNKNOWN"), 26, "Unknown position uses default")

## Test that decline starts are correctly extracted
func _test_development_config_decline_starts(t) -> void:
	var positions_cfg := {
		"QB": {"development": {"decline_start": 32}},
		"RB": {"development": {"decline_start": 28}},
		"OL": {"development": {"decline_start": 33}}
	}
	var main_cfg := {"development": {"curve_multipliers": {}}}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	t.assert_eq(dev_config.decline_start("QB"), 32, "QB decline start extracted")
	t.assert_eq(dev_config.decline_start("RB"), 28, "RB decline start extracted")
	t.assert_eq(dev_config.decline_start("OL"), 33, "OL decline start extracted")
	t.assert_eq(dev_config.decline_start("UNKNOWN"), 30, "Unknown position uses default")

## Test that development curves are correctly extracted
func _test_development_config_curves(t) -> void:
	var positions_cfg := {
		"QB": {"development": {"curve": "mid"}},
		"RB": {"development": {"curve": "fast"}}
	}
	var main_cfg := {"development": {"curve_multipliers": {}}}

	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

	t.assert_eq(dev_config.curve_name("QB"), "mid", "QB curve extracted")
	t.assert_eq(dev_config.curve_name("RB"), "fast", "RB curve extracted")
	t.assert_eq(dev_config.curve_name("UNKNOWN"), "mid", "Unknown position uses default")

## Test that progress ranges are correctly extracted
func _test_development_config_progress_ranges(t) -> void:
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
	t.assert_approx(base_range.x, 1.5, 0.01, "Base progress min extracted")
	t.assert_approx(base_range.y, 4.5, 0.01, "Base progress max extracted")

	var prime_range: Vector2 = dev_config.prime_growth_range()
	t.assert_approx(prime_range.x, 0.3, 0.01, "Prime min extracted")
	t.assert_approx(prime_range.y, 0.9, 0.01, "Prime max extracted")

	var decline_range: Vector2 = dev_config.decline_range()
	t.assert_approx(decline_range.x, 0.5, 0.01, "Decline min extracted")
	t.assert_approx(decline_range.y, 1.8, 0.01, "Decline max extracted")

	t.assert_approx(dev_config.progress_cap(), 7.0, 0.01, "Progress cap extracted")

## Test that RetirementConfig correctly extracts from dictionaries
func _test_retirement_config_extraction(t) -> void:
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

	# Verify extraction didn't crash
	t.assert_true(ret_config != null, "RetirementConfig created successfully")

## Test that age thresholds are correctly extracted
func _test_retirement_config_age_thresholds(t) -> void:
	var main_cfg := {
		"retirement": {
			"min_age": 36,
			"soft_cap_age": 39,
			"max_age": 46
		}
	}

	var ret_config := RetirementConfig.new(main_cfg)

	t.assert_eq(ret_config.min_age(), 36, "Min age extracted")
	t.assert_eq(ret_config.soft_cap_age(), 39, "Soft cap age extracted")
	t.assert_eq(ret_config.max_age(), 46, "Max age extracted")

## Test that retirement chances are correctly extracted
func _test_retirement_config_chances(t) -> void:
	var main_cfg := {
		"retirement": {
			"base_chance": 0.03,
			"age_chance_per_year": 0.05,
			"low_rating_threshold": 60.0,
			"low_rating_boost": 0.10
		}
	}

	var ret_config := RetirementConfig.new(main_cfg)

	t.assert_approx(ret_config.base_chance(), 0.03, 0.001, "Base chance extracted")
	t.assert_approx(ret_config.age_chance_per_year(), 0.05, 0.001, "Age chance per year extracted")
	t.assert_approx(ret_config.low_rating_threshold(), 60.0, 0.01, "Low rating threshold extracted")
	t.assert_approx(ret_config.low_rating_boost(), 0.10, 0.001, "Low rating boost extracted")

## Test that WearConfig correctly extracts from dictionaries
func _test_wear_config_extraction(t) -> void:
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

	# Verify extraction didn't crash
	t.assert_true(wear_config != null, "WearConfig created successfully")

## Test that base wear values are correctly extracted
func _test_wear_config_base_values(t) -> void:
	var main_cfg := {
		"wear": {
			"snaps_per_year": 700,
			"collisions_per_year": 250,
			"position_multipliers": {"RB": 1.2, "OL": 0.9}
		}
	}

	var wear_config := WearConfig.new(main_cfg)

	t.assert_eq(wear_config.snaps_per_year(), 700, "Snaps per year extracted")
	t.assert_eq(wear_config.collisions_per_year(), 250, "Collisions per year extracted")

	var pos_mults := wear_config.position_multipliers()
	t.assert_approx(float(pos_mults.get("RB", 0.0)), 1.2, 0.01, "RB position multiplier extracted")
	t.assert_approx(float(pos_mults.get("OL", 0.0)), 0.9, 0.01, "OL position multiplier extracted")

## Test that decline scale factors are correctly extracted
func _test_wear_config_decline_scales(t) -> void:
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

	t.assert_approx(wear_config.decline_snaps_scale(), 9000.0, 0.1, "Decline snaps scale extracted")
	t.assert_approx(wear_config.decline_collisions_scale(), 3000.0, 0.1, "Decline collisions scale extracted")
	t.assert_approx(wear_config.decline_injuries_scale(), 7.0, 0.01, "Decline injuries scale extracted")
	t.assert_approx(wear_config.decline_per_wear(), 0.25, 0.001, "Decline per wear extracted")
	t.assert_approx(wear_config.decline_min_multiplier(), 0.9, 0.01, "Decline min multiplier extracted")
	t.assert_approx(wear_config.decline_max_multiplier(), 1.8, 0.01, "Decline max multiplier extracted")

## Test that decline multiplier calculation works correctly
func _test_wear_config_decline_multiplier(t) -> void:
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

	# Test with no wear
	var player_no_wear := {
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		}
	}
	t.assert_approx(wear_config.decline_multiplier(player_no_wear), 1.0, 0.01, "No wear = 1.0 multiplier")

	# Test with moderate wear
	var player_moderate_wear := {
		"wear": {
			"snaps": 4000,  # 4000/8000 = 0.5
			"collisions": 1300,  # 1300/2600 = 0.5
			"injury_count": 3  # 3/6 = 0.5
		}
	}
	# Total wear = 0.5 + 0.5 + 0.5 = 1.5
	# Multiplier = 1.0 + (1.5 * 0.2) = 1.3
	t.assert_approx(wear_config.decline_multiplier(player_moderate_wear), 1.3, 0.01, "Moderate wear calculated correctly")

	# Test clamping at max
	var player_high_wear := {
		"wear": {
			"snaps": 16000,  # 16000/8000 = 2.0
			"collisions": 5200,  # 5200/2600 = 2.0
			"injury_count": 12  # 12/6 = 2.0
		}
	}
	# Total wear = 2.0 + 2.0 + 2.0 = 6.0
	# Multiplier = 1.0 + (6.0 * 0.2) = 2.2, clamped to 1.6
	t.assert_approx(wear_config.decline_multiplier(player_high_wear), 1.6, 0.01, "High wear clamped to max")

## Test config extraction with real config data
func _test_config_with_real_data(t) -> void:
	var config := Config.new()
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")

	# Test that config extraction works with real data
	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	var ret_config := RetirementConfig.new(main_cfg)
	var wear_config := WearConfig.new(main_cfg)

	# Verify some known positions exist
	t.assert_true(dev_config.peak_age("QB") > 0, "Real QB peak age extracted")
	t.assert_true(dev_config.decline_start("QB") > dev_config.peak_age("QB"), "QB decline after peak")

	t.assert_true(ret_config.min_age() > 0, "Real min retirement age extracted")
	t.assert_true(ret_config.max_age() > ret_config.min_age(), "Max age greater than min age")

	t.assert_true(wear_config.snaps_per_year() > 0, "Real snaps per year extracted")
	t.assert_true(wear_config.collisions_per_year() > 0, "Real collisions per year extracted")

	# Test performance characteristic: O(1) access
	# Multiple accesses should use pre-extracted values, not dictionary lookups
	var start := Time.get_ticks_usec()
	for i in range(1000):
		var _peak := dev_config.peak_age("QB")
		var _decline := dev_config.decline_start("RB")
		var _curve := dev_config.curve_name("WR")
	var elapsed := Time.get_ticks_usec() - start

	# 3000 accesses should be very fast with O(1) pre-extracted values
	# Expect < 1ms for 3000 member accesses vs ~3-5ms for 3000 dictionary lookups
	t.assert_true(elapsed < 2000, "Config access is fast (O(1) member access)")
