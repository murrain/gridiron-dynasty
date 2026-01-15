## GdUnit4 test suite for PA6.1: Player Satisfaction from Playing Time and Awards
##
## Validates that player satisfaction is calculated correctly based on:
##   - Playing time (games_started vs games_played)
##   - Individual awards (OPOY, DPOY, All-Pro, Pro Bowl, Rookie awards)
##   - Team success (championships, playoffs, winning records)
extends GdUnitTestSuite

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")


func test_satisfaction_from_playing_time_starter() -> void:
	var player := {"player_id": "player_001"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 10
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 6, "losses": 6}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_equal(47.0)
	assert_float(satisfaction).is_less(50.0)


func test_satisfaction_from_playing_time_backup() -> void:
	var player := {"player_id": "player_002"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 5
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 6, "losses": 6}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(40.0)
	assert_float(satisfaction).is_less_equal(60.0)


func test_satisfaction_from_playing_time_rarely_plays() -> void:
	var player := {"player_id": "player_003"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 8,
			"games_started": 2
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 6, "losses": 6}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_less(50.0)


func test_satisfaction_from_awards_opoy() -> void:
	var player := {"player_id": "player_004"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 16,
			"games_started": 16
		}
	}
	var awards := {
		"awards": {
			"2025": {
				"opoy": {"player_id": "player_004"}
			}
		},
		"all_pro_teams": {},
		"pro_bowl_rosters": {}
	}
	var team_record := {"wins": 8, "losses": 8}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(54.0)


func test_satisfaction_from_awards_all_pro() -> void:
	var player := {"player_id": "player_005"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 16,
			"games_started": 16
		}
	}
	var awards := {
		"awards": {},
		"all_pro_teams": {
			"2025": {
				"first_team": [
					{"player_id": "player_005", "position": "QB"}
				],
				"second_team": []
			}
		},
		"pro_bowl_rosters": {}
	}
	var team_record := {"wins": 8, "losses": 8}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(52.0)


func test_satisfaction_from_awards_pro_bowl() -> void:
	var player := {"player_id": "player_006"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 16,
			"games_started": 16
		}
	}
	var awards := {
		"awards": {},
		"all_pro_teams": {},
		"pro_bowl_rosters": {
			"2025": {
				"afc": [
					{"player_id": "player_006", "position": "RB"}
				],
				"nfc": []
			}
		}
	}
	var team_record := {"wins": 8, "losses": 8}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(49.0)


func test_satisfaction_from_team_success_champion() -> void:
	var player := {"player_id": "player_007"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 10
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 12, "losses": 0, "is_champion": true, "playoff_appearance": true}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(54.0)


func test_satisfaction_from_team_success_playoff() -> void:
	var player := {"player_id": "player_008"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 10
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 10, "losses": 2, "is_champion": false, "playoff_appearance": true}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(51.0)


func test_satisfaction_from_team_success_losing_record() -> void:
	var player := {"player_id": "player_009"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 10
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 3, "losses": 9, "is_champion": false, "playoff_appearance": false}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_less_equal(50.0)


func test_satisfaction_weighted_combination() -> void:
	var player := {"player_id": "player_010"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 12
		}
	}
	var awards := {
		"awards": {
			"2025": {
				"opoy": {"player_id": "player_010"}
			}
		},
		"all_pro_teams": {
			"2025": {
				"first_team": [
					{"player_id": "player_010", "position": "QB"}
				],
				"second_team": []
			}
		},
		"pro_bowl_rosters": {}
	}
	var team_record := {"wins": 12, "losses": 0, "is_champion": true, "playoff_appearance": true}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_greater_equal(65.0)


func test_satisfaction_no_stats_returns_neutral() -> void:
	var player := {"player_id": "player_011"}
	var year := 2025
	var player_stats := {}  # No stats for this year
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 10, "losses": 2}

	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	assert_float(satisfaction).is_equal(50.0)
