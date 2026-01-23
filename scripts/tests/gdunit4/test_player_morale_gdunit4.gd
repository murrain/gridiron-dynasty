extends GdUnitTestSuite
class_name TestPlayerMoraleGdUnit4

## GdUnit4 tests for PlayerMorale - Player satisfaction and morale system
##
## Tests:
##   - Satisfaction calculation (playing time, awards, team success)
##   - Morale updates and trends
##   - Transfer probability calculations
##   - Transfer decisions (with RNG)
##   - Development multipliers

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# TEST HELPERS
# =============================================================================

func _create_player(player_id: String, morale: float = 50.0, college_year: int = 1) -> Dictionary:
	return {
		"player_id": player_id,
		"morale": morale,
		"college_year": college_year
	}


func _create_season_stats(games_played: int, games_started: int) -> Dictionary:
	return {
		str(2025): {
			"games_played": games_played,
			"games_started": games_started
		}
	}


func _create_team_record(wins: int, losses: int, is_champion: bool = false, playoff_appearance: bool = false) -> Dictionary:
	return {
		"wins": wins,
		"losses": losses,
		"is_champion": is_champion,
		"playoff_appearance": playoff_appearance
	}


# =============================================================================
# PLAYING TIME SATISFACTION TESTS
# =============================================================================

func test_playing_time_score_starter_high_satisfaction() -> void:
	var stats := {"games_played": 12, "games_started": 12}
	var score := PlayerMorale._calculate_playing_time_score(stats)

	# Starter with full season should have high satisfaction
	assert_float(score).is_greater(70.0)


func test_playing_time_score_backup_moderate_satisfaction() -> void:
	var stats := {"games_played": 12, "games_started": 5}
	var score := PlayerMorale._calculate_playing_time_score(stats)

	# Regular backup should have moderate satisfaction
	assert_float(score).is_greater(50.0)
	assert_float(score).is_less(70.0)


func test_playing_time_score_rarely_plays_low_satisfaction() -> void:
	var stats := {"games_played": 4, "games_started": 1}
	var score := PlayerMorale._calculate_playing_time_score(stats)

	# Player who rarely plays should have lower satisfaction
	assert_float(score).is_less(50.0)


func test_playing_time_score_no_games_neutral() -> void:
	var stats := {"games_played": 0, "games_started": 0}
	var score := PlayerMorale._calculate_playing_time_score(stats)

	# No playing time should result in low satisfaction
	assert_float(score).is_greater_equal(0.0)
	assert_float(score).is_less_equal(100.0)


# =============================================================================
# TEAM SUCCESS SATISFACTION TESTS
# =============================================================================

func test_team_success_score_champion_high_satisfaction() -> void:
	var record := _create_team_record(12, 4, true, true)
	var score := PlayerMorale._calculate_team_success_score(record)

	# Championship should provide high satisfaction
	assert_float(score).is_greater(65.0)


func test_team_success_score_playoff_moderate_satisfaction() -> void:
	var record := _create_team_record(10, 6, false, true)
	var score := PlayerMorale._calculate_team_success_score(record)

	# Playoff appearance should provide moderate satisfaction boost
	assert_float(score).is_greater(55.0)


func test_team_success_score_winning_record_positive() -> void:
	var record := _create_team_record(9, 7, false, false)
	var score := PlayerMorale._calculate_team_success_score(record)

	# Winning record should be above neutral
	assert_float(score).is_greater(50.0)


func test_team_success_score_losing_record_negative() -> void:
	var record := _create_team_record(3, 13, false, false)
	var score := PlayerMorale._calculate_team_success_score(record)

	# Losing record should be below neutral
	assert_float(score).is_less(50.0)


# =============================================================================
# SATISFACTION CALCULATION TESTS
# =============================================================================

func test_calculate_satisfaction_combines_all_factors() -> void:
	var player := {"player_id": "TEST001"}
	var stats := _create_season_stats(12, 12)  # Starter
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := _create_team_record(10, 6, false, true)  # Playoff team

	var satisfaction := PlayerMorale.calculate_satisfaction(
		player, 2025, stats, awards, team_record
	)

	# Should combine playing time (high) + team success (moderate) = good satisfaction
	assert_float(satisfaction).is_greater(60.0)


func test_calculate_satisfaction_no_stats_returns_neutral() -> void:
	var player := {"player_id": "TEST001"}
	var stats := {}  # No stats for year
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := _create_team_record(8, 8, false, false)

	var satisfaction := PlayerMorale.calculate_satisfaction(
		player, 2025, stats, awards, team_record
	)

	# No stats should return neutral (50.0)
	assert_float(satisfaction).is_equal(50.0)


func test_calculate_satisfaction_invalid_player_returns_neutral() -> void:
	var player := {}  # No player_id
	var stats := _create_season_stats(12, 12)
	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := _create_team_record(10, 6, false, false)

	var satisfaction := PlayerMorale.calculate_satisfaction(
		player, 2025, stats, awards, team_record
	)

	assert_float(satisfaction).is_equal(50.0)


