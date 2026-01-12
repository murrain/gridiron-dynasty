# Feature Expansion Plan

**Created**: 2026-01-12
**Branch**: `claude/plan-feature-expansion-EcKdj`
**Status**: Planning Complete - Ready for Team Assignment

---

## Executive Summary

Three Architect agents analyzed the Gridiron Dynasty codebase and identified:
- **47 expansion opportunities** for existing features
- **15 high-priority missing realism features**
- **12 strategic future feature categories**

This document organizes these findings into **5 parallel work streams** with minimized blocking dependencies.

---

## Team Assignments

### Team 1: Data Model Foundation
**Priority**: CRITICAL (Partially Blocking)
**Scope**: Small-Medium
**Blocking Status**: Other teams can stub these models. Deliver core structures within first 2 days.

| Feature | Complexity | Primary Files | Description |
|---------|------------|---------------|-------------|
| Coach Attributes Expansion | Very Low | `Coach.gd` | Add coaching_ability, recruiting_skill, player_development, experience_years, scheme_preference, personality_traits |
| Player Career Awards | Very Low | `Player.gd` | Add `career_awards: Dictionary` tracking OPOY, DPOY, All-Pro, Pro Bowl, championships |
| Player Jersey Numbers | Very Low | `Player.gd` | Add `jersey_number: int` with position-based assignment logic |
| DepthChart Class | Low | New `DepthChart.gd` | Position-ordered player arrays with get_starter(), get_depth(), set_depth() methods |
| Team History Expansion | Low | `Team.gd` / world_state | Track wins, losses, championships, division_titles, conference_titles, best/worst seasons |

**Interfaces to Define**:
```gdscript
# DepthChart.gd
class_name DepthChart
var position_depths: Dictionary = {}  # {"QB": ["player_id_1", "player_id_2"], ...}

func get_starter(position: String) -> String
func get_depth(position: String) -> Array[String]
func set_depth(position: String, player_ids: Array[String])
func get_backup(position: String, depth_index: int) -> String

# Player.gd additions
@export var jersey_number: int = 0
@export var career_awards: Dictionary = {
    "opoy": 0, "dpoy": 0, "all_pro_first": 0, "all_pro_second": 0,
    "pro_bowl": 0, "rookie_of_year": 0, "championships": 0
}

# Coach.gd additions
@export var coaching_ability: float = 50.0
@export var recruiting_skill: float = 50.0
@export var player_development: float = 50.0
@export var experience_years: int = 0
@export var specialty_position: String = ""
@export var scheme_preference: String = ""
```

---

### Team 2: Roster & Depth Management
**Priority**: HIGH
**Scope**: Medium
**Depends On**: DepthChart class from Team 1 (can stub initially)

| Feature | Complexity | Primary Files | Description |
|---------|------------|---------------|-------------|
| DepthChart Integration | Low-Medium | `StatGenerator.gd`, `Roster.gd` | Use depth charts for starter selection and playing time distribution |
| Practice Squad System | Medium | `Roster.gd` | Active/PS roster categories with promotion/demotion rules |
| Injured Reserve Management | Medium | `Roster.gd`, `Injury.gd` | Auto-IR placement for severe injuries, activation windows |
| Team Needs Assessment | Low | New `TeamNeeds.gd` | Analyze position depth, age distribution, contract windows, performance gaps |
| Roster Validation | Low | `CapValidationFlow.gd` | Enforce roster limits from league.json config |

**Interfaces to Define**:
```gdscript
# TeamNeeds.gd
class_name TeamNeeds

static func assess_team_needs(team_id: String, world_state: Dictionary) -> Array[Dictionary]:
    # Returns [{position: "QB", priority: "critical", reason: "No backup"}, ...]
    pass

static func get_priority_positions(team_id: String, world_state: Dictionary, top_n: int = 5) -> Array[String]:
    pass

# Roster.gd additions
enum RosterStatus { ACTIVE, PRACTICE_SQUAD, INJURED_RESERVE, SUSPENDED }

func move_to_practice_squad(player_id: String) -> bool
func promote_from_practice_squad(player_id: String) -> bool
func place_on_ir(player_id: String) -> bool
func activate_from_ir(player_id: String) -> bool
func get_roster_by_status(status: RosterStatus) -> Array[String]
```

