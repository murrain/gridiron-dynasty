# Testing Infrastructure Tasks

## Overview

Testing infrastructure tasks focus on improving test suite performance and developer experience. Current test suite runs in ~2 minutes, which is acceptable but could be improved for faster iteration.

## World State Snapshots (IMPLEMENTED)

The snapshot system provides instant loading of pre-generated world state data for testing features that require mature simulation data (contracts, trades, career progression).

### Quick Start

```gdscript
const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

# Load 10-year snapshot (no additional simulation)
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x7E57001)

# Load 5-year snapshot + simulate 2 more years
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 2, 0x72ADE01)

# Generate fresh 3-year world (no snapshot)
var world_state := SnapshotLoader.setup_world(SnapshotLoader.FRESH, 3, 0xF2E5401)
```

### Available Snapshots

| Constant | Years | Use Cases | Time Saved |
|----------|-------|-----------|------------|
| `FRESH` | 0 | Generate from scratch | None |
| `YEAR_5` | 5 | Basic rosters, recruiting data | ~60-90s |
| `YEAR_10` | 10 | Trade tests, contract history | ~120-180s |
| `YEAR_20` | 20 | Hall of Fame, dynasty detection | ~240-360s |

### Unified API: setup_world()

All world state setup uses a single function:

```gdscript
static func setup_world(base: int, years: int, seed: int) -> Dictionary
```

**Parameters:**
- `base`: Which snapshot to start from (FRESH, YEAR_5, YEAR_10, YEAR_20)
- `years`: Additional years to simulate (0 = just load snapshot)
- `seed`: Required seed for deterministic simulation (cannot be 0)

**Returns:**
- A world state dictionary (always an isolated copy, safe to mutate)

**Examples:**
```gdscript
# Generate fresh 3-year world
var world_state := SnapshotLoader.setup_world(SnapshotLoader.FRESH, 3, 0x5EED001)

# Load 10yr snapshot, no additional simulation
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x5EED001)

# Load 5yr snapshot + 2 more years
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 2, 0x72ADE01)
```

### Always Safe to Mutate

`setup_world()` always returns an isolated deep copy. You can safely mutate the returned world state without affecting the cache or other tests.

```gdscript
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x7E57001)
world_state["nfl_teams"].append(new_team)  # Safe - isolated copy
```

### Config-Driven Snapshots

Snapshots are defined in `snapshot_config.json`, making it easy to add new snapshot years:

```json
{
  "schema_version": 1,
  "deterministic_seed": 2120392742,
  "snapshots": {
    "5": {
      "filename": "snapshot_5yr.json",
      "description": "Basic rosters, recruiting data"
    },
    "10": {
      "filename": "snapshot_10yr.json",
      "description": "Trade tests, contract history"
    },
    "20": {
      "filename": "snapshot_20yr.json",
      "description": "Hall of Fame, dynasty, long-term trends"
    }
  }
}
```

**To add a new snapshot (e.g., 30 years):**
1. Add entry to `snapshot_config.json`:
   ```json
   "30": {
     "filename": "snapshot_30yr.json",
     "description": "Very long-term trends"
   }
   ```
2. Add constant to SnapshotLoader.gd: `const YEAR_30 := 30`
3. Run `godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd`

### Regenerating Snapshots

When to regenerate:
- Config schema changes
- Player model changes
- World state schema changes
- Simulation logic changes materially

To regenerate:
```bash
godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
```

### Schema Versioning

Snapshots include schema versioning for evolution tracking. If schema mismatch detected:

1. SnapshotLoader will log an error with regeneration instructions
2. Tests using snapshots will fail with empty world_state
3. Regenerate snapshots using the command above

Current schema version: 1 (see `SNAPSHOT_SCHEMA_VERSION` in SnapshotGenerator.gd)

### Test Isolation

TestRunner automatically clears the snapshot cache between test files to ensure isolation. For manual cache clearing:

```gdscript
SnapshotLoader.clear_cache()
```

### Files

- Config: `scripts/tests/fixtures/world_state/snapshot_config.json`
- Generator: `scripts/tests/fixtures/world_state/SnapshotGenerator.gd`
- Loader: `scripts/tests/fixtures/world_state/SnapshotLoader.gd`
- Tests: `scripts/tests/test_snapshot_loader.gd`
- Data: `scripts/tests/fixtures/world_state/snapshot_*.json`

---

## Active Tasks

### TEST_FIXTURES: Test Fixtures Implementation (PARTIALLY COMPLETE)
**Status**: World State Snapshots Implemented
**Priority**: Medium
**Remaining Effort**: 1-2 days (player/team fixtures)
**Expected Impact**: Additional 30-40% reduction in test suite time

#### Completed
- World state snapshots (5yr, 10yr, 20yr)
- SnapshotLoader with config-driven snapshot definitions
- Unified setup_world() API
- Schema versioning for snapshot evolution
- Comprehensive test suite for snapshot loader

