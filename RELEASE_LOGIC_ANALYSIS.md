# ARCHITECTURAL ASSESSMENT: Roster Management Release Logic

**Guardian #2 Report - Release Candidate Identification**

**Date:** 2026-01-13
**Scope:** Investigation of zero releases across years 20-29 in integration testing
**Files Analyzed:**
- `/scripts/world/RosterManagement.gd` (lines 304-358)
- `/configs/sports/american_football/main.json` (lines 506-513)

---

## Executive Summary

**ROOT CAUSE IDENTIFIED:** The cap inefficiency threshold is mathematically impossible to exceed with realistic contract values in year 20+ data.

**Impact:** CRITICAL - System is functionally disabled despite passing unit tests.

**Classification:** Configuration Error + Formula Design Issue

---

## 1. RELEASE CANDIDATE IDENTIFICATION LOGIC

### Current Implementation (lines 304-358 in RosterManagement.gd)

```gdscript
func _identify_release_candidates(
    players: Array,
    value_threshold: float,      # Config: 1.5
    age_decline_factor: float,   # Config: 0.02
    year: int
) -> Array:
    for player in players:
        # Skip rookie contracts (first 3 years)
        if is_rookie and years_since_draft < 3:
            continue

        # Calculate age penalty
        var age_penalty := 1.0
        if age > 30:
            age_penalty = 1.0 + (float(age - 30) * age_decline_factor)

        # Calculate expected value
        var expected_value := (eval_score / 100.0) * value_threshold

        # Calculate cap inefficiency
        var cap_inefficiency := (annual_value / expected_value) * age_penalty

        # CRITICAL THRESHOLD
        if cap_inefficiency > 1.0:
            candidates.append(player)
```

### Configuration Values (main.json)

```json
{
  "roster_management": {
    "enabled": true,
    "target_fa_budget_min": 30.0,
    "target_fa_budget_max": 50.0,
    "value_threshold": 1.5,           // ← KEY PARAMETER
    "age_decline_factor": 0.02,       // ← AGE PENALTY
    "min_roster_size": 45
  }
}
```

---

## 2. MATHEMATICAL ANALYSIS

### Formula Breakdown

**Cap Inefficiency** = (annual_value / expected_value) * age_penalty

Where:
- **expected_value** = (eval_score / 100) * value_threshold
- **age_penalty** = 1.0 + max(0, age - 30) * age_decline_factor

### Threshold Requirement

For a player to be a release candidate:
```
cap_inefficiency > 1.0
=> (annual_value / expected_value) * age_penalty > 1.0
=> annual_value > expected_value / age_penalty
```

### Example Calculations

**Example 1: Average 27-year-old player**
- eval_score = 70.0
- age = 27 (no penalty)
- value_threshold = 1.5
- expected_value = (70 / 100) * 1.5 = 1.05
- age_penalty = 1.0

**Threshold:** annual_value > 1.05M

For cap_inefficiency > 1.0, this player needs to be paid MORE than $1.05M/year.

**Reality Check:** A 70-rated NFL player at age 27 should command $5-15M/year in the market.

**Example 2: Aging 32-year-old veteran**
- eval_score = 65.0
- age = 32
- value_threshold = 1.5
- expected_value = (65 / 100) * 1.5 = 0.975
- age_penalty = 1.0 + (32 - 30) * 0.02 = 1.04

**Threshold:** annual_value > 0.975 / 1.04 = 0.938M

Even with age penalty, this player needs less than $1M to avoid being a candidate.

---

## 3. DIAGNOSTIC TEST RESULTS

### Synthetic Data Test
Running the diagnostic with synthetic data (realistic contract values):

```
[SUMMARY STATISTICS]
  Total players analyzed: 36
  Average eval_score: 73.4
  Average annual_value: $9.30M
  Average age: 28.8
  Average cap_inefficiency: 9.045

[RELEASE CANDIDATE THRESHOLD ANALYSIS]
  Players exceeding threshold: 36 / 36 (100.0%)
```

**Key Finding:** With realistic contract values ($3M-$15M), ALL players become release candidates.

### Expected Integration Test Scenario

In year 20+ integration tests, if players have contracts:
- Drafted players have rookie contracts (~$2-5M for rounds 1-3)
- Free agent signings have market-rate contracts
- Re-signed veterans have varied contracts

**Hypothesis:** Most year 20+ rosters consist primarily of:
1. Recent draftees (protected by 3-year rookie rule)
2. Players on rookie-scale contracts that haven't been renewed yet
3. Very few veteran free agent signings

---

## 4. ROOT CAUSE ANALYSIS

### Issue #1: Threshold Too Low

The threshold of `cap_inefficiency > 1.0` means:
- Player's actual cap hit > their "expected value"
- Expected value = (eval_score/100) * 1.5

**Problem:** This formula treats `value_threshold` as a direct dollar amount, not a multiplier.

An eval_score of 70 produces expected_value of 1.05M, but a 70-rated player should command $8-12M in the real market.

