extends ReactivePanel
class_name ExampleReactivePanel

## Example ReactivePanel implementation for testing and reference.
##
## This panel demonstrates:
## - Subscribing to multiple collections
## - Handling data changes
## - Handling world state load
## - Proper initialization pattern
##
## This is a reference implementation and should NOT be used in production.
## It exists solely for testing and documentation purposes.

@onready var status_label: Label = $StatusLabel if has_node("StatusLabel") else null
@onready var data_log: RichTextLabel = $DataLog if has_node("DataLog") else null

var _refresh_count: int = 0
var _last_collection: String = ""
var _last_operation: String = ""


# ============================================================================
# REACTIVE PANEL OVERRIDES
# ============================================================================

func _get_subscribed_collections() -> Array[String]:
	# Example: Subscribe to NFL and draft-related collections
	return ["nfl_rosters", "nfl_teams", "draft_pool"]


func _on_data_changed(collection: String, operation: String) -> void:
	_refresh_count += 1
	_last_collection = collection
	_last_operation = operation

	_log_event("Data changed: %s (%s)" % [collection, operation])

	# Example: Refresh different parts based on collection
	match collection:
		"nfl_rosters":
			_refresh_roster_data()
		"nfl_teams":
			_refresh_team_data()
		"draft_pool":
			_refresh_draft_data()


func _on_world_state_loaded() -> void:
	_log_event("World state loaded - full refresh")
	_refresh_all()


func initialize(ws: Dictionary) -> void:
	super.initialize(ws)
	_log_event("Panel initialized")
	_refresh_all()


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _refresh_all() -> void:
	_refresh_roster_data()
	_refresh_team_data()
	_refresh_draft_data()
	_update_status()


func _refresh_roster_data() -> void:
	var rosters = world_state.get("nfl_rosters", {})
	_log_event("Refreshed roster data (%d teams)" % rosters.size())


func _refresh_team_data() -> void:
	var teams = world_state.get("nfl_teams", [])
	_log_event("Refreshed team data (%d teams)" % teams.size())


func _refresh_draft_data() -> void:
	var draft_pool = world_state.get("draft_pool", {})
	_log_event("Refreshed draft data (%d years)" % draft_pool.size())


func _update_status() -> void:
	if status_label == null:
		return

	var current_year = world_state.get("current_year", 0)
	status_label.text = "Year: %d | Refreshes: %d | Last: %s (%s)" % [
		current_year,
		_refresh_count,
		_last_collection,
		_last_operation
	]


func _log_event(message: String) -> void:
	print("[ExampleReactivePanel] %s" % message)

	if data_log != null:
		var timestamp = Time.get_ticks_msec()
		data_log.append_text("[%d] %s\n" % [timestamp, message])
