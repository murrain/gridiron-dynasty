# Architecture Review: Pure Functional State Machine Expansion

**PR Reviewed:** #155 - Redesign data flow architecture for UI updates
**Reviewer:** Architecture Guardian
**Date:** 2026-01-20

---

## Executive Summary

PR #155 introduced an excellent pure functional architecture for player state management. This review identifies **7 additional domains** where similar patterns should be applied, prioritized by impact and architectural debt.

### PR #155 Assessment: **APPROVED** (Excellent Foundation)

The PR establishes three key patterns that should become project standards:

1. **Pure Transformation Functions** (`scripts/core/transformations/`)
   - Never modify input dictionaries
   - Always return NEW dictionaries with updated values
   - Deterministic with explicit RNG parameter passing
   - Composable via functional pipelines

2. **State Manager Layer** (`scripts/core/state/PlayerStateManager.gd`)
   - Single point of mutation for player state
   - Calls pure functions, then updates world_state atomically
   - Automatic DataBus notifications for UI sync
   - Returns operation summaries for logging/debugging

3. **Lifecycle State Machine** (`scripts/world/PlayerLifecycleStateMachine.gd`)
   - Explicit valid states and transitions
   - Validates transitions before execution
   - Single source of truth for lifecycle rules

---

## Domains Requiring Similar Refactoring

### Priority 1: CRITICAL (Architectural Debt)

#### 1.1 Draft State Management

**Current State:** Scattered mutations across 3+ files with implicit state

**Files Affected:**
- `scripts/world/NflDraft.gd` - Direct mutations to `world_state["nfl_scouting_quality"]`, `world_state["draft_pick_ownership"]`, rosters
- `scripts/world/InteractiveDraft.gd` - Internal `_state: DraftState` with direct mutations
- `scripts/world/DraftTradeEngine.gd` - Pick ownership changes without centralized interface

**Specific Issues Found:**

```gdscript
# NflDraft.gd:66-73 - Direct world_state mutations
if not world_state.has("draft_pick_ownership"):
    initialize_pick_ownership(world_state, teams, year, rounds)
if not world_state.has("nfl_scouting_quality"):
    world_state["nfl_scouting_quality"] = _generate_team_scouting_quality(...)

# NflDraft.gd:278-281 - Direct undrafted pool mutation
var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})
undrafted_pool[year] = remaining_pool
world_state["undrafted_pool"] = undrafted_pool
world_state["nfl_rosters"] = rosters
```

**Recommended Solution:**

Create `scripts/core/state/DraftStateManager.gd`:
```gdscript
class_name DraftStateManager

# Pure transformation functions
static func initialize_draft_structures(
    world_state: Dictionary,
    teams: Array,
    year: int,
    rounds: int,
    seed: int
) -> Dictionary:
    # Return NEW dict with initialized structures (doesn't mutate input)

static func execute_pick(
    draft_state: Dictionary,
    team_id: String,
    player: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Return NEW draft_state with pick recorded, player assigned

static func execute_trade(
    draft_state: Dictionary,
    from_team: String,
    to_team: String,
    picks: Array,
    players: Array
) -> Dictionary:
    # Return NEW draft_state with ownership transferred
```

Create `scripts/core/state/DraftStateMachine.gd`:
```gdscript
enum DraftState { NOT_STARTED, INITIALIZING, RUNNING, PAUSED, COMPLETED }

static func can_transition(from: DraftState, to: DraftState) -> bool:
    # Validate state transitions
```

---

#### 1.2 Season State Management

**Current State:** In-place roster mutations, scattered standings updates

**Files Affected:**
- `scripts/world/NflSeason.gd:108-110` - Direct roster mutations
- `scripts/world/CollegeSeason.gd:99-100, 172-176` - Direct roster updates, draft_eligible appends
- `scripts/world/HighSchoolSeason.gd:76-89` - Direct player property mutations

**Specific Issues Found:**

```gdscript
# NflSeason.gd:108-110 - Direct in-place mutation
roster["players"] = prepared_players
rosters[team_id] = roster

# CollegeSeason.gd:172 - Untracked state change
draft_eligible.append(p)

# HighSchoolSeason.gd:76 - Direct property mutation (violates immutability)
p["hs_year"] = new_year
```

**Recommended Solution:**

Create `scripts/core/state/SeasonStateManager.gd`:
```gdscript
class_name SeasonStateManager

static func advance_season_phase(
    world_state: Dictionary,
    phase: SeasonPhase,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Return updated world_state through pure transformations

static func record_game_result(
    world_state: Dictionary,
    game_result: Dictionary
) -> Dictionary:
    # Atomically update standings, stats, records
```

