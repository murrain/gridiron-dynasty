extends VBoxContainer
class_name RetiredPanel

# Preload query utilities
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")

## Retired Panel for World Explorer
##
## Displays retired players with career summary information.
## Handles large datasets (5000+ players) with pagination.
##
## Features:
## - Pagination (100 players per page)
## - Sort by career length, peak rating, or name
## - Position filtering
## - Career summary display (years played, teams, peak rating)
## - Search filtering
##
## Emits signals when items are selected (handled by WorldExplorer)
## Does NOT modify world_state (read-only)

# Signals required by WorldExplorer
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

# Sort modes
enum SortMode {
	CAREER_LENGTH,  # Sort by years played
	PEAK_RATING,    # Sort by highest rating
	NAME            # Sort alphabetically
}

# Node references
@onready var position_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/PositionFilter
@onready var sort_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/SortFilter
@onready var content_list: Tree = $ContentPanel/ContentList
@onready var prev_page_button: Button = $PaginationBar/PrevPageButton
@onready var page_label: Label = $PaginationBar/PageLabel
@onready var next_page_button: Button = $PaginationBar/NextPageButton

# State
var world_state: Dictionary = {}
var current_position: String = "All"
var current_sort_mode: SortMode = SortMode.CAREER_LENGTH
var current_search: String = ""

# Pagination
var current_page: int = 0
var items_per_page: int = 100
var total_pages: int = 0
var filtered_players: Array = []

func _ready() -> void:
	_setup_filters()
	_connect_signals()

func _setup_filters() -> void:
	# Position filter
	position_filter.clear()
	position_filter.add_item("All")
	var positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
	for pos in positions:
		position_filter.add_item(pos)

	# Sort filter
	sort_filter.clear()
	sort_filter.add_item("Career Length", SortMode.CAREER_LENGTH)
	sort_filter.add_item("Peak Rating", SortMode.PEAK_RATING)
	sort_filter.add_item("Name", SortMode.NAME)

func _connect_signals() -> void:
	position_filter.item_selected.connect(_on_position_filter_changed)
	sort_filter.item_selected.connect(_on_sort_filter_changed)
	content_list.item_selected.connect(_on_tree_item_selected)
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)

## Public API: Initialize panel with world state
## Called by WorldExplorer when panel is added or refreshed
func initialize(ws: Dictionary) -> void:
	world_state = ws
	current_search = ""
	current_page = 0
	_refresh_content()

## Public API: Filter content by search text
## Called by WorldExplorer when search text changes
func filter_by_search(search_text: String) -> void:
	current_search = search_text.to_lower()
	current_page = 0  # Reset to first page when search changes
	_refresh_content()

## Optional: Cleanup before re-initialization
func cleanup() -> void:
	content_list.clear()
	filtered_players.clear()
	world_state = {}
	current_search = ""
	current_page = 0

# Private methods

func _refresh_content() -> void:
	if content_list == null:
		return

	# Get and filter retired players
	_filter_and_sort_players()

	# Update pagination
	_update_pagination()

	# Populate tree
	_populate_retired_players()

func _filter_and_sort_players() -> void:
	# Get all retired players
	var retired_players = PlayerQueries.get_retired_players(world_state)

	# Apply position filter
	if current_position != "All":
		retired_players = retired_players.filter(func(p):
			return p.get("position", "") == current_position
		)

	# Apply search filter
	if not current_search.is_empty():
		retired_players = retired_players.filter(func(p):
			var first = p.get("first_name", "").to_lower()
			var last = p.get("last_name", "").to_lower()
			var full = (first + " " + last).to_lower()
			return full.contains(current_search) or first.contains(current_search) or last.contains(current_search)
		)

	# Sort players based on current sort mode
	match current_sort_mode:
		SortMode.CAREER_LENGTH:
			retired_players.sort_custom(func(a, b):
				var length_a = _calculate_career_length(a)
				var length_b = _calculate_career_length(b)
				return length_a > length_b
			)
		SortMode.PEAK_RATING:
			retired_players.sort_custom(func(a, b):
				var rating_a = _get_peak_rating(a)
				var rating_b = _get_peak_rating(b)
				return rating_a > rating_b
			)
		SortMode.NAME:
			retired_players.sort_custom(func(a, b):
				var name_a = PlayerQueries.get_player_name(a).to_lower()
				var name_b = PlayerQueries.get_player_name(b).to_lower()
				return name_a < name_b
			)

	filtered_players = retired_players

func _update_pagination() -> void:
	# Calculate total pages
	total_pages = ceili(float(filtered_players.size()) / float(items_per_page))
	if total_pages == 0:
		total_pages = 1

	# Clamp current page
	current_page = clampi(current_page, 0, total_pages - 1)

	# Update pagination controls
	page_label.text = "Page %d of %d (%d players)" % [current_page + 1, total_pages, filtered_players.size()]
	prev_page_button.disabled = (current_page == 0)
	next_page_button.disabled = (current_page >= total_pages - 1)

