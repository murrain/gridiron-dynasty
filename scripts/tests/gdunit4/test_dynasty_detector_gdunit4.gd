extends GdUnitTestSuite
class_name TestDynastyDetectorGdUnit4

## GdUnit4 tests for DynastyDetector - Dynasty era detection system
##
## Tests:
##   - Dynasty detection (3+ championships in 5 years)
##   - Active dynasty tracking
##   - Dynasty end conditions
##   - Dynasty statistics and queries
##   - Championship history building

const DynastyDetector = preload("res://scripts/core/awards/DynastyDetector.gd")


# =============================================================================
# TEST HELPERS
# =============================================================================

func _create_world_state_with_championships(championships: Dictionary) -> Dictionary:
	return {
		"championships": {
			"nfl": {
				"super_bowl_winners": championships
			}
		},
		"team_history": {}
	}


# =============================================================================
# BASIC DYNASTY DETECTION TESTS
# =============================================================================

func test_detect_dynasty_with_three_championships_in_five_years() -> void:
	# Team wins championships in years 2020, 2021, 2023
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2023: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	var result := DynastyDetector.detect_dynasties(world_state, 2023)

	assert_int(result["new_dynasties"]).is_greater(0)
	assert_int(result["active_dynasties"]).is_greater(0)


func test_no_dynasty_with_two_championships() -> void:
	# Team wins only 2 championships
	var championships := {
		2020: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	var result := DynastyDetector.detect_dynasties(world_state, 2022)

	assert_int(result["new_dynasties"]).is_equal(0)


func test_no_dynasty_with_championships_spread_too_far() -> void:
	# Team wins 3 championships but spread over 6+ years
	var championships := {
		2020: "TEAM_A",
		2023: "TEAM_A",
		2027: "TEAM_A"  # More than 5 years from 2020
	}

	var world_state := _create_world_state_with_championships(championships)
	var result := DynastyDetector.detect_dynasties(world_state, 2027)

	# May detect a partial dynasty for 2023-2027 window, but not 2020-2027
	# Check that not all championships are in one dynasty
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	var all_dynasties := dynasties.get("active_dynasties", []) + dynasties.get("completed_dynasties", [])

	# If there's a dynasty, it shouldn't span all 7 years
	for dynasty in all_dynasties:
		var d: Dictionary = dynasty
		var champ_years: Array = d.get("championship_years", [])
		if champ_years.size() >= 3:
			var span := int(champ_years[champ_years.size() - 1]) - int(champ_years[0])
			assert_int(span).is_less_equal(5)


func test_dynasty_requires_three_championships_minimum() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2021)

	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	var active := dynasties.get("active_dynasties", [])

	assert_int(active.size()).is_equal(0)


# =============================================================================
# ACTIVE DYNASTY TRACKING TESTS
# =============================================================================

func test_dynasty_remains_active_when_winning_continues() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A",
		2023: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)

	# Detect after year 2022 (3 championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	# Check dynasty is active
	var dynasties: Dictionary = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(1)

	# Win again in 2023
	DynastyDetector.detect_dynasties(world_state, 2023)

	# Dynasty should still be active and updated
	dynasties = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(1)
	var dynasty: Dictionary = dynasties["active_dynasties"][0]
	assert_int(dynasty["championship_count"]).is_equal(4)


func test_dynasty_ends_after_three_years_without_championship() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)

	# Detect dynasty in 2022
	DynastyDetector.detect_dynasties(world_state, 2022)
	var dynasties: Dictionary = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(1)

	# Run simulation for years without championships
	DynastyDetector.detect_dynasties(world_state, 2023)  # 1 year without
	DynastyDetector.detect_dynasties(world_state, 2024)  # 2 years without
	DynastyDetector.detect_dynasties(world_state, 2025)  # 3 years without - should end

	# Dynasty should now be completed, not active
	dynasties = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(0)
	assert_int(dynasties["completed_dynasties"].size()).is_equal(1)


# =============================================================================
# DYNASTY DATA STRUCTURE TESTS
# =============================================================================

func test_dynasty_contains_required_fields() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	var dynasties: Dictionary = world_state["dynasty_eras"]
	var dynasty: Dictionary = dynasties["active_dynasties"][0]

	assert_bool(dynasty.has("team_id")).is_true()
	assert_bool(dynasty.has("start_year")).is_true()
	assert_bool(dynasty.has("championship_years")).is_true()
	assert_bool(dynasty.has("championship_count")).is_true()
	assert_bool(dynasty.has("last_championship_year")).is_true()


func test_dynasty_championship_years_are_sorted() -> void:
	var championships := {
		2022: "TEAM_A",
		2020: "TEAM_A",
		2021: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	var dynasties: Dictionary = world_state["dynasty_eras"]
	var dynasty: Dictionary = dynasties["active_dynasties"][0]
	var champ_years: Array = dynasty["championship_years"]

	# Years should be in ascending order
	for i in range(champ_years.size() - 1):
		assert_int(int(champ_years[i])).is_less(int(champ_years[i + 1]))


# =============================================================================
# MULTIPLE TEAM DYNASTY TESTS
# =============================================================================

func test_multiple_teams_can_have_dynasties_simultaneously() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A",
		2023: "TEAM_B",
		2024: "TEAM_B",
		2025: "TEAM_B"
	}

	var world_state := _create_world_state_with_championships(championships)

	# Detect after TEAM_A's dynasty
	DynastyDetector.detect_dynasties(world_state, 2022)
	var dynasties: Dictionary = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(1)

	# TEAM_A's dynasty should end, TEAM_B's should start
	DynastyDetector.detect_dynasties(world_state, 2025)
	dynasties = world_state["dynasty_eras"]

	# Should have 1 completed (TEAM_A) and 1 active (TEAM_B)
	var total_dynasties := dynasties["active_dynasties"].size() + dynasties["completed_dynasties"].size()
	assert_int(total_dynasties).is_equal(2)


