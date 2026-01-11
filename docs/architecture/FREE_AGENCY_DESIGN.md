# Free Agency Design

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: [CONTRACT_SYSTEM_ARCHITECTURE.md](/home/patrick/Documents/code/gridiron-dynasty/docs/architectural_notes/CONTRACT_SYSTEM_ARCHITECTURE.md)

---

## Executive Summary

This document specifies the free agency market mechanics, including player valuation, multi-team bidding, player preferences, and signing resolution. The free agency system creates realistic player movement while maintaining determinism and computational efficiency.

**Design Principles**:
- **Competitive Market**: Multiple teams bid on same player (supply/demand)
- **Player Agency**: Players choose among offers based on money, winning, loyalty
- **Deterministic Auction**: Same seed produces same signings every time
- **Cap-Constrained**: Teams can only bid within their cap space
- **Position-Based Strategy**: Teams prioritize needs, not best available

---

## Free Agency Timeline

### Integration into World Calendar

**Phase sequence** (from `calendar.json`):
```
1. College Season (Sep-Dec)
2. Draft Prep (Jan)
3. Cap Validation (Feb)
4. NFL Draft (Mar)
5. NFL Free Agency (Apr)  ← NEW
6. NFL Season (May-Oct)
```

**Why after draft**:
- Teams know rookie cap commitments before FA spending
- Allows GM to evaluate roster needs post-draft
- Mimics NFL timeline (draft late April, FA starts mid-March but major signings post-draft)

---

## Free Agent Pool Collection

### Sources of Free Agents

**Phase 1 Sources**:
1. **Expired contracts** from NflSeason.run()
2. **Undrafted players** (Phase 2+)
3. **Released players** (Phase 2+)

```gdscript
func collect_free_agents(world_state: Dictionary, year: int) -> Array:
  var free_agents = []

  # Source 1: Expired contracts from previous season
  var fa_pool = world_state.get("free_agents", {})
  var expired = fa_pool.get(year, [])
  free_agents.append_array(expired)

  # Source 2: Released players (Phase 2)
  var releases = world_state.get("released_players", {}).get(year, [])
  free_agents.append_array(releases)

  # Source 3: Undrafted eligible players (Phase 2)
  var draft_eligible = world_state.get("draft_pool", {}).get(year, [])
  var undrafted = draft_eligible.filter(func(p): return not p.has("drafted"))
  free_agents.append_array(undrafted)

  return free_agents
```

### Free Agent Eligibility

**Requirements for FA status**:
- No active contract (`contract.status != "active"`)
- Not retired (`nfl_status != "retired"`)
- NFL-eligible (drafted or 3+ years removed from HS)

**Restricted vs Unrestricted** (Phase 4):
- **UFA**: 4+ accrued seasons, no rights held by former team
- **RFA**: 3 accrued seasons, former team can match offers
- **ERFA**: <3 accrued seasons, former team exclusive rights

Phase 1-2: All free agents are unrestricted.

---

## Player Valuation for Free Agency

### Market Value Calculation

Uses existing `PlayerValue.calculate()` system:

```gdscript
func value_free_agents(
  free_agents: Array,
  valuation_cfg: Dictionary,
  positions_cfg: Dictionary,
  rng: RandomNumberGenerator
) -> Array:
  var valued = []

  for fa in free_agents:
    var player = fa as Dictionary

    # Calculate market value using PlayerValue
    var context = {}  # No team context for free agents
    var valuation = PlayerValue.calculate(player, context, valuation_cfg, rng)

    # Store valuation in player for GM decision-making
    player["valuation"] = valuation
    player["market_value"] = valuation.market_value
    player["contract_demands"] = _generate_demands(player, valuation, valuation_cfg)

    valued.append(player)

  return valued
```

### Contract Demands Generation

**Player demands** (what they want from offers):

```gdscript
func _generate_demands(
  player: Dictionary,
  valuation: Dictionary,
  config: Dictionary
) -> Dictionary:
  var age = int(player.get("age", 25))
  var market_value = float(valuation.get("market_value"))
  var range_min = float(valuation.get("range_min"))
  var range_max = float(valuation.get("range_max"))

  # Contract years by age
  var min_years = 1
  var max_years = ContractValuation._typical_contract_years(age)

  # Young players want longer deals (security)
  if age < 26:
    min_years = max(2, max_years - 1)
  # Old players want flexibility
  elif age > 32:
    max_years = min(2, max_years)

  # Guaranteed money preference
  var position = String(player.get("position"))
  var min_guaranteed_pct = _base_guaranteed_pct(position) * 0.8  # Accept 80% of norm
  var max_guaranteed_pct = _base_guaranteed_pct(position) * 1.2  # Prefer 120% of norm

  return {
    "min_apy": range_min,
    "max_apy": range_max,
    "preferred_apy": market_value,
    "min_years": min_years,
    "max_years": max_years,
    "min_guaranteed_pct": min_guaranteed_pct,
    "preferred_guaranteed_pct": (min_guaranteed_pct + max_guaranteed_pct) / 2.0
  }

func _base_guaranteed_pct(position: String) -> float:
  match position:
    "QB", "EDGE": return 0.7
    "CB", "WR", "OL": return 0.6
    "DL", "LB", "TE": return 0.5
    "RB", "S": return 0.4
    _: return 0.5
```

