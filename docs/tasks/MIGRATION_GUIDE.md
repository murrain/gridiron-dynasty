# Task Folder Reorganization - Migration Guide

## Overview

The `docs/tasks/` folder has been reorganized to separate completed work (archived) from active tasks (organized by theme). This improves clarity and makes it easier to understand project status.

## What Changed

### Before (27 files, flat structure)
```
docs/tasks/
  ├── README.md
  ├── TASK_E5_player_value_calculator.md
  ├── TASK_E6_update_contract_valuation.md
  ├── TASK_E7_market_supply.md
  ├── TASK_E8_wire_valuation_flow.md
  ├── TASK_E9_valuation_configs.md
  ├── TASK_E10_valuation_tests.md
  ├── TASK_F1_profiling_report.md
  ├── TASK_F2_recruiting_optimization.md
  ├── TASK_F2_SUMMARY.md
  ├── TASK_F2_INTEGRATION_CHECKLIST.md
  ├── TASK_F3_scout_caching.md
  ├── TASK_F4_deep_copy_reduction.md
  ├── TASK_F4_implementation_summary.md
  ├── TASK_F5_parallel_lifecycle.md
  ├── TASK_F6_config_optimization.md
  ├── TASK_F6_implementation_summary.md
  ├── TASK_F7_development_report_deferral.md
  ├── TASK_F8_benchmark_suite.md
  ├── TASK_P1_phase_timing_capture.md
  ├── TASK_P2_recruiting_score_cache.md
  ├── TASK_P3_lifecycle_copy_reduction.md
  ├── TASK_P3_implementation_summary.md
  ├── TASK_TEST_FIXTURES.md
  └── TASK_TEST_PARALLEL.md
```

### After (organized structure)
```
docs/tasks/
  ├── README.md (updated, active tasks only)
  ├── MIGRATION_GUIDE.md (this file)
  ├── valuation/
  │   ├── README.md
  │   ├── TASK_E5_player_value_calculator.md
  │   ├── TASK_E6_update_contract_valuation.md
  │   ├── TASK_E7_market_supply.md
  │   ├── TASK_E8_wire_valuation_flow.md
  │   ├── TASK_E9_valuation_configs.md
  │   └── TASK_E10_valuation_tests.md
  ├── performance/
  │   ├── README.md
  │   ├── TASK_F7_development_report_deferral.md
  │   └── TASK_P1_phase_timing_capture.md
  ├── testing/
  │   ├── README.md
  │   ├── TASK_TEST_FIXTURES.md
  │   └── TASK_TEST_PARALLEL.md
  └── archive/
      └── 2026-01/
          ├── README.md (completion summary)
          ├── performance_track_F1-F3_F8/
          │   ├── TASK_F1_profiling_report.md
          │   ├── TASK_F2_recruiting_optimization.md
          │   ├── TASK_F2_SUMMARY.md
          │   ├── TASK_F2_INTEGRATION_CHECKLIST.md
          │   ├── TASK_F3_scout_caching.md
          │   └── TASK_F8_benchmark_suite.md
          ├── deep_optimizations_F4-F6/
          │   ├── TASK_F4_deep_copy_reduction.md
          │   ├── TASK_F4_implementation_summary.md
          │   ├── TASK_F5_parallel_lifecycle.md
          │   ├── TASK_F6_config_optimization.md
          │   └── TASK_F6_implementation_summary.md
          └── lifecycle_refinements_P2-P3/
              ├── TASK_P2_recruiting_score_cache.md
              ├── TASK_P3_lifecycle_copy_reduction.md
              └── TASK_P3_implementation_summary.md
```

## File Movement Summary

### Archived (Completed January 2026)

**Performance Track (F1-F3, F8)**
- `TASK_F1_profiling_report.md` → `archive/2026-01/performance_track_F1-F3_F8/`
- `TASK_F2_recruiting_optimization.md` → `archive/2026-01/performance_track_F1-F3_F8/`
- `TASK_F2_SUMMARY.md` → `archive/2026-01/performance_track_F1-F3_F8/`
- `TASK_F2_INTEGRATION_CHECKLIST.md` → `archive/2026-01/performance_track_F1-F3_F8/`
- `TASK_F3_scout_caching.md` → `archive/2026-01/performance_track_F1-F3_F8/`
- `TASK_F8_benchmark_suite.md` → `archive/2026-01/performance_track_F1-F3_F8/`

**Deep Optimizations (F4-F6)**
- `TASK_F4_deep_copy_reduction.md` → `archive/2026-01/deep_optimizations_F4-F6/`
- `TASK_F4_implementation_summary.md` → `archive/2026-01/deep_optimizations_F4-F6/`
- `TASK_F5_parallel_lifecycle.md` → `archive/2026-01/deep_optimizations_F4-F6/`
- `TASK_F6_config_optimization.md` → `archive/2026-01/deep_optimizations_F4-F6/`
- `TASK_F6_implementation_summary.md` → `archive/2026-01/deep_optimizations_F4-F6/`

**Lifecycle Refinements (P2-P3)**
- `TASK_P2_recruiting_score_cache.md` → `archive/2026-01/lifecycle_refinements_P2-P3/`
- `TASK_P3_lifecycle_copy_reduction.md` → `archive/2026-01/lifecycle_refinements_P2-P3/`
- `TASK_P3_implementation_summary.md` → `archive/2026-01/lifecycle_refinements_P2-P3/`

### Organized by Theme (Active Tasks)

