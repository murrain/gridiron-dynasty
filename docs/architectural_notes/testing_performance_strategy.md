# Testing Performance Strategy

**Status**: Proposal
**Created**: 2026-01-10
**Priority**: High (impacts developer velocity)

## Current Problem

**Test suite execution time**: 2 minutes 21 seconds (141 seconds)
**Test count**: 43 tests (39 passing, 4 pre-existing failures)
**Bottleneck**: Sequential execution of expensive multi-year simulations

### Impact

- **Slow feedback loop**: Developers wait 2+ minutes per test run
- **CI/CD delays**: Merge checks take longer
- **Test reluctance**: Developers may skip running full suite
- **Iteration speed**: Slows down TDD/refactoring workflows

---

## Root Causes

### 1. Expensive Player Generation
Tests that generate thousands of players:
- `test_player_generator.gd` - Generates full class (~2000 players)
- `test_draft_class_generator.gd` - Generates + de-ages classes
- `test_bootstrap_game_world.gd` - Runs 2-3 years of full simulation
- `test_world_history_preview.gd` - Runs 2 years of world advancement

**Estimated cost**: 60-90 seconds per multi-year simulation test

### 2. Sequential Test Execution
Current `TestRunner.gd` runs tests one at a time:
```gdscript
for path in TEST_SCRIPTS:
    var script = load(path)
    var test_instance = script.new()
    test_instance.run(helper)  # Blocks until complete
```

**Opportunity**: Modern CPUs have 8-16 cores, but we use only 1

### 3. Repeated Expensive Setup
Many tests regenerate the same data:
- College recruiting tests regenerate recruits every time
- NFL draft tests regenerate draft pools
- No caching or fixture reuse between tests

---

## Proposed Solutions

### Solution 1: Test Fixtures (Immediate Win)

**Impact**: Reduce generation tests from ~60s to <5s
**Complexity**: Low
**Risk**: Low

#### Implementation

1. **Create fixture directory structure**
```
scripts/tests/fixtures/
  players/
    hs_class_100.json         # 100 HS players
    draft_class_200.json      # 200 draft-ready players
    college_recruits_50.json  # 50 recruits with ratings
  teams/
    colleges_10.json          # 10 colleges with configs
    nfl_teams_4.json          # 4 NFL teams (for test speed)
  world_states/
    year_1_populated.json     # World after 1 year
    year_3_populated.json     # World after 3 years
```

2. **Create FixtureLoader helper**
```gdscript
# scripts/tests/FixtureLoader.gd
class_name FixtureLoader

const FIXTURE_DIR := "res://scripts/tests/fixtures/"

static func load_players(name: String) -> Array:
    var path := FIXTURE_DIR + "players/" + name + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Fixture not found: %s" % path)
        return []
    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    if parse_result != OK:
        push_error("Invalid JSON in fixture: %s" % path)
        return []
    return json.get_data()

static func load_world_state(name: String) -> Dictionary:
    var path := FIXTURE_DIR + "world_states/" + name + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    if parse_result != OK:
        return {}
    return json.get_data()
```

3. **Generate fixtures once (tooling script)**
```gdscript
# scripts/tools/GenerateTestFixtures.gd
extends Node

func _ready() -> void:
    _generate_player_fixtures()
    _generate_world_state_fixtures()
    print("✅ Test fixtures generated")
    get_tree().quit()

func _generate_player_fixtures() -> void:
    var gen := PlayerGenerator.new()
    # Generate and save to fixture files
```

4. **Update tests to use fixtures**
```gdscript
# Before (slow):
func _test_college_recruiting(t):
    var generator := PlayerGenerator.new()
    var recruits := generator.generate_class(500, 0.7, rng)  # 10+ seconds
    # ... test logic

# After (fast):
func _test_college_recruiting(t):
    var recruits := FixtureLoader.load_players("college_recruits_50")  # <0.1 seconds
    # ... test logic
```

#### Fixture Generation Strategy

- **One-time generation**: Run fixture generator manually when models change
- **Version control**: Commit fixtures to git (small JSON files)
- **Deterministic fixtures**: Always use same seed (42) for consistency
- **Minimal size**: Only generate what tests need (50-200 entities, not 2000)

**When to regenerate fixtures**:
- When Player model schema changes
- When generation logic changes significantly
- When adding new test scenarios

---

### Solution 2: Parallel Test Execution (Moderate Win)

**Impact**: 2-3x speedup on multi-core CPUs
**Complexity**: Medium
**Risk**: Medium (requires careful isolation)

#### Implementation

1. **Test Categories**
```gdscript
# Fast tests (< 1 second each)
const FAST_TESTS := [
    "test_rand.gd",
    "test_config.gd",
    "test_helpers.gd",
    "test_deager.gd",
    # ... unit tests
]

# Slow tests (> 5 seconds each)
const SLOW_TESTS := [
    "test_player_generator.gd",
    "test_bootstrap_game_world.gd",
    "test_world_history_preview.gd",
    # ... integration tests
]
```

