# GdUnit4 Migration - Compilation Error Fixes

**Date:** 2026-01-14
**Branch:** test-infra/gdunit4-migration
**Test Infrastructure Engineer:** Claude Sonnet 4.5

## Summary

Fixed critical compilation errors in the GdUnit4 test migration. Out of 125 migrated test files, **18 files** had compilation errors that prevented tests from running.

## Files Fixed

| File | Error Type | Fix Applied |
|------|------------|-------------|
| test_free_agency_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_contract_negotiation_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_high_school_generator_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_scout_factory_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_trade_system_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_tier_recruiting_gdunit4.gd | Unused import | Removed unused ConfigService import |
| test_error_handling_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_report_deferral_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_draft_history_debug_gdunit4.gd | Wrong preload path, load_all_configs, type inference | Changed path, removed load_all_configs(), added explicit types |
| test_edge_cases_comprehensive_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_d5_1_draft_history_all_picks_recorded_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_d5_1_draft_history_correct_pick_order_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_d5_5_draft_trades_schema_ready_gdunit4.gd | Wrong preload path, load_all_configs | Changed path to res://autoloads/Config.gd, removed load_all_configs() |
| test_recruiting_optimization_gdunit4.gd | Wrong preload path, load_all_configs, type inference | Changed path, removed load_all_configs(), added explicit types |
| test_roster_management_unit_gdunit4.gd | Wrong function signature | Added missing market_value_multiplier parameter (5th arg) |
| test_snapshot_loader_gdunit4.gd | var _ syntax, is_sorted() method, type inference | Renamed var _ to var _unused, implemented manual sort check, added explicit String type |
| test_quality_function_only_gdunit4.gd | Type inference errors | Added explicit bool types to comparison variables |
| test_roster_management_data_flow_gdunit4.gd | Type inference from Dictionary.get() | Added explicit float types and float() cast |

## Error Categories

### 1. Wrong ConfigService Path (14 files)

**Error:**
```
Parse Error: Preload file "res://scripts/autoload/ConfigService.gd" does not exist.
```

**Root Cause:** Migration used incorrect path `res://scripts/autoload/ConfigService.gd` instead of the correct path `res://autoloads/Config.gd`.

**Fix:** Updated all preload statements:
```gdscript
# Before (incorrect)
const ConfigService = preload("res://scripts/autoload/ConfigService.gd")

# After (correct)
const ConfigService = preload("res://autoloads/Config.gd")
```

### 2. Non-existent load_all_configs() Method (14 files)

**Error:**
```
Parse Error: Cannot infer the type of "config" variable because the value doesn't have a set type.
```

**Root Cause:** The old API had `load_all_configs()` method that no longer exists in Config.gd.

**Fix:** Removed calls to `load_all_configs()` - the new Config class loads configs on-demand:
```gdscript
# Before (incorrect)
var config := ConfigService.new()
config.load_all_configs()
_positions_cfg = config.get_config("positions")

# After (correct)
var config_service := ConfigService.new()
_positions_cfg = config_service.get_config("positions")
```

### 3. Wrong Function Signature (1 file)

**Error:**
```
Parse Error: Too few arguments for "_identify_release_candidates()" call. Expected at least 5 but received 4.
```

**Root Cause:** `RosterManagement._identify_release_candidates()` requires 5 parameters but test passed only 4.

**Fix:** Added missing `market_value_multiplier` parameter:
```gdscript
# Before (4 args - incorrect)
RosterManagement._identify_release_candidates(players, 1.5, 0.02, 2025)

# After (5 args - correct)
RosterManagement._identify_release_candidates(players, 0.15, 1.5, 0.02, 2025)
```

### 4. Type Inference Errors (4 files)

**Error:**
```
Parse Error: Cannot infer the type of "X" variable because the value doesn't have a set type.
Parse Error: The variable type is being inferred from a Variant value, so it will be typed as Variant.
```

**Root Cause:** GDScript strict type checking treats `Dictionary.get()` return as Variant, which cannot be inferred with `:=`.

**Fix:** Added explicit type annotations:
```gdscript
# Before (type inference fails)
var skill_same := abs(float(scout_a.get("base_skill", 0.0)) - ...) < 0.0001
var base := {...}.get(position, 3.0)

# After (explicit types)
var skill_same: bool = abs(float(scout_a.get("base_skill", 0.0)) - ...) < 0.0001
var base: float = float({...}.get(position, 3.0))
```

### 5. Missing Array Method (1 file)

**Error:**
```
Parse Error: Cannot find member "is_sorted" in base "Array".
```

**Root Cause:** `Array.is_sorted()` does not exist in Godot 4.5.

**Fix:** Implemented manual sort check:
```gdscript
# Before (method doesn't exist)
assert_bool(years.is_sorted()).is_true()

# After (manual implementation)
var is_sorted: bool = true
for i in range(1, years.size()):
    if years[i] < years[i - 1]:
        is_sorted = false
        break
assert_bool(is_sorted).is_true()
```

### 6. Reserved Variable Name (1 file)

**Error:**
```
Parse Error: Expected variable name after "var".
```

**Root Cause:** Using `var _` with type inference was problematic.

**Fix:** Renamed to descriptive unused variable name:
```gdscript
# Before
var _ := SnapshotLoader.setup_world(...)

# After
var _unused := SnapshotLoader.setup_world(...)
```

## Verification Results

### Compilation Check
- **Total files:** 125
- **Files with errors before fix:** 18
- **Files with errors after fix:** 0
- **All 125 files compile successfully**

### POC Tests
All 5 POC test suites pass (32/32 tests):

| Test Suite | Tests | Status |
|------------|-------|--------|
| test_rand_gdunit4.gd | 6 | PASSED |
| test_game_simulation_determinism_gdunit4.gd | 4 | PASSED |
| test_scout_runtime_gdunit4.gd | 7 | PASSED |
| test_api_contracts_gdunit4.gd | 7 | PASSED |
| test_season_simulation_integration_gdunit4.gd | 8 | PASSED |
| **Total** | **32** | **PASSED** |

## Lessons Learned

1. **Consistent paths:** Always verify preload paths match actual file locations
2. **API changes:** Check for removed methods when migrating from old patterns
3. **Function signatures:** Verify all parameters when calling internal/private functions
4. **Type annotations:** Use explicit types with `Dictionary.get()` and similar Variant-returning methods
5. **Godot version compatibility:** Verify Array methods exist in target Godot version

## Next Steps

1. Run full test suite to identify any remaining test logic failures
2. Fix any flaky tests discovered during bulk runs
3. Set up CI pipeline with per-test retry mechanism
4. Configure test parallelization for performance optimization
