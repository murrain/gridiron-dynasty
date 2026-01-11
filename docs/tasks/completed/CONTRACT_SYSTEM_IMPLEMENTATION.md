# Contract System Implementation Plan

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: [CONTRACT_SYSTEM_ARCHITECTURE.md](/home/patrick/Documents/code/gridiron-dynasty/docs/architectural_notes/CONTRACT_SYSTEM_ARCHITECTURE.md)

---

## Executive Summary

This document provides a concrete, phased implementation plan for the contract management system. Each phase is independently valuable, fully tested, and production-ready. The plan prioritizes early value delivery while maintaining architectural integrity and minimizing technical debt.

**Implementation Strategy**:
- **Phase 1** (2-3 days): Foundation - contracts exist, cap tracking works, basic signing
- **Phase 2** (3-4 days): Free agency market with multi-team bidding
- **Phase 3** (2-3 days): Advanced contract mechanics (bonuses, dead money)
- **Phase 4** (2-3 days): Sophisticated GM strategy and analytics

**Total Estimated Effort**: 10-14 days of focused development

---

## Phase 1: Foundation (MVP)

**Goal**: Contracts exist, salary cap is tracked, players sign basic deals

**Value Delivered**:
- All players have contracts with years and dollar values
- Teams have cap constraints that limit roster construction
- Contract expiration produces free agents
- Rookie contracts automatically assigned at draft
- 20-year simulation produces realistic cap distribution

### Phase 1A: Data Model and Contract Lifecycle

**Files to Create**:

#### 1. `/scripts/world/ContractLifecycle.gd`

```gdscript
extends RefCounted
class_name ContractLifecycle

## Manages contract state transitions and lifecycle operations.
## All functions are deterministic and stateless (take explicit parameters).

## Create a rookie contract for a drafted player.
## Slotted by draft position according to rookie wage scale.
static func create_rookie_contract(
  player: Dictionary,
  draft_pick: int,
  year: int,
  config: Dictionary
) -> Dictionary:
  var rookie_scale = config.get("rookie_contract_scale", {})
  var round = (draft_pick - 1) / 32 + 1
  var pick_in_round = ((draft_pick - 1) % 32) + 1

  var contract_value = _calculate_rookie_value(round, pick_in_round, rookie_scale)
  var years = 4  # NFL CBA standard

  return {
    "contract_id": "rookie_%d_pick_%d" % [year, draft_pick],
    "contract_type": "rookie",
    "signed_year": year,
    "total_years": years,
    "years_remaining": years,
    "current_year": 1,
    "total_value": contract_value,
    "annual_value": contract_value / years,
    "guaranteed": contract_value,  # Fully guaranteed
    "year_values": [],
    "signing_bonus": 0.0,
    "bonus_proration": 0.0,
    "cap_hit": contract_value / years,
    "dead_money": contract_value,
    "valuation_source": "draft_slot_%d" % draft_pick,
    "valuation_version": "rookie_scale_v1",
    "source_eval_id": "",
    "market_value_at_signing": contract_value / years,
    "status": "active",
    "expiration_year": year + years
  }

## Create a veteran free agent contract.
static func create_veteran_contract(
  player: Dictionary,
  team_id: String,
  offer: Dictionary,
  year: int,
  valuation: Dictionary
) -> Dictionary:
  var years = int(offer.get("years", 3))
  var total = float(offer.get("total_value"))
  var apy = total / years

  return {
    "contract_id": "fa_%d_%s_%s" % [year, player.get("player_id"), team_id],
    "contract_type": "veteran",
    "signed_year": year,
    "total_years": years,
    "years_remaining": years,
    "current_year": 1,
    "total_value": total,
    "annual_value": apy,
    "guaranteed": float(offer.get("guaranteed", total * 0.5)),
    "year_values": [],
    "signing_bonus": 0.0,
    "bonus_proration": 0.0,
    "cap_hit": apy,
    "dead_money": float(offer.get("guaranteed", total * 0.5)),
    "valuation_source": "free_agency",
    "valuation_version": valuation.get("valuation_version", "v2"),
    "source_eval_id": valuation.get("player_id", ""),
    "market_value_at_signing": float(valuation.get("market_value", apy)),
    "status": "active",
    "expiration_year": year + years
  }

## Advance contract by one year (called during season advancement).
## Returns whether contract expired.
static func advance_contract_year(player: Dictionary, year: int) -> Dictionary:
  var contract = player.get("contract", {})

  if contract.is_empty() or contract.get("status") != "active":
    return {"expired": false, "years_remaining": 0}

  var years_remaining = int(contract.get("years_remaining", 0))
  years_remaining -= 1

  contract["years_remaining"] = years_remaining
  contract["current_year"] = int(contract.get("current_year", 1)) + 1

  if years_remaining <= 0:
    contract["status"] = "expired"
    return {"expired": true, "years_remaining": 0}

  # Update cap hit for new year (Phase 1: static)
  contract["cap_hit"] = float(contract.get("annual_value", 0.0))

  return {"expired": false, "years_remaining": years_remaining}

## Check if player's contract has expired.
static func is_expired(contract: Dictionary) -> bool:
  if contract.is_empty():
    return false
  return contract.get("status") == "expired" or int(contract.get("years_remaining", 0)) <= 0

## Calculate cap hit for a contract (Phase 1: simple annual value).
static func calculate_cap_hit(contract: Dictionary) -> float:
  if contract.get("status") != "active":
    return 0.0
  return float(contract.get("annual_value", 0.0))

## Calculate dead money if player is released (Phase 1: remaining guaranteed).
static func calculate_dead_money(contract: Dictionary) -> float:
  var guaranteed = float(contract.get("guaranteed", 0.0))
  var years_total = int(contract.get("total_years", 1))
  var years_elapsed = int(contract.get("current_year", 1)) - 1
  var years_remaining = max(0, years_total - years_elapsed)

  if years_remaining <= 0:
    return 0.0

  var guaranteed_per_year = guaranteed / years_total
  return guaranteed_per_year * years_remaining

## INTERNAL: Calculate rookie contract value from draft slot.
static func _calculate_rookie_value(round: int, pick_in_round: int, scale: Dictionary) -> float:
  if round == 1:
    var round1 = scale.get("round_1", {})
    # Linear interpolation between known picks
    if pick_in_round == 1:
      return float(round1.get("pick_1", {}).get("total", 36.0))
    elif pick_in_round <= 10:
      var p1 = float(round1.get("pick_1", {}).get("total", 36.0))
      var p10 = float(round1.get("pick_10", {}).get("total", 18.0))
      var t = (pick_in_round - 1) / 9.0
      return p1 * (1.0 - t) + p10 * t
    elif pick_in_round <= 20:
      var p10 = float(round1.get("pick_10", {}).get("total", 18.0))
      var p20 = float(round1.get("pick_20", {}).get("total", 12.0))
      var t = (pick_in_round - 10) / 10.0
      return p10 * (1.0 - t) + p20 * t
    else:
      var p20 = float(round1.get("pick_20", {}).get("total", 12.0))
      var p32 = float(round1.get("pick_32", {}).get("total", 8.0))
      var t = (pick_in_round - 20) / 12.0
      return p20 * (1.0 - t) + p32 * t
  elif round <= 3:
    return float(scale.get("round_2_3", {}).get("base", 3.0))
  else:
    return float(scale.get("round_4_7", {}).get("base", 1.0))
```

