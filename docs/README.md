# Gridiron Dynasty Documentation

Welcome to the Gridiron Dynasty documentation.

## Folder Structure

### `/architecture/` - Architecture & Implementation Plans
- **[IMPLEMENTATION_TICKETS.md](architecture/IMPLEMENTATION_TICKETS.md)** - Comprehensive architectural improvement tickets organized by phase

### `/contributing/` - Contribution Standards
- `COMMIT_STYLE.md` - Commit message conventions
- `PR_STYLE.md` - Pull request standards
- `TESTING.md` - Test documentation requirements

### `/guides/` - User Guides
- `QUICK_REFERENCE.md` - Quick lookup for common operations
- `WORLD_EXPLORER_QUICK_START.md` - Getting started with the World Explorer UI

### `/metrics/` - Performance Data
- `BENCHMARKS.md` - Bootstrap performance metrics and benchmarks

### Top-Level Documents
- **[AGENT_GUIDELINES.md](AGENT_GUIDELINES.md)** - Developer guidelines and coding standards

## Current Development Focus

See **[IMPLEMENTATION_TICKETS.md](architecture/IMPLEMENTATION_TICKETS.md)** for the comprehensive implementation plan covering:
- **Phase 1**: Foundation (model renames, base classes, type safety)
- **Phase 2**: Model Decomposition (component extraction)
- **Phase 3**: Database Persistence (SQLite migration)
- **Phase 4**: Testing Infrastructure (GdUnit4 migration)

## Core Principles

1. **Determinism First** - All simulation must be reproducible with same seed
2. **No Premature Abstraction** - Solve the immediate problem simply
3. **World Model Integrity** - The world state is single source of truth
4. **Performance Matters** - Target <90s for 20-year world bootstrap
5. **Test Everything** - Comprehensive test coverage for all systems

## Quick Commands

```bash
# Run full test suite
godot --headless --path . --script scripts/tests/TestRunner.gd

# Run fast tests
godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Run 5-year bootstrap
godot --headless res://scenes/bootstrap_preview.tscn -- --years 5
```

---

Last updated: 2026-01-14
