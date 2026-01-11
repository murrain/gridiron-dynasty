# Salary Cap Specification

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: [CONTRACT_SYSTEM_ARCHITECTURE.md](/home/patrick/Documents/code/gridiron-dynasty/docs/architectural_notes/CONTRACT_SYSTEM_ARCHITECTURE.md)

---

## Executive Summary

This document specifies the detailed mechanics of the salary cap system, including cap calculation formulas, dead money accounting, cap manipulation strategies, and enforcement rules. The salary cap creates the primary economic constraint that drives team-building trade-offs and makes contract management strategically interesting.

**Design Principles**:
- **Simplicity First**: Phase 1 uses simple annual cap hits, complexity added incrementally
- **NFL-Inspired**: Mechanics loosely based on NFL CBA rules (not exact replica)
- **Configuration-Driven**: All cap values, inflation rates, and rules in JSON files
- **Deterministic**: Cap calculations are reproducible from contract data alone

---

## Cap Accounting Fundamentals

### Basic Cap Hit Calculation (Phase 1)

**Simplest model**: Cap hit = annual contract value

```gdscript
func calculate_cap_hit_phase1(contract: Dictionary) -> float:
  if contract.get("status") != "active":
    return 0.0

  return float(contract.get("annual_value", 0.0))
```

**Example**:
```
Contract: 4 years, $40M total
Annual value: $40M / 4 = $10M per year
Cap hit each year: $10M
```

**Advantages**:
- Extremely simple to understand and implement
- No year-by-year cap charge array needed
- Works for bootstrap validation

**Limitations**:
- No signing bonus amortization
- No ability to structure contracts for cap relief
- All years count equally (no front/back loading)

### Advanced Cap Hit Calculation (Phase 3)

**Structured model**: Cap hit = base salary + bonus proration + incentives

```gdscript
func calculate_cap_hit_phase3(contract: Dictionary, year: int) -> float:
  if contract.get("status") != "active":
    return 0.0

  var year_idx = int(contract.get("current_year", 1)) - 1
  var year_values = contract.get("year_values", [])

  # Base salary for this year
  var base_salary = 0.0
  if year_idx >= 0 and year_idx < year_values.size():
    base_salary = float(year_values[year_idx])
  else:
    # Fallback if year_values not populated
    base_salary = float(contract.get("annual_value", 0.0))

  # Signing bonus proration (amortized over contract)
  var bonus_proration = float(contract.get("bonus_proration", 0.0))

  # Performance incentives (simplified: likely to be earned)
  var incentives = float(contract.get("incentives", 0.0))

  return base_salary + bonus_proration + incentives
```

**Example**:
```
Contract: 4 years, $40M total, $10M signing bonus
Structure:
  Year 1: $5M base + $2.5M bonus proration = $7.5M cap hit
  Year 2: $7M base + $2.5M bonus proration = $9.5M cap hit
  Year 3: $9M base + $2.5M bonus proration = $11.5M cap hit
  Year 4: $9M base + $2.5M bonus proration = $11.5M cap hit
Total: $30M base + $10M bonus = $40M

Why this structure?
- Lower Year 1 cap hit (easier to sign)
- Signing bonus $10M paid upfront, spread over 4 years for cap purposes
- Cap hit increases over time (typical NFL structure)
```

### Team Total Cap Usage

```gdscript
func calculate_team_cap_used(roster: Dictionary, year: int) -> float:
  var players = roster.get("players", [])
  var total = 0.0

  for player in players:
    var p = player as Dictionary
    var contract = p.get("contract", {})

    # Only count active contracts
    if contract.get("status") != "active":
      continue

    # Phase 1: Simple
    var cap_hit = calculate_cap_hit_phase1(contract)

    # Phase 3: Advanced
    # var cap_hit = calculate_cap_hit_phase3(contract, year)

    total += cap_hit

  return total
```

---

## Dead Money Mechanics

### What is Dead Money?

