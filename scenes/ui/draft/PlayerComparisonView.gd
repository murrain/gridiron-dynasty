## PlayerComparisonView - Side-by-side player comparison modal
##
## ARCHITECTURAL PATTERN: UI Component (Modal Window)
##
## Displays 2-3 players side-by-side for comparison during draft.
## Shows key attributes, stats, scheme fit, and contract projection.
## Allows user to select a player directly from the comparison view.
##
## Design Philosophy:
##   - Purely presentational - receives player data, displays it
##   - No RNG usage
##   - Emits signal when player is chosen
##   - Self-contained modal that can be shown/hidden
##
## Integration Points:
##   - DraftDayUI: Opens comparison view with selected players
##   - InteractiveDraft: Receives player_chosen signal
##
## Usage:
##   comparison_view.player_chosen.connect(_on_player_chosen)
##   comparison_view.show_comparison([player1, player2, player3])
##
extends Window
class_name PlayerComparisonView

## Emitted when user selects a player from the comparison view
## @param player_id: The ID of the chosen player
signal player_chosen(player_id: String)

## Emitted when comparison is closed without selection
signal comparison_closed()

## Maximum players to compare
const MAX_PLAYERS := 3

## Stats to display in comparison (priority order)
const DISPLAY_STATS := [
	"SPD", "ACC", "STR", "AGI", "AWR", "CAR",
	"THP", "THA", "SAC", "MAC", "DAC",
	"RTR", "CIT", "SPC", "RLS", "CAT",
	"RBK", "PBK", "RUN", "CTH", "IMP",
	"TAK", "HTP", "BSH", "PUR", "MCV", "ZCV",
	"PRC", "TKL", "POW"
]

## References to UI elements
var _main_container: VBoxContainer
var _comparison_grid: GridContainer
var _close_button: Button
var _players: Array = []

## Configuration for display
var _positions_cfg: Dictionary = {}
var _class_rules: Dictionary = {}
var _team_scheme: String = ""


func _init() -> void:
	title = "Player Comparison"
	size = Vector2i(800, 600)
	min_size = Vector2i(600, 400)
	unresizable = false
	transient = true
	exclusive = false
	always_on_top = true


func _ready() -> void:
	_setup_ui()
	close_requested.connect(_on_close_requested)


## Setup the UI structure
func _setup_ui() -> void:
	# Main margin container
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	# Main VBox container
	_main_container = VBoxContainer.new()
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_main_container)

	# Title label
	var title_label := Label.new()
	title_label.text = "Compare Players"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_container.add_child(title_label)

	# Separator
	var sep := HSeparator.new()
	_main_container.add_child(sep)

	# Scroll container for the comparison grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_main_container.add_child(scroll)

	# Comparison grid container
	_comparison_grid = GridContainer.new()
	_comparison_grid.columns = 4  # Label + up to 3 players
	_comparison_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comparison_grid.add_theme_constant_override("h_separation", 15)
	_comparison_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_comparison_grid)

	# Bottom separator
	var sep2 := HSeparator.new()
	_main_container.add_child(sep2)

	# Button row
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	_main_container.add_child(button_row)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(spacer)

	# Close button
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(100, 35)
	_close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(_close_button)


## Show comparison view with array of players
## @param players: Array of player dictionaries (2-3 players)
## @param positions_cfg: Position configuration for stat display
## @param class_rules: Class rules configuration
## @param team_scheme: User's team scheme for fit calculation
func show_comparison(
	players: Array,
	positions_cfg: Dictionary = {},
	class_rules: Dictionary = {},
	team_scheme: String = ""
) -> void:
	if players.size() < 2:
		push_warning("[PlayerComparisonView] Need at least 2 players to compare")
		return

	_players = players.slice(0, MAX_PLAYERS)
	_positions_cfg = positions_cfg
	_class_rules = class_rules
	_team_scheme = team_scheme

	# Update grid columns based on player count
	_comparison_grid.columns = _players.size() + 1

	_populate_comparison()
	popup_centered()


