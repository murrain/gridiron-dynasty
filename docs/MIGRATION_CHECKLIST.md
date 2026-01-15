# GdUnit4 Migration Checklist

This document provides patterns for converting legacy tests to GdUnit4 v6.0+.

## Assertion Conversion Table

| Legacy TestHelpers | GdUnit4 Equivalent |
|-------------------|---------------------|
| `t.assert_eq(a, b, msg)` | `assert_that(a).is_equal(b)` |
| `t.assert_ne(a, b, msg)` | `assert_that(a).is_not_equal(b)` |
| `t.assert_equal(a, b, msg)` | `assert_that(a).is_equal(b)` |
| `t.assert_not_equal(a, b, msg)` | `assert_that(a).is_not_equal(b)` |
| `t.assert_true(cond, msg)` | `assert_bool(cond).is_true()` |
| `t.assert_false(cond, msg)` | `assert_bool(cond).is_false()` |
| `t.assert_gt(a, b, msg)` | `assert_int(a).is_greater(b)` or `assert_float(a).is_greater(b)` |
| `t.assert_gte(a, b, msg)` | `assert_int(a).is_greater_equal(b)` or `assert_float(a).is_greater_equal(b)` |
| `t.assert_lt(a, b, msg)` | `assert_int(a).is_less(b)` or `assert_float(a).is_less(b)` |
| `t.assert_lte(a, b, msg)` | `assert_int(a).is_less_equal(b)` or `assert_float(a).is_less_equal(b)` |
| `t.assert_between(a, lo, hi, msg)` | `assert_float(a).is_between(lo, hi)` |
| `t.assert_approx(a, b, eps, msg)` | `assert_float(a).is_equal_approx(b, eps)` |
| `t.assert_schema(obj, fields, msg)` | `TestHelpersGdUnit4.assert_schema(self, obj, fields, msg)` |
| `t.assert_schema_typed(obj, schema, msg)` | `TestHelpersGdUnit4.assert_schema_typed(self, obj, schema, msg)` |
| `t.assert_deterministic(callable, seed, msg)` | `TestHelpersGdUnit4.assert_deterministic(self, callable, seed, msg)` |
| `t.assert_max_time(callable, max_ms, msg)` | `TestHelpersGdUnit4.assert_max_time(self, callable, max_ms, msg)` |
| `t.create_seeded_rng(seed)` | `TestHelpersGdUnit4.create_seeded_rng(seed)` |
| `t.create_test_player(...)` | `TestHelpersGdUnit4.create_test_player(...)` |
| `t.create_minimal_world_state(year)` | `TestHelpersGdUnit4.create_minimal_world_state(year)` |

## Type-Specific Assertions

Choose the appropriate assertion type based on the value:

```gdscript
# Integers
assert_int(value).is_equal(expected)
assert_int(value).is_greater(threshold)

# Floats
assert_float(value).is_equal(expected)
assert_float(value).is_between(lo, hi)
assert_float(value).is_equal_approx(expected, epsilon)

# Strings
assert_str(value).is_equal(expected)
assert_str(value).is_not_empty()
assert_str(value).contains("substring")

# Booleans
assert_bool(value).is_true()
assert_bool(value).is_false()

# Arrays
assert_array(value).has_size(expected)
assert_array(value).is_empty()
assert_array(value).contains(element)

# Generic (any type)
assert_that(value).is_equal(expected)
assert_that(value).is_not_equal(expected)
assert_that(value).is_null()
assert_that(value).is_not_null()
```

## Custom Messages

Add custom failure messages with `override_failure_message()`:

```gdscript
assert_int(value).override_failure_message(
    "Custom error: expected %d but got %d" % [expected, value]
).is_equal(expected)
```

## File Structure Conversion

### Before (Legacy)

```gdscript
extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const MyClass = preload("res://scripts/path/MyClass.gd")

func run(t: TestHelpers) -> void:
    test_something(t)
    test_another(t)

func test_something(t: TestHelpers) -> void:
    var result := MyClass.do_something()
    t.assert_eq(result, 42, "result should be 42")
```

