# Trade System Implementation Plan

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: TRADE_SYSTEM_ARCHITECTURE.md

---

## Implementation Overview

This document breaks down the trade system into phased, implementable tasks with clear dependencies and acceptance criteria.

---

## Phase 1: MVP (Player Trades Only)

**Goal**: Implement basic 1-for-1 player trades with realistic constraints.

**Scope**: Player trades only (no draft picks), 4 trade windows, CPU-only trades, deterministic execution.

**Estimated Complexity**: High (10-15 implementation units)

### Task 1.1: Trade Data Models

**File**: `scripts/core/models/Trade.gd`

**Create Core Classes**:
```gdscript
class_name TradeProposal extends Resource

@export var proposal_id: String
@export var year: int
@export var week: int
@export var phase: String

@export var team_a_id: String
@export var team_b_id: String

# Assets (Phase 1: players only)
@export var team_a_gives_players: Array[String] = []
@export var team_b_gives_players: Array[String] = []

# Valuation
@export var team_a_value: float
@export var team_b_value: float
@export var value_differential: float
@export var value_pct_diff: float

# Context
@export var team_a_motivation: String
@export var team_b_motivation: String
@export var team_a_urgency: float
@export var team_b_urgency: float

# Status
@export var status: String  # "proposed", "accepted", "rejected"
@export var rejection_reason: String

# Cap
@export var team_a_cap_impact: float
@export var team_b_cap_impact: float

# Metadata
@export var rng_seed: int

func from_dict(d: Dictionary) -> void:
  # Load from dictionary

func to_dict() -> Dictionary:
  # Serialize to dictionary
```

```gdscript
class_name CompletedTrade extends Resource

@export var trade_id: String
@export var year: int
@export var week: int
@export var phase: String

@export var team_a_id: String
@export var team_a_name: String
@export var team_b_id: String
@export var team_b_name: String

# What was traded (with names for display)
@export var team_a_gave: Array[Dictionary] = []  # [{id, name, position, value}]
@export var team_b_gave: Array[Dictionary] = []

# Final valuation
@export var team_a_value_received: float
@export var team_b_value_received: float
@export var value_differential: float
@export var winner: String  # "team_a", "team_b", "balanced"

# Context
@export var primary_motivation: String
@export var headline: String

# Cap
@export var team_a_cap_change: float
@export var team_b_cap_change: float

func from_dict(d: Dictionary) -> void:
  # Load from dictionary

func to_dict() -> Dictionary:
  # Serialize to dictionary
```

**Acceptance Criteria**:
- [ ] `TradeProposal` class with all Phase 1 fields
- [ ] `CompletedTrade` class with serialization
- [ ] Unit tests for from_dict/to_dict conversions
- [ ] No RNG usage (pure data models)

---

### Task 1.2: Team Trade Profile Builder

**File**: `scripts/world/TradeProfileBuilder.gd`

**Purpose**: Calculate team's trading context (needs, surplus, temperature, status).

**Key Functions**:
```gdscript
class_name TradeProfileBuilder extends RefCounted

static func build_profile(
  team: Dictionary,
  roster: Dictionary,
  season_record: Dictionary,
  week: int,
  config: Dictionary
) -> Dictionary:
  # Returns TeamTradeProfile dictionary
  pass

static func classify_team_status(wins: int, losses: int, avg_rating: float) -> String:
  # "contender", "playoff_bubble", "rebuilder", "mediocre"
  pass

static func identify_positional_needs(roster: Dictionary, config: Dictionary) -> Dictionary:
  # Returns {position: {severity: float, reason: String}}
  pass

static func identify_positional_surplus(roster: Dictionary, config: Dictionary) -> Dictionary:
  # Returns {position: {count: int, tradeable: [player_ids]}}
  pass

static func calculate_trade_temperature(
  needs: Dictionary,
  surplus: Dictionary,
  team_status: String,
  must_shed_salary: bool,
  week: int,
  config: Dictionary
) -> float:
  # Returns 0.0-1.0 temperature score
  pass

static func identify_untouchables(
  roster: Dictionary,
  team_status: String,
  config: Dictionary
) -> Array[String]:
  # Returns array of player IDs that cannot be traded
  pass
```

