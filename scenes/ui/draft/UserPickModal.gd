## UserPickModal - Embedded panel for user draft pick selection
##
## An embedded panel (not a Window) displayed within DraftDayUI when
## it's the user's turn to make a draft pick. Provides:
## - Player list sorted by value/position
## - Player detail panel with key stats
## - Draft button to select the player
## - Auto-pick BPA button for quick selection
##
## This is designed for performance (<100ms render time) and
## integrates directly into the DraftDayUI scene tree.
##
## Usage:
##   var modal = UserPickModal.new()
##   modal.player_selected.connect(_on_player_selected)
##   modal.auto_pick_requested.connect(_on_auto_pick)
##   modal.show_pick(round, pick, available_players)
##
extends PanelContainer
class_name UserPickModal

## Emitted when user selects a player to draft
signal player_selected(player_id: String)

## Emitted when user requests auto-pick (BPA)
signal auto_pick_requested

## Current pick context
var _round: int = 0
var _pick: int = 0
var _available_players: Array = []
var _selected_player_id: String = ""
var _selected_index: int = -1

## Performance tracking
var _render_start_time: int = 0

## UI References
@onready var title_label: Label = $VBoxContainer/Header/TitleLabel
@onready var player_list: ItemList = $VBoxContainer/MainContent/LeftPanel/PlayerList
@onready var detail_panel: PanelContainer = $VBoxContainer/MainContent/RightPanel/DetailPanel
@onready var player_name_label: Label = $VBoxContainer/MainContent/RightPanel/DetailPanel/VBoxContainer/PlayerNameLabel
@onready var position_label: Label = $VBoxContainer/MainContent/RightPanel/DetailPanel/VBoxContainer/PositionLabel
@onready var college_label: Label = $VBoxContainer/MainContent/RightPanel/DetailPanel/VBoxContainer/CollegeLabel
@onready var overall_label: Label = $VBoxContainer/MainContent/RightPanel/DetailPanel/VBoxContainer/OverallLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/MainContent/RightPanel/DetailPanel/VBoxContainer/StatsContainer
@onready var draft_button: Button = $VBoxContainer/Footer/DraftButton
@onready var auto_button: Button = $VBoxContainer/Footer/AutoButton


func _ready() -> void:
	# Validate critical UI nodes
	if not player_list:
		push_error("[UserPickModal] player_list node not found - modal will not function")
		return

	if not draft_button:
		push_error("[UserPickModal] draft_button node not found - cannot draft players")
		return

	# Connect signals
	player_list.item_selected.connect(_on_player_selected)

	if draft_button:
		draft_button.pressed.connect(_on_draft_pressed)
		draft_button.disabled = true

	if auto_button:
		auto_button.pressed.connect(_on_auto_pick_pressed)

	# Start hidden
	visible = false
	_clear_detail_panel()


## Show the pick modal with available players
## Performance target: <100ms render time
func show_pick(round_num: int, pick_num: int, available_players: Array) -> void:
	_render_start_time = Time.get_ticks_usec()

	_round = round_num
	_pick = pick_num
	_available_players = available_players
	_selected_player_id = ""
	_selected_index = -1

	# Update title with player count
	if title_label:
		var player_count := available_players.size()
		title_label.text = "Your Pick - Round %d, Pick #%d (%d players available)" % [
			round_num, pick_num, player_count
		]

	# Populate player list
	_populate_player_list(available_players)

	# Reset detail panel
	_clear_detail_panel()

	# Disable draft button until selection
	if draft_button:
		draft_button.disabled = true
		draft_button.text = "DRAFT"

	# Show the modal
	visible = true

	# Log render time for performance monitoring
	var render_time_ms := (Time.get_ticks_usec() - _render_start_time) / 1000.0
	if render_time_ms > 100.0:
		push_warning("[UserPickModal] Render time exceeded target: %.1fms (target: <100ms)" % render_time_ms)
	else:
		print("[UserPickModal] Rendered in %.1fms" % render_time_ms)


## Hide the modal
func hide_modal() -> void:
	visible = false
	_clear_detail_panel()


## Populate the player list with available players
## Performance-optimized with configurable display limit
func _populate_player_list(players: Array) -> void:
	if not player_list:
		return

	player_list.clear()

	# Display limit: Show top 150 players by default for performance
	# For larger pools (250+), this prevents UI lag while showing a reasonable selection
	# Users can use search/filter features to find specific players beyond the limit
	var display_limit := 150
	var total_count := players.size()
	var displayed_count: int = min(display_limit, total_count)

	for i in range(displayed_count):
		var p: Dictionary = players[i]
		var position := String(p.get("position", ""))
		var name := String(p.get("name", "Unknown"))
		var overall := float(p.get("overall", 50.0))
		var college := String(p.get("college", ""))

		# Format: "[POS] Name - XX OVR"
		var display_text := "[%s] %s - %.0f OVR" % [position, name, overall]
		if not college.is_empty():
			display_text += " (%s)" % college

		var idx := player_list.add_item(display_text)
		player_list.set_item_metadata(idx, String(p.get("player_id", "")))

	# Add informational message if list is truncated
	if total_count > display_limit:
		var info_msg := "--- Showing top %d of %d players ---" % [display_limit, total_count]
		player_list.add_item(info_msg)
		# Set metadata to empty string so it can't be selected
		player_list.set_item_metadata(displayed_count, "")
		player_list.set_item_disabled(displayed_count, true)
		player_list.set_item_selectable(displayed_count, false)


