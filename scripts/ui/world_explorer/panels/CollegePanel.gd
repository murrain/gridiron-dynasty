extends VBoxContainer
class_name CollegePanel

# Preload query utilities
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")

## College Panel for World Explorer
##
## Displays college football programs with three view modes:
## 1. Schools View - All 130 colleges with tier filtering
## 2. Players by Class - Hierarchical tree grouped by class year (FR/SO/JR/SR)
## 3. All Players - Flat list with position and class filters
##
## Features:
## - Draft-eligible player identification (seniors 65+, juniors 80+)
## - Tier filtering (Elite, Power5, Mid-Major)
## - Position filtering (in All Players mode)
## - Class year filtering (in All Players mode)
## - Search filtering across all modes

# Signals - required by WorldExplorer contract
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

# View modes
enum ViewMode {
	SCHOOLS,           # List all schools with stats
	PLAYERS_BY_CLASS,  # Tree grouped by class year
	ALL_PLAYERS        # Flat player list
}

# Filter indices
enum TierFilterIndex {
	ALL = 0,
	ELITE = 1,
	POWER5 = 2,
	MID_MAJOR = 3
}

enum ClassFilterIndex {
	ALL = 0,
	FRESHMAN = 1,
	SOPHOMORE = 2,
	JUNIOR = 3,
	SENIOR = 4
}

enum PositionFilterIndex {
	ALL = 0,
	QB = 1,
	RB = 2,
	WR = 3,
	TE = 4,
	OL = 5,
	DL = 6,
	LB = 7,
	CB = 8,
	S = 9,
	K = 10,
	P = 11
}

# Node references
@onready var view_mode_button: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/ViewModeButton
@onready var tier_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/TierFilter
@onready var tier_label: Label = $FilterBarPanel/MarginContainer/FilterBar/TierLabel
@onready var position_label: Label = $FilterBarPanel/MarginContainer/FilterBar/PositionLabel
@onready var position_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/PositionFilter
@onready var year_label: Label = $FilterBarPanel/MarginContainer/FilterBar/ClassLabel
@onready var year_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/ClassFilter
@onready var spacer1: Control = $FilterBarPanel/MarginContainer/FilterBar/Spacer1
@onready var spacer2: Control = $FilterBarPanel/MarginContainer/FilterBar/Spacer2
@onready var spacer3: Control = $FilterBarPanel/MarginContainer/FilterBar/Spacer3
@onready var content_list: Tree = $ContentPanel/ContentList

# State
var world_state: Dictionary = {}
var current_view_mode: ViewMode = ViewMode.SCHOOLS
var current_search: String = ""
var current_tier_filter: TierFilterIndex = TierFilterIndex.ALL
var current_position_filter: PositionFilterIndex = PositionFilterIndex.ALL
var current_class_filter: ClassFilterIndex = ClassFilterIndex.ALL

# Cache for performance
var all_colleges: Array = []
var all_college_players: Array = []

func _ready() -> void:
	_setup_filters()
	_connect_signals()