**Dependencies**:
- `PlayerValue.gd` (already exists)
- `Team.gd` (already exists)
- Config: `league.json` trade section

**Acceptance Criteria**:
- [ ] `build_profile()` returns complete TeamTradeProfile
- [ ] `classify_team_status()` correctly categorizes teams (test with known records)
- [ ] `identify_positional_needs()` detects depth <2 as critical need
- [ ] `calculate_trade_temperature()` produces 0.0-1.0 score
- [ ] `identify_untouchables()` protects franchise QBs (age <30, rating >80)
- [ ] Unit tests with fixture data (90%+ coverage)
- [ ] Deterministic (same inputs = same outputs, no RNG)

---

### Task 1.3: Trade Valuation Engine

**File**: `scripts/core/valuation/TradeValuation.gd`

**Purpose**: Calculate trade value using PlayerValue, apply premiums/penalties.

**Key Functions**:
```gdscript
class_name TradeValuation extends RefCounted

static func calculate_player_trade_value(
  player_id: String,
  from_team_roster: Array,
  to_team_roster: Array,
  from_team_profile: Dictionary,
  to_team_profile: Dictionary,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  # Returns {
  #   player_id: String,
  #   market_value: float,
  #   from_team_value: float,
  #   to_team_value: float,
  #   trade_value: float,  # What from_team asks for
  #   team_premium: float,
  #   receiving_premium: float
  # }
  pass

static func is_trade_fair(
  value_a_gives: float,
  value_a_receives: float,
  value_b_gives: float,
  value_b_receives: float,
  team_a_profile: Dictionary,
  team_b_profile: Dictionary,
  config: Dictionary
) -> Dictionary:
  # Returns {fair: bool, pct_diff: float, tolerance: float, reason: String}
  pass

static func apply_division_rival_penalty(
  base_value_required: float,
  team_a: Dictionary,
  team_b: Dictionary,
  config: Dictionary
) -> Dictionary:
  # Returns {penalty_applied: bool, adjusted_value: float, multiplier: float}
  pass

static func apply_contract_adjustments(
  base_value: float,
  player: Dictionary,
  config: Dictionary
) -> Dictionary:
  # Returns {base_value, adjusted_value, contract_multiplier}
  pass
```

**Dependencies**:
- `PlayerValue.gd` (already exists)
- Task 1.2 (TeamTradeProfile)

**Acceptance Criteria**:
- [ ] `calculate_player_trade_value()` integrates PlayerValue correctly
- [ ] Team premium increases asking price (up to 25%)
- [ ] Receiving team values based on needs (up to 30% bonus)
- [ ] `is_trade_fair()` respects tolerance bounds (default 30%)
- [ ] `apply_division_rival_penalty()` applies 1.5x multiplier for same division
- [ ] Contract adjustments reduce value for expiring contracts (15% discount)
- [ ] Unit tests with known valuations (95%+ coverage)
- [ ] Deterministic except for PlayerValue RNG usage (controlled seed)

---

### Task 1.4: Trade Partner Matching

**File**: `scripts/world/TradeMatchmaker.gd`

**Purpose**: Find compatible trade partners based on complementary needs.

**Key Functions**:
```gdscript
class_name TradeMatchmaker extends RefCounted

static func find_trade_partners(
  initiating_team_profile: Dictionary,
  all_team_profiles: Array,
  config: Dictionary
) -> Array:
  # Returns array of {team_id, profile, compatibility_score}
  # Sorted by compatibility (highest first)
  pass

static func find_trade_candidates(
  team_profile: Dictionary,
  target_position: String,
  roster: Dictionary,
  config: Dictionary
) -> Array:
  # Returns array of {player_id, player, position, trade_value, age, contract_years}
  # Players that team CAN trade at position
  pass

static func can_trade_player_positionally(
  player_id: String,
  roster: Dictionary,
  config: Dictionary
) -> Dictionary:
  # Returns {can_trade: bool, reason: String}
  pass

static func find_best_value_match(
  player_a: Dictionary,  # Candidate from team A
  player_b_candidates: Array,  # All candidates from team B
  config: Dictionary
) -> Dictionary:
  # Returns best matching player from team B (closest value)
  # Or null if no good match
  pass
```

