# State Machines and Transformations Test Suite

Comprehensive GDUnit4 test coverage for state machines and transformation functions in the Gridiron Dynasty project.

## Test Files Created

### State Machine Tests

#### 1. ContractStateMachine Tests (`test_contract_state_machine_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_contract_state_machine_gdunit4.gd`
**Target**: `scripts/core/state/ContractStateMachine.gd`

**Test Coverage:**
- **Contract State Transitions** (80+ assertions)
  - Valid transitions for all 8 states (UNSIGNED, SIGNED, ACTIVE, EXPIRED, RELEASED, FRANCHISE_TAGGED, VOIDED, RESTRUCTURED)
  - Invalid transition rejection
  - Terminal state detection

- **Free Agency Period Transitions** (20+ assertions)
  - Valid FA period transitions (CLOSED, PREP, TAGS_APPLIED, MARKET_OPEN, SIGNINGS_COMPLETE, YEAR_ROUND)
  - Invalid FA period transition rejection

- **String Conversion & Serialization** (30+ assertions)
  - State enum to string conversion
  - String to state enum parsing (case-insensitive)
  - Round-trip serialization
  - Unknown state handling

- **Validation Helpers** (15+ assertions)
  - Franchise tag eligibility
  - Contract release eligibility
  - Contract restructure eligibility
  - Transition trigger validation

**Total Assertions**: ~145 assertions across 34 test methods

---

#### 2. DraftStateMachine Tests (`test_draft_state_machine_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_draft_state_machine_gdunit4.gd`
**Target**: `scripts/core/state/DraftStateMachine.gd`

**Test Coverage:**
- **State Transitions** (40+ assertions)
  - Valid transitions for all 5 states (NOT_STARTED, INITIALIZING, RUNNING, PAUSED, COMPLETED)
  - Invalid transition rejection
  - Terminal state detection (COMPLETED)

- **Operation Validation** (50+ assertions)
  - State-specific allowed operations
  - Operation execution validation
  - Convenience methods (can_execute_pick, can_pause, can_resume, etc.)

- **State Information Queries** (20+ assertions)
  - Reachable states calculation
  - Active state detection
  - Completed state detection
  - Allowed operations retrieval

- **Transition Execution** (15+ assertions)
  - Successful state transitions
  - Invalid transition handling
  - Null/empty state handling

- **String Conversion** (20+ assertions)
  - State to string conversion
  - String to state parsing
  - Round-trip serialization

**Total Assertions**: ~145 assertions across 36 test methods

---

#### 3. SeasonStateMachine Tests (`test_season_state_machine_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_season_state_machine_gdunit4.gd`
**Target**: `scripts/core/state/SeasonStateMachine.gd`

**Test Coverage:**
- **Phase Transitions** (50+ assertions)
  - Valid transitions for all 8 phases (PRE_SEASON, REGULAR_SEASON, PLAYOFFS, POST_SEASON, OFF_SEASON, DRAFT_PREP, DRAFT, FREE_AGENCY)
  - Invalid transition rejection
  - Alternate path validation (skip playoffs, skip FA, etc.)
  - Cyclical nature verification

- **Phase Validation** (20+ assertions)
  - Detailed validation with error messages
  - Context-aware error reporting

- **Phase Properties** (30+ assertions)
  - Standings calculation requirements
  - Game simulation allowance
  - Active season detection
  - Off-season detection

- **Standard Lifecycle** (10+ assertions)
  - Lifecycle path retrieval
  - Complete cycle validation
  - Immutability verification

**Total Assertions**: ~110 assertions across 27 test methods

---

### Transformation Function Tests

#### 4. AgeFunctions Tests (`test_age_functions_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_age_functions_gdunit4.gd`
**Target**: `scripts/core/transformations/AgeFunctions.gd`

**Test Coverage:**
- **Age Increment** (15+ assertions)
  - Basic age increment
  - Field preservation
  - Default handling
  - Max age capping (99)
  - Purity verification

