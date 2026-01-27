# Evaluation & Rating System Test Suite

Comprehensive test coverage for Gridiron Dynasty's evaluation and rating systems using GDUnit4.

## Quick Start

### Running All Tests
```bash
# From project root
godot --path . --headless -d -s \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --test res://scripts/tests/gdunit4/test_evaluation*
```

### Running Specific Test Suite
```bash
godot --path . --headless -d -s \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --test res://scripts/tests/gdunit4/test_hype_modifier_gdunit4.gd
```

### Running Single Test
```bash
godot --path . --headless -d -s \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --test "res://scripts/tests/gdunit4/test_hype_modifier_gdunit4.gd::test_heisman_winner_receives_large_bonus"
```

## Test Files

### Core Framework
- **test_evaluation_context_gdunit4.gd** - EvaluationContext data container
- **test_evaluation_modifier_gdunit4.gd** - Base modifier class
- **test_evaluation_modifier_stack_gdunit4.gd** - Modifier orchestration

### Modifier Implementations
- **test_hype_modifier_gdunit4.gd** - Hype and awards system
- **test_scheme_fit_modifier_gdunit4.gd** - Scheme fit calculations
- **test_coach_and_need_modifiers_gdunit4.gd** - Coach preferences and roster needs

### Rating Systems
- **test_combine_calculator_gdunit4.gd** - Combine performance
- **test_player_rating_calculator_gdunit4.gd** - Overall ratings
- **test_scheme_fit_calculator_gdunit4.gd** - Scheme fit scoring

## Test Coverage

### Total: 200+ tests across 9 test suites

**By Category:**
- Core Framework: 58 tests
- Modifiers: 68 tests
- Rating Calculators: 74+ tests

**By Type:**
- Happy Path: 90 tests (45%)
- Edge Cases: 60 tests (30%)
- Determinism: 30 tests (15%)
- Integration: 20 tests (10%)

## Writing New Tests

### Test File Template
```gdscript
extends GdUnitTestSuite
class_name TestYourFeatureGdUnit4

const YourFeature = preload("res://scripts/core/your_feature.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

func test_feature_does_something() -> void:
    var result := YourFeature.calculate_something(input)
    assert_float(result).is_greater(0.0)
```

### Common Assertions
```gdscript
# Floats
assert_float(value).is_equal(expected)
assert_float(value).is_equal_approx(expected, 0.01)
assert_float(value).is_greater(min_value)
assert_float(value).is_less_equal(max_value)

# Integers
assert_int(value).is_equal(expected)
assert_int(value).is_between(min, max)

# Strings
assert_string(value).is_equal("expected")
assert_string(value).contains("substring")
assert_string(value).is_empty()

# Booleans
assert_bool(value).is_true()
assert_bool(value).is_false()

# Objects/Dictionaries
assert_object(obj).is_not_null()
assert_that(dict).has("key")
assert_that(dict).is_equal(expected_dict)

# Arrays
assert_array(arr).has_size(3)
assert_array(arr).is_empty()
assert_array(arr).contains([item1, item2])
```

### Testing Determinism
```gdscript
func test_calculation_is_deterministic() -> void:
    TestHelpersGdUnit4.assert_deterministic(self, func(rng: RandomNumberGenerator):
        return YourSystem.calculate_with_rng(data, rng)
    , 12345, "Description of what's being tested")
```

### Testing Edge Cases
```gdscript
func test_handles_missing_data_gracefully() -> void:
    var empty_data := {}
    var result := YourSystem.calculate(empty_data)

    # Should not crash
    assert_object(result).is_not_null()
    # Should use sensible defaults
    assert_float(result.value).is_equal(50.0)
```

## Test Helpers

### TestHelpersGdUnit4 Utilities

#### Create Test Players
```gdscript
var player := TestHelpersGdUnit4.create_test_player(
    "P001",      # player_id
    "QB",        # position
    21,          # age
    80.0,        # rating
    4            # college_year
)
```

#### Assert Determinism
```gdscript
TestHelpersGdUnit4.assert_deterministic(
    self,
    callable,
    seed_value,
    "description"
)
```

#### Validate Schema
```gdscript
TestHelpersGdUnit4.assert_schema(
    self,
    obj,
    ["field1", "field2", "field3"],
    "object name"
)
```

