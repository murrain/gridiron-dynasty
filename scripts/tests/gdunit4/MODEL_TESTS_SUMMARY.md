# Core Models Test Suite - GDUnit4

## Overview
Comprehensive test suite for all Core Models in the Gridiron Dynasty project.

**Total Tests:** 243 test methods across 7 test files
**Framework:** GDUnit4 v6.0.3
**Godot Version:** 4.5

## Test Files Created

### 1. test_contract_model_gdunit4.gd (27 tests)
Tests the `Contract` model (res://scripts/core/models/Contract.gd)

**Test Categories:**
- **Initialization (3 tests):** Default values, constructor behavior
- **Serialization (5 tests):** to_dict/from_dict round-trip, schema validation, backward compatibility
- **Business Logic (12 tests):** is_active, is_expired, years_remaining, advance_year
- **Edge Cases (7 tests):** Negative values, large financials, type coercion

**Key Features Tested:**
- Contract lifecycle (active, expired, unsigned states)
- Year advancement logic
- Financial field serialization
- Contract status queries

### 2. test_coach_model_gdunit4.gd (27 tests)
Tests the `Coach` model (res://scripts/core/models/Coach.gd)

**Test Categories:**
- **Initialization (3 tests):** Default values, scheme system, evaluation philosophy
- **Serialization (4 tests):** Round-trip, schema validation, missing fields
- **Business Logic (5 tests):** get_full_name with various edge cases
- **Coaching Attributes (3 tests):** Valid ranges, min/max values
- **Scheme System (2 tests):** Offensive/defensive scheme preferences, rigidity
- **Evaluation Philosophy (2 tests):** Character and medical tolerance variants
- **Edge Cases (8 tests):** Special characters, long names, experience years

**Key Features Tested:**
- Person inheritance (first_name, last_name, id)
- Coaching attributes (ability, recruiting, development)
- Scheme preferences and rigidity
- Player evaluation philosophy (character/medical tolerance)

### 3. test_depth_chart_model_gdunit4.gd (40 tests)
Tests the `DepthChart` model (res://scripts/core/models/DepthChart.gd)

**Test Categories:**
- **Initialization (1 test):** Default empty state
- **Serialization (4 tests):** Round-trip, schema, order preservation
- **Core Functionality (7 tests):** get_starter, get_depth, set_depth, get_backup
- **Add/Remove Player (11 tests):** Adding at index, removing, duplicate handling
- **Query Operations (5 tests):** get_player_positions, get_filled_positions, clear
- **Edge Cases (12 tests):** Empty IDs, large depth charts, special position names

**Key Features Tested:**
- Position depth management
- Starter and backup queries
- Player position tracking
- Duplicate prevention
- Batch operations (remove from all positions)

### 4. test_roster_model_gdunit4.gd (33 tests)
Tests the `Roster` model (res://scripts/core/models/Roster.gd)

**Test Categories:**
- **Initialization (1 test):** Default values
- **Serialization (5 tests):** Round-trip, schema, depth chart integration, backward compatibility
- **Cap Calculation (5 tests):** Single/multiple players, cap exemptions
- **Status Queries (3 tests):** Get players by status, status counts
- **Roster Movement (10 tests):** Practice squad, IR, promotions/activations
- **Internal Helpers (3 tests):** Status enum/string conversions
- **Edge Cases (6 tests):** Empty contracts, multiple exemptions, large rosters

**Key Features Tested:**
- Cap accounting and exemptions
- Roster status management (active, practice squad, IR, suspended)
- Player movement between statuses
- Depth chart integration
- Cap charge calculations

### 5. test_roster_entry_model_gdunit4.gd (32 tests)
Tests the `RosterEntry` model (res://scripts/core/models/RosterEntry.gd)

**Test Categories:**
- **Initialization (1 test):** Default values and sub-resource initialization
- **Serialization (6 tests):** Round-trip, schema, legacy formats, status as string
- **Status Parsing (4 tests):** String variants, case insensitivity, enum parsing
- **Business Logic (6 tests):** is_active, is_on_ir, counts_against_cap, get_cap_charge
- **Cap Exemption (3 tests):** Practice squad, IR, suspended status
- **Edge Cases (12 tests):** Empty IDs, negative values, special characters, dead money

**Key Features Tested:**
- Roster status tracking
- Cap exemption logic
- Contract cap charge calculation
- Backward compatibility with legacy formats
- Status enum/string conversion

### 6. test_team_model_gdunit4.gd (33 tests)
Tests the `Team` model (res://scripts/core/models/Team.gd)

**Test Categories:**
- **Initialization (2 tests):** Default values, scouting budget
- **Serialization (5 tests):** Round-trip, schema, cap structure, backward compatibility
- **Cap Calculation (4 tests):** cap_used, cap_space properties, over-cap scenarios
- **Player ID Queries (6 tests):** Active/inactive filtering, empty roster
- **Scheme Tests (2 tests):** Offensive and defensive scheme variants
- **Scouting (3 tests):** Data serialization, budget tracking, deep copy
- **Edge Cases (11 tests):** Special characters, large rosters, null roster

**Key Features Tested:**
- Team identity and naming
- Roster management integration
- Cap space calculations
- Player ID queries with status filtering
- Scouting data and budget tracking
- Scheme preferences

### 7. test_player_model_gdunit4.gd (51 tests)
Tests the `Player` model (res://scripts/core/models/Player.gd) - THE MOST COMPREHENSIVE

**Test Categories:**
- **Initialization (2 tests):** Default values, sub-resource initialization
- **Serialization (7 tests):** Round-trip, schema, nested resource formats (physicals, stats, contract)
- **Backward Compatibility (4 tests):** Legacy flat formats, stage inference, class_year inference
- **Stage Transitions (12 tests):** Valid/invalid transitions, all stage paths
- **Stage Queries (8 tests):** All is_*() methods (is_nfl_player, is_college_player, etc.)
- **Stats Tests (4 tests):** get_stat, set_stat, null handling
- **Business Logic (6 tests):** get_full_name, jersey clamping, class_year clamping, draft intelligence
- **Edge Cases (8 tests):** Position variants, special characters, age boundaries, complex serialization

**Key Features Tested:**
- Player lifecycle stages (HIGH_SCHOOL → COLLEGE → DRAFT_ELIGIBLE → NFL_ROOKIE → NFL_VETERAN → RETIRED)
- Stage transition validation
- Sub-resource management (Contract, PlayerPhysicals, StatsProfile, TraitSet, etc.)
- Stats and potential tracking
- Draft eligibility and declaration
- Jersey number and class year validation
- Backward compatibility with legacy save formats

## Test Coverage Summary

### Models Tested
1. Contract.gd - Contract management
2. Coach.gd - Coach entity (extends Person)
3. DepthChart.gd - Position depth chart
4. Roster.gd - Team roster with cap accounting
5. RosterEntry.gd - Individual roster entry
6. Team.gd - Team entity with roster and scouting
7. Player.gd - Player entity with full lifecycle (extends Person)

### Test Patterns Used

#### 1. Initialization Tests
Verify default values and resource initialization:
```gdscript
func test_model_initialization() -> void:
    var model = Model.new()
    assert_str(model.field).is_equal("default")
    assert_int(model.number).is_equal(0)
```

#### 2. Serialization Tests
Verify to_dict/from_dict round-trip:
```gdscript
func test_model_serialization_roundtrip() -> void:
    var model = Model.new()
    model.field = "value"
    var dict = model.to_dict()
    var restored = Model.new()
    restored.from_dict(dict)
    assert_str(restored.field).is_equal("value")
```

#### 3. Business Logic Tests
Verify domain logic and computed properties:
```gdscript
func test_contract_is_active() -> void:
    var contract = Contract.new()
    contract.current_year = 2
    contract.total_years = 5
    assert_bool(contract.is_active()).is_true()
```

#### 4. Edge Case Tests
Verify boundary conditions and error handling:
```gdscript
func test_roster_empty_contract_in_entry() -> void:
    var roster = Roster.new()
    roster.entries = [{"player_id": "P001", "cap_exempt": false}]
    var cap_used = roster.get_cap_used()
    assert_float(cap_used).is_equal(0.0)
```

## Running the Tests

### Option 1: Using Godot Editor
1. Open the project in Godot 4.5
2. Navigate to the GDUnit4 panel (bottom panel)
3. Click "Run All Tests" or select specific test files
4. View results in the test output panel

### Option 2: Using Command Line
```bash
# Run all tests
godot4 --headless -s addons/gdunit4/bin/GdUnitCmdTool.gd -a tests/

# Run specific test file
godot4 --headless -s addons/gdunit4/bin/GdUnitCmdTool.gd -a tests/gdunit4/test_player_model_gdunit4.gd

# Generate test report
godot4 --headless -s addons/gdunit4/bin/GdUnitCmdTool.gd -a tests/ --report-dir test_reports/
```

### Option 3: Using CI/CD
```yaml
# Example GitHub Actions workflow
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - name: Setup Godot
      uses: chickensoft-games/setup-godot@v1
      with:
        version: 4.5
    - name: Run Tests
      run: godot4 --headless -s addons/gdunit4/bin/GdUnitCmdTool.gd -a tests/
```

## Test Quality Standards

All tests follow these quality standards:

1. **Deterministic:** Tests produce consistent results across runs
2. **Isolated:** Each test is independent and doesn't affect others
3. **Readable:** Test names clearly describe what is being tested
4. **Comprehensive:** Tests cover initialization, serialization, business logic, and edge cases
5. **Type-Safe:** Uses GDUnit4's fluent assertion API for type safety

## GDUnit4 Assertion Patterns

### String Assertions
```gdscript
assert_str(value).is_equal("expected")
assert_str(value).is_empty()
```

### Integer Assertions
```gdscript
assert_int(value).is_equal(42)
assert_int(value).is_between(0, 100)
```

### Float Assertions
```gdscript
assert_float(value).is_equal(3.14)
assert_float(value).is_less_equal(100.0)
```

### Boolean Assertions
```gdscript
assert_bool(value).is_true()
assert_bool(value).is_false()
```

### Array Assertions
```gdscript
assert_array(array).has_size(5)
assert_array(array).contains("item")
assert_array(array).contains_exactly(["a", "b", "c"])
assert_array(array).is_empty()
```

### Object Assertions
```gdscript
assert_object(obj).is_null()
assert_object(obj).is_not_null()
assert_object(obj).is_instanceof(ClassName)
```

## Backward Compatibility Testing

All models include backward compatibility tests for:
- Legacy flat field formats (e.g., stats at player root vs. nested in stats_profile)
- Missing fields in old save files
- Type inference when explicit fields are absent
- Schema evolution over time

Example:
```gdscript
func test_player_from_dict_legacy_physicals_flat() -> void:
    var player = Player.new()
    var legacy_dict = {
        "id": "P_OLD",
        "height_in": 74.0,  # Flat at root, not in physicals sub-resource
        "weight_lb": 210.0
    }
    player.from_dict(legacy_dict)
    assert_float(player.physicals.height_in).is_equal(74.0)
```

## Test Maintenance Guidelines

1. **Add tests for new features:** When adding new model fields or methods, add corresponding tests
2. **Update tests when refactoring:** Keep tests in sync with model changes
3. **Mark deprecated patterns:** Document when old test patterns should be updated
4. **Run tests before committing:** Ensure all tests pass before pushing changes
5. **Review test coverage:** Periodically review test coverage reports

## Known Limitations

1. **No RNG tests yet:** Models don't currently use RNG, but when added, use TestHelpersGdUnit4.assert_deterministic
2. **No performance tests:** Currently focused on correctness; performance tests can be added later
3. **Limited integration tests:** These are unit tests; integration tests across models are separate

## Future Enhancements

1. Add property-based tests using GDUnit4 fuzzers
2. Add performance benchmarks for large rosters (100+ players)
3. Add integration tests for complex workflows (e.g., season progression)
4. Add mutation testing to verify test quality
5. Add code coverage reporting

## Related Files

- **Test Helpers:** `scripts/tests/TestHelpersGdUnit4.gd`
- **Models Directory:** `scripts/core/models/`
- **Engineer Protocols:** `docs/agents/ENGINEER_PROTOCOLS.md`
- **Agent Guidelines:** `AGENTS.md`

## Test Execution Time

Expected execution time (approximate):
- Contract tests: ~0.1s
- Coach tests: ~0.1s
- DepthChart tests: ~0.2s
- Roster tests: ~0.2s
- RosterEntry tests: ~0.2s
- Team tests: ~0.2s
- Player tests: ~0.3s

**Total expected time:** ~1.3 seconds for all 243 tests

---

**Generated by:** Claude Code Test Engineer
**Date:** 2026-01-23
**GDUnit4 Version:** v6.0.3
**Godot Version:** 4.5
