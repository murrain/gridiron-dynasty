# Missing Features Audit - 20-Year Simulation Realism

**Document Version**: 1.0
**Date**: 2026-01-11
**Author**: Architecture Guardian
**Purpose**: Comprehensive gap analysis identifying missing features for realistic 20-year world state

---

## Executive Summary

**Current State Assessment**:
After 20 years of bootstrap, the simulation produces:
- Player lifecycles (generation, development, retirement)
- Team rosters (college and NFL)
- Draft mechanics (eligibility, selection)
- Recruiting system (college targeting, commitment)
- Contract management (signing, salary cap)
- Basic injury model (wear tracking)

**Critical Gaps**:
The simulation lacks essential outcome data that defines sports universes:
- No game results (W-L records, standings)
- No season history (championships, playoffs)
- No player statistics (career stats, performance tracking)
- No awards or recognition (MVP, Heisman, All-Pro)
- No coaching systems (hiring, firing, development impact)
- No meaningful drama (holdouts, trades, controversies)

**Impact**: Without these features, a 20-year simulation feels like a roster generator, not a living football universe with narratives, legacies, and authentic dynamics.

---

## Feature Categories

### Category 1: Game Results & Season Outcomes
**Current State**: No games simulated, no season outcomes tracked
**Impact on Realism**: CRITICAL - Games define everything in sports

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| G1.1 | Game Simulation | Simulate game outcomes (winner/loser) | Missing | CRITICAL | Medium |
| G1.2 | Season W-L Records | Track wins/losses per team per season | Missing | CRITICAL | Small |
| G1.3 | Season Standings | Division/conference standings | Missing | CRITICAL | Medium |
| G1.4 | Playoff Brackets | College playoff, NFL playoff structure | Missing | CRITICAL | Large |
| G1.5 | Championship Tracking | National champions, Super Bowl winners | Missing | CRITICAL | Small |
| G1.6 | Game Scores | Point totals per game | Missing | Important | Medium |
| G1.7 | Point Differentials | Season-long scoring margins | Missing | Important | Small |
| G1.8 | Strength of Schedule | Opponent quality metrics | Missing | Important | Small |
| G1.9 | Bowl Game Selection | College bowl matchups and outcomes | Missing | Important | Large |
| G1.10 | Conference Championships | Conference title games | Missing | Important | Medium |
| G1.11 | Head-to-Head Records | Historical matchup tracking | Missing | Nice-to-Have | Medium |
| G1.12 | Rivalry Tracking | Designated rivalry games | Missing | Nice-to-Have | Medium |
| G1.13 | Home/Away Split | Performance by venue | Missing | Nice-to-Have | Small |
| G1.14 | Upset Tracking | Underdog victories | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Already Designed**: See `/docs/architectural_notes/GAME_SIMULATION_ARCHITECTURE.md` and `/docs/tasks/GAME_SIMULATION_SPECS.md`
- **Integration Point**: `CollegeSeason.run()` and `NflSeason.run()` during `college_season` and `nfl_season` phases
- **Storage**: `world_state["season_records"][year][team_id]` with SeasonRecord structure
- **Performance Target**: <5% bootstrap overhead (Phase 1 estimates 3.15% for 21,040 games over 20 years)
- **Status**: Phase 1 (MVP) design complete, awaiting implementation

---

### Category 2: Player Statistics
**Current State**: No per-player game stats tracked
**Impact on Realism**: HIGH - Stats define player legacies and value

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| S2.1 | Career Stat Totals | Lifetime yards, TDs, sacks, etc. | Missing | HIGH | Medium |
| S2.2 | Season Stat Lines | Per-season statistical performance | Missing | HIGH | Medium |
| S2.3 | Position-Specific Stats | QB: pass yards/TDs, RB: rush yards, etc. | Missing | HIGH | Large |
| S2.4 | Games Played/Started | Participation tracking | Missing | HIGH | Small |
| S2.5 | Per-Game Averages | YPG, PPG, sacks per game | Missing | Important | Small |
| S2.6 | Career Highs | Single-game and single-season records | Missing | Important | Medium |
| S2.7 | Statistical Leaders | League leaders by category | Missing | Important | Small |
| S2.8 | Statistical Milestones | 1000-yard seasons, 10+ sacks, etc. | Missing | Important | Medium |
| S2.9 | Consistency Metrics | Performance variance | Missing | Nice-to-Have | Medium |
| S2.10 | Advanced Stats | Passer rating, YAC, target %, etc. | Missing | Nice-to-Have | Large |
| S2.11 | Postseason Stats | Playoff performance tracking | Missing | Nice-to-Have | Medium |
| S2.12 | Pro Bowl Stats | All-star game statistics | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Storage Challenge**: Full per-game stats = massive memory (10K+ players × 12-17 games × 20 years × stat categories)
- **Proposed Approach**: Aggregate season totals only (Phase 1), detailed game logs optional (Phase 3+)
- **Integration Point**: After game simulation, update player stat accumulators
- **Data Model**: `world_state["player_career_stats"][player_id][year]` with position-specific schema
- **Performance Concern**: Stat aggregation must be O(1) per game to avoid bootstrap slowdown

