## GdUnit4 test suite for HighSchoolSeason
##
## Validates high school season progression and graduation.
## Migrated from test_high_school_season.gd
extends GdUnitTestSuite

const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")


func test_player_graduates_after_hs_years() -> void:
	var players = [
		{"player_id": "p1", "name": "Player One", "hs_year": 1, "stats": {"speed": 80.0}, "hs_school_id": "s1"}
	]
	var schools = [
		{"id": "s1", "eliteness": 70.0}
	]
	var positions_cfg = {"WR": {"development": {"peak_age": 18, "decline_start": 30, "curve": "mid"}}}
	var main_cfg = {
		"development": {"curve_multipliers": {"mid": {"growth": 1.0, "prime": 1.0, "decline": 1.0}}, "prime_growth_min": 0.2, "prime_growth_max": 0.2, "decline_min": 0.5, "decline_max": 0.5},
		"annual_base_progress_min": 0.0,
		"annual_base_progress_max": 0.0,
		"annual_progress_cap": 2.0,
		"retirement": {"min_age": 99, "soft_cap_age": 99, "max_age": 120, "base_chance": 0.0}
	}
	var stats_cfg = {"stats": [{"name": "speed", "type": "base"}]}
	var config = {
		"eligibility": {"hs_years": 2, "underclass_years": 1},
		"performance": {"base_min": 50.0, "base_max": 50.0, "rating_weight": 0.0, "school_eliteness_weight": 0.0, "noise_min": 0.0, "noise_max": 0.0}
	}

	var season = HighSchoolSeason.new()
	var result = season.run(players, schools, positions_cfg, main_cfg, stats_cfg, config, 555, 2025)
	var graduates = result.get("graduates", []) as Array
	assert_int(graduates.size()).is_equal(1)


func test_graduate_status_is_hs_grad() -> void:
	var players = [
		{"player_id": "p1", "name": "Player One", "hs_year": 1, "stats": {"speed": 80.0}, "hs_school_id": "s1"}
	]
	var schools = [{"id": "s1", "eliteness": 70.0}]
	var positions_cfg = {"WR": {"development": {"peak_age": 18, "decline_start": 30, "curve": "mid"}}}
	var main_cfg = {
		"development": {"curve_multipliers": {"mid": {"growth": 1.0, "prime": 1.0, "decline": 1.0}}, "prime_growth_min": 0.2, "prime_growth_max": 0.2, "decline_min": 0.5, "decline_max": 0.5},
		"annual_base_progress_min": 0.0, "annual_base_progress_max": 0.0, "annual_progress_cap": 2.0,
		"retirement": {"min_age": 99, "soft_cap_age": 99, "max_age": 120, "base_chance": 0.0}
	}
	var stats_cfg = {"stats": [{"name": "speed", "type": "base"}]}
	var config = {
		"eligibility": {"hs_years": 2, "underclass_years": 1},
		"performance": {"base_min": 50.0, "base_max": 50.0, "rating_weight": 0.0, "school_eliteness_weight": 0.0, "noise_min": 0.0, "noise_max": 0.0}
	}

	var season = HighSchoolSeason.new()
	var result = season.run(players, schools, positions_cfg, main_cfg, stats_cfg, config, 555, 2025)
	var transitions = result.get("transitions", []) as Array
	assert_str(String(transitions[0].get("new_status"))).is_equal("hs_grad")


func test_performance_bundle_includes_year() -> void:
	var players = [
		{"player_id": "p1", "name": "Player One", "hs_year": 1, "stats": {"speed": 80.0}, "hs_school_id": "s1"}
	]
	var schools = [{"id": "s1", "eliteness": 70.0}]
	var positions_cfg = {"WR": {"development": {"peak_age": 18, "decline_start": 30, "curve": "mid"}}}
	var main_cfg = {
		"development": {"curve_multipliers": {"mid": {"growth": 1.0, "prime": 1.0, "decline": 1.0}}, "prime_growth_min": 0.2, "prime_growth_max": 0.2, "decline_min": 0.5, "decline_max": 0.5},
		"annual_base_progress_min": 0.0, "annual_base_progress_max": 0.0, "annual_progress_cap": 2.0,
		"retirement": {"min_age": 99, "soft_cap_age": 99, "max_age": 120, "base_chance": 0.0}
	}
	var stats_cfg = {"stats": [{"name": "speed", "type": "base"}]}
	var config = {
		"eligibility": {"hs_years": 2, "underclass_years": 1},
		"performance": {"base_min": 50.0, "base_max": 50.0, "rating_weight": 0.0, "school_eliteness_weight": 0.0, "noise_min": 0.0, "noise_max": 0.0}
	}

	var season = HighSchoolSeason.new()
	var result = season.run(players, schools, positions_cfg, main_cfg, stats_cfg, config, 555, 2025)
	var graduates = result.get("graduates", []) as Array
	var perf = (graduates[0] as Dictionary).get("hs_stats", {}) as Dictionary
	assert_int(int(perf.get("year"))).is_equal(2025)
