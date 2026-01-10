# Task F7: Development Report Deferral

**Track**: Performance Optimization (Track F)
**Dependencies**: F6 (Config Optimization)
**Status**: Not started
**Estimated Effort**: 0.5 day
**Priority**: P4 - Memory Optimization

## Problem Statement

Each player accumulates a `development_report` array that grows unbounded throughout their career:

```gdscript
var report: Array = player.get("development_report", []) as Array
report.append({
    "age": int(player.get("age", 0)),
    "wear": wear_snapshot.duplicate(true),
    "decline_multiplier": float(dev_report.get("decline_multiplier", 1.0))
})
player["development_report"] = report
```

**Issues**:
1. Array grows by 1 entry per year per player
2. 15-year career = 15 entries per player
3. 10,000 players * 15 entries = 150,000 report objects
4. Not used during simulation (only for UI/debugging)
5. Included in serialization, bloating save files

## Current Usage Analysis

Searching the codebase for `development_report`:

1. **Written**: `PlayerLifecycle._append_development_report()` - every year
2. **Read**: Not read during simulation
3. **Purpose**: Debugging, UI history display, analytics

## Proposed Solutions

### Option 1: Lazy Generation (Recommended)

Store minimal data, generate full reports on demand:

```gdscript
# During simulation - store only essential deltas
player["development_history"] = {
    "career_start_age": 18,
    "seasons": [
        {"year": 2023, "phase": "growth", "decline_mult": 1.0},
        {"year": 2024, "phase": "prime", "decline_mult": 1.0}
        # Minimal entries
    ]
}

# On-demand generation for UI
func get_full_development_report(player: Dictionary) -> Array:
    var history: Dictionary = player.get("development_history", {})
    var seasons: Array = history.get("seasons", [])
    var reports: Array = []

    for season in seasons:
        reports.append({
            "age": calculate_age(player, season.year),
            "year": season.year,
            "phase": season.phase,
            "decline_multiplier": season.decline_mult
            # Reconstruct other fields as needed
        })

    return reports
```

### Option 2: Capped History

Keep only last N years of history:

```gdscript
const MAX_HISTORY := 5

func _append_development_report(...) -> void:
    var report: Array = player.get("development_report", []) as Array
    report.append({...})

    # Cap at MAX_HISTORY entries
    if report.size() > MAX_HISTORY:
        report = report.slice(report.size() - MAX_HISTORY)

    player["development_report"] = report
```

### Option 3: Separate Storage (Deferred Write)

Store reports separately from player dictionaries:

```gdscript
# World state has dedicated report storage
world_state["development_reports"] = {}  # player_id -> reports

# During simulation
func _append_development_report_deferred(
    player: Dictionary,
    report: Dictionary,
    reports_storage: Dictionary
) -> void:
    var player_id := String(player.get("player_id", ""))
    if not reports_storage.has(player_id):
        reports_storage[player_id] = []
    (reports_storage[player_id] as Array).append(report)
    # Player dictionary stays lean
```

### Option 4: Disable During Bootstrap

Skip report generation entirely during bootstrap:

```gdscript
static func advance_one_year(
    players: Array,
    ...,
    options: Dictionary = {}  # {"skip_reports": true}
) -> Dictionary:
    var skip_reports := bool(options.get("skip_reports", false))

    for i in range(players.size()):
        # ...
        if not skip_reports:
            _append_development_report(p, wear_snapshot, development_report)
```

## Recommended Approach

Combine Options 1 and 4:

1. **During bootstrap**: Skip report generation entirely (`skip_reports: true`)
2. **During normal play**: Store minimal history (Option 1)
3. **For UI/debugging**: Generate full reports on demand

## Implementation Plan

### Phase 1: Add Skip Option to PlayerLifecycle

**File**: `scripts/world/PlayerLifecycle.gd`

```gdscript
static func advance_one_year(
    players: Array,
    positions_cfg: Dictionary,
    main_cfg: Dictionary,
    stats_cfg: Dictionary,
    rng: RandomNumberGenerator,
    development_context: Dictionary = {},
    options: Dictionary = {}
) -> Dictionary:
    var skip_reports := bool(options.get("skip_reports", false))

    for i in range(players.size()):
        var evolved := _advance_player_one_year(
            p, positions_cfg, main_cfg, stats_cfg, rng,
            development_context, skip_reports
        )
        # ...

static func _advance_player_one_year(
    player: Dictionary,
    ...,
    skip_reports: bool = false
) -> Dictionary:
    # ...
    if not skip_reports:
        _append_development_report(p, wear_snapshot, development_report)
    # ...
```

### Phase 2: Update Bootstrap to Skip Reports

**File**: `scripts/pipelines/AdvanceWorldYear.gd`