---

### Category 3: Awards & Recognition
**Current State**: No awards system
**Impact on Realism**: HIGH - Awards create narratives and affect player value

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| A3.1 | NFL MVP | League MVP award | Missing | HIGH | Medium |
| A3.2 | Offensive/Defensive POY | NFL OPOY/DPOY awards | Missing | HIGH | Medium |
| A3.3 | All-Pro Teams | First/Second Team All-Pro | Missing | HIGH | Medium |
| A3.4 | Pro Bowl Selections | AFC/NFC Pro Bowl rosters | Missing | HIGH | Small |
| A3.5 | Heisman Trophy | College top player award | Missing | HIGH | Large |
| A3.6 | All-American Teams | College consensus All-Americans | Missing | HIGH | Medium |
| A3.7 | Conference Awards | Conference POY, All-Conference teams | Missing | Important | Medium |
| A3.8 | Rookie of the Year | NFL OROY/DROY | Missing | Important | Medium |
| A3.9 | Coach of the Year | NFL/College coaching awards | Missing | Important | Small |
| A3.10 | Position-Specific Awards | Walter Payton Award, etc. | Missing | Nice-to-Have | Medium |
| A3.11 | Hall of Fame Selection | Career legacy recognition | Missing | Nice-to-Have | Large |
| A3.12 | Team MVP | Individual team awards | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Dependency**: Requires player statistics (S2.x) to determine award winners
- **Algorithm**: Voting-based (weighted by stats + team success) or deterministic formula
- **Storage**: `world_state["awards"][year][award_type]` with winner metadata
- **Impact on Systems**: Awards affect player valuation, contract negotiations, recruiting appeal
- **Integration Point**: End-of-season phase after stat aggregation

---

### Category 4: Team History & Records
**Current State**: No historical tracking beyond current roster state
**Impact on Realism**: MEDIUM - History defines program prestige

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| H4.1 | Franchise Win Totals | All-time team W-L records | Missing | Important | Small |
| H4.2 | Championship History | Count of titles per team | Missing | Important | Small |
| H4.3 | Playoff Appearance Count | Postseason participation | Missing | Important | Small |
| H4.4 | Winning Streaks | Consecutive wins/losses | Missing | Important | Small |
| H4.5 | Dynasty Detection | Sustained success periods | Missing | Important | Medium |
| H4.6 | Drought Tracking | Years since championship | Missing | Important | Small |
| H4.7 | Team Records | Franchise single-season records | Missing | Nice-to-Have | Medium |
| H4.8 | Retired Numbers | Jersey retirement tracking | Missing | Nice-to-Have | Small |
| H4.9 | Ring of Honor | Team hall of fame | Missing | Nice-to-Have | Small |
| H4.10 | Historical Rosters | Archived team compositions | Missing | Nice-to-Have | Large |

**Architecture Notes**:
- **Storage**: Lightweight aggregation in `world_state["team_history"][team_id]`
- **Performance**: Incremental updates during season phases (no full recomputation)
- **Integration Point**: End-of-season phase, update historical counters
- **Use Case**: Recruiting appeal, UI display, dynasty narrative generation

---