**Dependencies**:
- Task 1.2 (TradeProfileBuilder)
- Task 1.3 (TradeValuation)

**Acceptance Criteria**:
- [ ] `find_trade_partners()` returns complementary matches only
- [ ] Compatibility score weights need severity (0.0-1.0)
- [ ] Partners sorted by compatibility (highest first)
- [ ] `find_trade_candidates()` respects positional minimums
- [ ] `can_trade_player_positionally()` prevents trading only QB
- [ ] `find_best_value_match()` finds player within 20% value
- [ ] Unit tests with fixture rosters (90%+ coverage)
- [ ] Performance: O(N) partner matching, O(M) candidate search

---

### Task 1.5: Trade Proposal Builder

**File**: `scripts/world/TradeProposalBuilder.gd`

**Purpose**: Construct and validate trade proposals.

**Key Functions**:
```gdscript
class_name TradeProposalBuilder extends RefCounted

static func build_proposal(
  team_a_id: String,
  team_b_id: String,
  team_a_gives_players: Array[String],
  team_b_gives_players: Array[String],
  team_a_profile: Dictionary,
  team_b_profile: Dictionary,
  world_state: Dictionary,
  year: int,
  week: int,
  phase: String,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> TradeProposal:
  # Build complete proposal with valuations
  pass

static func validate_proposal(
  proposal: TradeProposal,
  team_a_profile: Dictionary,
  team_b_profile: Dictionary,
  world_state: Dictionary,
  config: Dictionary
) -> Dictionary:
  # Returns {valid: bool, reason: String, message: String}
  # Checks: value fairness, cap space, positional constraints, untouchables
  pass

static func calculate_cap_impact(
  player_ids: Array[String],
  from_roster: Dictionary,
  to_roster: Dictionary
) -> float:
  # Calculate change in cap used for trading team
  pass
```

**Dependencies**:
- Task 1.1 (Trade models)
- Task 1.3 (TradeValuation)
- Task 1.4 (TradeMatchmaker)

**Acceptance Criteria**:
- [ ] `build_proposal()` creates complete TradeProposal object
- [ ] All valuations calculated using TradeValuation
- [ ] Proposal IDs unique and deterministic (hash of teams + players)
- [ ] `validate_proposal()` checks all constraints
- [ ] Cap impact correctly calculated (sum of annual_value changes)
- [ ] Validation rejects untouchable players
- [ ] Validation rejects insufficient cap space
- [ ] Unit tests with valid and invalid proposals (95%+ coverage)

---

### Task 1.6: Trade Execution Engine

**File**: `scripts/world/TradeExecutor.gd`

**Purpose**: Execute accepted trades, update rosters and world state.

**Key Functions**:
```gdscript
class_name TradeExecutor extends RefCounted

static func execute_trade(
  proposal: TradeProposal,
  world_state: Dictionary,
  year: int,
  config: Dictionary
) -> Dictionary:
  # Apply roster changes, update world state
  # Returns {success: bool, completed_trade: CompletedTrade}
  pass

static func move_player_to_team(
  player_id: String,
  from_team_id: String,
  to_team_id: String,
  world_state: Dictionary
) -> void:
  # Remove from source roster, add to destination roster
  # Update player's team affiliation
  pass

static func convert_proposal_to_completed_trade(
  proposal: TradeProposal,
  world_state: Dictionary
) -> CompletedTrade:
  # Create CompletedTrade record for history
  pass

static func generate_trade_headline(
  completed_trade: CompletedTrade,
  world_state: Dictionary
) -> String:
  # Create headline: "Team A trades Player X to Team B for Player Y"
  pass
```

**Dependencies**:
- Task 1.1 (Trade models)
- Task 1.5 (TradeProposalBuilder)

**Acceptance Criteria**:
- [ ] `execute_trade()` moves players between rosters correctly
- [ ] Player's `current_team_id` updated
- [ ] Player's `traded_from` and `trade_year` set
- [ ] Roster `by_position` dictionaries rebuilt
- [ ] CompletedTrade stored in `world_state["trade_history"][year]`
- [ ] Trade history persists across saves/loads
- [ ] `generate_trade_headline()` produces readable summary
- [ ] Integration tests with full world state (90%+ coverage)
- [ ] No data loss (all players accounted for)

---

