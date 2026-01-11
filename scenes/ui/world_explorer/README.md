# World Explorer UI - Track 1: Core Infrastructure

## Overview

This directory contains the foundational World Explorer UI components - a master-detail interface for exploring bootstrapped game worlds in Gridiron Dynasty.

## Files Created

### Scene Files
- `world_explorer.tscn` - Main scene with complete UI layout

### Script Files
- `../../scripts/ui/world_explorer/WorldExplorer.gd` - Main controller script
- `../../scripts/ui/world_explorer/core/WorldExplorerConfig.gd` - Configuration resource

### Test Files (in project root)
- `world_explorer_test.tscn` - Test scene that instances the World Explorer
- `world_explorer_test.gd` - Test script with mock world data

## Architecture

### Scene Structure

```
WorldExplorer (Control)
├── MarginContainer (10px margins)
│   └── VBoxContainer
│       ├── HeaderPanel (48px height)
│       │   └── HBoxContainer
│       │       ├── TitleLabel ("Gridiron Dynasty - World Explorer")
│       │       ├── Spacer (expands)
│       │       ├── YearLabel ("Year: 2025")
│       │       └── RefreshButton ("↻")
│       │
│       └── MainContent (HSplitContainer, split at 400px)
│           ├── SidebarPanel (300px min width)
│           │   └── VBoxContainer
│           │       ├── SearchBox
│           │       │   ├── SearchField (with clear button)
│           │       │   └── ClearButton ("×")
│           │       │
│           │       └── NavigationTabs (TabContainer)
│           │           [Panels added by other tracks]
│           │
│           └── DetailPanel (expands)
│               └── ScrollContainer
│                   └── DetailText (RichTextLabel with BBCode)
```

### Key Features

1. **Master-Detail Layout**: Split view with sidebar navigation and detail panel
2. **Tabbed Navigation**: Support for multiple panels (NFL, College, HS, Draft, Retired)
3. **Global Search**: Search field broadcasts to active tab panel
4. **BBCode Formatting**: Rich text detail views with colors and formatting
5. **Graceful Degradation**: All node access is null-safe
6. **Extensible Design**: Easy to add new panels and detail formatters

## Public API

### WorldExplorer Class

```gdscript
# Load world state and initialize UI
func load_world_state(ws: Dictionary) -> void

# Show player detail in right panel
func show_player_detail(player_id: String) -> void

# Show team/school detail in right panel
func show_team_detail(team_id: String, level: String) -> void

# Clear detail panel and show welcome screen
func clear_detail() -> void
```

### WorldExplorerConfig Class

```gdscript
# Get hex color for rating value
func get_rating_color(rating: float) -> String

# Get Color object for rating value
func get_rating_color_obj(rating: float) -> Color
```

## Configuration Options

Exposed via `WorldExplorerConfig` resource:

- `auto_scroll_detail: bool` - Auto-scroll detail panel when updated
- `show_debug_info: bool` - Show debug info in header
- `default_split_offset: int` - Default sidebar width (400px)
- `max_search_results: int` - Max search results (100)
- `enable_shortcuts: bool` - Enable keyboard shortcuts
- `color_elite/great/good/average/below_avg/poor: String` - Rating tier colors

## World State Schema

The World Explorer expects a world state dictionary with this structure:

```gdscript
{
    "current_year": 2025,
    "nfl_teams": [{"id": "KC", "name": "Kansas City Chiefs"}, ...],
    "nfl_rosters": {"KC": {"players": ["p1", "p2", ...]}, ...},
    "colleges": [{"id": "ALA", "name": "Alabama"}, ...],
    "college_rosters": {"ALA": {"players": ["c1", "c2", ...]}, ...},
    "hs_schools": [{"id": "hs1", "name": "Central High"}, ...],
    "hs_players": ["h1", "h2", ...],
    "draft_pool": {2025: ["d1", "d2", ...], 2026: [...]},
    "retired_players": ["r1", "r2", ...]
}
```

## Testing

### Running the Test Scene

1. Open `world_explorer_test.tscn` in Godot editor
2. Run the scene (F6)
3. The welcome screen should display world statistics
4. Test keyboard shortcuts:
   - `F5` - Refresh and show welcome
   - `1` - Show player detail placeholder
   - `2` - Show team detail placeholder
   - `3` - Clear detail panel

### Validation Checklist

- [x] Scene loads without errors
- [x] All node paths resolve correctly
- [x] Welcome screen displays with mock data
- [x] Search field is functional
- [x] Refresh button works
- [x] Clear button clears search
- [x] Tab container is ready for panels
- [x] Detail panel shows placeholder content
- [x] Public API methods work correctly

## Integration Points

### For Track 2 (Detail Formatters)

Track 2 will provide:
- `PlayerDetailFormatter` - Replace placeholder in `show_player_detail()`
- `TeamDetailFormatter` - Replace placeholder in `show_team_detail()`

### For Track 3+ (Tab Panels)

Each track will:
1. Create a panel scene (e.g., `nfl_panel.tscn`)
2. Add it as child of `NavigationTabs` in the main scene
3. Implement required methods and signals (see Panel Integration Guide below)

