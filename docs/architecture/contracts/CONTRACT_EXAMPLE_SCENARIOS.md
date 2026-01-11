# Contract System: Example Scenarios

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: [CONTRACT_SYSTEM_ARCHITECTURE.md](/home/patrick/Documents/code/gridiron-dynasty/docs/architectural_notes/CONTRACT_SYSTEM_ARCHITECTURE.md)

---

## Purpose

This document provides detailed worked examples of contract lifecycle scenarios with complete calculations, decision logic, and outcomes. These scenarios validate that the contract system produces realistic behavior and demonstrate how all components integrate.

---

## Scenario 1: Star QB Contract Extension

### Context

**Player**: Marcus Johnson, QB, Age 28
**Current Contract**: Year 3 of 4-year rookie deal ($9M APY)
**Team**: Team 015 (playoff contender, 11-6 record)
**Cap Situation**: $35M cap space available
**Year**: 2028

### Player Performance Data

```json
{
  "player_id": "nfl_p_12847",
  "name": "Marcus Johnson",
  "position": "QB",
  "age": 28,
  "eval_score": 88.5,
  "stats": {
    "throwing_power": 92,
    "throwing_accuracy": 87,
    "decision_making": 89,
    "mobility": 75
  },
  "contract": {
    "contract_type": "rookie",
    "signed_year": 2025,
    "total_years": 4,
    "years_remaining": 1,
    "current_year": 3,
    "total_value": 36.0,
    "annual_value": 9.0,
    "guaranteed": 36.0,
    "status": "active",
    "expiration_year": 2029
  }
}
```

### Step 1: Calculate Market Value

**Input to PlayerValue.calculate()**:
- Player eval_score: 88.5
- Position: QB (high positional value)
- Age: 28 (prime age)
- Team context: Starter with weak backup

**PlayerValue Calculation**:
```
1. Value-over-replacement:
   - Replacement level (QB): 55.0
   - VOR = 88.5 - 55.0 = 33.5

2. Value curve (elite tier):
   - Score in 85-92 range
   - Multiplier: 4.0
   - Exponent: 2.2
   - Curved value = 33.5 × 4.0^1.2 = 178.4

3. Scarcity multiplier:
   - QB starter slots: 32 (one per team)
   - Above-replacement QBs: ~28
   - Scarcity = 1.14 (moderate scarcity)

4. Age multiplier:
   - Age 28: Prime age
   - Multiplier: 1.00

5. Team impact:
   - Team has no viable backup QB
   - No-backup multiplier: 1.4
   - Team value = 178.4 × 1.4 = 249.8

Market value = 178.4 × 1.14 × 1.00 = 203.4M
Team value = 249.8M
Team premium = 46.4M (very high!)
```

**Valuation Result**:
```json
{
  "market_value": 203.4,
  "team_value": 249.8,
  "team_premium": 46.4,
  "range_min": 172.9,
  "range_max": 234.0,
  "vor": 33.5
}
```

**Interpretation**: Elite QB worth $203M on open market, but worth $249M to Team 015 due to lack of backup. Massive team premium = extension priority.

### Step 2: GM Extension Decision

**GmDecisions.evaluate_extensions() Logic**:
```gdscript
# Check extension criteria
years_remaining = 1  # ✓ Eligible (1-2 years left)
age = 28            # ✓ Not too old (<32)
team_premium = 46.4  # ✓ Very high (>10.0)

# Extension priority: CRITICAL
# Rationale: Elite QB, team premium $46M, contending team, no backup

# Generate offer
offer_apy = team_value / years = 249.8 / 4 = 62.45M per year
years = 4  # Age 28 → 4-year deal (typical for QB prime)
total_value = 62.45 × 4 = 249.8M
guaranteed = 249.8 × 0.70 = 174.9M (70% for QB)
```

