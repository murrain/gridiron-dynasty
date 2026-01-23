extends GdUnitTestSuite
class_name TestAwardSelectorGdUnit4

## GdUnit4 tests for AwardSelector - NFL award selection system
##
## Tests:
##   - Award selection algorithms (OPOY, DPOY, OROY, DROY)
##   - All-Pro team selection (First and Second Team)
##   - Pro Bowl roster selection (AFC/NFC)
##   - Score calculation formulas
##   - Position mapping and categorization
##   - Single-pass ranking optimization

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# TEST HELPERS
# =============================================================================

func _create_player_stats(player_id: String, position: String, stats: Dictionary, is_rookie: bool = false) -> Dictionary:
	return {
		"player_id": player_id,
		"position": position,
		"stats": stats,
		"team_id": "TEAM001",
		"conference": "afc_east",
		"is_rookie": is_rookie
	}


func _create_qb_stats(pass_yards: int, pass_tds: int, interceptions: int = 0, games_played: int = 16) -> Dictionary:
	return {
		"pass_yards": pass_yards,
		"pass_tds": pass_tds,
		"interceptions": interceptions,
		"games_played": games_played
	}


func _create_rb_stats(rush_yards: int, rush_tds: int, receptions: int = 0, rec_yards: int = 0, games_played: int = 16) -> Dictionary:
	return {
		"rush_yards": rush_yards,
		"rush_tds": rush_tds,
		"receptions": receptions,
		"receiving_yards": rec_yards,
		"games_played": games_played
	}


func _create_wr_stats(receptions: int, rec_yards: int, rec_tds: int, games_played: int = 16) -> Dictionary:
	return {
		"receptions": receptions,
		"receiving_yards": rec_yards,
		"receiving_tds": rec_tds,
		"games_played": games_played
	}


func _create_lb_stats(tackles: int, sacks: float, tfl: int, pass_breakups: int = 0, games_played: int = 16) -> Dictionary:
	return {
		"tackles": tackles,
		"sacks": sacks,
		"tackles_for_loss": tfl,
		"pass_breakups": pass_breakups,
		"games_played": games_played
	}


func _create_cb_stats(interceptions: int, pass_breakups: int, tackles: int, games_played: int = 16) -> Dictionary:
	return {
		"interceptions": interceptions,
		"pass_breakups": pass_breakups,
		"tackles": tackles,
		"games_played": games_played
	}


# =============================================================================
# OFFENSIVE PLAYER OF THE YEAR TESTS
# =============================================================================

func test_select_opoy_qb_with_best_stats() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5000, 40, 10)),
		_create_player_stats("QB2", "QB", _create_qb_stats(3500, 25, 15)),
		_create_player_stats("RB1", "RB", _create_rb_stats(1500, 12, 50, 400))
	]

	var result := AwardSelector.select_offensive_player_of_year(year_stats)

	assert_str(result.get("player_id", "")).is_equal("QB1")
	assert_str(result.get("position", "")).is_equal("QB")
	assert_float(result.get("score", 0.0)).is_greater(0.0)


func test_select_opoy_returns_empty_with_no_offensive_players() -> void:
	var year_stats := [
		_create_player_stats("LB1", "LB", _create_lb_stats(100, 10.0, 15))
	]

	var result := AwardSelector.select_offensive_player_of_year(year_stats)

	assert_str(result.get("player_id", "")).is_empty()


func test_opoy_score_calculation_qb() -> void:
	var player := _create_player_stats("QB1", "QB", _create_qb_stats(4800, 36, 8))

	var score := AwardSelector._calculate_offensive_score(player)

	# Score should be positive and significant
	assert_float(score).is_greater(0.0)
	# More TDs should increase score significantly
	var player_more_tds := _create_player_stats("QB2", "QB", _create_qb_stats(4800, 50, 8))
	var score_more_tds := AwardSelector._calculate_offensive_score(player_more_tds)
	assert_float(score_more_tds).is_greater(score)


func test_opoy_rb_vs_qb_scoring() -> void:
	# Elite RB season
	var rb := _create_player_stats("RB1", "RB", _create_rb_stats(2000, 18, 60, 500))
	var rb_score := AwardSelector._calculate_offensive_score(rb)

	# Elite QB season
	var qb := _create_player_stats("QB1", "QB", _create_qb_stats(5000, 40, 10))
	var qb_score := AwardSelector._calculate_offensive_score(qb)

	# Both should have substantial scores
	assert_float(rb_score).is_greater(100.0)
	assert_float(qb_score).is_greater(100.0)


