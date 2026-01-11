# Draft & Retired Panels - Track 6 Implementation

## Overview

Track 6 introduces two new panels for the World Explorer UI:

1. **DraftPanel** - Browse draft-eligible players with ranking and grading
2. **RetiredPanel** - Explore retired players archive with career summaries

Both panels follow the established World Explorer architecture and integrate seamlessly with existing query utilities and formatters.

---

## Draft Panel

### Purpose

Display draft-eligible players organized by year with comprehensive ranking and grading. Shows top 200 prospects by default with position filtering and search capabilities.

### Key Features

- **Multi-year support**: Navigate between draft years dynamically
- **Draft grade calculation**: 0-100 composite rating (using DraftQueries.calculate_draft_grade())
- **Dual ranking system**: Overall rank + positional rank (e.g., "#5 overall (QB2)")
- **Position filtering**: Filter by specific positions
- **Search**: Filter by player name
- **School display**: Shows college/university affiliation

### Data Source

```gdscript
# Draft pool structure in world_state
world_state.draft_pool = {
    2025: [player1, player2, ...],  # ~520 players per year
    2026: [player1, player2, ...],
    # ...
}
```

### Scene Structure

```
DraftPanel (VBoxContainer)
├── FilterBarPanel
│   └── MarginContainer
│       └── FilterBar (HBoxContainer)
│           ├── YearLabel "Draft Year:"
│           ├── YearFilter (OptionButton) - Dynamic years
│           ├── Spacer1
│           ├── PositionLabel "Position:"
│           └── PositionFilter (OptionButton) - All/QB/RB/etc.
└── ContentPanel
    └── ContentList (Tree)
        Columns: [Rank, Player, Pos, School, Grade]
```

### Usage

```gdscript
# Initialize panel
var draft_panel = DraftPanel.new()
draft_panel.initialize(world_state)

# Filter by search
draft_panel.filter_by_search("Smith")

# Handle player selection
draft_panel.player_selected.connect(func(player_id):
    show_player_detail(player_id)
)
```

### Ranking Logic

**Overall Ranking**: All prospects sorted by draft grade (highest to lowest)

**Positional Ranking**: Calculated within each position group
- When "All" positions selected: Shows both ranks (e.g., "#5 overall (QB2)")
- When specific position selected: Shows positional rank only (e.g., "#1", "#2")

```gdscript
# Example ranking display
# Position: All
"#1 (QB1)"   - Best QB
"#2 (RB1)"   - Best RB
"#3 (QB2)"   - Second best QB

# Position: QB
"#1"  - Best QB
"#2"  - Second best QB
"#3"  - Third best QB
```

### Performance

- **Dataset size**: ~520 players per draft year
- **Display limit**: Top 200 prospects (configurable via MAX_PROSPECTS_DISPLAYED)
- **Expected load time**: <50ms for initial render
- **Search/filter time**: <30ms

---

## Retired Panel

### Purpose

Browse retired players with career summary information. Handles large datasets (5000+ players) with pagination and multiple sorting options.

### Key Features

- **Pagination**: 100 players per page
- **Multiple sort modes**:
  - Career Length (default)
  - Peak Rating
  - Name (alphabetical)
- **Position filtering**: Filter by specific positions
- **Search**: Filter by player name
- **Career summary**: Years played, teams, peak rating

### Data Source

```gdscript
# Retired players structure in world_state
world_state.retired_players = [player1, player2, ...]  # 5000+ players

# Player fields used:
player = {
    "career_start_year": 2015,
    "career_end_year": 2025,
    "career_length": 10,
    "career_teams": ["team_id_1", "team_id_2"],
    "peak_rating": 88.5,
    # ... other fields
}
```

### Scene Structure

```
RetiredPanel (VBoxContainer)
├── FilterBarPanel
│   └── MarginContainer
│       └── FilterBar (HBoxContainer)
│           ├── PositionLabel "Position:"
│           ├── PositionFilter (OptionButton)
│           ├── Spacer1
│           ├── SortLabel "Sort by:"
│           └── SortFilter (OptionButton)
├── ContentPanel
│   └── ContentList (Tree)
│       Columns: [Player, Pos, Career Years, Teams, Peak Rating]
└── PaginationBar (HBoxContainer)
    ├── PrevPageButton "<< Previous"
    ├── PageLabel "Page 1 of X"
    └── NextPageButton "Next >>"
```

