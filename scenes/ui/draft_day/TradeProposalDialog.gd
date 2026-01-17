## TradeProposalDialog - User Interface for Draft Pick Trading
##
## Purpose: Provides UI for users to propose draft pick trades during the draft.
## Allows selecting a target team, choosing picks to offer/request, and seeing
## the trade value preview before submission.
##
## Signals:
##   - trade_proposed(offer: Dictionary): Emitted when user submits a valid trade
##   - trade_cancelled(): Emitted when user cancels the dialog
##
## Integration:
##   - Opened by DraftDayUI when user clicks "Propose Trade"
##   - Submits offer to InteractiveDraft for validation and AI decision
##   - Uses DraftTradeEngine for value calculation preview
##
extends Window
class_name TradeProposalDialog

const DraftTradeEngine = preload("res://scripts/world/DraftTradeEngine.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")

## Emitted when user submits a trade proposal
signal trade_proposed(offer: Dictionary)

## Emitted when user cancels the dialog
signal trade_cancelled()

## State
var _user_team_id: String = ""
var _target_team_id: String = ""
var _user_picks: Array = []
var _target_picks: Array = []
var _ownership: Dictionary = {}
var _year: int = 0
var _league_cfg: Dictionary = {}
var _available_teams: Array = []

## Selected picks
var _selected_user_picks: Array = []
var _selected_target_picks: Array = []

## UI References (created programmatically or from scene tree)
var _team_dropdown: OptionButton
var _user_picks_container: VBoxContainer
var _target_picks_container: VBoxContainer
var _value_label: Label
var _differential_label: Label
var _submit_button: Button
var _cancel_button: Button


func _ready() -> void:
	title = "Propose Trade"
	size = Vector2i(650, 500)
	close_requested.connect(_on_cancel_pressed)
	_build_ui()


## Build the dialog UI programmatically
func _build_ui() -> void:
	# Create main container
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Title
	var title_label := Label.new()
	title_label.text = "Propose Draft Pick Trade"
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)

	# Team selection
	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 10)
	vbox.add_child(team_row)

	var trade_with_label := Label.new()
	trade_with_label.text = "Trade with:"
	team_row.add_child(trade_with_label)

	_team_dropdown = OptionButton.new()
	_team_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_dropdown.item_selected.connect(_on_team_selected)
	team_row.add_child(_team_dropdown)

	# Separator
	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Split container for picks
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	# User picks column
	var user_column := VBoxContainer.new()
	user_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(user_column)

	var user_picks_label := Label.new()
	user_picks_label.text = "Your Picks (to offer):"
	user_picks_label.add_theme_font_size_override("font_size", 14)
	user_column.add_child(user_picks_label)

	var user_scroll := ScrollContainer.new()
	user_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	user_column.add_child(user_scroll)

	_user_picks_container = VBoxContainer.new()
	_user_picks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_scroll.add_child(_user_picks_container)

	# Target picks column
	var target_column := VBoxContainer.new()
	target_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(target_column)

	var target_picks_label := Label.new()
	target_picks_label.text = "Their Picks (to request):"
	target_picks_label.add_theme_font_size_override("font_size", 14)
	target_column.add_child(target_picks_label)

	var target_scroll := ScrollContainer.new()
	target_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_column.add_child(target_scroll)

	_target_picks_container = VBoxContainer.new()
	_target_picks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_scroll.add_child(_target_picks_container)

	# Separator
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Value summary panel
	var value_panel := PanelContainer.new()
	vbox.add_child(value_panel)

	var value_vbox := VBoxContainer.new()
	value_vbox.add_theme_constant_override("separation", 5)
	value_panel.add_child(value_vbox)

	_value_label = Label.new()
	_value_label.text = "Value: You give 0 pts | You receive 0 pts"
	value_vbox.add_child(_value_label)

	_differential_label = Label.new()
	_differential_label.text = "Differential: 0 pts (Fair trade)"
	value_vbox.add_child(_differential_label)

	# Buttons
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(_cancel_button)

	_submit_button = Button.new()
	_submit_button.text = "Propose Trade"
	_submit_button.disabled = true
	_submit_button.pressed.connect(_on_submit_pressed)
	button_row.add_child(_submit_button)


