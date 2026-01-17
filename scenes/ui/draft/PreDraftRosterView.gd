## PreDraftRosterView - Displays team roster context for draft decisions
##
## This component provides a tabbed interface showing:
## - Current roster grouped by position
## - Position needs with color-coded priorities
## - Depth chart visualization
##
## Purpose: Helps user understand which positions to target in the draft.
##
## Usage:
##   roster_view.initialize(user_team_id, world_state, positions_cfg, main_cfg)
##   roster_view.refresh_after_pick(new_pick)
##
## No RNG usage - pure display component.
extends TabContainer
class_name PreDraftRosterView

const TeamNeeds = preload("res://scripts/core/roster/TeamNeeds.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")

## Priority threshold constants (from TeamNeeds)
const PRIORITY_CRITICAL := 0.9
const PRIORITY_HIGH := 0.7

## Weak player rating threshold - players below this are highlighted in orange
## Rationale: 65 represents the boundary between "below average starter" (60-65)
## and "backup/depth quality" (65-70). Players below this threshold at starter
## positions represent significant roster weaknesses requiring immediate attention.
const WEAK_RATING_THRESHOLD := 65.0

## Standard NFL positions in display order
const POSITIONS_ORDER := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

## Offensive positions for depth chart grouping
const OFFENSIVE_POSITIONS := ["QB", "RB", "WR", "TE", "OL"]
const DEFENSIVE_POSITIONS := ["DL", "EDGE", "LB", "CB", "S"]
const SPECIAL_TEAMS_POSITIONS := ["K", "P"]

## Colors for priority display
const COLOR_CRITICAL := Color(0.9, 0.2, 0.2)  # Red
const COLOR_HIGH := Color(0.9, 0.8, 0.2)       # Yellow
const COLOR_ADEQUATE := Color(0.2, 0.8, 0.2)   # Green
const COLOR_WEAK := Color(0.9, 0.5, 0.2)       # Orange for weak positions

## UI References - populated in _ready or passed via initialize
var roster_tab: Control = null
var roster_scroll: ScrollContainer = null
var roster_list: VBoxContainer = null
var roster_sort_button: OptionButton = null

var needs_tab: Control = null
var needs_recommendation_label: Label = null
var needs_grid: GridContainer = null

var depth_tab: Control = null
var depth_offense_container: VBoxContainer = null
var depth_defense_container: VBoxContainer = null

## State
var _user_team_id: String = ""
var _world_state: Dictionary = {}
var _positions_cfg: Dictionary = {}
var _main_cfg: Dictionary = {}
var _roster: Roster = null
var _roster_data: Dictionary = {}  # Raw roster dictionary
var _position_needs: Dictionary = {}
var _players_by_position: Dictionary = {}
var _current_sort: String = "position"  # position, overall, age, contract

## Performance tracking
var _last_render_time_ms: float = 0.0


func _ready() -> void:
	# Setup tabs and UI structure
	_create_ui_structure()


## Initialize the roster view with team data
##
## Parameters:
##   user_team_id: ID of the user's team
##   world_state: Complete world state dictionary
##   positions_cfg: Position configuration for rating calculations
##   main_cfg: Main configuration with class rules
func initialize(
	user_team_id: String,
	world_state: Dictionary,
	positions_cfg: Dictionary = {},
	main_cfg: Dictionary = {}
) -> void:
	_user_team_id = user_team_id
	_world_state = world_state
	_positions_cfg = positions_cfg
	_main_cfg = main_cfg

	var start_time := Time.get_ticks_usec()

	# Load roster data
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	_roster_data = rosters.get(user_team_id, {"players": []})

	# Create Roster resource if depth chart data exists
	if _roster_data.has("depth_chart") or _roster_data.has("entries"):
		_roster = Roster.new()
		_roster.from_dict(_roster_data)
	else:
		# Create roster from players array
		_roster = Roster.new()
		var players: Array = _roster_data.get("players", [])
		for player in players:
			var p: Dictionary = player
			_roster.entries.append({
				"player_id": String(p.get("player_id", p.get("id", ""))),
				"status": "active",
				"position": String(p.get("position", "")),
				"name": String(p.get("name", "Unknown")),
				"age": int(p.get("age", 22)),
				"composite_score": float(p.get("composite_score", p.get("overall", 50.0))),
				"contract": p.get("contract", {})
			})

	# Group players by position
	_build_players_by_position()

	# Calculate position needs
	_calculate_position_needs()

	# Populate all tabs
	_populate_roster_list()
	_populate_needs_grid()
	_populate_depth_chart()

	var elapsed := (Time.get_ticks_usec() - start_time) / 1000.0
	_last_render_time_ms = elapsed

	if elapsed > 50.0:
		push_warning("[PreDraftRosterView] Render time %.1fms exceeds 50ms target" % elapsed)


