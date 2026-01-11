extends RefCounted

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

## Test suite for P3 lifecycle copy reduction optimizations
## Verifies that all optimizations maintain determinism and correctness

func run(t) -> void:
	_test_advance_years_no_initial_copy_determinism(t)
	_test_context_merge_determinism(t)
	_test_injury_normalization_determinism(t)
	_test_report_generation_determinism(t)
	_test_multi_year_advance_determinism(t)
	_test_advance_years_isolation(t)
	# NOTE: Parallel test commented out - parallel implementation is separate Task F5
	# _test_parallel_determinism_vs_serial(t)
	_test_injury_heavy_workload_determinism(t)

## Test that advance_years produces identical results without initial copy
## Verifies that removing players.duplicate(true) doesn't break isolation
func _test_advance_years_no_initial_copy_determinism(t) -> void:
	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy", "decision"],
			"development": {"peak_age": 26, "decline_start": 30, "curve": "mid"}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0,
		"retirement": {"min_age": 35, "soft_cap_age": 36, "max_age": 40, "base_chance": 0.0},
		"wear": {
			"snaps_per_year": 600,
			"collisions_per_year": 50,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}
	var stats_cfg := {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "decision", "type": "base"}
	]}

	var original_players := [
		{
			"player_id": "p1",
			"name": "Player One",
			"age": 22,
			"position": "QB",
			"stats": {"accuracy": 60.0, "decision": 55.0},
			"potential": {"accuracy": 80.0, "decision": 75.0}
		},
		{
			"player_id": "p2",
			"name": "Player Two",
			"age": 23,
			"position": "QB",
			"stats": {"accuracy": 70.0, "decision": 65.0},
			"potential": {"accuracy": 85.0, "decision": 80.0}
		}
	]

	# Run twice with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := PlayerLifecycle.advance_years(
		original_players,
		3,
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := PlayerLifecycle.advance_years(
		original_players,
		3,
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng2
	)

	var players1 := result1.get("players", []) as Array
	var players2 := result2.get("players", []) as Array

	t.assert_eq(players1.size(), players2.size(), "advance_years: same player count")

	for i in range(players1.size()):
		var p1: Dictionary = players1[i]
		var p2: Dictionary = players2[i]
		t.assert_eq(p1.get("player_id"), p2.get("player_id"), "advance_years: same player_id")
		t.assert_eq(p1.get("age"), p2.get("age"), "advance_years: same age")
		var stats1: Dictionary = p1.get("stats", {}) as Dictionary
		var stats2: Dictionary = p2.get("stats", {}) as Dictionary
		for stat_name in stats1.keys():
			t.assert_eq(
				float(stats1.get(stat_name, 0.0)),
				float(stats2.get(stat_name, 0.0)),
				"advance_years: same stat %s" % stat_name
			)

	# Verify original players were not modified
	t.assert_eq(int(original_players[0].get("age")), 22, "original player age unchanged")
	t.assert_eq(int(original_players[1].get("age")), 23, "original player age unchanged")

## Test that _merge_development_context produces identical results
## Verifies optimized merge logic maintains correctness
func _test_context_merge_determinism(t) -> void:
	var global_ctx := {
		"program_quality": 1.0,
		"competition_tier": 1.1,
		"usage": 0.9,
		"season": "hs"
	}
	var player_ctx := {
		"usage": 1.2,  # Overrides global
		"scheme_fit": {"score": 0.05},
		"extra_field": "test"
	}

	var merged := PlayerLifecycle._merge_development_context(global_ctx, player_ctx)

	t.assert_eq(float(merged.get("program_quality")), 1.0, "global key present")
	t.assert_eq(float(merged.get("competition_tier")), 1.1, "global key present")
	t.assert_eq(float(merged.get("usage")), 1.2, "player key overrides global")
	t.assert_eq(String(merged.get("season")), "hs", "global key present")
	t.assert_true(merged.has("scheme_fit"), "player-only key present")
	t.assert_eq(String(merged.get("extra_field")), "test", "player-only key present")