func _setup_filters() -> void:
	# View mode options
	view_mode_button.clear()
	view_mode_button.add_item("Schools", ViewMode.SCHOOLS)
	view_mode_button.add_item("Players by Class", ViewMode.PLAYERS_BY_CLASS)
	view_mode_button.add_item("All Players", ViewMode.ALL_PLAYERS)
	view_mode_button.select(ViewMode.SCHOOLS)

	# Tier filter
	tier_filter.clear()
	tier_filter.add_item("All Tiers", TierFilterIndex.ALL)
	tier_filter.add_item("Elite", TierFilterIndex.ELITE)
	tier_filter.add_item("Power 5", TierFilterIndex.POWER5)
	tier_filter.add_item("Mid-Major", TierFilterIndex.MID_MAJOR)
	tier_filter.select(TierFilterIndex.ALL)

	# Position filter
	position_filter.clear()
	position_filter.add_item("All Positions", PositionFilterIndex.ALL)
	position_filter.add_item("QB", PositionFilterIndex.QB)
	position_filter.add_item("RB", PositionFilterIndex.RB)
	position_filter.add_item("WR", PositionFilterIndex.WR)
	position_filter.add_item("TE", PositionFilterIndex.TE)
	position_filter.add_item("OL", PositionFilterIndex.OL)
	position_filter.add_item("DL", PositionFilterIndex.DL)
	position_filter.add_item("LB", PositionFilterIndex.LB)
	position_filter.add_item("CB", PositionFilterIndex.CB)
	position_filter.add_item("S", PositionFilterIndex.S)
	position_filter.add_item("K", PositionFilterIndex.K)
	position_filter.add_item("P", PositionFilterIndex.P)
	position_filter.select(PositionFilterIndex.ALL)

	# Class filter
	year_filter.clear()
	year_filter.add_item("All Classes", ClassFilterIndex.ALL)
	year_filter.add_item("Freshman", ClassFilterIndex.FRESHMAN)
	year_filter.add_item("Sophomore", ClassFilterIndex.SOPHOMORE)
	year_filter.add_item("Junior", ClassFilterIndex.JUNIOR)
	year_filter.add_item("Senior", ClassFilterIndex.SENIOR)
	year_filter.select(ClassFilterIndex.ALL)

func _connect_signals() -> void:
	view_mode_button.item_selected.connect(_on_view_mode_changed)
	tier_filter.item_selected.connect(_on_tier_filter_changed)
	position_filter.item_selected.connect(_on_position_filter_changed)
	year_filter.item_selected.connect(_on_class_filter_changed)
	content_list.item_selected.connect(_on_content_list_item_selected)

## Required by WorldExplorer: Initialize with world state
func initialize(ws: Dictionary) -> void:
	world_state = ws
	_cache_data()
	_update_view()

## Required by WorldExplorer: Filter by search text
func filter_by_search(search_text: String) -> void:
	current_search = search_text
	_update_view()

## Optional: Cleanup resources
func cleanup() -> void:
	all_colleges.clear()
	all_college_players.clear()
	content_list.clear()

# Private methods

func _cache_data() -> void:
	# Cache colleges
	all_colleges = world_state.get("colleges", []).duplicate()

	# Cache all college players
	all_college_players.clear()
	var college_rosters = world_state.get("college_rosters", {})
	for roster_data in college_rosters.values():
		var players = roster_data.get("players", [])
		all_college_players.append_array(players)

func _update_view() -> void:
	content_list.clear()

	match current_view_mode:
		ViewMode.SCHOOLS:
			_render_schools_view()
		ViewMode.PLAYERS_BY_CLASS:
			_render_players_by_class_view()
		ViewMode.ALL_PLAYERS:
			_render_all_players_view()

func _render_schools_view() -> void:
	# Configure tree for schools view
	content_list.columns = 5
	content_list.set_column_title(0, "School")
	content_list.set_column_title(1, "Tier")
	content_list.set_column_title(2, "Eliteness")
	content_list.set_column_title(3, "Roster")
	content_list.set_column_title(4, "Draft Eligible")

	# Set column expand/sizing
	content_list.set_column_expand(0, true)
	content_list.set_column_expand(1, false)
	content_list.set_column_expand(2, false)
	content_list.set_column_expand(3, false)
	content_list.set_column_expand(4, false)

	content_list.set_column_expand_ratio(0, 3)
	content_list.set_column_expand_ratio(1, 1)
	content_list.set_column_expand_ratio(2, 1)
	content_list.set_column_expand_ratio(3, 1)
	content_list.set_column_expand_ratio(4, 1)

	var root = content_list.create_item()

	# Filter and sort colleges
	var filtered_colleges = _filter_colleges(all_colleges)
	filtered_colleges.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))

	# Add each college
	for college in filtered_colleges:
		var item = content_list.create_item(root)

		var college_id = college.get("id", "")
		var college_name = college.get("name", "Unknown")
		var tier = college.get("tier", "unknown")
		var eliteness = college.get("eliteness", 0.0)

		# Get roster size and draft-eligible count
		var roster = TeamQueries.get_college_roster(world_state, college_id)
		var roster_size = roster.size()
		var draft_eligible_count = _count_draft_eligible(roster)

		# Set columns
		item.set_text(0, college_name)
		item.set_text(1, _get_tier_display(tier))
		item.set_text(2, "%.0f" % eliteness)
		item.set_text(3, str(roster_size))
		item.set_text(4, str(draft_eligible_count))

		# Store metadata for selection
		item.set_metadata(0, {"type": "school", "id": college_id})

		# Color coding for eliteness
		var color = _get_eliteness_color(eliteness)
		item.set_custom_color(2, color)

