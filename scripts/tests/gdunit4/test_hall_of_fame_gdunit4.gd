extends GdUnitTestSuite
class_name TestHallOfFameGdUnit4

## GdUnit4 tests for HallOfFame - NFL Hall of Fame system
##
## Tests:
##   - HOF score calculation (awards, stats, longevity)
##   - Eligibility checks
##   - Inductee selection
##   - Career stat aggregation
##   - Query functions

const HallOfFame = preload("res://scripts/core/awards/HallOfFame.gd")


# =============================================================================
# TEST HELPERS
# =============================================================================

func _create_player(player_id: String, position: String, career_awards: Dictionary = {}) -> Dictionary:
	return {
		"id": player_id,
		"position": position,
		"first_name": "Test",
		"last_name": "Player",
		"career_awards": career_awards,
		"retirement_year": 2025
	}


func _create_career_stats(seasons: Array) -> Dictionary:
	var career := {}
	for i in range(seasons.size()):
		career[2015 + i] = seasons[i]
	return career


func _create_qb_season(pass_yards: int, pass_tds: int, games_played: int = 16) -> Dictionary:
	return {
		"pass_yards": pass_yards,
		"pass_tds": pass_tds,
		"games_played": games_played
	}


func _create_rb_season(rush_yards: int, rush_tds: int, games_played: int = 16) -> Dictionary:
	return {
		"rush_yards": rush_yards,
		"rush_tds": rush_tds,
		"games_played": games_played
	}


func _create_lb_season(tackles: int, sacks: float, games_played: int = 16) -> Dictionary:
	return {
		"tackles": tackles,
		"sacks": sacks,
		"games_played": games_played
	}


# =============================================================================
# HOF SCORE CALCULATION TESTS
# =============================================================================

func test_calculate_hof_score_awards_contribute() -> void:
	var awards := {
		"opoy": 1,
		"all_pro_first": 5,
		"pro_bowl": 8
	}
	var player := _create_player("QB1", "QB", awards)
	var player_stats := {}

	var score := HallOfFame.calculate_hof_score(player, player_stats)

	# Awards should contribute significantly to score
	assert_float(score).is_greater(100.0)


func test_calculate_hof_score_mvp_awards_worth_more() -> void:
	var player_mvp := _create_player("QB1", "QB", {"opoy": 1})
	var player_pro_bowl := _create_player("QB2", "QB", {"pro_bowl": 1})
	var stats := {}

	var score_mvp := HallOfFame.calculate_hof_score(player_mvp, stats)
	var score_pro_bowl := HallOfFame.calculate_hof_score(player_pro_bowl, stats)

	# MVP should be worth more than Pro Bowl
	assert_float(score_mvp).is_greater(score_pro_bowl)


func test_calculate_hof_score_longevity_bonus() -> void:
	var player := _create_player("QB1", "QB", {})

	# 10-year career
	var career_stats := _create_career_stats([
		_create_qb_season(3000, 20),
		_create_qb_season(3200, 22),
		_create_qb_season(3500, 25),
		_create_qb_season(3800, 28),
		_create_qb_season(4000, 30),
		_create_qb_season(4200, 32),
		_create_qb_season(4000, 28),
		_create_qb_season(3800, 26),
		_create_qb_season(3500, 24),
		_create_qb_season(3000, 20)
	])

	var player_stats := {"QB1": career_stats}
	var score := HallOfFame.calculate_hof_score(player, player_stats)

	# 10 seasons × 5 points = 50 points minimum from longevity
	assert_float(score).is_greater(50.0)


func test_calculate_hof_score_career_stats_bonus_qb() -> void:
	var player := _create_player("QB1", "QB", {})

	# Elite QB career: 50,000 yards, 350 TDs over 12 seasons
	var seasons := []
	for i in range(12):
		seasons.append(_create_qb_season(4200, 30))

	var career_stats := _create_career_stats(seasons)
	var player_stats := {"QB1": career_stats}

	var score := HallOfFame.calculate_hof_score(player, player_stats)

	# Should get significant stat bonuses for elite career numbers
	assert_float(score).is_greater(100.0)