### After (GdUnit4)

```gdscript
extends GdUnitTestSuite

const MyClass = preload("res://scripts/path/MyClass.gd")

func test_something() -> void:
    var result := MyClass.do_something()
    assert_int(result).is_equal(42)

func test_another() -> void:
    # Each test method is discovered automatically
    pass
```

## Setup/Teardown Lifecycle

### Before (Legacy)
No formal setup/teardown - manual inline setup.

### After (GdUnit4)

```gdscript
extends GdUnitTestSuite

const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

var _world_state: Dictionary

# Called once before all tests in this file
func before() -> void:
    _world_state = SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x5EED)

# Called once after all tests in this file
func after() -> void:
    SnapshotLoader.clear_cache()

# Called before each individual test
func before_test() -> void:
    pass

# Called after each individual test
func after_test() -> void:
    pass
```

## Test Method Naming

- GdUnit4 discovers test methods by prefix: `test_`
- Remove `(t: TestHelpers)` parameter
- Return type must be `void`

```gdscript
# Legacy: func test_something(t: TestHelpers) -> void:
# GdUnit4: func test_something() -> void:
```

## Helper Method Patterns

### Local Helpers

Keep as private methods (prefix with `_`):

```gdscript
func _create_test_data() -> Dictionary:
    return {"key": "value"}

func test_uses_helper() -> void:
    var data := _create_test_data()
    assert_that(data["key"]).is_equal("value")
```

### Shared Helpers

Use `TestHelpersGdUnit4` static methods:

```gdscript
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

func test_with_shared_helper() -> void:
    var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 19, 75.0)
    assert_that(player["position"]).is_equal("QB")
```

## Migration Checklist Per File

- [ ] Change `extends RefCounted` to `extends GdUnitTestSuite`
- [ ] Remove `const TestHelpers = preload(...)` line
- [ ] Add `const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")` if needed
- [ ] Remove `func run(t) -> void:` method
- [ ] Rename test methods: remove `(t)` parameter, ensure `test_` prefix
- [ ] Convert all assertions per conversion table above
- [ ] Add `before()` and `after()` for fixture setup/cleanup if using SnapshotLoader
- [ ] Ensure all helper methods are private (prefix with `_`)
- [ ] Remove any return statements from test methods (they return `void`)
- [ ] Test the file runs correctly with GdUnit4

## Common Patterns

### Determinism Testing

```gdscript
func test_operation_is_deterministic() -> void:
    TestHelpersGdUnit4.assert_deterministic(
        self,
        func(rng): return MyClass.process(data, rng),
        12345,
        "MyClass.process is deterministic"
    )
```

### Schema Validation

```gdscript
func test_api_contract() -> void:
    var result := MyAPI.get_data()
    TestHelpersGdUnit4.assert_schema(
        self,
        result,
        ["id", "name", "value"],
        "MyAPI return contract"
    )
```

### Performance Testing

```gdscript
func test_performance() -> void:
    TestHelpersGdUnit4.assert_max_time(
        self,
        func(): MyClass.expensive_operation(),
        500.0,
        "expensive_operation completes in 500ms"
    )
```

### Loop Assertions

```gdscript
# Legacy
for item in items:
    t.assert_true(item.has("id"), "item has id")

# GdUnit4
for item in items:
    assert_bool(item.has("id")).is_true()
```

## Batch Migration Order

1. **Batch 1**: Core utilities and config tests (~15 files)
2. **Batch 2**: Draft and player generation tests (~20 files)
3. **Batch 3**: Season simulation and game tests (~15 files)
4. **Batch 4**: API contracts and schema tests (~15 files)
5. **Batch 5**: Award and history tracking tests (~15 files)
6. **Batch 6**: Roster and contract management tests (~15 files)
7. **Batch 7**: Integration and remaining tests (~39 files)

## Verification Commands

```bash
# Run all GdUnit4 tests
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add res://scripts/tests/gdunit4 \
    --ignoreHeadlessMode

# Run specific test file
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add res://scripts/tests/gdunit4/test_example_gdunit4.gd \
    --ignoreHeadlessMode
```
