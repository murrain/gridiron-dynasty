# UI Base Classes

This directory contains base classes for building reactive UI components in Gridiron Dynasty.

## Classes

### ReactivePanel

**File:** `ReactivePanel.gd`
**Extends:** `Control`

Base class for reactive UI panels that automatically subscribe to DataBus signals. Eliminates boilerplate code for smart containers.

**Use when:**
- Building a smart container that needs to refresh when data changes
- You want automatic DataBus subscription management
- You need filtered notifications for specific collections

**Example:**
```gdscript
extends ReactivePanel
class_name RosterPanel

func _get_subscribed_collections() -> Array[String]:
    return ["nfl_rosters", "contracts"]

func _on_data_changed(collection: String, operation: String) -> void:
    _refresh_display()
```

### ReactivePanelContainer

**File:** `ReactivePanelContainer.gd`
**Extends:** `PanelContainer`

Identical to ReactivePanel but extends PanelContainer for styled panel UIs.

**Use when:**
- Same as ReactivePanel, but you need PanelContainer styling
- Building info cards, stat panels, or other styled containers

### ExampleReactivePanel

**File:** `ExampleReactivePanel.gd`
**Extends:** `ReactivePanel`

Reference implementation demonstrating ReactivePanel usage. Used for testing and documentation.

**Do NOT use in production** - this is for reference only.

## Documentation

- **Full Guide:** `/docs/ui/REACTIVE_PANEL_GUIDE.md`
- **Component Patterns:** `/docs/ui/COMPONENT_CONTRACTS.md`
- **Tests:** `/tests/ui/test_reactive_panel.gd`

## Quick Start

1. **Extend the base class:**
   ```gdscript
   extends ReactivePanel
   class_name MyPanel
   ```

2. **Declare subscriptions:**
   ```gdscript
   func _get_subscribed_collections() -> Array[String]:
       return ["nfl_rosters", "draft_pool"]
   ```

3. **Handle data changes:**
   ```gdscript
   func _on_data_changed(collection: String, operation: String) -> void:
       match collection:
           "nfl_rosters":
               _refresh_roster()
           "draft_pool":
               _refresh_draft()
   ```

4. **Initialize with data:**
   ```gdscript
   func initialize(ws: Dictionary) -> void:
       super.initialize(ws)
       _refresh_all()
   ```

## Benefits

- **50+ lines of boilerplate eliminated per panel**
- **Automatic cleanup** - no memory leaks
- **Filtered notifications** - only receive relevant events
- **Consistent pattern** - all reactive panels work the same way
- **Self-documenting** - subscriptions are explicit

## When NOT to Use

- ❌ Dumb components (use `initialize()` pattern instead)
- ❌ Modals with transient state
- ❌ Child of another ReactivePanel (avoid double-subscription)
- ❌ Simulation UIs (use controller signals instead)

## Architecture

```
DataBus (autoload)
    │
    ├── collection_changed(collection, operation)
    └── world_state_loaded()
         │
         ↓
ReactivePanel (base class)
    │
    ├── _connect_databus_signals()      [automatic]
    ├── _disconnect_databus_signals()   [automatic]
    ├── _on_databus_collection_changed() [filters]
    │       │
    │       ↓
    ├── _on_data_changed(collection, operation)  [override in subclass]
    └── _on_world_state_loaded()                 [override in subclass]
```

## See Also

- [WorldExplorer.gd](../world_explorer/WorldExplorer.gd) - Example smart container
- [DataBus.gd](../../../autoloads/DataBus.gd) - Event bus implementation
- [REACTIVE_PANEL_GUIDE.md](../../../docs/ui/REACTIVE_PANEL_GUIDE.md) - Complete guide
