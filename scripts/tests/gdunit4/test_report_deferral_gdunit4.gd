## GdUnit4 test suite for Development Report Deferral (Task F7)
##
## Verifies that:
## 1. skip_reports option correctly skips report generation
## 2. Bootstrap mode enables skip_reports throughout the pipeline
## 3. PlayerReportGenerator can reconstruct basic reports on-demand
## 4. Determinism is maintained regardless of skip_reports setting
##
## Migrated from test_report_deferral.gd
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const PlayerReportGenerator = preload("res://scripts/world/PlayerReportGenerator.gd")
const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _stats_cfg: Dictionary


func before() -> void:
	var config_service := ConfigService.new()
	_positions_cfg = config_service.get_config("positions")
	_main_cfg = config_service.get_config("main")
	_stats_cfg = config_service.get_config("stats")


func _create_test_player() -> Dictionary:
	return {
		"player_id": "test_player_001",
		"name": "Test Player",
		"position": "QB",
		"age": 20,
		"birth_year": 2004,
		"draft_year": 2024,
		"career_start_age": 18,
		"stats": {
			"speed": 70.0,
			"strength": 65.0,
			"awareness": 60.0,
			"throwing_power": 75.0,
			"throwing_accuracy": 72.0,
			"injury_proneness": 50.0
		},
		"potential": {
			"speed": 80.0,
			"strength": 75.0,
			"awareness": 85.0,
			"throwing_power": 90.0,
			"throwing_accuracy": 88.0,
			"injury_proneness": 50.0
		},
		"wear": {"snaps": 0, "collisions": 0, "injury_count": 0},
		"development_context": {},
		"injuries": [],
		"development_report": []
	}


func test_skip_reports_produces_empty_report() -> void:
	var player := _create_test_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var result := PlayerLifecycle.advance_one_year(
		[player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng,
		{},
		{"skip_reports": true}
	)

	var updated_player: Dictionary = result.players[0]
	var report: Array = updated_player.get("development_report", [])

	assert_int(report.size()).is_equal(0)


func test_skip_reports_still_advances_age() -> void:
	var player := _create_test_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var result := PlayerLifecycle.advance_one_year(
		[player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng,
		{},
		{"skip_reports": true}
	)

	var updated_player: Dictionary = result.players[0]

	assert_int(int(updated_player.get("age", 0))).is_equal(21)


func test_normal_reports_appended() -> void:
	var player := _create_test_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var result := PlayerLifecycle.advance_one_year(
		[player],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng,
		{},
		{"skip_reports": false}
	)

	var updated_player: Dictionary = result.players[0]
	var report: Array = updated_player.get("development_report", [])

	assert_int(report.size()).is_equal(1)
	assert_bool((report[0] as Dictionary).has("age")).is_true()
	assert_bool((report[0] as Dictionary).has("wear")).is_true()


func test_determinism_with_skip_reports() -> void:
	var player := _create_test_player()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng1,
		{},
		{"skip_reports": true}
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng2,
		{},
		{"skip_reports": true}
	)

	var p1: Dictionary = result1.players[0]
	var p2: Dictionary = result2.players[0]

	var stats1: Dictionary = p1.get("stats", {})
	var stats2: Dictionary = p2.get("stats", {})

	for stat_name in stats1.keys():
		assert_float(float(stats1.get(stat_name, 0.0))).is_equal_approx(float(stats2.get(stat_name, 0.0)), 0.001)


func test_skip_reports_does_not_affect_simulation() -> void:
	var player := _create_test_player()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var result1 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng1,
		{},
		{"skip_reports": true}
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var result2 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng2,
		{},
		{"skip_reports": false}
	)

	var p1: Dictionary = result1.players[0]
	var p2: Dictionary = result2.players[0]

	var stats1: Dictionary = p1.get("stats", {})
	var stats2: Dictionary = p2.get("stats", {})

	for stat_name in stats1.keys():
		assert_float(float(stats1.get(stat_name, 0.0))).is_equal_approx(float(stats2.get(stat_name, 0.0)), 0.001)


func test_advance_years_with_skip_reports() -> void:
	var player := _create_test_player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var result := PlayerLifecycle.advance_years(
		[player],
		5,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		rng,
		{},
		{"skip_reports": true}
	)

	var updated_player: Dictionary = result.players[0]
	var report: Array = updated_player.get("development_report", [])

	assert_int(report.size()).is_equal(0)
	assert_int(int(updated_player.get("age", 0))).is_equal(25)


func test_bootstrap_mode_enables_skip_reports() -> void:
	var advance := AdvanceWorldYear.new()

	advance.set_bootstrap_mode(true)
	var options := advance._lifecycle_options()

	assert_bool(bool(options.get("skip_reports", false))).is_true()


func test_bootstrap_mode_disable_skip_reports() -> void:
	var advance := AdvanceWorldYear.new()

	advance.set_bootstrap_mode(false)
	var options := advance._lifecycle_options()

	assert_bool(not bool(options.get("skip_reports", true))).is_true()


func test_report_generator_returns_existing_report() -> void:
	var player := _create_test_player()
	player["development_report"] = [
		{"age": 18, "phase": "growth"},
		{"age": 19, "phase": "growth"}
	]

	var report := PlayerReportGenerator.generate_development_report(player, {})

	assert_int(report.size()).is_equal(2)
	assert_int(int((report[0] as Dictionary).get("age", 0))).is_equal(18)
	assert_str(String((report[0] as Dictionary).get("phase", ""))).is_equal("growth")


func test_report_generator_summary_growth() -> void:
	var entry := {"age": 20, "phase": "growth", "decline_multiplier": 1.0}
	var summary := PlayerReportGenerator.generate_summary(entry)

	assert_bool(summary.contains("Developing")).is_true()


func test_report_generator_summary_prime() -> void:
	var entry := {"age": 26, "phase": "prime", "decline_multiplier": 1.0}
	var summary := PlayerReportGenerator.generate_summary(entry)

	assert_bool(summary.contains("Peak")).is_true()


func test_report_generator_summary_decline() -> void:
	var entry := {"age": 32, "phase": "decline", "decline_multiplier": 1.2}
	var summary := PlayerReportGenerator.generate_summary(entry)

	assert_bool(summary.contains("regression")).is_true()


func test_report_generator_summary_heavy_decline() -> void:
	var entry := {"age": 35, "phase": "decline", "decline_multiplier": 1.5}
	var summary := PlayerReportGenerator.generate_summary(entry)

	assert_bool(summary.contains("Significant")).is_true()
