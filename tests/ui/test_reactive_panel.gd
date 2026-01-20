extends GutTest

## Unit tests for ReactivePanel base class.
##
## Tests:
## - Automatic DataBus subscription on _ready()
## - Automatic DataBus disconnection on _exit_tree()
## - Filtered notifications to subscribed collections only
## - Proper delegation to subclass handlers
## - world_state_loaded event handling

const ExampleReactivePanel = preload("res://scripts/ui/base/ExampleReactivePanel.gd")

var panel: ExampleReactivePanel
var mock_world_state: Dictionary


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_each() -> void:
	panel = ExampleReactivePanel.new()
	mock_world_state = _create_test_world_state()
	add_child_autofree(panel)


func after_each() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
		panel = null


# ============================================================================
# SUBSCRIPTION TESTS
# ============================================================================

func test_subscriptions_declared() -> void:
	# Test that subclass declares expected subscriptions
	var subscriptions = panel._get_subscribed_collections()

	assert_eq(subscriptions.size(), 3, "Should subscribe to 3 collections")
	assert_true("nfl_rosters" in subscriptions, "Should subscribe to nfl_rosters")
	assert_true("nfl_teams" in subscriptions, "Should subscribe to nfl_teams")
	assert_true("draft_pool" in subscriptions, "Should subscribe to draft_pool")


func test_databus_auto_connect_on_ready() -> void:
	# Panel should auto-connect in _ready()
	await get_tree().process_frame

	assert_true(
		DataBus.collection_changed.is_connected(panel._on_databus_collection_changed),
		"Should auto-connect to DataBus.collection_changed"
	)

	assert_true(
		DataBus.world_state_loaded.is_connected(panel._on_databus_world_state_loaded),
		"Should auto-connect to DataBus.world_state_loaded"
	)


func test_databus_auto_disconnect_on_exit() -> void:
	# Panel should auto-disconnect in _exit_tree()
	await get_tree().process_frame

	# Verify connected first
	assert_true(
		DataBus.collection_changed.is_connected(panel._on_databus_collection_changed),
		"Should be connected before exit"
	)

	# Free the panel
	panel.queue_free()
	await get_tree().process_frame

	# Verify disconnected
	assert_false(
		DataBus.collection_changed.is_connected(panel._on_databus_collection_changed),
		"Should auto-disconnect on exit"
	)


func test_no_double_connection() -> void:
	# Verify panel doesn't double-connect if _ready() called multiple times
	await get_tree().process_frame

	# Manually call _connect_databus_signals again
	panel._connect_databus_signals()

	# Count connections (should still be 1)
	var connection_count = 0
	for connection in DataBus.collection_changed.get_connections():
		if connection["callable"].get_object() == panel:
			connection_count += 1

	assert_eq(connection_count, 1, "Should only connect once")


# ============================================================================
# FILTERING TESTS
# ============================================================================

func test_filters_to_subscribed_collections_only() -> void:
	panel.initialize(mock_world_state)
	await get_tree().process_frame

	var initial_refresh_count = panel._refresh_count

	# Emit for UNSUBSCRIBED collection
	DataBus.notify_collection_changed("hs_players", "insert")
	await get_tree().process_frame

	assert_eq(
		panel._refresh_count,
		initial_refresh_count,
		"Should NOT refresh for unsubscribed collection"
	)

	# Emit for SUBSCRIBED collection
	DataBus.notify_collection_changed("nfl_rosters", "insert")
	await get_tree().process_frame

	assert_eq(
		panel._refresh_count,
		initial_refresh_count + 1,
		"Should refresh for subscribed collection"
	)


func test_receives_all_subscribed_collections() -> void:
	panel.initialize(mock_world_state)
	await get_tree().process_frame

	var initial_count = panel._refresh_count

	# Emit for each subscribed collection
	DataBus.notify_collection_changed("nfl_rosters", "update")
	await get_tree().process_frame

	DataBus.notify_collection_changed("nfl_teams", "update")
	await get_tree().process_frame

	DataBus.notify_collection_changed("draft_pool", "update")
	await get_tree().process_frame

	assert_eq(
		panel._refresh_count,
		initial_count + 3,
		"Should refresh for all subscribed collections"
	)


