# Guardian Diagnostic Team - Summary Report
## Roster Management: 0 Releases Investigation

**Date**: 2026-01-13
**Team**: 3 Architecture Guardians
**Problem**: 0 releases across 10 years (seasons 20-29) in integration testing

---

## Guardian #1: DATA FLOW ANALYSIS ✓ COMPLETE

### Root Cause Identified

**CRITICAL DATA MODEL ISSUE**: Integration test contracts are missing the `annual_value` field required for cap calculations.

### Evidence Chain

1. **Contract Structure** (`test_g1_integration_season_simulation.gd:254`)
   ```gdscript
   "contract": {
       "years_remaining": 1 + (j % 4),
       "years_total": 4
       // MISSING: annual_value ❌
       // MISSING: signed_year ❌
   }
   ```

2. **Cap Calculation** (`RosterManagement.gd:288`)
   ```gdscript
   total += float(contract.get("annual_value", 0.0))  // Returns 0.0 when missing!
   ```

3. **Release Decision** (`RosterManagement.gd:194-203`)
   ```gdscript
   var current_cap_used := _calculate_team_cap_usage(players)  // = 0.0
   var current_cap_space := cap_limit - current_cap_used      // = 200.0 - 0.0 = 200.0

   if current_cap_space >= target_budget:  // 200.0 >= 35.0 = TRUE
       return {"releases": 0, ...}  // Early exit - no releases!
   ```

### Data Flow Diagram

```
Integration Test Data (Missing annual_value)
              ↓
Player Contracts: {years_remaining, years_total}
              ↓
_calculate_team_cap_usage() reads contract.get("annual_value", 0.0)
              ↓
Returns 0.0 (default value)
              ↓
Cap Space Calculation: 200M - 0M = 200M
              ↓
Comparison: 200M >= 35M (target) = TRUE
              ↓
Early Exit: Return 0 releases
```

### Impact Assessment

| System Component | Status | Impact |
|-----------------|--------|---------|
| Contract Data Model | ❌ Incomplete | Missing required field |
| Cap Calculation | ❌ Returns 0.0 | Silent failure |
| Release Decision Logic | ⚠️ Works correctly | But with wrong inputs |
| Unit Tests | ✓ Pass | Use correct structure |
| Integration Tests | ❌ Fail | Use incomplete structure |

### Verification Evidence

**File**: `GUARDIAN_1_DATA_FLOW_ANALYSIS.md` (Full detailed report)
**File**: `scripts/tests/test_roster_management_data_flow.gd` (Diagnostic test)

Run diagnostic:
```bash
godot --headless --script scripts/tests/test_roster_management_data_flow.gd
```

Expected output:
- Test 1 (without annual_value): 0 releases
- Test 2 (with annual_value): >0 releases
- Cap calculation tests: Confirm 0.0 return when field missing

---

## Guardian #2: LOGIC FLOW ANALYSIS 🔄 PENDING

### Areas to Investigate

**Given that contracts WILL have annual_value** (after fixing data), please verify:

1. **Release Candidate Identification**
   - Does `_identify_release_candidates()` correctly calculate cap inefficiency?
   - Formula: `cap_inefficiency = (annual_value / expected_value) * age_penalty`
   - Are thresholds appropriate? (inefficiency > 1.0)

2. **Candidate Sorting**
   - Is sorting by cap_inefficiency (descending) correct?
   - Tie-breaker logic (age > age) appropriate?

3. **Release Selection Loop**
   - Does it correctly accumulate cap savings?
   - Does it stop at needed_cap threshold?
   - Does it respect min_roster_size?

4. **Edge Cases to Test**
   - What if ALL players are efficient? (no candidates)
   - What if target budget > cap_limit?
   - What if roster already at min_roster_size?

### Test Data for Logic Testing