func _populate_retired_players() -> void:
	content_list.clear()

	# Configure tree columns
	var root = content_list.create_item()
	content_list.set_column_titles_visible(true)
	content_list.columns = 5
	content_list.set_column_title(0, "Player")
	content_list.set_column_title(1, "Pos")
	content_list.set_column_title(2, "Career Years")
	content_list.set_column_title(3, "Teams")
	content_list.set_column_title(4, "Peak Rating")
	content_list.hide_root = true

	# Set column sizing
	content_list.set_column_expand(0, true)
	content_list.set_column_expand(1, false)
	content_list.set_column_expand(2, false)
	content_list.set_column_expand(3, true)
	content_list.set_column_expand(4, false)

	content_list.set_column_expand_ratio(0, 3)
	content_list.set_column_expand_ratio(1, 1)
	content_list.set_column_expand_ratio(2, 1)
	content_list.set_column_expand_ratio(3, 2)
	content_list.set_column_expand_ratio(4, 1)

	# Calculate page slice
	var start_idx = current_page * items_per_page
	var end_idx = mini(start_idx + items_per_page, filtered_players.size())

	# Display players for current page
	for i in range(start_idx, end_idx):
		var player = filtered_players[i]
		var item = content_list.create_item(root)

		# Player name
		var name = PlayerQueries.get_player_name(player)
		item.set_text(0, name)

		# Position
		var pos = player.get("position", "?")
		item.set_text(1, pos)

		# Career years
		var career_length = _calculate_career_length(player)
		var career_text = _format_career_years(player, career_length)
		item.set_text(2, career_text)

		# Teams
		var teams_text = _format_teams_played(player)
		item.set_text(3, teams_text)

		# Peak rating
		var peak_rating = _get_peak_rating(player)
		item.set_text(4, "%.0f" % peak_rating)
		var rating_color = StatQueries.get_stat_color(peak_rating)
		item.set_custom_color(4, rating_color)

		# Store metadata for selection handling
		var player_id = PlayerQueries.get_player_id(player)
		item.set_metadata(0, {"type": "player", "id": player_id})

# Utility functions

func _calculate_career_length(player: Dictionary) -> int:
	# Check for explicit career start/end years
	var start_year = player.get("career_start_year", 0)
	var end_year = player.get("career_end_year", 0)

	if start_year > 0 and end_year > 0:
		return end_year - start_year + 1

	# Fallback: Check if player has career_length field
	if player.has("career_length"):
		return player.get("career_length", 0)

	# Fallback: estimate from age (assume retirement age 35, draft age 22)
	var age = player.get("age", 0)
	if age >= 35:
		# Rough estimate: retired players likely played for some years
		return mini(age - 22, 15)  # Cap at 15 years

	return 0  # Unknown

func _format_career_years(player: Dictionary, career_length: int) -> String:
	var start_year = player.get("career_start_year", 0)
	var end_year = player.get("career_end_year", 0)

	if start_year > 0 and end_year > 0:
		return "%d-%d (%d yrs)" % [start_year, end_year, career_length]

	if career_length > 0:
		return "%d yrs" % career_length

	return "N/A"

func _format_teams_played(player: Dictionary) -> String:
	# Check if player has career_teams array
	var career_teams = player.get("career_teams", [])

	if career_teams.is_empty():
		# Fallback: check current team
		var nfl_team_id = player.get("nfl_team_id", "")
		if not nfl_team_id.is_empty():
			var team = TeamQueries.get_nfl_team(world_state, nfl_team_id)
			if team:
				return team.get("name", "Unknown")

		# Check last NFL team
		var last_nfl_team_id = player.get("last_nfl_team_id", "")
		if not last_nfl_team_id.is_empty():
			var team = TeamQueries.get_nfl_team(world_state, last_nfl_team_id)
			if team:
				return team.get("name", "Unknown")

		return "N/A"

	# Format team names (abbreviate if more than 3 teams)
	if career_teams.size() <= 3:
		var team_names: Array = []
		for team_id in career_teams:
			var team = TeamQueries.get_nfl_team(world_state, team_id)
			if team:
				team_names.append(team.get("abbreviation", team.get("name", "?")))
		return ", ".join(team_names) if team_names.size() > 0 else "N/A"
	else:
		# Show first team and count
		var first_team = TeamQueries.get_nfl_team(world_state, career_teams[0])
		var first_name = first_team.get("abbreviation", "?") if first_team else "?"
		return "%s (+%d more)" % [first_name, career_teams.size() - 1]

func _get_peak_rating(player: Dictionary) -> float:
	# Check if player has explicit peak_rating field
	if player.has("peak_rating"):
		return player.get("peak_rating", 0.0)

	# Fallback: use current composite rating as approximation
	# (retired players may have declined from peak)
	return StatQueries.calculate_composite_rating(player)

# Signal handlers

func _on_position_filter_changed(index: int) -> void:
	current_position = position_filter.get_item_text(index)
	current_page = 0  # Reset to first page
	_refresh_content()

func _on_sort_filter_changed(index: int) -> void:
	current_sort_mode = sort_filter.get_item_id(index) as SortMode
	current_page = 0  # Reset to first page
	_refresh_content()

func _on_tree_item_selected() -> void:
	var selected = content_list.get_selected()
	if selected == null:
		return

	var metadata = selected.get_metadata(0)
	if metadata == null or not metadata is Dictionary:
		return

	match metadata.get("type", ""):
		"player":
			player_selected.emit(metadata.get("id", ""))

func _on_prev_page_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		_refresh_content()

func _on_next_page_pressed() -> void:
	if current_page < total_pages - 1:
		current_page += 1
		_refresh_content()
