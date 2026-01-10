# Active Development Tasks

For completed work, see `COMPLETED.md`.

## Working Agreements (All Engineers)

- Prefer explicit state transitions over hidden state
- RNG must be passed explicitly; seeds logged or persisted per phase
- Keep changes small and reviewable
- Avoid UI unless required by simulation correctness
- Configuration over magic numbers

## Current Priorities

1. **Track E (Player Valuation)** - Complete the valuation system integration (80% complete)
2. **Track F (Performance Optimization)** - Bootstrap performance improvement (Ready to start)

---

## Available Tasks

Tasks are organized by priority and dependencies. Each task is a complete, self-contained unit of work documented in `docs/tasks/`.

### High Priority: Player Valuation (Track E)

**Status**: 8/10 tasks completed (E1-E7 ✅)

Components complete:
- ✅ E1: Non-linear value curve (`ValueCurve.gd`)
- ✅ E2: Replacement level (`ReplacementLevel.gd`)
- ✅ E3: Positional scarcity (`PositionalScarcity.gd`)
- ✅ E4: Team impact valuation (`TeamImpact.gd`)
- ✅ E5: Unified PlayerValue calculator (`PlayerValue.gd`)
- ✅ E6: ContractValuation integration (`ContractValuation.gd`)
- ✅ E7: Market supply tracking (`MarketSupply.gd`)
- ✅ E9: Consolidated configs (`valuation.json`)

**Remaining integration work** (do in order):

| Task | File | Dependencies | Effort | Status |
|------|------|--------------|--------|--------|
| **E8** | `docs/tasks/TASK_E8_wire_valuation_flow.md` | E5, E6, E7 (✅) | 1-2 days | 🔴 Ready to start |
| **E10** | `docs/tasks/TASK_E10_valuation_tests.md` | E1-E9 | 2 days | 🔴 Not started |

**To start next task**: Read `docs/tasks/TASK_E8_wire_valuation_flow.md`

**Implementation sequence**:
```
✅ E5 (PlayerValue) ─┬─→ ✅ E6 (ContractValuation) ─┐
✅ E7 (MarketSupply) ─┴─→ E8 (ValuationFlow) ───────┤
✅ E9 (Configs) ─────────────────────────────────┬─┘
E10 (Tests) ──────────────────────────────────┘
```

---

### Critical Priority: Performance Optimization (Track F)

**Status**: Planning complete, ready to implement

| Task | File | Dependencies | Effort | Status | Impact |
|------|------|--------------|--------|--------|--------|
| **F1** | `docs/tasks/TASK_F1_profiling_report.md` | None | - | ✅ Complete | Foundation |
| **F8** | `docs/tasks/TASK_F8_benchmark_suite.md` | F1 | 1 day | 🔴 Not started | Required |
| **F2** | `docs/tasks/TASK_F2_recruiting_optimization.md` | F8 | 2-3 days | 🔴 Not started | 50-70% reduction |
| **F3** | `docs/tasks/TASK_F3_scout_caching.md` | F2 | 1-2 days | 🔴 Not started | 20-30% reduction |
| **F4** | `docs/tasks/TASK_F4_deep_copy_reduction.md` | F3 | 1-2 days | 🔴 Not started | 10-20% reduction |
| **F5** | `docs/tasks/TASK_F5_parallel_lifecycle.md` | F4 | 1-2 days | 🔴 Not started | 10-15% reduction |
| **F6** | `docs/tasks/TASK_F6_config_optimization.md` | F5 | 0.5-1 day | 🔴 Not started | 5-10% reduction |
| **F7** | `docs/tasks/TASK_F7_development_report_deferral.md` | F5 | 0.5 day | 🔴 Not started | Memory focus |

**Current baseline**: 20-year bootstrap takes ~12 minutes (~36s per year)
**Target**: Reduce to under 3 minutes (75% improvement)

**To start next task**: Read `docs/PHASE_F_ROADMAP.md` for overview, then `docs/tasks/TASK_F8_benchmark_suite.md`

**Implementation sequence**:
```
✅ F1 (Profiling) → F8 (Benchmarks) → F2 (Recruiting) → F3 (Caching) → F4 (Deep Copy) → F5 (Parallel) → F6/F7 (Polish)
```

---

### Medium Priority: Testing Performance (Phase 2-3)

**Status**: Phase 1 complete ✅ (TestRunnerFast - 10s feedback loop)