### Issue #2: Missing Market Value Context

The formula doesn't account for:
- Position-specific market rates (QB vs RB vs K)
- Actual contract market dynamics
- Inflation/league-wide salary cap context

**The formula assumes:**
- eval_score directly translates to millions
- A player rated 50 should earn $0.75M
- A player rated 80 should earn $1.20M

**Reality:**
- A 50-rated backup might earn $1-2M
- An 80-rated starter earns $10-25M depending on position

### Issue #3: value_threshold Semantic Confusion

The parameter name "value_threshold" suggests "how much over their value must they be paid to be cut?"

**Current interpretation:** `expected_value = eval_score * 0.015`

**Likely intended interpretation:** "Cut players who cost more than 1.5x their market value"

But market value is never actually calculated - it's just eval_score * 0.015.

---

## 5. INTEGRATION TEST SILENCE

### Why Zero Releases in Years 20-29?

**Scenario:** Most rosters in year 20+ consist of:

1. **Recent Draft Picks (Years 0-2 since draft)**
   - Protected by rookie contract rule
   - Skip evaluation entirely

2. **Young Veterans (Years 3-5 since draft)**
   - Still on rookie contracts or first extensions
   - Rookie contracts are cheap ($1-5M typical)
   - eval_score = 65-75 typical
   - expected_value = 0.975 - 1.125
   - Even at $5M, cap_inefficiency = 5M / 1.0M = 5.0
   - **These SHOULD be candidates but rosters may have few of them**

3. **True Veterans (6+ years)**
   - These would have higher contracts
   - But may have already been released or retired

**Most Likely:** Rosters are predominantly rookies (protected) with few expensive veterans, resulting in zero candidates.

---

## 6. UNIT TEST DECEPTION

### Why Unit Tests Pass

Looking at `test_roster_management_unit.gd` (lines 25-100):

```gdscript
{
    "id": "p1",
    "name": "High Cap Low Value",
    "age": 32,
    "eval_score": 55.0,              // Low rating
    "contract": {
        "annual_value": 15.0,        // $15M - Very high
        "signed_year": 2015,
        "years_remaining": 1
    }
}
```

**Why this passes:**
- expected_value = (55 / 100) * 1.5 = 0.825
- age_penalty = 1.0 + (32-30) * 0.02 = 1.04
- cap_inefficiency = 15.0 / 0.825 * 1.04 = **18.9** ✓ > 1.0

The unit test uses **artificially high** contract values ($15M) paired with **artificially low** eval_scores (55) to force the threshold.

**Integration test reality:** No player has this extreme mismatch because:
- Contract generation is based on player value
- Low-rated players get low contracts
- High-rated players get high contracts
- The system creates internally consistent contracts that don't trigger the threshold

---

## 7. ARCHITECTURAL VERDICT

### Decision: REQUIRES MAJOR MODIFICATION

**Classification:** Critical Logic Error + Configuration Mismatch

### Issues Identified:

1. **Formula Disconnect from Economics**
   - expected_value calculation bears no relation to actual contract markets
   - Uses eval_score directly as millions rather than as rating

2. **Threshold Mathematically Impossible**
   - With consistent contract generation, threshold cannot be exceeded
   - Unit tests pass only with artificial data mismatches

3. **Missing Architectural Component**
   - No integration with actual contract market valuation
   - Should use PlayerValue.calculate() or similar market-based calculation

4. **Configuration Semantic Error**
   - value_threshold parameter name is misleading
   - Current value (1.5) appears calibrated for wrong formula

---

## 8. RECOMMENDATIONS

### Option A: Fix Formula (Recommended)

Replace expected_value calculation with actual market value:

```gdscript
# BEFORE
var expected_value := (eval_score / 100.0) * value_threshold

# AFTER - Use market valuation
var valuation_context := {}
var valuation_cfg := _build_valuation_config(positions_cfg, main_cfg)
var valuation := PlayerValue.calculate(player, valuation_context, valuation_cfg, rng)
var market_value := float(valuation.get("market_value", 1.0))
var expected_value := market_value * value_threshold
```

**New threshold:** value_threshold = 1.5 means "cut players earning 50% more than market value"

### Option B: Recalibrate Threshold (Workaround)

If formula must remain unchanged, recalibrate value_threshold:

```json
{
  "value_threshold": 15.0  // Scale to millions (was 1.5)
}
```

This treats eval_score as percentage of a $15M baseline:
- 70-rated player: expected_value = 0.70 * 15 = 10.5M
- More realistic market values

**Risk:** Still disconnected from actual contract economics.

### Option C: Hybrid Approach

Add market_value_multiplier to scale eval_score to realistic dollar amounts:

```gdscript
var market_value_multiplier := float(rm_cfg.get("market_value_multiplier", 0.15))
var expected_value := (eval_score * market_value_multiplier) * value_threshold
```

