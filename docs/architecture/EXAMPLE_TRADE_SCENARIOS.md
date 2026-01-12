# Example Trade Scenarios

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: TRADE_SYSTEM_ARCHITECTURE.md

---

## Purpose

This document provides detailed walkthroughs of realistic trade scenarios, showing how the trade system's components work together to produce authentic NFL team-building decisions.

Each scenario includes:
- Initial situation
- Motivation detection
- Partner matching
- Value calculation
- Decision logic
- Trade outcome

---

## Scenario 1: Contender Playoff Push Trade

### Initial Situation

**Team A (Seattle Storm)**: 9-2 record, Week 11
- Team Status: "contender" (73% win rate)
- Playoff Outlook: Likely 2nd seed, competing for championship
- Roster Strength: 74.2 overall rating
- **Weakness**: CB depth (only 3 CBs, all below 70 rating)
- **Recent**: Starting CB injured week 9 (out 4 weeks)

**Team B (Houston Pioneers)**: 3-8 record, Week 11
- Team Status: "rebuilder" (27% win rate)
- Playoff Outlook: Eliminated, building for future
- Roster Strength: 62.8 overall rating
- **Surplus**: 5 CBs on roster (including 28-year-old veteran)

### Step 1: Motivation Detection

**Team A (Seattle)**:
```gdscript
# TradeProfileBuilder.build_profile()
{
  "team_status": "contender",
  "wins": 9,
  "losses": 2,

  "positional_needs": {
    "CB": {
      "severity": 0.75,  # High severity (starter injured + weak depth)
      "reason": "starter_injured_and_weak_depth"
    }
  },

  "positional_surplus": {},  # No surplus

  "trade_temperature": 0.68,  # Hot (contender + need + deadline urgency)
  # Breakdown:
  # Base: 0.3
  # Need severity (0.75 * 0.15): +0.11
  # Contender late-season boost: +0.2
  # Deadline proximity (week 11, deadline week 10): +0.07
  # = 0.68

  "untouchables": ["p_qb_001", "p_edge_042", "p_wr_089"],  # Young core

  "cap_space": 15.2,
  "must_shed_salary": false
}
```

**Team B (Houston)**:
```gdscript
{
  "team_status": "rebuilder",
  "wins": 3,
  "losses": 8,

  "positional_needs": {
    "QB": {"severity": 0.6, "reason": "aging_starter"}
  },

  "positional_surplus": {
    "CB": {
      "count": 5,
      "tradeable": ["p_cb_201", "p_cb_202"]  # Can trade 2 without issues
    }
  },

  "trade_temperature": 0.52,  # Warm (rebuilder + surplus)
  # Breakdown:
  # Base: 0.3
  # Rebuilder boost: +0.1
  # Surplus positions: +0.1
  # Deadline proximity (selling opportunity): +0.02
  # = 0.52

  "untouchables": ["p_qb_young_123"],  # Young QB (age 23, potential 82)

  "cap_space": 42.8,
  "must_shed_salary": false
}
```

### Step 2: Partner Matching

```gdscript
# TradeMatchmaker.find_trade_partners(team_a_profile, all_teams, config)

# Scan all teams for CB surplus
candidates = [
  {
    "team_id": "nfl_015",  # Houston
    "profile": team_b_profile,
    "compatibility": 0.75  # High: A needs CB, B has surplus CB
    # Calculation: Need severity (0.75) * 0.5 + Surplus match (1.0) * 0.5 = 0.75
  },
  {
    "team_id": "nfl_022",  # Another team
    "profile": {...},
    "compatibility": 0.42  # Lower: has CB but not surplus
  }
]

# Sort by compatibility
partners = sorted(candidates, key=lambda x: x.compatibility, reverse=True)
# Houston (0.75) is best match
```

### Step 3: Trade Candidate Selection