#### Remaining (Optional)
Player and team fixtures for tests that need specific entity data without full world state:

```
scripts/tests/fixtures/
  players/
    hs_class_100.json         # 100 HS players (seed: 42)
    draft_class_200.json      # 200 draft-ready players (seed: 43)
  teams/
    colleges_10.json          # 10 colleges (seed: 45)
    nfl_teams_4.json          # 4 NFL teams (seed: 47)
```

These are optional since world state snapshots cover most use cases.

### TEST_PARALLEL: Parallel Test Execution (BLOCKED)
**Status**: Blocked by TEST_FIXTURES
**Priority**: Low
**Effort**: 5-7 days
**Expected Impact**: Additional 40-50% time reduction (30-45s -> 15-30s)

#### Problem
Tests run sequentially on a single core, wasting available CPU resources.

#### Prerequisites
Tests must be:
1. **Stateless**: No shared global state
2. **Config-isolated**: Each test creates own ConfigService
3. **RNG-isolated**: Each test uses own RNG instance
4. **File-isolated**: No shared file writes

**Current status**: Most tests already follow these patterns

#### Proposed Solution
Use Godot's ThreadPool to run tests in parallel.

#### Implementation Plan

**Step 1: Categorize Tests**
```gdscript
# Fast tests (< 1 second) - Run sequentially
const FAST_TESTS := [
    "res://scripts/tests/test_rand.gd",
    "res://scripts/tests/test_config.gd",
]

# Medium tests (1-10 seconds) - Run in parallel
const MEDIUM_TESTS := [
    "res://scripts/tests/test_lifecycle.gd",
    "res://scripts/tests/test_recruiting.gd",
]

# Slow tests (> 10 seconds) - Run in parallel with high priority
const SLOW_TESTS := [
    "res://scripts/tests/test_world_gen.gd",
    "res://scripts/tests/test_bootstrap.gd",
]
```

**Step 2: Create Parallel Test Runner**
```gdscript
func run_tests_parallel():
    # Run fast tests sequentially first
    for test_path in FAST_TESTS:
        run_single_test(test_path)

    # Run medium + slow tests in parallel
    var pool := ThreadPool.new(OS.get_processor_count())
    var results := pool.map(MEDIUM_TESTS + SLOW_TESTS, _run_test_worker)

    # Aggregate results
    for result in results:
        process_test_result(result)
```

**Step 3: Test Isolation Verification**
Create a test that verifies all tests are properly isolated:
```gdscript
func test_parallel_isolation():
    # Run all tests twice in parallel
    # Verify same results both times
    # Ensures no shared state contamination
```

#### Benefits
1. **Faster CI**: Parallel execution on multi-core CI runners
2. **Better CPU utilization**: Use all available cores
3. **Scalable**: More tests != proportionally longer runtime

#### Trade-offs
**Pros**:
- 40-50% additional time reduction
- Better resource utilization
- Scales with CPU cores

**Cons**:
- More complex test infrastructure
- Harder to debug test failures
- Requires proper test isolation
- Output interleaving can be confusing

#### Dependencies
Should complete TEST_FIXTURES first because:
1. Fixture loading is fast and parallel-safe
2. Reduces test generation contention
3. Makes parallel isolation easier to verify
4. Provides baseline for measuring parallel improvement

## Current Test Suite Status

### Test Categories
1. **Unit tests** (fast, < 1s each)
   - Config loading
   - Helper functions
   - Random number generation
   - Value calculations

2. **Integration tests** (medium, 1-10s each)
   - Player lifecycle
   - Scout runtime
   - Recruiting pipeline
   - Draft logic

3. **System tests** (slow, > 10s each)
   - Multi-year world generation
   - Full bootstrap simulation
   - End-to-end pipelines

### Current Performance
- **Total runtime**: ~120-140 seconds
- **Bottlenecks**: World generation tests (60-90s), player generation (10-15s)
- **Test count**: ~20-25 test files

### Expected Performance with Optimizations
| Optimization | Runtime | Improvement |
|--------------|---------|-------------|
| Current | 120-140s | Baseline |
| + Fixtures | 30-45s | 65-75% faster |
| + Parallel | 15-30s | 85-90% faster |

## Priority Recommendation

### Start with TEST_FIXTURES
1. Easier to implement
2. Larger immediate impact
3. Prerequisite for TEST_PARALLEL
4. Improves developer experience today

### Then consider TEST_PARALLEL
1. Only if test suite is still a bottleneck
2. Only if tests are properly isolated
3. Provides diminishing returns

## Related Documentation

- Test infrastructure: `scripts/tests/TestRunner.gd`
- Fast test runner: `scripts/tests/TestRunnerFast.gd`
- Performance patterns: `docs/tasks/performance/README.md`
- Parallel processing: See F5 in archive for ThreadPool patterns