### Task 1.7: Trade Window Processing

**File**: `scripts/world/TradeWindowProcessor.gd`

**Purpose**: Orchestrate trade window logic (detect motivations, match partners, negotiate).

**Key Functions**:
```gdscript
class_name TradeWindowProcessor extends RefCounted

static func process_trade_window(
  world_state: Dictionary,
  year: int,
  week: int,
  phase: String,
  seed: int,
  config: Dictionary
) -> Array:
  # Returns array of CompletedTrade
  # Processes entire trade window (multiple attempts)
  pass

static func attempt_trade_with_partner(
  initiator_profile: Dictionary,
  partner_profile: Dictionary,
  world_state: Dictionary,
  year: int,
  week: int,
  phase: String,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  # Returns {completed: bool, trade: CompletedTrade, reason: String}
  # Single trade negotiation attempt
  pass

static func select_most_urgent_need(profile: Dictionary) -> String:
  # Pick highest severity need from profile.positional_needs
  pass
```

**Dependencies**:
- All previous tasks (1.2-1.6)

**Acceptance Criteria**:
- [ ] `process_trade_window()` attempts correct number of trades (based on frequency)
- [ ] Only warm teams (temp >= 0.4) initiate trades
- [ ] Teams can't trade twice in same window
- [ ] Partner matching works (complementary needs)
- [ ] Trade proposals validated before acceptance
- [ ] Failed trade attempts logged (rejection reason)
- [ ] Completed trades executed via TradeExecutor
- [ ] Integration tests with full 20-year bootstrap
- [ ] Deterministic (same seed = same trades)
- [ ] Performance: <1 second per trade window

---

### Task 1.8: NflSeason Integration

**File**: `scripts/world/NflSeason.gd` (modify existing)

**Purpose**: Add trade windows to NFL season pipeline.

**Changes**:
```gdscript
# Add trade window calls at appropriate times
func run(world_state: Dictionary, year: int, seed: int, ...) -> Dictionary:
  # ... existing roster loading ...

  # NEW: Trade Window 1 - Pre-Draft
  var pre_draft_seed := Rand.splitmix64(seed ^ 0xTRADE01)
  var pre_draft_trades := TradeWindowProcessor.process_trade_window(
    world_state, year, 0, "pre_draft", pre_draft_seed, league_cfg
  )

  # ... draft processing ...

  # NEW: Trade Window 2 - Preseason
  var preseason_seed := Rand.splitmix64(seed ^ 0xTRADE02)
  var preseason_trades := TradeWindowProcessor.process_trade_window(
    world_state, year, 0, "preseason", preseason_seed, league_cfg
  )

  # ... season simulation (if enabled) ...

  # NEW: Trade Window 3 - Mid-Season (week 6)
  var midseason_seed := Rand.splitmix64(seed ^ 0xTRADE03)
  var midseason_trades := TradeWindowProcessor.process_trade_window(
    world_state, year, 6, "midseason", midseason_seed, league_cfg
  )

  # NEW: Trade Window 4 - Trade Deadline (week 10)
  var deadline_seed := Rand.splitmix64(seed ^ 0xTRADE04)
  var deadline_trades := TradeWindowProcessor.process_trade_window(
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

**Dependencies**:
- Task 1.7 (TradeWindowProcessor)

**Acceptance Criteria**:
- [ ] Four trade windows called in correct order
- [ ] Each window uses unique seed derivation
- [ ] Trade counts returned in phase output
- [ ] World state updated with trade history
- [ ] No regression in existing NflSeason behavior
- [ ] Integration test: 20-year bootstrap with trades enabled
- [ ] Performance: <5% overhead compared to no-trade baseline

---

### Task 1.9: Configuration Setup

**File**: `configs/sports/american_football/world/league.json` (modify existing)

**Add Trade Configuration**:
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
    },

    "contract_adjustments": {
      "rental_discount": 0.15,
      "free_agent_discount": 0.30,
      "bad_contract_penalty_rate": 0.1,
      "good_contract_bonus_rate": 0.05
    },

    "untouchables": {
      "franchise_qb_rating_threshold": 80.0,
      "franchise_qb_age_threshold": 30,
      "elite_young_potential_threshold": 85.0,
      "elite_young_age_threshold": 25,
      "recent_first_rounder_years": 2
    }
  }
}
```

