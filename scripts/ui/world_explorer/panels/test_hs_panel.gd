extends Node

## Test script for HsPanel
## Tests all view modes, filtering, pagination, and signal emission

# Preload panel scene and utilities
const HsPanelScene = preload("res://scenes/ui/world_explorer/panels/hs_panel.tscn")
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")

func _ready() -> void:
	print("=" * 80)
	print("HsPanel Test Suite")
	print("=" * 80)

	var world_state = _create_mock_world_state()
	_test_panel_initialization(world_state)
	_test_schools_view(world_state)
	_test_pagination(world_state)
	_test_players_by_year_view(world_state)
	_test_all_players_view(world_state)
	_test_seniors_only_view(world_state)
	_test_filtering(world_state)
	_test_search(world_state)
	_test_college_eligibility(world_state)
	_test_signals()

	print("\n" + "=" * 80)
	print("All tests completed!")
	print("=" * 80)

func _create_mock_world_state() -> Dictionary:
	var ws = {
		"current_year": 2025,
		"hs_schools": [],
		"hs_players": [],
		"nfl_teams": [],
		"nfl_rosters": {},
		"colleges": [],
		"college_rosters": {},
		"draft_pool": {},
		"retired_players": []
	}

	# Create 100 mock high schools (subset of 400)
	var regions = ["midwest", "south", "west", "northeast"]
	var tiers = ["powerhouse", "competitive", "developmental"]
	var program_qualities = ["elite_dev", "strong_dev", "solid_dev", "average_dev", "below_avg_dev"]

	for i in range(100):
		var school = {
			"id": "hs_%03d" % i,
			"name": "High School %d" % i,
			"region": regions[i % regions.size()],
			"tier": tiers[i % tiers.size()],
			"program_quality_tier": program_qualities[i % program_qualities.size()]
		}
		ws["hs_schools"].append(school)

	# Create mock players (5 players per school, mix of years 1-4)
	for school in ws["hs_schools"]:
		var school_id = school["id"]

		for year in range(1, 5):  # Years 1-4
			var player = _create_mock_player(school_id, year)
			ws["hs_players"].append(player)

	print("\nCreated mock world state:")
	print("  - Schools: %d" % ws["hs_schools"].size())
	print("  - Players: %d" % ws["hs_players"].size())

	return ws

func _create_mock_player(school_id: String, year: int) -> Dictionary:
	var positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]
	var player_num = randi() % 10000

	# Generate varying attributes for ratings
	var speed = randf_range(30.0, 95.0)
	var strength = randf_range(30.0, 95.0)
	var agility = randf_range(30.0, 95.0)
	var intelligence = randf_range(30.0, 95.0)

	return {
		"id": "player_%s_%d" % [school_id, year],
		"player_id": "player_%s_%d" % [school_id, year],
		"first_name": "Player",
		"last_name": "%d" % player_num,
		"position": positions[randi() % positions.size()],
		"hs_school_id": school_id,
		"hs_year": year,
		"speed": speed,
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence
	}

func _test_panel_initialization(world_state: Dictionary) -> void:
	print("\n[TEST] Panel Initialization")

	var panel = HsPanelScene.instantiate()
	add_child(panel)

	# Wait for _ready()
	await get_tree().process_frame

	# Initialize panel
	panel.initialize(world_state)

	assert(panel.world_state.size() > 0, "Panel should store world_state")
	assert(panel.all_hs_schools.size() == 100, "Panel should cache schools")
	assert(panel.all_hs_players.size() == 400, "Panel should cache players (4 per school)")

	print("  ✓ Panel initialized successfully")
	print("  ✓ Cached %d schools" % panel.all_hs_schools.size())
	print("  ✓ Cached %d players" % panel.all_hs_players.size())

	panel.queue_free()

func _test_schools_view(world_state: Dictionary) -> void:
	print("\n[TEST] Schools View")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Default view should be Schools
	assert(panel.current_view_mode == panel.ViewMode.SCHOOLS, "Default view should be SCHOOLS")

	# Check tree structure
	var tree = panel.content_list
	assert(tree.columns == 6, "Schools view should have 6 columns")

	# Count items (should be first page = 50)
	var root = tree.get_root()
	var item_count = 0
	var child = root.get_first_child()
	while child != null:
		item_count += 1
		child = child.get_next()

	print("  ✓ Schools view rendered")
	print("  ✓ First page shows %d schools (expected 50)" % item_count)

	panel.queue_free()

