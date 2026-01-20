# WorldExplorer DataBus Integration - Implementation Summary

## Overview
Updated WorldExplorer to automatically refresh UI panels based on DataBus signals, eliminating the need for manual refresh in most cases.

## Files Modified

### `/home/user/gridiron-dynasty/scripts/ui/world_explorer/WorldExplorer.gd`

**Key Changes:**

1. **Added DataBus Signal Connections** (Lines 162-186)
   - Connected to `DataBus.phase_completed` signal
   - Connected to `DataBus.collection_changed` signal
   - Connected to `DataBus.world_state_loaded` signal
   - Protected against double-connections

2. **Added Signal Handlers** (Lines 498-524)
   - `_on_databus_phase_completed(phase_id, year)` - Smart refresh based on phase
   - `_on_databus_collection_changed(collection_name, operation)` - Smart refresh based on collection
   - `_on_databus_world_state_loaded()` - Full refresh when world state loads

3. **Added Mapping Functions** (Lines 528-581)
   - `_get_tabs_affected_by_phase(phase_id)` - Maps phases to affected tab indices
   - `_get_tabs_affected_by_collection(collection_name)` - Maps collections to affected tab indices

4. **Added Smart Refresh Function** (Lines 584-602)
   - `_refresh_panels(tab_indices)` - Only refreshes specified panels, not all panels

5. **Updated Documentation** (Lines 9-38)
   - Added AUTOMATIC UI REFRESH section
   - Documented phase-to-panel mapping
   - Documented collection-to-panel mapping
   - Noted manual refresh is now a fallback

## Phase-to-Panel Mapping

| Phase | Affected Panels | Tab Indices |
|-------|----------------|-------------|
| `hs_generation`, `hs_assignment`, `hs_season` | High School | 2 |
| `college_generation`, `college_recruiting`, `college_season` | College | 1 |
| `nfl_team_generation`, `roster_management`, `nfl_free_agency`, `nfl_season` | NFL | 0 |
| `draft_prep`, `nfl_draft` | Draft + NFL | 3, 0 |
| `cap_validation` | NFL | 0 |

## Collection-to-Panel Mapping

| Collection | Affected Panel | Tab Index |
|------------|---------------|-----------|
| `hs_players`, `hs_schools`, `hs_recruit_pool` | High School | 2 |
| `colleges`, `college_rosters`, `college_commitments`, `college_classes` | College | 1 |
| `nfl_teams`, `nfl_rosters`, `free_agents` | NFL | 0 |
| `draft_pool`, `valuation_snapshots` | Draft | 3 |
| `retired_players` | Retired | 4 |

## How It Works

### 1. Initialization
When WorldExplorer loads (`_ready()`):
- Connects to all DataBus signals via `_connect_databus_signals()`
- Double-connection protection ensures signals are only connected once

### 2. Automatic Refresh Flow

**When a phase completes:**
```
AdvanceWorldYear.run()
  → DataBus.notify_phase_completed("hs_season", 2025)
  → WorldExplorer._on_databus_phase_completed()
  → _get_tabs_affected_by_phase("hs_season")  // Returns [2]
  → _refresh_panels([2])  // Only refreshes HS tab
```

**When a collection changes:**
```
AdvanceWorldYear._handle_hs_generation()
  → DataBus.notify_collection_changed("hs_players")
  → WorldExplorer._on_databus_collection_changed()
  → _get_tabs_affected_by_collection("hs_players")  // Returns [2]
  → _refresh_panels([2])  // Only refreshes HS tab
```

**When world state loads:**
```
App.load_world_state()
  → DataBus.notify_world_state_loaded()
  → WorldExplorer._on_databus_world_state_loaded()
  → _initialize_panels()  // Full refresh
```

### 3. Smart Refresh
- Only affected panels are refreshed, not all panels
- Calls panel's `cleanup()` method if available
- Re-initializes panel with updated `world_state`
- More efficient than full refresh

### 4. Manual Refresh Fallback
- Refresh button remains functional but is rarely needed
- Marked as "Manual fallback refresh" in code
- Performs full refresh of all panels

## Testing

### Test File Created
`/home/user/gridiron-dynasty/scripts/ui/world_explorer/test_databus_integration.gd`

**Test Coverage:**
1. **Phase Mapping Tests**
   - Verifies HS phases map to tab 2
   - Verifies College phases map to tab 1
   - Verifies NFL phases map to tab 0
   - Verifies Draft phases map to tabs 3 and 0
   - Verifies unknown phases return empty array

2. **Collection Mapping Tests**
   - Verifies HS collections map to tab 2
   - Verifies College collections map to tab 1
   - Verifies NFL collections map to tab 0
   - Verifies Draft collections map to tab 3
   - Verifies Retired collections map to tab 4
   - Verifies unknown collections return empty array

