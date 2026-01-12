# Feature Priority Matrix - Impact vs Complexity

**Document Version**: 1.0
**Date**: 2026-01-11
**Author**: Architecture Guardian
**Purpose**: Prioritize 134 missing features by impact/complexity for optimal development ROI

---

## Executive Summary

This document organizes all 134 missing features (from `MISSING_FEATURES_AUDIT.md`) into four priority quadrants:

1. **HIGH IMPACT + LOW COMPLEXITY**: Quick wins with immediate realism boost
2. **HIGH IMPACT + HIGH COMPLEXITY**: Strategic investments requiring careful planning
3. **LOW IMPACT + LOW COMPLEXITY**: Easy additions for completeness
4. **LOW IMPACT + HIGH COMPLEXITY**: Defer or skip (poor ROI)

**Key Insight**: Focus on **Quadrant 1 (Quick Wins)** first to rapidly increase realism, then tackle **Quadrant 2 (Strategic Investments)** with proper design and phasing.

---

## Quadrant Definitions

### Impact Levels
- **CRITICAL**: System cannot feel realistic without this (blocks other features)
- **HIGH**: Massively improves realism, creates important narratives
- **Important**: Noticeable improvement, expected by users
- **Nice-to-Have**: Polish and depth, not essential

### Complexity Levels
- **Small**: <5 days implementation, low risk, extends existing systems
- **Medium**: 5-15 days, moderate risk, new subsystem or significant integration
- **Large**: 15+ days, high risk, major architectural changes or AI systems

---

## Quadrant 1: HIGH IMPACT + LOW/MEDIUM COMPLEXITY
**Priority**: IMMEDIATE - Implement in Phase 1-2
**Count**: 18 features
**Expected ROI**: Highest (big realism gains for reasonable effort)

| Feature ID | Feature Name | Impact | Complexity | Days Est. | Dependencies |
|-----------|--------------|--------|-----------|-----------|--------------|
| **G1.2** | Season W-L Records | CRITICAL | Small | 2 | G1.1 |
| **G1.5** | Championship Tracking | CRITICAL | Small | 2 | G1.2 |
| **G1.8** | Strength of Schedule | Important | Small | 3 | G1.2 |
| **A3.4** | Pro Bowl Selections | HIGH | Small | 4 | S2.1 |
| **H4.1** | Franchise Win Totals | Important | Small | 2 | G1.2 |
| **H4.2** | Championship History | Important | Small | 2 | G1.5 |
| **H4.3** | Playoff Appearance Count | Important | Small | 2 | G1.4 |
| **H4.6** | Drought Tracking | Important | Small | 1 | H4.2 |
| **D5.1** | Draft History | Important | Small | 3 | None |
| **D5.5** | Draft Pick Trades | Important | Small | 3 | D5.1 |
| **I6.5** | Injury-Prone Trait | Important | Small | 2 | None |
| **B8.5** | Retirement Decisions | Important | Small | 3 | None |
| **P13.1** | Early Draft Entry | HIGH | Small | 4 | Partial exist |
| **S14.3** | Combine Measurements | Important | Small | 2 | Partial exist |
| **A3.2** | Offensive/Defensive POY | HIGH | Medium | 6 | S2.1 |
| **A3.3** | All-Pro Teams | HIGH | Medium | 6 | S2.1 |
| **A3.8** | Rookie of the Year | Important | Medium | 5 | S2.1 |
| **H4.4** | Winning Streaks | Important | Small | 2 | G1.2 |

**Total Estimated Days**: 54 days (~11 weeks)

**Implementation Strategy**:
1. **Week 1-2**: Game simulation (G1.1 already designed) + W-L records (G1.2)
2. **Week 3-4**: Historical tracking (H4.1-H4.6), draft history (D5.1, D5.5)
3. **Week 5-6**: Basic player stats infrastructure (S2.1 setup)
4. **Week 7-9**: Award systems (A3.2-A3.4, A3.8)
5. **Week 10-11**: Player agency (P13.1, B8.5, I6.5)

---

## Quadrant 2: HIGH IMPACT + HIGH COMPLEXITY
**Priority**: STRATEGIC - Plan carefully, implement in Phase 2-3
**Count**: 20 features
**Expected ROI**: High (essential but requires significant effort)