## Refresh the roster view after a draft pick
##
## Parameters:
##   new_pick: Dictionary with pick information including the new player
func refresh_after_pick(new_pick: Dictionary) -> void:
	if String(new_pick.get("team_id", "")) != _user_team_id:
		return  # Not our pick, nothing to update

	var start_time := Time.get_ticks_usec()

	# Add the new player to our local roster data
	var new_player: Dictionary = new_pick.get("player_data", {})
	if new_player.is_empty():
		# Build player data from pick info
		new_player = {
			"player_id": String(new_pick.get("player_id", "")),
			"name": String(new_pick.get("player_name", "Unknown")),
			"position": String(new_pick.get("position", "")),
			"age": 22,  # Rookies default to 22
			"composite_score": float(new_pick.get("overall", 70.0)),
			"contract": new_pick.get("contract", {})
		}

	# Add to roster entries
	_roster.entries.append({
		"player_id": String(new_player.get("player_id", new_player.get("id", ""))),
		"status": "active",
		"position": String(new_player.get("position", "")),
		"name": String(new_player.get("name", "Unknown")),
		"age": int(new_player.get("age", 22)),
		"composite_score": float(new_player.get("composite_score", new_player.get("overall", 50.0))),
		"contract": new_player.get("contract", {})
	})

	# Add to players list
	var players: Array = _roster_data.get("players", [])
	players.append(new_player)
	_roster_data["players"] = players

	# Rebuild position groupings
	_build_players_by_position()

	# Recalculate position needs
	_calculate_position_needs()

	# Refresh all displays
	_populate_roster_list()
	_populate_needs_grid()
	_populate_depth_chart()

	var elapsed := (Time.get_ticks_usec() - start_time) / 1000.0
	_last_render_time_ms = elapsed


## Get the last render time in milliseconds (for performance testing)
func get_last_render_time_ms() -> float:
	return _last_render_time_ms


## Get the current position needs dictionary
func get_position_needs() -> Dictionary:
	return _position_needs


## Get players grouped by position
func get_players_by_position() -> Dictionary:
	return _players_by_position


# =============================================================================
# UI CREATION
# =============================================================================

## Create the tabbed UI structure
func _create_ui_structure() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()

	# Tab 1: Current Roster
	roster_tab = _create_roster_tab()
	add_child(roster_tab)

	# Tab 2: Position Needs
	needs_tab = _create_needs_tab()
	add_child(needs_tab)

	# Tab 3: Depth Chart
	depth_tab = _create_depth_tab()
	add_child(depth_tab)


## Create the roster list tab
func _create_roster_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Roster"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header with sort controls
	var header := HBoxContainer.new()
	header.name = "Header"

	var title := Label.new()
	title.text = "Current Roster"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var sort_label := Label.new()
	sort_label.text = "Sort by:"
	header.add_child(sort_label)

	roster_sort_button = OptionButton.new()
	roster_sort_button.add_item("Position", 0)
	roster_sort_button.add_item("Overall", 1)
	roster_sort_button.add_item("Age", 2)
	roster_sort_button.add_item("Contract", 3)
	roster_sort_button.item_selected.connect(_on_sort_changed)
	header.add_child(roster_sort_button)

	tab.add_child(header)

	# Scrollable roster list
	roster_scroll = ScrollContainer.new()
	roster_scroll.name = "RosterScroll"
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	roster_list = VBoxContainer.new()
	roster_list.name = "RosterList"
	roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(roster_list)

	tab.add_child(roster_scroll)

	return tab


