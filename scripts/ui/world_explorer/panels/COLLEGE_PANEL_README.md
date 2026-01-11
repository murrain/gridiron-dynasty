# College Panel Implementation

## Overview

The College Panel provides a comprehensive interface for exploring college football programs and players in the World Explorer UI.

## Files Created

1. **Scene**: `/home/patrick/Documents/code/gridiron-dynasty/scenes/ui/world_explorer/panels/college_panel.tscn`
2. **Script**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/panels/CollegePanel.gd`

## Features

### Three View Modes

1. **Schools View** (default)
   - Lists all 130 colleges
   - Shows: School name, Tier, Eliteness, Roster size, Draft-eligible count
   - Sortable by name (alphabetical)
   - Tier filtering (All/Elite/Power5/Mid-Major)

2. **Players by Class**
   - Hierarchical tree grouped by class year
   - Groups: Senior, Junior, Sophomore, Freshman
   - Shows: Player name, Position, School, Rating
   - Draft-eligible players marked with ★
   - Sorted by rating within each class

3. **All Players**
   - Flat list of all college players
   - Shows: Player name, Position, Class (FR/SO/JR/SR), School, Rating
   - Filters: Tier, Position, Class
   - Draft-eligible players marked with ★
   - Sorted by rating (highest first)

### Filtering System

- **Tier Filter**: Elite / Power 5 / Mid-Major (available in all views)
- **Position Filter**: All positions (QB, RB, WR, TE, OL, DL, LB, CB, S, K, P) - All Players view only
- **Class Filter**: Freshman / Sophomore / Junior / Senior - All Players view only
- **Search**: Filters by player name or school name (integrated with WorldExplorer search)

### Draft Eligibility Logic

Players are marked as draft-eligible if:
- **Seniors** (Year 4) with rating ≥ 65
- **Juniors** (Year 3) with rating ≥ 80 (early declaration)

Draft-eligible players are marked with a ★ symbol in their name.

## Integration with WorldExplorer

### Required Interface

The panel implements the WorldExplorer panel contract:

```gdscript
# Required methods
func initialize(world_state: Dictionary) -> void
func filter_by_search(search_text: String) -> void
func cleanup() -> void  # Optional

# Required signals
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)
```

### Adding to WorldExplorer

To add the College Panel to the WorldExplorer:

1. Open `scenes/ui/world_explorer/world_explorer.tscn` in the Godot editor
2. Navigate to the `NavigationTabs` node (path: `MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/NavigationTabs`)
3. Right-click `NavigationTabs` and select "Instance Child Scene"
4. Select `scenes/ui/world_explorer/panels/college_panel.tscn`
5. The tab will automatically be named "College Panel" (you can rename it to just "College" in the inspector)
6. Save the scene

The WorldExplorer will automatically:
- Call `initialize(world_state)` when loaded or refreshed
- Call `filter_by_search(text)` when the search field changes
- Connect to `player_selected` and `team_selected` signals
- Show player/team details in the detail panel when selections are made

## Data Requirements

The panel expects the following structure in `world_state`:

```gdscript
{
    "colleges": [
        {
            "id": String,
            "name": String,
            "tier": String,  # "elite", "power5", "mid_major"
            "eliteness": float,  # 0-100 scale
            "region": String,
            "capacity": int
        }
    ],
    "college_rosters": {
        "college_id": {
            "players": [
                {
                    "id": String,  # or "player_id"
                    "first_name": String,
                    "last_name": String,
                    "position": String,
                    "college_id": String,
                    "college_year": int,  # 1-4 (FR/SO/JR/SR)
                    "stats": Dictionary,  # Used for rating calculation
                    "age": int
                }
            ]
        }
    }
}
```

## Dependencies

- **PlayerQueries**: Player search, filtering, and retrieval
- **TeamQueries**: College/roster queries
- **StatQueries**: Rating calculation and color coding

## Color Coding

### Eliteness (Schools View)
- ≥90: Bright green (#00ff00)
- ≥80: Light green (#66ff66)
- ≥70: Pale green (#99ff99)
- ≥60: Yellow (#ffff00)
- ≥50: Orange (#ffaa00)
- <50: Light red (#ff6666)

### Player Ratings (All Views)
Uses `StatQueries.get_stat_color()` for consistent color coding across the app:
- ≥90: Elite (green)
- ≥80: Great (light green)
- ≥70: Good (pale green)
- ≥60: Average (yellow)
- ≥50: Below average (orange)
- <50: Poor (red)

## Testing Checklist

- [ ] All 130 colleges display in Schools view
- [ ] Tier filter correctly filters Elite/Power5/Mid-Major
- [ ] Class filter works in All Players mode
- [ ] Position filter works in All Players mode
- [ ] Draft-eligible players are marked with ★
- [ ] Players by Class groups correctly (SR/JR/SO/FR)
- [ ] Search filters schools and players
- [ ] Clicking a school emits `team_selected(college_id, "college")`
- [ ] Clicking a player emits `player_selected(player_id)`
- [ ] View mode changes update filter visibility
- [ ] Ratings are color-coded correctly
- [ ] Performance is acceptable with ~6500 college players

## Performance Considerations

- **Caching**: All colleges and players are cached on `initialize()` to avoid repeated queries
- **Lazy filtering**: Filters are applied on-demand when view changes or filters update
- **Efficient grouping**: Players are grouped using dictionaries for O(1) lookups
- **Sort optimization**: Uses GDScript's built-in `sort_custom()` for efficient sorting

## Known Limitations

1. Does not currently support multi-column sorting
2. Search is case-insensitive substring match only (no regex)
3. Tree columns cannot be resized by the user (Godot limitation)
4. Draft eligibility logic is simplified (doesn't account for position-specific rules)

## Future Enhancements

- Add stat comparison view for multiple players
- Add recruiting rankings/stars
- Show conference affiliations
- Add depth chart view per school
- Export filtered lists to CSV
- Add advanced search (regex, multi-field)
- Show transfer portal status
