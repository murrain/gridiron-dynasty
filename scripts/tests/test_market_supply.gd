extends RefCounted

const MarketSupply = preload("res://scripts/core/valuation/MarketSupply.gd")
const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")

## Test 1: Verify supply counts only players above replacement level
func test_counts_only_above_replacement(t) -> void:
	var players := [
		# QB replacement level is 55.0
		{"position": "QB", "eval_score": 70.0},  # Above - counted
		{"position": "QB", "eval_score": 55.0},  # Equal - NOT counted
		{"position": "QB", "eval_score": 50.0},  # Below - NOT counted
		{"position": "QB", "eval_score": 80.0},  # Above - counted

		# RB replacement level is 62.0
		{"position": "RB", "eval_score": 65.0},  # Above - counted
		{"position": "RB", "eval_score": 62.0},  # Equal - NOT counted
		{"position": "RB", "eval_score": 60.0},  # Below - NOT counted
		{"position": "RB", "eval_score": 75.0},  # Above - counted
		{"position": "RB", "eval_score": 70.0},  # Above - counted
	]

	var supply := MarketSupply.compute_position_supply(players)

	# Should count only the 2 QBs above 55.0
	t.assert_eq(supply.get("QB", 0), 2, "QB supply counts only above replacement")

	# Should count only the 3 RBs above 62.0
	t.assert_eq(supply.get("RB", 0), 3, "RB supply counts only above replacement")

## Test 2: Verify correct position grouping
func test_position_grouping(t) -> void:
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

	# QB replacement is 55.0, both above
	t.assert_eq(supply.get("QB", 0), 2, "QB supply grouped correctly")

	# WR replacement is 58.0, all three above
	t.assert_eq(supply.get("WR", 0), 3, "WR supply grouped correctly")

	# CB replacement is 53.0, both above
	t.assert_eq(supply.get("CB", 0), 2, "CB supply grouped correctly")

	# Positions not in player list should not appear
	t.assert_eq(supply.has("TE"), false, "Unlisted positions not in supply")

## Test 3: Verify empty pools return empty supply dictionary
func test_empty_pools(t) -> void:
	# Completely empty array
	var empty_supply := MarketSupply.compute_position_supply([])
	t.assert_eq(empty_supply.size(), 0, "Empty array returns empty supply")

	# Null array
	var null_supply := MarketSupply.compute_position_supply(null)
	t.assert_eq(null_supply.size(), 0, "Null array returns empty supply")

	# Array with all players below replacement
	var below_repl := [
		{"position": "QB", "eval_score": 40.0},  # Well below 55.0
		{"position": "RB", "eval_score": 50.0},  # Well below 62.0
		{"position": "WR", "eval_score": 45.0},  # Well below 58.0
	]
	var below_supply := MarketSupply.compute_position_supply(below_repl)
	t.assert_eq(below_supply.size(), 0, "All below-replacement returns empty supply")

## Test 4: Verify supply calculation with mixed quality players
func test_mixed_quality_players(t) -> void:
	var players := [
		# Elite tier
		{"position": "QB", "eval_score": 95.0},
		{"position": "QB", "eval_score": 90.0},

		# Starter tier
		{"position": "QB", "eval_score": 75.0},
		{"position": "QB", "eval_score": 70.0},
		{"position": "QB", "eval_score": 68.0},

		# Backup tier (still above replacement 55.0)
		{"position": "QB", "eval_score": 60.0},
		{"position": "QB", "eval_score": 58.0},
		{"position": "QB", "eval_score": 56.0},

		# Replacement level (exactly at or below 55.0)
		{"position": "QB", "eval_score": 55.0},
		{"position": "QB", "eval_score": 54.0},
		{"position": "QB", "eval_score": 50.0},
		{"position": "QB", "eval_score": 40.0},
	]

	var supply := MarketSupply.compute_position_supply(players)

	# Should count all 8 above replacement (not the 4 at/below)
	t.assert_eq(supply.get("QB", 0), 8, "Mixed quality supply counted correctly")

## Test 5: Verify compute_pool_supply filters by min_score
func test_pool_supply_filtering(t) -> void:
	var players := [
		{"position": "QB", "eval_score": 85.0},  # Above min_score
		{"position": "QB", "eval_score": 75.0},  # Above min_score
		{"position": "QB", "eval_score": 65.0},  # Below min_score
		{"position": "QB", "eval_score": 55.0},  # Below min_score
		{"position": "RB", "eval_score": 80.0},  # Above min_score
		{"position": "RB", "eval_score": 60.0},  # Below min_score
	]

	# Filter to only players with 70+ score
	var supply := MarketSupply.compute_pool_supply(players, 70.0)

	# QB: Only 85.0 and 75.0 pass the filter, both are above replacement (55.0)
	t.assert_eq(supply.get("QB", 0), 2, "Pool supply filters QB correctly")

	# RB: Only 80.0 passes the filter, and it's above replacement (62.0)
	t.assert_eq(supply.get("RB", 0), 1, "Pool supply filters RB correctly")

## Test 6: Verify compute_pool_supply with empty pool
func test_pool_supply_empty(t) -> void:
	var empty_supply := MarketSupply.compute_pool_supply([])
	t.assert_eq(empty_supply.size(), 0, "Empty pool returns empty supply")

	var null_supply := MarketSupply.compute_pool_supply(null)
	t.assert_eq(null_supply.size(), 0, "Null pool returns empty supply")

