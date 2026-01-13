extends VBoxContainer
class_name HsPanel

# Preload query utilities
const PlayerQueries = preload("res://scripts/ui/world_explorer/queries/PlayerQueries.gd")
const TeamQueries = preload("res://scripts/ui/world_explorer/queries/TeamQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")

## High School Panel for World Explorer
##
## Displays high school football programs with four view modes:
## 1. Schools View - All 400 high schools (paginated, 50 per page)
## 2. Players by Year - Hierarchical tree grouped by year (1-4)
## 3. All Players - Flat list with position and year filters
## 4. Seniors Only - Graduating class view (college prospects)
##
## Features:
## - Pagination for Schools view (50 schools per page = 8 pages)
## - College eligibility identification (seniors with rating 50+)
## - Tier filtering (Powerhouse, Competitive, Developmental)
## - Position filtering (in All Players mode)
## - Year filtering (in All Players mode)
## - Search filtering across all modes

# Signals - required by WorldExplorer contract
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

# View modes
enum ViewMode {
	SCHOOLS,            # Paginated list of all schools
	PLAYERS_BY_YEAR,    # Tree grouped by year (1-4)
	ALL_PLAYERS,        # Flat player list with filters
	SENIORS_ONLY        # Year 4 players only (college prospects)
}

# Filter indices
enum TierFilterIndex {
	ALL = 0,
	POWERHOUSE = 1,
	COMPETITIVE = 2,
	DEVELOPMENTAL = 3
}

enum YearFilterIndex {
	ALL = 0,
	YEAR1 = 1,
	YEAR2 = 2,
	YEAR3 = 3,
	YEAR4 = 4
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

# Constants
const SCHOOLS_PER_PAGE: int = 50

# Node references
@onready var view_mode_button: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/ViewModeButton
@onready var tier_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/TierFilter
@onready var position_label: Label = $FilterBarPanel/MarginContainer/FilterBar/PositionLabel
@onready var position_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/PositionFilter
@onready var year_label: Label = $FilterBarPanel/MarginContainer/FilterBar/YearLabel
@onready var year_filter: OptionButton = $FilterBarPanel/MarginContainer/FilterBar/YearFilter
@onready var content_list: Tree = $ContentPanel/ContentList
@onready var pagination_bar: HBoxContainer = $PaginationBar
@onready var prev_page_button: Button = $PaginationBar/PrevPageButton
@onready var page_label: Label = $PaginationBar/PageLabel
@onready var next_page_button: Button = $PaginationBar/NextPageButton

# State
var world_state: Dictionary = {}
var current_view_mode: ViewMode = ViewMode.SCHOOLS
var current_search: String = ""
var current_tier_filter: TierFilterIndex = TierFilterIndex.ALL
var current_position_filter: PositionFilterIndex = PositionFilterIndex.ALL
var current_year_filter: YearFilterIndex = YearFilterIndex.ALL

# Pagination state
var current_page: int = 0
var total_pages: int = 0

# Cache for performance
var all_hs_schools: Array = []
var all_hs_players: Array = []

# Config values (loaded from high_schools.json)
var college_eligibility_threshold: float = 40.0  # Default, loaded from config
var elite_tier_threshold: float = 75.0  # Default, loaded from config
var power5_tier_threshold: float = 65.0  # Default, loaded from config
var mid_major_tier_threshold: float = 55.0  # Default, loaded from config

func _ready() -> void:
	_setup_filters()
	_connect_signals()

func _setup_filters() -> void:
	# View mode options
	view_mode_button.clear()
	view_mode_button.add_item("Schools", ViewMode.SCHOOLS)
	view_mode_button.add_item("Players by Year", ViewMode.PLAYERS_BY_YEAR)
	view_mode_button.add_item("All Players", ViewMode.ALL_PLAYERS)
	view_mode_button.add_item("Seniors Only", ViewMode.SENIORS_ONLY)
	view_mode_button.select(ViewMode.SCHOOLS)

	# Tier filter
	tier_filter.clear()
	tier_filter.add_item("All Tiers", TierFilterIndex.ALL)
	tier_filter.add_item("Powerhouse", TierFilterIndex.POWERHOUSE)
	tier_filter.add_item("Competitive", TierFilterIndex.COMPETITIVE)
	tier_filter.add_item("Developmental", TierFilterIndex.DEVELOPMENTAL)
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