**Definition**: Cap charge from a player no longer on the roster due to release or trade.

**Why it exists**: Guaranteed money must be accounted for even if player is gone. This prevents teams from easily escaping bad contracts.

**Strategic implication**: Teams must balance short-term cap relief (releasing expensive player) vs long-term cap damage (dead money).

### Dead Money Calculation (Phase 1 - Simplified)

**Formula**: Remaining guaranteed money spread over remaining years

```gdscript
func calculate_dead_money_phase1(contract: Dictionary) -> float:
  var guaranteed = float(contract.get("guaranteed", 0.0))
  var years_total = int(contract.get("total_years", 1))
  var current_year = int(contract.get("current_year", 1))
  var years_elapsed = current_year - 1
  var years_remaining = max(0, years_total - years_elapsed)

  if years_remaining <= 0:
    return 0.0

  # Guaranteed money vests equally per year (simplified)
  var guaranteed_per_year = guaranteed / years_total
  return guaranteed_per_year * years_remaining
```

**Example**:
```
Contract: 4 years, $40M total, $24M guaranteed ($6M per year)
After Year 1:
  - Years remaining: 3
  - Dead money if released: $6M × 3 = $18M

After Year 2:
  - Years remaining: 2
  - Dead money if released: $6M × 2 = $12M
```

**Net Savings from Release**:
```
Cap savings = current_cap_hit - dead_money

Year 1 release:
  - Current cap hit: $10M (annual value)
  - Dead money: $18M
  - Net impact: -$8M (WORSE for cap!)
  - Conclusion: Don't release in Year 1

Year 3 release:
  - Current cap hit: $10M
  - Dead money: $6M
  - Net savings: $4M
  - Conclusion: Can save money if needed
```

### Dead Money Calculation (Phase 3 - Bonus Acceleration)

**Formula**: All remaining bonus proration accelerates immediately + remaining guaranteed base salary

```gdscript
func calculate_dead_money_phase3(contract: Dictionary) -> float:
  var years_remaining = int(contract.get("years_remaining", 0))

  if years_remaining <= 0:
    return 0.0

  # Signing bonus acceleration: all remaining proration hits immediately
  var bonus_proration = float(contract.get("bonus_proration", 0.0))
  var accelerated_bonus = bonus_proration * years_remaining

  # Guaranteed base salary remaining
  var year_values = contract.get("year_values", [])
  var year_guarantees = contract.get("year_guarantees", [])  # Array of 0.0-1.0
  var current_year = int(contract.get("current_year", 1))
  var guaranteed_remaining = 0.0

  for i in range(current_year - 1, year_values.size()):
    if i >= year_guarantees.size():
      break
    var year_salary = float(year_values[i])
    var guarantee_pct = float(year_guarantees[i])
    guaranteed_remaining += year_salary * guarantee_pct

  return accelerated_bonus + guaranteed_remaining
```

**Example**:
```
Contract: 4 years, $40M total, $10M signing bonus, $20M guaranteed base
Structure:
  Year 1: $5M base (fully guaranteed), $2.5M bonus proration
  Year 2: $7M base (fully guaranteed), $2.5M bonus proration
  Year 3: $9M base ($4M guaranteed), $2.5M bonus proration
  Year 4: $9M base (not guaranteed), $2.5M bonus proration

Release after Year 1:
  - Accelerated bonus: $2.5M × 3 = $7.5M (immediate cap hit)
  - Guaranteed base remaining: $7M (Y2) + $4M (Y3) = $11M
  - Total dead money: $7.5M + $11M = $18.5M
  - Current cap hit if kept: $9.5M (Y2 cap hit)
  - Net impact: $18.5M - $9.5M = $9M WORSE
```

### Dead Money Spreading (Phase 4 - June 1 Designation)

**NFL Rule**: Post-June 1 cuts spread dead money over 2 years instead of immediate acceleration.