### Category 5: Draft & Prospect Tracking
**Current State**: Draft occurs but no historical tracking
**Impact on Realism**: MEDIUM - Draft history affects team-building evaluation

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| D5.1 | Draft History | Record of all picks (round, pick, team) | Missing | Important | Small |
| D5.2 | Draft Class Rankings | Best/worst draft classes | Missing | Important | Medium |
| D5.3 | Draft Hit Rates | % of picks who became stars by team | Missing | Important | Medium |
| D5.4 | Prospect Rankings | Pre-draft ranking consensus | Missing | Important | Medium |
| D5.5 | Draft Pick Trades | Trade history tracking | Missing | Important | Small |
| D5.6 | Compensatory Picks | NFL comp pick assignment | Missing | Nice-to-Have | Large |
| D5.7 | Supplemental Draft | Mid-year draft events | Missing | Nice-to-Have | Medium |
| D5.8 | Draft Steals/Busts | Late-round stars, high-pick failures | Missing | Nice-to-Have | Medium |
| D5.9 | Combine Results | Historical combine data per prospect | Partial | Nice-to-Have | Small |

**Architecture Notes**:
- **Current Draft System**: `NflDraft.gd` handles draft execution, updates `world_state["draft_pool"]`
- **Missing Storage**: No persistent draft history (`world_state["draft_history"][year]`)
- **Integration Point**: End of `nfl_draft` phase, record selections
- **Performance**: Minimal overhead (only store selections, not full evaluations)

---

### Category 6: Injury System
**Current State**: Basic wear tracking exists, no dynamic injuries
**Impact on Realism**: HIGH - Injuries massively affect rosters and narratives

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| I6.1 | Season-Ending Injuries | ACL, Achilles, career-threatening | Missing | HIGH | Large |
| I6.2 | In-Season Injuries | Multi-week absences | Missing | HIGH | Large |
| I6.3 | Game-Time Injuries | Single-game impact | Missing | Important | Medium |
| I6.4 | Injury Reserve System | IR designation and roster rules | Missing | Important | Medium |
| I6.5 | Injury-Prone Trait | Players with higher injury risk | Missing | Important | Small |
| I6.6 | Recovery Variance | Unpredictable healing timelines | Missing | Important | Medium |
| I6.7 | Permanent Stat Loss | Reduced performance post-injury | Missing | Important | Medium |
| I6.8 | Medical Staff Quality | Team facility impact on recovery | Missing | Nice-to-Have | Large |
| I6.9 | Injury History Tracking | Career injury log | Missing | Nice-to-Have | Small |
| I6.10 | Comeback Player Award | Recognition for injury recovery | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Existing Model**: `Injury.gd` class exists with `type`, `severity`, `affected_stats`, `recovery_timeline`, `long_term_penalty`
- **Current Usage**: Minimal (wear accumulation only, not dynamic injuries)
- **Integration Point**: During `PlayerLifecycle.advance_one_year()` or game simulation
- **Performance Impact**: HIGH if injuries checked per-game (21K games × 22 starters × injury roll)
- **Proposed Approach**: Season-level injury phase (not per-game) for performance

---

### Category 7: Coaching System
**Current State**: Coach model exists but unused
**Impact on Realism**: HIGH - Coaching defines team identity and development

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| C7.1 | Head Coach Hiring | Hire/fire mechanics | Missing | HIGH | Large |
| C7.2 | Coaching Staff | OC, DC, position coaches | Missing | HIGH | Large |
| C7.3 | Coaching Philosophy | Offensive/defensive schemes | Missing | HIGH | Large |
| C7.4 | Development Multipliers | Coach skill affects player growth | Missing | HIGH | Medium |
| C7.5 | Coaching Tenure | Years with team, hot seat status | Missing | Important | Small |
| C7.6 | Coaching Records | Career W-L by coach | Missing | Important | Small |
| C7.7 | Coaching Tree | Assistant-to-HC progressions | Missing | Important | Medium |
| C7.8 | Recruiting Impact | Coach skill affects recruiting | Missing | Important | Medium |
| C7.9 | Coaching Contracts | Contract length, buyouts | Missing | Nice-to-Have | Medium |
| C7.10 | Coaching Retirement | Age-based or voluntary retirement | Missing | Nice-to-Have | Small |
| C7.11 | Coaching Mobility | Coaches switching teams | Missing | Nice-to-Have | Medium |
| C7.12 | Coaching Ratings | Overall coach quality score | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Existing Model**: `Coach.gd` with `id`, `first_name`, `last_name`, `role` (skeleton only)
- **Missing Fields**: Philosophy, skill ratings, tenure, win_loss, contract
- **Integration Points**:
  - Coaching hire/fire during offseason phase (new phase or extend `nfl_season`/`college_season`)
  - Development multipliers in `PlayerLifecycle._apply_development_context()`
  - Recruiting impact in `CollegeRecruiting` evaluation
