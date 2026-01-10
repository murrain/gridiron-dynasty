# Task F6: Configuration Access Optimization

**Track**: Performance Optimization (Track F)
**Dependencies**: F5 (Parallel Lifecycle)
**Status**: Not started
**Estimated Effort**: 0.5-1 day
**Priority**: P5 - Low Impact (Polish)

## Problem Statement

Configuration dictionaries are accessed repeatedly throughout the simulation pipeline. While the Config autoload caches loaded files, there are still inefficiencies:

1. Repeated dictionary key lookups in hot paths
2. Default value computation on every access
3. Type conversions (float/int casts) repeated

## Current Pattern

```gdscript
func _apply_development(...) -> Dictionary:
    var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary
    var peak_age := int(dev_cfg.get("peak_age", 26))      # Repeated access
    var decline_start := int(dev_cfg.get("decline_start", 30))

    var dev_global: Dictionary = main_cfg.get("development", {}) as Dictionary
    var curve_mults: Dictionary = dev_global.get("curve_multipliers", {}) as Dictionary
    var curve_cfg: Dictionary = curve_mults.get(curve, {}) as Dictionary
    var growth_mult := float(curve_cfg.get("growth", 1.0))  # Deep nesting
```

This pattern repeats for every player advancement.

## Proposed Solution

### Strategy 1: Early Binding / Pre-extraction

Extract commonly used values once at phase start:

```gdscript
class DevelopmentConfig:
    var peak_ages: Dictionary = {}  # position -> peak_age
    var decline_starts: Dictionary = {}  # position -> decline_start
    var curve_multipliers: Dictionary = {}  # curve_name -> {growth, prime, decline}
    var base_progress_min: float
    var base_progress_max: float
    var progress_cap: float

    func _init(positions_cfg: Dictionary, main_cfg: Dictionary) -> void:
        # Extract all needed values once
        for pos in positions_cfg.keys():
            var pos_cfg: Dictionary = positions_cfg[pos]
            var dev: Dictionary = pos_cfg.get("development", {})
            peak_ages[pos] = int(dev.get("peak_age", 26))
            decline_starts[pos] = int(dev.get("decline_start", 30))

        var dev_global: Dictionary = main_cfg.get("development", {})
        curve_multipliers = dev_global.get("curve_multipliers", {})
        base_progress_min = float(main_cfg.get("annual_base_progress_min", 1.0))
        base_progress_max = float(main_cfg.get("annual_base_progress_max", 4.0))
        progress_cap = float(main_cfg.get("annual_progress_cap", 6.0))

    func get_peak_age(position: String) -> int:
        return peak_ages.get(position, 26)

    func get_decline_start(position: String) -> int:
        return decline_starts.get(position, 30)

    func get_curve(name: String) -> Dictionary:
        return curve_multipliers.get(name, {"growth": 1.0, "prime": 0.35, "decline": 1.0})
```

### Strategy 2: Config Snapshot Classes

Create typed config classes that parse once:

```gdscript
class RecruitingConfig:
    var offer_limit: int
    var board_limit: int
    var class_size_min: int
    var class_size_max: int
    var rating_weight: float
    var eliteness_weight: float
    var proximity_weight: float

    static func from_dict(cfg: Dictionary) -> RecruitingConfig:
        var c := RecruitingConfig.new()
        var rec: Dictionary = cfg.get("recruiting", {})
        c.offer_limit = int(rec.get("offer_limit", 30))
        c.board_limit = int(rec.get("board_limit", 120))
        c.class_size_min = int(rec.get("class_size_min", 15))
        c.class_size_max = int(rec.get("class_size_max", 25))
        c.rating_weight = float(rec.get("rating_weight", 0.55))
        c.eliteness_weight = float(rec.get("eliteness_weight", 0.25))
        c.proximity_weight = float(rec.get("proximity_weight", 0.20))
        return c
```

### Strategy 3: Position-Indexed Arrays

For position-specific lookups, use arrays instead of dictionaries:

```gdscript
# Map positions to indices
const POS_QB = 0
const POS_RB = 1
const POS_WR = 2
# ...

# Pre-build position config arrays
var peak_ages: Array = []  # [26, 27, 28, ...]  indexed by position
var decline_starts: Array = []

# Lookup: O(1) array access vs O(log n) dict lookup
var peak := peak_ages[position_index]
```

## Implementation Plan

### Phase 1: Create Config Helper Classes

**File**: `scripts/support/config/DevelopmentConfig.gd`