**Team A (Seattle) identifies what to give**:
```gdscript
# What does Houston need? QB (0.6 severity) - but Seattle won't trade QB
# Houston is rebuilder → wants picks or young players

# Seattle identifies tradeable assets:
candidates_to_give = [
  # Can't trade untouchables
  # Can't trade picks (Phase 1: players only)
  # Look for surplus positions + young players
  {
    "player_id": "p_rb_145",
    "name": "Marcus Johnson",
    "position": "RB",
    "age": 24,
    "rating": 72,
    "potential": 78,
    "trade_value": 8.5,
    "contract_years": 2
  }
]
```

**Team B (Houston) identifies what to give**:
```gdscript
# Seattle needs CB, Houston has surplus

candidates_to_give = [
  {
    "player_id": "p_cb_201",
    "name": "Darren Williams",
    "position": "CB",
    "age": 28,
    "rating": 76,
    "potential": 76,  # Peaked
    "trade_value": 9.2,
    "contract_years": 1  # Expiring contract
  },
  {
    "player_id": "p_cb_202",
    "name": "Chris Baker",
    "position": "CB",
    "age": 26,
    "rating": 74,
    "potential": 78,
    "trade_value": 10.5,
    "contract_years": 3
  }
]

# Choose Williams (expiring contract, older, rebuilder prefers to keep younger Baker)
selected = candidates_to_give[0]
```

### Step 4: Value Calculation

**Team A gives: Marcus Johnson (RB)**
```gdscript
# TradeValuation.calculate_player_trade_value()

# From Seattle's perspective:
market_value = 8.5  # Base PlayerValue
team_value = 8.0  # Slight negative (4 RBs, surplus)
team_premium = -0.5  # Negative, willing to shed
trade_value = 8.5 * 1.0 = 8.5  # No premium adjustment (negative premium)

# From Houston's perspective:
market_value = 8.5
team_value = 9.2  # Young RB fits rebuild timeline
receiving_premium = 0.7  # Positive, values young players

seattle_gives_value = 8.5
houston_receives_value = 9.2  # Houston values more than Seattle
```

**Team B gives: Darren Williams (CB)**
```gdscript
# From Houston's perspective:
market_value = 9.2
team_value = 7.8  # Less valuable (surplus + aging)
team_premium = -1.4  # Want to trade
trade_value = 9.2 * 1.0 = 9.2  # No premium (surplus player)

# Contract adjustment:
years_remaining = 1  # Expiring contract
adjusted_value = 9.2 * 0.85 = 7.82  # 15% discount for rental

# From Seattle's perspective:
market_value = 9.2
adjusted_market = 7.82  # After contract adjustment
team_value = 10.9  # High value (fills critical need)
receiving_premium = 3.1  # Desperate for CB

# Need multiplier:
need_severity = 0.75
need_multiplier = 1.0 + (0.75 * 0.3) = 1.225
receiving_value = 7.82 * 1.225 = 9.58

houston_gives_value = 7.82  # Adjusted for contract
seattle_receives_value = 9.58  # Need multiplier applied
```

### Step 5: Fairness Check

```gdscript
# TradeValuation.is_trade_fair()

# Team A (Seattle):
gives = 8.5
receives = 9.58
net = +1.08 (Seattle gains value)

# Team B (Houston):
gives = 7.82
receives = 9.2
net = +1.38 (Houston gains value)

# Check fairness from both perspectives:
# Method: Compare value differential as percentage of larger value

# Seattle perspective:
pct_diff = |9.58 - 8.5| / 9.58 = 11.3%

# Houston perspective:
pct_diff = |9.2 - 7.82| / 9.2 = 15.0%

# Calculate tolerance:
base_tolerance = 0.30 (30%)
seattle_urgency = 0.68
houston_urgency = 0.52
max_urgency = 0.68
urgency_bonus = 0.68 * 0.15 = 0.102
effective_tolerance = 0.30 + 0.102 = 0.402 (40.2%)

# Check:
11.3% < 40.2% ✓
15.0% < 40.2% ✓

Result: FAIR TRADE
```

### Step 6: Division Check

```gdscript
# apply_division_rival_penalty()

seattle_division = "nfc_west"
houston_division = "afc_south"

# Different divisions → no penalty
penalty_applied = false
```

### Step 7: Validation