```gdscript
func calculate_dead_money_june1(contract: Dictionary) -> Dictionary:
  var total_dead = calculate_dead_money_phase3(contract)
  var current_year_charge = float(contract.get("bonus_proration", 0.0))  # This year's proration
  var next_year_charge = total_dead - current_year_charge

  return {
    "current_year": current_year_charge,
    "next_year": next_year_charge,
    "total": total_dead
  }
```

**Example** (same contract as above):
```
Normal release after Year 1: $18.5M dead money immediately

June 1 release after Year 1:
  - Year 1 dead money: $2.5M (current year's bonus proration only)
  - Year 2 dead money: $16M (remaining $7.5M bonus + $11M guaranteed base)
  - Total: Same $18.5M, but spread over 2 years

Strategic benefit: More cap space in Year 1 to sign replacements
```

---

## Cap Manipulation Strategies

### Contract Restructuring (Phase 3)

**Concept**: Convert base salary to signing bonus to reduce current year cap hit.

**Mechanism**:
1. Take portion of current year's base salary
2. Convert it to signing bonus
3. Signing bonus prorates over remaining years
4. Current year cap hit decreases
5. Future year cap hits increase

```gdscript
func restructure_contract(
  contract: Dictionary,
  amount_to_convert: float,
  current_year: int
) -> Dictionary:
  var years_remaining = int(contract.get("years_remaining", 0))

  if years_remaining <= 0:
    return contract  # Can't restructure expired contract

  var year_values = contract.get("year_values", [])
  var year_idx = int(contract.get("current_year", 1)) - 1

  if year_idx < 0 or year_idx >= year_values.size():
    return contract

  # Reduce current year base salary
  var current_base = float(year_values[year_idx])
  var new_base = max(0.0, current_base - amount_to_convert)
  year_values[year_idx] = new_base

  # Add to signing bonus and recalculate proration
  var signing_bonus = float(contract.get("signing_bonus", 0.0))
  signing_bonus += amount_to_convert

  # New proration: total bonus / remaining years
  var new_proration = signing_bonus / years_remaining

  contract["year_values"] = year_values
  contract["signing_bonus"] = signing_bonus
  contract["bonus_proration"] = new_proration

  # Recalculate cap hit for current year
  contract["cap_hit"] = new_base + new_proration

  return contract
```

**Example**:
```
Original contract (Year 2 of 4):
  Year 2: $10M base + $2M bonus proration = $12M cap hit
  Years remaining: 3

Restructure: Convert $6M base to bonus
  New Year 2: $4M base + $4M bonus proration = $8M cap hit (saved $4M)
  Future years: Each gains $2M in cap hit ($6M / 3 years)

  Year 2: $4M base + $4M proration = $8M (-$4M)
  Year 3: $10M base + $4M proration = $14M (+$2M)
  Year 4: $10M base + $4M proration = $14M (+$2M)

Total contract value unchanged, but cap hits shifted.
```

**When teams restructure**:
- Need immediate cap space to sign free agents
- "Win-now" mode (sacrificing future flexibility)
- Avoiding cap violation in current year
- Star players on contending teams

**Downside**:
- Increases dead money if player released
- Harder to cut player in future years
- "Kicking the can down the road" (cap debt accumulates)

### Extension Timing Strategy

**Question**: When should teams extend players?

**Option 1**: Extend 2 years before expiration
- **Pros**: Lock in player before market value rises, avoid bidding war
- **Cons**: Commit money early, risk injury/regression

**Option 2**: Extend 1 year before expiration
- **Pros**: More data on player's trajectory, less risk
- **Cons**: Higher price if player has good year, competitive pressure

**Option 3**: Let reach free agency
- **Pros**: Maximum flexibility, no overpay risk
- **Cons**: May lose player, bidding war, expensive

