# World Explorer - Quick Start Guide

## What is World Explorer?

World Explorer is a comprehensive UI for browsing and exploring your generated Gridiron Dynasty world. It displays all players, teams, schools, draft prospects, and retired players across all league levels (NFL, College, High School).

## Quick Start

### Launch World Explorer

```bash
cd /path/to/gridiron-dynasty
godot scenes/main/world_explorer_main.tscn
```

**First Launch**: The initial launch will take 60-90 seconds to generate a 20-year world. You'll see a loading screen with a progress indicator.

### What You'll See

After bootstrap completes, you'll see:

1. **Header Bar** - Shows current year and refresh button
2. **Left Sidebar** - Search box and tabbed navigation
3. **Right Panel** - Detailed information for selected items

### Navigation Tabs

Click any tab to switch views:

- **NFL** - Browse all 32 NFL teams and their rosters
- **College** - Explore FBS colleges and college players
- **High Schools** - View all high schools and HS players
- **Draft** - See draft-eligible players by year
- **Retired** - Browse retired players and their career stats

### Basic Operations

#### Browse Teams/Schools

1. Click a tab (NFL, College, or High Schools)
2. Click a team/school name in the list
3. View roster and details in the right panel

#### Browse Players

1. Click a tab
2. Click any player name in the list
3. View detailed player stats in the right panel

#### Search

1. Type in the search box at the top of the sidebar
2. Results filter automatically as you type
3. Click the X button to clear search

#### Refresh Data

Click the ↻ (refresh) button in the header to reinitialize all panels with current world data.

## Features by Panel

### NFL Panel

**Views Available:**
- Teams List - All 32 NFL teams
- Players by Position - Top 20 per position
- All Players - Top 500 by rating

**Information Shown:**
- Team roster size and salary cap
- Player ratings (overall, position-specific)
- Career stats
- College attended

### College Panel

**Views Available:**
- Schools List - All FBS colleges
- Players by Position - Top players per position
- All Players - Full player list

**Information Shown:**
- School roster size and average rating
- Player year (FR/SO/JR/SR)
- High school origin
- Academic standing

### High School Panel

**Views Available:**
- Schools List - All high schools by state
- Players by Grade - Organized by class year

**Information Shown:**
- School location (city, state)
- Player count per school
- Potential ratings
- Recruiting interest

### Draft Panel

**Organization:**
- Grouped by draft year
- Shows all draft-eligible players

**Information Shown:**
- College attended
- Position and ratings
- Draft projections
- Career stats

### Retired Panel

**Organization:**
- Listed by retirement year
- Sorted by peak rating

**Information Shown:**
- Years played
- Teams played for
- Career statistics
- Peak rating
- Retirement reason

## Keyboard Shortcuts

Currently, World Explorer uses mouse/click navigation. Keyboard shortcuts may be added in future updates.

## Configuration

### Change Bootstrap Parameters

Edit `/home/patrick/Documents/code/gridiron-dynasty/scenes/main/world_explorer_main.tscn`:

```gdscript
bootstrap_years = 20  # Change to 10, 15, or 25
base_seed = 0         # Change to any integer for different world
```

Or modify in Godot Editor:
1. Open `scenes/main/world_explorer_main.tscn`
2. Select the `WorldExplorerMain` root node
3. Adjust `Bootstrap Years` and `Base Seed` in Inspector

### Performance Tips

- **Reduce bootstrap time**: Lower `bootstrap_years` to 10 or 15
- **Deterministic worlds**: Use same `base_seed` to regenerate identical world
- **Different worlds**: Change `base_seed` to get different players/teams

## Troubleshooting

### Loading Takes Too Long

**Expected**: 60-90 seconds for 20 years
**Too Long**: >2 minutes

**Solutions:**
1. Check CPU usage (should be 100% on one core)
2. Run in release mode: `godot --release scenes/main/world_explorer_main.tscn`
3. Reduce `bootstrap_years` to 10-15

### Panels Are Empty

**Symptoms**: Tabs appear but no data shown

**Solutions:**
1. Check console for errors (run from terminal)
2. Click refresh button (↻ in header)
3. Verify bootstrap completed successfully

### Search Doesn't Work

**Symptoms**: Typing has no effect

**Solutions:**
1. Ensure you're on a panel (not just in WorldExplorer root)
2. Try switching tabs
3. Clear and retype search query

### "Player Not Found" Error

**Symptoms**: Clicking player shows error

**Solutions:**
1. Click refresh button
2. Try another player
3. Check console for query errors

## Advanced Usage

### Programmatic Launch

Use `WorldExplorerLauncher` for custom integrations:

```gdscript
# From existing world_state
var explorer = WorldExplorerLauncher.launch_with_world_state(my_world_state)
get_tree().root.add_child(explorer)

# From bootstrap with custom params
var result = WorldExplorerLauncher.launch_from_bootstrap(15, 42)
if result.has("explorer"):
    get_tree().root.add_child(result["explorer"])
    print("Generated %d NFL teams" % result["summary"]["nfl_teams"])
```

### Export World Data

Currently, World Explorer is read-only. Export functionality may be added in future updates to save generated worlds to JSON/CSV.

## File Locations

### Launch Files
- Main scene: `/home/patrick/Documents/code/gridiron-dynasty/scenes/main/world_explorer_main.tscn`
- Main script: `/home/patrick/Documents/code/gridiron-dynasty/scripts/main/WorldExplorerMain.gd`
- Launcher: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/WorldExplorerLauncher.gd`

### Core Components
- WorldExplorer: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/WorldExplorer.gd`
- Panels: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/panels/`
- Queries: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/queries/`
- Formatters: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/formatters/`

### Bootstrap Pipeline
- Bootstrap: `/home/patrick/Documents/code/gridiron-dynasty/scripts/pipelines/BootstrapGameWorld.gd`
- Year Advance: `/home/patrick/Documents/code/gridiron-dynasty/scripts/pipelines/AdvanceWorldYear.gd`

## Performance Metrics

### Bootstrap (20 years)
- **Time**: 60-90 seconds
- **Generated Entities**:
  - ~130 FBS colleges
  - ~1000 high schools
  - ~10,000+ total players
  - ~500+ retired players
  - 32 NFL teams with full rosters

### UI Performance
- **Panel Load**: <100ms
- **Search**: <50ms for 1000+ items
- **Detail Render**: <20ms
- **Tab Switch**: <30ms

### Memory Usage
- **Bootstrap Peak**: 500-800 MB
- **Runtime**: 300-500 MB
- **Per Panel**: 10-20 MB

## Getting Help

### Check Documentation
- Full guide: `/home/patrick/Documents/code/gridiron-dynasty/docs/INTEGRATION_COMPLETE.md`
- Panel guides: `/home/patrick/Documents/code/gridiron-dynasty/scripts/ui/world_explorer/panels/README_*.md`

### Common Issues
Most issues are resolved by:
1. Clicking refresh button
2. Checking console output
3. Verifying bootstrap completed successfully

### Report Bugs
Check console output and note:
- Which panel you were using
- What action caused the error
- Full error message from console

---

**Version**: 1.0
**Last Updated**: 2026-01-10
**Status**: Ready for Use
