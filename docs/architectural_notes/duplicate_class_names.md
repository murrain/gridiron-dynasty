# Duplicate Class Name Issue

**Discovered**: 2026-01-10 during type inference fixes
**Status**: Known issue, needs resolution before Phase 4 completion
**Priority**: Medium (blocking for Phase 4, not for current phase)

## Issue

GDScript class name collision exists for two core entity types:

### Team Classes

1. **`scripts/core/models/Team.gd`** (Phase 4 cap accounting model)
   - Has `SportRoster` integration
   - Cap accounting (`cap_used`, `cap_space` as computed properties)
   - Serialization: `to_dict()`, `from_dict()`
   - Purpose: Full team model with financial tracking

2. **`scripts/models/Team.gd`** (Legacy/simpler model)
   - Simple arrays: `roster`, `practice_squad`, `staff`
   - No cap accounting
   - Purpose: Earlier phase model

**Both define**: `class_name Team`

### Coach Classes

1. **`scripts/core/models/Coach.gd`** (Minimal model)
   - Basic serialization only
   - Fields: TBD (file exists but minimal)

2. **`scripts/models/Coach.gd`** (Richer model)
   - Has ratings, resume, prestige
   - More complete representation

**Both define**: `class_name Coach`

### WorldBootstrap Classes

1. **`systems/WorldBootstrap.gd`** (Legacy implementation)
   - Uses global `Config` autoload
   - Has `_gen_ranked_class()` helper
   - Multi-year HS → College → Pro bootstrap
   - Purpose: Original bootstrap implementation

2. **`scripts/world/WorldBootstrap.gd`** (Slightly newer legacy)
   - Uses global `Config` autoload
   - Has `generate_class()` and safe_get/safe_set helpers
   - Similar multi-year bootstrap
   - Purpose: Refactored bootstrap implementation

3. **`scripts/pipelines/BootstrapGameWorld.gd`** (NEW - Track D)
   - Uses `ConfigService` instances (proper architecture)
   - Integrates with `AdvanceWorldYear` pipeline
   - Deterministic seed derivation
   - Purpose: **Current canonical implementation**

**Both legacy files define**: `class_name WorldBootstrap` at line 2

**Additional errors in both legacy files**:
- Line 7/9: Wrong RecruitRater path (`scripts/rating/` → should be `scripts/core/rating/`)
- Line 75/96: Missing `rng` parameter in `generate_class()` call
- Line 76/97: Type inference fails for `rater` variable due to failed preload

**Current usage**: Only `scenes/BootstrapPreview.gd` references WorldBootstrap (explicitly loads `scripts/world/WorldBootstrap.gd`)

## Impact

- **GDScript Limitation**: Only one class with a given `class_name` can be registered
- **Current Behavior**: Which class is used depends on load order (non-deterministic)
- **Risk**: Code expecting one Team class may get the other, causing runtime errors

## Recommended Resolution

### Option 1: Rename Legacy Classes (Preferred)
- Keep `scripts/core/models/Team.gd` as canonical `Team`
- Rename `scripts/models/Team.gd` to `TeamLegacy` or `TeamSimple`
- Same for Coach

**Pros**: Clear migration path, preserves new architecture
**Cons**: Requires updating references to old classes

### Option 2: Namespace by Phase
- `TeamHS`, `TeamCollege`, `TeamPro` (level-specific)
- Only if different levels truly need different models

**Pros**: Explicit level distinction
**Cons**: More complex, may be premature

### Option 3: Remove Deprecated Classes
- Delete `scripts/models/` versions if no longer used
- Consolidate to single canonical model

**Pros**: Simplest, removes confusion
**Cons**: May lose work if those models are still needed

## Investigation Needed

1. **Which Team class is currently used?**
   - Search codebase for `Team.new()` calls
   - Check which features are actively used

2. **Are both models needed?**
   - Could `core/models/Team` replace `models/Team` entirely?
   - Or do they serve different lifecycle stages?

3. **Migration path for Coach**
   - Same questions apply to Coach classes

## Action Items

- [ ] Audit all `Team.new()` and `Coach.new()` usage across codebase
- [ ] Determine if `scripts/models/` versions are actively used
- [ ] Choose resolution strategy (rename, consolidate, or namespace)
- [ ] Update all references to use canonical classes
- [ ] Add test coverage for chosen Team/Coach models
- [ ] Remove duplicate class definitions

## References

- Identified in code-quality-reviewer report (2026-01-10)
- Related to Phase 4 scaffolding work (plan.md)
- See AGENTS.md for architecture change guidelines