# =============================================================================
# DEFENSIVE PLAYER OF THE YEAR TESTS
# =============================================================================

func test_select_dpoy_best_defensive_player() -> void:
	var year_stats := [
		_create_player_stats("LB1", "LB", _create_lb_stats(150, 15.0, 20, 10)),
		_create_player_stats("LB2", "LB", _create_lb_stats(100, 8.0, 12, 5)),
		_create_player_stats("CB1", "CB", _create_cb_stats(8, 20, 60))
	]

	var result := AwardSelector.select_defensive_player_of_year(year_stats)

	assert_str(result.get("player_id", "")).is_equal("LB1")
	assert_str(result.get("position", "")).is_equal("LB")


func test_select_dpoy_returns_empty_with_no_defensive_players() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(4000, 30, 10))
	]

	var result := AwardSelector.select_defensive_player_of_year(year_stats)

	assert_str(result.get("player_id", "")).is_empty()


func test_dpoy_score_calculation_lb() -> void:
	var player := _create_player_stats("LB1", "LB", _create_lb_stats(120, 12.0, 18, 8))

	var score := AwardSelector._calculate_defensive_score(player)

	assert_float(score).is_greater(0.0)


func test_dpoy_cb_interceptions_increase_score() -> void:
	var cb_few_ints := _create_player_stats("CB1", "CB", _create_cb_stats(3, 15, 50))
	var score_few := AwardSelector._calculate_defensive_score(cb_few_ints)

	var cb_many_ints := _create_player_stats("CB2", "CB", _create_cb_stats(10, 15, 50))
	var score_many := AwardSelector._calculate_defensive_score(cb_many_ints)

	# More interceptions should significantly increase score
	assert_float(score_many).is_greater(score_few)


# =============================================================================
# ROOKIE OF THE YEAR TESTS
# =============================================================================

func test_select_oroy_best_offensive_rookie() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(3500, 25, 12), true),
		_create_player_stats("QB2", "QB", _create_qb_stats(5000, 40, 10), false),  # Not rookie
		_create_player_stats("RB1", "RB", _create_rb_stats(1200, 10, 40, 300), true)
	]

	var result := AwardSelector.select_offensive_rookie_of_year(year_stats)

	assert_str(result.get("player_id", "")).is_equal("QB1")


func test_select_oroy_only_considers_rookies() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5000, 50, 5), false),  # Not rookie, amazing stats
		_create_player_stats("RB1", "RB", _create_rb_stats(800, 6, 20, 150), true)  # Rookie, mediocre stats
	]

	var result := AwardSelector.select_offensive_rookie_of_year(year_stats)

	# Should select the rookie, not the veteran
	assert_str(result.get("player_id", "")).is_equal("RB1")


func test_select_droy_best_defensive_rookie() -> void:
	var year_stats := [
		_create_player_stats("LB1", "LB", _create_lb_stats(100, 10.0, 15, 5), true),
		_create_player_stats("LB2", "LB", _create_lb_stats(150, 20.0, 25, 10), false),  # Not rookie
		_create_player_stats("CB1", "CB", _create_cb_stats(4, 12, 45), true)
	]

	var result := AwardSelector.select_defensive_rookie_of_year(year_stats)

	assert_str(result.get("player_id", "")).is_equal("LB1")


# =============================================================================
# ALL-PRO TEAM SELECTION TESTS
# =============================================================================

func test_select_all_pro_teams_structure() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5000, 40, 10)),
		_create_player_stats("QB2", "QB", _create_qb_stats(4500, 35, 12)),
		_create_player_stats("QB3", "QB", _create_qb_stats(4000, 30, 15)),
		_create_player_stats("RB1", "RB", _create_rb_stats(1800, 15, 50, 400)),
		_create_player_stats("RB2", "RB", _create_rb_stats(1600, 12, 45, 350))
	]

	var result := AwardSelector.select_all_pro_teams(year_stats)

	assert_bool(result.has("first_team")).is_true()
	assert_bool(result.has("second_team")).is_true()