## Test that injury normalization produces identical results
## Verifies selective copying of injury structures maintains correctness
func _test_injury_normalization_determinism(t) -> void:
	var injury := {
		"type": "ACL",
		"severity": 0.8,
		"affected_stats": ["speed", "agility"],
		"recovery_timeline": {
			"years_total": 2,
			"years_remaining": 1,
			"status": "active"
		},
		"long_term_penalty": {
			"stat_caps": {"speed": 85.0, "agility": 80.0},
			"decline_multipliers": {"speed": 1.2, "agility": 1.15}
		}
	}

	var normalized1 := PlayerLifecycle._normalize_injury(injury)
	var normalized2 := PlayerLifecycle._normalize_injury(injury)

	t.assert_eq(String(normalized1.get("type")), "ACL", "injury type preserved")
	t.assert_eq(float(normalized1.get("severity")), 0.8, "injury severity preserved")

	var affected1: Array = normalized1.get("affected_stats", []) as Array
	var affected2: Array = normalized2.get("affected_stats", []) as Array
	t.assert_eq(affected1.size(), 2, "affected stats size correct")
	t.assert_eq(affected1[0], affected2[0], "affected stats identical")

	var timeline1: Dictionary = normalized1.get("recovery_timeline", {}) as Dictionary
	var timeline2: Dictionary = normalized2.get("recovery_timeline", {}) as Dictionary
	t.assert_eq(int(timeline1.get("years_remaining")), 1, "timeline years_remaining correct")
	t.assert_eq(timeline1.get("years_remaining"), timeline2.get("years_remaining"), "timelines identical")

	# Modify original injury and verify normalized copies are isolated
	injury["severity"] = 0.5
	t.assert_eq(float(normalized1.get("severity")), 0.8, "normalized injury isolated from original")