### Usage

```gdscript
# Initialize panel
var retired_panel = RetiredPanel.new()
retired_panel.initialize(world_state)

# Change sort mode
retired_panel.sort_filter.select(SortMode.PEAK_RATING)

# Navigate pages
retired_panel._on_next_page_pressed()

# Handle player selection
retired_panel.player_selected.connect(func(player_id):
    show_player_detail(player_id)
)
```

### Career Summary Calculation

**Career Length**:
```gdscript
# Priority 1: Explicit career years
if player.has("career_start_year") and player.has("career_end_year"):
    career_length = end_year - start_year + 1

# Priority 2: Explicit career length field
elif player.has("career_length"):
    career_length = player.career_length

# Priority 3: Estimate from age (fallback)
else:
    career_length = min(age - 22, 15)  # Assume draft at 22, cap at 15 years
```

**Teams Played For**:
```gdscript
# Priority 1: career_teams array
if player.has("career_teams"):
    # Show up to 3 teams, then abbreviate
    if len(career_teams) <= 3:
        display = "DAL, PHI, NYG"
    else:
        display = "DAL (+3 more)"

# Priority 2: last_nfl_team_id
elif player.has("last_nfl_team_id"):
    display = team.name

# Fallback
else:
    display = "N/A"
```

**Peak Rating**:
```gdscript
# Priority 1: Explicit peak_rating field
if player.has("peak_rating"):
    return player.peak_rating

# Priority 2: Current composite rating (approximation)
else:
    return StatQueries.calculate_composite_rating(player)
```

### Pagination Logic

```gdscript
# Pagination calculation
items_per_page = 100
total_pages = ceil(filtered_players.size() / items_per_page)
current_page = 0 to (total_pages - 1)

# Display slice
start_idx = current_page * items_per_page
end_idx = min(start_idx + items_per_page, filtered_players.size())
display_players = filtered_players[start_idx:end_idx]
```

### Performance

- **Dataset size**: 5000+ retired players
- **Items per page**: 100
- **Expected load time**: <100ms for initial render
- **Sort time**: <150ms for full dataset
- **Page navigation**: <30ms

---

## Integration Guide

### Step 1: Add Panels to WorldExplorer Scene

1. Open `scenes/ui/world_explorer/world_explorer.tscn` in Godot
2. Locate the `NavigationTabs` node (under SidebarPanel)
3. Right-click → "Instance Child Scene"
4. Add both scenes:
   - `scenes/ui/world_explorer/panels/draft_panel.tscn`
   - `scenes/ui/world_explorer/panels/retired_panel.tscn`
5. Save the scene

### Step 2: Connect Signals in WorldExplorer

The panels already emit the required signals:
- `player_selected(player_id: String)`
- `team_selected(team_id: String, level: String)` (unused in these panels)

WorldExplorer should automatically connect these if it follows the established pattern.

### Step 3: Test Integration

Run the game and verify:

**Draft Panel Tests:**
- [ ] Draft years populate in YearFilter
- [ ] Can switch between years
- [ ] Position filter works correctly
- [ ] Rankings display (overall + positional)
- [ ] Draft grades are color-coded
- [ ] Search filters players by name
- [ ] Clicking player shows detail panel

**Retired Panel Tests:**
- [ ] Pagination displays correct page count
- [ ] Can navigate between pages
- [ ] Sort by Career Length works
- [ ] Sort by Peak Rating works
- [ ] Sort by Name (alphabetical) works
- [ ] Position filter works correctly
- [ ] Career summary displays correctly
- [ ] Peak ratings are color-coded
- [ ] Search filters players by name
- [ ] Clicking player shows detail panel

---

## Data Requirements

### Draft Panel Requirements

The panel expects `world_state.draft_pool` to be a Dictionary with structure:

