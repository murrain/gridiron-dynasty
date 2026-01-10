# WorldBootstrap Duplicate Class Resolution

**Created**: 2026-01-10
**Status**: Proposed
**Priority**: High (blocks scene loading)

## Current Issue

When opening any scene in Godot, compilation fails with 4 errors:
1. **Line 2**: Class "WorldBootstrap" hides a global script class
2. **Line 9**: Preload file "res://scripts/rating/RecruitRater.gd" does not exist
3. **Line 96**: Too few arguments for "generate_class()" call. Expected at least 3 but received 2
4. **Line 97**: Cannot infer the type of "rater" variable

## Root Cause

Two files define `class_name WorldBootstrap`:
- `systems/WorldBootstrap.gd` (line 2)
- `scripts/world/WorldBootstrap.gd` (line 2)

Both files have identical compilation errors:
- Wrong RecruitRater path: `scripts/rating/RecruitRater.gd` → should be `scripts/core/rating/RecruitRater.gd`
- Missing RNG parameter: `gen.generate_class(count, gaussian_share)` → needs 3rd argument `rng`
- Type inference fails for `rater` variable due to failed RecruitRater preload

## Architecture Context

**Legacy implementations** (both broken):
- `systems/WorldBootstrap.gd` - Original bootstrap with global Config
- `scripts/world/WorldBootstrap.gd` - Refactored bootstrap, still uses global Config

**Current canonical implementation** (Track D):
- `scripts/pipelines/BootstrapGameWorld.gd` - Multi-year orchestrator
- `scripts/pipelines/AdvanceWorldYear.gd` - Single year advancement
- Uses `ConfigService` instances (proper architecture)
- Deterministic seed derivation with explicit RNG threading

**Current usage of legacy WorldBootstrap**:
- Only `scenes/BootstrapPreview.gd` references it (line 4)
- Explicitly preloads `scripts/world/WorldBootstrap.gd`
- Scene files: `bootstrap_preview.tscn`, `world_bootstrap.tscn`

## Recommended Resolution

### Option 1: Minimal Fix (Quick Unblock)

**Goal**: Fix compilation errors to allow scene loading

**Actions**:
1. Remove `class_name WorldBootstrap` from `systems/WorldBootstrap.gd` (make it anonymous)
2. Keep `class_name WorldBootstrap` in `scripts/world/WorldBootstrap.gd` only
3. Fix RecruitRater path in both files: `scripts/core/rating/RecruitRater.gd`
4. Fix generate_class calls to include RNG parameter

**Pros**:
- Quick fix (~5 minutes)
- Unblocks scene loading immediately
- Preserves existing BootstrapPreview functionality

**Cons**:
- Doesn't address architectural debt
- Leaves deprecated code in place
- May confuse future developers

### Option 2: Architectural Migration (Recommended)

**Goal**: Migrate to new BootstrapGameWorld architecture, deprecate legacy files

**Actions**:

#### Phase 1: Migrate BootstrapPreview.gd
```gdscript
# Before (scenes/BootstrapPreview.gd)
const WorldBootstrap = preload("res://scripts/world/WorldBootstrap.gd")
var wb := WorldBootstrap.new()
wb.bootstrap_once()

# After
const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
var bootstrap := BootstrapGameWorld.new()
bootstrap.years_to_simulate = 3
var result := bootstrap.run(12345)
var world_state := result.get("world_state", {})
```

#### Phase 2: Remove deprecated files
- Delete `systems/WorldBootstrap.gd`
- Delete `scripts/world/WorldBootstrap.gd`
- Update `scenes/BootstrapPreview.gd` to use BootstrapGameWorld
- Verify bootstrap_preview.tscn and world_bootstrap.tscn still work

#### Phase 3: Update documentation
- Mark WORLD_BOOTSTRAP.md as deprecated
- Point to BootstrapGameWorld in Track D documentation

**Pros**:
- Removes architectural debt completely
- Consolidates to single canonical implementation
- Uses proper ConfigService pattern
- Aligns with Track D work

**Cons**:
- Requires testing BootstrapPreview migration
- More work (~30 minutes)
- May need to adjust world_state access patterns

### Option 3: Deprecate Without Migration

**Goal**: Remove both legacy files, deprecate BootstrapPreview

**Actions**:
1. Delete `systems/WorldBootstrap.gd`
2. Delete `scripts/world/WorldBootstrap.gd`
3. Add deprecation comment to `scenes/BootstrapPreview.gd`
4. Document that `bootstrap_preview.tscn` is no longer functional
5. Point users to `scripts/tests/test_bootstrap_game_world.gd` for bootstrap testing

**Pros**:
- Cleanest architectural solution
- Removes all deprecated code
- Forces migration to new architecture

**Cons**:
- Breaks existing bootstrap_preview scenes
- Requires scene rewrite if preview functionality is needed

## Implementation Plan

**Recommended**: Option 2 (Architectural Migration)

### Step 1: Migrate BootstrapPreview.gd to use BootstrapGameWorld

**File**: `scenes/BootstrapPreview.gd`

**Changes**:
- Replace WorldBootstrap preload with BootstrapGameWorld
- Update initialization to use `run()` method with seed
- Extract `world_state` from result dictionary
- Access leagues/teams through world_state structure instead of `wb.leagues`

**Critical**: Understand world_state structure from AdvanceWorldYear:
- `world_state["hs_schools"]` - High school teams
- `world_state["colleges"]` - College teams
- `world_state["nfl_teams"]` - NFL teams
- `world_state["nfl_rosters"]` - Roster dictionaries by team_id

### Step 2: Test migration

Run bootstrap_preview scene and verify output matches expectations

### Step 3: Remove deprecated files

```bash
git rm systems/WorldBootstrap.gd
git rm scripts/world/WorldBootstrap.gd
```

### Step 4: Commit and document

Commit message:
```
refactor: migrate BootstrapPreview to BootstrapGameWorld, remove duplicate WorldBootstrap classes

- Remove duplicate class_name definitions (systems/ and scripts/world/)
- Migrate scenes/BootstrapPreview.gd to use new Track D BootstrapGameWorld
- Use world_state structure instead of direct league access
- Fixes compilation errors: RecruitRater path, generate_class signature
```

## Alternative: If BootstrapPreview is no longer needed

If bootstrap_preview scenes are obsolete and not used:

**Fastest solution**:
1. Delete both WorldBootstrap files
2. Delete bootstrap_preview.tscn and world_bootstrap.tscn
3. Delete scenes/BootstrapPreview.gd
4. Document that `test_bootstrap_game_world.gd` is the canonical bootstrap test

This removes ~444 lines of deprecated code and eliminates all errors immediately.

## Verification Checklist

After implementing resolution:
- [ ] `generate_once.tscn` loads without errors
- [ ] `bootstrap_preview.tscn` loads (or is removed)
- [ ] Test suite still passes (43 tests)
- [ ] No class name collision errors
- [ ] BootstrapGameWorld tests still pass
- [ ] Documentation updated to reference correct files

## References

- Track D implementation: `scripts/pipelines/BootstrapGameWorld.gd`
- Track D tests: `scripts/tests/test_bootstrap_game_world.gd`
- Duplicate class documentation: `docs/architectural_notes/duplicate_class_names.md`
- Original issue reported: 2026-01-10 (generate_once scene load errors)
