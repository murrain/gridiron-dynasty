# Contract and Evaluation System Architecture

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Context**: NFL contract management and salary cap system for 20-year simulation

---

## Executive Summary

This document specifies the architecture for a comprehensive contract management and player evaluation system that enables realistic NFL team-building dynamics over 20+ years of simulation. The system integrates seamlessly with the existing `PlayerValue` valuation framework while adding contract lifecycle management, salary cap enforcement, free agency, and GM decision-making.

**Core Principles**:
- **Leverage Existing Systems**: Build on `PlayerValue`, `ContractValuation`, and `TeamImpact` rather than replacing them
- **Deterministic Economics**: All contract decisions are reproducible with seed-based RNG
- **Minimal Complexity**: Start with essential features, expand incrementally
- **Realistic Constraints**: Salary cap enforcement creates authentic team-building trade-offs
- **Data-Driven**: Configuration files control contract economics, not hardcoded values

**Architectural Decisions**:
1. **Contract as Player Property**: Contract data lives in `Player.contract` dictionary (already present)
2. **Team Cap Tracking**: Teams track salary cap via aggregation, not separate ledgers
3. **Phase Integration**: Free agency becomes new phase in world calendar between draft and season
4. **GM as Pure Functions**: Decision logic is stateless, takes world state and returns decisions
5. **Market Simulation**: Simple auction model with deterministic bidding strategies

---

## Design Philosophy

### 1. Architectural Coherence

The contract system must feel native to the existing architecture:

**Integration Points**:
- Extends `PlayerValue` for market value calculation (no duplication)
- Follows `NflSeason` pattern for contract year advancement
- Uses `world_state` dictionary for free agent pool persistence
- Aligns with deterministic RNG patterns from `AdvanceWorldYear`

**Pattern Consistency**:
- Configuration-driven behavior (JSON files define cap limits, rookie scales, etc.)
- Stateless functions with explicit parameters (no hidden global state)
- In-place mutation of world_state (standard pattern across codebase)
- Seed derivation follows `_derive_seed(year_seed, phase_id, step_id)` pattern

**Boundary Respect**:
- Valuation logic stays in `scripts/core/valuation/`
- Contract lifecycle in `scripts/world/ContractLifecycle.gd` (new)
- GM decisions in `scripts/world/GmDecisions.gd` (new)
- Free agency orchestration in `scripts/pipelines/FreeAgency.gd` (new)

### 2. Complexity Management

Build incrementally with clear phase boundaries:

**Phase 1 (MVP - Foundation)**:
- Basic contract model (years, annual value, guaranteed money)
- Salary cap tracking and enforcement
- Contract expiration and free agency pool
- Simple contract signings (no negotiation, just assign market value)
- Rookie contracts from draft (slotted by pick position)

**Phase 2 (Market Dynamics)**:
- Multi-team bidding for free agents
- Player preferences (winning team discount, hometown bias)
- GM decision logic (extensions, releases, franchise tags)
- Contract range negotiation (offers within market value ± spread)

**Phase 3 (Advanced Contracts)**:
- Signing bonus cap amortization
- Dead money from releases
- Contract restructuring for cap relief
- Performance incentives and escalators
- Trade clauses and contract options

**Phase 4 (Sophistication)**:
- Compensatory picks for lost free agents
- Transition tags and restricted free agency
- Cap penalty/rollover mechanics
- Multi-year contract strategy (analytics-driven GM)

**CRITICAL**: Each phase must be production-ready and valuable on its own. No skeleton implementations waiting for "later."

### 3. Lifecycle Analysis

Long-term maintenance considerations:

**Version 1 Constraints**:
- No complex contract negotiations (accept/reject only, not back-and-forth)
- No agent simulation (player demands are deterministic from value)
- No coaching staff contracts (only players)
- No injury guarantees vs skill guarantees (simple total guaranteed)
- No void years or post-career cap manipulation

**Future Expansion Hooks**:
- Contract model includes optional fields (unused in Phase 1-2)
- GM strategy pluggable (can add ML-based decision models later)
- Market model abstracted (can swap auction algorithm)
- Cap accounting supports multiple charge types (extensible)

**Migration Strategy**:
- Contract schema version field enables backward compatibility
- Missing contract data defaults to league minimum 1-year deal
- Cap validation can be run retroactively on old saves
- World state format supports schema evolution via version checks

### 4. Fit Assessment

How this integrates with existing architecture:

**Existing Systems Leveraged**:
```
PlayerValue.calculate()
  ├─> market_value: What player is worth in free agency
  ├─> team_value: Worth to current team (depth considerations)
  ├─> range_min/max: Contract negotiation bounds
  └─> components: Detailed valuation breakdown

ContractValuation.estimate_value()
  ├─> apy: Average per year (market value)
  ├─> years: Typical contract length by age
  ├─> total: Total contract value
  └─> Already returns all data needed for contract creation!
```

**New Systems Required**:
```
ContractLifecycle (NEW)
  ├─> advance_contract_year(): Decrement years_remaining
  ├─> check_expiration(): Identify free agents
  ├─> sign_contract(): Create contract from valuation
  └─> release_player(): Handle dead money

GmDecisions (NEW)
  ├─> evaluate_extensions(): Which players to extend early
  ├─> evaluate_releases(): Who to cut for cap space
  ├─> prioritize_free_agents(): Which positions to target
  └─> make_offer(): Generate competitive bid

FreeAgency (NEW - Pipeline Phase)
  ├─> collect_free_agents(): Build market from expired contracts
  ├─> run_bidding(): Simulate multi-team auction
  ├─> resolve_signings(): Assign players to teams
  └─> update_rosters(): Persist contract changes
```

**Data Flow**:
```
1. NflSeason.run()
   └─> ContractLifecycle.advance_contract_year() for all players
       └─> Expired contracts → free_agents pool

2. FreeAgency.run() [NEW PHASE]
   ├─> GmDecisions.prioritize_free_agents() for each team
   ├─> GmDecisions.make_offer() for targeted players
   ├─> Resolve signings via auction model
   └─> ContractLifecycle.sign_contract() for winners

3. NflDraft.run()
   └─> ContractLifecycle.sign_rookie_contract() for draftees

4. CapValidation.run()
   └─> Validate all teams under cap
   └─> Flag violations for resolution
```

---

## Data Models

### Core Contract Model

