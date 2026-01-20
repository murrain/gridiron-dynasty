# DataBus Notification Strategy

This document defines the standard patterns for emitting DataBus notifications from state managers. Following these guidelines ensures consistent UI reactivity and efficient update batching.

## Overview

The DataBus is the central event bus for UI synchronization. When state managers mutate `world_state`, they emit notifications that UI components subscribe to for reactive updates.

```
State Manager → DataBus.notify_collection_changed() → UI Components
```

## Notification Granularity Levels

### 1. Fine-Grained Notifications (Default)

Use fine-grained notifications when:
- User is actively viewing the affected UI
- Real-time feedback is important (draft picks, signings)
- Individual entity changes matter to the user

```gdscript
# Example: Single draft pick
_notify_collection_changed("draft_pool", "update")
_notify_collection_changed("nfl_rosters", "update")
```

**When to use:**
- Interactive operations (user-initiated actions)
- Animations or visual feedback needed
- Debugging/development mode

### 2. Batched Notifications (Performance)

Use batched notifications when:
- Processing many items in a loop
- Background simulation (user not watching)
- Performance is critical

```gdscript
# Example: Advancing all players one year
_notify_collection_changed(collection_name, "bulk_update")
```

**When to use:**
- Season simulation (many game results)
- Year-end processing (aging, retirements)
- Initial data loading

### 3. Deferred Notifications (Complex Operations)

For operations with multiple dependent changes, defer notification until all changes complete:

```gdscript
# Example: Trade execution (both rosters change)
_update_roster(team_a, ...)  # Don't notify yet
_update_roster(team_b, ...)  # Don't notify yet
_notify_collection_changed("nfl_rosters", "trade")  # Single notification
```

**When to use:**
- Multi-step atomic operations
- Trades (two rosters change together)
- Complex contract restructures

## Collection Names

Standard collection names for notifications:

| Collection | Description | Typical Operations |
|------------|-------------|-------------------|
| `draft_pool` | Draft-eligible players | pick, remove, reorder |
| `nfl_rosters` | NFL team rosters | add, remove, trade, update |
| `college_rosters` | College team rosters | add, remove, transfer |
| `free_agents` | Free agent pool | add, remove, sign |
| `contracts` | Contract data | sign, release, restructure |
| `standings` | League standings | game_result, update |
| `draft_picks` | Draft pick ownership | trade, allocate |
| `franchise_tags` | Franchise tag data | apply, remove |
| `cap_space` | Salary cap data | update |

## Operation Types

Standard operation types for the second parameter:

| Operation | Description | UI Response |
|-----------|-------------|-------------|
| `insert` | New item added | Animate new row |
| `update` | Existing item changed | Refresh row |
| `delete` | Item removed | Animate removal |
| `bulk_update` | Many items changed | Full refresh |
| `trade` | Items moved between entities | Multi-row refresh |
| `reorder` | Items reordered | Re-sort list |

## Manager-Specific Guidelines

### DraftStateManager

```gdscript
# Pick execution - fine-grained (user watching draft)
_notify_collection_changed("draft_pool", "update")
_notify_collection_changed("nfl_rosters", "update")

# Draft initialization - single notification
_notify_collection_changed("draft_picks", "bulk_update")

# Trade execution - single notification after both sides update
_notify_collection_changed("draft_picks", "trade")
```

### SeasonStateManager

```gdscript
# Single game result - fine-grained if user watching
_notify_collection_changed("standings", "update")

# Full week simulation - batched
_notify_collection_changed("standings", "bulk_update")

# Season phase transition - informational
_notify_collection_changed("season", "phase_change")
```

### ContractStateManager

```gdscript
# Player signing - multiple affected collections
_notify_collection_changed("contracts", "insert")
_notify_collection_changed("nfl_rosters", "update")
_notify_collection_changed("cap_space", "update")

# Free agency batch - single notification after processing
_notify_collection_changed("free_agents", "bulk_update")
_notify_collection_changed("nfl_rosters", "bulk_update")
```

### PlayerStateManager

```gdscript
# Single player update
_notify_players_changed(stage, 1)

# Bulk advancement (year-end)
_notify_collection_changed(collection_name, "bulk_update")
```

## Performance Considerations

### Do

- Batch notifications when processing loops
- Use `bulk_update` for >10 items
- Defer notifications until atomic operation completes
- Consider UI visibility (is anyone watching?)

### Don't

- Notify inside tight loops (notify once after)
- Use fine-grained for background processing
- Emit duplicate notifications for same change
- Notify for read-only operations

## Example: Complete Operation Flow

```gdscript
## Execute a draft pick with proper notifications.
static func execute_pick(
    world_state: Dictionary,
    team_id: String,
    player: Dictionary,
    pick_number: int
) -> Dictionary:
    # 1. Perform pure transformations (no side effects)
    var updated_pool := DraftTransformations.remove_from_pool(...)
    var updated_roster := DraftTransformations.add_to_roster(...)
    var pick_record := DraftTransformations.create_pick_record(...)

    # 2. Apply all mutations atomically
    StatePathUtils.replace_array(world_state, ["draft_pool"], updated_pool)
    StatePathUtils.replace_array(world_state, ["nfl_rosters", team_id, "players"], updated_roster)
    StatePathUtils.append_to_array(world_state, ["draft_history"], pick_record)

    # 3. Emit notifications (fine-grained for interactive draft)
    _notify_collection_changed("draft_pool", "update")
    _notify_collection_changed("nfl_rosters", "update")

    # 4. Return result
    return {"success": true, "pick": pick_record}
```

## Testing Notifications

When testing state managers, verify notifications fire correctly:

```gdscript
func test_signing_emits_correct_notifications() -> void:
    var notifications := []
    DataBus.collection_changed.connect(func(name, op):
        notifications.append({"name": name, "op": op})
    )

    ContractStateManager.execute_signing(...)

    assert_that(notifications).contains({"name": "contracts", "op": "insert"})
    assert_that(notifications).contains({"name": "nfl_rosters", "op": "update"})
```

## Migration Notes

When adding new state managers, follow this checklist:

1. [ ] Identify all collections the manager mutates
2. [ ] Determine appropriate granularity for each operation
3. [ ] Document notification pattern in manager docstring
4. [ ] Add notification calls after all mutations complete
5. [ ] Test notifications fire correctly
6. [ ] Update this document if adding new collection names

---

*Last updated: 2026-01-20*
*Related: [Pure Functional Expansion Review](./PURE_FUNCTIONAL_EXPANSION_REVIEW.md)*