| Feature ID | Feature Name | Impact | Complexity | Days Est. | Dependencies |
|-----------|--------------|--------|-----------|-----------|--------------|
| **G1.1** | Game Simulation | CRITICAL | Medium | 15 | DESIGNED |
| **G1.3** | Season Standings | CRITICAL | Medium | 8 | G1.2 |
| **G1.4** | Playoff Brackets | CRITICAL | Large | 20 | G1.3 |
| **G1.10** | Conference Championships | Important | Medium | 10 | G1.3 |
| **S2.1** | Career Stat Totals | HIGH | Medium | 12 | G1.1 |
| **S2.2** | Season Stat Lines | HIGH | Medium | 8 | S2.1 |
| **S2.3** | Position-Specific Stats | HIGH | Large | 20 | S2.2 |
| **S2.4** | Games Played/Started | HIGH | Small | 4 | S2.1 |
| **A3.1** | NFL MVP | HIGH | Medium | 8 | S2.1 |
| **A3.5** | Heisman Trophy | HIGH | Large | 15 | S2.1, S2.3 |
| **A3.6** | All-American Teams | HIGH | Medium | 8 | S2.1 |
| **A3.7** | Conference Awards | Important | Medium | 10 | S2.1, S2.3 |
| **I6.1** | Season-Ending Injuries | HIGH | Large | 20 | None |
| **I6.2** | In-Season Injuries | HIGH | Large | 18 | I6.1 |
| **C7.1** | Head Coach Hiring | HIGH | Large | 25 | None |
| **C7.4** | Development Multipliers | HIGH | Medium | 10 | C7.1 |
| **P13.2** | Transfer Portal | HIGH | Large | 20 | None |
| **M12.1** | Power Rankings | Important | Medium | 8 | G1.2 |
| **M12.3** | Team Reputation | Important | Medium | 10 | Multi-year |
| **L18.1** | Dynasty Detection | Important | Medium | 8 | Multi-year |

**Total Estimated Days**: 257 days (~51 weeks / 12 months)

**Implementation Strategy** (Phased):

### Phase 2A: Core Game Features (Months 4-6)
- Game simulation (G1.1) - ALREADY DESIGNED, just implement
- Season standings (G1.3)
- Conference championships (G1.10)
- Player stats foundation (S2.1, S2.2, S2.4)

### Phase 2B: Recognition Systems (Months 6-8)
- Award infrastructure (A3.1, A3.6, A3.7)
- Heisman/MVP voting (A3.5)
- Power rankings (M12.1)

### Phase 3A: Advanced Systems (Months 9-12)
- Injury system (I6.1, I6.2)
- Transfer portal (P13.2)
- Position-specific stats (S2.3)

### Phase 3B: Coaching & Dynasty (Months 12+)
- Coaching system (C7.1, C7.4)
- Dynasty tracking (L18.1)
- Team reputation (M12.3)

---

## Quadrant 3: LOW IMPACT + LOW/MEDIUM COMPLEXITY
**Priority**: FILL-IN - Implement when time allows
**Count**: 63 features
**Expected ROI**: Medium (easy wins for completeness, not urgent)

### Category: Stats & Records (12 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| S2.5 | Per-Game Averages | Important | Small |
| S2.6 | Career Highs | Important | Medium |
| S2.7 | Statistical Leaders | Important | Small |
| S2.8 | Statistical Milestones | Important | Medium |
| H4.7 | Team Records | Nice-to-Have | Medium |
| D5.2 | Draft Class Rankings | Important | Medium |
| D5.3 | Draft Hit Rates | Important | Medium |
| D5.4 | Prospect Rankings | Important | Medium |
| D5.8 | Draft Steals/Busts | Nice-to-Have | Medium |
| S2.11 | Postseason Stats | Nice-to-Have | Medium |
| S2.12 | Pro Bowl Stats | Nice-to-Have | Small |
| D5.9 | Combine Results | Nice-to-Have | Small |

### Category: Game Results (8 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| G1.6 | Game Scores | Important | Medium |
| G1.7 | Point Differentials | Important | Small |
| G1.11 | Head-to-Head Records | Nice-to-Have | Medium |
| G1.12 | Rivalry Tracking | Nice-to-Have | Medium |
| G1.13 | Home/Away Split | Nice-to-Have | Small |
| G1.14 | Upset Tracking | Nice-to-Have | Small |
| G1.9 | Bowl Game Selection | Important | Large |
| S11.4 | Scheduling Logic | HIGH | Large |

