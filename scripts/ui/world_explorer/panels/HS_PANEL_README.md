# High School Panel - Complete Documentation

## Overview

The High School Panel is the fifth track of the World Explorer UI system. It provides comprehensive exploration of the 400 high school football programs and approximately 1,800 active players across four view modes with pagination and advanced filtering.

## Files

- **Scene**: `scenes/ui/world_explorer/panels/hs_panel.tscn`
- **Script**: `scripts/ui/world_explorer/panels/HsPanel.gd`
- **Test**: `scripts/ui/world_explorer/panels/test_hs_panel.gd`

## Architecture

### View Modes

1. **Schools View** - Paginated list of all high schools
2. **Players by Year** - Hierarchical tree grouped by year (1-4)
3. **All Players** - Flat list with position and year filters
4. **Seniors Only** - Graduating class with college eligibility tracking

### Key Features

- **Pagination**: 50 schools per page (8 total pages for 400 schools)
- **College Eligibility**: Automatically marks seniors who qualify for college (rating 50+)
- **Tier Filtering**: Powerhouse, Competitive, Developmental
- **Multi-level Filtering**: Position, Year, Tier, and Search
- **Smart Grouping**: Seniors Only view groups by school with top programs first

## Data Model

### High School Structure

```gdscript
{
    "id": String,                    # Unique school ID
    "name": String,                  # School name
    "region": String,                # Geographic region
    "tier": String,                  # "powerhouse" | "competitive" | "developmental"
    "program_quality_tier": String   # Program development rating
}
```

### High School Player Structure

```gdscript
{
    "id": String,              # Unique player ID
    "player_id": String,       # Alternative ID field
    "first_name": String,      # First name
    "last_name": String,       # Last name
    "position": String,        # "QB" | "RB" | "WR" | etc.
    "hs_school_id": String,    # Reference to school ID
    "hs_year": int,            # Year 1-4 (not FR/SO/JR/SR)
    # Attributes...
}
```

## View Mode Details

### 1. Schools View

**Purpose**: Browse all 400 high schools with pagination

**Columns**:
- School Name
- Region
- Tier (color-coded)
- Program Quality
- Roster Size
- Seniors Count

**Pagination**:
- 50 schools per page
- 8 total pages
- Navigation buttons enable/disable at boundaries
- Page indicator shows current/total

**Sorting**: Alphabetical by school name

**Filtering**:
- Tier filter (All, Powerhouse, Competitive, Developmental)
- Search by school name

**Implementation**:
```gdscript
func _render_schools_view() -> void:
    # Configure 6 columns
    content_list.columns = 6

    # Filter and paginate
    var filtered_schools = _filter_schools(all_hs_schools)
    var start_idx = current_page * SCHOOLS_PER_PAGE
    var page_schools = filtered_schools.slice(start_idx, start_idx + SCHOOLS_PER_PAGE)

    # Populate tree with metadata
    for school in page_schools:
        var item = content_list.create_item(root)
        item.set_metadata(0, {"type": "school", "id": school_id})
```

### 2. Players by Year View

**Purpose**: Hierarchical exploration of players grouped by class year

**Structure**:
```
Year 1 (450 players)
  ├─ Player A (70 rating)
  ├─ Player B (68 rating)
  └─ ...
Year 2 (450 players)
  └─ ...
Year 3 (450 players)
  └─ ...
Year 4 (Seniors) (450 players)
  ├─ ★ College-eligible senior (rating 65)
  └─ ...
```

**Columns**:
- Year / Player
- Position
- School
- Rating (color-coded)

**Sorting**: Within each year, players sorted by rating (highest first)

**College Eligibility**: Seniors with rating 50+ marked with ★

