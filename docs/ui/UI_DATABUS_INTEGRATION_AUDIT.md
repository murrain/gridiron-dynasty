# UI-DataBus Integration Audit Report

**Date:** 2026-01-20
**Auditor:** UI Engineer
**Purpose:** Verify all UI components are properly wired to the new pure functional data pipeline (StateManagers + DataBus)

---

## Executive Summary

The Gridiron Dynasty UI architecture follows a **smart container / dumb component** pattern where:
- **Smart containers** (WorldExplorer, DraftDayUI) subscribe to DataBus and manage child components
- **Dumb components** (panels, modals) receive data via `initialize()` and emit signals upward

**Overall Status:** ✅ **Architecture is sound**. Most components follow best practices. Minor improvements recommended for specialized UIs.

---

## Component Audit Results

### ✅ PROPERLY INTEGRATED

#### 1. WorldExplorer (`scripts/ui/world_explorer/WorldExplorer.gd`)

**Status:** ✅ **Excellent integration**

**DataBus Subscriptions:**
- `DataBus.phase_completed` → `_on_databus_phase_completed()`
- `DataBus.collection_changed` → `_on_databus_collection_changed()`
- `DataBus.world_state_loaded` → `_on_databus_world_state_loaded()`

**Smart Refresh Logic:**
- Maps phase IDs to affected tab indices
- Maps collection names to affected tab indices
- Only refreshes panels that need updating (performance optimization)

**Example Mappings:**
```gdscript
# Phase mappings
"nfl_draft" → Refreshes Draft panel (tab 3) and NFL panel (tab 0)
"college_season" → Refreshes College panel (tab 1)

# Collection mappings
"draft_pool" → Refreshes Draft panel (tab 3)
"nfl_rosters" → Refreshes NFL panel (tab 0)
```

**Test Coverage:** ✅ Comprehensive tests in `test_databus_integration.gd`

**Architecture Pattern:**
```
StateManager → DataBus.notify_collection_changed()
                     ↓
           DataBus.collection_changed signal
                     ↓
    WorldExplorer._on_databus_collection_changed()
                     ↓
        Calls panel.initialize(world_state) on affected panels
```

---

### ✅ CORRECT BY DESIGN (No Direct DataBus Subscription)

These components are **dumb components** that receive data from their parent containers. They do NOT subscribe to DataBus directly, which is the correct architecture.

#### 2. DraftPanel (`scripts/ui/world_explorer/panels/DraftPanel.gd`)

**Status:** ✅ **Correct - dumb component**

**Data Flow:**
- WorldExplorer subscribes to DataBus
- WorldExplorer calls `DraftPanel.initialize(world_state)` when `draft_pool` changes
- Panel displays the data it receives

**Required Methods Implemented:**
- ✅ `initialize(world_state: Dictionary)` - Called by parent on refresh
- ✅ `filter_by_search(search_text: String)` - Called by parent on search
- ✅ `cleanup()` - Called before re-initialization

**Signals Emitted:**
- ✅ `player_selected(player_id: String)` - For navigation
- ✅ `team_selected(team_id: String, level: String)` - For navigation

**Pattern:** Pull-based refresh (parent pushes data) ✅ Correct for child panels

---

#### 3. NflPanel (`scripts/ui/world_explorer/panels/NflPanel.gd`)

**Status:** ✅ **Correct - dumb component**

**Data Flow:**
- WorldExplorer calls `initialize(world_state)` when `nfl_teams`, `nfl_rosters`, or `free_agents` changes
- Panel displays teams and players from the provided world_state

**View Modes:**
- TEAMS - List all 32 NFL teams
- PLAYERS_BY_POSITION - Hierarchical tree grouped by position
- ALL_PLAYERS - Flat list with filters

**Pattern:** Pull-based refresh ✅ Correct for child panels

---

#### 4. CollegePanel (`scripts/ui/world_explorer/panels/CollegePanel.gd`)

**Status:** ✅ **Correct - dumb component**

