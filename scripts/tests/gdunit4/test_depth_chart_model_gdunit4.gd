extends GdUnitTestSuite
class_name TestDepthChartModelGdUnit4

const DepthChart = preload("res://scripts/core/models/DepthChart.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_depth_chart_initialization() -> void:
	var depth_chart = DepthChart.new()
	assert_bool(depth_chart.position_depths.is_empty()).is_true()
	assert_bool(depth_chart.is_empty()).is_true()

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_depth_chart_serialization_roundtrip() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002", "P003"])
	depth_chart.set_depth("RB", ["P004", "P005"])

	var dict = depth_chart.to_dict()
	var restored = DepthChart.new()
	restored.from_dict(dict)

	assert_array(restored.get_depth("QB")).contains_exactly(["P001", "P002", "P003"])
	assert_array(restored.get_depth("RB")).contains_exactly(["P004", "P005"])

func test_depth_chart_to_dict_schema() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("WR", ["P010", "P011"])

	var dict = depth_chart.to_dict()

	assert_bool(dict.has("position_depths")).is_true()
	assert_that(dict["position_depths"]).is_instanceof(Dictionary)

func test_depth_chart_from_dict_empty() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.from_dict({})

	assert_bool(depth_chart.is_empty()).is_true()

func test_depth_chart_serialization_preserves_order() -> void:
	var depth_chart = DepthChart.new()
	var player_order = ["P001", "P002", "P003", "P004"]
	depth_chart.set_depth("QB", player_order)

	var dict = depth_chart.to_dict()
	var restored = DepthChart.new()
	restored.from_dict(dict)

	var restored_order = restored.get_depth("QB")
	for i in range(player_order.size()):
		assert_str(restored_order[i]).is_equal(player_order[i])

# =============================================================================
# CORE FUNCTIONALITY TESTS
# =============================================================================

func test_depth_chart_get_starter() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002"])

	assert_str(depth_chart.get_starter("QB")).is_equal("P001")

func test_depth_chart_get_starter_empty_position() -> void:
	var depth_chart = DepthChart.new()
	assert_str(depth_chart.get_starter("QB")).is_equal("")

func test_depth_chart_get_starter_unknown_position() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])

	assert_str(depth_chart.get_starter("RB")).is_equal("")

func test_depth_chart_get_depth() -> void:
	var depth_chart = DepthChart.new()
	var players = ["P001", "P002", "P003"]
	depth_chart.set_depth("WR", players)

	var result = depth_chart.get_depth("WR")
	assert_array(result).contains_exactly(players)

func test_depth_chart_get_depth_empty_position() -> void:
	var depth_chart = DepthChart.new()
	var result = depth_chart.get_depth("QB")

	assert_array(result).is_empty()

func test_depth_chart_set_depth() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("RB", ["P010", "P011"])

	assert_str(depth_chart.get_starter("RB")).is_equal("P010")
	assert_array(depth_chart.get_depth("RB")).has_size(2)

func test_depth_chart_set_depth_overwrites_existing() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002"])
	depth_chart.set_depth("QB", ["P003", "P004"])

	assert_str(depth_chart.get_starter("QB")).is_equal("P003")
	assert_array(depth_chart.get_depth("QB")).contains_exactly(["P003", "P004"])

func test_depth_chart_get_backup() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002", "P003"])

	assert_str(depth_chart.get_backup("QB", 0)).is_equal("P001")
	assert_str(depth_chart.get_backup("QB", 1)).is_equal("P002")
	assert_str(depth_chart.get_backup("QB", 2)).is_equal("P003")

func test_depth_chart_get_backup_out_of_bounds() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002"])

	assert_str(depth_chart.get_backup("QB", 5)).is_equal("")

func test_depth_chart_get_backup_negative_index() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])

	assert_str(depth_chart.get_backup("QB", -1)).is_equal("")

# =============================================================================
# ADD/REMOVE PLAYER TESTS
# =============================================================================

func test_depth_chart_add_player_to_end() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.add_player("QB", "P002")

	assert_array(depth_chart.get_depth("QB")).contains_exactly(["P001", "P002"])

func test_depth_chart_add_player_at_index() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P003"])
	depth_chart.add_player("QB", "P002", 1)

	assert_array(depth_chart.get_depth("QB")).contains_exactly(["P001", "P002", "P003"])

func test_depth_chart_add_player_at_start() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P002"])
	depth_chart.add_player("QB", "P001", 0)

	assert_str(depth_chart.get_starter("QB")).is_equal("P001")

func test_depth_chart_add_player_to_empty_position() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.add_player("QB", "P001")

	assert_str(depth_chart.get_starter("QB")).is_equal("P001")

func test_depth_chart_add_player_removes_duplicate() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002", "P003"])
	depth_chart.add_player("QB", "P002", 0)  # Move P002 to starter

	var depth = depth_chart.get_depth("QB")
	assert_array(depth).has_size(3)
	assert_str(depth[0]).is_equal("P002")

func test_depth_chart_remove_player() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002", "P003"])

	var removed = depth_chart.remove_player("QB", "P002")

	assert_bool(removed).is_true()
	assert_array(depth_chart.get_depth("QB")).contains_exactly(["P001", "P003"])

