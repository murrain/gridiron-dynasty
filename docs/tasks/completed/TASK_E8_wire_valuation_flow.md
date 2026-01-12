# Task E8: Wire Valuation into ValuationFlow

**Track**: Player Valuation (Track E)
**Dependencies**: E5 (PlayerValue), E6 (ContractValuation), E7 (MarketSupply) - Must be completed first
**Status**: Not started
**Estimated Effort**: 1-2 days

## Goal

Replace the stub implementation in `ValuationFlow.gd` with actual valuation logic that integrates all Track E components into the game loop.

## Current State

`scripts/world/ValuationFlow.gd` is currently a **scaffold stub**:
```gdscript
return {
    "valuation_stub": true,
    "note": "Valuation scaffolding only; no RNG consumed beyond seeding."
}
```

## Implementation

### File to Modify

`scripts/world/ValuationFlow.gd`

### New Logic Flow

```gdscript
static func run(
    world_state: Dictionary,
    year: int,
    phase_id: String,
    seed: int
) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(seed)

    var config := Config.get_config("valuation")

    # STEP 1: Compute market supply (for scarcity)
    var all_nfl_players := _gather_all_nfl_players(world_state)
    var position_supply := MarketSupply.compute_position_supply(all_nfl_players, config)

    # STEP 2: Valuate free agents entering market
    var free_agents: Array = world_state.get("free_agents", {}).get(year, [])
    var fa_valuations: Array = []

    for player in free_agents:
        var context := {"position_supply": position_supply}
        var valuation := PlayerValue.calculate(player, context, config, rng)
        fa_valuations.append(valuation)

        # Store valuation on player for signing decisions
        player["valuation"] = valuation

    # STEP 3: Valuate each team's roster (for retention decisions)
    var team_valuations: Dictionary = {}

    for team_id in world_state.get("nfl_rosters", {}).keys():
        var roster: Array = world_state.nfl_rosters[team_id]
        var team_vals: Array = []

        for player in roster:
            var context := {
                "team_roster": roster,
                "position_supply": position_supply
            }
            var valuation := PlayerValue.calculate(player, context, config, rng)
            team_vals.append(valuation)

            # Store both market and team value
            player["market_value"] = valuation.market_value
            player["team_value"] = valuation.team_value

        team_valuations[team_id] = team_vals

    return {
        "phase_id": phase_id,
        "year": year,
        "seed": seed,
        "position_supply": position_supply,
        "free_agent_count": free_agents.size(),
        "teams_valuated": team_valuations.size(),
        "data_flow": [
            "market_supply_calculated",
            "free_agents_valuated",
            "team_rosters_valuated"
        ]
    }

static func _gather_all_nfl_players(world_state: Dictionary) -> Array:
    var all_players: Array = []
    for team_id in world_state.get("nfl_rosters", {}).keys():
        all_players.append_array(world_state.nfl_rosters[team_id])
    return all_players
```

## Integration Points

ValuationFlow is called from `AdvanceWorldYear.gd` during the `draft_prep` phase:
```gdscript
# In AdvanceWorldYear._handle_draft_prep()
var valuation_result := ValuationFlow.run(world_state, year, phase.phase_id, step_seed)
```

The valuation data stored on players is then used by:
- **Free agency signing decisions** (future task)
- **Retention/cut decisions** (future task)
- **Trade value calculations** (existing TradeValuation.gd)

## Test Coverage

**File**: `scripts/tests/test_valuation_flow.gd` (update existing)

**Test Cases**:
1. Verify position_supply is calculated correctly
2. Verify all free agents receive valuations
3. Verify team rosters receive both market and team values
4. Verify team_value > market_value for players with no backup
5. Assert determinism with fixed seeds

## Acceptance Criteria

- [ ] ValuationFlow.run() no longer returns stub data
- [ ] position_supply calculated from all NFL rosters
- [ ] Free agents have `valuation` field stored
- [ ] Team roster players have `market_value` and `team_value` fields
- [ ] All tests pass with deterministic seeds
- [ ] No RNG usage beyond explicit seeding

## Files to Modify

- `scripts/world/ValuationFlow.gd`

## Files to Reference

- `scripts/core/valuation/PlayerValue.gd` - For player valuation
- `scripts/core/valuation/MarketSupply.gd` - For supply calculation
- `scripts/pipelines/AdvanceWorldYear.gd` - For phase integration

## Next Task

After completing E8, proceed to **TASK_E9_valuation_configs.md** to consolidate and document all valuation configuration values.