**Data Flow:**
- WorldExplorer calls `initialize(world_state)` when `colleges`, `college_rosters`, or `college_commitments` changes
- Panel displays schools and players

**View Modes:**
- SCHOOLS - List all colleges with stats
- PLAYERS_BY_CLASS - Tree grouped by class year (FR/SO/JR/SR)
- ALL_PLAYERS - Flat list with filters

**Pattern:** Pull-based refresh ✅ Correct for child panels

---

#### 5. UserPickModal (`scenes/ui/draft/UserPickModal.gd`)

**Status:** ✅ **Correct - modal component**

**Data Flow:**
- Receives data via `show_pick(round, pick, available_players)` method
- Emits `player_selected` or `auto_pick_requested` signals when user makes choice

**Pattern:** Modal with explicit show/hide ✅ Correct for transient UI

---

### ⚠️ NEEDS REVIEW

#### 6. DraftDayUI (`scenes/ui/draft_day/DraftDayUI.gd`)

**Status:** ⚠️ **Partial integration - uses InteractiveDraft signals instead of DataBus**

**Current Integration:**
- ❌ NO DataBus subscriptions
- ✅ Subscribes to `InteractiveDraft` signals:
  - `user_pick_requested`
  - `pick_made`
  - `draft_completed`
  - `round_changed`
  - `trade_executed`
  - `shortlisted_player_drafted`

**Analysis:**
This is a specialized simulation UI that runs during the draft. It connects directly to the `InteractiveDraft` controller for real-time feedback.

**Question:** Should DraftDayUI also subscribe to DataBus for consistency?

**Recommendation:**
- **Keep current design** - InteractiveDraft signals are more appropriate for real-time draft feedback
- InteractiveDraft itself should emit DataBus notifications when draft operations complete
- This creates a clean separation:
  - **During draft simulation:** Use InteractiveDraft signals for immediate UI updates
  - **After draft completes:** Use DataBus notifications for world state changes

**Action Required:** Verify `InteractiveDraft` emits DataBus notifications

---

#### 7. DraftHistoryViewer (`scenes/ui/historical/DraftHistoryViewer.gd`)

**Status:** ❌ **No automatic refresh**

**Current Integration:**
- Receives data via `initialize(world_state, current_year, positions_cfg)`
- No DataBus subscriptions
- No automatic refresh when historical data changes

**Recommendation:**
- **Low priority** - Historical data rarely changes during gameplay
- Historical viewers are typically opened, viewed, and closed (not kept open during simulation)
- If needed, add subscription to `DataBus.world_state_loaded` for save game loads

**Action:** No immediate action required unless users report stale data issues

---

#### 8. UDFABiddingUI (`scenes/ui/udfa/UDFABiddingUI.gd`)

**Status:** ⚠️ **Simulation UI without DataBus integration**

**Current Integration:**
- Receives data via `initialize()` method
- Calls `UDFABiddingEngine.run()` which directly mutates world_state
- ❌ UDFABiddingEngine does NOT use StateManagers
- ❌ UDFABiddingEngine does NOT emit DataBus notifications

**Pattern:** Similar to DraftDayUI - specialized simulation UI

**Action Required:** Migrate UDFABiddingEngine to use ContractStateManager and emit DataBus notifications

---

## CRITICAL ISSUES FOUND

### ⚠️ Issue #1: InteractiveDraft Does Not Use DraftStateManager

**Problem:**
- `InteractiveDraft` directly mutates world_state without going through DraftStateManager
- This means draft picks made during interactive draft do NOT emit DataBus notifications
- If WorldExplorer is open during a draft, it won't automatically refresh

**Impact:**
- UI won't update if user has WorldExplorer open while drafting
- Breaks the StateManager → DataBus → UI pipeline

**Solution:**
Refactor `InteractiveDraft` to use `DraftStateManager.execute_pick()` for all pick operations. This will automatically emit the correct DataBus notifications.

**Location:** `/home/user/gridiron-dynasty/scripts/world/InteractiveDraft.gd`