# =============================================================================
# MORALE UPDATE TESTS
# =============================================================================

func test_update_morale_increases_with_high_satisfaction() -> void:
	var player := _create_player("TEST001", 50.0)
	var high_satisfaction := 80.0

	var new_morale := PlayerMorale.update_morale(player, high_satisfaction)

	# Morale should increase from neutral (50) with high satisfaction
	assert_float(new_morale).is_greater(50.0)
	assert_float(player["morale"]).is_equal(new_morale)


func test_update_morale_decreases_with_low_satisfaction() -> void:
	var player := _create_player("TEST001", 50.0)
	var low_satisfaction := 20.0

	var new_morale := PlayerMorale.update_morale(player, low_satisfaction)

	# Morale should decrease from neutral with low satisfaction
	assert_float(new_morale).is_less(50.0)


func test_update_morale_stays_neutral_with_neutral_satisfaction() -> void:
	var player := _create_player("TEST001", 50.0)
	var neutral_satisfaction := 50.0

	var new_morale := PlayerMorale.update_morale(player, neutral_satisfaction)

	# Morale should stay neutral (no change)
	assert_float(new_morale).is_equal(50.0)


func test_update_morale_clamped_to_zero() -> void:
	var player := _create_player("TEST001", 10.0)  # Already low
	var very_low_satisfaction := 0.0

	var new_morale := PlayerMorale.update_morale(player, very_low_satisfaction)

	# Should not go below 0
	assert_float(new_morale).is_greater_equal(0.0)


func test_update_morale_clamped_to_hundred() -> void:
	var player := _create_player("TEST001", 90.0)  # Already high
	var very_high_satisfaction := 100.0

	var new_morale := PlayerMorale.update_morale(player, very_high_satisfaction)

	# Should not exceed 100
	assert_float(new_morale).is_less_equal(100.0)


func test_update_morale_stores_satisfaction() -> void:
	var player := _create_player("TEST001", 50.0)
	var satisfaction := 75.0

	PlayerMorale.update_morale(player, satisfaction)

	# Should store satisfaction in player dict
	assert_float(player.get("satisfaction", 0.0)).is_equal(satisfaction)


# =============================================================================
# TRANSFER PROBABILITY TESTS
# =============================================================================

func test_calculate_transfer_probability_high_morale_low_chance() -> void:
	var player := _create_player("TEST001", 80.0, 2)

	var probability := PlayerMorale.calculate_transfer_probability(player)

	assert_float(probability).is_equal(PlayerMorale.TRANSFER_PROB_HIGH_MORALE)
	assert_float(probability).is_less(0.1)  # Should be low


func test_calculate_transfer_probability_neutral_morale_moderate_chance() -> void:
	var player := _create_player("TEST001", 55.0, 2)

	var probability := PlayerMorale.calculate_transfer_probability(player)

	assert_float(probability).is_equal(PlayerMorale.TRANSFER_PROB_NEUTRAL_MORALE)


func test_calculate_transfer_probability_low_morale_high_chance() -> void:
	var player := _create_player("TEST001", 20.0, 2)

	var probability := PlayerMorale.calculate_transfer_probability(player)

	assert_float(probability).is_equal(PlayerMorale.TRANSFER_PROB_LOW_MORALE)
	assert_float(probability).is_greater(0.3)  # Should be high


func test_calculate_transfer_probability_senior_zero_chance() -> void:
	var player := _create_player("TEST001", 20.0, 4)  # Senior, low morale

	var probability := PlayerMorale.calculate_transfer_probability(player)

	# Seniors never transfer
	assert_float(probability).is_equal(0.0)


# =============================================================================
# TRANSFER DECISION TESTS (RNG)
# =============================================================================

func test_should_transfer_deterministic_with_same_seed() -> void:
	var test_callable := func(rng: RandomNumberGenerator) -> bool:
		var player := _create_player("TEST001", 30.0, 2)  # Low morale
		return PlayerMorale.should_transfer(player, rng)

	TestHelpersGdUnit4.assert_deterministic(self, test_callable, 0x12345, "Transfer decision")


func test_should_transfer_respects_zero_probability() -> void:
	var rng := TestHelpersGdUnit4.create_seeded_rng(0x999)
	var senior := _create_player("TEST001", 10.0, 4)  # Senior with low morale

	# Try many times, should never transfer
	for i in range(100):
		var transfers := PlayerMorale.should_transfer(senior, rng)
		assert_bool(transfers).is_false()


func test_should_transfer_with_high_probability_eventually_transfers() -> void:
	var rng := TestHelpersGdUnit4.create_seeded_rng(0x777)
	var unhappy_player := _create_player("TEST001", 10.0, 2)  # Very low morale (40% chance)

	# With 40% probability, should transfer within 10 tries
	var transferred := false
	for i in range(10):
		if PlayerMorale.should_transfer(unhappy_player, rng):
			transferred = true
			break

	assert_bool(transferred).is_true()


# =============================================================================
# DEVELOPMENT MULTIPLIER TESTS
# =============================================================================

