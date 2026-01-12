# Master Implementation Plan - Realistic 20-Year Simulation

**Document Version**: 1.0
**Date**: 2026-01-11
**Author**: Master Architect
**Purpose**: Comprehensive implementation plan synthesizing all architecture agent deliverables

---

## Executive Summary

After comprehensive architectural analysis by 4 specialized agents, we have identified a phased approach to transform the simulation from a "roster generator" to a "realistic football universe" with authentic 20-year narratives.

**Current State**: Solid foundation (player lifecycle, rosters, contracts, recruiting, draft) but missing game outcomes, statistics, awards, and historical tracking.

**Target State**: Complete simulation where users can answer:
- "Who won the Super Bowl in 2025?"
- "What are this player's career stats?"
- "Which teams are dynasties?"
- "Who won the Heisman Trophy?"

**Approach**: Phased implementation prioritizing high-impact, low-complexity features first.

---

## Architecture Agent Deliverables Summary

### Agent 1: Player Growth Depth (abf9395)
**Documents Created**:
- Player Growth Depth Architecture
- Coaching System Design
- Player Growth Depth Implementation Plan

**Key Insights**:
- Work ethic, coachability, and coaching quality should multiply base development
- Program strength affects resource access for player improvement
- Head coach quality impacts entire program development trajectory

**Integration**: Phase 3+ (after core systems established)

### Agent 2: Player Evaluation & Contracts (aabf247)
**Documents Created**:
- Contract System Architecture
- Salary Cap Specification
- Free Agency Design
- Contract System Implementation

**Key Insights**:
- NFL salary cap (~$225M) requires dead money tracking and cap hit calculations
- Player evaluation drives contract value (stats, awards, age, position)
- Free agency needs bidding mechanics and contract negotiations

**Integration**: Partial exists, full implementation Phase 2-3

### Agent 3: Trade Request System (af9b282)
**Documents Created**:
- Trade System Architecture
- Trade Value Specification
- Trade Realism Guide
- Example Trade Scenarios
- Trade System Implementation

**Key Insights**:
- Teams should have variable trade willingness (rebuilding vs contending)
- Players request trades after injuries to key teammates or retirements
- Trade value must account for position scarcity, age curves, contract status

**Integration**: Phase 3+ (requires player stats, team records, injury system)

### Agent 4: Missing Features Audit (aa604de)
**Documents Created**:
- Missing Features Audit (134 features across 18 categories)
- Feature Priority Matrix (4 quadrants by impact × complexity)
- Quick Wins List (18 Phase 1 features, 11-week timeline)
- Architectural Guardian Assessment (executive recommendations)

**Key Insights**:
- **Quadrant 1 (Quick Wins)**: 18 features, 54 days, 60% realism gain
- **Quadrant 2 (Strategic)**: 20 features, 257 days, 25% realism gain
- **Quadrant 3 (Backlog)**: 63 features, 300 days, 5% realism gain
- **Quadrant 4 (Defer)**: 33 features, 600+ days, <1% realism gain - DO NOT BUILD

**Integration**: Roadmap for all future work

---

## Phase 1: Foundation (Weeks 1-11, ~54 Implementation Days)

**Goal**: Transform from "roster generator" to "has season outcomes"
**Expected Realism Gain**: 60%
**Performance Target**: <90 seconds for 20-year bootstrap (<20% overhead)

### Implementation Tracks (Parallel Work)

#### Track 1: Game Simulation Foundation (Weeks 1-2)
**Owner**: Engineer Agent 1
**Features**:
- **G1.1**: Game Simulation (Medium, 15 days) - ALREADY DESIGNED
  - Implementation: `/scripts/core/game_simulation/GameSimulator.gd`
  - Integration: `CollegeSeason.run()` and `NflSeason.run()`
  - Tests: Determinism, home advantage, upset frequency
  - Acceptance: 20-year bootstrap completes, home win rate 55-65%

- **G1.2**: Season W-L Records (Small, 2 days)
  - Storage: `world_state["season_records"][year][team_id]`
  - Integration: After game simulation in season phases
  - Acceptance: All teams have W-L for all 20 years