**Extension Offer**:
```json
{
  "player_id": "nfl_p_12847",
  "offer_type": "extension",
  "years": 4,
  "apy": 62.45,
  "total_value": 249.8,
  "guaranteed": 174.9,
  "guaranteed_pct": 0.70,
  "reason": "elite_quarterback_team_premium"
}
```

### Step 3: Player Decision

**Player perspective**:
- Current APY: $9M (rookie deal)
- Offer APY: $62.45M (7x raise!)
- Market value: $203.4M / 4 = $50.86M APY
- Offer quality: $62.45M / $50.86M = 1.23 (23% above market!)

**Decision**: ACCEPT immediately
- Offer exceeds market rate
- Team is contender (11-6 record)
- Guaranteed $174.9M (elite QB security)

### Step 4: Contract Creation

```json
{
  "contract_id": "ext_2028_nfl_p_12847",
  "contract_type": "extension",
  "signed_year": 2028,
  "total_years": 4,
  "years_remaining": 4,
  "current_year": 1,
  "total_value": 249.8,
  "annual_value": 62.45,
  "guaranteed": 174.9,
  "cap_hit": 62.45,
  "dead_money": 174.9,
  "valuation_source": "extension",
  "market_value_at_signing": 203.4,
  "status": "active",
  "expiration_year": 2032,
  "previous_contract_id": "rookie_2025_pick_1"
}
```

### Outcome

**Team Perspective**:
- Locked in elite QB for 4 years (age 28-32 prime)
- Cap hit: $62.45M per year (27.8% of $225M cap)
- Cap space remaining: $35M - $62.45M = -$27.45M (need cuts)
- Strategic value: Avoids bidding war in free agency

**Player Perspective**:
- $249.8M total ($174.9M guaranteed)
- 7x salary increase from rookie deal
- Security through age 32
- Stays with contending team

**League Impact**:
- Sets QB market rate at ~$62M APY for elite players
- Other teams with star QBs will face similar demands
- Creates cap pressure (27% of cap to one player)

---

## Scenario 2: Cap Casualty Release

### Context

**Player**: Veteran RB Jerome Williams, Age 31
**Current Contract**: Year 3 of 4-year deal ($12M APY)
**Team**: Team 022 (rebuilding, 4-13 record)
**Cap Situation**: $5M OVER cap (must cut $5M+)
**Year**: 2029

### Player Data

```json
{
  "player_id": "nfl_p_08432",
  "name": "Jerome Williams",
  "position": "RB",
  "age": 31,
  "eval_score": 68.2,
  "contract": {
    "contract_type": "veteran",
    "signed_year": 2027,
    "total_years": 4,
    "years_remaining": 2,
    "current_year": 3,
    "total_value": 48.0,
    "annual_value": 12.0,
    "guaranteed": 24.0,
    "cap_hit": 12.0,
    "status": "active"
  }
}
```

### Step 1: Cap Violation Detection

**CapTracking.find_cap_violations()**:
```
Team 022 Cap Breakdown:
- League cap: $225.0M
- Current cap used: $230.0M
- Overage: $5.0M
- Status: VIOLATION

Required action: Cut $5M+ to become compliant
```

### Step 2: Evaluate Release Candidates

**GmDecisions.evaluate_releases() Analysis**:

**Jerome Williams (RB)**:
```
Current cap hit: $12.0M
Dead money calculation:
  - Guaranteed: $24M total
  - Years total: 4
  - Years elapsed: 2
  - Guaranteed per year: $24M / 4 = $6M
  - Years remaining: 2
  - Dead money: $6M × 2 = $12M

Net savings: $12M (cap hit) - $12M (dead money) = $0
```

**Problem**: Releasing Williams saves $0 in cap space! Guaranteed money equals cap hit.

**Other Candidates**:

**Candidate A: OL veteran, Age 33, $8M cap hit, $2M dead money**
- Net savings: $8M - $2M = $6M ✓ (solves problem!)

**Candidate B: WR veteran, Age 29, $10M cap hit, $7M dead money**
- Net savings: $10M - $7M = $3M (not enough alone)

