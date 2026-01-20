# Season State Management Architecture

## Overview

This document describes the Season State Management layer, which implements pure functional architecture for all season-related state mutations following the patterns established in PR #155.

## Implementation Date

2026-01-20

## Architecture Components

### 1. SeasonStateMachine (`scripts/core/state/SeasonStateMachine.gd`)

**Purpose**: Formal state machine defining valid season phase transitions.

**Key Features**:
- Defines 8 season phases: PRE_SEASON, REGULAR_SEASON, PLAYOFFS, POST_SEASON, OFF_SEASON, DRAFT_PREP, DRAFT, FREE_AGENCY
- Validates all phase transitions before they occur
- Provides helper methods for phase queries (is_active_season, is_off_season, etc.)
- Single source of truth for season lifecycle rules

**API**:
```gdscript
# Validate transition
if SeasonStateMachine.can_transition(from, to):
    # Perform transition

# Get valid next phases
var next_phases = SeasonStateMachine.get_valid_transitions(current_phase)

# Get phase name for logging
var phase_name = SeasonStateMachine.get_phase_name(phase)
```

**Valid Transitions**:
- PRE_SEASON → REGULAR_SEASON
- REGULAR_SEASON → PLAYOFFS or POST_SEASON
- PLAYOFFS → POST_SEASON
- POST_SEASON → OFF_SEASON
- OFF_SEASON → DRAFT_PREP or FREE_AGENCY
- DRAFT_PREP → DRAFT
- DRAFT → FREE_AGENCY or PRE_SEASON
- FREE_AGENCY → PRE_SEASON

### 2. SeasonTransformations (`scripts/core/transformations/SeasonTransformations.gd`)

**Purpose**: Pure transformation functions for season-related state changes.

**Critical Contract**: ALL functions are PURE - they never modify input dictionaries. They always return NEW dictionaries.

**Key Functions**:

#### `apply_game_result(standings, game_result) -> Dictionary`
- **RNG Consumption**: NONE (deterministic)
- **Purpose**: Apply single game result to standings
- **Returns**: NEW standings dictionary with updated records
- Updates win/loss/tie records, points for/against, win percentage

#### `apply_game_results(standings, game_results) -> Dictionary`
- **RNG Consumption**: NONE
- **Purpose**: Batch apply multiple game results
- **Returns**: NEW standings with all results applied

#### `prepare_roster(roster, configs) -> Dictionary`
- **RNG Consumption**: NONE
- **Purpose**: Prepare roster for season simulation
- **Returns**: NEW roster with simulation-ready player data
- Adds injury_status, stamina, morale fields
- Calculates overall ratings

#### `calculate_playoff_seeding(standings, playoff_config, rng) -> Dictionary`
- **RNG Consumption**: 1 call per tied pair (only if random tiebreaker needed)
- **Purpose**: Calculate playoff bracket from final standings
- **Returns**: Dictionary with seeds and matchups arrays

#### `transition_to_draft_eligible(players, eligibility_rules, rng) -> Dictionary`
- **RNG Consumption**: 1 call per player (for opt-in decisions)
- **Purpose**: Determine which college players enter draft
- **Returns**: Dictionary with "eligible" and "remaining" arrays
- Handles automatic eligibility (seniors) and early opt-ins

**Immutability Pattern**:
```gdscript
# All functions use this pattern:
static func transform(input: Dictionary) -> Dictionary:
    var new_dict := input.duplicate(true)  # Deep copy
    # Modify new_dict...
    return new_dict  # Original unchanged
```

### 3. SeasonStateManager (`scripts/core/state/SeasonStateManager.gd`)

**Purpose**: Single interface for all season state mutations with DataBus integration.

**Critical Contract**: ALL season state mutations MUST flow through this manager.

**Core Responsibilities**:
1. Validate inputs at boundaries
2. Call pure transformation functions
3. Update world_state atomically
4. Emit DataBus notifications automatically
5. Provide logging/audit trail

**Key Methods**:

#### `record_game_result(world_state, standings_path, game_result) -> Dictionary`
- **Purpose**: Record single game outcome and update standings
- **Side Effects**: Mutates world_state, emits DataBus.collection_changed
- **Returns**: Summary with success flag, winner, scores

#### `record_game_results(world_state, standings_path, game_results) -> Dictionary`
- **Purpose**: Batch record multiple game outcomes
- **Side Effects**: Mutates world_state, emits DataBus.collection_changed

#### `advance_season_phase(world_state, season_state_path, from_phase, to_phase) -> bool`
- **Purpose**: Transition season to next phase with validation
- **Side Effects**: Mutates world_state, emits DataBus.phase_completed
- **Validates**: Transition is legal and from_phase matches current

#### `update_roster_for_season(world_state, roster_path, configs) -> Dictionary`
- **Purpose**: Prepare team roster for season simulation
- **Side Effects**: Mutates world_state, emits DataBus.collection_changed
- **Returns**: Summary with player count and team ID

#### `process_draft_eligibility(world_state, players_path, eligibility_rules, rng) -> Dictionary`
- **Purpose**: Determine draft eligibility for college players
- **Side Effects**: Mutates world_state, moves eligible players to draft_pool
- **RNG Consumption**: 1 call per player
- **Returns**: Summary with eligible_count, remaining_count, eligible_players array

**Usage Pattern**:
```gdscript
# Record game result
var result := SeasonStateManager.record_game_result(
    world_state,
    ["nfl_standings", 2033],
    {
        "home_team_id": "SF",
        "away_team_id": "SEA",
        "home_score": 28,
        "away_score": 21,
        "week": 1
    }
)

# Advance season phase
var success := SeasonStateManager.advance_season_phase(
    world_state,
    ["nfl_season_state"],
    SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
    SeasonStateMachine.SeasonPhase.PLAYOFFS
)
```

### 4. SeasonStateManagerTest (`tests/core/state/SeasonStateManagerTest.gd`)

**Purpose**: Comprehensive test suite ensuring correctness and determinism.

**Test Categories**:

1. **Game Result Tests**:
   - Updates standings correctly
   - Handles ties
   - Batch processing
   - Immutability verification

2. **Season Phase Transition Tests**:
   - Valid transitions succeed
   - Invalid transitions fail
   - Current phase validation

3. **Roster Preparation Tests**:
   - Players prepared with simulation fields
   - Immutability verification

4. **Draft Eligibility Tests**:
   - Senior auto-eligibility
   - Determinism (same seed = same results)
   - Immutability verification

5. **Error Handling Tests**:
   - Input validation for all methods
   - Graceful failure handling

**Running Tests**:
```bash
godot --headless --script addons/gut/gut_cmdln.gd -gtest=tests/core/state/SeasonStateManagerTest.gd
```

## Design Principles

### 1. Immutability

**Rule**: Pure transformation functions NEVER modify inputs.

**Implementation**:
```gdscript
# CORRECT: Create new dictionary
static func transform(input: Dictionary) -> Dictionary:
    var result := input.duplicate(true)
    result["new_field"] = value
    return result

# WRONG: Modify input
static func transform(input: Dictionary) -> Dictionary:
    input["new_field"] = value  # NEVER DO THIS!
    return input
```

**Testing**:
```gdscript
func test_immutability() -> void:
    var original := {"wins": 5}
    var result := apply_game_result(original, game)
    assert_eq(original["wins"], 5, "Input unchanged")
```

### 2. Determinism

**Rule**: Identical RNG seeds MUST produce identical results.

**Implementation**:
- Always pass RNG as explicit parameter
- Never use Math.random() or global random state
- Document RNG consumption in comments

**Testing**:
```gdscript
func test_determinism() -> void:
    var rng1 := RandomNumberGenerator.new()
    rng1.seed = 12345
    var rng2 := RandomNumberGenerator.new()
    rng2.seed = 12345

    var result1 := process_draft_eligibility(players, rules, rng1)
    var result2 := process_draft_eligibility(players, rules, rng2)

    assert_eq(result1["eligible_count"], result2["eligible_count"])
```