- **G1.5**: Championship Tracking (Small, 2 days)
  - Storage: `world_state["championships"]`
  - Logic: Best record = champion (Phase 1 simple version)
  - Acceptance: One champion per year per league

**Dependencies**: None (foundational work)
**Estimated Duration**: 2 weeks
**Deliverable**: Game simulation working end-to-end

#### Track 2: Historical Tracking (Weeks 3-4)
**Owner**: Engineer Agent 2
**Features**:
- **H4.1**: Franchise Win Totals (Small, 2 days)
- **H4.2**: Championship History (Small, 2 days)
- **H4.3**: Playoff Appearance Count (Small, 2 days)
- **H4.4**: Winning Streaks (Small, 2 days)
- **H4.6**: Drought Tracking (Small, 1 day)

**Storage**: `world_state["team_history"][team_id]`
**Integration**: End-of-season phase, incremental updates
**Dependencies**: G1.2 (Season W-L Records)
**Estimated Duration**: 2 weeks
**Deliverable**: Complete team history tracking

#### Track 3: Draft History (Weeks 3-4)
**Owner**: Engineer Agent 3
**Features**:
- **D5.1**: Draft History (Small, 3 days)
  - Storage: `world_state["draft_history"][year]`
  - Integration: End of `nfl_draft` phase in `NflDraft.gd`
  - Acceptance: All 250 picks per year recorded for 20 years

- **D5.5**: Draft Pick Trades (Small, 3 days)
  - Extend draft history with `original_team_id` and `traded` flag
  - Phase 1: Set `traded: false` (placeholder for future trade system)
  - Acceptance: Schema ready for trade tracking

**Dependencies**: None (independent of game simulation)
**Estimated Duration**: 1 week
**Deliverable**: Complete draft history tracking

#### Track 4: Player Stats Infrastructure (Weeks 5-6)
**Owner**: Engineer Agent 4
**Features**:
- **S2.1**: Career Stat Totals (Medium, 12 days)
  - Storage: `world_state["player_career_stats"][player_id][year]`
  - Create: `/scripts/core/game_simulation/StatGenerator.gd`
  - Algorithm: Generate stats based on player rating + game outcome
  - Position-specific: QB (pass yards/TDs), RB (rush yards/TDs), etc.
  - Integration: During game simulation, accumulate stats
  - Acceptance: All active players have career stats, correlate with rating

- **S2.4**: Games Played/Started (Small, 3 days)
  - Integrated with S2.1 stat line
  - Logic: All roster players get games_played += 1
  - Starters (top N by rating) get games_started += 1
  - Acceptance: games_played ~= season length, starters have more starts

- **G1.8**: Strength of Schedule (Small, 3 days)
  - Calculated in `GameSimulator.aggregate_season_results()`
  - Formula: Average opponent team strength
  - Acceptance: All teams have SOS 0-100, correlates with opponent quality

**Dependencies**: G1.1 (Game Simulation)
**Estimated Duration**: 2 weeks
**Deliverable**: Player career stats infrastructure complete

#### Track 5: Award Systems (Weeks 7-9)
**Owner**: Engineer Agent 5
**Features**:
- **A3.2**: Offensive/Defensive POY (Medium, 6 days)
  - Create: `/scripts/core/awards/AwardCalculator.gd`
  - Algorithm: Score-based selection (stats × importance weights)
  - QB: pass_yards/10 + pass_tds×40 - INTs×20
  - RB: rush_yards/10 + rush_tds×60 + receptions×5
  - Integration: End-of-season in `NflSeason.run()`
  - Acceptance: One OPOY/DPOY per year, elite stats

- **A3.3**: All-Pro Teams (Medium, 6 days)
  - Select top 2 players per position
  - First team > second team stats
  - Integration: End-of-season award phase
  - Acceptance: All positions represented, 22 players per team

- **A3.4**: Pro Bowl Selections (Small, 4 days)
  - AFC/NFC rosters, position-specific counts
  - Top N players per position per conference
  - Acceptance: 88 total players selected (44 per conference)

- **A3.8**: Rookie of the Year (Medium, 5 days)
  - Filter current year's draft class
  - Apply same scoring as OPOY/DPOY
  - Acceptance: Winners are rookies, have strong stats

