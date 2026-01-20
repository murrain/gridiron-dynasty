# Pure Functional Player State Architecture

**Status**: Design Document
**Version**: 1.0
**Last Updated**: 2026-01-20
**Owner**: Architecture Guardian

---

## Executive Summary

This document specifies a complete architectural redesign of the player state management system using pure functional programming principles. The new architecture eliminates scattered mutations, establishes unidirectional data flow, and provides a single source of truth for all state changes.

**Core Principles**:
1. **Pure Functions**: All state transformations are side-effect-free functions
2. **Helper Layer**: Single interface for all state mutations with automatic DataBus notifications
3. **Unidirectional Flow**: Event → Helper → Pure Function → New State → DataBus → UI

**Benefits**:
- **Testability**: Pure functions are trivial to test (input → output)
- **Traceability**: Every state change flows through a single point
- **Predictability**: No hidden mutations or side effects
- **Maintainability**: Clear separation of concerns and responsibilities

---

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [Proposed Architecture](#proposed-architecture)
3. [Data Flow Diagram](#data-flow-diagram)
4. [Core Interfaces](#core-interfaces)
5. [Implementation Structure](#implementation-structure)
6. [Migration Strategy](#migration-strategy)
7. [Example Implementations](#example-implementations)
8. [Testing Strategy](#testing-strategy)
9. [Performance Considerations](#performance-considerations)
10. [Appendix](#appendix)

---

## 1. Current Architecture Analysis

### 1.1 Problems Identified

#### Problem 1: Scattered Mutations
**Location**: Throughout codebase
**Severity**: High

```gdscript
# AdvanceWorldYear.gd - Direct mutation of world_state
func _handle_hs_generation(world_state: Dictionary, ...) -> Dictionary:
    var hs_players: Array = world_state.get("hs_players", [])
    hs_players.append_array(players)  # Direct mutation
    world_state["hs_players"] = hs_players  # Direct mutation
```

**Impact**:
- No centralized control over state changes
- Inconsistent DataBus notifications
- Difficult to audit what changed and when
- Hard to implement undo/redo or time-travel debugging

#### Problem 2: Model Contains Mutation Logic
**Location**: `Player.gd`
**Severity**: Medium

```gdscript
# Player.gd - Model has mutation methods
func transition_to(new_stage: PlayerStage) -> bool:
    stage = new_stage  # Self-mutation violates separation of concerns
    return true
```

**Impact**:
- Violates Single Responsibility Principle
- Models should be data containers, not state managers
- Makes testing harder (need to construct full Player objects)

#### Problem 3: Lifecycle Functions Mutate In-Place
**Location**: `PlayerLifecycle.gd`
**Severity**: High

```gdscript
# PlayerLifecycle.gd - Mutates player dict in-place
static func _advance_player_one_year(player: Dictionary, ...) -> Dictionary:
    var p := _selective_copy(player)  # Creates copy, but...
    p["age"] = int(p.get("age", 18)) + 1  # ...then mutates copy
    stats[stat_name] = next_val  # Direct mutation of nested dict
    return {"player": p, "retired": false}
```

**Impact**:
- Mixing pure computation with mutation
- Hard to compose transformations
- Difficult to preview changes without applying them

#### Problem 4: No State Management Layer
**Location**: System-wide
**Severity**: Critical

**Missing**: A centralized layer that:
- Controls all state mutations
- Ensures DataBus notifications happen atomically
- Provides transactional semantics
- Maintains invariants

**Impact**:
- UI updates are unreliable (missed notifications)
- No rollback capability
- No audit trail
- Cannot implement optimistic updates

---

## 2. Proposed Architecture

### 2.1 Architectural Vision

The new architecture establishes three distinct layers with clear responsibilities:

```
┌─────────────────────────────────────────────────────────────┐
│                      APPLICATION LAYER                       │
│  (Phases, Handlers, Business Logic)                         │
└────────────────┬────────────────────────────────────────────┘
                 │ calls helpers
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      HELPER LAYER                            │
│  (PlayerStateManager, WorldStateAccessor)                   │
│  - Single point of mutation                                 │
│  - Automatic DataBus notifications                          │
│  - Validation & invariant enforcement                       │
└────────────────┬────────────────────────────────────────────┘
                 │ calls pure functions
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   PURE FUNCTION LAYER                        │
│  (StagePipeline, GrowthFunctions, TransitionFunctions)      │
│  - Zero side effects                                        │
│  - Input → Output only                                      │
│  - 100% deterministic                                       │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Layer Responsibilities

#### Application Layer
- **What**: Orchestrates business processes (phases, handlers, workflows)
- **How**: Calls helper layer methods, never mutates state directly
- **Example**: `AdvanceWorldYear._handle_hs_season()` calls `PlayerStateManager.advance_players_one_year()`

#### Helper Layer
- **What**: Manages state mutations and notifications
- **How**: Wraps pure functions, applies results, emits DataBus events
- **Example**: `PlayerStateManager.advance_players_one_year()` calls pure functions, updates world_state, notifies UI

#### Pure Function Layer
- **What**: Computes new state from old state + inputs
- **How**: Pure functions with no side effects, fully testable
- **Example**: `GrowthFunctions.apply_development(player, context) -> new_player`

---

## 3. Data Flow Diagram

### 3.1 Complete Flow

```
┌──────────────┐
│ WORLD EVENT  │ (e.g., "Advance Year", "Sign Player", "Draft Player")
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  PHASE HANDLER       │ (e.g., AdvanceWorldYear._handle_nfl_season)
│  - Gathers inputs    │
│  - Validates context │
└──────┬───────────────┘
       │ calls helper
       ▼
┌──────────────────────────────────────┐
│  HELPER LAYER                        │
│  (PlayerStateManager)                │
│  ┌────────────────────────────────┐  │
│  │ 1. Validate input              │  │
│  │ 2. Call pure function          │  │
│  │ 3. Compute new state           │  │
│  │ 4. Apply to world_state        │  │
│  │ 5. Emit DataBus notification   │  │
│  └────────────────────────────────┘  │
└──────┬───────────────────────────────┘
       │ calls
       ▼
┌──────────────────────────────────────┐
│  PURE FUNCTION LAYER                 │
│  (StagePipeline, GrowthFunctions)    │
│  ┌────────────────────────────────┐  │
│  │ Input: old_player + context    │  │
│  │         ↓                      │  │
│  │    Compute changes             │  │
│  │         ↓                      │  │
│  │ Output: new_player             │  │
│  └────────────────────────────────┘  │
└──────┬───────────────────────────────┘
       │ returns new_player
       ▼
┌──────────────────────────────────────┐
│  WORLD STATE                         │
│  - Updated atomically                │
│  - Single source of truth            │
└──────┬───────────────────────────────┘
       │ emits
       ▼
┌──────────────────────────────────────┐
│  DATABUS                             │
│  - Notifies all subscribers          │
│  - UI components react               │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  UI COMPONENTS                       │
│  - Refresh displays                  │
│  - No direct state access            │
└──────────────────────────────────────┘
```

### 3.2 Detailed Example: Player Development

```
Event: "Advance Season"
   ↓
Handler: NflSeason.run()
   ↓
   calls: PlayerStateManager.advance_players_one_year(
      players=[p1, p2, p3],
      context={program_quality: 0.9, ...}
   )
   ↓
Helper: PlayerStateManager
   ├─ Validates inputs
   ├─ For each player:
   │  ├─ Calls: GrowthFunctions.apply_development(player, context)
   │  │           ↓
   │  │      Pure Function returns new player state
   │  │           ↓
   │  └─ Replaces player in world_state.nfl_rosters[team_id]
   ├─ Emits: DataBus.notify_collection_changed("nfl_rosters", "bulk_update")
   └─ Returns: summary stats
   ↓
UI: RosterScreen receives signal
   ↓
   Refreshes display with updated rosters
```

---

## 4. Core Interfaces

### 4.1 PlayerStateManager

**Purpose**: Single interface for all player state mutations with automatic DataBus notifications.

**Location**: `scripts/core/state/PlayerStateManager.gd`

```gdscript
class_name PlayerStateManager
extends RefCounted

## Core contract: ALL player state mutations MUST flow through this manager.
## This ensures atomic updates with DataBus notifications.

# ============================================================================
# PUBLIC API - State Mutation Methods
# ============================================================================

## Advance multiple players by one year using pure lifecycle functions.
## Returns: Dictionary with summary stats (active_count, retired_count, etc.)
static func advance_players_one_year(
    world_state: Dictionary,
    collection_path: Array,  # e.g., ["nfl_rosters", "SF", "players"]
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # 1. Extract players from world_state using collection_path
    # 2. For each player, call StagePipeline.advance_one_year(player, context)
    # 3. Replace players in world_state at collection_path
    # 4. Emit DataBus.notify_collection_changed(collection_name, "bulk_update")
    # 5. Return summary stats
    pass

## Transition a single player to a new lifecycle stage.
## Returns: true if successful, false if invalid transition
static func transition_player_stage(
    world_state: Dictionary,
    player_id: String,
    from_stage: Player.PlayerStage,
    to_stage: Player.PlayerStage,
    phase_id: String
) -> bool:
    # 1. Validate transition using PlayerLifecycleStateMachine
    # 2. Call TransitionFunctions.transition_stage(player, to_stage)
    # 3. Update player in world_state
    # 4. Emit DataBus.notify_players_changed(to_stage, 1)
    # 5. Return success/failure
    pass

## Update a single player's stats using pure stat functions.
## Returns: Updated player dict
static func update_player_stats(
    world_state: Dictionary,
    player_id: String,
    stat_changes: Dictionary  # {"speed": 85, "strength": 78}
) -> Dictionary:
    # 1. Find player in world_state
    # 2. Call StatFunctions.apply_stat_changes(player, stat_changes)
    # 3. Update player in world_state
    # 4. Emit DataBus.notify_collection_changed("players", "update")
    # 5. Return updated player
    pass

## Sign a player to a team with contract validation.
## Returns: Dictionary with {success: bool, player: Dictionary, contract: Dictionary}
static func sign_player_to_team(
    world_state: Dictionary,
    player_id: String,
    team_id: String,
    contract_terms: Dictionary
) -> Dictionary:
    # 1. Validate player exists and is free agent
    # 2. Validate team has cap space
    # 3. Call ContractFunctions.create_contract(player, team, terms)
    # 4. Update player.contract in world_state
    # 5. Add player to team roster
    # 6. Emit DataBus.notify_collection_changed("nfl_rosters", "update")
    # 7. Return result
    pass

## Release a player from a team.
## Returns: Dictionary with {success: bool, player_id: String, cap_savings: float}
static func release_player_from_team(
    world_state: Dictionary,
    player_id: String,
    team_id: String
) -> Dictionary:
    # 1. Find player on team roster
    # 2. Call ContractFunctions.calculate_dead_cap(player.contract)
    # 3. Remove player from roster
    # 4. Update player stage to FREE_AGENT
    # 5. Emit DataBus.notify_collection_changed("nfl_rosters", "update")
    # 6. Return cap impact
    pass

# ============================================================================
# INTERNAL HELPERS - State Access & Validation
# ============================================================================

## Find a player by ID across all collections.
## Returns: {collection: String, index: int, player: Dictionary}
static func _find_player(world_state: Dictionary, player_id: String) -> Dictionary:
    pass

## Replace a player in world_state at a specific location.
## Returns: true if successful
static func _replace_player(
    world_state: Dictionary,
    collection_path: Array,
    index: int,
    new_player: Dictionary
) -> bool:
    pass

## Validate that a state change maintains system invariants.
## Returns: {valid: bool, errors: Array[String]}
static func _validate_invariants(
    world_state: Dictionary,
    change_type: String,
    change_data: Dictionary
) -> Dictionary:
    pass
```

### 4.2 StagePipeline

**Purpose**: Pure function composition for player lifecycle transformations.

**Location**: `scripts/core/state/StagePipeline.gd`

```gdscript
class_name StagePipeline
extends RefCounted

## Pure function pipeline for player lifecycle stages.
## All functions are side-effect-free and deterministic.

# ============================================================================
# PURE FUNCTIONS - Stage Transformations
# ============================================================================

## Advance a single player by one year (pure function).
## Input: player dict, context dict, configs, RNG
## Output: {player: Dictionary, retired: bool, report: Dictionary}
static func advance_one_year(
    player: Dictionary,
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # 1. Create immutable copy of player
    var new_player := _immutable_copy(player)

    # 2. Apply age increment
    new_player = AgeFunctions.increment_age(new_player)

    # 3. Apply development based on lifecycle stage
    var development_result := GrowthFunctions.apply_development(
        new_player,
        context,
        configs,
        rng
    )
    new_player = development_result.player

    # 4. Apply injury simulation
    var injury_result := InjuryFunctions.simulate_injuries(
        new_player,
        configs,
        rng
    )
    new_player = injury_result.player

    # 5. Check retirement eligibility
    var should_retire := RetirementFunctions.should_retire(
        new_player,
        configs,
        rng
    )

    # 6. Return new state (original player unchanged!)
    return {
        "player": new_player,
        "retired": should_retire,
        "report": {
            "development": development_result.report,
            "injuries": injury_result.report
        }
    }

## Transition a player to a new lifecycle stage (pure function).
## Input: player dict, target stage
## Output: new player dict with updated stage
static func transition_stage(
    player: Dictionary,
    to_stage: int  # Player.PlayerStage enum value
) -> Dictionary:
    var new_player := _immutable_copy(player)
    new_player["stage"] = to_stage
    return new_player

# ============================================================================
# COMPOSITION HELPERS - Pure Function Utilities
# ============================================================================

## Create a deep immutable copy of a player dictionary.
## This prevents accidental mutation of input.
static func _immutable_copy(player: Dictionary) -> Dictionary:
    # Deep copy entire structure
    return player.duplicate(true)

## Compose multiple transformation functions into a pipeline.
## Example: pipeline([age_fn, growth_fn, injury_fn])
static func compose(functions: Array[Callable]) -> Callable:
    return func(input):
        var result = input
        for fn in functions:
            result = fn.call(result)
        return result
```

### 4.3 GrowthFunctions

**Purpose**: Pure functions for player stat development.

**Location**: `scripts/core/state/GrowthFunctions.gd`

```gdscript
class_name GrowthFunctions
extends RefCounted

## Pure functions for player stat development.
## All functions return NEW player dicts, never mutate input.

# ============================================================================
# DEVELOPMENT FUNCTIONS - Pure Transformations
# ============================================================================

## Apply one year of stat development (pure function).
## Input: player dict, context dict, configs, RNG
## Output: {player: Dictionary, report: Dictionary}
static func apply_development(
    player: Dictionary,
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var age := int(player.get("age", 18))
    var position := String(player.get("position", ""))

    # Extract config values
    var dev_config := configs.get("development", {})
    var peak_age := int(dev_config.get("peak_age", 26))
    var decline_start := int(dev_config.get("decline_start", 30))

    # Determine phase
    var phase := "growth"
    if age < peak_age:
        phase = "growth"
    elif age < decline_start:
        phase = "prime"
    else:
        phase = "decline"

    # Compute stat changes (pure function)
    var stat_changes := _compute_stat_changes(
        player,
        phase,
        context,
        configs,
        rng
    )

    # Create new player with updated stats
    var new_player := player.duplicate(true)
    var new_stats := (new_player.get("stats", {}) as Dictionary).duplicate(true)

    for stat_name in stat_changes.keys():
        var old_value := float(new_stats.get(stat_name, 0.0))
        var delta := float(stat_changes[stat_name])
        var new_value := clamp(old_value + delta, 0.0, 100.0)
        new_stats[stat_name] = new_value

    new_player["stats"] = new_stats

    # Build report (for debugging/analytics)
    var report := {
        "phase": phase,
        "age": age,
        "stat_changes": stat_changes
    }

    return {"player": new_player, "report": report}

## Compute stat changes for one year (pure function).
## Returns: Dictionary of {stat_name: delta_value}
static func _compute_stat_changes(
    player: Dictionary,
    phase: String,
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var changes := {}
    var stats := player.get("stats", {}) as Dictionary
    var potential := player.get("potential", stats) as Dictionary

    var dev_config := configs.get("development", {})
    var base_min := float(dev_config.get("annual_base_progress_min", 1.0))
    var base_max := float(dev_config.get("annual_base_progress_max", 4.0))

    # Apply phase-specific multipliers
    var multiplier := 1.0
    if phase == "growth":
        multiplier = 1.0
    elif phase == "prime":
        multiplier = 0.35
    else:
        multiplier = -1.0  # Decline

    # Apply context modifiers (coaching, scheme fit, etc.)
    var context_mult := _compute_context_multiplier(context)
    multiplier *= context_mult

    # Generate random progress for each stat
    for stat_name in stats.keys():
        var current := float(stats.get(stat_name, 0.0))
        var pot := float(potential.get(stat_name, current))

        # Roll for progress
        var raw_delta := rng.randf_range(base_min, base_max)
        var delta := raw_delta * multiplier

        # Cap by potential
        if delta > 0.0 and current + delta > pot:
            delta = pot - current

        changes[stat_name] = delta

    return changes

## Compute context multiplier from development context (pure function).
## Returns: float multiplier (0.7 to 1.4)
static func _compute_context_multiplier(context: Dictionary) -> float:
    var total_deviation := 0.0
    var factors := ["program_quality", "coach_specialization", "usage", "rehab_quality"]

    for factor in factors:
        var value := float(context.get(factor, 1.0))
        total_deviation += (value - 1.0)

    var multiplier := 1.0 + total_deviation
    return clamp(multiplier, 0.7, 1.4)
```

### 4.4 WorldStateAccessor

**Purpose**: Controlled read-only access to world_state with query helpers.

**Location**: `scripts/core/state/WorldStateAccessor.gd`

```gdscript
class_name WorldStateAccessor
extends RefCounted

## Read-only accessor for world_state with query helpers.
## Prevents accidental mutations by providing safe read-only views.

# ============================================================================
# QUERY METHODS - Read-Only Access
# ============================================================================

## Get all players matching a lifecycle stage.
## Returns: Array of player dictionaries (immutable copies)
static func get_players_by_stage(
    world_state: Dictionary,
    stage: int  # Player.PlayerStage
) -> Array:
    var results := []

    # Search across all player collections
    for collection_name in ["hs_players", "college_rosters", "draft_pool", "nfl_rosters"]:
        var collection = world_state.get(collection_name, null)
        if collection == null:
            continue

        # Handle different collection structures
        match collection_name:
            "nfl_rosters":
                # Dictionary of team_id -> roster
                for team_id in collection.keys():
                    var roster: Dictionary = collection[team_id]
                    var players: Array = roster.get("players", [])
                    for player in players:
                        var p: Dictionary = player
                        if int(p.get("stage", -1)) == stage:
                            results.append(p.duplicate(true))
            _:
                # Simple array of players
                if collection is Array:
                    for player in collection:
                        var p: Dictionary = player
                        if int(p.get("stage", -1)) == stage:
                            results.append(p.duplicate(true))

    return results

## Get a player by ID (immutable copy).
## Returns: Player dict or null if not found
static func get_player_by_id(
    world_state: Dictionary,
    player_id: String
) -> Dictionary:
    var location := _find_player_location(world_state, player_id)
    if location.is_empty():
        return {}

    var player: Dictionary = location.player
    return player.duplicate(true)  # Return immutable copy

## Get all teams with roster counts.
## Returns: Dictionary of {team_id: {name: String, roster_count: int}}
static func get_team_roster_counts(world_state: Dictionary) -> Dictionary:
    var results := {}
    var rosters: Dictionary = world_state.get("nfl_rosters", {})

    for team_id in rosters.keys():
        var roster: Dictionary = rosters[team_id]
        var players: Array = roster.get("players", [])
        results[team_id] = {
            "name": String(roster.get("name", team_id)),
            "roster_count": players.size()
        }

    return results

## Get draft-eligible players sorted by rating.
## Returns: Array of player dictionaries sorted descending by composite_score
static func get_draft_eligible_players_sorted(
    world_state: Dictionary
) -> Array:
    var draft_pool: Array = world_state.get("draft_pool", [])
    var sorted := draft_pool.duplicate(true)

    sorted.sort_custom(func(a, b):
        var score_a := float(a.get("composite_score", 0.0))
        var score_b := float(b.get("composite_score", 0.0))
        return score_a > score_b
    )

    return sorted

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

## Find player location in world_state.
## Returns: {collection: String, path: Array, player: Dictionary}
static func _find_player_location(
    world_state: Dictionary,
    player_id: String
) -> Dictionary:
    # Search across all collections
    # Return location metadata for efficient updates
    pass
```

---

## 5. Implementation Structure

### 5.1 File Organization

```
scripts/
├── core/
│   ├── models/
│   │   ├── Player.gd                    # Pure data model (no mutation methods)
│   │   ├── Contract.gd
│   │   ├── Injury.gd
│   │   └── ...
│   │
│   ├── state/                           # NEW: State management layer
│   │   ├── PlayerStateManager.gd       # Helper layer - mutation + notifications
│   │   ├── WorldStateAccessor.gd       # Read-only queries
│   │   ├── StateValidator.gd           # Invariant validation
│   │   └── StateTransaction.gd         # Transactional updates (future)
│   │
│   └── transformations/                 # NEW: Pure function layer
│       ├── StagePipeline.gd            # Lifecycle pipeline composition
│       ├── GrowthFunctions.gd          # Stat development (pure)
│       ├── InjuryFunctions.gd          # Injury simulation (pure)
│       ├── RetirementFunctions.gd      # Retirement checks (pure)
│       ├── TransitionFunctions.gd      # Stage transitions (pure)
│       ├── ContractFunctions.gd        # Contract calculations (pure)
│       ├── AgeFunctions.gd             # Age-related transforms (pure)
│       └── StatFunctions.gd            # Stat manipulation (pure)
│
├── world/
│   ├── PlayerLifecycle.gd              # DEPRECATED: Migrate to transformations/
│   ├── PlayerLifecycleStateMachine.gd  # Keep: Used by TransitionFunctions
│   └── ...
│
├── pipelines/
│   └── AdvanceWorldYear.gd             # REFACTOR: Use PlayerStateManager
│
└── autoloads/
    └── DataBus.gd                       # Keep: Event notification system
```

### 5.2 Module Dependencies

```
Application Layer (AdvanceWorldYear, NflSeason, etc.)
    ↓ depends on
Helper Layer (PlayerStateManager, WorldStateAccessor)
    ↓ depends on
Pure Function Layer (StagePipeline, GrowthFunctions, etc.)
    ↓ depends on
Core Models (Player, Contract, Injury)
    ↓ depends on
Nothing (pure data)
```

**Dependency Rules**:
1. Lower layers NEVER depend on higher layers
2. Pure functions NEVER depend on helpers or application logic
3. Models NEVER depend on transformation logic
4. DataBus is a singleton that can be accessed by helpers only

---

## 6. Migration Strategy

### 6.1 Migration Phases

#### Phase 1: Foundation (Week 1)
**Goal**: Establish pure function layer and helper infrastructure

**Tasks**:
1. Create `scripts/core/state/` directory
2. Implement `StagePipeline.gd` with pure `advance_one_year()` function
3. Implement `GrowthFunctions.gd` with pure development functions
4. Implement `PlayerStateManager.gd` skeleton with one method: `advance_players_one_year()`
5. Write unit tests for pure functions (easy - no mocks needed!)

**Success Criteria**:
- All pure functions pass unit tests
- Pure functions have ZERO side effects (verified by tests)
- PlayerStateManager can update world_state and notify DataBus

**No Breaking Changes**: Existing code still works

---

#### Phase 2: Pilot Migration (Week 2)
**Goal**: Migrate one phase handler as proof-of-concept

**Tasks**:
1. Choose simplest phase handler (e.g., `_handle_nfl_season`)
2. Refactor to use `PlayerStateManager.advance_players_one_year()`
3. Remove direct world_state mutations
4. Verify DataBus notifications fire correctly
5. Run integration tests to verify determinism preserved

**Success Criteria**:
- One phase handler fully migrated
- All tests pass
- No regression in determinism or performance

**Rollback Plan**: Keep old implementation commented out

---

#### Phase 3: Full Migration (Week 3-4)
**Goal**: Migrate all phase handlers to use helper layer

**Priority Order**:
1. Player lifecycle phases (HS season, college season, NFL season)
2. Draft and free agency phases
3. Roster management phases
4. Generation phases (lowest priority - mostly read-only)

**For Each Phase**:
1. Identify all world_state mutations
2. Create corresponding PlayerStateManager method if needed
3. Replace mutations with helper calls
4. Verify DataBus notifications
5. Run full test suite
6. Code review for pure function violations

**Success Criteria**:
- All phase handlers use PlayerStateManager
- Zero direct world_state mutations outside helpers
- All DataBus notifications consistent
- Performance maintained or improved

---

#### Phase 4: Model Cleanup (Week 5)
**Goal**: Remove mutation methods from Player.gd and related models

**Tasks**:
1. Remove `Player.transition_to()` method
2. Remove `Player.set_stat()` method
3. Make Player constructor immutable (optional)
4. Update all call sites to use helper layer
5. Add deprecation warnings for any missed cases

**Success Criteria**:
- Player.gd is pure data model
- No mutation methods remain
- All tests pass

---

#### Phase 5: Enhanced Features (Week 6+)
**Goal**: Add features enabled by new architecture

**Potential Features**:
1. **Undo/Redo**: Easy with pure functions (store state snapshots)
2. **Time-Travel Debugging**: Replay state changes
3. **Optimistic Updates**: Preview changes before committing
4. **State Auditing**: Log all mutations for debugging
5. **Parallel Processing**: Pure functions are trivially parallelizable

---

### 6.2 Compatibility Strategy

**Problem**: During migration, we need to support both old and new code paths.

**Solution**: Adapter pattern

```gdscript
# Old code (still works during migration)
var players: Array = world_state.get("nfl_rosters", {})["SF"]["players"]
for player in players:
    player["age"] += 1  # Direct mutation

# Adapter (temporary bridge)
func _advance_players_old_api(players: Array, context: Dictionary):
    # Convert to new API call
    PlayerStateManager.advance_players_one_year(
        world_state,
        ["nfl_rosters", "SF", "players"],
        context,
        configs,
        rng
    )

# New code (final target)
var result := PlayerStateManager.advance_players_one_year(
    world_state,
    ["nfl_rosters", "SF", "players"],
    context,
    configs,
    rng
)
# DataBus notification happens automatically!
```

**Timeline**:
- Weeks 1-2: Both old and new code coexist
- Weeks 3-4: All new code uses helper layer
- Week 5: Remove old mutation code
- Week 6+: Adapter code deleted

---

## 7. Example Implementations

### 7.1 Example: Pure Function for Player Development

```gdscript
# scripts/core/transformations/GrowthFunctions.gd

## PURE FUNCTION: Apply one year of development to a player.
## Input: player dict (unchanged), context dict, configs, RNG
## Output: NEW player dict with updated stats
static func apply_development(
    player: Dictionary,
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Step 1: Create immutable copy (input unchanged)
    var new_player := player.duplicate(true)

    # Step 2: Extract current state
    var age := int(new_player.get("age", 18))
    var stats: Dictionary = new_player.get("stats", {})
    var potential: Dictionary = new_player.get("potential", stats)

    # Step 3: Determine development phase
    var phase := _determine_phase(age, configs)

    # Step 4: Compute stat changes (pure)
    var stat_changes := _compute_stat_changes(
        stats,
        potential,
        phase,
        context,
        configs,
        rng
    )

    # Step 5: Apply changes to new_player (input still unchanged!)
    var new_stats := stats.duplicate(true)
    for stat_name in stat_changes.keys():
        var old_value := float(new_stats.get(stat_name, 0.0))
        var delta := float(stat_changes[stat_name])
        var new_value := clamp(old_value + delta, 0.0, 100.0)
        new_stats[stat_name] = new_value

    new_player["stats"] = new_stats

    # Step 6: Return NEW player (original unchanged)
    return new_player
```

**Key Properties**:
- **Pure**: Same inputs always produce same outputs
- **No Side Effects**: Original `player` dict is never modified
- **Testable**: No mocks needed, just call function and check output
- **Composable**: Can chain with other pure functions
- **Parallelizable**: Safe to run on multiple players concurrently

**Test**:
```gdscript
func test_apply_development_is_pure():
    var player := {"age": 22, "stats": {"speed": 80}}
    var context := {"program_quality": 1.0}
    var configs := {"development": {"peak_age": 26}}
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    # Call function
    var result := GrowthFunctions.apply_development(player, context, configs, rng)

    # Original player unchanged
    assert_eq(player["stats"]["speed"], 80, "Original unchanged")

    # Result is new dict
    assert_ne(result, player, "Result is new dict")

    # Result has expected changes
    assert_gt(result["stats"]["speed"], 80, "Speed increased")
```

---

### 7.2 Example: Helper Function with DataBus Notification

```gdscript
# scripts/core/state/PlayerStateManager.gd

## Advance multiple players by one year using pure functions.
## Automatically updates world_state and notifies UI via DataBus.
static func advance_players_one_year(
    world_state: Dictionary,
    collection_path: Array,  # e.g., ["nfl_rosters", "SF", "players"]
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Step 1: Extract players from world_state
    var players := _extract_collection(world_state, collection_path)
    if players.is_empty():
        return {"active_count": 0, "retired_count": 0}

    # Step 2: Transform players using pure functions
    var active := []
    var retired := []

    for player in players:
        var p: Dictionary = player
        # Call pure function (no side effects!)
        var result := StagePipeline.advance_one_year(p, context, configs, rng)

        if result.get("retired", false):
            retired.append(result.player)
        else:
            active.append(result.player)

    # Step 3: Update world_state atomically
    _replace_collection(world_state, collection_path, active)

    # Step 4: Emit DataBus notification (automatic!)
    var collection_name := String(collection_path[0])
    DataBus.notify_collection_changed(collection_name, "bulk_update")

    # Step 5: Return summary stats
    return {
        "active_count": active.size(),
        "retired_count": retired.size(),
        "collection": collection_name
    }
```

**Key Properties**:
- **Single Responsibility**: Only this function mutates world_state
- **Atomic Updates**: State change + notification happen together
- **Transactional**: If function fails, world_state unchanged (future enhancement)
- **Auditable**: Can log all calls for debugging
- **Traceable**: Every state change flows through here

**Usage**:
```gdscript
# In phase handler (e.g., NflSeason.run)
var result := PlayerStateManager.advance_players_one_year(
    world_state,
    ["nfl_rosters", team_id, "players"],
    {"program_quality": 0.9, "usage": 1.2},
    configs,
    rng
)

print("Advanced %d players, %d retired" % [result.active_count, result.retired_count])
# UI automatically refreshes via DataBus signal!
```

---

### 7.3 Example: Phase Handler Using Helper Layer

```gdscript
# scripts/pipelines/AdvanceWorldYear.gd (refactored)

func _handle_nfl_season(
    world_state: Dictionary,
    year: int,
    _seed: int,
    phase: Dictionary,
    year_seed: int
) -> Dictionary:
    var phase_id := String(phase.get("phase_id", ""))
    var step_seed := _derive_seed(year_seed, phase_id, "nfl_season")

    var rng := RandomNumberGenerator.new()
    rng.seed = step_seed

    var configs := {
        "league": _get_config().get_config("world/league"),
        "positions": _get_config().get_config("positions"),
        "main": _get_config().get_config("main"),
        "stats": _get_config().get_config("stats")
    }

    var context := {
        "program_quality": 1.0,
        "usage": 1.0,
        "competition_tier": 1.0
    }

    # OLD CODE (direct mutation):
    # var rosters := world_state.get("nfl_rosters", {})
    # for team_id in rosters.keys():
    #     var players: Array = rosters[team_id]["players"]
    #     for player in players:
    #         player["age"] += 1  # MUTATION!

    # NEW CODE (helper layer):
    var total_active := 0
    var total_retired := 0

    var rosters: Dictionary = world_state.get("nfl_rosters", {})
    for team_id in rosters.keys():
        # Use helper function (automatic DataBus notification!)
        var result := PlayerStateManager.advance_players_one_year(
            world_state,
            ["nfl_rosters", team_id, "players"],
            context,
            configs,
            rng
        )
        total_active += result.active_count
        total_retired += result.retired_count

    # UI already updated via DataBus signals!
    # No manual refresh needed!

    return {
        "year": year,
        "teams_processed": rosters.size(),
        "active_players": total_active,
        "retirements": total_retired,
        "step_seeds": {"nfl_season": step_seed}
    }
```

**Benefits**:
- **No Direct Mutations**: All changes flow through helper layer
- **Automatic Notifications**: DataBus signals emitted automatically
- **Clean Separation**: Business logic separate from state management
- **Easy to Test**: Pure functions are trivial to unit test
- **Easy to Audit**: All state changes traceable through helper layer

---

## 8. Testing Strategy

### 8.1 Pure Function Tests

**Advantages of Pure Functions**:
- No mocks needed
- No setup/teardown
- Fast execution
- Easy to write
- 100% deterministic

**Test Template**:
```gdscript
# tests/core/transformations/test_growth_functions.gd

func test_apply_development_increases_stats_in_growth_phase():
    # Arrange
    var player := {
        "age": 22,
        "stats": {"speed": 70, "strength": 75},
        "potential": {"speed": 85, "strength": 90}
    }
    var context := {"program_quality": 1.0}
    var configs := {
        "development": {
            "peak_age": 26,
            "annual_base_progress_min": 1.0,
            "annual_base_progress_max": 4.0
        }
    }
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    # Act
    var result := GrowthFunctions.apply_development(player, context, configs, rng)

    # Assert - Original unchanged
    assert_eq(player["stats"]["speed"], 70, "Original unchanged")

    # Assert - Result has new dict
    assert_ne(result, player, "Result is new dict")

    # Assert - Stats increased in growth phase
    assert_gt(result["stats"]["speed"], 70, "Speed increased")
    assert_gt(result["stats"]["strength"], 75, "Strength increased")

    # Assert - Stats capped by potential
    assert_lte(result["stats"]["speed"], 85, "Speed capped by potential")
    assert_lte(result["stats"]["strength"], 90, "Strength capped by potential")

func test_apply_development_is_deterministic():
    var player := {"age": 22, "stats": {"speed": 70}}
    var context := {"program_quality": 1.0}
    var configs := {"development": {"peak_age": 26}}

    # Same seed = same results
    var rng1 := RandomNumberGenerator.new()
    rng1.seed = 12345
    var result1 := GrowthFunctions.apply_development(player, context, configs, rng1)

    var rng2 := RandomNumberGenerator.new()
    rng2.seed = 12345
    var result2 := GrowthFunctions.apply_development(player, context, configs, rng2)

    assert_eq(result1["stats"]["speed"], result2["stats"]["speed"], "Deterministic")

func test_apply_development_with_max_potential():
    var player := {
        "age": 22,
        "stats": {"speed": 85},
        "potential": {"speed": 85}  # Already at potential
    }
    var context := {"program_quality": 1.0}
    var configs := {"development": {"peak_age": 26}}
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    var result := GrowthFunctions.apply_development(player, context, configs, rng)

    # Speed should not exceed potential
    assert_eq(result["stats"]["speed"], 85, "Capped at potential")
```

**Coverage Goals**:
- 100% line coverage for pure functions
- Test all edge cases (min/max values, nulls, empty dicts)
- Test determinism with same seeds
- Test composition (chaining functions)

---

### 8.2 Helper Layer Tests

**Testing Strategy**: Integration tests with real world_state

**Test Template**:
```gdscript
# tests/core/state/test_player_state_manager.gd

func test_advance_players_one_year_updates_world_state():
    # Arrange
    var world_state := {
        "nfl_rosters": {
            "SF": {
                "players": [
                    {"id": "p1", "age": 22, "stats": {"speed": 70}},
                    {"id": "p2", "age": 24, "stats": {"speed": 80}}
                ]
            }
        }
    }
    var context := {"program_quality": 1.0}
    var configs := _minimal_configs()
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    # Act
    var result := PlayerStateManager.advance_players_one_year(
        world_state,
        ["nfl_rosters", "SF", "players"],
        context,
        configs,
        rng
    )

    # Assert - Players advanced
    var players: Array = world_state["nfl_rosters"]["SF"]["players"]
    assert_eq(players[0]["age"], 23, "Age incremented")
    assert_gt(players[0]["stats"]["speed"], 70, "Stats updated")

    # Assert - Return value
    assert_eq(result.active_count, 2, "Both players active")
    assert_eq(result.retired_count, 0, "No retirements")

func test_advance_players_emits_databus_signal():
    # Arrange
    var world_state := {"nfl_rosters": {"SF": {"players": [{"id": "p1", "age": 22}]}}}
    var context := {}
    var configs := _minimal_configs()
    var rng := RandomNumberGenerator.new()

    # Setup signal spy
    var signal_emitted := false
    var emitted_collection := ""
    DataBus.collection_changed.connect(func(coll, op):
        signal_emitted = true
        emitted_collection = coll
    )

    # Act
    PlayerStateManager.advance_players_one_year(
        world_state,
        ["nfl_rosters", "SF", "players"],
        context,
        configs,
        rng
    )

    # Assert
    assert_true(signal_emitted, "DataBus signal emitted")
    assert_eq(emitted_collection, "nfl_rosters", "Correct collection")
```

**Coverage Goals**:
- Test all helper methods
- Verify DataBus signals emitted correctly
- Test error handling (invalid inputs, missing data)
- Test atomicity (state unchanged on error)

---

### 8.3 Integration Tests

**Testing Strategy**: Full pipeline tests with phase handlers

**Test Template**:
```gdscript
# tests/pipelines/test_advance_world_year_integration.gd

func test_nfl_season_phase_uses_pure_functions():
    # Arrange - Create minimal world_state
    var world_state := _create_test_world_state()
    var year := 2033
    var year_seed := 12345

    var pipeline := AdvanceWorldYear.new()

    # Act - Run NFL season phase
    var result := pipeline.run(world_state, year, year_seed)

    # Assert - Players advanced
    var players: Array = world_state["nfl_rosters"]["SF"]["players"]
    for player in players:
        var p: Dictionary = player
        assert_gt(p["age"], 22, "Age advanced")

    # Assert - DataBus notifications occurred (check logs)
    # Assert - Determinism preserved (run twice with same seed)

    var world_state2 := _create_test_world_state()
    var result2 := pipeline.run(world_state2, year, year_seed)

    assert_eq_deep(
        world_state["nfl_rosters"],
        world_state2["nfl_rosters"],
        "Deterministic results"
    )
```

**Coverage Goals**:
- Test each phase handler
- Verify determinism across full pipeline
- Test error recovery
- Test performance (no regressions)

---

## 9. Performance Considerations

### 9.1 Potential Concerns

#### Concern 1: Deep Copying Overhead
**Issue**: Pure functions require deep copying player dicts

**Analysis**:
```
Current: Selective copy (~150 bytes per player per year)
Pure Function: Full deep copy (~500 bytes per player per year)
Overhead: +350 bytes per player per year
```

**For 10,000 players**: +3.5 MB per year advancement

**Mitigation**:
1. **Structural Sharing**: Use GDScript's copy-on-write semantics where possible
2. **Lazy Copying**: Only copy fields that will be modified
3. **Batch Processing**: Process players in chunks to improve cache locality
4. **Immutable Data Structures** (future): Use persistent data structures

**Benchmark Target**: < 5% performance regression vs. current implementation

---

#### Concern 2: Function Call Overhead
**Issue**: Pure functions add extra call stack depth

**Analysis**:
```
Current: Direct mutation (0 extra calls)
Pure Function: 2-3 extra function calls per transformation
```

**Impact**: Negligible in GDScript (JIT-compiled, stack is cheap)

**Mitigation**: Profile-guided optimization if needed

---

#### Concern 3: DataBus Notification Overhead
**Issue**: Emitting signals for every mutation could be expensive

**Analysis**:
- Current: Inconsistent notifications (some phases notify, others don't)
- New: Consistent notifications from helper layer

**Mitigation**:
1. **Batch Notifications**: Emit one signal per collection, not per player
2. **Deferred Notifications**: Queue notifications and emit at frame end
3. **Selective Notifications**: Only notify if UI is listening

**Benchmark Target**: < 1ms per batch notification

---

### 9.2 Optimization Strategies

#### Strategy 1: Selective Deep Copy
**Implementation**:
```gdscript
static func _immutable_copy(player: Dictionary) -> Dictionary:
    # Only deep copy mutable nested structures
    var copy := player.duplicate(false)  # Shallow copy top-level

    # Deep copy only modified fields
    copy["stats"] = player["stats"].duplicate(true)
    copy["potential"] = player["potential"].duplicate(true)
    copy["injuries"] = player["injuries"].duplicate(true)

    # Share immutable fields (strings, ints, enums)
    # copy["id"], copy["name"], copy["position"] are shared references

    return copy
```

**Savings**: ~60% reduction in copy overhead

---

#### Strategy 2: Batch Processing
**Implementation**:
```gdscript
static func advance_players_one_year_batched(
    world_state: Dictionary,
    collection_paths: Array[Array],  # Multiple collections
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Process all collections in one pass
    # Emit single DataBus notification at end
    # Reduces overhead from N signals to 1 signal
```

---

#### Strategy 3: Parallel Pure Functions
**Implementation**:
```gdscript
static func advance_players_one_year_parallel(
    world_state: Dictionary,
    collection_path: Array,
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator,
    thread_count: int = 4
) -> Dictionary:
    # Pure functions are trivially parallelizable!
    # No shared mutable state = no race conditions
    # Use ThreadPool for parallel execution
```

**Speedup**: 2-4x on multi-core systems

---

## 10. Appendix

### 10.1 Glossary

**Pure Function**: A function where:
- Output depends only on inputs (no hidden state)
- No side effects (no mutations, no I/O, no signals)
- Same inputs always produce same outputs (deterministic)

**Helper Layer**: Intermediate layer that:
- Wraps pure functions
- Manages state mutations
- Emits DataBus notifications
- Enforces invariants

**Unidirectional Data Flow**: Design pattern where:
- Data flows in one direction (Event → Helper → State → UI)
- No circular dependencies
- State changes are predictable and traceable

**Immutability**: Property where:
- Data structures cannot be modified after creation
- All transformations create new copies
- Original data remains unchanged

**State Transaction**: Atomic operation where:
- Multiple state changes succeed or fail as a unit
- Partial updates are rolled back on error
- Ensures consistency

---

### 10.2 References

**Academic Papers**:
- "Out of the Tar Pit" by Ben Moseley and Peter Marks (2006)
  - Argues for separating state, logic, and control
  - Advocates for pure functions and minimal mutable state

- "Functional Programming in GDScript" (Community Wiki)
  - Patterns for FP in game development
  - Performance considerations for functional idioms

**Related Documentation**:
- `/docs/architecture/SIMULATION_LOOP_DESIGN.md`
- `/docs/architecture/MODEL_HIERARCHY.md`
- `/docs/guides/QUICK_REFERENCE.md`

**Code Examples**:
- Elm Architecture (web framework with similar principles)
- Redux (state management for web apps)
- Clojure's persistent data structures

---

### 10.3 Decision Log

| Date       | Decision                                      | Rationale                                                |
|------------|-----------------------------------------------|----------------------------------------------------------|
| 2026-01-20 | Use pure functions for all transformations    | Testability, composability, parallelization              |
| 2026-01-20 | Helper layer as single mutation interface     | Single source of truth, atomic notifications             |
| 2026-01-20 | DataBus notifications automatic in helpers    | Prevents missed updates, ensures consistency             |
| 2026-01-20 | Selective deep copy for performance           | Balance purity with pragmatic performance                |
| 2026-01-20 | Keep PlayerLifecycleStateMachine              | Transition validation logic is still valuable            |
| 2026-01-20 | Migrate in phases (6 week timeline)           | Reduces risk, allows rollback, maintains stability       |

---

### 10.4 Open Questions

**Q1**: Should we implement full immutable data structures (like Clojure's persistent vectors)?
**A**: Not initially. Start with deep copying and optimize if profiling shows performance issues.

**Q2**: How do we handle undo/redo with this architecture?
**A**: Store snapshots of world_state before each phase. Pure functions make this trivial (no need to track deltas).

**Q3**: Can we make this work with Godot's built-in undo/redo system?
**A**: Yes, but deferred to Phase 5+ (enhanced features).

**Q4**: What about transaction rollback if a phase fails mid-execution?
**A**: Implement `StateTransaction` class in Phase 5+ (not critical for MVP).

**Q5**: Should pure functions return Result types instead of raw dictionaries?
**A**: Consider for Phase 5+ (type safety improvements). For now, use dictionaries for compatibility.

---

### 10.5 Success Metrics

**Quantitative Metrics**:
- **Test Coverage**: > 95% for pure functions, > 85% for helpers
- **Performance**: < 5% regression vs. current implementation
- **Determinism**: 100% deterministic with same seeds (0 flakiness)
- **Code Quality**: 0 direct mutations outside helper layer
- **DataBus Coverage**: 100% of state changes emit notifications

**Qualitative Metrics**:
- **Developer Velocity**: Faster to add new features after migration
- **Bug Density**: Fewer state-related bugs (tracked in issue tracker)
- **Code Clarity**: Easier to onboard new developers (subjective feedback)
- **Debuggability**: Faster to diagnose issues (time to resolution)

---

## Conclusion

This architecture redesign transforms the player state system from scattered mutations to a clean, traceable, testable pure functional architecture. The migration is designed to be incremental, low-risk, and deliver immediate benefits at each phase.

**Key Takeaways**:
1. **Pure functions** enable testing, composition, and parallelization
2. **Helper layer** provides single source of truth for all mutations
3. **Unidirectional data flow** makes state changes predictable and traceable
4. **Incremental migration** reduces risk and allows validation at each step
5. **DataBus integration** ensures UI always stays synchronized

**Next Steps**:
1. Review and approve this design document
2. Begin Phase 1 implementation (foundation layer)
3. Create implementation tickets for each phase
4. Assign engineers and begin development

---

**Document History**:
- 2026-01-20: Initial version (v1.0) by Architecture Guardian