# ============================================================================
# DELEGATION TESTS
# ============================================================================

func test_delegates_to_on_data_changed() -> void:
	panel.initialize(mock_world_state)
	await get_tree().process_frame

	# Emit collection change
	DataBus.notify_collection_changed("nfl_rosters", "insert")
	await get_tree().process_frame

	# Verify subclass handler was called with correct params
	assert_eq(panel._last_collection, "nfl_rosters")
	assert_eq(panel._last_operation, "insert")


func test_delegates_to_on_world_state_loaded() -> void:
	panel.initialize(mock_world_state)
	await get_tree().process_frame

	var initial_refresh_count = panel._refresh_count

	# Emit world_state_loaded
	DataBus.notify_world_state_loaded()
	await get_tree().process_frame

	# Verify subclass handler was called
	# (ExampleReactivePanel calls _refresh_all which increments count)
	assert_gt(
		panel._refresh_count,
		initial_refresh_count,
		"Should call _on_world_state_loaded handler"
	)


# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_initialize_sets_world_state() -> void:
	panel.initialize(mock_world_state)

	assert_eq(panel.world_state, mock_world_state, "Should set world_state reference")
	assert_eq(
		panel.world_state.get("current_year"),
		2025,
		"Should have access to world_state data"
	)


func test_initialize_can_be_called_multiple_times() -> void:
	# First initialization
	panel.initialize(mock_world_state)
	assert_eq(panel.world_state.get("current_year"), 2025)

	# Second initialization with different data
	var new_world_state = mock_world_state.duplicate()
	new_world_state["current_year"] = 2026
	panel.initialize(new_world_state)

	assert_eq(
		panel.world_state.get("current_year"),
		2026,
		"Should update world_state on re-initialization"
	)


# ============================================================================
# OPERATION PARAMETER TESTS
# ============================================================================

func test_receives_operation_parameter() -> void:
	panel.initialize(mock_world_state)
	await get_tree().process_frame

	# Test different operation types
	var operations = ["insert", "update", "delete", "bulk_update"]

	for op in operations:
		DataBus.notify_collection_changed("nfl_rosters", op)
		await get_tree().process_frame
		assert_eq(panel._last_operation, op, "Should receive operation: %s" % op)


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_handles_empty_subscriptions() -> void:
	# Create a panel with no subscriptions
	var empty_panel = ReactivePanel.new()
	add_child_autofree(empty_panel)
	await get_tree().process_frame

	# Should not crash when receiving DataBus signals
	DataBus.notify_collection_changed("nfl_rosters", "insert")
	await get_tree().process_frame

	assert_true(true, "Should handle empty subscriptions gracefully")


func test_handles_null_world_state() -> void:
	# Should not crash with empty world_state
	panel.initialize({})

	assert_eq(panel.world_state, {}, "Should accept empty world_state")


func test_handles_missing_collection_in_world_state() -> void:
	# Initialize with incomplete world_state
	var incomplete_ws = {"current_year": 2025}
	panel.initialize(incomplete_ws)

	# Trigger refresh for collection not in world_state
	DataBus.notify_collection_changed("nfl_rosters", "update")
	await get_tree().process_frame

	# Should not crash (panel should use .get() with defaults)
	assert_true(true, "Should handle missing collections gracefully")


# ============================================================================
# HELPER METHODS
# ============================================================================

func _create_test_world_state() -> Dictionary:
	return {
		"current_year": 2025,
		"nfl_teams": [
			{"id": "ATL", "name": "Atlanta Falcons", "wins": 10, "losses": 7},
			{"id": "DAL", "name": "Dallas Cowboys", "wins": 12, "losses": 5}
		],
		"nfl_rosters": {
			"ATL": {
				"players": [
					{"id": "P1", "name": "Test Player 1", "position": "QB", "overall_rating": 85}
				]
			},
			"DAL": {
				"players": [
					{"id": "P2", "name": "Test Player 2", "position": "RB", "overall_rating": 88}
				]
			}
		},
		"draft_pool": {
			"2025": [
				{"id": "D1", "name": "Draft Prospect 1", "position": "WR"}
			]
		},
		"contracts": {
			"ATL": [
				{"player_id": "P1", "cap_hit": 5_000_000}
			]
		}
	}