**Dependencies**: S2.1 (Career Stat Totals)
**Estimated Duration**: 3 weeks
**Deliverable**: Four award types functional

#### Track 6: Player Agency (Weeks 10-11)
**Owner**: Engineer Agent 1 or 2 (reassignment)
**Features**:
- **P13.1**: Early Draft Entry (Small, 4 days)
  - Enhance existing eligibility system in `CollegeSeason.gd`
  - Juniors (year 3+) with rating ≥75 have 50% chance to declare
  - Config: `early_declaration.junior_threshold`, `junior_early_chance`
  - Acceptance: 50-100 early entries per year, realistic rate

- **B8.5**: Retirement Decisions (Small, 3 days)
  - Extend `PlayerLifecycle.advance_one_year()`
  - Injury retirement: 3+ severe injuries → 70% retire chance
  - Performance retirement: Age >32 + rating <50 → 30% retire chance
  - Acceptance: Non-age retirements occur, reasons tracked

- **I6.5**: Injury-Prone Trait (Small, 2 days)
  - Add during player generation: 10% of players get trait
  - Flag: `player["hidden_traits"].append("InjuryFlag:Prone")`
  - Future use: 2x injury multiplier (Phase 3 injury system)
  - Acceptance: ~10% of players have trait

- **S14.3**: Combine Measurements (Small, 2 days)
  - Already exists in player model (forty_sec, vertical_in, etc.)
  - Ensure visibility in UI (World Explorer panels)
  - Acceptance: All draft-eligible players have combine stats

**Dependencies**: Partial (existing systems, enhance only)
**Estimated Duration**: 2 weeks
**Deliverable**: Enhanced player agency mechanics

---

## Parallel Implementation Strategy

### Week 1-2: Foundational (1 agent)
**Agent 1**: Game Simulation Foundation (Track 1)
- Critical path: G1.1, G1.2, G1.5 must complete first
- Blocks: Tracks 2, 4, 5 depend on this

### Week 3-4: Historical Data (3 agents in parallel)
**Agent 2**: Historical Tracking (Track 2) - depends on Track 1
**Agent 3**: Draft History (Track 3) - independent
**Agent 1** (continues): Complete G1.8 if needed, prepare for Track 4

### Week 5-6: Stats Infrastructure (1-2 agents)
**Agent 4**: Player Stats Infrastructure (Track 4) - depends on Track 1
**Agent 3** (continues): Support or start Track 6 prep

### Week 7-9: Awards (1 agent)
**Agent 5**: Award Systems (Track 5) - depends on Track 4

### Week 10-11: Player Agency (1 agent)
**Agent 1 or 2** (reassigned): Player Agency (Track 6) - mostly independent

**Maximum Parallelization**: 3 agents simultaneously (weeks 3-4)
**Sequential Constraints**: Track 1 → Tracks 2,4 → Track 5

---

## Feature Dependencies Graph

```
G1.1 (Game Simulation) ──┬──→ G1.2 (W-L Records) ──┬──→ H4.1-H4.6 (Team History)
                         │                         │
                         │                         └──→ G1.5 (Championships)
                         │
                         └──→ S2.1 (Stats) ──┬──→ A3.2 (OPOY/DPOY)
                                             ├──→ A3.3 (All-Pro)
                                             ├──→ A3.4 (Pro Bowl)
                                             └──→ A3.8 (Rookie OTY)

D5.1 (Draft History) ──→ D5.5 (Draft Trades)  [Independent]

P13.1, B8.5, I6.5, S14.3  [Mostly independent, can run in parallel with others]
```

---

## Implementation Assignments

### Game-Systems-Engineer Agent 1: "Foundation Engineer"
**Primary Responsibility**: Game Simulation Core
**Assigned Features**:
- Weeks 1-2: G1.1, G1.2, G1.5, G1.8 (Track 1)
- Weeks 10-11: P13.1, B8.5 (part of Track 6)

**Rationale**: Most critical path, requires strong system integration skills

### Game-Systems-Engineer Agent 2: "History Engineer"
**Primary Responsibility**: Historical Tracking
**Assigned Features**:
- Weeks 3-4: H4.1, H4.2, H4.3, H4.4, H4.6 (Track 2)
- Weeks 10-11: I6.5, S14.3 (part of Track 6)

