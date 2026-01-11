extends Control
class_name TestNflPanel

## Test script for NFL Panel integration
## This creates a mock world state with realistic NFL data and loads it into the WorldExplorer

@onready var world_explorer: WorldExplorer = $WorldExplorer

func _ready() -> void:
	# Wait one frame for WorldExplorer to initialize
	await get_tree().process_frame

	# Load the NFL panel into the tabs
	_add_nfl_panel_to_tabs()

	# Load a mock world state for testing
	var mock_world = _create_realistic_mock_world()
	world_explorer.load_world_state(mock_world)

	print("NFL Panel Test loaded successfully")
	print("- World state loaded with %d NFL teams" % mock_world.nfl_teams.size())
	print("- Total NFL players: %d" % _count_nfl_players(mock_world))
	print("- NFL tab should be visible with all three view modes working")

func _add_nfl_panel_to_tabs() -> void:
	"""Dynamically add NFL panel to the TabContainer"""
	var tabs = world_explorer.get_node("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/NavigationTabs") as TabContainer
	if tabs == null:
		push_error("Could not find NavigationTabs")
		return

	# Load the NFL panel scene
	var nfl_panel_scene = load("res://scenes/ui/world_explorer/panels/nfl_panel.tscn")
	if nfl_panel_scene == null:
		push_error("Could not load nfl_panel.tscn")
		return

	var nfl_panel = nfl_panel_scene.instantiate()
	nfl_panel.name = "NFL"
	tabs.add_child(nfl_panel)

	print("NFL Panel added to tabs successfully")

func _count_nfl_players(world: Dictionary) -> int:
	"""Count total NFL players across all rosters"""
	var count = 0
	var nfl_rosters = world.get("nfl_rosters", {})
	for roster_data in nfl_rosters.values():
		count += roster_data.get("players", []).size()
	return count

func _create_realistic_mock_world() -> Dictionary:
	"""Create a realistic mock world state with full NFL data"""
	var world := {}

	world["current_year"] = 2025

	# Create all 32 NFL teams with realistic data
	world["nfl_teams"] = _create_nfl_teams()
	world["nfl_rosters"] = _create_nfl_rosters()

	# Mock college data
	world["colleges"] = [
		{"id": "ALA", "name": "Alabama"},
		{"id": "OSU", "name": "Ohio State"},
		{"id": "UGA", "name": "Georgia"},
	]

	world["college_rosters"] = {
		"ALA": {"players": []},
		"OSU": {"players": []},
		"UGA": {"players": []},
	}

	# Mock HS data
	world["hs_schools"] = [
		{"id": "hs1", "name": "Central High"},
		{"id": "hs2", "name": "East High"},
	]

	world["hs_players"] = []

	# Mock draft pool
	world["draft_pool"] = {
		2025: [],
		2026: [],
	}

	# Mock retired players
	world["retired_players"] = []

	return world

func _create_nfl_teams() -> Array:
	"""Create all 32 NFL teams with cap space"""
	return [
		# AFC East
		{"id": "BUF", "name": "Buffalo Bills", "region": "northeast", "cap_space": 15.3},
		{"id": "MIA", "name": "Miami Dolphins", "region": "southeast", "cap_space": 8.7},
		{"id": "NE", "name": "New England Patriots", "region": "northeast", "cap_space": 22.1},
		{"id": "NYJ", "name": "New York Jets", "region": "northeast", "cap_space": 12.4},

		# AFC North
		{"id": "BAL", "name": "Baltimore Ravens", "region": "mid_atlantic", "cap_space": 6.2},
		{"id": "CIN", "name": "Cincinnati Bengals", "region": "midwest", "cap_space": 11.8},
		{"id": "CLE", "name": "Cleveland Browns", "region": "midwest", "cap_space": 3.5},
		{"id": "PIT", "name": "Pittsburgh Steelers", "region": "mid_atlantic", "cap_space": 9.1},

		# AFC South
		{"id": "HOU", "name": "Houston Texans", "region": "south", "cap_space": 18.6},
		{"id": "IND", "name": "Indianapolis Colts", "region": "midwest", "cap_space": 14.2},
		{"id": "JAX", "name": "Jacksonville Jaguars", "region": "southeast", "cap_space": 19.8},
		{"id": "TEN", "name": "Tennessee Titans", "region": "south", "cap_space": 7.3},

		# AFC West
		{"id": "DEN", "name": "Denver Broncos", "region": "mountain", "cap_space": 10.5},
		{"id": "KC", "name": "Kansas City Chiefs", "region": "midwest", "cap_space": 4.1},
		{"id": "LV", "name": "Las Vegas Raiders", "region": "mountain", "cap_space": 16.9},
		{"id": "LAC", "name": "Los Angeles Chargers", "region": "west", "cap_space": 13.7},

		# NFC East
		{"id": "DAL", "name": "Dallas Cowboys", "region": "south", "cap_space": 5.8},
		{"id": "NYG", "name": "New York Giants", "region": "northeast", "cap_space": 17.2},
		{"id": "PHI", "name": "Philadelphia Eagles", "region": "mid_atlantic", "cap_space": 8.9},
		{"id": "WAS", "name": "Washington Commanders", "region": "mid_atlantic", "cap_space": 11.3},

		# NFC North
		{"id": "CHI", "name": "Chicago Bears", "region": "midwest", "cap_space": 20.4},
		{"id": "DET", "name": "Detroit Lions", "region": "midwest", "cap_space": 6.7},
		{"id": "GB", "name": "Green Bay Packers", "region": "midwest", "cap_space": 9.8},
		{"id": "MIN", "name": "Minnesota Vikings", "region": "midwest", "cap_space": 12.1},

		# NFC South
		{"id": "ATL", "name": "Atlanta Falcons", "region": "southeast", "cap_space": 15.6},
		{"id": "CAR", "name": "Carolina Panthers", "region": "southeast", "cap_space": 21.3},
		{"id": "NO", "name": "New Orleans Saints", "region": "south", "cap_space": 2.9},
		{"id": "TB", "name": "Tampa Bay Buccaneers", "region": "southeast", "cap_space": 7.5},

		# NFC West
		{"id": "ARI", "name": "Arizona Cardinals", "region": "mountain", "cap_space": 14.8},
		{"id": "LAR", "name": "Los Angeles Rams", "region": "west", "cap_space": 4.6},
		{"id": "SF", "name": "San Francisco 49ers", "region": "west", "cap_space": 8.2},
		{"id": "SEA", "name": "Seattle Seahawks", "region": "west", "cap_space": 10.9},
	]