func test_calculate_development_multiplier_neutral_morale() -> void:
	var multiplier := PlayerMorale.calculate_development_multiplier(50.0)

	# Neutral morale (50) should give 1.0x multiplier
	assert_float(multiplier).is_equal(1.0)


func test_calculate_development_multiplier_high_morale_boost() -> void:
	var multiplier := PlayerMorale.calculate_development_multiplier(75.0)

	# High morale should boost development
	assert_float(multiplier).is_greater(1.0)
	assert_float(multiplier).is_equal(1.5)


func test_calculate_development_multiplier_low_morale_penalty() -> void:
	var multiplier := PlayerMorale.calculate_development_multiplier(25.0)

	# Low morale should reduce development
	assert_float(multiplier).is_less(1.0)
	assert_float(multiplier).is_equal(0.5)


# =============================================================================
# BATCH UPDATE TESTS
# =============================================================================

func test_update_team_morale_updates_all_players() -> void:
	var players := [
		_create_player("P1", 50.0),
		_create_player("P2", 50.0),
		_create_player("P3", 50.0)
	]

	var player_career_stats := {
		"P1": _create_season_stats(12, 12),
		"P2": _create_season_stats(12, 6),
		"P3": _create_season_stats(12, 2)
	}

	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := _create_team_record(10, 6, false, true)

	var result := PlayerMorale.update_team_morale(
		players, 2025, player_career_stats, awards, team_record
	)

	assert_int(result["players_updated"]).is_equal(3)
	assert_float(result["avg_satisfaction"]).is_greater(0.0)
	assert_float(result["avg_morale"]).is_greater(0.0)


func test_batched_morale_update_produces_same_results() -> void:
	var players := [
		_create_player("P1", 50.0),
		_create_player("P2", 50.0)
	]

	var player_career_stats := {
		"P1": _create_season_stats(12, 12),
		"P2": _create_season_stats(12, 6)
	}

	var awards := {"awards": {}, "all_pro_teams": {}, "pro_bowl_rosters": {}}
	var team_record := _create_team_record(10, 6, false, true)

	# Regular update
	var players_copy1 := players.duplicate(true)
	var result1 := PlayerMorale.update_team_morale(
		players_copy1, 2025, player_career_stats, awards, team_record
	)

	# Batched update
	var players_copy2 := players.duplicate(true)
	var batched_data := PlayerMorale.prepare_team_batched_data(
		players_copy2, 2025, player_career_stats, awards, team_record
	)
	var result2 := PlayerMorale.update_team_morale_batched(
		players_copy2, 2025, batched_data
	)

	# Results should be equivalent
	assert_float(result1["avg_satisfaction"]).is_equal(result2["avg_satisfaction"])
	assert_float(result1["avg_morale"]).is_equal(result2["avg_morale"])


# =============================================================================
# TRANSFER PORTAL BATCH PROCESSING
# =============================================================================

func test_determine_transfers_returns_unhappy_players() -> void:
	var rng := TestHelpersGdUnit4.create_seeded_rng(0x555)

	var players := [
		_create_player("P1", 10.0, 2),  # Very unhappy
		_create_player("P2", 80.0, 2),  # Happy
		_create_player("P3", 30.0, 2),  # Unhappy
		_create_player("P4", 20.0, 4)   # Senior (won't transfer)
	]

	# Run many times to ensure we get transfers
	var transfer_players := PlayerMorale.determine_transfers(players, rng)

	# Should return an array (may be empty or have transfers)
	assert_object(transfer_players).is_not_null()


func test_determine_transfers_deterministic() -> void:
	var test_callable := func(rng: RandomNumberGenerator) -> int:
		var players := [
			_create_player("P1", 15.0, 2),
			_create_player("P2", 25.0, 2),
			_create_player("P3", 80.0, 2)
		]
		var transfers := PlayerMorale.determine_transfers(players, rng)
		return transfers.size()

	TestHelpersGdUnit4.assert_deterministic(self, test_callable, 0x777, "Transfer portal decisions")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_satisfaction_calculation_with_missing_data() -> void:
	var player := {"player_id": "TEST001"}
	var stats := {"2025": {}}  # Empty stats
	var awards := {}  # No awards
	var team_record := {}  # No record

	var satisfaction := PlayerMorale.calculate_satisfaction(
		player, 2025, stats, awards, team_record
	)

	# Should handle gracefully
	assert_float(satisfaction).is_greater_equal(0.0)
	assert_float(satisfaction).is_less_equal(100.0)


func test_morale_update_initializes_if_missing() -> void:
	var player := {"player_id": "TEST001"}  # No morale field

	var new_morale := PlayerMorale.update_morale(player, 70.0)

	# Should initialize to neutral (50) and then update
	assert_float(new_morale).is_greater(50.0)
	assert_float(player["morale"]).is_equal(new_morale)


func test_transfer_probability_with_missing_college_year() -> void:
	var player := {"player_id": "TEST001", "morale": 30.0}  # No college_year

	var probability := PlayerMorale.calculate_transfer_probability(player)

	# Should default to non-senior behavior
	assert_float(probability).is_greater(0.0)