**Rationale**: Incremental counter logic, well-bounded scope

### Game-Systems-Engineer Agent 3: "Draft Engineer"
**Primary Responsibility**: Draft History
**Assigned Features**:
- Weeks 3-4: D5.1, D5.5 (Track 3)
- Support: Testing, documentation, review support for other tracks

**Rationale**: Shorter track, can support others after completion

### Game-Systems-Engineer Agent 4: "Stats Engineer"
**Primary Responsibility**: Player Statistics
**Assigned Features**:
- Weeks 5-6: S2.1, S2.4, stat generation algorithms (Track 4)

**Rationale**: Complex stat generation logic, position-specific details

### Game-Systems-Engineer Agent 5: "Awards Engineer"
**Primary Responsibility**: Award Systems
**Assigned Features**:
- Weeks 7-9: A3.2, A3.3, A3.4, A3.8 (Track 5)

**Rationale**: Award calculation formulas, voting logic

---

## Testing Strategy

### Per-Feature Testing (Each Engineer)
- Unit tests for new classes (GameSimulator, StatGenerator, AwardCalculator)
- Integration tests for season phase modifications
- Determinism validation tests (same seed = same results)
- Data model validation tests (schema correctness)

### System-Level Testing (All Engineers)
- **Full Bootstrap Test**: 20-year world bootstrapping with all features enabled
- **Performance Benchmark**: Bootstrap time <90 seconds
- **Determinism Test**: Run 3x with same seed, verify identical results
- **World State Validation**: Verify all new data present and correct

### Test Naming Convention
- `test_<feature_id>_<aspect>.gd`
- Example: `test_g1_1_game_simulation_determinism.gd`
- Example: `test_s2_1_career_stats_accumulation.gd`

---

## PR Organization Strategy

### PR 1: Game Simulation Foundation (Weeks 1-2)
**Features**: G1.1, G1.2, G1.5, G1.8
**Files Modified**:
- NEW: `/scripts/core/game_simulation/GameSimulator.gd`
- MOD: `/scripts/world/CollegeSeason.gd`
- MOD: `/scripts/world/NflSeason.gd`
- MOD: `/configs/sports/american_football/world/colleges.json` (v2)
- MOD: `/configs/sports/american_football/world/league.json` (v3)
- NEW: 4 test files

**Title**: "feat: implement game simulation and season records tracking"
**Description**: Implements game simulation engine with deterministic outcomes, tracks W-L records, championships, and strength of schedule for all teams across 20-year simulation.

### PR 2: Historical Tracking (Weeks 3-4)
**Features**: H4.1-H4.6
**Files Modified**:
- MOD: `/scripts/world/CollegeSeason.gd` (team_history updates)
- MOD: `/scripts/world/NflSeason.gd` (team_history updates)
- NEW: 5 test files

**Title**: "feat: add comprehensive team history tracking"
**Description**: Tracks franchise win totals, championship history, playoff appearances, winning streaks, and championship droughts across simulation.

### PR 3: Draft History (Weeks 3-4)
**Features**: D5.1, D5.5
**Files Modified**:
- MOD: `/scripts/world/NflDraft.gd`
- NEW: 2 test files

**Title**: "feat: persist draft history across all years"
**Description**: Records all draft picks with team, round, player, and trade information for historical tracking.

### PR 4: Player Stats Infrastructure (Weeks 5-6)
**Features**: S2.1, S2.4
**Files Modified**:
- NEW: `/scripts/core/game_simulation/StatGenerator.gd`
- MOD: `/scripts/world/CollegeSeason.gd`
- MOD: `/scripts/world/NflSeason.gd`
- NEW: 3 test files

**Title**: "feat: implement player career statistics tracking"
**Description**: Creates stat generation algorithms and accumulates position-specific career statistics for all active players across games.

### PR 5: Award Systems (Weeks 7-9)
**Features**: A3.2, A3.3, A3.4, A3.8
**Files Modified**:
- NEW: `/scripts/core/awards/AwardCalculator.gd`
- MOD: `/scripts/world/NflSeason.gd`
- NEW: 4 test files