```gdscript
# TradeProposalBuilder.validate_proposal()

# Check 1: Positional constraints
seattle_rbs = 4  # Can trade 1 (minimum 3)
houston_cbs = 5  # Can trade 1 (minimum 4)
✓ Pass

# Check 2: Untouchables
neither player in untouchables
✓ Pass

# Check 3: Cap space
seattle_cap_space = 15.2
williams_contract = 4.5/year
johnson_contract = 3.2/year
net_cap_change = 4.5 - 3.2 = +1.3 (increase, but within space)
✓ Pass

# Check 4: Value fairness
Already validated (11.3% and 15.0% < 40.2%)
✓ Pass

Validation Result: APPROVED
```

### Trade Outcome

**Trade Executed**:
```
Seattle Storm trades RB Marcus Johnson (24, rating 72)
to Houston Pioneers for CB Darren Williams (28, rating 76)

Motivation: Playoff push (CB depth need)
Value: Balanced (slight wins for both teams)
Winner: Balanced trade

Headline: "Storm bolster secondary for playoff run, acquire Williams from Pioneers"
```

**Impact**:
- Seattle: Fills critical need, improves CB depth for playoff run
- Houston: Gets young RB for rebuild, trades expiring-contract veteran
- Both teams satisfied (win-win based on different timelines)

---

## Scenario 2: Rebuilder Salary Dump (Rejected Trade)

### Initial Situation

**Team A (New York Knights)**: 2-9 record, Week 11
- Team Status: "rebuilder"
- Cap Situation: $8M OVER cap for next year
- **Problem**: 32-year-old DE with $18M/year contract
- **Need**: Shed salary or cut player (dead money hit)

**Team B (Dallas Rangers)**: 9-2 record, Week 11, **Same Division (NFC East)**
- Team Status: "contender"
- EDGE Depth: Adequate (3 quality pass rushers)
- Cap Space: $22M available

### Step 1: Motivation Detection

**Team A (New York)**:
```gdscript
{
  "team_status": "rebuilder",
  "wins": 2,
  "losses": 9,

  "positional_needs": {},

  "positional_surplus": {
    "EDGE": {"count": 4, "tradeable": ["p_de_301"]}  # Aging DE with big contract
  },

  "trade_temperature": 0.82,  # OVERHEATING (cap crisis + deadline)
  # Breakdown:
  # Base: 0.3
  # Cap crisis boost: +0.25
  # Rebuilder boost: +0.1
  # Deadline urgency: +0.15
  # Must shed salary: +0.02
  # = 0.82

  "must_shed_salary": true,  # Over cap

  "cap_space": -8.0  # Negative (over cap)
}
```

**Team B (Dallas)**:
```gdscript
{
  "team_status": "contender",
  "wins": 9,
  "losses": 2,

  "positional_needs": {},  # No critical needs

  "trade_temperature": 0.25,  # COLD (contender protecting assets)
  # Breakdown:
  # Base: 0.3
  # Contender reduction: -0.1
  # Late season (protecting roster): -0.05
  # No needs: -0.0
  # = 0.25

  "cap_space": 22.0
}
```

### Step 2: Partner Matching

```gdscript
# TradeMatchmaker.find_trade_partners()

# New York has surplus EDGE, needs cap relief
# Dallas has cap space, but no EDGE need
# Compatibility score: 0.15 (very low, no complementary needs)

# Dallas temperature: 0.25 (COLD, below 0.4 threshold)
# Would normally be filtered out, but New York is desperate

partners = [
  {
    "team_id": "nfl_007",  # Dallas
    "profile": dallas_profile,
    "compatibility": 0.15  # Low
  }
]
```

### Step 3: Trade Candidate Selection

**Team A gives**:
```gdscript
{
  "player_id": "p_de_301",
  "name": "veteran DE Marcus Strong",
  "position": "EDGE",
  "age": 32,
  "rating": 78,  # Still productive
  "potential": 75,  # Declining
  "trade_value": 12.0,
  "contract_years": 2,
  "annual_value": 18.0  # OVERPAID (18.0 vs 12.0 value)
}
```

