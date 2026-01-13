extends RefCounted

const CollegeStatsService = preload("res://scripts/world/CollegeStatsService.gd")

func run(t) -> void:
	test_calculate_efficiency_metrics_qb(t)
	test_calculate_efficiency_metrics_rb(t)
	test_analyze_production_trajectory(t)
	test_get_career_totals(t)
	test_get_trajectory_draft_modifier(t)

func test_calculate_efficiency_metrics_qb(t) -> void:
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

	t.assert_true(not metrics.is_empty(), "QB metrics calculated")
	t.assert_true(metrics.has("completion_percentage"), "has completion_percentage")
	t.assert_true(metrics.has("yards_per_attempt"), "has yards_per_attempt")
	t.assert_true(metrics.has("td_int_ratio"), "has td_int_ratio")
	t.assert_true(metrics.has("qbr"), "has qbr")

	# Verify calculations
	var comp_pct := float(metrics.get("completion_percentage", 0.0))
	t.assert_true(abs(comp_pct - 65.0) < 0.1, "completion_percentage is ~65%")

	var ypa := float(metrics.get("yards_per_attempt", 0.0))
	t.assert_true(abs(ypa - 8.0) < 0.1, "yards_per_attempt is ~8.0")

func test_calculate_efficiency_metrics_rb(t) -> void:
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

	t.assert_true(not metrics.is_empty(), "RB metrics calculated")
	t.assert_true(metrics.has("yards_per_carry"), "has yards_per_carry")
	t.assert_true(metrics.has("yards_per_touch"), "has yards_per_touch")

	var ypc := float(metrics.get("yards_per_carry", 0.0))
	t.assert_true(abs(ypc - 6.0) < 0.1, "yards_per_carry is ~6.0")

func test_analyze_production_trajectory(t) -> void:
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

	t.assert_eq(trajectory.get("trend"), "rising", "rising production trajectory detected")
	t.assert_true(trajectory.has("year_over_year"), "has year_over_year changes")
	t.assert_true(trajectory.has("consistency_score"), "has consistency_score")

	# Insufficient data
	var single_year := {"player_002": {2024: {"position": "QB", "passing_yards": 3000}}}
	trajectory = CollegeStatsService.analyze_production_trajectory("player_002", single_year, {})
	t.assert_eq(trajectory.get("trend"), "insufficient_data", "single year = insufficient data")

func test_get_career_totals(t) -> void:
	var career_stats := {
		"player_001": {
			2022: {"position": "RB", "rushing_yards": 800, "rushing_touchdowns": 6, "games_played": 10, "games_started": 5},
			2023: {"position": "RB", "rushing_yards": 1100, "rushing_touchdowns": 10, "games_played": 12, "games_started": 12},
			2024: {"position": "RB", "rushing_yards": 1400, "rushing_touchdowns": 14, "games_played": 13, "games_started": 13}
		}
	}

	var totals := CollegeStatsService.get_career_totals("player_001", career_stats)

	t.assert_eq(totals.get("position"), "RB", "position preserved")
	t.assert_eq(int(totals.get("rushing_yards", 0)), 3300, "rushing yards summed correctly")
	t.assert_eq(int(totals.get("rushing_touchdowns", 0)), 30, "touchdowns summed correctly")
	t.assert_eq(int(totals.get("games_played", 0)), 35, "games played summed correctly")
	t.assert_eq(int(totals.get("seasons", 0)), 3, "seasons counted correctly")

func test_get_trajectory_draft_modifier(t) -> void:
	var config := {
		"trajectory_analysis": {
			"rising": {"draft_boost": 0.05},
			"declining": {"draft_penalty": -0.03}
		}
	}

	var rising := {"trend": "rising"}
	var modifier := CollegeStatsService.get_trajectory_draft_modifier(rising, config)
	t.assert_true(abs(modifier - 1.05) < 0.001, "rising trajectory gives +5% boost")

	var declining := {"trend": "declining"}
	modifier = CollegeStatsService.get_trajectory_draft_modifier(declining, config)
	t.assert_true(abs(modifier - 0.97) < 0.001, "declining trajectory gives -3% penalty")

	var stable := {"trend": "stable"}
	modifier = CollegeStatsService.get_trajectory_draft_modifier(stable, config)
	t.assert_true(abs(modifier - 1.0) < 0.001, "stable trajectory is neutral")
