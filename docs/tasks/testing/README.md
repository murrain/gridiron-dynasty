# Testing Infrastructure Tasks

## Overview

Testing infrastructure tasks focus on improving test suite performance and developer experience. Current test suite runs in ~2 minutes, which is acceptable but could be improved for faster iteration.

## Active Tasks

### TEST_FIXTURES: Test Fixtures Implementation (READY)
**Status**: 🟢 Ready to start
**Priority**: Medium
**Effort**: 3-4 days
**Expected Impact**: Reduce test suite time from ~2 minutes to 30-45 seconds

#### Problem
Tests repeatedly generate expensive test data:
- Player generation: ~2000 players per class (~10+ seconds)
- Multi-year simulations: 2-3 years of world advancement (~60-90 seconds)
- College/team generation: Regenerated for each test

This creates a slow feedback loop where developers wait 2+ minutes per test run.

#### Proposed Solution
Implement a fixture system that pre-generates expensive test data once and loads it from JSON files.

#### Implementation Plan

**Step 1: Create Fixture Directory Structure**
```
scripts/tests/fixtures/
  players/
    hs_class_100.json         # 100 HS players (seed: 42)
    draft_class_200.json      # 200 draft-ready players (seed: 43)
    college_recruits_50.json  # 50 recruits with ratings (seed: 44)
  teams/
    colleges_10.json          # 10 colleges (seed: 45)
    hs_schools_20.json        # 20 high schools (seed: 46)
    nfl_teams_4.json          # 4 NFL teams (seed: 47)
  world_states/
    year_1_populated.json     # World after 1 year (seed: 100)
    year_3_populated.json     # World after 3 years (seed: 100)
```

**Step 2: Create FixtureLoader Helper**

```gdscript
# scripts/tests/FixtureLoader.gd
class_name FixtureLoader

const FIXTURE_DIR := "res://scripts/tests/fixtures/"

static func load_players(fixture_name: String) -> Array:
    var path := FIXTURE_DIR + "players/" + fixture_name + ".json"
    return _load_json(path)

static func load_teams(fixture_name: String) -> Array:
    var path := FIXTURE_DIR + "teams/" + fixture_name + ".json"
    return _load_json(path)

static func load_world_state(fixture_name: String) -> Dictionary:
    var path := FIXTURE_DIR + "world_states/" + fixture_name + ".json"
    return _load_json(path)
```

**Step 3: Create Fixture Generator**

```gdscript
# scripts/tests/generate_fixtures.gd
# Run once to create fixtures, commit to repo

extends SceneTree

func _init():
    generate_player_fixtures()
    generate_team_fixtures()
    generate_world_state_fixtures()
    quit()
```

**Step 4: Update Existing Tests**

Before:
```gdscript
func test_player_lifecycle():
    var players := DraftClassGenerator.generate(100, 2020, rng, cfg)
    # ... rest of test
```

After:
```gdscript
func test_player_lifecycle():
    var players := FixtureLoader.load_players("hs_class_100")
    # ... rest of test (much faster!)
```

#### Benefits
1. **Faster test runs**: 60-75% reduction in test suite time
2. **Deterministic data**: Same fixtures across runs
3. **Better debugging**: Can inspect fixture files directly
4. **Parallel-friendly**: No generation contention

#### Trade-offs
**Pros**:
- Significant time savings
- Better developer experience
- Easier to debug (inspect JSON files)
- Enables parallel test execution (TEST_PARALLEL)

**Cons**:
- Adds fixture files to repo (~5-10 MB)
- Fixtures can become stale if generation changes
- Need to regenerate fixtures when code changes
- Fixture generation script needs maintenance

#### Testing Strategy
1. Generate fixtures with known seeds
2. Verify fixtures load correctly
3. Run existing tests with fixtures, verify same results
4. Benchmark test suite before/after

### TEST_PARALLEL: Parallel Test Execution (BLOCKED)
**Status**: 🟡 Blocked by TEST_FIXTURES
**Priority**: Low
**Effort**: 5-7 days
**Expected Impact**: Additional 40-50% time reduction (30-45s → 15-30s)

#### Problem
Tests run sequentially on a single core, wasting available CPU resources.

#### Prerequisites
Tests must be:
1. **Stateless**: No shared global state
2. **Config-isolated**: Each test creates own ConfigService
3. **RNG-isolated**: Each test uses own RNG instance
4. **File-isolated**: No shared file writes

**Current status**: ✅ Most tests already follow these patterns

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
3. **Scalable**: More tests ≠ proportionally longer runtime

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