```gdscript
# GM decision logic for extension timing
func should_extend_player(
  player: Dictionary,
  contract: Dictionary,
  team_context: Dictionary,
  valuation: Dictionary
) -> bool:
  var years_remaining = int(contract.get("years_remaining", 0))
  var age = int(player.get("age", 25))
  var team_premium = float(valuation.get("team_premium", 0.0))

  # Don't extend if more than 2 years left
  if years_remaining > 2:
    return false

  # Don't extend old players (1-year deals)
  if age >= 32:
    return false

  # High priority: Irreplaceable players (high team premium)
  if team_premium > 10.0:
    return years_remaining <= 2  # Extend 2 years early

  # Medium priority: Solid starters
  if team_premium > 0:
    return years_remaining <= 1  # Extend 1 year early

  # Low priority: Let walk
  return false
```

---

## Cap Limits and Growth

### League-Wide Cap Settings

**Configuration** (`league.json`):
```json
{
  "cap_limit": 225.0,
  "_comment": "Starting cap in Year 1 (millions)",

  "cap_floor": 200.0,
  "_comment": "Minimum team spending (89% of cap, NFL CBA)",

  "cap_growth_rate": 0.05,
  "_comment": "Annual increase (5% typical, tracks revenue growth)",

  "cap_growth_type": "compound",
  "_comment": "compound or flat (compound = exponential)",

  "cap_history": []
  "_comment": "Phase 4: Track actual cap by year for historical accuracy"
}
```

### Cap Growth Calculation

```gdscript
func calculate_league_cap(base_year: int, current_year: int, config: Dictionary) -> float:
  var base_cap = float(config.get("cap_limit", 225.0))
  var growth_rate = float(config.get("cap_growth_rate", 0.05))
  var growth_type = String(config.get("cap_growth_type", "compound"))
  var years_elapsed = current_year - base_year

  if years_elapsed <= 0:
    return base_cap

  if growth_type == "compound":
    # Exponential growth: cap * (1 + rate)^years
    return base_cap * pow(1.0 + growth_rate, years_elapsed)
  else:
    # Linear growth: cap + (rate * cap * years)
    return base_cap + (base_cap * growth_rate * years_elapsed)

# Example: $225M base, 5% growth, 20 years
# Year 1: $225.0M
# Year 5: $225M × 1.05^4 = $273.5M
# Year 10: $225M × 1.05^9 = $348.5M
# Year 20: $225M × 1.05^19 = $567.7M
```

**Why cap grows**:
- Reflects league revenue growth (TV deals, merchandise, etc.)
- Keeps veteran contracts affordable over time
- Allows young players to eventually earn high contracts

**Design choice**: 5% annual growth = reasonable middle ground
- NFL actual: Varies 3-8% per year depending on TV deals
- Too low: Veterans contracts balloon relative to cap
- Too high: Rookie contracts become insignificant

### Cap Floor Enforcement

**NFL Rule**: Teams must spend at least 89% of cap over 4-year periods.

```gdscript
func check_cap_floor_compliance(
  team_id: String,
  cap_history: Array,  # Last 4 years of cap usage
  cap_limits: Array,   # Last 4 years of league cap
  floor_pct: float = 0.89
) -> Dictionary:
  if cap_history.size() < 4:
    return {"compliant": true, "too_soon": true}

  var total_spent = 0.0
  var total_allowed = 0.0

  for i in range(cap_history.size()):
    total_spent += float(cap_history[i])
    total_allowed += float(cap_limits[i])

  var required = total_allowed * floor_pct
  var compliant = (total_spent >= required)

  return {
    "compliant": compliant,
    "total_spent": total_spent,
    "required": required,
    "shortfall": max(0.0, required - total_spent)
  }
```

**Implementation note**: Phase 1 does not enforce floor (only ceiling). Phase 4 adds floor enforcement.

---

## Cap Violation Handling

### Violation Detection

