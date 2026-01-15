## GdUnit4 test suite for MarketSupply
##
## Validates market supply calculation, position grouping, and replacement level filtering.
## Migrated from test_market_supply.gd
extends GdUnitTestSuite

const MarketSupply = preload("res://scripts/core/valuation/MarketSupply.gd")
const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")


func test_counts_only_above_replacement() -> void:
	var players := [
		{"position": "QB", "eval_score": 70.0},
		{"position": "QB", "eval_score": 55.0},
		{"position": "QB", "eval_score": 50.0},
		{"position": "QB", "eval_score": 80.0},
		{"position": "RB", "eval_score": 65.0},
		{"position": "RB", "eval_score": 62.0},
		{"position": "RB", "eval_score": 60.0},
		{"position": "RB", "eval_score": 75.0},
		{"position": "RB", "eval_score": 70.0},
	]

	var supply := MarketSupply.compute_position_supply(players)

	assert_int(int(supply.get("QB", 0))).is_equal(2)
	assert_int(int(supply.get("RB", 0))).is_equal(3)


func test_position_grouping() -> void:
	var players := [
		{"position": "QB", "eval_score": 70.0},
		{"position": "QB", "eval_score": 65.0},
		{"position": "WR", "eval_score": 70.0},
		{"position": "WR", "eval_score": 75.0},
		{"position": "WR", "eval_score": 80.0},
		{"position": "CB", "eval_score": 65.0},
		{"position": "CB", "eval_score": 70.0},
	]

	var supply := MarketSupply.compute_position_supply(players)

	assert_int(int(supply.get("QB", 0))).is_equal(2)
	assert_int(int(supply.get("WR", 0))).is_equal(3)
	assert_int(int(supply.get("CB", 0))).is_equal(2)
	assert_bool(supply.has("TE")).is_false()


func test_empty_pools() -> void:
	var empty_supply := MarketSupply.compute_position_supply([])
	assert_int(empty_supply.size()).is_equal(0)

	var null_array: Array = []
	var null_supply := MarketSupply.compute_position_supply(null_array)
	assert_int(null_supply.size()).is_equal(0)

	var below_repl := [
		{"position": "QB", "eval_score": 40.0},
		{"position": "RB", "eval_score": 50.0},
		{"position": "WR", "eval_score": 45.0},
	]
	var below_supply := MarketSupply.compute_position_supply(below_repl)
	assert_int(below_supply.size()).is_equal(0)


func test_mixed_quality_players() -> void:
	var players := [
		{"position": "QB", "eval_score": 95.0},
		{"position": "QB", "eval_score": 90.0},
		{"position": "QB", "eval_score": 75.0},
		{"position": "QB", "eval_score": 70.0},
		{"position": "QB", "eval_score": 68.0},
		{"position": "QB", "eval_score": 60.0},
		{"position": "QB", "eval_score": 58.0},
		{"position": "QB", "eval_score": 56.0},
		{"position": "QB", "eval_score": 55.0},
		{"position": "QB", "eval_score": 54.0},
		{"position": "QB", "eval_score": 50.0},
		{"position": "QB", "eval_score": 40.0},
	]

	var supply := MarketSupply.compute_position_supply(players)

	assert_int(int(supply.get("QB", 0))).is_equal(8)


func test_pool_supply_filtering() -> void:
	var players := [
		{"position": "QB", "eval_score": 85.0},
		{"position": "QB", "eval_score": 75.0},
		{"position": "QB", "eval_score": 65.0},
		{"position": "QB", "eval_score": 55.0},
		{"position": "RB", "eval_score": 80.0},
		{"position": "RB", "eval_score": 60.0},
	]

	var supply := MarketSupply.compute_pool_supply(players, 70.0)

	assert_int(int(supply.get("QB", 0))).is_equal(2)
	assert_int(int(supply.get("RB", 0))).is_equal(1)


