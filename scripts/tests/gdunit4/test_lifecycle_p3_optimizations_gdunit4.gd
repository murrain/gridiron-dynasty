## GdUnit4 test suite for P3 lifecycle copy reduction optimizations
##
## Verifies that all optimizations maintain determinism and correctness.
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")


func test_advance_years_no_initial_copy_determinism() -> void:
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
		}
	]

	# Run twice with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := PlayerLifecycle.advance_years(
		original_players, 3, positions_cfg, main_cfg, stats_cfg, rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := PlayerLifecycle.advance_years(
		original_players, 3, positions_cfg, main_cfg, stats_cfg, rng2
	)

	var players1 := result1.get("players", []) as Array
	var players2 := result2.get("players", []) as Array

	assert_int(players1.size()).is_equal(players2.size())

	for i in range(players1.size()):
		var p1: Dictionary = players1[i]
		var p2: Dictionary = players2[i]
		assert_str(p1.get("player_id")).is_equal(p2.get("player_id"))
		assert_int(p1.get("age")).is_equal(p2.get("age"))


func test_context_merge_determinism() -> void:
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

	assert_float(float(merged.get("program_quality"))).is_equal(1.0)
	assert_float(float(merged.get("competition_tier"))).is_equal(1.1)
	assert_float(float(merged.get("usage"))).is_equal(1.2)  # Player overrides
	assert_str(String(merged.get("season"))).is_equal("hs")
	assert_bool(merged.has("scheme_fit")).is_true()
	assert_str(String(merged.get("extra_field"))).is_equal("test")


func test_injury_normalization_determinism() -> void:
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

	assert_str(String(normalized1.get("type"))).is_equal("ACL")
	assert_float(float(normalized1.get("severity"))).is_equal(0.8)

	var affected1: Array = normalized1.get("affected_stats", []) as Array
	var affected2: Array = normalized2.get("affected_stats", []) as Array
	assert_int(affected1.size()).is_equal(2)
	assert_str(affected1[0]).is_equal(affected2[0])

	var timeline1: Dictionary = normalized1.get("recovery_timeline", {}) as Dictionary
	var timeline2: Dictionary = normalized2.get("recovery_timeline", {}) as Dictionary
	assert_int(int(timeline1.get("years_remaining"))).is_equal(1)
	assert_int(timeline1.get("years_remaining")).is_equal(timeline2.get("years_remaining"))


func test_advance_years_isolation() -> void:
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
	assert_int(int(original_players[0].get("age"))).is_equal(original_age)
	var current_stats: Dictionary = original_players[0].get("stats", {}) as Dictionary
	assert_float(float(current_stats.get("accuracy", 0.0))).is_equal(original_accuracy)


func test_injury_heavy_workload_determinism() -> void:
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

	assert_int(players1.size()).is_equal(1)
	assert_int(players2.size()).is_equal(1)

	var p1: Dictionary = players1[0]
	var p2: Dictionary = players2[0]

	var stats1: Dictionary = p1.get("stats", {}) as Dictionary
	var stats2: Dictionary = p2.get("stats", {}) as Dictionary
	assert_float(float(stats1.get("accuracy", 0.0))).is_equal(float(stats2.get("accuracy", 0.0)))
