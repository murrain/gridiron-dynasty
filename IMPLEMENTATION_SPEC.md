# Team 4: Offseason & Transactions - Implementation Specifications

**Version**: 1.0
**Date**: 2026-01-12
**Author**: Architecture Guardian
**Status**: APPROVED WITH MODIFICATIONS

---

## Executive Summary

This document provides complete implementation specifications for Team 4's offseason and transactions features. All features are APPROVED except Feature 3 (Franchise Tag) which requires architectural modification to prevent data model pollution.

**Critical Modification**: Franchise tag state MUST be stored in `world_state["franchise_tags"]`, NOT in `Team.gd` model.

---

## Table of Contents

1. [Data Structures](#data-structures)
2. [Feature Specifications](#feature-specifications)
3. [Implementation Sequence](#implementation-sequence)
4. [RNG Determinism Patterns](#rng-determinism-patterns)
5. [World State Schema](#world-state-schema)
6. [API Reference](#api-reference)
7. [Testing Requirements](#testing-requirements)
8. [Integration Points](#integration-points)

---

## Data Structures

### FreeAgentProfile

Represents a player entering free agency.

```gdscript
{
  "player_id": String,           # "player-12345"
  "position": String,            # "QB"
  "age": int,                    # 27
  "overall_rating": float,       # 78.5
  "previous_team_id": String,    # "SF" (null if rookie FA)
  "contract_expired": bool,      # true
  "minimum_demand": float,       # 15.0M (based on market value)
  "position_rank": int,          # 8 (8th best QB in FA class)
  "priority_tier": String        # "elite", "starter", "depth", "camp_body"
}
```

### ContractOffer

Represents a team's offer to a free agent.

```gdscript
{
  "team_id": String,             # "NYJ"
  "player_id": String,           # "player-12345"
  "base_salary": float,          # 18.0M
  "signing_bonus": float,        # 5.0M
  "years_total": int,            # 4
  "guaranteed_value": float,     # 45.0M
  "annual_value": float,         # 23.0M (base + signing_bonus amortized)
  "cap_hit_year_1": float,       # 19.25M
  "offer_quality": float         # 0.85 (% of player demand met)
}
```

### FranchiseTag

Represents a franchise tag applied to a player.

**CRITICAL: Stored in `world_state["franchise_tags"]`, NOT in Team.gd**

```gdscript
{
  "player_id": String,           # "player-12345"
  "team_id": String,             # "SF"
  "tag_type": String,            # "exclusive", "non_exclusive", "transition"
  "salary": float,               # 25.5M (top 5 position average)
  "applied_year": int,           # 2024
  "consecutive_years": int       # 1 (used for penalty calculation)
}
```

### CompensatoryPick

Represents a compensatory draft pick awarded to a team.

```gdscript
{
  "team_id": String,             # "BAL"
  "year": int,                   # 2025
  "round": int,                  # 3
  "overall_pick": int,           # 98
  "reason": String,              # "fa_loss_player-12345"
  "player_lost_id": String,      # "player-12345"
  "player_lost_value": float     # 78.5
}
```

### DraftPickOwnership

Tracks ownership of draft picks (enables pick trading).

**Stored in `world_state["draft_pick_ownership"]`**

```gdscript
{
  year: {
    round: {
      original_team_id: current_owner_team_id
    }
  }
}

# Example:
{
  2025: {
    1: {
      "SF": "CHI",   # Bears own 49ers' 1st rounder
      "CHI": "CHI",  # Bears own their own pick
      "NYJ": "NYJ"
    },
    2: {
      "SF": "SF",
      "CHI": "CHI"
    }
  }
}
```

---

## Feature Specifications

### Feature 1: Free Agency System

**File**: `scripts/world/FreeAgency.gd`

**Purpose**: Simulate NFL free agency period where players with expired contracts sign with new teams.

**Core Functions**:

#### `collect_free_agents(world_state: Dictionary, year: int) -> Array`

Identifies all players with expired contracts eligible for free agency.

**Algorithm**:
1. Iterate through all NFL rosters
2. For each player, check if contract status == "expired" OR years_remaining == 0
3. Calculate player market value using `PlayerValue.calculate_value()`
4. Calculate minimum demand (market_value * config multiplier)
5. Classify into priority tiers (elite, starter, depth, camp_body)
6. Store in `world_state["free_agent_pool"][year]`

**RNG**: None (deterministic filtering)

#### `generate_team_interest(world_state: Dictionary, year: int, rng: RandomNumberGenerator) -> Dictionary`

Generates interest scores for each team/player pair based on needs and cap space.

**Algorithm**:
1. For each team, assess positional needs (call stub or Team 2's TeamNeeds.gd)
2. For each free agent:
   - Calculate position need match (0.0-2.0)
   - Calculate cap affordability (0.0-1.0)
   - Calculate team quality fit (contenders prefer veterans, rebuilders prefer youth)
   - Add random variance (RNG: 1 randf_range() call per team-player pair)
   - Compute final interest score = base_interest * need_match * affordability * variance
3. Return dictionary: `{team_id: {player_id: interest_score}}`

**RNG**: 1 randf_range() per team-player pair (~32 teams * 200 FA = 6400 calls)

#### `player_chooses_team(player_id: String, team_interests: Dictionary, offers: Dictionary, rng: RandomNumberGenerator) -> String`

Simulates player decision-making between competing offers.

**Algorithm**:
1. Filter to teams that made offers
2. Calculate decision score for each offer:
   - Money weight: 60% (offer_value / player_demand)
   - Contender bonus: 20% (team win% last 3 years)
   - Familiarity bonus: 10% (previous team)
   - Random variance: 10% (RNG: 1 randf_range() per offer)
3. Select team with highest decision score
4. Handle ties with RNG tiebreaker

**RNG**: 1 randf_range() per offer + potential tiebreaker

#### `run_free_agency(world_state: Dictionary, year: int, seed: int, configs: Dictionary) -> Dictionary`

Orchestrates complete free agency simulation.

**Algorithm**:
1. Initialize RNG with seed
2. Collect free agents
3. Generate team interest
4. For each FA tier (elite → starter → depth → camp_body):
   - Generate offers from top-interested teams (up to 5 offers per player)
   - Player chooses team (or remains unsigned)
   - If signed:
     - Create contract using ContractNegotiation.generate_offer()
     - Transition contract status (unsigned → signed)
     - Move player to new roster
     - Update team cap space
     - Record transaction in history
5. Store unsigned players in `world_state["free_agent_pool"][year]["unsigned"]`
6. Return signing summary

**Mutation Contract**: MUTATES `world_state["nfl_rosters"]` in-place (like TradeGenerator)

**RNG**: Composite of generate_team_interest + player_chooses_team + offer generation

---

### Feature 2: Contract Negotiations

**File**: `scripts/world/ContractNegotiation.gd`

**Purpose**: Generate realistic contract offers and evaluate player demands.

**Core Functions**:

#### `generate_player_demand(player: Dictionary, positions_cfg: Dictionary, main_cfg: Dictionary) -> Dictionary`

Calculates what a player expects to be paid in free agency.

**Algorithm**:
1. Calculate player market value using `PlayerValue.calculate_value()`
2. Apply age curve modifier:
   - Peak (25-28): 1.0x
   - Young (22-24): 0.9x (upside discount)
   - Declining (29-31): 0.85x
   - Old (32+): 0.7x
3. Apply position market multiplier:
   - QB: 1.5x
   - EDGE, CB: 1.2x
   - RB, S: 0.8x
4. Apply performance tier multiplier:
   - Elite (rating >= 80): 1.3x
   - Starter (70-79): 1.0x
   - Depth (60-69): 0.7x
   - Camp body (<60): 0.4x
5. Return demand structure:
   ```gdscript
   {
     "minimum_annual_value": float,
     "desired_years": int,
     "guaranteed_demand": float
   }
   ```

**RNG**: None (deterministic calculation)

#### `evaluate_offer(offer: Dictionary, demand: Dictionary) -> Dictionary`

Evaluates whether an offer meets player expectations.

**Algorithm**:
1. Calculate offer quality metrics:
   - Annual value ratio = offer.annual_value / demand.minimum_annual_value
   - Guaranteed ratio = offer.guaranteed_value / demand.guaranteed_demand
   - Years match = abs(offer.years_total - demand.desired_years) <= 1
2. Calculate acceptance score:
   - Base score = (annual_value_ratio * 0.7) + (guaranteed_ratio * 0.3)
   - Years penalty = -0.1 if years don't match
   - Final score = base_score + years_penalty
3. Accept if final_score >= 0.85 (85% threshold)
4. Return evaluation:
   ```gdscript
   {
     "accept": bool,
     "score": float,
     "reason": String  # "insufficient_value", "low_guarantees", "accepted"
   }
   ```

**RNG**: None (deterministic evaluation)

#### `generate_offer(team: Dictionary, player: Dictionary, demand: Dictionary, aggression: float) -> Dictionary`

Generates a contract offer from a team to a player.

**Algorithm**:
1. Calculate base offer = demand.minimum_annual_value * aggression
   - Aggression factors:
     - High cap space: 1.1x
     - Desperate need: 1.2x
     - Contender tax: 1.05x
     - Rebuilder discount: 0.9x
2. Calculate contract structure:
   - Base salary = base_offer * 0.7
   - Signing bonus = base_offer * 0.3
   - Years = demand.desired_years (clamped 1-5)
   - Guaranteed = base_offer * years * 0.5 (50% guaranteed typical)
3. Validate cap compliance:
   - Cap hit year 1 = base_salary + (signing_bonus / years)
   - If cap_hit > team.cap_space, reduce offer or abort
4. Return ContractOffer structure

**RNG**: None (deterministic calculation)

---

### Feature 3: Franchise Tag

**Files Modified**: NONE (Team.gd NOT modified)
**World State**: `world_state["franchise_tags"]`

**Purpose**: Allow teams to retain one key free agent at guaranteed salary (top 5 position average).

**Core Functions**:

#### `apply_franchise_tag(world_state: Dictionary, team_id: String, player_id: String, tag_type: String, year: int, config: Dictionary) -> Dictionary`

Applies franchise tag to a player, preventing free agency.

**Algorithm**:
1. Validate team hasn't already tagged a player this year
2. Calculate tag salary:
   - Query all contracts for player's position
   - Sort by annual_value descending
   - Take mean of top 5 contracts
   - Apply tag type multiplier:
     - "exclusive": 1.2x (120% of top 5 avg)
     - "non_exclusive": 1.0x (100%)
     - "transition": 1.0x (100%)
3. Validate team has cap space for tag salary
4. Create tag entry in `world_state["franchise_tags"][year][team_id]`
5. Mark player as ineligible for free agency
6. Create 1-year contract with tag salary
7. Return tag confirmation

**RNG**: None (deterministic calculation)

**World State Structure**:
```gdscript
world_state["franchise_tags"] = {
  2024: {
    "SF": {
      "player_id": "player-12345",
      "tag_type": "exclusive",
      "salary": 25.5,
      "applied_year": 2024,
      "consecutive_years": 1
    }
  }
}
```

**Verification**:
```bash
# Should return NO RESULTS (Team.gd not modified)
grep -n "franchise_tag" scripts/core/models/Team.gd

# Should show tag tracking in world state
grep -n "franchise_tags" scripts/world/FreeAgency.gd
```

---

### Feature 4: Compensatory Picks

**Files Modified**: `scripts/world/NflDraft.gd`

**Purpose**: Award compensatory draft picks to teams that lose more/better free agents than they sign.

**Core Functions**:

#### `track_free_agent_transactions(world_state: Dictionary, year: int) -> void`

Records all FA signings for compensatory pick calculation.

**Algorithm**:
1. Create tracking structure in world_state:
   ```gdscript
   world_state["fa_transaction_tracking"] = {
     year: {
       team_id: {
         "losses": [{"player_id": str, "value": float, "destination_team": str}],
         "gains": [{"player_id": str, "value": float, "origin_team": str}]
       }
     }
   }
   ```
2. Call this at end of free agency period
3. For each signed player:
   - Record as "loss" for previous team
   - Record as "gain" for new team
   - Store player market value

**RNG**: None (deterministic tracking)

#### `calculate_compensatory_picks(world_state: Dictionary, year: int, config: Dictionary) -> Array`

Calculates which teams earn compensatory picks and in which rounds.

**Algorithm**:
1. For each team, calculate net FA loss value:
   - Total losses = sum of all departed player values
   - Total gains = sum of all acquired player values
   - Net loss = losses - gains
2. If net loss > threshold (config: 50.0 value points):
   - Determine comp pick round based on player lost quality:
     - Elite (80+): Round 3
     - Starter (70-79): Round 4
     - Depth (60-69): Round 5
     - Multiple losses: Award up to 4 comp picks per team
3. Sort comp picks by round and team net loss (higher loss = earlier pick)
4. Assign overall pick numbers (after normal picks)
5. Return array of CompensatoryPick structures

**RNG**: None (deterministic calculation)

#### `insert_compensatory_picks(draft_order: Array, comp_picks: Array) -> Array`

Inserts compensatory picks into draft order at appropriate positions.

**Algorithm**:
1. For each round (3-7):
   - Find end of normal picks for that round
   - Insert all comp picks for that round (sorted by priority)
   - Update overall pick numbers for subsequent picks
2. Return modified draft order
3. Store in `world_state["draft_history"][year]` with `compensatory: true` flag

**RNG**: None (deterministic insertion)

**Integration Point**: Called within `NflDraft.run()` before round execution

---

### Feature 5: Draft Pick Trading

**Files Modified**:
- `scripts/world/NflDraft.gd` (ownership tracking)
- `scripts/world/TradeGenerator.gd` (pick trading offers)

**Purpose**: Allow teams to trade draft picks for players or other picks.

**Core Functions**:

#### `initialize_pick_ownership(world_state: Dictionary, teams: Array, year: int, rounds: int) -> void`

Initializes draft pick ownership ledger for a draft year.

**Algorithm**:
1. Create ownership structure:
   ```gdscript
   world_state["draft_pick_ownership"][year] = {
     round: {original_team_id: current_owner_team_id}
   }
   ```
2. For each team and each round:
   - Default: team owns their own pick
   - Example: ownership[year][1]["SF"] = "SF"
3. This runs once at start of season before any trades

**RNG**: None (deterministic initialization)

#### `resolve_draft_order_with_ownership(teams: Array, ownership: Dictionary, year: int, round: int) -> Array`

Resolves draft order respecting pick ownership (trades).

**Algorithm**:
1. Sort teams by draft_order (worst → best)
2. For each team in draft_order:
   - Check ownership[year][round][team.id]
   - If ownership exists and differs from team.id:
     - Assign pick to current owner
     - Mark as traded in pick record
3. Return ordered list of {team_id, pick_owner, original_team, traded: bool}
4. This runs at start of each draft round

**RNG**: None (deterministic lookup)

#### `value_draft_pick(year: int, round: int, pick_in_round: int, config: Dictionary) -> float`

Calculates trade value of a draft pick using Jimmy Johnson chart equivalent.

**Algorithm**:
1. Calculate overall pick number = (round - 1) * 32 + pick_in_round
2. Use value chart (stored in config):
   ```gdscript
   {
     1: 3000,   # 1st overall
     2: 2600,
     ...
     32: 590,   # Last pick of round 1
     33: 580,   # First pick of round 2
     ...
   }
   ```
3. Interpolate for picks not in chart
4. Apply year discount for future picks:
   - Current year: 1.0x
   - Next year: 0.9x
   - 2 years out: 0.8x
5. Return trade value points

**RNG**: None (deterministic lookup)

#### `TradeGenerator._generate_pick_trade_offer()` (Extension)

Extends existing trade generation to include draft picks.

**Algorithm**:
1. Assess if teams are willing to trade picks:
   - Contenders: More likely to trade future picks for players
   - Rebuilders: More likely to trade players for picks
2. If offering team is contender and has surplus at position:
   - Offer: Player + nothing → Future draft pick
3. If offering team is rebuilder and has valuable player:
   - Offer: Player → Draft pick(s)
4. Validate trade value balance:
   - Player value (from PlayerValue.calculate_value())
   - Pick value (from value_draft_pick())
   - Accept if within 15% value tolerance
5. Execute trade:
   - Move player between rosters
   - Update ownership ledger
   - Record trade in history

**RNG**: Uses existing TradeGenerator RNG pattern

---

## Implementation Sequence

### Phase 1: Core Infrastructure (CP1-CP2)

**Priority**: Contract → FA → Franchise Tag

1. **ContractNegotiation.gd** (Feature 2)
   - No dependencies
   - Pure valuation functions
   - Can be tested in isolation

2. **FreeAgency.gd** (Feature 1)
   - Depends on ContractNegotiation
   - Integrates with ContractLifecycle
   - Tests require roster setup

3. **Franchise Tag** (Feature 3)
   - Integrates with FreeAgency
   - CRITICAL: Use world_state, NOT Team.gd
   - Tests verify no Team.gd pollution

### Phase 2: Draft Integration (CP3-CP4)

**Priority**: Pick Trading → Comp Picks

4. **Draft Pick Trading** (Feature 5)
   - Establishes ownership ledger infrastructure
   - NflDraft.gd modifications
   - TradeGenerator.gd extensions

5. **Compensatory Picks** (Feature 4)
   - Uses ownership ledger from Feature 5
   - NflDraft.gd modifications
   - Integrates FA tracking

**Rationale**: Pick ownership must exist before compensatory picks are awarded (comp picks must respect ownership)

---

## RNG Determinism Patterns

### Pattern 1: Free Agency (Feature 1)

```gdscript
# Master seed derivation
var fa_rng := RandomNumberGenerator.new()
fa_rng.seed = Rand.splitmix64(seed ^ 0xFAFA0001)

# Team interest generation (per team-player pair)
var interest_variance := rng.randf_range(0.9, 1.1)  # RNG CALL 1

# Player decision (per offer)
var decision_variance := rng.randf_range(0.0, 0.1)  # RNG CALL 2

# Total: (32 teams * 200 players * 1 call) + (avg 3 offers/player * 200 players * 1 call)
#      = 6400 + 600 = 7000 RNG calls per FA period
```

### Pattern 2: Contract Negotiation (Feature 2)

**No RNG** - purely deterministic calculations based on player attributes and team context.

### Pattern 3: Franchise Tag (Feature 3)

**No RNG** - deterministic tag salary calculation based on position salary averages.

### Pattern 4: Compensatory Picks (Feature 4)

**No RNG** - deterministic allocation based on FA transaction value deltas.

### Pattern 5: Draft Pick Trading (Feature 5)

```gdscript
# Uses existing TradeGenerator RNG pattern
# Inherits RNG consumption from TradeGenerator.generate_trades()
# Additional RNG: Pick selection (if multiple picks available)
var pick_idx := rng.randi() % available_picks.size()  # RNG CALL
```

---

## World State Schema

### New World State Keys

```gdscript
world_state["free_agent_pool"] = {
  year: {
    "all": Array[FreeAgentProfile],
    "signed": Array[{player_id, team_id, contract}],
    "unsigned": Array[player_id]
  }
}

world_state["franchise_tags"] = {
  year: {
    team_id: FranchiseTag
  }
}

world_state["fa_transaction_tracking"] = {
  year: {
    team_id: {
      "losses": Array[{player_id, value, destination}],
      "gains": Array[{player_id, value, origin}]
    }
  }
}

world_state["draft_pick_ownership"] = {
  year: {
    round: {
      original_team_id: current_owner_team_id
    }
  }
}

world_state["contract_negotiation_history"] = {
  year: Array[{
    player_id,
    team_id,
    offer: ContractOffer,
    demand: Dictionary,
    accepted: bool,
    timestamp: int
  }]
}
```

---

## API Reference

### FreeAgency.gd

```gdscript
class_name FreeAgency
extends RefCounted

static func run_free_agency(
  world_state: Dictionary,
  year: int,
  seed: int,
  positions_cfg: Dictionary,
  main_cfg: Dictionary,
  stats_cfg: Dictionary,
  league_cfg: Dictionary
) -> Dictionary:
  # Returns:
  # {
  #   "year": int,
  #   "signings": Array[{player_id, team_id, contract}],
  #   "unsigned": Array[player_id],
  #   "franchise_tags": Array[{team_id, player_id, salary}]
  # }
```

### ContractNegotiation.gd

```gdscript
class_name ContractNegotiation
extends RefCounted

static func generate_player_demand(
  player: Dictionary,
  positions_cfg: Dictionary,
  main_cfg: Dictionary
) -> Dictionary:
  # Returns: {minimum_annual_value, desired_years, guaranteed_demand}

static func generate_offer(
  team: Dictionary,
  player: Dictionary,
  demand: Dictionary,
  aggression: float
) -> Dictionary:
  # Returns: ContractOffer structure

static func evaluate_offer(
  offer: Dictionary,
  demand: Dictionary
) -> Dictionary:
  # Returns: {accept: bool, score: float, reason: String}
```

### NflDraft.gd Extensions

```gdscript
# Added to existing NflDraft class

static func initialize_pick_ownership(
  world_state: Dictionary,
  teams: Array,
  year: int,
  rounds: int
) -> void

static func calculate_compensatory_picks(
  world_state: Dictionary,
  year: int,
  config: Dictionary
) -> Array[CompensatoryPick]

static func resolve_draft_order_with_ownership(
  teams: Array,
  ownership: Dictionary,
  year: int,
  round: int
) -> Array

static func value_draft_pick(
  year: int,
  round: int,
  pick_in_round: int,
  config: Dictionary
) -> float
```

### TradeGenerator.gd Extensions

```gdscript
# Added to existing TradeGenerator class

static func _generate_pick_trade_offer(
  offering_team: Dictionary,
  receiving_team: Dictionary,
  rosters: Dictionary,
  team_needs: Dictionary,
  team_contexts: Dictionary,
  draft_pick_values: Dictionary,
  rng: RandomNumberGenerator
) -> Variant  # Returns trade offer or null
```

---

## Testing Requirements

### Unit Tests

1. **test_contract_negotiation.gd**
   - `test_generate_player_demand_elite_qb()` - Elite QB demands premium
   - `test_generate_player_demand_aging_rb()` - Age discount applies
   - `test_evaluate_offer_accepts_fair_offer()` - 85% threshold
   - `test_evaluate_offer_rejects_low_offer()` - Below threshold
   - `test_generate_offer_respects_cap_space()` - Cap compliance

2. **test_free_agency.gd**
   - `test_collect_free_agents_finds_expired_contracts()` - FA eligibility
   - `test_generate_team_interest_prioritizes_needs()` - Need matching
   - `test_player_chooses_highest_offer()` - Decision logic
   - `test_run_free_agency_signs_players()` - End-to-end signing
   - `test_run_free_agency_updates_rosters()` - Roster mutation
   - `test_franchise_tag_prevents_free_agency()` - Tag exclusion

3. **test_franchise_tag.gd**
   - `test_calculate_tag_salary_top_5_average()` - Salary calculation
   - `test_franchise_tag_stored_in_world_state()` - NOT in Team.gd
   - `test_one_tag_per_team_per_year()` - Tag limit enforcement
   - `test_consecutive_tag_penalty()` - 120% penalty for 2nd year

4. **test_compensatory_picks.gd**
   - `test_calculate_comp_picks_net_loss()` - Loss calculation
   - `test_comp_pick_round_based_on_quality()` - Round assignment
   - `test_insert_comp_picks_after_regular()` - Draft order insertion
   - `test_comp_picks_capped_at_four()` - Max picks per team

5. **test_draft_pick_trading.gd**
   - `test_initialize_pick_ownership_default()` - Ownership init
   - `test_resolve_draft_order_respects_trades()` - Traded pick lookup
   - `test_value_draft_pick_jimmy_johnson()` - Pick valuation
   - `test_trade_pick_updates_ownership()` - Ownership mutation
   - `test_future_pick_discount()` - Year discount factor

### Integration Tests

1. **test_offseason_pipeline.gd**
   - `test_full_offseason_sequence()` - FA → Tag → Draft flow
   - `test_fa_signings_affect_comp_picks()` - Cross-system interaction
   - `test_cap_space_limits_fa_activity()` - Cap enforcement
   - `test_determinism_same_seed()` - RNG reproducibility

### Performance Tests

1. **benchmark_free_agency.gd**
   - Target: <500ms for 200-player FA period
   - Memory: <50MB overhead for FA tracking

---

## Integration Points

### Team 2 Soft Dependency: TeamNeeds.gd

**Interface Contract**:
```gdscript
static func assess_team_needs(
  team_id: String,
  world_state: Dictionary
) -> Array[Dictionary]
  # Returns: [{position: String, priority: String}]
```

**Stub Implementation** (use until Team 2 ready):
```gdscript
static func assess_team_needs_stub(
  team_id: String,
  world_state: Dictionary
) -> Array:
  var roster = world_state.get("nfl_rosters", {}).get(team_id, {})
  var by_position = roster.get("by_position", {})

  var needs = []
  var ideal_depth = {
    "QB": 3, "RB": 4, "WR": 6, "TE": 3,
    "OL": 8, "DL": 6, "EDGE": 4, "LB": 6,
    "CB": 5, "S": 4
  }

  for position in ideal_depth.keys():
    var current = by_position.get(position, []).size()
    var target = ideal_depth[position]
    if current < target * 0.7:  # 70% threshold
      needs.append({
        "position": position,
        "priority": "high" if current < target * 0.5 else "medium"
      })

  return needs
```

### ContractLifecycle Integration

Free agency must use existing contract transition functions:

```gdscript
# When player signs FA contract
var transition = ContractLifecycle.transition_unsigned_to_signed(
  contract,
  "free_agency_signed",
  year
)
player["contract"] = transition["contract"]
team.cap_used += transition["cap_impact"]["annual_value_delta"]
```

### Pipeline Integration

Offseason phase sequence (in WorldCalendar):

1. **Contract Expiration** (tick 200)
   - Mark expired contracts
   - Generate FA eligible list

2. **Franchise Tag Period** (tick 210)
   - Teams apply franchise tags
   - Tagged players excluded from FA

3. **Free Agency** (tick 220-240)
   - Team interest generation
   - Offer generation
   - Player signings

4. **NFL Draft** (tick 250)
   - Initialize pick ownership
   - Calculate compensatory picks
   - Execute draft with traded picks

5. **Post-Draft FA** (tick 260)
   - Sign undrafted free agents
   - Fill remaining roster spots

---

## Configuration Schema

### league.json

```json
{
  "free_agency": {
    "elite_tier_threshold": 80.0,
    "starter_tier_threshold": 70.0,
    "depth_tier_threshold": 60.0,
    "max_offers_per_player": 5,
    "interest_variance": 0.1,
    "acceptance_threshold": 0.85
  },
  "franchise_tag": {
    "enabled": true,
    "exclusive_multiplier": 1.2,
    "consecutive_year_penalty": 1.2,
    "transition_tag_available": true
  },
  "compensatory_picks": {
    "enabled": true,
    "net_loss_threshold": 50.0,
    "elite_comp_round": 3,
    "starter_comp_round": 4,
    "depth_comp_round": 5,
    "max_per_team": 4
  },
  "draft_pick_trading": {
    "enabled": true,
    "future_year_discount": 0.9,
    "value_chart": "jimmy_johnson",
    "value_tolerance": 0.15
  }
}
```

---

## Verification Commands

```bash
# Feature 1: Free Agency System
ls -la scripts/world/FreeAgency.gd
grep -n "run_free_agency" scripts/world/FreeAgency.gd

# Feature 2: Contract Negotiations
ls -la scripts/world/ContractNegotiation.gd
grep -n "generate_player_demand" scripts/world/ContractNegotiation.gd

# Feature 3: Franchise Tag (verify NO Team.gd pollution)
grep -n "franchise_tag" scripts/core/models/Team.gd
# EXPECTED: No results

grep -n "franchise_tags" scripts/world/FreeAgency.gd
# EXPECTED: Multiple results showing world_state usage

# Feature 4: Compensatory Picks
grep -n "compensatory\|comp_pick" scripts/world/NflDraft.gd
grep -n "fa_transaction_tracking" scripts/world/FreeAgency.gd

# Feature 5: Draft Pick Trading
grep -n "pick_ownership\|resolve_draft_order_with_ownership" scripts/world/NflDraft.gd
grep -n "value_draft_pick\|_generate_pick_trade_offer" scripts/world/TradeGenerator.gd
```

---

## Success Criteria

### Checkpoint 4 (Implementation Complete)
- [ ] All 5 features implemented
- [ ] No Team.gd modifications (franchise tag in world_state)
- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] RNG determinism verified

### Checkpoint 5 (Integration & Polish)
- [ ] Team 2 integration (if available)
- [ ] Performance benchmarks met
- [ ] Documentation complete
- [ ] Code review feedback addressed

### Checkpoint 6 (PR Ready)
- [ ] Code quality ≥9.5/10
- [ ] All tests green
- [ ] No architectural violations
- [ ] PR description complete

---

## Notes

**Critical Architecture Decision**: Franchise tag state lives in `world_state["franchise_tags"]`, NOT in `Team.gd`. This prevents model pollution and enables historical queries without iterating team objects.

**Mutation Contract**: FreeAgency and TradeGenerator follow identical patterns - mutate rosters in-place, return history for audit trail.

**RNG Budget**: Free agency is most expensive (7000 calls), but still deterministic and bounded. Consider parallelization if FA period becomes bottleneck.

**Future Evolution Paths**:
- Restricted free agency (RFA)
- Compensatory pick cancellation rules
- June 1st cap designations
- Voidable years in contracts
- Contract restructures
- Trade deadline dynamics

---

**END OF SPECIFICATION**