func test_different_teams_championships_dont_create_dynasty() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_B",
		2022: "TEAM_C"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	var dynasties: Dictionary = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(0)


# =============================================================================
# DYNASTY QUERY FUNCTION TESTS
# =============================================================================

func test_is_in_dynasty_returns_true_for_active_dynasty() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	var is_dynasty := DynastyDetector.is_in_dynasty(world_state, "TEAM_A")

	assert_bool(is_dynasty).is_true()


func test_is_in_dynasty_returns_false_for_non_dynasty_team() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	var is_dynasty := DynastyDetector.is_in_dynasty(world_state, "TEAM_B")

	assert_bool(is_dynasty).is_false()


func test_get_active_dynasty_returns_dynasty_data() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	var dynasty := DynastyDetector.get_active_dynasty(world_state, "TEAM_A")

	assert_bool(dynasty.is_empty()).is_false()
	assert_str(String(dynasty["team_id"])).is_equal("TEAM_A")


func test_get_team_dynasties_returns_all_dynasties_for_team() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A",
		2026: "TEAM_A",
		2027: "TEAM_A",
		2028: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)

	# First dynasty (2020-2022)
	DynastyDetector.detect_dynasties(world_state, 2022)

	# Let first dynasty end
	DynastyDetector.detect_dynasties(world_state, 2025)

	# Second dynasty (2026-2028)
	DynastyDetector.detect_dynasties(world_state, 2028)

	var all_team_dynasties := DynastyDetector.get_team_dynasties(world_state, "TEAM_A")

	# Should have 2 dynasties (1 completed, 1 active)
	assert_int(all_team_dynasties.size()).is_equal(2)


# =============================================================================
# DYNASTY STATISTICS TESTS
# =============================================================================

func test_get_dynasty_stats_calculates_duration() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2023: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2023)

	var dynasty := DynastyDetector.get_active_dynasty(world_state, "TEAM_A")
	var stats := DynastyDetector.get_dynasty_stats(dynasty)

	assert_int(stats["championships"]).is_equal(3)
	assert_int(stats["start_year"]).is_equal(2020)
	assert_bool(stats["is_active"]).is_true()


func test_rank_dynasties_by_championships() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A",
		2025: "TEAM_B",
		2026: "TEAM_B",
		2027: "TEAM_B",
		2028: "TEAM_B",
		2029: "TEAM_B"
	}

	var world_state := _create_world_state_with_championships(championships)

	DynastyDetector.detect_dynasties(world_state, 2022)
	DynastyDetector.detect_dynasties(world_state, 2025)
	DynastyDetector.detect_dynasties(world_state, 2029)

	var ranked := DynastyDetector.rank_dynasties_by_championships(world_state, true)

	# TEAM_B has 5 championships, should be ranked first
	assert_int(ranked.size()).is_greater_equal(2)
	assert_str(String(ranked[0]["team_id"])).is_equal("TEAM_B")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_detect_dynasties_with_empty_championships() -> void:
	var world_state := _create_world_state_with_championships({})

	var result := DynastyDetector.detect_dynasties(world_state, 2025)

	assert_int(result["new_dynasties"]).is_equal(0)
	assert_int(result["active_dynasties"]).is_equal(0)


func test_dynasty_detection_initializes_structure_if_missing() -> void:
	var world_state := _create_world_state_with_championships({})

	# dynasty_eras doesn't exist initially
	assert_bool(world_state.has("dynasty_eras")).is_false()

	DynastyDetector.detect_dynasties(world_state, 2025)

	# Should be initialized
	assert_bool(world_state.has("dynasty_eras")).is_true()
	assert_bool(world_state["dynasty_eras"].has("active_dynasties")).is_true()
	assert_bool(world_state["dynasty_eras"].has("completed_dynasties")).is_true()


func test_dynasty_with_exactly_five_year_window() -> void:
	# Championships exactly 5 years apart
	var championships := {
		2020: "TEAM_A",
		2022: "TEAM_A",
		2024: "TEAM_A"  # Exactly within 5-year window (2020-2024)
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2024)

	var dynasties: Dictionary = world_state["dynasty_eras"]
	assert_int(dynasties["active_dynasties"].size()).is_equal(1)


func test_dynasty_with_four_championships_in_window() -> void:
	# 4 championships in 5 years (strong dynasty)
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A",
		2024: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2024)

	var dynasty := DynastyDetector.get_active_dynasty(world_state, "TEAM_A")
	assert_int(dynasty["championship_count"]).is_equal(4)


func test_get_all_active_dynasties() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A",
		2023: "TEAM_B",
		2024: "TEAM_B",
		2025: "TEAM_B"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2025)

	var active := DynastyDetector.get_all_active_dynasties(world_state)

	# TEAM_B should have active dynasty, TEAM_A's may have ended
	assert_int(active.size()).is_greater_equal(1)


func test_get_all_completed_dynasties() -> void:
	var championships := {
		2020: "TEAM_A",
		2021: "TEAM_A",
		2022: "TEAM_A"
	}

	var world_state := _create_world_state_with_championships(championships)
	DynastyDetector.detect_dynasties(world_state, 2022)

	# Let dynasty end
	DynastyDetector.detect_dynasties(world_state, 2025)
	DynastyDetector.detect_dynasties(world_state, 2026)

	var completed := DynastyDetector.get_all_completed_dynasties(world_state)

	assert_int(completed.size()).is_equal(1)
	assert_str(String(completed[0]["team_id"])).is_equal("TEAM_A")