---

### Team 3: Game & Season Simulation
**Priority**: CRITICAL
**Scope**: Medium
**Depends On**: None (FULLY INDEPENDENT)

| Feature | Complexity | Primary Files | Description |
|---------|------------|---------------|-------------|
| Playoff Bracket Simulation | Low | `CollegeSeason.gd`, `NflSeason.gd` | 4-team CFP, NFL playoff brackets using GameSimulator |
| Weather Effects | Low-Medium | `GameSimulator.gd` | Rain/snow/wind affecting passing accuracy, kicking, fumbles |
| Rivalry Game System | Low | `GameSimulator.gd`, config | Define rivalries, apply intensity modifiers to games |
| Special Teams Impact | Medium | `GameSimulator.gd`, `StatGenerator.gd` | K/P positions meaningfully affect outcomes |
| Situational Game States | Medium | `GameSimulator.gd` | Track clutch moments, comebacks, 4th quarter leads |

**Implementation Notes**:
```gdscript
# Playoff simulation reuses existing GameSimulator
func simulate_playoff_bracket(teams: Array, world_state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    # teams = [seed1, seed2, seed3, seed4] for CFP
    var semi1 = GameSimulator.determine_winner(teams[0], teams[3], ...)
    var semi2 = GameSimulator.determine_winner(teams[1], teams[2], ...)
    var final = GameSimulator.determine_winner(semi1.winner, semi2.winner, ...)
    return {"champion": final.winner, "games": [semi1, semi2, final]}

# Weather config (new)
var weather_types = {
    "clear": {"pass_modifier": 0, "kick_modifier": 0},
    "rain": {"pass_modifier": -0.05, "kick_modifier": -0.08, "fumble_modifier": 0.02},
    "snow": {"pass_modifier": -0.08, "kick_modifier": -0.12, "fumble_modifier": 0.03},
    "wind": {"pass_modifier": -0.03, "kick_modifier": -0.15}
}

# Rivalry config (new JSON or world_state)
"rivalries": [
    {"teams": ["team_001", "team_005"], "name": "The Classic", "intensity": 0.9},
    ...
]
```

---

### Team 4: Offseason & Transactions
**Priority**: CRITICAL
**Scope**: Large
**Depends On**: Can stub TeamNeeds from Team 2

| Feature | Complexity | Primary Files | Description |
|---------|------------|---------------|-------------|
| Free Agency System | Low-Medium | New `FreeAgency.gd` | FA market, bidding, team targeting based on needs |
| Basic Contract Negotiations | Medium | New `ContractNegotiation.gd` | Player demands vs team offers, acceptance logic |
| Franchise Tag | Medium | `Team.gd`, FA system | Exclusive/non-exclusive tags, position salary tracking |
| Compensatory Picks | Medium | `NflDraft.gd`, FA system | Track net FA value, assign comp picks (rounds 3-7) |
| Draft Pick Trading | Medium | `NflDraft.gd`, `TradeGenerator.gd` | Include picks in trade valuations, track pick ownership |

**Implementation Notes**:
```gdscript
# FreeAgency.gd
class_name FreeAgency

static func collect_free_agents(world_state: Dictionary) -> Array[String]:
    # Players with expired contracts
    pass

static func generate_team_interest(player_id: String, world_state: Dictionary) -> Array[Dictionary]:
    # Returns [{team_id, offer: {years, aav, guaranteed}}, ...]
    # Uses TeamNeeds and cap space
    pass

static func player_chooses_team(player_id: String, offers: Array, world_state: Dictionary) -> String:
    # Weighs money, winning chance, playing time, location
    pass

static func run_free_agency(world_state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    # Main orchestration - called during offseason phase
    pass

# ContractNegotiation.gd
static func generate_player_demand(player: Dictionary, market_value: float) -> Dictionary:
    return {
        "annual_value": market_value * player.get("greed_factor", 1.0),
        "years": _preferred_years_by_age(player.age),
        "guaranteed_pct": 0.5 + randf() * 0.2
    }

static func evaluate_offer(demand: Dictionary, offer: Dictionary) -> bool:
    var value_gap = (offer.annual_value - demand.annual_value) / demand.annual_value
    return value_gap >= -0.15  # Accept within 15% of ask
```