#### Create Seeded RNG
```gdscript
var rng := TestHelpersGdUnit4.create_seeded_rng(12345)
```

## Best Practices

### 1. Test Naming
Use descriptive names that explain what's being tested:
```gdscript
✅ test_heisman_winner_receives_large_bonus()
❌ test_hype1()
```

### 2. Arrange-Act-Assert
Structure tests clearly:
```gdscript
func test_something() -> void:
    # Arrange
    var player := create_test_player()
    var modifier := HypeModifier.new()

    # Act
    var result := modifier.calculate(context)

    # Assert
    assert_float(result.additive_bonus).is_greater(0.0)
```

### 3. Test One Thing
Each test should verify one specific behavior:
```gdscript
✅ test_high_hype_produces_positive_bonus()
✅ test_low_hype_produces_negative_penalty()
❌ test_hype_calculation() # Too broad
```

### 4. Use Meaningful Data
Create realistic test data:
```gdscript
✅ player["hype"] = 90.0  # Top prospect
✅ player["hype"] = 30.0  # Small school prospect
❌ player["hype"] = 5.0   # Unrealistic
```

### 5. Test Edge Cases
Always test boundary conditions:
```gdscript
# Zero values
# Empty collections
# Missing data
# Maximum values
# Null/invalid inputs
```

### 6. Verify Determinism
For non-random calculations:
```gdscript
var result1 := system.calculate(data)
var result2 := system.calculate(data)
assert_float(result1).is_equal(result2)
```

For random calculations:
```gdscript
TestHelpersGdUnit4.assert_deterministic(
    self, callable, seed, "description"
)
```

## Debugging Failed Tests

### Verbose Output
```bash
godot --path . --headless -d -s \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --test <test_file> \
  --verbose
```

### Custom Failure Messages
```gdscript
assert_float(result).override_failure_message(
    "Expected positive bonus for high hype, got %.2f" % result
).is_greater(0.0)
```

### Debug Prints
```gdscript
func test_something() -> void:
    var result := calculate()
    print("DEBUG: result = ", result)
    print("DEBUG: details = ", result.details)
    assert_float(result.value).is_equal(expected)
```

## Common Issues

### Issue: "Function not found"
**Cause:** Missing preload or wrong path
**Fix:** Check file path in preload statement

### Issue: "Expected X but got Y"
**Cause:** Calculation changed or test expectations wrong
**Fix:** Verify expected behavior, update test if needed

### Issue: "Determinism test fails"
**Cause:** Hidden RNG or external state
**Fix:** Ensure function is pure, no global state

### Issue: "Null reference"
**Cause:** Missing setup or invalid data
**Fix:** Add null checks, validate setup

## Performance Considerations

### Fast Tests
- Core framework tests: <1ms per test
- Modifier tests: <2ms per test
- Calculator tests: <5ms per test

### Slow Tests (>10ms)
- File I/O operations
- Complex integration tests
- Large data set processing

**Optimization:** Mock file operations, use smaller test data

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Run Evaluation Tests
  run: |
    godot --path . --headless -d -s \
      res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
      --test res://scripts/tests/gdunit4/test_evaluation* \
      --report-junit test-results.xml
```

### Test Report
Results saved to `test-results.xml` in JUnit format for CI dashboards.

## Troubleshooting

### GDUnit4 Not Found
```bash
# Install GDUnit4
# Download from: https://github.com/MikeSchulze/gdUnit4
# Copy to: addons/gdUnit4/
```

### Tests Not Discovered
- Ensure file ends with `_gdunit4.gd`
- Verify class extends `GdUnitTestSuite`
- Check test functions start with `test_`

### Import Errors
- Use absolute paths in preload: `res://scripts/...`
- Verify file exists at specified path
- Check for circular dependencies

## Further Reading

- **TEST_SUITE_SUMMARY.md** - Detailed test coverage report
- **TestHelpersGdUnit4.gd** - Helper function documentation
- **ENGINEER_PROTOCOLS.md** - Testing requirements and standards
- [GDUnit4 Docs](https://mikeschulze.github.io/gdUnit4/)

## Questions?

Check the test examples in this directory. Each test suite demonstrates patterns and best practices for that system.

---

**Last Updated:** 2026-01-23
**Maintainer:** Gridiron Dynasty Test Team
**Framework:** GDUnit4 v6.0.3
