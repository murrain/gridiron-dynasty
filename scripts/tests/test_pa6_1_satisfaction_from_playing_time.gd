extends RefCounted

## Test PA6.1: Player Satisfaction from Playing Time and Awards
##
## Validates that player satisfaction is calculated correctly based on:
##   - Playing time (games_started vs games_played)
##   - Individual awards (OPOY, DPOY, All-Pro, Pro Bowl, Rookie awards)
##   - Team success (championships, playoffs, winning records)

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")

func run(t) -> void:
	_test_satisfaction_from_playing_time_starter(t)
	_test_satisfaction_from_playing_time_backup(t)
	_test_satisfaction_from_playing_time_rarely_plays(t)
	_test_satisfaction_from_awards_opoy(t)
	_test_satisfaction_from_awards_all_pro(t)
	_test_satisfaction_from_awards_pro_bowl(t)
	_test_satisfaction_from_team_success_champion(t)
	_test_satisfaction_from_team_success_playoff(t)
	_test_satisfaction_from_team_success_losing_record(t)
	_test_satisfaction_weighted_combination(t)
	_test_satisfaction_no_stats_returns_neutral(t)


func _test_satisfaction_from_playing_time_starter(t) -> void:
	# Arrange: Starter with 12 games played, 10 games started (college)
	var player := {"player_id": "player_001"}
	var year := 2025
	var player_stats := {
		"2025": {
			"games_played": 12,
			"games_started": 10
		}
	}
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 6, "losses": 6}  # Neutral record

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Starter should have below-neutral satisfaction with neutral team
	# Base 50 + 20 (starter) + 10 (full participation) = 80 * 0.4 (weight) = 32
	# Team neutral (50) * 0.3 = 15
	# Awards (0) * 0.3 = 0
	# Total = 47
	# Note: Starter on neutral team with no awards is slightly below neutral overall
	t.assert_eq(satisfaction, 47.0, "Starter on neutral team should have 47 satisfaction (got %.1f)" % satisfaction)
	t.assert_true(satisfaction < 50.0, "Starter on neutral team is slightly below neutral overall (got %.1f)" % satisfaction)


func _test_satisfaction_from_playing_time_backup(t) -> void:
	# Arrange: Backup with 12 games played, 5 games started
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Backup should have slightly above-neutral satisfaction
	# Playing time: 50 + 10 (backup) + 10 (full participation) = 70 * 0.4 = 28
	# Team: 50 * 0.3 = 15
	# Awards: 0 * 0.3 = 0
	# Total = 43
	t.assert_true(satisfaction >= 40.0, "Regular backup should have satisfaction >= 40 (got %.1f)" % satisfaction)
	t.assert_true(satisfaction <= 60.0, "Regular backup should have satisfaction <= 60 (got %.1f)" % satisfaction)


func _test_satisfaction_from_playing_time_rarely_plays(t) -> void:
	# Arrange: Rarely plays - 8 games played, 2 games started
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Rarely plays should have below-neutral satisfaction
	# Playing time: 50 - 10 (rarely plays) + 6.67 (8/12 participation) = 46.67 * 0.4 = 18.67
	# Team: 50 * 0.3 = 15
	# Awards: 0 * 0.3 = 0
	# Total ≈ 33.67
	t.assert_true(satisfaction < 50.0, "Rarely plays should have below-neutral satisfaction (got %.1f)" % satisfaction)


func _test_satisfaction_from_awards_opoy(t) -> void:
	# Arrange: Player wins OPOY
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: OPOY winner should have very high satisfaction
	# Playing time: 80 * 0.4 = 32
	# Awards: 25 (OPOY) * 0.3 = 7.5
	# Team: 50 * 0.3 = 15
	# Total ≈ 54.5
	t.assert_true(satisfaction >= 54.0, "OPOY winner should have satisfaction >= 54 (got %.1f)" % satisfaction)


func _test_satisfaction_from_awards_all_pro(t) -> void:
	# Arrange: Player makes All-Pro First Team
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: All-Pro First Team should boost satisfaction
	# Playing time: 80 * 0.4 = 32
	# Awards: 20 (All-Pro First) * 0.3 = 6
	# Team: 50 * 0.3 = 15
	# Total ≈ 53
	t.assert_true(satisfaction >= 52.0, "All-Pro First Team should have satisfaction >= 52 (got %.1f)" % satisfaction)


func _test_satisfaction_from_awards_pro_bowl(t) -> void:
	# Arrange: Player makes Pro Bowl
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Pro Bowl should give modest boost
	# Playing time: 80 * 0.4 = 32
	# Awards: 10 (Pro Bowl) * 0.3 = 3
	# Team: 50 * 0.3 = 15
	# Total ≈ 50
	t.assert_true(satisfaction >= 49.0, "Pro Bowl selection should have satisfaction >= 49 (got %.1f)" % satisfaction)


func _test_satisfaction_from_team_success_champion(t) -> void:
	# Arrange: Player on championship team
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Championship should significantly boost satisfaction
	# Playing time: 80 * 0.4 = 32
	# Awards: 0 * 0.3 = 0
	# Team: (50 + 20 (champion) + 5 (winning record)) = 75 * 0.3 = 22.5
	# Total ≈ 54.5
	t.assert_true(satisfaction >= 54.0, "Champion should have satisfaction >= 54 (got %.1f)" % satisfaction)


func _test_satisfaction_from_team_success_playoff(t) -> void:
	# Arrange: Player on playoff team (not champion)
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Playoff team should have above-neutral satisfaction
	# Playing time: 80 * 0.4 = 32
	# Team: (50 + 10 (playoff) + 5 (winning record)) = 65 * 0.3 = 19.5
	# Total ≈ 51.5
	t.assert_true(satisfaction >= 51.0, "Playoff team should have satisfaction >= 51 (got %.1f)" % satisfaction)


func _test_satisfaction_from_team_success_losing_record(t) -> void:
	# Arrange: Player on losing team
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Losing team should reduce satisfaction
	# Playing time: 80 * 0.4 = 32
	# Team: (50 - 5 (losing record)) = 45 * 0.3 = 13.5
	# Total ≈ 45.5
	t.assert_true(satisfaction <= 50.0, "Losing team should have satisfaction <= 50 (got %.1f)" % satisfaction)


func _test_satisfaction_weighted_combination(t) -> void:
	# Arrange: Elite player on championship team with awards
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

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: Elite player should have very high satisfaction (70+)
	# Playing time: 80 * 0.4 = 32
	# Awards: (25 OPOY + 20 All-Pro) = 45, capped at 100, * 0.3 = 13.5
	# Team: 75 * 0.3 = 22.5
	# Total ≈ 68
	t.assert_true(satisfaction >= 65.0, "Elite player with all bonuses should have satisfaction >= 65 (got %.1f)" % satisfaction)


func _test_satisfaction_no_stats_returns_neutral(t) -> void:
	# Arrange: Player with no stats (injured or redshirted)
	var player := {"player_id": "player_011"}
	var year := 2025
	var player_stats := {}  # No stats for this year
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := {"wins": 10, "losses": 2}

	# Act
	var satisfaction := PlayerMorale.calculate_satisfaction(player, year, player_stats, awards, team_record)

	# Assert: No stats should return neutral satisfaction (50.0)
	t.assert_eq(satisfaction, 50.0, "Player with no stats should have neutral satisfaction")
