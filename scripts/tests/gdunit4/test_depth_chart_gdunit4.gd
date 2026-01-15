## GdUnit4 test suite for DepthChart
##
## Validates depth chart operations, serialization, and player management.
## Migrated from test_depth_chart.gd
extends GdUnitTestSuite

const DepthChart = preload("res://scripts/core/models/DepthChart.gd")


func test_set_depth_and_get_starter() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])
	chart.set_depth("RB", ["player_4", "player_5"])

	assert_str(chart.get_starter("QB")).is_equal("player_1")
	assert_str(chart.get_starter("RB")).is_equal("player_4")
	assert_str(chart.get_starter("WR")).is_equal("")


func test_get_depth_returns_correct_array() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])

	var qb_depth: Array[String] = chart.get_depth("QB")
	assert_int(qb_depth.size()).is_equal(3)
	assert_str(qb_depth[0]).is_equal("player_1")
	assert_str(qb_depth[1]).is_equal("player_2")
	assert_str(qb_depth[2]).is_equal("player_3")


func test_get_backup_at_index() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])

	assert_str(chart.get_backup("QB", 0)).is_equal("player_1")
	assert_str(chart.get_backup("QB", 1)).is_equal("player_2")
	assert_str(chart.get_backup("QB", 2)).is_equal("player_3")
	assert_str(chart.get_backup("QB", 3)).is_equal("")
	assert_str(chart.get_backup("QB", -1)).is_equal("")


func test_add_player_becomes_starter() -> void:
	var chart := DepthChart.new()

	chart.add_player("WR", "player_10")
	assert_str(chart.get_starter("WR")).is_equal("player_10")


func test_add_player_as_backup() -> void:
	var chart := DepthChart.new()
	chart.add_player("WR", "player_10")
	chart.add_player("WR", "player_11")

	assert_str(chart.get_backup("WR", 1)).is_equal("player_11")


func test_add_player_at_specific_index() -> void:
	var chart := DepthChart.new()
	chart.add_player("WR", "player_10")
	chart.add_player("WR", "player_11")
	chart.add_player("WR", "player_12", 0)

	assert_str(chart.get_starter("WR")).is_equal("player_12")


func test_remove_player_from_position() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])

	var removed := chart.remove_player("QB", "player_2")
	assert_bool(removed).is_true()
	assert_int(chart.get_depth("QB").size()).is_equal(2)
	assert_str(chart.get_backup("QB", 1)).is_equal("player_3")


func test_remove_nonexistent_player_returns_false() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])

	var removed := chart.remove_player("QB", "player_999")
	assert_bool(removed).is_false()


func test_remove_player_from_all_positions() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])
	chart.set_depth("RB", ["player_1", "player_4"])

	var count := chart.remove_player_from_all_positions("player_1")
	assert_int(count).is_equal(2)
	assert_str(chart.get_starter("QB")).is_equal("player_2")
	assert_str(chart.get_starter("RB")).is_equal("player_4")


func test_get_player_positions() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1"])
	chart.set_depth("RB", ["player_2", "player_3"])
	chart.set_depth("WR", ["player_1", "player_4"])

	var p1_positions: Array[String] = chart.get_player_positions("player_1")
	assert_int(p1_positions.size()).is_equal(2)
	assert_bool(p1_positions.has("QB")).is_true()
	assert_bool(p1_positions.has("WR")).is_true()


func test_get_filled_positions() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1"])
	chart.set_depth("RB", ["player_2", "player_3"])
	chart.set_depth("WR", ["player_4"])

	var filled: Array[String] = chart.get_filled_positions()
	assert_int(filled.size()).is_equal(3)
	assert_bool(filled.has("QB")).is_true()
	assert_bool(filled.has("RB")).is_true()
	assert_bool(filled.has("WR")).is_true()


func test_is_empty() -> void:
	var chart := DepthChart.new()
	assert_bool(chart.is_empty()).is_true()

	chart.set_depth("QB", ["player_1"])
	assert_bool(chart.is_empty()).is_false()


func test_clear() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1"])
	chart.set_depth("RB", ["player_2"])

	chart.clear()
	assert_bool(chart.is_empty()).is_true()


func test_to_dict_serialization() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2"])
	chart.set_depth("RB", ["player_3", "player_4", "player_5"])
	chart.set_depth("WR", ["player_6"])

	var serialized: Dictionary = chart.to_dict()
	assert_bool(serialized.has("position_depths")).is_true()

	var depths: Dictionary = serialized["position_depths"]
	assert_bool(depths.has("QB")).is_true()
	assert_bool(depths.has("RB")).is_true()
	assert_bool(depths.has("WR")).is_true()


func test_from_dict_deserialization() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2"])
	chart.set_depth("RB", ["player_3", "player_4", "player_5"])
	chart.set_depth("WR", ["player_6"])

	var serialized: Dictionary = chart.to_dict()

	var restored := DepthChart.new()
	restored.from_dict(serialized)

	assert_str(restored.get_starter("QB")).is_equal("player_1")
	assert_int(restored.get_depth("RB").size()).is_equal(3)
	assert_str(restored.get_backup("RB", 2)).is_equal("player_5")


func test_round_trip_serialization() -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2"])
	chart.set_depth("RB", ["player_3", "player_4", "player_5"])
	chart.set_depth("WR", ["player_6"])

	var serialized: Dictionary = chart.to_dict()
	var restored := DepthChart.new()
	restored.from_dict(serialized)
	var round_trip: Dictionary = restored.to_dict()

	assert_bool(round_trip.has("position_depths")).is_true()

	var rt_depths: Dictionary = round_trip["position_depths"]
	assert_int((rt_depths["QB"] as Array).size()).is_equal(2)
	assert_int((rt_depths["RB"] as Array).size()).is_equal(3)
	assert_int((rt_depths["WR"] as Array).size()).is_equal(1)