func test_all_pro_first_team_gets_best_players() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5500, 45, 8)),   # Best QB
		_create_player_stats("QB2", "QB", _create_qb_stats(4500, 32, 12)),  # Second best
		_create_player_stats("QB3", "QB", _create_qb_stats(3500, 25, 15))   # Third
	]

	var result := AwardSelector.select_all_pro_teams(year_stats)
	var first_team: Array = result.get("first_team", [])

	# First team should have exactly 1 QB (the best one)
	var first_team_qbs := []
	for player in first_team:
		if player.get("position", "") == "QB":
			first_team_qbs.append(player.get("player_id", ""))

	assert_int(first_team_qbs.size()).is_equal(1)
	assert_str(first_team_qbs[0]).is_equal("QB1")


func test_all_pro_second_team_gets_next_best_players() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5500, 45, 8)),
		_create_player_stats("QB2", "QB", _create_qb_stats(4500, 32, 12))
	]

	var result := AwardSelector.select_all_pro_teams(year_stats)
	var second_team: Array = result.get("second_team", [])

	# Second team should have the second-best QB
	var second_team_qbs := []
	for player in second_team:
		if player.get("position", "") == "QB":
			second_team_qbs.append(player.get("player_id", ""))

	assert_int(second_team_qbs.size()).is_equal(1)
	assert_str(second_team_qbs[0]).is_equal("QB2")


# =============================================================================
# PRO BOWL ROSTER SELECTION TESTS
# =============================================================================

func test_select_pro_bowl_rosters_structure() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5000, 40, 10)),
		_create_player_stats("RB1", "RB", _create_rb_stats(1500, 12, 50, 400))
	]

	# Set conferences
	year_stats[0]["conference"] = "afc_east"
	year_stats[1]["conference"] = "nfc_west"

	var result := AwardSelector.select_pro_bowl_rosters(year_stats)

	assert_bool(result.has("afc")).is_true()
	assert_bool(result.has("nfc")).is_true()


func test_pro_bowl_separates_by_conference() -> void:
	var year_stats := [
		_create_player_stats("QB_AFC", "QB", _create_qb_stats(5000, 40, 10)),
		_create_player_stats("QB_NFC", "QB", _create_qb_stats(4800, 38, 12))
	]

	year_stats[0]["conference"] = "afc_north"
	year_stats[1]["conference"] = "nfc_south"

	var result := AwardSelector.select_pro_bowl_rosters(year_stats)
	var afc_roster: Array = result.get("afc", [])
	var nfc_roster: Array = result.get("nfc", [])

	# AFC should have QB_AFC
	var afc_has_qb := false
	for player in afc_roster:
		if player.get("player_id", "") == "QB_AFC":
			afc_has_qb = true

	# NFC should have QB_NFC
	var nfc_has_qb := false
	for player in nfc_roster:
		if player.get("player_id", "") == "QB_NFC":
			nfc_has_qb = true

	assert_bool(afc_has_qb).is_true()
	assert_bool(nfc_has_qb).is_true()


# =============================================================================
# SINGLE-PASS RANKING OPTIMIZATION TESTS
# =============================================================================

func test_rank_players_once_produces_all_categories() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5000, 40, 10), false),
		_create_player_stats("QB2", "QB", _create_qb_stats(3500, 25, 12), true),
		_create_player_stats("LB1", "LB", _create_lb_stats(120, 12.0, 18, 8), false)
	]

	var ranked := AwardSelector._rank_players_once(year_stats)

	assert_bool(ranked.has("offense_all")).is_true()
	assert_bool(ranked.has("defense_all")).is_true()
	assert_bool(ranked.has("offense_rookies")).is_true()
	assert_bool(ranked.has("defense_rookies")).is_true()
	assert_bool(ranked.has("all_pro_positions")).is_true()
	assert_bool(ranked.has("pro_bowl_afc")).is_true()
	assert_bool(ranked.has("pro_bowl_nfc")).is_true()


func test_rank_players_once_sorts_by_score() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(3000, 20, 15)),  # Low score
		_create_player_stats("QB2", "QB", _create_qb_stats(5500, 45, 5))   # High score
	]

	var ranked := AwardSelector._rank_players_once(year_stats)
	var offense_all: Array = ranked.get("offense_all", [])

	# Best QB should be first
	assert_int(offense_all.size()).is_equal(2)
	assert_str(String(offense_all[0].get("player_id", ""))).is_equal("QB2")
	assert_str(String(offense_all[1].get("player_id", ""))).is_equal("QB1")