**Title**: "feat: implement NFL award systems (MVP, All-Pro, Pro Bowl, ROTY)"
**Description**: Adds end-of-season awards with stat-based selection for OPOY/DPOY, All-Pro teams, Pro Bowl rosters, and Rookie of the Year.

### PR 6: Player Agency Enhancements (Weeks 10-11)
**Features**: P13.1, B8.5, I6.5, S14.3
**Files Modified**:
- MOD: `/scripts/world/CollegeSeason.gd` (early draft entry)
- MOD: `/scripts/world/PlayerLifecycle.gd` (retirement decisions)
- MOD: `/scripts/generation/PlayerGenerator.gd` or `/scripts/generation/ClassGenerator.gd` (injury-prone trait)
- MOD: UI files for combine stats visibility
- NEW: 4 test files

**Title**: "feat: enhance player agency with early entry, retirement logic, and injury traits"
**Description**: Improves player decision-making with realistic early draft declarations, non-age retirement, injury-prone trait assignment, and combine stat visibility.

---

## Success Criteria

### Phase 1 Completion Checklist

#### Functional Requirements
- [ ] Game simulation integrated (G1.1)
- [ ] Season W-L records stored (G1.2)
- [ ] Championships tracked (G1.5)
- [ ] Team history complete (H4.1-H4.6)
- [ ] Draft history recorded (D5.1, D5.5)
- [ ] Player career stats infrastructure (S2.1, S2.4)
- [ ] Strength of schedule calculated (G1.8)
- [ ] Four award types functional (A3.2-A3.4, A3.8)
- [ ] Early draft entry enhanced (P13.1)
- [ ] Retirement decisions expanded (B8.5)
- [ ] Injury-prone trait added (I6.5)
- [ ] Combine stats visible (S14.3)

#### Non-Functional Requirements
- [ ] Bootstrap time <90 seconds (20 years)
- [ ] World state size <200 MB
- [ ] Home team win rate 55-65%
- [ ] Upset frequency 15-25%
- [ ] Determinism validated (same seed = same results)
- [ ] All tests passing (83+ existing + ~20 new = 103+ total)

#### User Value Validation
- [ ] Users can query: "Who won the Super Bowl in year X?"
- [ ] Users can query: "What are this player's career stats?"
- [ ] Users can query: "Which teams are dynasties?"
- [ ] Users can query: "Who won awards in year X?"

---

## Risk Mitigation

### High-Risk Areas

**1. Performance Regression**
- **Risk**: Game simulation adds >20% overhead
- **Mitigation**: Already designed with 3.15% target, incremental testing
- **Monitoring**: Per-phase timing capture during bootstrap

**2. Determinism Violation**
- **Risk**: New RNG usage breaks reproducibility
- **Mitigation**: Follow existing RNG patterns (splitmix64, explicit seed derivation)
- **Testing**: Run bootstrap 3x with same seed, verify identical results

**3. Memory Explosion**
- **Risk**: Stat tracking consumes excessive memory
- **Mitigation**: Aggregate season totals only, no per-game logs (Phase 1)
- **Monitoring**: World state size checks after bootstrap

**4. Integration Complexity**
- **Risk**: Season phase modifications create bugs
- **Mitigation**: Incremental integration, comprehensive test coverage
- **Review**: Code quality review after each PR

### Medium-Risk Areas

**1. Stat Generation Realism**
- **Risk**: Generated stats don't correlate with player ratings
- **Mitigation**: Simple formulas initially, tuning based on validation
- **Testing**: Validate elite players have elite stats

**2. Award Selection Accuracy**
- **Risk**: Award winners seem arbitrary
- **Mitigation**: Formula-based scoring, clear stat weights
- **Testing**: Verify winners have top-tier stats

**3. Parallel Development Conflicts**
- **Risk**: Merge conflicts when multiple engineers modify same files
- **Mitigation**: Clear track assignments, sequential constraints where needed
- **Process**: Daily sync meetings, PR review before merge

---

## Post-Phase 1: Future Phases Overview