**Team B gives**:
```gdscript
# Dallas doesn't need anything from New York
# New York desperate, willing to take any return
# Dallas would consider: 6th or 7th round pick (Phase 1: none available)

# Phase 1 constraint: Must find player to trade
# Dallas looks for expendable player:
{
  "player_id": "p_ol_445",
  "name": "Backup OL",
  "position": "OL",
  "age": 26,
  "rating": 65,
  "trade_value": 3.0
}
```

### Step 4: Value Calculation

**New York gives: Marcus Strong (EDGE)**
```gdscript
market_value = 12.0
team_value = 10.0  # Less valuable (surplus + aging)
trade_value = 12.0

# Contract adjustment:
annual_value = 18.0
value_ratio = 18.0 / 12.0 = 1.5
overpay_ratio = 1.5  # Not quite 2.0 threshold
# No penalty (need 2.0+ for bad contract penalty)

# BUT: Cap relief is primary motivation
# New York values getting rid of $18M more than player's value
effective_value_for_NY = 12.0 - 8.0 = 4.0  # Willing to trade for less
```

**Dallas gives: Backup OL**
```gdscript
market_value = 3.0
trade_value = 3.0
```

### Step 5: Division Rival Penalty

```gdscript
# THIS IS THE KILLER

ny_division = "nfc_east"
dallas_division = "nfc_east"

# SAME DIVISION
penalty_multiplier = 1.5

# Dallas would need to receive:
required_value = 12.0 * 1.5 = 18.0

# Dallas gives: 3.0
# Dallas receives: 12.0 (base), but requires 18.0 after penalty

value_shortfall = 18.0 - 12.0 = 6.0  # Not enough value
```

### Step 6: Fairness Check

```gdscript
# Even without division penalty:

ny_gives = 12.0
ny_receives = 3.0
pct_diff = |3.0 - 12.0| / 12.0 = 75%

tolerance = 0.30 + (0.82 * 0.15) = 0.423 (42.3%)

75% > 42.3%  # UNFAIR even with high urgency

# With division penalty:
dallas_required_value = 18.0
value_received = 12.0
shortfall = 33%  # Dallas needs 33% more value

Result: UNFAIR + DIVISION RIVAL = REJECTED
```

### Trade Outcome

**Trade Rejected**:
```
Reason: "division_rival_insufficient_value"
Details: {
  "same_division": "nfc_east",
  "penalty_multiplier": 1.5,
  "required_value": 18.0,
  "offered_value": 12.0,
  "shortfall_pct": 33.0
}
Message: "Division rivals require 50% premium. Cowboys demand 18.0 value, Knights offer only 12.0. Insufficient value to overcome rivalry penalty."
```

**Consequence**:
- New York cannot find trade partner for Marcus Strong
- Must cut player (dead money hit: $12M guaranteed)
- Cap space improves but at cost of future cap
- Lesson: Cap casualties are hard to trade (bad contracts + division constraints)

---

## Scenario 3: Multi-Team Bidding War (QB Injury)

### Initial Situation

**Week 2, Three Teams Affected**:

**Team A (Phoenix Blaze)**: 1-1 record
- **Crisis**: Starting QB torn ACL week 2 (out for season)
- Backup QB: Rating 58 (not starter quality)
- Team Status: "playoff_bubble" (projected 8-9 wins)

**Team B (Miami Sharks)**: 1-1 record
- **Crisis**: Starting QB concussion week 1 (out 4 weeks)
- Backup QB: Rating 62 (serviceable but shaky)
- Team Status: "playoff_bubble"

**Team C (Las Vegas Aces)**: 0-2 record
- **Surplus**: 3 QBs on roster (drafted QB in 1st round, previous starter still on team)
- Previous starter: Age 29, rating 74, contract $8M/year

### Step 1: Motivation Detection

**Phoenix (Most Desperate)**:
```gdscript
{
  "positional_needs": {
    "QB": {
      "severity": 0.95,  # CRITICAL (starter out for season, backup inadequate)
      "reason": "starter_season_ending_injury"
    }
  },
  "trade_temperature": 0.88,  # OVERHEATING
  "urgency": "immediate"  # Must act within 1 week
}
```