---

## GM Decision Logic

### Positional Need Identification

```gdscript
func identify_positional_needs(
  roster: Dictionary,
  config: Dictionary
) -> Array:
  var players = roster.get("players", [])
  var depth_by_position = {}

  # Count players by position
  for player in players:
    var pos = String(player.get("position"))
    if not depth_by_position.has(pos):
      depth_by_position[pos] = []
    depth_by_position[pos].append(player)

  # Compare to required starter slots
  var needs = []
  var starter_slots = config.get("scarcity", {}).get("starter_slots", {})

  for position in starter_slots.keys():
    var required = int(starter_slots.get(position, 1))
    var current_depth = depth_by_position.get(position, [])
    var count = current_depth.size()

    var priority = 5  # Default: low priority

    if count == 0:
      priority = 1  # Critical: No players at position
    elif count < required:
      priority = 1  # Critical: Not enough starters
    elif count == required:
      # Check starter quality
      current_depth.sort_custom(func(a, b): return a.get("eval_score", 0) > b.get("eval_score", 0))
      var best_player = current_depth[0]
      var best_rating = float(best_player.get("eval_score", 50.0))

      if best_rating < 55.0:
        priority = 1  # Critical: Starter is below replacement
      elif best_rating < 65.0:
        priority = 2  # High: Weak starter
      elif best_rating < 75.0:
        priority = 3  # Medium: Average starter
      else:
        priority = 4  # Low: Good starter, depth only

    if priority <= 3:  # Only track medium+ priority needs
      needs.append({
        "position": position,
        "priority": priority,
        "current_depth": count,
        "required_starters": required,
        "best_rating": current_depth[0].get("eval_score", 0.0) if not current_depth.is_empty() else 0.0
      })

  # Sort by priority (1=most critical)
  needs.sort_custom(func(a, b): return a.priority < b.priority)

  return needs
```

### Free Agent Prioritization

```gdscript
func prioritize_free_agents(
  context: Dictionary,
  free_agent_pool: Array,
  config: Dictionary
) -> Array:
  var cap_space = float(context.get("cap_space", 0.0))
  var needs = context.get("positional_needs", [])

  if cap_space < 2.0:  # Less than $2M cap space
    return []  # Can't afford anyone

  # Create need map for quick lookup
  var need_map = {}
  for need in needs:
    need_map[String(need.get("position"))] = int(need.get("priority", 5))

  # Score each free agent
  var targets = []
  for fa in free_agent_pool:
    var player = fa as Dictionary
    var position = String(player.get("position"))
    var market_value = float(player.get("market_value", 0.0))
    var eval_score = float(player.get("eval_score", 50.0))

    # Can't afford player
    if market_value > cap_space:
      continue

    # Not a position of need
    var priority = need_map.get(position, 5)
    if priority > 3:
      continue  # Only target high/critical needs

    # Calculate target score
    var score = 0.0

    # Need priority (30 points max)
    score += (5 - priority) * 6.0

    # Player quality (30 points max)
    score += (eval_score - 50.0) / 50.0 * 30.0

    # Affordability (20 points max)
    var affordability = 1.0 - (market_value / cap_space)
    score += affordability * 20.0

    # Value for money (20 points max)
    var value_per_dollar = eval_score / max(1.0, market_value)
    score += min(20.0, value_per_dollar * 2.0)

    targets.append({
      "player_id": String(player.get("player_id")),
      "player": player,
      "position": position,
      "market_value": market_value,
      "target_score": score,
      "need_priority": priority
    })

  # Sort by target score (highest first)
  targets.sort_custom(func(a, b): return a.target_score > b.target_score)

  # Take top targets within budget
  var final_targets = []
  var budget_committed = 0.0

  for target in targets:
    var cost = target.market_value

    # Would exceed 80% of cap space
    if budget_committed + cost > cap_space * 0.8:
      continue

    final_targets.append(target)
    budget_committed += cost

    # Max 5 targets per team
    if final_targets.size() >= 5:
      break

  return final_targets
```

### Offer Generation

