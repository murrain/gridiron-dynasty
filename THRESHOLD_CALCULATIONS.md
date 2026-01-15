# Release Threshold Calculations - Quick Reference

## Current Formula

```
cap_inefficiency = (annual_value / expected_value) * age_penalty

Where:
  expected_value = (eval_score / 100) * value_threshold
  age_penalty = 1.0 + max(0, age - 30) * age_decline_factor

Threshold: cap_inefficiency > 1.0 to become release candidate
```

## Config Values
- value_threshold = 1.5
- age_decline_factor = 0.02

---

## Calculation Examples

### Player Profile 1: Young Starter (Age 25)

| Rating | Expected Value | Age Penalty | Threshold Cap Hit | Realistic Cap Hit | Would Release? |
|--------|---------------|-------------|-------------------|-------------------|----------------|
| 60 | $0.90M | 1.00 | > $0.90M | $5.0M | YES (5.56x) |
| 70 | $1.05M | 1.00 | > $1.05M | $8.0M | YES (7.62x) |
| 80 | $1.20M | 1.00 | > $1.20M | $15.0M | YES (12.5x) |
| 90 | $1.35M | 1.00 | > $1.35M | $25.0M | YES (18.5x) |

**Issue:** Even elite players (90-rated) only need $1.35M to avoid release, but realistically earn $25M.

---

### Player Profile 2: Prime Veteran (Age 28)

| Rating | Expected Value | Age Penalty | Threshold Cap Hit | Realistic Cap Hit | Would Release? |
|--------|---------------|-------------|-------------------|-------------------|----------------|
| 60 | $0.90M | 1.00 | > $0.90M | $6.0M | YES (6.67x) |
| 70 | $1.05M | 1.00 | > $1.05M | $10.0M | YES (9.52x) |
| 80 | $1.20M | 1.00 | > $1.20M | $18.0M | YES (15.0x) |
| 90 | $1.35M | 1.00 | > $1.35M | $30.0M | YES (22.2x) |

**Issue:** All prime veterans exceed threshold massively (6-22x over).

---

### Player Profile 3: Aging Veteran (Age 32)

| Rating | Expected Value | Age Penalty | Threshold Cap Hit | Realistic Cap Hit | Would Release? |
|--------|---------------|-------------|-------------------|-------------------|----------------|
| 55 | $0.825M | 1.04 | > $0.79M | $4.0M | YES (5.05x) |
| 65 | $0.975M | 1.04 | > $0.94M | $8.0M | YES (8.52x) |
| 75 | $1.125M | 1.04 | > $1.08M | $12.0M | YES (11.1x) |
| 85 | $1.275M | 1.04 | > $1.23M | $20.0M | YES (16.3x) |

**Issue:** Even with age penalty, thresholds are $0.79M - $1.23M, far below realistic values.

---

### Player Profile 4: Ancient Veteran (Age 36)

| Rating | Expected Value | Age Penalty | Threshold Cap Hit | Realistic Cap Hit | Would Release? |
|--------|---------------|-------------|-------------------|-------------------|----------------|
| 50 | $0.75M | 1.12 | > $0.67M | $2.0M | YES (2.99x) |
| 60 | $0.90M | 1.12 | > $0.80M | $5.0M | YES (6.23x) |
| 70 | $1.05M | 1.12 | > $0.94M | $8.0M | YES (8.53x) |
| 80 | $1.20M | 1.12 | > $1.07M | $15.0M | YES (14.0x) |

**Issue:** Even 36-year-olds have thresholds under $1.1M for 80+ ratings.

---

## Position-Specific Reality Check

### Quarterback (QB)

| Rating | Expected Value | Realistic NFL Contract | Inefficiency Ratio |
|--------|---------------|------------------------|-------------------|
| 70 | $1.05M | $15M - $25M | 14.3x - 23.8x |
| 80 | $1.20M | $30M - $45M | 25.0x - 37.5x |
| 90 | $1.35M | $45M - $60M | 33.3x - 44.4x |

**Every QB is a release candidate** by current formula.

### Wide Receiver (WR)

| Rating | Expected Value | Realistic NFL Contract | Inefficiency Ratio |
|--------|---------------|------------------------|-------------------|
| 70 | $1.05M | $8M - $15M | 7.6x - 14.3x |
| 80 | $1.20M | $18M - $25M | 15.0x - 20.8x |
| 90 | $1.35M | $25M - $35M | 18.5x - 25.9x |

**Every starting WR is a release candidate.**

### Running Back (RB)

| Rating | Expected Value | Realistic NFL Contract | Inefficiency Ratio |
|--------|---------------|------------------------|-------------------|
| 70 | $1.05M | $5M - $10M | 4.8x - 9.5x |
| 80 | $1.20M | $12M - $18M | 10.0x - 15.0x |
| 90 | $1.35M | $18M - $25M | 13.3x - 18.5x |

**Even devalued RBs massively exceed threshold.**

### Offensive Line (OL)

| Rating | Expected Value | Realistic NFL Contract | Inefficiency Ratio |
|--------|---------------|------------------------|-------------------|
| 70 | $1.05M | $8M - $12M | 7.6x - 11.4x |
| 80 | $1.20M | $15M - $22M | 12.5x - 18.3x |
| 90 | $1.35M | $22M - $30M | 16.3x - 22.2x |

**All starting offensive linemen are candidates.**

---

## Rookie Contract Analysis

### Why Rookies Might NOT Be Candidates (Even Without Protection)

**1st Round Pick (70 rating, Age 22):**
- expected_value = $1.05M
- Rookie contract = $2M - $5M (typical)
- cap_inefficiency = 2.0M / 1.05M = 1.90x
- **Status:** RELEASE CANDIDATE (but protected by 3-year rule)