**Filtering**:
- Tier filter (applies to player's school)
- Search by player name or school name

### 3. All Players View

**Purpose**: Flat list of all HS players with multi-filter capability

**Columns**:
- Player Name (★ if college-eligible)
- Position
- Year (1-4)
- School
- Rating (color-coded)

**Sorting**: By rating descending (top prospects first)

**Filtering**:
- Tier filter
- Position filter (QB, RB, WR, TE, OL, DL, LB, CB, S, K, P)
- Year filter (1, 2, 3, 4)
- Search by player or school name

**Use Cases**:
- Find all Year 3 QBs
- Scout top WRs from Powerhouse schools
- Compare players across schools

### 4. Seniors Only View

**Purpose**: College recruiting focus - graduating class with eligibility

**Structure**:
```
Springfield High (8 seniors, 5 eligible)
  ├─ ★ John Smith (QB, 72 rating) → Power 5
  ├─ ★ Mike Jones (RB, 68 rating) → Power 5
  ├─ ★ Tom Brown (WR, 55 rating) → Mid-Major
  └─ Bob White (K, 45 rating) → Retire
```

**Columns**:
- Player Name (★ if eligible)
- Position
- School
- Rating (color-coded)
- Projected Level

**Grouping**: By school, ordered by average senior rating (top schools first)

**Projected Level Logic**:
```gdscript
func _get_projected_college_level(rating: float) -> String:
    if rating >= 75.0: return "Elite"
    elif rating >= 65.0: return "Power 5"
    elif rating >= 55.0: return "Mid-Major"
    else: return "Developmental"
```

**Eligibility Threshold**: Rating >= 50.0

**Use Cases**:
- Identify college prospects
- Track graduating class strength by school
- Forecast next year's college rosters

## College Eligibility System

### Rules

**Eligible**:
- Must be Year 4 (senior)
- Rating >= 50.0

**Visual Indicators**:
- ★ prefix on player name
- "Projected Level" column shows college tier
- Green color for eligible, red for retire

### Implementation

```gdscript
func _is_college_eligible(player: Dictionary) -> bool:
    var hs_year = player.get("hs_year", 0)
    var rating = StatQueries.calculate_composite_rating(player)

    # Must be senior (year 4)
    if hs_year != 4:
        return false

    # Minimum rating threshold for college
    return rating >= MIN_COLLEGE_ELIGIBLE_RATING  # 50.0
```

### Counting

```gdscript
func _count_college_eligible(players: Array) -> int:
    var count = 0
    for player in players:
        if _is_college_eligible(player):
            count += 1
    return count
```

## Pagination System

### Constants

```gdscript
const SCHOOLS_PER_PAGE: int = 50
```

### Calculation

```gdscript
var total_schools = filtered_schools.size()
total_pages = ceili(float(total_schools) / float(SCHOOLS_PER_PAGE))
```

### Navigation

```gdscript
func _on_prev_page_pressed() -> void:
    if current_page > 0:
        current_page -= 1
        _update_view()

func _on_next_page_pressed() -> void:
    if current_page < total_pages - 1:
        current_page += 1
        _update_view()
```

### Button States

```gdscript
func _update_pagination_controls() -> void:
    page_label.text = "Page %d of %d" % [current_page + 1, total_pages]
    prev_page_button.disabled = (current_page == 0)
    next_page_button.disabled = (current_page >= total_pages - 1)
```

## Filtering System

### Tier Filter

**Options**: All, Powerhouse, Competitive, Developmental

**Applies To**: All views

**Logic**:
```gdscript
func _passes_tier_filter(school: Dictionary) -> bool:
    if current_tier_filter == TierFilterIndex.ALL:
        return true

    var tier = school.get("tier", "").to_lower()

    match current_tier_filter:
        TierFilterIndex.POWERHOUSE: return tier == "powerhouse"
        TierFilterIndex.COMPETITIVE: return tier == "competitive"
        TierFilterIndex.DEVELOPMENTAL: return tier == "developmental"

    return false
```

### Position Filter

**Options**: All, QB, RB, WR, TE, OL, DL, LB, CB, S, K, P

**Applies To**: All Players view only

**Visibility**: Shown only in All Players mode

### Year Filter

**Options**: All, Year 1, Year 2, Year 3, Year 4

**Applies To**: All Players view only

**Visibility**: Shown only in All Players mode

### Search Filter

**Applies To**: All views

**Behavior**:
- Schools view: Searches school names
- Player views: Searches player names and school names
- Case-insensitive
- Partial match

**Implementation**:
```gdscript
func filter_by_search(search_text: String) -> void:
    current_search = search_text
    _reset_pagination()  # Reset to page 0 when searching
    _update_view()
```

## Display Formatting

### Region Display

```gdscript
func _get_region_display(region: String) -> String:
    return region.capitalize().replace("_", " ")
    # "midwest" → "Midwest"
    # "south_central" → "South Central"
```

### Tier Display

```gdscript
func _get_tier_display(tier: String) -> String:
    match tier.to_lower():
        "powerhouse": return "Powerhouse"
        "competitive": return "Competitive"
        "developmental": return "Developmental"
        _: return tier.capitalize()
```

### Program Quality Display

```gdscript
func _get_program_quality_display(quality_tier: String) -> String:
    match quality_tier.to_lower():
        "elite_dev": return "Elite Development"
        "strong_dev": return "Strong Development"
        "solid_dev": return "Solid Development"
        "average_dev": return "Average Development"
        "below_avg_dev": return "Below Average"
        "poor_dev": return "Poor Development"
        _: return quality_tier.capitalize().replace("_", " ")
```

### Color Coding

**Tier Colors**:
```gdscript
func _get_tier_color(tier: String) -> Color:
    match tier.to_lower():
        "powerhouse": return Color("#00ff00")  # Green
        "competitive": return Color("#ffff00")  # Yellow
        "developmental": return Color("#ffaa00")  # Orange
        _: return Color("#ffffff")  # White
```

**Rating Colors**: Uses `StatQueries.get_stat_color(rating)`

## Signal Emission

### player_selected(player_id: String)

**Emitted When**: User clicks a player in any view

**Metadata Format**:
```gdscript
item.set_metadata(0, {"type": "player", "id": player_id})
```

**Handler in WorldExplorer**:
```gdscript
func show_player_detail(player_id: String) -> void:
    var player = PlayerQueries.get_player_by_id(world_state, player_id)
    var bbcode = PlayerDetailFormatter.format(player, world_state)
    detail_text.text = bbcode
```

### team_selected(team_id: String, level: String)

**Emitted When**: User clicks a school in Schools view

**Metadata Format**:
```gdscript
item.set_metadata(0, {"type": "school", "id": school_id})
```

**Level**: Always "hs" for high schools

**Handler in WorldExplorer**:
```gdscript
func show_team_detail(team_id: String, level: String) -> void:
    var team = TeamQueries.get_hs_school(world_state, team_id)
    var bbcode = TeamDetailFormatter.format(team, world_state, level)
    detail_text.text = bbcode
```

## Performance Considerations

### Expected Data Volumes

- **Schools**: 400
- **Players**: ~1,800 active (450 per year)
- **Seniors**: ~450
- **College-eligible**: ~100-200 (varies by ratings)

### Optimization Strategies

1. **Pagination**: Limits rendering to 50 schools at a time
2. **Caching**: Stores all_hs_schools and all_hs_players on initialization
3. **Filtering**: Applied before rendering, not during
4. **Sorting**: Done once per view refresh, not per item

### Performance Targets

- **Initialization**: <100ms
- **View switching**: <50ms
- **Pagination**: <30ms
- **Filtering**: <40ms
- **Search**: <60ms

### Profiling

```gdscript
func _update_view() -> void:
    var start_time = Time.get_ticks_msec()
    # ... render logic ...
    var elapsed = Time.get_ticks_msec() - start_time
    if elapsed > 100:
        push_warning("HsPanel._update_view() took %d ms (threshold: 100ms)" % elapsed)
```

## Testing

### Unit Tests

Run `test_hs_panel.gd` to verify:

- [x] Panel initialization
- [x] Schools view rendering
- [x] Pagination (next/prev)
- [x] Players by Year view
- [x] All Players view with filters
- [x] Seniors Only view
- [x] College eligibility calculation
- [x] Signal emission

### Manual Testing Checklist

- [ ] Schools view shows 50 schools per page
- [ ] Pagination navigates all 8 pages
- [ ] Prev/Next buttons disable at boundaries
- [ ] Tier filter correctly filters schools
- [ ] Position filter works in All Players mode
- [ ] Year filter works in All Players mode
- [ ] College-eligible seniors marked with ★
- [ ] Seniors Only groups by school
- [ ] Projected Level shows correct tier
- [ ] Search filters schools by name
- [ ] Search filters players by name and school
- [ ] Clicking school shows school detail
- [ ] Clicking player shows player detail
- [ ] View mode switching updates filter visibility
- [ ] Ratings color-coded correctly
- [ ] No console errors during use

## Integration

### Step 1: Add to WorldExplorer

1. Open `scenes/ui/world_explorer/world_explorer.tscn` in Godot
2. Select `NavigationTabs` node
3. Right-click → "Instance Child Scene"
4. Choose `scenes/ui/world_explorer/panels/hs_panel.tscn`
5. The tab name will default to "Hs Panel" - rename to "High Schools"
6. Save the scene

### Step 2: Verify Integration

1. Run bootstrap to generate world state
2. Open World Explorer
3. Click "High Schools" tab
4. Verify schools and players appear
5. Test all view modes
6. Test pagination
7. Test filters and search

### Step 3: Test Signals

1. Click a school → verify detail panel shows school info
2. Click a player → verify detail panel shows player info
3. Switch views → verify selection clears
4. Use search → verify results update

## Common Issues

### Issue: Empty Schools View

**Symptoms**: Tab loads but no schools appear

**Causes**:
- world_state missing "hs_schools" key
- hs_schools is empty array
- Filtering too aggressive (all schools filtered out)

**Solutions**:
1. Check `world_state.get("hs_schools", [])` in console
2. Verify bootstrap created schools
3. Reset tier filter to "All"
4. Clear search text

### Issue: Pagination Not Working

**Symptoms**: Can't navigate pages or stuck on one page

**Causes**:
- total_pages calculated incorrectly
- current_page out of bounds
- Button signals not connected

**Solutions**:
1. Check `total_pages` value in debugger
2. Verify button connections in scene file
3. Add debug prints in `_on_prev_page_pressed` / `_on_next_page_pressed`

### Issue: College Eligibility Not Showing

**Symptoms**: No ★ marks on seniors or all marked as "Retire"

**Causes**:
- Rating calculation failing
- MIN_COLLEGE_ELIGIBLE_RATING too high
- hs_year field incorrect

**Solutions**:
1. Verify `StatQueries.calculate_composite_rating()` works
2. Check MIN_COLLEGE_ELIGIBLE_RATING = 50.0
3. Print player ratings in Seniors Only view

### Issue: Filters Not Visible

**Symptoms**: Position/Year filters don't appear in All Players mode

**Causes**:
- `_update_filter_visibility()` not called
- View mode change signal not connected
- Node paths incorrect

**Solutions**:
1. Call `_update_filter_visibility()` after view mode change
2. Verify signal connections in `_connect_signals()`
3. Check `@onready` node references

## API Reference

### Public Methods

```gdscript
# Required by WorldExplorer
func initialize(ws: Dictionary) -> void
func filter_by_search(search_text: String) -> void

# Optional
func cleanup() -> void
```

### Public Signals

```gdscript
signal player_selected(player_id: String)
signal team_selected(team_id: String, level: String)
```

### Constants

```gdscript
const SCHOOLS_PER_PAGE: int = 50
const MIN_COLLEGE_ELIGIBLE_RATING: float = 50.0
```

### Enums

```gdscript
enum ViewMode {
    SCHOOLS,
    PLAYERS_BY_YEAR,
    ALL_PLAYERS,
    SENIORS_ONLY
}

enum TierFilterIndex {
    ALL = 0,
    POWERHOUSE = 1,
    COMPETITIVE = 2,
    DEVELOPMENTAL = 3
}

enum YearFilterIndex {
    ALL = 0,
    YEAR1 = 1,
    YEAR2 = 2,
    YEAR3 = 3,
    YEAR4 = 4
}

enum PositionFilterIndex {
    ALL = 0,
    QB = 1,
    RB = 2,
    # ... etc
}
```

## Future Enhancements

### Potential Additions

1. **Recruits View**: Track recruited players by college
2. **Compare Schools**: Side-by-side comparison of programs
3. **Prospect Rankings**: League-wide ranking of top seniors
4. **Export**: Export senior class to CSV for scouting
5. **Advanced Stats**: Team statistics (wins/losses if tracking games)

### Performance Improvements

1. **Virtualized Scrolling**: For views with 1000+ items
2. **Search Indexing**: Pre-build search index for instant results
3. **Lazy Loading**: Load player details on-demand
4. **Background Threading**: Move filtering to worker thread

## References

- **Query Utilities**: `PlayerQueries.gd`, `TeamQueries.gd`, `StatQueries.gd`
- **Integration Guide**: `INTEGRATION_GUIDE.md`
- **Similar Panels**: `CollegePanel.gd`, `NflPanel.gd`
- **WorldExplorer**: `WorldExplorer.gd`

## Support

For questions or issues:

1. Check console for error messages
2. Verify world_state structure matches expected format
3. Review `test_hs_panel.gd` for usage examples
4. Check `INTEGRATION_GUIDE.md` for common problems
5. Compare with working panels (NFL, College)
