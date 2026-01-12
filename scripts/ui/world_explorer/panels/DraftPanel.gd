extends VBoxContainer
class_name DraftPanel

# Preload query utilities
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const DraftQueries = preload("res://scripts/ui/world_explorer/queries/DraftQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")

## Draft Panel for World Explorer
##
## Displays draft-eligible players with ranking and grade calculation.
## Shows top 200 prospects by default, with year and position filtering.
##
## Features:
## - Multi-year draft pool support
## - Draft grade calculation (0-100 composite rating)
## - Overall and positional rankings
## - Position filtering
## - School/team display
##
## Emits signals when items are selected (handled by WorldExplorer)
## Does NOT modify world_state (read-only)

# Signals required by WorldExplorer
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

# Node references
@onready var year_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/YearFilter
@onready var position_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/PositionFilter
@onready var content_list: Tree = $ContentPanel/ContentList

# State
var world_state: Dictionary = {}
var current_year: int = 0
var current_position: String = "All"
var current_search: String = ""

# Constants
const MAX_PROSPECTS_DISPLAYED = 200

func _ready() -> void:
	_setup_filters()
	_connect_signals()

func _setup_filters() -> void:
	# Year filter will be populated dynamically in initialize()
	year_filter.clear()

	# Position filter
	position_filter.clear()
	position_filter.add_item("All")
	var positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
	for pos in positions:
		position_filter.add_item(pos)

func _connect_signals() -> void:
	year_filter.item_selected.connect(_on_year_filter_changed)
	position_filter.item_selected.connect(_on_position_filter_changed)
	content_list.item_selected.connect(_on_tree_item_selected)

## Public API: Initialize panel with world state
## Called by WorldExplorer when panel is added or refreshed
func initialize(ws: Dictionary) -> void:
	world_state = ws
	current_search = ""
	_initialize_year_filter()
	_refresh_content()

## Public API: Filter content by search text
## Called by WorldExplorer when search text changes
func filter_by_search(search_text: String) -> void:
	current_search = search_text.to_lower()
	_refresh_content()

## Optional: Cleanup before re-initialization
func cleanup() -> void:
	content_list.clear()
	year_filter.clear()
	world_state = {}
	current_search = ""

# Private methods

func _initialize_year_filter() -> void:
	year_filter.clear()
	var years = DraftQueries.get_draft_years(world_state)

	if years.is_empty():
		push_warning("DraftPanel: No draft years available")
		return

	# Sort in descending order (most recent first)
	years.sort()
	years.reverse()

	for year in years:
		year_filter.add_item(str(year))

	# Select first year (most recent)
	if years.size() > 0:
		current_year = years[0]
		year_filter.select(0)

func _refresh_content() -> void:
	if content_list == null:
		return

	content_list.clear()
	_populate_draft_prospects()