### Phase 2: Core Gameplay (Months 4-8, ~120 days)
**Focus**: Standings, playoffs, comprehensive stats, major awards
**Key Features**: G1.3, G1.4, S2.2, S2.3, A3.1, A3.5, M12.1
**Realism Gain**: +25% (cumulative 85%)

### Phase 3: Depth & Drama (Months 9-15, ~137 days)
**Focus**: Injuries, transfers, coaching
**Key Features**: I6.1, I6.2, P13.2, C7.1, C7.4
**Realism Gain**: +10% (cumulative 95%)

### Phase 4: Completeness (Months 16+, ongoing)
**Focus**: Backlog features, polish, user-requested enhancements
**Key Features**: Quadrant 3 features as needed
**Realism Gain**: +5% (cumulative 100%)

---

## Monitoring & Metrics

### Daily Metrics (Per Engineer)
- Features completed vs. planned
- Tests written and passing
- Code review status
- Blockers identified

### Weekly Metrics (Team)
- PRs created, reviewed, merged
- Bootstrap performance (seconds)
- Test coverage percentage
- Integration issues resolved

### Phase Completion Metrics
- All 18 features implemented
- All 6 PRs merged
- All acceptance criteria met
- Performance targets achieved (<90s bootstrap)
- Realism improvement validated (60% gain)

---

## Communication Protocol

### Daily Stand-Up (Async)
Each engineer posts:
1. What I completed yesterday
2. What I'm working on today
3. Any blockers or questions

### PR Review Process
1. Engineer creates PR with description, test results, performance impact
2. At least one other engineer reviews code
3. Code quality checks pass (linting, tests)
4. Merge after approval

### Weekly Sync (All Engineers + Architect)
1. Review progress vs. timeline
2. Discuss integration issues
3. Adjust assignments if needed
4. Plan next week's work

---

## Document Control

**Version**: 1.0
**Status**: Master Plan - Ready for Implementation
**Created**: 2026-01-11
**Review Date**: Weekly during Phase 1

**Related Documents**:
- `/docs/analysis/MISSING_FEATURES_AUDIT.md`
- `/docs/analysis/FEATURE_PRIORITY_MATRIX.md`
- `/docs/planning/QUICK_WINS_LIST.md`
- `/docs/planning/ARCHITECTURAL_GUARDIAN_ASSESSMENT.md`
- `/docs/architectural_notes/GAME_SIMULATION_ARCHITECTURE.md`
- `/docs/tasks/GAME_SIMULATION_SPECS.md`

**Next Action**: Spawn 5 game-systems-engineer agents with feature assignments per this plan.

---

## Agent Spawn Commands

### Agent 1: Foundation Engineer
**Assignment**: Track 1 (Weeks 1-2) + Track 6 partial (Weeks 10-11)
**Features**: G1.1, G1.2, G1.5, G1.8, P13.1, B8.5
**Prompt**: "Implement game simulation foundation and season records tracking per MASTER_IMPLEMENTATION_PLAN Track 1"

### Agent 2: History Engineer
**Assignment**: Track 2 (Weeks 3-4) + Track 6 partial (Weeks 10-11)
**Features**: H4.1-H4.6, I6.5, S14.3
**Prompt**: "Implement comprehensive team history tracking per MASTER_IMPLEMENTATION_PLAN Track 2"

### Agent 3: Draft Engineer
**Assignment**: Track 3 (Weeks 3-4)
**Features**: D5.1, D5.5
**Prompt**: "Implement draft history persistence per MASTER_IMPLEMENTATION_PLAN Track 3"

### Agent 4: Stats Engineer
**Assignment**: Track 4 (Weeks 5-6)
**Features**: S2.1, S2.4
**Prompt**: "Implement player career statistics infrastructure per MASTER_IMPLEMENTATION_PLAN Track 4"

### Agent 5: Awards Engineer
**Assignment**: Track 5 (Weeks 7-9)
**Features**: A3.2-A3.4, A3.8
**Prompt**: "Implement NFL award systems per MASTER_IMPLEMENTATION_PLAN Track 5"

---

**Implementation Start Date**: 2026-01-11
**Estimated Completion**: 2026-03-23 (11 weeks)
**Expected Outcome**: Realistic 20-year simulation with 60% realism improvement and <90s bootstrap time