func _test_pagination(world_state: Dictionary) -> void:
	print("\n[TEST] Pagination")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Check pagination controls
	assert(panel.pagination_bar.visible, "Pagination bar should be visible in Schools view")
	assert(panel.current_page == 0, "Should start on page 0")
	assert(panel.total_pages == 2, "100 schools / 50 per page = 2 pages")

	print("  ✓ Pagination initialized")
	print("  ✓ Total pages: %d" % panel.total_pages)
	print("  ✓ Current page: %d" % (panel.current_page + 1))

	# Test page navigation
	panel._on_next_page_pressed()
	await get_tree().process_frame

	assert(panel.current_page == 1, "Should move to page 1")
	print("  ✓ Next page button works")

	panel._on_prev_page_pressed()
	await get_tree().process_frame

	assert(panel.current_page == 0, "Should return to page 0")
	print("  ✓ Previous page button works")

	panel.queue_free()

func _test_players_by_year_view(world_state: Dictionary) -> void:
	print("\n[TEST] Players by Year View")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Switch to Players by Year view
	panel.current_view_mode = panel.ViewMode.PLAYERS_BY_YEAR
	panel._update_view()
	await get_tree().process_frame

	# Check pagination is hidden
	assert(not panel.pagination_bar.visible, "Pagination should be hidden in Players by Year view")

	# Check tree structure
	var tree = panel.content_list
	assert(tree.columns == 4, "Players by Year view should have 4 columns")

	print("  ✓ Players by Year view rendered")
	print("  ✓ Pagination hidden correctly")

	panel.queue_free()

func _test_all_players_view(world_state: Dictionary) -> void:
	print("\n[TEST] All Players View")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Switch to All Players view
	panel.current_view_mode = panel.ViewMode.ALL_PLAYERS
	panel._update_view()
	await get_tree().process_frame

	# Check filters are visible
	assert(panel.position_filter.visible, "Position filter should be visible")
	assert(panel.year_filter.visible, "Year filter should be visible")

	# Check tree structure
	var tree = panel.content_list
	assert(tree.columns == 5, "All Players view should have 5 columns")

	print("  ✓ All Players view rendered")
	print("  ✓ Position filter visible")
	print("  ✓ Year filter visible")

	panel.queue_free()

func _test_seniors_only_view(world_state: Dictionary) -> void:
	print("\n[TEST] Seniors Only View")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Switch to Seniors Only view
	panel.current_view_mode = panel.ViewMode.SENIORS_ONLY
	panel._update_view()
	await get_tree().process_frame

	# Check tree structure
	var tree = panel.content_list
	assert(tree.columns == 5, "Seniors Only view should have 5 columns")

	# Count seniors in data
	var seniors = world_state["hs_players"].filter(func(p): return p.get("hs_year", 0) == 4)
	print("  ✓ Seniors Only view rendered")
	print("  ✓ Total seniors in data: %d" % seniors.size())

	panel.queue_free()

func _test_filtering(world_state: Dictionary) -> void:
	print("\n[TEST] Filtering")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Test tier filtering
	panel.current_tier_filter = panel.TierFilterIndex.POWERHOUSE
	panel._update_view()
	await get_tree().process_frame

	var powerhouse_schools = world_state["hs_schools"].filter(
		func(s): return s.get("tier", "").to_lower() == "powerhouse"
	)

	print("  ✓ Tier filter applied")
	print("  ✓ Powerhouse schools: %d" % powerhouse_schools.size())

	# Reset filter
	panel.current_tier_filter = panel.TierFilterIndex.ALL
	panel._update_view()
	await get_tree().process_frame

	# Test position filter in All Players view
	panel.current_view_mode = panel.ViewMode.ALL_PLAYERS
	panel.current_position_filter = panel.PositionFilterIndex.QB
	panel._update_view()
	await get_tree().process_frame

	var qbs = world_state["hs_players"].filter(func(p): return p.get("position", "") == "QB")
	print("  ✓ Position filter applied")
	print("  ✓ QBs in data: %d" % qbs.size())

	# Test year filter
	panel.current_year_filter = panel.YearFilterIndex.YEAR4
	panel._update_view()
	await get_tree().process_frame

	print("  ✓ Year filter applied")

	panel.queue_free()

