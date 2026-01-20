# ReactivePanel Guide

**Author:** Engineering Protocols
**Last Updated:** 2026-01-20
**Status:** Active

---

## Overview

`ReactivePanel` and `ReactivePanelContainer` are base classes that simplify building reactive UI components. They automatically handle DataBus subscriptions, filter notifications to relevant collections, and ensure proper cleanup.

### Benefits

- **Less Boilerplate:** No manual DataBus subscription code
- **Filtered Notifications:** Only receive events for collections you care about
- **Automatic Cleanup:** No memory leaks from forgotten disconnects
- **Consistent Pattern:** All reactive panels follow the same structure
- **Self-Documenting:** Clear intent through `_get_subscribed_collections()`

### Trade-offs

- **Smart Container Only:** Not suitable for dumb components
- **Global Subscription:** Subscribes at panel level (not per-item)
- **Limited Filtering:** Only filters by collection name (not operation type)

---

## When to Use ReactivePanel

### ✅ Use ReactivePanel When

1. **Your panel is a smart container**
   - Manages child components
   - Coordinates multiple views
   - Top-level coordinator in your UI hierarchy

2. **Your panel displays world_state data**
   - Shows rosters, teams, players, contracts, etc.
   - Needs to refresh when specific collections change
   - Queries world_state for data

3. **Your panel needs automatic refresh**
   - Should update when simulation runs
   - Should reflect changes made elsewhere in the UI
   - Should stay in sync with world_state

### ❌ DON'T Use ReactivePanel When

1. **Your panel is a dumb component**
   - Receives data from parent via `initialize()`
   - Parent already subscribes to DataBus
   - Would create double-subscription

2. **Your panel is a modal/dialog**
   - Transient UI with short lifespan
   - Receives data via `show_modal()`
   - Doesn't need to track world_state changes

3. **Your panel is a simulation UI**
   - Receives updates from domain controller signals
   - Short-lived, task-specific
   - Not a general-purpose data viewer

4. **Your parent already handles DataBus**
   - Avoid duplicate subscriptions
   - Let parent coordinate refresh
   - Follow smart container / dumb component pattern

---

## Basic Usage

### 1. Extend ReactivePanel

```gdscript
extends ReactivePanel
class_name RosterPanel

@onready var player_list: ItemList = $PlayerList
@onready var cap_label: Label = $CapLabel

var current_team_id: String = ""
```

### 2. Declare Subscriptions

Override `_get_subscribed_collections()` to specify which collections to watch:

```gdscript
func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters", "contracts"]
```

### 3. Handle Data Changes

Override `_on_data_changed()` to refresh your UI:

```gdscript
func _on_data_changed(collection: String, operation: String) -> void:
    match collection:
        "nfl_rosters":
            _refresh_roster_list()
        "contracts":
            _refresh_cap_space()
```

### 4. Handle World Load

Override `_on_world_state_loaded()` for full refresh:

```gdscript
func _on_world_state_loaded() -> void:
    _refresh_all()
```

### 5. Initialize with Data

Call `initialize()` to set initial world_state:

```gdscript
func initialize(ws: Dictionary) -> void:
    super.initialize(ws)  # IMPORTANT: Call super first
    _refresh_all()

func _refresh_all() -> void:
    _refresh_roster_list()
    _refresh_cap_space()
```

---

## Complete Example: NFLRosterPanel