## Populate the comparison grid with player data
func _populate_comparison() -> void:
	# Clear existing content
	for child in _comparison_grid.get_children():
		child.queue_free()

	# Wait for cleanup
	await get_tree().process_frame

	# Header row (empty + player names)
	_add_header_row()

	# Basic info rows
	_add_row("Position", func(p): return String(p.get("position", "?")))
	_add_row("College", func(p): return String(p.get("college", p.get("college_team_id", "?"))))
	_add_row("Age", func(p): return "%d" % int(p.get("age", 22)))
	_add_row("Height/Weight", func(p):
		var height := String(p.get("height", "?"))
		var weight := int(p.get("weight", 0))
		return "%s / %d lbs" % [height, weight] if weight > 0 else height
	)

	# Overall rating
	_add_row("Overall", func(p):
		var ovr := float(p.get("overall", p.get("composite_score", 50.0)))
		return "%.0f" % ovr
	, true)

	# Separator
	_add_separator_row()

	# Core stats based on position (use first player's position for display)
	var first_position := String(_players[0].get("position", ""))
	var core_stats := _get_position_core_stats(first_position)

	for stat in core_stats:
		_add_stat_row(stat)

	# Separator
	_add_separator_row()

	# Scheme fit (if team scheme provided)
	if not _team_scheme.is_empty():
		_add_row("Scheme Fit", func(p):
			var scheme_fit: Dictionary = p.get("scheme_fit", {})
			var fit := float(scheme_fit.get(_team_scheme, 75.0))
			return _format_scheme_fit(fit)
		)

	# Contract projection (based on overall rating)
	_add_row("Contract Est.", func(p):
		var ovr := float(p.get("overall", p.get("composite_score", 50.0)))
		return _estimate_contract(ovr)
	)

	# Mock draft rank
	_add_row("Mock Rank", func(p):
		var di: Dictionary = p.get("draft_intelligence", {})
		var mock_history: Array = di.get("mock_history", [])
		if mock_history.is_empty():
			return "N/A"
		var latest: Dictionary = mock_history[-1]
		return "#%d" % int(latest.get("projected_pick", 999))
	)

	# Separator
	_add_separator_row()

	# Select buttons row
	_add_select_buttons_row()


## Add header row with player names
func _add_header_row() -> void:
	# Empty corner label
	var corner := Label.new()
	corner.text = ""
	_comparison_grid.add_child(corner)

	# Player name labels
	for player in _players:
		var p: Dictionary = player
		var name_label := Label.new()
		name_label.text = String(p.get("name", "Unknown"))
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_comparison_grid.add_child(name_label)


## Add a data row with label and values
func _add_row(label_text: String, value_func: Callable, highlight: bool = false) -> void:
	# Row label
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_comparison_grid.add_child(label)

	# Player values
	var values: Array = []
	for player in _players:
		var value: String = value_func.call(player)
		values.append(value)

	# Find best value if highlight is enabled
	var best_idx := -1
	if highlight:
		best_idx = _find_best_numeric_value(values)

	# Add value labels
	for i in range(values.size()):
		var value_label := Label.new()
		value_label.text = values[i]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if highlight and i == best_idx:
			value_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			value_label.add_theme_font_size_override("font_size", 16)

		_comparison_grid.add_child(value_label)


## Add a stat row with highlighting for best value
func _add_stat_row(stat_name: String) -> void:
	# Row label
	var label := Label.new()
	label.text = stat_name
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_comparison_grid.add_child(label)

	# Get values for each player
	var values: Array = []
	for player in _players:
		var p: Dictionary = player
		var stats: Dictionary = p.get("stats", {})
		# Try stats dict first, then top-level
		var val := float(stats.get(stat_name, p.get(stat_name, -1.0)))
		values.append(val)

	# Find best value
	var best_idx := _find_best_stat_idx(values)

	# Add value labels
	for i in range(values.size()):
		var value_label := Label.new()
		if values[i] < 0:
			value_label.text = "N/A"
		else:
			value_label.text = "%.0f" % values[i]

		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if i == best_idx and values[i] >= 0:
			value_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

		_comparison_grid.add_child(value_label)


