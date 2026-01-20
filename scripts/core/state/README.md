# State Management Layer

This directory contains the helper layer for player state management, implementing the pure functional architecture defined in `/docs/architecture/PURE_FUNCTIONAL_PLAYER_STATE_ARCHITECTURE.md`.

## Architecture Overview

```
Application Layer (Phases, Handlers)
    ↓ calls
Helper Layer (PlayerStateManager, WorldStateAccessor) ← YOU ARE HERE
    ↓ calls
Pure Function Layer (scripts/core/transformations/) ← TODO: Phase 1
    ↓ uses
Core Models (Player, Contract, etc.)
```

## Files in This Directory

### PlayerStateManager.gd
**Purpose**: Single interface for ALL player state mutations with automatic DataBus notifications.

**Core Contract**:
- Every mutation method MUST call pure functions (when available)
- Updates world_state atomically
- Emits appropriate DataBus signals automatically
- Never mutates input parameters (except world_state itself)

**Key Methods**:
```gdscript
# Advance multiple players by one year
PlayerStateManager.advance_players_one_year(
    world_state,
    ["nfl_rosters", team_id, "players"],
    context,
    configs,
    rng
) -> Dictionary  # {active_count, retired_count, reports}

# Transition a single player to new stage
PlayerStateManager.transition_player_stage(
    world_state,
    player_id,
    from_stage,
    to_stage,
    phase_id
) -> bool  # true if successful

# Update player stats
PlayerStateManager.update_player_stats(
    world_state,
    player_id,
    {"speed": 85, "strength": 78}
) -> Dictionary  # Updated player dict
```

### WorldStateAccessor.gd
**Purpose**: Read-only access to world_state with query helpers.

**Core Contract**:
- Never mutates world_state
- Returns COPIES of data to prevent accidental mutation
- Provides common query patterns
- Performance-conscious (shallow copies where appropriate)

**Key Methods**:
```gdscript
# Get all players at a specific lifecycle stage
WorldStateAccessor.get_players_by_stage(
    world_state,
    Player.PlayerStage.DRAFT_ELIGIBLE
) -> Array  # Array of player dicts (copies)

# Get a specific player by ID
WorldStateAccessor.get_player_by_id(
    world_state,
    "player_123"
) -> Dictionary  # Player dict (copy) or empty if not found

# Get team roster counts
WorldStateAccessor.get_team_roster_counts(
    world_state
) -> Dictionary  # {team_id: {name, roster_count, roster_limit}}

# Get draft pool sorted by rating
WorldStateAccessor.get_draft_eligible_players_sorted(
    world_state
) -> Array  # Sorted by composite_score descending

# Check if player exists
WorldStateAccessor.has_player(world_state, player_id) -> bool

# Get player location metadata
WorldStateAccessor.get_player_location(
    world_state,
    player_id
) -> Dictionary  # {collection_type, team_id, index}

# Get player statistics
WorldStateAccessor.get_player_counts(
    world_state
) -> Dictionary  # {total, by_stage: {...}}
```

## Usage Examples

### Example 1: Advancing Players During Season

```gdscript
# In a phase handler (e.g., NflSeason.gd)
func _run_season_phase(world_state: Dictionary, rng: RandomNumberGenerator) -> void:
    var context := {
        "program_quality": 1.0,
        "usage": 1.0,
        "coaching": 1.0
    }

    var configs := {
        "league": ConfigService.get_config("world/league"),
        "positions": ConfigService.get_config("positions")
    }

    # Advance all players on each team
    var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
    for team_id in nfl_rosters.keys():
        var result := PlayerStateManager.advance_players_one_year(
            world_state,
            ["nfl_rosters", team_id, "players"],
            context,
            configs,
            rng
        )

        print("Team %s: %d active, %d retired" % [
            team_id,
            result.active_count,
            result.retired_count
        ])

    # UI automatically refreshes via DataBus signals!
```

### Example 2: Transitioning Players After Draft

```gdscript
# In draft logic
func _draft_player(world_state: Dictionary, player_id: String, team_id: String) -> bool:
    # Transition from DRAFT_ELIGIBLE to NFL_ROOKIE
    var success := PlayerStateManager.transition_player_stage(
        world_state,
        player_id,
        Player.PlayerStage.DRAFT_ELIGIBLE,
        Player.PlayerStage.NFL_ROOKIE,
        "nfl_draft"
    )

    if success:
        print("Player %s drafted successfully" % player_id)
        # DataBus notification sent automatically
    else:
        push_error("Failed to draft player %s" % player_id)

    return success
```

### Example 3: Querying Players (Read-Only)

```gdscript
# In a UI component
func _refresh_draft_board() -> void:
    var draft_players := WorldStateAccessor.get_draft_eligible_players_sorted(
        GameState.world_state
    )

    # Display top prospects
    for i in range(min(10, draft_players.size())):
        var player: Dictionary = draft_players[i]
        var name := "%s %s" % [player.get("first_name"), player.get("last_name")]
        var score := player.get("composite_score", 0.0)
        print("%d. %s (%.1f)" % [i + 1, name, score])
```

### Example 4: Checking Roster Status

