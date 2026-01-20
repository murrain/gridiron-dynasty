extends Node
## Test script to verify WorldExplorer DataBus integration

func _ready() -> void:
	print("=== WorldExplorer DataBus Integration Tests ===\n")

	test_phase_mapping()
	test_collection_mapping()
	test_signal_connections()

	print("\n=== All DataBus Tests Complete ===")

func test_phase_mapping() -> void:
	print("TEST 1: Phase-to-Tab Mapping")

	var explorer = WorldExplorer.new()

	# Test High School phases -> HS tab (index 2)
	var hs_phases = ["hs_generation", "hs_assignment", "hs_season"]
	for phase_id in hs_phases:
		var tabs = explorer._get_tabs_affected_by_phase(phase_id)
		assert(tabs.size() == 1, "HS phase should affect 1 tab")
		assert(tabs[0] == 2, "HS phase should affect tab 2")
	print("  ✓ HS phases map to tab 2")

	# Test College phases -> College tab (index 1)
	var college_phases = ["college_generation", "college_recruiting", "college_season"]
	for phase_id in college_phases:
		var tabs = explorer._get_tabs_affected_by_phase(phase_id)
		assert(tabs.size() == 1, "College phase should affect 1 tab")
		assert(tabs[0] == 1, "College phase should affect tab 1")
	print("  ✓ College phases map to tab 1")

	# Test NFL phases -> NFL tab (index 0)
	var nfl_phases = ["nfl_team_generation", "roster_management", "nfl_free_agency", "nfl_season"]
	for phase_id in nfl_phases:
		var tabs = explorer._get_tabs_affected_by_phase(phase_id)
		assert(tabs.size() == 1, "NFL phase should affect 1 tab")
		assert(tabs[0] == 0, "NFL phase should affect tab 0")
	print("  ✓ NFL phases map to tab 0")

	# Test Draft phases -> Draft tab (index 3) + NFL tab (index 0)
	var draft_phases = ["draft_prep", "nfl_draft"]
	for phase_id in draft_phases:
		var tabs = explorer._get_tabs_affected_by_phase(phase_id)
		assert(tabs.size() == 2, "Draft phase should affect 2 tabs")
		assert(3 in tabs, "Draft phase should affect tab 3")
		assert(0 in tabs, "Draft phase should affect tab 0")
	print("  ✓ Draft phases map to tabs 3 and 0")

	# Test unknown phase
	var unknown_tabs = explorer._get_tabs_affected_by_phase("unknown_phase")
	assert(unknown_tabs.is_empty(), "Unknown phase should not affect any tabs")
	print("  ✓ Unknown phases return empty array")

	explorer.free()
	print("  ✓ Phase mapping tests passed\n")

func test_collection_mapping() -> void:
	print("TEST 2: Collection-to-Tab Mapping")

	var explorer = WorldExplorer.new()

	# Test HS collections -> HS tab (index 2)
	var hs_collections = ["hs_players", "hs_schools", "hs_recruit_pool"]
	for collection_name in hs_collections:
		var tabs = explorer._get_tabs_affected_by_collection(collection_name)
		assert(tabs.size() == 1, "HS collection should affect 1 tab")
		assert(tabs[0] == 2, "HS collection should affect tab 2")
	print("  ✓ HS collections map to tab 2")

	# Test College collections -> College tab (index 1)
	var college_collections = ["colleges", "college_rosters", "college_commitments", "college_classes"]
	for collection_name in college_collections:
		var tabs = explorer._get_tabs_affected_by_collection(collection_name)
		assert(tabs.size() == 1, "College collection should affect 1 tab")
		assert(tabs[0] == 1, "College collection should affect tab 1")
	print("  ✓ College collections map to tab 1")

	# Test NFL collections -> NFL tab (index 0)
	var nfl_collections = ["nfl_teams", "nfl_rosters", "free_agents"]
	for collection_name in nfl_collections:
		var tabs = explorer._get_tabs_affected_by_collection(collection_name)
		assert(tabs.size() == 1, "NFL collection should affect 1 tab")
		assert(tabs[0] == 0, "NFL collection should affect tab 0")
	print("  ✓ NFL collections map to tab 0")

	# Test Draft collections -> Draft tab (index 3)
	var draft_collections = ["draft_pool", "valuation_snapshots"]
	for collection_name in draft_collections:
		var tabs = explorer._get_tabs_affected_by_collection(collection_name)
		assert(tabs.size() == 1, "Draft collection should affect 1 tab")
		assert(tabs[0] == 3, "Draft collection should affect tab 3")
	print("  ✓ Draft collections map to tab 3")

	# Test Retired collections -> Retired tab (index 4)
	var tabs = explorer._get_tabs_affected_by_collection("retired_players")
	assert(tabs.size() == 1, "Retired collection should affect 1 tab")
	assert(tabs[0] == 4, "Retired collection should affect tab 4")
	print("  ✓ Retired collections map to tab 4")

	# Test unknown collection
	var unknown_tabs = explorer._get_tabs_affected_by_collection("unknown_collection")
	assert(unknown_tabs.is_empty(), "Unknown collection should not affect any tabs")
	print("  ✓ Unknown collections return empty array")

	explorer.free()
	print("  ✓ Collection mapping tests passed\n")

func test_signal_connections() -> void:
	print("TEST 3: DataBus Signal Connections")

	var explorer = WorldExplorer.new()

	# Call _connect_databus_signals
	explorer._connect_databus_signals()

	# Verify signals are connected
	assert(DataBus.phase_completed.is_connected(explorer._on_databus_phase_completed),
		"phase_completed signal should be connected")
	print("  ✓ phase_completed signal connected")

	assert(DataBus.collection_changed.is_connected(explorer._on_databus_collection_changed),
		"collection_changed signal should be connected")
	print("  ✓ collection_changed signal connected")

	assert(DataBus.world_state_loaded.is_connected(explorer._on_databus_world_state_loaded),
		"world_state_loaded signal should be connected")
	print("  ✓ world_state_loaded signal connected")

	# Test that calling connect again doesn't double-connect
	explorer._connect_databus_signals()

	# Count connections (should still be 1 each)
	var phase_connections = DataBus.phase_completed.get_connections()
	var phase_count = 0
	for conn in phase_connections:
		if conn["callable"].get_object() == explorer:
			phase_count += 1
	assert(phase_count == 1, "Should only have one connection after double-connect")
	print("  ✓ Double-connect protection works")

	explorer.free()
	print("  ✓ Signal connection tests passed\n")
