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

## Built-in Theme and Style System

Both `ReactivePanel` and `ReactivePanelContainer` include a built-in theme system for consistent, professional styling with automatic nesting support.

### Style Variants

Choose from 9 built-in style variants:

| Variant | Description | Use Case |
|---------|-------------|----------|
| `default` | Standard dark panel | General-purpose panels |
| `primary` | Blue accent | Primary actions, highlighted content |
| `secondary` | Purple accent | Secondary actions, alternative content |
| `info` | Teal accent | Informational messages, tooltips |
| `warning` | Orange accent | Warnings, cautions, alerts |
| `success` | Green accent | Success messages, confirmations |
| `error` | Red accent | Error messages, critical alerts |
| `nested` | Auto-darkening | Panels nested inside other panels |
| `transparent` | No background/border | Invisible containers |

### Using Style Variants

Set the variant via the exported property:

```gdscript
extends ReactivePanelContainer
class_name TeamInfoPanel

# Set in editor or script
@export_enum("default", "primary", "secondary", "info", "warning", "success", "error", "nested", "transparent")
var style_variant: String = "primary"
```

Or programmatically:

```gdscript
func _ready() -> void:
    super._ready()
    set_style_variant("warning")  # Changes to warning style
```

### Nesting and Auto-Indenting

Panels automatically detect when they're nested inside other `ReactivePanel` or `ReactivePanelContainer` instances.

#### Automatic Nesting Detection

```gdscript
# Parent panel
var parent := ReactivePanelContainer.new()
parent.style_variant = "default"
add_child(parent)

# Child panel (automatically detects it's nested)
var child := ReactivePanelContainer.new()
child.style_variant = "nested"  # Auto-darkens based on depth
child.auto_indent_nested = true  # Adds left margin (8px by default)
parent.add_child(child)

# Grandchild panel (even darker, more indented)
var grandchild := ReactivePanelContainer.new()
grandchild.style_variant = "nested"
child.add_child(grandchild)
```

**Result:**
- Parent: Medium background, no indent
- Child: Dark background, 8px left indent
- Grandchild: Darker background, 16px left indent

#### Configuring Auto-Indent

Control nesting behavior with exported properties:

```gdscript
@export var auto_indent_nested: bool = true  # Enable auto-indent
@export_range(0, 32, 1) var nest_indent: int = 8  # Pixels per level
```

Disable auto-indent for horizontal layouts:

```gdscript
var panel := ReactivePanelContainer.new()
panel.auto_indent_nested = false  # No indenting
panel.style_variant = "nested"  # Still auto-darkens
```

### Example: Multi-Level Nested Panels

```gdscript
extends Control

func _ready() -> void:
    # Parent: Team Overview
    var team_panel := ReactivePanelContainer.new()
    team_panel.style_variant = "default"
    add_child(team_panel)

    var team_label := Label.new()
    team_label.text = "Atlanta Falcons"
    team_panel.add_child(team_label)

    # Child: Roster Section
    var roster_panel := ReactivePanelContainer.new()
    roster_panel.style_variant = "nested"
    team_panel.add_child(roster_panel)

    var roster_label := Label.new()
    roster_label.text = "Roster (53 players)"
    roster_panel.add_child(roster_label)

    # Grandchild: Position Group
    var qb_panel := ReactivePanelContainer.new()
    qb_panel.style_variant = "nested"
    roster_panel.add_child(qb_panel)

    var qb_label := Label.new()
    qb_label.text = "QB: 3 players"
    qb_panel.add_child(qb_label)
```

Visual result:
```
┌─────────────────────────────────────┐
│ Atlanta Falcons (medium bg)         │
│  ┌──────────────────────────────────┤
│  │ Roster (53 players) (dark bg)    │
│  │  ┌───────────────────────────────┤
│  │  │ QB: 3 players (darker bg)     │
│  │  └───────────────────────────────┘
│  └──────────────────────────────────┘
└─────────────────────────────────────┘
```

### Using PanelStyles Directly

For advanced use cases, use the `PanelStyles` utility class:

```gdscript
# Create a custom style
var style := PanelStyles.create_style("primary", 0)

# Apply to any Control
some_panel.add_theme_stylebox_override("panel", style)

# Access color palette
var bg_color := PanelStyles.get_color("bg_dark")
var border_color := PanelStyles.get_color("border_accent")

# Access spacing constants
var padding := PanelStyles.get_spacing("md")  # 12px
var gap := PanelStyles.get_spacing("lg")  # 16px

# Custom style configuration
var custom_style := PanelStyles.create_style("warning", 0, {
    "padding": 16,
    "corner_radius": 8,
    "border_width": 2,
    "bg_color": Color(0.3, 0.2, 0.1)
})
```

### Color Palette Reference

The `PanelStyles` class provides a consistent color palette:

#### Background Colors
- `bg_darker`: #121215 (deepest nested)
- `bg_dark`: #1a1a1f (dark panels)
- `bg_medium`: #252530 (standard panels)
- `bg_light`: #33333d (light panels)

#### Border Colors
- `border_subtle`: #3a3a45 (subtle borders)
- `border_medium`: #4a4a59 (medium borders)
- `border_accent`: #4a6a9a (accent borders)

#### Semantic Colors
- `primary`: #2a4a7a (blue)
- `secondary`: #4a3a6a (purple)
- `info`: #2a5a6a (teal)
- `warning`: #7a5a2a (orange)
- `success`: #2a6030 (green)
- `error`: #7a1f1f (red)

### Spacing Constants

Consistent spacing values for margins, padding, and gaps:

```gdscript
PanelStyles.SPACING = {
    "xs": 4,   # Extra small
    "sm": 8,   # Small
    "md": 12,  # Medium (default)
    "lg": 16,  # Large
    "xl": 24,  # Extra large
}
```

### Example: Style Variants in a Dashboard

```gdscript
extends Control
class_name GameDashboard

func _ready() -> void:
    # Create main container
    var vbox := VBoxContainer.new()
    add_child(vbox)

    # Header panel (primary)
    var header := ReactivePanelContainer.new()
    header.style_variant = "primary"
    vbox.add_child(header)

    var title := Label.new()
    title.text = "Game Dashboard"
    header.add_child(title)

    # Stats panel (info)
    var stats := ReactivePanelContainer.new()
    stats.style_variant = "info"
    vbox.add_child(stats)

    var stats_label := Label.new()
    stats_label.text = "Season: Week 12 | Record: 8-4"
    stats.add_child(stats_label)

    # Warning panel (warning)
    var warning := ReactivePanelContainer.new()
    warning.style_variant = "warning"
    vbox.add_child(warning)

    var warning_label := Label.new()
    warning_label.text = "⚠ Cap space critical: $2.5M remaining"
    warning.add_child(warning_label)
```

### Example Scene: ExampleNestedPanels

See `scripts/ui/base/ExampleNestedPanels.gd` for a complete demonstration scene showing:
- All style variants
- Multi-level nesting
- Auto-indenting
- Dynamic style changes

To try it:
1. Create a new scene with a Control node
2. Attach the ExampleNestedPanels script
3. Run the scene

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

### Style System Best Practices

#### ✅ DO

1. **Use semantic variants for clarity**
   ```gdscript
   # ✅ GOOD - Clear intent
   warning_panel.style_variant = "warning"  # Visual hierarchy
   error_panel.style_variant = "error"      # Semantic meaning
   ```

2. **Use "nested" variant for hierarchical layouts**
   ```gdscript
   # ✅ GOOD - Auto-darkening shows depth
   parent.style_variant = "default"
   child.style_variant = "nested"
   grandchild.style_variant = "nested"
   ```

3. **Disable auto-indent for horizontal layouts**
   ```gdscript
   # ✅ GOOD - Prevents awkward indenting
   var hbox := HBoxContainer.new()
   for i in 3:
       var panel := ReactivePanelContainer.new()
       panel.auto_indent_nested = false  # Horizontal layout
       hbox.add_child(panel)
   ```

