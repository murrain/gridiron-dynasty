extends Control
class_name WorldExplorer

# Preload query utilities and formatters
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")
const PlayerDetailFormatter = preload("res://scripts/ui/world_explorer/formatters/PlayerDetailFormatter.gd")
const TeamDetailFormatter = preload("res://scripts/ui/world_explorer/formatters/TeamDetailFormatter.gd")

## World Explorer UI - Main entry point for exploring bootstrapped worlds
##
## Architecture:
## - Master-detail split layout (sidebar list + detail panel)
## - Tabbed navigation (NFL, College, HS, Draft, Retired)
## - Global search across all players
## - BBCode formatted detail views
##
## PANEL INTEGRATION GUIDE:
##
## Required Methods:
##   func initialize(world_state: Dictionary) -> void
##     Called when panel is added or refreshed.
##     world_state is READ-ONLY - do not modify it!
##
## Optional Methods:
##   func filter_by_search(search_text: String) -> void
##     Called when user types in search box.
##
##   func cleanup() -> void
##     Called before re-initialization (on refresh).
##     Use to free resources, clear caches, etc.
##
## Required Signals:
##   signal player_selected(player_id: String)
##     Emit when user clicks a player in your list.
##
##   signal team_selected(team_id: String, level: String)
##     Emit when user clicks a team/school in your list.
##
## Best Practices:
##   - Do NOT modify world_state (treat as immutable)
##   - Do NOT store reference to WorldExplorer
##   - Create local filtered copies if needed
##   - Emit signals for navigation, don't call methods directly
##   - Handle empty data gracefully (show placeholder text)

# Node references (exported for editor configuration)
@export var year_label_path: NodePath = NodePath("MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/YearLabel")
@export var refresh_button_path: NodePath = NodePath("MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/RefreshButton")
@export var search_field_path: NodePath = NodePath("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/SearchBox/SearchField")
@export var clear_button_path: NodePath = NodePath("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/SearchBox/ClearButton")
@export var detail_text_path: NodePath = NodePath("MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/DetailScroll/DetailText")
@export var tabs_path: NodePath = NodePath("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/NavigationTabs")

# Configuration
@export var config: WorldExplorerConfig = null

## World state reference (READ-ONLY - panels must not modify!)
## Panels should create local copies if they need to filter/sort
var world_state: Dictionary = {}

# Debug tracking for mutation detection
var _world_state_original_keys: Array = []

# Cached node references
var year_label: Label
var refresh_button: Button
var search_field: LineEdit
var clear_button: Button
var detail_text: RichTextLabel
var tabs: TabContainer

# Current selection state
var current_player_id: String = ""
var current_team_id: String = ""
var current_level: String = ""

func _ready() -> void:
	if config == null:
		config = WorldExplorerConfig.new()

	_cache_nodes()
	_connect_signals()
	_initialize_ui()

func _cache_nodes() -> void:
	year_label = get_node_or_null(year_label_path) as Label
	refresh_button = get_node_or_null(refresh_button_path) as Button
	search_field = get_node_or_null(search_field_path) as LineEdit
	clear_button = get_node_or_null(clear_button_path) as Button
	detail_text = get_node_or_null(detail_text_path) as RichTextLabel
	tabs = get_node_or_null(tabs_path) as TabContainer

	# Validate critical nodes
	var errors: Array[String] = []
	if detail_text == null:
		errors.append("DetailText node not found at path: %s" % detail_text_path)
	if tabs == null:
		errors.append("NavigationTabs node not found at path: %s" % tabs_path)

	if errors.size() > 0:
		push_error("WorldExplorer: Critical initialization errors:")
		for error in errors:
			push_error("  - " + error)

		# Show error in UI
		var error_label = Label.new()
		error_label.text = "WorldExplorer Initialization Failed:\n" + "\n".join(errors)
		error_label.add_theme_color_override("font_color", Color.RED)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		error_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(error_label)

		# Disable all functionality
		set_process(false)
		set_process_input(false)
		return

func _connect_signals() -> void:
	if search_field != null:
		search_field.text_changed.connect(_on_search_changed)

	if clear_button != null:
		clear_button.pressed.connect(_on_clear_search_pressed)

	if refresh_button != null:
		refresh_button.pressed.connect(_on_refresh_pressed)

	if tabs != null:
		tabs.tab_changed.connect(_on_tab_changed)

func _initialize_ui() -> void:
	if world_state.is_empty():
		_show_no_world_loaded()
		return

	_update_header()
	_show_welcome()
	_initialize_panels()

## Public API: Load world state and initialize UI
func load_world_state(ws: Dictionary) -> void:
	if not _validate_world_state(ws):
		push_error("WorldExplorer: Invalid world_state structure")
		_show_error_state("Invalid world state data")
		return

	# In debug builds, detect unintended mutations by tracking original keys
	if OS.is_debug_build():
		_world_state_original_keys = ws.keys().duplicate()

	world_state = ws
	_initialize_ui()