## Add a separator row
func _add_separator_row() -> void:
	for i in range(_players.size() + 1):
		var sep := HSeparator.new()
		_comparison_grid.add_child(sep)


## Add select buttons row
func _add_select_buttons_row() -> void:
	# Empty corner
	var spacer := Control.new()
	_comparison_grid.add_child(spacer)

	# Select buttons for each player
	for player in _players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", p.get("id", "")))
		var player_name := String(p.get("name", "Unknown"))

		var btn := Button.new()
		btn.text = "Select %s" % player_name.split(" ")[-1]  # Last name only
		btn.custom_minimum_size = Vector2(120, 35)
		btn.pressed.connect(_on_player_selected.bind(player_id))
		_comparison_grid.add_child(btn)


## Get core stats for a position
func _get_position_core_stats(position: String) -> Array:
	if not _positions_cfg.is_empty() and _positions_cfg.has(position):
		var pos_cfg: Dictionary = _positions_cfg.get(position, {})
		var core: Array = pos_cfg.get("core_stats", [])
		if not core.is_empty():
			return core

	# Fallback to position-specific defaults
	match position:
		"QB":
			return ["THP", "THA", "SAC", "MAC", "DAC", "AWR"]
		"RB":
			return ["SPD", "ACC", "AGI", "CAR", "CTH", "STR"]
		"WR":
			return ["SPD", "ACC", "RTR", "CTH", "CIT", "RLS"]
		"TE":
			return ["CTH", "RBK", "SPD", "STR", "CIT", "RTR"]
		"OL":
			return ["STR", "RBK", "PBK", "AWR", "IMP", "AGI"]
		"DL":
			return ["STR", "TAK", "BSH", "POW", "AWR", "SPD"]
		"EDGE":
			return ["SPD", "BSH", "TAK", "STR", "AWR", "AGI"]
		"LB":
			return ["TAK", "SPD", "AWR", "MCV", "ZCV", "BSH"]
		"CB":
			return ["SPD", "MCV", "ZCV", "PRC", "ACC", "AGI"]
		"S":
			return ["SPD", "TAK", "ZCV", "AWR", "HTP", "PRC"]
		_:
			return ["SPD", "STR", "AGI", "AWR", "ACC"]


## Find best numeric value index from string values
func _find_best_numeric_value(values: Array) -> int:
	var best_idx := 0
	var best_val := -INF

	for i in range(values.size()):
		var str_val: String = values[i]
		# Try to parse as float
		if str_val.is_valid_float():
			var val := str_val.to_float()
			if val > best_val:
				best_val = val
				best_idx = i

	return best_idx if best_val > -INF else -1


## Find index of best stat value
func _find_best_stat_idx(values: Array) -> int:
	var best_idx := -1
	var best_val := -1.0

	for i in range(values.size()):
		var val: float = values[i]
		if val > best_val:
			best_val = val
			best_idx = i

	return best_idx


## Format scheme fit value for display
func _format_scheme_fit(fit: float) -> String:
	if fit >= 90:
		return "%.0f (A+)" % fit
	elif fit >= 80:
		return "%.0f (A)" % fit
	elif fit >= 70:
		return "%.0f (B)" % fit
	elif fit >= 60:
		return "%.0f (C)" % fit
	else:
		return "%.0f (D)" % fit


## Estimate rookie contract based on overall rating
func _estimate_contract(overall: float) -> String:
	if overall >= 85:
		return "$25-35M (1st Rd)"
	elif overall >= 75:
		return "$5-10M (2nd Rd)"
	elif overall >= 65:
		return "$1-2M (3rd-4th)"
	elif overall >= 55:
		return "$800K-1M (5th-6th)"
	else:
		return "$700K (7th/UDFA)"


## Handle player selection
func _on_player_selected(player_id: String) -> void:
	hide()
	player_chosen.emit(player_id)


## Handle close button press
func _on_close_pressed() -> void:
	hide()
	comparison_closed.emit()


## Handle window close request
func _on_close_requested() -> void:
	hide()
	comparison_closed.emit()