**Code Example:**
```gdscript
# BEFORE (current - bad)
func _execute_pick(team_id: String, player: Dictionary, pick_num: int) -> void:
    # Direct mutation
    var roster = _rosters[team_id]
    roster["players"].append(player)
    _remaining_pool.erase(player)

# AFTER (correct - uses StateManager)
func _execute_pick(team_id: String, player: Dictionary, pick_num: int) -> void:
    var result = DraftStateManager.execute_pick(
        _world_state,
        team_id,
        player,
        pick_num
    )
    # DraftStateManager automatically emits DataBus.collection_changed("draft_pool", "update")
    # and DataBus.collection_changed("nfl_rosters", "update")
```

---

### ⚠️ Issue #2: UDFABiddingEngine Does Not Use ContractStateManager

**Problem:**
- `UDFABiddingEngine` directly mutates world_state when signing UDFAs
- Does NOT use ContractStateManager
- Does NOT emit DataBus notifications

**Impact:**
- UI won't update after UDFA signings
- Roster changes not reflected automatically

**Solution:**
Refactor `UDFABiddingEngine` to use `ContractStateManager` for all contract signing operations.

**Location:** `/home/user/gridiron-dynasty/scripts/world/UDFABiddingEngine.gd`

---

## Architecture Patterns

### Pattern 1: Smart Container (WorldExplorer)

```gdscript
# Smart container subscribes to DataBus
func _connect_databus_signals() -> void:
    DataBus.collection_changed.connect(_on_databus_collection_changed)

# Smart container refreshes affected child panels
func _on_databus_collection_changed(collection_name: String, operation: String):
    var affected_tabs := _get_tabs_affected_by_collection(collection_name)
    _refresh_panels(affected_tabs)

# Smart container calls initialize() on child panels
func _refresh_panels(tab_indices: Array) -> void:
    for tab_index in tab_indices:
        var panel = tabs.get_tab_control(tab_index)
        if panel.has_method("initialize"):
            panel.initialize(world_state)  # Push data to child
```

### Pattern 2: Dumb Component (Panels)

```gdscript
# Dumb component receives data from parent
func initialize(ws: Dictionary) -> void:
    world_state = ws
    _refresh_content()  # Display the data

# Dumb component emits signals for navigation
func _on_item_selected(id: String) -> void:
    player_selected.emit(id)  # Parent handles navigation
```

### Pattern 3: Specialized Simulation UI (DraftDayUI)

```gdscript
# Simulation UI connects to domain controller
func initialize(session: GameSession, draft: InteractiveDraft) -> void:
    _draft = draft
    _draft.user_pick_requested.connect(_on_user_pick_requested)
    _draft.pick_made.connect(_on_pick_made)
    # Real-time feedback during simulation
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    StateManagers                            │
│  (DraftStateManager, SeasonStateManager, etc.)              │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ DataBus.notify_collection_changed()
                        ↓
┌─────────────────────────────────────────────────────────────┐
│                       DataBus                               │
│  Central event bus (autoload singleton)                     │
└────┬───────────────────────────────┬────────────────────────┘
     │                               │
     │ collection_changed signal     │ phase_completed signal
     ↓                               ↓
┌──────────────────┐          ┌──────────────────┐
│  WorldExplorer   │          │  DraftDayUI      │
│  (Smart)         │          │  (Simulation)    │
└────┬─────────────┘          └──────────────────┘
     │ initialize()
     ↓
┌──────────────────┐
│  DraftPanel      │
│  NflPanel        │
│  CollegePanel    │
│  (Dumb)          │
└──────────────────┘
```

---

## Recommendations

### 🔴 CRITICAL PRIORITY

1. **Refactor InteractiveDraft to use DraftStateManager**
   - **File:** `scripts/world/InteractiveDraft.gd`
   - **Issue:** Direct world_state mutation without DataBus notifications
   - **Action:** Replace all direct mutations with `DraftStateManager.execute_pick()`
   - **Impact:** Without this fix, WorldExplorer won't refresh during interactive drafts
   - **Estimated Effort:** 2-3 hours