## Public API: Show player detail in right panel
func show_player_detail(player_id: String) -> void:
	if detail_text == null:
		return

	current_player_id = player_id
	current_team_id = ""

	detail_text.clear()

	# Find player in world state
	var player = PlayerQueries.get_player_by_id(world_state, player_id)
	if player == null:
		detail_text.append_text("[center][color=#ff0000]Player not found: %s[/color][/center]" % player_id)
		return

	# Format and display player details
	var formatted_text = PlayerDetailFormatter.format(player, world_state)
	detail_text.append_text(formatted_text)

## Public API: Show team/school detail in right panel
func show_team_detail(team_id: String, level: String) -> void:
	if detail_text == null:
		return

	current_team_id = team_id
	current_level = level
	current_player_id = ""

	detail_text.clear()

	# Find team/school in world state based on level
	var team: Variant = null
	match level.to_lower():
		"nfl":
			team = TeamQueries.get_nfl_team(world_state, team_id)
		"college":
			team = TeamQueries.get_college(world_state, team_id)
		"hs", "high_school":
			team = TeamQueries.get_hs_school(world_state, team_id)
		_:
			detail_text.append_text("[center][color=#ff0000]Unknown level: %s[/color][/center]" % level)
			return

	if team == null:
		detail_text.append_text("[center][color=#ff0000]%s not found: %s[/color][/center]" % [level.to_upper(), team_id])
		return

	# Format and display team details
	var formatted_text = TeamDetailFormatter.format(team, world_state, level)
	detail_text.append_text(formatted_text)

## Public API: Clear detail panel
func clear_detail() -> void:
	if detail_text == null:
		return

	_clear_selection_state()
	detail_text.clear()
	_show_welcome()

# Private methods

func _clear_selection_state() -> void:
	current_player_id = ""
	current_team_id = ""
	current_level = ""

func _update_header() -> void:
	if year_label == null:
		return

	var current_year = world_state.get("current_year", 2025)
	year_label.text = "Year: %d" % current_year

func _show_welcome() -> void:
	if detail_text == null:
		return

	detail_text.clear()
	var summary = _build_world_summary()
	detail_text.append_text(summary)

func _show_no_world_loaded() -> void:
	if detail_text == null:
		return

	detail_text.clear()
	detail_text.append_text("[center][font_size=18][color=#ff6600]No world loaded[/color][/font_size][/center]\n\n")
	detail_text.append_text("[center]Please run bootstrap first to generate a world.[/center]")

func _show_error_state(message: String) -> void:
	if detail_text == null:
		return

	detail_text.clear()
	detail_text.append_text("[center][font_size=18][color=#ff0000][b]Error[/b][/color][/font_size][/center]\n\n")
	detail_text.append_text("[center]%s[/center]" % message)
	detail_text.append_text("\n\n[center][color=#666666]Check the console for details[/color][/center]")

func _validate_world_state(ws: Dictionary) -> bool:
	# Check if null or empty
	if ws == null or ws.is_empty():
		push_error("WorldExplorer: world_state is null or empty")
		return false

	# Check required keys
	var required_keys = [
		"current_year",
		"nfl_teams",
		"nfl_rosters",
		"colleges",
		"college_rosters",
		"hs_schools",
		"hs_players",
		"draft_pool",
		"retired_players"
	]

	for key in required_keys:
		if not ws.has(key):
			push_error("WorldExplorer: Missing required key '%s'" % key)
			return false

	# Validate types of critical keys
	if not (ws["current_year"] is int):
		push_error("WorldExplorer: 'current_year' must be int, got %s" % typeof(ws["current_year"]))
		return false

	if not (ws["nfl_teams"] is Array):
		push_error("WorldExplorer: 'nfl_teams' must be Array, got %s" % typeof(ws["nfl_teams"]))
		return false

	if not (ws["nfl_rosters"] is Dictionary):
		push_error("WorldExplorer: 'nfl_rosters' must be Dictionary, got %s" % typeof(ws["nfl_rosters"]))
		return false

	if not (ws["colleges"] is Array):
		push_error("WorldExplorer: 'colleges' must be Array, got %s" % typeof(ws["colleges"]))
		return false

	if not (ws["college_rosters"] is Dictionary):
		push_error("WorldExplorer: 'college_rosters' must be Dictionary, got %s" % typeof(ws["college_rosters"]))
		return false

	if not (ws["hs_schools"] is Array):
		push_error("WorldExplorer: 'hs_schools' must be Array, got %s" % typeof(ws["hs_schools"]))
		return false

	if not (ws["hs_players"] is Array):
		push_error("WorldExplorer: 'hs_players' must be Array, got %s" % typeof(ws["hs_players"]))
		return false

	if not (ws["draft_pool"] is Dictionary):
		push_error("WorldExplorer: 'draft_pool' must be Dictionary, got %s" % typeof(ws["draft_pool"]))
		return false

	if not (ws["retired_players"] is Array):
		push_error("WorldExplorer: 'retired_players' must be Array, got %s" % typeof(ws["retired_players"]))
		return false

	return true

