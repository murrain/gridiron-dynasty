# Architecture Guardian #1: Data Flow Analysis Report
## Roster Management - Zero Releases Investigation

**Date**: 2026-01-13
**Guardian**: Architecture Guardian #1
**Focus**: Contract Structure & Data Flow from Contracts → Cap Calculation → Release Decisions

---

## EXECUTIVE SUMMARY

**ROOT CAUSE IDENTIFIED**: Integration test data is missing the `annual_value` field in player contracts, causing all cap calculations to return 0.0, which makes teams appear to have infinite cap space.

**Impact**: 0 releases across 10 years (seasons 20-29) because every team has `current_cap_space >= target_budget` due to incorrect cap calculation.

---

## ARCHITECTURAL ASSESSMENT

### Impact Scope
- **Contract Data Model**: Missing required field `annual_value`
- **Cap Calculation System**: `RosterManagement._calculate_team_cap_usage()`
- **Release Decision Logic**: `_process_team_roster()` early exit condition
- **Test Data Factory**: `test_g1_integration_season_simulation.gd::_create_test_nfl_world_state()`

---

## DETAILED DATA FLOW ANALYSIS

### 1. CONTRACT STRUCTURE ANALYSIS

**Expected Contract Structure** (per RosterManagement.gd requirements):
```gdscript
{
    "annual_value": float,  // REQUIRED for cap calculations
    "years_remaining": int,
    "years_total": int,
    "signed_year": int,     // Used for rookie contract protection
    "status": string        // Optional
}
```

**Actual Contract Structure** (from integration test, line 254):
```gdscript
{
    "years_remaining": 1 + (j % 4),
    "years_total": 4
    // MISSING: annual_value
    // MISSING: signed_year
}
```

**Data Model Verdict**: ❌ **INCOMPLETE CONTRACT DATA MODEL**

The integration test creates contracts WITHOUT the `annual_value` field that is CRITICAL for roster management calculations.

---

### 2. CAP CALCULATION PATH TRACE

**Function**: `RosterManagement._calculate_team_cap_usage()`
**Location**: `/scripts/world/RosterManagement.gd`, lines 283-291

```gdscript
static func _calculate_team_cap_usage(players: Array) -> float:
    var total := 0.0
    for player in players:
        var p: Dictionary = player
        var contract: Dictionary = p.get("contract", {})
        if contract.is_empty():
            continue
        total += float(contract.get("annual_value", 0.0))  // <-- RETURNS 0.0 when field missing!
    return total
```

**Execution Flow with Missing annual_value**:
1. Loop through 53 players per team
2. Each contract.get("annual_value", 0.0) returns **0.0** (default value)
3. Total cap usage = 0.0 + 0.0 + ... + 0.0 = **0.0M**
4. Return 0.0

**Cap Calculation Verdict**: ❌ **RETURNS 0.0 FOR ALL TEAMS**

With missing `annual_value`, every team appears to be using $0M against the cap.

---

### 3. TARGET BUDGET ANALYSIS

**Configuration** (from `/configs/sports/american_football/main.json`):
```json
"roster_management": {
    "target_fa_budget_min": 30.0,
    "target_fa_budget_max": 50.0,
    "value_threshold": 1.5,
    "age_decline_factor": 0.02,
    "min_roster_size": 45
}
```

**League Cap Limit** (from `/configs/sports/american_football/world/league.json`):
```json
"cap_limit": 200.0
```

**Target Budget Calculation** (per team, randomized):
- Target FA Budget: Random between $30M - $50M
- League Cap Limit: $200M

**Release Decision Logic** (`_process_team_roster()`, lines 192-203):
```gdscript
// Calculate current cap space
var current_cap_used := _calculate_team_cap_usage(players)  // Returns 0.0!
var current_cap_space := cap_limit - current_cap_used      // 200.0 - 0.0 = 200.0

// Check if we need to release players
if current_cap_space >= target_budget:  // 200.0 >= 35.0 (example) = TRUE
    // Team already has enough cap space
    return {
        "releases": 0,
        "cap_saved": 0.0,
        "released_players": []
    }
```

**Budget Analysis Verdict**: ❌ **EARLY EXIT - TEAMS HAVE "INFINITE" CAP SPACE**

With `current_cap_used = 0.0`, every team has `current_cap_space = 200.0M`, which is ALWAYS greater than target budget (30-50M), causing immediate early exit without evaluating any release candidates.

---

### 4. DATA MODEL VERIFICATION

**Unit Test Contracts** (`test_roster_management_unit.gd`, lines 36-40):
```gdscript
"contract": {
    "annual_value": 15.0,      // ✓ PRESENT
    "signed_year": 2015,       // ✓ PRESENT
    "years_remaining": 1
}
```

**Integration Test Contracts** (`test_g1_integration_season_simulation.gd`, line 254):
```gdscript
"contract": {
    "years_remaining": 1 + (j % 4),
    "years_total": 4
    // ❌ MISSING: annual_value
    // ❌ MISSING: signed_year
}
```

**Data Model Consistency Verdict**: ❌ **INCONSISTENT DATA MODELS**

Unit tests use complete contract structure with `annual_value`, but integration tests omit this critical field.

---

## ROOT CAUSE CONCLUSION

**WHY teams aren't releasing players**:

1. ❌ **Missing Contract Data**: Integration tests create contracts WITHOUT `annual_value` field
2. ❌ **Incorrect Cap Calculations**: `_calculate_team_cap_usage()` returns 0.0 when annual_value is missing
3. ❌ **Teams Already Have Enough Space**: With 0.0 cap usage, teams have 200M cap space vs 30-50M target
4. ❌ **Early Exit in Logic**: Code exits before evaluating release candidates

