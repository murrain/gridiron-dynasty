# College Panel - Integration Guide

## Quick Start

### Step 1: Add Panel to WorldExplorer

1. Open `scenes/ui/world_explorer/world_explorer.tscn` in Godot
2. Select the `NavigationTabs` node (under SidebarPanel)
3. Right-click → "Instance Child Scene"
4. Choose `scenes/ui/world_explorer/panels/college_panel.tscn`
5. Save the scene

**That's it!** The panel will automatically integrate.

### Step 2: Test the Integration

Run your game and:
1. Bootstrap a world (if not already done)
2. Open World Explorer
3. Click the "College Panel" tab
4. Verify that colleges/players appear
5. Test the filters and search

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      WorldExplorer                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 1. Loads world_state (from bootstrap or save file)   │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 2. Calls initialize(world_state) on each panel       │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     CollegePanel                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 3. Caches colleges and players from world_state      │   │
│  │    - all_colleges = ws["colleges"]                   │   │
│  │    - all_college_players = extract from rosters      │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 4. Renders initial view (Schools by default)         │   │
│  │    - Filters by current_tier_filter                  │   │
│  │    - Sorts alphabetically                            │   │
│  │    - Populates Tree widget                           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    User Interactions                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ View Mode    │  │ Filter       │  │ Search       │      │
│  │ Changed      │  │ Changed      │  │ Changed      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            ▼                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 5. _update_view() called                             │   │
│  │    - Applies all active filters                      │   │
│  │    - Re-renders Tree widget                          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    User Clicks Item                          │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────────┐    │
│  │ Player Clicked       │  │ School Clicked           │    │
│  └──────┬───────────────┘  └──────┬───────────────────┘    │
│         │                          │                        │
│         ▼                          ▼                        │
│  ┌──────────────────┐  ┌──────────────────────────────┐    │
│  │ player_selected  │  │ team_selected                │    │
│  │ signal emitted   │  │ signal emitted               │    │
│  └──────┬───────────┘  └──────┬───────────────────────┘    │
└─────────┼──────────────────────┼──────────────────────────┘
          │                      │
          └──────────┬───────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   WorldExplorer                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 6. Receives signal and shows detail                  │   │
│  │    - show_player_detail(player_id)                   │   │
│  │    - show_team_detail(team_id, "college")            │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 7. Formats detail view using formatters              │   │
│  │    - PlayerDetailFormatter.format()                  │   │
│  │    - TeamDetailFormatter.format()                    │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 8. Displays BBCode in DetailText panel               │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Signal Flow

### player_selected(player_id: String)

**Triggered**: User clicks a player in any view
**Handler**: `WorldExplorer.show_player_detail(player_id)`
**Result**: Player details shown in right panel

```gdscript
# In CollegePanel
func _on_content_list_item_selected():
    var metadata = selected_item.get_metadata(0)
    if metadata.type == "player":
        player_selected.emit(metadata.id)  # → WorldExplorer

# In WorldExplorer
func show_player_detail(player_id: String):
    var player = PlayerQueries.get_player_by_id(world_state, player_id)
    var bbcode = PlayerDetailFormatter.format(player, world_state)
    detail_text.text = bbcode
```

### team_selected(team_id: String, level: String)

**Triggered**: User clicks a school in Schools view
**Handler**: `WorldExplorer.show_team_detail(team_id, level)`
**Result**: College details shown in right panel

```gdscript
# In CollegePanel
func _on_content_list_item_selected():
    var metadata = selected_item.get_metadata(0)
    if metadata.type == "school":
        team_selected.emit(metadata.id, "college")  # → WorldExplorer

# In WorldExplorer
func show_team_detail(team_id: String, level: String):
    var team = TeamQueries.get_college(world_state, team_id)
    var bbcode = TeamDetailFormatter.format(team, world_state, level)
    detail_text.text = bbcode
```

## Filter Interaction Matrix

| View Mode          | Tier Filter | Position Filter | Class Filter | Search Filter |
|--------------------|-------------|-----------------|--------------|---------------|
| Schools            | ✓           | ✗               | ✗            | ✓ (schools)   |
| Players by Class   | ✓           | ✗               | ✗            | ✓ (players)   |
| All Players        | ✓           | ✓               | ✓            | ✓ (players)   |

**Filter Visibility Logic**:
```gdscript
match current_view_mode:
    ViewMode.SCHOOLS:
        # Show: tier_filter
        # Hide: position_filter, year_filter

    ViewMode.PLAYERS_BY_CLASS:
        # Show: tier_filter
        # Hide: position_filter, year_filter

    ViewMode.ALL_PLAYERS:
        # Show: tier_filter, position_filter, year_filter
```

## Common Integration Issues