	# Year filter
	year_filter.clear()
	year_filter.add_item("All Years", YearFilterIndex.ALL)
	year_filter.add_item("Year 1", YearFilterIndex.YEAR1)
	year_filter.add_item("Year 2", YearFilterIndex.YEAR2)
	year_filter.add_item("Year 3", YearFilterIndex.YEAR3)
	year_filter.add_item("Year 4", YearFilterIndex.YEAR4)
	year_filter.select(YearFilterIndex.ALL)

func _connect_signals() -> void:
	if not view_mode_button.item_selected.is_connected(_on_view_mode_changed):
		view_mode_button.item_selected.connect(_on_view_mode_changed)
	if not tier_filter.item_selected.is_connected(_on_tier_filter_changed):
		tier_filter.item_selected.connect(_on_tier_filter_changed)
	if not position_filter.item_selected.is_connected(_on_position_filter_changed):
		position_filter.item_selected.connect(_on_position_filter_changed)
	if not year_filter.item_selected.is_connected(_on_year_filter_changed):
		year_filter.item_selected.connect(_on_year_filter_changed)
	if not content_list.item_selected.is_connected(_on_content_list_item_selected):
		content_list.item_selected.connect(_on_content_list_item_selected)
	if not prev_page_button.pressed.is_connected(_on_prev_page_pressed):
		prev_page_button.pressed.connect(_on_prev_page_pressed)
	if not next_page_button.pressed.is_connected(_on_next_page_pressed):
		next_page_button.pressed.connect(_on_next_page_pressed)

## Required by WorldExplorer: Initialize with world state
func initialize(ws: Dictionary) -> void:
	world_state = ws
	_load_config_values()
	_cache_data()
	_reset_pagination()
	_update_view()

## Required by WorldExplorer: Filter by search text
func filter_by_search(search_text: String) -> void:
	current_search = search_text
	_reset_pagination()
	_update_view()

## Optional: Cleanup resources
func cleanup() -> void:
	all_hs_schools.clear()
	all_hs_players.clear()
	content_list.clear()

# Private methods

func _load_config_values() -> void:
	# Load HS config to get college eligibility threshold and tier thresholds
	var config_path = "res://configs/sports/american_football/world/high_schools.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var config = json.data
			var recruiting = config.get("recruiting", {})

			# Load college eligibility threshold
			college_eligibility_threshold = recruiting.get("college_eligibility_threshold", 40.0)

			# Load projected tier thresholds for college projection
			var tier_thresholds = recruiting.get("projected_tier_thresholds", {})
			elite_tier_threshold = tier_thresholds.get("elite", 75.0)
			power5_tier_threshold = tier_thresholds.get("power5", 65.0)
			mid_major_tier_threshold = tier_thresholds.get("mid_major", 55.0)
		file.close()

func _cache_data() -> void:
	# Cache high schools
	all_hs_schools = world_state.get("hs_schools", []).duplicate()

	# Cache all high school players
	all_hs_players = world_state.get("hs_players", []).duplicate()

func _reset_pagination() -> void:
	current_page = 0
	total_pages = 0

func _update_view() -> void:
	content_list.clear()

	match current_view_mode:
		ViewMode.SCHOOLS:
			_render_schools_view()
		ViewMode.PLAYERS_BY_YEAR:
			_render_players_by_year_view()
		ViewMode.ALL_PLAYERS:
			_render_all_players_view()
		ViewMode.SENIORS_ONLY:
			_render_seniors_only_view()

## SCHOOLS VIEW MODE
## Displays all high schools with pagination (50 per page)
func _render_schools_view() -> void:
	# Configure tree for schools view
	content_list.columns = 6
	content_list.set_column_title(0, "School")
	content_list.set_column_title(1, "Region")
	content_list.set_column_title(2, "Tier")
	content_list.set_column_title(3, "Program Quality")
	content_list.set_column_title(4, "Roster")
	content_list.set_column_title(5, "Seniors")

	# Set column expand/sizing
	content_list.set_column_expand(0, true)
	content_list.set_column_expand(1, false)
	content_list.set_column_expand(2, false)
	content_list.set_column_expand(3, true)
	content_list.set_column_expand(4, false)
	content_list.set_column_expand(5, false)