```gdscript
# In roster management logic
func _check_roster_compliance(world_state: Dictionary) -> Dictionary:
    var roster_counts := WorldStateAccessor.get_team_roster_counts(world_state)
    var violations := []

    for team_id in roster_counts.keys():
        var info: Dictionary = roster_counts[team_id]
        if info.roster_count > info.roster_limit:
            violations.append({
                "team_id": team_id,
                "team_name": info.name,
                "count": info.roster_count,
                "limit": info.roster_limit,
                "overage": info.roster_count - info.roster_limit
            })

    return {
        "compliant": violations.is_empty(),
        "violations": violations
    }
```

## Implementation Status

### Completed
- ✅ PlayerStateManager core structure
- ✅ WorldStateAccessor core structure
- ✅ DataBus integration (automatic notifications)
- ✅ PlayerLifecycleStateMachine integration (transition validation)
- ✅ Collection navigation helpers
- ✅ Placeholder for pure functions (will be replaced in Phase 1)

### TODO: Phase 1 (Pure Function Layer)
The following pure function modules need to be created in `scripts/core/transformations/`:

1. **StagePipeline.gd** - Compose lifecycle transformations
   - `advance_one_year(player, context, configs, rng) -> {player, retired, report}`
   - `transition_stage(player, to_stage) -> player`

2. **GrowthFunctions.gd** - Stat development (pure)
   - `apply_development(player, context, configs, rng) -> {player, report}`
   - `compute_stat_changes(player, phase, context, configs, rng) -> stat_changes`

3. **AgeFunctions.gd** - Age-related transforms (pure)
   - `increment_age(player) -> player`
   - `calculate_age_multiplier(age, position) -> float`

4. **RetirementFunctions.gd** - Retirement checks (pure)
   - `should_retire(player, configs, rng) -> bool`
   - `calculate_retirement_probability(player, context) -> float`

5. **TransitionFunctions.gd** - Stage transitions (pure)
   - `transition_stage(player, to_stage) -> player`
   - `validate_transition(player, to_stage) -> bool`

6. **StatFunctions.gd** - Stat manipulation (pure)
   - `apply_stat_changes(player, stat_changes) -> player`
   - `clamp_stats(player, min_val, max_val) -> player`

Once these are implemented, replace the placeholder functions in PlayerStateManager.

## Testing

### Unit Tests
Create tests in `tests/core/state/`:

```gdscript
# test_player_state_manager.gd
func test_advance_players_updates_world_state():
    var world_state := _create_test_world_state()
    var result := PlayerStateManager.advance_players_one_year(...)
    assert_eq(result.active_count, 2)

func test_advance_players_emits_databus_signal():
    # Setup signal spy
    var signal_emitted := false
    DataBus.collection_changed.connect(func(_c, _op): signal_emitted = true)

    PlayerStateManager.advance_players_one_year(...)
    assert_true(signal_emitted)
```

### Integration Tests
Verify end-to-end flow with actual phase handlers.

## Design Principles

### 1. Single Source of Truth
ALL player state mutations flow through PlayerStateManager. No direct world_state mutations allowed.

### 2. Unidirectional Data Flow
```
Event → Helper → Pure Function → New State → DataBus → UI
```

### 3. Immutability
- Input parameters are never mutated (except world_state)
- Pure functions return NEW data structures
- WorldStateAccessor returns COPIES to prevent accidental mutation

### 4. Determinism
- All randomness comes from explicit RNG parameter
- Same seed = same results (always)
- No hidden state or global variables

### 5. Traceability
- Every state change logs verbose output (optional)
- DataBus notifications provide audit trail
- Summary results returned for logging

## DataBus Integration

PlayerStateManager automatically emits these signals:

- `collection_changed(collection_name, operation)` - After bulk updates
- `players_changed(stage, count)` - After stage transitions

UI components can subscribe to these signals for reactive updates:

```gdscript
func _ready():
    DataBus.collection_changed.connect(_on_collection_changed)
    DataBus.players_changed.connect(_on_players_changed)

func _on_collection_changed(collection: String, op: String):
    if collection == "nfl_rosters":
        _refresh_roster_display()
```

## Performance Considerations

### Deep Copying
- PlayerStateManager uses `duplicate(true)` for immutability
- WorldStateAccessor uses `duplicate(true)` for safety
- Future optimization: selective copying (only modified fields)

### Collection Iteration
- Both classes iterate through collections linearly
- Performance: O(n) for searches, acceptable for typical roster sizes
- Future optimization: index by player_id for O(1) lookups

### Signal Overhead
- DataBus signals are emitted after bulk operations (not per-player)
- UI updates are batched automatically by Godot's signal system
- No noticeable performance impact

## Migration Path

### Current State (Phase 0)
- ✅ Helper layer implemented with placeholders
- ⏳ Pure function layer pending (Phase 1)
- ⏳ Phase handlers need refactoring (Phase 2-3)

### Phase 1: Pure Functions
Create transformation functions in `scripts/core/transformations/`

### Phase 2: Pilot Migration
Refactor one phase handler to use PlayerStateManager

### Phase 3: Full Migration
Migrate all phase handlers to use helper layer

### Phase 4: Model Cleanup
Remove mutation methods from Player.gd

## Related Documentation

- `/docs/architecture/PURE_FUNCTIONAL_PLAYER_STATE_ARCHITECTURE.md` - Architecture design
- `/autoloads/DataBus.gd` - Event notification system
- `/scripts/world/PlayerLifecycleStateMachine.gd` - Stage transition validation
- `/scripts/core/models/Player.gd` - Player data model

## Questions?

Contact the Architecture Guardian or refer to the design document for detailed rationale and examples.