- **Complexity Driver**: Coaching AI decision-making (scheme fit, roster assessment)

---

### Category 8: Player Behavior & Drama
**Current State**: Players are passive entities with no agency
**Impact on Realism**: MEDIUM - Drama creates compelling narratives

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| B8.1 | Contract Holdouts | Players demand new contracts | Missing | Important | Medium |
| B8.2 | Trade Demands | Players request trades | Missing | Important | Medium |
| B8.3 | Locker Room Issues | Chemistry conflicts | Missing | Important | Large |
| B8.4 | Off-Field Problems | Suspensions, arrests | Missing | Important | Medium |
| B8.5 | Retirement Decisions | Non-age retirement (injuries, choice) | Partial | Important | Small |
| B8.6 | Team Captains | Leadership roles | Missing | Nice-to-Have | Small |
| B8.7 | Mentorship | Veteran-to-rookie development | Missing | Nice-to-Have | Medium |
| B8.8 | Player Morale | Satisfaction with team | Missing | Nice-to-Have | Medium |
| B8.9 | Rivalry Feuds | Player-vs-player conflicts | Missing | Nice-to-Have | Small |
| B8.10 | Social Media Presence | Public personality impact | Missing | Nice-to-Have | Large |

**Architecture Notes**:
- **Existing Traits**: `work_ethic`, `coachability` exist in player model but unused
- **Integration Point**: Annual personality check during `PlayerLifecycle` or offseason phase
- **Impact on Systems**: Drama affects contract negotiations, trade willingness, team chemistry
- **Performance**: Minimal (one roll per player per year, ~10K players = 10K rolls)

---

### Category 9: Financial Systems
**Current State**: Basic contract/salary cap exists
**Impact on Realism**: MEDIUM - Finances constrain team-building

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| F9.1 | Team Revenue | Ticket sales, TV deals, merchandise | Missing | Important | Large |
| F9.2 | Operating Costs | Staff salaries, facility upkeep | Missing | Important | Large |
| F9.3 | Revenue Sharing | League-wide distribution | Missing | Important | Medium |
| F9.4 | Budget Constraints | Small vs big market impact | Missing | Important | Large |
| F9.5 | Facility Investments | Stadium upgrades, training facilities | Missing | Nice-to-Have | Large |
| F9.6 | Luxury Tax | Penalties for high spending | Missing | Nice-to-Have | Medium |
| F9.7 | Revenue Projections | Multi-year financial planning | Missing | Nice-to-Have | Large |
| F9.8 | Bankruptcy Risk | Financial instability | Missing | Nice-to-Have | Large |

**Architecture Notes**:
- **Existing System**: `ContractLifecycle.gd` and `CapValidationFlow.gd` handle contracts/cap
- **Missing Layer**: Revenue generation and budget allocation
- **Integration Point**: New offseason financial phase
- **Complexity Driver**: Realistic economic modeling (TV markets, attendance, etc.)
- **Priority**: LOW for Phase 1 (cap compliance more important than revenue modeling)

---

### Category 10: Facilities & Infrastructure
**Current State**: No facility system
**Impact on Realism**: LOW - Nice-to-have for depth

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| I10.1 | Training Facilities | Quality rating (affects development) | Missing | Nice-to-Have | Large |
| I10.2 | Stadiums | Capacity, location, home advantage | Missing | Nice-to-Have | Medium |
| I10.3 | Medical Facilities | Injury recovery impact | Missing | Nice-to-Have | Large |
| I10.4 | Facility Upgrades | Investments over time | Missing | Nice-to-Have | Large |
| I10.5 | Practice Fields | Infrastructure quality | Missing | Nice-to-Have | Small |
| I10.6 | Academic Centers | College academic support (development) | Missing | Nice-to-Have | Medium |

**Architecture Notes**:
- **Integration Point**: Team metadata, affects development/recruiting/injury multipliers
- **Storage**: `world_state["colleges"][college_id]["facilities"]` or `world_state["nfl_teams"][team_id]["facilities"]`
- **Impact**: Small multipliers (1.0-1.1x) on player development or recruiting appeal
- **Priority**: DEFERRED - Complexity not justified by realism gain in Phase 1-2

---

