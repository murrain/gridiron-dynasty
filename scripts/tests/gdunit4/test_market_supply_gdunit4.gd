extends GdUnitTestSuite
class_name TestMarketSupplyGdUnit4

const MarketSupply = preload("res://scripts/core/valuation/MarketSupply.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

## Test empty player array returns empty supply
func test_empty_players_returns_empty_supply() -> void:
	var supply := MarketSupply.compute_position_supply([])
	assert_that(supply).is_empty()

## Test null player array returns empty supply
func test_null_players_returns_empty_supply() -> void:
	var supply := MarketSupply.compute_position_supply(null)
	assert_that(supply).is_empty()

## Test single player above replacement level
func test_single_player_above_replacement() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 75.0}
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	assert_int(supply["QB"]).is_equal(1)

## Test player at replacement level not counted
func test_player_at_replacement_not_counted() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 55.0}
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	# Player at replacement level (55.0) is not above (>) replacement
	assert_bool(supply.has("QB")).is_false()

## Test player below replacement level not counted
func test_player_below_replacement_not_counted() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 50.0}
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	assert_bool(supply.has("QB")).is_false()

## Test multiple players at same position
func test_multiple_players_same_position() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 75.0},
		{"position": "QB", "eval_score": 80.0},
		{"position": "QB", "eval_score": 65.0}
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	assert_int(supply["QB"]).is_equal(3)

## Test multiple positions
func test_multiple_positions() -> void:
	var config := {
		"replacement_levels": {
			"QB": 55.0,
			"RB": 62.0,
			"WR": 58.0
		}
	}

	var players := [
		{"position": "QB", "eval_score": 75.0},
		{"position": "QB", "eval_score": 80.0},
		{"position": "RB", "eval_score": 70.0},
		{"position": "WR", "eval_score": 65.0},
		{"position": "WR", "eval_score": 72.0},
		{"position": "WR", "eval_score": 59.0}
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	assert_int(supply["QB"]).is_equal(2)
	assert_int(supply["RB"]).is_equal(1)
	assert_int(supply["WR"]).is_equal(3)

## Test mixed above and below replacement players
func test_mixed_above_below_replacement() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 75.0},  # Above
		{"position": "QB", "eval_score": 50.0},  # Below
		{"position": "QB", "eval_score": 80.0},  # Above
		{"position": "QB", "eval_score": 55.0},  # At replacement
		{"position": "QB", "eval_score": 60.0}   # Above
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	# Only 3 players are strictly above replacement
	assert_int(supply["QB"]).is_equal(3)

## Test invalid player entries are skipped
func test_invalid_players_skipped() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 75.0},
		null,  # Invalid
		{"position": "QB", "eval_score": 80.0},
		"not a dict",  # Invalid
		{"position": "QB", "eval_score": 65.0}
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	assert_int(supply["QB"]).is_equal(3)

## Test player missing position field
func test_player_missing_position() -> void:
	var config := {
		"replacement_levels": {"ATH": 55.0}
	}

	var players := [
		{"eval_score": 75.0}  # Missing position, defaults to "ATH"
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	assert_int(supply["ATH"]).is_equal(1)

## Test player missing eval_score field
func test_player_missing_eval_score() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB"}  # Missing eval_score, defaults to 0.0
	]

	var supply := MarketSupply.compute_position_supply(players, config)
	# Default score 0.0 is below replacement 55.0
	assert_bool(supply.has("QB")).is_false()

## Test compute_pool_supply with minimum threshold
func test_pool_supply_with_threshold() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 80.0},  # Above threshold
		{"position": "QB", "eval_score": 75.0},  # Above threshold
		{"position": "QB", "eval_score": 65.0},  # Above replacement but below threshold
		{"position": "QB", "eval_score": 50.0}   # Below replacement
	]

	var supply := MarketSupply.compute_pool_supply(players, 70.0, config)
	# Only players with 70+ score are counted
	assert_int(supply["QB"]).is_equal(2)