**Miami (Urgent)**:
```gdscript
{
  "positional_needs": {
    "QB": {
      "severity": 0.7,  # HIGH (starter out 4 weeks, backup shaky)
      "reason": "starter_temporary_injury"
    }
  },
  "trade_temperature": 0.65,  # HOT
  "urgency": "high"  # Should act within 2 weeks
}
```

**Las Vegas (Seller)**:
```gdscript
{
  "positional_surplus": {
    "QB": {
      "count": 3,
      "tradeable": ["p_qb_veteran_777"]  # Previous starter
    }
  },
  "trade_temperature": 0.48,  # WARM (surplus, opportunity to capitalize)
}
```

### Step 2: Partner Matching (System Finds Competition)

```gdscript
# When Phoenix initiates trade search:
partners_for_phoenix = [
  {"team_id": "las_vegas", "compatibility": 0.85},  # Has QB surplus
  {"team_id": "other_team", "compatibility": 0.42}
]

# When Miami initiates trade search (same window):
partners_for_miami = [
  {"team_id": "las_vegas", "compatibility": 0.75},  # Same team!
]

# CONFLICT: Both Phoenix and Miami want Las Vegas' QB
# System detects: multiple bidders for same player
```

### Step 3: Bidding Logic

**Las Vegas identifies leverage**:
```gdscript
# Two teams competing for same player
# Can demand premium value

veteran_qb_value = 15.0  # Base market value

# Bidding teams' offers:
phoenix_offer_candidates = [
  {"player": "WR", "value": 18.0, "age": 25},  # Young WR
  {"player": "CB", "value": 14.0, "age": 27}
]

miami_offer_candidates = [
  {"player": "OL", "value": 12.0, "age": 24},
  {"player": "LB", "value": 16.0, "age": 26}
]
```

### Step 4: Value Calculation (Competitive)

**Phoenix Offer: Young WR (value 18.0) for QB (value 15.0)**
```gdscript
# Phoenix perspective:
gives = 18.0
receives = 15.0
net = -3.0 (loses value)

# Phoenix urgency calculation:
need_severity = 0.95
need_multiplier = 1.0 + (0.95 * 0.3) = 1.285
receiving_value = 15.0 * 1.285 = 19.28

# Adjusted:
gives = 18.0
receives = 19.28
net = +1.28 (wins after need adjustment)

# Fairness:
pct_diff = |19.28 - 18.0| / 19.28 = 6.6%
tolerance = 0.30 + (0.88 * 0.15) = 0.432
6.6% < 43.2% ✓ FAIR

Phoenix accepts: "Overpay by pure value, but desperate need justifies"
```

**Miami Offer: LB (value 16.0) for QB (value 15.0)**
```gdscript
# Miami perspective:
gives = 16.0
receives = 15.0
net = -1.0

# Miami urgency:
need_severity = 0.7
need_multiplier = 1.0 + (0.7 * 0.3) = 1.21
receiving_value = 15.0 * 1.21 = 18.15

# Adjusted:
gives = 16.0
receives = 18.15
net = +2.15

pct_diff = |18.15 - 16.0| / 18.15 = 11.8%
tolerance = 0.30 + (0.65 * 0.15) = 0.398
11.8% < 39.8% ✓ FAIR

Miami accepts: "Slight overpay, acceptable given injury"
```

### Step 5: Las Vegas Chooses Winner

```gdscript
# Las Vegas evaluates both offers:

phoenix_offer = {
  "value": 18.0,
  "player": "WR",
  "age": 25,
  "position_need": "low"  # Already have WRs
}

miami_offer = {
  "value": 16.0,
  "player": "LB",
  "age": 26,
  "position_need": "medium"  # Could use LB depth
}

# Decision logic:
# 1. Pure value: Phoenix offers more (18.0 vs 16.0)
# 2. Age: Phoenix player younger (25 vs 26)
# 3. Position fit: Miami's LB slightly more useful

# Value difference: 18.0 - 16.0 = 2.0 (12.5% more)
# Value wins

Winner: Phoenix (higher value offer)
```