---

### Team 5: Historical & Legacy Systems
**Priority**: HIGH
**Scope**: Medium
**Depends On**: Career awards dict from Team 1 (can build infrastructure first)

| Feature | Complexity | Primary Files | Description |
|---------|------------|---------------|-------------|
| Career Awards to Players | Very Low | `AwardSelector.gd`, `NflSeason.gd` | Write award counts to player.career_awards after selection |
| League Records Tracking | Low | New `RecordBook.gd` | Single-season and career records (pass yards, TDs, etc.) |
| Team Franchise Records | Low-Medium | New `FranchiseRecords.gd` | Per-team all-time records |
| Hall of Fame System | Medium | New `HallOfFame.gd` | Eligibility (5yr retired), scoring algorithm, induction |
| Dynasty Era Detection | Low-Medium | New `DynastyDetector.gd` | Identify sustained success (3+ titles in 5 years) |

**Implementation Notes**:
```gdscript
# RecordBook.gd
class_name RecordBook

var single_season: Dictionary = {
    "pass_yards": {"value": 0, "player_id": "", "year": 0, "player_name": ""},
    "pass_tds": {"value": 0, "player_id": "", "year": 0, "player_name": ""},
    "rush_yards": {"value": 0, "player_id": "", "year": 0, "player_name": ""},
    # ... all stat categories
}

var career: Dictionary = {
    "pass_yards": {"value": 0, "player_id": "", "player_name": ""},
    # ...
}

func check_record(category: String, value: float, player_id: String, year: int, is_career: bool) -> bool:
    # Returns true if record broken
    pass

# HallOfFame.gd
class_name HallOfFame

static func calculate_hof_score(player: Dictionary, career_stats: Dictionary) -> float:
    var score = 0.0
    score += player.career_awards.get("opoy", 0) * 20
    score += player.career_awards.get("dpoy", 0) * 20
    score += player.career_awards.get("all_pro_first", 0) * 15
    score += player.career_awards.get("all_pro_second", 0) * 8
    score += player.career_awards.get("pro_bowl", 0) * 5
    score += player.career_awards.get("championships", 0) * 25

    # Career stat bonuses (position-specific thresholds)
    if career_stats.get("pass_yards", 0) > 50000: score += 20
    if career_stats.get("pass_tds", 0) > 400: score += 15
    # ...

    return score

static func is_hof_eligible(player: Dictionary, years_since_retirement: int) -> bool:
    return years_since_retirement >= 5

static func select_inductees(eligible_players: Array, max_inductees: int = 5) -> Array:
    # Sort by score, take top N above threshold
    pass
```

---

## Dependency Graph

```
                    ┌──────────────────────────────────────────────────────────────┐
                    │                    PARALLEL EXECUTION                        │
                    ├──────────────────────────────────────────────────────────────┤
                    │                                                              │
   Day 1-2          │  ┌─────────────┐                                             │
   ───────────────► │  │   TEAM 1    │ ◄─── Delivers: DepthChart, Coach attrs,    │
                    │  │ Data Models │      career_awards dict, jersey numbers     │
                    │  └──────┬──────┘                                             │
                    │         │                                                    │
                    │         ├────────────────┬───────────────────┐               │
                    │         ▼                ▼                   ▼               │
   Day 2-7          │  ┌─────────────┐  ┌─────────────┐     ┌─────────────┐        │
   ───────────────► │  │   TEAM 2    │  │   TEAM 4    │     │   TEAM 5    │        │
                    │  │   Roster    │  │  Offseason  │     │   Legacy    │        │
                    │  └──────┬──────┘  └─────────────┘     └─────────────┘        │
                    │         │                                                    │
                    │         │ TeamNeeds                                          │
                    │         ▼                                                    │
                    │  ┌─────────────┐                                             │
                    │  │   TEAM 4    │ ◄─── Uses TeamNeeds for FA targeting        │
                    │  │  (cont'd)   │                                             │
                    │  └─────────────┘                                             │
                    │                                                              │
   Day 1-7          │  ┌─────────────┐                                             │
   ───────────────► │  │   TEAM 3    │ ◄─── FULLY INDEPENDENT                      │
   (parallel)       │  │  Game Sim   │      No dependencies on other teams         │
                    │  └─────────────┘                                             │
                    │                                                              │
                    └──────────────────────────────────────────────────────────────┘
```

