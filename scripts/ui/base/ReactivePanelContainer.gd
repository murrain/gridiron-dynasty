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
func initialize(ws: Dictionary) -> void:
	world_state = ws
	# Subclasses override and add custom initialization


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
