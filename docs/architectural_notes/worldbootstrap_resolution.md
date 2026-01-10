# WorldBootstrap Duplicate Class Resolution ✅ RESOLVED

**Created**: 2026-01-10
**Status**: ✅ Resolved (January 2026, PR #65)
**Resolution**: Removed both legacy files, migrated to BootstrapGameWorld

---

## Original Issue

When opening scenes in Godot, compilation failed with 4 errors:
1. Class "WorldBootstrap" hides a global script class
2. Preload file "res://scripts/rating/RecruitRater.gd" does not exist
3. Too few arguments for "generate_class()" call
4. Cannot infer type of "rater" variable

### Root Cause

Two files defined `class_name WorldBootstrap`:
- `systems/WorldBootstrap.gd` (line 2) - Original implementation
- `scripts/world/WorldBootstrap.gd` (line 2) - Refactored version

Both had identical errors:
- Wrong RecruitRater path
- Missing RNG parameter in generate_class()
- Failed type inference from broken preload

---

## Resolution Implemented

### Option 2 (Chosen): Architectural Migration

**Actions Taken**:

#### Phase 1: Migrate BootstrapPreview
✅ Updated `scenes/BootstrapPreview.gd`:
```gdscript
# Before (broken)
const WorldBootstrap = preload("res://scripts/world/WorldBootstrap.gd")
var wb := WorldBootstrap.new()
wb.bootstrap_once()

# After (working)
const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
var bootstrap := BootstrapGameWorld.new()
bootstrap.years_to_simulate = 3
var result := bootstrap.run(12345)
var world_state := result.get("world_state", {})
```

#### Phase 2: Remove Deprecated Files
✅ Deleted:
- `systems/WorldBootstrap.gd`
- `scripts/world/WorldBootstrap.gd`
- `systems/` directory (entire legacy architecture)

#### Phase 3: Verify Scenes Work
✅ Tested:
- `bootstrap_preview.tscn` loads and runs successfully
- `generate_once.tscn` loads without compilation errors
- All 43 tests still pass

---

## Benefits of Resolution

**Before**:
- Compilation errors blocked scene loading
- Duplicate class definitions caused confusion
- Legacy code used global Config autoload

**After**:
- ✅ All scenes load without errors
- ✅ Single canonical bootstrap implementation
- ✅ Proper ConfigService architecture
- ✅ Deterministic seed derivation
- ✅ Clean architecture (pipelines/ for orchestration)

---

## New Architecture

### Canonical Bootstrap System

**`scripts/pipelines/BootstrapGameWorld.gd`**:
- Multi-year world simulator
- Configurable years_to_simulate (default: 20)
- Returns complete world_state with summary
- Uses ConfigService instances (not global Config)
- Integrates with AdvanceWorldYear pipeline

**Usage**:
```gdscript
var bootstrap := BootstrapGameWorld.new()
bootstrap.years_to_simulate = 20
var result := bootstrap.run(base_seed)

var world_state := result.world_state
var summary := result.summary
# summary: {hs_schools, hs_players, colleges, college_players, nfl_teams, nfl_players, retired_players}
```

### World State Structure

After bootstrap, world_state contains:
- `hs_schools` - High school teams
- `hs_players` - Current HS player pool
- `colleges` - College teams
- `college_rosters` - Rosters by college_id
- `nfl_teams` - NFL teams
- `nfl_rosters` - Rosters by team_id
- `retired_players` - Historical retired players
- `draft_pool` - Future draft classes by year

---

## Comparison: Old vs New

| Aspect | Legacy WorldBootstrap | New BootstrapGameWorld |
|--------|----------------------|------------------------|
| Config | Global Config autoload | ConfigService instances |
| Seeding | Unclear seed derivation | Explicit _resolve_year_seed() |
| Pipeline | Monolithic bootstrap_once() | Delegates to AdvanceWorldYear |
| Testing | Not tested | test_bootstrap_game_world.gd |
| Architecture | Mixed concerns | Clean separation (pipeline layer) |
| State | Unclear world_state structure | Documented dict structure |

---

## Lessons Learned

### What Caused the Issue

1. **Incremental refactoring** - New implementation created without removing old
2. **Incomplete migration** - BootstrapPreview still referenced old file
3. **No deprecation markers** - Legacy files not clearly marked obsolete
4. **Missing path updates** - RecruitRater moved but references not updated

### Prevention Strategies

1. **Complete migrations** - Update all references before removing files
2. **Test after cleanup** - Verify scenes load and tests pass
3. **Deprecation workflow** - Mark files as deprecated before deleting
4. **Path audits** - Search codebase for all references before moves

---

## References

- **Resolution PR**: #65 (WorldBootstrap resolution)
- **New implementation**: `scripts/pipelines/BootstrapGameWorld.gd`
- **Tests**: `scripts/tests/test_bootstrap_game_world.gd`
- **Track D documentation**: See `docs/COMPLETED.md` (Track D section)
- **Related cleanup**: See `duplicate_class_names.md`
