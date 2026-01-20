extends PanelContainer
class_name ReactivePanelContainer

## PanelContainer variant of ReactivePanel for container-based UIs.
##
## Identical to [ReactivePanel] but extends [PanelContainer] instead of [Control].
## Use this when your UI needs the visual styling of a panel container.
##
## [b]See [ReactivePanel] for full documentation.[/b]
##
## [b]Example Subclass:[/b]
## [codeblock]
## class_name TeamInfoPanel
## extends ReactivePanelContainer
##
## @onready var team_name_label: Label = $MarginContainer/VBoxContainer/TeamName
## @onready var record_label: Label = $MarginContainer/VBoxContainer/Record
##
## var current_team_id: String = ""
##
## func _get_subscribed_collections() -> Array[String]:
##     return ["nfl_teams"]
##
## func _on_data_changed(collection: String, operation: String) -> void:
##     _refresh_team_info()
##
## func initialize(ws: Dictionary) -> void:
##     super.initialize(ws)
##     _refresh_team_info()
##
## func set_team(team_id: String) -> void:
##     current_team_id = team_id
##     _refresh_team_info()
##
## func _refresh_team_info() -> void:
##     var teams = world_state.get("nfl_teams", [])
##     var team = teams.filter(func(t): return t["id"] == current_team_id).front()
##     if team:
##         team_name_label.text = team["name"]
##         record_label.text = "%d - %d" % [team["wins"], team["losses"]]
## [/codeblock]

## World state reference (READ-ONLY - do not modify!)
var world_state: Dictionary = {}

## Subscribed collection names (cached from _get_subscribed_collections)
var _subscribed_collections: Array[String] = []

## Whether DataBus signals are connected
var _databus_connected: bool = false


# ============================================================================
# STYLE CONFIGURATION
# ============================================================================

## Style variant for this panel.
##
## Available variants:
## - [b]default:[/b] Standard dark panel
## - [b]primary:[/b] Primary accent (blue)
## - [b]secondary:[/b] Secondary accent (purple)
## - [b]info:[/b] Info accent (teal)
## - [b]warning:[/b] Warning accent (orange)
## - [b]success:[/b] Success accent (green)
## - [b]error:[/b] Error accent (red)
## - [b]nested:[/b] Auto-darkening based on depth
## - [b]transparent:[/b] No background or border
@export_enum("default", "primary", "secondary", "info", "warning", "success", "error", "nested", "transparent")
var style_variant: String = "default"

## Whether to auto-indent when nested inside another ReactivePanel.
##
## When enabled, nested panels automatically add left margin based on
## their nesting depth for visual hierarchy.
@export var auto_indent_nested: bool = true

## Indent amount in pixels per nesting level.
##
## Each level of nesting adds this amount of left margin.
## Example: depth 2 with indent 8 = 16px left margin
@export_range(0, 32, 1) var nest_indent: int = 8

## Whether to apply the style automatically on ready.
##
## When true, style is applied in [method _ready].
## Set to false if you want manual control via [method apply_style].
@export var auto_apply_style: bool = true


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_subscribed_collections = _get_subscribed_collections()
	_connect_databus_signals()

	# Apply style if enabled
	if auto_apply_style:
		apply_style()


func _exit_tree() -> void:
	_disconnect_databus_signals()


# ============================================================================
# PUBLIC API
# ============================================================================

## Initialize panel with world state.
## Call this to set initial data when panel is first shown.
##
## [b]Subclasses:[/b] Call [code]super.initialize(ws)[/code] then perform custom refresh.
func initialize(ws: Dictionary) -> void:
	world_state = ws
	# Subclasses override and add custom initialization


## Apply the style variant to this panel.
##
## This method creates and applies a StyleBoxFlat based on the current
## [member style_variant] and nesting configuration. It also handles
## auto-indent for nested panels if enabled.
##
## [b]Note:[/b] This is called automatically in [method _ready] if
## [member auto_apply_style] is true. You can also call it manually
## to reapply styles after changing configuration.
##
## [b]Example:[/b]
## [codeblock]
## func _ready() -> void:
##     super._ready()
##     style_variant = "primary"
##     apply_style()  # Manually apply after changing variant
## [/codeblock]
func apply_style() -> void:
	var depth := _get_nesting_depth()
	var style := PanelStyles.create_style(style_variant, depth)

	# Apply the style to this PanelContainer
	# PanelContainer has built-in support for StyleBoxFlat
	add_theme_stylebox_override("panel", style)

	# Handle nesting indent
	if auto_indent_nested and _is_nested():
		_apply_nesting_indent(depth)