### Category: Player Behavior (8 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| B8.6 | Team Captains | Nice-to-Have | Small |
| B8.9 | Rivalry Feuds | Nice-to-Have | Small |
| B8.1 | Contract Holdouts | Important | Medium |
| B8.2 | Trade Demands | Important | Medium |
| B8.4 | Off-Field Problems | Important | Medium |
| B8.7 | Mentorship | Nice-to-Have | Medium |
| B8.8 | Player Morale | Nice-to-Have | Medium |
| P13.3 | Redshirt Decisions | Important | Medium |

### Category: Awards & Recognition (7 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| A3.9 | Coach of the Year | Important | Small |
| A3.10 | Position-Specific Awards | Nice-to-Have | Medium |
| A3.12 | Team MVP | Nice-to-Have | Small |
| I6.10 | Comeback Player Award | Nice-to-Have | Small |
| M12.2 | Draft Rankings | Important | Medium |
| M12.4 | Coaching Hot Seat | Important | Small |
| M12.7 | Media Buzz | Nice-to-Have | Medium |

### Category: Injury & Health (5 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| I6.3 | Game-Time Injuries | Important | Medium |
| I6.4 | Injury Reserve System | Important | Medium |
| I6.6 | Recovery Variance | Important | Medium |
| I6.7 | Permanent Stat Loss | Important | Medium |
| I6.9 | Injury History Tracking | Nice-to-Have | Small |

### Category: Coaching (6 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| C7.5 | Coaching Tenure | Important | Small |
| C7.6 | Coaching Records | Important | Small |
| C7.10 | Coaching Retirement | Nice-to-Have | Small |
| C7.12 | Coaching Ratings | Nice-to-Have | Small |
| C7.7 | Coaching Tree | Important | Medium |
| C7.11 | Coaching Mobility | Nice-to-Have | Medium |

### Category: Career Decisions (4 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| P13.4 | Graduate Transfer | Important | Medium |
| P13.5 | Position Changes | Nice-to-Have | Medium |
| P13.6 | Medical Redshirts | Nice-to-Have | Medium |
| P13.7 | Academic Ineligibility | Nice-to-Have | Medium |

### Category: Team Management (5 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| H4.5 | Dynasty Detection | Important | Medium |
| H4.8 | Retired Numbers | Nice-to-Have | Small |
| H4.9 | Ring of Honor | Nice-to-Have | Small |
| L18.3 | All-Time Great Teams | Nice-to-Have | Medium |
| L18.4 | Cursed Franchises | Nice-to-Have | Small |

### Category: Offseason (5 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| O15.2 | OTAs/Minicamps | Nice-to-Have | Small |
| O15.5 | Retirement Announcements | Nice-to-Have | Small |
| O15.6 | Award Ceremonies | Nice-to-Have | Small |
| O15.7 | Rookie Minicamp | Nice-to-Have | Small |
| O15.4 | Free Agency Period | Important | Medium |

### Category: UI & Exploration (3 features)
| Feature ID | Feature Name | Impact | Complexity |
|-----------|--------------|--------|-----------|
| U19.3 | League Leaders | Important | Small |
| U19.5 | Trade Tracker | Nice-to-Have | Medium |
| U19.8 | Comparison Tools | Nice-to-Have | Medium |

**Total Quadrant 3**: 63 features, ~300 implementation days (backlog work)

---

## Quadrant 4: LOW IMPACT + HIGH COMPLEXITY
**Priority**: DEFER OR SKIP - Poor ROI, reevaluate later
**Count**: 33 features
**Expected ROI**: Low (high effort for minimal realism gain)

### Financial Systems (8 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| F9.1 | Team Revenue | Important | Large | Cap compliance more important than revenue modeling |
| F9.2 | Operating Costs | Important | Large | Not player-facing, minimal narrative value |
| F9.3 | Revenue Sharing | Important | Medium | Complex economic modeling, low visibility |
| F9.4 | Budget Constraints | Important | Large | Salary cap already handles spending constraints |
| F9.5 | Facility Investments | Nice-to-Have | Large | See I10.x facilities |
| F9.6 | Luxury Tax | Nice-to-Have | Medium | NFL has hard cap, not needed |
| F9.7 | Revenue Projections | Nice-to-Have | Large | Management sim feature, not narrative |
| F9.8 | Bankruptcy Risk | Nice-to-Have | Large | Edge case, unrealistic in modern NFL/college |

**Decision**: Skip financial modeling beyond existing salary cap. Focus on gameplay.

