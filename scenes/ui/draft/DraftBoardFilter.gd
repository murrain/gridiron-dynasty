## DraftBoardFilter - Filter controls for draft board
##
## ARCHITECTURAL PATTERN: UI Component
##
## Provides position filter, name search, and sort options for the draft board.
## Emits filters_changed signal when any filter is modified.
##
## Design Philosophy:
##   - Purely presentational - does not perform filtering itself
##   - Emits signals with filter state - parent handles filtering logic
##   - No RNG usage
##   - Immediate feedback - filter changes trigger instant signal emission
##
## Integration Points:
##   - DraftDayUI: Receives signals and filters player list
##   - UserPickModal: Alternative integration point
##
## Usage:
##   filters.filters_changed.connect(_on_filters_changed)
##   func _on_filters_changed(position: String, search: String, sort_mode: String) -> void:
##       _apply_filters(position, search, sort_mode)
##
extends HBoxContainer
class_name DraftBoardFilter

## Emitted when any filter value changes
## @param position: Selected position or "All" for all positions
## @param search: Search text (case-insensitive name matching)
## @param sort_mode: Sort mode string (Overall, Scheme Fit, Position Need, Mock Rank)
signal filters_changed(position: String, search: String, sort_mode: String)

## All NFL positions for filtering
const POSITIONS := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

## Sort mode options
const SORT_MODES := ["Overall", "Scheme Fit", "Position Need", "Mock Rank"]

## Sort mode enum for programmatic access
enum SortMode {
	OVERALL,
	SCHEME_FIT,
	POSITION_NEED,
	MOCK_RANK
}

## UI References - created dynamically if not present in scene tree
var position_filter: OptionButton
var search_box: LineEdit
var sort_options: OptionButton
var clear_button: Button

## Current filter state (for external queries)
var _current_position: String = "All"
var _current_search: String = ""
var _current_sort_mode: String = "Overall"

## Debounce timer for search input
var _search_debounce_timer: Timer
const SEARCH_DEBOUNCE_MS := 150.0  # Debounce delay in milliseconds


func _ready() -> void:
	_setup_ui()
	_connect_signals()


## Setup the UI controls
func _setup_ui() -> void:
	# Position filter label
	var pos_label := Label.new()
	pos_label.text = "Position:"
	add_child(pos_label)

	# Position filter dropdown
	position_filter = OptionButton.new()
	position_filter.name = "PositionFilter"
	position_filter.custom_minimum_size = Vector2(100, 0)
	_populate_position_filter()
	add_child(position_filter)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(20, 0)
	add_child(spacer1)

	# Search label
	var search_label := Label.new()
	search_label.text = "Search:"
	add_child(search_label)

	# Search box
	search_box = LineEdit.new()
	search_box.name = "SearchBox"
	search_box.placeholder_text = "Player name..."
	search_box.custom_minimum_size = Vector2(150, 0)
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(search_box)

	# Clear search button
	clear_button = Button.new()
	clear_button.name = "ClearButton"
	clear_button.text = "X"
	clear_button.tooltip_text = "Clear search"
	clear_button.custom_minimum_size = Vector2(30, 0)
	add_child(clear_button)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(20, 0)
	add_child(spacer2)

	# Sort label
	var sort_label := Label.new()
	sort_label.text = "Sort by:"
	add_child(sort_label)

	# Sort options dropdown
	sort_options = OptionButton.new()
	sort_options.name = "SortOptions"
	sort_options.custom_minimum_size = Vector2(130, 0)
	_populate_sort_options()
	add_child(sort_options)

	# Setup debounce timer for search
	_search_debounce_timer = Timer.new()
	_search_debounce_timer.one_shot = true
	_search_debounce_timer.wait_time = SEARCH_DEBOUNCE_MS / 1000.0
	add_child(_search_debounce_timer)


## Populate position filter with all positions
func _populate_position_filter() -> void:
	position_filter.clear()
	position_filter.add_item("All", 0)

	for i in range(POSITIONS.size()):
		position_filter.add_item(POSITIONS[i], i + 1)


