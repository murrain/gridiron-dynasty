extends RefCounted

## Test PA6.2: Player Happiness/Morale System
##
## Validates that:
##   - Morale tracks multi-year satisfaction trends
##   - High satisfaction increases morale over time
##   - Low satisfaction decreases morale over time
##   - Morale affects development rate multiplier

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")

func run(t) -> void:
	_test_morale_initialized_to_neutral(t)
	_test_morale_increases_with_high_satisfaction(t)
	_test_morale_decreases_with_low_satisfaction(t)
	_test_morale_stays_neutral_with_neutral_satisfaction(t)
	_test_morale_multi_year_cumulative(t)
	_test_morale_clamped_to_range(t)
	_test_development_multiplier_neutral_morale(t)
	_test_development_multiplier_high_morale(t)
	_test_development_multiplier_low_morale(t)
	_test_update_morale_modifies_player_dict(t)


func _test_morale_initialized_to_neutral(t) -> void:
	# Arrange: New player with no morale history
	var player := {"player_id": "player_001"}
	var satisfaction := 50.0

	# Act
	var morale := PlayerMorale.update_morale(player, satisfaction)

	# Assert: Morale should initialize to 50 and stay at 50 with neutral satisfaction
	t.assert_eq(morale, 50.0, "New player morale should stay at 50 with neutral satisfaction")
	t.assert_eq(float(player.get("morale", 0.0)), 50.0, "Player dict should have morale = 50")


func _test_morale_increases_with_high_satisfaction(t) -> void:
	# Arrange: Player with initial neutral morale
	var player := {"player_id": "player_002", "morale": 50.0}
	var high_satisfaction := 80.0  # +30 above neutral

	# Act
	var morale := PlayerMorale.update_morale(player, high_satisfaction)

	# Assert: Morale should increase
	# Formula: morale += (satisfaction - 50) * 0.3
	# Expected: 50 + (80 - 50) * 0.3 = 50 + 9 = 59
	t.assert_eq(morale, 59.0, "Morale should increase to 59 with satisfaction 80 (got %.1f)" % morale)
	t.assert_true(morale > 50.0, "Morale should be above neutral with high satisfaction")


func _test_morale_decreases_with_low_satisfaction(t) -> void:
	# Arrange: Player with initial neutral morale
	var player := {"player_id": "player_003", "morale": 50.0}
	var low_satisfaction := 30.0  # -20 below neutral

	# Act
	var morale := PlayerMorale.update_morale(player, low_satisfaction)

	# Assert: Morale should decrease
	# Formula: 50 + (30 - 50) * 0.3 = 50 - 6 = 44
	t.assert_eq(morale, 44.0, "Morale should decrease to 44 with satisfaction 30 (got %.1f)" % morale)
	t.assert_true(morale < 50.0, "Morale should be below neutral with low satisfaction")


func _test_morale_stays_neutral_with_neutral_satisfaction(t) -> void:
	# Arrange: Player with neutral morale
	var player := {"player_id": "player_004", "morale": 50.0}
	var neutral_satisfaction := 50.0

	# Act
	var morale := PlayerMorale.update_morale(player, neutral_satisfaction)

	# Assert: Morale should stay at 50
	t.assert_eq(morale, 50.0, "Morale should stay neutral with neutral satisfaction")


func _test_morale_multi_year_cumulative(t) -> void:
	# Arrange: Simulate 3 years of high satisfaction
	var player := {"player_id": "player_005", "morale": 50.0}

	# Act: Year 1 - satisfaction 70
	var morale_y1 := PlayerMorale.update_morale(player, 70.0)
	# Expected: 50 + (70 - 50) * 0.3 = 56

	# Act: Year 2 - satisfaction 70 (cumulative)
	var morale_y2 := PlayerMorale.update_morale(player, 70.0)
	# Expected: 56 + (70 - 50) * 0.3 = 62

	# Act: Year 3 - satisfaction 70 (cumulative)
	var morale_y3 := PlayerMorale.update_morale(player, 70.0)
	# Expected: 62 + (70 - 50) * 0.3 = 68

	# Assert: Morale should trend upward over multiple years
	t.assert_eq(morale_y1, 56.0, "Year 1 morale should be 56 (got %.1f)" % morale_y1)
	t.assert_eq(morale_y2, 62.0, "Year 2 morale should be 62 (got %.1f)" % morale_y2)
	t.assert_eq(morale_y3, 68.0, "Year 3 morale should be 68 (got %.1f)" % morale_y3)
	t.assert_true(morale_y3 > morale_y2, "Morale should continue increasing")
	t.assert_true(morale_y2 > morale_y1, "Morale should continue increasing")


func _test_morale_clamped_to_range(t) -> void:
	# Test upper bound
	var player_high := {"player_id": "player_006", "morale": 95.0}
	var very_high_satisfaction := 100.0

	var morale_high := PlayerMorale.update_morale(player_high, very_high_satisfaction)
	t.assert_true(morale_high <= 100.0, "Morale should be capped at 100 (got %.1f)" % morale_high)

	# Test lower bound
	var player_low := {"player_id": "player_007", "morale": 5.0}
	var very_low_satisfaction := 0.0

	var morale_low := PlayerMorale.update_morale(player_low, very_low_satisfaction)
	t.assert_true(morale_low >= 0.0, "Morale should be floored at 0 (got %.1f)" % morale_low)


func _test_development_multiplier_neutral_morale(t) -> void:
	# Arrange: Neutral morale (50)
	var morale := 50.0

	# Act
	var multiplier := PlayerMorale.calculate_development_multiplier(morale)

	# Assert: Neutral morale should give 1.0x multiplier
	t.assert_eq(multiplier, 1.0, "Neutral morale (50) should give 1.0x development multiplier")


func _test_development_multiplier_high_morale(t) -> void:
	# Arrange: High morale (75)
	var morale := 75.0

	# Act
	var multiplier := PlayerMorale.calculate_development_multiplier(morale)

	# Assert: High morale should give >1.0x multiplier
	# Formula: morale / 50 = 75 / 50 = 1.5
	t.assert_eq(multiplier, 1.5, "High morale (75) should give 1.5x development multiplier")
	t.assert_true(multiplier > 1.0, "High morale should boost development rate")


func _test_development_multiplier_low_morale(t) -> void:
	# Arrange: Low morale (25)
	var morale := 25.0

	# Act
	var multiplier := PlayerMorale.calculate_development_multiplier(morale)

	# Assert: Low morale should give <1.0x multiplier
	# Formula: 25 / 50 = 0.5
	t.assert_eq(multiplier, 0.5, "Low morale (25) should give 0.5x development multiplier")
	t.assert_true(multiplier < 1.0, "Low morale should reduce development rate")


func _test_update_morale_modifies_player_dict(t) -> void:
	# Arrange: Player dict
	var player := {"player_id": "player_008", "morale": 50.0}
	var satisfaction := 70.0

	# Act
	var returned_morale := PlayerMorale.update_morale(player, satisfaction)

	# Assert: Player dict should be updated with new morale and satisfaction
	t.assert_eq(float(player.get("morale", 0.0)), returned_morale, "Player dict morale should match returned value")
	t.assert_eq(float(player.get("satisfaction", 0.0)), satisfaction, "Player dict should have satisfaction stored")
	t.assert_true(player.has("morale"), "Player dict should have morale field")
	t.assert_true(player.has("satisfaction"), "Player dict should have satisfaction field")
