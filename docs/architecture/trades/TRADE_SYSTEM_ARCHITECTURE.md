# Trade System Architecture

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Context**: Realistic team-building through player and draft pick trades

---

## Executive Summary

This document specifies the architecture for a realistic NFL trade system that creates authentic team-building dynamics. The design emphasizes **realism over accessibility**: teams should NOT always be willing to trade, bad teams won't give up young talent easily, division rivals rarely help each other, and trades should be rare events (~10-20 significant trades per year across 32 teams).

**Core Philosophy**: Teams are rational actors with asymmetric information, competing interests, and organizational constraints. The system must model **motivation** (why trade?), **willingness** (why refuse?), and **valuation** (what's fair?) to produce trades that feel like real NFL GMs making tough decisions.

**Key Decisions**:
- **Integration**: Extends `NflSeason` and uses existing `PlayerValue` system
- **Timing**: Trade checks occur during specific season phases (draft day, preseason, mid-season, trade deadline)
- **Frequency**: Configurable but defaults to "rare" (5-15 trades per year)
- **Determinism**: Fully deterministic given same world state and RNG seed
- **Scope**: Phase 1 includes player trades only; draft picks in Phase 2

---

## Design Philosophy

### 1. Architectural Coherence

The trade system must integrate seamlessly with existing systems:

**Integration Points**:
- Uses `PlayerValue.calculate()` for trade valuation (market_value, team_value, team_premium)
- Extends `NflSeason.run()` with trade processing phases
- Leverages `ContractLifecycle` for cap implications of trades
- Follows existing RNG patterns (seed derivation, deterministic random)
- Uses `world_state` dictionary for trade history persistence

**Pattern Consistency**:
- Season classes orchestrate trade logic (not separate systems)
- Configuration-driven behavior (trade windows, value thresholds)
- Stateless helper functions with explicit RNG passing
- In-place world_state mutation (standard pattern)

### 2. Complexity Management

Build incrementally to avoid over-engineering:

**Phase 1 (MVP)**: Player trades only
- Trade motivation detection (injury, roster imbalance, team status)
- Simple partner matching (need-based filtering)
- Value-based fairness checking (±30% tolerance)
- 1-for-1 player trades only
- Configurable trade frequency

**Phase 2 (Draft Picks)**: Add pick trading
- Draft pick value chart (positional value model)
- Player + pick combinations
- Pick swaps (trade down scenarios)
- Future pick trading (up to 2 years forward)

**Phase 3 (Advanced)**: Multi-team trades
- 3-team trade matching
- Conditional picks (if player starts X games)
- Trade clauses (no-trade protection)

**Phase 4 (Realism)**: Behavioral complexity
- Team relationship modeling (division rivalry penalty)
- GM personality variance (risk-taking, loyalty)
- Media pressure simulation (playoff push urgency)

**CRITICAL**: Do not implement Phase 2+ until Phase 1 validates in production.

### 3. Boundary Definition

Clear separation of concerns:

```
┌─────────────────────────────────────────────────┐
│           NflSeason.run() Pipeline              │
│  - Orchestrates trade windows                   │
│  - Manages world state updates                  │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼────────┐    ┌────────▼────────┐
│  TradeEngine    │    │  TradeValuation │
│  - match()      │    │  - fair_value() │
│  - negotiate()  │    │  - cap_impact() │
└────────┬────────┘    └────────┬────────┘
         │                      │
         └──────────┬───────────┘
                    │
         ┌──────────▼──────────┐
         │  PlayerValue        │
         │  (Existing system)  │
         │  - calculate()      │
         └─────────────────────┘
```

**Responsibilities**:
- **NflSeason**: Trade window timing, world state integration, cap validation
- **TradeEngine**: Motivation detection, partner matching, negotiation logic
- **TradeValuation**: Fair value calculation, cap impact analysis
- **PlayerValue**: Intrinsic player valuation (already exists)
- **Config files**: Trade windows, value thresholds, behavior parameters

### 4. Lifecycle Analysis

Long-term maintenance considerations:

**Version 1 Constraints**:
- No human player interaction (CPU-only trades in Phase 1)
- No agent negotiations (simplified accept/reject logic)
- No trade rumors or media simulation
- No player happiness impact on trade value

**Future Expansion Hooks**:
- Trade model includes `negotiation_history` field (unused in Phase 1)
- Team model can include `trade_block` array (explicit availability list)
- Player model supports `no_trade_clause` flag (respected in Phase 3+)
- Trade value calculation pluggable (can add advanced models later)

**Migration Strategy**:
- Config version fields allow backwards compatibility
- World state trade history format supports schema evolution
- Trade engine can detect missing player fields (graceful degradation)

---

## Core Concepts

### Trade Motivation Taxonomy

Teams trade for **specific reasons**, not just because they can. The system models six primary motivations:

#### 1. Injury Crisis (Reactive)
- **Trigger**: Key starter injured for season (IR designation)
- **Urgency**: HIGH (must act within 1-2 weeks)
- **Target**: Veteran replacement at injured position
- **Value Tolerance**: +20% overpay acceptable (desperation premium)
- **Example**: QB tears ACL week 2 → trade for backup QB immediately

#### 2. Unexpected Retirement (Reactive)
- **Trigger**: Player retires mid-offseason or unexpectedly
- **Urgency**: MEDIUM (need to fill hole before season)
- **Target**: Similar position, similar age/skill
- **Value Tolerance**: +10% overpay acceptable
- **Example**: Pro Bowl LT retires at 32 → need new starter

#### 3. Playoff Push (Proactive)
- **Trigger**: Team 7+ wins by week 10, weak playoff spot
- **Urgency**: MEDIUM (deadline-driven)
- **Target**: "Missing piece" at weak position
- **Value Tolerance**: Future value trade (picks for players)
- **Example**: 9-2 team trades 1st rounder for star WR

#### 4. Rebuild Mode (Proactive)
- **Trigger**: Team 2-8 or worse by week 10
- **Urgency**: LOW (patient asset accumulation)
- **Target**: Draft picks, young players with potential
- **Value Tolerance**: Accept 15% discount for future value
- **Example**: 2-10 team trades 30-year-old DE for 2nd round pick

#### 5. Cap Casualty (Proactive)
- **Trigger**: Team over cap, must shed salary
- **Urgency**: HIGH (cap compliance required)
- **Target**: Any team with cap space
- **Value Tolerance**: Accept significant discount to avoid release
- **Example**: Trade $15M/year player for 5th round pick to clear space

#### 6. Roster Imbalance (Proactive)
- **Trigger**: 4+ players at same position (surplus)
- **Urgency**: LOW (opportunistic)
- **Target**: Team with deficit at that position
- **Value Tolerance**: Equal value only (no desperation)
- **Example**: Team with 4 quality RBs trades one for OL help

**Implementation Note**: Each motivation has a `detect()` function that scans world state and returns motivation score (0.0-1.0).

---

## Data Models

### Core Entities

#### TradeProposal

Represents a potential trade before execution.

```gdscript
{
  "proposal_id": String,           # "trade_2025_w8_p42"
  "year": int,                     # 2025
  "week": int,                     # 8 (or 0 for offseason)
  "phase": String,                 # "draft", "preseason", "midseason", "deadline"

  # Teams involved
  "team_a_id": String,
  "team_b_id": String,

  # Assets exchanged (Phase 1: players only)
  "team_a_gives": {
    "players": [player_id_1, ...],
    "picks": []                    # Phase 2+
  },
  "team_b_gives": {
    "players": [player_id_2, ...],
    "picks": []                    # Phase 2+
  },

  # Valuation
  "team_a_value": float,           # Total value team A receives
  "team_b_value": float,           # Total value team B receives
  "value_differential": float,     # abs(a_value - b_value)
  "value_pct_diff": float,         # Percentage difference

  # Context
  "team_a_motivation": String,     # "injury_crisis", "playoff_push", etc.
  "team_b_motivation": String,
  "team_a_urgency": float,         # 0.0-1.0
  "team_b_urgency": float,

  # Negotiation state
  "status": String,                # "proposed", "accepted", "rejected", "countered"
  "rejection_reason": String,      # "unfair_value", "division_rival", "positional_need", etc.
  "counter_offer_id": String,      # Reference to counter-proposal (Phase 2+)

  # Cap implications
  "team_a_cap_impact": float,      # Change in cap used (can be negative)
  "team_b_cap_impact": float,

  # Metadata
  "rng_seed": int,                 # For determinism tracking
  "generation_method": String      # "cpu_initiated", "opportunity_match", etc.
}
```

**Storage**: NOT persisted during season (recalculated). Only completed trades stored.

#### CompletedTrade

Executed trade stored in history.

```gdscript
{
  "trade_id": String,              # "trade_2025_w8_t12"
  "year": int,
  "week": int,
  "phase": String,

  # Teams
  "team_a_id": String,
  "team_a_name": String,           # Cached for display
  "team_b_id": String,
  "team_b_name": String,

  # What was traded
  "team_a_gave": {
    "players": [
      {"id": String, "name": String, "position": String, "value": float},
      ...
    ],
    "picks": []                    # Phase 2+
  },
  "team_b_gave": {
    "players": [...],
    "picks": []
  },

  # Final valuation
  "team_a_value_received": float,
  "team_b_value_received": float,
  "value_differential": float,
  "winner": String,                # "team_a", "team_b", or "balanced" if <5% diff

  # Context (for storytelling)
  "primary_motivation": String,    # The driving force behind the trade
  "headline": String,              # "Team A trades star WR to Team B for 1st round pick"

  # Contract implications
  "team_a_cap_change": float,
  "team_b_cap_change": float,

  # Timestamp
  "trade_date": String             # "2025-W8-Tuesday" or similar
}
```

**Storage**: `world_state["trade_history"][year]` (array of CompletedTrade)

#### TeamTradeProfile

Per-team trading context (computed each trade window).

```gdscript
{
  "team_id": String,
  "year": int,
  "week": int,

  # Team status
  "team_status": String,           # "contender", "playoff_bubble", "rebuilder", "mediocre"
  "wins": int,
  "losses": int,

  # Roster health
  "positional_needs": {            # Positions with depth < 2
    "QB": {"severity": 0.9, "reason": "starter_injured"},
    "CB": {"severity": 0.6, "reason": "low_depth"}
  },
  "positional_surplus": {          # Positions with depth > 4
    "RB": {"count": 5, "tradeable": [player_id_1, player_id_2]}
  },

  # Trade willingness
  "trade_temperature": String,     # "frozen", "cold", "warm", "hot"
  "temperature_score": float,      # 0.0-1.0
  "untouchables": [player_id, ...],  # Core players not available

  # Cap situation
  "cap_space": float,
  "cap_flexibility": String,       # "tight", "neutral", "flexible"
  "must_shed_salary": bool,        # Over cap or close

  # Asset inventory
  "future_picks": {                # Phase 2+
    2026: [7],  # Remaining picks by round
    2027: [7]
  },
  "young_assets": [player_id, ...],  # Players age <25 with potential >75

  # Relationships (Phase 4)
  "division_rivals": [team_id, ...],
  "recent_trade_partners": [team_id, ...]  # Last 3 years
}
```

**Storage**: Computed on-demand during trade windows, not persisted.

---

## Trade Willingness System

### Team Status Classification

Teams have different trade behaviors based on competitive status:

```gdscript
func classify_team_status(team: Dictionary, roster: Dictionary, season_record: Dictionary) -> String:
  var wins := int(season_record.get("wins", 0))
  var losses := int(season_record.get("losses", 0))
  var games_played := wins + losses

  if games_played < 6:
    # Early season: use roster strength to project
    var avg_rating := _calculate_average_roster_rating(roster)
    if avg_rating >= 75.0:
      return "contender"
    elif avg_rating <= 60.0:
      return "rebuilder"
    else:
      return "mediocre"

  var win_pct := float(wins) / float(games_played)

  if win_pct >= 0.650:
    return "contender"  # ~10+ wins projected
  elif win_pct >= 0.500:
    return "playoff_bubble"  # 8-9 wins, could go either way
  elif win_pct >= 0.350:
    return "mediocre"  # 5-7 wins, not competing
  else:
    return "rebuilder"  # <6 wins, rebuild mode
```

### Trade Temperature Model

Temperature determines how willing a team is to make ANY trade:

**Frozen (0.0-0.2)**: Will not trade except under extreme duress
- Contenders protecting core during playoff push
- Teams just hit by major trade (reluctance to make another)
- No clear needs or surplus

**Cold (0.2-0.4)**: Reluctant but will consider great offers
- Mediocre teams without clear direction
- Teams with balanced rosters (no pressing needs)
- Recently completed trade (cooling off period)

**Warm (0.4-0.6)**: Open to reasonable trades
- Playoff bubble teams identifying weak positions
- Teams with clear positional surplus
- Normal trade interest

**Hot (0.6-0.8)**: Actively seeking trades
- Injury crisis requiring immediate help
- Playoff push needing "missing piece"
- Cap trouble requiring salary dump
- Deadline pressure (last chance to move veterans)

**Overheating (0.8-1.0)**: Desperate to trade
- Must cut salary to reach cap compliance
- Starter lost for season, no backup
- Extreme roster imbalance (6 RBs, 1 QB)

**Temperature Calculation**:

```gdscript
func calculate_trade_temperature(profile: TeamTradeProfile, week: int, cfg: Dictionary) -> float:
  var temp := 0.3  # Base temperature (slightly cold)

  # Motivation boosts
  for need in profile.positional_needs.values():
    var severity := float(need.get("severity", 0.0))
    temp += severity * 0.15  # Each critical need adds heat

  if profile.must_shed_salary:
    temp += 0.25  # Cap crisis is urgent

  # Deadline proximity (if in-season)
  if week > 0:
    var weeks_to_deadline := 10 - week  # Deadline typically week 10
    if weeks_to_deadline <= 2 and weeks_to_deadline >= 0:
      temp += 0.15  # Deadline urgency

  # Team status adjustments
  match profile.team_status:
    "contender":
      temp -= 0.1  # Contenders protect assets
      if week >= 8:  # Late season, might push
        temp += 0.2
    "rebuilder":
      temp += 0.1  # Rebuilders always looking for picks
    "playoff_bubble":
      if week >= 6:
        temp += 0.15  # Bubble teams get aggressive

  # Surplus encourages trades
  if profile.positional_surplus.size() >= 2:
    temp += 0.1

  # Recent trade cooldown
  var recent_trades := _count_recent_trades(profile.team_id, 4)
  temp -= recent_trades * 0.15  # Each recent trade reduces willingness

  return clamp(temp, 0.0, 1.0)
```

### Untouchable Players

Certain players should never be available for trade:

```gdscript
func identify_untouchables(roster: Dictionary, cfg: Dictionary) -> Array:
  var untouchables := []
  var players: Array = roster.get("players", [])

  for player in players:
    var p: Dictionary = player

    # Franchise QB under 30
    if p.get("position") == "QB" and p.get("age") < 30:
      var rating := _calculate_overall_rating(p)
      if rating >= 80.0:
        untouchables.append(p.get("id"))
        continue

    # Elite young players (future cornerstones)
    if p.get("age") <= 25:
      var potential := _calculate_potential_rating(p)
      if potential >= 85.0:
        untouchables.append(p.get("id"))
        continue

    # Team captains / culture players (Phase 4)
    if p.get("traits", []).has("Team_Captain"):
      untouchables.append(p.get("id"))
      continue

    # Players with no-trade clauses (Phase 3)
    var contract: Dictionary = p.get("contract", {})
    if contract.get("no_trade_clause", false):
      untouchables.append(p.get("id"))
      continue

  return untouchables
```

### Positional Constraints

Teams won't trade themselves into impossible roster situations:

```gdscript
func can_trade_player_positionally(
  player_id: String,
  roster: Dictionary,
  cfg: Dictionary
) -> Dictionary:
  var player := _find_player_by_id(roster, player_id)
  var position := String(player.get("position", ""))

  # Count depth at position
  var depth := _count_position_depth(roster, position)

  # Position-specific minimums
  var min_depth := _get_position_minimum(position, cfg)

  if depth <= min_depth:
    return {
      "can_trade": false,
      "reason": "insufficient_depth",
      "message": "Cannot trade only starter at %s" % position
    }

  # Special case: QB protection
  if position == "QB":
    var healthy_qbs := _count_healthy_qbs(roster)
    if healthy_qbs <= 1:
      return {
        "can_trade": false,
        "reason": "qb_scarcity",
        "message": "Must have 2+ healthy QBs to trade one"
      }

  return {"can_trade": true}
```

**Position Minimums** (from config):
```json
{
  "position_minimums": {
    "QB": 2,
    "RB": 3,
    "WR": 4,
    "TE": 2,
    "OL": 8,
    "DL": 6,
    "EDGE": 4,
    "LB": 5,
    "CB": 4,
    "S": 3,
    "K": 1,
    "P": 1
  }
}
```

---

## Trade Valuation System

### Value Calculation Algorithm

Leverage existing `PlayerValue` system for accurate valuation:

```gdscript
func calculate_trade_value(
  player_id: String,
  from_team: Dictionary,
  to_team: Dictionary,
  context: Dictionary,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  var player := _find_player_by_id(from_team, player_id)

  # Use PlayerValue for market value
  var from_roster: Array = from_team.get("roster", {}).get("players", [])
  var to_roster: Array = to_team.get("roster", {}).get("players", [])

  var from_context := {
    "team_roster": from_roster,
    "position_supply": context.get("position_supply", {})
  }
  var to_context := {
    "team_roster": to_roster,
    "position_supply": context.get("position_supply", {})
  }

  # Calculate value from both perspectives
  var from_valuation := PlayerValue.calculate(player, from_context, config, rng)
  var to_valuation := PlayerValue.calculate(player, to_context, config, rng)

  # Trade value is market_value (what other teams pay)
  # BUT if team has high team_premium, they demand more
  var base_trade_value := from_valuation.market_value

  # Team premium increases asking price
  var team_premium := from_valuation.team_premium
  if team_premium > 0:
    # Teams with high internal value demand premium
    # Example: QB with no backup worth 50% more to current team
    var premium_factor := clamp(team_premium / base_trade_value, 0.0, 0.5)
    base_trade_value *= (1.0 + premium_factor * 0.5)  # Max 25% premium

  # Receiving team values based on their needs
  var to_team_value := to_valuation.team_value

  return {
    "player_id": player_id,
    "market_value": from_valuation.market_value,
    "from_team_value": from_valuation.team_value,
    "to_team_value": to_team_value,
    "trade_value": base_trade_value,  # What team asks for
    "team_premium": team_premium,
    "receiving_premium": to_team_value - to_valuation.market_value
  }
```

### Fair Trade Bounds

Trades must be within acceptable value ranges:

```gdscript
func is_trade_fair(
  proposal: TradeProposal,
  team_a_profile: TeamTradeProfile,
  team_b_profile: TeamTradeProfile,
  cfg: Dictionary
) -> Dictionary:
  var value_a := proposal.team_a_value
  var value_b := proposal.team_b_value

  if value_a == 0 or value_b == 0:
    return {"fair": false, "reason": "zero_value"}

  var pct_diff := abs(value_a - value_b) / max(value_a, value_b)

  # Base tolerance from config (default 30%)
  var base_tolerance := float(cfg.get("trade_value_tolerance", 0.30))

  # Urgency increases tolerance
  var max_urgency := max(
    team_a_profile.temperature_score,
    team_b_profile.temperature_score
  )
  var urgency_bonus := max_urgency * 0.15  # Up to 15% extra tolerance

  var effective_tolerance := base_tolerance + urgency_bonus

  if pct_diff <= effective_tolerance:
    return {
      "fair": true,
      "pct_diff": pct_diff,
      "tolerance": effective_tolerance
    }
  else:
    return {
      "fair": false,
      "reason": "value_imbalance",
      "pct_diff": pct_diff,
      "tolerance": effective_tolerance,
      "message": "Trade value off by %.1f%%, exceeds %.1f%% tolerance" % [
        pct_diff * 100.0,
        effective_tolerance * 100.0
      ]
    }
```

### Division Rival Penalty

Teams in the same division rarely trade with each other:

```gdscript
func apply_division_rival_penalty(
  proposal: TradeProposal,
  team_a: Dictionary,
  team_b: Dictionary,
  cfg: Dictionary
) -> Dictionary:
  var team_a_div := String(team_a.get("division", ""))
  var team_b_div := String(team_b.get("division", ""))

  if team_a_div == team_b_div and team_a_div != "":
    # Same division: apply penalty
    var penalty_mult := float(cfg.get("division_rival_penalty", 1.5))

    # Increase value requirement by penalty multiplier
    # Example: 1.5x means value must be 50% better to overcome reluctance
    proposal.team_a_value *= penalty_mult
    proposal.value_differential = abs(proposal.team_a_value - proposal.team_b_value)
    proposal.value_pct_diff = proposal.value_differential / max(proposal.team_a_value, proposal.team_b_value)

    return {
      "penalty_applied": true,
      "multiplier": penalty_mult,
      "note": "Division rivals require %d%% better value to trade" % int((penalty_mult - 1.0) * 100)
    }

  return {"penalty_applied": false}
```

---

## Trade Partner Matching

### Motivation-Based Matching

Efficient algorithm to find compatible trade partners:

```gdscript
func find_trade_partners(
  initiating_team_profile: TeamTradeProfile,
  all_teams: Array,
  world_state: Dictionary,
  config: Dictionary
) -> Array:
  var matches := []
  var initiator_id := initiating_team_profile.team_id

  # Identify what initiating team wants
  var needs := initiating_team_profile.positional_needs.keys()
  var surplus := initiating_team_profile.positional_surplus.keys()

  if needs.is_empty() and surplus.is_empty():
    return []  # No clear trade motivation

  # Scan all other teams for complementary needs
  for team in all_teams:
    var t: Dictionary = team
    var team_id := String(t.get("id", ""))

    if team_id == initiator_id:
      continue  # Can't trade with self

    var partner_profile := _build_team_trade_profile(t, world_state, config)

    # Skip frozen teams (won't trade)
    if partner_profile.temperature_score < 0.2:
      continue

    # Check for complementary needs
    var compatibility_score := 0.0

    # Do we have surplus they need?
    for pos in surplus:
      if partner_profile.positional_needs.has(pos):
        var severity := float(partner_profile.positional_needs[pos].get("severity", 0.0))
        compatibility_score += severity * 0.5

    # Do they have surplus we need?
    for pos in needs:
      if partner_profile.positional_surplus.has(pos):
        var severity := float(initiating_team_profile.positional_needs[pos].get("severity", 0.0))
        compatibility_score += severity * 0.5

    if compatibility_score >= 0.3:  # Minimum threshold
      matches.append({
        "team_id": team_id,
        "profile": partner_profile,
        "compatibility": compatibility_score
      })

  # Sort by compatibility (most compatible first)
  matches.sort_custom(func(a, b): return a.compatibility > b.compatibility)

  return matches
```

### Trade Candidate Selection

Find tradeable players that meet partner needs:

```gdscript
func find_trade_candidates(
  team_profile: TeamTradeProfile,
  target_position: String,
  roster: Dictionary,
  config: Dictionary
) -> Array:
  var candidates := []
  var players: Array = roster.get("players", [])

  for player in players:
    var p: Dictionary = player
    var player_id := String(p.get("id", ""))
    var position := String(p.get("position", ""))

    if position != target_position:
      continue

    # Skip untouchables
    if team_profile.untouchables.has(player_id):
      continue

    # Check positional constraint
    var can_trade_check := can_trade_player_positionally(player_id, roster, config)
    if not can_trade_check.get("can_trade", false):
      continue

    # Calculate trade value
    var value := _calculate_player_market_value(p, roster, config)

    candidates.append({
      "player_id": player_id,
      "player": p,
      "position": position,
      "trade_value": value,
      "age": int(p.get("age", 30)),
      "contract_years": int(p.get("contract", {}).get("years_remaining", 0))
    })

  # Sort by value (best players first, usually)
  candidates.sort_custom(func(a, b): return a.trade_value > b.trade_value)

  return candidates
```

---

## Trade Execution Pipeline

### Phase 1: Trade Window Processing

`NflSeason.run()` integrates trade windows at specific times:

```gdscript
func run(world_state: Dictionary, year: int, seed: int, league_cfg: Dictionary, ...) -> Dictionary:
  # ... existing roster loading ...

  # TRADE WINDOW 1: Pre-Draft (late offseason)
  var pre_draft_seed := Rand.splitmix64(seed ^ 0xTRADE01)
  var pre_draft_trades := _process_trade_window(
    world_state, year, 0, "pre_draft", pre_draft_seed, league_cfg
  )

  # ... draft processing ...

  # TRADE WINDOW 2: Preseason (roster cuts period)
  var preseason_seed := Rand.splitmix64(seed ^ 0xTRADE02)
  var preseason_trades := _process_trade_window(
    world_state, year, 0, "preseason", preseason_seed, league_cfg
  )

  # ... season simulation ...

  # TRADE WINDOW 3: Mid-Season (week 6)
  var midseason_seed := Rand.splitmix64(seed ^ 0xTRADE03)
  var midseason_trades := _process_trade_window(
    world_state, year, 6, "midseason", midseason_seed, league_cfg
  )

  # TRADE WINDOW 4: Trade Deadline (week 10)
  var deadline_seed := Rand.splitmix64(seed ^ 0xTRADE04)
  var deadline_trades := _process_trade_window(
    world_state, year, 10, "deadline", deadline_seed, league_cfg
  )

  # ... existing player lifecycle ...

  return {
    # ... existing fields ...
    "trades": {
      "pre_draft": pre_draft_trades.size(),
      "preseason": preseason_trades.size(),
      "midseason": midseason_trades.size(),
      "deadline": deadline_trades.size(),
      "total": pre_draft_trades.size() + preseason_trades.size() +
               midseason_trades.size() + deadline_trades.size()
    }
  }
```

### Phase 2: Trade Window Logic

Core trade processing for each window:

```gdscript
func _process_trade_window(
  world_state: Dictionary,
  year: int,
  week: int,
  phase: String,
  seed: int,
  config: Dictionary
) -> Array:
  var rng := RandomNumberGenerator.new()
  rng.seed = seed

  var trades_cfg: Dictionary = config.get("trades", {})

  # Check if trades enabled for this phase
  var phase_cfg: Dictionary = trades_cfg.get(phase, {})
  if not bool(phase_cfg.get("enabled", false)):
    return []

  var teams: Array = world_state.get("nfl_teams", [])
  var rosters: Dictionary = world_state.get("nfl_rosters", {})
  var season_records: Dictionary = world_state.get("season_records", {}).get(year, {})

  # Build trade profiles for all teams
  var team_profiles := []
  for team in teams:
    var t: Dictionary = team
    var team_id := String(t.get("id", ""))
    var roster: Dictionary = rosters.get(team_id, {})
    var record: Dictionary = season_records.get(team_id, {})

    var profile := _build_team_trade_profile(t, roster, record, week, config)
    team_profiles.append(profile)

  # Determine how many trades to attempt this window
  var trade_frequency := float(phase_cfg.get("trade_frequency", 0.3))
  var max_trades := int(float(teams.size()) * trade_frequency / 4.0)  # Divided by 4 windows
  max_trades = max(1, max_trades)  # At least 1 attempt

  var completed_trades := []
  var teams_already_traded := {}  # Prevent same team trading twice in window

  for i in range(max_trades):
    # Pick random team to initiate trade
    var initiator_idx := rng.randi_range(0, team_profiles.size() - 1)
    var initiator_profile: Dictionary = team_profiles[initiator_idx]

    if teams_already_traded.has(initiator_profile.team_id):
      continue  # This team already traded this window

    # Check if team is warm enough to trade
    if initiator_profile.temperature_score < 0.4:
      continue  # Too cold, won't initiate

    # Find compatible partners
    var partners := find_trade_partners(initiator_profile, teams, world_state, config)
    if partners.is_empty():
      continue  # No viable partners

    # Attempt trade with most compatible partner
    var trade_result := _attempt_trade_with_partner(
      initiator_profile,
      partners[0],
      world_state,
      year,
      week,
      phase,
      config,
      rng
    )

    if trade_result.get("completed", false):
      completed_trades.append(trade_result.trade)
      teams_already_traded[initiator_profile.team_id] = true
      teams_already_traded[partners[0].team_id] = true

  # Execute all trades (update rosters, contracts, world state)
  for trade in completed_trades:
    _execute_trade(trade, world_state, year, config)

  return completed_trades
```

### Phase 3: Trade Negotiation

Attempt to construct and accept a trade:

```gdscript
func _attempt_trade_with_partner(
  initiator_profile: TeamTradeProfile,
  partner_match: Dictionary,
  world_state: Dictionary,
  year: int,
  week: int,
  phase: String,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  var partner_profile: Dictionary = partner_match.profile

  # Identify what each team wants
  var initiator_needs := initiator_profile.positional_needs.keys()
  var partner_needs := partner_profile.positional_needs.keys()

  if initiator_needs.is_empty() or partner_needs.is_empty():
    return {"completed": false, "reason": "no_mutual_needs"}

  # Pick most urgent need for each team
  var initiator_target_pos := _select_most_urgent_need(initiator_profile)
  var partner_target_pos := _select_most_urgent_need(partner_profile)

  # Get rosters
  var rosters: Dictionary = world_state.get("nfl_rosters", {})
  var initiator_roster := rosters.get(initiator_profile.team_id, {})
  var partner_roster := rosters.get(partner_profile.team_id, {})

  # Find tradeable players
  var initiator_candidates := find_trade_candidates(
    initiator_profile, partner_target_pos, initiator_roster, config
  )
  var partner_candidates := find_trade_candidates(
    partner_profile, initiator_target_pos, partner_roster, config
  )

  if initiator_candidates.is_empty() or partner_candidates.is_empty():
    return {"completed": false, "reason": "no_tradeable_players"}

  # Phase 1: Only 1-for-1 trades
  # Try to match players of similar value
  var best_match := _find_best_value_match(
    initiator_candidates[0],
    partner_candidates,
    config
  )

  if best_match == null:
    return {"completed": false, "reason": "no_value_match"}

  # Construct proposal
  var proposal := _build_trade_proposal(
    initiator_profile.team_id,
    partner_profile.team_id,
    [initiator_candidates[0].player_id],
    [best_match.player_id],
    world_state,
    year,
    week,
    phase,
    config,
    rng
  )

  # Validate trade
  var validation := _validate_trade_proposal(
    proposal,
    initiator_profile,
    partner_profile,
    world_state,
    config
  )

  if not validation.get("valid", false):
    return {
      "completed": false,
      "reason": validation.get("reason", "validation_failed"),
      "message": validation.get("message", "")
    }

  # Accept trade (both teams agree)
  proposal.status = "accepted"

  return {
    "completed": true,
    "trade": proposal
  }
```

### Phase 4: Trade Execution

Apply roster changes and update world state:

```gdscript
func _execute_trade(
  trade: TradeProposal,
  world_state: Dictionary,
  year: int,
  config: Dictionary
) -> void:
  var rosters: Dictionary = world_state.get("nfl_rosters", {})

  var team_a_roster := rosters.get(trade.team_a_id, {})
  var team_b_roster := rosters.get(trade.team_b_id, {})

  # Move players from A to B
  for player_id in trade.team_a_gives.players:
    var player := _remove_player_from_roster(player_id, team_a_roster)
    if player != null:
      _add_player_to_roster(player, team_b_roster)

      # Update player's team affiliation
      player["current_team_id"] = trade.team_b_id
      player["traded_from"] = trade.team_a_id
      player["trade_year"] = year

  # Move players from B to A
  for player_id in trade.team_b_gives.players:
    var player := _remove_player_from_roster(player_id, team_b_roster)
    if player != null:
      _add_player_to_roster(player, team_a_roster)

      player["current_team_id"] = trade.team_a_id
      player["traded_from"] = trade.team_b_id
      player["trade_year"] = year

  # Update rosters
  rosters[trade.team_a_id] = team_a_roster
  rosters[trade.team_b_id] = team_b_roster
  world_state["nfl_rosters"] = rosters

  # Store trade in history
  var trade_history: Dictionary = world_state.get("trade_history", {})
  if not trade_history.has(year):
    trade_history[year] = []

  var completed_trade := _convert_proposal_to_completed_trade(trade, world_state)
  (trade_history[year] as Array).append(completed_trade)
  world_state["trade_history"] = trade_history
```

---

## Configuration

### Trade System Config

Add to `league.json`:

```json
{
  "version": 3,
  "trades": {
    "enabled": true,
    "trade_value_tolerance": 0.30,
    "division_rival_penalty": 1.5,

    "position_minimums": {
      "QB": 2,
      "RB": 3,
      "WR": 4,
      "TE": 2,
      "OL": 8,
      "DL": 6,
      "EDGE": 4,
      "LB": 5,
      "CB": 4,
      "S": 3,
      "K": 1,
      "P": 1
    },

    "trade_windows": {
      "pre_draft": {
        "enabled": true,
        "trade_frequency": 0.2
      },
      "preseason": {
        "enabled": true,
        "trade_frequency": 0.3
      },
      "midseason": {
        "enabled": false,
        "trade_frequency": 0.15
      },
      "deadline": {
        "enabled": true,
        "trade_frequency": 0.4
      }
    },

    "temperature_factors": {
      "injury_crisis_boost": 0.25,
      "cap_crisis_boost": 0.25,
      "deadline_urgency_boost": 0.15,
      "recent_trade_penalty": 0.15,
      "contender_base_reduction": 0.1,
      "rebuilder_base_boost": 0.1
    },

    "motivation_weights": {
      "injury_crisis": 0.9,
      "cap_casualty": 0.85,
      "playoff_push": 0.7,
      "rebuild_mode": 0.6,
      "roster_imbalance": 0.4,
      "retirement_replacement": 0.75
    }
  }
}
```

---

## Performance Considerations

### Computational Complexity

**Trade window processing** (worst case):
```
Teams: 32
Max trade attempts per window: 32 * 0.3 / 4 = 2-3 trades
Partner matching: O(N) = 32 teams
Trade candidate search: O(M) = ~53 players per team
Value calculation: O(1) per player
Total per window: ~3 trades * 32 teams * 53 players * 0.001s = ~5 seconds worst case
```

**Optimization**: Cache team profiles at start of window (recalculate only once).

**Expected performance**:
- 4 trade windows per year
- 3-5 trades per window
- ~50ms per trade negotiation
- **Total overhead: <1 second per year** (negligible)

### Memory Footprint

**World state additions**:
```
Trade history per year:
- 10 trades * 500 bytes per CompletedTrade = 5 KB
- 20 years = 100 KB (negligible)

Team profiles (temporary):
- 32 teams * 2 KB per profile = 64 KB
- Not persisted (computed on demand)
```

---

## Testing Strategy

### Unit Tests

**TradeEngine functions**:
- `calculate_trade_temperature()`: Various team situations
- `identify_untouchables()`: Position/age/contract scenarios
- `can_trade_player_positionally()`: Depth constraints
- `is_trade_fair()`: Value differential edge cases
- `apply_division_rival_penalty()`: Same division validation

**TradeValuation functions**:
- `calculate_trade_value()`: Use PlayerValue integration
- `find_best_value_match()`: 1-for-1 matching logic

### Integration Tests

**NflSeason with trades**:
- World state correctly updated with trade history
- Rosters reflect player movements
- Contracts transferred correctly
- Cap implications calculated
- Determinism validated (same seed = same trades)

### Behavioral Tests

**Realism validation**:
- Division rivals trade <5% of time compared to non-rivals
- Contenders keep core players (80%+ rating, age <30)
- Rebuilders accept worse value for future assets
- Injury crisis increases trade temperature by >0.25
- Trade frequency: 10-20 trades per year (target range)

---

## Acceptance Criteria (Phase 1)

- [ ] `TradeEngine` class with pure functions (matching, valuation, negotiation)
- [ ] `NflSeason.run()` calls `_process_trade_window()` for 4 trade periods
- [ ] Trade history stored in `world_state["trade_history"]`
- [ ] Config file updated with `trades` section in `league.json`
- [ ] Unit tests for all TradeEngine functions (>90% coverage)
- [ ] Integration test: 20-year bootstrap produces 200-400 total trades
- [ ] Realism test: Division rivals trade <10% as often as non-rivals
- [ ] Realism test: Contenders keep 95%+ of elite young core players
- [ ] Performance test: Trade processing <5% overhead per season
- [ ] Documentation: Code comments explain motivation detection, value calculation

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial architecture specification |

---

**Next Steps**: Proceed to implementation planning, trade value specification, and example scenarios.