## Open the trade dialog
##
## @param user_team_id: User's team ID
## @param available_teams: Array of team dictionaries to trade with
## @param user_picks: Array of pick dictionaries the user can offer
## @param ownership: Draft pick ownership ledger
## @param year: Current draft year
## @param league_cfg: League configuration (for value calculation)
func open_dialog(
	user_team_id: String,
	available_teams: Array,
	user_picks: Array,
	ownership: Dictionary,
	year: int,
	league_cfg: Dictionary = {}
) -> void:
	_user_team_id = user_team_id
	_available_teams = available_teams
	_user_picks = user_picks
	_ownership = ownership
	_year = year
	_league_cfg = league_cfg

	_selected_user_picks.clear()
	_selected_target_picks.clear()
	_target_team_id = ""
	_target_picks.clear()

	# Populate team dropdown
	_team_dropdown.clear()
	_team_dropdown.add_item("-- Select Team --", 0)
	for i in range(available_teams.size()):
		var team: Dictionary = available_teams[i]
		var team_name := "%s %s" % [String(team.get("city", "")), String(team.get("name", ""))]
		_team_dropdown.add_item(team_name, i + 1)

	# Populate user picks
	_populate_user_picks()

	# Clear target picks (no team selected yet)
	_clear_target_picks()

	# Update value display
	_update_value_display()

	# Show dialog
	popup_centered()


## Set target team and populate their picks
##
## @param team_id: Target team ID
## @param team_picks: Array of pick dictionaries the target team owns
func set_target_team(team_id: String, team_picks: Array) -> void:
	_target_team_id = team_id
	_target_picks = team_picks
	_selected_target_picks.clear()

	_populate_target_picks()
	_update_value_display()


## Populate user picks checkboxes
func _populate_user_picks() -> void:
	# Clear existing
	for child in _user_picks_container.get_children():
		child.queue_free()

	# Add checkbox for each pick
	for pick in _user_picks:
		var p: Dictionary = pick
		var checkbox := CheckBox.new()
		checkbox.text = _format_pick_display(p)
		checkbox.set_meta("pick_data", p)
		checkbox.toggled.connect(_on_user_pick_toggled.bind(p))
		_user_picks_container.add_child(checkbox)

	if _user_picks.is_empty():
		var label := Label.new()
		label.text = "No tradeable picks available"
		label.modulate = Color(0.7, 0.7, 0.7)
		_user_picks_container.add_child(label)


## Populate target team picks checkboxes
func _populate_target_picks() -> void:
	_clear_target_picks()

	# Add checkbox for each pick
	for pick in _target_picks:
		var p: Dictionary = pick
		var checkbox := CheckBox.new()
		checkbox.text = _format_pick_display(p)
		checkbox.set_meta("pick_data", p)
		checkbox.toggled.connect(_on_target_pick_toggled.bind(p))
		_target_picks_container.add_child(checkbox)

	if _target_picks.is_empty():
		var label := Label.new()
		label.text = "Select a team to see their picks"
		label.modulate = Color(0.7, 0.7, 0.7)
		_target_picks_container.add_child(label)


## Clear target picks display
func _clear_target_picks() -> void:
	for child in _target_picks_container.get_children():
		child.queue_free()


## Format pick for display
func _format_pick_display(pick: Dictionary) -> String:
	var pick_year := int(pick.get("year", _year))
	var round_num := int(pick.get("round", 1))
	var pick_in_round := int(pick.get("pick_in_round", 1))
	var overall := int(pick.get("overall", (round_num - 1) * 32 + pick_in_round))

	var value := NflDraft.value_draft_pick(pick_year, round_num, pick_in_round, _year, _league_cfg)

	if pick_year == _year:
		return "Rd %d #%d (Overall #%d) - %d pts" % [round_num, pick_in_round, overall, int(value)]
	else:
		return "%d Rd %d #%d - %d pts" % [pick_year, round_num, pick_in_round, int(value)]


