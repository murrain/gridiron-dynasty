# Testing Guide: GdUnit4 Framework

This guide documents the testing patterns and infrastructure for the Gridiron Dynasty simulation codebase using GdUnit4 v6.0+.

## Table of Contents

1. [Overview](#overview)
2. [Test Structure](#test-structure)
3. [Writing Tests](#writing-tests)
4. [Custom Assertions](#custom-assertions)
5. [Fixture System](#fixture-system)
6. [Running Tests](#running-tests)
7. [CI/CD Integration](#cicd-integration)
8. [Migration from Legacy Tests](#migration-from-legacy-tests)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The test suite uses **GdUnit4 v6.0+**, a modern testing framework for Godot that provides:

- Fluent assertion syntax for readable tests
- Automatic test discovery
- Per-test retry for flaky test detection
- HTML and XML reporting
- Performance timing

### Key Principles

1. **Determinism First**: All simulation tests must be reproducible with explicit seeds
2. **Test Isolation**: Each test must clean up its state (especially SnapshotLoader cache)
3. **Performance Budgets**: Tests must complete within defined time limits
4. **Schema Validation**: API contracts are verified to catch breaking changes early

---

## Test Structure

### Directory Layout

```
scripts/tests/
  gdunit4/                      # GdUnit4 test suites
    test_rand_gdunit4.gd
    test_game_simulation_determinism_gdunit4.gd
    test_scout_runtime_gdunit4.gd
    test_api_contracts_gdunit4.gd
    test_season_simulation_integration_gdunit4.gd
  fixtures/
    world_state/
      SnapshotLoader.gd         # Fixture loading system
      SnapshotGenerator.gd      # Snapshot generation tool
      snapshot_config.json      # Snapshot configuration
      year_5_snapshot.json      # Pre-generated snapshots
      year_10_snapshot.json
      year_20_snapshot.json
  TestHelpersGdUnit4.gd         # Custom assertion utilities
```

### Naming Conventions

- Test files: `test_<feature>_gdunit4.gd`
- Test functions: `func test_<what_is_being_tested>() -> void:`
- Setup: `func before() -> void:` (per-suite) or `func before_test() -> void:` (per-test)
- Teardown: `func after() -> void:` (per-suite) or `func after_test() -> void:` (per-test)

---

## Writing Tests

### Basic Test Structure

```gdscript
extends GdUnitTestSuite

const MyClass = preload("res://scripts/core/MyClass.gd")

func test_my_feature_does_something() -> void:
    var result := MyClass.do_something()
    assert_int(result).is_equal(42)
```

### Test with Setup/Teardown

```gdscript
extends GdUnitTestSuite

const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

var _world_state: Dictionary

func before() -> void:
    # Called once before all tests in this suite
    _world_state = SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x5EED001)

func after() -> void:
    # Called once after all tests in this suite
    # CRITICAL: Always clear SnapshotLoader cache for isolation
    SnapshotLoader.clear_cache()

func test_world_state_has_teams() -> void:
    assert_bool(_world_state.has("nfl_teams")).is_true()
```

### Determinism Tests

```gdscript
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

func test_operation_is_deterministic() -> void:
    TestHelpersGdUnit4.assert_deterministic(
        self,
        func(rng): return MyClass.simulate_with_rng(data, rng),
        12345,  # Explicit seed
        "MyClass.simulate_with_rng produces deterministic results"
    )
```

### Performance Tests

```gdscript
func test_operation_completes_within_budget() -> void:
    TestHelpersGdUnit4.assert_max_time(
        self,
        func(): MyClass.expensive_operation(),
        500.0,  # Maximum milliseconds
        "Expensive operation completes within 500ms"
    )
```

### Schema Validation Tests

```gdscript
func test_api_returns_expected_structure() -> void:
    var result := MyAPI.get_data()

    TestHelpersGdUnit4.assert_schema(
        self,
        result,
        ["id", "name", "value"],
        "MyAPI.get_data return contract"
    )

    # For stricter type checking:
    TestHelpersGdUnit4.assert_schema_typed(
        self,
        result,
        {
            "id": TYPE_STRING,
            "name": TYPE_STRING,
            "value": TYPE_INT
        },
        "MyAPI.get_data typed contract"
    )
```

---

## Custom Assertions

The `TestHelpersGdUnit4` class provides custom assertions tailored to simulation testing:

### assert_deterministic

Verifies a function produces identical results with the same seed.

```gdscript
static func assert_deterministic(
    suite: Object,
    callable: Callable,  # Function accepting RNG, returning result
    seed_value: int,
    message: String
) -> void
```

### assert_schema

Validates a dictionary has required fields.

```gdscript
static func assert_schema(
    suite: Object,
    obj: Dictionary,
    required_fields: Array,  # ["field1", "field2", ...]
    message: String
) -> void
```

### assert_schema_typed

Validates field presence and types.

```gdscript
static func assert_schema_typed(
    suite: Object,
    obj: Dictionary,
    schema: Dictionary,  # {"field": TYPE_INT, "name": TYPE_STRING}
    message: String
) -> void
```

### assert_max_time

Verifies operation completes within time budget.

```gdscript
static func assert_max_time(
    suite: Object,
    callable: Callable,  # Function to time (no parameters)
    max_ms: float,       # Maximum allowed milliseconds
    message: String
) -> void
```

### Helper Methods

```gdscript
# Create seeded RNG
var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

# Create test player
var player := TestHelpersGdUnit4.create_test_player("QB001", "QB", 19, 75.0)

# Create minimal world state
var world := TestHelpersGdUnit4.create_minimal_world_state(2025)
```

---

## Fixture System

### SnapshotLoader

The `SnapshotLoader` provides pre-generated world states for testing.

```gdscript
const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

# Load 10-year snapshot (instant from cache)
var world := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x5EED001)

# Load 5-year snapshot + simulate 2 more years
var world := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 2, 0x5EED001)

# Generate fresh world (slower - 3 years of simulation)
var world := SnapshotLoader.setup_world(SnapshotLoader.FRESH, 3, 0x5EED001)
```

### CRITICAL: Cache Cleanup

Always clear the snapshot cache in `after()` to prevent test pollution:

```gdscript
func after() -> void:
    SnapshotLoader.clear_cache()
```

### Regenerating Snapshots

When schemas change, regenerate snapshots:

```bash
godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
```

---

## Running Tests

### Command Line

```bash
# Run all GdUnit4 tests
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add res://scripts/tests/gdunit4 \
    --ignoreHeadlessMode

# Run specific test file
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add res://scripts/tests/gdunit4/test_rand_gdunit4.gd \
    --ignoreHeadlessMode

# Using the runtest script
GODOT_BIN=/path/to/godot ./addons/gdUnit4/runtest.sh \
    --add res://scripts/tests/gdunit4
```

### From Godot Editor

1. Open the GdUnit4 panel (Editor > GdUnit4)
2. Select tests to run
3. Click "Run Tests"

### Reports

Test reports are generated in `reports/`:
- `results.xml` - JUnit XML format for CI
- `index.html` - Human-readable HTML report

---

## CI/CD Integration

### GitHub Action

The `.github/workflows/test.yml` workflow runs tests automatically:

```yaml
- name: Run GdUnit4 Tests
  uses: MikeSchulze/gdUnit4-action@v1
  with:
    godot-version: '4.5.0'
    version: 'v6.0.1'
    paths: 'res://scripts/tests/gdunit4'
    retries: 3          # Per-test retry count
    timeout: 10         # Minutes per test
```

### Features

- **Per-test retry**: Individual tests are retried up to 3 times before failing
- **Artifact upload**: HTML and XML reports are preserved as artifacts
- **Status checks**: Test results appear on PRs

---

## Migration from Legacy Tests

### Converting Test Files

Legacy tests use `TestHelpers` with callback pattern:

```gdscript
# Legacy pattern
extends RefCounted

func run(t) -> void:
    t.assert_eq(actual, expected, "message")
```

Convert to GdUnit4 pattern:

```gdscript
# GdUnit4 pattern
extends GdUnitTestSuite

func test_my_feature() -> void:
    assert_that(actual).is_equal(expected)
```

### Assertion Mapping

| Legacy TestHelpers | GdUnit4 |
|-------------------|---------|
| `t.assert_eq(a, b, msg)` | `assert_that(a).is_equal(b)` |
| `t.assert_ne(a, b, msg)` | `assert_that(a).is_not_equal(b)` |
| `t.assert_true(cond, msg)` | `assert_bool(cond).is_true()` |
| `t.assert_false(cond, msg)` | `assert_bool(cond).is_false()` |
| `t.assert_gt(a, b, msg)` | `assert_int(a).is_greater(b)` |
| `t.assert_gte(a, b, msg)` | `assert_int(a).is_greater_equal(b)` |
| `t.assert_lt(a, b, msg)` | `assert_int(a).is_less(b)` |
| `t.assert_lte(a, b, msg)` | `assert_int(a).is_less_equal(b)` |
| `t.assert_between(a, lo, hi, msg)` | `assert_float(a).is_between(lo, hi)` |
| `t.assert_approx(a, b, eps, msg)` | `assert_float(a).is_equal_approx(b, eps)` |

### Custom Message Override

```gdscript
assert_int(value).override_failure_message("Custom error: %s" % context).is_equal(42)
```

---

## Troubleshooting

### Orphan Node Warnings

GdUnit4 reports orphan nodes when resources aren't cleaned up:

```
WARNING: Detected <1> orphan nodes during test execution!
```

**Solution**: Ensure all created nodes are freed or use `auto_free()`:

```gdscript
var node := auto_free(Node.new())
```

### Test Isolation Issues

If tests pass individually but fail together:

1. Check for shared static state
2. Ensure `SnapshotLoader.clear_cache()` is called in `after()`
3. Verify RNG seeds are explicit, not relying on global state

### Headless Mode Warning

GdUnit4 warns about headless mode limitations:

```
Headless mode is not supported!
```

Use `--ignoreHeadlessMode` flag for CI/CD (tests without UI interaction work fine).

### Snapshot Version Mismatch

```
SnapshotLoader: Schema version mismatch
```

Regenerate snapshots:

```bash
godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
```

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Full test suite | < 154 seconds (25% over 120s baseline) |
| Individual test | < 5 seconds (except integration) |
| Fixture loading | < 2 seconds |
| CI pipeline | < 10 minutes |

---

## Best Practices

1. **Always use explicit seeds** for any operation involving RNG
2. **Clean up in `after()`** - especially SnapshotLoader cache
3. **Use custom assertions** for domain-specific checks
4. **Test determinism explicitly** - don't assume it
5. **Set performance budgets** for expensive operations
6. **Validate API contracts** to catch breaking changes
7. **Keep tests isolated** - no shared mutable state