func _create_nfl_rosters() -> Dictionary:
	"""Create rosters for all teams with realistic player data"""
	var rosters := {}

	# For testing, create a few teams with full rosters
	rosters["KC"] = {"players": _create_chiefs_roster()}
	rosters["BUF"] = {"players": _create_bills_roster()}
	rosters["SF"] = {"players": _create_49ers_roster()}

	# For other teams, create minimal rosters
	var team_ids = ["MIA", "NE", "NYJ", "BAL", "CIN", "CLE", "PIT", "HOU", "IND", "JAX",
	                "TEN", "DEN", "LV", "LAC", "DAL", "NYG", "PHI", "WAS", "CHI", "DET",
	                "GB", "MIN", "ATL", "CAR", "NO", "TB", "ARI", "LAR", "SEA"]

	for team_id in team_ids:
		rosters[team_id] = {"players": _create_generic_roster(team_id)}

	return rosters

func _create_chiefs_roster() -> Array:
	"""Create Kansas City Chiefs roster with star players"""
	return [
		_create_player("p1", "Patrick", "Mahomes", "QB", "KC", 98),
		_create_player("p2", "Travis", "Kelce", "TE", "KC", 95),
		_create_player("p3", "Chris", "Jones", "DL", "KC", 94),
		_create_player("p4", "Rashee", "Rice", "WR", "KC", 82),
		_create_player("p5", "Isiah", "Pacheco", "RB", "KC", 78),
		_create_player("p6", "Nick", "Bolton", "LB", "KC", 81),
		_create_player("p7", "Trent", "McDuffie", "CB", "KC", 85),
		_create_player("p8", "Justin", "Reid", "S", "KC", 83),
		_create_player("p9", "Orlando", "Brown", "OL", "KC", 80),
		_create_player("p10", "Creed", "Humphrey", "OL", "KC", 92),
	]

func _create_bills_roster() -> Array:
	"""Create Buffalo Bills roster with star players"""
	return [
		_create_player("p11", "Josh", "Allen", "QB", "BUF", 97),
		_create_player("p12", "Stefon", "Diggs", "WR", "BUF", 93),
		_create_player("p13", "Von", "Miller", "DL", "BUF", 88),
		_create_player("p14", "Matt", "Milano", "LB", "BUF", 87),
		_create_player("p15", "James", "Cook", "RB", "BUF", 79),
		_create_player("p16", "Dion", "Dawkins", "OL", "BUF", 84),
		_create_player("p17", "Mitch", "Morse", "OL", "BUF", 82),
		_create_player("p18", "Tre", "White", "CB", "BUF", 90),
		_create_player("p19", "Jordan", "Poyer", "S", "BUF", 86),
		_create_player("p20", "Dawson", "Knox", "TE", "BUF", 76),
	]