2. **Parallel Test Runner**
```gdscript
# scripts/tests/TestRunnerParallel.gd
extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const ThreadPool = preload("res://autoloads/ThreadPool.gd")

func _init() -> void:
    var fast_results := _run_tests_sequential(FAST_TESTS)  # Run fast tests first
    var slow_results := _run_tests_parallel(SLOW_TESTS)    # Run slow tests in parallel

    var all_results := fast_results + slow_results
    _report_results(all_results)

func _run_tests_parallel(test_paths: Array) -> Array:
    var max_threads := min(4, OS.get_processor_count())  # Cap at 4 to avoid resource contention
    var thread_pool := ThreadPool.map_parallel(
        test_paths,
        func(path): return _run_single_test(path),
        max_threads
    )
    return thread_pool

func _run_single_test(path: String) -> Dictionary:
    var script = load(path)
    var test_instance = script.new()
    var helper = TestHelpers.new()
    test_instance.run(helper)
    return {
        "path": path,
        "failures": helper.failures
    }
```

3. **Test Isolation Requirements**

For parallel execution, tests must be:
- **Stateless**: No shared global state between tests
- **Config-isolated**: Each test creates its own ConfigService
- **RNG-isolated**: Each test uses its own RNG instance
- **File-isolated**: No shared file writes

**Current status**: ✅ Most tests already follow these patterns

#### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Race conditions on config loading | ConfigService instances are already per-test |
| Global RNG contamination | Use explicit RNG instances (already done) |
| File system conflicts | Tests don't write files currently |
| Memory pressure | Limit concurrent threads to 4 |

---

### Solution 3: Test Categorization + Selective Execution (Quick Win)

**Impact**: Developers run fast tests only, CI runs all
**Complexity**: Low
**Risk**: None

#### Implementation

1. **Create TestRunnerFast.gd**
```gdscript
extends SceneTree

const TEST_SCRIPTS := [
    "res://scripts/tests/test_rand.gd",
    "res://scripts/tests/test_config.gd",
    "res://scripts/tests/test_helpers.gd",
    "res://scripts/tests/test_deager.gd",
    "res://scripts/tests/test_stathelpers.gd",
    "res://scripts/tests/test_combine_calculator.gd",
    # ... unit tests only (~15 tests, < 10 seconds)
]
```

2. **Update tests.md with commands**
```bash
# Fast tests only (< 10 seconds)
Godot --headless -s res://scripts/tests/TestRunnerFast.gd

# Full suite (~2 minutes)
Godot --headless -s res://scripts/tests/TestRunner.gd

# Single test (for debugging)
Godot --headless -s res://scripts/tests/TestRunnerSingle.gd test_player_generator.gd
```

3. **CI Configuration**
```yaml
# .github/workflows/test.yml
jobs:
  fast-tests:
    runs-on: ubuntu-latest
    steps:
      - run: Godot --headless -s res://scripts/tests/TestRunnerFast.gd
    # Runs on every push (~10 seconds)

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - run: Godot --headless -s res://scripts/tests/TestRunner.gd
    # Runs on PR merge / nightly (~2 minutes)
```

---

## Recommended Implementation Order

### Phase 1: Quick Wins (1-2 days)
1. ✅ **Create TestRunnerFast.gd** - Immediate developer relief
2. ✅ **Document test categories** in tests.md
3. ✅ **Update CI** to run fast tests on push, full suite on merge

**Expected improvement**: Developers get 10-second feedback loop

### Phase 2: Fixtures (3-4 days)
1. Create fixture directory structure
2. Implement FixtureLoader.gd
3. Create GenerateTestFixtures.gd tool
4. Generate initial fixture set
5. Refactor top 5 slowest tests to use fixtures

**Expected improvement**: Test suite drops to ~30-45 seconds

### Phase 3: Parallelization (5-7 days)
1. Implement TestRunnerParallel.gd
2. Verify test isolation (audit for global state)
3. Add thread safety assertions
4. Profile and tune thread count

**Expected improvement**: Test suite drops to ~15-30 seconds on 4+ core CPUs

---

## Performance Targets

| Milestone | Current | Target | Improvement |
|-----------|---------|--------|-------------|
| Phase 1 (Fast tests only) | 141s | 10s | 14x faster |
| Phase 2 (Fixtures) | 141s | 30-45s | 3-5x faster |
| Phase 3 (Parallel) | 141s | 15-30s | 5-9x faster |
| **Final State** | **141s** | **10s (dev) / 30s (CI)** | **14x / 5x** |

---

## Example: Refactoring a Slow Test with Fixtures

### Before (slow)
```gdscript
# test_college_recruiting.gd
func _test_recruiting_flow(t):
    # Generate 500 recruits (10+ seconds)
    var generator := PlayerGenerator.new()
    var recruits := generator.generate_class(500, 0.7, rng)

    # Generate 20 colleges (2+ seconds)
    var college_gen := CollegeGenerator.new()
    var colleges := college_gen.generate(seed, "world/colleges")

    # Run recruiting (1 second)
    var recruiting := CollegeRecruiting.new()
    var result := recruiting.run(recruits, colleges, config, ...)

    # Assert results
    t.assert_true(result.commitments.size() > 0)
```