**3rd Round Pick (65 rating, Age 22):**
- expected_value = $0.975M
- Rookie contract = $1M - $2M (typical)
- cap_inefficiency = 1.5M / 0.975M = 1.54x
- **Status:** RELEASE CANDIDATE (but protected)

**7th Round Pick (55 rating, Age 22):**
- expected_value = $0.825M
- Rookie contract = $0.7M - $1M (typical)
- cap_inefficiency = 0.85M / 0.825M = 1.03x
- **Status:** BARELY a candidate (saved by protection)

**Key Insight:** Even cheap rookie contracts exceed the absurdly low thresholds!

---

## Integration Test Hypothesis

### Why Zero Releases in Years 20-29?

**Roster Composition (Typical NFL Team):**

| Player Group | Count | Protected? | Would Be Candidate? | Actually Released? |
|-------------|-------|------------|---------------------|-------------------|
| Years 0-2 (Rookies) | 15-20 | YES | N/A | NO (Protected) |
| Years 3-5 (Young Vets) | 12-15 | NO | YES (Most) | Possible |
| Years 6-10 (Prime Vets) | 8-12 | NO | YES (All) | Possible |
| Years 11+ (Old Vets) | 3-8 | NO | YES (All) | Possible |

**Problem Scenario:**

If rosters are predominantly:
- 40% rookies (protected)
- 30% young players still on rookie deals or cheap extensions
- 20% mid-career veterans
- 10% expensive veterans

**And if:**
- Contract generation hasn't inflated salaries properly
- Most players are on team-friendly deals
- Veterans have already been released/retired naturally

**Then:**
- Protected group = 40%
- Eligible but cheap contracts = 20-30%
- Actual expensive veterans = 10-20%

**Result:** Maybe 10-20 players per team are candidates, but if cap space is already sufficient, zero releases.

---

## Mathematical Break-Even Analysis

### What value_threshold Would Create Realistic Thresholds?

**Goal:** 75-rated player at age 27 should have threshold of $10M

```
expected_value = (75 / 100) * value_threshold
10.0 = 0.75 * value_threshold
value_threshold = 13.33
```

**New Config:**
```json
{
  "value_threshold": 13.0  // (was 1.5)
}
```

**Result Table:**

| Rating | Old Expected | New Expected | Realistic Contract | Matches? |
|--------|-------------|-------------|-------------------|----------|
| 60 | $0.90M | $7.80M | $5-8M | ✓ Close |
| 70 | $1.05M | $9.10M | $8-15M | ✓ Close |
| 80 | $1.20M | $10.40M | $15-25M | ~ Low end |
| 90 | $1.35M | $11.70M | $25-50M | ✗ Still low |

**Better but not perfect** - still needs position multipliers.

---

## Alternative: Market Value Multiplier Approach

**Formula:**
```
expected_value = (eval_score * market_value_multiplier) * value_threshold
```

**Config:**
```json
{
  "market_value_multiplier": 0.15,  // 70 rating = 10.5M base
  "value_threshold": 1.5            // Cut if 50% overpaid
}
```

**Result Table:**

| Rating | Base Value | Expected (1.5x) | Threshold Cap Hit | Realistic |
|--------|-----------|----------------|-------------------|-----------|
| 60 | $9.0M | $13.5M | > $13.5M | $5-8M ✓ |
| 70 | $10.5M | $15.75M | > $15.75M | $8-15M ✓ |
| 80 | $12.0M | $18.0M | > $18.0M | $15-25M ✓ |
| 90 | $13.5M | $20.25M | > $20.25M | $25-50M ~ |

**Much better alignment!** Players need to be paid 50% OVER market (1.5x) to be cut.

---

## Recommended Fix Comparison

### Option A: Use PlayerValue.calculate()
**Pro:** Integrates with existing market valuation
**Con:** Complex, requires dependency
**Threshold Behavior:** Dynamic based on position, age curves, market conditions

### Option B: Recalibrate value_threshold to 13.0
**Pro:** Simple one-number change
**Con:** Still doesn't account for position differences
**Threshold Behavior:** Fixed scale, all positions treated equally

### Option C: Add market_value_multiplier = 0.15
**Pro:** Simple, maintains value_threshold semantics
**Con:** Still doesn't account for position differences
**Threshold Behavior:** Fixed scale with configurable "cut if X% overpaid"

### Option D: Position-Specific Thresholds
**Pro:** Most realistic
**Con:** Most complex configuration
**Example:**
```json
{
  "position_market_values": {
    "QB": 20.0,  // 70-rated QB worth $14M
    "WR": 12.0,  // 70-rated WR worth $8.4M
    "RB": 8.0,   // 70-rated RB worth $5.6M
    "OL": 10.0   // 70-rated OL worth $7M
  },
  "value_threshold": 1.5  // Cut if 50% overpaid
}
```

---

## Summary Table: Threshold Comparison

| Approach | 70-Rated QB Threshold | 70-Rated RB Threshold | Reflects Reality? |
|----------|----------------------|----------------------|-------------------|
| **Current (1.5)** | $1.05M | $1.05M | NO - 10-20x too low |
| **Recalibrated (13.0)** | $9.1M | $9.1M | PARTIAL - ignores position |
| **Multiplier (0.15)** | $15.75M | $15.75M | GOOD - but no position diff |
| **Position-Specific** | $30M | $12M | EXCELLENT - realistic |
| **PlayerValue Integration** | Dynamic | Dynamic | EXCELLENT - most accurate |

**Recommendation:** Option C (market_value_multiplier) for immediate fix, Option A (PlayerValue) for best long-term solution.