Use contracts with these characteristics:
```gdscript
// Overpaid veteran (should be released)
{
    "age": 34,
    "eval_score": 60.0,
    "contract": {
        "annual_value": 15.0,  // High salary
        "signed_year": 2020
    }
}

// Good value (should NOT be released)
{
    "age": 27,
    "eval_score": 85.0,
    "contract": {
        "annual_value": 8.0,   // Fair salary
        "signed_year": 2022
    }
}

// Rookie (should be PROTECTED)
{
    "age": 22,
    "eval_score": 70.0,
    "draft_year": 2023,
    "contract": {
        "annual_value": 2.0,
        "signed_year": 2023  // Same as draft_year = rookie
    }
}
```

---

## Guardian #3: EDGE CASES & BOUNDARY CONDITIONS 🔄 PENDING

### Areas to Investigate

1. **Rookie Contract Protection**
   - Logic: `is_rookie and years_since_draft < 3` should skip player
   - Test: Player with `signed_year == draft_year` and `year - draft_year < 3`
   - Edge: What if `draft_year` is missing?

2. **Dead Cap Calculation**
   - Currently placeholder returns 0.0
   - Logic: `net_savings = annual_value - dead_cap`
   - Edge: What if dead_cap > annual_value? (net_savings negative)
   - Current code: "Only release if net_savings > 0.0" (correct guard)

3. **Minimum Roster Size**
   - Config: `min_roster_size = 45`
   - Logic: `if remaining_roster_size <= min_roster_size: break`
   - Edge: What if initial roster < 45? (should not release anyone)

4. **Empty/Missing Data**
   - What if players array is empty?
   - What if contract is empty dict {}?
   - What if eval_score is missing?
   - What if age is missing?

5. **Extreme Values**
   - annual_value = 0.0 (undrafted FA)
   - annual_value > cap_limit (impossible but test)
   - eval_score = 0.0 (injured?)
   - age < 22 or age > 40

### Boundary Test Matrix

| Scenario | Input | Expected Behavior |
|----------|-------|-------------------|
| No contracts | players with empty contracts | Skip in cap calculation |
| All rookies | All players year - draft_year < 3 | 0 candidates, 0 releases |
| All efficient | All cap_inefficiency < 1.0 | 0 candidates, 0 releases |
| Min roster already | 45 players, need releases | Stop at 45, partial releases |
| Below min roster | 40 players | 0 releases (protect minimum) |
| Negative cap space | cap_used > cap_limit | Release until positive? |

---

## Critical Data Fixes Required

### Fix #1: Integration Test Contract Data

**File**: `scripts/tests/test_g1_integration_season_simulation.gd`
**Line**: 254

**Current** (BROKEN):
```gdscript
"contract": {
    "years_remaining": 1 + (j % 4),
    "years_total": 4
}
```

**Required** (FIXED):
```gdscript
"contract": {
    "annual_value": _generate_realistic_salary(position, age, eval_score),
    "signed_year": draft_year,
    "years_remaining": 1 + (j % 4),
    "years_total": 4
}
```

Helper function:
```gdscript
func _generate_realistic_salary(position: String, age: int, eval_score: float) -> float:
    var base := {"QB": 8.0, "RB": 2.5, "WR": 4.0, "TE": 3.0, "OL": 3.5}.get(position, 3.0)
    var age_mult := 1.0
    if age < 25: age_mult = 0.6
    elif age < 28: age_mult = 1.2
    elif age < 32: age_mult = 1.0
    else: age_mult = 0.8
    var perf_mult := eval_score / 75.0
    return clampf(base * age_mult * perf_mult * randf_range(0.8, 1.2), 0.5, 25.0)
```

### Fix #2: Add Contract Validation

**File**: `scripts/world/RosterManagement.gd`
**Location**: In `run()` function, after line 106

