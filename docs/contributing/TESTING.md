# Tests

This project uses a custom GDScript testing framework designed for headless execution
with **Godot 4.5 stable**. All tests run without rendering, ensuring fast and
deterministic results.

## Running the Test Suite

### Command

From the repository root, run:

```bash
godot --headless -s res://scripts/tests/TestRunner.gd
```

This executes all 34 test modules and reports results to stdout.

### Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

### Example Output

Success:
```
All tests passed (34).
```

Failure:
```
Failures (2):
- res://scripts/tests/test_rand.gd: splitmix64 should be deterministic (expected 123, got 456)
- res://scripts/tests/test_config.gd: nested merge failed (expected 5, got 3)
```

## Test Suite Structure

```
scripts/tests/
├── TestRunner.gd          # Main test orchestrator
├── TestHelpers.gd         # Assertion library
├── test_*.gd              # Individual test modules (34 files)
└── fixtures/
    ├── configs/           # Base test configurations
    │   ├── alpha.json
    │   ├── beta.json
    │   └── world/
    │       ├── calendar.json
    │       ├── high_schools.json
    │       └── league.json
    └── configs_override/  # Override configurations for merge testing
        └── alpha.json
```

## Test Modules by Category

### Core Utilities
| Module | Purpose |
|--------|---------|
| `test_rand.gd` | RNG determinism, splitmix64, seed derivation |
| `test_threadpool.gd` | Array chunking, parallel task utilities |
| `test_core_utilities.gd` | General utility functions |
| `test_config.gd` | Configuration structure and defaults |
| `test_config_loader.gd` | Config loading, merging, and overrides |
| `test_helpers.gd` | Helper function validation |
| `test_deager.gd` | Deferred/eager evaluation utilities |
| `test_stathelpers.gd` | Statistical helper functions |

### Player Systems
| Module | Purpose |
|--------|---------|
| `test_player_model.gd` | Player data serialization/deserialization |
| `test_player_generator.gd` | Player creation and attribute generation |
| `test_player_lifecycle.gd` | Age progression, development, retirement |
| `test_player_lifecycle_reports.gd` | Development and injury report generation |
| `test_combine_calculator.gd` | Combine score calculations |

### Scouting & Evaluation
| Module | Purpose |
|--------|---------|
| `test_recruit_rater.gd` | Recruit rating algorithms |
| `test_scout_runtime.gd` | Scouting evaluation execution |
| `test_scout_model.gd` | Scout data models |
| `test_scout_factory.gd` | Scout instance creation |

### High School Pipeline
| Module | Purpose |
|--------|---------|
| `test_high_school_generator.gd` | High school entity generation |
| `test_high_school_season.gd` | High school season simulation |
| `test_high_school_assignment.gd` | Player-to-school assignment logic |

### College Pipeline
| Module | Purpose |
|--------|---------|
| `test_class_generator.gd` | Recruiting class generation |
| `test_draft_class_generator.gd` | Draft-eligible class creation |
| `test_college_recruiting.gd` | College recruitment mechanics |
| `test_college_season.gd` | College season simulation and roster advancement |

### NFL Systems
| Module | Purpose |
|--------|---------|
| `test_nfl_team_generator.gd` | NFL team roster generation |

### Financial & Valuation
| Module | Purpose |
|--------|---------|
| `test_valuation_helpers.gd` | Player/pick valuation utilities |
| `test_cap_accounting.gd` | Salary cap calculations |
| `test_cap_validation_flow.gd` | Cap compliance validation |
| `test_trade_valuation.gd` | Trade value assessment |

### World Systems
| Module | Purpose |
|--------|---------|
| `test_world_calendar.gd` | Calendar and date progression |
| `test_world_history_preview.gd` | Historical data preview generation |
| `test_advance_world_year_helpers.gd` | Year advancement utilities |
| `test_pipeline_seed_helpers.gd` | Seed management for simulation pipelines |
| `test_phase4_scaffolding.gd` | Phase 4 system scaffolding |

