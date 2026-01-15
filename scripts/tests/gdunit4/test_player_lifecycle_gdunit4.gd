## GdUnit4 test suite for PlayerLifecycle
##
## Validates player development, aging, and retirement.
## Migrated from test_player_lifecycle.gd
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")


var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _stats_cfg: Dictionary


func before() -> void:
	_positions_cfg = {
		"QB": {
			"core_stats": ["accuracy", "decision"],
			"development": {"peak_age": 20, "decline_start": 21, "curve": "fast"}
		}
	}
	_main_cfg = {
		"development": {
			"curve_multipliers": {"fast": {"growth": 1.0, "prime": 1.0, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.2,
			"decline_min": 1.0,
			"decline_max": 1.0
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 1.0,
		"annual_progress_cap": 5.0,
		"retirement": {"min_age": 21, "soft_cap_age": 21, "max_age": 21, "base_chance": 0.0},
		"wear": {
			"snaps_per_year": 100,
			"collisions_per_year": 10,
			"decline_snaps_scale": 1000.0,
			"decline_collisions_scale": 100.0,
			"decline_injuries_scale": 1.0,
			"decline_per_wear": 0.1,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 2.0
		}
	}
	_stats_cfg = {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "decision", "type": "base"}
	]}


func test_advance_one_year_increments_age() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	assert_int(int(evolved.get("age"))).is_equal(20)


func test_development_stays_within_potential() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	var stats = evolved.get("stats", {}) as Dictionary
	assert_float(float(stats.get("accuracy"))).is_between(50.0, 60.0)


func test_wear_snaps_increment() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	var wear = evolved.get("wear", {}) as Dictionary
	assert_int(int(wear.get("snaps", 0))).is_equal(100)


func test_wear_collisions_increment() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	var wear = evolved.get("wear", {}) as Dictionary
	assert_int(int(wear.get("collisions", 0))).is_equal(10)


func test_development_report_logged() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	var report = evolved.get("development_report", []) as Array
	assert_int(report.size()).is_equal(1)


func test_decline_multiplier_neutral_before_decline() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	var report = evolved.get("development_report", []) as Array
	assert_float(float((report[0] as Dictionary).get("decline_multiplier", 0.0))).is_equal(1.0)


func test_development_report_attached() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	assert_bool(evolved.has("development_report")).is_true()


func test_injury_report_attached() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], _positions_cfg, _main_cfg, _stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	assert_bool(evolved.has("injury_report")).is_true()


func test_retirement_at_max_age() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var result = PlayerLifecycle.advance_one_year([{"age": 21, "position": "QB", "stats": {"accuracy": 40.0}}], _positions_cfg, _main_cfg, _stats_cfg, rng)
	assert_int((result.get("retired", []) as Array).size()).is_equal(1)


func test_core_rating_averages_core_stats() -> void:
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var core_rating = PlayerLifecycle._core_rating(player, _positions_cfg)
	assert_float(core_rating).is_equal(45.0)