## Panel Integration Guide

### Required Methods

```gdscript
func initialize(world_state: Dictionary) -> void
```
Called when panel is added or refreshed. The `world_state` parameter is **READ-ONLY** - panels must not modify it!

### Optional Methods

```gdscript
func filter_by_search(search_text: String) -> void
```
Called when user types in search box. Implement filtering logic here.

```gdscript
func cleanup() -> void
```
Called before re-initialization (on refresh). Use to free resources, clear caches, etc.

### Required Signals

```gdscript
signal player_selected(player_id: String)
```
Emit this signal when user clicks a player in your list. WorldExplorer will handle navigation.

```gdscript
signal team_selected(team_id: String, level: String)
```
Emit this signal when user clicks a team/school in your list. WorldExplorer will handle navigation.

### Best Practices

1. **Do NOT modify world_state** - Treat it as immutable
2. **Do NOT store reference to WorldExplorer** - Use signals instead
3. **Create local filtered copies if needed** - Don't modify the original data
4. **Emit signals for navigation** - Don't call WorldExplorer methods directly
5. **Handle empty data gracefully** - Show placeholder text when data is missing

### Example Panel Implementation

```gdscript
extends Control

signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)

var _world_data: Dictionary = {}
var _filtered_players: Array = []

func initialize(world_state: Dictionary) -> void:
	# Store a reference (but don't modify!)
	_world_data = world_state

	# Create local filtered copy
	_filtered_players = _world_data.get("nfl_players", []).duplicate()
	_refresh_list()

func filter_by_search(search_text: String) -> void:
	# Filter local copy only
	_filtered_players = []
	var search_lower = search_text.to_lower()

	for player in _world_data.get("nfl_players", []):
		if player.get("name", "").to_lower().contains(search_lower):
			_filtered_players.append(player)

	_refresh_list()

func cleanup() -> void:
	_world_data.clear()
	_filtered_players.clear()

func _on_player_clicked(player_id: String) -> void:
	# Emit signal instead of calling explorer.show_player_detail()
	player_selected.emit(player_id)
```

## Node Path Reference

All exported node paths (configurable in editor):

```gdscript
year_label_path = "MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/YearLabel"
refresh_button_path = "MarginContainer/VBoxContainer/HeaderPanel/MarginContainer/HBoxContainer/RefreshButton"
search_field_path = "MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/SearchBox/SearchField"
clear_button_path = "MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/SearchBox/ClearButton"
detail_text_path = "MarginContainer/VBoxContainer/MainContent/DetailPanel/MarginContainer/DetailScroll/DetailText"
tabs_path = "MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/NavigationTabs"
```

## Error Handling

The implementation includes:
- Null-safe node access with `get_node_or_null()`
- Fatal error handling for missing critical nodes (scene disables itself)
- Graceful fallbacks for empty world state
- Comprehensive validation of world state structure and types
- User-friendly error messages displayed in the UI
- Debug build mutation detection for world_state

## Future Enhancements

Potential improvements for future tracks:
- Keyboard shortcuts (Ctrl+F for search, etc.)
- Export world data to JSON/CSV
- Bookmarking/favorites system
- Compare players side-by-side
- History navigation (back/forward)
- Dark/light theme toggle

## Implementation Notes

### Design Decisions

1. **NodePath Exports**: Used instead of @onready for flexibility and editor configuration
2. **Null Safety**: All node access is checked to prevent crashes
3. **Signal-Driven**: Uses Godot signals for clean event handling
4. **Stateless Panels**: Panels are re-initialized on refresh for consistency
5. **BBCode Formatting**: RichTextLabel enables rich, styled detail views

### Performance Considerations

- World state is passed by reference (not copied)
- Detail text is cleared before updates to free memory
- Search is delegated to individual panels (not centralized)
- No unnecessary scene tree traversals
- Selection state is efficiently managed and cleared on transitions

### Code Quality

- Follows Godot style guide
- Comprehensive inline documentation
- Clear separation of public/private methods
- Type hints throughout
- No magic numbers (all configurable)

## Troubleshooting

### Scene won't load
- Check that script paths are correct in TSCN file
- Ensure WorldExplorerConfig.gd is parseable

### Nodes not found
- Verify node paths match scene hierarchy
- Check console for error messages

### Detail panel blank
- Ensure world_state is loaded via `load_world_state()`
- Check that DetailText node exists and is visible

### Search not working
- Panels must implement `filter_by_search(String)` method
- Check that tab panels are properly initialized

## File Locations

```
/home/patrick/Documents/code/gridiron-dynasty/
├── scenes/ui/world_explorer/
│   ├── world_explorer.tscn
│   └── README.md (this file)
├── scripts/ui/world_explorer/
│   ├── WorldExplorer.gd
│   └── core/
│       └── WorldExplorerConfig.gd
├── world_explorer_test.tscn
└── world_explorer_test.gd
```

## Status

**Track 1: Complete** ✅

- Core infrastructure implemented
- Scene structure finalized
- Public API stable
- Ready for integration with other tracks
