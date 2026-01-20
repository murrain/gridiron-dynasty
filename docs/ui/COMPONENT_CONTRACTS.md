# UI Component Contracts

This document defines the standard patterns and contracts for UI components in Gridiron Dynasty.

---

## Architecture Overview

Gridiron Dynasty uses a **smart container / dumb component** pattern:

- **Smart Containers** subscribe to DataBus and manage child components
- **Dumb Components** receive data via methods and emit signals upward
- **Simulation UIs** connect to domain controllers for real-time feedback

---

## Component Types

### Type 1: Smart Container

**Purpose:** Manage data flow and coordinate child components

**Characteristics:**
- Subscribes to DataBus signals
- Calls `initialize()` on child components when data changes
- Handles navigation signals from children
- Manages global UI state (search, filters, tabs)

**Example:** `WorldExplorer`

**Required Implementation:**

```gdscript
extends Control
class_name MySmartContainer

## Subscribe to DataBus signals
func _ready() -> void:
    _connect_databus_signals()

func _connect_databus_signals() -> void:
    # Subscribe to relevant signals
    if not DataBus.collection_changed.is_connected(_on_databus_collection_changed):
        DataBus.collection_changed.connect(_on_databus_collection_changed)

    if not DataBus.world_state_loaded.is_connected(_on_databus_world_state_loaded):
        DataBus.world_state_loaded.connect(_on_databus_world_state_loaded)

## Handle DataBus notifications
func _on_databus_collection_changed(collection_name: String, operation: String) -> void:
    # Determine which child components are affected
    var affected_components := _get_components_affected_by_collection(collection_name)
    _refresh_components(affected_components)

func _on_databus_world_state_loaded() -> void:
    # Full refresh on world state load
    _refresh_all_components()

## Refresh child components
func _refresh_components(components: Array) -> void:
    for component in components:
        if component.has_method("cleanup"):
            component.cleanup()
        if component.has_method("initialize"):
            component.initialize(world_state)  # Push data to child
```

**Best Practices:**
- ✅ DO subscribe to DataBus signals
- ✅ DO map collections/phases to affected child components
- ✅ DO call `cleanup()` before `initialize()` on child components
- ✅ DO avoid double-connecting signals (use `is_connected()` check)
- ❌ DON'T directly modify child component state
- ❌ DON'T mutate world_state (read-only reference)

---

### Type 2: Dumb Component (Panel)

**Purpose:** Display data passed from parent container

**Characteristics:**
- Receives data via `initialize()` method
- Emits signals for user actions (navigation, selection)
- No direct DataBus subscriptions
- Stateless (can be re-initialized at any time)

**Example:** `DraftPanel`, `NflPanel`, `CollegePanel`

**Required Methods:**

```gdscript
extends VBoxContainer
class_name MyDumbPanel

## Required by parent container
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

var world_state: Dictionary = {}
var current_search: String = ""

## REQUIRED: Initialize with world state
## Called by parent when data changes
func initialize(ws: Dictionary) -> void:
    world_state = ws
    _refresh_content()

## OPTIONAL: Filter by search text
## Called by parent when search changes
func filter_by_search(search_text: String) -> void:
    current_search = search_text
    _refresh_content()

## OPTIONAL: Cleanup resources before re-initialization
func cleanup() -> void:
    content_list.clear()
    world_state = {}
    current_search = ""

## Private: Display the data
func _refresh_content() -> void:
    # Render UI based on world_state and current_search
    pass

## Private: Emit signals for user actions
func _on_item_selected(id: String) -> void:
    player_selected.emit(id)  # Parent handles navigation
```

**Best Practices:**
- ✅ DO treat world_state as read-only
- ✅ DO emit signals for user actions
- ✅ DO implement `initialize()`, `filter_by_search()`, `cleanup()`
- ✅ DO create local filtered copies if needed
- ✅ DO handle empty data gracefully (show placeholder text)
- ❌ DON'T subscribe to DataBus directly (parent handles this)
- ❌ DON'T mutate world_state
- ❌ DON'T store reference to parent container
- ❌ DON'T call methods on other components directly

---

### Type 3: Simulation UI

**Purpose:** Provide real-time feedback during simulation

**Characteristics:**
- Connects to domain controller (InteractiveDraft, UDFABiddingEngine, etc.)
- Receives real-time updates via controller signals
- Blocks until user completes action
- Manages transient simulation state

**Example:** `DraftDayUI`, `UDFABiddingUI`