	content_list.set_column_expand_ratio(0, 3)
	content_list.set_column_expand_ratio(1, 1)
	content_list.set_column_expand_ratio(2, 1)
	content_list.set_column_expand_ratio(3, 2)
	content_list.set_column_expand_ratio(4, 1)
	content_list.set_column_expand_ratio(5, 1)

	var root = content_list.create_item()

	# Filter and sort schools
	var filtered_schools = _filter_schools(all_hs_schools)
	filtered_schools.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))

	# Calculate pagination
	var total_schools = filtered_schools.size()
	total_pages = ceili(float(total_schools) / float(SCHOOLS_PER_PAGE))
	if total_pages == 0:
		total_pages = 1

	# Clamp current page
	current_page = clampi(current_page, 0, maxi(0, total_pages - 1))

	# Get schools for current page
	var start_idx = current_page * SCHOOLS_PER_PAGE
	var end_idx = mini(start_idx + SCHOOLS_PER_PAGE, total_schools)
	var page_schools = filtered_schools.slice(start_idx, end_idx)

	# Show pagination controls
	pagination_bar.visible = true
	_update_pagination_controls()

	# Add each school on current page
	for school in page_schools:
		var item = content_list.create_item(root)

		var school_id = school.get("id", "")
		var school_name = school.get("name", "Unknown")
		var region = school.get("region", "unknown")
		var tier = school.get("tier", "")
		var program_quality_tier = school.get("program_quality_tier", "")

		# Get roster and count seniors
		var roster = TeamQueries.get_hs_roster(world_state, school_id)
		var roster_size = roster.size()
		var seniors_count = _count_seniors(roster)

		# Set columns
		item.set_text(0, school_name)
		item.set_text(1, _get_region_display(region))
		item.set_text(2, _get_tier_display(tier))
		item.set_text(3, _get_program_quality_display(program_quality_tier))
		item.set_text(4, str(roster_size))
		item.set_text(5, str(seniors_count))

		# Store metadata for selection
		item.set_metadata(0, {"type": "school", "id": school_id})

		# Color coding for tier
		var tier_color = _get_tier_color(tier)
		item.set_custom_color(2, tier_color)

## PLAYERS BY YEAR VIEW MODE
## Displays hierarchical tree grouped by year (1-4)
func _render_players_by_year_view() -> void:
	# Hide pagination
	pagination_bar.visible = false

	# Configure tree for hierarchical view
	content_list.columns = 4
	content_list.set_column_title(0, "Year / Player")
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
	var filtered_players = _filter_players(all_hs_players)

	# Group by year
	var by_year: Dictionary = {
		1: [],  # Year 1
		2: [],  # Year 2
		3: [],  # Year 3
		4: []   # Year 4 (Seniors)
	}

	for player in filtered_players:
		var year = player.get("hs_year", 0)
		if by_year.has(year):
			by_year[year].append(player)

	# Create tree structure (Years 1-4)
	for year in [1, 2, 3, 4]:
		var players_in_year = by_year[year]
		if players_in_year.is_empty():
			continue

		# Create year header
		var year_item = content_list.create_item(root)
		var year_name = "Year %d" % year
		if year == 4:
			year_name = "Year 4 (Seniors)"
		year_item.set_text(0, "%s (%d)" % [year_name, players_in_year.size()])
		year_item.set_selectable(0, false)
		year_item.set_custom_bg_color(0, Color(0.2, 0.2, 0.3))

		# Sort players by rating
		players_in_year.sort_custom(func(a, b):
			return StatQueries.calculate_composite_rating(a) > StatQueries.calculate_composite_rating(b)
		)

		# Add players under this year
		for player in players_in_year:
			var player_item = content_list.create_item(year_item)

			var player_id = PlayerQueries.get_player_id(player)
			var player_name = PlayerQueries.get_player_name(player)
			var position = player.get("position", "?")
			var school_id = player.get("hs_school_id", "")
			var rating = StatQueries.calculate_composite_rating(player)

			# Get school name
			var school = TeamQueries.get_hs_school(world_state, school_id)
			var school_name = school.get("name", "Unknown") if school else "Unknown"

			# Mark college-eligible seniors
			var display_name = player_name
			if _is_college_eligible(player):
				display_name = "★ " + player_name

			player_item.set_text(0, display_name)
			player_item.set_text(1, position)
			player_item.set_text(2, school_name)
			player_item.set_text(3, "%.0f" % rating)

			# Color rating
			var color = StatQueries.get_stat_color(rating)
			player_item.set_custom_color(3, color)

			# Store metadata
			player_item.set_metadata(0, {"type": "player", "id": player_id})