Create `scripts/core/state/SeasonStateMachine.gd`:
```gdscript
enum SeasonPhase {
    PRE_SEASON, REGULAR_SEASON, PLAYOFFS,
    OFF_SEASON, DRAFT_PREP, FREE_AGENCY
}

static func can_transition(from: SeasonPhase, to: SeasonPhase) -> bool
```

---

#### 1.3 Contract & Free Agency State

**Current State:** Acknowledged in-place mutations, no centralized interface

**Files Affected:**
- `scripts/world/FreeAgency.gd:7-11` - Explicitly documents "Mutates world_state in-place"
- `scripts/world/RosterManagement.gd:9` - Documents "Mutates world_state in-place"
- `scripts/world/ContractLifecycle.gd` - Pure transitions exist but not coordinated

**Specific Issues Found:**

```gdscript
# FreeAgency.gd:7-9 - Explicit mutation acknowledgment (technical debt marker)
## Architecture:
## - Mutates world_state["nfl_rosters"] in-place (same pattern as TradeGenerator)

# RosterManagement.gd has similar acknowledgment
```

**Recommended Solution:**

Create `scripts/core/state/ContractStateManager.gd`:
```gdscript
class_name ContractStateManager

static func execute_signing(
    world_state: Dictionary,
    player_id: String,
    team_id: String,
    contract: Dictionary
) -> Dictionary:
    # Atomic: validate → apply transition → update roster → update cap → notify DataBus

static func release_player(
    world_state: Dictionary,
    player_id: String,
    reason: String
) -> Dictionary:
    # Atomic: validate → apply ContractLifecycle transition → update roster → notify
```

---

### Priority 2: HIGH (Determinism & Testability)

#### 2.1 Draft Eligibility & Pre-Draft Process

**Current State:** Good RNG discipline but scattered flag mutations

**Files Affected:**
- `scripts/world/PreDraftProcess.gd` - Uses `_shuffle_with_rng()` correctly (good!)
- `scripts/world/UnderclassmanDeclarationEngine.gd:37` - Direct `declared_for_draft` flag mutation

**Positive Finding:** PreDraftProcess.gd:779-784 correctly implements deterministic shuffle:
```gdscript
static func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
    for i in range(arr.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var temp = arr[i]
        arr[i] = arr[j]
        arr[j] = temp
```

**Issue:** Flag mutations not going through manager:
```gdscript
# UnderclassmanDeclarationEngine - Sets flag directly
p["declared_for_draft"] = true  # Should go through manager
```

**Recommended Solution:**

Create `scripts/core/state/DraftEligibilityManager.gd`:
```gdscript
class_name DraftEligibilityManager

static func declare_for_draft(
    world_state: Dictionary,
    player_id: String,
    declaration_reason: String
) -> Dictionary:
    # Validate eligibility → apply transition → update world_state → notify DataBus
```

---

#### 2.2 Roster Operations (Trades & Moves)

**Current State:** Explicit mutation documentation (technical debt acknowledged)

**Files Affected:**
- `scripts/world/TradeGenerator.gd:19-23` - Documents "MUTATION CONTRACT: mutates in-place"
- `scripts/pipelines/AdvanceWorldYear.gd:192-915` - 40+ direct world_state mutations

**Specific Issues Found:**

```gdscript
# TradeGenerator.gd:19-23 - Technical debt explicitly documented
## MUTATION CONTRACT: This generator mutates world_state["nfl_rosters"] IN PLACE

# AdvanceWorldYear.gd - Extensive direct mutations
world_state["hs_schools"] = schools      # Line 192
world_state["hs_players"] = hs_players   # Line 205
world_state["colleges"] = colleges        # Line 318
world_state["college_rosters"] = rosters # Line 915
```

**Recommended Solution:**

Create `scripts/core/state/RosterStateManager.gd`:
```gdscript
class_name RosterStateManager

static func execute_trade(
    world_state: Dictionary,
    trade: Dictionary
) -> Dictionary:
    # Validate trade legality → apply transformations → update both rosters → notify

static func add_player_to_roster(
    world_state: Dictionary,
    player_id: String,
    team_id: String,
    collection: String  # "nfl_rosters", "college_rosters", etc.
) -> Dictionary
```

**Critical Refactor:** `AdvanceWorldYear.gd` should call managers instead of direct mutations:
```gdscript
# Instead of:
world_state["hs_players"] = hs_players

# Use:
world_state = PlayerStateManager.update_collection(
    world_state, ["hs_players"], hs_players, "bulk_update"
)
```

---

### Priority 3: MEDIUM (Code Quality)