### Category 11: Conference & Scheduling
**Current State**: Basic conference structure exists, no realignment
**Impact on Realism**: MEDIUM - Conference structure defines competitive landscape

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| S11.1 | Conference Realignment | Teams switching conferences | Missing | Important | Large |
| S11.2 | TV Deals | Conference-level revenue | Missing | Important | Large |
| S11.3 | Conference Championships | Title game mechanics | Missing | HIGH | Medium |
| S11.4 | Scheduling Logic | Opponent selection rules | Missing | HIGH | Large |
| S11.5 | Rivalry Protection | Guaranteed annual matchups | Missing | Nice-to-Have | Medium |
| S11.6 | Cross-Division Games | Rotation scheduling | Missing | Nice-to-Have | Medium |

**Architecture Notes**:
- **Current State**: Conferences defined in `colleges.json`, but no dynamic behavior
- **Game Simulation Dependency**: Requires game results (G1.x) to determine champions
- **Integration Point**: Phase 2 of game simulation architecture (conference-aware schedules)
- **Storage**: `world_state["conference_membership_history"][year][conference_id]`

---

### Category 12: Media & Public Perception
**Current State**: No media system
**Impact on Realism**: MEDIUM - Media creates narrative layer

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| M12.1 | Power Rankings | AP Poll, Coaches Poll | Missing | Important | Medium |
| M12.2 | Draft Rankings | Prospect consensus boards | Missing | Important | Medium |
| M12.3 | Team Reputation | Program prestige over time | Missing | Important | Medium |
| M12.4 | Coaching Hot Seat | Fire pressure tracking | Missing | Important | Small |
| M12.5 | Scandal Impact | Negative publicity effects | Missing | Nice-to-Have | Large |
| M12.6 | Recruiting Dead Periods | Penalty-based restrictions | Missing | Nice-to-Have | Medium |
| M12.7 | Media Buzz | Hype cycles for players/teams | Missing | Nice-to-Have | Medium |

**Architecture Notes**:
- **Integration Point**: Post-season ranking calculation phase
- **Impact on Systems**: Rankings affect recruiting appeal, coaching job security
- **Storage**: `world_state["rankings"][year]` with poll positions
- **Algorithm**: Formula-based (W-L, SOS, historical prestige) or simulated voting

---

### Category 13: Player Career Decisions
**Current State**: Basic draft eligibility, no transfer system
**Impact on Realism**: MEDIUM - Player agency affects rosters

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| P13.1 | Early Draft Entry | Underclassmen declare for draft | Partial | HIGH | Small |
| P13.2 | Transfer Portal | College player transfers | Missing | HIGH | Large |
| P13.3 | Redshirt Decisions | Eligibility preservation | Missing | Important | Medium |
| P13.4 | Graduate Transfer | Fifth-year transfers | Missing | Important | Medium |
| P13.5 | Position Changes | Player switches position | Missing | Nice-to-Have | Medium |
| P13.6 | Medical Redshirts | Injury-based eligibility extension | Missing | Nice-to-Have | Medium |
| P13.7 | Academic Ineligibility | Loss of eligibility due to grades | Missing | Nice-to-Have | Medium |

**Architecture Notes**:
- **Current System**: `CollegeSeason.gd` handles early declarations with threshold checks
- **Missing Mechanics**: Transfer portal (requires new phase or extend `college_recruiting`)
- **Integration Point**: Between college seasons, before recruiting
- **Performance**: Minimal (one decision per eligible player)

---

### Category 14: Scouting & Information
**Current State**: Full player visibility (unrealistic)
**Impact on Realism**: MEDIUM - Fog of war increases strategic depth

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| S14.1 | Fog of War | Limited visibility into other teams | Missing | Important | Large |
| S14.2 | Scouting Reports | Incomplete player information | Missing | Important | Large |
| S14.3 | Combine Measurements | Public testing data | Partial | Important | Small |
| S14.4 | Pro Day Results | School-based testing | Missing | Nice-to-Have | Medium |
| S14.5 | Background Checks | Character evaluation | Missing | Nice-to-Have | Medium |
| S14.6 | Draft Grade Uncertainty | Uncertain prospect evaluations | Missing | Important | Medium |
| S14.7 | Injury Reports | Public vs hidden injury info | Missing | Nice-to-Have | Medium |

**Architecture Notes**:
- **Existing System**: `Scout.gd` and `ScoutEvaluation.gd` provide scouting framework
- **Current Behavior**: All data fully visible (no fog of war)
- **Integration Complexity**: HIGH (requires UI changes, query filtering, access control)
- **Priority**: DEFERRED - More important for player-controlled game than simulation

