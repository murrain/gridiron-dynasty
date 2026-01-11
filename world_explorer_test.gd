extends Control

## Test script for WorldExplorer UI
## This demonstrates how to load world state and test the UI

@onready var world_explorer: WorldExplorer = $WorldExplorer

func _ready() -> void:
	# Wait one frame for WorldExplorer to initialize
	await get_tree().process_frame

	# Load a mock world state for testing
	var mock_world = _create_mock_world_state()
	world_explorer.load_world_state(mock_world)

	print("World Explorer Test loaded successfully")
	print("- World state loaded with %d NFL teams" % mock_world.nfl_teams.size())
	print("- World state loaded with %d colleges" % mock_world.colleges.size())
	print("- Welcome screen should be visible in detail panel")

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