**Acceptance Criteria**:
- [ ] Config loads without errors
- [ ] All sections have sensible defaults
- [ ] Config version incremented (2 → 3)
- [ ] Feature flag `enabled` allows disabling trades
- [ ] Backward compatible (missing config = trades disabled)

---

### Task 1.10: Testing Suite

**Files**: `scripts/tests/test_trade_*.gd`

**Test Coverage**:

#### Unit Tests
- [ ] `test_trade_profile_builder.gd`: All TradeProfileBuilder functions
- [ ] `test_trade_valuation.gd`: All TradeValuation functions
- [ ] `test_trade_matchmaker.gd`: Partner matching, candidate selection
- [ ] `test_trade_proposal_builder.gd`: Proposal construction, validation
- [ ] `test_trade_executor.gd`: Trade execution, roster updates

#### Integration Tests
- [ ] `test_trade_window_processing.gd`: Full trade window flow
- [ ] `test_nfl_season_trades.gd`: NflSeason with trades enabled

#### Behavioral Tests
- [ ] `test_trade_realism.gd`:
  - Trade frequency: 10-20 per year
  - Division rival trades <10%
  - Franchise QBs never traded
  - Contenders keep young core
  - Value fairness within tolerance

#### Performance Tests
- [ ] `test_trade_performance.gd`:
  - Trade window processing <1 second
  - 20-year bootstrap with trades <5% overhead

**Acceptance Criteria**:
- [ ] >90% code coverage for trade modules
- [ ] All realism tests pass
- [ ] Performance benchmarks met
- [ ] Determinism validation (10 runs with same seed = identical trades)

---

## Phase 2: Draft Pick Trading (Future)

**Scope**: Add draft pick trades, player+pick combinations, pick swaps.

**Deferred**: Not part of Phase 1 MVP.

**Key Tasks**:
- Draft pick value chart
- Pick + player trade logic
- Future pick tracking (up to 2 years)
- Trade down scenarios

---

## Phase 3: Advanced Features (Future)

**Scope**: Multi-team trades, conditional picks, no-trade clauses.

**Deferred**: Not part of Phase 1 MVP.

---

## Phase 4: Human Player Integration (Future)

**Scope**: Allow human player to propose trades to CPU teams.

**Deferred**: Not part of Phase 1 MVP.

---

## Implementation Order

**Recommended sequence**:

1. **Week 1**: Tasks 1.1-1.3 (Data models, profiles, valuation)
2. **Week 2**: Tasks 1.4-1.5 (Matching, proposal building)
3. **Week 3**: Tasks 1.6-1.7 (Execution, window processing)
4. **Week 4**: Tasks 1.8-1.9 (Integration, config)
5. **Week 5**: Task 1.10 (Testing, validation)

**Total Estimate**: 5-6 weeks for Phase 1 MVP.

---

## Risk Mitigation

### Risk 1: Determinism Violations
**Mitigation**: Strict RNG seed derivation, sequential processing within windows.
**Validation**: Run bootstrap 10 times with same seed, verify identical trades.

### Risk 2: Performance Regression
**Mitigation**: Cache team profiles, optimize partner matching, batch processing.
**Validation**: Benchmark each trade window, set <1s threshold.

### Risk 3: Unrealistic Trade Patterns
**Mitigation**: Comprehensive behavioral tests, tunable config parameters.
**Validation**: 20-year bootstrap, analyze trade frequency, division trades, untouchables.

### Risk 4: Integration Complexity
**Mitigation**: Modular design, clear interfaces, extensive unit testing.
**Validation**: Integration tests before modifying NflSeason.

---

## Success Metrics

**Phase 1 considered successful if**:
- [ ] 20-year bootstrap produces 200-400 total trades (10-20/year)
- [ ] Division rival trades <10% of total
- [ ] Franchise QBs (age <30, rating >80) never traded
- [ ] 95%+ of trades within configured value tolerance
- [ ] Trade window processing <1 second per window
- [ ] Total bootstrap overhead <5%
- [ ] Zero determinism failures (10 runs with same seed)
- [ ] All unit tests pass (>90% coverage)
- [ ] All behavioral tests pass

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial implementation plan |