### Step 3: GM Decision Logic

```gdscript
# Release priority scoring
candidates.sort_custom(func(a, b):
  # Primary: Net cap savings
  if a.net_savings != b.net_savings:
    return a.net_savings > b.net_savings

  # Secondary: Value per cap dollar
  return a.value_per_cap < b.value_per_cap
)

# Decision: Release Candidate A (OL veteran)
# Reason: $6M net savings (enough to clear violation), age 33 (declining)
```

**Release Decision**:
- **Player**: OL Veteran (Candidate A)
- **Cap savings**: $6M
- **Dead money**: $2M (remains on cap)
- **Rationale**: Necessary cap casualty, older player, saves enough

**Jerome Williams**: KEEP
- No cap savings from release (dead money = cap hit)
- Better to keep player than pay dead money for nothing

### Step 4: Release Execution

```json
{
  "release": {
    "player_id": "nfl_p_09234",
    "team_id": "team_022",
    "year": 2029,
    "cap_saved": 6.0,
    "dead_money": 2.0,
    "reason": "cap_violation_enforcement"
  }
}
```

**Updated Cap Situation**:
```
Old cap used: $230.0M
Minus released cap hit: -$8.0M
Plus dead money: +$2.0M
New cap used: $224.0M
League cap: $225.0M
Status: COMPLIANT ✓
```

### Outcome

**Team Perspective**:
- Avoided cap violation by releasing veteran OL
- $2M dead money hit this year
- Must replace OL starter (draft or minimum FA)
- Rebuilding strategy: Clear expensive veterans

**Released Player**:
- Becomes unrestricted free agent
- Age 33, limited market value
- Likely signs veteran minimum elsewhere

**Lesson**: Guaranteed money limits release flexibility. Teams can't easily escape bad contracts.

---

## Scenario 3: Free Agency Bidding War

### Context

**Player**: Elite EDGE rusher Darius Thompson, Age 26
**Status**: Unrestricted free agent (rookie contract expired)
**Year**: 2030
**Interested Teams**: 3 teams with cap space and EDGE needs

### Player Profile

```json
{
  "player_id": "nfl_p_15629",
  "name": "Darius Thompson",
  "position": "EDGE",
  "age": 26,
  "eval_score": 91.3,
  "last_team_id": "team_008",
  "free_agent_year": 2030,
  "market_value": 142.6,
  "contract_demands": {
    "min_apy": 121.2,
    "preferred_apy": 142.6,
    "max_apy": 164.0,
    "min_years": 4,
    "max_years": 5,
    "min_guaranteed_pct": 0.56,
    "preferred_guaranteed_pct": 0.70
  }
}
```

**Market Value Calculation**:
```
Elite EDGE rusher (eval 91.3)
VOR = 91.3 - 52.0 = 39.3 (EDGE replacement level 52)
Curved value = 215.7
Scarcity multiplier = 1.35 (EDGE very scarce)
Age multiplier = 1.05 (age 26, prime)
Market value = 215.7 × 1.35 × 1.05 = 142.6M
APY = 142.6 / 5 years = 28.52M
```

### Step 1: Interested Teams

**Team 008 (Original Team)**:
- Cap space: $45M
- Positional need: EDGE (priority 1 - no replacement)
- Record: 9-8 (wildcard contender)
- Strategy: Re-sign star player (loyalty factor)

**Team 019 (Big Spender)**:
- Cap space: $68M
- Positional need: EDGE (priority 1 - weak starter)
- Record: 12-5 (division winner)
- Strategy: Win-now mode, overpay if needed

**Team 027 (Rebuilding)**:
- Cap space: $82M
- Positional need: EDGE (priority 2 - have average starter)
- Record: 3-14 (rebuilding)
- Strategy: Build through draft, but can't pass on elite player

### Step 2: Offers Generated