```gdscript
extends ReactivePanel
class_name NFLRosterPanel

## Displays NFL roster for a selected team with automatic refresh.
##
## Subscribes to:
## - nfl_rosters: Player additions, cuts, trades
## - contracts: Contract updates affecting cap space

@onready var player_list: ItemList = $ScrollContainer/PlayerList
@onready var cap_label: Label = $Header/CapSpace
@onready var team_name_label: Label = $Header/TeamName

var current_team_id: String = ""


# ============================================================================
# REACTIVE PANEL OVERRIDES
# ============================================================================

func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters", "contracts"]


func _on_data_changed(collection: String, operation: String) -> void:
    # Refresh affected sections
    match collection:
        "nfl_rosters":
            _refresh_roster_list()
        "contracts":
            _refresh_cap_space()


func _on_world_state_loaded() -> void:
    # Full refresh when world changes
    _refresh_all()


func initialize(ws: Dictionary) -> void:
    super.initialize(ws)
    _refresh_all()


# ============================================================================
# PUBLIC API
# ============================================================================

## Set the team to display
func set_team(team_id: String) -> void:
    if team_id == current_team_id:
        return

    current_team_id = team_id
    _refresh_all()


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _refresh_all() -> void:
    _refresh_team_name()
    _refresh_roster_list()
    _refresh_cap_space()


func _refresh_team_name() -> void:
    var teams = world_state.get("nfl_teams", [])
    var team = teams.filter(func(t): return t["id"] == current_team_id)

    if team.is_empty():
        team_name_label.text = "Unknown Team"
        return

    team_name_label.text = team.front()["name"]


func _refresh_roster_list() -> void:
    player_list.clear()

    if current_team_id.is_empty():
        return

    var rosters = world_state.get("nfl_rosters", {})
    var roster = rosters.get(current_team_id, {})
    var players = roster.get("players", [])

    for player in players:
        var text = "%s - %s (%d)" % [
            player["name"],
            player["position"],
            player["overall_rating"]
        ]
        player_list.add_item(text)

    if players.is_empty():
        player_list.add_item("[No Players]")


func _refresh_cap_space() -> void:
    if current_team_id.is_empty():
        cap_label.text = "Cap Space: N/A"
        return

    var contracts = world_state.get("contracts", {})
    var team_contracts = contracts.get(current_team_id, [])

    var total_cap_hit = 0
    for contract in team_contracts:
        total_cap_hit += contract.get("cap_hit", 0)

    var cap_limit = 200_000_000  # Should come from config
    var cap_space = cap_limit - total_cap_hit

    cap_label.text = "Cap Space: $%s" % _format_money(cap_space)


func _format_money(amount: int) -> String:
    return "%d M" % (amount / 1_000_000)
```

---

## Advanced Patterns

### Pattern 1: Conditional Refresh

Only refresh if the change affects your current view:

```gdscript
func _on_data_changed(collection: String, operation: String) -> void:
    # Only refresh if we're showing this team
    if current_team_id.is_empty():
        return

    match collection:
        "nfl_rosters":
            # Check if the change affects our team
            # (This is a simple implementation; you may need metadata)
            _refresh_roster_list()
```

### Pattern 2: Debounced Refresh

Avoid excessive refreshes for bulk operations:

```gdscript
var _refresh_timer: Timer = null
var _pending_collections: Array[String] = []

func _ready() -> void:
    super._ready()
    _refresh_timer = Timer.new()
    _refresh_timer.wait_time = 0.1
    _refresh_timer.one_shot = true
    _refresh_timer.timeout.connect(_execute_pending_refresh)
    add_child(_refresh_timer)

func _on_data_changed(collection: String, operation: String) -> void:
    if collection not in _pending_collections:
        _pending_collections.append(collection)

    _refresh_timer.start()

func _execute_pending_refresh() -> void:
    for collection in _pending_collections:
        match collection:
            "nfl_rosters":
                _refresh_roster_list()
            "contracts":
                _refresh_cap_space()

    _pending_collections.clear()
```

### Pattern 3: Granular Operation Handling

Handle different operations differently:

```gdscript
func _on_data_changed(collection: String, operation: String) -> void:
    match collection:
        "nfl_rosters":
            match operation:
                "insert":
                    _add_player_to_list()  # Incremental update
                "delete":
                    _remove_player_from_list()  # Incremental update
                "bulk_update":
                    _refresh_roster_list()  # Full refresh
```

### Pattern 4: Multi-Panel Coordination

Use ReactivePanel in a parent container that coordinates multiple child panels:

```gdscript
extends ReactivePanel
class_name TeamManagementScreen

@onready var roster_panel: RosterPanel = $HSplitContainer/RosterPanel
@onready var contract_panel: ContractPanel = $HSplitContainer/ContractPanel
@onready var depth_chart_panel: DepthChartPanel = $VBoxContainer/DepthChartPanel

func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters", "contracts", "depth_charts"]

func _on_data_changed(collection: String, operation: String) -> void:
    # Coordinate refresh across child panels
    match collection:
        "nfl_rosters":
            roster_panel.refresh()
            depth_chart_panel.refresh()
        "contracts":
            contract_panel.refresh()
            roster_panel.refresh_cap_info()
        "depth_charts":
            depth_chart_panel.refresh()

func initialize(ws: Dictionary) -> void:
    super.initialize(ws)

    # Push world_state to child panels (dumb components)
    roster_panel.initialize(ws)
    contract_panel.initialize(ws)
    depth_chart_panel.initialize(ws)
```

---

## Common Collections

Here are the most commonly subscribed collections:

| Collection | Contains | Typical Subscriber |
|------------|----------|-------------------|
| `nfl_rosters` | NFL team rosters | Roster panels, depth charts |
| `nfl_teams` | NFL team data | Team info panels, standings |
| `colleges` | College team data | College panels, recruiting |
| `college_rosters` | College rosters | College roster panels |
| `hs_players` | High school players | HS panels, recruiting |
| `draft_pool` | Draft-eligible players | Draft panels, scouting |
| `contracts` | Contract data | Contract panels, cap info |
| `free_agents` | Free agent pool | Free agency panels |
| `retired_players` | Retired players | History panels, hall of fame |
| `depth_charts` | Team depth charts | Depth chart editors |

---

## ReactivePanelContainer Variant

If your UI needs a styled panel container, use `ReactivePanelContainer` instead:

```gdscript
extends ReactivePanelContainer
class_name TeamInfoCard

# Same API as ReactivePanel
func _get_subscribed_collections() -> Array[String]:
    return ["nfl_teams"]

func _on_data_changed(collection: String, operation: String) -> void:
    _refresh_team_info()
```

The only difference is the base class: `ReactivePanelContainer` extends `PanelContainer` instead of `Control`.

---

## Comparison with Manual Subscription

### Without ReactivePanel (Manual)

```gdscript
extends Control
class_name ManualRosterPanel

var world_state: Dictionary = {}
var _databus_connected: bool = false

func _ready() -> void:
    _connect_databus()

func _exit_tree() -> void:
    _disconnect_databus()

func _connect_databus() -> void:
    if _databus_connected:
        return

    if not DataBus.collection_changed.is_connected(_on_collection_changed):
        DataBus.collection_changed.connect(_on_collection_changed)

    if not DataBus.world_state_loaded.is_connected(_on_world_state_loaded):
        DataBus.world_state_loaded.connect(_on_world_state_loaded)

    _databus_connected = true

func _disconnect_databus() -> void:
    if not _databus_connected:
        return

    if DataBus.collection_changed.is_connected(_on_collection_changed):
        DataBus.collection_changed.disconnect(_on_collection_changed)

    if DataBus.world_state_loaded.is_connected(_on_world_state_loaded):
        DataBus.world_state_loaded.disconnect(_on_world_state_loaded)

    _databus_connected = false

func _on_collection_changed(collection: String, operation: String) -> void:
    # Must manually filter collections
    if collection not in ["nfl_rosters", "contracts"]:
        return

    match collection:
        "nfl_rosters":
            _refresh_roster_list()
        "contracts":
            _refresh_cap_space()

func _on_world_state_loaded() -> void:
    _refresh_all()

func initialize(ws: Dictionary) -> void:
    world_state = ws
    _refresh_all()
```

**Problems:**
- 50+ lines of boilerplate
- Easy to forget cleanup
- Manual filtering required
- Not DRY (repeated across panels)

### With ReactivePanel (Clean)

```gdscript
extends ReactivePanel
class_name ReactiveRosterPanel

func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters", "contracts"]

func _on_data_changed(collection: String, operation: String) -> void:
    match collection:
        "nfl_rosters":
            _refresh_roster_list()
        "contracts":
            _refresh_cap_space()

func _on_world_state_loaded() -> void:
    _refresh_all()

func initialize(ws: Dictionary) -> void:
    super.initialize(ws)
    _refresh_all()
```