```gdscript
var _bootstrap_mode: bool = false

func set_bootstrap_mode(enabled: bool) -> void:
    _bootstrap_mode = enabled

func _lifecycle_options() -> Dictionary:
    return {"skip_reports": _bootstrap_mode}

func _handle_hs_season(...) -> Dictionary:
    var progressed: Dictionary = PlayerLifecycle.advance_one_year(
        prepared_players,
        positions_cfg,
        main_cfg,
        stats_cfg,
        lifecycle_rng,
        {},
        _lifecycle_options()
    )
```

**File**: `scripts/pipelines/BootstrapGameWorld.gd`

```gdscript
func run(base_seed: int = 0) -> Dictionary:
    var advance := AdvanceWorldYear.new()
    advance.set_bootstrap_mode(true)  # Skip reports during bootstrap

    for year in range(first_year, start_year + 1):
        # ...
```

### Phase 3: Add On-Demand Report Generation

**File**: `scripts/world/PlayerReportGenerator.gd`

```gdscript
class_name PlayerReportGenerator
extends RefCounted

static func generate_development_report(
    player: Dictionary,
    world_state: Dictionary
) -> Array:
    # Reconstruct full report from minimal history
    var history: Dictionary = player.get("development_history", {})
    if history.is_empty():
        return []

    var reports: Array = []
    var seasons: Array = history.get("seasons", [])

    for season in seasons:
        var s: Dictionary = season
        reports.append({
            "year": int(s.get("year", 0)),
            "age": int(s.get("age", 0)),
            "phase": String(s.get("phase", "")),
            "decline_multiplier": float(s.get("decline_mult", 1.0)),
            "summary": _generate_summary(s)
        })

    return reports

static func _generate_summary(season: Dictionary) -> String:
    var phase := String(season.get("phase", ""))
    match phase:
        "growth":
            return "Developing skills"
        "prime":
            return "Peak performance"
        "decline":
            return "Managing age-related regression"
        _:
            return ""
```

## Memory Impact

Current memory per player:
```
development_report: ~15 entries * ~500 bytes = ~7.5 KB per player
10,000 players = ~75 MB just for reports
```

After optimization:
```
development_history: ~15 entries * ~50 bytes = ~750 bytes per player
10,000 players = ~7.5 MB for minimal history

During bootstrap (skip_reports):
0 bytes for reports
```

**Savings**: 90%+ reduction in report-related memory during bootstrap.

## Save File Impact

Reports are currently serialized with players. Reducing report size improves:
- Save file size
- Save/load time
- Autosave performance

## Test Coverage

**File**: `scripts/tests/test_report_deferral.gd`

```gdscript
func _test_skip_reports_option(t):
    var players := [_create_test_player()]
    var rng := _create_rng(42)

    var result := PlayerLifecycle.advance_one_year(
        players, positions_cfg, main_cfg, stats_cfg, rng,
        {}, {"skip_reports": true}
    )

    var p: Dictionary = result.players[0]
    t.assert_true(not p.has("development_report") or p["development_report"].is_empty())

func _test_bootstrap_mode(t):
    var bootstrap := BootstrapGameWorld.new()
    bootstrap.years_to_simulate = 5
    var result := bootstrap.run(42)

    # Players should have minimal/no reports
    var nfl_rosters: Dictionary = result.world_state.get("nfl_rosters", {})
    for team_id in nfl_rosters.keys():
        var roster: Dictionary = nfl_rosters[team_id]
        for player in roster.get("players", []):
            var report: Array = player.get("development_report", [])
            t.assert_true(report.is_empty(), "Bootstrap should skip reports")

func _test_on_demand_generation(t):
    var player := _create_player_with_history()
    var report := PlayerReportGenerator.generate_development_report(player, {})

    t.assert_true(report.size() > 0)
    t.assert_true(report[0].has("year"))
    t.assert_true(report[0].has("phase"))
```

## Acceptance Criteria

- [ ] `skip_reports` option added to PlayerLifecycle
- [ ] BootstrapGameWorld enables skip_reports mode
- [ ] PlayerReportGenerator can reconstruct reports on demand
- [ ] Memory usage during bootstrap reduced by 90%+
- [ ] All existing tests pass
- [ ] Save file size reduced for bootstrapped worlds

## Files to Modify

- `scripts/world/PlayerLifecycle.gd`
- `scripts/pipelines/AdvanceWorldYear.gd`
- `scripts/pipelines/BootstrapGameWorld.gd`

## Files to Create

- `scripts/world/PlayerReportGenerator.gd`
- `scripts/tests/test_report_deferral.gd`

## Next Task

After completing F7, proceed to **TASK_F8_benchmark_suite.md** for creating a comprehensive performance benchmark suite.
