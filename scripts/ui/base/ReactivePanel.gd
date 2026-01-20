extends Control
class_name ReactivePanel

## Base class for reactive UI panels that auto-subscribe to DataBus.
##
## ReactivePanel simplifies building UI components that need to refresh when
## world_state changes. Instead of manually subscribing to DataBus signals,
## subclasses simply declare which collections they care about.
##
## [b]Subclass Requirements:[/b]
## 1. Override [method _get_subscribed_collections] to specify which collections to watch
## 2. Override [method _on_data_changed] to handle refreshes
## 3. Optionally override [method _on_world_state_loaded] for full refresh
## 4. Call [method initialize] to set initial data
##
## [b]Example Subclass:[/b]
## [codeblock]
## class_name RosterPanel
## extends ReactivePanel
##
## @onready var roster_list: ItemList = $RosterList
## var current_team_id: String = ""
##
## func _get_subscribed_collections() -> Array[String]:
##     return ["nfl_rosters", "contracts"]
##
## func _on_data_changed(collection: String, operation: String) -> void:
##     if collection == "nfl_rosters":
##         _refresh_roster_display()
##     elif collection == "contracts":
##         _refresh_contract_info()
##
## func _on_world_state_loaded() -> void:
##     # Full refresh when world loads
##     _refresh_all()
##
## func initialize(ws: Dictionary) -> void:
##     super.initialize(ws)
##     _refresh_all()
##
## func _refresh_roster_display() -> void:
##     roster_list.clear()
##     var roster = world_state.get("nfl_rosters", {}).get(current_team_id, {})
##     for player in roster.get("players", []):
##         roster_list.add_item(player["name"])
## [/codeblock]
##
## [b]Benefits:[/b]
## - Automatic DataBus subscription management
## - Filtered notifications (only subscribed collections)
## - Automatic cleanup on exit (no memory leaks)
## - Consistent pattern across all reactive panels
##
## [b]When to Use:[/b]
## - Your panel needs to display world_state data
## - Your panel should refresh when specific collections change
## - Your panel is a smart container managing child components
##
## [b]When NOT to Use:[/b]
## - Your panel receives data from a parent container (use dumb component pattern)
## - Your panel is a modal with transient state
## - Your parent already subscribes to DataBus (avoid double-subscription)
##
## [b]See Also:[/b]
## - [ReactivePanelContainer] - PanelContainer variant
## - [code]docs/ui/REACTIVE_PANEL_GUIDE.md[/code] - Detailed usage guide
## - [code]docs/ui/COMPONENT_CONTRACTS.md[/code] - Component patterns

## World state reference (READ-ONLY - do not modify!)
## Panels should query this dictionary but never mutate it.
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
##
## [codeblock]
## func initialize(ws: Dictionary) -> void:
##     super.initialize(ws)
##     _refresh_content()
## [/codeblock]
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

	# Apply the style to this panel
	# Note: Control doesn't have a built-in panel stylebox,
	# so we need to use a Panel child or override drawing
	# For now, we'll add a ColorRect as the background
	_apply_style_to_panel(style)

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
##
## Only emit signals for collections in this array will trigger [method _on_data_changed].
##
## [b]Common collection names:[/b]
## - [code]"nfl_rosters"[/code] - NFL team rosters
## - [code]"nfl_teams"[/code] - NFL team data
## - [code]"colleges"[/code] - College team data
## - [code]"college_rosters"[/code] - College rosters
## - [code]"hs_players"[/code] - High school players
## - [code]"draft_pool"[/code] - Draft-eligible players
## - [code]"contracts"[/code] - Contract data
## - [code]"free_agents"[/code] - Free agent pool
## - [code]"retired_players"[/code] - Retired players
##
## [codeblock]
## func _get_subscribed_collections() -> Array[String]:
##     return ["nfl_rosters", "contracts"]
## [/codeblock]
func _get_subscribed_collections() -> Array[String]:
	return []


## Override: Handle data changes for subscribed collections.
##
## Called when a subscribed collection changes. Use this to refresh
## the relevant parts of your UI.
##
## [param collection] The name of the collection that changed
## [param operation] The type of operation: "insert", "update", "delete", "bulk_update"
##
## [b]Example:[/b]
## [codeblock]
## func _on_data_changed(collection: String, operation: String) -> void:
##     match collection:
##         "nfl_rosters":
##             _refresh_roster_list()
##         "contracts":
##             _refresh_contract_details()
##         _:
##             push_warning("Unexpected collection: %s" % collection)
## [/codeblock]
func _on_data_changed(collection: String, operation: String) -> void:
	pass  # Subclass implements


## Override: Handle world state load events.
##
## Called when world state is loaded or initialized. Use this for
## full UI refresh when the entire world changes.
##
## [b]Example:[/b]
## [codeblock]
## func _on_world_state_loaded() -> void:
##     _refresh_all_panels()
##     _clear_selection()
## [/codeblock]
func _on_world_state_loaded() -> void:
	pass  # Subclass implements


# ============================================================================
# PRIVATE METHODS
# ============================================================================

## Connect to DataBus signals for automatic refresh.
## Checks for double-connections to prevent memory leaks.
func _connect_databus_signals() -> void:
	if _databus_connected:
		push_warning("ReactivePanel: DataBus signals already connected")
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

## Apply the style to this panel's visual representation.
##
## Since Control doesn't have a built-in panel stylebox, we need to
## either use draw_style_box in _draw() or add visual child nodes.
## This implementation uses a ColorRect background for simplicity.
func _apply_style_to_panel(style: StyleBoxFlat) -> void:
	# Find or create background ColorRect
	var bg_rect: ColorRect = _get_or_create_background()

	# Apply background color
	bg_rect.color = style.bg_color

	# Apply border using a custom draw (if needed)
	# For now, we'll just set the background color
	# Future enhancement: add border drawing

	# Apply corner radius via custom drawing (requires _draw override)
	# This is a limitation of using Control directly
	# For full style support, subclasses should use PanelContainer or Panel

	# Note: For full StyleBoxFlat support, consider using a Panel child
	# or override _draw() to draw the style box manually


## Get or create the background ColorRect for this panel.
func _get_or_create_background() -> ColorRect:
	# Look for existing background
	var bg_name := "_panel_bg"
	for child in get_children():
		if child.name == bg_name and child is ColorRect:
			return child

	# Create new background
	var bg := ColorRect.new()
	bg.name = bg_name
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1  # Behind other children
	add_child(bg)
	move_child(bg, 0)  # Ensure it's the first child

	return bg


## Apply nesting indent based on depth.
func _apply_nesting_indent(depth: int) -> void:
	if depth <= 0:
		return

	var margin := nest_indent * depth

	# Add left margin via offset
	# Note: This modifies the panel's position/margins
	# Alternative: use MarginContainer wrapper
	if has_theme_constant_override("margin_left"):
		set_theme_constant_override("margin_left", margin)
	else:
		# Fallback: adjust offset
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