| Task | File | Dependencies | Effort | Status |
|------|------|--------------|--------|--------|
| **Phase 2** | `docs/tasks/TASK_TEST_FIXTURES.md` | None | 3-4 days | 🔴 Not started |
| **Phase 3** | `docs/tasks/TASK_TEST_PARALLEL.md` | Phase 2 | 5-7 days | 🔴 Not started |

**Goals**:
- Phase 2: Reduce test time to 30-45s via fixtures
- Phase 3: Reduce test time to 15-30s via parallel execution

**To start Phase 2**: Read `docs/tasks/TASK_TEST_FIXTURES.md`

---

## How to Pick a Task

### For Engineers

1. **Check dependencies**: Ensure prerequisite tasks are completed (marked ✅)
2. **Read task file**: Full context and implementation details in `docs/tasks/TASK_*.md`
3. **Follow task structure**:
   - Goal and motivation
   - Implementation details with code examples
   - Test coverage requirements
   - Acceptance criteria
   - Files to create/modify
4. **Submit PR**: Reference task file in PR description

### Task File Structure

Each task file includes:
- **Dependencies**: What must be done first
- **Goal**: What this task achieves
- **Implementation**: Detailed code examples and logic
- **Test Coverage**: Required test cases
- **Acceptance Criteria**: Definition of done
- **Files**: What to create/modify
- **Next Task**: What to do after completion

---

## Quick Reference

### Commands

```bash
# Fast test feedback (< 10 seconds)
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Full test suite (~2 minutes)
godot --headless -s res://scripts/tests/TestRunner.gd

# Single test for debugging
godot --headless -s res://scripts/tests/TestRunnerSingle.gd test_name.gd

# Generate a draft class (with BBCode formatting)
godot --headless res://scenes/generate_once.tscn

# Bootstrap world preview
godot --headless res://scenes/bootstrap_preview.tscn
```

### Current Architecture

**Simulation Pipeline** (AdvanceWorldYear.gd):
1. HS Generation → Assignment → Season
2. College Generation → Recruiting → Season
3. NFL Team Generation (cached)
4. Draft Prep → Valuation → Draft
5. Cap Validation → NFL Season

**Valuation Pipeline** (ValuationFlow.gd - in progress):
1. Market supply calculation (E7)
2. Player valuation (E5)
3. Team-specific adjustments (E4)
4. Contract generation (E6)

**Testing Strategy**:
- Fast tests: Unit tests (< 1s each) - 20 tests, ~10s total
- Slow tests: Integration tests (> 2s each) - 10+ tests, ~30s with fixtures
- Full suite: All tests (~2 min currently, target < 30s)

---

## Parallel Work Guidelines

Tasks can be worked on in parallel if:
- Dependencies are met
- No file conflicts (check "Files to Modify" in task files)
- Different engineers coordinate via PRs

**Currently safe to parallelize**:
- E7 (MarketSupply) + E9 (Configs) - no file conflicts
- Any E-track task + Testing Phase 2 - completely independent

---

## Review Checklist

Before marking a task complete, verify:

1. **Determinism**: All RNG is explicit, seeds logged, same seed = same output
2. **State transitions**: Player/team status changes are explicit and logged
3. **No data loss**: Operations preserve all required data
4. **Config-driven**: No magic numbers (all values in config files)
5. **Test coverage**: All new code has deterministic tests
6. **Documentation**: Complex logic has explanatory comments
7. **Backwards compatibility**: Existing callers still work

---

## Notes

### Simulation Complete ✅

The core simulation loop (Tracks A-D) is **complete**:
- High school → College → NFL player progression
- Multi-year bootstrapping with deterministic seeds
- Draft, season advancement, retirements all functional

### Valuation In Progress 🟡

Core valuation components (E1-E4) are implemented. Remaining work:
- **Integration**: Wire components together (E5, E6, E8)
- **Infrastructure**: Supply tracking (E7), configs (E9), tests (E10)
- **Timeline**: ~5-7 days of work remaining

### Testing Optimization Available 🟢

Phase 1 provides immediate relief (10s feedback).
Phases 2-3 are optional quality-of-life improvements.

---

## For Architects

When planning new features, follow this structure:

1. **Create task file** in `docs/tasks/TASK_[NAME].md`
2. **Include**:
   - Clear dependencies
   - Code examples and API designs
   - Test requirements
   - Acceptance criteria
3. **Add to plan.md** with priority and effort estimate
4. **Assign to engineer** or mark available

This ensures engineers have complete context to work autonomously.

---

## References

- **Completed Work**: `docs/COMPLETED.md`
- **Task Files**: `docs/tasks/TASK_*.md`
- **Architectural Notes**: `docs/architectural_notes/`
- **Agent Guidelines**: `AGENTS.md`