#### 3.1 Awards & Red Flags

**Files Affected:**
- `scripts/world/CollegeAwardsService.gd` - 1100+ lines with scattered `append()` mutations
- `scripts/world/RedFlagSystem.gd:128` - Direct red flag appends

**Specific Issues Found:**

```gdscript
# RedFlagSystem.gd:128 - Direct mutation
(di["red_flags"] as Array).append(flag)
```

**Recommended Solution:**

Create `scripts/core/state/IntelligenceStateManager.gd`:
```gdscript
class_name IntelligenceStateManager

static func add_red_flag(
    world_state: Dictionary,
    player_id: String,
    flag: Dictionary
) -> Dictionary:
    # Immutable append pattern

static func award_player(
    world_state: Dictionary,
    player_id: String,
    award: Dictionary
) -> Dictionary
```

---

#### 3.2 Player Morale (Already Mostly Pure)

**Current State:** Pure functions exist but not integrated with manager pattern

**File:** `scripts/core/player_agency/PlayerMorale.gd:7` - "Pure, stateless functions"

**Recommended Solution:**

Wrap with `scripts/core/state/PlayerMoraleManager.gd` to coordinate with DataBus:
```gdscript
class_name PlayerMoraleManager

static func update_player_morale(
    world_state: Dictionary,
    player_id: String,
    morale_change: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Call pure function → update world_state → notify DataBus
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
1. Create `DraftStateManager.gd` + `DraftStateMachine.gd`
2. Create `SeasonStateManager.gd` + `SeasonStateMachine.gd`
3. Refactor `NflDraft.gd` to use managers
4. Add tests following `tests/core/state/` pattern

### Phase 2: Contracts & Rosters (Weeks 2-3)
1. Create `ContractStateManager.gd` + `ContractLifecycleStateMachine.gd`
2. Create `RosterStateManager.gd`
3. Refactor `FreeAgency.gd` and `TradeGenerator.gd`
4. Add comprehensive tests

### Phase 3: Pipeline Cleanup (Week 3-4)
1. Refactor `AdvanceWorldYear.gd` to use managers
2. Create `DraftEligibilityManager.gd`
3. Update `PreDraftProcess.gd` and `UnderclassmanDeclarationEngine.gd`

### Phase 4: Polish (Week 4+)
1. Create `IntelligenceStateManager.gd` for awards/red flags
2. Wrap `PlayerMorale.gd` with manager
3. Audit remaining direct mutations

---

## Architectural Principles (Codified)

Based on PR #155, these principles should be documented and enforced:

### 1. Immutability First
```gdscript
# WRONG: Mutating input
func update_player(player: Dictionary) -> void:
    player["age"] = player["age"] + 1

# RIGHT: Return new dictionary
static func increment_age(player: Dictionary) -> Dictionary:
    var new_player := player.duplicate(true)
    new_player["age"] = int(new_player.get("age", 0)) + 1
    return new_player
```

### 2. Explicit RNG for Determinism
```gdscript
# WRONG: Implicit global RNG
func shuffle_pool(pool: Array) -> void:
    pool.shuffle()  # Non-deterministic!

# RIGHT: Explicit RNG parameter
static func shuffle_pool(pool: Array, rng: RandomNumberGenerator) -> Array:
    var result := pool.duplicate()
    _shuffle_with_rng(result, rng)
    return result
```

### 3. Single Point of Mutation
```gdscript
# WRONG: Scattered mutations
world_state["nfl_rosters"][team_id]["players"].append(player)

# RIGHT: Through manager
world_state = RosterStateManager.add_player(world_state, player_id, team_id)
```

### 4. Automatic UI Notification
```gdscript
# Manager automatically notifies DataBus
static func add_player(...) -> Dictionary:
    # ... apply transformation ...
    DataBus.notify_collection_changed("nfl_rosters", "add")
    return updated_world_state
```

---

## Testing Requirements

All new managers must have test coverage matching `tests/core/state/` pattern:

1. **Immutability Tests** - Verify inputs are NEVER modified
2. **Determinism Tests** - Same RNG seed produces identical results
3. **Functionality Tests** - Verify correct behavior
4. **Edge Cases** - Null inputs, empty arrays, boundary values
5. **State Machine Tests** - Verify valid/invalid transitions

---

## Conclusion

PR #155 establishes an excellent foundation. The patterns should be systematically applied across all state-mutating code. The priority order above reflects both architectural debt severity and business impact.

**Estimated Total Effort:** 3-4 weeks for full migration (can be parallelized)

**Risk Assessment:** LOW - Each domain can be migrated independently without breaking others

---

*Review conducted by Architecture Guardian agent*