func test_optimized_opoy_selection_matches_legacy() -> void:
	var year_stats := [
		_create_player_stats("QB1", "QB", _create_qb_stats(5000, 40, 10)),
		_create_player_stats("RB1", "RB", _create_rb_stats(1800, 15, 50, 400))
	]

	# Legacy method
	var legacy_result := AwardSelector.select_offensive_player_of_year(year_stats)

	# Optimized method
	var ranked := AwardSelector._rank_players_once(year_stats)
	var optimized_result := AwardSelector._select_opoy_from_ranked(ranked)

	# Should produce same winner
	assert_str(optimized_result.get("player_id", "")).is_equal(legacy_result.get("player_id", ""))


# =============================================================================
# POSITION MAPPING TESTS
# =============================================================================

func test_map_to_all_pro_position_offensive() -> void:
	assert_str(AwardSelector._map_to_all_pro_position("QB")).is_equal("QB")
	assert_str(AwardSelector._map_to_all_pro_position("RB")).is_equal("RB")
	assert_str(AwardSelector._map_to_all_pro_position("WR")).is_equal("WR")
	assert_str(AwardSelector._map_to_all_pro_position("TE")).is_equal("TE")
	assert_str(AwardSelector._map_to_all_pro_position("OL")).is_equal("OL")
	assert_str(AwardSelector._map_to_all_pro_position("OT")).is_equal("OL")
	assert_str(AwardSelector._map_to_all_pro_position("OG")).is_equal("OL")
	assert_str(AwardSelector._map_to_all_pro_position("C")).is_equal("OL")


func test_map_to_all_pro_position_defensive() -> void:
	assert_str(AwardSelector._map_to_all_pro_position("DL")).is_equal("DL")
	assert_str(AwardSelector._map_to_all_pro_position("DT")).is_equal("DL")
	assert_str(AwardSelector._map_to_all_pro_position("DE")).is_equal("EDGE")
	assert_str(AwardSelector._map_to_all_pro_position("EDGE")).is_equal("EDGE")
	assert_str(AwardSelector._map_to_all_pro_position("LB")).is_equal("LB")
	assert_str(AwardSelector._map_to_all_pro_position("CB")).is_equal("CB")
	assert_str(AwardSelector._map_to_all_pro_position("S")).is_equal("S")


func test_map_to_all_pro_position_special_teams() -> void:
	assert_str(AwardSelector._map_to_all_pro_position("K")).is_equal("K")
	assert_str(AwardSelector._map_to_all_pro_position("P")).is_equal("P")


func test_map_to_all_pro_position_unknown_returns_empty() -> void:
	assert_str(AwardSelector._map_to_all_pro_position("UNKNOWN")).is_empty()


# =============================================================================
# STATS SUMMARY TESTS
# =============================================================================

func test_summarize_stats_qb() -> void:
	var stats := _create_qb_stats(5000, 40, 12, 16)
	var summary := AwardSelector._summarize_stats(stats, "QB")

	assert_int(summary.get("pass_yards", 0)).is_equal(5000)
	assert_int(summary.get("pass_tds", 0)).is_equal(40)
	assert_int(summary.get("interceptions", 0)).is_equal(12)
	assert_int(summary.get("games_played", 0)).is_equal(16)


func test_summarize_stats_rb() -> void:
	var stats := _create_rb_stats(1500, 12, 50, 400, 16)
	var summary := AwardSelector._summarize_stats(stats, "RB")

	assert_int(summary.get("rush_yards", 0)).is_equal(1500)
	assert_int(summary.get("rush_tds", 0)).is_equal(12)
	assert_int(summary.get("receptions", 0)).is_equal(50)


func test_summarize_stats_lb() -> void:
	var stats := _create_lb_stats(120, 12.0, 18, 8, 16)
	var summary := AwardSelector._summarize_stats(stats, "LB")

	assert_int(summary.get("tackles", 0)).is_equal(120)
	assert_float(summary.get("sacks", 0.0)).is_equal(12.0)
	assert_int(summary.get("pass_breakups", 0)).is_equal(8)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_awards_with_empty_year_stats() -> void:
	var year_stats := []

	var opoy := AwardSelector.select_offensive_player_of_year(year_stats)
	var dpoy := AwardSelector.select_defensive_player_of_year(year_stats)

	assert_str(opoy.get("player_id", "")).is_empty()
	assert_str(dpoy.get("player_id", "")).is_empty()


func test_awards_with_incomplete_stats() -> void:
	var player := _create_player_stats("QB1", "QB", {"games_played": 16})

	var score := AwardSelector._calculate_offensive_score(player)

	# Should handle missing stats gracefully
	assert_float(score).is_greater_equal(0.0)