```gdscript
func make_offer(
  player: Dictionary,
  team_context: Dictionary,
  valuation: Dictionary,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  var cap_space = float(team_context.get("cap_space", 0.0))
  var market_value = float(valuation.get("market_value"))
  var range_min = float(valuation.get("range_min"))
  var range_max = float(valuation.get("range_max"))

  # Can't afford player
  if market_value > cap_space:
    return {}

  # Determine offer APY (slight randomness within range)
  var offer_apy = rng.randf_range(range_min, range_max)
  offer_apy = min(offer_apy, cap_space * 0.5)  # Don't commit >50% cap to one player

  # Determine contract years
  var age = int(player.get("age", 25))
  var years = ContractValuation._typical_contract_years(age)

  # Total value
  var total = offer_apy * years

  # Guaranteed money
  var position = String(player.get("position"))
  var guaranteed_pct = _guaranteed_percentage(position, config)
  var guaranteed = total * guaranteed_pct

  return {
    "team_id": String(team_context.get("team_id")),
    "years": years,
    "apy": offer_apy,
    "total_value": total,
    "guaranteed": guaranteed,
    "guaranteed_pct": guaranteed_pct,
    "offer_quality": offer_apy / market_value  # 1.0 = fair market, >1.0 = overpay
  }
```

---

## Bidding and Signing Resolution

### Multi-Team Bidding

```gdscript
func collect_offers(
  teams: Array,
  rosters: Dictionary,
  free_agents: Array,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Array:
  var all_offers = []

  for team in teams:
    var t = team as Dictionary
    var team_id = String(t.get("id"))
    var roster = rosters.get(team_id, {})

    # Build GM context
    var context = GmDecisions.build_context(t, roster, {}, config)

    # Prioritize free agents
    var targets = GmDecisions.prioritize_free_agents(context, free_agents, config)

    # Make offers to each target
    for target in targets:
      var player = target.player
      var valuation = player.get("valuation", {})

      var offer = GmDecisions.make_offer(player, context, valuation, config, rng)

      if not offer.is_empty():
        all_offers.append({
          "player_id": String(player.get("player_id")),
          "team_id": team_id,
          "offer": offer
        })

  return all_offers
```

### Player Decision Model (Phase 1 - Money Only)

```gdscript
func resolve_signings_phase1(
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

  # Each player chooses best offer
  for player in free_agents:
    var player_id = String(player.get("player_id"))
    var player_offers = offers_by_player.get(player_id, [])

    if player_offers.is_empty():
      continue  # Unsigned

    # Phase 1: Simple - pick highest APY
    player_offers.sort_custom(func(a, b):
      return a.get("offer", {}).get("apy", 0.0) > b.get("offer", {}).get("apy", 0.0)
    )

    var best_offer = player_offers[0]

    signings.append({
      "player": player,
      "team_id": String(best_offer.get("team_id")),
      "offer": best_offer.get("offer", {}),
      "num_offers": player_offers.size(),
      "decision_reason": "highest_apy"
    })

  return signings
```

### Player Decision Model (Phase 2 - Preferences)

```gdscript
func resolve_signings_phase2(
  free_agents: Array,
  offers: Array,
  world_state: Dictionary,
  rng: RandomNumberGenerator
) -> Array:
  var signings = []
  var offers_by_player = _group_offers(offers)

  for player in free_agents:
    var player_id = String(player.get("player_id"))
    var player_offers = offers_by_player.get(player_id, [])

    if player_offers.is_empty():
      continue

    # Score each offer based on player preferences
    var scored_offers = []
    for offer_entry in player_offers:
      var score = _score_offer(player, offer_entry, world_state, rng)
      scored_offers.append({
        "offer_entry": offer_entry,
        "score": score
      })

    # Pick highest-scoring offer
    scored_offers.sort_custom(func(a, b): return a.score > b.score)
    var best = scored_offers[0]

    signings.append({
      "player": player,
      "team_id": String(best.offer_entry.get("team_id")),
      "offer": best.offer_entry.get("offer", {}),
      "num_offers": player_offers.size(),
      "decision_score": best.score
    })

  return signings

func _score_offer(
  player: Dictionary,
  offer_entry: Dictionary,
  world_state: Dictionary,
  rng: RandomNumberGenerator
) -> float:
  var offer = offer_entry.get("offer", {})
  var team_id = String(offer_entry.get("team_id"))
  var last_team_id = String(player.get("last_team_id", ""))

  var score = 0.0

  # Money weight (60% of decision)
  var apy = float(offer.get("apy", 0.0))
  var market_value = float(player.get("market_value", 1.0))
  var money_factor = apy / market_value
  score += money_factor * 60.0

  # Winning weight (25% of decision)
  var team_record = _get_team_record(team_id, world_state)
  var winning_pct = float(team_record.get("win_pct", 0.5))
  score += winning_pct * 25.0

  # Loyalty bonus (15% of decision)
  if team_id == last_team_id:
    score += 15.0  # Bonus for re-signing with current team

  # Random noise (±5 points for tiebreaking)
  score += rng.randf_range(-5.0, 5.0)

  return score

func _get_team_record(team_id: String, world_state: Dictionary) -> Dictionary:
  # Phase 2+: Look up team's W/L record from previous season
  var season_records = world_state.get("season_records", {})
  # ... implementation depends on game simulation
  return {"win_pct": 0.5}  # Default: average team
```

