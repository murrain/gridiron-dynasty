## GdUnit4 test suite for PA6.2: Player Happiness/Morale System
##
## Validates that:
##   - Morale tracks multi-year satisfaction trends
##   - High satisfaction increases morale over time
##   - Low satisfaction decreases morale over time
##   - Morale affects development rate multiplier
extends GdUnitTestSuite

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")


func test_morale_initialized_to_neutral() -> void:
	var player := {"player_id": "player_001"}
	var satisfaction := 50.0

	var morale := PlayerMorale.update_morale(player, satisfaction)

	assert_float(morale).is_equal(50.0)
	assert_float(float(player.get("morale", 0.0))).is_equal(50.0)


func test_morale_increases_with_high_satisfaction() -> void:
	var player := {"player_id": "player_002", "morale": 50.0}
	var high_satisfaction := 80.0  # +30 above neutral

	var morale := PlayerMorale.update_morale(player, high_satisfaction)

	# Formula: morale += (satisfaction - 50) * 0.3
	# Expected: 50 + (80 - 50) * 0.3 = 50 + 9 = 59
	assert_float(morale).is_equal(59.0)
	assert_float(morale).is_greater(50.0)


func test_morale_decreases_with_low_satisfaction() -> void:
	var player := {"player_id": "player_003", "morale": 50.0}
	var low_satisfaction := 30.0  # -20 below neutral

	var morale := PlayerMorale.update_morale(player, low_satisfaction)

	# Formula: 50 + (30 - 50) * 0.3 = 50 - 6 = 44
	assert_float(morale).is_equal(44.0)
	assert_float(morale).is_less(50.0)


func test_morale_stays_neutral_with_neutral_satisfaction() -> void:
	var player := {"player_id": "player_004", "morale": 50.0}
	var neutral_satisfaction := 50.0

	var morale := PlayerMorale.update_morale(player, neutral_satisfaction)

	assert_float(morale).is_equal(50.0)


func test_morale_multi_year_cumulative() -> void:
	var player := {"player_id": "player_005", "morale": 50.0}

	# Year 1 - satisfaction 70
	var morale_y1 := PlayerMorale.update_morale(player, 70.0)
	# Expected: 50 + (70 - 50) * 0.3 = 56

	# Year 2 - satisfaction 70 (cumulative)
	var morale_y2 := PlayerMorale.update_morale(player, 70.0)
	# Expected: 56 + (70 - 50) * 0.3 = 62

	# Year 3 - satisfaction 70 (cumulative)
	var morale_y3 := PlayerMorale.update_morale(player, 70.0)
	# Expected: 62 + (70 - 50) * 0.3 = 68

	assert_float(morale_y1).is_equal(56.0)
	assert_float(morale_y2).is_equal(62.0)
	assert_float(morale_y3).is_equal(68.0)
	assert_float(morale_y3).is_greater(morale_y2)
	assert_float(morale_y2).is_greater(morale_y1)


func test_morale_clamped_to_range() -> void:
	# Test upper bound
	var player_high := {"player_id": "player_006", "morale": 95.0}
	var very_high_satisfaction := 100.0

	var morale_high := PlayerMorale.update_morale(player_high, very_high_satisfaction)
	assert_float(morale_high).is_less_equal(100.0)

	# Test lower bound
	var player_low := {"player_id": "player_007", "morale": 5.0}
	var very_low_satisfaction := 0.0

	var morale_low := PlayerMorale.update_morale(player_low, very_low_satisfaction)
	assert_float(morale_low).is_greater_equal(0.0)


func test_development_multiplier_neutral_morale() -> void:
	var morale := 50.0

	var multiplier := PlayerMorale.calculate_development_multiplier(morale)

	assert_float(multiplier).is_equal(1.0)


func test_development_multiplier_high_morale() -> void:
	var morale := 75.0

	var multiplier := PlayerMorale.calculate_development_multiplier(morale)

	# Formula: morale / 50 = 75 / 50 = 1.5
	assert_float(multiplier).is_equal(1.5)
	assert_float(multiplier).is_greater(1.0)


func test_development_multiplier_low_morale() -> void:
	var morale := 25.0

	var multiplier := PlayerMorale.calculate_development_multiplier(morale)

	# Formula: 25 / 50 = 0.5
	assert_float(multiplier).is_equal(0.5)
	assert_float(multiplier).is_less(1.0)


func test_update_morale_modifies_player_dict() -> void:
	var player := {"player_id": "player_008", "morale": 50.0}
	var satisfaction := 70.0

	var returned_morale := PlayerMorale.update_morale(player, satisfaction)

	assert_float(float(player.get("morale", 0.0))).is_equal(returned_morale)
	assert_float(float(player.get("satisfaction", 0.0))).is_equal(satisfaction)
	assert_bool(player.has("morale")).is_true()
	assert_bool(player.has("satisfaction")).is_true()
