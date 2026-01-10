# Task E7: Market Supply Calculator

**Track**: Player Valuation (Track E)
**Dependencies**: E2 (ReplacementLevel) - ✅ Completed
**Status**: Not started
**Estimated Effort**: 0.5 days

## Goal

Implement a market supply calculator that tracks how many players are above replacement level at each position. This feeds into positional scarcity calculations in PlayerValue.

## Implementation

### File to Create

`scripts/core/valuation/MarketSupply.gd`

### Core Logic

```gdscript
class_name MarketSupply

## Compute how many players are above replacement level at each position
## Used for scarcity multiplier calculations in PlayerValue
static func compute_position_supply(
    all_players: Array,
    config: Dictionary = {}
) -> Dictionary:
    var supply: Dictionary = {}

    for player in all_players:
        var position := String(player.get("position", "ATH"))
        var score := float(player.get("eval_score", 0.0))
        var repl := ReplacementLevel.get_replacement_level(position)

        # Only count players above replacement level
        if score > repl:
            supply[position] = supply.get(position, 0) + 1

    return supply

## Compute supply for a specific player pool (e.g., draft-eligible, free agents)
static func compute_pool_supply(
    player_pool: Array,
    min_score: float = 0.0,
    config: Dictionary = {}
) -> Dictionary:
    var filtered := player_pool.filter(func(p):
        return float(p.get("eval_score", 0.0)) >= min_score
    )
    return compute_position_supply(filtered, config)
```

## Usage Example

```gdscript
# Calculate supply across all NFL rosters
var all_nfl_players: Array = []
for team_id in world_state.nfl_rosters.keys():
    all_nfl_players.append_array(world_state.nfl_rosters[team_id])

var supply := MarketSupply.compute_position_supply(all_nfl_players)
# Returns: {"QB": 64, "RB": 120, "WR": 180, ...}

# Use in PlayerValue calculation
var context := {
    "team_roster": team_roster,
    "position_supply": supply
}
var valuation := PlayerValue.calculate(player, context, config, rng)
```

## Test Coverage

**File**: `scripts/tests/test_market_supply.gd`

**Test Cases**:
1. Verify supply counts only players above replacement level
2. Verify correct position grouping
3. Verify empty pools return empty supply dictionary
4. Verify supply calculation with mixed quality players

## Acceptance Criteria

- [ ] `compute_position_supply()` returns accurate counts per position
- [ ] Only players above replacement level are counted
- [ ] Works with empty or null player arrays
- [ ] All tests pass with deterministic data

## Files to Create

- `scripts/core/valuation/MarketSupply.gd`
- `scripts/tests/test_market_supply.gd`

## Files to Reference

- `scripts/core/valuation/ReplacementLevel.gd` - For replacement thresholds

## Integration Points

This calculator is used by:
- **PlayerValue**: Provides position_supply for scarcity calculations
- **ValuationFlow**: Computes supply snapshot during draft_prep phase

## Next Task

After completing E7, proceed to **TASK_E8_wire_valuation_flow.md** to integrate all valuation components into the game loop.