func test_depth_chart_remove_player_not_found() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])

	var removed = depth_chart.remove_player("QB", "P999")

	assert_bool(removed).is_false()

func test_depth_chart_remove_player_empty_position() -> void:
	var depth_chart = DepthChart.new()
	var removed = depth_chart.remove_player("QB", "P001")

	assert_bool(removed).is_false()

func test_depth_chart_remove_starter() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002"])

	depth_chart.remove_player("QB", "P001")

	assert_str(depth_chart.get_starter("QB")).is_equal("P002")

func test_depth_chart_remove_player_from_all_positions() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001", "P002"])
	depth_chart.set_depth("RB", ["P003", "P001"])
	depth_chart.set_depth("WR", ["P004", "P005"])

	var count = depth_chart.remove_player_from_all_positions("P001")

	assert_int(count).is_equal(2)
	assert_array(depth_chart.get_depth("QB")).contains_exactly(["P002"])
	assert_array(depth_chart.get_depth("RB")).contains_exactly(["P003"])
	assert_array(depth_chart.get_depth("WR")).contains_exactly(["P004", "P005"])

func test_depth_chart_remove_player_from_all_positions_not_found() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])

	var count = depth_chart.remove_player_from_all_positions("P999")

	assert_int(count).is_equal(0)

# =============================================================================
# QUERY TESTS
# =============================================================================

func test_depth_chart_get_player_positions() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.set_depth("RB", ["P002", "P001"])
	depth_chart.set_depth("WR", ["P003", "P004", "P001"])

	var positions = depth_chart.get_player_positions("P001")

	assert_int(positions.size()).is_equal(3)
	assert_array(positions).contains("QB")
	assert_array(positions).contains("RB")
	assert_array(positions).contains("WR")

func test_depth_chart_get_player_positions_not_found() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])

	var positions = depth_chart.get_player_positions("P999")

	assert_array(positions).is_empty()

func test_depth_chart_get_filled_positions() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.set_depth("RB", ["P002"])
	depth_chart.set_depth("WR", ["P003"])

	var filled = depth_chart.get_filled_positions()

	assert_int(filled.size()).is_equal(3)
	assert_array(filled).contains("QB")
	assert_array(filled).contains("RB")
	assert_array(filled).contains("WR")

func test_depth_chart_get_filled_positions_empty() -> void:
	var depth_chart = DepthChart.new()
	var filled = depth_chart.get_filled_positions()

	assert_array(filled).is_empty()

func test_depth_chart_clear() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.set_depth("RB", ["P002"])

	depth_chart.clear()

	assert_bool(depth_chart.is_empty()).is_true()
	assert_array(depth_chart.get_filled_positions()).is_empty()

# =============================================================================
# EDGE CASES
# =============================================================================

func test_depth_chart_add_player_with_empty_id() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.add_player("QB", "")

	# Should log warning but not crash
	assert_array(depth_chart.get_depth("QB")).is_empty()

func test_depth_chart_add_player_to_empty_position_name() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.add_player("", "P001")

	# Should log warning but not crash
	assert_bool(depth_chart.is_empty()).is_true()

func test_depth_chart_set_depth_with_empty_position() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("", ["P001"])

	# Should log warning but not crash
	assert_bool(depth_chart.is_empty()).is_true()

func test_depth_chart_multiple_positions_per_player() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.set_depth("RB", ["P001"])  # Same player at multiple positions

	assert_str(depth_chart.get_starter("QB")).is_equal("P001")
	assert_str(depth_chart.get_starter("RB")).is_equal("P001")

func test_depth_chart_large_depth_chart() -> void:
	var depth_chart = DepthChart.new()
	var players: Array[String] = []
	for i in range(20):
		players.append("P%03d" % i)

	depth_chart.set_depth("QB", players)

	assert_array(depth_chart.get_depth("QB")).has_size(20)
	assert_str(depth_chart.get_starter("QB")).is_equal("P000")
	assert_str(depth_chart.get_backup("QB", 19)).is_equal("P019")

func test_depth_chart_special_position_names() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("K/P", ["P001"])
	depth_chart.set_depth("3-4 OLB", ["P002"])

	assert_str(depth_chart.get_starter("K/P")).is_equal("P001")
	assert_str(depth_chart.get_starter("3-4 OLB")).is_equal("P002")

func test_depth_chart_case_sensitive_positions() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.set_depth("qb", ["P002"])

	# Positions should be case-sensitive
	assert_str(depth_chart.get_starter("QB")).is_equal("P001")
	assert_str(depth_chart.get_starter("qb")).is_equal("P002")

func test_depth_chart_empty_array_set_depth() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.set_depth("QB", [])

	# Empty array should clear the position
	assert_array(depth_chart.get_depth("QB")).is_empty()

func test_depth_chart_add_player_with_large_index() -> void:
	var depth_chart = DepthChart.new()
	depth_chart.set_depth("QB", ["P001"])
	depth_chart.add_player("QB", "P002", 999)

	# Large index should add to end
	assert_array(depth_chart.get_depth("QB")).contains_exactly(["P001", "P002"])