**Is it**:
- Missing contract data? ✓ **YES** - `annual_value` field missing
- Incorrect cap calculations? ✓ **YES** - Returns 0.0 due to missing data
- Teams already have enough space? ✓ **YES** - But only because of data issue
- Something else? ❌ **NO** - The logic is correct, data is wrong

---

## ARCHITECTURAL VIOLATIONS IDENTIFIED

### 1. **Incomplete Data Model Contract**
**Violation**: Integration tests do not create contracts that satisfy the RosterManagement system's data requirements.

**Contract**: RosterManagement expects contracts to have:
- `annual_value` (float) - REQUIRED for cap calculations
- `signed_year` (int) - REQUIRED for rookie protection logic
- `years_remaining` (int) - Optional
- `years_total` (int) - Optional

**Current State**: Integration tests only provide `years_remaining` and `years_total`.

### 2. **Missing Data Validation**
**Violation**: RosterManagement system does not validate contract structure at entry point.

**Risk**: Silent failures - system returns 0.0 cap usage instead of failing loudly when data is incomplete.

**Recommendation**: Add contract validation at `run()` entry point:
```gdscript
static func _validate_contract(contract: Dictionary) -> bool:
    if not contract.has("annual_value"):
        SimLogger.error("Contract missing required field: annual_value")
        return false
    return true
```

### 3. **Test Data Factory Divergence**
**Violation**: Unit test factories and integration test factories create different contract structures.

**Risk**: Tests pass in isolation but fail in integration due to data model inconsistency.

**Recommendation**: Create shared contract factory function:
```gdscript
static func create_test_contract(annual_value: float, signed_year: int) -> Dictionary:
    return {
        "annual_value": annual_value,
        "signed_year": signed_year,
        "years_remaining": 3,
        "years_total": 4
    }
```

---

## PERSISTENCE STRATEGY IMPACT

**Contract Serialization**: If world_state is saved/loaded, contracts must include `annual_value` field.

**Migration Path**: Existing world states without `annual_value` will silently fail cap calculations.

**Recommendation**:
1. Add migration logic to populate `annual_value` for existing contracts
2. Add schema version to contracts for future-proofing
3. Document contract structure in central location

---

## RECOMMENDATIONS

### Immediate Fixes (Guardian #2 & #3)

1. **Fix Integration Test Data** (Priority: CRITICAL)
   - Add `annual_value` to all contracts in `_create_test_nfl_world_state()`
   - Add `signed_year` to enable rookie protection logic
   - Use realistic salary values (e.g., 2M-20M range)

2. **Add Contract Validation** (Priority: HIGH)
   - Validate contract structure at `RosterManagement.run()` entry
   - Log errors for missing required fields
   - Fail fast instead of silent 0.0 returns

3. **Create Shared Test Utilities** (Priority: MEDIUM)
   - Centralize contract creation logic
   - Ensure consistency between unit and integration tests
   - Document required contract fields

### Architectural Improvements (Future)

1. **Contract Data Model Documentation**
   - Create canonical contract structure specification
   - Document which systems require which fields
   - Add field-level documentation

2. **Contract Factory Pattern**
   - Create ContractFactory.gd for standardized contract creation
   - Support different contract types (rookie, veteran, FA signing)
   - Include validation in factory

3. **Schema Versioning**
   - Add "schema_version" to contracts
   - Enable migration logic for breaking changes
   - Support backward compatibility

---

## EVIDENCE FILES

1. `/scripts/world/RosterManagement.gd` (lines 283-291) - Cap calculation logic
2. `/scripts/world/RosterManagement.gd` (lines 192-203) - Early exit condition
3. `/scripts/tests/test_g1_integration_season_simulation.gd` (line 254) - Missing annual_value
4. `/scripts/tests/test_roster_management_unit.gd` (lines 36-40) - Correct structure
5. `/configs/sports/american_football/main.json` - Roster management config
6. `/configs/sports/american_football/world/league.json` - Cap limit config

---

## GUARDIAN #1 VERDICT

**Decision**: ❌ **REJECTED** - Integration test data model is architecturally unsound

**Rationale**:
1. Contract structure is incomplete and violates RosterManagement's data requirements
2. Silent failures mask data issues instead of failing loudly
3. Test data factories have diverged, causing unit/integration test inconsistency
4. System boundary contract (expected fields) is not enforced or validated

**Required Modifications**:
1. Add `annual_value` field to all player contracts in integration tests
2. Add `signed_year` field for rookie contract protection
3. Implement contract validation at RosterManagement entry point
4. Create shared contract factory for test data consistency

**Blocking Issues**:
- Integration tests cannot validate roster management without correct contract data
- Silent 0.0 cap calculations create false confidence in system correctness
- Data model inconsistency will cause production failures

---

## HANDOFF TO GUARDIANS #2 & #3

**Guardian #2 (Logic Flow)**: Please verify:
1. Release candidate identification logic (assuming correct cap data)
2. Cap inefficiency calculation formula
3. Sorting and selection algorithm

**Guardian #3 (Edge Cases)**: Please verify:
1. Minimum roster size enforcement
2. Rookie contract protection logic
3. Behavior when NO release candidates exist (all efficient contracts)
4. Dead cap calculation placeholder impact

**Critical Data to Share**:
- Integration test contracts need `annual_value` between 2.0-20.0M (realistic NFL range)
- Draft contracts should have `annual_value` matching rookie scale (0.5-5.0M)
- FA signings need `annual_value` from ContractNegotiation system
- All contracts need `signed_year` = draft_year for rookie protection

---

**Report Completed**: 2026-01-13
**Status**: ROOT CAUSE IDENTIFIED - DATA MODEL INCOMPLETE
**Next Action**: Fix integration test contract data + add validation
