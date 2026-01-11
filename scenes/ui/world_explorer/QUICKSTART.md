# World Explorer - Quick Start Guide

## For Developers Adding New Features

### How to Use the World Explorer in Your Scene

```gdscript
extends Node

# Preload the scene
const WorldExplorerScene = preload("res://scenes/ui/world_explorer/world_explorer.tscn")

func _ready():
	# Instance the scene
	var explorer = WorldExplorerScene.instantiate()
	add_child(explorer)

	# Load your world state
	var world_state = load_world_from_somewhere()
	explorer.load_world_state(world_state)
```

### How to Show Details Programmatically

```gdscript
# Show player detail
explorer.show_player_detail("player_123")

# Show team detail
explorer.show_team_detail("KC", "NFL")

# Clear and show welcome screen
explorer.clear_detail()
```

### How to Add a New Tab Panel (Tracks 3-7)

1. **Create your panel scene:**
```
MyPanel (Control)
└── VBoxContainer
	├── ItemList
	└── [other controls]
```

2. **Create panel script:**
```gdscript
extends Control

var world_state: Dictionary
var explorer: WorldExplorer

# Called by WorldExplorer on initialization
func initialize(ws: Dictionary, exp: WorldExplorer) -> void:
	world_state = ws
	explorer = exp
	_populate_list()

# Called when search text changes
func filter_by_search(search_text: String) -> void:
	_update_filtered_list(search_text)

func _on_item_selected(index: int) -> void:
	var player_id = _get_player_id_at_index(index)
	explorer.show_player_detail(player_id)
```

3. **Add to world_explorer.tscn:**
- Open the scene in Godot
- Select NavigationTabs node
- Add your panel as a child
- Set the tab name in the inspector

### World State Structure

```gdscript
{
	"current_year": 2025,

	# NFL
	"nfl_teams": [
		{"id": "KC", "name": "Kansas City Chiefs", ...}
	],
	"nfl_rosters": {
		"KC": {"players": ["p1", "p2", ...]}
	},

	# College
	"colleges": [
		{"id": "ALA", "name": "Alabama", ...}
	],
	"college_rosters": {
		"ALA": {"players": ["c1", "c2", ...]}
	},

	# High School
	"hs_schools": [
		{"id": "hs1", "name": "Central High", ...}
	],
	"hs_players": ["h1", "h2", ...],

	# Draft
	"draft_pool": {
		2025: ["d1", "d2", ...],
		2026: [...]
	},

	# Retired
	"retired_players": ["r1", "r2", ...]
}
```

### Configuration

To customize behavior, create a WorldExplorerConfig resource:

```gdscript
var config = WorldExplorerConfig.new()
config.auto_scroll_detail = true
config.max_search_results = 50
config.color_elite = "#00ff00"

explorer.config = config
```

### Common Patterns

#### Pattern 1: Update on Selection
```gdscript
func _on_item_selected(item_id: String) -> void:
	explorer.show_player_detail(item_id)
```

#### Pattern 2: Filtered Search
```gdscript
func filter_by_search(search_text: String) -> void:
	item_list.clear()
	var filtered = _filter_items(search_text)
	for item in filtered:
		item_list.add_item(item.name)
```

#### Pattern 3: Tab Initialization
```gdscript
func initialize(ws: Dictionary, exp: WorldExplorer) -> void:
	world_state = ws
	explorer = exp
	_load_data()
	_connect_signals()
```

### Keyboard Shortcuts (in test scene)

- **F5**: Refresh UI
- **1**: Show player detail test
- **2**: Show team detail test
- **3**: Clear detail panel

### Debug Tips

1. **Check node paths:**
```gdscript
print(explorer.detail_text)  # Should not be null
print(explorer.tabs)          # Should not be null
```

2. **Verify world state loaded:**
```gdscript
print(explorer.world_state.size())  # Should be > 0
```

3. **Test panel integration:**
```gdscript
var panel = explorer.tabs.get_tab_control(0)
print(panel.has_method("initialize"))  # Should be true
```

### File Paths Reference

```
Core Files:
  scenes/ui/world_explorer/world_explorer.tscn
  scripts/ui/world_explorer/WorldExplorer.gd
  scripts/ui/world_explorer/core/WorldExplorerConfig.gd

Test Files:
  world_explorer_test.tscn
  world_explorer_test.gd

Documentation:
  scenes/ui/world_explorer/README.md
  TRACK1_IMPLEMENTATION_SUMMARY.md
```

### Need Help?

1. Check README.md for architecture details
2. Check TRACK1_IMPLEMENTATION_SUMMARY.md for implementation info
3. Run world_explorer_test.tscn to see working example
4. Look at existing formatter/query scripts for patterns

### Quick Checklist for New Panels

- [ ] Scene created with proper structure
- [ ] Script extends Control
- [ ] `initialize(ws, exp)` method implemented
- [ ] `filter_by_search(text)` method implemented
- [ ] Signals connected to call explorer methods
- [ ] Added as child of NavigationTabs
- [ ] Tab name set in inspector
- [ ] Tested with mock world state

---

**Version**: Track 1 Complete
**Last Updated**: January 10, 2026