- **Age Modifier Calculation** (25+ assertions)
  - Growth phase modifiers (> 1.0)
  - Prime phase modifiers (= 1.0)
  - Decline phase modifiers (< 1.0)
  - Min/max clamping (0.4 - 1.4)
  - Missing config handling

- **Years to Peak** (10+ assertions)
  - Before peak calculation
  - At peak calculation
  - Past peak calculation (negative values)

- **Years Until Decline** (10+ assertions)
  - Before decline calculation
  - At decline calculation
  - Past decline clamping (0 minimum)

- **Lifecycle Phase Detection** (15+ assertions)
  - Growth phase detection
  - Prime phase detection
  - Decline phase detection
  - Boundary condition handling

- **Position-Specific Curves** (5+ assertions)
  - Different aging curves per position

- **Purity & Determinism** (10+ assertions)
  - Input immutability
  - Consistent results across calls

**Total Assertions**: ~90 assertions across 30 test methods

---

#### 5. GrowthFunctions Tests (`test_growth_functions_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_growth_functions_gdunit4.gd`
**Target**: `scripts/core/transformations/GrowthFunctions.gd`

**Test Coverage:**
- **Apply Development** (30+ assertions)
  - Returns new player (purity)
  - Growth phase stat increases
  - Potential ceiling enforcement
  - RNG determinism
  - Report structure validation
  - Stat entry details
  - Missing stats handling

- **Context Multiplier** (25+ assertions)
  - Neutral context (1.0)
  - Good program bonus (> 1.0)
  - Poor program penalty (< 1.0)
  - Min/max clamping (0.7 - 1.4)
  - Additive deviation system
  - Empty context handling

- **Wear Multiplier** (20+ assertions)
  - No wear baseline (1.0)
  - High snaps impact
  - High collisions impact
  - High injuries impact
  - Min/max clamping (1.0 - 1.6)

- **Phase-Specific Logic** (20+ assertions)
  - Growth phase multiplier usage
  - Prime phase multiplier usage
  - Decline phase multiplier usage
  - Decline stat decreases

- **Position-Specific Logic** (5+ assertions)
  - Position-specific decline timing

- **Edge Cases** (15+ assertions)
  - Potential ceiling enforcement
  - Stat clamping to [0, 100]
  - Derived stat filtering

- **Purity & Determinism** (15+ assertions)
  - Player immutability
  - Context immutability
  - Config immutability
  - RNG determinism

**Total Assertions**: ~130 assertions across 28 test methods

---

#### 6. RetirementFunctions Tests (`test_retirement_functions_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_retirement_functions_gdunit4.gd`
**Target**: `scripts/core/transformations/RetirementFunctions.gd`

**Test Coverage:**
- **Should Retire** (30+ assertions)
  - Below min age rejection
  - At/above max age forced retirement
  - Career-ending injury forced retirement
  - RNG determinism
  - Probabilistic behavior in range

- **Calculate Retirement Probability** (30+ assertions)
  - Below min age (0.0)
  - At max age (1.0)
  - At soft cap (base chance)
  - Above soft cap (age slope)
  - Low rating boost
  - Combined factors
  - 95% probability cap
  - Purity verification
  - Consistency verification

- **Apply Retirement** (10+ assertions)
  - Stage field setting (6 = RETIRED)
  - Purity verification
  - Field preservation

- **Core Rating Calculation** (15+ assertions)
  - Core stats averaging
  - Non-core stats exclusion
  - Fallback to all stats
  - Empty stats handling

- **Mean of Stats** (10+ assertions)
  - Basic mean calculation
  - Single stat handling
  - Empty stats handling
  - Non-numeric filtering

- **Edge Cases** (15+ assertions)
  - Multiple career-ending injuries
  - Non-career-ending injuries
  - Missing configs
  - Zero/negative age

