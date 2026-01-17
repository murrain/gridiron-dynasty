## PlayerShortlistPanel - UI panel for managing player shortlist during draft
##
## Displays the user's watchlist of players they want to track.
## Shows visual indicators for availability and allows add/remove actions.
##
## Features:
## - Display shortlisted players with priority indicators
## - Visual status (available = green, drafted = red/strikethrough)
## - One-click add/remove from shortlist
## - Priority promotion/demotion
## - Alert popup when shortlisted player is drafted
##
extends PanelContainer
class_name PlayerShortlistPanel

const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const PlayerShortlist = preload("res://scripts/core/models/PlayerShortlist.gd")

## Emitted when user clicks on a shortlisted player to select them
signal player_selected(player_id: String)

## Reference to the draft controller
var _draft: InteractiveDraft = null

## UI elements
@onready var title_label: Label = $VBoxContainer/Header/TitleLabel
@onready var count_label: Label = $VBoxContainer/Header/CountLabel
@onready var shortlist_container: VBoxContainer = $VBoxContainer/ScrollContainer/ShortlistContainer
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var empty_label: Label = $VBoxContainer/EmptyLabel
@onready var alert_panel: PanelContainer = $AlertPanel
@onready var alert_label: Label = $AlertPanel/MarginContainer/AlertLabel

## Timer for auto-hiding alert
var _alert_timer: Timer = null

## Color constants for visual indicators
const COLOR_AVAILABLE := Color(0.2, 0.8, 0.2)  # Green
const COLOR_DRAFTED := Color(0.6, 0.3, 0.3)    # Muted red
const COLOR_HIGH_PRIORITY := Color(1.0, 0.8, 0.0)    # Gold
const COLOR_MEDIUM_PRIORITY := Color(0.7, 0.7, 0.7)  # Gray
const COLOR_LOW_PRIORITY := Color(0.5, 0.5, 0.5)     # Dark gray


func _ready() -> void:
	# Validate critical UI nodes
	if not shortlist_container:
		push_warning("[PlayerShortlistPanel] shortlist_container node not found - panel will not display shortlist")
		return

	if not title_label:
		push_warning("[PlayerShortlistPanel] title_label node not found - title display missing")

	if not count_label:
		push_warning("[PlayerShortlistPanel] count_label node not found - count display missing")

	if not empty_label:
		push_warning("[PlayerShortlistPanel] empty_label node not found - empty state will not display")

	if not scroll_container:
		push_warning("[PlayerShortlistPanel] scroll_container node not found - scrolling disabled")

	# Create alert timer
	_alert_timer = Timer.new()
	_alert_timer.one_shot = true
	_alert_timer.timeout.connect(_on_alert_timer_timeout)
	add_child(_alert_timer)

	# Hide alert panel initially
	if alert_panel:
		alert_panel.visible = false
	else:
		push_warning("[PlayerShortlistPanel] alert_panel node not found - draft alerts will not display")

	# Setup empty state
	_update_empty_state()


## Initialize with draft controller
func initialize(draft: InteractiveDraft) -> void:
	_draft = draft

	# Connect signals
	_draft.shortlist_changed.connect(_on_shortlist_changed)
	_draft.shortlisted_player_drafted.connect(_on_shortlisted_player_drafted)

	# Initial population
	_refresh_shortlist()


## Refresh the shortlist display
func _refresh_shortlist() -> void:
	if _draft == null:
		push_warning("[PlayerShortlistPanel] Cannot refresh shortlist - draft controller is null")
		return

	if not shortlist_container:
		push_warning("[PlayerShortlistPanel] Cannot refresh shortlist - shortlist_container is null")
		return

	# Clear existing entries
	for child in shortlist_container.get_children():
		child.queue_free()

	var entries: Array = _draft.get_shortlist()

	if count_label:
		count_label.text = "(%d)" % entries.size()

	for entry in entries:
		var e: Dictionary = entry
		_add_shortlist_entry(e)

	_update_empty_state()


