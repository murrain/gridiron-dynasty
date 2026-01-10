extends RefCounted

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func run(t) -> void:
	var positions_cfg = {
		"QB": {
			"core_stats": ["accuracy", "decision"],
			"development": {"peak_age": 20, "decline_start": 21, "curve": "fast"}
		}
	}
	var main_cfg = {
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
	var stats_cfg = {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "decision", "type": "base"}
	]}

	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	var player = {"age": 19, "position": "QB", "stats": {"accuracy": 50.0, "decision": 40.0}, "potential": {"accuracy": 60.0, "decision": 45.0}}
	var result = PlayerLifecycle.advance_one_year([player], positions_cfg, main_cfg, stats_cfg, rng)
	var updated = result.get("players", []) as Array
	var evolved = updated[0] as Dictionary
	t.assert_eq(evolved.get("age"), 20, "advance_one_year increments age")
	var stats = evolved.get("stats", {}) as Dictionary
	t.assert_between(float(stats.get("accuracy")), 50.0, 60.0, "development should stay within potential")
	var wear = evolved.get("wear", {}) as Dictionary
	t.assert_eq(int(wear.get("snaps", 0)), 100, "wear snaps increment")
	t.assert_eq(int(wear.get("collisions", 0)), 10, "wear collisions increment")
	var report = evolved.get("development_report", []) as Array
	t.assert_eq(report.size(), 1, "development report logged")
	t.assert_eq(float((report[0] as Dictionary).get("decline_multiplier", 0.0)), 1.0, "decline multiplier is neutral before decline")

	var result_retire = PlayerLifecycle.advance_one_year([{"age": 21, "position": "QB", "stats": {"accuracy": 40.0}}], positions_cfg, main_cfg, stats_cfg, rng)
	t.assert_eq((result_retire.get("retired", []) as Array).size(), 1, "retirement at max age")

	var core_rating = PlayerLifecycle._core_rating(player, positions_cfg)
	t.assert_eq(core_rating, 45.0, "core rating averages core stats")