func _render_players_by_class_view() -> void:
	# Configure tree for hierarchical view
	content_list.columns = 4
	content_list.set_column_title(0, "Class / Player")
	content_list.set_column_title(1, "Position")
	content_list.set_column_title(2, "School")
	content_list.set_column_title(3, "Rating")

	content_list.set_column_expand(0, true)
	content_list.set_column_expand(1, false)
	content_list.set_column_expand(2, true)
	content_list.set_column_expand(3, false)

	content_list.set_column_expand_ratio(0, 2)
	content_list.set_column_expand_ratio(1, 1)
	content_list.set_column_expand_ratio(2, 2)
	content_list.set_column_expand_ratio(3, 1)

	var root = content_list.create_item()

	# Filter players
	var filtered_players = _filter_players(all_college_players)

	# Group by class year
	var by_class: Dictionary = {
		4: [],  # Senior
		3: [],  # Junior
		2: [],  # Sophomore
		1: []   # Freshman
	}

	for player in filtered_players:
		var year = player.get("college_year", 0)
		if by_class.has(year):
			by_class[year].append(player)

	# Create tree structure (Seniors first)
	for year in [4, 3, 2, 1]:
		var players_in_class = by_class[year]
		if players_in_class.is_empty():
			continue

		# Create class header
		var year_item = content_list.create_item(root)
		var year_name = _get_class_name(year)
		year_item.set_text(0, "%s (%d)" % [year_name, players_in_class.size()])
		year_item.set_selectable(0, false)

		# Sort players by rating
		players_in_class.sort_custom(func(a, b):
			return StatQueries.calculate_composite_rating(a) > StatQueries.calculate_composite_rating(b)
		)

		# Add players under this class
		for player in players_in_class:
			var player_item = content_list.create_item(year_item)

			var player_id = PlayerQueries.get_player_id(player)
			var player_name = PlayerQueries.get_player_name(player)
			var position = player.get("position", "?")
			var college_id = player.get("college_id", "")
			var rating = StatQueries.calculate_composite_rating(player)

			# Get college name
			var college = TeamQueries.get_college(world_state, college_id)
			var college_name = college.get("name", "Unknown") if college else "Unknown"

			# Mark draft-eligible players
			var display_name = player_name
			if _is_draft_eligible(player):
				display_name = "★ " + player_name

			player_item.set_text(0, display_name)
			player_item.set_text(1, position)
			player_item.set_text(2, college_name)
			player_item.set_text(3, "%.0f" % rating)

			# Color rating
			var color = StatQueries.get_stat_color(rating)
			player_item.set_custom_color(3, color)

			# Store metadata
			player_item.set_metadata(0, {"type": "player", "id": player_id})

