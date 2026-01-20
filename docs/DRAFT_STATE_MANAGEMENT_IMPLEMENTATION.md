# Draft State Management - Phase 1 Implementation

**Status**: ✅ Complete
**Date**: 2026-01-20
**Architecture Pattern**: Pure Functional with State Manager

---

## Overview

This implementation creates a clean, functional architecture for draft state management following the established patterns from PR #155. All draft-related state mutations now flow through a single manager with pure transformation functions, state machine validation, and automatic DataBus notifications.

---

## Files Created

### 1. `/scripts/core/transformations/DraftTransformations.gd` (433 lines)

**Purpose**: Pure transformation functions for draft operations

**Key Functions**:
- `generate_scouting_quality()` - Generates team-specific scouting quality metrics
- `allocate_draft_picks()` - Creates initial pick ownership structure
- `apply_draft_pick()` - Records a draft pick (pure function)
- `apply_pick_trade()` - Transfers pick ownership between teams
- `generate_draft_history()` - Creates draft history records

**Critical Properties**:
- ✅ All functions are PURE (never modify inputs)
- ✅ All functions use `.duplicate(true)` for deep copies
- ✅ RNG passed explicitly as parameters
- ✅ Deterministic for given seeds
- ✅ Fully documented RNG consumption patterns

**Example Usage**:
```gdscript
# Generate scouting quality (deterministic)
var quality := DraftTransformations.generate_scouting_quality(teams, class_rules, seed)

# Apply a draft pick (returns NEW dictionaries)
var result := DraftTransformations.apply_draft_pick(
    draft_pool,  # Unchanged
    rosters,     # Unchanged
    player_id,
    team_id,
    draft_info,
    contract
)
# result.updated_pool - NEW pool with player removed
# result.updated_rosters - NEW rosters with player added
# result.drafted_player - NEW player dictionary
```

---

### 2. `/scripts/core/state/DraftStateMachine.gd` (344 lines)

**Purpose**: State machine for draft lifecycle transitions

**States**:
```gdscript
enum State {
    NOT_STARTED,   # Draft has not been initialized
    INITIALIZING,  # Draft is being set up
    RUNNING,       # Draft is actively in progress
    PAUSED,        # Draft is temporarily paused
    COMPLETED      # Draft has finished
}
```

**Valid Transitions**:
- `NOT_STARTED` → `INITIALIZING`
- `INITIALIZING` → `RUNNING`, `NOT_STARTED` (abort)
- `RUNNING` → `PAUSED`, `COMPLETED`
- `PAUSED` → `RUNNING`, `COMPLETED`
- `COMPLETED` → (terminal state)

**Key Methods**:
- `can_transition(from, to)` - Validates state transitions
- `can_execute_pick(state)` - Checks if picks can be executed
- `transition_state(draft_state, to_state, reason)` - Performs validated transition
- `validate_operation(state, operation)` - Validates operations for current state

**Example Usage**:
```gdscript
# Validate transition before attempting
if DraftStateMachine.can_transition(current_state, DraftStateMachine.State.RUNNING):
    DraftStateMachine.transition_state(draft_state, DraftStateMachine.State.RUNNING, "start_draft")

# Check if operation allowed
if DraftStateMachine.can_execute_pick(draft_state["state"]):
    # Execute pick...
```

---

### 3. `/scripts/core/state/DraftStateManager.gd` (593 lines)

**Purpose**: Single interface for all draft state mutations

**Key Methods**:

#### `initialize_draft(world_state, teams, year, league_cfg, class_rules, seed)`
- Sets up draft structures for a year
- Allocates pick ownership
- Generates scouting quality (cached)
- Transitions state to INITIALIZING
- **Side Effects**: Mutates `world_state["draft_pick_ownership"]`, `world_state["nfl_scouting_quality"]`
- **DataBus**: Emits `collection_changed` for both

#### `execute_pick(world_state, player_id, team_id, draft_info, contract, year)`
- Removes player from draft pool
- Adds player to team roster
- Updates all related structures atomically
- **Side Effects**: Mutates `world_state["draft_pool"]`, `world_state["nfl_rosters"]`
- **DataBus**: Emits `collection_changed` for both

#### `execute_trade(world_state, year, round_num, original_team_id, new_owner_id)`
- Transfers pick ownership between teams
- **Side Effects**: Mutates `world_state["draft_pick_ownership"]`
- **DataBus**: Emits `collection_changed`

#### `record_draft_history(world_state, picks, year)`
- Records complete draft history
- Transitions state to COMPLETED
- **Side Effects**: Mutates `world_state["draft_history"]`
- **DataBus**: Emits `collection_changed` and `phase_completed`