### Trade Outcome

**Trade Executed**:
```
Phoenix Blaze trades WR Tyler Mason (25, rating 79)
to Las Vegas Aces for QB James Carter (29, rating 74)

Motivation: Injury crisis (season-ending QB injury)
Value: Phoenix "overpays" by market value (18.0 for 15.0)
Winner: Las Vegas (gets premium value due to leverage)

Headline: "Blaze acquire veteran Carter to replace injured franchise QB"
```

**Miami Result**:
```
Trade Rejected: Las Vegas chose Phoenix's offer
Reason: "better_offer_accepted"
Miami forced to continue with backup QB for 4 weeks
```

**Lesson**: Competition for scarce resources drives premium prices. Multiple bidders create leverage for seller.

---

## Scenario 4: Deadline Seller (Balanced Trade)

### Initial Situation

**Team A (Carolina Storm)**: 4-6 record, Week 10 (Trade Deadline)
- Team Status: "mediocre" (not competing, not rebuilding)
- 30-year-old WR: Rating 80, contract $10M/year (2 years left)
- Decision: Trade veteran now or keep and rebuild?

**Team B (Green Bay Wolves)**: 8-2 record, Week 10
- Team Status: "contender"
- WR Depth: Weak (best WR is rating 72)
- Missing piece: Quality WR1 for playoff run

### Step 1: Motivation Detection

**Carolina**:
```gdscript
{
  "team_status": "mediocre",  # 4-6, not competing this year

  "positional_surplus": {
    "WR": {"count": 5}  # Have other WRs
  },

  "trade_temperature": 0.55,  # WARM (deadline, veteran asset)
  # Breakdown:
  # Base: 0.3
  # Deadline urgency (seller's market): +0.15
  # Mediocre team (could go either way): +0.0
  # Aging veteran: +0.1
  # = 0.55

  "motivation": "deadline_seller"  # Get value before deadline passes
}
```

**Green Bay**:
```gdscript
{
  "team_status": "contender",

  "positional_needs": {
    "WR": {
      "severity": 0.65,  # Significant weakness
      "reason": "weak_wr_depth"
    }
  },

  "trade_temperature": 0.72,  # HOT (contender + deadline + need)
  # Breakdown:
  # Base: 0.3
  # Contender boost (late season push): +0.2
  # Positional need: +0.12
  # Deadline urgency (last chance): +0.1
  # = 0.72

  "motivation": "playoff_push"
}
```

### Step 2: Value Calculation

**Carolina gives: WR Veteran (rating 80)**
```gdscript
market_value = 20.0
team_value = 18.0  # Less valuable (mediocre team, not competing)
trade_value = 20.0

# No premium (team willing to trade)
```

**Green Bay gives: Young CB (rating 74)**
```gdscript
market_value = 12.0
age = 24
potential = 80
team_value = 13.5

# Green Bay has CB depth, willing to trade for immediate help
```

**+ Green Bay gives: 3rd Round Pick (Phase 2 feature)**
```
In Phase 1: Must find another player instead
Green Bay adds: Backup TE (value 8.0)

Total Green Bay gives: CB (12.0) + TE (8.0) = 20.0
```

### Step 3: Fairness Check

```gdscript
# Carolina perspective:
gives = 20.0 (veteran WR)
receives = 20.0 (young CB + backup TE)
net = 0.0 (exactly balanced)

pct_diff = 0%
tolerance = 30%
Result: FAIR

# Green Bay perspective:
gives = 20.0
receives = 20.0
net = 0.0

# But: Green Bay values WR more due to need
need_multiplier = 1.0 + (0.65 * 0.3) = 1.195
adjusted_receiving_value = 20.0 * 1.195 = 23.9

# Green Bay feels they won:
net = +3.9 value (after need adjustment)

Result: Both teams happy (different valuations)
```

### Trade Outcome