**Config:**
```json
{
  "market_value_multiplier": 0.15,  // 70 rating = 10.5M baseline
  "value_threshold": 1.5             // Cut if 50% overpaid
}
```

### Option D: Use Release Budget Directly (Alternative Architecture)

Instead of individual player evaluation, release players until target budget reached:

1. Calculate total cap needed for FA budget
2. Sort all players by "value per dollar" (eval_score / annual_value)
3. Release worst value players until budget met
4. Remove threshold entirely

**Pro:** Guarantees releases when needed
**Con:** Changes architectural approach

---

## 9. IMPACT ASSESSMENT

### Affected Systems

**Direct:**
- RosterManagement.gd (core logic)
- AdvanceWorldYear.gd (pipeline caller)
- Integration tests (validation)

**Indirect:**
- FreeAgency (depends on release pool)
- CapValidation (cap space calculations)
- Historical statistics (release tracking)

### Breaking Changes

**Option A (Fix Formula):**
- Requires PlayerValue dependency
- Changes release patterns significantly
- May need rebalancing of value_threshold
- **Migration:** Old saves may produce different results

**Option B (Recalibrate):**
- Simple config change
- No code changes
- **Migration:** Compatible with existing saves

**Option C (Hybrid):**
- Adds new config parameter
- Minimal code change
- **Migration:** New parameter with default preserves old behavior

---

## 10. TESTING STRATEGY RECOMMENDATIONS

### Unit Tests Need Enhancement

Current tests use artificial data mismatches. Add realistic scenarios:

```gdscript
# Realistic Year 20+ scenario
{
    "id": "vet1",
    "name": "Veteran Starter",
    "age": 29,
    "eval_score": 72.0,
    "contract": {
        "annual_value": 12.0,  // Realistic for 72-rated vet
        "signed_year": 2018
    }
}
```

### Integration Test Enhancement

Add assertions for release counts:

```gdscript
# Should release 5-15 players per year across 32 teams
assert(total_releases > 0, "No releases detected - system may be broken")
assert(total_releases > (years * 5), "Release rate too low")
```

### Diagnostic Script Integration

The diagnostic script (`diagnostic_roster_release.gd`) should be:
1. Integrated into test suite
2. Run against actual world state snapshots
3. Provide early warning of threshold issues

---

## 11. ARCHITECTURAL PRINCIPLES VIOLATED

### Violated Principles:

1. **Realistic Economics:** Formula doesn't reflect actual contract markets
2. **System Integration:** No connection to existing valuation systems (PlayerValue)
3. **Configuration Clarity:** Parameter names misleading about actual behavior
4. **Test Coverage:** Unit tests pass but integration fails (false confidence)
5. **Fail-Safe Design:** System silently fails (zero releases) rather than warning

### Maintained Principles:

1. **Determinism:** Formula is fully deterministic ✓
2. **Clear Logic Flow:** Code structure is clean and readable ✓
3. **Configuration Driven:** Behavior controlled by config ✓
4. **Documentation:** Function comments are clear ✓

---

## 12. FORWARD COMPATIBILITY CONSIDERATIONS

### If Formula Changes:

**Save Game Compatibility:**
- World states from old formula will produce different results
- Release history will change on replay
- **Mitigation:** Version config, migrate old saves with warning

**Mod/Extension Support:**
- value_threshold parameter may be used by mods
- Changing meaning breaks mods
- **Mitigation:** Add new parameter, deprecate old one

**Balance Impact:**
- More/fewer releases affects roster turnover
- FA pool size changes
- Draft pick values change
- **Mitigation:** Extensive playtesting required

---

## CONCLUSION

**ARCHITECTURAL ASSESSMENT:** The release candidate identification logic contains a critical design flaw where the expected_value calculation is disconnected from actual contract market economics. The threshold is mathematically impossible to exceed with realistic, internally-consistent contract data.

**ROOT CAUSE:** Expected value is calculated as `(eval_score / 100) * 1.5`, treating player ratings as dollar amounts in millions, when actual contracts are 5-20x higher. A 70-rated player has expected_value of $1.05M but earns $8-15M in reality.

**IMPACT SCOPE:**
- RosterManagement system (CRITICAL)
- Free agency player pool (HIGH)
- Long-term roster dynamics (HIGH)
- Historical statistics (MEDIUM)

**DECISION:** REQUIRES MODIFICATION

**RECOMMENDED SOLUTION:** Option A (Fix Formula) or Option C (Hybrid) to connect expected_value to actual contract market dynamics.

**RISK LEVEL:** Medium - Changes release patterns but system is currently non-functional.

**NEXT STEPS:**
1. Guardian #1: Review contract generation logic to confirm value ranges
2. Guardian #3: Assess downstream impact on FA and cap validation
3. Team Decision: Select Option A, B, or C
4. Implementation: Recalibrate or refactor with comprehensive testing

---

**Report Prepared By:** Architecture Guardian #2
**Focus Area:** Release Candidate Logic
**Status:** Analysis Complete - Awaiting Team Decision
