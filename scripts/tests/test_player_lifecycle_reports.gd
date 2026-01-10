extends RefCounted

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func _run_once(seed: int) -> Dictionary:
	var positions_cfg = {
		"QB": {
			"core_stats": ["accuracy"],
			"development": {"peak_age": 20, "decline_start": 30, "curve": "fast"}
		}
	}
	var main_cfg = {
		"development": {
			"curve_multipliers": {"fast": {"growth": 1.0, "prime": 1.0, "decline": 1.0}},
			"prime_growth_min": 0.25,
			"prime_growth_max": 0.25,
			"decline_min": 0.9,
			"decline_max": 0.9
		},
		"annual_base_progress_min": 1.5,
		"annual_base_progress_max": 1.5,
		"annual_progress_cap": 5.0,
		"retirement": {"min_age": 99, "soft_cap_age": 99, "max_age": 120, "base_chance": 0.0},
		"injury": {"base_chance": 0.1, "proneness_slope": 0.2}
	}
	var stats_cfg = {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "injury_proneness", "type": "base"}
	]}

	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	var player = {
		"age": 19,
		"position": "QB",
		"stats": {"accuracy": 55.0, "injury_proneness": 80.0},
		"potential": {"accuracy": 70.0}
	}
	var result = PlayerLifecycle.advance_one_year([player], positions_cfg, main_cfg, stats_cfg, rng)
	var evolved = (result.get("players", []) as Array)[0] as Dictionary
	var report = (result.get("development_reports", []) as Array)[0] as Dictionary
	return {
		"stats": evolved.get("stats", {}) as Dictionary,
		"development_report": report,
		"injury_report": evolved.get("injury_report", {}) as Dictionary
	}

func run(t) -> void:
	var first = _run_once(4242)
	var second = _run_once(4242)
	var third = _run_once(7777)

	t.assert_eq(first.get("stats"), second.get("stats"), "stats should be deterministic for fixed seed")
	t.assert_eq(first.get("development_report"), second.get("development_report"), "development reports should match for fixed seed")
	t.assert_eq(first.get("injury_report"), second.get("injury_report"), "injury reports should match for fixed seed")

	var dev_report: Dictionary = first.get("development_report", {}) as Dictionary
	var entries: Array = dev_report.get("stat_entries", []) as Array
	t.assert_true(not entries.is_empty(), "development report should include stat entries")
	var entry = entries[0] as Dictionary
	t.assert_true(entry.has("raw_draw"), "development report should capture RNG draw")
	t.assert_true(entry.has("multiplier"), "development report should capture modifier")

	var injury_report: Dictionary = first.get("injury_report", {}) as Dictionary
	t.assert_true(injury_report.has("roll"), "injury report should capture RNG draw")
	t.assert_true(injury_report.has("chance"), "injury report should capture applied chance")

	var second_injury_report: Dictionary = second.get("injury_report", {}) as Dictionary
	t.assert_eq(injury_report.get("roll"), second_injury_report.get("roll"), "injury roll should be deterministic")
	var third_injury_report: Dictionary = third.get("injury_report", {}) as Dictionary
	t.assert_ne(injury_report.get("roll"), third_injury_report.get("roll"), "injury roll should differ with different seed")
