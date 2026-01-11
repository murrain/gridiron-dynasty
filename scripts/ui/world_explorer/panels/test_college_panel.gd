extends SceneTree

## Test script for CollegePanel
##
## Usage: godot --script scripts/ui/world_explorer/panels/test_college_panel.gd

const CollegePanel = preload("res://scenes/ui/world_explorer/panels/college_panel.tscn")

func _init():
	print("=== College Panel Test ===\n")

	# Create test world state
	var world_state = _create_test_world_state()

	# Instantiate panel
	var panel = CollegePanel.instantiate()
	root.add_child(panel)

	# Connect signals for testing
	panel.player_selected.connect(_on_player_selected)
	panel.team_selected.connect(_on_team_selected)

	# Test 1: Initialize
	print("Test 1: Initializing panel...")
	panel.initialize(world_state)
	print("✓ Panel initialized\n")

	# Test 2: Check cached data
	print("Test 2: Checking cached data...")
	assert(panel.all_colleges.size() == 3, "Should have 3 colleges")
	assert(panel.all_college_players.size() == 6, "Should have 6 players")
	print("✓ Data cached correctly: %d colleges, %d players\n" % [
		panel.all_colleges.size(),
		panel.all_college_players.size()
	])

	# Test 3: View mode switching
	print("Test 3: Testing view mode switching...")
	panel.current_view_mode = panel.ViewMode.SCHOOLS
	panel._update_view()
	print("✓ Schools view rendered")

	panel.current_view_mode = panel.ViewMode.PLAYERS_BY_CLASS
	panel._update_view()
	print("✓ Players by Class view rendered")

	panel.current_view_mode = panel.ViewMode.ALL_PLAYERS
	panel._update_view()
	print("✓ All Players view rendered\n")

	# Test 4: Tier filtering
	print("Test 4: Testing tier filtering...")
	panel.current_view_mode = panel.ViewMode.SCHOOLS
	panel.current_tier_filter = panel.TierFilterIndex.ELITE
	panel._update_view()
	print("✓ Elite tier filter applied")

	panel.current_tier_filter = panel.TierFilterIndex.ALL
	panel._update_view()
	print("✓ All tiers filter applied\n")

	# Test 5: Search filtering
	print("Test 5: Testing search filtering...")
	panel.filter_by_search("elite")
	print("✓ Search filter applied: 'elite'")

	panel.filter_by_search("")
	print("✓ Search cleared\n")

	# Test 6: Draft eligibility
	print("Test 6: Testing draft eligibility logic...")
	var senior_65 = {
		"college_year": 4,
		"stats": {"speed": 65, "strength": 65}  # Avg = 65
	}
	assert(panel._is_draft_eligible(senior_65), "Senior with 65 rating should be eligible")
	print("✓ Senior (rating 65) is draft-eligible")

	var senior_64 = {
		"college_year": 4,
		"stats": {"speed": 64, "strength": 64}  # Avg = 64
	}
	assert(not panel._is_draft_eligible(senior_64), "Senior with 64 rating should not be eligible")
	print("✓ Senior (rating 64) is not draft-eligible")

	var junior_80 = {
		"college_year": 3,
		"stats": {"speed": 80, "strength": 80}  # Avg = 80
	}
	assert(panel._is_draft_eligible(junior_80), "Junior with 80 rating should be eligible (early)")
	print("✓ Junior (rating 80) is draft-eligible (early declaration)")

	var junior_79 = {
		"college_year": 3,
		"stats": {"speed": 79, "strength": 79}  # Avg = 79
	}
	assert(not panel._is_draft_eligible(junior_79), "Junior with 79 rating should not be eligible")
	print("✓ Junior (rating 79) is not draft-eligible\n")

	# Test 7: Class name conversion
	print("Test 7: Testing class name conversion...")
	assert(panel._get_class_name(1) == "Freshman", "Year 1 = Freshman")
	assert(panel._get_class_name(2) == "Sophomore", "Year 2 = Sophomore")
	assert(panel._get_class_name(3) == "Junior", "Year 3 = Junior")
	assert(panel._get_class_name(4) == "Senior", "Year 4 = Senior")
	assert(panel._get_class_abbreviation(1) == "FR", "Year 1 = FR")
	assert(panel._get_class_abbreviation(4) == "SR", "Year 4 = SR")
	print("✓ Class name conversions correct\n")

	# Test 8: Tier display
	print("Test 8: Testing tier display...")
	assert(panel._get_tier_display("elite") == "Elite")
	assert(panel._get_tier_display("power5") == "Power 5")
	assert(panel._get_tier_display("mid_major") == "Mid-Major")
	print("✓ Tier display formatting correct\n")

	# Test 9: Cleanup
	print("Test 9: Testing cleanup...")
	panel.cleanup()
	assert(panel.all_colleges.size() == 0, "Colleges should be cleared")
	assert(panel.all_college_players.size() == 0, "Players should be cleared")
	print("✓ Cleanup successful\n")

	print("=== All Tests Passed! ===")
	quit()