#### `store_undrafted_players(world_state, remaining_players, year)`
- Stores undrafted free agents
- **Side Effects**: Mutates `world_state["undrafted_pool"]`
- **DataBus**: Emits `collection_changed`

#### State Control:
- `start_draft(world_state, year, round_num)` - INITIALIZING → RUNNING
- `pause_draft(world_state)` - RUNNING → PAUSED
- `resume_draft(world_state)` - PAUSED → RUNNING

**Example Usage**:
```gdscript
# Initialize draft
var result := DraftStateManager.initialize_draft(
    world_state,
    teams,
    2025,
    league_cfg,
    class_rules,
    seed
)

# Start draft execution
DraftStateManager.start_draft(world_state, 2025, 1)

# Execute a pick
var pick_result := DraftStateManager.execute_pick(
    world_state,
    "player_123",
    "SF",
    {"year": 2025, "round": 1, "pick": 13, "team_id": "SF"},
    contract,
    2025
)

# Record history at completion
DraftStateManager.record_draft_history(world_state, picks, 2025)
```

---

### 4. `/tests/core/state/DraftStateManagerTest.gd` (654 lines)

**Purpose**: Comprehensive test suite for draft state management

**Test Categories**:

1. **Immutability Tests** (verify inputs never modified):
   - `test_initialize_draft_preserves_inputs()`
   - `test_execute_pick_preserves_draft_pool()`
   - `test_execute_trade_preserves_ownership()`

2. **Determinism Tests** (same seed = same results):
   - `test_initialize_draft_deterministic()`
   - `test_scouting_quality_different_seeds()`

3. **State Machine Tests**:
   - `test_state_machine_valid_transitions()`
   - `test_state_machine_invalid_transition_rejected()`
   - `test_cannot_execute_pick_when_not_running()`

4. **Atomicity Tests** (all-or-nothing updates):
   - `test_execute_pick_updates_all_structures()`
   - `test_record_draft_history_complete_workflow()`

5. **Transformation Tests**:
   - `test_allocate_draft_picks_creates_ownership()`
   - `test_apply_pick_trade_transfers_ownership()`
   - `test_apply_draft_pick_removes_from_pool()`

6. **Integration Tests** (full workflow):
   - `test_full_draft_workflow()`

**Running Tests**:
```bash
# Run all tests
godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add tests/core/state/DraftStateManagerTest.gd

# Run specific test
godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add tests/core/state/DraftStateManagerTest.gd:test_full_draft_workflow
```

---

## Architecture Patterns Followed

### 1. Immutability (from StagePipeline.gd)
```gdscript
# ✅ CORRECT: Create new dictionary
var new_player := player.duplicate(true)
new_player["age"] = 23
return new_player

# ❌ WRONG: Modify input
player["age"] = 23  # NEVER DO THIS
return player
```

### 2. Determinism (explicit RNG)
```gdscript
# ✅ CORRECT: RNG passed as parameter
static func generate_scouting_quality(
    teams: Array,
    class_rules: Dictionary,
    world_seed: int  # Explicit seed
) -> Dictionary:
    var team_rng := RandomNumberGenerator.new()
    team_rng.seed = Rand.splitmix64(world_seed ^ hash(team_id))
    # ... use team_rng

# ❌ WRONG: Global random state
var random_value = randf()  # Non-deterministic!
```

### 3. Manager Pattern (from PlayerStateManager.gd)
```gdscript
# ✅ Manager calls pure functions, updates world_state, emits signals
static func execute_pick(...) -> Dictionary:
    # 1. Call pure transformation
    var result := DraftTransformations.apply_draft_pick(...)

    # 2. Update world_state atomically
    world_state["draft_pool"][year] = result["updated_pool"]
    world_state["nfl_rosters"] = result["updated_rosters"]

    # 3. Emit DataBus notification
    _notify_collection_changed("draft_pool", "update")

    return result
```

### 4. State Machine Validation (from PlayerLifecycleStateMachine.gd)
```gdscript
# ✅ Validate before allowing operations
if not DraftStateMachine.can_execute_pick(current_state):
    push_warning("Cannot execute pick in state %s" % state)
    return _empty_pick_result()

# Proceed with operation...
```

---

## DataBus Integration

All state mutations automatically emit DataBus signals:

```gdscript
# Collection changes
DataBus.collection_changed.emit("draft_pool", "update")
DataBus.collection_changed.emit("nfl_rosters", "update")
DataBus.collection_changed.emit("draft_pick_ownership", "update")
DataBus.collection_changed.emit("draft_history", "insert")
DataBus.collection_changed.emit("undrafted_pool", "insert")

# Phase completion
DataBus.phase_completed.emit("nfl_draft", year)
```

UI components can subscribe to these signals for reactive updates:
```gdscript
# In UI component
func _ready():
    DataBus.collection_changed.connect(_on_collection_changed)

func _on_collection_changed(collection_name: String, operation: String):
    if collection_name == "draft_pool":
        refresh_draft_board()
```