## Handle player selection in the list
func _on_player_selected(index: int) -> void:
	if index < 0 or index >= player_list.item_count:
		return

	_selected_index = index
	_selected_player_id = String(player_list.get_item_metadata(index))

	# Find player data
	var player_data := _get_player_data(_selected_player_id)
	if player_data.is_empty():
		return

	_update_detail_panel(player_data)

	# Enable draft button
	if draft_button:
		draft_button.disabled = false
		draft_button.text = "DRAFT %s" % String(player_data.get("name", "Unknown"))


## Update the detail panel with player info
func _update_detail_panel(player: Dictionary) -> void:
	var name := String(player.get("name", "Unknown"))
	var position := String(player.get("position", ""))
	var college := String(player.get("college", ""))
	var overall := float(player.get("overall", 50.0))
	var age := int(player.get("age", 22))
	var height := String(player.get("height", ""))
	var weight := int(player.get("weight", 0))

	if player_name_label:
		player_name_label.text = name

	if position_label:
		position_label.text = "Position: %s" % position

	if college_label:
		college_label.text = "College: %s" % college if not college.is_empty() else "College: -"

	if overall_label:
		overall_label.text = "Overall: %.0f" % overall

	# Update stats container with top stats
	_update_stats_container(player, age, height, weight)


## Update stats container with player attributes
func _update_stats_container(player: Dictionary, age: int, height: String, weight: int) -> void:
	if not stats_container:
		return

	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()

	# Add age
	var age_label := Label.new()
	age_label.text = "Age: %d" % age
	stats_container.add_child(age_label)

	# Add height/weight if available
	if not height.is_empty() and weight > 0:
		var size_label := Label.new()
		size_label.text = "Size: %s, %d lbs" % [height, weight]
		stats_container.add_child(size_label)

	# Add top 3 stats if available in player data
	var stats: Dictionary = player.get("stats", {})
	if not stats.is_empty():
		var separator := HSeparator.new()
		stats_container.add_child(separator)

		var stats_title := Label.new()
		stats_title.text = "Key Attributes:"
		stats_title.add_theme_font_size_override("font_size", 14)
		stats_container.add_child(stats_title)

		# Get top stats for this player's position
		var top_stats := _get_top_stats_for_position(String(player.get("position", "")), stats)
		for stat_entry in top_stats:
			var stat_label := Label.new()
			stat_label.text = "%s: %.0f" % [stat_entry.get("name", ""), stat_entry.get("value", 0)]
			stats_container.add_child(stat_label)


## Get top stats for a given position
func _get_top_stats_for_position(position: String, stats: Dictionary) -> Array:
	var result: Array = []

	# Define key stats per position group
	var key_stats: Array = []
	match position:
		"QB":
			key_stats = ["arm_strength", "accuracy", "decision_making", "awareness"]
		"RB":
			key_stats = ["speed", "agility", "vision", "power"]
		"WR":
			key_stats = ["speed", "route_running", "catching", "agility"]
		"TE":
			key_stats = ["blocking", "catching", "speed", "strength"]
		"OL":
			key_stats = ["pass_blocking", "run_blocking", "strength", "awareness"]
		"DL", "EDGE":
			key_stats = ["pass_rush", "run_defense", "strength", "speed"]
		"LB":
			key_stats = ["tackling", "coverage", "speed", "awareness"]
		"CB":
			key_stats = ["coverage", "speed", "agility", "awareness"]
		"S":
			key_stats = ["coverage", "tackling", "speed", "awareness"]
		_:
			key_stats = ["speed", "strength", "agility", "awareness"]

	# Extract top 3 stats with values
	var count := 0
	for stat_name in key_stats:
		if count >= 3:
			break
		if stats.has(stat_name):
			result.append({
				"name": _format_stat_name(stat_name),
				"value": float(stats.get(stat_name, 0))
			})
			count += 1

	return result


## Format stat name for display (snake_case to Title Case)
func _format_stat_name(stat_name: String) -> String:
	return stat_name.replace("_", " ").capitalize()


## Clear the detail panel to initial state
func _clear_detail_panel() -> void:
	if player_name_label:
		player_name_label.text = "Select a Player"

	if position_label:
		position_label.text = "Position: -"

	if college_label:
		college_label.text = "College: -"

	if overall_label:
		overall_label.text = "Overall: -"

	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()


## Get player data by ID from available players
func _get_player_data(player_id: String) -> Dictionary:
	for player in _available_players:
		var p: Dictionary = player
		if String(p.get("player_id", "")) == player_id:
			return p
	return {}


## Get the selected player ID
func _get_selected_player_id() -> String:
	return _selected_player_id


## Handle Draft button press
func _on_draft_pressed() -> void:
	if _selected_player_id.is_empty():
		push_warning("[UserPickModal] No player selected")
		return

	player_selected.emit(_selected_player_id)
	hide_modal()


## Handle Auto-Pick BPA button press
func _on_auto_pick_pressed() -> void:
	auto_pick_requested.emit()
	hide_modal()


## Get current round number
func get_current_round() -> int:
	return _round


## Get current pick number
func get_current_pick() -> int:
	return _pick


## Check if modal is visible
func is_showing() -> bool:
	return visible
