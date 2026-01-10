# Task E10: Comprehensive Valuation Test Suite

**Track**: Player Valuation (Track E)
**Dependencies**: E1-E9 (entire valuation system) - Should be completed last
**Status**: Not started
**Estimated Effort**: 2 days

## Goal

Add comprehensive end-to-end test coverage for the complete valuation system, ensuring all edge cases are handled and the system behaves correctly under various scenarios.

## Test Files Status

**Existing** (already created with E1-E4):
- ✅ `test_value_curve.gd` - Tests non-linear curve
- ✅ `test_replacement_level.gd` - Tests VOR calculation
- ✅ `test_positional_scarcity.gd` - Tests scarcity multiplier
- ✅ `test_team_impact.gd` - Tests depth premium

**To Create**:
- `test_player_value.gd` - Tests unified calculator (E5)
- `test_market_supply.gd` - Tests supply tracking (E7)
- `test_valuation_integration.gd` - End-to-end integration tests
- `test_valuation_edge_cases.gd` - Edge cases and error handling

## New Test Files

### 1. test_player_value.gd

**Purpose**: Test the unified PlayerValue calculator

**Key Test Cases**:
```gdscript
func _test_basic_valuation(t):
    # Verify PlayerValue.calculate returns complete dictionary
    var player := _create_test_player(75.0, "WR", 25)
    var context := {}
    var config := Config.get_config("valuation")
    var rng := _create_rng(42)

    var result := PlayerValue.calculate(player, context, config, rng)

    t.assert_true(result.has("market_value"))
    t.assert_true(result.has("team_value"))
    t.assert_true(result.has("vor"))
    t.assert_true(result.has("components"))

func _test_elite_premium(t):
    # Elite players should be worth 5-10x average players
    var average_player := _create_test_player(75.0, "QB", 26)
    var elite_player := _create_test_player(95.0, "QB", 26)

    var avg_val := PlayerValue.calculate(average_player, {}, config, rng)
    var elite_val := PlayerValue.calculate(elite_player, {}, config, rng)

    var premium := elite_val.market_value / avg_val.market_value
    t.assert_true(premium >= 5.0, "Elite premium too low: %.2f" % premium)
    t.assert_true(premium <= 10.0, "Elite premium too high: %.2f" % premium)

func _test_team_premium_no_backup(t):
    # Player with no backup should have team_value > market_value
    var player := _create_test_player(80.0, "QB", 26)
    var roster := [player]  # Only QB on roster
    var context := {"team_roster": roster}

    var result := PlayerValue.calculate(player, context, config, rng)

    t.assert_true(result.team_value > result.market_value,
        "No backup should increase team value")
    t.assert_true(result.team_premium > 0.0,
        "Team premium should be positive")

func _test_determinism(t):
    # Same inputs should produce same outputs
    var player := _create_test_player(82.0, "WR", 24)
    var rng1 := _create_rng(12345)
    var rng2 := _create_rng(12345)

    var result1 := PlayerValue.calculate(player, {}, config, rng1)
    var result2 := PlayerValue.calculate(player, {}, config, rng2)

    t.assert_eq(result1.market_value, result2.market_value)
    t.assert_eq(result1.team_value, result2.team_value)
```

### 2. test_market_supply.gd

**Purpose**: Test market supply calculation

**Key Test Cases**:
```gdscript
func _test_supply_above_replacement(t):
    # Only players above replacement level should count
    var players := [
        _create_test_player(70.0, "QB", 25),  # Above replacement (55)
        _create_test_player(50.0, "QB", 26),  # Below replacement
        _create_test_player(60.0, "QB", 24),  # Above replacement
    ]

    var supply := MarketSupply.compute_position_supply(players)

    t.assert_eq(supply.get("QB", 0), 2, "Should count 2 QBs above replacement")

func _test_supply_by_position(t):
    # Verify correct position grouping
    var players := [
        _create_test_player(75.0, "QB", 25),
        _create_test_player(75.0, "WR", 24),
        _create_test_player(75.0, "WR", 26),
    ]

    var supply := MarketSupply.compute_position_supply(players)

    t.assert_eq(supply.get("QB", 0), 1)
    t.assert_eq(supply.get("WR", 0), 2)

func _test_empty_pool(t):
    # Empty pool should return empty dictionary
    var supply := MarketSupply.compute_position_supply([])
    t.assert_true(supply.is_empty())
```

### 3. test_valuation_integration.gd

**Purpose**: End-to-end integration tests

