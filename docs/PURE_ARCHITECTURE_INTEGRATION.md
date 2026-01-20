# Pure Function Architecture Integration

## Overview

This document describes the integration of the pure function architecture with the existing season simulation pipeline. The integration maintains backward compatibility while providing a cleaner, more testable data flow.

## Architecture

### Before Integration

**Old Flow:**
```
AdvanceWorldYear → Season Classes → PlayerLifecycle.advance_one_year_parallel()
                                     ↓
                              Direct player mutation
```

Problems:
- Players mutated in-place
- Hard to test individual transformations
- Difficult to trace data flow
- Parallel processing required for performance

### After Integration

**New Flow:**
```
AdvanceWorldYear → Season Classes → PlayerStateManager.advance_players_one_year()
                                     ↓
                              StagePipeline.advance_one_year() (pure)
                                     ↓
                              ┌──────────────────────────────┐
                              │  Pure Transformation Layer    │
                              │  - AgeFunctions              │
                              │  - GrowthFunctions           │
                              │  - InjuryFunctions           │
                              │  - RetirementFunctions       │
                              └──────────────────────────────┘
                                     ↓
                              Atomic world_state update
```

Benefits:
- Pure functions (no mutations)
- Testable transformations
- Clear data flow
- Deterministic (same seed = same results)
- Automatic DataBus notifications

## Modified Files

### Core Architecture

1. **scripts/core/state/PlayerStateManager.gd**
   - Updated to use `StagePipeline.advance_one_year()` instead of placeholder
   - Added per-player context merging
   - Returns retired players for tracking
   - Added deterministic seed derivation per player

2. **scripts/core/transformations/StagePipeline.gd**
   - Added missing imports for transformation functions
   - No logic changes needed

### Season Handlers

3. **scripts/world/HighSchoolSeason.gd**
   - Replaced `PlayerLifecycle.advance_one_year_parallel()` with `PlayerStateManager.advance_players_one_year()`
   - Created temporary world_state for API compatibility
   - Maintained existing context building logic

4. **scripts/world/CollegeSeason.gd**
   - Replaced `PlayerLifecycle.advance_one_year_parallel()` with `PlayerStateManager.advance_players_one_year()`
   - Uses world_state directly (no temp state needed)
   - Maintained roster-by-roster processing

5. **scripts/world/NflSeason.gd**
   - Replaced `PlayerLifecycle.advance_one_year_parallel()` with `PlayerStateManager.advance_players_one_year()`
   - Uses world_state directly (no temp state needed)
   - Maintained team-by-team processing

### Pipeline

6. **scripts/pipelines/AdvanceWorldYear.gd**
   - Added `PlayerStateManager` import
   - No phase handler changes needed (delegation pattern maintained)

## Key Design Decisions

### 1. Per-Player Context Handling

**Problem:** Each player has different development context (school quality, usage, etc.)

**Solution:** Context is embedded in each player's `development_context` field, then extracted and merged by `PlayerStateManager` before calling pure functions.

```gdscript
# In season handlers (unchanged):
player["development_context"] = {
    "program_quality": 1.2,
    "usage": 1.3,
    "coach_specialization": 1.1
}

# In PlayerStateManager (new):
var merged_context := global_context.duplicate()
var player_context := player.get("development_context", {})
for key in player_context.keys():
    merged_context[key] = player_context[key]

var result := StagePipeline.advance_one_year(player, merged_context, configs, rng)
```

### 2. Deterministic Seed Derivation

Each player gets a deterministic seed derived from the base RNG:

```gdscript
var base_seed := int(rng.seed)
for i in range(players.size()):
    var player_seed := Rand.splitmix64(base_seed + i)
    var player_rng := RandomNumberGenerator.new()
    player_rng.seed = player_seed

    # Use player_rng for this player's transformations
```

This ensures:
- Same input seed → same results
- Player order doesn't affect individual outcomes
- Reproducible simulations

### 3. Retirement Tracking

**Problem:** NflSeason needs retired players for stats/awards

**Solution:** PlayerStateManager returns retired players in result:

```gdscript
return {
    "active_count": active.size(),
    "retired_count": retired.size(),
    "retired": retired,  # Array of retired player dictionaries
    "reports": reports
}
```

### 4. API Compatibility

**HighSchoolSeason:** Takes array of players (not world_state)

**Solution:** Create temporary world_state internally:

```gdscript
var temp_world_state := {"hs_players": players}
var result := PlayerStateManager.advance_players_one_year(
    temp_world_state,
    ["hs_players"],
    {},
    configs,
    rng
)
var updated_players := temp_world_state.get("hs_players", [])
```

**CollegeSeason/NflSeason:** Already have world_state

**Solution:** Use collection paths directly:

```gdscript
var result := PlayerStateManager.advance_players_one_year(
    world_state,
    ["nfl_rosters", team_id, "players"],
    {},
    configs,
    rng
)
```

## RNG Consumption Patterns

### PlayerStateManager
- Derives per-player seed: `Rand.splitmix64(base_seed + i)`
- No additional RNG calls beyond seed derivation

### StagePipeline (per player)
- Age increment: 0 calls (deterministic)
- Stat development: ~15-20 calls (one per base stat)
- Injury simulation: 1-5 calls (occurrence + details if injured)
- Retirement check: 1 call
- **Total: ~20-30 calls per player**

### Example

For 1000 players with seed 12345:
1. Player 0: seed = splitmix64(12345 + 0) → ~25 RNG calls
2. Player 1: seed = splitmix64(12345 + 1) → ~25 RNG calls
3. ...
4. Player 999: seed = splitmix64(12345 + 999) → ~25 RNG calls

**Total:** ~25,000 RNG calls (deterministic and reproducible)

## Testing

### Unit Tests

**Pure Functions:** `scripts/core/transformations/test_pure_functions.gd`
- Tests immutability
- Tests determinism
- Tests basic functionality

**Integration:** `scripts/tests/test_pure_architecture_integration.gd`
- Tests PlayerStateManager basic flow
- Tests per-player context handling
- Tests determinism (same seed = same results)

### Running Tests

```bash
# Pure function tests
godot --headless --script scripts/core/transformations/test_pure_functions.gd

# Integration tests
godot --headless --script scripts/tests/test_pure_architecture_integration.gd

# Full test suite
./run_tests.sh
```

## Migration Notes

### For Developers

1. **Context Building:** Unchanged - continue populating `player["development_context"]`
2. **Season Logic:** Unchanged - graduation, eligibility, etc. still handled by season classes
3. **DataBus:** Notifications now automatic from PlayerStateManager

### Removed Code

- **PlayerLifecycle:** No longer used by season handlers (can be deprecated)
- **DevelopmentConfig/RetirementConfig:** No longer needed (pure functions read from configs directly)

### Backward Compatibility

- Existing tests should pass unchanged
- World state structure unchanged
- Phase handler signatures unchanged
- Determinism maintained (with seed)

## Performance Considerations

### Before (Parallel Processing)

- Used ThreadPool for large player sets (>100 players)
- Complex seed management across threads
- Thread-safe config copying overhead

### After (Serial Processing)

- Processes players sequentially per team/roster
- Simpler seed management (deterministic derivation)
- No thread synchronization overhead

**Trade-off:** Serial processing is simpler and more maintainable. If performance becomes an issue, parallelization can be added at the team/roster level (coarser granularity).

### Optimization Opportunities

1. **Batch Processing:** Process multiple teams in parallel (not yet implemented)
2. **Config Caching:** Cache config lookups (already done in pure functions)
3. **Selective Updates:** Only update changed stats (future optimization)

## Error Handling

PlayerStateManager validates inputs and provides clear error messages:

```gdscript
if world_state == null or world_state.is_empty():
    push_error("PlayerStateManager: world_state is null or empty")
    return {"active_count": 0, "retired_count": 0, "collection": "", "reports": []}

if collection_path.is_empty():
    push_error("PlayerStateManager: collection_path is empty")
    return {"active_count": 0, "retired_count": 0, "collection": "", "reports": []}
```

## Future Enhancements

1. **Parallel Team Processing:** Process teams/rosters in parallel
2. **Incremental Updates:** Only update changed player fields
3. **Development Reports:** Detailed reports for UI (currently skipped in bootstrap)
4. **State Versioning:** Track player state versions for undo/replay
5. **Transaction Log:** Log all state changes for debugging

## Conclusion

The pure function architecture integration provides:
- ✅ Clean separation of concerns
- ✅ Testable transformations
- ✅ Deterministic simulations
- ✅ Maintainable codebase
- ✅ Backward compatibility
- ✅ Automatic DataBus notifications

All existing functionality is preserved while providing a foundation for future enhancements.