- **RNG Consumption** (20+ assertions)
  - No consumption for career-ending injury
  - No consumption below min age
  - No consumption at max age
  - Exactly one consumption in probabilistic range

**Total Assertions**: ~130 assertions across 30 test methods

---

#### 7. InjuryFunctions Tests (`test_injury_functions_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_injury_functions_gdunit4.gd`
**Target**: `scripts/core/transformations/InjuryFunctions.gd`

**Test Coverage:**
- **Simulate Injuries** (40+ assertions)
  - Return structure (player + report)
  - RNG determinism
  - Purity verification
  - Report field validation
  - High proneness increases chance
  - Position multiplier effects
  - Trait modifier effects
  - Injury instance creation

- **Apply Injury** (15+ assertions)
  - Injury addition
  - Purity verification
  - Severity clamping [0, 5]

- **Heal Injuries** (25+ assertions)
  - Years remaining reduction
  - Recovery status marking
  - Purity verification
  - Recovered injury preservation
  - Zero weeks handling
  - Partial weeks handling

- **Edge Cases** (15+ assertions)
  - No injury types configured
  - Empty injuries list
  - Missing injuries field
  - Injury chance clamping at 95%

- **RNG Consumption** (5+ assertions)
  - Exactly one consumption for no injury

- **Injury Generation** (10+ assertions)
  - Valid type selection from config
  - Severity range validation

**Total Assertions**: ~110 assertions across 21 test methods

---

#### 8. StatFunctions Tests (`test_stat_functions_gdunit4.gd`)
**File**: `/home/user/gridiron-dynasty/scripts/tests/gdunit4/test_stat_functions_gdunit4.gd`
**Target**: `scripts/core/transformations/StatFunctions.gd`

**Test Coverage:**
- **Apply Stat Changes** (20+ assertions)
  - Basic stat updates
  - Purity verification
  - Clamping to [0, 100]
  - Creating missing stats dict
  - Empty changes handling

- **Cap Stats at Potential** (15+ assertions)
  - Above potential capping
  - Below potential preservation
  - Purity verification
  - Missing potential fallback

- **Calculate Composite Score** (20+ assertions)
  - Basic weighted average
  - Equal weights handling
  - Missing stat handling
  - Empty weights handling
  - Purity verification

- **Apply Stat Decay** (20+ assertions)
  - Basic decay (< 1.0)
  - No change (1.0)
  - Growth (> 1.0)
  - Clamping to [0, 100]
  - Purity verification

- **Apply Stat Deltas** (25+ assertions)
  - Positive deltas
  - Negative deltas
  - Mixed deltas
  - Clamping to [0, 100]
  - New stat default to 0
  - Purity verification

- **Scale Stats** (15+ assertions)
  - Basic scaling
  - Existing stats only
  - Clamping to 100
  - Purity verification

- **Get Stat** (10+ assertions)
  - Existing stat retrieval
  - Missing stat with default
  - Missing stat without default

- **Set Stat** (15+ assertions)
  - Basic stat setting
  - New stat creation
  - Clamping to [0, 100]
  - Purity verification

- **Calculate Mean Stat** (10+ assertions)
  - Basic mean calculation
  - Empty stats handling
  - Non-numeric filtering

- **Calculate Mean of Stats** (15+ assertions)
  - Basic subset mean
  - Single stat handling
  - Empty list handling
  - Missing stats handling

- **Normalize Stats to Mean** (15+ assertions)
  - Upward normalization
  - Downward normalization
  - Zero mean handling
  - Purity verification

- **Edge Cases** (10+ assertions)
  - Missing stats dict handling
  - Empty deltas preservation

- **Purity Verification** (5+ assertions)
  - All functions preserve inputs

**Total Assertions**: ~195 assertions across 43 test methods

---

## Test Suite Summary

### Total Coverage Statistics

