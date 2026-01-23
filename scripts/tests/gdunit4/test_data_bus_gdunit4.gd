extends GdUnitTestSuite
class_name TestDataBusGdUnit4

## GdUnit4 tests for DataBus autoload - event-driven UI update system
##
## Tests:
##   - Signal emission and subscription
##   - players_changed signal
##   - collection_changed signal
##   - phase_completed signal
##   - world_state_loaded signal

const DataBus = preload("res://autoloads/DataBus.gd")
const Player = preload("res://scripts/core/models/Player.gd")


# =============================================================================
# SIGNAL SUBSCRIPTION TESTS
# =============================================================================

func test_players_changed_signal_emits() -> void:
	var bus := DataBus.new()
	var signal_received := false
	var received_stage := -1
	var received_count := -1

	bus.players_changed.connect(func(stage, count):
		signal_received = true
		received_stage = stage
		received_count = count
	)

	bus.notify_players_changed(Player.PlayerStage.HIGH_SCHOOL, 500)

	assert_bool(signal_received).is_true()
	assert_int(received_stage).is_equal(Player.PlayerStage.HIGH_SCHOOL)
	assert_int(received_count).is_equal(500)


func test_collection_changed_signal_emits() -> void:
	var bus := DataBus.new()
	var signal_received := false
	var received_collection := ""
	var received_operation := ""

	bus.collection_changed.connect(func(collection_name, operation):
		signal_received = true
		received_collection = collection_name
		received_operation = operation
	)

	bus.notify_collection_changed("players", "insert")

	assert_bool(signal_received).is_true()
	assert_str(received_collection).is_equal("players")
	assert_str(received_operation).is_equal("insert")


func test_phase_completed_signal_emits() -> void:
	var bus := DataBus.new()
	var signal_received := false
	var received_phase := ""
	var received_year := -1

	bus.phase_completed.connect(func(phase_id, year):
		signal_received = true
		received_phase = phase_id
		received_year = year
	)

	bus.notify_phase_completed("hs_gen", 2025)

	assert_bool(signal_received).is_true()
	assert_str(received_phase).is_equal("hs_gen")
	assert_int(received_year).is_equal(2025)


func test_world_state_loaded_signal_emits() -> void:
	var bus := DataBus.new()
	var signal_received := false

	bus.world_state_loaded.connect(func():
		signal_received = true
	)

	bus.notify_world_state_loaded()

	assert_bool(signal_received).is_true()


# =============================================================================
# MULTIPLE SUBSCRIBERS TESTS
# =============================================================================

func test_multiple_subscribers_all_receive_signal() -> void:
	var bus := DataBus.new()
	var subscriber1_called := false
	var subscriber2_called := false
	var subscriber3_called := false

	bus.players_changed.connect(func(_stage, _count):
		subscriber1_called = true
	)

	bus.players_changed.connect(func(_stage, _count):
		subscriber2_called = true
	)

	bus.players_changed.connect(func(_stage, _count):
		subscriber3_called = true
	)

	bus.notify_players_changed(Player.PlayerStage.COLLEGE, 100)

	assert_bool(subscriber1_called).is_true()
	assert_bool(subscriber2_called).is_true()
	assert_bool(subscriber3_called).is_true()


func test_subscribers_receive_correct_parameters() -> void:
	var bus := DataBus.new()
	var params1 := {}
	var params2 := {}

	bus.collection_changed.connect(func(collection_name, operation):
		params1 = {"collection": collection_name, "op": operation}
	)

	bus.collection_changed.connect(func(collection_name, operation):
		params2 = {"collection": collection_name, "op": operation}
	)

	bus.notify_collection_changed("teams", "bulk_update")

	assert_str(String(params1["collection"])).is_equal("teams")
	assert_str(String(params1["op"])).is_equal("bulk_update")
	assert_str(String(params2["collection"])).is_equal("teams")
	assert_str(String(params2["op"])).is_equal("bulk_update")


# =============================================================================
# EDGE CASES AND VALIDATION
# =============================================================================

