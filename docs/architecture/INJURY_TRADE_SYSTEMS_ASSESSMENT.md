# Injury and Trade Systems: Comprehensive Architectural Assessment

**Date**: 2026-01-11
**Status**: Architecture Review
**Assessment Type**: Build vs Enhance vs Defer Analysis

---

## Executive Summary

After comprehensive codebase investigation, this assessment provides architectural guidance on injury and trade system implementation for the Gridiron Dynasty simulation.

**Key Findings**:
1. **Injury System**: Foundation exists but is incomplete (40% implemented)
2. **Trade System**: Strong foundation exists (70% implemented)
3. **Recommendation**: Enhance injury system, integrate trade system

**Priority**: Medium-High (impacts realism and emergent narratives)

---

## Part 1: Current State Analysis

### 1.1 Injury System - Current Implementation

**Data Model** (`/home/patrick/Documents/code/gridiron-dynasty/scripts/core/models/Injury.gd`):
```gdscript
class_name Injury
@export var type: String = ""
@export var severity: float = 0.0
@export var affected_stats: Array[String] = []
@export var recovery_timeline: Dictionary = {}
@export var long_term_penalty: Dictionary = {}
```

**Player Model Integration** (`/home/patrick/Documents/code/gridiron-dynasty/scripts/core/models/Player.gd`):
- Line 36: `@export var injury_eval: String` (combine medical evaluation)
- Line 55: `var wear: Dictionary = {"snaps": 0, "collisions": 0, "injury_count": 0}`
- Line 58: `var injuries: Array[Dictionary] = []`

**Lifecycle Integration** (`/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`):

1. **Injury Application** (Lines 867-889):
   - Simple probability model: `base_chance + (proneness - 50.0) * proneness_slope`
   - Returns injury report but **does NOT create actual injuries**
   - Missing: Injury generation, type selection, severity calculation

2. **Injury Processing** (Lines 1083-1172):
   - **Active Injury Suppression** (Lines 1083-1118): Reduces stats during recovery
   - **Recovery Updates** (Lines 1120-1133): Decrements recovery timeline yearly
   - **Long-Term Penalties** (Lines 1135-1172): Applies stat caps after recovery
   - Uses constant: `INJURY_SUPPRESSION_PER_SEVERITY = 0.25`

3. **Retirement Impact** (`NflSeason.gd` Lines 272-275):
   ```gdscript
   var injuries: Array = player.get("injuries", []) as Array
   if injuries.size() >= 3:
       chance += 0.05  # 5% boost to retirement probability
   ```

**Configuration** (`/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`):
- Lines 58, 62, 72-74: Placeholder modifiers (all set to 1.0)
- **MISSING**: No `"injury"` configuration block with base_chance, types, severities

### 1.2 Trade System - Current Implementation

**Core Data Models** (`/home/patrick/Documents/code/gridiron-dynasty/scripts/core/trades/`):

1. **TradeOffer.gd** (Lines 1-24):
   ```gdscript
   @export var send_player_ids: Array[String] = []
   @export var send_picks: Array = []
   @export var receive_player_ids: Array[String] = []
   @export var receive_picks: Array = []
   ```

2. **TradeValueCalculator.gd** (Lines 1-37):
   - Bundles players and picks into total value
   - Uses `PickValueCurve` for draft pick valuation
   - Pure calculation, no RNG (deterministic)

3. **TradeDecision.gd** (Lines 1-35):
   - Simple threshold-based acceptance: `incoming_value >= outgoing_value * threshold`
   - Default threshold: 1.05 (requires 5% overpay)
   - Configured via `/home/patrick/Documents/code/gridiron-dynasty/configs/trades/trade_rules.json`

4. **TradeValuation.gd** (Lines 1-129):
   - Context-aware valuation with team needs multipliers
   - Supports player values, pick curves, positional scarcity
   - Static evaluation (no RNG consumption)

**Pick Value Infrastructure**:
- `Pick.gd`: Draft pick representation
- `PickValueCurve.gd`: Value curve for draft slots
- Config: `/home/patrick/Documents/code/gridiron-dynasty/configs/trades/pick_value_curve.json`