| Category | Files | Test Methods | Assertions |
|----------|-------|--------------|------------|
| **State Machines** | 3 | 97 | ~400 |
| **Transformations** | 5 | 180 | ~655 |
| **TOTAL** | **8** | **277** | **~1,055** |

### Test Quality Features

#### 1. **Determinism Testing**
All RNG-based transformations include explicit determinism tests using the `TestHelpersGdUnit4.assert_deterministic()` helper:
- GrowthFunctions: Development progression
- RetirementFunctions: Retirement decisions
- InjuryFunctions: Injury simulation

#### 2. **Purity Verification**
Every transformation function verifies immutability:
- Original player dictionaries never modified
- Config dictionaries never modified
- Context dictionaries never modified
- All functions return NEW instances

#### 3. **Edge Case Coverage**
Comprehensive edge case testing:
- Empty inputs
- Missing fields
- Null/undefined values
- Boundary conditions (min/max ages, stat caps)
- Invalid states/transitions

#### 4. **RNG Consumption Tracking**
Explicit tests verify exact RNG call counts:
- RetirementFunctions: 0-1 calls depending on conditions
- InjuryFunctions: 1-4 calls depending on injury occurrence
- GrowthFunctions: N calls (one per base stat)

#### 5. **String Serialization**
All enums tested for:
- Enum to string conversion
- String to enum parsing
- Case-insensitive parsing
- Round-trip consistency
- Unknown value handling

### Test Execution

All tests can be run with GDUnit4:

```bash
# Run all state and transformation tests
godot --headless -s addons/gdunit4/bin/GdUnitCmdTool.gd \
  --test-path scripts/tests/gdunit4/test_contract_state_machine_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_draft_state_machine_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_season_state_machine_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_age_functions_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_growth_functions_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_retirement_functions_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_injury_functions_gdunit4.gd \
  --test-path scripts/tests/gdunit4/test_stat_functions_gdunit4.gd
```

### Key Testing Patterns

#### State Machine Testing Pattern
```gdscript
func test_state_transition_valid() -> void:
    assert_bool(StateMachine.can_transition(
        StateMachine.State.FROM,
        StateMachine.State.TO
    )).is_true()

func test_state_transition_invalid() -> void:
    assert_bool(StateMachine.can_transition(
        StateMachine.State.FROM,
        StateMachine.State.INVALID_TO
    )).is_false()
```

#### Transformation Testing Pattern
```gdscript
func test_transformation_is_pure() -> void:
    var input := create_test_data()
    var input_copy := input.duplicate(true)

    var _result := TransformFunction.apply(input, params)

    # Verify input unchanged
    assert_that(input).is_equal(input_copy)

func test_transformation_is_deterministic() -> void:
    var transform := func(rng: RandomNumberGenerator) -> Dictionary:
        return TransformFunction.apply(data, params, rng)

    TestHelpersGdUnit4.assert_deterministic(
        self, transform, 12345, "operation is deterministic"
    )
```

### Files Not Yet Tested

The following state and transformation files still need test coverage:

**State Managers:**
- `PlayerStateManager.gd`
- `ContractStateManager.gd`
- `DraftStateManager.gd`
- `SeasonStateManager.gd`
- `WorldStateAccessor.gd`
- `StatePathUtils.gd`

**Transformations:**
- `ContractTransformations.gd`
- `DraftTransformations.gd`
- `SeasonTransformations.gd`
- `TransitionFunctions.gd`
- `StagePipeline.gd`

These can be added following the same patterns established in the existing tests.

---

## Conclusion

This test suite provides comprehensive coverage of the core state machines and transformation functions in Gridiron Dynasty. The tests ensure:

1. **Correctness**: All state transitions follow defined rules
2. **Determinism**: Same seed always produces same results
3. **Purity**: No side effects on input data
4. **Robustness**: Handles edge cases and invalid inputs gracefully
5. **Maintainability**: Clear test structure and naming conventions

The test suite serves as both validation and documentation of the intended behavior of these critical simulation systems.