func _build_world_summary() -> String:
	var bb := ""
	bb += _format_summary_header()
	bb += _format_nfl_stats()
	bb += _format_college_stats()
	bb += _format_hs_stats()
	bb += _format_draft_stats()
	bb += _format_retired_stats()
	bb += _format_summary_footer()
	return bb

func _format_summary_header() -> String:
	var bb := ""
	bb += "[center][font_size=24][b]🏈 Gridiron Dynasty World Explorer[/b][/font_size][/center]\n\n"
	var current_year = world_state.get("current_year", 2025)
	bb += "[center][font_size=16]Current Year: [color=#66ff66]%d[/color][/font_size][/center]\n\n" % current_year
	bb += "[font_size=18][b]World Statistics[/b][/font_size]\n"
	bb += "[table=2]"
	return bb

func _format_nfl_stats() -> String:
	var bb := ""
	var nfl_teams = world_state.get("nfl_teams", [])
	var nfl_rosters = world_state.get("nfl_rosters", {})
	var nfl_player_count = 0
	for roster_data in nfl_rosters.values():
		nfl_player_count += roster_data.get("players", []).size()

	bb += "[cell][b]NFL Teams:[/b][/cell][cell][color=#66ff66]%d[/color][/cell]" % nfl_teams.size()
	bb += "[cell][b]NFL Players:[/b][/cell][cell][color=#66ff66]%d[/color][/cell]" % nfl_player_count
	return bb

func _format_college_stats() -> String:
	var bb := ""
	var colleges = world_state.get("colleges", [])
	var college_rosters = world_state.get("college_rosters", {})
	var college_player_count = 0
	for roster_data in college_rosters.values():
		college_player_count += roster_data.get("players", []).size()

	bb += "[cell][b]Colleges:[/b][/cell][cell][color=#ffff00]%d[/color][/cell]" % colleges.size()
	bb += "[cell][b]College Players:[/b][/cell][cell][color=#ffff00]%d[/color][/cell]" % college_player_count
	return bb

func _format_hs_stats() -> String:
	var bb := ""
	var hs_schools = world_state.get("hs_schools", [])
	var hs_players = world_state.get("hs_players", [])

	bb += "[cell][b]High Schools:[/b][/cell][cell][color=#ffaa00]%d[/color][/cell]" % hs_schools.size()
	bb += "[cell][b]HS Players:[/b][/cell][cell][color=#ffaa00]%d[/color][/cell]" % hs_players.size()
	return bb

func _format_draft_stats() -> String:
	var bb := ""
	var draft_pool = world_state.get("draft_pool", {})
	var draft_years = draft_pool.keys()
	draft_years.sort()
	var draft_count = 0
	for year in draft_years:
		draft_count += draft_pool[year].size()

	bb += "[cell][b]Draft Pool:[/b][/cell][cell][color=#00ffff]%d players[/color][/cell]" % draft_count
	return bb

func _format_retired_stats() -> String:
	var bb := ""
	var retired = world_state.get("retired_players", [])
	bb += "[cell][b]Retired Players:[/b][/cell][cell][color=#999999]%d[/color][/cell]" % retired.size()
	return bb

func _format_summary_footer() -> String:
	return "[/table]\n\n[center][font_size=14][color=#66ff66]Select a tab above to explore →[/color][/font_size][/center]"

func _initialize_panels() -> void:
	if tabs == null:
		return

	# Panels will be added by other tracks
	# This method will call initialize() on each panel once they exist
	for i in range(tabs.get_tab_count()):
		var panel = tabs.get_tab_control(i)
		if panel == null:
			continue

		# Clean up first if panel supports it
		if panel.has_method("cleanup"):
			panel.cleanup()

		# Initialize with only world_state (NOT self)
		if panel.has_method("initialize"):
			panel.initialize(world_state)

		# Connect panel signals to our handlers
		if panel.has_signal("player_selected"):
			if not panel.player_selected.is_connected(show_player_detail):
				panel.player_selected.connect(show_player_detail)

		if panel.has_signal("team_selected"):
			if not panel.team_selected.is_connected(show_team_detail):
				panel.team_selected.connect(show_team_detail)

# Signal handlers

func _on_search_changed(new_text: String) -> void:
	if tabs == null:
		return

	# Broadcast search to current tab panel
	var current_tab = tabs.get_current_tab_control()
	if current_tab != null and current_tab.has_method("filter_by_search"):
		current_tab.filter_by_search(new_text)

func _on_clear_search_pressed() -> void:
	if search_field != null:
		search_field.text = ""

func _on_refresh_pressed() -> void:
	_initialize_panels()
	clear_detail()

func _on_tab_changed(tab_index: int) -> void:
	# Clear search on tab change
	if search_field != null:
		search_field.text = ""

	# Clear selection state when switching tabs
	_clear_selection_state()

	# Show welcome message when switching tabs
	_show_welcome()