---

### Category 15: Offseason Activities
**Current State**: Draft and recruiting exist, little else
**Impact on Realism**: LOW - Calendar filler

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| O15.1 | Training Camp | Position battles | Missing | Nice-to-Have | Medium |
| O15.2 | OTAs/Minicamps | Pre-season activities | Missing | Nice-to-Have | Small |
| O15.3 | Coaching Changes | Hiring season | Missing | HIGH | Large |
| O15.4 | Free Agency Period | Legal tampering, signing period | Partial | Important | Medium |
| O15.5 | Retirement Announcements | Public declarations | Partial | Nice-to-Have | Small |
| O15.6 | Award Ceremonies | Public events | Missing | Nice-to-Have | Small |
| O15.7 | Rookie Minicamp | Drafted player integration | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Integration Point**: Extend calendar phases in `calendar.json`
- **Impact**: Mostly narrative (minimal gameplay impact)
- **Priority**: DEFERRED until core features (games, stats, awards) implemented

---

### Category 16: Special Teams
**Current State**: Minimal kicker/punter presence
**Impact on Realism**: LOW - Often overlooked but present

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| ST16.1 | Field Goal Stats | FG success rates, distance records | Missing | Nice-to-Have | Medium |
| ST16.2 | Punt Stats | Punting average, touchbacks | Missing | Nice-to-Have | Medium |
| ST16.3 | Return Game | Kick/punt return yards, TDs | Missing | Nice-to-Have | Medium |
| ST16.4 | Special Teams Aces | Coverage unit specialists | Missing | Nice-to-Have | Small |
| ST16.5 | Special Teams Coordinator | Coaching specialization | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Integration Point**: Part of game simulation (G1.x) and stats system (S2.x)
- **Priority**: LOW (less visible than offensive/defensive stats)

---

### Category 17: Rules & Meta
**Current State**: Static rule system
**Impact on Realism**: LOW - Rule changes are infrequent

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| R17.1 | Rule Changes | Evolving gameplay rules | Missing | Nice-to-Have | Large |
| R17.2 | Officiating Variance | Crew-to-crew differences | Missing | Nice-to-Have | Medium |
| R17.3 | Weather Effects | Impact on game outcomes | Missing | Nice-to-Have | Medium |
| R17.4 | Home Field Advantage | Stadium-specific modifiers | Partial | Important | Small |
| R17.5 | Altitude Effects | Denver, Mexico City impacts | Missing | Nice-to-Have | Small |

**Architecture Notes**:
- **Integration Point**: Game simulation modifiers (part of `GameSimulator`)
- **Priority**: DEFERRED until game simulation (G1.x) implemented

---

### Category 18: Legacy & Dynasty Building
**Current State**: No long-term narrative tracking
**Impact on Realism**: MEDIUM - Defines simulation goals

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| L18.1 | Dynasty Detection | Sustained success tracking | Missing | Important | Medium |
| L18.2 | Hall of Fame | Player/coach legacy | Missing | Important | Large |
| L18.3 | All-Time Great Teams | Historic team comparisons | Missing | Nice-to-Have | Medium |
| L18.4 | Cursed Franchises | Sustained failure narratives | Missing | Nice-to-Have | Small |
| L18.5 | Generational Talents | Once-in-a-generation players | Missing | Nice-to-Have | Medium |
| L18.6 | Legacy Points | Quantified historical impact | Missing | Nice-to-Have | Large |

**Architecture Notes**:
- **Integration Point**: Post-simulation analysis, historical aggregation
- **Storage**: `world_state["legacies"]` with dynasty periods, HOF inductees
- **Dependency**: Requires multi-year game results (G1.x), awards (A3.x), stats (S2.x)

---

### Category 19: User Interface & Exploration
**Current State**: World Explorer exists with basic panels
**Impact on Realism**: MEDIUM - How users interact with world

| Feature ID | Feature Name | Description | Current State | Impact | Complexity |
|-----------|--------------|-------------|---------------|--------|-----------|
| U19.1 | Team History Pages | Full franchise history view | Partial | Important | Medium |
| U19.2 | Player Career Pages | Complete career stats/awards | Partial | Important | Medium |
| U19.3 | League Leaders | Statistical category leaders | Missing | Important | Small |
| U19.4 | Playoff Bracket Viz | Visual playoff tree | Missing | Important | Medium |
| U19.5 | Trade Tracker | Transaction history | Missing | Nice-to-Have | Medium |
| U19.6 | Draft Board | Visual draft results | Missing | Nice-to-Have | Medium |
| U19.7 | Season Highlights | Notable events per year | Missing | Nice-to-Have | Large |
| U19.8 | Comparison Tools | Player-to-player comparisons | Missing | Nice-to-Have | Medium |