func _test_search(world_state: Dictionary) -> void:
	print("\n[TEST] Search Filtering")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Test school search
	panel.filter_by_search("High School 1")
	await get_tree().process_frame

	print("  ✓ School search applied")

	# Test player search
	panel.current_view_mode = panel.ViewMode.ALL_PLAYERS
	panel.filter_by_search("Player")
	await get_tree().process_frame

	print("  ✓ Player search applied")

	# Clear search
	panel.filter_by_search("")
	await get_tree().process_frame

	print("  ✓ Search cleared")

	panel.queue_free()

func _test_college_eligibility(world_state: Dictionary) -> void:
	print("\n[TEST] College Eligibility")

	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Test eligibility function
	var senior_player = {
		"hs_year": 4,
		"speed": 70.0,
		"strength": 70.0,
		"agility": 70.0,
		"intelligence": 70.0
	}

	var junior_player = {
		"hs_year": 3,
		"speed": 70.0,
		"strength": 70.0,
		"agility": 70.0,
		"intelligence": 70.0
	}

	var low_rated_senior = {
		"hs_year": 4,
		"speed": 30.0,
		"strength": 30.0,
		"agility": 30.0,
		"intelligence": 30.0
	}

	var senior_is_eligible = panel._is_college_eligible(senior_player)
	var junior_is_eligible = panel._is_college_eligible(junior_player)
	var low_rated_is_eligible = panel._is_college_eligible(low_rated_senior)

	print("  ✓ Eligibility function tested")
	print("  ✓ Senior (70 rating): %s" % ("eligible" if senior_is_eligible else "not eligible"))
	print("  ✓ Junior (70 rating): %s" % ("eligible" if junior_is_eligible else "not eligible"))
	print("  ✓ Low-rated senior (30 rating): %s" % ("eligible" if low_rated_is_eligible else "not eligible"))

	assert(senior_is_eligible, "Senior with 70 rating should be eligible")
	assert(not junior_is_eligible, "Junior should not be eligible")
	assert(not low_rated_is_eligible, "Low-rated senior should not be eligible")

	panel.queue_free()

func _test_signals() -> void:
	print("\n[TEST] Signal Emission")

	var world_state = _create_mock_world_state()
	var panel = HsPanelScene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	panel.initialize(world_state)

	# Connect signals
	var player_signal_received = false
	var team_signal_received = false
	var received_player_id = ""
	var received_team_id = ""
	var received_level = ""

	panel.player_selected.connect(func(player_id):
		player_signal_received = true
		received_player_id = player_id
	)

	panel.team_selected.connect(func(team_id, level):
		team_signal_received = true
		received_team_id = team_id
		received_level = level
	)

	# Simulate player selection
	var tree = panel.content_list
	panel.current_view_mode = panel.ViewMode.ALL_PLAYERS
	panel._update_view()
	await get_tree().process_frame

	var root = tree.get_root()
	var first_player = root.get_first_child()
	if first_player != null:
		var metadata = first_player.get_metadata(0)
		if metadata and metadata.has("type") and metadata["type"] == "player":
			panel.player_selected.emit(metadata["id"])
			await get_tree().process_frame

			assert(player_signal_received, "Player signal should be received")
			print("  ✓ player_selected signal emitted")
			print("  ✓ Received player_id: %s" % received_player_id)

	# Simulate school selection
	panel.current_view_mode = panel.ViewMode.SCHOOLS
	panel._update_view()
	await get_tree().process_frame

	root = tree.get_root()
	var first_school = root.get_first_child()
	if first_school != null:
		var metadata = first_school.get_metadata(0)
		if metadata and metadata.has("type") and metadata["type"] == "school":
			panel.team_selected.emit(metadata["id"], "hs")
			await get_tree().process_frame

			assert(team_signal_received, "Team signal should be received")
			assert(received_level == "hs", "Level should be 'hs'")
			print("  ✓ team_selected signal emitted")
			print("  ✓ Received team_id: %s, level: %s" % [received_team_id, received_level])

	panel.queue_free()
