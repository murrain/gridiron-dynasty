# Quick Reference: Planning Documentation Guide

**Purpose**: One-page navigation to all planning documents
**Last Updated**: 2026-01-12

---

## What Are You Looking For?

### "What's being worked on right now?"
→ **[CURRENT_WORK_STATUS.md](CURRENT_WORK_STATUS.md)**
- Active sprint status
- Current assignments
- Blockers and dependencies
- Weekly sync template

### "What's the full Phase 1 plan?"
→ **[PHASE_1_ROADMAP.md](PHASE_1_ROADMAP.md)**
- All 25 Phase 1 features
- Team assignments (5 teams)
- Progress tracking (23/25 complete)
- Success criteria

### "What's next after Phase 1?"
→ **[PHASE_2_FEATURES.md](PHASE_2_FEATURES.md)**
- Strategic planning for future phases
- Long-term feature categories
- Architectural foundations needed
- Prioritization framework

### "How's the test suite doing?"
→ **[TEST_IMPROVEMENT_PLAN.md](TEST_IMPROVEMENT_PLAN.md)**
- Test quality assessment (7.5/10)
- 3 parallel improvement tracks
- Consolidation opportunities
- Coverage gaps

### "What about performance?"
→ **[PHASE_F_ROADMAP.md](PHASE_F_ROADMAP.md)**
- Performance optimization plan
- Current: 184.72s, Target: <150s
- 8 optimization tasks
- Benchmark results

---

## Phase 1 Progress at a Glance

```
PHASE 1 COMPLETION: 92% (23/25 features)

Team 1: Data Models        ✅ ████████████████████ 100% (5/5)
Team 2: Roster/Depth       ✅ ████████████████████ 100% (5/5)
Team 3: Game Simulation    ✅ ████████████████████ 100% (5/5)
Team 4: Offseason          🟡 ████████████░░░░░░░░  60% (3/5)
Team 5: Historical         ✅ ████████████████████ 100% (5/5)

Current Focus: Complete Team 4 (O4: Comp Picks, O5: Draft Trading)
ETA: 5 days
```

---

## Document Hierarchy

```
docs/planning/
├── README.md                     ← Master index (you are here-ish)
├── QUICK_REFERENCE.md            ← This file - navigation guide
│
├── PHASE_1_ROADMAP.md            ← Current phase (92% complete)
├── CURRENT_WORK_STATUS.md        ← Active sprint status
│
├── PHASE_2_FEATURES.md           ← Future strategic planning
│
├── TEST_IMPROVEMENT_PLAN.md      ← Test suite optimization
├── PHASE_F_ROADMAP.md            ← Performance optimization
│
└── archive/                      ← Superseded documents
    ├── MASTER_IMPLEMENTATION_PLAN.md.bak
    ├── QUICK_WINS_LIST.md.bak
    ├── FEATURE_EXPANSION_PLAN.md.bak
    ├── ARCHITECTURAL_GUARDIAN_ASSESSMENT.md.bak
    └── ACTIVE_TASKS.md.bak
```

---

## Quick Facts

### Timeline
- **Phase 1**: 11 weeks (Weeks 1-11) - 92% complete
- **Phase 2**: ~120 days (Months 4-8) - Planning stage
- **Phase 3**: ~137 days (Months 9-15) - Future

### Metrics
| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Phase 1 Features | 23/25 | 25/25 | 🟡 In Progress |
| Bootstrap Time | ~75s | <90s | ✅ On Target |
| World State Size | ~170MB | <200MB | ✅ On Target |
| Tests Passing | 107/107 | 100+ | ✅ Healthy |
| Performance (20yr) | 184.72s | <150s | 🟡 Optimization ongoing |