**Required Implementation:**

```gdscript
extends Control
class_name MySimulationUI

signal simulation_completed(results: Dictionary)

## Domain controller reference
var _controller: MyController = null

## Initialize with controller
func initialize(controller: MyController) -> void:
    _controller = controller
    _connect_controller_signals()
    _controller.start()

## Connect to controller signals for real-time feedback
func _connect_controller_signals() -> void:
    _controller.user_action_requested.connect(_on_user_action_requested)
    _controller.event_occurred.connect(_on_event_occurred)
    _controller.simulation_completed.connect(_on_simulation_completed)

## Handle controller signals
func _on_user_action_requested(options: Array) -> void:
    # Display options to user
    # Wait for user selection
    pass

func _on_event_occurred(event_info: Dictionary) -> void:
    # Update UI immediately (ticker, log, etc.)
    pass

func _on_simulation_completed(results: Dictionary) -> void:
    # Emit completion signal to parent
    simulation_completed.emit(results)
```

**Best Practices:**
- ✅ DO connect to domain controller signals
- ✅ DO provide immediate visual feedback for events
- ✅ DO block user until action completes
- ✅ DO emit completion signal when simulation finishes
- ✅ ENSURE controller uses StateManagers (for DataBus notifications)
- ❌ DON'T directly mutate world_state (controller handles this)
- ❌ DON'T bypass controller to make changes

**Critical Requirement:**
The domain controller (InteractiveDraft, UDFABiddingEngine, etc.) **MUST use StateManagers** for all world_state mutations. This ensures DataBus notifications are emitted.

**Example:**
```gdscript
# CORRECT: Controller uses StateManager
func _execute_pick(team_id: String, player: Dictionary, pick_num: int) -> void:
    var result = DraftStateManager.execute_pick(
        _world_state, team_id, player, pick_num
    )
    # DraftStateManager automatically emits DataBus notifications

# WRONG: Direct mutation (no DataBus notifications)
func _execute_pick(team_id: String, player: Dictionary, pick_num: int) -> void:
    _world_state["nfl_rosters"][team_id]["players"].append(player)
    # ❌ No notification - WorldExplorer won't refresh!
```

---

### Type 4: Modal / Dialog

**Purpose:** Transient UI for specific user input

**Characteristics:**
- Created on-demand, destroyed after use
- Receives data via `show_*()` method
- Emits signal with user choice
- Blocks parent until dismissed

**Example:** `UserPickModal`

**Required Implementation:**

```gdscript
extends PanelContainer
class_name MyModal

signal choice_made(result: Dictionary)
signal cancelled()

var _data: Dictionary = {}

## Show the modal with data
func show_modal(data: Dictionary) -> void:
    _data = data
    _populate_ui()
    visible = true

## Hide the modal
func hide_modal() -> void:
    visible = false
    _data = {}

## Handle user action
func _on_confirm_pressed() -> void:
    var result := _build_result()
    choice_made.emit(result)
    hide_modal()

func _on_cancel_pressed() -> void:
    cancelled.emit()
    hide_modal()
```

**Best Practices:**
- ✅ DO accept data via `show_*()` method
- ✅ DO emit signal with user choice
- ✅ DO hide modal after emitting signal
- ✅ DO handle cancellation gracefully
- ❌ DON'T store long-lived state
- ❌ DON'T subscribe to DataBus (transient UI)

---

## DataBus Integration Guide

### When to Subscribe to DataBus

**Subscribe if:**
- ✅ You are a **smart container** managing child components
- ✅ Your component needs to refresh when data changes
- ✅ You coordinate multiple panels/views

**Don't subscribe if:**
- ❌ You are a **dumb component** receiving data from parent
- ❌ You are a **modal** with transient state
- ❌ Your parent already handles DataBus subscriptions

### Available DataBus Signals

```gdscript
## Signal: players_changed
## When: Player data changes for a specific stage
DataBus.players_changed.connect(func(stage: PlayerStage, count: int):
    # Refresh UI showing players at this stage
)

## Signal: collection_changed
## When: World state collection modified
DataBus.collection_changed.connect(func(collection_name: String, operation: String):
    # Refresh UI showing this collection
    match collection_name:
        "draft_pool":
            _refresh_draft_panel()
        "nfl_rosters":
            _refresh_nfl_panel()
)

## Signal: phase_completed
## When: Simulation phase completes
DataBus.phase_completed.connect(func(phase_id: String, year: int):
    # Refresh affected panels
    match phase_id:
        "nfl_draft":
            _refresh_draft_and_nfl_panels()
        "nfl_season":
            _refresh_nfl_panel()
)

## Signal: world_state_loaded
## When: World state loaded or initialized
DataBus.world_state_loaded.connect(func():
    # Full refresh of all panels
    _refresh_all_panels()
)
```

