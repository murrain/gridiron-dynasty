extends RefCounted

const CollegeAwardsService = preload("res://scripts/world/CollegeAwardsService.gd")

func run(t) -> void:
	test_select_heisman_trophy(t)
	test_select_all_americans(t)
	test_select_conference_awards(t)
	test_generate_mock_draft_rankings(t)
	test_hype_vs_talent_gap(t)

func test_select_heisman_trophy(t) -> void:
	var eligible_players := [
		{"player_id": "qb_001", "position": "QB", "college_id": "ohio_state", "hype": 85.0},
		{"player_id": "rb_001", "position": "RB", "college_id": "alabama", "hype": 75.0},
		{"player_id": "wr_001", "position": "WR", "college_id": "lsu", "hype": 70.0},
		{"player_id": "ol_001", "position": "OL", "college_id": "michigan", "hype": 60.0}  # Not eligible
	]

	var career_stats := {
		"qb_001": {2024: {"games_played": 12, "passing_yards": 4000, "touchdown_passes": 40, "interceptions": 5, "attempts": 400, "completions": 280}},
		"rb_001": {2024: {"games_played": 12, "rushing_yards": 1800, "rushing_touchdowns": 18}},
		"wr_001": {2024: {"games_played": 12, "receiving_yards": 1400, "receiving_touchdowns": 12, "receptions": 90}},
		"ol_001": {2024: {"games_played": 12, "games_started": 12}}
	}

	var season_records := {
		"ohio_state": {"wins": 12, "losses": 0, "is_champion": true},
		"alabama": {"wins": 11, "losses": 1},
		"lsu": {"wins": 10, "losses": 2},
		"michigan": {"wins": 9, "losses": 3}
	}

	var college_index := {
		"ohio_state": {"id": "ohio_state", "conference": "big_ten"},
		"alabama": {"id": "alabama", "conference": "sec"},
		"lsu": {"id": "lsu", "conference": "sec"},
		"michigan": {"id": "michigan", "conference": "big_ten"}
	}

	var config := {
		"heisman": {
			"eligible_positions": ["QB", "RB", "WR"],
			"finalist_count": 4,
			"min_games_played": 10,
			"voting_weights": {
				"stats_production": 0.4,
				"efficiency_metrics": 0.25,
				"team_success": 0.2,
				"hype": 0.15
			},
			"position_bias": {"QB": 1.1, "RB": 1.0, "WR": 0.95}
		}
	}

	var result := CollegeAwardsService.select_heisman_trophy(
		eligible_players, career_stats, season_records, college_index, 2024, config
	)

	t.assert_true(result.has("winner"), "result has winner")
	t.assert_true(result.has("finalists"), "result has finalists")

	var winner: Dictionary = result.get("winner", {})
	t.assert_true(not winner.is_empty(), "winner is not empty")
	t.assert_true(winner.get("position") in ["QB", "RB", "WR"], "winner is Heisman-eligible position")

	var finalists: Array = result.get("finalists", [])
	t.assert_true(finalists.size() <= 4, "at most 4 finalists")

func test_select_all_americans(t) -> void:
	var eligible_players := [
		{"player_id": "qb_001", "position": "QB", "college_id": "school_a"},
		{"player_id": "qb_002", "position": "QB", "college_id": "school_b"},
		{"player_id": "rb_001", "position": "RB", "college_id": "school_c"},
		{"player_id": "rb_002", "position": "RB", "college_id": "school_d"}
	]

	var career_stats := {
		"qb_001": {2024: {"games_started": 12, "passing_yards": 4000, "touchdown_passes": 35, "interceptions": 6, "attempts": 400, "completions": 270}},
		"qb_002": {2024: {"games_started": 12, "passing_yards": 3500, "touchdown_passes": 30, "interceptions": 8, "attempts": 380, "completions": 240}},
		"rb_001": {2024: {"games_started": 12, "rushing_yards": 1500, "rushing_touchdowns": 14}},
		"rb_002": {2024: {"games_started": 12, "rushing_yards": 1200, "rushing_touchdowns": 10}}
	}

	var config := {
		"all_american": {
			"positions": {"QB": 1, "RB": 1},
			"min_games_started": 8
		}
	}

	var result := CollegeAwardsService.select_all_americans(
		eligible_players, career_stats, 2024, config
	)

	t.assert_true(result.has("first_team"), "result has first_team")
	t.assert_true(result.has("second_team"), "result has second_team")
	t.assert_true(result.has("third_team"), "result has third_team")