```gdscript
class_name DevelopmentConfig
extends RefCounted

var _peak_ages: Dictionary
var _decline_starts: Dictionary
var _curves: Dictionary
var _base_min: float
var _base_max: float
var _cap: float
var _prime_min: float
var _prime_max: float
var _decline_min: float
var _decline_max: float

func _init(positions_cfg: Dictionary, main_cfg: Dictionary) -> void:
    _extract_position_config(positions_cfg)
    _extract_global_config(main_cfg)

func _extract_position_config(positions_cfg: Dictionary) -> void:
    _peak_ages = {}
    _decline_starts = {}
    _curves = {}
    for pos in positions_cfg.keys():
        var cfg: Dictionary = positions_cfg[pos]
        var dev: Dictionary = cfg.get("development", {})
        _peak_ages[pos] = int(dev.get("peak_age", 26))
        _decline_starts[pos] = int(dev.get("decline_start", 30))
        _curves[pos] = String(dev.get("curve", "mid"))

func _extract_global_config(main_cfg: Dictionary) -> void:
    _base_min = float(main_cfg.get("annual_base_progress_min", 1.0))
    _base_max = float(main_cfg.get("annual_base_progress_max", 4.0))
    _cap = float(main_cfg.get("annual_progress_cap", 6.0))
    var dev: Dictionary = main_cfg.get("development", {})
    _prime_min = float(dev.get("prime_growth_min", 0.2))
    _prime_max = float(dev.get("prime_growth_max", 0.8))
    _decline_min = float(dev.get("decline_min", 0.4))
    _decline_max = float(dev.get("decline_max", 1.6))

func peak_age(position: String) -> int:
    return _peak_ages.get(position, 26)

func decline_start(position: String) -> int:
    return _decline_starts.get(position, 30)

func curve_name(position: String) -> String:
    return _curves.get(position, "mid")

func base_progress_range() -> Vector2:
    return Vector2(_base_min, _base_max)

func prime_range() -> Vector2:
    return Vector2(_prime_min, _prime_max)

func decline_range() -> Vector2:
    return Vector2(_decline_min, _decline_max)

func progress_cap() -> float:
    return _cap
```

### Phase 2: Update PlayerLifecycle

**File**: `scripts/world/PlayerLifecycle.gd`

```gdscript
static func advance_one_year_with_config(
    players: Array,
    dev_config: DevelopmentConfig,
    stats_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Use pre-extracted config values
    for i in range(players.size()):
        var p: Dictionary = players[i]
        var position := String(p.get("position", ""))
        var age := int(p.get("age", 18))

        var peak := dev_config.peak_age(position)
        var decline := dev_config.decline_start(position)
        var base_range := dev_config.base_progress_range()

        # ... use pre-extracted values
```

### Phase 3: Update Phase Handlers

**File**: `scripts/pipelines/AdvanceWorldYear.gd`

```gdscript
func _handle_hs_season(...) -> Dictionary:
    # Create config once per phase
    var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)

    # Pass to lifecycle
    var progressed := PlayerLifecycle.advance_one_year_with_config(
        prepared_players,
        dev_config,
        stats_cfg,
        lifecycle_rng
    )
```

## Benchmark Approach

```gdscript
func _benchmark_config_access():
    var main_cfg := Config.get_config("main")
    var positions_cfg := Config.get_config("positions")

    # Method 1: Repeated access
    var start := Time.get_ticks_usec()
    for i in range(10000):
        var dev: Dictionary = main_cfg.get("development", {})
        var _ := float(dev.get("prime_growth_min", 0.2))
    var method1 := Time.get_ticks_usec() - start

    # Method 2: Pre-extracted
    var dev: Dictionary = main_cfg.get("development", {})
    var prime_min := float(dev.get("prime_growth_min", 0.2))
    start = Time.get_ticks_usec()
    for i in range(10000):
        var _ := prime_min
    var method2 := Time.get_ticks_usec() - start

    print("Repeated access: %d us, Pre-extracted: %d us" % [method1, method2])
```

## Expected Impact

This is a polish optimization with modest but measurable impact:

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| Config access per player | ~5us | ~0.5us | 10x |
| 10k players * 11 phases | ~550ms | ~55ms | 10x |

Total expected improvement: ~0.5s per simulated year (5% of total time)

## Acceptance Criteria

- [ ] DevelopmentConfig class implemented
- [ ] PlayerLifecycle uses pre-extracted config
- [ ] No change in simulation output (determinism)
- [ ] Benchmark shows measurable improvement
- [ ] All tests pass

## Files to Create

- `scripts/support/config/DevelopmentConfig.gd`
- `scripts/support/config/RecruitingConfig.gd`
- `scripts/support/config/RetirementConfig.gd`

## Files to Modify

- `scripts/world/PlayerLifecycle.gd`
- `scripts/pipelines/AdvanceWorldYear.gd`
- `scripts/world/HighSchoolSeason.gd`
- `scripts/world/CollegeSeason.gd`
- `scripts/world/NflSeason.gd`

## Next Task

After completing F6, proceed to **TASK_F7_development_report_deferral.md** for memory optimization.