### Common Collection Names

| Collection | Description | Typical UI |
|------------|-------------|-----------|
| `draft_pool` | Draft-eligible players | DraftPanel |
| `nfl_rosters` | NFL team rosters | NflPanel |
| `nfl_teams` | NFL team data | NflPanel |
| `colleges` | College team data | CollegePanel |
| `college_rosters` | College rosters | CollegePanel |
| `hs_players` | High school players | HsPanel |
| `retired_players` | Retired players | RetiredPanel |
| `contracts` | Contract data | RosterPanel |
| `free_agents` | Free agent pool | FreeAgencyPanel |

### Common Phase IDs

| Phase | Description | Affected UI |
|-------|-------------|-------------|
| `nfl_draft` | NFL draft | DraftPanel, NflPanel |
| `college_season` | College season | CollegePanel |
| `nfl_season` | NFL season | NflPanel |
| `hs_generation` | HS player generation | HsPanel |
| `roster_management` | Roster cuts/signings | NflPanel |
| `nfl_free_agency` | Free agency | FreeAgencyPanel, NflPanel |

---

## StateManager Integration (For Simulation Code)

If you're writing simulation code that mutates world_state, you **MUST use StateManagers**.

### Available StateManagers

```gdscript
## Draft operations
const DraftStateManager = preload("res://scripts/core/state/DraftStateManager.gd")

# Execute a draft pick
var result := DraftStateManager.execute_pick(
    world_state, team_id, player, pick_number
)

## Contract operations
const ContractStateManager = preload("res://scripts/core/state/ContractStateManager.gd")

# Sign a player
var result := ContractStateManager.execute_signing(
    world_state, team_id, player_id, contract_terms
)

## Season operations
const SeasonStateManager = preload("res://scripts/core/state/SeasonStateManager.gd")

# Record game result
var result := SeasonStateManager.record_game_result(
    world_state, game_id, home_score, away_score
)

## Player operations
const PlayerStateManager = preload("res://scripts/core/state/PlayerStateManager.gd")

# Advance players one year
var result := PlayerStateManager.advance_players_one_year(
    world_state, collection_path, context, configs, rng
)
```

### Why Use StateManagers?

1. **Automatic DataBus notifications** - UI updates automatically
2. **State machine validation** - Prevents invalid state transitions
3. **Atomic updates** - All-or-nothing mutations
4. **Testability** - Pure functions with predictable outputs
5. **Auditability** - All mutations go through one place

### Don't Do This (Anti-Pattern)

```gdscript
# ❌ WRONG: Direct mutation (no DataBus notification)
func sign_player(world_state: Dictionary, team_id: String, player: Dictionary) -> void:
    world_state["nfl_rosters"][team_id]["players"].append(player)
    world_state["cap_space"][team_id] -= player["contract"]["cap_hit"]
    # UI won't refresh! WorldExplorer is now stale!

# ✅ CORRECT: Use StateManager
func sign_player(world_state: Dictionary, team_id: String, player: Dictionary) -> void:
    var result := ContractStateManager.execute_signing(
        world_state, team_id, player["id"], player["contract"]
    )
    # ContractStateManager automatically:
    # 1. Updates world_state atomically
    # 2. Emits DataBus.collection_changed("nfl_rosters", "update")
    # 3. Emits DataBus.collection_changed("cap_space", "update")
    # 4. WorldExplorer automatically refreshes!
```

---

## Testing Your UI Component

### Checklist for Dumb Components

```gdscript
func test_my_panel() -> void:
    var panel = MyPanel.new()

    # Test 1: Initialize with empty data
    panel.initialize({})
    assert_true(panel.is_empty_state_displayed())

    # Test 2: Initialize with valid data
    var test_data := _create_test_world_state()
    panel.initialize(test_data)
    assert_equal(panel.get_item_count(), 10)

    # Test 3: Filter by search
    panel.filter_by_search("test")
    assert_equal(panel.get_item_count(), 3)

    # Test 4: Cleanup
    panel.cleanup()
    assert_equal(panel.get_item_count(), 0)

    # Test 5: Signal emission
    var signal_emitted := false
    panel.player_selected.connect(func(id): signal_emitted = true)
    panel._simulate_user_click(0)
    assert_true(signal_emitted)
```