## Handle team selection
func _on_team_selected(index: int) -> void:
	if index <= 0:
		_target_team_id = ""
		_target_picks.clear()
		_selected_target_picks.clear()
		_clear_target_picks()
		_update_value_display()
		return

	var team_index := index - 1
	if team_index >= 0 and team_index < _available_teams.size():
		var team: Dictionary = _available_teams[team_index]
		var team_id := String(team.get("id", ""))

		# Get target team's picks
		var team_picks := _get_team_picks(team_id)
		set_target_team(team_id, team_picks)


## Get picks owned by a specific team
func _get_team_picks(team_id: String) -> Array:
	var picks: Array = []

	var year_ownership: Dictionary = _ownership.get(_year, {}) as Dictionary

	for round_num in range(1, 8):
		var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary
		var pick_in_round := 1

		for orig_team_id in round_ownership.keys():
			var owner := String(round_ownership.get(orig_team_id, ""))
			if owner == team_id:
				picks.append({
					"year": _year,
					"round": round_num,
					"pick_in_round": pick_in_round,
					"original_team_id": orig_team_id,
					"pick_id": "%d_%d_%d" % [_year, round_num, pick_in_round]
				})
			pick_in_round += 1

	return picks


## Handle user pick toggle
func _on_user_pick_toggled(toggled: bool, pick: Dictionary) -> void:
	if toggled:
		if not pick in _selected_user_picks:
			_selected_user_picks.append(pick)
	else:
		_selected_user_picks.erase(pick)

	_update_value_display()


## Handle target pick toggle
func _on_target_pick_toggled(toggled: bool, pick: Dictionary) -> void:
	if toggled:
		if not pick in _selected_target_picks:
			_selected_target_picks.append(pick)
	else:
		_selected_target_picks.erase(pick)

	_update_value_display()


## Update value display
func _update_value_display() -> void:
	var user_value := 0.0
	for pick in _selected_user_picks:
		var p: Dictionary = pick
		user_value += NflDraft.value_draft_pick(
			int(p.get("year", _year)),
			int(p.get("round", 1)),
			int(p.get("pick_in_round", 1)),
			_year,
			_league_cfg
		)

	var target_value := 0.0
	for pick in _selected_target_picks:
		var p: Dictionary = pick
		target_value += NflDraft.value_draft_pick(
			int(p.get("year", _year)),
			int(p.get("round", 1)),
			int(p.get("pick_in_round", 1)),
			_year,
			_league_cfg
		)

	var differential := target_value - user_value

	_value_label.text = "Value: You give %d pts | You receive %d pts" % [
		int(user_value), int(target_value)
	]

	var diff_text := ""
	if differential > 0:
		diff_text = "+%d pts (You benefit)" % int(differential)
		_differential_label.modulate = Color.GREEN
	elif differential < 0:
		diff_text = "%d pts (They benefit)" % int(differential)
		_differential_label.modulate = Color.RED
	else:
		diff_text = "0 pts (Fair trade)"
		_differential_label.modulate = Color.WHITE

	_differential_label.text = "Differential: %s" % diff_text

	# Enable submit if valid trade
	var can_submit := (
		not _target_team_id.is_empty() and
		not _selected_user_picks.is_empty() and
		not _selected_target_picks.is_empty()
	)
	_submit_button.disabled = not can_submit


## Calculate value preview (called from external code if needed)
func calculate_value_preview() -> void:
	_update_value_display()


## Handle submit button
func _on_submit_pressed() -> void:
	if _target_team_id.is_empty():
		return
	if _selected_user_picks.is_empty() or _selected_target_picks.is_empty():
		return

	var offer := {
		"offering_team_id": _user_team_id,
		"receiving_team_id": _target_team_id,
		"picks_offered": _selected_user_picks.duplicate(true),
		"picks_requested": _selected_target_picks.duplicate(true),
		"initiated_by": "user"
	}

	trade_proposed.emit(offer)


## Handle cancel button
func _on_cancel_pressed() -> void:
	hide()
	trade_cancelled.emit()