## Create the position needs tab
func _create_needs_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "Needs"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Recommendation header
	needs_recommendation_label = Label.new()
	needs_recommendation_label.name = "RecommendationLabel"
	needs_recommendation_label.add_theme_font_size_override("font_size", 14)
	needs_recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tab.add_child(needs_recommendation_label)

	var sep := HSeparator.new()
	tab.add_child(sep)

	# Grid for position needs
	needs_grid = GridContainer.new()
	needs_grid.name = "NeedsGrid"
	needs_grid.columns = 4  # 4 positions per row
	needs_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_grid.add_theme_constant_override("h_separation", 10)
	needs_grid.add_theme_constant_override("v_separation", 10)
	tab.add_child(needs_grid)

	return tab


## Create the depth chart tab
func _create_depth_tab() -> Control:
	var tab := HBoxContainer.new()
	tab.name = "Depth"
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Offense side
	var offense_panel := PanelContainer.new()
	offense_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var offense_margin := MarginContainer.new()
	offense_margin.add_theme_constant_override("margin_left", 5)
	offense_margin.add_theme_constant_override("margin_top", 5)
	offense_margin.add_theme_constant_override("margin_right", 5)
	offense_margin.add_theme_constant_override("margin_bottom", 5)

	var offense_vbox := VBoxContainer.new()

	var offense_title := Label.new()
	offense_title.text = "OFFENSE"
	offense_title.add_theme_font_size_override("font_size", 14)
	offense_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offense_vbox.add_child(offense_title)

	var offense_sep := HSeparator.new()
	offense_vbox.add_child(offense_sep)

	var offense_scroll := ScrollContainer.new()
	offense_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	depth_offense_container = VBoxContainer.new()
	depth_offense_container.name = "OffenseDepth"
	offense_scroll.add_child(depth_offense_container)

	offense_vbox.add_child(offense_scroll)
	offense_margin.add_child(offense_vbox)
	offense_panel.add_child(offense_margin)
	tab.add_child(offense_panel)

	# Separator
	var vsep := VSeparator.new()
	tab.add_child(vsep)

	# Defense side
	var defense_panel := PanelContainer.new()
	defense_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var defense_margin := MarginContainer.new()
	defense_margin.add_theme_constant_override("margin_left", 5)
	defense_margin.add_theme_constant_override("margin_top", 5)
	defense_margin.add_theme_constant_override("margin_right", 5)
	defense_margin.add_theme_constant_override("margin_bottom", 5)

	var defense_vbox := VBoxContainer.new()

	var defense_title := Label.new()
	defense_title.text = "DEFENSE"
	defense_title.add_theme_font_size_override("font_size", 14)
	defense_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defense_vbox.add_child(defense_title)

	var defense_sep := HSeparator.new()
	defense_vbox.add_child(defense_sep)

	var defense_scroll := ScrollContainer.new()
	defense_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	depth_defense_container = VBoxContainer.new()
	depth_defense_container.name = "DefenseDepth"
	defense_scroll.add_child(depth_defense_container)

	defense_vbox.add_child(defense_scroll)
	defense_margin.add_child(defense_vbox)
	defense_panel.add_child(defense_margin)
	tab.add_child(defense_panel)

	return tab


# =============================================================================
# DATA PROCESSING
# =============================================================================

## Build the players_by_position dictionary from roster data
func _build_players_by_position() -> void:
	_players_by_position.clear()

	var players: Array = _roster_data.get("players", [])
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		if position.is_empty():
			continue

		if not _players_by_position.has(position):
			_players_by_position[position] = []

		# Calculate overall rating (cache in player dict to avoid recalculation)
		var overall: float
		if p.has("_cached_overall"):
			overall = float(p.get("_cached_overall", 50.0))
		else:
			overall = PlayerRatingCalculator.calculate_overall_rating(
				p, _positions_cfg, class_rules
			)
			p["_cached_overall"] = overall

		# Build player entry with all needed data
		var entry := {
			"player_id": String(p.get("player_id", p.get("id", ""))),
			"name": String(p.get("name", "Unknown")),
			"position": position,
			"overall": overall,
			"age": int(p.get("age", 22)),
			"contract": p.get("contract", {}),
		}

		_players_by_position[position].append(entry)

	# Sort each position group by overall rating descending
	for position in _players_by_position.keys():
		var pos_players: Array = _players_by_position[position]
		pos_players.sort_custom(func(a, b):
			return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
		)