## Populate sort options
func _populate_sort_options() -> void:
	sort_options.clear()

	for i in range(SORT_MODES.size()):
		sort_options.add_item(SORT_MODES[i], i)


## Connect UI signals
func _connect_signals() -> void:
	position_filter.item_selected.connect(_on_position_changed)
	search_box.text_changed.connect(_on_search_text_changed)
	sort_options.item_selected.connect(_on_sort_changed)
	clear_button.pressed.connect(_on_clear_pressed)
	_search_debounce_timer.timeout.connect(_on_search_debounce_timeout)


## Handle position filter change
func _on_position_changed(index: int) -> void:
	if index == 0:
		_current_position = "All"
	else:
		_current_position = position_filter.get_item_text(index)

	_emit_filters_changed()


## Handle search text change (with debounce)
func _on_search_text_changed(new_text: String) -> void:
	# Restart debounce timer
	_search_debounce_timer.stop()
	_search_debounce_timer.start()


## Handle debounce timeout - emit the search change
func _on_search_debounce_timeout() -> void:
	_current_search = search_box.text.strip_edges()
	_emit_filters_changed()


## Handle sort option change
func _on_sort_changed(index: int) -> void:
	_current_sort_mode = sort_options.get_item_text(index)
	_emit_filters_changed()


## Handle clear button press
func _on_clear_pressed() -> void:
	search_box.text = ""
	_current_search = ""
	_emit_filters_changed()


## Emit the filters_changed signal with current state
func _emit_filters_changed() -> void:
	filters_changed.emit(_current_position, _current_search, _current_sort_mode)


## Get current filter state
## Returns dictionary with position, search, and sort_mode keys
func get_filter_state() -> Dictionary:
	return {
		"position": _current_position,
		"search": _current_search,
		"sort_mode": _current_sort_mode
	}


## Set filter state programmatically
## @param position: Position to filter (or "All")
## @param search: Search text
## @param sort_mode: Sort mode string
func set_filter_state(position: String, search: String, sort_mode: String) -> void:
	# Update position
	if position == "All":
		position_filter.select(0)
		_current_position = "All"
	else:
		var idx := POSITIONS.find(position)
		if idx >= 0:
			position_filter.select(idx + 1)
			_current_position = position

	# Update search
	search_box.text = search
	_current_search = search

	# Update sort mode
	var sort_idx := SORT_MODES.find(sort_mode)
	if sort_idx >= 0:
		sort_options.select(sort_idx)
		_current_sort_mode = sort_mode

	# Don't emit signal when setting programmatically
	# Caller can call _emit_filters_changed() if needed


## Reset all filters to defaults
func reset_filters() -> void:
	position_filter.select(0)
	_current_position = "All"

	search_box.text = ""
	_current_search = ""

	sort_options.select(0)
	_current_sort_mode = "Overall"

	_emit_filters_changed()


## Get the current sort mode as enum
func get_sort_mode_enum() -> SortMode:
	match _current_sort_mode:
		"Overall":
			return SortMode.OVERALL
		"Scheme Fit":
			return SortMode.SCHEME_FIT
		"Position Need":
			return SortMode.POSITION_NEED
		"Mock Rank":
			return SortMode.MOCK_RANK
		_:
			return SortMode.OVERALL


## Check if a player matches the current filters
## This is a convenience method for external use
## @param player: Player dictionary with name and position
## @return bool: True if player matches all active filters
static func player_matches_filters(
	player: Dictionary,
	position_filter_val: String,
	search_filter_val: String
) -> bool:
	# Position filter
	if position_filter_val != "All":
		var player_position := String(player.get("position", ""))
		if player_position != position_filter_val:
			return false

	# Name search filter (case-insensitive)
	if not search_filter_val.is_empty():
		var player_name := String(player.get("name", "")).to_lower()
		if search_filter_val.to_lower() not in player_name:
			return false

	return true
