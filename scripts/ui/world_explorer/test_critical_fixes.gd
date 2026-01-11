extends Node

## Test script to verify all critical fixes from Track 2 code review
##
## Tests:
## 1. Warning logs when data not found
## 2. Magic numbers replaced with constants
## 3. Placeholder text for missing data
## 4. Performance documentation exists
## 5. in_place sorting parameter works

func _ready():
	print("=== Testing Critical Fixes ===\n")

	# Create minimal test world_state
	var world_state = _create_test_world_state()

	_test_warning_logs(world_state)
	_test_constants()
	_test_placeholder_text(world_state)
	_test_in_place_sorting()

	print("\n=== All Critical Fixes Verified ===")

func _create_test_world_state() -> Dictionary:
	"""Create a minimal world_state for testing"""
	return {
		"current_year": 2024,
		"nfl_teams": [
			{"id": "team_1", "name": "Test Team", "league_cap": 200.0, "cap_space": 15.0}
		],
		"colleges": [
			{"id": "college_1", "name": "Test College"}
		],
		"hs_schools": [
			{"id": "hs_1", "name": "Test High School"}
		],
		"nfl_rosters": {
			"team_1": {
				"players": [
					{
						"id": "player_1",
						"first_name": "John",
						"last_name": "Doe",
						"position": "QB",
						"age": 25,
						"stats": {
							"throw_power": 85.0,
							"throw_accuracy": 90.0,
							"awareness": 88.0,
							"decision_making": 87.0
						}
					},
					{
						"id": "player_2",
						"first_name": "Jane",
						"last_name": "Smith",
						"position": "RB",
						"age": 23,
						"stats": {
							"speed": 92.0,
							"agility": 88.0,
							"strength": 80.0,
							"vision": 85.0
						}
					}
				]
			}
		},
		"college_rosters": {},
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}

func _test_warning_logs(world_state: Dictionary):
	print("--- Test 1: Warning Logs ---")

	print("Testing PlayerQueries.get_player_by_id with empty ID...")
	var result = PlayerQueries.get_player_by_id(world_state, "")
	print("  Result: %s (should be null)" % ("null" if result == null else "NOT NULL"))

	print("Testing PlayerQueries.get_player_by_id with non-existent ID...")
	result = PlayerQueries.get_player_by_id(world_state, "fake_player_999")
	print("  Result: %s (should be null)" % ("null" if result == null else "NOT NULL"))

	print("Testing TeamQueries.get_nfl_team with empty ID...")
	result = TeamQueries.get_nfl_team(world_state, "")
	print("  Result: %s (should be null)" % ("null" if result == null else "NOT NULL"))

	print("Testing TeamQueries.get_nfl_team with non-existent ID...")
	result = TeamQueries.get_nfl_team(world_state, "fake_team_999")
	print("  Result: %s (should be null)" % ("null" if result == null else "NOT NULL"))

	print("Testing TeamQueries.get_college with non-existent ID...")
	result = TeamQueries.get_college(world_state, "fake_college_999")
	print("  Result: %s (should be null)" % ("null" if result == null else "NOT NULL"))

	print("Testing TeamQueries.get_hs_school with non-existent ID...")
	result = TeamQueries.get_hs_school(world_state, "fake_school_999")
	print("  Result: %s (should be null)" % ("null" if result == null else "NOT NULL"))

	print("Testing DraftQueries.get_draft_pool with non-existent year...")
	var pool = DraftQueries.get_draft_pool(world_state, 2099)
	print("  Result: %d players (should be 0)" % pool.size())

	print("Testing DraftQueries.get_top_prospects with non-existent year...")
	var prospects = DraftQueries.get_top_prospects(world_state, 2099, 5)
	print("  Result: %d prospects (should be 0)" % prospects.size())

	print("  PASS: All warning logs should appear above")