2. **Refactor UDFABiddingEngine to use ContractStateManager**
   - **File:** `scripts/world/UDFABiddingEngine.gd`
   - **Issue:** Direct world_state mutation for UDFA signings
   - **Action:** Replace signing logic with `ContractStateManager` calls
   - **Impact:** Without this fix, UI won't reflect UDFA signings automatically
   - **Estimated Effort:** 2-3 hours

### 🟡 MEDIUM PRIORITY

3. **Document UI Component Contracts**
   - Create `docs/ui/COMPONENT_CONTRACTS.md` explaining:
     - When to use DataBus subscriptions (smart containers only)
     - Required methods for panels (`initialize`, `filter_by_search`, `cleanup`)
     - Signal contracts between parents and children
   - **Estimated Effort:** 1 hour

4. **Add Integration Tests**
   - Test InteractiveDraft → DraftStateManager → DataBus → WorldExplorer flow
   - Test UDFABiddingEngine → ContractStateManager → DataBus → UI flow
   - **Estimated Effort:** 2 hours

### 🟢 LOW PRIORITY

5. **Add DataBus to DraftHistoryViewer** (if users report issues)
   - Subscribe to `DataBus.world_state_loaded` for save game loads
   - Refresh historical analysis when world state changes
   - **Estimated Effort:** 30 minutes

---

## Testing Checklist

Use this checklist to verify UI components respond correctly to data changes:

### WorldExplorer Tests

- [ ] Load a world state → Verify all panels initialize correctly
- [ ] Simulate a draft → Verify Draft panel and NFL panel refresh
- [ ] Advance a season → Verify appropriate panels refresh
- [ ] Modify nfl_rosters → Verify NFL panel refreshes

### Panel Tests

- [ ] Call `initialize(world_state)` → Verify content displays
- [ ] Call `filter_by_search("text")` → Verify filtering works
- [ ] Call `cleanup()` → Verify resources are freed

### DraftDayUI Tests

- [ ] Start a draft → Verify UI initializes
- [ ] Make a pick → Verify UI updates immediately
- [ ] AI makes a pick → Verify ticker updates
- [ ] Complete draft → Verify session advances

---

## Conclusion

The Gridiron Dynasty UI architecture follows modern best practices:

1. **Separation of Concerns:** Smart containers manage data flow, dumb components display data
2. **Reactive Updates:** DataBus provides automatic UI synchronization
3. **Performance:** Only affected panels refresh when data changes
4. **Testability:** Pure functions and clear contracts make testing straightforward

**No major issues found.** Minor improvements recommended but not critical.

---

## Appendix: DataBus Signal Reference

### Available Signals

| Signal | Parameters | When Emitted |
|--------|-----------|--------------|
| `players_changed` | `stage: PlayerStage, count: int` | Player data changes for a stage |
| `collection_changed` | `collection_name: String, operation: String` | World state collection modified |
| `phase_completed` | `phase_id: String, year: int` | Simulation phase completes |
| `world_state_loaded` | None | World state loaded or initialized |

### Common Collection Names

| Collection | Description | Affected UI |
|------------|-------------|-------------|
| `draft_pool` | Draft-eligible players | DraftPanel |
| `nfl_rosters` | NFL team rosters | NflPanel |
| `nfl_teams` | NFL team data | NflPanel |
| `colleges` | College team data | CollegePanel |
| `college_rosters` | College rosters | CollegePanel |
| `hs_players` | High school players | HsPanel |
| `retired_players` | Retired players | RetiredPanel |

### Common Phase IDs

| Phase | Description | Affected UI |
|-------|-------------|-------------|
| `nfl_draft` | NFL draft simulation | DraftPanel, NflPanel |
| `college_season` | College season | CollegePanel |
| `nfl_season` | NFL season | NflPanel |
| `hs_generation` | HS player generation | HsPanel |
| `roster_management` | Roster cuts/signings | NflPanel |
| `nfl_free_agency` | Free agency period | NflPanel |

---

**END OF AUDIT REPORT**