func test_pool_supply_empty() -> void:
	var empty_supply := MarketSupply.compute_pool_supply([])
	assert_int(empty_supply.size()).is_equal(0)

	var null_pool: Array = []
	var null_supply := MarketSupply.compute_pool_supply(null_pool)
	assert_int(null_supply.size()).is_equal(0)


func test_invalid_player_entries() -> void:
	var players := [
		{"position": "QB", "eval_score": 70.0},
		null,
		{"position": "RB", "eval_score": 70.0},
		{},
		{"position": "WR", "eval_score": 70.0},
	]

	var supply := MarketSupply.compute_position_supply(players)

	assert_int(int(supply.get("QB", 0))).is_equal(1)
	assert_int(int(supply.get("RB", 0))).is_equal(1)
	assert_int(int(supply.get("WR", 0))).is_equal(1)


func test_custom_replacement_levels() -> void:
	var players := [
		{"position": "QB", "eval_score": 60.0},
		{"position": "QB", "eval_score": 70.0},
		{"position": "QB", "eval_score": 50.0},
	]

	var default_supply := MarketSupply.compute_position_supply(players)
	assert_int(int(default_supply.get("QB", 0))).is_equal(2)

	var custom_config := {
		"replacement_levels": {
			"QB": 65.0
		}
	}
	var custom_supply := MarketSupply.compute_position_supply(players, custom_config)
	assert_int(int(custom_supply.get("QB", 0))).is_equal(1)


func test_all_standard_positions() -> void:
	var players := [
		{"position": "QB", "eval_score": 70.0},
		{"position": "RB", "eval_score": 75.0},
		{"position": "WR", "eval_score": 70.0},
		{"position": "TE", "eval_score": 70.0},
		{"position": "OL", "eval_score": 70.0},
		{"position": "DL", "eval_score": 70.0},
		{"position": "EDGE", "eval_score": 70.0},
		{"position": "LB", "eval_score": 70.0},
		{"position": "CB", "eval_score": 70.0},
		{"position": "S", "eval_score": 70.0},
		{"position": "K", "eval_score": 70.0},
		{"position": "P", "eval_score": 70.0},
	]

	var supply := MarketSupply.compute_position_supply(players)

	assert_int(int(supply.get("QB", 0))).is_equal(1)
	assert_int(int(supply.get("RB", 0))).is_equal(1)
	assert_int(int(supply.get("WR", 0))).is_equal(1)
	assert_int(int(supply.get("TE", 0))).is_equal(1)
	assert_int(int(supply.get("OL", 0))).is_equal(1)
	assert_int(int(supply.get("DL", 0))).is_equal(1)
	assert_int(int(supply.get("EDGE", 0))).is_equal(1)
	assert_int(int(supply.get("LB", 0))).is_equal(1)
	assert_int(int(supply.get("CB", 0))).is_equal(1)
	assert_int(int(supply.get("S", 0))).is_equal(1)
	assert_int(int(supply.get("K", 0))).is_equal(1)
	assert_int(int(supply.get("P", 0))).is_equal(1)


func test_realistic_nfl_scenario() -> void:
	var players := []

	for team in range(32):
		players.append({"position": "QB", "eval_score": 75.0 + (team % 10)})
		players.append({"position": "QB", "eval_score": 60.0 + (team % 5)})

		players.append({"position": "RB", "eval_score": 75.0})
		players.append({"position": "RB", "eval_score": 70.0})
		players.append({"position": "RB", "eval_score": 68.0})
		players.append({"position": "RB", "eval_score": 65.0})

		for i in range(6):
			players.append({"position": "WR", "eval_score": 70.0 + (i * 2)})

	var supply := MarketSupply.compute_position_supply(players)

	assert_int(int(supply.get("QB", 0))).is_equal(64)
	assert_int(int(supply.get("RB", 0))).is_equal(128)
	assert_int(int(supply.get("WR", 0))).is_equal(192)