```gdscript
draft_pool = {
    2025: [
        {
            "id": "player_123",
            "first_name": "John",
            "last_name": "Smith",
            "position": "QB",
            "college_id": "college_456",
            "stats": {
                "throw_power": 85,
                "throw_accuracy": 80,
                # ... other stats
            }
        },
        # ... more players
    ],
    2026: [...]
}
```

**Required player fields:**
- `id` or `player_id` (string)
- `first_name` (string)
- `last_name` (string)
- `position` (string: QB, RB, WR, etc.)
- `college_id` (string)
- `stats` (Dictionary of stat_name: value)

### Retired Panel Requirements

The panel expects `world_state.retired_players` to be an Array:

```gdscript
retired_players = [
    {
        "id": "player_789",
        "first_name": "Tom",
        "last_name": "Brady",
        "position": "QB",
        "career_start_year": 2000,
        "career_end_year": 2022,
        "career_length": 23,  # Optional if years provided
        "career_teams": ["team_1", "team_2"],  # Optional
        "peak_rating": 95.0,  # Optional (will use current rating)
        "stats": {...}
    },
    # ... more players
]
```

**Required player fields:**
- `id` or `player_id` (string)
- `first_name` (string)
- `last_name` (string)
- `position` (string)
- `stats` (Dictionary - for composite rating calculation)

**Optional player fields** (used for better display):
- `career_start_year` (int)
- `career_end_year` (int)
- `career_length` (int)
- `career_teams` (Array of team IDs)
- `peak_rating` (float)
- `last_nfl_team_id` (string)

---

## Query Dependencies

### Draft Panel

Uses the following query utilities:

```gdscript
# DraftQueries
DraftQueries.get_draft_years(world_state) -> Array[int]
DraftQueries.get_draft_pool(world_state, year) -> Array[Dictionary]
DraftQueries.calculate_draft_grade(player) -> float

# PlayerQueries
PlayerQueries.get_player_id(player) -> String
PlayerQueries.get_player_name(player) -> String

# TeamQueries
TeamQueries.get_college(world_state, college_id) -> Dictionary

# StatQueries
StatQueries.get_stat_color(value) -> Color
StatQueries.calculate_composite_rating(player) -> float
```

### Retired Panel

Uses the following query utilities:

```gdscript
# PlayerQueries
PlayerQueries.get_retired_players(world_state) -> Array[Dictionary]
PlayerQueries.get_player_id(player) -> String
PlayerQueries.get_player_name(player) -> String

# TeamQueries
TeamQueries.get_nfl_team(world_state, team_id) -> Dictionary

# StatQueries
StatQueries.get_stat_color(value) -> Color
StatQueries.calculate_composite_rating(player) -> float
```

---

## Common Issues & Solutions

### Issue 1: Draft panel shows no years

**Symptom**: YearFilter is empty, no content displays

**Solution**:
1. Verify `world_state.draft_pool` exists and is not empty
2. Check that draft_pool keys are integers (years), not strings
3. Add debug print in `_initialize_year_filter()` to check years array

```gdscript
var years = DraftQueries.get_draft_years(world_state)
print("Draft years available: ", years)  # Should show [2025, 2026, ...]
```

### Issue 2: Retired panel shows wrong career length

**Symptom**: Career years display "N/A" or incorrect values

**Solution**:
1. Ensure retired players have `career_start_year` and `career_end_year` fields
2. Alternatively, add `career_length` field to player data
3. Check console for calculation warnings

### Issue 3: Pagination shows incorrect page count

**Symptom**: Page label shows "Page 1 of 0" or wrong total

**Solution**:
1. Verify `filtered_players` array is populated correctly
2. Check that `items_per_page` is set to 100 (not 0)
3. Add debug print in `_update_pagination()`:

```gdscript
print("Filtered players: %d, Pages: %d" % [filtered_players.size(), total_pages])
```

### Issue 4: Rankings don't match in Draft Panel

**Symptom**: Ranks are duplicated or incorrect

**Solution**:
1. Verify sorting is done before displaying
2. Check that `pos_counters` Dictionary is reset before loop
3. Ensure draft grades are calculated for all players

### Issue 5: Performance issues with large datasets

**Symptom**: UI freezes or lags when filtering/sorting

**Solution**:

For Draft Panel:
- Reduce `MAX_PROSPECTS_DISPLAYED` from 200 to 100
- Consider caching draft grades on initialization

For Retired Panel:
- Reduce `items_per_page` from 100 to 50
- Implement search debouncing (delay search until typing stops)
- Cache sorted results

---

## Extension Points

### Adding a New Sort Mode (Retired Panel)

1. Add enum value:
```gdscript
enum SortMode {
    CAREER_LENGTH,
    PEAK_RATING,
    NAME,
    TOTAL_GAMES_PLAYED  # New sort mode
}
```

2. Add to sort filter:
```gdscript
func _setup_filters():
    # ...
    sort_filter.add_item("Games Played", SortMode.TOTAL_GAMES_PLAYED)
```

3. Add sort logic:
```gdscript
func _filter_and_sort_players():
    match current_sort_mode:
        # ... existing cases
        SortMode.TOTAL_GAMES_PLAYED:
            retired_players.sort_custom(func(a, b):
                var games_a = a.get("total_games_played", 0)
                var games_b = b.get("total_games_played", 0)
                return games_a > games_b
            )
```

### Adding Draft Combine Data (Draft Panel)

1. Add columns to tree:
```gdscript
content_list.columns = 7  # Instead of 5
content_list.set_column_title(5, "40-Yard")
content_list.set_column_title(6, "Bench")
```

2. Display combine stats:
```gdscript
var forty_time = player.get("forty_yard_dash", 0.0)
item.set_text(5, "%.2fs" % forty_time if forty_time > 0 else "N/A")

var bench_press = player.get("bench_press_reps", 0)
item.set_text(6, str(bench_press) if bench_press > 0 else "N/A")
```

---

## Testing Checklist

### Draft Panel
- [ ] Draft years populate correctly from world_state
- [ ] Can switch between draft years
- [ ] Position filter shows all positions
- [ ] Position filter "All" shows both overall and positional ranks
- [ ] Position filter specific position shows positional rank only
- [ ] Rankings are sequential (1, 2, 3, ...)
- [ ] Draft grades are accurate and color-coded
- [ ] School names display correctly
- [ ] Search filters by player name (case-insensitive)
- [ ] Clicking player emits player_selected signal
- [ ] Top 200 prospects displayed (or less if fewer exist)

### Retired Panel
- [ ] All retired players load correctly
- [ ] Pagination shows correct page count
- [ ] "Previous" button disabled on first page
- [ ] "Next" button disabled on last page
- [ ] Can navigate forward and backward through pages
- [ ] Sort by Career Length orders correctly
- [ ] Sort by Peak Rating orders correctly
- [ ] Sort by Name orders alphabetically
- [ ] Position filter works on all pages
- [ ] Career years format correctly (e.g., "2015-2025 (10 yrs)")
- [ ] Teams display correctly (abbreviated if >3 teams)
- [ ] Peak ratings are accurate and color-coded
- [ ] Search filters by player name across all pages
- [ ] Page resets to 1 when filter/search changes
- [ ] Clicking player emits player_selected signal

---

## File Locations

### Scene Files
- `/home/patrick/Documents/code/gridiron-dynasty/scenes/ui/world_explorer/panels/draft_panel.tscn`
- `/home/patrick/Documents/code/gridiron-dynasty/scenes/ui/world_explorer/panels/retired_panel.tscn`

### Script Files
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/panels/DraftPanel.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/panels/RetiredPanel.gd`

### Dependencies
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/queries/DraftQueries.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/queries/PlayerQueries.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/queries/TeamQueries.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/queries/StatQueries.gd`

---

## Summary

Track 6 provides two robust panels for exploring draft prospects and retired players:

**DraftPanel** excels at:
- Multi-year draft pool navigation
- Dual ranking system (overall + positional)
- Draft grade calculation and visualization
- Efficient filtering and search

**RetiredPanel** excels at:
- Handling large datasets with pagination
- Multiple sorting options
- Career summary display
- Performance with 5000+ players

Both panels follow the established World Explorer patterns, integrate seamlessly with existing query utilities, and provide intuitive user interfaces for exploring player data.
