extends RefCounted

const ScoutingResourceManager = preload("res://scripts/core/scouting/ScoutingResourceManager.gd")

func run(t) -> void:
	_test_scouting_depth_levels(t)
	_test_multi_year_bonus(t)
	_test_staleness_penalty(t)
	_test_resource_tiers(t)
	_test_report_lifecycle(t)

func _test_scouting_depth_levels(t) -> void:
	# Test depth level thresholds
	var minimal := ScoutingResourceManager.calculate_scouting_depth(3.0)
	t.assert_eq(minimal["level"], "minimal", "3 hours = minimal depth")
	t.assert_approx(minimal["accuracy_modifier"], 0.7, 0.01, "minimal accuracy = 0.7")

	var basic := ScoutingResourceManager.calculate_scouting_depth(10.0)
	t.assert_eq(basic["level"], "basic", "10 hours = basic depth")
	t.assert_approx(basic["accuracy_modifier"], 0.85, 0.01, "basic accuracy = 0.85")

	var detailed := ScoutingResourceManager.calculate_scouting_depth(30.0)
	t.assert_eq(detailed["level"], "detailed", "30 hours = detailed depth")
	t.assert_approx(detailed["accuracy_modifier"], 1.0, 0.01, "detailed accuracy = 1.0")

	var comprehensive := ScoutingResourceManager.calculate_scouting_depth(80.0)
	t.assert_eq(comprehensive["level"], "comprehensive", "80 hours = comprehensive depth")
	t.assert_approx(comprehensive["accuracy_modifier"], 1.15, 0.01, "comprehensive accuracy = 1.15")

	# Test boundary - 0 hours defaults to minimal (no "none" level in implementation)
	var zero := ScoutingResourceManager.calculate_scouting_depth(0.0)
	t.assert_eq(zero["level"], "minimal", "0 hours = minimal (default)")

	# Test exact threshold boundaries
	var just_basic := ScoutingResourceManager.calculate_scouting_depth(8.0)
	t.assert_eq(just_basic["level"], "basic", "8 hours = basic (threshold)")

	var just_detailed := ScoutingResourceManager.calculate_scouting_depth(25.0)
	t.assert_eq(just_detailed["level"], "detailed", "25 hours = detailed (threshold)")

	var just_comprehensive := ScoutingResourceManager.calculate_scouting_depth(60.0)
	t.assert_eq(just_comprehensive["level"], "comprehensive", "60 hours = comprehensive (threshold)")

func _test_multi_year_bonus(t) -> void:
	var bonus_1yr := ScoutingResourceManager.calculate_multi_year_bonus(1)
	t.assert_approx(bonus_1yr["accuracy_bonus"], 0.0, 0.001, "1 year = no accuracy bonus")
	t.assert_approx(bonus_1yr["variance_reduction"], 0.0, 0.001, "1 year = no variance reduction")

	var bonus_2yr := ScoutingResourceManager.calculate_multi_year_bonus(2)
	t.assert_approx(bonus_2yr["accuracy_bonus"], 0.05, 0.001, "2 years = 5% accuracy bonus")
	t.assert_approx(bonus_2yr["variance_reduction"], 0.15, 0.001, "2 years = 15% variance reduction")

	var bonus_3yr := ScoutingResourceManager.calculate_multi_year_bonus(3)
	t.assert_approx(bonus_3yr["accuracy_bonus"], 0.10, 0.001, "3 years = 10% accuracy bonus")
	t.assert_approx(bonus_3yr["variance_reduction"], 0.30, 0.001, "3 years = 30% variance reduction")

	var bonus_4yr := ScoutingResourceManager.calculate_multi_year_bonus(4)
	t.assert_approx(bonus_4yr["accuracy_bonus"], 0.15, 0.001, "4 years = 15% accuracy bonus")
	t.assert_approx(bonus_4yr["variance_reduction"], 0.45, 0.001, "4 years = 45% variance reduction")

	# Test cap at 4 years
	var bonus_5yr := ScoutingResourceManager.calculate_multi_year_bonus(5)
	t.assert_approx(bonus_5yr["accuracy_bonus"], 0.15, 0.001, "5+ years capped at 4yr bonus")

func _test_staleness_penalty(t) -> void:
	# Current year = no penalty
	var current := ScoutingResourceManager.calculate_staleness_penalty(2025, 2025)
	t.assert_approx(current, 1.0, 0.01, "Same year = no penalty")

	# 1 year old
	var one_year := ScoutingResourceManager.calculate_staleness_penalty(2024, 2025)
	t.assert_approx(one_year, 0.9, 0.01, "1 year old = 10% penalty")

	# 2 years old
	var two_years := ScoutingResourceManager.calculate_staleness_penalty(2023, 2025)
	t.assert_approx(two_years, 0.75, 0.01, "2 years old = 25% penalty")

	# 3+ years old
	var three_years := ScoutingResourceManager.calculate_staleness_penalty(2022, 2025)
	t.assert_approx(three_years, 0.5, 0.01, "3+ years old = 50% penalty")

func _test_resource_tiers(t) -> void:
	var nfl := ScoutingResourceManager.get_resources_for_tier("nfl")
	t.assert_eq(nfl["annual_scout_hours"], 8000, "NFL = 8000 hours")

	var p5 := ScoutingResourceManager.get_resources_for_tier("college_p5")
	t.assert_eq(p5["annual_scout_hours"], 3000, "P5 = 3000 hours")

	var g5 := ScoutingResourceManager.get_resources_for_tier("college_g5")
	t.assert_eq(g5["annual_scout_hours"], 1500, "G5 = 1500 hours")

	var fcs := ScoutingResourceManager.get_resources_for_tier("college_fcs")
	t.assert_eq(fcs["annual_scout_hours"], 800, "FCS = 800 hours")

	# Test affordability (hours_remaining, target_depth)
	t.assert_true(
		ScoutingResourceManager.can_afford_depth(5000.0, "detailed"),
		"Can afford detailed with 5000 remaining"
	)
	t.assert_true(
		not ScoutingResourceManager.can_afford_depth(50.0, "comprehensive"),
		"Cannot afford comprehensive with only 50 remaining"
	)

func _test_report_lifecycle(t) -> void:
	# Create empty report
	var report := ScoutingResourceManager.create_empty_report("player-123", 2025)
	t.assert_eq(report["player_id"], "player-123", "Report has correct player_id")
	t.assert_eq(report["last_updated_year"], 2025, "Report has last_updated_year")
	t.assert_approx(report["hours_invested"], 0.0, 0.01, "New report has 0 hours")

	# Update report
	var observations := {"speed": 72.5, "strength": 68.0}
	var updated := ScoutingResourceManager.update_report(report, observations, 10.0, 2025)
	t.assert_approx(updated["hours_invested"], 10.0, 0.01, "Updated report has 10 hours")
	t.assert_eq(updated["last_updated_year"], 2025, "Last updated year set")
	t.assert_true(updated["revealed_stats"].has("speed"), "Speed revealed")

	# Check staleness
	t.assert_true(
		not ScoutingResourceManager.is_report_stale(updated, 2025),
		"Report not stale in same year"
	)
	t.assert_true(
		not ScoutingResourceManager.is_report_stale(updated, 2027),
		"Report not stale at 2 years"
	)
	t.assert_true(
		ScoutingResourceManager.is_report_stale(updated, 2029),
		"Report stale at 4+ years"
	)