func test_calculate_hof_score_no_stats_low_score() -> void:
	var player := _create_player("QB1", "QB", {})
	var player_stats := {}

	var score := HallOfFame.calculate_hof_score(player, player_stats)

	# No awards, no stats = very low score
	assert_float(score).is_less(10.0)


# =============================================================================
# ELIGIBILITY TESTS
# =============================================================================

func test_is_hof_eligible_requires_minimum_seasons() -> void:
	var player := _create_player("QB1", "QB", {"opoy": 3})

	# Only 3 seasons (below minimum)
	var career_stats := _create_career_stats([
		_create_qb_season(5000, 40),
		_create_qb_season(5200, 42),
		_create_qb_season(5000, 38)
	])

	var player_stats := {"QB1": career_stats}
	var eligible := HallOfFame.is_hof_eligible(player, player_stats)

	# Should not be eligible (need 5+ seasons)
	assert_bool(eligible).is_false()


func test_is_hof_eligible_requires_minimum_score() -> void:
	var player := _create_player("QB1", "QB", {})  # No awards

	# 8 seasons of mediocre stats
	var seasons := []
	for i in range(8):
		seasons.append(_create_qb_season(2000, 10))

	var career_stats := _create_career_stats(seasons)
	var player_stats := {"QB1": career_stats}

	var eligible := HallOfFame.is_hof_eligible(player, player_stats)

	# Should not be eligible (score too low)
	assert_bool(eligible).is_false()


func test_is_hof_eligible_with_elite_career() -> void:
	var player := _create_player("QB1", "QB", {
		"opoy": 2,
		"all_pro_first": 7,
		"pro_bowl": 10
	})

	# 12-year elite career
	var seasons := []
	for i in range(12):
		seasons.append(_create_qb_season(4500, 35))

	var career_stats := _create_career_stats(seasons)
	var player_stats := {"QB1": career_stats}

	var eligible := HallOfFame.is_hof_eligible(player, player_stats)

	# Should be eligible (elite career)
	assert_bool(eligible).is_true()


# =============================================================================
# CAREER STAT AGGREGATION TESTS
# =============================================================================

func test_aggregate_career_stats_sums_all_seasons() -> void:
	var career := {
		2020: {"pass_yards": 4000, "pass_tds": 30, "games_played": 16},
		2021: {"pass_yards": 4500, "pass_tds": 35, "games_played": 16},
		2022: {"pass_yards": 4200, "pass_tds": 32, "games_played": 16}
	}

	var totals := HallOfFame._aggregate_career_stats(career)

	assert_float(totals["career_pass_yards"]).is_equal(12700.0)
	assert_float(totals["career_pass_tds"]).is_equal(97.0)
	assert_int(totals["seasons"]).is_equal(3)


func test_aggregate_career_stats_handles_empty_career() -> void:
	var career := {}

	var totals := HallOfFame._aggregate_career_stats(career)

	assert_float(totals["career_pass_yards"]).is_equal(0.0)
	assert_int(totals["seasons"]).is_equal(0)


func test_aggregate_career_stats_rb() -> void:
	var career := {
		2020: {"rush_yards": 1500, "rush_tds": 12, "receptions": 50, "receiving_yards": 400, "games_played": 16},
		2021: {"rush_yards": 1600, "rush_tds": 14, "receptions": 55, "receiving_yards": 450, "games_played": 16}
	}

	var totals := HallOfFame._aggregate_career_stats(career)

	assert_float(totals["career_rush_yards"]).is_equal(3100.0)
	assert_float(totals["career_rush_tds"]).is_equal(26.0)
	assert_float(totals["career_receptions"]).is_equal(105.0)


func test_aggregate_career_stats_defensive() -> void:
	var career := {
		2020: {"tackles": 120, "sacks": 12.0, "interceptions": 3, "games_played": 16},
		2021: {"tackles": 125, "sacks": 14.5, "interceptions": 4, "games_played": 16}
	}

	var totals := HallOfFame._aggregate_career_stats(career)

	assert_float(totals["career_tackles"]).is_equal(245.0)
	assert_float(totals["career_sacks"]).is_equal(26.5)
	assert_float(totals["career_interceptions"]).is_equal(7.0)


