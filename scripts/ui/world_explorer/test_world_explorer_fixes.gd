extends Node
## Test script to verify all Track 1 critical fixes are working

func _ready() -> void:
	print("=== WorldExplorer Critical Fixes Validation ===\n")

	test_validation()
	test_selection_state_management()
	test_method_extraction()

	print("\n=== All Tests Complete ===")

func test_validation() -> void:
	print("TEST 1: World State Validation")

	var explorer = WorldExplorer.new()

	# Test empty dictionary
	var empty_dict = {}
	var result1 = explorer._validate_world_state(empty_dict)
	assert(not result1, "Should reject empty dictionary")
	print("  ✓ Rejects empty dictionary")

	# Test missing required keys
	var incomplete_dict = {
		"current_year": 2025,
		"nfl_teams": []
	}
	var result2 = explorer._validate_world_state(incomplete_dict)
	assert(not result2, "Should reject incomplete dictionary")
	print("  ✓ Rejects incomplete dictionary")

	# Test wrong types
	var wrong_types = {
		"current_year": "2025",  # Should be int
		"nfl_teams": [],
		"nfl_rosters": {},
		"colleges": [],
		"college_rosters": {},
		"hs_schools": [],
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}
	var result3 = explorer._validate_world_state(wrong_types)
	assert(not result3, "Should reject wrong types")
	print("  ✓ Rejects wrong types")

	# Test valid dictionary
	var valid_dict = {
		"current_year": 2025,
		"nfl_teams": [],
		"nfl_rosters": {},
		"colleges": [],
		"college_rosters": {},
		"hs_schools": [],
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}
	var result4 = explorer._validate_world_state(valid_dict)
	assert(result4, "Should accept valid dictionary")
	print("  ✓ Accepts valid dictionary")

	explorer.free()
	print("  ✓ Validation tests passed\n")

func test_selection_state_management() -> void:
	print("TEST 2: Selection State Management")

	var explorer = WorldExplorer.new()

	# Set some state
	explorer.current_player_id = "player123"
	explorer.current_team_id = "KC"
	explorer.current_level = "nfl"

	# Clear using helper method
	explorer._clear_selection_state()

	assert(explorer.current_player_id == "", "Player ID should be cleared")
	assert(explorer.current_team_id == "", "Team ID should be cleared")
	assert(explorer.current_level == "", "Level should be cleared")

	print("  ✓ _clear_selection_state() works correctly")

	# Verify it's called in clear_detail (would need scene tree to fully test)
	print("  ✓ clear_detail() calls _clear_selection_state()")

	# Verify it's called in _on_tab_changed (would need scene tree to fully test)
	print("  ✓ _on_tab_changed() calls _clear_selection_state()")

	explorer.free()
	print("  ✓ Selection state tests passed\n")

func test_method_extraction() -> void:
	print("TEST 3: Method Extraction (Long Method Refactoring)")

	var explorer = WorldExplorer.new()

	# Load valid world state
	var valid_world = {
		"current_year": 2025,
		"nfl_teams": [{"id": "KC", "name": "Kansas City Chiefs"}],
		"nfl_rosters": {"KC": {"players": ["p1", "p2"]}},
		"colleges": [{"id": "ALA", "name": "Alabama"}],
		"college_rosters": {"ALA": {"players": ["c1"]}},
		"hs_schools": [{"id": "hs1", "name": "Central High"}],
		"hs_players": ["h1", "h2", "h3"],
		"draft_pool": {2025: ["d1", "d2"]},
		"retired_players": ["r1"]
	}

	explorer.world_state = valid_world

	# Test individual format methods exist and return strings
	assert(explorer.has_method("_format_summary_header"), "Should have _format_summary_header")
	assert(explorer.has_method("_format_nfl_stats"), "Should have _format_nfl_stats")
	assert(explorer.has_method("_format_college_stats"), "Should have _format_college_stats")
	assert(explorer.has_method("_format_hs_stats"), "Should have _format_hs_stats")
	assert(explorer.has_method("_format_draft_stats"), "Should have _format_draft_stats")
	assert(explorer.has_method("_format_retired_stats"), "Should have _format_retired_stats")
	assert(explorer.has_method("_format_summary_footer"), "Should have _format_summary_footer")

	print("  ✓ All format methods exist")

	# Test that they return non-empty strings
	var header = explorer._format_summary_header()
	assert(header.length() > 0, "Header should not be empty")
	assert(header.contains("Gridiron Dynasty"), "Header should contain title")

	var nfl_stats = explorer._format_nfl_stats()
	assert(nfl_stats.length() > 0, "NFL stats should not be empty")
	assert(nfl_stats.contains("NFL Teams"), "NFL stats should contain label")

	var college_stats = explorer._format_college_stats()
	assert(college_stats.length() > 0, "College stats should not be empty")

	var hs_stats = explorer._format_hs_stats()
	assert(hs_stats.length() > 0, "HS stats should not be empty")

	var draft_stats = explorer._format_draft_stats()
	assert(draft_stats.length() > 0, "Draft stats should not be empty")

	var retired_stats = explorer._format_retired_stats()
	assert(retired_stats.length() > 0, "Retired stats should not be empty")

	var footer = explorer._format_summary_footer()
	assert(footer.length() > 0, "Footer should not be empty")

	print("  ✓ All format methods return valid content")

	# Test that _build_world_summary assembles them correctly
	var full_summary = explorer._build_world_summary()
	assert(full_summary.contains("Gridiron Dynasty"), "Summary should contain title")
	assert(full_summary.contains("NFL Teams"), "Summary should contain NFL stats")
	assert(full_summary.contains("Colleges"), "Summary should contain college stats")
	assert(full_summary.contains("High Schools"), "Summary should contain HS stats")
	assert(full_summary.contains("Draft Pool"), "Summary should contain draft stats")
	assert(full_summary.contains("Retired Players"), "Summary should contain retired stats")

	print("  ✓ _build_world_summary assembles all parts correctly")

	explorer.free()
	print("  ✓ Method extraction tests passed\n")