## Calculate position needs using TeamNeeds - single source of truth
func _calculate_position_needs() -> void:
	_position_needs.clear()

	# CRITICAL: TeamNeeds is the single source of truth for position needs
	# If it fails, we fail loudly rather than producing inconsistent results
	if _roster == null or _positions_cfg.is_empty():
		push_error("[PreDraftRosterView] TeamNeeds assessment failed - roster or positions_cfg is missing")
		# Leave _position_needs empty - UI will show error state
		return

	_position_needs = TeamNeeds.assess_team_needs(
		_roster,
		_positions_cfg,
		_main_cfg
	)

	# Validate that we got results
	if _position_needs.is_empty():
		push_error("[PreDraftRosterView] TeamNeeds assessment returned empty results")
		# UI will handle empty state appropriately


# =============================================================================
# UI POPULATION
# =============================================================================

## Populate the roster list tab
func _populate_roster_list() -> void:
	if roster_list == null:
		return

	# Clear existing content
	for child in roster_list.get_children():
		child.queue_free()

	var players: Array = _roster_data.get("players", [])
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	# Build flat list with all player data
	var all_players: Array = []
	for player in players:
		var p: Dictionary = player

		# Use cached rating if available (prevents redundant calculations)
		var overall: float
		if p.has("_cached_overall"):
			overall = float(p.get("_cached_overall", 50.0))
		else:
			overall = PlayerRatingCalculator.calculate_overall_rating(
				p, _positions_cfg, class_rules
			)
			p["_cached_overall"] = overall

		all_players.append({
			"player_id": String(p.get("player_id", p.get("id", ""))),
			"name": String(p.get("name", "Unknown")),
			"position": String(p.get("position", "")),
			"overall": overall,
			"age": int(p.get("age", 22)),
			"contract": p.get("contract", {}),
		})

	# Sort based on current sort mode
	match _current_sort:
		"position":
			all_players.sort_custom(func(a, b):
				var pos_a := POSITIONS_ORDER.find(String(a.get("position", "")))
				var pos_b := POSITIONS_ORDER.find(String(b.get("position", "")))
				if pos_a == pos_b:
					return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
				return pos_a < pos_b
			)
		"overall":
			all_players.sort_custom(func(a, b):
				return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
			)
		"age":
			all_players.sort_custom(func(a, b):
				return int(a.get("age", 99)) < int(b.get("age", 99))
			)
		"contract":
			all_players.sort_custom(func(a, b):
				var val_a := float((a.get("contract", {}) as Dictionary).get("annual_value", 0.0))
				var val_b := float((b.get("contract", {}) as Dictionary).get("annual_value", 0.0))
				return val_a > val_b
			)

	# Group by position if sorting by position
	if _current_sort == "position":
		_populate_roster_grouped_by_position(all_players)
	else:
		_populate_roster_flat(all_players)

	# Add total count
	var total_label := Label.new()
	total_label.text = "Total: %d active roster players" % all_players.size()
	total_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	roster_list.add_child(total_label)


## Populate roster list grouped by position
func _populate_roster_grouped_by_position(players: Array) -> void:
	var current_position := ""

	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))

		# Add position header if changed
		if position != current_position:
			current_position = position
			var header := Label.new()
			header.text = "--- %s ---" % position
			header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			roster_list.add_child(header)

		# Add player row
		var row := _create_player_row(p)
		roster_list.add_child(row)


## Populate roster list as flat list
func _populate_roster_flat(players: Array) -> void:
	for player in players:
		var row := _create_player_row(player)
		roster_list.add_child(row)