---

## Market Dynamics

### Supply and Demand

**Market clearing**: Not all free agents sign (some priced out).

```gdscript
func analyze_market_clearing(
  free_agents: Array,
  signings: Array
) -> Dictionary:
  var by_position = {}

  for fa in free_agents:
    var pos = String(fa.get("position"))
    if not by_position.has(pos):
      by_position[pos] = {"available": 0, "signed": 0}
    by_position[pos]["available"] += 1

  for signing in signings:
    var player = signing.get("player", {})
    var pos = String(player.get("position"))
    by_position[pos]["signed"] += 1

  # Calculate signing rates by position
  var market_data = {}
  for pos in by_position.keys():
    var data = by_position[pos]
    var signing_rate = float(data.signed) / float(data.available)
    market_data[pos] = {
      "available": data.available,
      "signed": data.signed,
      "signing_rate": signing_rate,
      "market_status": "hot" if signing_rate > 0.7 else ("balanced" if signing_rate > 0.4 else "cold")
    }

  return market_data

# Expected output:
# {
#   "QB": {"available": 8, "signed": 7, "signing_rate": 0.875, "market_status": "hot"},
#   "RB": {"available": 24, "signed": 10, "signing_rate": 0.417, "market_status": "balanced"},
#   "K": {"available": 6, "signed": 2, "signing_rate": 0.333, "market_status": "cold"}
# }
```

**Interpretation**:
- **Hot market** (>70% signing rate): High demand, scarce position, most players sign
- **Balanced market** (40-70%): Normal supply/demand, half sign
- **Cold market** (<40%): Oversupply, many unsigned players

### Unsigned Players

**What happens to unsigned free agents**:

```gdscript
func handle_unsigned_players(
  free_agents: Array,
  signings: Array,
  world_state: Dictionary,
  year: int
) -> void:
  var signed_ids = {}
  for signing in signings:
    var player_id = String(signing.get("player", {}).get("player_id"))
    signed_ids[player_id] = true

  var unsigned = []
  for fa in free_agents:
    var player_id = String(fa.get("player_id"))
    if not signed_ids.has(player_id):
      unsigned.append(fa)

  # Option 1: Roll over to next year's FA pool (stay unsigned)
  var next_year_pool = world_state.get("free_agents", {}).get(year + 1, [])
  next_year_pool.append_array(unsigned)
  world_state["free_agents"][year + 1] = next_year_pool

  # Option 2 (Phase 2): Sign to veteran minimum with random team
  # Option 3 (Phase 2): Retire if old + unsigned
```

---

## Statistical Validation Targets

After 20-year simulation:

```gdscript
{
  "free_agency_statistics": {
    "avg_fas_per_year": 120,
    "_comment": "~15% of 800 total NFL players",

    "avg_signings_per_year": 85,
    "_comment": "~70% of FAs sign new contracts",

    "avg_offers_per_player": 2.3,
    "_comment": "Most players have 2-3 suitors",

    "position_signing_rates": {
      "QB": 0.85,    # High demand
      "EDGE": 0.82,
      "CB": 0.78,
      "WR": 0.75,
      "RB": 0.55,    # Oversupply
      "K": 0.40
    },

    "team_player_turnover": 0.18,
    "_comment": "~18% roster turnover per year (realistic)",

    "re_signing_rate": 0.35,
    "_comment": "35% of FAs re-sign with same team (loyalty)"
  }
}
```

---

## Configuration Reference

### valuation.json Additions

```json
{
  "free_agency": {
    "max_offers_per_team": 5,
    "max_cap_commitment_pct": 0.8,
    "min_cap_space_to_bid": 2.0,

    "player_preferences": {
      "money_weight": 0.60,
      "winning_weight": 0.25,
      "loyalty_weight": 0.15,
      "noise_range": 5.0
    },

    "guaranteed_money_base": {
      "QB": 0.70,
      "EDGE": 0.70,
      "CB": 0.60,
      "WR": 0.60,
      "OL": 0.60,
      "DL": 0.50,
      "LB": 0.50,
      "TE": 0.50,
      "RB": 0.40,
      "S": 0.40,
      "K": 0.20,
      "P": 0.20
    }
  }
}
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial free agency design |