**Valuation Track**
- `TASK_E5_player_value_calculator.md` → `valuation/`
- `TASK_E6_update_contract_valuation.md` → `valuation/`
- `TASK_E7_market_supply.md` → `valuation/`
- `TASK_E8_wire_valuation_flow.md` → `valuation/`
- `TASK_E9_valuation_configs.md` → `valuation/`
- `TASK_E10_valuation_tests.md` → `valuation/`

**Performance Track**
- `TASK_F7_development_report_deferral.md` → `performance/`
- `TASK_P1_phase_timing_capture.md` → `performance/`

**Testing Infrastructure**
- `TASK_TEST_FIXTURES.md` → `testing/`
- `TASK_TEST_PARALLEL.md` → `testing/`

## How to Migrate

### Option 1: Run Migration Script (Recommended)

```bash
cd /home/patrick/Documents/code/gridiron-dynasty
bash scripts/reorganize_tasks.sh
```

The script will:
1. Create all necessary directories
2. Move completed tasks to archive
3. Organize active tasks by theme
4. Preserve all file contents (no data loss)

### Option 2: Manual Migration

If you prefer manual control, follow the file movement summary above. The script `/home/patrick/Documents/code/gridiron-dynasty/scripts/reorganize_tasks.sh` contains all the commands.

### Option 3: Git-based Migration (Preserves History)

If you want to preserve git history for moved files:

```bash
cd /home/patrick/Documents/code/gridiron-dynasty

# Create directories
mkdir -p docs/tasks/archive/2026-01/{performance_track_F1-F3_F8,deep_optimizations_F4-F6,lifecycle_refinements_P2-P3}
mkdir -p docs/tasks/{valuation,performance,testing}

# Use git mv to preserve history
git mv docs/tasks/TASK_F1_profiling_report.md docs/tasks/archive/2026-01/performance_track_F1-F3_F8/
git mv docs/tasks/TASK_F2_recruiting_optimization.md docs/tasks/archive/2026-01/performance_track_F1-F3_F8/
# ... continue for all files (see script for complete list)

# Commit the reorganization
git add docs/tasks/
git commit -m "docs: reorganize tasks folder (archive completed work, organize by theme)"
```

## Updating References

### In Documentation
If any docs reference moved task files, update paths:

**Old**: `See docs/tasks/TASK_F4_deep_copy_reduction.md`
**New**: `See docs/tasks/archive/2026-01/deep_optimizations_F4-F6/TASK_F4_deep_copy_reduction.md`

### In Code Comments
If code comments reference task files, update paths:

```gdscript
# Old
# See docs/tasks/TASK_F5_parallel_lifecycle.md for design rationale

# New
# See docs/tasks/archive/2026-01/deep_optimizations_F4-F6/TASK_F5_parallel_lifecycle.md for design rationale
```

### Search for References
```bash
# Find all references to old task paths
grep -r "docs/tasks/TASK_F[0-9]" --exclude-dir=.git
grep -r "docs/tasks/TASK_P[0-9]" --exclude-dir=.git
grep -r "docs/tasks/TASK_E[0-9]" --exclude-dir=.git
```

## What to Do After Migration

### 1. Verify Files
Check that all files are in the correct locations:
```bash
ls docs/tasks/archive/2026-01/performance_track_F1-F3_F8/
ls docs/tasks/archive/2026-01/deep_optimizations_F4-F6/
ls docs/tasks/archive/2026-01/lifecycle_refinements_P2-P3/
ls docs/tasks/valuation/
ls docs/tasks/performance/
ls docs/tasks/testing/
```

### 2. Replace README
```bash
cd /home/patrick/Documents/code/gridiron-dynasty/docs/tasks
mv README.md README_OLD.md
mv README_NEW.md README.md
```

### 3. Review Archive README
Read `docs/tasks/archive/2026-01/README.md` for completion summary and performance metrics.

### 4. Update Bookmarks
If you have editor bookmarks or browser links to specific task files, update them to new paths.

## Benefits of New Structure

### Clarity
- **Active vs Complete**: Immediately clear what's done vs pending
- **Thematic Grouping**: Related tasks together (valuation, performance, testing)
- **Historical Context**: Archive preserves what was done and why

### Navigation
- **Fewer Files in Root**: Only 3 subdirs + README vs 27 files
- **Contextual READMEs**: Each subdirectory explains its tasks
- **Clear Sequencing**: Dependencies and priorities documented

### Maintainability
- **Archive Pattern**: Established pattern for future completions
- **Performance Metrics**: Archive documents impact of completed work
- **Lessons Learned**: Archive captures what worked and what didn't

## Troubleshooting

### "File not found" after migration
Check both old and new locations. The file may have been moved to:
- `archive/2026-01/` (if completed)
- `valuation/` (if E5-E10)
- `performance/` (if F7 or P1)
- `testing/` (if TEST_*)

### "I need to reference a completed task"
Use the archive path:
```
docs/tasks/archive/2026-01/<category>/<filename>
```

### "I want to undo the migration"
The reorganization script doesn't delete files, only moves them. You can:
1. Move files back manually
2. Use `git mv` to reverse moves (if using git)
3. Restore from backup if one was made

## Questions?

- **What was completed?** See `docs/tasks/archive/2026-01/README.md`
- **What's next?** See `docs/tasks/README.md` (active tasks)
- **How to add new tasks?** Place in appropriate subdirectory with status
- **When to archive?** When implementation summary is written and PR merged

## Checklist

- [ ] Run migration script or manually move files
- [ ] Replace README.md with README_NEW.md
- [ ] Verify all files in correct locations
- [ ] Update any references in code/docs
- [ ] Review archive README for historical context
- [ ] Update bookmarks/shortcuts to task files
- [ ] Commit changes (if using git)