**Key Test Cases**:
```gdscript
func _test_valuation_flow_integration(t):
    # Test complete ValuationFlow.run() with real world_state
    var world_state := _create_test_world_state()
    var result := ValuationFlow.run(world_state, 2025, "draft_prep", 42)

    t.assert_true(result.has("position_supply"))
    t.assert_true(result.free_agent_count >= 0)
    t.assert_true(result.teams_valuated >= 0)

func _test_contract_valuation_integration(t):
    # Test ContractValuation uses PlayerValue correctly
    var player := _create_test_player(85.0, "EDGE", 27)
    var config := Config.get_config("contract_valuation")
    var rng := _create_rng(42)

    var contract := ContractValuation.estimate_value(player, config, rng)

    t.assert_true(contract.has("market_value"))
    t.assert_true(contract.has("apy"))
    t.assert_true(contract.apy > 0.0)

func _test_full_pipeline(t):
    # Test valuation through complete pipeline
    # 1. Generate players
    # 2. Calculate supply
    # 3. Valuate each player
    # 4. Verify consistency
    var players := _generate_test_roster(53)
    var supply := MarketSupply.compute_position_supply(players)

    for player in players:
        var context := {
            "team_roster": players,
            "position_supply": supply
        }
        var valuation := PlayerValue.calculate(player, context, config, rng)

        # Verify all components present
        t.assert_true(valuation.market_value > 0.0)
        t.assert_true(valuation.has("components"))
```

### 4. test_valuation_edge_cases.gd

**Purpose**: Test error handling and edge cases

**Key Test Cases**:
```gdscript
func _test_below_replacement_player(t):
    # Below-replacement player should have 0 VOR but still have value
    var player := _create_test_player(40.0, "RB", 25)  # Below RB replacement (62)
    var result := PlayerValue.calculate(player, {}, config, rng)

    t.assert_eq(result.vor, 0.0, "Below replacement should have 0 VOR")
    t.assert_true(result.market_value > 0.0, "Should still have minimum value")

func _test_invalid_position(t):
    # Unknown position should use default replacement level
    var player := _create_test_player(70.0, "UNKNOWN", 25)
    var result := PlayerValue.calculate(player, {}, config, rng)

    t.assert_true(result.market_value > 0.0, "Should handle unknown position")

func _test_extreme_age(t):
    # Very young and very old players
    var young := _create_test_player(75.0, "QB", 20)
    var old := _create_test_player(75.0, "QB", 38)

    var young_val := PlayerValue.calculate(young, {}, config, rng)
    var old_val := PlayerValue.calculate(old, {}, config, rng)

    t.assert_true(old_val.market_value < young_val.market_value,
        "Old player should be worth less")

func _test_scarcity_extremes(t):
    # Test with zero supply and oversupply
    var player := _create_test_player(80.0, "QB", 26)

    # No supply (very scarce)
    var context_scarce := {"position_supply": {"QB": 1}}
    var result_scarce := PlayerValue.calculate(player, context_scarce, config, rng)

    # Oversupply (abundant)
    var context_abundant := {"position_supply": {"QB": 500}}
    var result_abundant := PlayerValue.calculate(player, context_abundant, config, rng)

    t.assert_true(result_scarce.market_value > result_abundant.market_value,
        "Scarce positions should command premium")

func _test_missing_config_fields(t):
    # Test with incomplete config (should use defaults)
    var player := _create_test_player(75.0, "WR", 25)
    var minimal_config := {"value_curve": {}}

    var result := PlayerValue.calculate(player, {}, minimal_config, rng)

    t.assert_true(result.has("market_value"), "Should handle minimal config")
```

## Performance Tests

Add performance benchmarks for large-scale valuation:

```gdscript
func _test_valuation_performance(t):
    # Valuate 1696 players (full NFL rosters)
    var players := _generate_test_roster(1696)
    var supply := MarketSupply.compute_position_supply(players)

    var start := Time.get_ticks_msec()

    for player in players:
        var context := {"position_supply": supply}
        var _result := PlayerValue.calculate(player, context, config, rng)

    var elapsed := Time.get_ticks_msec() - start

    # Should complete in reasonable time (< 1 second)
    t.assert_true(elapsed < 1000, "Valuation too slow: %d ms" % elapsed)
```

## Acceptance Criteria

- [ ] All 4 new test files created
- [ ] All edge cases covered (below replacement, unknown position, extreme ages)
- [ ] Integration tests verify complete pipeline
- [ ] Performance tests ensure reasonable speed
- [ ] All tests pass with deterministic seeds
- [ ] Test coverage > 90% for valuation modules

## Files to Create

- `scripts/tests/test_player_value.gd`
- `scripts/tests/test_market_supply.gd`
- `scripts/tests/test_valuation_integration.gd`
- `scripts/tests/test_valuation_edge_cases.gd`

## Files to Update

- `scripts/tests/TestRunner.gd` - Add new tests to suite
- `scripts/tests/TestRunnerFast.gd` - Add fast tests (not integration tests)

## Next Steps

After completing E10:
1. Run full test suite to verify all valuation tests pass
2. Update TestRunner.gd to include all new tests
3. Document valuation system in architecture docs
4. Consider Track E complete ✅
