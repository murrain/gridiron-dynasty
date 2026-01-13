extends VBoxContainer
class_name NflPanel

# Preload query utilities
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")

## NFL exploration panel
## Displays teams and players with multiple view modes and filtering
##
## This panel provides three view modes:
## 1. TEAMS - List all 32 NFL teams with roster and cap space info
## 2. PLAYERS_BY_POSITION - Hierarchical tree grouped by position (top 20 per position)
## 3. ALL_PLAYERS - Flat list with position filter (limited to top 500 by rating)
##
## Emits signals when items are selected (handled by WorldExplorer)
## Does NOT modify world_state (read-only)

# Signals required by WorldExplorer
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

# Node references
@export var view_mode_button_path: NodePath = NodePath("FilterBarPanel/MarginContainer/FilterBar/ViewModeButton")
@export var position_filter_path: NodePath = NodePath("FilterBarPanel/MarginContainer/FilterBar/PositionFilter")
@export var position_label_path: NodePath = NodePath("FilterBarPanel/MarginContainer/FilterBar/PositionLabel")
@export var content_list_path: NodePath = NodePath("ContentPanel/ContentList")

var view_mode_button: OptionButton
var position_filter: OptionButton
var position_label: Label
var content_list: Tree

# View modes
enum ViewMode { TEAMS, PLAYERS_BY_POSITION, ALL_PLAYERS }
var current_view_mode: ViewMode = ViewMode.TEAMS
var current_position: String = "All"

# World state reference (READ-ONLY)
var world_state: Dictionary = {}

# Search state
var current_search: String = ""

func _ready() -> void:
	_cache_nodes()
	_setup_filters()
	_connect_signals()

func _cache_nodes() -> void:
	view_mode_button = get_node(view_mode_button_path) as OptionButton
	position_filter = get_node(position_filter_path) as OptionButton
	position_label = get_node(position_label_path) as Label
	content_list = get_node(content_list_path) as Tree

func _setup_filters() -> void:
	# View mode dropdown
	view_mode_button.clear()
	view_mode_button.add_item("Teams", ViewMode.TEAMS)
	view_mode_button.add_item("Players by Position", ViewMode.PLAYERS_BY_POSITION)
	view_mode_button.add_item("All Players", ViewMode.ALL_PLAYERS)

	# Position filter
	position_filter.clear()
	position_filter.add_item("All")
	var positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
	for pos in positions:
		position_filter.add_item(pos)

	# Initially hidden (only shown in ALL_PLAYERS mode)
	position_filter.visible = false
	position_label.visible = false

func _connect_signals() -> void:
	if not view_mode_button.item_selected.is_connected(_on_view_mode_changed):
		view_mode_button.item_selected.connect(_on_view_mode_changed)
	if not position_filter.item_selected.is_connected(_on_position_filter_changed):
		position_filter.item_selected.connect(_on_position_filter_changed)
	if not content_list.item_selected.is_connected(_on_tree_item_selected):
		content_list.item_selected.connect(_on_tree_item_selected)

## Public API: Initialize panel with world state
## Called by WorldExplorer when panel is added or refreshed
func initialize(ws: Dictionary) -> void:
	world_state = ws
	current_search = ""
	_refresh_content()

## Public API: Filter content by search text
## Called by WorldExplorer when search text changes
func filter_by_search(search_text: String) -> void:
	current_search = search_text.to_lower()
	_refresh_content()

## Optional: Cleanup before re-initialization
func cleanup() -> void:
	content_list.clear()
	world_state = {}
	current_search = ""

# Private methods

func _refresh_content() -> void:
	if content_list == null:
		return

	content_list.clear()

	match current_view_mode:
		ViewMode.TEAMS:
			_populate_teams()
		ViewMode.PLAYERS_BY_POSITION:
			_populate_players_by_position()
		ViewMode.ALL_PLAYERS:
			_populate_all_players()

## TEAMS VIEW MODE
## Displays all 32 NFL teams with roster size and cap space
func _populate_teams() -> void:
	var root = content_list.create_item()
	content_list.set_column_titles_visible(true)
	content_list.columns = 4
	content_list.set_column_title(0, "Team")
	content_list.set_column_title(1, "Region")
	content_list.set_column_title(2, "Roster")
	content_list.set_column_title(3, "Cap Space")
	content_list.hide_root = true

	var nfl_teams = world_state.get("nfl_teams", [])

	# Filter by search if active
	if not current_search.is_empty():
		nfl_teams = nfl_teams.filter(func(t):
			return t.get("name", "").to_lower().contains(current_search)
		)

	# Sort by name
	nfl_teams.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))

	for team in nfl_teams:
		var item = content_list.create_item(root)
		item.set_text(0, team.get("name", "Unknown"))
		item.set_text(1, team.get("region", "N/A").capitalize().replace("_", " "))

		var roster_size = TeamQueries.get_roster_size(world_state, team.get("id", ""), "nfl")
		item.set_text(2, str(roster_size))

		var cap_space = team.get("cap_space", 0.0)
		var cap_text = "$%.1fM" % cap_space
		# Scale cap space (0-20M range) to 0-100 for color calculation
		var cap_normalized = clampf(cap_space * 5.0, 0.0, 100.0)
		var cap_color = StatQueries.get_stat_color(cap_normalized)
		item.set_text(3, cap_text)
		item.set_custom_color(3, cap_color)

		# Store metadata for selection handling
		item.set_metadata(0, {"type": "team", "id": team.get("id", "")})