#### 2. `/scripts/world/CapTracking.gd`

```gdscript
extends RefCounted
class_name CapTracking

## Calculates team salary cap usage and validates cap compliance.
## All functions are stateless and deterministic.

## Calculate total cap usage for a team.
static func calculate_team_cap_used(roster: Dictionary) -> float:
  var players = roster.get("players", [])
  var total = 0.0

  for player in players:
    var p = player as Dictionary
    var contract = p.get("contract", {})
    total += ContractLifecycle.calculate_cap_hit(contract)

  return total

## Calculate cap space remaining for a team.
static func calculate_cap_space(roster: Dictionary, league_cap: float) -> float:
  var cap_used = calculate_team_cap_used(roster)
  return league_cap - cap_used

## Check if team is over the cap.
static func is_over_cap(roster: Dictionary, league_cap: float) -> bool:
  return calculate_team_cap_used(roster) > league_cap

## Find all teams violating the salary cap.
static func find_cap_violations(
  teams: Array,
  rosters: Dictionary,
  league_cap: float
) -> Array:
  var violations = []

  for team in teams:
    var t = team as Dictionary
    var team_id = String(t.get("id", ""))
    var roster = rosters.get(team_id, {})
    var cap_used = calculate_team_cap_used(roster)

    if cap_used > league_cap:
      violations.append({
        "team_id": team_id,
        "cap_used": cap_used,
        "league_cap": league_cap,
        "overage": cap_used - league_cap
      })

  return violations

## Calculate distribution statistics for all teams (for validation).
static func calculate_cap_statistics(teams: Array, rosters: Dictionary) -> Dictionary:
  var cap_usages = []

  for team in teams:
    var t = team as Dictionary
    var team_id = String(t.get("id", ""))
    var roster = rosters.get(team_id, {})
    cap_usages.append(calculate_team_cap_used(roster))

  if cap_usages.is_empty():
    return {"mean": 0.0, "min": 0.0, "max": 0.0, "teams": 0}

  var total = 0.0
  var min_cap = cap_usages[0]
  var max_cap = cap_usages[0]

  for cap in cap_usages:
    total += cap
    min_cap = min(min_cap, cap)
    max_cap = max(max_cap, cap)

  return {
    "mean": total / cap_usages.size(),
    "min": min_cap,
    "max": max_cap,
    "teams": cap_usages.size()
  }
```