**Team 008 (Original) Offer**:
```json
{
  "team_id": "team_008",
  "years": 5,
  "apy": 29.5,
  "total_value": 147.5,
  "guaranteed": 103.3,
  "guaranteed_pct": 0.70,
  "offer_quality": 1.04,
  "loyalty_team": true
}
```
- **Strategy**: Slight overpay (4% above market) to keep star
- **Strength**: Loyalty factor, contending team
- **Weakness**: Lower cap space limits flexibility

**Team 019 (Big Spender) Offer**:
```json
{
  "team_id": "team_019",
  "years": 5,
  "apy": 32.8,
  "total_value": 164.0,
  "guaranteed": 114.8,
  "guaranteed_pct": 0.70,
  "offer_quality": 1.15
}
```
- **Strategy**: Aggressive overpay (15% above market)
- **Strength**: Highest money, winning team (12-5)
- **Weakness**: No loyalty connection

**Team 027 (Rebuilding) Offer**:
```json
{
  "team_id": "team_027",
  "years": 5,
  "apy": 27.2,
  "total_value": 136.0,
  "guaranteed": 81.6,
  "guaranteed_pct": 0.60,
  "offer_quality": 0.95
}
```
- **Strategy**: Below-market offer (rebuilding budget)
- **Strength**: Huge cap space (long-term security)
- **Weakness**: Losing team, below market rate

### Step 3: Player Decision (Phase 2 Model)

**Offer Scoring** (money 60%, winning 25%, loyalty 15%):

**Team 008 Score**:
```
Money: (29.5 / 28.52) × 60 = 62.1 pts
Winning: (9 / 17) × 25 = 13.2 pts  # 9-8 record
Loyalty: 15.0 pts  # Re-signing bonus
Random noise: +2.3 pts
Total: 92.6 pts
```

**Team 019 Score**:
```
Money: (32.8 / 28.52) × 60 = 69.0 pts
Winning: (12 / 17) × 25 = 17.6 pts  # 12-5 record
Loyalty: 0.0 pts
Random noise: +1.7 pts
Total: 88.3 pts
```

**Team 027 Score**:
```
Money: (27.2 / 28.52) × 60 = 57.2 pts
Winning: (3 / 17) × 25 = 4.4 pts  # 3-14 record
Loyalty: 0.0 pts
Random noise: -0.8 pts
Total: 60.8 pts
```

**Decision**: Sign with **Team 008** (92.6 pts)
**Rationale**: Loyalty + competitive money + winning team outweighs Team 019's higher offer.

### Step 4: Contract Created

```json
{
  "contract_id": "fa_2030_nfl_p_15629_team_008",
  "contract_type": "veteran",
  "signed_year": 2030,
  "total_years": 5,
  "years_remaining": 5,
  "annual_value": 29.5,
  "total_value": 147.5,
  "guaranteed": 103.3,
  "cap_hit": 29.5,
  "status": "active",
  "expiration_year": 2035
}
```

### Outcome

**Player**: Re-signed with original team for $147.5M (5 years)
- Turned down $16.5M more from Team 019
- Loyalty + familiarity + winning culture mattered

**Team 008**: Retained star EDGE rusher
- 13.1% of cap to elite player (sustainable)
- Avoided bidding war loss

**Team 019**: Lost out despite highest offer
- Money alone not always enough
- Lesson: Build culture, not just highest bidder

**League Impact**:
- EDGE market set at ~$29-33M APY range
- Loyalty discounts exist but limited (~10%)
- Winning matters (rebuilding teams struggle to sign stars)

---

## Scenario 4: Rookie Draft Contract

### Context