func _create_test_world_state() -> Dictionary:
	return {
		"current_year": 2025,
		"colleges": [
			{
				"id": "college_1",
				"name": "Elite University",
				"tier": "elite",
				"eliteness": 95.0,
				"region": "south",
				"capacity": 85
			},
			{
				"id": "college_2",
				"name": "Power Five State",
				"tier": "power5",
				"eliteness": 75.0,
				"region": "midwest",
				"capacity": 85
			},
			{
				"id": "college_3",
				"name": "Mid-Major Tech",
				"tier": "mid_major",
				"eliteness": 55.0,
				"region": "west",
				"capacity": 65
			}
		],
		"college_rosters": {
			"college_1": {
				"players": [
					{
						"id": "player_1",
						"first_name": "John",
						"last_name": "Elite",
						"position": "QB",
						"college_id": "college_1",
						"college_year": 4,
						"age": 22,
						"stats": {
							"throw_power": 90,
							"throw_accuracy": 88,
							"speed": 75,
							"awareness": 85
						}
					},
					{
						"id": "player_2",
						"first_name": "Jane",
						"last_name": "Star",
						"position": "WR",
						"college_id": "college_1",
						"college_year": 3,
						"age": 21,
						"stats": {
							"speed": 92,
							"route_running": 85,
							"catching": 88,
							"awareness": 82
						}
					}
				]
			},
			"college_2": {
				"players": [
					{
						"id": "player_3",
						"first_name": "Mike",
						"last_name": "Tackle",
						"position": "OL",
						"college_id": "college_2",
						"college_year": 4,
						"age": 22,
						"stats": {
							"strength": 80,
							"blocking": 78,
							"awareness": 70,
							"technique": 75
						}
					},
					{
						"id": "player_4",
						"first_name": "Sarah",
						"last_name": "Rusher",
						"position": "RB",
						"college_id": "college_2",
						"college_year": 2,
						"age": 20,
						"stats": {
							"speed": 85,
							"agility": 88,
							"strength": 70,
							"vision": 80
						}
					}
				]
			},
			"college_3": {
				"players": [
					{
						"id": "player_5",
						"first_name": "Tom",
						"last_name": "Corner",
						"position": "CB",
						"college_id": "college_3",
						"college_year": 1,
						"age": 19,
						"stats": {
							"speed": 78,
							"coverage": 72,
							"awareness": 65,
							"agility": 80
						}
					},
					{
						"id": "player_6",
						"first_name": "Lisa",
						"last_name": "Backer",
						"position": "LB",
						"college_id": "college_3",
						"college_year": 3,
						"age": 21,
						"stats": {
							"speed": 75,
							"tackling": 70,
							"awareness": 72,
							"coverage": 68
						}
					}
				]
			}
		},
		"nfl_teams": [],
		"nfl_rosters": {},
		"hs_schools": [],
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}

func _on_player_selected(player_id: String):
	print("Signal: player_selected(%s)" % player_id)

func _on_team_selected(team_id: String, level: String):
	print("Signal: team_selected(%s, %s)" % [team_id, level])