## Test compute_pool_supply with zero threshold
func test_pool_supply_zero_threshold() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 80.0},
		{"position": "QB", "eval_score": 60.0},
		{"position": "QB", "eval_score": 50.0}
	]

	var supply := MarketSupply.compute_pool_supply(players, 0.0, config)
	# Only players above replacement level (55.0)
	assert_int(supply["QB"]).is_equal(2)

## Test compute_pool_supply with empty pool
func test_pool_supply_empty_pool() -> void:
	var supply := MarketSupply.compute_pool_supply([])
	assert_that(supply).is_empty()

## Test compute_pool_supply with null pool
func test_pool_supply_null_pool() -> void:
	var supply := MarketSupply.compute_pool_supply(null)
	assert_that(supply).is_empty()

## Test realistic NFL roster scenario
func test_realistic_nfl_roster() -> void:
	var config := {
		"replacement_levels": {
			"QB": 55.0,
			"RB": 62.0,
			"WR": 58.0,
			"TE": 56.0,
			"OL": 54.0
		}
	}

	var players := []
	# Create 32 teams worth of players
	for team in range(32):
		# Each team has players with varying quality
		players.append({"position": "QB", "eval_score": 60.0 + (team % 20)})
		players.append({"position": "QB", "eval_score": 50.0})  # Backup below replacement
		players.append({"position": "RB", "eval_score": 65.0 + (team % 15)})
		players.append({"position": "RB", "eval_score": 68.0})
		players.append({"position": "WR", "eval_score": 60.0 + (team % 20)})
		players.append({"position": "WR", "eval_score": 65.0})
		players.append({"position": "WR", "eval_score": 62.0})

	var supply := MarketSupply.compute_position_supply(players, config)

	# Verify we have supply counts for each position
	assert_bool(supply.has("QB")).is_true()
	assert_bool(supply.has("RB")).is_true()
	assert_bool(supply.has("WR")).is_true()

	# QB should have ~32 starters above replacement
	assert_int(supply["QB"]).is_greater(25)

	# RB should have many above replacement (abundant position)
	assert_int(supply["RB"]).is_greater(50)

	# WR should have many above replacement (96 starters needed)
	assert_int(supply["WR"]).is_greater(80)

## Test draft pool scenario
func test_draft_pool_scenario() -> void:
	var config := {
		"replacement_levels": {
			"QB": 55.0,
			"WR": 58.0,
			"EDGE": 52.0
		}
	}

	# Draft class with varying quality
	var draft_class := [
		{"position": "QB", "eval_score": 82.0},   # Elite prospect
		{"position": "QB", "eval_score": 75.0},   # Good prospect
		{"position": "QB", "eval_score": 58.0},   # Average prospect
		{"position": "WR", "eval_score": 78.0},
		{"position": "WR", "eval_score": 72.0},
		{"position": "WR", "eval_score": 68.0},
		{"position": "WR", "eval_score": 62.0},
		{"position": "EDGE", "eval_score": 85.0},
		{"position": "EDGE", "eval_score": 55.0}
	]

	# Count draft-worthy players (60+ score)
	var supply := MarketSupply.compute_pool_supply(draft_class, 60.0, config)

	assert_int(supply["QB"]).is_equal(2)   # Only 82 and 75 are 60+
	assert_int(supply["WR"]).is_equal(4)   # All WRs are 60+
	assert_int(supply["EDGE"]).is_equal(1) # Only 85 is 60+

## Test supply calculation is deterministic
func test_supply_deterministic() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0}
	}

	var players := [
		{"position": "QB", "eval_score": 75.0},
		{"position": "QB", "eval_score": 80.0},
		{"position": "QB", "eval_score": 65.0}
	]

	var supply1 := MarketSupply.compute_position_supply(players, config)
	var supply2 := MarketSupply.compute_position_supply(players, config)
	var supply3 := MarketSupply.compute_position_supply(players, config)

	assert_that(supply1).is_equal(supply2)
	assert_that(supply2).is_equal(supply3)