func _populate_draft_prospects() -> void:
	# Configure tree columns
	var root = content_list.create_item()
	content_list.set_column_titles_visible(true)
	content_list.columns = 5
	content_list.set_column_title(0, "Rank")
	content_list.set_column_title(1, "Player")
	content_list.set_column_title(2, "Pos")
	content_list.set_column_title(3, "School")
	content_list.set_column_title(4, "Grade")
	content_list.hide_root = true

	# Set column sizing
	content_list.set_column_expand(0, false)
	content_list.set_column_expand(1, true)
	content_list.set_column_expand(2, false)
	content_list.set_column_expand(3, true)
	content_list.set_column_expand(4, false)

	content_list.set_column_expand_ratio(0, 1)
	content_list.set_column_expand_ratio(1, 3)
	content_list.set_column_expand_ratio(2, 1)
	content_list.set_column_expand_ratio(3, 2)
	content_list.set_column_expand_ratio(4, 1)

	if current_year == 0:
		push_warning("DraftPanel: No draft year selected")
		return

	# Get draft pool for current year
	var draft_pool = DraftQueries.get_draft_pool(world_state, current_year)

	if draft_pool.is_empty():
		push_warning("DraftPanel: No draft pool for year %d" % current_year)
		return

	# Calculate draft grades for all prospects
	# RNG consumption: One calculate_composite_rating() call per player
	var prospects_with_grades: Array = []
	for player in draft_pool:
		var grade = DraftQueries.calculate_draft_grade(player)
		prospects_with_grades.append({
			"player": player,
			"grade": grade
		})

	# Sort by grade (highest first)
	prospects_with_grades.sort_custom(func(a, b): return a.grade > b.grade)

	# Assign overall ranks BEFORE filtering (this is the rank in the entire draft class)
	for i in range(prospects_with_grades.size()):
		prospects_with_grades[i]["overall_rank"] = i + 1

	# Apply position filter
	if current_position != "All":
		prospects_with_grades = prospects_with_grades.filter(func(p):
			return p.player.get("position", "") == current_position
		)

	# Apply search filter
	if not current_search.is_empty():
		prospects_with_grades = prospects_with_grades.filter(func(p):
			var player = p.player
			var first = player.get("first_name", "").to_lower()
			var last = player.get("last_name", "").to_lower()
			var full = (first + " " + last).to_lower()
			return full.contains(current_search) or first.contains(current_search) or last.contains(current_search)
		)

	# Limit to top N prospects
	var display_count = mini(MAX_PROSPECTS_DISPLAYED, prospects_with_grades.size())

	# Calculate positional ranks if filtering by position
	var positional_ranks: Dictionary = {}
	if current_position != "All":
		for i in range(display_count):
			var player = prospects_with_grades[i].player
			var pos = player.get("position", "?")
			if not positional_ranks.has(pos):
				positional_ranks[pos] = 1
			else:
				positional_ranks[pos] += 1
	else:
		# Calculate positional ranks for all positions
		for prospect_data in prospects_with_grades:
			var pos = prospect_data.player.get("position", "?")
			if not positional_ranks.has(pos):
				positional_ranks[pos] = 0

	# Reset positional counters
	var pos_counters: Dictionary = {}

	# Display prospects
	for i in range(display_count):
		var prospect_data = prospects_with_grades[i]
		var player = prospect_data.player
		var grade = prospect_data.grade
		var overall_rank = prospect_data.overall_rank  # Use pre-calculated overall rank

		var item = content_list.create_item(root)

		# Calculate positional rank
		var pos = player.get("position", "?")
		if not pos_counters.has(pos):
			pos_counters[pos] = 1
		else:
			pos_counters[pos] += 1
		var pos_rank = pos_counters[pos]

		# Format rank display - ALWAYS show overall rank
		# When filtering by position, show: #15 (overall rank in entire class)
		# When showing all, show: #15 QB3 (overall rank + positional rank)
		var rank_text = "#%d" % overall_rank
		if current_position == "All":
			# Show both overall and positional rank
			rank_text = "#%d %s%d" % [overall_rank, pos, pos_rank]

		item.set_text(0, rank_text)

		# Player name
		var name = PlayerQueries.get_player_name(player)
		item.set_text(1, name)

		# Position
		item.set_text(2, pos)

		# School (college or last college)
		var college_id = player.get("college_id", "")
		var school_name = "Unknown"
		if not college_id.is_empty():
			var college = TeamQueries.get_college(world_state, college_id)
			if college:
				school_name = college.get("name", "Unknown")
		item.set_text(3, school_name)

		# Draft grade (color-coded)
		item.set_text(4, "%.0f" % grade)
		var grade_color = StatQueries.get_stat_color(grade)
		item.set_custom_color(4, grade_color)

		# Store metadata for selection handling
		var player_id = PlayerQueries.get_player_id(player)
		item.set_metadata(0, {"type": "player", "id": player_id})

# Signal handlers

func _on_year_filter_changed(index: int) -> void:
	var year_text = year_filter.get_item_text(index)
	current_year = int(year_text)
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
		"player":
			player_selected.emit(metadata.get("id", ""))