### Facilities & Infrastructure (6 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| I10.1 | Training Facilities | Nice-to-Have | Large | Marginal multiplier, invisible to user |
| I10.2 | Stadiums | Nice-to-Have | Medium | Home advantage already exists |
| I10.3 | Medical Facilities | Nice-to-Have | Large | Injury recovery complexity not justified |
| I10.4 | Facility Upgrades | Nice-to-Have | Large | Management sim feature, low narrative value |
| I10.5 | Practice Fields | Nice-to-Have | Small | No visible impact |
| I10.6 | Academic Centers | Nice-to-Have | Medium | Development already handled |

**Decision**: Facilities add minimal realism for significant complexity. Skip unless user-requested.

### Coaching (Advanced) (4 features) - PARTIAL DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| C7.2 | Coaching Staff | HIGH | Large | Full staff = positional coach AI, excessive |
| C7.3 | Coaching Philosophy | HIGH | Large | Scheme fit requires play-by-play game engine |
| C7.8 | Recruiting Impact | Important | Medium | May reconsider if coaching (C7.1) successful |
| C7.9 | Coaching Contracts | Nice-to-Have | Medium | Hiring/firing more important than contracts |

**Decision**: Implement basic coaching (C7.1, C7.4-C7.6), defer advanced features until justified.

### Player Behavior (Advanced) (3 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| B8.3 | Locker Room Issues | Important | Large | Chemistry simulation = entire subsystem |
| B8.10 | Social Media Presence | Nice-to-Have | Large | Modern feature, not core football sim |
| S14.1 | Fog of War | Important | Large | Player control feature, not sim-first |

**Decision**: Keep players deterministic, avoid complex personality AI for now.

### Scouting (Advanced) (4 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| S14.2 | Scouting Reports | Important | Large | UI overhaul, access control system |
| S14.4 | Pro Day Results | Nice-to-Have | Medium | Combine already exists, redundant |
| S14.5 | Background Checks | Nice-to-Have | Medium | Character eval = personality system |
| S14.6 | Draft Grade Uncertainty | Important | Medium | Evaluation already has scout skill variance |
| S14.7 | Injury Reports | Nice-to-Have | Medium | Information hiding layer, low priority |

**Decision**: Existing scout system sufficient, defer information hiding until player control added.

### Conference & Scheduling (Advanced) (4 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| S11.1 | Conference Realignment | Important | Large | Historical events, hard to simulate realistically |
| S11.2 | TV Deals | Important | Large | Financial system dependency (F9.x) |
| S11.5 | Rivalry Protection | Nice-to-Have | Medium | Phase 2 of scheduling (G1.x Phase 2) |
| S11.6 | Cross-Division Games | Nice-to-Have | Medium | Phase 2 of scheduling |

**Decision**: Basic scheduling in Phase 1, advanced scheduling in Phase 2 of game simulation.

### Special Teams (5 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| ST16.1 | Field Goal Stats | Nice-to-Have | Medium | Requires per-play simulation |
| ST16.2 | Punt Stats | Nice-to-Have | Medium | Requires per-play simulation |
| ST16.3 | Return Game | Nice-to-Have | Medium | Requires per-play simulation |
| ST16.4 | Special Teams Aces | Nice-to-Have | Small | Depth role, low visibility |
| ST16.5 | Special Teams Coordinator | Nice-to-Have | Small | Coaching subsystem expansion |

**Decision**: Special teams stats require play-by-play engine. Skip unless game detail increases.

### Rules & Meta (3 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| R17.1 | Rule Changes | Nice-to-Have | Large | Historical events, hard to model impact |
| R17.2 | Officiating Variance | Nice-to-Have | Medium | Marginal impact, user won't notice |
| R17.3 | Weather Effects | Nice-to-Have | Medium | Game modifier, low priority vs core features |
| R17.5 | Altitude Effects | Nice-to-Have | Small | Edge case (Denver only) |

**Decision**: Static rule system acceptable. Focus on gameplay before meta-game.

### Offseason (Advanced) (1 feature) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| O15.1 | Training Camp | Nice-to-Have | Medium | Requires position battle AI |

**Decision**: Roster finalization sufficient, camp battles add little value.