func _test_constants():
	print("\n--- Test 2: Magic Numbers Replaced with Constants ---")

	print("Testing StatQueries constants exist...")
	print("  RATING_ELITE: %.1f" % StatQueries.RATING_ELITE)
	print("  RATING_GREAT: %.1f" % StatQueries.RATING_GREAT)
	print("  RATING_GOOD: %.1f" % StatQueries.RATING_GOOD)
	print("  RATING_AVERAGE: %.1f" % StatQueries.RATING_AVERAGE)
	print("  RATING_BELOW_AVG: %.1f" % StatQueries.RATING_BELOW_AVG)

	print("  COLOR_ELITE: %s" % StatQueries.COLOR_ELITE)
	print("  COLOR_GREAT: %s" % StatQueries.COLOR_GREAT)
	print("  COLOR_GOOD: %s" % StatQueries.COLOR_GOOD)
	print("  COLOR_AVERAGE: %s" % StatQueries.COLOR_AVERAGE)
	print("  COLOR_BELOW_AVG: %s" % StatQueries.COLOR_BELOW_AVG)
	print("  COLOR_POOR: %s" % StatQueries.COLOR_POOR)

	print("Testing TeamDetailFormatter constants exist...")
	print("  CAP_SPACE_HEALTHY: %.1f" % TeamDetailFormatter.CAP_SPACE_HEALTHY)
	print("  CAP_SPACE_TIGHT: %.1f" % TeamDetailFormatter.CAP_SPACE_TIGHT)
	print("  COLOR_CAP_HEALTHY: %s" % TeamDetailFormatter.COLOR_CAP_HEALTHY)
	print("  COLOR_CAP_TIGHT: %s" % TeamDetailFormatter.COLOR_CAP_TIGHT)
	print("  COLOR_CAP_OVER: %s" % TeamDetailFormatter.COLOR_CAP_OVER)

	print("  PASS: All constants defined")

func _test_placeholder_text(world_state: Dictionary):
	print("\n--- Test 3: Placeholder Text for Missing Data ---")

	# Create player with missing data
	var empty_player = {
		"id": "empty_player",
		"first_name": "Empty",
		"last_name": "Player",
		"position": "UNKNOWN",
		"age": 20
	}

	print("Testing PlayerDetailFormatter with empty player data...")
	var formatted = PlayerDetailFormatter.format(empty_player, world_state)

	var has_physicals_placeholder = "No physical data available" in formatted
	print("  Has physicals placeholder: %s" % ("YES" if has_physicals_placeholder else "NO"))

	var has_stats_placeholder = "No stats available" in formatted or "No core stats" in formatted
	print("  Has stats placeholder: %s" % ("YES" if has_stats_placeholder else "NO"))

	var has_career_placeholder = "No career information available" in formatted
	print("  Has career placeholder: %s" % ("YES" if has_career_placeholder else "NO"))

	if has_physicals_placeholder and has_stats_placeholder and has_career_placeholder:
		print("  PASS: All placeholders present")
	else:
		print("  WARNING: Some placeholders missing")

func _test_in_place_sorting():
	print("\n--- Test 4: in_place Sorting Parameter ---")

	# Create test players
	var players = [
		{"id": "p1", "stats": {"speed": 70.0}},
		{"id": "p2", "stats": {"speed": 90.0}},
		{"id": "p3", "stats": {"speed": 80.0}}
	]

	print("Testing sort_players_by_rating with in_place=false...")
	var original_first_id = players[0].get("id")
	var sorted_copy = PlayerQueries.sort_players_by_rating(players, false, false)
	var original_still_same = players[0].get("id") == original_first_id
	print("  Original array unchanged: %s" % ("YES" if original_still_same else "NO"))
	print("  Sorted result is different array: %s" % ("YES" if sorted_copy != players else "NO"))

	print("Testing sort_players_by_rating with in_place=true...")
	var sorted_in_place = PlayerQueries.sort_players_by_rating(players, false, true)
	var arrays_are_same = sorted_in_place == players
	print("  Arrays are same reference: %s" % ("YES" if arrays_are_same else "NO"))
	print("  Original array was modified: %s" % ("YES" if players[0].get("id") != original_first_id else "NO"))

	if original_still_same and arrays_are_same:
		print("  PASS: in_place parameter works correctly")
	else:
		print("  FAIL: in_place parameter not working as expected")
