extends RefCounted

func run(t: TestHelpers) -> void:
	var players := [
		{"player_id": "p1", "name": "Player One", "hs_year": 1, "stats": {"speed": 80.0}, "hs_school_id": "s1"}
	]
	var schools := [
		{"id": "s1", "eliteness": 70.0}
	]
	var positions_cfg := {"WR": {"development": {"peak_age": 18, "decline_start": 30, "curve": "mid"}}}
	var main_cfg := {
		"development": {"curve_multipliers": {"mid": {"growth": 1.0, "prime": 1.0, "decline": 1.0}}, "prime_growth_min": 0.2, "prime_growth_max": 0.2, "decline_min": 0.5, "decline_max": 0.5},
		"annual_base_progress_min": 0.0,
		"annual_base_progress_max": 0.0,
		"annual_progress_cap": 2.0,
		"retirement": {"min_age": 99, "soft_cap_age": 99, "max_age": 120, "base_chance": 0.0}
	}
	var stats_cfg := {"stats": [{"name": "speed", "type": "base"}]}
	var config := {
		"eligibility": {"hs_years": 2, "underclass_years": 1},
		"performance": {"base_min": 50.0, "base_max": 50.0, "rating_weight": 0.0, "school_eliteness_weight": 0.0, "noise_min": 0.0, "noise_max": 0.0}
	}

	var season := HighSchoolSeason.new()
	var result := season.run(players, schools, positions_cfg, main_cfg, stats_cfg, config, 555, 2025)
	var graduates := result.get("graduates", []) as Array
	var transitions := result.get("transitions", []) as Array
	t.assert_eq(graduates.size(), 1, "player should graduate after hs_years")
	t.assert_eq(transitions[0].get("new_status"), "hs_grad", "status should be graduate")
	var perf := (graduates[0] as Dictionary).get("hs_stats", {}) as Dictionary
	t.assert_eq(perf.get("year"), 2025, "performance bundle should include year")