## ALL PLAYERS VIEW MODE
## Displays flat list with position and year filters
func _render_all_players_view() -> void:
	# Hide pagination
	pagination_bar.visible = false

	# Configure tree for flat player list
	content_list.columns = 5
	content_list.set_column_title(0, "Player")
	content_list.set_column_title(1, "Position")
	content_list.set_column_title(2, "Year")
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
	var filtered_players = _filter_players(all_hs_players)

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
		var hs_year = player.get("hs_year", 0)
		var school_id = player.get("hs_school_id", "")
		var rating = StatQueries.calculate_composite_rating(player)

		# Get school name
		var school = TeamQueries.get_hs_school(world_state, school_id)
		var school_name = school.get("name", "Unknown") if school else "Unknown"

		# Mark college-eligible seniors
		var display_name = player_name
		if _is_college_eligible(player):
			display_name = "★ " + player_name

		item.set_text(0, display_name)
		item.set_text(1, position)
		item.set_text(2, str(hs_year))
		item.set_text(3, school_name)
		item.set_text(4, "%.0f" % rating)

		# Color rating
		var color = StatQueries.get_stat_color(rating)
		item.set_custom_color(4, color)

		# Store metadata
		item.set_metadata(0, {"type": "player", "id": player_id})

## SENIORS ONLY VIEW MODE
## Displays graduating class (year 4 players) with college eligibility
func _render_seniors_only_view() -> void:
	# Hide pagination
	pagination_bar.visible = false

	# Configure tree for seniors view
	content_list.columns = 5
	content_list.set_column_title(0, "Player")
	content_list.set_column_title(1, "Position")
	content_list.set_column_title(2, "School")
	content_list.set_column_title(3, "Rating")
	content_list.set_column_title(4, "Projected Level")

	content_list.set_column_expand(0, true)
	content_list.set_column_expand(1, false)
	content_list.set_column_expand(2, true)
	content_list.set_column_expand(3, false)
	content_list.set_column_expand(4, false)

	content_list.set_column_expand_ratio(0, 2)
	content_list.set_column_expand_ratio(1, 1)
	content_list.set_column_expand_ratio(2, 2)
	content_list.set_column_expand_ratio(3, 1)
	content_list.set_column_expand_ratio(4, 1)

	var root = content_list.create_item()

	# Get only seniors (year 4)
	var seniors = all_hs_players.filter(func(p): return p.get("hs_year", 0) == 4)

	# Apply other filters
	seniors = _filter_players(seniors)

	# Sort by rating (top prospects first)
	seniors.sort_custom(func(a, b):
		return StatQueries.calculate_composite_rating(a) > StatQueries.calculate_composite_rating(b)
	)

	# Group by school for better organization
	var by_school: Dictionary = {}
	for senior in seniors:
		var school_id = senior.get("hs_school_id", "")
		if not by_school.has(school_id):
			by_school[school_id] = []
		by_school[school_id].append(senior)

	# Get schools sorted by average player rating
	var school_ids = by_school.keys()
	school_ids.sort_custom(func(a, b):
		var players_a = by_school[a]
		var players_b = by_school[b]
		var avg_a = _calculate_average_rating(players_a)
		var avg_b = _calculate_average_rating(players_b)
		return avg_a > avg_b
	)

	# Create tree grouped by school (top schools first)
	for school_id in school_ids:
		var school_players = by_school[school_id]
		var school = TeamQueries.get_hs_school(world_state, school_id)
		var school_name = school.get("name", "Unknown") if school else "Unknown"

		# Create school header
		var school_item = content_list.create_item(root)
		var eligible_count = _count_college_eligible(school_players)
		school_item.set_text(0, "%s (%d seniors, %d eligible)" % [school_name, school_players.size(), eligible_count])
		school_item.set_selectable(0, false)
		school_item.set_custom_bg_color(0, Color(0.2, 0.3, 0.2))

		# Sort players by rating within school
		school_players.sort_custom(func(a, b):
			return StatQueries.calculate_composite_rating(a) > StatQueries.calculate_composite_rating(b)
		)

		# Add players
		for player in school_players:
			var player_item = content_list.create_item(school_item)

			var player_id = PlayerQueries.get_player_id(player)
			var player_name = PlayerQueries.get_player_name(player)
			var position = player.get("position", "?")
			var rating = StatQueries.calculate_composite_rating(player)

			# Determine projected level
			var is_eligible = _is_college_eligible(player)
			var projected_level = "Retire" if not is_eligible else _get_projected_college_level(rating)

			# Mark college-eligible with star
			var display_name = player_name
			if is_eligible:
				display_name = "★ " + player_name

			player_item.set_text(0, display_name)
			player_item.set_text(1, position)
			player_item.set_text(2, school_name)
			player_item.set_text(3, "%.0f" % rating)
			player_item.set_text(4, projected_level)

			# Color rating
			var color = StatQueries.get_stat_color(rating)
			player_item.set_custom_color(3, color)

			# Color projected level
			if is_eligible:
				player_item.set_custom_color(4, Color("#66ff66"))
			else:
				player_item.set_custom_color(4, Color("#ff6666"))

			# Store metadata
			player_item.set_metadata(0, {"type": "player", "id": player_id})