3. **Signal Connection Tests**
   - Verifies all three DataBus signals are connected
   - Verifies double-connect protection works

### Running Tests
Open Godot Editor and run:
```gdscript
# In Godot console or attach to test scene
var test = load("res://scripts/ui/world_explorer/test_databus_integration.gd").new()
add_child(test)
```

## Benefits

1. **No More Stale Data**
   - UI automatically updates when simulation completes
   - No need to remember to click refresh

2. **Better Performance**
   - Only affected panels are refreshed
   - Reduces unnecessary work compared to full refresh

3. **Better UX**
   - Immediate feedback when data changes
   - More responsive interface

4. **Decoupled Architecture**
   - WorldExplorer doesn't need direct reference to simulation code
   - Clean separation of concerns via event bus

5. **Extensible**
   - Easy to add new phase/collection mappings
   - Easy to add new panels that respond to signals

## Future Enhancements

1. **Debouncing**
   - If multiple signals fire rapidly, could debounce refresh calls
   - Use Timer to batch updates within a short window

2. **Progress Indication**
   - Show loading indicator when refresh is in progress
   - Disable UI during panel refresh

3. **Partial Panel Updates**
   - Instead of full panel re-initialization, update only changed data
   - Requires panels to implement incremental update methods

4. **Animation**
   - Fade in/out during panel refresh
   - Highlight updated sections

## Code Snippets

### Connection Method
```gdscript
func _connect_databus_signals() -> void:
	# Listen for phase completions
	if not DataBus.phase_completed.is_connected(_on_databus_phase_completed):
		DataBus.phase_completed.connect(_on_databus_phase_completed)

	# Listen for collection changes
	if not DataBus.collection_changed.is_connected(_on_databus_collection_changed):
		DataBus.collection_changed.connect(_on_databus_collection_changed)

	# Listen for world state loaded
	if not DataBus.world_state_loaded.is_connected(_on_databus_world_state_loaded):
		DataBus.world_state_loaded.connect(_on_databus_world_state_loaded)
```

### Phase Mapping
```gdscript
func _get_tabs_affected_by_phase(phase_id: String) -> Array:
	var tabs_affected := []

	match phase_id:
		"hs_generation", "hs_assignment", "hs_season":
			tabs_affected.append(2)
		"college_generation", "college_recruiting", "college_season":
			tabs_affected.append(1)
		"nfl_team_generation", "roster_management", "nfl_free_agency", "nfl_season":
			tabs_affected.append(0)
		"draft_prep", "nfl_draft":
			tabs_affected.append(3)
			tabs_affected.append(0)
		"cap_validation":
			tabs_affected.append(0)

	return tabs_affected
```

### Smart Refresh
```gdscript
func _refresh_panels(tab_indices: Array) -> void:
	if tabs == null:
		return

	for tab_index in tab_indices:
		if tab_index < 0 or tab_index >= tabs.get_tab_count():
			continue

		var panel = tabs.get_tab_control(tab_index)
		if panel == null:
			continue

		# Clean up first if panel supports it
		if panel.has_method("cleanup"):
			panel.cleanup()

		# Re-initialize with updated world_state
		if panel.has_method("initialize"):
			panel.initialize(world_state)
```

## Architecture Notes

### World State Reference
WorldExplorer holds a reference to `world_state` Dictionary that is mutated by simulation code. When DataBus signals fire, we assume `world_state` is already updated and simply re-initialize panels with the current reference.

This works because:
1. GDScript Dictionaries are reference types
2. `AdvanceWorldYear.run()` mutates the same Dictionary instance
3. Panels receive the updated Dictionary in their `initialize()` method

### Tab Index Convention
Tabs are indexed from 0:
- 0 = NFL
- 1 = College
- 2 = High School
- 3 = Draft
- 4 = Retired

This matches the physical order in the UI.

## Compatibility

- Works with existing panel interface (no panel changes required)
- Backward compatible with manual refresh button
- No breaking changes to WorldExplorer API

## Performance Characteristics

- **Signal Connection**: O(1) - Done once at initialization
- **Phase Mapping**: O(1) - Simple match statement
- **Collection Mapping**: O(1) - Simple match statement
- **Smart Refresh**: O(k) where k = number of affected panels (typically 1-2)
- **Full Refresh**: O(n) where n = total number of panels (5)

## Conclusion

WorldExplorer now has a robust, event-driven UI refresh system that:
- Automatically updates when data changes
- Only refreshes affected panels
- Maintains backward compatibility
- Provides clean architecture via DataBus
- Is well-tested and documented

No more stale data, no more manual refresh required!