### Phase 1B: Integration with Existing Systems

**Files to Modify**:

#### 3. `/scripts/world/NflDraft.gd` (Enhancement)

Add rookie contract assignment after draft selection:

```gdscript
# In NflDraft.run(), after player is assigned to team

# NEW: Assign rookie contract
var contract = ContractLifecycle.create_rookie_contract(
  player,
  draft_pick,
  year,
  league_cfg
)
player["contract"] = contract
player["team_id"] = team_id
player["nfl_status"] = "active"
```

#### 4. `/scripts/world/NflSeason.gd` (Enhancement)

Add contract year advancement in existing run() method:

```gdscript
# In NflSeason.run(), in player loop (around line 102-130)

# EXISTING: Process each player for contract expiration
for i in range(updated_players.size()):
  var p = updated_players[i]

  # NEW: Update contract years
  var contract_result = ContractLifecycle.advance_contract_year(p, year)

  # NEW: Check for free agency (contract expired)
  if contract_result.get("expired", false):
    p["free_agent_year"] = year
    p["last_team_id"] = team_id
    p["nfl_status"] = "free_agent"
    new_free_agents.append(p)
    total_free_agents += 1
    continue  # Don't add to active roster

  # EXISTING: Check for retirement...
  # EXISTING: Player remains active...
```

#### 5. `/scripts/pipelines/AdvanceWorldYear.gd` (Enhancement)

Update cap validation phase to use new CapTracking:

```gdscript
# In _handle_cap_validation() (around line 413-425)

func _handle_cap_validation(
  world_state: Dictionary,
  year: int,
  _seed: int,
  phase: Dictionary,
  _year_seed: int
) -> Dictionary:
  var phase_id = String(phase.get("phase_id", ""))
  var league_cfg = _get_config().get_config("world/league")
  var league_cap = float(league_cfg.get("cap_limit", 225.0))

  var teams = world_state.get("nfl_teams", [])
  var rosters = world_state.get("nfl_rosters", {})

  # NEW: Use CapTracking
  var violations = CapTracking.find_cap_violations(teams, rosters, league_cap)
  var statistics = CapTracking.calculate_cap_statistics(teams, rosters)

  return {
    "year": year,
    "league_cap": league_cap,
    "violations": violations.size(),
    "teams_over_cap": violations,
    "statistics": statistics
  }
```

### Phase 1C: Bootstrap Integration

**Files to Modify**:

#### 6. `/scripts/pipelines/BootstrapGameWorld.gd` (Enhancement)

Ensure drafted players get rookie contracts during bootstrap:

```gdscript
# No changes needed - NflDraft.run() handles contract assignment
# Validation: Check that after 20-year bootstrap, all active NFL players have contracts
```

### Phase 1D: Configuration

**Files to Modify**:

#### 7. `/configs/sports/american_football/world/league.json`

Add rookie contract scale and cap settings:

```json
{
  "version": 3,
  "cap_limit": 225.0,
  "cap_floor": 200.0,
  "cap_growth_rate": 0.05,

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
  }
}
```

### Phase 1 Testing

**Test Files to Create**:

#### 8. `/scripts/tests/unit/test_contract_lifecycle.gd`

```gdscript
extends GutTest

const ContractLifecycle = preload("res://scripts/world/ContractLifecycle.gd")

func test_create_rookie_contract_first_pick():
  var config = {
    "rookie_contract_scale": {
      "round_1": {"pick_1": {"total": 36.0}}
    }
  }
  var player = {"player_id": "test_123"}
  var contract = ContractLifecycle.create_rookie_contract(player, 1, 2025, config)

  assert_eq(contract.get("total_value"), 36.0, "First pick should be $36M")
  assert_eq(contract.get("total_years"), 4, "Rookie contracts are 4 years")
  assert_eq(contract.get("years_remaining"), 4)
  assert_eq(contract.get("guaranteed"), 36.0, "Rookie contracts fully guaranteed")
  assert_eq(contract.get("contract_type"), "rookie")
  assert_eq(contract.get("status"), "active")

func test_advance_contract_year():
  var player = {
    "contract": {
      "status": "active",
      "years_remaining": 3,
      "current_year": 1,
      "annual_value": 5.0
    }
  }

  var result = ContractLifecycle.advance_contract_year(player, 2025)

  assert_false(result.get("expired"), "Should not expire with 3 years remaining")
  assert_eq(player["contract"]["years_remaining"], 2, "Should decrement years")
  assert_eq(player["contract"]["current_year"], 2)

func test_contract_expiration():
  var player = {
    "contract": {
      "status": "active",
      "years_remaining": 1,
      "current_year": 4,
      "annual_value": 5.0
    }
  }

  var result = ContractLifecycle.advance_contract_year(player, 2025)

  assert_true(result.get("expired"), "Should expire on last year")
  assert_eq(player["contract"]["status"], "expired")
  assert_eq(player["contract"]["years_remaining"], 0)

func test_calculate_dead_money():
  var contract = {
    "guaranteed": 20.0,
    "total_years": 4,
    "current_year": 2,  # Completed 1 year, 3 remaining
    "status": "active"
  }

  var dead_money = ContractLifecycle.calculate_dead_money(contract)

  # $20M guaranteed / 4 years = $5M per year
  # 3 years remaining = $15M dead money
  assert_eq(dead_money, 15.0, "Dead money should be $15M")
```