---

## Execution Phases

### Phase A: Kickoff (Days 1-2)
All teams start simultaneously. Team 1 prioritizes blocking deliverables.

| Team | Focus | Deliverable |
|------|-------|-------------|
| Team 1 | Coach attributes, DepthChart class, career_awards | Unblock Teams 2, 4, 5 |
| Team 2 | TeamNeeds logic (stub DepthChart), PS/IR infrastructure | Core logic ready |
| Team 3 | Playoff simulation, weather effects | 2 features complete |
| Team 4 | Free Agency core structure (stub TeamNeeds) | FA framework ready |
| Team 5 | RecordBook class, HOF scoring algorithm | Infrastructure ready |

### Phase B: Integration (Days 3-5)
Teams integrate with delivered dependencies.

| Team | Focus | Deliverable |
|------|-------|-------------|
| Team 1 | Jersey number assignment, team history expansion | All models complete |
| Team 2 | Integrate real DepthChart, roster validation | Depth system working |
| Team 3 | Rivalries, special teams, situational states | 3 more features |
| Team 4 | Contract negotiations, franchise tag | Core transactions |
| Team 5 | Wire career awards to players, franchise records | Awards flowing |

### Phase C: Completion (Days 6-8)
Feature completion and cross-team integration testing.

| Team | Focus | Deliverable |
|------|-------|-------------|
| Team 2 | Full PS/IR management, integration tests | Complete |
| Team 3 | Polish, edge cases, testing | Complete |
| Team 4 | Comp picks, draft pick trading | Complete |
| Team 5 | Hall of Fame induction, dynasty detection | Complete |

---

## Feature Summary

| Team | Features | Blocking? | Independence |
|------|----------|-----------|--------------|
| Team 1: Data Models | 5 | Yes (2-day delivery) | Foundation layer |
| Team 2: Roster Management | 5 | Partially (TeamNeeds) | Medium |
| Team 3: Game Simulation | 5 | No | **Fully independent** |
| Team 4: Offseason | 5 | No (can stub) | Medium |
| Team 5: Legacy | 5 | No (can stub) | Medium |
| **TOTAL** | **25 features** | 3 soft blocks | High parallelism |

---

## Risk Mitigation

### Blocking Risk: Team 1 Delays
**Mitigation**: Teams 2, 4, 5 create interface stubs on Day 1. If Team 1 is delayed, they continue with stubs and integrate later.

### Integration Risk: Cross-Team Interfaces
**Mitigation**: Define interfaces in this document (above). Teams code to interface, not implementation.

### Scope Risk: Feature Creep
**Mitigation**: Each feature has defined complexity. Teams should not expand scope without Director approval.

---

## Success Criteria

- [ ] All 25 features implemented and tested
- [ ] No regressions in existing bootstrap_world functionality
- [ ] Determinism maintained (same seed = same results)
- [ ] Performance target: <10% increase in bootstrap time
- [ ] All cross-team interfaces working correctly

---

## Next Steps

1. **Director**: Review and approve this plan
2. **Director**: Spawn 5 teams with assigned features
3. **Teams**: Begin Phase A work immediately
4. **Team 1**: Prioritize DepthChart and Coach attributes (Day 1 delivery target)
5. **All Teams**: Report blockers immediately to Director

---

*Plan prepared by Director Agent*
*Based on analysis from 3 Architect Agents*
