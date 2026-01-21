# ReactivePanel Quick Reference Card

**Version:** 1.0
**Last Updated:** 2026-01-20

---

## The Three-Method Pattern

```gdscript
extends ReactivePanel
class_name MyPanel

# 1. DECLARE: What collections to watch
func _get_subscribed_collections() -> Array[String]:
    return ["collection_name"]

# 2. HANDLE: Respond to changes
func _on_data_changed(collection: String, operation: String) -> void:
    _refresh_ui()

# 3. INITIALIZE: Set initial data
func initialize(ws: Dictionary) -> void:
    super.initialize(ws)  # ← MUST call super first!
    _refresh_ui()
```

---

## Common Collections

| Collection | Data Type | Use Case |
|-----------|-----------|----------|
| `nfl_rosters` | Dict of Arrays | NFL team rosters |
| `nfl_teams` | Array | NFL team data |
| `colleges` | Array | College team data |
| `college_rosters` | Dict of Arrays | College rosters |
| `hs_players` | Array | High school players |
| `draft_pool` | Dict of Arrays | Draft prospects by year |
| `contracts` | Dict of Arrays | Contracts by team |
| `free_agents` | Array | Free agent pool |
| `retired_players` | Array | Retired players |

---

## Complete Example

```gdscript
extends ReactivePanel
class_name TeamRosterPanel

@onready var player_list: ItemList = $PlayerList
var current_team_id: String = ""

func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters"]

func _on_data_changed(collection: String, operation: String) -> void:
    _refresh_roster()

func _on_world_state_loaded() -> void:
    _refresh_roster()

func initialize(ws: Dictionary) -> void:
    super.initialize(ws)
    _refresh_roster()

func set_team(team_id: String) -> void:
    current_team_id = team_id
    _refresh_roster()

func _refresh_roster() -> void:
    player_list.clear()
    var roster = world_state.get("nfl_rosters", {}).get(current_team_id, {})
    for player in roster.get("players", []):
        player_list.add_item(player["name"])
```

---

## Operation Types

| Operation | Meaning | Typical Response |
|-----------|---------|------------------|
| `insert` | New item added | Add to list |
| `update` | Existing item modified | Refresh display |
| `delete` | Item removed | Remove from list |
| `bulk_update` | Multiple items changed | Full refresh |

---

## Common Patterns

### Pattern: Conditional Refresh

Only refresh if change affects current view:

```gdscript
func _on_data_changed(collection: String, operation: String) -> void:
    if current_team_id.is_empty():
        return
    _refresh_roster()
```

### Pattern: Partial Refresh

Refresh only affected sections:

```gdscript
func _on_data_changed(collection: String, operation: String) -> void:
    match collection:
        "nfl_rosters":
            _refresh_roster_list()     # Only roster section
        "contracts":
            _refresh_cap_display()      # Only cap section
```

### Pattern: Operation-Specific Handling

```gdscript
func _on_data_changed(collection: String, operation: String) -> void:
    match operation:
        "insert":
            _add_player_to_list()      # Incremental
        "delete":
            _remove_player_from_list() # Incremental
        "bulk_update":
            _refresh_roster()          # Full refresh
```

---

## Checklist

Before considering your ReactivePanel complete:

- [ ] Called `super.initialize(ws)` in initialize()
- [ ] Subscribed only to relevant collections (not all)
- [ ] Handled empty/missing data gracefully
- [ ] Treated world_state as read-only (no mutations)
- [ ] Used `world_state.get(key, default)` with defaults
- [ ] Tested with DataBus signals manually
- [ ] Verified cleanup on panel removal

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Panel not refreshing | Check collection name matches exactly |
| Refreshing too often | Narrow subscription scope |
| world_state is empty | Forgot to call `super.initialize(ws)` |
| Memory leak | Panel should auto-cleanup, check if stuck in tree |
| Double refresh | Both initialize() and _on_world_state_loaded() refresh |

---

## Don't Use ReactivePanel If...

- ❌ Your parent already subscribes to DataBus
- ❌ You're building a dumb component
- ❌ Your component is a modal
- ❌ Your component is simulation UI

Use the `initialize()` pattern from parent instead:

```gdscript
extends VBoxContainer
class_name DumbPanel

var world_state: Dictionary = {}

func initialize(ws: Dictionary) -> void:
    world_state = ws
    _refresh_display()
```

---

## API Reference

### Methods to Override

```gdscript
# REQUIRED: Which collections to subscribe to
func _get_subscribed_collections() -> Array[String]

# REQUIRED: Handle data changes
func _on_data_changed(collection: String, operation: String) -> void

# OPTIONAL: Handle world state load
func _on_world_state_loaded() -> void

# REQUIRED: Initialize with world state
func initialize(ws: Dictionary) -> void
```

### Available Properties

```gdscript
# Read-only reference to world state
var world_state: Dictionary

# Cached subscriptions (internal use)
var _subscribed_collections: Array[String]

# Connection tracking (internal use)
var _databus_connected: bool
```

### Automatic Behavior

- ✅ Auto-connects to DataBus in `_ready()`
- ✅ Auto-disconnects in `_exit_tree()`
- ✅ Filters to subscribed collections only
- ✅ Prevents double-connections

---

## See Also

- **Full Guide:** [REACTIVE_PANEL_GUIDE.md](./REACTIVE_PANEL_GUIDE.md)
- **Component Patterns:** [COMPONENT_CONTRACTS.md](./COMPONENT_CONTRACTS.md)
- **Source Code:** [ReactivePanel.gd](../../scripts/ui/base/ReactivePanel.gd)
- **Tests:** [test_reactive_panel.gd](../../tests/ui/test_reactive_panel.gd)

---

**Print this and keep it next to your keyboard!**