func test_select_conference_awards(t) -> void:
	var eligible_players := [
		{"player_id": "qb_001", "position": "QB", "college_id": "ohio_state"},
		{"player_id": "de_001", "position": "DE", "college_id": "michigan"}
	]

	var career_stats := {
		"qb_001": {2024: {"games_played": 12, "passing_yards": 3500, "touchdown_passes": 30}},
		"de_001": {2024: {"games_played": 12, "sacks": 12, "tackles": 45}}
	}

	var season_records := {}

	var college_index := {
		"ohio_state": {"id": "ohio_state", "conference": "big_ten"},
		"michigan": {"id": "michigan", "conference": "big_ten"}
	}

	var config := {
		"conference_awards": {
			"voting_weights": {
				"stats_production": 0.5,
				"efficiency_metrics": 0.3,
				"team_contribution": 0.2
			}
		}
	}

	var result := CollegeAwardsService.select_conference_awards(
		eligible_players, career_stats, season_records, college_index, 2024, config
	)

	t.assert_true(result.has("big_ten"), "result has big_ten conference")
	var big_ten: Dictionary = result.get("big_ten", {})
	t.assert_true(big_ten.has("offensive_poy"), "big_ten has offensive_poy")
	t.assert_true(big_ten.has("defensive_poy"), "big_ten has defensive_poy")

func test_generate_mock_draft_rankings(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var draft_pool := [
		{"player_id": "p1", "position": "QB", "college_id": "school_a", "hype": 90.0, "stats": {"speed": 85, "arm": 90}},
		{"player_id": "p2", "position": "RB", "college_id": "school_b", "hype": 75.0, "stats": {"speed": 92, "power": 80}},
		{"player_id": "p3", "position": "WR", "college_id": "school_c", "hype": 60.0, "stats": {"speed": 95, "hands": 88}}
	]

	var config := {
		"mock_draft": {
			"sources": ["espn", "nfl_network", "pff"],
			"top_n_players": 10,
			"noise_sigma": 5.0,
			"hype_susceptibility_by_source": {
				"espn": 0.8,
				"nfl_network": 0.5,
				"pff": 0.2
			},
			"source_bias": {
				"espn": {"flashy_positions": ["QB", "WR"]},
				"nfl_network": {},
				"pff": {}
			}
		}
	}

	var positions_cfg := {}
	var main_cfg := {"class_rules": {}}

	var result := CollegeAwardsService.generate_mock_draft_rankings(
		draft_pool, config, rng, positions_cfg, main_cfg
	)

	t.assert_true(result.has("source_rankings"), "result has source_rankings")
	t.assert_true(result.has("consensus"), "result has consensus")

	var source_rankings: Dictionary = result.get("source_rankings", {})
	t.assert_true(source_rankings.has("espn"), "has ESPN rankings")
	t.assert_true(source_rankings.has("pff"), "has PFF rankings")

func test_hype_vs_talent_gap(t) -> void:
	var player := {
		"player_id": "overhyped",
		"stats": {"speed": 70, "strength": 65}  # Average talent
	}

	var mock_rankings := {
		"consensus": [
			{"player_id": "overhyped", "rank": 5}  # Ranked high despite average talent
		]
	}

	var gap := CollegeAwardsService.calculate_hype_vs_talent_gap(
		player, mock_rankings, {}, {"class_rules": {}}
	)

	# Gap should be positive (overhyped) or calculation should complete without error
	t.assert_true(gap >= -1.0 and gap <= 1.0, "gap is in valid range -1 to 1")

	# Player not in rankings
	var unranked_player := {"player_id": "unknown", "stats": {}}
	gap = CollegeAwardsService.calculate_hype_vs_talent_gap(
		unranked_player, mock_rankings, {}, {"class_rules": {}}
	)
	t.assert_eq(gap, 0.0, "unranked player has 0 gap")