### 3. DataBus Integration

**Rule**: All state mutations automatically emit DataBus signals.

**Implementation**:
```gdscript
# Manager emits signals automatically
static func record_game_result(...) -> Dictionary:
    # ... update world_state ...
    _notify_collection_changed("standings", "update")
    return result
```

**UI Pattern**:
```gdscript
# UI components subscribe to DataBus
func _ready() -> void:
    DataBus.collection_changed.connect(_on_standings_changed)

func _on_standings_changed(collection: String, operation: String) -> void:
    if collection == "standings":
        _refresh_standings_display()
```

### 4. Atomic Updates

**Rule**: world_state updates are all-or-nothing.

**Implementation**:
- Extract value from world_state
- Transform value with pure function
- Replace value in world_state (single mutation point)
- Emit notification

```gdscript
# Pattern
var current := _extract_value(world_state, path)
var updated := pure_transform(current)
_replace_value(world_state, path, updated)
_notify_collection_changed(collection, operation)
```

## Integration with Existing Code

### Current Mutations (Will Eventually Use Manager)

These files currently mutate season-related state directly:

1. **`scripts/world/NflSeason.gd:108-110`**
   - Direct roster mutation: `roster["players"] = prepared_players`
   - Should use: `SeasonStateManager.update_roster_for_season()`

2. **`scripts/world/CollegeSeason.gd:99-100, 172-176`**
   - Direct roster updates and draft_eligible appends
   - Should use: `SeasonStateManager.update_roster_for_season()` and `process_draft_eligibility()`

3. **`scripts/world/HighSchoolSeason.gd:76-89`**
   - Direct player property mutations
   - Should use: `SeasonStateManager` methods (TBD for high school specific logic)

**Note**: These files are NOT refactored yet. This is Phase 1 - infrastructure creation only.

## Future Work

### Phase 2: Refactor Season Files
- Replace direct mutations in NflSeason.gd with SeasonStateManager calls
- Replace direct mutations in CollegeSeason.gd with SeasonStateManager calls
- Replace direct mutations in HighSchoolSeason.gd with SeasonStateManager calls

### Phase 3: Additional Transformations
- Add `update_team_stats()` for post-game team statistics
- Add `calculate_season_awards()` for MVP, DPOY, etc.
- Add `generate_season_summary()` for historical records

### Phase 4: Enhanced State Machine
- Add state machine for game phases (pre-game, quarters, overtime, post-game)
- Add state machine for draft phases (combine, pro day, draft day)
- Integrate with existing PlayerLifecycleStateMachine

### Phase 5: Performance Optimization
- Profile transformation functions for performance
- Consider batch processing optimizations
- Evaluate memory usage for large season simulations

## Benefits of This Architecture

1. **Testability**: All logic is unit-testable with predictable inputs/outputs
2. **Debuggability**: Clear audit trail via logging and DataBus signals
3. **Maintainability**: Separation of concerns (state machine, transformations, manager)
4. **Extensibility**: Easy to add new transformations without breaking existing code
5. **Correctness**: Immutability prevents accidental mutations and race conditions
6. **Determinism**: Explicit RNG ensures reproducible simulations
7. **UI Reactivity**: Automatic DataBus notifications enable reactive UI updates

## References

- **PlayerStateManager Pattern**: `scripts/core/state/PlayerStateManager.gd`
- **Pure Function Pattern**: `scripts/core/transformations/StagePipeline.gd`
- **State Machine Pattern**: `scripts/world/PlayerLifecycleStateMachine.gd`
- **DataBus Integration**: `autoloads/DataBus.gd`
- **PR #155**: "Redesign data flow architecture for UI updates"

## Contact

For questions or clarifications about this architecture, refer to:
- `docs/agents/ENGINEER_PROTOCOLS.md` - Full engineer protocols
- `AGENTS.md` - Cross-cutting agent guidelines