**Architecture Notes**:
- **Current State**: World Explorer has NFL, College, HS, Draft, Retired panels
- **Missing Data**: Most features depend on missing backend data (stats, awards, game results)
- **Integration Point**: Add query methods to `WorldExplorerQueries.gd`, new panel types
- **Priority**: Deferred until backend data exists

---

## Summary Statistics

### By Impact Level

| Impact Level | Feature Count | Percentage |
|-------------|---------------|------------|
| CRITICAL | 8 | 6% |
| HIGH | 24 | 18% |
| Important | 62 | 46% |
| Nice-to-Have | 40 | 30% |
| **TOTAL** | **134** | **100%** |

### By Complexity

| Complexity | Feature Count | Percentage |
|-----------|---------------|------------|
| Small | 42 | 31% |
| Medium | 59 | 44% |
| Large | 33 | 25% |
| **TOTAL** | **134** | **100%** |

### Priority Quadrants (Impact × Complexity)

| Quadrant | Description | Count | Examples |
|----------|-------------|-------|----------|
| **High Impact + Low Complexity** | Quick wins | 12 | G1.2 (W-L records), A3.4 (Pro Bowl), H4.2 (Championships) |
| **High Impact + High Complexity** | Strategic investments | 20 | G1.1 (Game simulation), S2.3 (Position stats), C7.1 (Coaching) |
| **Low Impact + Low Complexity** | Easy additions | 30 | H4.6 (Droughts), B8.6 (Captains), O15.5 (Retirements) |
| **Low Impact + High Complexity** | Defer/skip | 13 | F9.1 (Revenue), I10.1 (Facilities), S14.1 (Fog of war) |

---

## Critical Path Analysis

### Foundational Features (Must Have First)
These features unlock other features and must be prioritized:

1. **G1.1 - Game Simulation**: Unlocks standings, playoffs, records
2. **G1.2 - Season W-L Records**: Required for all historical tracking
3. **S2.1 - Career Stat Totals**: Foundation for awards, legacy, player value
4. **A3.x - Award Systems**: Depends on stats, drives narratives
5. **C7.1 - Coaching System**: Affects development, recruiting, team identity

### Blocked Features (Cannot Implement Yet)
These features depend on missing foundational systems:

- **All Category 3 (Awards)**: Blocked by missing stats (S2.x)
- **All Category 4 (Team History)**: Blocked by missing game results (G1.x)
- **Category 5 (Draft Tracking)**: Blocked by missing historical storage
- **Category 11 (Scheduling)**: Blocked by missing game simulation (G1.1)
- **Category 18 (Legacy)**: Blocked by missing stats, awards, game results

---

## Architecture Impact Assessment

### World State Schema Changes Required

**New Top-Level Keys**:
```gdscript
world_state = {
  # Existing (unchanged)
  "hs_players": [...],
  "colleges": [...],
  "college_rosters": {...},
  "nfl_teams": [...],
  "nfl_rosters": {...},
  "draft_pool": {...},

  # NEW: Game Results & Season Data
  "season_records": {year: {team_id: SeasonRecord}},
  "championships": {league: {category: {year: winner_id}}},
  "playoff_brackets": {year: {league: BracketStructure}},

  # NEW: Player Statistics
  "player_career_stats": {player_id: {year: StatLine}},
  "stat_leaders": {year: {category: [player_ids]}},

  # NEW: Awards
  "awards": {year: {award_type: winner_id}},

  # NEW: Team History
  "team_history": {team_id: HistoricalRecord},

  # NEW: Draft History
  "draft_history": {year: [DraftPick]},

  # NEW: Coaching
  "coaching_staff": {team_id: [Coach]},
  "coaching_history": {coach_id: CareerRecord},

  # NEW: Rankings & Reputation
  "rankings": {year: {poll_type: [team_id]}},
  "team_reputation": {team_id: ReputationScore}
}
```

