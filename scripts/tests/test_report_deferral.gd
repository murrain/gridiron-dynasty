extends RefCounted

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const PlayerReportGenerator = preload("res://scripts/world/PlayerReportGenerator.gd")
const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")

## Test suite for Task F7: Development Report Deferral
##
## Verifies that:
## 1. skip_reports option correctly skips report generation
## 2. Bootstrap mode enables skip_reports throughout the pipeline
## 3. PlayerReportGenerator can reconstruct basic reports on-demand
## 4. Determinism is maintained regardless of skip_reports setting

func run(t) -> void:
	_test_skip_reports_option(t)
	_test_normal_reports_generation(t)
	_test_determinism_with_skip_reports(t)
	_test_skip_reports_does_not_affect_simulation(t)
	_test_advance_years_with_skip_reports(t)
	_test_bootstrap_mode_enables_skip_reports(t)
	_test_player_report_generator_reconstructs_reports(t)
	_test_player_report_generator_returns_existing_report(t)
	_test_player_report_generator_summary(t)
	_test_bootstrap_integration(t)

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
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		},
		"development_context": {},
		"injuries": [],
		"development_report": []
	}

func _create_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng

func _load_configs() -> Dictionary:
	var config_service := preload("res://autoloads/Config.gd").new()
	return {
		"positions": config_service.get_config("positions"),
		"main": config_service.get_config("main"),
		"stats": config_service.get_config("stats")
	}

## Test: skip_reports option skips development report generation
func _test_skip_reports_option(t):
	var player := _create_test_player()
	var configs := _load_configs()
	var rng := _create_rng(42)

	# Advance with skip_reports = true
	var result := PlayerLifecycle.advance_one_year(
		[player],
		configs.positions,
		configs.main,
		configs.stats,
		rng,
		{},
		{"skip_reports": true}
	)

	var updated_player: Dictionary = result.players[0]

	# Verify report was not appended
	var report: Array = updated_player.get("development_report", [])
	t.assert_eq(report.size(), 0, "Report should be empty when skip_reports is true")

	# Verify player was still advanced (age increased)
	t.assert_eq(int(updated_player.get("age", 0)), 21, "Age should have increased")

func _test_normal_reports_generation(t):
	var player := _create_test_player()
	var configs := _load_configs()
	var rng := _create_rng(42)

	# Advance with skip_reports = false (default)
	var result := PlayerLifecycle.advance_one_year(
		[player],
		configs.positions,
		configs.main,
		configs.stats,
		rng,
		{},
		{"skip_reports": false}
	)

	var updated_player: Dictionary = result.players[0]

	# Verify report was appended
	var report: Array = updated_player.get("development_report", [])
	t.assert_eq(report.size(), 1, "Report should have one entry")
	t.assert_true(report[0].has("age"), "Report entry should have age")
	t.assert_true(report[0].has("wear"), "Report entry should have wear")
	t.assert_true(report[0].has("decline_multiplier"), "Report entry should have decline_multiplier")

func _test_determinism_with_skip_reports(t):
	var player := _create_test_player()
	var configs := _load_configs()

	# Run with skip_reports = true
	var rng1 := _create_rng(12345)
	var result1 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		configs.positions,
		configs.main,
		configs.stats,
		rng1,
		{},
		{"skip_reports": true}
	)

	# Run again with same seed
	var rng2 := _create_rng(12345)
	var result2 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		configs.positions,
		configs.main,
		configs.stats,
		rng2,
		{},
		{"skip_reports": true}
	)

	var p1: Dictionary = result1.players[0]
	var p2: Dictionary = result2.players[0]

	# Verify stats are identical (determinism maintained)
	var stats1: Dictionary = p1.get("stats", {})
	var stats2: Dictionary = p2.get("stats", {})

	for stat_name in stats1.keys():
		t.assert_approx(
			float(stats1.get(stat_name, 0.0)),
			float(stats2.get(stat_name, 0.0)),
			0.001,
			"Stat %s should be identical across runs" % stat_name
		)

func _test_skip_reports_does_not_affect_simulation(t):
	var player := _create_test_player()
	var configs := _load_configs()

	# Run with skip_reports = true
	var rng1 := _create_rng(99999)
	var result1 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		configs.positions,
		configs.main,
		configs.stats,
		rng1,
		{},
		{"skip_reports": true}
	)

	# Run with skip_reports = false
	var rng2 := _create_rng(99999)
	var result2 := PlayerLifecycle.advance_one_year(
		[player.duplicate(true)],
		configs.positions,
		configs.main,
		configs.stats,
		rng2,
		{},
		{"skip_reports": false}
	)

	var p1: Dictionary = result1.players[0]
	var p2: Dictionary = result2.players[0]

	# Verify stats are identical (skip_reports doesn't affect simulation)
	var stats1: Dictionary = p1.get("stats", {})
	var stats2: Dictionary = p2.get("stats", {})

	for stat_name in stats1.keys():
		t.assert_approx(
			float(stats1.get(stat_name, 0.0)),
			float(stats2.get(stat_name, 0.0)),
			0.001,
			"Stat %s should be identical regardless of skip_reports" % stat_name
		)