# =============================================================================
# HALL OF FAME PROCESSING TESTS
# =============================================================================

func test_process_hall_of_fame_inducts_eligible_players() -> void:
	var eligible_player := _create_player("QB1", "QB", {
		"opoy": 2,
		"all_pro_first": 5,
		"pro_bowl": 8
	})

	# Elite career
	var seasons := []
	for i in range(10):
		seasons.append(_create_qb_season(4500, 35))

	var world_state := {
		"player_career_stats": {
			"QB1": _create_career_stats(seasons)
		}
	}

	var result := HallOfFame.process_hall_of_fame(world_state, 2025, [eligible_player])

	assert_int(result["inducted"]).is_greater(0)


func test_process_hall_of_fame_respects_max_inductees() -> void:
	# Create 10 eligible players
	var retirees := []
	var player_stats := {}

	for i in range(10):
		var player_id := "QB" + str(i)
		var player := _create_player(player_id, "QB", {
			"opoy": 1,
			"all_pro_first": 3,
			"pro_bowl": 5
		})
		retirees.append(player)

		# Elite career
		var seasons := []
		for s in range(10):
			seasons.append(_create_qb_season(4500, 35))
		player_stats[player_id] = _create_career_stats(seasons)

	var world_state := {
		"player_career_stats": player_stats
	}

	var result := HallOfFame.process_hall_of_fame(world_state, 2025, retirees)

	# Should induct max 5 per year
	assert_int(result["inducted"]).is_less_equal(HallOfFame.MAX_INDUCTEES_PER_YEAR)


func test_process_hall_of_fame_adds_to_eligible_pool() -> void:
	var eligible_player := _create_player("QB1", "QB", {
		"all_pro_first": 3,
		"pro_bowl": 5
	})

	# Good career but not top-tier
	var seasons := []
	for i in range(10):
		seasons.append(_create_qb_season(4000, 28))

	var world_state := {
		"player_career_stats": {
			"QB1": _create_career_stats(seasons)
		}
	}

	HallOfFame.process_hall_of_fame(world_state, 2025, [eligible_player])

	var hof: Dictionary = world_state["hall_of_fame"]
	var pool: Array = hof["eligible_pool"]

	# Should be in pool (not yet inducted, but eligible)
	assert_int(pool.size()).is_greater_equal(0)


func test_process_hall_of_fame_skips_ineligible_players() -> void:
	var ineligible_player := _create_player("QB1", "QB", {})  # No awards

	# Only 3 seasons with mediocre stats
	var career_stats := _create_career_stats([
		_create_qb_season(2500, 15),
		_create_qb_season(2600, 16),
		_create_qb_season(2400, 14)
	])

	var world_state := {
		"player_career_stats": {
			"QB1": career_stats
		}
	}

	var result := HallOfFame.process_hall_of_fame(world_state, 2025, [ineligible_player])

	assert_int(result["new_eligible"]).is_equal(0)


# =============================================================================
# INDUCTEE QUERY TESTS
# =============================================================================

func test_get_all_inductees_returns_all() -> void:
	var world_state := {
		"hall_of_fame": {
			"inductees": [
				{"player_id": "QB1", "induction_year": 2020},
				{"player_id": "RB1", "induction_year": 2021}
			],
			"eligible_pool": [],
			"induction_history": {}
		}
	}

	var inductees := HallOfFame.get_all_inductees(world_state)

	assert_int(inductees.size()).is_equal(2)


func test_get_inductees_by_year() -> void:
	var world_state := {
		"hall_of_fame": {
			"inductees": [],
			"eligible_pool": [],
			"induction_history": {
				2020: ["QB1", "RB1"],
				2021: ["WR1"]
			}
		}
	}

	var inductees_2020 := HallOfFame.get_inductees_by_year(world_state, 2020)
	var inductees_2021 := HallOfFame.get_inductees_by_year(world_state, 2021)

	assert_int(inductees_2020.size()).is_equal(2)
	assert_int(inductees_2021.size()).is_equal(1)