## Create a player row for the roster list
func _create_player_row(player: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Position badge
	var pos_label := Label.new()
	pos_label.text = String(player.get("position", "?"))
	pos_label.custom_minimum_size = Vector2(40, 0)
	pos_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	row.add_child(pos_label)

	# Name
	var name_label := Label.new()
	name_label.text = String(player.get("name", "Unknown"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Overall rating
	var overall := float(player.get("overall", 50.0))
	var ovr_label := Label.new()
	ovr_label.text = "%.0f OVR" % overall
	ovr_label.custom_minimum_size = Vector2(60, 0)

	# Color code overall
	if overall >= 80:
		ovr_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	elif overall >= 70:
		ovr_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	elif overall < WEAK_RATING_THRESHOLD:
		ovr_label.add_theme_color_override("font_color", COLOR_WEAK)
	row.add_child(ovr_label)

	# Age
	var age_label := Label.new()
	age_label.text = "Age %d" % int(player.get("age", 22))
	age_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(age_label)

	# Contract
	var contract: Dictionary = player.get("contract", {})
	var contract_label := Label.new()
	var years_remaining := int(contract.get("years_remaining", 0))
	var annual_value := float(contract.get("annual_value", 0.0))

	if years_remaining > 0:
		contract_label.text = "%dyr/$%.1fM" % [years_remaining, annual_value]
	else:
		contract_label.text = "Rookie"
	contract_label.custom_minimum_size = Vector2(80, 0)
	contract_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	row.add_child(contract_label)

	# Depth indicator
	var depth_label := Label.new()
	var pos_players: Array = _players_by_position.get(String(player.get("position", "")), [])
	var player_index := -1
	for i in range(pos_players.size()):
		if String((pos_players[i] as Dictionary).get("player_id", "")) == String(player.get("player_id", "")):
			player_index = i
			break

	var required := int(StatGenerator.STARTER_POSITION_THRESHOLDS.get(String(player.get("position", "")), 1))
	if player_index >= 0 and player_index < required:
		depth_label.text = "[STARTER]"
		depth_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	elif player_index >= 0 and player_index < required + 2:
		depth_label.text = "[BACKUP]"
		depth_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	else:
		depth_label.text = "[RESERVE]"
		depth_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	depth_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(depth_label)

	return row


## Populate the position needs grid
func _populate_needs_grid() -> void:
	if needs_grid == null or needs_recommendation_label == null:
		return

	# Clear existing content
	for child in needs_grid.get_children():
		child.queue_free()

	# Check if position needs assessment failed
	if _position_needs.is_empty():
		needs_recommendation_label.text = "ERROR: Position needs assessment unavailable. Cannot display recommendations."
		needs_recommendation_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

		var error_label := Label.new()
		error_label.text = "Position needs data is missing. Check console for errors."
		error_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		needs_grid.add_child(error_label)
		return

	# Get priority positions for recommendation text
	var priority_positions := TeamNeeds.get_priority_positions(_position_needs, 3, 0.5)

	if priority_positions.is_empty():
		needs_recommendation_label.text = "Your roster is well-balanced. Draft best player available."
	else:
		needs_recommendation_label.text = "Priority Needs: %s" % ", ".join(priority_positions)

	# Create position cells
	for position in POSITIONS_ORDER:
		var cell := _create_needs_cell(position)
		needs_grid.add_child(cell)


## Create a cell for the needs grid
func _create_needs_cell(position: String) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(80, 80)

	# Get priority for this position
	var priority := float(_position_needs.get(position, 0.3))

	# Get players at this position
	var pos_players: Array = _players_by_position.get(position, [])
	var required := int(StatGenerator.STARTER_POSITION_THRESHOLDS.get(position, 1))

	# Get top player info
	var top_name := "None"
	var top_rating := 0.0
	if not pos_players.is_empty():
		var top_player: Dictionary = pos_players[0]
		top_name = String(top_player.get("name", "Unknown"))
		# Truncate long names
		if top_name.length() > 12:
			top_name = top_name.substr(0, 10) + ".."
		top_rating = float(top_player.get("overall", 0.0))

	# Create style for background color
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	if priority >= PRIORITY_CRITICAL:
		style.bg_color = COLOR_CRITICAL.darkened(0.5)
	elif priority >= PRIORITY_HIGH:
		style.bg_color = COLOR_HIGH.darkened(0.5)
	else:
		style.bg_color = COLOR_ADEQUATE.darkened(0.6)

	cell.add_theme_stylebox_override("panel", style)

	# Content
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)

	# Position abbreviation
	var pos_label := Label.new()
	pos_label.text = position
	pos_label.add_theme_font_size_override("font_size", 14)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pos_label)

	# Starter count
	var count_label := Label.new()
	count_label.text = "%d / %d" % [min(pos_players.size(), required), required]
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(count_label)

	# Top player
	var top_label := Label.new()
	if top_rating > 0:
		top_label.text = "%s (%.0f)" % [top_name, top_rating]
	else:
		top_label.text = "No players"
	top_label.add_theme_font_size_override("font_size", 10)
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Color code weak top player
	if top_rating > 0 and top_rating < WEAK_RATING_THRESHOLD:
		top_label.add_theme_color_override("font_color", COLOR_WEAK)

	vbox.add_child(top_label)

	margin.add_child(vbox)
	cell.add_child(margin)

	return cell


## Populate the depth chart tab
func _populate_depth_chart() -> void:
	if depth_offense_container == null or depth_defense_container == null:
		return

	# Clear existing content
	for child in depth_offense_container.get_children():
		child.queue_free()
	for child in depth_defense_container.get_children():
		child.queue_free()

	# Populate offense
	for position in OFFENSIVE_POSITIONS:
		var pos_row := _create_depth_position_row(position)
		depth_offense_container.add_child(pos_row)

	# Populate defense
	for position in DEFENSIVE_POSITIONS:
		var pos_row := _create_depth_position_row(position)
		depth_defense_container.add_child(pos_row)


## Create a depth chart row for a position
func _create_depth_position_row(position: String) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Position header
	var header := Label.new()
	header.text = position
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(header)

	# Get players at this position
	var pos_players: Array = _players_by_position.get(position, [])
	var required := int(StatGenerator.STARTER_POSITION_THRESHOLDS.get(position, 1))

	# Starter row
	var starter_row := HBoxContainer.new()
	var starter_label := Label.new()
	starter_label.text = "S: "
	starter_label.add_theme_font_size_override("font_size", 11)
	starter_label.custom_minimum_size = Vector2(20, 0)
	starter_row.add_child(starter_label)

	if pos_players.size() >= 1:
		for i in range(min(required, pos_players.size())):
			var player: Dictionary = pos_players[i]
			var name := String(player.get("name", "?"))
			if name.length() > 10:
				name = name.substr(0, 8) + ".."
			var rating := float(player.get("overall", 0.0))

			var player_label := Label.new()
			player_label.text = "%s (%.0f)" % [name, rating]
			player_label.add_theme_font_size_override("font_size", 10)

			# Highlight weak starters
			if rating < WEAK_RATING_THRESHOLD:
				player_label.add_theme_color_override("font_color", COLOR_WEAK)

			starter_row.add_child(player_label)

			if i < min(required, pos_players.size()) - 1:
				var sep := Label.new()
				sep.text = " | "
				sep.add_theme_font_size_override("font_size", 10)
				sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				starter_row.add_child(sep)
	else:
		var empty_label := Label.new()
		empty_label.text = "EMPTY"
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", COLOR_CRITICAL)
		starter_row.add_child(empty_label)

	container.add_child(starter_row)

	# Backup row
	var backup_row := HBoxContainer.new()
	var backup_label := Label.new()
	backup_label.text = "B: "
	backup_label.add_theme_font_size_override("font_size", 11)
	backup_label.custom_minimum_size = Vector2(20, 0)
	backup_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	backup_row.add_child(backup_label)

	var backup_start: int = required
	var backup_end: int = min(required + 2, pos_players.size())

	if backup_start < pos_players.size():
		for i in range(backup_start, backup_end):
			var player: Dictionary = pos_players[i]
			var name := String(player.get("name", "?"))
			if name.length() > 10:
				name = name.substr(0, 8) + ".."
			var rating := float(player.get("overall", 0.0))

			var player_label := Label.new()
			player_label.text = "%s (%.0f)" % [name, rating]
			player_label.add_theme_font_size_override("font_size", 10)
			player_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

			backup_row.add_child(player_label)

			if i < backup_end - 1:
				var sep := Label.new()
				sep.text = " | "
				sep.add_theme_font_size_override("font_size", 10)
				sep.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
				backup_row.add_child(sep)
	else:
		var none_label := Label.new()
		none_label.text = "None"
		none_label.add_theme_font_size_override("font_size", 10)
		none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		backup_row.add_child(none_label)

	container.add_child(backup_row)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	container.add_child(sep)

	return container


# =============================================================================
# EVENT HANDLERS
# =============================================================================

## Handle sort mode change
func _on_sort_changed(index: int) -> void:
	match index:
		0:
			_current_sort = "position"
		1:
			_current_sort = "overall"
		2:
			_current_sort = "age"
		3:
			_current_sort = "contract"

	_populate_roster_list()
