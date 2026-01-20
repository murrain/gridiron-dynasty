# Edge Cases: Direct Mutations Still Present

## Overview

After refactoring NflDraft.gd to use DraftStateManager, a few direct `world_state` mutations remain. These are **intentional exceptions** for edge cases that don't fit the core draft flow.

## Acceptable Direct Mutations

### 1. Roster Cut Mid-Draft (Line 1507)

**Location**: `_release_player_to_undrafted_pool()`

**Code**:
```gdscript
world_state["undrafted_pool"] = undrafted_pool
```

**Rationale**:
- This is a roster management operation triggered by position overstocking
- Occurs mid-draft when a player is cut due to roster composition constraints
- Not part of the core draft pick execution flow
- Edge case: Adding a player back to undrafted pool after they were briefly on a roster

**Alternative**: Could add `DraftStateManager.release_player_during_draft()`, but this adds complexity for a rare operation.

**Decision**: Keep as direct mutation (documented exception)

### 2. Compensatory Pick Ownership (Lines 2056-2057)

**Location**: `insert_compensatory_picks()`

**Code**:
```gdscript
world_state["draft_pick_ownership"] = {}
var ownership: Dictionary = world_state["draft_pick_ownership"]
```

**Rationale**:
- Compensatory picks are generated dynamically at draft time
- They need to be added to ownership structure after regular picks are allocated
- Static function that operates on ownership without draft state context
- Pre-existing pattern from Feature 4 (Compensatory Picks)

**Alternative**: Could route through DraftStateManager, but this function is also called from other contexts.

**Decision**: Keep as direct mutation (documented exception)

### 3. Free Agent Transaction Tracking (Lines 1798-1800)

**Location**: `track_free_agent_transactions()`

**Code**:
```gdscript
world_state["fa_transaction_tracking"] = {}
var tracking: Dictionary = world_state["fa_transaction_tracking"]
```

**Rationale**:
- This is a different system (Free Agency compensatory pick tracking)
- Not part of the draft execution flow
- Static function that operates independently
- Would belong in a future `FreeAgencyStateManager` when that system is refactored

**Alternative**: Wait for FreeAgency refactoring, then route through `FreeAgencyStateManager`.

**Decision**: Keep as direct mutation (will be addressed in future refactoring)

## Summary

| Location | Function | System | Status |
|----------|----------|--------|--------|
| Line 1507 | `_release_player_to_undrafted_pool()` | Roster Management | Acceptable exception |
| Lines 2056-2057 | `insert_compensatory_picks()` | Compensatory Picks | Acceptable exception |
| Lines 1798-1800 | `track_free_agent_transactions()` | Free Agency Tracking | Future refactoring |

## Core Draft Flow: 100% Via DraftStateManager

The **core draft execution flow** has zero direct mutations:

✅ Draft initialization → `DraftStateManager.initialize_draft()`
✅ Pick execution → `DraftStateManager.execute_pick()`
✅ Undrafted storage → `DraftStateManager.store_undrafted_players()`
✅ Draft history → `DraftStateManager.record_draft_history()`

The exceptions above are utility/helper functions that operate on **related but separate** concerns:
- Roster composition enforcement (roster management)
- Dynamic pick allocation (compensatory system)
- Cross-system data tracking (free agency)

## Future Work

When refactoring adjacent systems, consider:

1. **RosterManagement** → Create `RosterStateManager.release_player()`
   - Would handle the roster cut case
   - Would emit proper DataBus notifications

2. **FreeAgency** → Create `FreeAgencyStateManager`
   - Would handle FA transaction tracking
   - Would integrate with compensatory pick system

3. **CompensatoryPicks** → Create `CompensatoryPickManager`
   - Would handle dynamic pick allocation
   - Would integrate with draft ownership

## Verification

To verify core draft flow uses no direct mutations:

```bash
# Should find only the 3 exceptions documented above
grep -n 'world_state\[' scripts/world/NflDraft.gd | grep -v 'world_state.get' | grep -v 'world_state.has'
```

Expected results:
- Line 1507: `_release_player_to_undrafted_pool` (roster management)
- Lines 2056-2057: `insert_compensatory_picks` (comp pick system)
- Lines 1798-1800: `track_free_agent_transactions` (FA tracking)

All other mutations go through DraftStateManager.

---

**Conclusion**: The refactoring successfully eliminates direct mutations from the **core draft flow** while preserving direct mutations for **edge cases** that belong to separate systems. This is architecturally sound and follows the principle of incremental refactoring.