### UI (Advanced) (4 features) - DEFER UNTIL DATA EXISTS
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| U19.1 | Team History Pages | Important | Medium | Blocked by missing historical data |
| U19.2 | Player Career Pages | Important | Medium | Blocked by missing stats/awards |
| U19.4 | Playoff Bracket Viz | Important | Medium | Blocked by missing playoff system |
| U19.6 | Draft Board | Nice-to-Have | Medium | Blocked by missing draft history |
| U19.7 | Season Highlights | Nice-to-Have | Large | Requires event detection system |

**Decision**: UI depends on backend data. Build data layer first, then enhance UI.

### Legacy (Advanced) (2 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| L18.2 | Hall of Fame | Important | Large | Requires voting system, career evaluation AI |
| L18.5 | Generational Talents | Nice-to-Have | Medium | Narrative layer, not core simulation |
| L18.6 | Legacy Points | Nice-to-Have | Large | Quantification system, unclear value |

**Decision**: Dynasty detection (L18.1) sufficient for legacy. Skip advanced features.

### Compensatory & Supplemental (2 features) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| D5.6 | Compensatory Picks | Nice-to-Have | Large | Complex NFL formula, edge case |
| D5.7 | Supplemental Draft | Nice-to-Have | Medium | Rare event, low ROI |

**Decision**: Standard draft sufficient. Skip edge case mechanics.

### Historical Storage (1 feature) - DEFER
| Feature ID | Feature Name | Impact | Complexity | Rationale for Deferral |
|-----------|--------------|--------|-----------|----------------------|
| H4.10 | Historical Rosters | Nice-to-Have | Large | Memory intensive, marginal value |

**Decision**: Store results/stats, not full roster snapshots.

**Total Quadrant 4**: 33 features, ~600+ implementation days (DO NOT BUILD)

---

## Priority Matrix Visualization

```
HIGH IMPACT
    │
    │  ┌─────────────────────┬─────────────────────┐
    │  │   QUADRANT 1        │   QUADRANT 2        │
    │  │   Quick Wins        │   Strategic         │
    │  │                     │   Investments       │
    │  │   18 features       │   20 features       │
    │  │   ~54 days          │   ~257 days         │
    │  │                     │                     │
    │  │   DO FIRST          │   PLAN CAREFULLY    │
    │  │                     │                     │
────┼──┼─────────────────────┼─────────────────────┼────
    │  │   QUADRANT 3        │   QUADRANT 4        │
    │  │   Fill-In           │   Defer/Skip        │
    │  │                     │                     │
    │  │   63 features       │   33 features       │
    │  │   ~300 days         │   ~600+ days        │
    │  │                     │                     │
    │  │   BACKLOG           │   DO NOT BUILD      │
    │  │                     │                     │
    └──┴─────────────────────┴─────────────────────┘
LOW IMPACT       LOW COMPLEXITY           HIGH COMPLEXITY
```

---

## Development Sequencing

### Phase 1: Foundation (Weeks 1-11, ~54 days)
**Focus**: Quadrant 1 - Quick wins that unblock other features

**Week 1-2**: Game Simulation Foundation
- G1.1: Game simulation (ALREADY DESIGNED)
- G1.2: Season W-L records
- G1.5: Championship tracking

**Week 3-4**: Historical Tracking
- H4.1: Franchise win totals
- H4.2: Championship history
- H4.3: Playoff appearance count
- H4.4: Winning streaks
- H4.6: Drought tracking
- D5.1: Draft history
- D5.5: Draft pick trades

**Week 5-6**: Player Stats Infrastructure
- S2.1: Career stat totals (data model + storage)
- S2.4: Games played/started

**Week 7-9**: Award Systems
- A3.2: Offensive/Defensive POY
- A3.3: All-Pro teams
- A3.4: Pro Bowl selections
- A3.8: Rookie of the Year

**Week 10-11**: Player Agency
- P13.1: Early draft entry (enhance existing)
- B8.5: Retirement decisions (enhance existing)
- I6.5: Injury-prone trait
- S14.3: Combine measurements

**Deliverable**: Realistic 20-year simulation with game results, basic stats, awards, historical tracking.

---

### Phase 2: Core Gameplay (Months 4-8, ~120 days)
**Focus**: Quadrant 2 (Part 1) - Essential gameplay systems

**Months 4-5**: Standings & Playoffs
- G1.3: Season standings
- G1.4: Playoff brackets
- G1.10: Conference championships

**Months 5-6**: Player Statistics
- S2.2: Season stat lines
- S2.3: Position-specific stats
- S2.5: Per-game averages (Q3)
- S2.7: Statistical leaders (Q3)