**Location**: `Player.contract` dictionary (already exists, we're defining schema)

```gdscript
# Player.contract schema (Phase 1)
{
  # Identity and type
  "contract_id": String,          # Unique contract identifier
  "contract_type": String,        # "rookie", "veteran", "extension", "franchise_tag", "minimum"
  "signed_year": int,             # Year contract was signed

  # Term structure
  "total_years": int,             # Original contract length (1-5 years typical)
  "years_remaining": int,         # Years left including current year
  "current_year": int,            # Which year of contract (1-based)

  # Financial structure (Phase 1: simplified)
  "total_value": float,           # Total contract dollars
  "annual_value": float,          # Average per year (APY)
  "guaranteed": float,            # Total guaranteed money

  # Per-year breakdown (Phase 3+)
  "year_values": Array,           # [year1_salary, year2_salary, ...] (empty in Phase 1)
  "signing_bonus": float,         # Upfront bonus (Phase 3+)
  "bonus_proration": float,       # Annual cap charge from bonus (Phase 3+)

  # Cap impact (calculated, not persisted)
  "cap_hit": float,               # Current year cap charge (annual_value in Phase 1)
  "dead_money": float,            # Cap charge if released (guaranteed / years_remaining)

  # Valuation metadata (for debugging/analysis)
  "valuation_source": String,     # "draft_slot", "free_agency", "extension"
  "valuation_version": String,    # Version of valuation system used
  "source_eval_id": String,       # Scout evaluation ID that produced valuation
  "market_value_at_signing": float, # PlayerValue.market_value when signed

  # Status
  "status": String,               # "active", "expired", "extended", "restructured"
  "expiration_year": int          # Year contract expires
}
```

**Default Contract** (unsigned player, Phase 1):
```gdscript
func _default_contract() -> Dictionary:
  return {
    "contract_id": "",
    "contract_type": "none",
    "signed_year": 0,
    "total_years": 0,
    "years_remaining": 0,
    "current_year": 0,
    "total_value": 0.0,
    "annual_value": 0.0,
    "guaranteed": 0.0,
    "year_values": [],
    "signing_bonus": 0.0,
    "bonus_proration": 0.0,
    "cap_hit": 0.0,
    "dead_money": 0.0,
    "valuation_source": "",
    "valuation_version": "",
    "source_eval_id": "",
    "market_value_at_signing": 0.0,
    "status": "none",
    "expiration_year": 0
  }
```

**Validation Rules**:
- `years_remaining >= 0` (0 means expired this year)
- `current_year <= total_years`
- `annual_value = total_value / total_years` (Phase 1)
- `cap_hit >= 0` (minimum contract still costs something)
- `guaranteed <= total_value` (can't guarantee more than total)

### Team Salary Cap Model

**Location**: `Team` class (already has `cap_limit`, `cap_used`, `cap_space`)

**Enhancement**: Add cap tracking fields to Team.to_dict():

```gdscript
# Team.to_dict() additions (Phase 1)
{
  "id": String,
  "name": String,

  # Existing cap fields (already present)
  "cap": {
    "league_cap": float,         # League-wide cap limit (from config)
    "cap_used": float,           # Sum of active contract cap_hits (calculated)
    "cap_space": float           # league_cap - cap_used (calculated)
  },

  # NEW: Cap management (Phase 1)
  "cap_management": {
    "active_contracts": int,     # Count of players with active contracts
    "dead_money": float,         # Cap charge from released players (Phase 3+)
    "cap_carryover": float,      # Unused cap from previous year (Phase 4+)
    "is_over_cap": bool,         # True if cap_used > league_cap
    "cap_violations": Array      # [{year, amount, resolved}] (Phase 1)
  },

  # Roster tracking (already exists as player_ids)
  "player_ids": Array[String],
  "roster": SportRoster          # Contains cap_used calculation
}
```

**Cap Used Calculation** (already exists in SportRoster):
```gdscript
# From SportRoster.get_cap_used()
func calculate_team_cap_used(roster: SportRoster, players: Dictionary) -> float:
  var total := 0.0
  for player_id in roster.entries:
    var player = players.get(player_id)
    if player == null:
      continue
    var contract = player.get("contract", {})
    if contract.get("status") != "active":
      continue
    total += float(contract.get("cap_hit", 0.0))
  return total
```

### Free Agent Model

**Location**: `world_state["free_agents"]` dictionary

```gdscript
# world_state schema additions
{
  # Existing world state (unchanged)
  "nfl_teams": Array,
  "nfl_rosters": Dictionary,
  "draft_pool": Dictionary,

  # NEW: Free agent market (Phase 1)
  "free_agents": {
    2025: {
      "unrestricted": [
        {
          "player_id": String,
          "last_team_id": String,     # Team they played for
          "position": String,
          "age": int,
          "market_value": float,      # From PlayerValue
          "contract_demands": {       # Generated from valuation
            "min_years": int,
            "max_years": int,
            "min_apy": float,
            "max_apy": float,
            "min_guaranteed_pct": float
          },
          "preferences": {            # Phase 2+
            "winning_weight": float,  # How much they value contending
            "loyalty_discount": float, # Discount for re-signing with current team
            "region_preference": String # Hometown bias
          }
        }
      ],
      "restricted": [],              # Phase 4+ (RFAs)
      "franchise_tagged": []         # Phase 2+ (tagged players)
    },
    2026: {...}
  },

  # NEW: Contract transactions log (for analysis)
  "contract_transactions": {
    2025: [
      {
        "type": "signing",           # "signing", "extension", "release", "trade"
        "player_id": String,
        "team_id": String,
        "contract": Dictionary,      # Full contract object
        "timestamp": int             # Simulation year + phase
      }
    ]
  }
}
```

### GM Decision Context

**Ephemeral** (not persisted, computed per free agency phase):

```gdscript
# GM decision context (Phase 2)
{
  "team_id": String,
  "year": int,

  # Cap situation
  "cap_space": float,
  "projected_cap_next_year": float,

  # Roster needs
  "positional_needs": [
    {
      "position": String,
      "priority": int,              # 1 (critical) to 5 (depth)
      "current_depth": int,         # Players at position
      "starter_quality": float,     # Best player's eval_score
      "need_reason": String         # "no_starter", "aging_starter", "depth"
    }
  ],

  # Team strategy
  "rebuild_mode": bool,             # Tanking vs competing
  "contender_status": bool,         # Playoff team or not
  "draft_capital": int,             # Number of draft picks (affects FA strategy)

  # Contract status
  "expiring_contracts": [
    {"player_id": String, "position": String, "value": float}
  ],
  "extension_candidates": [
    {"player_id": String, "priority": int, "estimated_cost": float}
  ]
}
```

---

## Contract Lifecycle State Machine

### Contract States

```
[NO CONTRACT] (Draft eligible, unsigned)
     |
     | 1. Draft Selection
     | 2. Free Agent Signing
     |
     v
[ACTIVE] (years_remaining > 0, status="active")
     |
     |---> Year advancement (NflSeason.run)
     |     └─> years_remaining--
     |
     |---> Extension offer (before expiration)
     |     └─> [EXTENDED] → New ACTIVE contract
     |
     |---> Release decision (cap casualty)
     |     └─> [RELEASED] → Dead money applied
     |
     |---> Trade (Phase 3+)
     |     └─> Contract transfers to new team
     |
     v
[EXPIRED] (years_remaining == 0, status="expired")
     |
     | Enter free agency pool
     |
     v
[FREE AGENT] (no contract, can be signed)
     |
     | Re-sign with team OR Sign with new team
     |
     v
[ACTIVE] (new contract)
```

### State Transitions

**1. Draft Signing** (Rookie Contract):
```gdscript
# In NflDraft.run() after player selected
func assign_rookie_contract(player: Dictionary, draft_pick: int, year: int, config: Dictionary) -> void:
  var rookie_scale = config.get("rookie_contract_scale", {})
  var round = (draft_pick - 1) / 32 + 1
  var pick_in_round = ((draft_pick - 1) % 32) + 1

  # Rookie contracts are slotted by draft position
  var contract_value = _calculate_rookie_value(round, pick_in_round, rookie_scale)
  var years = 4  # All rookie contracts are 4 years (NFL CBA)

  player["contract"] = {
    "contract_id": "rookie_%d_pick_%d" % [year, draft_pick],
    "contract_type": "rookie",
    "signed_year": year,
    "total_years": years,
    "years_remaining": years,
    "current_year": 1,
    "total_value": contract_value,
    "annual_value": contract_value / years,
    "guaranteed": contract_value,  # Rookie contracts fully guaranteed
    "cap_hit": contract_value / years,
    "dead_money": contract_value,  # Fully guaranteed
    "valuation_source": "draft_slot_%d" % draft_pick,
    "valuation_version": "rookie_scale_v1",
    "status": "active",
    "expiration_year": year + years
  }
```

**2. Year Advancement** (Contract Aging):
```gdscript
# In NflSeason.run(), called for each player
func advance_contract_year(player: Dictionary, year: int) -> Dictionary:
  var contract = player.get("contract", {})

  if contract.get("status") != "active":
    return {"expired": false}

  var years_remaining = int(contract.get("years_remaining", 0))
  years_remaining -= 1

  contract["years_remaining"] = years_remaining
  contract["current_year"] = int(contract.get("current_year", 1)) + 1

  if years_remaining <= 0:
    contract["status"] = "expired"
    player["nfl_status"] = "free_agent"
    return {"expired": true}

  # Update cap hit for new year (Phase 1: same as annual_value)
  contract["cap_hit"] = float(contract.get("annual_value", 0.0))

  return {"expired": false, "years_remaining": years_remaining}
```

**3. Free Agent Signing**:
```gdscript
# In FreeAgency.run(), after auction determines winner
func sign_free_agent_contract(
  player: Dictionary,
  team_id: String,
  offer: Dictionary,
  year: int,
  valuation: Dictionary
) -> void:
  var contract_id = "fa_%d_%s_%s" % [year, player.get("player_id"), team_id]

  player["contract"] = {
    "contract_id": contract_id,
    "contract_type": "veteran",
    "signed_year": year,
    "total_years": int(offer.get("years", 3)),
    "years_remaining": int(offer.get("years", 3)),
    "current_year": 1,
    "total_value": float(offer.get("total_value")),
    "annual_value": float(offer.get("apy")),
    "guaranteed": float(offer.get("guaranteed")),
    "cap_hit": float(offer.get("apy")),
    "dead_money": float(offer.get("guaranteed")),
    "valuation_source": "free_agency",
    "valuation_version": valuation.get("valuation_version", "v2"),
    "source_eval_id": valuation.get("player_id", ""),
    "market_value_at_signing": float(valuation.get("market_value")),
    "status": "active",
    "expiration_year": year + int(offer.get("years", 3))
  }

  player["team_id"] = team_id
  player["nfl_status"] = "active"
```

**4. Contract Extension** (Phase 2):
```gdscript
# In GmDecisions.evaluate_extensions()
func extend_player_contract(
  player: Dictionary,
  extension_offer: Dictionary,
  year: int
) -> bool:
  var old_contract = player.get("contract", {})
  var years_remaining = int(old_contract.get("years_remaining", 0))

  # Extension replaces old contract
  var new_years = int(extension_offer.get("years"))
  var new_total = float(extension_offer.get("total_value"))

  old_contract["status"] = "extended"
  old_contract["extension_year"] = year

  player["contract"] = {
    "contract_id": "ext_%d_%s" % [year, player.get("player_id")],
    "contract_type": "extension",
    "signed_year": year,
    "total_years": new_years,
    "years_remaining": new_years,
    "current_year": 1,
    "total_value": new_total,
    "annual_value": new_total / new_years,
    "guaranteed": float(extension_offer.get("guaranteed")),
    "cap_hit": new_total / new_years,
    "dead_money": float(extension_offer.get("guaranteed")),
    "valuation_source": "extension",
    "status": "active",
    "expiration_year": year + new_years,
    "previous_contract_id": old_contract.get("contract_id")
  }

  return true
```

**5. Player Release** (Phase 2):
```gdscript
# In GmDecisions.evaluate_releases()
func release_player(
  player: Dictionary,
  team_id: String,
  year: int
) -> Dictionary:
  var contract = player.get("contract", {})
  var dead_money = float(contract.get("dead_money", 0.0))
  var years_remaining = int(contract.get("years_remaining", 0))

  # Dead money is guaranteed money spread over remaining years
  # Phase 1: Simple calculation (Phase 3: bonus acceleration rules)
  var dead_cap_per_year = dead_money / max(1, years_remaining)

  contract["status"] = "released"
  contract["release_year"] = year
  contract["years_remaining"] = 0

  player["team_id"] = ""
  player["nfl_status"] = "free_agent"

  # Return dead money impact for team cap tracking
  return {
    "dead_money_total": dead_money,
    "dead_cap_per_year": dead_cap_per_year,
    "years_impacted": years_remaining
  }
```

---

## Integration with PlayerValue System

### Market Value as Contract Foundation

The existing `PlayerValue.calculate()` provides everything needed for contract generation:

```gdscript
# In FreeAgency or GmDecisions
var valuation = PlayerValue.calculate(player, context, config, rng)

# valuation contains:
# - market_value: Base for contract APY
# - team_value: What current team should offer (may be higher)
# - range_min/max: Negotiation bounds
# - age_multiplier: Informs contract length
# - components: Detailed breakdown for debugging

# Convert to contract offer
var contract_offer = {
  "apy": valuation.market_value,
  "years": _determine_contract_years(player.get("age"), valuation),
  "total_value": valuation.market_value * years,
  "guaranteed": valuation.market_value * years * _guaranteed_percentage(player.get("position"))
}
```

### Team-Specific Valuation

Use `team_value` vs `market_value` for extension decisions:

```gdscript
# In GmDecisions.evaluate_extensions()
var team_context = {
  "team_roster": team.roster.entries,
  "position_supply": _calculate_position_supply(league_rosters)
}

var valuation = PlayerValue.calculate(player, team_context, config, rng)

# If team_premium is high, prioritize extension
var team_premium = valuation.team_value - valuation.market_value

if team_premium > 5.0:  # Player worth $5M+ more to current team
  # High priority extension (no backup, key position)
  return _create_extension_offer(player, valuation.team_value, config)
elif valuation.market_value > team_cap_space * 0.3:
  # Too expensive relative to cap, let walk
  return null
else:
  # Normal extension at market rate
  return _create_extension_offer(player, valuation.market_value, config)
```

### Position-Based Contract Structure

Use existing valuation config for position-specific contracts:

```gdscript
# From valuation.json
{
  "team_impact": {
    "position_win_impacts": {
      "QB": 2.5,    # Most important, longest contracts
      "EDGE": 1.4,  # Premium position
      "RB": 0.8,    # Replaceable, shorter contracts
      "K": 0.5      # Minimum contracts
    }
  }
}

# In contract generation
func _determine_contract_years(age: int, position: String, config: Dictionary) -> int:
  var win_impact = config.get("team_impact", {}).get("position_win_impacts", {}).get(position, 1.0)

  # Premium positions get longer contracts at younger ages
  var base_years = ContractValuation._typical_contract_years(age)

  if win_impact >= 2.0:  # QB
    return base_years  # Full length
  elif win_impact <= 0.8:  # RB, K, P
    return max(1, base_years - 1)  # Shorter by 1 year
  else:
    return base_years
```

---

## Salary Cap System

### Cap Configuration

**File**: `configs/sports/american_football/world/league.json`

```json
{
  "version": 3,
  "cap_limit": 225.0,
  "_cap_limit_comment": "Team salary cap in millions (NFL 2024: ~$224.8M)",

  "cap_floor": 200.0,
  "_cap_floor_comment": "Minimum team spending (89% of cap)",

  "cap_growth_rate": 0.05,
  "_cap_growth_rate_comment": "Annual cap increase (5% typical)",

  "cap_enforcement": {
    "grace_period_days": 0,
    "_comment": "No grace period in simulation (instant enforcement)",
    "violation_penalty": "force_release",
    "_violation_penalty_comment": "Auto-release lowest value players until compliant",
    "carryover_enabled": true,
    "_carryover_enabled_comment": "Phase 4: Unused cap rolls over to next year"
  },

  "rookie_contract_scale": {
    "_comment": "Slotted rookie contracts by draft position",
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
    "_comment": "Minimum salary by years of service",
    "0_years": 0.75,
    "1_year": 0.9,
    "2_years": 1.0,
    "3_plus_years": 1.1
  }
}
```

### Cap Calculation (Phase 1 - Simplified)

```gdscript
# Simple cap charge = annual contract value
func calculate_cap_hit_phase1(contract: Dictionary) -> float:
  if contract.get("status") != "active":
    return 0.0
  return float(contract.get("annual_value", 0.0))

# Team total cap used
func calculate_team_cap_used(team: Dictionary, rosters: Dictionary) -> float:
  var roster = rosters.get(team.get("id"), {})
  var players = roster.get("players", [])

  var total = 0.0
  for player in players:
    total += calculate_cap_hit_phase1(player.get("contract", {}))

  return total
```

### Cap Calculation (Phase 3 - Bonus Proration)

```gdscript
# Cap hit includes base salary + bonus proration
func calculate_cap_hit_phase3(contract: Dictionary, current_year: int) -> float:
  if contract.get("status") != "active":
    return 0.0

  var year_idx = int(contract.get("current_year", 1)) - 1
  var year_values = contract.get("year_values", [])

  var base_salary = 0.0
  if year_idx < year_values.size():
    base_salary = float(year_values[year_idx])
  else:
    base_salary = float(contract.get("annual_value", 0.0))

  var bonus_proration = float(contract.get("bonus_proration", 0.0))

  return base_salary + bonus_proration
```

### Dead Money Calculation

```gdscript
# Phase 1: Simple guaranteed money remaining
func calculate_dead_money_phase1(contract: Dictionary) -> float:
  var guaranteed = float(contract.get("guaranteed", 0.0))
  var years_total = int(contract.get("total_years", 1))
  var years_elapsed = int(contract.get("current_year", 1)) - 1
  var years_remaining = max(0, years_total - years_elapsed)

  # Guaranteed money vests equally per year
  var guaranteed_per_year = guaranteed / years_total
  return guaranteed_per_year * years_remaining

# Phase 3: Bonus acceleration
func calculate_dead_money_phase3(contract: Dictionary) -> float:
  # All remaining signing bonus accelerates immediately
  var bonus_proration = float(contract.get("bonus_proration", 0.0))
  var years_remaining = int(contract.get("years_remaining", 0))
  var accelerated_bonus = bonus_proration * years_remaining

  # Plus remaining guaranteed base salary
  var year_values = contract.get("year_values", [])
  var guaranteed_remaining = 0.0
  var current_year = int(contract.get("current_year", 1))

  for i in range(current_year - 1, year_values.size()):
    var year_salary = float(year_values[i])
    var guaranteed_pct = float(contract.get("year_guarantees", [])[i] if i < contract.get("year_guarantees", []).size() else 0.0)
    guaranteed_remaining += year_salary * guaranteed_pct

  return accelerated_bonus + guaranteed_remaining
```

### Cap Enforcement

```gdscript
# In CapValidationFlow.run() (already exists, enhance)
func enforce_salary_cap(world_state: Dictionary, year: int, league_cap: float) -> Dictionary:
  var teams = world_state.get("nfl_teams", [])
  var rosters = world_state.get("nfl_rosters", {})
  var violations = []
  var forced_releases = []

  for team in teams:
    var team_id = String(team.get("id"))
    var cap_used = calculate_team_cap_used(team, rosters)

    if cap_used > league_cap:
      var overage = cap_used - league_cap

      # Find players to release (lowest value first)
      var roster = rosters.get(team_id, {})
      var players = roster.get("players", [])
      var release_candidates = _sort_by_value_over_cap(players)

      var released = []
      var cap_saved = 0.0

      for player in release_candidates:
        if cap_saved >= overage:
          break

        var contract = player.get("contract", {})
        var cap_hit = calculate_cap_hit_phase1(contract)
        var dead_money = calculate_dead_money_phase1(contract)
        var net_savings = cap_hit - dead_money

        if net_savings > 0:
          release_player(player, team_id, year)
          released.append(player.get("player_id"))
          cap_saved += net_savings

      violations.append({
        "team_id": team_id,
        "year": year,
        "overage": overage,
        "cap_saved": cap_saved,
        "players_released": released,
        "resolved": (cap_saved >= overage)
      })

      forced_releases.append_array(released)

  return {
    "violations": violations,
    "forced_releases": forced_releases.size(),
    "teams_over_cap": violations.size()
  }
```

---

## GM Decision-Making Algorithms

### Decision Context Gathering

```gdscript
# Build context for GM decisions (Phase 2)
func build_gm_context(team: Dictionary, world_state: Dictionary, year: int, config: Dictionary) -> Dictionary:
  var roster = world_state.get("nfl_rosters", {}).get(team.get("id"), {})
  var players = roster.get("players", [])

  # Positional depth analysis
  var depth_by_position = {}
  for player in players:
    var pos = String(player.get("position"))
    if not depth_by_position.has(pos):
      depth_by_position[pos] = []
    depth_by_position[pos].append(player)

  # Identify needs
  var positional_needs = []
  var starter_slots = config.get("scarcity", {}).get("starter_slots", {})

  for position in starter_slots.keys():
    var needed = int(starter_slots.get(position, 1))
    var current = depth_by_position.get(position, []).size()

    if current < needed:
      positional_needs.append({
        "position": position,
        "priority": 1,  # Critical need
        "current_depth": current,
        "starter_quality": 0.0,
        "need_reason": "no_starter"
      })
    elif current == needed:
      # Check starter quality
      var starters = depth_by_position.get(position, [])
      starters.sort_custom(func(a, b): return a.get("eval_score", 0) > b.get("eval_score", 0))
      var best_eval = starters[0].get("eval_score", 50.0) if starters.size() > 0 else 50.0

      if best_eval < 60.0:  # Below average starter
        positional_needs.append({
          "position": position,
          "priority": 2,  # High need
          "current_depth": current,
          "starter_quality": best_eval,
          "need_reason": "weak_starter"
        })

  # Cap situation
  var cap_used = calculate_team_cap_used(team, world_state.get("nfl_rosters", {}))
  var league_cap = float(config.get("cap_limit", 225.0))
  var cap_space = league_cap - cap_used

  # Expiring contracts
  var expiring = []
  for player in players:
    var contract = player.get("contract", {})
    if int(contract.get("years_remaining", 0)) == 1:  # Expires next year
      expiring.append({
        "player_id": String(player.get("player_id")),
        "position": String(player.get("position")),
        "value": float(player.get("eval_score", 50.0))
      })

  return {
    "team_id": String(team.get("id")),
    "year": year,
    "cap_space": cap_space,
    "projected_cap_next_year": cap_space * 0.95,  # Assume 5% inflation
    "positional_needs": positional_needs,
    "rebuild_mode": false,  # Phase 2: Infer from record
    "contender_status": false,  # Phase 2: Infer from record
    "draft_capital": 7,  # Assume 7 picks (can track trades in Phase 3)
    "expiring_contracts": expiring,
    "extension_candidates": []  # Populated below
  }
```

### Extension Evaluation

```gdscript
# Evaluate which players to extend (Phase 2)
func evaluate_extensions(
  context: Dictionary,
  players: Array,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Array:
  var extensions = []
  var cap_space = float(context.get("cap_space", 0.0))
  var reserved_for_draft = cap_space * 0.2  # Reserve 20% for rookies
  var available_for_extensions = cap_space - reserved_for_draft

  # Only extend players with 1-2 years remaining
  var extension_candidates = []
  for player in players:
    var contract = player.get("contract", {})
    var years_remaining = int(contract.get("years_remaining", 0))

    if years_remaining >= 1 and years_remaining <= 2:
      # Calculate value to team
      var team_context = {"team_roster": players}
      var valuation = PlayerValue.calculate(player, team_context, config, rng)

      extension_candidates.append({
        "player": player,
        "valuation": valuation,
        "team_premium": valuation.team_value - valuation.market_value
      })

  # Sort by team premium (prioritize irreplaceable players)
  extension_candidates.sort_custom(func(a, b): return a.team_premium > b.team_premium)

  var cap_committed = 0.0
  for candidate in extension_candidates:
    var player = candidate.player
    var valuation = candidate.valuation

    # Only extend if team premium is positive (worth more to us than market)
    if candidate.team_premium < 0:
      continue

    # Generate extension offer
    var age = int(player.get("age", 25))
    var years = ContractValuation._typical_contract_years(age + 1)  # Next year's age
    var apy = valuation.team_value  # Willing to pay team value, not just market
    var total = apy * years

    # Check if we can afford it
    if cap_committed + apy > available_for_extensions:
      break  # Out of cap space

    extensions.append({
      "player_id": String(player.get("player_id")),
      "position": String(player.get("position")),
      "years": years,
      "apy": apy,
      "total_value": total,
      "guaranteed": total * _guaranteed_percentage(player.get("position")),
      "reason": "high_team_premium",
      "team_premium": candidate.team_premium
    })

    cap_committed += apy

  return extensions
```

### Release Evaluation

```gdscript
# Evaluate which players to release (Phase 2)
func evaluate_releases(
  context: Dictionary,
  players: Array,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Array:
  var releases = []
  var cap_space = float(context.get("cap_space", 0.0))

  # Only consider releases if over cap or critically low on space
  if cap_space > 10.0:  # $10M cushion is comfortable
    return []

  var target_cap_space = max(15.0, -cap_space)  # Need at least $15M or clear overage

  # Find release candidates (poor value for cap hit)
  var release_candidates = []
  for player in players:
    var contract = player.get("contract", {})
    var cap_hit = calculate_cap_hit_phase1(contract)
    var dead_money = calculate_dead_money_phase1(contract)
    var net_savings = cap_hit - dead_money

    if net_savings <= 0:
      continue  # No cap savings from release

    # Calculate value vs cost
    var team_context = {"team_roster": players}
    var valuation = PlayerValue.calculate(player, team_context, config, rng)
    var value_per_cap = valuation.market_value / max(1.0, cap_hit)

    release_candidates.append({
      "player": player,
      "cap_hit": cap_hit,
      "dead_money": dead_money,
      "net_savings": net_savings,
      "value_per_cap": value_per_cap,
      "age": int(player.get("age", 25))
    })

  # Sort by value per cap dollar (release worst value first)
  release_candidates.sort_custom(func(a, b): return a.value_per_cap < b.value_per_cap)

  var cap_cleared = 0.0
  for candidate in release_candidates:
    if cap_cleared >= target_cap_space:
      break

    # Don't release young high-value players
    if candidate.age < 28 and candidate.value_per_cap > 0.8:
      continue

    releases.append({
      "player_id": String(candidate.player.get("player_id")),
      "position": String(candidate.player.get("position")),
      "cap_savings": candidate.net_savings,
      "dead_money": candidate.dead_money,
      "reason": "poor_value_for_cap" if candidate.value_per_cap < 0.5 else "cap_casualty"
    })

    cap_cleared += candidate.net_savings

  return releases
```

### Free Agent Prioritization

```gdscript
# Prioritize which free agents to target (Phase 2)
func prioritize_free_agents(
  context: Dictionary,
  free_agent_pool: Array,
  config: Dictionary
) -> Array:
  var targets = []
  var cap_space = float(context.get("cap_space", 0.0))
  var positional_needs = context.get("positional_needs", [])

  if cap_space < 5.0:
    return []  # Can't afford anyone

  # Create need lookup
  var need_positions = {}
  for need in positional_needs:
    need_positions[String(need.get("position"))] = int(need.get("priority", 5))

  # Score each free agent
  for fa in free_agent_pool:
    var position = String(fa.get("position"))
    var market_value = float(fa.get("market_value", 0.0))

    # Can we afford them?
    if market_value > cap_space:
      continue

    # Do we need this position?
    var need_priority = need_positions.get(position, 5)
    if need_priority > 3:
      continue  # Low priority position

    var score = 0.0
    score += (5 - need_priority) * 10.0  # Need priority (0-30 points)
    score += min(20.0, market_value / 2.0)  # Player quality (0-20 points)
    score += max(0, 10.0 - (market_value / cap_space * 10.0))  # Affordability (0-10 points)

    targets.append({
      "player_id": String(fa.get("player_id")),
      "position": position,
      "market_value": market_value,
      "target_score": score,
      "need_priority": need_priority
    })

  # Sort by target score
  targets.sort_custom(func(a, b): return a.target_score > b.target_score)

  # Take top N targets within budget
  var final_targets = []
  var budget_used = 0.0

  for target in targets:
    if budget_used + target.market_value > cap_space * 0.8:
      break  # Don't spend entire cap

    final_targets.append(target)
    budget_used += target.market_value

    if final_targets.size() >= 5:
      break  # Max 5 targets per team

  return final_targets
```

---

## Next Steps

This architectural foundation document establishes:
1. ✅ Data models for contracts, cap tracking, and free agents
2. ✅ Contract lifecycle state machine with clear transitions
3. ✅ Integration patterns with existing `PlayerValue` system
4. ✅ Salary cap calculation and enforcement mechanisms
5. ✅ GM decision-making algorithms for extensions and releases

**Continue to**:
- `CONTRACT_SYSTEM_IMPLEMENTATION.md` for phased implementation plan
- `SALARY_CAP_SPECIFICATION.md` for detailed cap accounting rules
- `FREE_AGENCY_DESIGN.md` for market simulation and bidding
- `EXAMPLE_SCENARIOS.md` for worked examples with calculations

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial architecture specification |