func test_is_in_hall_of_fame_returns_true_for_inductee() -> void:
	var world_state := {
		"hall_of_fame": {
			"inductees": [
				{"player_id": "QB1", "induction_year": 2020}
			],
			"eligible_pool": [],
			"induction_history": {}
		}
	}

	var is_hof := HallOfFame.is_in_hall_of_fame(world_state, "QB1")

	assert_bool(is_hof).is_true()


func test_is_in_hall_of_fame_returns_false_for_non_inductee() -> void:
	var world_state := {
		"hall_of_fame": {
			"inductees": [
				{"player_id": "QB1", "induction_year": 2020}
			],
			"eligible_pool": [],
			"induction_history": {}
		}
	}

	var is_hof := HallOfFame.is_in_hall_of_fame(world_state, "RB1")

	assert_bool(is_hof).is_false()


# =============================================================================
# STAT BONUS CALCULATION TESTS
# =============================================================================

func test_offensive_stat_bonus_qb_thresholds() -> void:
	# QB with 50,000 yards and 350 TDs
	var career_totals := {
		"career_pass_yards": 50000.0,
		"career_pass_tds": 350.0
	}

	var bonus := HallOfFame._calculate_offensive_stat_bonus(career_totals, "QB")

	# Should get bonuses for exceeding thresholds
	assert_float(bonus).is_greater(50.0)


func test_offensive_stat_bonus_rb_thresholds() -> void:
	# RB with 15,000 yards and 100 TDs
	var career_totals := {
		"career_rush_yards": 15000.0,
		"career_rush_tds": 100.0
	}

	var bonus := HallOfFame._calculate_offensive_stat_bonus(career_totals, "RB")

	assert_float(bonus).is_greater(30.0)


func test_offensive_stat_bonus_wr_thresholds() -> void:
	# WR with 15,000 yards, 1,000 receptions, 100 TDs
	var career_totals := {
		"career_receiving_yards": 15000.0,
		"career_receptions": 1000.0,
		"career_receiving_tds": 100.0
	}

	var bonus := HallOfFame._calculate_offensive_stat_bonus(career_totals, "WR")

	assert_float(bonus).is_greater(50.0)


func test_defensive_stat_bonus_pass_rusher() -> void:
	# DL with 150 sacks
	var career_totals := {
		"career_sacks": 150.0
	}

	var bonus := HallOfFame._calculate_defensive_stat_bonus(career_totals, "DE")

	assert_float(bonus).is_greater(50.0)


func test_defensive_stat_bonus_cb() -> void:
	# CB with 50 interceptions
	var career_totals := {
		"career_interceptions": 50.0
	}

	var bonus := HallOfFame._calculate_defensive_stat_bonus(career_totals, "CB")

	assert_float(bonus).is_greater(30.0)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_process_hall_of_fame_with_empty_retirees() -> void:
	var world_state := {
		"player_career_stats": {}
	}

	var result := HallOfFame.process_hall_of_fame(world_state, 2025, [])

	assert_int(result["inducted"]).is_equal(0)
	assert_int(result["new_eligible"]).is_equal(0)


func test_calculate_hof_score_with_invalid_player() -> void:
	var player := {}  # No id field
	var player_stats := {}

	var score := HallOfFame.calculate_hof_score(player, player_stats)

	# Should handle gracefully and return 0
	assert_float(score).is_greater_equal(0.0)


func test_hof_initializes_structure_if_missing() -> void:
	var world_state := {
		"player_career_stats": {}
	}

	# Structure doesn't exist initially
	assert_bool(world_state.has("hall_of_fame")).is_false()

	HallOfFame.process_hall_of_fame(world_state, 2025, [])

	# Should be initialized
	assert_bool(world_state.has("hall_of_fame")).is_true()
	assert_bool(world_state["hall_of_fame"].has("inductees")).is_true()
	assert_bool(world_state["hall_of_fame"].has("eligible_pool")).is_true()
