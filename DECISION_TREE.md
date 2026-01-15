# Release Candidate Decision Tree

## Current Logic Flow

```
For each player on roster:
│
├─ Does player have contract?
│  ├─ NO → Skip (not eligible)
│  └─ YES → Continue
│
├─ Is player a rookie? (signed_year == draft_year)
│  ├─ YES → Years since draft < 3?
│  │   ├─ YES → Skip (protected)
│  │   └─ NO → Continue
│  └─ NO → Continue
│
├─ Calculate expected_value
│  │  = (eval_score / 100) * value_threshold
│  │  = (eval_score / 100) * 1.5
│  │
│  └─ Example: 70-rated player
│      expected_value = 0.70 * 1.5 = $1.05M
│
├─ Calculate age_penalty
│  │  = 1.0 + max(0, age - 30) * age_decline_factor
│  │  = 1.0 + max(0, age - 30) * 0.02
│  │
│  └─ Examples:
│      Age 27: penalty = 1.00 (no penalty)
│      Age 32: penalty = 1.04 (4% penalty)
│      Age 35: penalty = 1.10 (10% penalty)
│
├─ Calculate cap_inefficiency
│  │  = (annual_value / expected_value) * age_penalty
│  │
│  └─ Example: 70-rated, age 27, $10M contract
│      = (10.0 / 1.05) * 1.0
│      = 9.52x over threshold
│
└─ Is cap_inefficiency > 1.0?
   ├─ NO → Keep player (good value)
   └─ YES → Add to release candidates
       │
       └─ Sort by inefficiency (worst first)
           Release until target budget reached
```

---

## Problem Identification

```
70-rated player, age 27, $10M contract:
│
├─ expected_value = (70/100) * 1.5 = $1.05M
│
├─ age_penalty = 1.0 (under 30)
│
├─ cap_inefficiency = (10.0 / 1.05) * 1.0 = 9.52
│
└─ 9.52 > 1.0? YES
    │
    ├─ Player is 9.5x OVER threshold
    └─ Should be first to release

BUT: $10M is FAIR MARKET VALUE for 70-rated player!

Problem: Threshold at $1.05M is absurdly low
         Real threshold should be $12-15M (50% over market)
```

---

## Why Zero Releases Occur

```
Typical Year 20+ Roster (53 players):
│
├─ 20 Recent Draftees (0-2 years since draft)
│  └─ [PROTECTED] - Skip entirely
│
├─ 15 Young Veterans (3-5 years)
│  ├─ Most on rookie contracts ($1-5M)
│  │  └─ expected_value = $0.90M - $1.20M
│  │      If contract < $5M: inefficiency = 4-5x
│  │      [SHOULD BE CANDIDATES]
│  │
│  └─ Few on extensions ($8-15M)
│      └─ expected_value = $1.05M - $1.20M
│          If contract $10M: inefficiency = 8-9x
│          [SHOULD BE CANDIDATES]
│
├─ 12 Prime Veterans (6-10 years)
│  ├─ Mixed contracts ($5-20M)
│  │  └─ expected_value = $1.05M - $1.35M
│  │      All exceed threshold by 4-15x
│  │      [SHOULD BE CANDIDATES]
│  │
│  └─ Some already released naturally
│
└─ 6 Aging Veterans (11+ years)
   ├─ Most expensive ($10-25M)
   │  └─ expected_value = $0.90M - $1.20M (declining ratings)
   │      age_penalty = 1.04 - 1.12
   │      All exceed threshold by 8-20x
   │      [SHOULD BE CANDIDATES]
   │
   └─ Many already retired

RESULT:
├─ Protected: 20 players (38%)
├─ Eligible: 33 players (62%)
│  └─ With realistic contracts: ALL are candidates
│      But system shows ZERO releases?
│
└─ HYPOTHESIS: One of two scenarios:
    ├─ A) Contract generation is broken (all contracts too low)
    │   └─ If all contracts are $1-3M, threshold isn't exceeded
    │
    └─ B) Cap space already sufficient (no releases needed)
        └─ If team has $40M space, no releases triggered
            Even though system WOULD identify candidates
```

---

## Release Execution Flow

```
Team Evaluation:
│
├─ Current cap space = cap_limit - sum(all annual_values)
│
├─ Target FA budget = random(30M, 50M)
│
├─ Need to release? (current_space < target_budget)
│  │
│  ├─ NO → Return (no releases)
│  │   └─ [MOST TEAMS MAY HIT THIS PATH IN YEAR 20+]
│  │
│  └─ YES → Continue
│      │
│      ├─ Identify candidates (as shown above)
│      │
│      ├─ Sort by cap_inefficiency (worst first)
│      │
│      └─ Release until target budget reached:
│          │
│          ├─ For each candidate:
│          │  ├─ Calculate dead_cap (currently $0)
│          │  ├─ net_savings = annual_value - dead_cap
│          │  ├─ Would we go below min_roster_size (45)?
│          │  │  ├─ YES → Stop releasing
│          │  │  └─ NO → Release player
│          │  └─ cap_saved >= needed_cap?
│          │     ├─ YES → Stop releasing
│          │     └─ NO → Continue
│          │
│          └─ Execute releases:
│              ├─ Remove from roster
│              ├─ Add to free_agents[year]
│              └─ Store in player_releases[year]

CRITICAL INSIGHT:
├─ If current_space >= target_budget
│  └─ System never evaluates candidates!
│      Zero releases reported
│
└─ This could explain integration test results
    IF rosters are cheap enough that no releases needed
```