func _render_all_players_view() -> void:
	# Configure tree for flat player list
	content_list.columns = 5
	content_list.set_column_title(0, "Player")
	content_list.set_column_title(1, "Position")
	content_list.set_column_title(2, "Class")
	content_list.set_column_title(3, "School")
	content_list.set_column_title(4, "Rating")

	content_list.set_column_expand(0, true)
	content_list.set_column_expand(1, false)
	content_list.set_column_expand(2, false)
	content_list.set_column_expand(3, true)
	content_list.set_column_expand(4, false)

	content_list.set_column_expand_ratio(0, 2)
	content_list.set_column_expand_ratio(1, 1)
	content_list.set_column_expand_ratio(2, 1)
	content_list.set_column_expand_ratio(3, 2)
	content_list.set_column_expand_ratio(4, 1)

	var root = content_list.create_item()

	# Filter players
	var filtered_players = _filter_players(all_college_players)

	# Sort by rating
	filtered_players.sort_custom(func(a, b):
		return StatQueries.calculate_composite_rating(a) > StatQueries.calculate_composite_rating(b)
	)

	# Add each player
	for player in filtered_players:
		var item = content_list.create_item(root)

		var player_id = PlayerQueries.get_player_id(player)
		var player_name = PlayerQueries.get_player_name(player)
		var position = player.get("position", "?")
		var college_year = player.get("college_year", 0)
		var college_id = player.get("college_id", "")
		var rating = StatQueries.calculate_composite_rating(player)

		# Get college name
		var college = TeamQueries.get_college(world_state, college_id)
		var college_name = college.get("name", "Unknown") if college else "Unknown"

		# Mark draft-eligible players
		var display_name = player_name
		if _is_draft_eligible(player):
			display_name = "★ " + player_name

		item.set_text(0, display_name)
		item.set_text(1, position)
		item.set_text(2, _get_class_abbreviation(college_year))
		item.set_text(3, college_name)
		item.set_text(4, "%.0f" % rating)

		# Color rating
		var color = StatQueries.get_stat_color(rating)
		item.set_custom_color(4, color)

		# Store metadata
		item.set_metadata(0, {"type": "player", "id": player_id})

# Filtering logic

func _filter_colleges(colleges: Array) -> Array:
	var filtered: Array = []

	for college in colleges:
		# Apply tier filter
		if not _passes_tier_filter(college):
			continue

		# Apply search filter
		if not current_search.is_empty():
			var name = college.get("name", "").to_lower()
			if not name.contains(current_search.to_lower()):
				continue

		filtered.append(college)

	return filtered

func _filter_players(players: Array) -> Array:
	var filtered: Array = []

	for player in players:
		# Apply position filter (All Players view only)
		if current_view_mode == ViewMode.ALL_PLAYERS:
			if not _passes_position_filter(player):
				continue

			# Apply class filter
			if not _passes_class_filter(player):
				continue

		# Apply tier filter (filter by school tier)
		if current_tier_filter != TierFilterIndex.ALL:
			var college_id = player.get("college_id", "")
			var college = TeamQueries.get_college(world_state, college_id)
			if college == null or not _passes_tier_filter(college):
				continue

		# Apply search filter
		if not current_search.is_empty():
			var player_name = PlayerQueries.get_player_name(player).to_lower()
			var college_id = player.get("college_id", "")
			var college = TeamQueries.get_college(world_state, college_id)
			var college_name = college.get("name", "").to_lower() if college else ""

			if not (player_name.contains(current_search.to_lower()) or college_name.contains(current_search.to_lower())):
				continue

		filtered.append(player)

	return filtered

func _passes_tier_filter(college: Dictionary) -> bool:
	if current_tier_filter == TierFilterIndex.ALL:
		return true

	var tier = college.get("tier", "").to_lower()

	match current_tier_filter:
		TierFilterIndex.ELITE:
			return tier == "elite"
		TierFilterIndex.POWER5:
			return tier == "power5"
		TierFilterIndex.MID_MAJOR:
			return tier == "mid_major" or tier == "mid-major"

	return false

func _passes_position_filter(player: Dictionary) -> bool:
	if current_position_filter == PositionFilterIndex.ALL:
		return true

	var position = player.get("position", "")
	var filter_position = _get_position_string_from_filter(current_position_filter)

	return position == filter_position

func _passes_class_filter(player: Dictionary) -> bool:
	if current_class_filter == ClassFilterIndex.ALL:
		return true

	var college_year = player.get("college_year", 0)

	match current_class_filter:
		ClassFilterIndex.FRESHMAN:
			return college_year == 1
		ClassFilterIndex.SOPHOMORE:
			return college_year == 2
		ClassFilterIndex.JUNIOR:
			return college_year == 3
		ClassFilterIndex.SENIOR:
			return college_year == 4

	return false

# Utility functions

func _is_draft_eligible(player: Dictionary) -> bool:
	var rating = StatQueries.calculate_composite_rating(player)
	var college_year = player.get("college_year", 0)

	# Seniors (year 4) with rating 65+
	if college_year == 4 and rating >= 65.0:
		return true

	# Juniors (year 3) with rating 80+ can declare early
	if college_year == 3 and rating >= 80.0:
		return true

	return false