### Checklist for Smart Containers

```gdscript
func test_my_container() -> void:
    var container = MyContainer.new()
    container.load_world_state(_create_test_world_state())

    # Test 1: DataBus signal connections
    assert_true(DataBus.collection_changed.is_connected(
        container._on_databus_collection_changed
    ))

    # Test 2: Child panel refresh on DataBus signal
    var panel_refreshed := false
    var panel = container.get_child_panel()
    var original_data := panel.world_state

    DataBus.notify_collection_changed("nfl_rosters", "update")
    await get_tree().process_frame  # Wait for signal processing

    assert_not_equal(panel.world_state, original_data)  # Panel was refreshed

    # Test 3: Cleanup on refresh
    var cleanup_called := false
    panel.cleanup.connect(func(): cleanup_called = true)

    DataBus.notify_world_state_loaded()
    await get_tree().process_frame

    assert_true(cleanup_called)
```

---

## Common Pitfalls

### Pitfall #1: Direct World State Mutation

```gdscript
# ❌ WRONG
func add_player_to_roster(world_state: Dictionary, team_id: String, player: Dictionary) -> void:
    world_state["nfl_rosters"][team_id]["players"].append(player)
    # No DataBus notification - UI won't update!

# ✅ CORRECT
func add_player_to_roster(world_state: Dictionary, team_id: String, player: Dictionary) -> void:
    var result := ContractStateManager.execute_signing(...)
    # StateManager emits DataBus notification automatically
```

### Pitfall #2: Dumb Component Subscribing to DataBus

```gdscript
# ❌ WRONG: Dumb component subscribing to DataBus
class_name MyPanel extends VBoxContainer

func _ready() -> void:
    DataBus.collection_changed.connect(_on_collection_changed)  # ❌ Don't do this!

# ✅ CORRECT: Parent subscribes, calls initialize() on child
class_name MyContainer extends Control

func _ready() -> void:
    DataBus.collection_changed.connect(_on_collection_changed)

func _on_collection_changed(collection: String, op: String) -> void:
    my_panel.initialize(world_state)  # ✅ Parent refreshes child
```

### Pitfall #3: Not Checking for Double-Connections

```gdscript
# ❌ WRONG: May connect multiple times
func _connect_signals() -> void:
    DataBus.collection_changed.connect(_on_collection_changed)
    # If called twice, signal will fire twice!

# ✅ CORRECT: Check before connecting
func _connect_signals() -> void:
    if not DataBus.collection_changed.is_connected(_on_collection_changed):
        DataBus.collection_changed.connect(_on_collection_changed)
```

### Pitfall #4: Storing Stale References

```gdscript
# ❌ WRONG: Storing reference to world_state data
class_name MyPanel

var cached_players: Array = []

func initialize(ws: Dictionary) -> void:
    cached_players = ws["players"]  # ❌ This is a reference, may become stale!

# ✅ CORRECT: Always query fresh data
class_name MyPanel

func initialize(ws: Dictionary) -> void:
    world_state = ws  # Store reference to world_state

func _refresh() -> void:
    var players = world_state.get("players", [])  # ✅ Fresh query each time
```

---

## Summary

### Component Type Quick Reference

| Type | DataBus Subscription | Data Flow | Example |
|------|---------------------|-----------|---------|
| Smart Container | ✅ Yes | Receives DataBus → Pushes to children | WorldExplorer |
| Dumb Component | ❌ No | Receives via `initialize()` | DraftPanel |
| Simulation UI | ❌ No (uses controller signals) | Receives from controller | DraftDayUI |
| Modal | ❌ No | Receives via `show_*()` | UserPickModal |

### Key Principles

1. **Smart containers subscribe to DataBus, dumb components don't**
2. **All world_state mutations must go through StateManagers**
3. **StateManagers automatically emit DataBus notifications**
4. **Dumb components emit signals upward, never call methods downward**
5. **Always treat world_state as read-only in UI code**

---

**For questions or clarifications, see:**
- `docs/ui/UI_DATABUS_INTEGRATION_AUDIT.md` - Full audit report
- `docs/architecture/DATABUS_NOTIFICATION_STRATEGY.md` - Notification patterns
- `autoloads/DataBus.gd` - DataBus implementation

---

**END OF COMPONENT CONTRACTS**