func _create_49ers_roster() -> Array:
	"""Create San Francisco 49ers roster with star players"""
	return [
		_create_player("p21", "Brock", "Purdy", "QB", "SF", 88),
		_create_player("p22", "Christian", "McCaffrey", "RB", "SF", 96),
		_create_player("p23", "Nick", "Bosa", "DL", "SF", 97),
		_create_player("p24", "Fred", "Warner", "LB", "SF", 98),
		_create_player("p25", "Trent", "Williams", "OL", "SF", 99),
		_create_player("p26", "Deebo", "Samuel", "WR", "SF", 91),
		_create_player("p27", "George", "Kittle", "TE", "SF", 94),
		_create_player("p28", "Javon", "Hargrave", "DL", "SF", 89),
		_create_player("p29", "Charvarius", "Ward", "CB", "SF", 85),
		_create_player("p30", "Talanoa", "Hufanga", "S", "SF", 87),
	]

func _create_generic_roster(team_id: String) -> Array:
	"""Create a generic roster with random players"""
	var roster := []
	var positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
	var first_names = ["John", "Mike", "Chris", "David", "James", "Robert", "Daniel", "Ryan", "Brandon", "Justin"]
	var last_names = ["Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor"]

	var base_id = team_id.hash()
	for i in range(15):  # 15 players per team for generic rosters
		var pos = positions[i % positions.size()]
		var first = first_names[randi() % first_names.size()]
		var last = last_names[randi() % last_names.size()]
		var rating = randf_range(60.0, 85.0)
		var pid = "%s_%d" % [team_id, base_id + i]
		roster.append(_create_player(pid, first, last, pos, team_id, rating))

	return roster

func _create_player(pid: String, first: String, last: String, pos: String, team: String, rating: float) -> Dictionary:
	"""Create a player dictionary with stats"""
	var stats := {}

	# Generate stats based on position
	match pos:
		"QB":
			stats = {
				"throw_power": rating + randf_range(-5, 5),
				"throw_accuracy": rating + randf_range(-3, 3),
				"awareness": rating + randf_range(-2, 2),
				"decision_making": rating + randf_range(-4, 4),
				"speed": rating * 0.7,
			}
		"RB":
			stats = {
				"speed": rating + randf_range(-3, 3),
				"agility": rating + randf_range(-2, 2),
				"strength": rating * 0.85,
				"vision": rating + randf_range(-4, 4),
				"catching": rating * 0.75,
			}
		"WR":
			stats = {
				"speed": rating + randf_range(-2, 2),
				"route_running": rating + randf_range(-3, 3),
				"catching": rating + randf_range(-2, 2),
				"awareness": rating * 0.85,
				"agility": rating + randf_range(-4, 4),
			}
		"TE":
			stats = {
				"catching": rating + randf_range(-3, 3),
				"route_running": rating * 0.85,
				"blocking": rating + randf_range(-4, 4),
				"strength": rating + randf_range(-2, 2),
				"awareness": rating * 0.8,
			}
		"OL":
			stats = {
				"strength": rating + randf_range(-2, 2),
				"blocking": rating + randf_range(-3, 3),
				"awareness": rating + randf_range(-4, 4),
				"technique": rating + randf_range(-2, 2),
				"agility": rating * 0.7,
			}
		"DL":
			stats = {
				"strength": rating + randf_range(-3, 3),
				"speed": rating * 0.8,
				"tackling": rating + randf_range(-2, 2),
				"technique": rating + randf_range(-4, 4),
				"awareness": rating * 0.85,
			}
		"LB":
			stats = {
				"speed": rating * 0.85,
				"tackling": rating + randf_range(-3, 3),
				"awareness": rating + randf_range(-2, 2),
				"coverage": rating + randf_range(-4, 4),
				"strength": rating * 0.8,
			}
		"CB":
			stats = {
				"speed": rating + randf_range(-2, 2),
				"coverage": rating + randf_range(-3, 3),
				"awareness": rating + randf_range(-2, 2),
				"agility": rating + randf_range(-4, 4),
				"tackling": rating * 0.75,
			}
		"S":
			stats = {
				"speed": rating + randf_range(-3, 3),
				"coverage": rating + randf_range(-2, 2),
				"tackling": rating + randf_range(-4, 4),
				"awareness": rating + randf_range(-2, 2),
				"agility": rating * 0.85,
			}
		"K", "P":
			stats = {
				"kick_power": rating + randf_range(-5, 5),
				"kick_accuracy": rating + randf_range(-3, 3),
			}

	return {
		"id": pid,
		"player_id": pid,
		"first_name": first,
		"last_name": last,
		"position": pos,
		"nfl_team_id": team,
		"stats": stats,
	}

func _input(event: InputEvent) -> void:
	"""Test keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				print("Testing refresh...")
				world_explorer.clear_detail()
			KEY_1:
				print("Testing player detail...")
				world_explorer.show_player_detail("p1")
			KEY_2:
				print("Testing team detail...")
				world_explorer.show_team_detail("KC", "nfl")
			KEY_3:
				print("Testing clear detail...")
				world_explorer.clear_detail()
