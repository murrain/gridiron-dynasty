## GdUnit4 test suite for ScoutingResourceManager
##
## Tests scouting depth levels, multi-year bonuses, staleness penalties,
## resource tiers, and report lifecycle.
extends GdUnitTestSuite

const ScoutingResourceManager = preload("res://scripts/core/scouting/ScoutingResourceManager.gd")


func test_scouting_depth_levels() -> void:
	# Test depth level thresholds
	var minimal := ScoutingResourceManager.calculate_scouting_depth(3.0)
	assert_str(String(minimal["level"])).is_equal("minimal")
	assert_float(float(minimal["accuracy_modifier"])).is_equal_approx(0.7, 0.01)

	var basic := ScoutingResourceManager.calculate_scouting_depth(10.0)
	assert_str(String(basic["level"])).is_equal("basic")
	assert_float(float(basic["accuracy_modifier"])).is_equal_approx(0.85, 0.01)

	var detailed := ScoutingResourceManager.calculate_scouting_depth(30.0)
	assert_str(String(detailed["level"])).is_equal("detailed")
	assert_float(float(detailed["accuracy_modifier"])).is_equal_approx(1.0, 0.01)

	var comprehensive := ScoutingResourceManager.calculate_scouting_depth(80.0)
	assert_str(String(comprehensive["level"])).is_equal("comprehensive")
	assert_float(float(comprehensive["accuracy_modifier"])).is_equal_approx(1.15, 0.01)

	# Test boundary - 0 hours defaults to minimal (no "none" level in implementation)
	var zero := ScoutingResourceManager.calculate_scouting_depth(0.0)
	assert_str(String(zero["level"])).is_equal("minimal")

	# Test exact threshold boundaries
	var just_basic := ScoutingResourceManager.calculate_scouting_depth(8.0)
	assert_str(String(just_basic["level"])).is_equal("basic")

	var just_detailed := ScoutingResourceManager.calculate_scouting_depth(25.0)
	assert_str(String(just_detailed["level"])).is_equal("detailed")

	var just_comprehensive := ScoutingResourceManager.calculate_scouting_depth(60.0)
	assert_str(String(just_comprehensive["level"])).is_equal("comprehensive")


func test_multi_year_bonus() -> void:
	var bonus_1yr := ScoutingResourceManager.calculate_multi_year_bonus(1)
	assert_float(float(bonus_1yr["accuracy_bonus"])).is_equal_approx(0.0, 0.001)
	assert_float(float(bonus_1yr["variance_reduction"])).is_equal_approx(0.0, 0.001)

	var bonus_2yr := ScoutingResourceManager.calculate_multi_year_bonus(2)
	assert_float(float(bonus_2yr["accuracy_bonus"])).is_equal_approx(0.05, 0.001)
	assert_float(float(bonus_2yr["variance_reduction"])).is_equal_approx(0.15, 0.001)

	var bonus_3yr := ScoutingResourceManager.calculate_multi_year_bonus(3)
	assert_float(float(bonus_3yr["accuracy_bonus"])).is_equal_approx(0.10, 0.001)
	assert_float(float(bonus_3yr["variance_reduction"])).is_equal_approx(0.30, 0.001)

	var bonus_4yr := ScoutingResourceManager.calculate_multi_year_bonus(4)
	assert_float(float(bonus_4yr["accuracy_bonus"])).is_equal_approx(0.15, 0.001)
	assert_float(float(bonus_4yr["variance_reduction"])).is_equal_approx(0.45, 0.001)

	# Test cap at 4 years
	var bonus_5yr := ScoutingResourceManager.calculate_multi_year_bonus(5)
	assert_float(float(bonus_5yr["accuracy_bonus"])).is_equal_approx(0.15, 0.001)


func test_staleness_penalty() -> void:
	# Current year = no penalty
	var current := ScoutingResourceManager.calculate_staleness_penalty(2025, 2025)
	assert_float(current).is_equal_approx(1.0, 0.01)

	# 1 year old
	var one_year := ScoutingResourceManager.calculate_staleness_penalty(2024, 2025)
	assert_float(one_year).is_equal_approx(0.9, 0.01)

	# 2 years old
	var two_years := ScoutingResourceManager.calculate_staleness_penalty(2023, 2025)
	assert_float(two_years).is_equal_approx(0.75, 0.01)

	# 3+ years old
	var three_years := ScoutingResourceManager.calculate_staleness_penalty(2022, 2025)
	assert_float(three_years).is_equal_approx(0.5, 0.01)


func test_resource_tiers() -> void:
	var nfl := ScoutingResourceManager.get_resources_for_tier("nfl")
	assert_int(int(nfl["annual_scout_hours"])).is_equal(8000)

	var p5 := ScoutingResourceManager.get_resources_for_tier("college_p5")
	assert_int(int(p5["annual_scout_hours"])).is_equal(3000)

	var g5 := ScoutingResourceManager.get_resources_for_tier("college_g5")
	assert_int(int(g5["annual_scout_hours"])).is_equal(1500)

	var fcs := ScoutingResourceManager.get_resources_for_tier("college_fcs")
	assert_int(int(fcs["annual_scout_hours"])).is_equal(800)

	# Test affordability (hours_remaining, target_depth)
	assert_bool(ScoutingResourceManager.can_afford_depth(5000.0, "detailed")).is_true()
	assert_bool(ScoutingResourceManager.can_afford_depth(50.0, "comprehensive")).is_false()


func test_report_lifecycle() -> void:
	# Create empty report
	var report := ScoutingResourceManager.create_empty_report("player-123", 2025)
	assert_str(String(report["player_id"])).is_equal("player-123")
	assert_int(int(report["last_updated_year"])).is_equal(2025)
	assert_float(float(report["hours_invested"])).is_equal_approx(0.0, 0.01)

	# Update report
	var observations := {"speed": 72.5, "strength": 68.0}
	var updated := ScoutingResourceManager.update_report(report, observations, 10.0, 2025)
	assert_float(float(updated["hours_invested"])).is_equal_approx(10.0, 0.01)
	assert_int(int(updated["last_updated_year"])).is_equal(2025)
	assert_bool((updated["revealed_stats"] as Dictionary).has("speed")).is_true()

	# Check staleness
	assert_bool(ScoutingResourceManager.is_report_stale(updated, 2025)).is_false()
	assert_bool(ScoutingResourceManager.is_report_stale(updated, 2027)).is_false()
	assert_bool(ScoutingResourceManager.is_report_stale(updated, 2029)).is_true()
