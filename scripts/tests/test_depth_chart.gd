extends RefCounted

const DepthChart = preload("res://scripts/core/models/DepthChart.gd")

func run(t) -> void:
	test_basic_operations(t)
	test_serialization(t)
	test_backup_operations(t)
	test_player_removal(t)
	test_position_queries(t)

func test_basic_operations(t) -> void:
	var chart := DepthChart.new()

	# Test setting depth chart
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])
	chart.set_depth("RB", ["player_4", "player_5"])

	# Test get_starter
	t.assert_eq(chart.get_starter("QB"), "player_1", "QB starter is player_1")
	t.assert_eq(chart.get_starter("RB"), "player_4", "RB starter is player_4")
	t.assert_eq(chart.get_starter("WR"), "", "WR starter is empty (no depth set)")

	# Test get_depth
	var qb_depth: Array[String] = chart.get_depth("QB")
	t.assert_eq(qb_depth.size(), 3, "QB depth has 3 players")
	t.assert_eq(qb_depth[0], "player_1", "QB depth[0] is player_1")
	t.assert_eq(qb_depth[1], "player_2", "QB depth[1] is player_2")
	t.assert_eq(qb_depth[2], "player_3", "QB depth[2] is player_3")

func test_backup_operations(t) -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])

	# Test get_backup
	t.assert_eq(chart.get_backup("QB", 0), "player_1", "Backup at index 0 is starter")
	t.assert_eq(chart.get_backup("QB", 1), "player_2", "Backup at index 1 is player_2")
	t.assert_eq(chart.get_backup("QB", 2), "player_3", "Backup at index 2 is player_3")
	t.assert_eq(chart.get_backup("QB", 3), "", "Backup at index 3 is empty (out of bounds)")
	t.assert_eq(chart.get_backup("QB", -1), "", "Backup at negative index is empty")

	# Test add_player
	chart.add_player("WR", "player_10")
	t.assert_eq(chart.get_starter("WR"), "player_10", "Added player becomes starter")

	chart.add_player("WR", "player_11")
	t.assert_eq(chart.get_backup("WR", 1), "player_11", "Second player is backup")

	# Test inserting at specific index
	chart.add_player("WR", "player_12", 0)
	t.assert_eq(chart.get_starter("WR"), "player_12", "Inserted player becomes starter")

func test_player_removal(t) -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2", "player_3"])
	chart.set_depth("RB", ["player_1", "player_4"])  # player_1 at multiple positions

	# Test remove_player
	var removed := chart.remove_player("QB", "player_2")
	t.assert_eq(removed, true, "Player removed successfully")
	t.assert_eq(chart.get_depth("QB").size(), 2, "QB depth reduced to 2")
	t.assert_eq(chart.get_backup("QB", 1), "player_3", "player_3 moved up in depth")

	removed = chart.remove_player("QB", "player_999")
	t.assert_eq(removed, false, "Removing non-existent player returns false")

	# Test remove_player_from_all_positions
	var count := chart.remove_player_from_all_positions("player_1")
	t.assert_eq(count, 2, "player_1 removed from 2 positions")
	t.assert_eq(chart.get_starter("QB"), "player_3", "QB starter updated after removal")
	t.assert_eq(chart.get_starter("RB"), "player_4", "RB starter updated after removal")

func test_position_queries(t) -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1"])
	chart.set_depth("RB", ["player_2", "player_3"])
	chart.set_depth("WR", ["player_1", "player_4"])

	# Test get_player_positions
	var p1_positions: Array[String] = chart.get_player_positions("player_1")
	t.assert_eq(p1_positions.size(), 2, "player_1 appears at 2 positions")
	t.assert_eq(p1_positions.has("QB"), true, "player_1 at QB")
	t.assert_eq(p1_positions.has("WR"), true, "player_1 at WR")

	# Test get_filled_positions
	var filled: Array[String] = chart.get_filled_positions()
	t.assert_eq(filled.size(), 3, "3 positions have players")
	t.assert_eq(filled.has("QB"), true, "QB is filled")
	t.assert_eq(filled.has("RB"), true, "RB is filled")
	t.assert_eq(filled.has("WR"), true, "WR is filled")

	# Test is_empty
	t.assert_eq(chart.is_empty(), false, "Chart is not empty")

	chart.clear()
	t.assert_eq(chart.is_empty(), true, "Chart is empty after clear")

func test_serialization(t) -> void:
	var chart := DepthChart.new()
	chart.set_depth("QB", ["player_1", "player_2"])
	chart.set_depth("RB", ["player_3", "player_4", "player_5"])
	chart.set_depth("WR", ["player_6"])

	# Test to_dict
	var serialized: Dictionary = chart.to_dict()
	t.assert_eq(serialized.has("position_depths"), true, "Serialized dict has position_depths")

	var depths: Dictionary = serialized["position_depths"]
	t.assert_eq(depths.has("QB"), true, "Serialized depths has QB")
	t.assert_eq(depths.has("RB"), true, "Serialized depths has RB")
	t.assert_eq(depths.has("WR"), true, "Serialized depths has WR")

	# Test from_dict
	var restored := DepthChart.new()
	restored.from_dict(serialized)
	t.assert_eq(restored.get_starter("QB"), "player_1", "Restored QB starter")
	t.assert_eq(restored.get_depth("RB").size(), 3, "Restored RB depth size")
	t.assert_eq(restored.get_backup("RB", 2), "player_5", "Restored RB backup at index 2")

	# Test round-trip
	var round_trip: Dictionary = restored.to_dict()
	t.assert_eq(round_trip.has("position_depths"), true, "Round-trip has position_depths")

	var rt_depths: Dictionary = round_trip["position_depths"]
	t.assert_eq((rt_depths["QB"] as Array).size(), 2, "Round-trip QB depth size")
	t.assert_eq((rt_depths["RB"] as Array).size(), 3, "Round-trip RB depth size")
	t.assert_eq((rt_depths["WR"] as Array).size(), 1, "Round-trip WR depth size")