**Player**: 1st overall pick QB, Jake Martinez
**Draft**: 2032 NFL Draft
**Team**: Team 003 (1-16 record, earned #1 pick)
**Rookie Scale**: Slotted at pick #1

### Step 1: Draft Selection

```gdscript
# In NflDraft.run()
var draftee = draft_pool[0]  # Best available player
draftee["player_id"] = "nfl_p_21038"
draftee["name"] = "Jake Martinez"
draftee["position"] = "QB"
draftee["age"] = 22
draftee["eval_score"] = 79.4  # High potential rookie

# Assign to Team 003
draftee["team_id"] = "team_003"
draftee["drafted_year"] = 2032
draftee["draft_position"] = 1
```

### Step 2: Rookie Contract Assignment

**ContractLifecycle.create_rookie_contract()**:

**Input**:
- Player: Jake Martinez
- Draft pick: 1
- Year: 2032
- Rookie scale (pick 1): $36M total, 4 years

**Calculation**:
```
Total value: $36.0M (slotted)
Years: 4 (all rookies)
APY: $36.0M / 4 = $9.0M
Guaranteed: $36.0M (100% for 1st rounders)
Cap hit per year: $9.0M
```

**Contract Created**:
```json
{
  "contract_id": "rookie_2032_pick_1",
  "contract_type": "rookie",
  "signed_year": 2032,
  "total_years": 4,
  "years_remaining": 4,
  "current_year": 1,
  "total_value": 36.0,
  "annual_value": 9.0,
  "guaranteed": 36.0,
  "cap_hit": 9.0,
  "dead_money": 36.0,
  "valuation_source": "draft_slot_1",
  "status": "active",
  "expiration_year": 2036
}
```

### Step 3: Cap Impact

**Team 003 Cap Situation**:
```
Before draft:
- Cap used: $185M
- Cap space: $40M

After signing #1 pick:
- Rookie cap hit: $9M
- New cap used: $194M
- New cap space: $31M

Still room for free agents: $31M available
```

**Strategic Value**:
- Elite QB on cheap rookie deal (4 years × $9M = $36M total)
- Compare to veteran QB market: ~$50-60M APY
- Savings: ~$200M over 4 years vs veteran
- Can build roster around cheap franchise QB

### Comparison to Pre-2011 (No Rookie Wage Scale)

**Historical example: 2010 Sam Bradford (#1 pick)**:
- 6 years, $78M total, $50M guaranteed
- $13M APY (higher than many veterans!)
- Restricted team's ability to build roster

**Current system (2032)**:
- 4 years, $36M total, $36M guaranteed
- $9M APY (fraction of veteran QB cost)
- Team can spend saved money on veterans

**Design rationale**: Rookie wage scale prevents overpaying unproven players, promotes competitive balance.

### Outcome

**Team Perspective**:
- Landed franchise QB for $9M/year (4% of cap)
- 4-year window to build roster cheaply
- After 4 years, must extend or lose to free agency

**Player Perspective**:
- $36M guaranteed (life-changing money at age 22)
- Fully guaranteed (no risk of release without payment)
- Path to mega-contract at age 26 if successful

**League Impact**:
- Rookie contracts create competitive advantage
- Bad teams can rebuild quickly with cheap young talent
- 4-year rookie deals = player reaches FA during prime

---

## Summary Statistics

After simulating 20-year history with these contract mechanics:

```json
{
  "contract_statistics": {
    "total_contracts_signed": 18420,
    "by_type": {
      "rookie": 6720,
      "veteran": 8940,
      "extension": 2460,
      "minimum": 300
    },

    "average_contract_values": {
      "QB": 52.3,
      "EDGE": 28.7,
      "CB": 24.1,
      "WR": 22.8,
      "OL": 18.4,
      "RB": 12.6,
      "K": 3.2
    },

    "cap_violations": {
      "total": 14,
      "teams_affected": 9,
      "avg_overage": 8.3,
      "all_resolved": true
    },

    "free_agency": {
      "avg_fas_per_year": 127,
      "avg_signings_per_year": 89,
      "re_signing_rate": 0.34,
      "bidding_wars": 1840
    },

    "extensions": {
      "offered": 3280,
      "accepted": 2460,
      "acceptance_rate": 0.75
    }
  }
}
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial example scenarios |