### Teams
- **Team 1**: Data Models (✅ Complete)
- **Team 2**: Roster/Depth (✅ Complete - PR #107)
- **Team 3**: Game Simulation (✅ Complete - already existed)
- **Team 4**: Offseason (🟡 In Progress - O4, O5 remaining)
- **Team 5**: Historical (✅ Complete - PR #108)

---

## Common Questions

### Q: Which document should I read first?
**A**: Start with **CURRENT_WORK_STATUS.md** to see what's happening now, then **PHASE_1_ROADMAP.md** for context.

### Q: Where are the old planning docs?
**A**: Archived in `docs/planning/archive/` with `.bak` extension. These were consolidated into the new structure.

### Q: How do I know what to work on?
**A**: Check **CURRENT_WORK_STATUS.md** → Current Assignments section.

### Q: Where's the detailed task breakdown?
**A**: **PHASE_1_ROADMAP.md** has the feature list. For implementation details, see `docs/tasks/TASK_*.md` files.

### Q: What about track-specific work (tests, performance)?
**A**:
- Tests → **TEST_IMPROVEMENT_PLAN.md**
- Performance → **PHASE_F_ROADMAP.md**
- These run in parallel with Phase 1 feature work.

### Q: How do I update these docs?
**A**:
- **CURRENT_WORK_STATUS.md**: Update daily/weekly with sprint progress
- **PHASE_1_ROADMAP.md**: Update when features complete (mark ✅)
- **QUICK_REFERENCE.md**: Update when structure changes
- **PHASE_2_FEATURES.md**: Update when planning new features

---

## Key Workflows

### Starting Work on a Feature
1. Read **CURRENT_WORK_STATUS.md** to confirm assignment
2. Read **PHASE_1_ROADMAP.md** for feature context
3. Check `docs/tasks/TASK_[FEATURE].md` for implementation details
4. Update **CURRENT_WORK_STATUS.md** when starting (mark 🟡)

### Completing a Feature
1. Update **PHASE_1_ROADMAP.md** (mark ✅)
2. Update **CURRENT_WORK_STATUS.md** (move to "Completed This Sprint")
3. Update metrics (tests passing, performance, etc.)
4. Document any decisions or tradeoffs

### Planning Next Phase
1. Review **PHASE_2_FEATURES.md** for upcoming work
2. Identify dependencies and prerequisites
3. Estimate effort and prioritize
4. Create detailed task files in `docs/tasks/`

---

## Command Reference

### Testing
```bash
# Fast feedback (< 10 seconds)
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Full test suite (~2 minutes)
godot --headless -s res://scripts/tests/TestRunner.gd

# Single test for debugging
godot --headless -s res://scripts/tests/TestRunnerSingle.gd test_name.gd
```

### Bootstrapping
```bash
# Full 20-year bootstrap (3-4 minutes)
godot --headless res://scenes/bootstrap_preview.tscn

# Quick 5-year bootstrap (< 1 minute)
godot --headless res://scenes/bootstrap_preview.tscn -- --years 5
```

### Performance
```bash
# Run benchmarks (10+ minutes)
timeout 900 godot --headless benchmark_runner.tscn
```

---

## Document Ownership

| Document | Owner | Update Frequency |
|----------|-------|------------------|
| QUICK_REFERENCE.md | Director | As structure changes |
| PHASE_1_ROADMAP.md | Team Leads | Weekly |
| CURRENT_WORK_STATUS.md | Active Engineers | Daily |
| PHASE_2_FEATURES.md | Architects | As planning evolves |
| TEST_IMPROVEMENT_PLAN.md | QA Team | As needed |
| PHASE_F_ROADMAP.md | Performance Team | As needed |

---

## Getting Help

### I'm blocked on my task
1. Check **CURRENT_WORK_STATUS.md** → Blockers section
2. Check **PHASE_1_ROADMAP.md** → Dependencies
3. Reach out to blocking team lead
4. Document blocker in **CURRENT_WORK_STATUS.md**

### I don't understand the architecture
1. Read `docs/architectural_notes/` for system design
2. Read `docs/analysis/` for feature context
3. Check **PHASE_1_ROADMAP.md** → Related Documents

### I need to change scope
1. Document proposed change
2. Discuss with Director/Architect
3. Update **CURRENT_WORK_STATUS.md** → Decision Log
4. Update **PHASE_1_ROADMAP.md** if features change

---

## Tips for Success

### For Engineers
- Update **CURRENT_WORK_STATUS.md** daily (stand-up pattern)
- Mark features complete in **PHASE_1_ROADMAP.md** when done
- Run tests after every change
- Document decisions and tradeoffs

### For Architects
- Keep **PHASE_2_FEATURES.md** updated with strategic thinking
- Review **CURRENT_WORK_STATUS.md** weekly for blockers
- Ensure **PHASE_1_ROADMAP.md** reflects reality

### For Directors
- Review **CURRENT_WORK_STATUS.md** for sprint health
- Check **PHASE_1_ROADMAP.md** progress weekly
- Plan Phase 2 using **PHASE_2_FEATURES.md**
- Keep **QUICK_REFERENCE.md** navigation clear

---

## What's New in This Structure?

**Consolidated From** (now in `archive/`):
- MASTER_IMPLEMENTATION_PLAN.md → **PHASE_1_ROADMAP.md**
- QUICK_WINS_LIST.md → **PHASE_1_ROADMAP.md**
- FEATURE_EXPANSION_PLAN.md → **PHASE_1_ROADMAP.md**
- ACTIVE_TASKS.md → **CURRENT_WORK_STATUS.md**
- FUTURE_FEATURES_ANALYSIS.md → **PHASE_2_FEATURES.md** (renamed)

**New Documents**:
- **QUICK_REFERENCE.md** (this file) - Navigation guide
- **README.md** - Master index explaining structure

**Kept Separate** (track-specific):
- TEST_IMPROVEMENT_PLAN.md (test quality focus)
- PHASE_F_ROADMAP.md (performance focus)

---

**Last Updated**: 2026-01-12
**Next Review**: When Phase 1 completes or structure changes