**Months 6-7**: Major Awards
- A3.1: NFL MVP
- A3.5: Heisman Trophy
- A3.6: All-American teams
- A3.7: Conference awards

**Month 8**: Power Rankings & Reputation
- M12.1: Power rankings
- M12.3: Team reputation
- L18.1: Dynasty detection

**Deliverable**: Complete competitive framework with standings, playoffs, comprehensive stats, major awards.

---

### Phase 3: Depth & Drama (Months 9-15, ~137 days)
**Focus**: Quadrant 2 (Part 2) + Selected Quadrant 3 - Advanced systems

**Months 9-11**: Injury System
- I6.1: Season-ending injuries
- I6.2: In-season injuries
- I6.4: Injury reserve system (Q3)
- I6.6: Recovery variance (Q3)
- I6.7: Permanent stat loss (Q3)

**Months 11-13**: Transfer & Player Movement
- P13.2: Transfer portal
- P13.3: Redshirt decisions (Q3)
- P13.4: Graduate transfer (Q3)

**Months 13-15**: Coaching System
- C7.1: Head coach hiring
- C7.4: Development multipliers
- C7.5: Coaching tenure (Q3)
- C7.6: Coaching records (Q3)
- C7.7: Coaching tree (Q3)

**Deliverable**: Dynamic rosters with injuries, transfers, coaching changes creating multi-year narratives.

---

### Phase 4: Completeness (Months 16+, ongoing)
**Focus**: Quadrant 3 - Fill remaining gaps, polish, optimize

**Backlog Work** (prioritize by user feedback):
- Game scoring (G1.6, G1.7)
- Player behavior drama (B8.1, B8.2, B8.4)
- Additional awards (A3.9, A3.10)
- Draft analysis (D5.2, D5.3, D5.4)
- Statistical milestones (S2.6, S2.8)
- UI enhancements (U19.3, U19.5)

**Continuous**:
- Performance optimization
- Bug fixes
- User-requested features

**Deliverable**: Polished, feature-complete simulation.

---

## ROI Analysis

### Quick Wins (Quadrant 1)
- **Investment**: 54 days (~2.5 months)
- **Realism Gain**: 60% (from "roster generator" to "has season outcomes")
- **ROI**: 11.1% realism per day
- **Unblocks**: 40+ features dependent on game results/stats

### Strategic Investments (Quadrant 2)
- **Investment**: 257 days (~12 months)
- **Realism Gain**: 35% (from "has outcomes" to "feels authentic")
- **ROI**: 1.4% realism per day
- **Unblocks**: 20+ features dependent on advanced systems

### Fill-In Work (Quadrant 3)
- **Investment**: 300 days (~14 months)
- **Realism Gain**: 5% (polish and completeness)
- **ROI**: 0.17% realism per day
- **Unblocks**: Nothing (self-contained features)

### Deferred Work (Quadrant 4)
- **Investment**: 600+ days (~28 months)
- **Realism Gain**: <1% (marginal edge cases)
- **ROI**: <0.01% realism per day
- **Unblocks**: Nothing (poor architectural fit)

**Conclusion**: Focus resources on Quadrants 1 and 2. Quadrant 3 is backlog filler. Quadrant 4 should remain unimplemented unless user demand emerges.

---

## Feature Dependencies (Critical Path)

### Tier 0: Foundation (No dependencies)
- G1.1: Game simulation (DESIGNED, ready to implement)
- D5.1: Draft history
- I6.5: Injury-prone trait
- B8.5: Retirement decisions
- P13.1: Early draft entry

### Tier 1: Depends on Game Simulation
- G1.2: Season W-L records → depends on G1.1
- G1.3: Season standings → depends on G1.2
- G1.5: Championship tracking → depends on G1.2
- G1.8: Strength of schedule → depends on G1.2
- All H4.x (Team history) → depends on G1.2
- M12.1: Power rankings → depends on G1.2

### Tier 2: Depends on Stats
- S2.1: Career stat totals → depends on G1.1 (accumulate during games)
- S2.2: Season stat lines → depends on S2.1
- S2.3: Position-specific stats → depends on S2.2
- All S2.x (Advanced stats) → depends on S2.1-S2.3

### Tier 3: Depends on Stats + Game Results
- All A3.x (Awards) → depends on S2.1+ and G1.2+
- D5.2-D5.4: Draft analysis → depends on S2.1+
- L18.1: Dynasty detection → depends on G1.2+ (multi-year)