## Test that report generation with shallow copies maintains determinism
## Verifies report optimizations don't affect correctness
func _test_report_generation_determinism(t) -> void:
	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy"],
			"development": {"peak_age": 26, "decline_start": 30, "curve": "mid"}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.2,
			"decline_min": 1.0,
			"decline_max": 1.0
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 1.0,
		"annual_progress_cap": 5.0,
		"retirement": {"min_age": 35, "soft_cap_age": 36, "max_age": 40, "base_chance": 0.0},
		"wear": {
			"snaps_per_year": 600,
			"collisions_per_year": 50,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		},
		"injury": {"base_chance": 0.0}
	}
	var stats_cfg := {"stats": [{"name": "accuracy", "type": "base"}]}

	var player := {
		"player_id": "p1",
		"age": 22,
		"position": "QB",
		"stats": {"accuracy": 60.0},
		"potential": {"accuracy": 80.0}
	}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var result1 := PlayerLifecycle.advance_one_year([player], positions_cfg, main_cfg, stats_cfg, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var result2 := PlayerLifecycle.advance_one_year([player], positions_cfg, main_cfg, stats_cfg, rng2)

	var reports1 := result1.get("development_reports", []) as Array
	var reports2 := result2.get("development_reports", []) as Array

	t.assert_eq(reports1.size(), reports2.size(), "same report count")
	if reports1.size() > 0:
		var report1: Dictionary = reports1[0]
		var report2: Dictionary = reports2[0]
		t.assert_eq(report1.get("age"), report2.get("age"), "report age identical")
		t.assert_eq(report1.get("phase"), report2.get("phase"), "report phase identical")

## Test multi-year advancement maintains determinism across all optimizations
## This is the most comprehensive test - exercises all optimization paths
func _test_multi_year_advance_determinism(t) -> void:
	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy", "decision", "arm_strength"],
			"development": {"peak_age": 26, "decline_start": 30, "curve": "mid"}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.2, "prime": 0.35, "decline": 1.1}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"development_context": {
			"scheme_fit": {
				"score_min": -0.15,
				"score_max": 0.15,
				"role_weights": {"core": 0.3, "secondary": 0.1},
				"multiplier_min": 0.85,
				"multiplier_max": 1.15
			}
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0,
		"retirement": {"min_age": 35, "soft_cap_age": 36, "max_age": 40, "base_chance": 0.02},
		"wear": {
			"snaps_per_year": 600,
			"collisions_per_year": 50,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		},
		"injury": {"base_chance": 0.05, "proneness_slope": 0.1}
	}
	var stats_cfg := {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "decision", "type": "base"},
		{"name": "arm_strength", "type": "base"},
		{"name": "injury_proneness", "type": "base"}
	]}

	var players := [
		{
			"player_id": "p1",
			"name": "Test QB",
			"age": 22,
			"position": "QB",
			"stats": {"accuracy": 65.0, "decision": 60.0, "arm_strength": 70.0, "injury_proneness": 50.0},
			"potential": {"accuracy": 85.0, "decision": 80.0, "arm_strength": 90.0, "injury_proneness": 50.0},
			"development_context": {"program_quality": 1.0, "competition_tier": 1.0, "usage": 1.0}
		}
	]

	# Run 5-year simulation twice with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 777777
	var result1 := PlayerLifecycle.advance_years(players, 5, positions_cfg, main_cfg, stats_cfg, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 777777
	var result2 := PlayerLifecycle.advance_years(players, 5, positions_cfg, main_cfg, stats_cfg, rng2)

	var players1 := result1.get("players", []) as Array
	var players2 := result2.get("players", []) as Array

	t.assert_eq(players1.size(), players2.size(), "multi-year: same player count after 5 years")

	if players1.size() > 0 and players2.size() > 0:
		var p1: Dictionary = players1[0]
		var p2: Dictionary = players2[0]

		t.assert_eq(p1.get("age"), p2.get("age"), "multi-year: age identical after 5 years")

		var stats1: Dictionary = p1.get("stats", {}) as Dictionary
		var stats2: Dictionary = p2.get("stats", {}) as Dictionary
		for stat_name in ["accuracy", "decision", "arm_strength"]:
			var val1 := float(stats1.get(stat_name, 0.0))
			var val2 := float(stats2.get(stat_name, 0.0))
			t.assert_eq(val1, val2, "multi-year: stat %s identical after 5 years" % stat_name)

		var wear1: Dictionary = p1.get("wear", {}) as Dictionary
		var wear2: Dictionary = p2.get("wear", {}) as Dictionary
		t.assert_eq(wear1.get("snaps"), wear2.get("snaps"), "multi-year: wear snaps identical")
		t.assert_eq(wear1.get("collisions"), wear2.get("collisions"), "multi-year: wear collisions identical")

## Test that advance_years doesn't modify original input array
## Critical for verifying no side effects from removing initial copy
func _test_advance_years_isolation(t) -> void:
	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy"],
			"development": {"peak_age": 26, "decline_start": 30, "curve": "mid"}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.2,
			"decline_min": 1.0,
			"decline_max": 1.0
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 1.0,
		"annual_progress_cap": 5.0,
		"retirement": {"min_age": 35, "soft_cap_age": 36, "max_age": 40, "base_chance": 0.0},
		"wear": {
			"snaps_per_year": 600,
			"collisions_per_year": 50,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}
	var stats_cfg := {"stats": [{"name": "accuracy", "type": "base"}]}

	var original_players := [
		{
			"player_id": "p1",
			"age": 22,
			"position": "QB",
			"stats": {"accuracy": 60.0},
			"potential": {"accuracy": 80.0}
		}
	]

	# Capture original values
	var original_age := int(original_players[0].get("age"))
	var original_stats: Dictionary = original_players[0].get("stats", {}) as Dictionary
	var original_accuracy := float(original_stats.get("accuracy", 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 11111
	var _result := PlayerLifecycle.advance_years(original_players, 3, positions_cfg, main_cfg, stats_cfg, rng)

	# Verify original was not modified
	t.assert_eq(int(original_players[0].get("age")), original_age, "original age unchanged")
	var current_stats: Dictionary = original_players[0].get("stats", {}) as Dictionary
	t.assert_eq(float(current_stats.get("accuracy", 0.0)), original_accuracy, "original accuracy unchanged")

## Test parallel vs serial advance_one_year determinism
## Verifies parallel implementation maintains identical results to serial
func _test_parallel_determinism_vs_serial(t) -> void:
	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy", "decision"],
			"development": {"peak_age": 26, "decline_start": 30, "curve": "mid"}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0,
		"retirement": {"min_age": 35, "soft_cap_age": 36, "max_age": 40, "base_chance": 0.0},
		"wear": {
			"snaps_per_year": 600,
			"collisions_per_year": 50,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}
	var stats_cfg := {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "decision", "type": "base"}
	]}

	# Create 200 players (above PARALLEL_THRESHOLD)
	var players := []
	for i in range(200):
		players.append({
			"player_id": "p%d" % i,
			"age": 22 + (i % 5),
			"position": "QB",
			"stats": {"accuracy": 60.0 + (i % 20), "decision": 55.0 + (i % 25)},
			"potential": {"accuracy": 80.0, "decision": 75.0}
		})

	# Run serial
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 555555
	var result_serial := PlayerLifecycle.advance_one_year(
		players,
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng1
	)

	# Run parallel with 4 threads
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 555555
	var result_parallel := PlayerLifecycle.advance_one_year_parallel(
		players,
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng2,
		{},
		4
	)

	var players_serial := result_serial.get("players", []) as Array
	var players_parallel := result_parallel.get("players", []) as Array

	t.assert_eq(players_serial.size(), players_parallel.size(), "parallel: same player count as serial")

	# Check first 10 players for determinism
	for i in range(min(10, players_serial.size())):
		var p_serial: Dictionary = players_serial[i]
		var p_parallel: Dictionary = players_parallel[i]
		t.assert_eq(p_serial.get("age"), p_parallel.get("age"), "parallel: player %d age matches serial" % i)

		var stats_serial: Dictionary = p_serial.get("stats", {}) as Dictionary
		var stats_parallel: Dictionary = p_parallel.get("stats", {}) as Dictionary
		t.assert_eq(
			float(stats_serial.get("accuracy", 0.0)),
			float(stats_parallel.get("accuracy", 0.0)),
			"parallel: player %d accuracy matches serial" % i
		)

## Test with injury-heavy workload to stress injury normalization optimization
func _test_injury_heavy_workload_determinism(t) -> void:
	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy"],
			"development": {"peak_age": 26, "decline_start": 30, "curve": "mid"}
		}
	}
	var main_cfg := {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.2,
			"decline_min": 1.0,
			"decline_max": 1.0
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 1.0,
		"annual_progress_cap": 5.0,
		"retirement": {"min_age": 35, "soft_cap_age": 36, "max_age": 40, "base_chance": 0.0},
		"wear": {
			"snaps_per_year": 600,
			"collisions_per_year": 50,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		},
		"injury": {"base_chance": 0.0}
	}
	var stats_cfg := {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "injury_proneness", "type": "base"}
	]}

	# Create player with multiple active injuries
	var player := {
		"player_id": "p1",
		"age": 25,
		"position": "QB",
		"stats": {"accuracy": 70.0, "injury_proneness": 60.0},
		"potential": {"accuracy": 85.0, "injury_proneness": 60.0},
		"injuries": [
			{
				"type": "ACL",
				"severity": 0.8,
				"affected_stats": ["accuracy"],
				"recovery_timeline": {
					"years_total": 2,
					"years_remaining": 1,
					"status": "active"
				},
				"long_term_penalty": {
					"stat_caps": {"accuracy": 80.0},
					"decline_multipliers": {"accuracy": 1.2}
				}
			},
			{
				"type": "Concussion",
				"severity": 0.5,
				"affected_stats": ["accuracy"],
				"recovery_timeline": {
					"years_total": 1,
					"years_remaining": 1,
					"status": "active"
				},
				"long_term_penalty": {
					"stat_caps": {},
					"decline_multipliers": {}
				}
			}
		]
	}

	# Run twice with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 333333
	var result1 := PlayerLifecycle.advance_one_year([player], positions_cfg, main_cfg, stats_cfg, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 333333
	var result2 := PlayerLifecycle.advance_one_year([player], positions_cfg, main_cfg, stats_cfg, rng2)

	var players1 := result1.get("players", []) as Array
	var players2 := result2.get("players", []) as Array

	t.assert_eq(players1.size(), 1, "injury test: player survived")
	t.assert_eq(players2.size(), 1, "injury test: player survived")

	var p1: Dictionary = players1[0]
	var p2: Dictionary = players2[0]

	var stats1: Dictionary = p1.get("stats", {}) as Dictionary
	var stats2: Dictionary = p2.get("stats", {}) as Dictionary
	t.assert_eq(
		float(stats1.get("accuracy", 0.0)),
		float(stats2.get("accuracy", 0.0)),
		"injury test: accuracy identical with active injuries"
	)

	var injuries1: Array = p1.get("injuries", []) as Array
	var injuries2: Array = p2.get("injuries", []) as Array
	t.assert_eq(injuries1.size(), injuries2.size(), "injury test: same injury count")

	if injuries1.size() > 0:
		var injury1: Dictionary = injuries1[0]
		var injury2: Dictionary = injuries2[0]
		var timeline1: Dictionary = injury1.get("recovery_timeline", {}) as Dictionary
		var timeline2: Dictionary = injury2.get("recovery_timeline", {}) as Dictionary
		t.assert_eq(
			timeline1.get("years_remaining"),
			timeline2.get("years_remaining"),
			"injury test: recovery timeline identical"
		)