**Add**:
```gdscript
# Validate contract data (fail fast if incomplete)
var validation_errors := 0
for team in nfl_teams:
    var team_id := String(team.get("id", ""))
    var roster: Dictionary = nfl_rosters.get(team_id, {})
    var players: Array = roster.get("players", [])
    for player in players:
        var p: Dictionary = player
        var contract: Dictionary = p.get("contract", {})
        if not contract.is_empty() and not contract.has("annual_value"):
            SimLogger.error("Player %s has contract without annual_value" % p.get("id", "unknown"))
            validation_errors += 1

if validation_errors > 0:
    SimLogger.error("Found %d contracts missing annual_value. Cannot calculate cap usage." % validation_errors)
    return {
        "year": year,
        "teams_processed": 0,
        "total_releases": 0,
        "total_cap_saved": 0.0,
        "releases_by_team": {},
        "error": "Invalid contract data"
    }
```

### Fix #3: Add Draft Year to Test Data

**File**: `scripts/tests/test_g1_integration_season_simulation.gd`
**Line**: 250-254

**Add**:
```gdscript
var draft_year := 2020 + (j / 10)  // Spread players across draft classes
players.append({
    "player_id": "player_%s_%d" % [t["id"], j],
    "position": ["QB", "RB", "WR", "TE", "OL"][j % 5],
    "composite_score": 60.0 + randf() * 30.0,
    "age": 22 + (j % 10),
    "draft_year": draft_year,  // ADD THIS
    "contract": {
        "annual_value": _generate_realistic_salary(...),  // ADD THIS
        "signed_year": draft_year,  // ADD THIS
        "years_remaining": 1 + (j % 4),
        "years_total": 4
    }
})
```

---

## Collaboration Plan

### Phase 1: Data Fix (IMMEDIATE)
**Owner**: Guardian #1 (Complete - documented fixes above)
- Document missing fields
- Create diagnostic test
- Specify correct data structure

### Phase 2: Logic Verification (Guardian #2)
**Dependencies**: Needs fixed test data
- Run roster management with correct contracts
- Verify release candidates are identified
- Check sorting and selection logic
- Test edge cases (all efficient, no candidates)

### Phase 3: Edge Case Testing (Guardian #3)
**Dependencies**: Needs Phase 2 verification
- Test rookie protection logic
- Test minimum roster size enforcement
- Test extreme values
- Test missing/empty data handling

### Phase 4: Integration Validation (ALL)
**Dependencies**: Phases 1-3 complete
- Run 10-year simulation with fixed data
- Verify releases occur each year
- Check cap space trends
- Validate FA pool grows with releases

---

## Success Criteria

### Must Have (Phase 1)
- ✓ Root cause identified (missing annual_value)
- ✓ Diagnostic test created
- ✓ Fix specifications documented
- ⏳ Integration test data fixed

### Must Have (Phase 2)
- ⏳ Logic flow verified with correct data
- ⏳ Release candidates correctly identified
- ⏳ Releases executed when needed

### Must Have (Phase 3)
- ⏳ Rookie protection works
- ⏳ Min roster size enforced
- ⏳ Edge cases handled gracefully

### Must Have (Phase 4)
- ⏳ >0 releases across 10 years
- ⏳ Realistic release counts (10-50 per year across 32 teams)
- ⏳ Cap space correctly calculated
- ⏳ FA pool receives released players

---

## Files Created

1. `/GUARDIAN_1_DATA_FLOW_ANALYSIS.md` - Full architectural assessment
2. `/scripts/tests/test_roster_management_data_flow.gd` - Diagnostic test
3. `/GUARDIAN_DIAGNOSTIC_SUMMARY.md` - This file (coordination doc)

---

## Next Actions

**Guardian #2**:
1. Review Guardian #1 findings
2. Implement test data fixes in integration test
3. Run roster management with corrected data
4. Verify logic flow with realistic contracts
5. Report findings on candidate selection and sorting

**Guardian #3**:
1. Review Guardian #1 & #2 findings
2. Create edge case test suite
3. Test boundary conditions
4. Test error handling
5. Report findings on protection logic and constraints

**All Guardians**:
- Coordinate through this summary document
- Update status as phases complete
- Raise any blocking issues immediately

---

**Status**: Phase 1 Complete ✓ | Phase 2 Pending | Phase 3 Pending
**Blocker**: None (root cause identified, fixes specified)
**Confidence**: HIGH (data model issue is clear and fixable)