## ALL PLAYERS VIEW MODE
## Displays flat list of NFL players with position filter
## Limited to top 500 by rating for performance
func _populate_all_players() -> void:
	var root = content_list.create_item()
	content_list.set_column_titles_visible(true)
	content_list.columns = 4
	content_list.set_column_title(0, "Player")
	content_list.set_column_title(1, "Pos")
	content_list.set_column_title(2, "Rating")
	content_list.set_column_title(3, "Team")
	content_list.hide_root = true

	var all_players = PlayerQueries.get_all_nfl_players(world_state)

	# Filter by position
	if current_position != "All":
		all_players = PlayerQueries.get_players_by_position(all_players, current_position)

	# Filter by search
	if not current_search.is_empty():
		# Search in name
		var matches = func(p: Dictionary) -> bool:
			# Handle both name formats: separate first/last or combined name field
			var search_text := ""
			if p.has("first_name") or p.has("last_name"):
				var first = p.get("first_name", "").to_lower()
				var last = p.get("last_name", "").to_lower()
				search_text = (first + " " + last).to_lower()
			elif p.has("name"):
				search_text = p.get("name", "").to_lower()
			return search_text.contains(current_search)

		all_players = all_players.filter(matches)

	# Sort by rating descending
	all_players = PlayerQueries.sort_players_by_rating(all_players, false)

	# Limit to top 500 for performance
	all_players = all_players.slice(0, mini(500, all_players.size()))

	for player in all_players:
		var item = content_list.create_item(root)
		var name = PlayerQueries.get_player_name(player)
		item.set_text(0, name)
		item.set_text(1, player.get("position", "?"))

		var rating = StatQueries.calculate_composite_rating(player)
		item.set_text(2, "%.0f" % rating)
		item.set_custom_color(2, StatQueries.get_stat_color(rating))

		var team_id = player.get("nfl_team_id", "")
		var team = TeamQueries.get_nfl_team(world_state, team_id)
		item.set_text(3, team.get("name", "Free Agent") if team else "Free Agent")

		# Store metadata for selection handling
		var pid = PlayerQueries.get_player_id(player)
		item.set_metadata(0, {"type": "player", "id": pid})

## PLAYERS BY POSITION VIEW MODE
## Displays hierarchical tree grouped by position
## Shows top 20 players per position
func _populate_players_by_position() -> void:
	var root = content_list.create_item()
	root.set_text(0, "NFL Players by Position")
	content_list.hide_root = true
	content_list.columns = 3
	content_list.set_column_titles_visible(true)
	content_list.set_column_title(0, "Player")
	content_list.set_column_title(1, "Rating")
	content_list.set_column_title(2, "Team")

	var all_players = PlayerQueries.get_all_nfl_players(world_state)

	# Filter by search
	if not current_search.is_empty():
		var matches = func(p: Dictionary) -> bool:
			# Handle both name formats: separate first/last or combined name field
			var search_text := ""
			if p.has("first_name") or p.has("last_name"):
				var first = p.get("first_name", "").to_lower()
				var last = p.get("last_name", "").to_lower()
				search_text = (first + " " + last).to_lower()
			elif p.has("name"):
				search_text = p.get("name", "").to_lower()
			return search_text.contains(current_search)

		all_players = all_players.filter(matches)

	var players_by_pos: Dictionary = {}

	# Group by position
	for player in all_players:
		var pos = player.get("position", "Unknown")
		if not players_by_pos.has(pos):
			players_by_pos[pos] = []
		players_by_pos[pos].append(player)

	# Create position headers
	var positions = players_by_pos.keys()
	positions.sort()

	for pos in positions:
		var pos_item = content_list.create_item(root)
		pos_item.set_text(0, "%s (%d players)" % [pos, players_by_pos[pos].size()])
		pos_item.set_selectable(0, false)
		pos_item.set_custom_bg_color(0, Color(0.2, 0.2, 0.3))

		# Sort players by rating
		var players = PlayerQueries.sort_players_by_rating(players_by_pos[pos], false)

		# Add top 20 per position (or all if less than 20)
		var display_count = mini(20, players.size())
		for i in range(display_count):
			var player = players[i]
			var item = content_list.create_item(pos_item)
			var name = PlayerQueries.get_player_name(player)
			item.set_text(0, "  " + name)

			var rating = StatQueries.calculate_composite_rating(player)
			item.set_text(1, "%.0f" % rating)
			item.set_custom_color(1, StatQueries.get_stat_color(rating))

			var team_id = player.get("nfl_team_id", "")
			var team = TeamQueries.get_nfl_team(world_state, team_id)
			item.set_text(2, team.get("name", "FA") if team else "FA")

			# Store metadata for selection handling
			var pid = PlayerQueries.get_player_id(player)
			item.set_metadata(0, {"type": "player", "id": pid})

# Signal handlers

func _on_view_mode_changed(index: int) -> void:
	current_view_mode = view_mode_button.get_item_id(index) as ViewMode

	# Show/hide position filter based on view mode
	var show_position_filter = (current_view_mode == ViewMode.ALL_PLAYERS)
	position_filter.visible = show_position_filter
	position_label.visible = show_position_filter

	_refresh_content()

func _on_position_filter_changed(index: int) -> void:
	current_position = position_filter.get_item_text(index)
	_refresh_content()

func _on_tree_item_selected() -> void:
	var selected = content_list.get_selected()
	if selected == null:
		return

	var metadata = selected.get_metadata(0)
	if metadata == null or not metadata is Dictionary:
		return

	match metadata.get("type", ""):
		"team":
			team_selected.emit(metadata.get("id", ""), "nfl")
		"player":
			player_selected.emit(metadata.get("id", ""))