## Add a single shortlist entry to the display
func _add_shortlist_entry(entry: Dictionary) -> void:
	var player_id := String(entry.get("player_id", ""))
	var name := String(entry.get("name", "Unknown"))
	var position := String(entry.get("position", ""))
	var status := String(entry.get("status", "available"))
	var priority := int(entry.get("priority", PlayerShortlist.Priority.MEDIUM))
	var drafted_by := String(entry.get("drafted_by", ""))

	# Create entry container
	var entry_container := HBoxContainer.new()
	entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Priority indicator
	var priority_indicator := Label.new()
	priority_indicator.custom_minimum_size = Vector2(20, 0)
	match priority:
		PlayerShortlist.Priority.HIGH:
			priority_indicator.text = "!"
			priority_indicator.add_theme_color_override("font_color", COLOR_HIGH_PRIORITY)
		PlayerShortlist.Priority.MEDIUM:
			priority_indicator.text = "-"
			priority_indicator.add_theme_color_override("font_color", COLOR_MEDIUM_PRIORITY)
		PlayerShortlist.Priority.LOW:
			priority_indicator.text = "."
			priority_indicator.add_theme_color_override("font_color", COLOR_LOW_PRIORITY)
	entry_container.add_child(priority_indicator)

	# Status indicator (colored dot)
	var status_indicator := Label.new()
	status_indicator.custom_minimum_size = Vector2(15, 0)
	if status == "available":
		status_indicator.text = "o"
		status_indicator.add_theme_color_override("font_color", COLOR_AVAILABLE)
	else:
		status_indicator.text = "x"
		status_indicator.add_theme_color_override("font_color", COLOR_DRAFTED)
	entry_container.add_child(status_indicator)

	# Player info button (clickable)
	var info_button := Button.new()
	info_button.flat = true
	info_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_button.text = "%s %s" % [position, name]

	if status == "drafted":
		info_button.text += " [%s]" % drafted_by
		info_button.add_theme_color_override("font_color", COLOR_DRAFTED)

	info_button.pressed.connect(_on_player_clicked.bind(player_id))
	entry_container.add_child(info_button)

	# Action buttons container
	var action_container := HBoxContainer.new()

	# Promote button (if not already high priority)
	if priority > PlayerShortlist.Priority.HIGH:
		var promote_btn := Button.new()
		promote_btn.text = "^"
		promote_btn.tooltip_text = "Increase priority"
		promote_btn.custom_minimum_size = Vector2(25, 0)
		promote_btn.pressed.connect(_on_promote_clicked.bind(player_id))
		action_container.add_child(promote_btn)

	# Demote button (if not already low priority)
	if priority < PlayerShortlist.Priority.LOW:
		var demote_btn := Button.new()
		demote_btn.text = "v"
		demote_btn.tooltip_text = "Decrease priority"
		demote_btn.custom_minimum_size = Vector2(25, 0)
		demote_btn.pressed.connect(_on_demote_clicked.bind(player_id))
		action_container.add_child(demote_btn)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.tooltip_text = "Remove from shortlist"
	remove_btn.custom_minimum_size = Vector2(25, 0)
	remove_btn.pressed.connect(_on_remove_clicked.bind(player_id))
	action_container.add_child(remove_btn)

	entry_container.add_child(action_container)
	shortlist_container.add_child(entry_container)


## Update empty state visibility
func _update_empty_state() -> void:
	if _draft == null:
		if empty_label:
			empty_label.visible = true
		if scroll_container:
			scroll_container.visible = false
		return

	var entries: Array = _draft.get_shortlist()

	if empty_label:
		empty_label.visible = entries.is_empty()

	if scroll_container:
		scroll_container.visible = not entries.is_empty()


## Show alert when shortlisted player is drafted
func _show_drafted_alert(player_name: String, position: String, team_id: String, pick_number: int) -> void:
	if not alert_panel or not alert_label:
		return

	alert_label.text = "ALERT: %s %s drafted by %s (Pick #%d)" % [position, player_name, team_id, pick_number]

	# Style the alert
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.2, 0.2, 0.9)
	style.border_width_all = 2
	style.border_color = Color(1.0, 0.3, 0.3)
	style.corner_radius_all = 4
	alert_panel.add_theme_stylebox_override("panel", style)

	alert_panel.visible = true

	# Auto-hide after 5 seconds
	_alert_timer.start(5.0)


## Hide alert panel
func _hide_alert() -> void:
	if alert_panel:
		alert_panel.visible = false


## Add player to shortlist from external source
func add_player(player_id: String, priority: int = PlayerShortlist.Priority.MEDIUM) -> bool:
	if _draft == null:
		return false
	return _draft.add_to_shortlist(player_id, priority)


## Check if player is on shortlist
func is_on_shortlist(player_id: String) -> bool:
	if _draft == null:
		return false
	return _draft.is_on_shortlist(player_id)


# =============================================================================
# Signal Handlers
# =============================================================================

func _on_shortlist_changed() -> void:
	_refresh_shortlist()


func _on_shortlisted_player_drafted(player_id: String, player_name: String, position: String, team_id: String, pick_number: int) -> void:
	_show_drafted_alert(player_name, position, team_id, pick_number)
	_refresh_shortlist()


func _on_player_clicked(player_id: String) -> void:
	player_selected.emit(player_id)


func _on_promote_clicked(player_id: String) -> void:
	if _draft == null:
		return
	var shortlist := _draft.get_shortlist_model()
	if shortlist:
		shortlist.promote(player_id)


func _on_demote_clicked(player_id: String) -> void:
	if _draft == null:
		return
	var shortlist := _draft.get_shortlist_model()
	if shortlist:
		shortlist.demote(player_id)


func _on_remove_clicked(player_id: String) -> void:
	if _draft == null:
		return
	_draft.remove_from_shortlist(player_id)


func _on_alert_timer_timeout() -> void:
	_hide_alert()
