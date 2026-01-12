# Task Folder Quick Reference

## TL;DR

- **Active tasks**: `docs/tasks/valuation/`, `performance/`, `testing/`
- **Completed work**: `docs/tasks/archive/2026-01/`
- **To migrate**: `bash scripts/reorganize_tasks.sh`

## File Finder

### Looking for a specific task?

| Task | Old Location | New Location | Status |
|------|-------------|--------------|--------|
| E5 | `docs/tasks/TASK_E5_*.md` | `docs/tasks/valuation/TASK_E5_*.md` | Active |
| E6 | `docs/tasks/TASK_E6_*.md` | `docs/tasks/valuation/TASK_E6_*.md` | Active |
| E7 | `docs/tasks/TASK_E7_*.md` | `docs/tasks/valuation/TASK_E7_*.md` | Active |
| E8 | `docs/tasks/TASK_E8_*.md` | `docs/tasks/valuation/TASK_E8_*.md` | Active |
| E9 | `docs/tasks/TASK_E9_*.md` | `docs/tasks/valuation/TASK_E9_*.md` | Active |
| E10 | `docs/tasks/TASK_E10_*.md` | `docs/tasks/valuation/TASK_E10_*.md` | Active |
| F1 | `docs/tasks/TASK_F1_*.md` | `docs/tasks/archive/2026-01/performance_track_F1-F3_F8/` | Completed ✅ |
| F2 | `docs/tasks/TASK_F2_*.md` | `docs/tasks/archive/2026-01/performance_track_F1-F3_F8/` | Completed ✅ |
| F3 | `docs/tasks/TASK_F3_*.md` | `docs/tasks/archive/2026-01/performance_track_F1-F3_F8/` | Completed ✅ |
| F4 | `docs/tasks/TASK_F4_*.md` | `docs/tasks/archive/2026-01/deep_optimizations_F4-F6/` | Completed ✅ |
| F5 | `docs/tasks/TASK_F5_*.md` | `docs/tasks/archive/2026-01/deep_optimizations_F4-F6/` | Completed ✅ |
| F6 | `docs/tasks/TASK_F6_*.md` | `docs/tasks/archive/2026-01/deep_optimizations_F4-F6/` | Completed ✅ |
| F7 | `docs/tasks/TASK_F7_*.md` | `docs/tasks/performance/TASK_F7_*.md` | Active |
| F8 | `docs/tasks/TASK_F8_*.md` | `docs/tasks/archive/2026-01/performance_track_F1-F3_F8/` | Completed ✅ |
| P1 | `docs/tasks/TASK_P1_*.md` | `docs/tasks/performance/TASK_P1_*.md` | Active |
| P2 | `docs/tasks/TASK_P2_*.md` | `docs/tasks/archive/2026-01/lifecycle_refinements_P2-P3/` | Completed ✅ |
| P3 | `docs/tasks/TASK_P3_*.md` | `docs/tasks/archive/2026-01/lifecycle_refinements_P2-P3/` | Completed ✅ |
| TEST_FIXTURES | `docs/tasks/TASK_TEST_FIXTURES.md` | `docs/tasks/testing/TASK_TEST_FIXTURES.md` | Active |
| TEST_PARALLEL | `docs/tasks/TASK_TEST_PARALLEL.md` | `docs/tasks/testing/TASK_TEST_PARALLEL.md` | Active |

## What Should I Work On Next?

### High Priority
1. **E5** - Foundation for valuation system (1-2 days)
2. **P1** - Phase timing instrumentation (1 day)

### After E5
3. **E6** - Contract valuation (1 day, depends on E5)
4. **E7** - Market supply (1-2 days, depends on E5)

### Lower Priority
5. **TEST_FIXTURES** - Speed up test suite (3-4 days)
6. **F7** - Report deferral (1-2 days, if profiling shows benefit)

See `docs/tasks/README.md` for detailed priorities and sequencing.

## What Was Completed?

**January 2026** - Major performance optimization push:
- Bootstrap time: 12min → 30sec (96% reduction)
- Memory usage: 2.27GB → 154MB (93% reduction)
- Tasks: F1, F2, F3, F4, F5, F6, F8, P2, P3

See `docs/tasks/archive/2026-01/README.md` for full details and metrics.

## Directory Structure

```
docs/tasks/
├── README.md ← Start here for overview
├── QUICK_REFERENCE.md ← This file
├── MIGRATION_GUIDE.md ← How to reorganize files
├── REORGANIZATION_SUMMARY.md ← Architecture guardian notes
│
├── valuation/ ← Player valuation system (E5-E10)
│   ├── README.md ← Valuation track overview
│   └── TASK_E*.md ← 6 valuation tasks
│
├── performance/ ← Speed/memory optimization (F7, P1)
│   ├── README.md ← Performance track overview
│   └── TASK_F7_*.md, TASK_P1_*.md ← 2 remaining tasks
│
├── testing/ ← Test infrastructure (TEST_*)
│   ├── README.md ← Testing track overview
│   └── TASK_TEST_*.md ← 2 testing tasks
│
└── archive/
    └── 2026-01/ ← January 2026 completions
        ├── README.md ← Completion summary + metrics
        ├── performance_track_F1-F3_F8/ ← 6 files
        ├── deep_optimizations_F4-F6/ ← 5 files
        └── lifecycle_refinements_P2-P3/ ← 3 files
```

## Quick Commands

### Migrate Files
```bash
bash scripts/reorganize_tasks.sh
```

### Find a Task
```bash
# Search by task number
find docs/tasks -name "*E5*"
find docs/tasks -name "*F7*"

# List all active tasks
ls docs/tasks/valuation/
ls docs/tasks/performance/
ls docs/tasks/testing/

# List archived tasks
ls docs/tasks/archive/2026-01/*/
```

### Update References
```bash
# Find references to old paths
grep -r "docs/tasks/TASK_F" --exclude-dir=.git

# Update them to new paths
# Old: docs/tasks/TASK_F4_deep_copy_reduction.md
# New: docs/tasks/archive/2026-01/deep_optimizations_F4-F6/TASK_F4_deep_copy_reduction.md
```

## Status Indicators

- 🟢 **READY** - Can start now, all dependencies met
- 🟡 **BLOCKED** - Waiting on other tasks
- 🔴 **PENDING** - Not yet prioritized
- ⚡ **HIGH PRIORITY** - Should tackle next

## Common Questions

**Q: Where did F4 go?**
A: `docs/tasks/archive/2026-01/deep_optimizations_F4-F6/` - it's completed!

**Q: What's the difference between F and P tracks?**
A: F = main performance track, P = follow-up refinements. Both completed in Jan 2026.

**Q: Should I start with E5 or P1?**
A: E5 if you want to build valuation system, P1 if you want better performance observability. See README for trade-offs.

**Q: Why are some tasks archived?**
A: They're completed! See archive README for what was done and performance improvements achieved.

**Q: How do I add a new task?**
A: Add to appropriate category (valuation/performance/testing), update that category's README, update main README.

**Q: What if a task doesn't fit any category?**
A: Create new category with README explaining its purpose and scope.

## Links

- [Main README](README.md) - Overview of all active tasks
- [Archive](archive/2026-01/README.md) - January 2026 completions
- [Migration Guide](MIGRATION_GUIDE.md) - How to reorganize
- [Architecture Summary](REORGANIZATION_SUMMARY.md) - Design rationale

## One-Liner Summary

**Completed work** → `archive/YYYY-MM/`
**Active work** → `valuation/`, `performance/`, `testing/`
**Next priorities** → E5 (valuation foundation) or P1 (timing instrumentation)