## Test 7: Verify handling of invalid player entries
func test_invalid_player_entries(t) -> void:
	var players := [
		{"position": "QB", "eval_score": 70.0},  # Valid
		null,  # Invalid - should be skipped
		{"position": "RB", "eval_score": 70.0},  # Valid
		{},  # Missing fields - should be skipped (treated as position="ATH", score=0.0)
		{"position": "WR", "eval_score": 70.0},  # Valid
	]

	var supply := MarketSupply.compute_position_supply(players)

	# Should count only the 3 valid players
	t.assert_eq(supply.get("QB", 0), 1, "QB counted despite invalid entries")
	t.assert_eq(supply.get("RB", 0), 1, "RB counted despite invalid entries")
	t.assert_eq(supply.get("WR", 0), 1, "WR counted despite invalid entries")

## Test 8: Verify custom config replacement levels
func test_custom_replacement_levels(t) -> void:
	var players := [
		{"position": "QB", "eval_score": 60.0},  # Above default (55.0), below custom (65.0)
		{"position": "QB", "eval_score": 70.0},  # Above both
		{"position": "QB", "eval_score": 50.0},  # Below both
	]

	# Use default replacement levels
	var default_supply := MarketSupply.compute_position_supply(players)
	t.assert_eq(default_supply.get("QB", 0), 2, "Default replacement counts 2 QBs")

	# Use custom replacement levels (higher threshold)
	var custom_config := {
		"replacement_levels": {
			"QB": 65.0  # Raised from 55.0 to 65.0
		}
	}
	var custom_supply := MarketSupply.compute_position_supply(players, custom_config)
	t.assert_eq(custom_supply.get("QB", 0), 1, "Custom replacement counts 1 QB")

## Test 9: Verify supply across all standard positions
func test_all_standard_positions(t) -> void:
	# Create one above-replacement player at each position
	var players := [
		{"position": "QB", "eval_score": 70.0},    # Repl: 55.0
		{"position": "RB", "eval_score": 75.0},    # Repl: 62.0
		{"position": "WR", "eval_score": 70.0},    # Repl: 58.0
		{"position": "TE", "eval_score": 70.0},    # Repl: 56.0
		{"position": "OL", "eval_score": 70.0},    # Repl: 54.0
		{"position": "DL", "eval_score": 70.0},    # Repl: 57.0
		{"position": "EDGE", "eval_score": 70.0},  # Repl: 52.0
		{"position": "LB", "eval_score": 70.0},    # Repl: 58.0
		{"position": "CB", "eval_score": 70.0},    # Repl: 53.0
		{"position": "S", "eval_score": 70.0},     # Repl: 57.0
		{"position": "K", "eval_score": 70.0},     # Repl: 65.0
		{"position": "P", "eval_score": 70.0},     # Repl: 65.0
	]

	var supply := MarketSupply.compute_position_supply(players)

	# All positions should have exactly 1 player
	t.assert_eq(supply.get("QB", 0), 1, "QB position counted")
	t.assert_eq(supply.get("RB", 0), 1, "RB position counted")
	t.assert_eq(supply.get("WR", 0), 1, "WR position counted")
	t.assert_eq(supply.get("TE", 0), 1, "TE position counted")
	t.assert_eq(supply.get("OL", 0), 1, "OL position counted")
	t.assert_eq(supply.get("DL", 0), 1, "DL position counted")
	t.assert_eq(supply.get("EDGE", 0), 1, "EDGE position counted")
	t.assert_eq(supply.get("LB", 0), 1, "LB position counted")
	t.assert_eq(supply.get("CB", 0), 1, "CB position counted")
	t.assert_eq(supply.get("S", 0), 1, "S position counted")
	t.assert_eq(supply.get("K", 0), 1, "K position counted")
	t.assert_eq(supply.get("P", 0), 1, "P position counted")

## Test 10: Verify realistic NFL roster scenario
func test_realistic_nfl_scenario(t) -> void:
	# Simulate a simplified NFL with 32 teams, typical position distribution
	# Each team: 2 QBs, 4 RBs, 6 WRs (above replacement)
	var players := []

	for team in range(32):
		# QBs: 1 starter (75+), 1 backup (60-65)
		players.append({"position": "QB", "eval_score": 75.0 + (team % 10)})
		players.append({"position": "QB", "eval_score": 60.0 + (team % 5)})

		# RBs: Mix of starters and backups (all above 62.0 replacement)
		players.append({"position": "RB", "eval_score": 75.0})
		players.append({"position": "RB", "eval_score": 70.0})
		players.append({"position": "RB", "eval_score": 68.0})
		players.append({"position": "RB", "eval_score": 65.0})

		# WRs: Mix of starters and depth (all above 58.0 replacement)
		for i in range(6):
			players.append({"position": "WR", "eval_score": 70.0 + (i * 2)})

	var supply := MarketSupply.compute_position_supply(players)

	# Verify expected counts
	t.assert_eq(supply.get("QB", 0), 64, "NFL QB supply: 32 teams × 2 QBs")
	t.assert_eq(supply.get("RB", 0), 128, "NFL RB supply: 32 teams × 4 RBs")
	t.assert_eq(supply.get("WR", 0), 192, "NFL WR supply: 32 teams × 6 WRs")

## Main test runner
func run(t) -> void:
	test_counts_only_above_replacement(t)
	test_position_grouping(t)
	test_empty_pools(t)
	test_mixed_quality_players(t)
	test_pool_supply_filtering(t)
	test_pool_supply_empty(t)
	test_invalid_player_entries(t)
	test_custom_replacement_levels(t)
	test_all_standard_positions(t)
	test_realistic_nfl_scenario(t)