**Benefits:**
- 20 lines instead of 80+
- No boilerplate
- Automatic cleanup
- Clear intent
- DRY across all panels

---

## Testing Your ReactivePanel

### Unit Test Template

```gdscript
extends GutTest

var panel: RosterPanel
var mock_world_state: Dictionary

func before_each() -> void:
    panel = RosterPanel.new()
    mock_world_state = _create_test_world_state()
    add_child_autofree(panel)

func after_each() -> void:
    if panel:
        panel.queue_free()

func test_subscriptions_declared() -> void:
    var subscriptions = panel._get_subscribed_collections()
    assert_true("nfl_rosters" in subscriptions)
    assert_true("contracts" in subscriptions)

func test_databus_auto_connect() -> void:
    # Panel should auto-connect in _ready()
    await get_tree().process_frame
    assert_true(DataBus.collection_changed.is_connected(
        panel._on_databus_collection_changed
    ))

func test_databus_auto_disconnect() -> void:
    # Panel should auto-disconnect in _exit_tree()
    panel.queue_free()
    await get_tree().process_frame
    assert_false(DataBus.collection_changed.is_connected(
        panel._on_databus_collection_changed
    ))

func test_filtered_notifications() -> void:
    panel.initialize(mock_world_state)

    var roster_refresh_called = false
    panel._refresh_roster_list = func(): roster_refresh_called = true

    # Emit for unsubscribed collection
    DataBus.notify_collection_changed("hs_players", "insert")
    await get_tree().process_frame
    assert_false(roster_refresh_called, "Should not refresh for unsubscribed collection")

    # Emit for subscribed collection
    DataBus.notify_collection_changed("nfl_rosters", "insert")
    await get_tree().process_frame
    assert_true(roster_refresh_called, "Should refresh for subscribed collection")

func test_world_state_loaded_triggers_refresh() -> void:
    panel.initialize(mock_world_state)

    var full_refresh_called = false
    panel._refresh_all = func(): full_refresh_called = true

    DataBus.notify_world_state_loaded()
    await get_tree().process_frame
    assert_true(full_refresh_called)

func _create_test_world_state() -> Dictionary:
    return {
        "current_year": 2025,
        "nfl_teams": [{"id": "ATL", "name": "Atlanta Falcons"}],
        "nfl_rosters": {
            "ATL": {
                "players": [
                    {"id": "P1", "name": "Test Player", "position": "QB"}
                ]
            }
        },
        "contracts": {
            "ATL": [
                {"player_id": "P1", "cap_hit": 5_000_000}
            ]
        }
    }
```

---

## Best Practices

### ✅ DO

1. **Call super in initialize()**
   ```gdscript
   func initialize(ws: Dictionary) -> void:
       super.initialize(ws)  # IMPORTANT
       _refresh_all()
   ```

2. **Return array of strings for subscriptions**
   ```gdscript
   func _get_subscribed_collections() -> Array[String]:
       return ["nfl_rosters", "contracts"]
   ```

3. **Treat world_state as read-only**
   ```gdscript
   func _refresh_roster_list() -> void:
       var rosters = world_state.get("nfl_rosters", {})  # Read only
   ```

4. **Handle empty data gracefully**
   ```gdscript
   func _refresh_roster_list() -> void:
       if current_team_id.is_empty():
           player_list.add_item("[No team selected]")
           return
   ```

5. **Use match for clarity**
   ```gdscript
   func _on_data_changed(collection: String, operation: String) -> void:
       match collection:
           "nfl_rosters":
               _refresh_roster_list()
           "contracts":
               _refresh_cap_space()
   ```

### ❌ DON'T

1. **Don't mutate world_state**
   ```gdscript
   # ❌ WRONG
   func add_player(player: Dictionary) -> void:
       world_state["nfl_rosters"]["ATL"]["players"].append(player)
   ```