---

## Three Possible Root Causes

### Scenario A: Formula Broken (Most Likely)
```
ALL players exceed threshold by 5-20x
│
├─ Contract generation working normally ($5-20M)
├─ Expected values absurdly low ($0.9-1.35M)
└─ Every eligible player is candidate

IF teams need cap space:
├─ Releases SHOULD occur
└─ System SHOULD work

IF zero releases in integration:
└─ Teams must not need cap space
    OR minimum roster size preventing releases
```

### Scenario B: Contracts Too Low
```
Contract generation broken
│
├─ All players earning $1-3M (unrealistic)
├─ Expected values at $0.9-1.35M
└─ Inefficiency ratios only 1.5-3x

Some players below threshold:
├─ System correctly identifies FEW candidates
└─ Zero releases if no one needs cap space
```

### Scenario C: Cap Space Already High
```
Teams already have $40-50M in space
│
├─ Retirements/expirations freed cap naturally
├─ Draft/FA hasn't filled all spots yet
└─ target_budget already met

System never calls _identify_release_candidates:
├─ Early exit at cap_space check
└─ Zero releases reported

BUT: Unit tests show candidates ARE identified
     So formula works mechanically
     Just never gets called in integration?
```

---

## Testing Path Forward

### Test 1: Force Cap Crunch
```
Manually create scenario with:
├─ Team at $178M cap usage (out of $180M)
├─ Target budget = $40M
├─ Need to release $38M

Expected: Should identify many candidates
Actual: [RUN TEST]

If still zero candidates:
└─ Confirms Formula Problem (Scenario B)
```

### Test 2: Check Actual Contracts
```
Sample 100 random players from year 20 rosters:
├─ Record: position, rating, age, annual_value
├─ Calculate: expected_value, cap_inefficiency
└─ Analyze distribution

If most annual_values are $1-3M:
└─ Contract generation problem

If most annual_values are $8-20M:
└─ Expected value problem (current diagnosis)
```

### Test 3: Override Threshold
```
Temporarily set value_threshold = 13.0 (instead of 1.5)

Expected: Now expected_values are $7-12M
         Should see some releases (not all players)

Actual: [RUN TEST]

If releases occur:
└─ Confirms threshold calibration issue
```

---

## Solution Decision Tree

```
Choose fix approach:
│
├─ Need quick fix?
│  ├─ YES → Option C: Recalibrate threshold
│  │   └─ Change value_threshold: 1.5 → 13.0
│  │       Pro: One line change
│  │       Con: Semantically incorrect
│  │
│  └─ NO → Continue to next question
│
├─ Need position-specific markets?
│  ├─ YES → Option A or D
│  │   ├─ Option A: PlayerValue integration
│  │   │   └─ Most realistic, most complex
│  │   │
│  │   └─ Option D: Position market configs
│  │       └─ Configurable, more work
│  │
│  └─ NO → Option B
│      └─ market_value_multiplier = 0.15
│          value_threshold = 1.5
│          Pro: Simple, semantically correct
│          Con: Position-agnostic
│
└─ How to validate?
   ├─ Unit tests: Add realistic contract scenarios
   ├─ Integration test: Assert releases > 0
   └─ Diagnostic: Run on actual world state
       └─ Should show 5-15% of players as candidates
```

---

## Validation Criteria

After any fix, system should exhibit:

```
✓ Releases occur (> 0 per year across league)
✓ Not all players are candidates (selectivity)
✓ Worse value/dollar ratios released first
✓ Age factors into decisions appropriately
✓ Rookie protection works
✓ Minimum roster size respected
✓ Target FA budget achieved (within reason)

Reasonable expectations:
├─ League-wide: 50-150 releases per year
├─ Per team: 0-8 releases per year
├─ Candidates: 10-30% of eligible players
└─ Most releases: Players aged 30+ with high contracts
```

---

## Summary Flowchart

```
Integration Test (Years 20-29)
│
├─ Run RosterManagement for each team
│  │
│  ├─ Check cap space vs target budget
│  │  │
│  │  ├─ Space sufficient?
│  │  │  └─ YES → [SKIP RELEASES]
│  │  │      └─ Report: 0 releases
│  │  │
│  │  └─ Need releases?
│  │     └─ YES → Identify candidates
│  │        │
│  │        ├─ Apply formula
│  │        │  ├─ expected_value = $0.9-1.35M
│  │        │  ├─ contracts = $5-20M
│  │        │  └─ ALL exceed threshold
│  │        │
│  │        ├─ Sort by inefficiency
│  │        └─ Release until budget met
│  │           └─ Report: X releases
│  │
│  └─ Aggregate results
│
└─ Total releases across all teams: 0
    │
    └─ WHY?
        ├─ Most likely: Cap space already sufficient
        │   └─ Due to retirements/expirations
        │       OR contracts too low
        │
        └─ Less likely: Roster at min size (45)
            └─ Can't release more
```