### After (fast)
```gdscript
# test_college_recruiting.gd
func _test_recruiting_flow(t):
    # Load pre-generated fixtures (<0.1 seconds)
    var recruits := FixtureLoader.load_players("college_recruits_50")
    var colleges := FixtureLoader.load_teams("colleges_10")

    # Run recruiting (1 second)
    var recruiting := CollegeRecruiting.new()
    var result := recruiting.run(recruits, colleges, config, ...)

    # Assert results
    t.assert_true(result.commitments.size() > 0)
```

**Speedup**: 13+ seconds → 1 second (13x faster)

---

## Alternative: Incremental Fixtures

For tests that verify generation logic itself, use smaller inputs:

```gdscript
# test_player_generator.gd
func _test_generate_class_determinism(t):
    var gen := PlayerGenerator.new()

    # Before: generate 2000 players
    # After: generate 50 players (40x faster, same determinism check)
    var class1 := gen.generate_class(50, 0.7, rng1)
    var class2 := gen.generate_class(50, 0.7, rng2)

    # Same assertions work
    t.assert_eq(class1.size(), class2.size())
    t.assert_eq(class1[0].player_id, class2[0].player_id)
```

**Philosophy**: Tests verify correctness, not production scale

---

## Fixture Maintenance Strategy

### When to Regenerate Fixtures

✅ **Do regenerate when**:
- Player/Team model schema changes (add/remove fields)
- Generation algorithms change significantly
- New test scenarios require different fixture data

❌ **Don't regenerate for**:
- Cosmetic code changes
- Bug fixes that don't affect data structure
- Config tuning (eliteness values, weights, etc.)

### Fixture Versioning

```
scripts/tests/fixtures/
  v1/  # Original schema
  v2/  # After Phase 3.6 contract changes
  v3/  # After Phase 4 roster changes
```

Tests specify which version:
```gdscript
var players := FixtureLoader.load_players("college_recruits_50", version: 2)
```

### Fixture Documentation

Each fixture should have a comment header:
```json
{
  "_fixture_meta": {
    "generated_date": "2026-01-10",
    "generator_version": "Phase 3.6",
    "seed": 42,
    "description": "50 college recruits with varied ratings for recruiting tests",
    "schema_version": 2
  },
  "players": [...]
}
```

---

## Migration Path for Existing Tests

### High Priority (slowest tests)
1. `test_bootstrap_game_world.gd` - Use pre-generated 3-year world state
2. `test_world_history_preview.gd` - Use fixture world state
3. `test_player_generator.gd` - Reduce class size from 2000 → 50
4. `test_draft_class_generator.gd` - Use fixture classes

### Medium Priority
5. `test_college_recruiting.gd` - Use fixture recruits + colleges
6. `test_nfl_draft.gd` - Use fixture draft pool + teams
7. `test_high_school_season.gd` - Use fixture HS players

### Low Priority (already fast)
- Unit tests (< 0.5s each) - No changes needed

---

## Success Metrics

### Developer Experience
- ✅ Fast test feedback loop (< 15 seconds for common changes)
- ✅ Full suite confidence (< 1 minute for thorough validation)
- ✅ Easy to run single tests for debugging

### CI/CD Pipeline
- ✅ Fast PR checks (< 30 seconds)
- ✅ Comprehensive nightly builds (< 2 minutes)
- ✅ Clear test failure reporting

### Test Reliability
- ✅ No flakiness from race conditions
- ✅ Deterministic results across runs
- ✅ Easy to reproduce failures locally

---

## Next Steps

1. **Architect Review**: Approve this strategy document
2. **Phase 1 Implementation**: Create TestRunnerFast.gd (1 day)
3. **Phase 2 Planning**: Design fixture schemas (2 days)
4. **Phase 2 Implementation**: Build fixture infrastructure (4 days)
5. **Continuous Improvement**: Monitor test times, refactor slowest tests

---

## Open Questions

1. **Fixture size**: 50 entities vs 200? (Recommendation: Start with 50)
2. **Fixture format**: JSON vs binary? (Recommendation: JSON for readability)
3. **Fixture generation**: Manual vs automatic on model changes? (Recommendation: Manual initially)
4. **Thread count**: 2 vs 4 vs 8? (Recommendation: 4 threads max to avoid thrashing)
5. **CI strategy**: Run fast tests on every push? (Recommendation: Yes)

---

## References

- Current test suite: `scripts/tests/TestRunner.gd`
- Example fixtures in other projects: `scripts/tests/fixtures/` (to be created)
- GDScript threading docs: https://docs.godotengine.org/en/stable/tutorials/performance/threads/using_multiple_threads.html