```gdscript
func detect_cap_violations(
  teams: Array,
  rosters: Dictionary,
  league_cap: float,
  year: int
) -> Array:
  var violations = []

  for team in teams:
    var t = team as Dictionary
    var team_id = String(t.get("id"))
    var roster = rosters.get(team_id, {})

    var cap_used = CapTracking.calculate_team_cap_used(roster)

    if cap_used > league_cap:
      violations.append({
        "team_id": team_id,
        "year": year,
        "cap_used": cap_used,
        "league_cap": league_cap,
        "overage": cap_used - league_cap,
        "severity": _calculate_severity(cap_used - league_cap, league_cap)
      })

  return violations

func _calculate_severity(overage: float, cap: float) -> String:
  var pct = (overage / cap) * 100.0
  if pct > 10.0:
    return "critical"  # >10% over (massive violation)
  elif pct > 5.0:
    return "major"     # 5-10% over
  else:
    return "minor"     # <5% over
```

### Automatic Enforcement (Phase 1)

**Strategy**: Force release lowest-value players until compliant.

```gdscript
func enforce_cap_compliance(
  team_id: String,
  roster: Dictionary,
  league_cap: float,
  year: int
) -> Dictionary:
  var cap_used = CapTracking.calculate_team_cap_used(roster)
  var overage = cap_used - league_cap

  if overage <= 0:
    return {"compliant": true, "releases": []}

  var players = roster.get("players", [])

  # Sort players by "value per cap dollar" (lowest first)
  var candidates = []
  for player in players:
    var p = player as Dictionary
    var contract = p.get("contract", {})
    var cap_hit = ContractLifecycle.calculate_cap_hit(contract)
    var dead_money = ContractLifecycle.calculate_dead_money(contract)
    var net_savings = cap_hit - dead_money

    if net_savings <= 0:
      continue  # No cap savings from release

    var eval_score = float(p.get("eval_score", 50.0))
    var value_per_cap = eval_score / max(1.0, cap_hit)

    candidates.append({
      "player": p,
      "cap_hit": cap_hit,
      "dead_money": dead_money,
      "net_savings": net_savings,
      "value_per_cap": value_per_cap
    })

  # Sort by value_per_cap (worst value first)
  candidates.sort_custom(func(a, b): return a.value_per_cap < b.value_per_cap)

  # Release players until under cap
  var releases = []
  var cap_saved = 0.0

  for candidate in candidates:
    if cap_saved >= overage:
      break

    var player = candidate.player
    release_player(player, team_id, year)
    releases.append(String(player.get("player_id")))
    cap_saved += candidate.net_savings

  return {
    "compliant": (cap_saved >= overage),
    "releases": releases,
    "cap_saved": cap_saved,
    "remaining_overage": max(0.0, overage - cap_saved)
  }
```

**Why automatic enforcement**:
- No GM intervention required (simulation can continue)
- Deterministic outcome (same inputs = same releases)
- Forces teams to manage cap proactively
- Simulates "cap hell" scenarios realistically

**Alternative approaches** (future phases):
- Manual GM decisions: Choose which players to cut
- Contract restructuring first: Attempt to create space before releases
- Grace period: Allow 1 year to get compliant (with penalties)

---

## Salary Distribution by Position

### Market Distribution Targets

**Goal**: After 20-year simulation, salary distribution should match realistic NFL patterns.

**Position Salary Shares** (target distribution):
```json
{
  "position_salary_targets": {
    "QB": 0.18,
    "_QB_comment": "18% of cap (most expensive position)",
    "EDGE": 0.12,
    "CB": 0.10,
    "WR": 0.10,
    "OL": 0.09,
    "DL": 0.08,
    "LB": 0.07,
    "S": 0.06,
    "TE": 0.05,
    "RB": 0.04,
    "K": 0.01,
    "P": 0.01
  }
}
```