### Tier 4: Depends on Advanced Systems
- C7.4: Development multipliers → depends on C7.1 (coaching hired)
- I6.2: In-season injuries → depends on I6.1 (injury system base)
- P13.2: Transfer portal → depends on P13.1 (eligibility system)

**Critical Path**: G1.1 (game sim) → G1.2 (W-L) → S2.1 (stats) → A3.x (awards) → Everything else

---

## Risk Assessment

### High-Risk Features (Potential Architectural Issues)
| Feature ID | Risk | Mitigation |
|-----------|------|------------|
| G1.1 | Performance regression (21K games) | Already designed with <5% target |
| S2.3 | Memory explosion (detailed stats) | Aggregate only, skip per-game logs |
| I6.1/I6.2 | Determinism violation (injury rolls) | Explicit RNG patterns, seed derivation |
| C7.1 | AI decision-making complexity | Rule-based hiring, avoid full AI coaching |
| P13.2 | Transfer logic complexity | Simple eligibility rules, avoid complex AI |

### Medium-Risk Features
| Feature ID | Risk | Mitigation |
|-----------|------|------------|
| G1.4 | Playoff bracket logic bugs | Comprehensive test suite, validate seeding |
| A3.5 | Heisman voting realism | Formula-based initially, tune parameters |
| L18.1 | Dynasty detection accuracy | Simple threshold (3+ titles in 5 years) |

### Low-Risk Features
- All Quadrant 1 features (extend existing systems)
- Historical tracking (H4.x) - simple counters
- Draft history (D5.1) - record keeping only

---

## Success Metrics

### Phase 1 Success Criteria
- [ ] 20-year bootstrap completes with season records for all teams
- [ ] Every team has W-L record for all 20 seasons
- [ ] Championships tracked for college and NFL
- [ ] Draft history persisted (all picks, all years)
- [ ] At least 3 award types functional (MVP, OPOY, DPOY)
- [ ] Bootstrap time <90 seconds (vs 75s baseline = <20% increase)
- [ ] World state size <200 MB (vs current ~150 MB)

### Phase 2 Success Criteria
- [ ] Playoff brackets generated for all years
- [ ] Player career stats populated (>500 players with 3+ years)
- [ ] Heisman Trophy awarded realistically (winner has elite stats)
- [ ] Dynasty detection identifies successful teams (3+ titles in 5 years)
- [ ] Bootstrap time <120 seconds (<60% increase from baseline)

### Phase 3 Success Criteria
- [ ] Injuries affect roster composition (IR lists, missing players)
- [ ] Transfer portal creates roster movement (>50 transfers per year)
- [ ] Coaching changes occur based on performance (<4 wins = fired)
- [ ] Multi-year narratives visible (dynasties, coaching tenures, injuries)

---

## Recommendations

### Immediate Actions (Week 1)
1. Implement G1.1 (game simulation) - design already complete
2. Add G1.2 (W-L records) storage to world state
3. Create H4.1/H4.2 (team history) storage structures
4. Set up D5.1 (draft history) persistence

### Month 1 Goals
- Complete all Quadrant 1 features
- Validate bootstrap performance (<90s for 20 years)
- Demonstrate realistic season outcomes (home win rate 55-65%)

### Quarter 1 Goals
- Complete Phase 1 (Quadrant 1)
- Begin Phase 2 (G1.3, G1.4, S2.1-S2.3)
- Achieve 60% realism improvement over baseline

### Year 1 Goals
- Complete Phases 1-2 (Quadrants 1 and 2A)
- Achieve 80% realism improvement
- Bootstrap time <120 seconds
- Begin Phase 3 (advanced systems)

---

## Document Control

**Version History**:
- 1.0 (2026-01-11): Initial priority matrix

**Related Documents**:
- `/docs/analysis/MISSING_FEATURES_AUDIT.md` - Complete feature list
- `/docs/analysis/REALISM_REQUIREMENTS.md` - MVP vs enhanced definitions
- `/docs/planning/FEATURE_ROADMAP.md` - Detailed implementation plan
- `/docs/planning/QUICK_WINS_LIST.md` - Quadrant 1 feature details

**Review Cycle**: Monthly (reassess priorities based on implementation progress)

---

**Next Action**: Review with team, approve Phase 1 feature list, begin implementation of G1.1 (game simulation).