#### 9. `/scripts/tests/unit/test_cap_tracking.gd`

```gdscript
extends GutTest

const CapTracking = preload("res://scripts/world/CapTracking.gd")

func test_calculate_team_cap_used():
  var roster = {
    "players": [
      {"contract": {"status": "active", "annual_value": 10.0}},
      {"contract": {"status": "active", "annual_value": 5.0}},
      {"contract": {"status": "expired", "annual_value": 3.0}}  # Should not count
    ]
  }

  var cap_used = CapTracking.calculate_team_cap_used(roster)
  assert_eq(cap_used, 15.0, "Should sum active contracts only")

func test_is_over_cap():
  var roster = {
    "players": [
      {"contract": {"status": "active", "annual_value": 150.0}},
      {"contract": {"status": "active", "annual_value": 100.0}}
    ]
  }

  assert_true(CapTracking.is_over_cap(roster, 225.0), "Should be over $225M cap")
  assert_false(CapTracking.is_over_cap(roster, 300.0), "Should be under $300M cap")

func test_find_cap_violations():
  var teams = [
    {"id": "team_001"},
    {"id": "team_002"}
  ]
  var rosters = {
    "team_001": {
      "players": [
        {"contract": {"status": "active", "annual_value": 250.0}}  # Over cap
      ]
    },
    "team_002": {
      "players": [
        {"contract": {"status": "active", "annual_value": 200.0}}  # Under cap
      ]
    }
  }

  var violations = CapTracking.find_cap_violations(teams, rosters, 225.0)

  assert_eq(violations.size(), 1, "Should find 1 violation")
  assert_eq(violations[0].get("team_id"), "team_001")
  assert_eq(violations[0].get("overage"), 25.0)
```

### Phase 1 Acceptance Criteria

- [ ] All drafted players receive rookie contracts with correct values
- [ ] Contract years decrement during NflSeason.run()
- [ ] Expired contracts produce free agents in world_state["free_agents"]
- [ ] CapTracking correctly calculates team cap usage
- [ ] CapValidation phase reports teams over/under cap
- [ ] 20-year bootstrap produces no cap violations (all under limit)
- [ ] Unit tests pass with >95% coverage
- [ ] Integration test: Bootstrap 20 years, verify all active players have contracts

---

## Phase 2: Free Agency Market

**Goal**: Multi-team bidding for free agents with realistic player decisions

**Value Delivered**:
- Free agents receive multiple offers from teams with cap space
- Players choose best offer based on money, winning, and loyalty
- Teams fill roster needs through strategic signings
- Contract values reflect competitive market dynamics
- Realistic player movement creates team turnover

### Phase 2A: GM Decision Logic

**Files to Create**:

#### 10. `/scripts/world/GmDecisions.gd`

