# Documentation Overview

This directory contains all project documentation organized by purpose.

## Quick Start for Engineers

**To pick up the next task**: Read `../plan.md` and follow the task file references.

**Current priority**: Track E (Player Valuation) - See task files in `tasks/` directory

---

## Directory Structure

```
docs/
├── README.md                      (this file)
├── COMPLETED.md                   Archive of finished work
├── PHASE_F_ROADMAP.md             Performance optimization plan
├── tasks/                         Individual task files (ready to work)
│   ├── TASK_E5_player_value_calculator.md
│   ├── TASK_E6_update_contract_valuation.md
│   ├── TASK_E7_market_supply.md
│   ├── TASK_E8_wire_valuation_flow.md
│   ├── TASK_E9_valuation_configs.md
│   ├── TASK_E10_valuation_tests.md
│   ├── TASK_F1_profiling_report.md
│   ├── TASK_F2_recruiting_optimization.md
│   ├── TASK_F3_scout_caching.md
│   ├── TASK_F4_deep_copy_reduction.md
│   ├── TASK_F5_parallel_lifecycle.md
│   ├── TASK_F6_config_optimization.md
│   ├── TASK_F7_development_report_deferral.md
│   ├── TASK_F8_benchmark_suite.md
│   ├── TASK_TEST_FIXTURES.md
│   └── TASK_TEST_PARALLEL.md
└── architectural_notes/           Historical decisions & resolutions
    ├── duplicate_class_names.md  (Resolved ✅)
    ├── worldbootstrap_resolution.md (Resolved ✅)
    └── testing_performance_strategy.md (Phase 1 complete ✅)
```

---

## File Purposes

### plan.md (Root)
**Active development roadmap**
- Current priorities and available tasks
- Task dependencies and implementation order
- Quick reference commands
- Review checklist

### COMPLETED.md
**Historical archive**
- Tracks A-D (Simulation pipeline) - Complete
- Track E tasks E1-E4 (Valuation foundation) - Complete
- Testing Phase 1 (Fast test runner) - Complete
- Architectural cleanups and resolutions

### tasks/ (Individual Task Files)
**Ready-to-work task specifications**

Each task file contains:
- Clear goal and motivation
- Dependencies (what must be done first)
- Detailed implementation with code examples
- Test coverage requirements
- Acceptance criteria (definition of done)
- List of files to create/modify
- Reference to next task

**Current tasks available**:

#### Performance Optimization (Track F) - Critical Priority
- **F1**: Profiling report and analysis (Complete)
- **F2**: College recruiting optimization (2-3 days) - P0
- **F3**: Scout evaluation caching (1-2 days) - P1
- **F4**: Deep copy reduction (1-2 days) - P2
- **F5**: Parallel player lifecycle (1-2 days) - P3
- **F6**: Config access optimization (0.5-1 day) - P5
- **F7**: Development report deferral (0.5 day) - P4
- **F8**: Benchmark suite (1 day) - Required

See `PHASE_F_ROADMAP.md` for complete optimization plan.

#### Player Valuation (Track E) - High Priority
- **E5**: Unified PlayerValue calculator (1-2 days)
- **E6**: Update ContractValuation integration (1 day)
- **E7**: Market supply tracking (0.5 days)
- **E8**: Wire into ValuationFlow (1-2 days)
- **E9**: Consolidate configs (0.5 days)
- **E10**: Comprehensive test suite (2 days)

#### Testing Performance - Medium Priority
- **Phase 2**: Test fixtures implementation (3-4 days)
- **Phase 3**: Parallel test execution (5-7 days)

### architectural_notes/
**Resolved issues and strategic decisions**

These documents capture:
- Problems encountered
- Solutions implemented
- Lessons learned
- Prevention strategies

All notes in this directory are **resolved** and serve as historical reference.

---

## How to Use This Documentation

### For Engineers Starting a Task

1. **Read plan.md** - Understand current priorities
2. **Check dependencies** - Ensure prerequisites are complete
3. **Open task file** - Get full implementation details
4. **Work autonomously** - Task files have everything needed
5. **Submit PR** - Reference task file in description

### For Architects Planning Work

1. **Create task file** in `tasks/TASK_[NAME].md`
2. **Include**:
   - Goal and motivation
   - Dependencies
   - Implementation details with code examples
   - Test requirements
   - Acceptance criteria
   - Files to modify
3. **Add to plan.md** with priority and effort estimate
4. **Assign or mark available**

### For Historical Research

- **COMPLETED.md** - What's been built
- **architectural_notes/** - Why decisions were made
- **Task files** - How features were implemented

---

## Documentation Principles

### Keep It Current
- Completed work moves to COMPLETED.md
- Active work stays in plan.md
- Task files remain until work is done

### Self-Contained Tasks
- Each task file has all information needed
- Engineers don't need to search multiple docs
- Code examples included inline

### Clear Status
- ✅ Completed (in COMPLETED.md)
- 🟡 In progress (in plan.md)
- 🔴 Not started (in tasks/)

### No Orphaned Docs
- Every doc has a clear purpose
- Outdated docs are archived or removed
- Status markers prevent confusion

---

## Recent Changes (January 2026)

### Documentation Reorganization
- ✅ Created `tasks/` directory with 8 individual task files
- ✅ Moved completed work to COMPLETED.md
- ✅ Updated plan.md to reference task files
- ✅ Marked resolved issues in architectural_notes/
- ✅ Removed obsolete PLAYER_VALUATION_TASKS.md

### Benefits
- **Clear next steps** - Engineers know exactly what to work on
- **Complete context** - All info in one task file
- **No ambiguity** - Status clearly marked
- **Easy navigation** - Logical file structure

---

## Quick Commands

```bash
# View active plan
cat plan.md

# View completed work
cat docs/COMPLETED.md

# List available tasks
ls docs/tasks/

# Read a specific task
cat docs/tasks/TASK_E5_player_value_calculator.md

# Run fast tests (10s feedback)
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Run full suite (~2 min)
godot --headless -s res://scripts/tests/TestRunner.gd
```

---

## Contributing

### When Adding New Features

1. **Architect creates task file** with complete specification
2. **Add to plan.md** with dependencies and priority
3. **Engineer picks task** and implements
4. **Upon completion**: Move to COMPLETED.md, remove task file

### When Updating Documentation

- **Completed work** → Add to COMPLETED.md
- **Resolved issues** → Update architectural_notes/ with ✅ status
- **New tasks** → Create in tasks/ directory
- **Active work** → Keep in plan.md

This ensures documentation stays organized and valuable.

---

## Support

For questions about:
- **Task implementation**: Read task file, then check plan.md
- **Historical context**: Check COMPLETED.md and architectural_notes/
- **Architecture decisions**: See architectural_notes/ or AGENTS.md
- **Testing strategy**: See testing_performance_strategy.md

---

Last updated: January 2026