func _count_draft_eligible(roster: Array) -> int:
	var count = 0
	for player in roster:
		if _is_draft_eligible(player):
			count += 1
	return count

func _get_class_name(year: int) -> String:
	match year:
		1: return "Freshman"
		2: return "Sophomore"
		3: return "Junior"
		4: return "Senior"
		_: return "Unknown"

func _get_class_abbreviation(year: int) -> String:
	match year:
		1: return "FR"
		2: return "SO"
		3: return "JR"
		4: return "SR"
		_: return "?"

func _get_tier_display(tier: String) -> String:
	match tier.to_lower():
		"elite": return "Elite"
		"power5": return "Power 5"
		"mid_major", "mid-major": return "Mid-Major"
		_: return tier.capitalize()

func _get_position_string_from_filter(filter_idx: PositionFilterIndex) -> String:
	match filter_idx:
		PositionFilterIndex.QB: return "QB"
		PositionFilterIndex.RB: return "RB"
		PositionFilterIndex.WR: return "WR"
		PositionFilterIndex.TE: return "TE"
		PositionFilterIndex.OL: return "OL"
		PositionFilterIndex.DL: return "DL"
		PositionFilterIndex.LB: return "LB"
		PositionFilterIndex.CB: return "CB"
		PositionFilterIndex.S: return "S"
		PositionFilterIndex.K: return "K"
		PositionFilterIndex.P: return "P"
		_: return ""

func _get_eliteness_color(eliteness: float) -> Color:
	# Color coding for eliteness (0-100 scale)
	if eliteness >= 90.0:
		return Color("#00ff00")  # Bright green
	elif eliteness >= 80.0:
		return Color("#66ff66")  # Light green
	elif eliteness >= 70.0:
		return Color("#99ff99")  # Pale green
	elif eliteness >= 60.0:
		return Color("#ffff00")  # Yellow
	elif eliteness >= 50.0:
		return Color("#ffaa00")  # Orange
	else:
		return Color("#ff6666")  # Light red

func _update_filter_visibility() -> void:
	match current_view_mode:
		ViewMode.SCHOOLS:
			# Show tier filter
			tier_filter.visible = true
			tier_label.visible = true
			spacer1.visible = true

			# Hide player filters
			position_filter.visible = false
			position_label.visible = false
			year_filter.visible = false
			year_label.visible = false
			spacer2.visible = false
			spacer3.visible = false

		ViewMode.PLAYERS_BY_CLASS:
			# Hide all filters for this view
			tier_filter.visible = false
			tier_label.visible = false
			position_filter.visible = false
			position_label.visible = false
			year_filter.visible = false
			year_label.visible = false
			spacer1.visible = false
			spacer2.visible = false
			spacer3.visible = false

		ViewMode.ALL_PLAYERS:
			# Show position and year filters
			position_filter.visible = true
			position_label.visible = true
			year_filter.visible = true
			year_label.visible = true
			spacer2.visible = true
			spacer3.visible = true

			# Hide tier filter
			tier_filter.visible = false
			tier_label.visible = false
			spacer1.visible = false

# Signal handlers

func _on_view_mode_changed(index: int) -> void:
	current_view_mode = index as ViewMode
	_update_filter_visibility()
	_update_view()

func _on_tier_filter_changed(index: int) -> void:
	current_tier_filter = index as TierFilterIndex
	_update_view()

func _on_position_filter_changed(index: int) -> void:
	current_position_filter = index as PositionFilterIndex
	_update_view()

func _on_class_filter_changed(index: int) -> void:
	current_class_filter = index as ClassFilterIndex
	_update_view()

func _on_content_list_item_selected() -> void:
	var selected = content_list.get_selected()
	if selected == null:
		return

	var metadata = selected.get_metadata(0)
	if metadata == null:
		return

	var item_type = metadata.get("type", "")
	var item_id = metadata.get("id", "")

	match item_type:
		"player":
			player_selected.emit(item_id)
		"school":
			team_selected.emit(item_id, "college")