**Validation test** (after bootstrap):
```gdscript
func validate_salary_distribution(rosters: Dictionary, league_cap: float) -> Dictionary:
  var position_totals = {}
  var total_cap_used = 0.0

  for roster in rosters.values():
    var players = roster.get("players", [])
    for player in players:
      var p = player as Dictionary
      var position = String(p.get("position"))
      var contract = p.get("contract", {})
      var cap_hit = ContractLifecycle.calculate_cap_hit(contract)

      if not position_totals.has(position):
        position_totals[position] = 0.0
      position_totals[position] += cap_hit
      total_cap_used += cap_hit

  # Calculate percentages
  var distribution = {}
  for position in position_totals.keys():
    distribution[position] = position_totals[position] / total_cap_used

  return distribution

# Example output after 20 years:
# {
#   "QB": 0.179,     # Close to 18% target ✓
#   "EDGE": 0.115,   # Close to 12% target ✓
#   "K": 0.012,      # Close to 1% target ✓
#   ...
# }
```

---

## Rookie Wage Scale

### Slotted Rookie Contracts

**NFL CBA**: Rookie contracts are slotted by draft position to prevent rookie overpayment.

**Configuration** (`league.json`):
```json
{
  "rookie_contract_scale": {
    "round_1": {
      "pick_1": {
        "total": 36.0,
        "years": 4,
        "guaranteed_pct": 1.0,
        "fifth_year_option": true
      },
      "pick_10": {"total": 18.0, "years": 4, "guaranteed_pct": 1.0},
      "pick_20": {"total": 12.0, "years": 4, "guaranteed_pct": 1.0},
      "pick_32": {"total": 8.0, "years": 4, "guaranteed_pct": 1.0}
    },
    "round_2_3": {
      "base": 3.0,
      "years": 4,
      "guaranteed_pct": 0.5
    },
    "round_4_7": {
      "base": 1.0,
      "years": 4,
      "guaranteed_pct": 0.0
    }
  }
}
```

**Interpolation for picks 2-32**:
```gdscript
func calculate_rookie_contract_value(pick: int, scale: Dictionary) -> float:
  var round = (pick - 1) / 32 + 1

  if round == 1:
    var round1 = scale.get("round_1", {})
    var pick_in_round = ((pick - 1) % 32) + 1

    # Linear interpolation between known values
    if pick_in_round <= 10:
      var v1 = float(round1.get("pick_1", {}).get("total", 36.0))
      var v10 = float(round1.get("pick_10", {}).get("total", 18.0))
      var t = (pick_in_round - 1) / 9.0
      return v1 * (1.0 - t) + v10 * t

    elif pick_in_round <= 20:
      var v10 = float(round1.get("pick_10", {}).get("total", 18.0))
      var v20 = float(round1.get("pick_20", {}).get("total", 12.0))
      var t = (pick_in_round - 10) / 10.0
      return v10 * (1.0 - t) + v20 * t

    else:
      var v20 = float(round1.get("pick_20", {}).get("total", 12.0))
      var v32 = float(round1.get("pick_32", {}).get("total", 8.0))
      var t = (pick_in_round - 20) / 12.0
      return v20 * (1.0 - t) + v32 * t

  elif round <= 3:
    return float(scale.get("round_2_3", {}).get("base", 3.0))
  else:
    return float(scale.get("round_4_7", {}).get("base", 1.0))
```

**Example outputs**:
```
Pick 1:  $36.0M / 4 years = $9.0M APY
Pick 5:  $27.0M / 4 years = $6.75M APY
Pick 10: $18.0M / 4 years = $4.5M APY
Pick 32: $8.0M / 4 years = $2.0M APY
Pick 64: $3.0M / 4 years = $0.75M APY (Round 2)
Pick 224: $1.0M / 4 years = $0.25M APY (Round 7)
```

**Design rationale**:
- Prevents Andrew Luck situation (2012: $22M signing bonus as rookie)
- Creates predictable cap cost for drafted players
- Young players still on cheap contracts = competitive advantage
- 4-year term ensures 1 contract before free agency

---

## Cap Carryover (Phase 4)

### Unused Cap Rollover

**NFL Rule**: Unused cap space can roll over to next year (since 2011 CBA).