2. **Don't subscribe to all collections**
   ```gdscript
   # ❌ WRONG - Too broad
   func _get_subscribed_collections() -> Array[String]:
       return [
           "nfl_rosters", "nfl_teams", "colleges", "college_rosters",
           "hs_players", "draft_pool", "contracts", "free_agents"
       ]
   ```

3. **Don't forget to call super.initialize()**
   ```gdscript
   # ❌ WRONG - Missing super call
   func initialize(ws: Dictionary) -> void:
       _refresh_all()  # world_state not set!
   ```

4. **Don't duplicate subscriptions**
   ```gdscript
   # ❌ WRONG - Parent already subscribes
   class_name ChildPanel
   extends ReactivePanel  # Parent is also ReactivePanel
   ```

5. **Don't assume operation type**
   ```gdscript
   # ❌ WRONG - May not always be "insert"
   func _on_data_changed(collection: String, operation: String) -> void:
       if collection == "nfl_rosters":
           _add_new_player()  # Assumes insert!
   ```

---

## Troubleshooting

### Problem: Panel not refreshing

**Cause:** Collection name mismatch
**Solution:** Verify exact collection name

```gdscript
# Check what collections are being emitted
func _on_data_changed(collection: String, operation: String) -> void:
    print("Received: %s - %s" % [collection, operation])
```

### Problem: Refresh happening too often

**Cause:** Subscribed to too many collections
**Solution:** Narrow subscription scope

```gdscript
# Only subscribe to what you need
func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters"]  # Not ["nfl_rosters", "nfl_teams", "contracts", ...]
```

### Problem: Memory leak

**Cause:** Panel not properly freed
**Solution:** Verify `_exit_tree()` is called

```gdscript
# Add debug logging
func _exit_tree() -> void:
    print("ReactivePanel cleanup")
    super._exit_tree()
```

### Problem: Double refresh on world load

**Cause:** Both `initialize()` and `_on_world_state_loaded()` refresh
**Solution:** Choose one

```gdscript
# Option 1: Only refresh in initialize()
func _on_world_state_loaded() -> void:
    pass  # Don't refresh here

# Option 2: Only refresh in world_state_loaded
func initialize(ws: Dictionary) -> void:
    super.initialize(ws)
    # Don't refresh here
```

---

## Migration Guide

### Converting Existing Panel to ReactivePanel

**Before:**
```gdscript
extends Control
class_name MyPanel

var world_state: Dictionary = {}

func _ready() -> void:
    if not DataBus.collection_changed.is_connected(_on_collection_changed):
        DataBus.collection_changed.connect(_on_collection_changed)

func _on_collection_changed(collection: String, operation: String) -> void:
    if collection in ["nfl_rosters", "contracts"]:
        _refresh()

func initialize(ws: Dictionary) -> void:
    world_state = ws
    _refresh()
```

**After:**
```gdscript
extends ReactivePanel
class_name MyPanel

func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters", "contracts"]

func _on_data_changed(collection: String, operation: String) -> void:
    _refresh()

func initialize(ws: Dictionary) -> void:
    super.initialize(ws)
    _refresh()
```

**Steps:**
1. Change `extends Control` to `extends ReactivePanel`
2. Remove manual DataBus connection code
3. Override `_get_subscribed_collections()`
4. Rename `_on_collection_changed()` to `_on_data_changed()`
5. Call `super.initialize(ws)` in `initialize()`
6. Remove `world_state = ws` (handled by super)
7. Test refresh behavior

---

## See Also

- **[COMPONENT_CONTRACTS.md](./COMPONENT_CONTRACTS.md)** - Component patterns and contracts
- **[UI_DATABUS_INTEGRATION_AUDIT.md](./UI_DATABUS_INTEGRATION_AUDIT.md)** - DataBus integration audit
- **[WorldExplorer.gd](../../scripts/ui/world_explorer/WorldExplorer.gd)** - Example smart container
- **[DataBus.gd](../../autoloads/DataBus.gd)** - DataBus implementation

---

**END OF REACTIVE PANEL GUIDE**