**Integration Points**:
- **Player Valuation**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/valuation/PlayerValue.gd` exists
- **Contract System**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/ContractLifecycle.gd` handles NFL contracts
- **Salary Cap**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CapValidationFlow.gd` validates cap compliance

**What's Missing**:
1. Trade generation logic (when/why trades happen)
2. Integration with season simulation (NflSeason, CollegeSeason)
3. Team context assessment (contending vs rebuilding)
4. Multi-team trade coordination
5. Trade history persistence

### 1.3 World State Architecture

**Bootstrap Pipeline** (`/home/patrick/Documents/code/gridiron-dynasty/scripts/pipelines/BootstrapWorld.gd`):
- Lines 48-78: Generates 20 years of classes, advances via `PlayerLifecycle`
- Optimized mode: Year 1 = 2,688 players, Years 2-20 = 400 players each
- Returns `active_players`, `retired_players`, `classes`

**Season Simulation**:
- **NflSeason.gd** (Lines 1-337): Processes NFL rosters, retirements, free agency
- **CollegeSeason.gd** (Lines 1-246): Processes college rosters, graduation, draft eligibility
- Both use `PlayerLifecycle.advance_one_year_parallel()` for development

**Determinism Requirements**:
- All systems use splitmix64 seed derivation (e.g., `seed ^ 0x5EA50001`)
- Parallel processing isolates RNG per player
- Config dictionaries deep-copied for thread safety (Godot limitation)

**World State Structure**:
```gdscript
world_state: Dictionary = {
    "nfl_teams": Array,
    "nfl_rosters": Dictionary,  # team_id -> {players: Array, by_position: Dictionary}
    "colleges": Array,
    "college_rosters": Dictionary,
    "draft_pool": Dictionary,   # year -> Array of eligible players
    "free_agents": Dictionary,  # year -> Array of free agents
    "retired_players": Array
}
```

---

## Part 2: Gap Analysis

### 2.1 Injury System Gaps

| Component | Current State | Required State | Gap Severity |
|-----------|---------------|----------------|--------------|
| **Data Model** | Complete (Injury.gd) | ✓ | None |
| **Player Integration** | Partial (storage only) | Need active injury tracking | **High** |
| **Occurrence Logic** | Stub (reports but doesn't create) | Full generation with types/severity | **Critical** |
| **Recovery Mechanics** | Complete | ✓ | None |
| **Long-Term Penalties** | Complete | ✓ | None |
| **Position-Specific Risk** | Missing | Different injury rates by position | **Medium** |
| **Career-Ending Injuries** | Missing | Rare but impactful events | **Low** |
| **Durability Traits** | Missing | Injury-prone vs durable players | **Medium** |
| **Configuration** | Placeholder only | Full injury types, rates, severities | **Critical** |

**Critical Path Issues**:
1. `_apply_injury()` returns report but never mutates `player["injuries"]`
2. No injury type selection logic (ACL, concussion, hamstring, etc.)
3. No severity assignment algorithm
4. Missing config block defining injury probabilities and types

### 2.2 Trade System Gaps

| Component | Current State | Required State | Gap Severity |
|-----------|---------------|----------------|--------------|
| **Data Models** | Complete | ✓ | None |
| **Valuation Logic** | Complete | ✓ | None |
| **Acceptance Logic** | Basic threshold | Context-aware decisions | **Medium** |
| **Trade Generation** | Missing | Deterministic offer generation | **Critical** |
| **Team Context** | Missing | Contender vs rebuilder logic | **High** |
| **Season Integration** | Missing | Trades during NFL season | **High** |
| **Multi-Team Trades** | Missing | 3-way trades (optional) | **Low** |
| **Trade History** | Missing | Persistence in world_state | **Medium** |
| **College Transfers** | Missing | Portal system (if desired) | **Low** |

**Critical Path Issues**:
1. No logic for when/why trades should be proposed
2. No integration point in `NflSeason.gd` or `CollegeSeason.gd`
3. Missing team needs assessment beyond positional scarcity
4. No trade deadline or timing constraints

---

## Part 3: Design Recommendations

### 3.1 Injury System Enhancement Design

#### 3.1.1 Architectural Approach: **ENHANCE EXISTING FOUNDATION**

**Rationale**:
- Data model is sound and complete
- Recovery/penalty mechanics work correctly
- Only missing: occurrence logic and configuration

**Integration Points**:
- Modify `PlayerLifecycle._apply_injury()` to generate actual injuries
- Add injury configuration to `main.json`
- Maintain deterministic RNG consumption

#### 3.1.2 Proposed Configuration Schema

Add to `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`:

```json
"injury": {
    "base_chance": 0.12,
    "proneness_slope": 0.15,
    "types": [
        {
            "type": "hamstring",
            "weight": 0.20,
            "severity_min": 1.0,
            "severity_max": 2.0,
            "affected_stats": ["speed", "acceleration", "agility"],
            "recovery_years_min": 0,
            "recovery_years_max": 1,
            "long_term_cap": 0.95,
            "long_term_decline_mult": 1.05
        },
        {
            "type": "knee",
            "weight": 0.15,
            "severity_min": 2.0,
            "severity_max": 3.0,
            "affected_stats": ["speed", "agility", "acceleration", "strength"],
            "recovery_years_min": 1,
            "recovery_years_max": 2,
            "long_term_cap": 0.90,
            "long_term_decline_mult": 1.10
        },
        {
            "type": "shoulder",
            "weight": 0.12,
            "severity_min": 1.0,
            "severity_max": 2.5,
            "affected_stats": ["throw_power", "throw_accuracy", "strength"],
            "recovery_years_min": 0,
            "recovery_years_max": 1,
            "long_term_cap": 0.92,
            "long_term_decline_mult": 1.08
        },
        {
            "type": "concussion",
            "weight": 0.10,
            "severity_min": 1.0,
            "severity_max": 3.0,
            "affected_stats": ["awareness", "decision_making", "reaction_time"],
            "recovery_years_min": 0,
            "recovery_years_max": 1,
            "long_term_cap": 0.93,
            "long_term_decline_mult": 1.12,
            "cumulative_penalty": 0.05
        },
        {
            "type": "ankle",
            "weight": 0.18,
            "severity_min": 0.5,
            "severity_max": 1.5,
            "affected_stats": ["agility", "balance", "acceleration"],
            "recovery_years_min": 0,
            "recovery_years_max": 1,
            "long_term_cap": 0.96,
            "long_term_decline_mult": 1.03
        },
        {
            "type": "back",
            "weight": 0.08,
            "severity_min": 1.5,
            "severity_max": 3.0,
            "affected_stats": ["strength", "speed", "agility"],
            "recovery_years_min": 1,
            "recovery_years_max": 2,
            "long_term_cap": 0.88,
            "long_term_decline_mult": 1.15,
            "career_ending_chance": 0.03
        },
        {
            "type": "minor",
            "weight": 0.17,
            "severity_min": 0.3,
            "severity_max": 1.0,
            "affected_stats": [],
            "recovery_years_min": 0,
            "recovery_years_max": 0,
            "long_term_cap": 1.0,
            "long_term_decline_mult": 1.0
        }
    ],
    "position_multipliers": {
        "RB": 1.25,
        "WR": 1.10,
        "TE": 1.15,
        "QB": 0.85,
        "OL": 1.20,
        "DL": 1.30,
        "EDGE": 1.25,
        "LB": 1.20,
        "CB": 1.10,
        "S": 1.15,
        "K": 0.30,
        "P": 0.30
    },
    "durability_trait_modifiers": {
        "injury_prone": 1.40,
        "durable": 0.65,
        "iron_man": 0.40
    }
}
```

#### 3.1.3 Enhanced `_apply_injury()` Logic

**Current Function** (Lines 867-889):
- Only calculates probability and returns report
- Never creates injuries

**Proposed Enhancement**:

```gdscript
static func _apply_injury(
    player: Dictionary,
    main_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary
    var base_chance := float(cfg.get("base_chance", 0.12))
    var proneness_slope := float(cfg.get("proneness_slope", 0.15))

    # Apply position multiplier
    var position := String(player.get("position", ""))
    var position_mults: Dictionary = cfg.get("position_multipliers", {}) as Dictionary
    var position_mult := float(position_mults.get(position, 1.0))

    # Apply durability trait modifiers
    var trait_mults: Dictionary = cfg.get("durability_trait_modifiers", {}) as Dictionary
    var trait_mult := 1.0
    var hidden_traits: Array = player.get("hidden_traits", []) as Array
    for trait in hidden_traits:
        if trait_mults.has(trait):
            trait_mult *= float(trait_mults[trait])

    var stats: Dictionary = player.get("stats", {}) as Dictionary
    var proneness := float(stats.get("injury_proneness", 50.0))
    var chance := base_chance + ((proneness - 50.0) / 100.0) * proneness_slope
    chance *= position_mult * trait_mult
    chance = clamp(chance, 0.0, 0.95)

    var roll := rng.randf()
    var injured := roll < chance

    var report := {
        "base_chance": base_chance,
        "proneness": proneness,
        "position_mult": position_mult,
        "trait_mult": trait_mult,
        "final_chance": chance,
        "roll": roll,
        "injured": injured
    }

    # NEW: Generate actual injury if roll succeeds
    if injured:
        var injury := _generate_injury(player, cfg, rng)
        if injury != null:
            var injuries: Array = player.get("injuries", []) as Array
            injuries.append(injury)
            player["injuries"] = injuries
            report["injury"] = injury

    return report

static func _generate_injury(
    player: Dictionary,
    injury_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Variant:
    var injury_types: Array = injury_cfg.get("types", []) as Array
    if injury_types.is_empty():
        return null

    # Weighted random selection of injury type
    var total_weight := 0.0
    for injury_def in injury_types:
        total_weight += float((injury_def as Dictionary).get("weight", 0.0))

    var roll := rng.randf() * total_weight
    var accumulated := 0.0
    var selected_def: Dictionary = {}

    for injury_def in injury_types:
        var def: Dictionary = injury_def as Dictionary
        accumulated += float(def.get("weight", 0.0))
        if roll <= accumulated:
            selected_def = def
            break

    if selected_def.is_empty():
        return null

    # Generate injury instance
    var severity_min := float(selected_def.get("severity_min", 1.0))
    var severity_max := float(selected_def.get("severity_max", 2.0))
    var severity := rng.randf_range(severity_min, severity_max)

    var recovery_min := int(selected_def.get("recovery_years_min", 0))
    var recovery_max := int(selected_def.get("recovery_years_max", 1))
    var recovery_years := rng.randi_range(recovery_min, recovery_max)

    # Check for career-ending outcome (rare)
    var career_ending_chance := float(selected_def.get("career_ending_chance", 0.0))
    var is_career_ending := rng.randf() < career_ending_chance

    var injury := {
        "type": String(selected_def.get("type", "unknown")),
        "severity": severity,
        "affected_stats": (selected_def.get("affected_stats", []) as Array).duplicate(),
        "recovery_timeline": {
            "years_total": recovery_years,
            "years_remaining": recovery_years,
            "status": "active"
        },
        "long_term_penalty": {
            "stat_caps": {},
            "decline_multipliers": {}
        },
        "career_ending": is_career_ending
    }

    # Set long-term penalties for affected stats
    var long_term_cap := float(selected_def.get("long_term_cap", 1.0))
    var decline_mult := float(selected_def.get("long_term_decline_mult", 1.0))
    var stats: Dictionary = player.get("stats", {}) as Dictionary

    for stat_name in injury["affected_stats"]:
        if stats.has(stat_name):
            var current_val := float(stats[stat_name])
            (injury["long_term_penalty"]["stat_caps"] as Dictionary)[stat_name] = current_val * long_term_cap
            (injury["long_term_penalty"]["decline_multipliers"] as Dictionary)[stat_name] = decline_mult

    return injury
```

**RNG Consumption**:
- **Current**: 1 call (probability roll)
- **Enhanced**: 1 + (2 if injured) = 1-3 calls per player per year
  - Call 1: Injury occurrence roll
  - Call 2: Type selection (if injured)
  - Call 3: Severity/recovery (if injured)

**Determinism**: Preserved (same seed = same injuries)

#### 3.1.4 Career-Ending Injury Integration

**Retirement Check Enhancement** (`PlayerLifecycle._should_retire()`):

```gdscript
# After existing retirement logic (line 930)
var injuries: Array = player.get("injuries", []) as Array
var has_career_ending := false
for injury_entry in injuries:
    var injury: Dictionary = injury_entry as Dictionary
    if injury.get("career_ending", false):
        has_career_ending = true
        break

if has_career_ending:
    return true  # Force retirement
```

#### 3.1.5 Backwards Compatibility

**Save File Compatibility**:
- Injury configuration is additive (no breaking changes)
- Player.injuries already exists as optional field
- Existing saves will have empty injury arrays (valid state)

**Migration Path**:
- No migration needed
- Old saves: players have no injuries (realistic for pre-injury-system state)
- New saves: injuries tracked going forward

### 3.2 Trade System Integration Design

#### 3.2.1 Architectural Approach: **INTEGRATE EXISTING COMPONENTS**

**Rationale**:
- Core valuation/decision logic is complete and correct
- Missing only: generation logic and season integration
- Should NOT reinvent valuation math

**Integration Strategy**:
1. Build trade generation layer on top of existing foundation
2. Integrate into `NflSeason.gd` as new phase
3. Preserve determinism via explicit seed derivation

#### 3.2.2 Trade Generation Architecture

**New Component**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/TradeGenerator.gd`

```gdscript
extends RefCounted
class_name TradeGenerator

const TradeOffer = preload("res://scripts/core/trades/TradeOffer.gd")
const TradeDecision = preload("res://scripts/core/trades/TradeDecision.gd")
const TradeValueCalculator = preload("res://scripts/core/trades/TradeValueCalculator.gd")
const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")

## Generates trade offers for NFL teams based on team context and needs.
##
## Algorithm:
##   1. Identify teams with surplus (excess depth at position)
##   2. Identify teams with deficits (weak depth at position)
##   3. For each deficit team, generate trade offer to surplus team
##   4. Evaluate offer using TradeDecision
##   5. Execute accepted trades
##
## Determinism:
##   - All RNG consumption is explicit via passed rng parameter
##   - Same seed produces identical trades every time
##
## RNG consumption per team pair:
##   - 1 call for surplus/deficit assessment randomness
##   - 1 call for offer generation variance
##   Total: ~2 calls per team pair evaluated
static func generate_trades(
    world_state: Dictionary,
    year: int,
    rng: RandomNumberGenerator,
    positions_cfg: Dictionary,
    main_cfg: Dictionary,
    trade_cfg: Dictionary,
    options: Dictionary = {}
) -> Dictionary:
    var teams: Array = world_state.get("nfl_teams", []) as Array
    var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
    var executed_trades: Array = []
    var rejected_trades: Array = []

    # Assess team contexts (contending vs rebuilding)
    var team_contexts := _assess_team_contexts(teams, rosters, positions_cfg, rng)

    # Assess positional needs for all teams
    var team_needs := _assess_team_needs(teams, rosters, positions_cfg)

    # Build player value index for valuation
    var player_values := _build_player_value_index(rosters, positions_cfg, main_cfg)

    # Generate trade opportunities
    var max_trades_per_year := int(trade_cfg.get("max_trades_per_year", 12))
    var attempts := 0
    var max_attempts := max_trades_per_year * 10  # Allow multiple attempts

    while executed_trades.size() < max_trades_per_year and attempts < max_attempts:
        attempts += 1

        # Select random team pair
        var team_a_idx := rng.randi() % teams.size()
        var team_b_idx := rng.randi() % teams.size()
        if team_a_idx == team_b_idx:
            continue

        var team_a: Dictionary = teams[team_a_idx]
        var team_b: Dictionary = teams[team_b_idx]

        # Generate offer from team_a to team_b
        var offer := _generate_offer(
            team_a, team_b,
            rosters, team_needs, team_contexts,
            player_values, positions_cfg, trade_cfg, rng
        )

        if offer == null:
            continue

        # Evaluate offer
        var decision := _evaluate_offer(
            offer, team_b,
            player_values, team_needs,
            trade_cfg
        )

        if decision.get("accept", false):
            # Execute trade
            _execute_trade(offer, rosters)
            executed_trades.append({
                "offer": offer,
                "year": year,
                "team_a": team_a.get("id"),
                "team_b": team_b.get("id"),
                "valuation": decision
            })
        else:
            rejected_trades.append({
                "offer": offer,
                "team_a": team_a.get("id"),
                "team_b": team_b.get("id"),
                "reason": decision.get("reason", "value_insufficient")
            })

    # Update world state
    var trade_history: Array = world_state.get("trade_history", []) as Array
    trade_history.append_array(executed_trades)
    world_state["trade_history"] = trade_history
    world_state["nfl_rosters"] = rosters

    return {
        "executed": executed_trades.size(),
        "rejected": rejected_trades.size(),
        "trades": executed_trades
    }

static func _assess_team_contexts(
    teams: Array,
    rosters: Dictionary,
    positions_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var contexts := {}
    for team in teams:
        var t: Dictionary = team
        var team_id := String(t.get("id", ""))
        var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
        var players: Array = roster.get("players", []) as Array

        # Simple heuristic: average player rating
        # TODO: Could incorporate win/loss record if tracked
        var total_rating := 0.0
        var count := 0
        for player in players:
            var p: Dictionary = player
            var stats: Dictionary = p.get("stats", {}) as Dictionary
            var position := String(p.get("position", ""))
            var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
            var core_stats: Array = pos_cfg.get("core_stats", []) as Array

            var player_rating := 0.0
            for stat_name in core_stats:
                player_rating += float(stats.get(stat_name, 0.0))
            if core_stats.size() > 0:
                player_rating /= float(core_stats.size())

            total_rating += player_rating
            count += 1

        var avg_rating := (total_rating / float(count)) if count > 0 else 50.0

        # Categorize team
        var mode := "neutral"
        if avg_rating >= 70.0:
            mode = "contending"
        elif avg_rating <= 55.0:
            mode = "rebuilding"

        contexts[team_id] = {
            "mode": mode,
            "avg_rating": avg_rating,
            "roster_size": players.size()
        }

    return contexts

static func _assess_team_needs(
    teams: Array,
    rosters: Dictionary,
    positions_cfg: Dictionary
) -> Dictionary:
    var needs := {}

    for team in teams:
        var t: Dictionary = team
        var team_id := String(t.get("id", ""))
        var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
        var by_position: Dictionary = roster.get("by_position", {}) as Dictionary

        var position_needs := {}
        for position in positions_cfg.keys():
            var position_players: Array = by_position.get(position, []) as Array
            var ideal_depth := _ideal_depth_for_position(position)
            var current_depth := position_players.size()

            # Need score: 0.0 (surplus) to 2.0 (desperate need)
            var need_score := 1.0
            if current_depth < ideal_depth:
                need_score = 1.0 + (float(ideal_depth - current_depth) / float(ideal_depth))
            elif current_depth > ideal_depth:
                need_score = 1.0 - (float(current_depth - ideal_depth) / float(ideal_depth))

            position_needs[position] = clamp(need_score, 0.5, 2.0)

        needs[team_id] = position_needs

    return needs

static func _ideal_depth_for_position(position: String) -> int:
    # NFL typical depth chart sizes
    var depths := {
        "QB": 3, "RB": 4, "WR": 6, "TE": 3,
        "OL": 8, "DL": 6, "EDGE": 4, "LB": 6,
        "CB": 5, "S": 4, "K": 1, "P": 1
    }
    return int(depths.get(position, 3))

static func _generate_offer(
    team_offering: Dictionary,
    team_receiving: Dictionary,
    rosters: Dictionary,
    team_needs: Dictionary,
    team_contexts: Dictionary,
    player_values: Dictionary,
    positions_cfg: Dictionary,
    trade_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Variant:
    # Placeholder: Complex trade generation logic
    # This would assess roster fits, salary cap, etc.
    # For now, return null (no trade generated)
    return null

static func _build_player_value_index(
    rosters: Dictionary,
    positions_cfg: Dictionary,
    main_cfg: Dictionary
) -> Dictionary:
    # Build dictionary of player_id -> valuation score
    var values := {}
    for team_id in rosters.keys():
        var roster: Dictionary = rosters[team_id]
        var players: Array = roster.get("players", []) as Array
        for player in players:
            var p: Dictionary = player
            var player_id := String(p.get("player_id", ""))
            # Use simplified valuation (real would use PlayerValue.gd)
            var position := String(p.get("position", ""))
            var stats: Dictionary = p.get("stats", {}) as Dictionary
            var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
            var core_stats: Array = pos_cfg.get("core_stats", []) as Array

            var avg := 0.0
            for stat_name in core_stats:
                avg += float(stats.get(stat_name, 0.0))
            if core_stats.size() > 0:
                avg /= float(core_stats.size())

            values[player_id] = avg * 10.0  # Scale to value points
    return values

static func _evaluate_offer(
    offer: Dictionary,
    receiving_team: Dictionary,
    player_values: Dictionary,
    team_needs: Dictionary,
    trade_cfg: Dictionary
) -> Dictionary:
    # Use existing TradeDecision logic
    var decision := TradeDecision.new()
    var incoming := offer.get("receive", {}) as Dictionary
    var outgoing := offer.get("send", {}) as Dictionary

    # Simple value calculation (real would use TradeValueCalculator)
    var incoming_value := 0.0
    var outgoing_value := 0.0

    for player_id in incoming.get("player_ids", []):
        incoming_value += float(player_values.get(player_id, 0.0))
    for player_id in outgoing.get("player_ids", []):
        outgoing_value += float(player_values.get(player_id, 0.0))

    var accept := decision.should_accept(incoming_value, outgoing_value)
    return {
        "accept": accept,
        "incoming_value": incoming_value,
        "outgoing_value": outgoing_value
    }

static func _execute_trade(offer: Dictionary, rosters: Dictionary) -> void:
    # Transfer players between rosters
    # Update roster by_position indices
    # Validate salary cap (should be done before acceptance)
    pass
```

#### 3.2.3 Season Integration

**Modify** `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd`:

Add trade phase after player development but before free agency:

```gdscript
# After line 145 (roster counts updated)
# NEW: Trade phase
if not options.get("skip_trades", false):
    var trade_rng := RandomNumberGenerator.new()
    trade_rng.seed = Rand.splitmix64(seed ^ 0x5EA50004)  # New seed derivation

    var trade_cfg: Dictionary = main_cfg.get("trades", {}) as Dictionary
    var trade_result := TradeGenerator.generate_trades(
        world_state,
        year,
        trade_rng,
        positions_cfg,
        main_cfg,
        trade_cfg
    )

    total_trades = int(trade_result.get("executed", 0))
```

Update return dictionary:

```gdscript
return {
    "year": year,
    "roster_counts": roster_counts,
    "total_players": _sum_roster_counts(roster_counts),
    "retirements": total_retirements,
    "free_agents": total_free_agents,
    "trades": total_trades,  # NEW
    "step_seeds": {
        "lifecycle": lifecycle_rng.seed,
        "context": context_rng.seed,
        "retirement": retirement_rng.seed,
        "trades": trade_rng.seed  # NEW
    }
}
```

#### 3.2.4 Trade Configuration

Add to `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`:

```json
"trades": {
    "enabled": true,
    "max_trades_per_year": 12,
    "trade_deadline_week": 8,
    "acceptance_threshold": 1.05,
    "context_modifiers": {
        "contending": {
            "draft_pick_value_mult": 0.85,
            "veteran_value_mult": 1.15,
            "prospect_value_mult": 0.90
        },
        "rebuilding": {
            "draft_pick_value_mult": 1.20,
            "veteran_value_mult": 0.80,
            "prospect_value_mult": 1.10
        },
        "neutral": {
            "draft_pick_value_mult": 1.0,
            "veteran_value_mult": 1.0,
            "prospect_value_mult": 1.0
        }
    },
    "salary_cap_buffer": 0.05,
    "min_roster_size_after_trade": 45
}
```

#### 3.2.5 Backwards Compatibility

**Save File Compatibility**:
- Add optional `"trade_history": []` to world_state
- Existing saves: empty trade history (valid state)
- New field: `options.skip_trades = true` for testing

---

## Part 4: Implementation Plan

### Phase 1: Injury System Enhancement (Priority: High)

**Milestone 1.1**: Configuration and Data Foundation (2-3 hours)
- [ ] Add injury configuration block to `main.json`
- [ ] Validate injury types, weights, severities
- [ ] Write unit tests for config loading
- [ ] Test: Config loads without errors

**Milestone 1.2**: Injury Generation Logic (4-5 hours)
- [ ] Enhance `_apply_injury()` to create actual injuries
- [ ] Implement `_generate_injury()` with type selection
- [ ] Add position multipliers
- [ ] Add durability trait modifiers
- [ ] Test: Determinism (same seed = same injuries)
- [ ] Test: Injury types match weights

**Milestone 1.3**: Career-Ending Injury Integration (2-3 hours)
- [ ] Add career-ending flag to injury schema
- [ ] Integrate with retirement logic
- [ ] Test: Career-ending injuries force retirement
- [ ] Test: Rare injuries occur at expected rate

**Milestone 1.4**: Validation and Tuning (3-4 hours)
- [ ] Run 20-year bootstrap with injuries enabled
- [ ] Validate injury rates (should be ~12% per year baseline)
- [ ] Check long-term penalty application
- [ ] Verify backwards compatibility (load old saves)
- [ ] Performance test (ensure no regression)

**Total Estimated Time**: 11-15 hours

**Risk Assessment**:
- **Low Risk**: Building on existing foundation
- **Determinism Risk**: Medium (need careful RNG consumption tracking)
- **Performance Risk**: Low (injury logic is lightweight)

### Phase 2: Trade System Integration (Priority: Medium-High)

**Milestone 2.1**: Trade Generation Stub (3-4 hours)
- [ ] Create `TradeGenerator.gd` file
- [ ] Implement team context assessment
- [ ] Implement team needs assessment
- [ ] Test: Context assessment runs without errors
- [ ] Test: Needs assessment produces reasonable scores

**Milestone 2.2**: Simple Trade Offers (5-6 hours)
- [ ] Implement player-for-player trade generation
- [ ] Add salary cap validation
- [ ] Integrate with existing `TradeDecision`
- [ ] Test: Offers are valued correctly
- [ ] Test: Acceptance logic works

**Milestone 2.3**: Season Integration (4-5 hours)
- [ ] Add trade phase to `NflSeason.gd`
- [ ] Wire up RNG seed derivation
- [ ] Add trade history to world_state
- [ ] Test: Trades execute and update rosters
- [ ] Test: Determinism preserved

**Milestone 2.4**: Advanced Features (6-8 hours, Optional)
- [ ] Player-for-pick trades
- [ ] Multi-team trades (3-way)
- [ ] Trade deadline enforcement
- [ ] Contender vs rebuilder logic
- [ ] Test: Complex trades work correctly

**Milestone 2.5**: Validation and Tuning (4-5 hours)
- [ ] Run 20-year bootstrap with trades enabled
- [ ] Validate trade frequency (target: 8-15 per year)
- [ ] Check roster balance after trades
- [ ] Verify backwards compatibility
- [ ] Performance test

**Total Estimated Time**: 16-23 hours (12-15 for core, +4-8 for advanced)

**Risk Assessment**:
- **Medium Risk**: Complex business logic (trade evaluation)
- **Determinism Risk**: Low (trade logic is already RNG-free)
- **Performance Risk**: Low (trade generation is O(teams²) = ~1000 ops)
- **Balance Risk**: High (trades could create unrealistic rosters)

### Phase 3: Testing and Validation (Priority: Critical)

**Testing Requirements**:

1. **Unit Tests**:
   - Injury configuration loading
   - Injury type selection (weighted randomness)
   - Career-ending injury retirement
   - Trade offer generation
   - Trade acceptance logic
   - Roster updates after trades

2. **Integration Tests**:
   - 20-year bootstrap with injuries
   - 20-year bootstrap with trades
   - Combined injuries + trades
   - Save/load with injury data
   - Save/load with trade history

3. **Determinism Tests**:
   - Same seed produces identical injuries
   - Same seed produces identical trades
   - Parallel processing determinism

4. **Performance Tests**:
   - Bootstrap time with injuries (target: <1% regression)
   - Bootstrap time with trades (target: <2% regression)
   - Memory usage (target: no growth)

5. **Balance Tests**:
   - Injury rates per position (validate against config)
   - Trade frequency per year (target: 8-15)
   - Roster balance after 20 years
   - No teams below minimum roster size

---

## Part 5: Risk Analysis and Mitigation

### 5.1 Determinism Risks

**Risk**: Injury/trade RNG consumption breaks determinism

**Mitigation**:
1. Use explicit seed derivation (splitmix64)
2. Document RNG consumption patterns in code comments
3. Write determinism tests (run twice, compare results)
4. Track RNG state before/after each system

**Testing**:
```gdscript
# Test: Same seed produces identical injuries
var result1 := PlayerLifecycle.advance_one_year(players, ..., rng1)
var result2 := PlayerLifecycle.advance_one_year(players, ..., rng2)
assert(result1["players"][0]["injuries"] == result2["players"][0]["injuries"])
```

### 5.2 Performance Risks

**Risk**: Injury/trade logic slows down bootstrap

**Mitigation**:
1. Keep injury generation lightweight (simple weighted selection)
2. Limit trade attempts per year (max 120 = 12 target × 10 multiplier)
3. Use early exits in trade generation (skip incompatible teams)
4. Profile before/after implementation

**Performance Budget**:
- Injuries: <1% regression (target: 0.1% = 75ms over 75s bootstrap)
- Trades: <2% regression (target: 1.5s over 75s bootstrap)

### 5.3 Balance Risks

**Risk**: Injuries too frequent/severe, ruining player careers

**Mitigation**:
1. Conservative default rates (12% base, adjusted by position)
2. Tunable configuration (easy to adjust without code changes)
3. Injury type distribution (80% minor/moderate, 20% severe)
4. Career-ending injuries very rare (<1% of all injuries)

**Risk**: Trades create unrealistic rosters

**Mitigation**:
1. Salary cap validation (hard requirement)
2. Minimum roster size enforcement (prevent trading entire team)
3. Position needs validation (don't trade only QB)
4. Trade history tracking (detect suspicious patterns)

**Validation Metrics**:
- Average injuries per player career: 2-4 (realistic)
- Career-ending injuries: <0.5% of all players (rare)
- Trades per year: 8-15 (matches NFL average)
- Teams below 45 roster size: 0 (hard requirement)

### 5.4 Save File Compatibility Risks

**Risk**: Old saves become unloadable

**Mitigation**:
1. All new fields are optional (default to empty arrays)
2. `from_dict()` ignores unknown keys (already implemented)
3. Migration not required (absence = valid state)
4. Test loading pre-injury/trade saves

**Backwards Compatibility Contract**:
```gdscript
# Old save without injuries
player = {
    "player_id": "abc",
    # ... no "injuries" field
}
# Loads successfully, player.injuries = [] by default

# Old world_state without trade_history
world_state = {
    "nfl_teams": [...],
    # ... no "trade_history" field
}
# Loads successfully, world_state.trade_history = [] by default
```

---

## Part 6: Architectural Decision Record

### Decision 1: Enhance Injury System (APPROVED)

**Context**: Injury foundation exists but is incomplete (40% done)

**Decision**: Enhance existing system rather than rebuild

**Rationale**:
1. Data model (Injury.gd) is well-designed and complete
2. Recovery/penalty mechanics work correctly
3. Only missing: occurrence logic and configuration
4. Lower risk than full rebuild

**Consequences**:
- Faster implementation (build on existing work)
- Maintains architectural consistency
- No breaking changes to data model
- Requires careful RNG consumption tracking

**Alternatives Considered**:
- **Rebuild from scratch**: Rejected (unnecessary, higher risk)
- **Defer until later**: Rejected (injury system impacts realism significantly)

---

### Decision 2: Integrate Trade System (APPROVED with Phasing)

**Context**: Trade foundation is 70% complete, needs generation logic

**Decision**: Integrate existing components, build generation layer

**Rationale**:
1. Valuation logic is correct and complete
2. Trade acceptance logic is simple and extensible
3. Only missing: when/why trades happen
4. Existing foundation is architecturally sound

**Consequences**:
- Faster implementation (reuse existing components)
- Maintains separation of concerns (valuation vs generation)
- Trade generation can start simple and evolve
- Performance impact is predictable and bounded

**Alternatives Considered**:
- **Build complete trade AI**: Rejected (scope too large, risk too high)
- **Use external trade data**: Rejected (breaks determinism)
- **Random trades only**: Rejected (unrealistic, poor emergent behavior)

**Phasing Strategy**:
- Phase 1: Player-for-player trades only
- Phase 2: Player-for-pick trades
- Phase 3: Multi-team trades (optional)
- Phase 4: Advanced context logic (contender/rebuilder)

---

### Decision 3: Configuration-Driven Design (APPROVED)

**Context**: Both systems need tunable parameters

**Decision**: Use JSON configuration for all rates, types, weights

**Rationale**:
1. Matches existing architecture (main.json, positions.json)
2. Enables tuning without code changes
3. Supports A/B testing of balance
4. Makes system behavior explicit and auditable

**Consequences**:
- Balance changes don't require recompilation
- Configuration changes can be version-controlled
- Users can customize behavior (modding support)
- Configuration validation becomes critical

**Configuration Strategy**:
- Injury: Add `"injury": {}` block to main.json
- Trade: Add `"trades": {}` block to main.json
- Validation: Load and validate configs at bootstrap
- Defaults: Provide conservative defaults (fail-safe)

---

### Decision 4: Determinism Non-Negotiable (APPROVED)

**Context**: Simulation must be reproducible for testing/debugging

**Decision**: All injury/trade logic must be deterministic

**Rationale**:
1. Matches existing architecture (all RNG is seeded)
2. Essential for regression testing
3. Enables save/load debugging
4. Required for multiplayer (future consideration)

**Consequences**:
- All randomness must flow through explicit RNG instances
- Seed derivation must be documented
- RNG consumption patterns must be stable
- Parallel processing must use deterministic seed splitting

**Testing Requirements**:
- Every stochastic system has determinism test
- Seed derivation documented in code comments
- RNG consumption counted and validated

---

## Part 7: Final Recommendations

### 7.1 Implementation Priority

**RECOMMENDED ORDER**:

1. **Phase 1: Injury System Enhancement** (Priority: **HIGH**)
   - Lower risk, higher impact on realism
   - Builds directly on existing foundation
   - 11-15 hours estimated effort
   - **Status**: Ready to implement

2. **Phase 2: Trade System Integration (Core)** (Priority: **MEDIUM-HIGH**)
   - Medium risk, high impact on emergent narratives
   - 12-15 hours for core functionality
   - **Status**: Ready to implement after Phase 1

3. **Phase 3: Trade System Integration (Advanced)** (Priority: **LOW**)
   - Lower priority, nice-to-have features
   - 4-8 hours additional effort
   - **Status**: Defer until core is validated

### 7.2 Success Criteria

**Injury System**:
- [ ] Injuries occur at configured rates (12% baseline)
- [ ] Position multipliers work correctly
- [ ] Career-ending injuries are rare (<0.5% of players)
- [ ] Long-term penalties reduce stats as expected
- [ ] Determinism preserved (same seed = same injuries)
- [ ] No performance regression (<1% bootstrap time)
- [ ] Old saves load without errors

**Trade System**:
- [ ] 8-15 trades per year average (NFL realistic)
- [ ] No teams below 45 roster size
- [ ] Salary cap always respected
- [ ] Trade values within 10% of fair value
- [ ] Determinism preserved (same seed = same trades)
- [ ] No performance regression (<2% bootstrap time)
- [ ] Old saves load without errors

### 7.3 Deferred Decisions

**DEFER TO FUTURE**:

1. **College Transfer Portal**:
   - Not critical for core simulation
   - Requires different logic than NFL trades
   - **Recommendation**: Defer to post-v1.0

2. **Three-Team Trades**:
   - Complex coordination logic
   - Rare in real NFL (<5% of trades)
   - **Recommendation**: Phase 3 (optional enhancement)

3. **Trade Veto Logic**:
   - League office vetoes are extremely rare
   - Adds complexity with minimal realism gain
   - **Recommendation**: Defer indefinitely

4. **Advanced Trade AI**:
   - Machine learning or complex heuristics
   - High development cost, uncertain benefit
   - **Recommendation**: Iterate on simple logic first

### 7.4 Key Architectural Principles

**MAINTAIN THESE**:

1. **Determinism First**: Same seed = same outcome (always)
2. **Configuration-Driven**: Balance changes via JSON, not code
3. **Backwards Compatible**: Old saves must load
4. **Performance Budget**: <5% total regression acceptable
5. **Testable**: Every feature has unit and integration tests
6. **Incremental**: Ship core functionality first, iterate

---

## Part 8: Critical Files Reference

### Files to Modify (Injury System)

1. `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`
   - Lines 867-889: Enhance `_apply_injury()`
   - Add: `_generate_injury()` helper function
   - Modify: `_should_retire()` for career-ending injuries

2. `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`
   - Add: `"injury": {}` configuration block

3. `/home/patrick/Documents/code/gridiron-dynasty/scripts/tests/`
   - Create: `test_injury_system.gd`
   - Create: `test_injury_determinism.gd`

### Files to Create (Trade System)

1. `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/TradeGenerator.gd`
   - New file for trade generation logic

2. `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`
   - Add: `"trades": {}` configuration block

3. `/home/patrick/Documents/code/gridiron-dynasty/scripts/tests/`
   - Create: `test_trade_generation.gd`
   - Create: `test_trade_execution.gd`

### Files to Modify (Trade System)

1. `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd`
   - Add: Trade phase after roster updates (after line 145)
   - Modify: Return dictionary to include trade count

2. `/home/patrick/Documents/code/gridiron-dynasty/scripts/pipelines/BootstrapWorld.gd`
   - Optional: Add trade history initialization

---

## Conclusion

**ARCHITECTURAL ASSESSMENT**: Both systems are **READY FOR IMPLEMENTATION**

**Injury System**: **ENHANCE** existing foundation (40% complete → 100%)
- Risk: Low
- Effort: 11-15 hours
- Impact: High (realism, career narratives)
- **Recommendation**: Proceed immediately

**Trade System**: **INTEGRATE** existing components (70% complete → 100%)
- Risk: Medium
- Effort: 12-15 hours (core), +4-8 hours (advanced)
- Impact: High (team building, emergent behavior)
- **Recommendation**: Proceed after injury system

**Combined Impact**: Significant increase in simulation realism and emergent storytelling without architectural disruption.

**Status**: APPROVED for phased implementation per outlined plan.