```gdscript
extends RefCounted
class_name GmDecisions

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")
const ContractValuation = preload("res://scripts/core/valuation/ContractValuation.gd")

## Build decision context for GM (positional needs, cap space, strategy).
static func build_context(
  team: Dictionary,
  roster: Dictionary,
  world_state: Dictionary,
  year: int,
  config: Dictionary
) -> Dictionary:
  var players = roster.get("players", [])

  # Analyze roster depth by position
  var depth_by_position = {}
  for player in players:
    var pos = String(player.get("position"))
    if not depth_by_position.has(pos):
      depth_by_position[pos] = []
    depth_by_position[pos].append(player)

  # Identify positional needs
  var positional_needs = _identify_needs(depth_by_position, config)

  # Calculate cap situation
  var league_cap = float(config.get("cap_limit", 225.0))
  var cap_used = CapTracking.calculate_team_cap_used(roster)
  var cap_space = league_cap - cap_used

  return {
    "team_id": String(team.get("id")),
    "year": year,
    "cap_space": cap_space,
    "positional_needs": positional_needs,
    "roster_size": players.size()
  }

## Prioritize which free agents to target based on needs and budget.
static func prioritize_free_agents(
  context: Dictionary,
  free_agent_pool: Array,
  config: Dictionary
) -> Array:
  var targets = []
  var cap_space = float(context.get("cap_space", 0.0))
  var needs = context.get("positional_needs", [])

  if cap_space < 5.0:
    return []  # Can't afford anyone

  # Create need lookup
  var need_map = {}
  for need in needs:
    need_map[String(need.get("position"))] = int(need.get("priority", 5))

  # Score each free agent
  for fa in free_agent_pool:
    var position = String(fa.get("position"))
    var market_value = float(fa.get("market_value", 0.0))

    # Can we afford them?
    if market_value > cap_space:
      continue

    # Do we need this position?
    var priority = need_map.get(position, 5)
    if priority > 3:
      continue  # Low priority

    var score = 0.0
    score += (5 - priority) * 10.0  # Need (0-30 pts)
    score += min(20.0, market_value / 2.0)  # Quality (0-20 pts)
    score += 10.0 * (1.0 - market_value / cap_space)  # Affordability (0-10 pts)

    targets.append({
      "player_id": String(fa.get("player_id")),
      "position": position,
      "market_value": market_value,
      "target_score": score
    })

  targets.sort_custom(func(a, b): return a.target_score > b.target_score)

  # Take top 5 within budget
  var final = []
  var budget = 0.0
  for target in targets:
    if budget + target.market_value > cap_space * 0.8:
      break
    final.append(target)
    budget += target.market_value
    if final.size() >= 5:
      break

  return final

## Generate contract offer for a free agent.
static func make_offer(
  player: Dictionary,
  team_context: Dictionary,
  valuation: Dictionary,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  var cap_space = float(team_context.get("cap_space", 0.0))
  var market_value = float(valuation.get("market_value", 0.0))

  # Can't afford player
  if market_value > cap_space:
    return {}

  # Determine contract years
  var age = int(player.get("age", 25))
  var years = ContractValuation._typical_contract_years(age)

  # Offer within market value range
  var range_min = float(valuation.get("range_min", market_value * 0.85))
  var range_max = float(valuation.get("range_max", market_value * 1.15))

  # Slight randomness in offer (deterministic from RNG)
  var offer_apy = rng.randf_range(range_min, range_max)
  offer_apy = min(offer_apy, cap_space / years)  # Cap constraint

  var total = offer_apy * years
  var guaranteed_pct = _guaranteed_percentage(player.get("position"), config)

  return {
    "team_id": String(team_context.get("team_id")),
    "years": years,
    "apy": offer_apy,
    "total_value": total,
    "guaranteed": total * guaranteed_pct,
    "offer_quality": offer_apy / market_value  # 1.0 = fair market value
  }

## INTERNAL: Identify positional needs based on roster depth.
static func _identify_needs(depth: Dictionary, config: Dictionary) -> Array:
  var needs = []
  var starter_slots = config.get("scarcity", {}).get("starter_slots", {})

  for position in starter_slots.keys():
    var required = int(starter_slots.get(position, 1))
    var current = depth.get(position, []).size()

    if current < required:
      needs.append({
        "position": position,
        "priority": 1,  # Critical
        "current_depth": current,
        "required": required
      })
    elif current == required:
      # Check starter quality
      var players = depth.get(position, [])
      if not players.is_empty():
        players.sort_custom(func(a, b): return a.get("eval_score", 0) > b.get("eval_score", 0))
        var best = players[0].get("eval_score", 50.0)
        if best < 60.0:
          needs.append({
            "position": position,
            "priority": 2,  # High need (weak starter)
            "current_depth": current,
            "required": required
          })

  return needs

## INTERNAL: Guaranteed money percentage by position.
static func _guaranteed_percentage(position: String, config: Dictionary) -> float:
  # Phase 2: Simple position-based guarantees
  # QB/EDGE get more guaranteed, RB/K get less
  match position:
    "QB", "EDGE": return 0.7
    "CB", "WR", "OL": return 0.6
    "DL", "LB", "TE": return 0.5
    "RB", "S": return 0.4
    "K", "P": return 0.2
    _: return 0.5
```

### Phase 2B: Free Agency Orchestration

**Files to Create**:

#### 11. `/scripts/pipelines/FreeAgency.gd`