# Filtering logic

func _filter_schools(schools: Array) -> Array:
	var filtered: Array = []

	for school in schools:
		# Apply tier filter
		if not _passes_tier_filter(school):
			continue

		# Apply search filter
		if not current_search.is_empty():
			var name = school.get("name", "").to_lower()
			if not name.contains(current_search.to_lower()):
				continue

		filtered.append(school)

	return filtered

func _filter_players(players: Array) -> Array:
	var filtered: Array = []

	for player in players:
		# Apply position filter (All Players view only)
		if current_view_mode == ViewMode.ALL_PLAYERS:
			if not _passes_position_filter(player):
				continue

			# Apply year filter
			if not _passes_year_filter(player):
				continue

		# Apply tier filter (filter by school tier)
		if current_tier_filter != TierFilterIndex.ALL:
			var school_id = player.get("hs_school_id", "")
			var school = TeamQueries.get_hs_school(world_state, school_id)
			if school == null or not _passes_tier_filter(school):
				continue

		# Apply search filter
		if not current_search.is_empty():
			var player_name = PlayerQueries.get_player_name(player).to_lower()
			var school_id = player.get("hs_school_id", "")
			var school = TeamQueries.get_hs_school(world_state, school_id)
			var school_name = school.get("name", "").to_lower() if school else ""

			if not (player_name.contains(current_search.to_lower()) or school_name.contains(current_search.to_lower())):
				continue

		filtered.append(player)

	return filtered

func _passes_tier_filter(school: Dictionary) -> bool:
	if current_tier_filter == TierFilterIndex.ALL:
		return true

	var tier = school.get("tier", "").to_lower()

	match current_tier_filter:
		TierFilterIndex.POWERHOUSE:
			return tier == "powerhouse"
		TierFilterIndex.COMPETITIVE:
			return tier == "competitive"
		TierFilterIndex.DEVELOPMENTAL:
			return tier == "developmental"

	return false

func _passes_position_filter(player: Dictionary) -> bool:
	if current_position_filter == PositionFilterIndex.ALL:
		return true

	var position = player.get("position", "")
	var filter_position = _get_position_string_from_filter(current_position_filter)

	return position == filter_position

func _passes_year_filter(player: Dictionary) -> bool:
	if current_year_filter == YearFilterIndex.ALL:
		return true

	var hs_year = player.get("hs_year", 0)

	match current_year_filter:
		YearFilterIndex.YEAR1:
			return hs_year == 1
		YearFilterIndex.YEAR2:
			return hs_year == 2
		YearFilterIndex.YEAR3:
			return hs_year == 3
		YearFilterIndex.YEAR4:
			return hs_year == 4

	return false

# Utility functions

## Check if player is eligible for college
## Must be senior (year 4) with minimum rating threshold
func _is_college_eligible(player: Dictionary) -> bool:
	var hs_year = player.get("hs_year", 0)
	var rating = StatQueries.calculate_composite_rating(player)

	# Must be senior (year 4)
	if hs_year != 4:
		return false

	# Minimum rating threshold for college (loaded from config)
	return rating >= college_eligibility_threshold

func _count_seniors(roster: Array) -> int:
	var count = 0
	for player in roster:
		if player.get("hs_year", 0) == 4:
			count += 1
	return count

func _count_college_eligible(players: Array) -> int:
	var count = 0
	for player in players:
		if _is_college_eligible(player):
			count += 1
	return count

