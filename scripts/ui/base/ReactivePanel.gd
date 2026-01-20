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
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_subscribed_collections = _get_subscribed_collections()
	_connect_databus_signals()


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