```gdscript
extends RefCounted
class_name FreeAgency

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")
const GmDecisions = preload("res://scripts/world/GmDecisions.gd")
const ContractLifecycle = preload("res://scripts/world/ContractLifecycle.gd")
const CapTracking = preload("res://scripts/world/CapTracking.gd")
const Rand = preload("res://autoloads/Rand.gd")

## Run free agency phase: collect free agents, run bidding, resolve signings.
##
## RNG Usage:
## - valuation_rng: For PlayerValue calculations (jitter if enabled)
## - offer_rng: For GM offer generation (slight variance)
## - player_rng: For player decision-making (tiebreakers)
static func run(
  world_state: Dictionary,
  year: int,
  seed: int,
  league_cfg: Dictionary,
  positions_cfg: Dictionary,
  main_cfg: Dictionary,
  valuation_cfg: Dictionary
) -> Dictionary:
  # Derive RNG seeds
  var valuation_rng = RandomNumberGenerator.new()
  valuation_rng.seed = Rand.splitmix64(seed ^ 0xFA000001)

  var offer_rng = RandomNumberGenerator.new()
  offer_rng.seed = Rand.splitmix64(seed ^ 0xFA000002)

  var player_rng = RandomNumberGenerator.new()
  player_rng.seed = Rand.splitmix64(seed ^ 0xFA000003)

  # Collect free agents
  var free_agents = _collect_free_agents(world_state, year)

  if free_agents.is_empty():
    return {
      "year": year,
      "free_agents": 0,
      "signings": 0,
      "unsigned": 0
    }

  # Value all free agents
  var valued_free_agents = _value_free_agents(
    free_agents,
    valuation_cfg,
    positions_cfg,
    valuation_rng
  )

  # GM decision phase: each team prioritizes targets
  var teams = world_state.get("nfl_teams", [])
  var rosters = world_state.get("nfl_rosters", {})
  var all_offers = []

  for team in teams:
    var t = team as Dictionary
    var team_id = String(t.get("id"))
    var roster = rosters.get(team_id, {})

    var context = GmDecisions.build_context(t, roster, world_state, year, league_cfg)
    var targets = GmDecisions.prioritize_free_agents(context, valued_free_agents, valuation_cfg)

    for target in targets:
      var player_id = String(target.get("player_id"))
      var player = _find_player(valued_free_agents, player_id)
      if player == null:
        continue

      var offer = GmDecisions.make_offer(
        player,
        context,
        player.get("valuation", {}),
        valuation_cfg,
        offer_rng
      )

      if not offer.is_empty():
        all_offers.append({
          "player_id": player_id,
          "team_id": team_id,
          "offer": offer
        })

  # Resolve signings: each player picks best offer
  var signings = _resolve_signings(
    valued_free_agents,
    all_offers,
    player_rng
  )

  # Apply signings to world state
  var signed_count = 0
  for signing in signings:
    _apply_signing(signing, world_state, year, rosters)
    signed_count += 1

  return {
    "year": year,
    "free_agents": free_agents.size(),
    "offers_made": all_offers.size(),
    "signings": signed_count,
    "unsigned": free_agents.size() - signed_count,
    "step_seeds": {
      "valuation": valuation_rng.seed,
      "offers": offer_rng.seed,
      "player_decisions": player_rng.seed
    }
  }

## INTERNAL: Collect all free agents from world state.
static func _collect_free_agents(world_state: Dictionary, year: int) -> Array:
  var free_agents = []

  # From free_agents pool (expired contracts)
  var fa_pool = world_state.get("free_agents", {})
  var year_fas = fa_pool.get(year, [])
  free_agents.append_array(year_fas)

  # TODO Phase 3: Also collect released players

  return free_agents

## INTERNAL: Calculate market value for all free agents.
static func _value_free_agents(
  free_agents: Array,
  valuation_cfg: Dictionary,
  positions_cfg: Dictionary,
  rng: RandomNumberGenerator
) -> Array:
  var valued = []

  for fa in free_agents:
    var player = fa as Dictionary
    var valuation = PlayerValue.calculate(player, {}, valuation_cfg, rng)

    player["valuation"] = valuation
    player["market_value"] = valuation.market_value
    valued.append(player)

  return valued

## INTERNAL: Resolve which players sign with which teams.
static func _resolve_signings(
  free_agents: Array,
  offers: Array,
  rng: RandomNumberGenerator
) -> Array:
  var signings = []

  # Group offers by player
  var offers_by_player = {}
  for offer_entry in offers:
    var player_id = String(offer_entry.get("player_id"))
    if not offers_by_player.has(player_id):
      offers_by_player[player_id] = []
    offers_by_player[player_id].append(offer_entry)

  # Each player picks best offer
  for player in free_agents:
    var player_id = String(player.get("player_id"))
    var player_offers = offers_by_player.get(player_id, [])

    if player_offers.is_empty():
      continue  # No offers, unsigned

    # Pick best offer (Phase 2: highest APY)
    # TODO Phase 3: Factor in player preferences (winning, loyalty)
    player_offers.sort_custom(func(a, b):
      return a.get("offer", {}).get("apy", 0.0) > b.get("offer", {}).get("apy", 0.0)
    )

    var best = player_offers[0]
    signings.append({
      "player": player,
      "team_id": String(best.get("team_id")),
      "offer": best.get("offer", {}),
      "num_offers": player_offers.size()
    })

  return signings

## INTERNAL: Apply signing to world state (update rosters, create contract).
static func _apply_signing(
  signing: Dictionary,
  world_state: Dictionary,
  year: int,
  rosters: Dictionary
) -> void:
  var player = signing.get("player", {})
  var team_id = String(signing.get("team_id"))
  var offer = signing.get("offer", {})

  # Create contract
  var contract = ContractLifecycle.create_veteran_contract(
    player,
    team_id,
    offer,
    year,
    player.get("valuation", {})
  )

  player["contract"] = contract
  player["team_id"] = team_id
  player["nfl_status"] = "active"

  # Add to team roster
  var roster = rosters.get(team_id, {"players": []})
  roster["players"].append(player)
  rosters[team_id] = roster

## INTERNAL: Find player by ID in array.
static func _find_player(players: Array, player_id: String) -> Dictionary:
  for player in players:
    var p = player as Dictionary
    if String(p.get("player_id")) == player_id:
      return p
  return {}
```

