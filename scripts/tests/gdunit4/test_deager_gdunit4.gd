## GdUnit4 test suite for DeAger helper
##
## Validates player de-aging for draft class generation.
## Migrated from test_deager.gd
extends GdUnitTestSuite

const DeAger = preload("res://scripts/generation/helpers/DeAger.gd")


var _player: Dictionary
var _stats_cfg: Dictionary
var _deage_cfg: Dictionary


func before() -> void:
	_player = {
		"age": 20,
		"stats": {"speed": 80.0, "awareness": 60.0, "bonus": 99.0}
	}
	_stats_cfg = {
		"stats": [
			{"name": "speed", "type": "base"},
			{"name": "awareness", "type": "base", "default": 50},
			{"name": "bonus", "type": "derived"}
		]
	}
	_deage_cfg = {
		"core_stats": ["speed"],
		"secondary_stats": ["awareness"],
		"core_pct_min": 0.9,
		"core_pct_max": 0.9,
		"core_var": 0.0,
		"secondary_pct_min": 0.8,
		"secondary_pct_max": 0.8,
		"secondary_var": 0.0,
		"other_pct_min": 0.5,
		"other_pct_max": 0.5,
		"other_var": 0.0,
		"noise_min": 0.0,
		"noise_max": 0.0,
		"floor": 0.0,
		"ceil": 100.0,
		"only_base_stats": true,
		"keep_existing_defaults": true,
		"target_age": 18
	}


func test_deager_updates_age() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var deaged = DeAger.de_age(_player, {}, _deage_cfg, _stats_cfg, rng)
	assert_int(deaged.get("age")).is_equal(18)


func test_deager_scales_core_stats() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var deaged = DeAger.de_age(_player, {}, _deage_cfg, _stats_cfg, rng)
	var stats = deaged.get("stats", {}) as Dictionary
	assert_float(float(stats.get("speed"))).is_between(70.0, 90.0)


func test_deager_keeps_existing_defaults_when_configured() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var deaged = DeAger.de_age(_player, {}, _deage_cfg, _stats_cfg, rng)
	var stats = deaged.get("stats", {}) as Dictionary
	assert_float(float(stats.get("awareness"))).is_equal(60.0)


func test_deager_skips_derived_stats_when_only_base_stats() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var deaged = DeAger.de_age(_player, {}, _deage_cfg, _stats_cfg, rng)
	var stats = deaged.get("stats", {}) as Dictionary
	assert_float(float(stats.get("bonus"))).is_equal(99.0)


func test_deager_forces_defaults_when_configured() -> void:
	_deage_cfg["keep_existing_defaults"] = false
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var deaged = DeAger.de_age(_player, {}, _deage_cfg, _stats_cfg, rng)
	var stats = deaged.get("stats", {}) as Dictionary
	assert_int(int(stats.get("awareness"))).is_equal(50)