### Issue 1: Panel doesn't appear in tabs

**Symptom**: Tab exists but is empty
**Solution**:
1. Check that scene path is correct in world_explorer.tscn
2. Verify script path in college_panel.tscn
3. Make sure `_ready()` is called (add debug print)

### Issue 2: "Class not found" errors

**Symptom**: PlayerQueries/TeamQueries/StatQueries not found
**Solution**:
1. Verify class_name declarations in query files
2. Check that project.godot includes scripts/ui/world_explorer/ in search paths
3. Reload Godot project (Project → Reload Current Project)

### Issue 3: Empty data despite valid world_state

**Symptom**: Panel shows no colleges/players
**Solution**:
1. Check world_state structure matches expected format
2. Add debug prints in `_cache_data()` to verify data extraction
3. Check console for warnings from TeamQueries/PlayerQueries

### Issue 4: Signals not firing

**Symptom**: Clicking items doesn't show details
**Solution**:
1. Verify `item_selected` signal is connected in scene file
2. Check that metadata is correctly set on Tree items
3. Test signal emission with debug prints

### Issue 5: Filters not working

**Symptom**: Changing filters doesn't update view
**Solution**:
1. Verify signal connections in `_connect_signals()`
2. Check that `_update_view()` is called after filter changes
3. Test individual filter functions with debug data

## Performance Monitoring

### Expected Performance

- **Initialization**: <100ms for 130 colleges + 6500 players
- **View switching**: <50ms
- **Filtering**: <30ms
- **Search**: <50ms for full text search

### Profiling Points

```gdscript
# In CollegePanel.gd, add timing code:

func _cache_data() -> void:
    var start_time = Time.get_ticks_msec()
    # ... existing code ...
    var elapsed = Time.get_ticks_msec() - start_time
    print("_cache_data() took %d ms" % elapsed)

func _update_view() -> void:
    var start_time = Time.get_ticks_msec()
    # ... existing code ...
    var elapsed = Time.get_ticks_msec() - start_time
    print("_update_view() took %d ms" % elapsed)
```

### Optimization Tips

1. **Large datasets (10,000+ players)**:
   - Consider pagination or virtualized scrolling
   - Lazy-load player details on demand
   - Cache filtered results

2. **Slow searches**:
   - Implement debouncing (delay search until typing stops)
   - Use background thread for search (if available)
   - Build search index on initialization

3. **Memory usage**:
   - Clear unused caches in `cleanup()`
   - Avoid storing duplicate data
   - Use weak references where possible

## Extending the Panel

### Adding a New View Mode

1. Add enum value:
```gdscript
enum ViewMode {
    SCHOOLS,
    PLAYERS_BY_CLASS,
    ALL_PLAYERS,
    MY_NEW_VIEW  # Add here
}
```

2. Add option button item in `_setup_filters()`:
```gdscript
view_mode_button.add_item("My New View", ViewMode.MY_NEW_VIEW)
```

3. Add render function:
```gdscript
func _render_my_new_view() -> void:
    content_list.columns = 3
    # ... configure columns ...
    # ... populate tree ...
```

4. Add case to `_update_view()`:
```gdscript
match current_view_mode:
    # ... existing cases ...
    ViewMode.MY_NEW_VIEW:
        _render_my_new_view()
```

### Adding a New Filter

1. Add enum:
```gdscript
enum MyFilterIndex {
    ALL = 0,
    OPTION1 = 1,
    OPTION2 = 2
}
```

2. Add UI elements to scene file

3. Initialize in `_setup_filters()`

4. Connect signal in `_connect_signals()`

5. Add filter logic to `_filter_colleges()` or `_filter_players()`

6. Update filter visibility in `_update_filter_visibility()`

## Testing Checklist

Before considering integration complete:

- [ ] Panel appears in WorldExplorer tabs
- [ ] All 130 colleges display in Schools view
- [ ] All ~6500 players display in player views
- [ ] Tier filter correctly filters schools
- [ ] Position filter works in All Players view
- [ ] Class filter works in All Players view
- [ ] Search filters by name (schools and players)
- [ ] Clicking schools shows college details
- [ ] Clicking players shows player details
- [ ] Draft-eligible players marked with ★
- [ ] View mode switching updates filter visibility
- [ ] Ratings are color-coded correctly
- [ ] No console errors during normal use
- [ ] Performance is acceptable (no lag)
- [ ] Panel survives refresh (refresh button)
- [ ] Panel cleans up properly when closed

## Support

For issues or questions:

1. Check console for error messages
2. Verify world_state structure
3. Review test_college_panel.gd for examples
4. Check COLLEGE_PANEL_README.md for detailed docs
5. Review WorldExplorer.gd panel integration comments