### Phase 2C: Calendar Integration

**Files to Modify**:

#### 12. `/configs/sports/american_football/world/calendar.json`

Add free agency phase between draft and season:

```json
{
  "phases": [
    {"phase_id": "hs_generation", "months": [1]},
    {"phase_id": "hs_assignment", "months": [2]},
    {"phase_id": "hs_season", "months": [3, 4, 5]},
    {"phase_id": "college_generation", "months": [6]},
    {"phase_id": "nfl_team_generation", "months": [6]},
    {"phase_id": "college_recruiting", "months": [7, 8]},
    {"phase_id": "college_season", "months": [9, 10, 11]},
    {"phase_id": "draft_prep", "months": [12]},
    {"phase_id": "cap_validation", "months": [1]},
    {"phase_id": "nfl_draft", "months": [2]},
    {"phase_id": "nfl_free_agency", "months": [3]},
    {"phase_id": "nfl_season", "months": [4, 5, 6, 7, 8, 9]}
  ]
}
```

#### 13. `/scripts/pipelines/AdvanceWorldYear.gd`

Add free agency phase handler:

```gdscript
# In _phase_handlers() (around line 132-145)
func _phase_handlers() -> Dictionary:
  return {
    # ... existing handlers ...
    "nfl_draft": Callable(self, "_handle_nfl_draft"),
    "nfl_free_agency": Callable(self, "_handle_nfl_free_agency"),  # NEW
    "nfl_season": Callable(self, "_handle_nfl_season")
  }

# NEW: Free agency handler
func _handle_nfl_free_agency(
  world_state: Dictionary,
  year: int,
  _seed: int,
  phase: Dictionary,
  year_seed: int
) -> Dictionary:
  var phase_id = String(phase.get("phase_id", ""))
  var step_seed = _derive_seed(year_seed, phase_id, "nfl_free_agency")
  _log_step_seed(year, phase_id, "nfl_free_agency", step_seed)

  var league_cfg = _get_config().get_config("world/league")
  var positions_cfg = _get_config().get_config("positions")
  var main_cfg = _get_config().get_config("main")
  var valuation_cfg = _get_config().get_config("valuation")

  return FreeAgency.run(
    world_state,
    year,
    step_seed,
    league_cfg,
    positions_cfg,
    main_cfg,
    valuation_cfg
  )
```

### Phase 2 Testing

**Test Files**:

#### 14. `/scripts/tests/unit/test_gm_decisions.gd`

Test GM context building, prioritization, and offer generation.

#### 15. `/scripts/tests/integration/test_free_agency_flow.gd`

Test end-to-end free agency: expired contracts → valuation → bidding → signings.

### Phase 2 Acceptance Criteria

- [ ] Free agency phase runs after draft in world calendar
- [ ] Teams with cap space make offers to free agents
- [ ] Multiple teams bid on same player (competitive market)
- [ ] Players sign with highest bidder (Phase 2: simple logic)
- [ ] Signed players added to team rosters with veteran contracts
- [ ] Cap space decreases for signing teams
- [ ] 20-year bootstrap produces realistic free agent movement
- [ ] Statistical validation: ~20-30% of players change teams per year
- [ ] Unit tests for GmDecisions and FreeAgency pass

---

## Phase 3: Advanced Contract Mechanics

**Goal**: Signing bonuses, dead money acceleration, contract restructuring

**Value Delivered**:
- Realistic cap hits spread over contract years
- Teams can manipulate cap structure for short-term flexibility
- Releasing players has multi-year cap implications
- Contract restructuring enables "win-now" strategies

### Phase 3 Implementation Summary

**Key Changes**:
1. Contract model adds `year_values` array and `bonus_proration`
2. Cap hit calculation changes from simple annual_value to year-specific
3. Dead money calculation accounts for bonus acceleration
4. Contract restructuring function allows cap manipulation

**Files to Modify**:
- `ContractLifecycle.gd`: Add bonus proration logic
- `CapTracking.gd`: Update cap hit calculation
- `GmDecisions.gd`: Add restructure evaluation
- `league.json`: Add restructuring rules

**Estimated Effort**: 2-3 days

---

## Phase 4: Sophisticated GM Strategy

**Goal**: Analytics-driven decisions, multi-year planning, compensatory picks

**Value Delivered**:
- Teams make strategic decisions based on window (rebuilding vs contending)
- Contract extensions balanced against cap flexibility
- Draft capital influences free agency aggression
- Compensatory picks for lost free agents

### Phase 4 Implementation Summary

**Key Changes**:
1. Team strategy inference from win/loss record
2. Multi-year cap projection for extension decisions
3. Compensatory pick tracking for free agent losses
4. Analytics-based position value tiers