## Set the style variant and reapply styles.
##
## Convenience method to change the variant and apply in one call.
##
## [param variant] The new variant name
##
## [b]Example:[/b]
## [codeblock]
## panel.set_style_variant("warning")  # Change to warning style
## [/codeblock]
func set_style_variant(variant: String) -> void:
	style_variant = variant
	apply_style()


# ============================================================================
# OVERRIDABLE METHODS (Subclass implements these)
# ============================================================================

## Override: Return array of collection names to subscribe to.
## See [ReactivePanel._get_subscribed_collections] for details.
func _get_subscribed_collections() -> Array[String]:
	return []


## Override: Handle data changes for subscribed collections.
## See [ReactivePanel._on_data_changed] for details.
func _on_data_changed(collection: String, operation: String) -> void:
	pass  # Subclass implements


## Override: Handle world state load events.
## See [ReactivePanel._on_world_state_loaded] for details.
func _on_world_state_loaded() -> void:
	pass  # Subclass implements


# ============================================================================
# PRIVATE METHODS
# ============================================================================

## Connect to DataBus signals for automatic refresh.
func _connect_databus_signals() -> void:
	if _databus_connected:
		push_warning("ReactivePanelContainer: DataBus signals already connected")
		return

	if not DataBus.collection_changed.is_connected(_on_databus_collection_changed):
		DataBus.collection_changed.connect(_on_databus_collection_changed)

	if not DataBus.world_state_loaded.is_connected(_on_databus_world_state_loaded):
		DataBus.world_state_loaded.connect(_on_databus_world_state_loaded)

	_databus_connected = true


## Disconnect from DataBus signals to prevent memory leaks.
func _disconnect_databus_signals() -> void:
	if not _databus_connected:
		return

	if DataBus.collection_changed.is_connected(_on_databus_collection_changed):
		DataBus.collection_changed.disconnect(_on_databus_collection_changed)

	if DataBus.world_state_loaded.is_connected(_on_databus_world_state_loaded):
		DataBus.world_state_loaded.disconnect(_on_databus_world_state_loaded)

	_databus_connected = false


# ============================================================================
# STYLE PRIVATE METHODS
# ============================================================================

## Apply nesting indent based on depth.
func _apply_nesting_indent(depth: int) -> void:
	if depth <= 0:
		return

	var margin := nest_indent * depth

	# Add left margin using MarginContainer or direct offset
	# For PanelContainer, we'll adjust the left offset
	offset_left = margin


## Check if this panel is nested inside another ReactivePanel or ReactivePanelContainer.
func _is_nested() -> bool:
	var parent := get_parent()
	while parent:
		if parent is ReactivePanel or parent is ReactivePanelContainer:
			return true
		parent = parent.get_parent()
	return false


## Get the nesting depth (how many ReactivePanel/ReactivePanelContainer ancestors).
func _get_nesting_depth() -> int:
	var depth := 0
	var parent := get_parent()
	while parent:
		if parent is ReactivePanel or parent is ReactivePanelContainer:
			depth += 1
		parent = parent.get_parent()
	return depth


# ============================================================================
# DATABUS SIGNAL HANDLERS
# ============================================================================

## DataBus signal: collection_changed
## Filters to only subscribed collections before calling subclass handler.
func _on_databus_collection_changed(collection_name: String, operation: String) -> void:
	# Filter: only notify if we're subscribed to this collection
	if collection_name not in _subscribed_collections:
		return

	# Delegate to subclass
	_on_data_changed(collection_name, operation)


## DataBus signal: world_state_loaded
## Calls subclass handler for full refresh.
func _on_databus_world_state_loaded() -> void:
	_on_world_state_loaded()