4. **Use PanelStyles for consistency**
   ```gdscript
   # ✅ GOOD - Consistent spacing
   vbox.add_theme_constant_override("separation", PanelStyles.SPACING["md"])
   label.add_theme_color_override("font_color", PanelStyles.COLORS["primary"])
   ```

5. **Prefer ReactivePanelContainer over ReactivePanel**
   ```gdscript
   # ✅ GOOD - Full StyleBox support
   extends ReactivePanelContainer  # Better style rendering
   ```

#### ❌ DON'T

1. **Don't hardcode colors**
   ```gdscript
   # ❌ WRONG - Hardcoded colors
   panel.modulate = Color(0.2, 0.4, 0.7)

   # ✅ GOOD - Use palette
   panel.set_style_variant("primary")
   ```

2. **Don't mix auto_apply_style settings inconsistently**
   ```gdscript
   # ❌ WRONG - Confusing behavior
   parent.auto_apply_style = true   # Applies on ready
   child.auto_apply_style = false   # Doesn't apply
   # Child won't match parent's theme

   # ✅ GOOD - Consistent settings
   parent.auto_apply_style = true
   child.auto_apply_style = true
   ```

3. **Don't nest too deeply without visual distinction**
   ```gdscript
   # ❌ WRONG - Hard to see hierarchy
   panel1.style_variant = "default"
   panel2.style_variant = "default"  # Same color!
   panel3.style_variant = "default"  # Can't tell depth

   # ✅ GOOD - Clear visual hierarchy
   panel1.style_variant = "nested"   # Auto-darkens by depth
   panel2.style_variant = "nested"
   panel3.style_variant = "nested"
   ```

4. **Don't use indenting for visual-only purposes**
   ```gdscript
   # ❌ WRONG - Abuse of nesting indent
   panel.auto_indent_nested = true
   panel.nest_indent = 100  # Way too much!

   # ✅ GOOD - Use containers for layout
   var margin := MarginContainer.new()
   margin.add_theme_constant_override("margin_left", 100)
   ```

5. **Don't forget to call apply_style() after manual changes**
   ```gdscript
   # ❌ WRONG - Style not applied
   panel.auto_apply_style = false
   panel.style_variant = "warning"  # Not visible yet!

   # ✅ GOOD - Manually apply after changes
   panel.auto_apply_style = false
   panel.style_variant = "warning"
   panel.apply_style()  # Now it's visible
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

### Problem: Style not applying

**Cause:** `auto_apply_style` is false or `apply_style()` not called
**Solution:** Enable auto-apply or call manually

```gdscript
# Option 1: Enable auto-apply (recommended)
panel.auto_apply_style = true  # Applies on _ready()

# Option 2: Manual control
panel.auto_apply_style = false
panel.style_variant = "warning"
panel.apply_style()  # Manually apply
```

### Problem: Panel has no visible style (ReactivePanel)

**Cause:** ReactivePanel uses ColorRect background, not full StyleBox
**Solution:** Use ReactivePanelContainer for full style support

```gdscript
# ❌ Limited style support
extends ReactivePanel  # Only background color

# ✅ Full style support
extends ReactivePanelContainer  # Full StyleBox with borders, corners
```

### Problem: Nested panels not indenting

**Cause:** `auto_indent_nested` is false or nesting not detected
**Solution:** Enable auto-indent and check hierarchy

```gdscript
# Enable auto-indent
child_panel.auto_indent_nested = true

# Verify nesting
print("Is nested: ", child_panel._is_nested())
print("Depth: ", child_panel._get_nesting_depth())
```

### Problem: Too much nesting indent

**Cause:** `nest_indent` value too high or too many nesting levels
**Solution:** Reduce indent amount or restructure UI

```gdscript
# Reduce indent per level
panel.nest_indent = 4  # Instead of default 8

# Or disable for specific panels
panel.auto_indent_nested = false
```

### Problem: Colors don't match palette reference

**Cause:** Color hex values converted incorrectly
**Solution:** Use PanelStyles color constants directly

```gdscript
# ❌ WRONG - Manual conversion errors
var color := Color(0.10, 0.10, 0.12)  # Might be off

# ✅ GOOD - Use constants
var color := PanelStyles.COLORS["bg_dark"]
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