**Trade Executed**:
```
Carolina Storm trades WR Marcus Brown (30, rating 80)
to Green Bay Wolves for CB Kevin Hayes (24, rating 74) + TE backup

Motivation: Deadline trade (seller gets future value, buyer gets win-now help)
Value: Perfectly balanced by market value (20.0 for 20.0)
Winner: Balanced (Carolina gets youth, Green Bay gets production)

Headline: "Wolves add veteran Brown to bolster passing attack for playoff run"
```

**Why This Trade Works**:
- Carolina: Gets young CB with upside (rebuilding asset)
- Green Bay: Gets proven WR for playoff push (win-now asset)
- Value exactly equal (20.0 = 20.0), fairness beyond question
- Timelines aligned (seller trades present for future, buyer opposite)
- Both GMs would defend trade to fanbase

**Lesson**: Balanced trades occur when teams have opposite timelines but complementary needs. Neither team "wins" by value, both win by fit.

---

## Scenario 5: Trade Rejection Examples

### Example 5A: Untouchable Player

**Proposed Trade**:
```
Kansas City Empire (10-1) receives offer:
Give: Franchise QB (age 26, rating 92)
Receive: 3 first-round picks (Phase 2 value: ~45.0)

Value Analysis:
QB value: 55.0
Picks value: 45.0
Pct diff: 18%  (within tolerance)
```

**Rejection**:
```gdscript
{
  "reason": "untouchable_player",
  "player_id": "p_qb_franchise_001",
  "untouchable_type": "franchise_qb",
  "details": {
    "position": "QB",
    "age": 26,
    "rating": 92,
    "status": "franchise_cornerstone"
  },
  "message": "Franchise QB not available at any price. Organizational cornerstone."
}
```

**Lesson**: Some players are more valuable than market value suggests. Team identity > pure value.

---

### Example 5B: Positional Constraint

**Proposed Trade**:
```
Arizona Scorpions receives offer:
Give: Starting QB (only healthy QB on roster)
Receive: Elite WR (higher value)

Value Analysis:
QB value: 25.0
WR value: 30.0
QB wins by value
```

**Rejection**:
```gdscript
{
  "reason": "positional_constraint",
  "position": "QB",
  "details": {
    "current_depth": 2,
    "healthy_count": 1,
    "minimum_depth": 2,
    "message": "Cannot trade only healthy QB. Must have 2 healthy QBs to trade one."
  }
}
```

**Lesson**: Roster construction trumps value. Can't trade into impossible situation.

---

### Example 5C: Cap Space Insufficient

**Proposed Trade**:
```
Indianapolis Colts receives offer:
Give: Cheap veteran LB ($3M/year)
Receive: Star DE ($25M/year)

Value Analysis: Colts win massively
Cap Situation: Only $8M cap space
```

**Rejection**:
```gdscript
{
  "reason": "cap_space_insufficient",
  "details": {
    "current_cap_space": 8.0,
    "player_contract": 25.0,
    "shortfall": 17.0,
    "message": "Insufficient cap space. Need $17M more to absorb contract."
  }
}
```

**Lesson**: Cap is hard constraint. Can't trade for players you can't afford.

---

## Summary: Key Patterns

### Pattern Recognition

**Win-Win Trades** (Most Common):
- Complementary timelines (contender + rebuilder)
- Complementary needs (surplus + deficit)
- Fair value within tolerance
- Both teams satisfied

**Leverage Trades** (Injury/Desperation):
- One team desperate (injury crisis, cap trouble)
- Receiving team "overpays" by market value
- Justified by urgency and need multipliers
- Desperate team still accepts (better than alternative)

**Rejected Trades** (Most Common):
- Division rivals (penalty too high)
- Untouchable players (organizational importance)
- Value imbalance (exceeds tolerance)
- Roster construction impossible

### Configuration Impact

**If trades too rare**:
- Increase trade_frequency in config
- Lower division_rival_penalty
- Increase trade_value_tolerance

**If trades too common**:
- Decrease trade_frequency
- Raise division_rival_penalty
- Tighten trade_value_tolerance

**If trades too lopsided**:
- Lower trade_value_tolerance
- Reduce urgency_bonus
- Increase untouchables thresholds

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial scenario examples |