func _test_advance_years_with_skip_reports(t):
	var player := _create_test_player()
	var configs := _load_configs()
	var rng := _create_rng(42)

	# Advance 5 years with skip_reports
	var result := PlayerLifecycle.advance_years(
		[player],
		5,
		configs.positions,
		configs.main,
		configs.stats,
		rng,
		{},
		{"skip_reports": true}
	)

	var updated_player: Dictionary = result.players[0]

	# Verify no reports were generated
	var report: Array = updated_player.get("development_report", [])
	t.assert_eq(report.size(), 0, "Report should be empty after 5 years with skip_reports")

	# Verify player was advanced 5 years
	t.assert_eq(int(updated_player.get("age", 0)), 25, "Age should have increased by 5")

func _test_bootstrap_mode_enables_skip_reports(t):
	var advance := AdvanceWorldYear.new()

	# Enable bootstrap mode
	advance.set_bootstrap_mode(true)

	# Verify _lifecycle_options returns skip_reports = true
	var options := advance._lifecycle_options()
	t.assert_true(bool(options.get("skip_reports", false)), "Bootstrap mode should enable skip_reports")

	# Disable bootstrap mode
	advance.set_bootstrap_mode(false)
	options = advance._lifecycle_options()
	t.assert_true(not bool(options.get("skip_reports", true)), "Disabling bootstrap should disable skip_reports")

func _test_player_report_generator_reconstructs_reports(t):
	var player := _create_test_player()
	player["age"] = 23
	player["birth_year"] = 2001
	player["draft_year"] = 2019  # Started career at age 18 (2019-2001=18)
	player["wear"] = {
		"snaps": 5000,
		"collisions": 1500,
		"injury_count": 2
	}

	# Generate report on-demand
	var report := PlayerReportGenerator.generate_development_report(player, {})

	# Should have entries for ages 18-23 (career_start_age calculated from birth/draft years)
	t.assert_eq(report.size(), 6, "Report should have 6 entries (ages 18-23)")

	# Verify each entry has required fields
	for i in range(report.size()):
		var entry: Dictionary = report[i]
		t.assert_true(entry.has("age"), "Entry %d should have age" % i)
		t.assert_true(entry.has("phase"), "Entry %d should have phase" % i)
		t.assert_true(entry.has("wear"), "Entry %d should have wear" % i)
		t.assert_true(entry.has("decline_multiplier"), "Entry %d should have decline_multiplier" % i)
		t.assert_true(bool(entry.get("reconstructed", false)), "Entry should be marked as reconstructed")

	# Verify ages are sequential
	for i in range(report.size()):
		t.assert_eq(int(report[i].get("age", 0)), 18 + i, "Age should be sequential")

func _test_player_report_generator_returns_existing_report(t):
	var player := _create_test_player()
	player["development_report"] = [
		{"age": 18, "phase": "growth"},
		{"age": 19, "phase": "growth"}
	]

	# Should return existing report, not reconstruct
	var report := PlayerReportGenerator.generate_development_report(player, {})

	t.assert_eq(report.size(), 2, "Should return existing report")
	t.assert_eq(int(report[0].get("age", 0)), 18, "First entry age should be 18")
	t.assert_eq(String(report[0].get("phase", "")), "growth", "First entry phase should be growth")

func _test_player_report_generator_summary(t):
	var entry_growth := {"age": 20, "phase": "growth", "decline_multiplier": 1.0}
	var entry_prime := {"age": 26, "phase": "prime", "decline_multiplier": 1.0}
	var entry_decline := {"age": 32, "phase": "decline", "decline_multiplier": 1.2}
	var entry_heavy_decline := {"age": 35, "phase": "decline", "decline_multiplier": 1.5}

	var summary1 := PlayerReportGenerator.generate_summary(entry_growth)
	var summary2 := PlayerReportGenerator.generate_summary(entry_prime)
	var summary3 := PlayerReportGenerator.generate_summary(entry_decline)
	var summary4 := PlayerReportGenerator.generate_summary(entry_heavy_decline)

	t.assert_true(summary1.contains("Developing"), "Growth summary should mention developing")
	t.assert_true(summary2.contains("Peak"), "Prime summary should mention peak")
	t.assert_true(summary3.contains("regression"), "Decline summary should mention regression")
	t.assert_true(summary4.contains("Significant"), "Heavy decline summary should mention significant")

func _test_bootstrap_integration(t):
	# This test verifies that BootstrapGameWorld properly enables skip_reports
	# Note: This is a lightweight test that only runs 1 year to avoid long test times
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 1

	var result := bootstrap.run(424242, false)

	# Verify world was created
	var world_state: Dictionary = result.get("world_state", {})
	t.assert_true(not world_state.is_empty(), "World state should not be empty")

	# Check that some players exist (after 1 year of simulation)
	var hs_players: Array = world_state.get("hs_players", [])
	print("  HS players after 1 year: %d" % hs_players.size())

	# Verify players have empty reports (bootstrap mode was enabled)
	if not hs_players.is_empty():
		var sample_player: Dictionary = hs_players[0]
		var report: Array = sample_player.get("development_report", [])
		t.assert_eq(report.size(), 0, "Bootstrap should skip development reports")