func test_notify_with_empty_parameters() -> void:
	var bus := DataBus.new()
	var signal_received := false

	bus.phase_completed.connect(func(_phase_id, _year):
		signal_received = true
	)

	bus.notify_phase_completed("", 0)

	assert_bool(signal_received).is_true()


func test_notify_players_changed_with_zero_count() -> void:
	var bus := DataBus.new()
	var received_count := -1

	bus.players_changed.connect(func(_stage, count):
		received_count = count
	)

	bus.notify_players_changed(Player.PlayerStage.NFL, 0)

	assert_int(received_count).is_equal(0)


func test_signal_without_subscribers_does_not_crash() -> void:
	var bus := DataBus.new()

	# Should not crash when no subscribers
	bus.notify_players_changed(Player.PlayerStage.HIGH_SCHOOL, 100)
	bus.notify_collection_changed("players", "insert")
	bus.notify_phase_completed("draft", 2025)
	bus.notify_world_state_loaded()

	# If we reach here without crashing, test passes
	assert_bool(true).is_true()


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_databus_supports_ui_reactive_pattern() -> void:
	var bus := DataBus.new()
	var ui_refresh_count := 0

	# Simulate UI component subscribing to multiple signals
	bus.players_changed.connect(func(_stage, _count):
		ui_refresh_count += 1
	)

	bus.collection_changed.connect(func(_collection, _op):
		ui_refresh_count += 1
	)

	bus.world_state_loaded.connect(func():
		ui_refresh_count += 1
	)

	# Simulate simulation updates
	bus.notify_players_changed(Player.PlayerStage.HIGH_SCHOOL, 500)
	bus.notify_collection_changed("players", "insert")
	bus.notify_world_state_loaded()

	# UI should have refreshed 3 times
	assert_int(ui_refresh_count).is_equal(3)


func test_databus_decouples_simulation_from_ui() -> void:
	var bus := DataBus.new()
	var simulation_events := []
	var ui_events := []

	# Simulation emits events
	simulation_events.append("hs_gen_start")
	bus.notify_phase_completed("hs_gen", 2025)
	simulation_events.append("hs_gen_end")

	# UI subscribes later (after events emitted)
	bus.phase_completed.connect(func(phase_id, year):
		ui_events.append({"phase": phase_id, "year": year})
	)

	# Emit another event
	bus.notify_phase_completed("draft", 2025)

	# UI only receives events after subscription
	assert_int(ui_events.size()).is_equal(1)
	assert_str(String(ui_events[0]["phase"])).is_equal("draft")


func test_multiple_collection_changes_in_sequence() -> void:
	var bus := DataBus.new()
	var events := []

	bus.collection_changed.connect(func(collection_name, operation):
		events.append({"collection": collection_name, "op": operation})
	)

	# Simulate multiple collection changes
	bus.notify_collection_changed("players", "insert")
	bus.notify_collection_changed("teams", "update")
	bus.notify_collection_changed("contracts", "delete")
	bus.notify_collection_changed("players", "bulk_update")

	# All events should be captured in order
	assert_int(events.size()).is_equal(4)
	assert_str(String(events[0]["collection"])).is_equal("players")
	assert_str(String(events[0]["op"])).is_equal("insert")
	assert_str(String(events[1]["collection"])).is_equal("teams")
	assert_str(String(events[2]["collection"])).is_equal("contracts")
	assert_str(String(events[3]["op"])).is_equal("bulk_update")


# =============================================================================
# SIGNAL DISCONNECTION TESTS
# =============================================================================

func test_signal_disconnection_works() -> void:
	var bus := DataBus.new()
	var call_count := 0

	var callback := func(_stage, _count):
		call_count += 1

	bus.players_changed.connect(callback)

	# First call
	bus.notify_players_changed(Player.PlayerStage.HIGH_SCHOOL, 100)
	assert_int(call_count).is_equal(1)

	# Disconnect
	bus.players_changed.disconnect(callback)

	# Second call should not trigger callback
	bus.notify_players_changed(Player.PlayerStage.COLLEGE, 200)
	assert_int(call_count).is_equal(1)  # Still 1, not incremented
