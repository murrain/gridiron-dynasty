## GdUnit4 test suite for CollegeStatsService
##
## Tests efficiency metrics calculation, production trajectory analysis,
## career totals, and draft modifiers.
extends GdUnitTestSuite

const CollegeStatsService = preload("res://scripts/world/CollegeStatsService.gd")


func test_calculate_efficiency_metrics_qb() -> void:
	var career_stats := {
		"qb_001": {
			2024: {
				"position": "QB",
				"attempts": 400,
				"completions": 260,
				"passing_yards": 3200,
				"touchdown_passes": 28,
				"interceptions": 8,
				"games_played": 12
			}
		}
	}

	var metrics := CollegeStatsService.calculate_efficiency_metrics(
		"qb_001", 2024, career_stats, {}
	)

	assert_bool(metrics.is_empty()).is_false()
	assert_bool(metrics.has("completion_percentage")).is_true()
	assert_bool(metrics.has("yards_per_attempt")).is_true()
	assert_bool(metrics.has("td_int_ratio")).is_true()
	assert_bool(metrics.has("qbr")).is_true()

	# Verify calculations
	var comp_pct := float(metrics.get("completion_percentage", 0.0))
	assert_float(abs(comp_pct - 65.0)).is_less(0.1)

	var ypa := float(metrics.get("yards_per_attempt", 0.0))
	assert_float(abs(ypa - 8.0)).is_less(0.1)


func test_calculate_efficiency_metrics_rb() -> void:
	var career_stats := {
		"rb_001": {
			2024: {
				"position": "RB",
				"carries": 200,
				"rushing_yards": 1200,
				"receptions": 30,
				"receiving_yards": 250,
				"games_played": 12
			}
		}
	}

	var metrics := CollegeStatsService.calculate_efficiency_metrics(
		"rb_001", 2024, career_stats, {}
	)

	assert_bool(metrics.is_empty()).is_false()
	assert_bool(metrics.has("yards_per_carry")).is_true()
	assert_bool(metrics.has("yards_per_touch")).is_true()

	var ypc := float(metrics.get("yards_per_carry", 0.0))
	assert_float(abs(ypc - 6.0)).is_less(0.1)


func test_analyze_production_trajectory_rising() -> void:
	# Rising trajectory
	var career_stats := {
		"player_001": {
			2022: {"position": "QB", "passing_yards": 2000, "touchdown_passes": 15, "interceptions": 8, "games_played": 12},
			2023: {"position": "QB", "passing_yards": 2800, "touchdown_passes": 22, "interceptions": 6, "games_played": 12},
			2024: {"position": "QB", "passing_yards": 3500, "touchdown_passes": 30, "interceptions": 5, "games_played": 12}
		}
	}

	var trajectory := CollegeStatsService.analyze_production_trajectory(
		"player_001", career_stats, {}
	)

	assert_str(trajectory.get("trend")).is_equal("rising")
	assert_bool(trajectory.has("year_over_year")).is_true()
	assert_bool(trajectory.has("consistency_score")).is_true()


func test_analyze_production_trajectory_insufficient_data() -> void:
	var single_year := {"player_002": {2024: {"position": "QB", "passing_yards": 3000}}}
	var trajectory := CollegeStatsService.analyze_production_trajectory("player_002", single_year, {})
	assert_str(trajectory.get("trend")).is_equal("insufficient_data")


func test_get_career_totals() -> void:
	var career_stats := {
		"player_001": {
			2022: {"position": "RB", "rushing_yards": 800, "rushing_touchdowns": 6, "games_played": 10, "games_started": 5},
			2023: {"position": "RB", "rushing_yards": 1100, "rushing_touchdowns": 10, "games_played": 12, "games_started": 12},
			2024: {"position": "RB", "rushing_yards": 1400, "rushing_touchdowns": 14, "games_played": 13, "games_started": 13}
		}
	}

	var totals := CollegeStatsService.get_career_totals("player_001", career_stats)

	assert_str(totals.get("position")).is_equal("RB")
	assert_int(int(totals.get("rushing_yards", 0))).is_equal(3300)
	assert_int(int(totals.get("rushing_touchdowns", 0))).is_equal(30)
	assert_int(int(totals.get("games_played", 0))).is_equal(35)
	assert_int(int(totals.get("seasons", 0))).is_equal(3)


func test_get_trajectory_draft_modifier() -> void:
	var config := {
		"trajectory_analysis": {
			"rising": {"draft_boost": 0.05},
			"declining": {"draft_penalty": -0.03}
		}
	}

	var rising := {"trend": "rising"}
	var modifier := CollegeStatsService.get_trajectory_draft_modifier(rising, config)
	assert_float(abs(modifier - 1.05)).is_less(0.001)

	var declining := {"trend": "declining"}
	modifier = CollegeStatsService.get_trajectory_draft_modifier(declining, config)
	assert_float(abs(modifier - 0.97)).is_less(0.001)

	var stable := {"trend": "stable"}
	modifier = CollegeStatsService.get_trajectory_draft_modifier(stable, config)
	assert_float(abs(modifier - 1.0)).is_less(0.001)