**Files to Create**:
- `TeamStrategy.gd`: Infer rebuild/contend mode
- `CompensatoryPicks.gd`: Track FA losses for draft compensation

**Estimated Effort**: 2-3 days

---

## Implementation Order

```
Week 1: Phase 1 (Foundation)
  Days 1-2: ContractLifecycle, CapTracking, config
  Day 3: Integration with NflDraft, NflSeason
  Day 4: Testing and validation

Week 2: Phase 2 (Free Agency)
  Days 1-2: GmDecisions, FreeAgency
  Day 3: Calendar integration, testing
  Day 4: Bootstrap validation, tuning

Week 3: Phase 3 (Advanced Mechanics)
  Days 1-2: Bonus proration, dead money
  Day 3: Contract restructuring
  Day 4: Testing

Week 4: Phase 4 (Sophistication)
  Days 1-2: Team strategy, analytics
  Day 3: Compensatory picks
  Day 4: Final testing, documentation
```

---

## Testing Strategy

### Unit Tests

**Coverage Requirements**: >95% for all new modules

- `ContractLifecycle`: All state transitions, edge cases
- `CapTracking`: Cap calculations, violation detection
- `GmDecisions`: Context building, prioritization, offers
- `FreeAgency`: Bidding resolution, signing application

### Integration Tests

- 20-year bootstrap with contracts enabled
- Free agency produces realistic player movement
- Cap violations are rare and resolved automatically
- Contract values match PlayerValue estimates

### Performance Tests

- Free agency phase <5% of total bootstrap time
- 32 teams, 100 free agents, full bidding completes in <1 second

### Statistical Validation

After 20-year bootstrap:
- Cap usage distribution: mean ~90% of cap, std dev <10%
- Free agent signings: 15-25% of players per year
- Rookie contracts: All drafted players signed
- Contract lengths: Match age curves (young=longer, old=shorter)

---

## Migration and Versioning

### World State Migration

**Version 1 → Version 2** (Phase 1):
- Add `free_agents` dictionary to world_state
- Add `contract_transactions` log
- All existing players get default contracts (0 years = free agent)

### Configuration Versioning

**league.json v2 → v3**:
- Add `rookie_contract_scale`
- Add `cap_enforcement` section
- Add `veteran_minimum` scale

### Backward Compatibility

- Missing contract data defaults to free agent status
- Old saves can be upgraded via migration script
- Cap validation can be disabled via feature flag

---

## Risk Mitigation

### High Risk

**Determinism Violations**:
- Mitigation: Strict RNG patterns, separate RNGs per phase
- Validation: Replay same seed, compare outputs

**Performance Regression**:
- Mitigation: Profile free agency phase, optimize bottlenecks
- Target: <5% bootstrap overhead

### Medium Risk

**Cap Accounting Bugs**:
- Mitigation: Comprehensive unit tests, statistical validation
- Recovery: Cap validation phase can force compliance

**Unrealistic Market Dynamics**:
- Mitigation: Tune GM decision weights via config
- Validation: Compare to real NFL FA market statistics

---

## Success Metrics

After Phase 1:
- ✅ All active NFL players have contracts
- ✅ Cap tracking works correctly
- ✅ Bootstrap completes without errors

After Phase 2:
- ✅ Free agency produces player movement
- ✅ Teams fill roster needs strategically
- ✅ Market values are competitive

After Phase 3:
- ✅ Cap manipulation creates strategic trade-offs
- ✅ Dead money affects multi-year planning

After Phase 4:
- ✅ Teams build coherent rosters over time
- ✅ Contenders vs rebuilders have different strategies
- ✅ Draft capital influences free agency behavior

---

## Appendix: File Structure

```
scripts/
├── world/
│   ├── ContractLifecycle.gd      [Phase 1]
│   ├── CapTracking.gd             [Phase 1]
│   ├── GmDecisions.gd             [Phase 2]
│   ├── TeamStrategy.gd            [Phase 4]
│   └── CompensatoryPicks.gd       [Phase 4]
├── pipelines/
│   ├── FreeAgency.gd              [Phase 2]
│   └── AdvanceWorldYear.gd        [Modified: Phase 2]
└── tests/
    ├── unit/
    │   ├── test_contract_lifecycle.gd    [Phase 1]
    │   ├── test_cap_tracking.gd          [Phase 1]
    │   ├── test_gm_decisions.gd          [Phase 2]
    │   └── test_free_agency.gd           [Phase 2]
    └── integration/
        ├── test_contract_bootstrap.gd     [Phase 1]
        └── test_free_agency_flow.gd       [Phase 2]

configs/sports/american_football/
├── world/
│   ├── league.json                [Modified: Phase 1, 2]
│   └── calendar.json              [Modified: Phase 2]
└── valuation.json                 [Existing, no changes needed]
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial implementation plan |
