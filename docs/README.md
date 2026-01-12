# Gridiron Dynasty Documentation

Welcome to the Gridiron Dynasty documentation! This folder contains all documentation about the game systems, architecture decisions, and implementation details.

## Folder Structure

### 📐 `/architecture/` - System Design & Specifications
Technical architecture and design documents for major game systems.

- **`contracts/`** - Player contracts, salary cap, team finances
- **`game_simulation/`** - Game outcome simulation, win probabilities, season scheduling
- **`player_growth/`** - Player development, aging, skill progression
- **`recruiting/`** - College recruiting, scouting systems, evaluation
- **`trades/`** - Trade logic, value calculations, AI decision-making

Additional architecture docs for coaching, free agency, and other systems are also here.

### 📚 `/guides/` - How-To & Reference Documentation
User-friendly guides explaining how game systems work.

- `QUICK_REFERENCE.md` - Quick lookup for common operations
- `WORLD_EXPLORER_QUICK_START.md` - Getting started with the World Explorer UI

### 🗺️ `/planning/` - Implementation Plans
Master plans and roadmaps for feature development.

- `MASTER_IMPLEMENTATION_PLAN.md` - Current Phase 1 implementation plan (6 tracks)
- `ARCHITECTURAL_GUARDIAN_ASSESSMENT.md` - Architecture review and assessment
- `QUICK_WINS_LIST.md` - High-impact features prioritized for implementation

### ✅ `/implementation/` - Completion Summaries
Track-by-track summaries of completed implementation work.

- `TRACK_1_COMPLETION_SUMMARY.md` - Game Simulation Foundation (G1.1, G1.2, G1.5, G1.8)
- `TRACK_2_COMPLETION_SUMMARY.md` - Team History Tracking (H4.1-H4.6)
- Performance analysis and optimization reports

### 🔧 `/tasks/` - Detailed Engineering Tasks
Individual task specifications for engineers to implement.

- **`completed/`** - Finished tasks and implementation reports
- **`performance/`** - Performance optimization tasks
- **`testing/`** - Test improvement and coverage tasks
- **`valuation/`** - Player/contract valuation system tasks
- **`archive/`** - Historical tasks for reference

## Getting Started

### For New Contributors
1. **Start with `/guides/`** to understand how the game systems work
   - Read system documentation to understand player lifecycle, development, etc.
2. **Review `/architecture/`** for the system you'll be working on
   - Understand design decisions and technical specifications
3. **Check `/planning/MASTER_IMPLEMENTATION_PLAN.md`** for current priorities
   - See which tracks are in progress and what's available
4. **Look in `/tasks/`** for specific tasks to implement
   - Find detailed engineering tasks with acceptance criteria

### For Architecture Planning
1. Review existing `/architecture/` docs for related systems
2. Check `/planning/` for strategic direction and priorities
3. Create new architecture docs in appropriate `/architecture/` subfolders
4. Update the master plan when adding new features

### For Implementation Work
1. Find your task in `/tasks/` (or get assigned by lead)
2. Review related `/architecture/` docs for design decisions
3. Implement the feature following `AGENT_GUIDELINES.md`
4. Create completion summary in `/implementation/` when done

## Current Development Status

**Phase 1 Implementation (Q1 2026)** - 18 "Quick Win" Features across 6 tracks

- ✅ **Track 1**: Game Simulation Foundation (Agent 1) - COMPLETE
- ✅ **Track 2**: Team History Tracking (Agent 2) - COMPLETE
- ✅ **Track 3**: Draft History (Agent 3) - COMPLETE
- ✅ **Track 4**: Player Career Statistics (Agent 4) - COMPLETE
- ✅ **Track 5**: NFL Awards (Agent 5) - COMPLETE
- 🔄 **Track 6**: Player Agency & Morale (Agent 6) - IN PROGRESS

See `/planning/MASTER_IMPLEMENTATION_PLAN.md` for full details.

## Documentation Standards

- **Architecture docs** should explain the "why" behind design decisions
- **Guides** should be accessible to non-technical readers
- **Task specs** should have clear acceptance criteria and examples
- **Completion summaries** should document what was built and any deviations from plan

## Core Principles

This codebase follows strict architectural principles:

1. **Determinism First** - All simulation must be reproducible with same seed
2. **No Premature Abstraction** - Solve the immediate problem simply
3. **World Model Integrity** - The world state is single source of truth
4. **Performance Matters** - Target <90s for 20-year world bootstrap
5. **Test Everything** - Comprehensive test coverage for all systems

See `AGENT_GUIDELINES.md` for detailed coding guidelines.

## Quick Commands

```bash
# View current implementation plan
cat docs/planning/MASTER_IMPLEMENTATION_PLAN.md

# View completed work
ls docs/implementation/

# List available tasks
ls docs/tasks/

# Run full test suite
godot --headless --path . --script scripts/tests/TestRunner.gd

# Run specific test
godot --headless --path . --script scripts/tests/test_g1_1_game_simulation_determinism.gd
```

## Contributing

### When Adding New Features
1. **Architect creates task file** with complete specification in `/tasks/`
2. **Add to planning docs** with dependencies and priority
3. **Engineer picks task** and implements
4. **Upon completion**: Create summary in `/implementation/`, archive task

### When Updating Documentation
- **System designs** → `/architecture/` subfolders
- **How-to guides** → `/guides/`
- **Completed work** → `/implementation/`
- **Active plans** → `/planning/`
- **Finished tasks** → `/tasks/completed/`

This ensures documentation stays organized and valuable.

---

Last updated: January 11, 2026