func _calculate_average_rating(players: Array) -> float:
	if players.is_empty():
		return 0.0

	var sum = 0.0
	for player in players:
		sum += StatQueries.calculate_composite_rating(player)

	return sum / float(players.size())

func _get_projected_college_level(rating: float) -> String:
	# Project college tier based on HS rating (thresholds from config)
	if rating >= elite_tier_threshold:
		return "Elite"
	elif rating >= power5_tier_threshold:
		return "Power 5"
	elif rating >= mid_major_tier_threshold:
		return "Mid-Major"
	else:
		return "Developmental"

func _get_region_display(region: String) -> String:
	# Convert region code to display name
	return region.capitalize().replace("_", " ")

func _get_tier_display(tier: String) -> String:
	match tier.to_lower():
		"powerhouse": return "Powerhouse"
		"competitive": return "Competitive"
		"developmental": return "Developmental"
		_: return tier.capitalize()

func _get_program_quality_display(quality_tier: String) -> String:
	# Map program quality tier codes to readable names
	match quality_tier.to_lower():
		"elite_dev": return "Elite Development"
		"strong_dev": return "Strong Development"
		"solid_dev": return "Solid Development"
		"average_dev": return "Average Development"
		"below_avg_dev": return "Below Average"
		"poor_dev": return "Poor Development"
		_: return quality_tier.capitalize().replace("_", " ")

func _get_tier_color(tier: String) -> Color:
	match tier.to_lower():
		"powerhouse":
			return Color("#00ff00")  # Bright green
		"competitive":
			return Color("#ffff00")  # Yellow
		"developmental":
			return Color("#ffaa00")  # Orange
		_:
			return Color("#ffffff")  # White

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

# Pagination

func _update_pagination_controls() -> void:
	# Update page label
	page_label.text = "Page %d of %d" % [current_page + 1, total_pages]

	# Enable/disable buttons
	prev_page_button.disabled = (current_page == 0)
	next_page_button.disabled = (current_page >= total_pages - 1)

func _update_filter_visibility() -> void:
	# Show/hide filters based on view mode
	match current_view_mode:
		ViewMode.SCHOOLS:
			# Schools view: show tier filter only
			tier_filter.visible = true
			tier_filter.get_parent().get_node("TierLabel").visible = true

			position_filter.visible = false
			position_label.visible = false
			position_filter.get_parent().get_node("Spacer3").visible = false

			year_filter.visible = false
			year_label.visible = false

		ViewMode.PLAYERS_BY_YEAR:
			# Players by Year: show tier filter only
			tier_filter.visible = true
			tier_filter.get_parent().get_node("TierLabel").visible = true

			position_filter.visible = false
			position_label.visible = false
			position_filter.get_parent().get_node("Spacer3").visible = false

			year_filter.visible = false
			year_label.visible = false

		ViewMode.ALL_PLAYERS:
			# All Players: show tier, position, and year filters
			tier_filter.visible = true
			tier_filter.get_parent().get_node("TierLabel").visible = true

			position_filter.visible = true
			position_label.visible = true
			position_filter.get_parent().get_node("Spacer3").visible = true

			year_filter.visible = true
			year_label.visible = true

		ViewMode.SENIORS_ONLY:
			# Seniors Only: show tier filter only
			tier_filter.visible = true
			tier_filter.get_parent().get_node("TierLabel").visible = true

			position_filter.visible = false
			position_label.visible = false
			position_filter.get_parent().get_node("Spacer3").visible = false

			year_filter.visible = false
			year_label.visible = false

# Signal handlers

func _on_view_mode_changed(index: int) -> void:
	current_view_mode = index as ViewMode
	_reset_pagination()
	_update_filter_visibility()
	_update_view()

func _on_tier_filter_changed(index: int) -> void:
	current_tier_filter = index as TierFilterIndex
	_reset_pagination()
	_update_view()

func _on_position_filter_changed(index: int) -> void:
	current_position_filter = index as PositionFilterIndex
	_update_view()

func _on_year_filter_changed(index: int) -> void:
	current_year_filter = index as YearFilterIndex
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
			team_selected.emit(item_id, "hs")

func _on_prev_page_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		_update_view()

func _on_next_page_pressed() -> void:
	if current_page < total_pages - 1:
		current_page += 1
		_update_view()