---

## Current NflDraft.gd Mutations (Reference)

The following direct mutations in `NflDraft.gd` should eventually be replaced with manager calls:

**Lines 66-73**: Pick ownership initialization
```gdscript
# OLD (direct mutation):
if not world_state.has("draft_pick_ownership"):
    initialize_pick_ownership(world_state, teams, year, rounds)

# NEW (use manager):
DraftStateManager.initialize_draft(world_state, teams, year, league_cfg, class_rules, seed)
```

**Lines 70-73**: Scouting quality initialization
```gdscript
# OLD (direct mutation):
if not world_state.has("nfl_scouting_quality"):
    world_state["nfl_scouting_quality"] = _generate_team_scouting_quality(...)

# NEW (use manager):
DraftStateManager.initialize_draft(world_state, teams, year, league_cfg, class_rules, seed)
```

**Lines 278-281**: Undrafted pool storage
```gdscript
# OLD (direct mutation):
var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
undrafted_pool[year] = remaining_pool
world_state["undrafted_pool"] = undrafted_pool
world_state["nfl_rosters"] = rosters

# NEW (use manager):
DraftStateManager.store_undrafted_players(world_state, remaining_pool, year)
```

**Lines 289-330**: Draft history recording
```gdscript
# OLD (direct mutation):
var draft_history: Dictionary = world_state.get("draft_history", {})
draft_history[year] = []
# ... build history ...
world_state["draft_history"] = draft_history

# NEW (use manager):
DraftStateManager.record_draft_history(world_state, picks, year)
```

---

## Testing Strategy

### 1. Immutability Verification
Tests hash inputs before transformation and verify hash unchanged after:
```gdscript
var teams_hash := hash(teams)
DraftStateManager.initialize_draft(world_state, teams, ...)
assert_int(hash(teams)).is_equal(teams_hash)  # Input preserved
```

### 2. Determinism Verification
Tests run same operation with same seed twice and compare results:
```gdscript
var result_1 := DraftTransformations.generate_scouting_quality(teams, rules, 42)
var result_2 := DraftTransformations.generate_scouting_quality(teams, rules, 42)
assert_equal(result_1["SF"]["base_quality"], result_2["SF"]["base_quality"])
```

### 3. State Machine Verification
Tests validate only legal transitions are allowed:
```gdscript
# Valid: INITIALIZING → RUNNING
assert_bool(DraftStateManager.start_draft(world_state, year, 1)).is_true()

# Invalid: INITIALIZING → PAUSED
assert_bool(DraftStateManager.pause_draft(world_state)).is_false()
```

---

## Next Steps

### Phase 2: Refactor NflDraft.gd
Replace direct mutations with manager calls:
1. Use `DraftStateManager.initialize_draft()` for setup
2. Use `DraftStateManager.execute_pick()` for picks
3. Use `DraftStateManager.store_undrafted_players()` for UDFAs
4. Use `DraftStateManager.record_draft_history()` for history

### Phase 3: Pick Trading Integration
Use existing manager methods:
```gdscript
DraftStateManager.execute_trade(
    world_state,
    2025,  # year
    1,     # round
    "SF",  # original owner
    "CHI"  # new owner
)
```

### Phase 4: UI Integration
Subscribe to DataBus signals for reactive updates:
```gdscript
DataBus.collection_changed.connect(_on_draft_pool_changed)
DataBus.phase_completed.connect(_on_draft_completed)
```

---

## Benefits of This Architecture

1. **Single Source of Truth**: All mutations flow through one manager
2. **Testability**: Pure functions are trivial to test with any inputs
3. **Determinism**: Explicit RNG ensures reproducible results
4. **Immutability**: No accidental state mutations
5. **Auditability**: All state changes logged and validated
6. **Extensibility**: Easy to add new operations or states
7. **UI Decoupling**: DataBus enables reactive UI updates

---

## Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| `DraftTransformations.gd` | 433 | Pure transformation functions |
| `DraftStateMachine.gd` | 344 | State machine validation |
| `DraftStateManager.gd` | 593 | State mutation manager |
| `DraftStateManagerTest.gd` | 654 | Comprehensive test suite |
| **Total** | **2,024** | **Complete infrastructure** |

---

## Quality Assurance

✅ All functions documented with RNG consumption patterns
✅ All transformations use `.duplicate(true)` for immutability
✅ All manager methods emit DataBus notifications
✅ All state transitions validated by state machine
✅ Comprehensive test coverage (14 test cases)
✅ Follows established patterns from PR #155
✅ No magic numbers (all constants named)
✅ Clear separation of concerns

---

**Implementation Complete** ✅