```gdscript
func calculate_cap_carryover(
  cap_used: float,
  league_cap: float,
  max_carryover_pct: float = 0.10
) -> float:
  var unused = max(0.0, league_cap - cap_used)
  var max_carryover = league_cap * max_carryover_pct

  return min(unused, max_carryover)

# Example:
# League cap: $225M
# Cap used: $210M
# Unused: $15M
# Max carryover (10%): $22.5M
# Actual carryover: $15M (all unused space)

# Next year effective cap: $236.25M + $15M = $251.25M
```

**Strategic implications**:
- Rebuilding teams accumulate cap space
- Contenders maximize cap usage (less carryover)
- Multi-year planning becomes important
- "Cap banking" for future free agency splurges

---

## Testing and Validation

### Unit Tests

**Test: Cap hit calculation**
- Active contract with annual value: Returns annual_value
- Expired contract: Returns 0
- Phase 3: Verify base + bonus proration math

**Test: Dead money calculation**
- Contract with guaranteed money: Correct proration
- Fully guaranteed contract: Dead money = total remaining
- No guarantees: Dead money = 0

**Test: Cap violation detection**
- Team over cap: Detected
- Team under cap: Not flagged
- Multiple teams: All violations found

**Test: Rookie contract scaling**
- Pick 1: $36M
- Pick 32: $8M
- Mid-round: Interpolated correctly

### Integration Tests

**Test: 20-year bootstrap cap distribution**
- Mean cap usage: 85-95% of cap
- No teams chronically over cap (enforcement works)
- Position salary shares match targets (±5%)

**Test: Cap growth over time**
- Year 1: $225M
- Year 20: ~$567M (5% compound growth)
- Player salaries scale proportionally

### Statistical Validation

After 20-year simulation:
```gdscript
{
  "cap_statistics": {
    "mean_usage_pct": 0.91,        # 91% of cap used (realistic)
    "std_dev_usage_pct": 0.06,     # Low variance (teams near cap)
    "violations_total": 5,          # Very rare over 640 team-years (32 teams × 20 years)
    "floor_violations": 12,         # Some tanking teams under floor (expected)
    "position_salary_accuracy": 0.94  # 94% match to target distribution
  }
}
```

---

## Configuration Reference

### Complete league.json Cap Section

```json
{
  "version": 3,

  "cap_limit": 225.0,
  "cap_floor": 200.0,
  "cap_growth_rate": 0.05,
  "cap_growth_type": "compound",

  "cap_enforcement": {
    "enabled": true,
    "violation_penalty": "force_release",
    "grace_period_days": 0,
    "floor_enforcement_years": 4,
    "floor_percentage": 0.89,
    "carryover_enabled": false,
    "max_carryover_pct": 0.10
  },

  "rookie_contract_scale": {
    "round_1": {
      "pick_1": {"total": 36.0, "years": 4, "guaranteed_pct": 1.0},
      "pick_10": {"total": 18.0, "years": 4, "guaranteed_pct": 1.0},
      "pick_20": {"total": 12.0, "years": 4, "guaranteed_pct": 1.0},
      "pick_32": {"total": 8.0, "years": 4, "guaranteed_pct": 1.0}
    },
    "round_2_3": {"base": 3.0, "years": 4, "guaranteed_pct": 0.5},
    "round_4_7": {"base": 1.0, "years": 4, "guaranteed_pct": 0.0}
  },

  "veteran_minimum": {
    "0_years": 0.75,
    "1_year": 0.9,
    "2_years": 1.0,
    "3_plus_years": 1.1
  },

  "position_salary_targets": {
    "QB": 0.18,
    "EDGE": 0.12,
    "CB": 0.10,
    "WR": 0.10,
    "OL": 0.09,
    "DL": 0.08,
    "LB": 0.07,
    "S": 0.06,
    "TE": 0.05,
    "RB": 0.04,
    "K": 0.01,
    "P": 0.01
  }
}
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial salary cap specification |
