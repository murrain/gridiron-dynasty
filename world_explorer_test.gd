extends Control

## Test script for WorldExplorer UI
## This demonstrates how to load world state and test the UI

@onready var world_explorer: WorldExplorer = $WorldExplorer

func _ready() -> void:
	# Wait one frame for WorldExplorer to initialize
	await get_tree().process_frame

	# Integrate all panels into the WorldExplorer
	_integrate_panels()

	# Load a mock world state for testing
	var mock_world = _create_mock_world_state()
	world_explorer.load_world_state(mock_world)

	print("World Explorer Test loaded successfully")
	print("- World state loaded with %d NFL teams" % mock_world.nfl_teams.size())
	print("- World state loaded with %d colleges" % mock_world.colleges.size())
	print("- 5 panels integrated (NFL, College, HS, Draft, Retired)")
	print("- Welcome screen should be visible in detail panel")

func _integrate_panels() -> void:
	"""Add all panel scenes to the WorldExplorer TabContainer"""
	# Get NavigationTabs from WorldExplorer
	var tabs = world_explorer.get_node_or_null("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/NavigationTabs")

	if tabs == null:
		push_error("Could not find NavigationTabs in WorldExplorer")
		return

	# Clear any existing children
	for child in tabs.get_children():
		child.queue_free()

	# Add all panels in order
	_add_panel(tabs, "res://scenes/ui/world_explorer/panels/nfl_panel.tscn", "NFL")
	_add_panel(tabs, "res://scenes/ui/world_explorer/panels/college_panel.tscn", "College")
	_add_panel(tabs, "res://scenes/ui/world_explorer/panels/hs_panel.tscn", "High Schools")
	_add_panel(tabs, "res://scenes/ui/world_explorer/panels/draft_panel.tscn", "Draft")
	_add_panel(tabs, "res://scenes/ui/world_explorer/panels/retired_panel.tscn", "Retired")

	print("Integrated %d panels into WorldExplorer" % tabs.get_tab_count())

func _add_panel(tabs: TabContainer, scene_path: String, tab_name: String) -> void:
	"""Load and add a panel scene to the TabContainer"""
	var panel_scene = load(scene_path)
	if panel_scene == null:
		push_warning("Could not load panel scene: %s" % scene_path)
		return

	var panel = panel_scene.instantiate()
	tabs.add_child(panel)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tab_name)

func _create_mock_world_state() -> Dictionary:
	"""Create a minimal mock world state for testing"""
	var world := {}

	world["current_year"] = 2025

	# Mock NFL data
	world["nfl_teams"] = [
		{"id": "KC", "name": "Kansas City Chiefs"},
		{"id": "BUF", "name": "Buffalo Bills"},
		{"id": "SF", "name": "San Francisco 49ers"},
	]

	world["nfl_rosters"] = {
		"KC": {"players": ["p1", "p2", "p3"]},
		"BUF": {"players": ["p4", "p5", "p6"]},
		"SF": {"players": ["p7", "p8", "p9"]},
	}

	# Mock college data
	world["colleges"] = [
		{"id": "ALA", "name": "Alabama"},
		{"id": "OSU", "name": "Ohio State"},
		{"id": "UGA", "name": "Georgia"},
	]

	world["college_rosters"] = {
		"ALA": {"players": ["c1", "c2", "c3"]},
		"OSU": {"players": ["c4", "c5", "c6"]},
		"UGA": {"players": ["c7", "c8", "c9"]},
	}

	# Mock HS data
	world["hs_schools"] = [
		{"id": "hs1", "name": "Central High"},
		{"id": "hs2", "name": "East High"},
	]

	world["hs_players"] = ["h1", "h2", "h3", "h4", "h5"]

	# Mock draft pool
	world["draft_pool"] = {
		2025: ["d1", "d2", "d3"],
		2026: ["d4", "d5", "d6"],
	}

	# Mock retired players
	world["retired_players"] = ["r1", "r2", "r3"]

	return world

func _input(event: InputEvent) -> void:
	# Test keyboard shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				# Test refresh
				print("Testing refresh...")
				world_explorer.clear_detail()
			KEY_1:
				# Test player detail
				print("Testing player detail...")
				world_explorer.show_player_detail("test_player_123")
			KEY_2:
				# Test team detail
				print("Testing team detail...")
				world_explorer.show_team_detail("KC", "NFL")
			KEY_3:
				# Test clear
				print("Testing clear detail...")
				world_explorer.clear_detail()
