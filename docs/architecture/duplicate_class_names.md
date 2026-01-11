# Duplicate Class Name Issue ✅ RESOLVED

**Discovered**: 2026-01-10 during type inference fixes
**Status**: ✅ Resolved (January 2026, PR #65)
**Resolution**: Removed duplicate files and migrated to canonical implementations

---

## Original Issue

GDScript class name collision existed for core entity types:

### Team Classes (RESOLVED ✅)
- `scripts/core/models/Team.gd` - **Canonical** (Phase 4 cap accounting model)
- `scripts/models/Team.gd` - **REMOVED** (legacy duplicate)

### Coach Classes (RESOLVED ✅)
- `scripts/core/models/Coach.gd` - **Canonical** (minimal serialization model)
- `scripts/models/Coach.gd` - **REMOVED** (legacy duplicate)

### WorldBootstrap Classes (RESOLVED ✅)
- `systems/WorldBootstrap.gd` - **REMOVED** (legacy)
- `scripts/world/WorldBootstrap.gd` - **REMOVED** (refactored legacy)
- `scripts/pipelines/BootstrapGameWorld.gd` - **Canonical** (Track D implementation)

---

## Resolution Taken

### Files Removed
✅ **Legacy duplicates** (January 2026):
- `scripts/models/Team.gd`
- `scripts/models/Coach.gd`
- `scripts/models/Resume.gd`
- `scripts/models/TeamRuntime.gd`
- `scripts/world/LeagueManager.gd`
- `scripts/world/SeasonSimulator.gd`
- `scripts/world/ResumeBook.gd`
- `scripts/world/DraftManager.gd`
- `scripts/world/League.gd`
- `systems/WorldBootstrap.gd`
- `scripts/world/WorldBootstrap.gd`
- `systems/` directory (entire legacy architecture)

### Migrations Completed
✅ **BootstrapPreview migrated** to use `BootstrapGameWorld`:
- `scenes/BootstrapPreview.gd` updated to call BootstrapGameWorld.run()
- Uses world_state structure instead of direct league access
- Properly integrates with AdvanceWorldYear pipeline

---

## Impact

**Before**:
- Class name collisions caused non-deterministic behavior
- Which class was used depended on load order
- Compilation errors from missing dependencies

**After**:
- ✅ Single canonical implementation for each entity type
- ✅ No class name collisions
- ✅ Compilation errors resolved
- ✅ Proper ConfigService architecture throughout

---

## Canonical Classes

### Core Models
- **Team**: `scripts/core/models/Team.gd`
  - Cap accounting integration
  - SportRoster support
  - Serialization: to_dict(), from_dict()

- **Coach**: `scripts/core/models/Coach.gd`
  - Basic serialization
  - Future: ratings, resume, prestige

### Pipeline Systems
- **WorldBootstrap**: `scripts/pipelines/BootstrapGameWorld.gd`
  - Multi-year world simulation
  - Deterministic seed derivation
  - Integrates with AdvanceWorldYear

---

## Lessons Learned

### What Caused Duplicates

1. **Iterative refactoring** - New implementations created without removing old
2. **Unclear deprecation** - Legacy files not marked as obsolete
3. **Scattered architecture** - Multiple directories with similar purposes
4. **No cleanup process** - No systematic review of deprecated code

### Prevention Strategies

1. **Delete first, create second** - Remove old implementation before committing new
2. **Clear migration docs** - Document what's canonical, what's deprecated
3. **Regular cleanup** - Periodic review of untracked and unused files
4. **Single source of truth** - One directory per architecture layer

---

## References

- **Resolution PR**: #65 (WorldBootstrap resolution)
- **Cleanup session**: January 2026 (removed ~30 files)
- **New architecture**: Track D implementation (BootstrapGameWorld)
- **Completed work**: See `docs/COMPLETED.md`