## Creating New Tests

### Step 1: Create the Test File

Create a new file in `scripts/tests/` following the naming convention `test_<component>.gd`:

```gdscript
extends RefCounted

# Preload the module you're testing
const MyModule = preload("res://scripts/path/to/MyModule.gd")

func run(t) -> void:
    # Your test assertions go here
    pass
```

### Step 2: Write Test Assertions

Use the assertion methods provided by `TestHelpers`:

```gdscript
func run(t) -> void:
    # Boolean assertion
    t.assert_true(1 + 1 == 2, "basic arithmetic works")

    # Equality assertion
    var result = MyModule.calculate(5)
    t.assert_eq(result, 25, "calculate returns square")

    # Inequality assertion
    var a = MyModule.generate(1)
    var b = MyModule.generate(2)
    t.assert_ne(a, b, "different inputs produce different outputs")

    # Float comparison with epsilon tolerance
    var ratio = MyModule.compute_ratio(3, 4)
    t.assert_approx(ratio, 0.75, 0.001, "ratio is approximately 0.75")

    # Range assertion
    var score = MyModule.random_score(rng)
    t.assert_between(score, 0.0, 100.0, "score within valid range")
```

### Step 3: Register the Test

Add your test file to the `TEST_SCRIPTS` array in `TestRunner.gd`:

```gdscript
const TEST_SCRIPTS := [
    # ... existing tests ...
    "res://scripts/tests/test_my_module.gd",  # Add your test here
]
```

## Available Assertions

| Method | Signature | Purpose |
|--------|-----------|---------|
| `assert_true` | `(condition: bool, message: String)` | Passes if condition is true |
| `assert_eq` | `(actual: Variant, expected: Variant, message: String)` | Passes if values are equal |
| `assert_ne` | `(actual: Variant, expected: Variant, message: String)` | Passes if values are not equal |
| `assert_approx` | `(actual: float, expected: float, epsilon: float, message: String)` | Passes if floats are within epsilon |
| `assert_between` | `(actual: float, lo: float, hi: float, message: String)` | Passes if value is in range [lo, hi] |

## Test Patterns

### Determinism Testing

For simulation systems, verify that identical seeds produce identical results:

```gdscript
func run(t) -> void:
    var result1 = _run_simulation(42)
    var result2 = _run_simulation(42)
    var result3 = _run_simulation(43)

    t.assert_eq(result1, result2, "same seed produces same result")
    t.assert_ne(result1, result3, "different seed produces different result")

func _run_simulation(seed_val: int) -> Dictionary:
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_val
    return MySimulation.run(rng)
```

### Configuration-Driven Testing

Use inline configurations for isolated, reproducible tests:

```gdscript
func run(t) -> void:
    var config = {
        "setting_a": 10,
        "setting_b": {"nested": true}
    }
    var result = MyModule.process(config)
    t.assert_eq(result.get("output"), 100, "config applied correctly")
```

### Fixture-Based Testing

For complex configurations, use fixture files:

```gdscript
func run(t) -> void:
    var cfg = ConfigLoader.new()
    cfg.configure(
        "res://scripts/tests/fixtures/configs",
        "res://scripts/tests/fixtures/configs_override",
        false
    )
    var world_cfg = cfg.get_config("world/calendar")
    # Test with loaded configuration
```

### State Mutation Testing

Verify that functions correctly modify state:

```gdscript
func run(t) -> void:
    var player = {"age": 19, "stats": {"speed": 50.0}}
    var result = PlayerLifecycle.advance_one_year([player], ...)
    var updated = result.get("players", [])[0]

    t.assert_eq(updated.get("age"), 20, "age incremented")
    t.assert_between(float(updated.get("stats").get("speed")), 50.0, 60.0, "stat developed")
```

### Round-Trip Serialization Testing

Verify data survives serialization cycles:

```gdscript
func run(t) -> void:
    var original = {"name": "Test", "value": 42}
    var serialized = MyModule.serialize(original)
    var restored = MyModule.deserialize(serialized)

    t.assert_eq(restored, original, "round-trip preserves data")
```

## Using Test Fixtures

### Directory Structure

```
fixtures/
├── configs/              # Base configurations (loaded first)
│   ├── alpha.json
│   └── world/
│       └── calendar.json
└── configs_override/     # Override configurations (merged on top)
    └── alpha.json
```

### Loading Fixtures

```gdscript
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")

func run(t) -> void:
    var cfg = ConfigLoader.new()
    cfg.configure(
        "res://scripts/tests/fixtures/configs",       # Base path
        "res://scripts/tests/fixtures/configs_override",  # Override path
        false  # Don't throw on missing files
    )

    # Load a specific config (merges base + override)
    var alpha = cfg.get_config("alpha")

    # Load nested config
    var calendar = cfg.get_config("world/calendar")

    # List available configs
    var keys = cfg.list_keys()  # ["alpha", "beta", "world/calendar", ...]
```

## Best Practices

### Write Descriptive Assertion Messages

Messages should explain what was expected:

```gdscript
# Good - explains the expectation
t.assert_eq(player.age, 21, "player age should increment after season")

# Bad - doesn't help diagnose failures
t.assert_eq(player.age, 21, "age check")
```

### Use Fixed Seeds for Reproducibility

Always use explicit seed values in tests involving RNG:

```gdscript
var rng = RandomNumberGenerator.new()
rng.seed = 12345  # Fixed seed for reproducibility
```

### Test Edge Cases

Include boundary conditions and error cases:

```gdscript
func run(t) -> void:
    # Empty input
    var empty_result = MyModule.process([])
    t.assert_eq(empty_result.size(), 0, "empty input returns empty output")

    # Single item
    var single_result = MyModule.process([1])
    t.assert_eq(single_result.size(), 1, "single item processed")

    # Boundary values
    var max_result = MyModule.calculate(999999)
    t.assert_true(max_result > 0, "handles large values")
```

### Keep Tests Independent

Each test module should be self-contained and not depend on other tests:

```gdscript
# Good - creates its own test data
func run(t) -> void:
    var player = _make_test_player()
    # ... test with player

func _make_test_player() -> Dictionary:
    return {"name": "Test", "age": 20, "position": "QB"}
```

### Use Helper Functions for Complex Setup

Extract repeated setup into private helper functions:

```gdscript
func run(t) -> void:
    _test_basic_functionality(t)
    _test_edge_cases(t)
    _test_error_handling(t)

func _test_basic_functionality(t) -> void:
    var data = _make_test_data()
    # ... assertions

func _make_test_data() -> Dictionary:
    return {"field": "value"}
```

## CI Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Godot 4.5 stable
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip
          unzip -q Godot_v4.5-stable_linux.x86_64.zip
          sudo mv Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot
          sudo chmod +x /usr/local/bin/godot

      - name: Run tests
        run: godot --headless -s res://scripts/tests/TestRunner.gd
```

### Important Notes

- Use Godot 4.5 stable for consistent behavior across environments
- Headless mode (`--headless`) is required for CI environments
- The test runner exits with code 1 on any failure, which fails the CI job
- Test output goes to stdout for easy capture in CI logs

## Troubleshooting

### Tests Pass Locally But Fail in CI

- Ensure CI uses the same Godot version (4.5 stable)
- Check for filesystem path differences (case sensitivity on Linux)
- Verify all fixture files are committed to the repository

### Flaky Tests

- Check for unseeded RNG usage (always set explicit seeds)
- Look for tests that depend on execution order
- Verify no shared mutable state between tests

### Test Not Running

- Confirm the test file is added to `TEST_SCRIPTS` in `TestRunner.gd`
- Verify the file has the correct `run(t)` function signature
- Check for syntax errors that prevent the script from loading