**Estimated Storage Overhead**:
- Season records: 648 KB (162 teams × 200 bytes × 20 years)
- Player stats: 3-5 MB (500 active players × 300 bytes × 20 years)
- Awards: 100 KB (15 awards × 100 bytes × 20 years)
- Draft history: 300 KB (250 picks × 60 bytes × 20 years)
- Coaching: 200 KB (200 coaches × 200 bytes × 5 avg years)
- **Total: ~5-6 MB additional storage** (acceptable)

### Performance Impact Estimates

| Feature Category | Bootstrap Overhead | Per-Year Cost |
|------------------|-------------------|---------------|
| Game Simulation (G1) | 3-5% | 1.2s (21K games) |
| Player Stats (S2) | 1-2% | 0.3s (aggregation) |
| Awards (A3) | <1% | 0.1s (voting/calculation) |
| Coaching (C7) | 2-3% | 0.5s (decision-making) |
| Injuries (I6) | 2-4% | 0.8s (rolls per player) |
| **Total Estimated** | **8-15%** | **3-4s per year** |

**Current 20-year bootstrap**: ~75 seconds
**Projected with core features**: ~85-90 seconds (13-20% increase)
**Acceptable**: Yes (still under 2 minutes)

---

## Integration Complexity Assessment

### Low-Risk Integrations (Extend Existing Systems)
- **G1.2 (W-L Records)**: Add storage to existing season phases
- **S2.1 (Career Stats)**: Extend player model, aggregate in lifecycle
- **H4.x (Team History)**: Incremental counters in season phases
- **D5.1 (Draft History)**: Record draft picks in existing draft phase

### Medium-Risk Integrations (New Subsystems)
- **G1.1 (Game Simulation)**: New `GameSimulator` class, integrate into season phases
- **A3.x (Awards)**: New end-of-season awards phase
- **I6.x (Injury System)**: Extend `PlayerLifecycle` with injury checks
- **B8.x (Player Drama)**: New personality simulation phase

### High-Risk Integrations (Major Architectural Changes)
- **C7.x (Coaching System)**: Requires AI decision-making, affects multiple systems
- **F9.x (Financial System)**: New economic layer, affects contracts/cap
- **S14.x (Fog of War)**: Requires access control, UI changes, query filtering
- **P13.2 (Transfer Portal)**: New roster movement mechanics, recruiting changes

---

## Recommendations

### Phase 1: Foundation (Q1 2026)
Focus on foundational features that unblock others:
1. Implement game simulation (G1.1, G1.2, G1.3) - Already designed
2. Add basic season history (H4.1, H4.2, H4.3)
3. Implement draft history tracking (D5.1)
4. Create infrastructure for stats storage (S2.1 data model only, no population yet)

### Phase 2: Statistics & Recognition (Q2 2026)
Build on game results to create narratives:
1. Populate player career stats (S2.1, S2.2, S2.3, S2.4)
2. Implement award systems (A3.1-A3.6)
3. Add stat leaders and milestones (S2.7, S2.8)
4. Enhance team history (H4.4, H4.5)

### Phase 3: Depth & Drama (Q3 2026)
Add systems that create compelling stories:
1. Implement injury system (I6.1-I6.4)
2. Add coaching framework (C7.1, C7.4, C7.5, C7.6)
3. Introduce player drama (B8.1, B8.2, B8.4)
4. Add dynasty tracking (L18.1, L18.2)

### Phase 4: Polish & Completeness (Q4 2026+)
Fill remaining gaps:
1. Complete coaching system (C7.2, C7.3, C7.7-C7.12)
2. Add conference/scheduling complexity (S11.x)
3. Implement facilities (I10.x) if justified
4. Enhance UI with missing visualizations (U19.x)

---

## Document Control

**Version History**:
- 1.0 (2026-01-11): Initial comprehensive audit

**Related Documents**:
- `/docs/analysis/FEATURE_PRIORITY_MATRIX.md` - Impact vs complexity analysis
- `/docs/analysis/REALISM_REQUIREMENTS.md` - MVP vs enhanced tiers
- `/docs/planning/FEATURE_ROADMAP.md` - Phased implementation plan
- `/docs/planning/QUICK_WINS_LIST.md` - High-impact, low-complexity features

**Review Cycle**: Quarterly (reassess priorities as features are implemented)

---

**Next Steps**:
1. Prioritize features using impact/complexity matrix
2. Define MVP requirements for "playable" vs "realistic"
3. Create implementation roadmap with dependencies
4. Identify quick wins for immediate value
