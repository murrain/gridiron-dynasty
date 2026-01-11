# Player Lifecycle Guide

**Comprehensive guide to how players are generated and progress through Gridiron Dynasty**

**Version**: 1.0
**Last Updated**: 2026-01-11
**Target Audience**: New contributors and developers

---

## Table of Contents

1. [Overview](#overview)
2. [High School Generation](#high-school-generation)
3. [College Recruiting](#college-recruiting)
4. [College Player Lifecycle](#college-player-lifecycle)
5. [NFL Draft](#nfl-draft)
6. [NFL Player Lifecycle](#nfl-player-lifecycle)
7. [Player Development System](#player-development-system)
8. [Complete Pipeline Flow](#complete-pipeline-flow)
9. [Technical Reference](#technical-reference)

---

## Overview

Gridiron Dynasty simulates a complete player pipeline from high school through professional football. Players are procedurally generated, develop over time, and eventually retire. The system is designed to be deterministic (same seed produces identical results) and realistic (modeling actual football career progressions).

### The Three Leagues

```
High School (HS)
    ↓ Recruiting
College (FBS)
    ↓ Draft
NFL
    ↓ Retirement
Retired Players Pool
```

### Key Statistics

- **High School Generation**: 2,000 players per year (configurable)
- **College Programs**: 130 FBS schools
- **College Roster Size**: 85 players per team (75-105 range)
- **NFL Teams**: 32 teams
- **NFL Roster Size**: 84 players per team (53 active + 16 practice squad + 15 IR)
- **Draft Rounds**: 7 rounds, 224 total picks

---

## High School Generation

### Generation Process

Each year, a new class of high school players is generated using the `DraftClassGenerator` system. This happens in the `hs_generation` phase of the world simulation.

**Location**: `scripts/pipelines/AdvanceWorldYear.gd` (lines 147-187)

```gdscript
var generator := DraftClassGenerator.new()
var players := generator.generate_for_year(year, step_seeds["hs_player_gen"])
```

### Class Size and Configuration

**Default Generation**: 2,000 players per year

**Configuration**: `configs/sports/american_football/main.json`
```json
"class_rules": {
    "class_size": 2000,
    "gaussian_share": 0.75
}
```

The `gaussian_share` parameter (75%) determines how many players have normally-distributed attributes versus uniform distribution, creating a realistic bell curve of talent.

### Attribute Generation

Each high school player is generated with:

1. **Physical Attributes** (`PhysicalsHelper.roll_for_position`)
   - Height, weight, body type
   - Position-specific ranges (e.g., OL are bigger than WR)

2. **Statistical Attributes** (`StatsHelper.roll_all`)
   - 40+ stats covering speed, strength, agility, technique, mental abilities
   - Rolled using gaussian or uniform distribution
   - Position-specific stat priorities

3. **Core Stats** (40-yard dash, bench press, vertical jump, etc.)
   - Generated based on physical attributes
   - Used for combine simulation

4. **Metadata**
   - Name (randomized from name database)
   - Position (weighted by roster needs)
   - Age (14-18 for high school)
   - Class year (freshman/sophomore/junior/senior)
   - Draft year (when they'll be college seniors)

**Code Reference**: `scripts/generation/PlayerGenerator.gd` (lines 76-90)

### Position Distribution

Position distribution is weighted to match realistic roster needs:

- **Offensive Line (OL)**: Highest percentage (~20%)
- **Defensive Line (DL)**: High percentage (~15%)
- **Wide Receiver (WR)**: High percentage (~12%)
- **Linebacker (LB)**: Medium percentage (~10%)
- **Cornerback (CB)**: Medium percentage (~10%)
- **Safety (S)**: Medium percentage (~8%)
- **Running Back (RB)**: Medium percentage (~8%)
- **Tight End (TE)**: Medium percentage (~6%)
- **Quarterback (QB)**: Low percentage (~5%)
- **Edge Rusher (EDGE)**: Medium percentage (~4%)
- **Kicker/Punter (K/P)**: Very low percentage (~2%)

**Code Reference**: `scripts/generation/helpers/PositionHelper.gd`

### Rating System

After generation, players receive overall ratings using the `RecruitRater` system:

1. **Star Ratings**: 2-star through 5-star (based on percentile)
   - 5-star: Top 0.5% of class (~10 players)
   - 4-star: Top 5% (~100 players)
   - 3-star: Top 40% (~800 players)
   - 2-star: Remaining 60% (~1,100 players)

2. **Position Rankings**: Ranked within position group

3. **Overall Rating**: 0-100 scale calculated from core stats

**Code Reference**: `scripts/core/rating/RecruitRater.gd`

### The "Freak" System

A small number of elite athletes (5-10 per class) receive athletic boosts:

- Selected from 80th-90th percentile of athleticism
- +3-7 points to speed, agility, acceleration, vertical, broad jump
- +2-5 points to strength
- Tagged as "PotentialSuperstar"
- These become franchise-level talents in the NFL

**Code Reference**: `scripts/generation/PlayerGenerator.gd` (lines 117-207)

### Geographic Distribution

Players are assigned to high schools based on regional distribution:

**Location**: `scripts/world/HighSchoolAssignment.gd`

- 50 states + DC
- Weighted by population (Texas, California, Florida have more players)
- High schools are generated with realistic names and locations

### The Four-Year Pool

High school players accumulate over 4 years of age progression:

```
Year 1: Generate 2,000 freshmen
Year 2: Generate 2,000 freshmen + age Year 1 players (total: 4,000)
Year 3: Generate 2,000 freshmen + age Year 1-2 players (total: 6,000)
Year 4: Generate 2,000 freshmen + age Year 1-3 players (total: 8,000)
Year 5+: Steady state of ~8,000 players (2,000 per grade level)
```

**Code Reference**: `scripts/pipelines/AdvanceWorldYear.gd` (lines 178-180)
```gdscript
var hs_players: Array = world_state.get("hs_players", []) as Array
hs_players.append_array(players)  # Cumulative pool
world_state["hs_players"] = hs_players
```

### High School Season

During the `hs_season` phase, players:

1. **Age by one year** (freshman → sophomore → junior → senior)
2. **Develop their skills** via `PlayerLifecycle.advance_one_year()`
3. **Graduate** when reaching senior year

**Graduation Filter**: Only players with sufficient rating are marked as college-eligible:

**Code Reference**: `scripts/pipelines/AdvanceWorldYear.gd` (lines 243-248)
```gdscript
var filtered_recruits := _filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
recruit_pool[year] = filtered_recruits
```

---

## College Recruiting

### Recruiting Pool

Each year, college-eligible high school seniors enter the recruiting pool:

**Typical Pool Size**: ~2,000-2,500 recruits per year
**College Demand**: ~2,860 recruits per year (130 colleges × 22 avg class size)

This creates healthy competition where colleges must evaluate and compete for top prospects.

### Scout Evaluation

Each college has scouts who evaluate recruits:

**Scout System**: `scripts/core/scouting/ScoutRuntime.gd`

1. **Scout Attributes**
   - Base skill (0.0-1.0): Overall evaluation accuracy
   - Overrate athletes: Tendency to overvalue speed/athleticism
   - Tape grinder: Bonus to technique evaluation
   - Risk aversion: Preference for safe picks vs high-upside players
   - Stat-specific skills: Better at evaluating certain positions

2. **Evaluation Process**
   - Scouts estimate player stats with noise/bias
   - Generate composite scores for each recruit
   - Rank recruits by projected value
   - Apply position need multipliers

3. **Caching for Performance**
   - Scout evaluations are cached per year
   - Eliminates redundant computation (130 colleges × 2,500 recruits = 325,000 evaluations)
   - Maintains determinism through seed derivation

**Code Reference**: `scripts/core/scouting/RecruitingScoreCache.gd`

### Recruiting Process

**Location**: `scripts/pipelines/CollegeRecruiting.gd`

The recruiting pipeline follows these steps:

1. **Generate Offers** (each college evaluates all recruits)
2. **Player Interest** (players rank colleges based on eliteness, distance, position need)
3. **Commitment Decisions** (players commit to highest-interest college that offered)
4. **Class Composition** (track recruiting class quality and position distribution)

### Class Size Targets

Each college has target class sizes:

**Configuration**: `configs/sports/american_football/world/colleges.json`
```json
"recruiting": {
    "class_size_min": 18,
    "class_size_max": 26
}
```

Colleges aim to recruit enough players to maintain roster size of ~85 players over a 4-year cycle.

### Eliteness and Tiers

Colleges are divided into tiers based on program quality:

- **Elite** (Top 25): Alabama, Ohio State, USC, etc.
  - Eliteness: 85-100
  - Recruit mostly 4-star and 5-star players

- **Mid** (Middle 60): Most P5 schools
  - Eliteness: 55-84
  - Recruit mostly 3-star players, some 4-star

- **Low** (Bottom 45): G5 schools
  - Eliteness: 20-54
  - Recruit mostly 2-star and 3-star players

**Code Reference**: `configs/sports/american_football/world/colleges.json`

### Recruit Decisions

Players evaluate colleges based on:

1. **Program Eliteness** (biggest factor)
2. **Distance from Home** (regional preference)
3. **Position Need** (likelihood of playing time)
4. **Playing Style Fit** (offensive/defensive scheme)

**Code Reference**: `scripts/pipelines/CollegeRecruiting.gd`

---

## College Player Lifecycle

### Four-Year Cycle

College players progress through four class years:

```
Year 1: Freshman (college_year = 1)
Year 2: Sophomore (college_year = 2)
Year 3: Junior (college_year = 3)
Year 4: Senior (college_year = 4) → Draft Eligible
```

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 119-124)
```gdscript
var old_year := int(p.get("college_year", 1))
var new_year := old_year + 1
p["college_year"] = new_year
var new_status := _eligibility_status(new_year)  // "freshman", "sophomore", "junior", "senior"
p["college_eligibility_status"] = new_status
```

### Player Development

Each college season, players undergo development via `PlayerLifecycle.advance_one_year_parallel()`:

**Development Factors**:

1. **Program Quality** (0.0-1.0)
   - Derived from college eliteness
   - Elite programs (Alabama): 0.95
   - Mid programs: 0.50-0.85
   - Low programs: 0.20-0.50

2. **Competition Tier** (multiplier)
   - Elite tier: 1.2x (playing against best talent)
   - Mid tier: 1.0x
   - Low tier: 0.9x

3. **Usage** (starter vs bench)
   - Starters: 1.2x development multiplier
   - Bench players: 0.8x development multiplier
   - Determined randomly each season (45% chance of starter)

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 188-223)

### Development Context

Before lifecycle processing, each player receives a development context:

```gdscript
var context := {
    "program_quality": 0.85,      // College eliteness / 100
    "competition_tier": 1.2,      // Tier multiplier
    "usage": 1.2,                 // Starter vs bench
    "season": "college",
    "year": 2025
}
p["development_context"] = context
```

This context influences how much each stat grows during the season.

### College Roster Management

Each college maintains:

```gdscript
{
    "players": [player1, player2, ...],  // Active roster
    "class_years": {
        1: ["player_id_1", "player_id_2"],  // Freshmen
        2: [...],  // Sophomores
        3: [...],  // Juniors
        4: [...]   // Seniors
    }
}
```

### Game Simulation

Before player development, the college season is simulated:

**Feature**: `G1.1: Game Simulation` (enabled via config)

1. **Schedule Generation**: Each college plays ~12 games
2. **Team Strength**: Calculated from roster quality
3. **Game Outcomes**: Win/loss determined by strength + randomness
4. **Player Stats**: Individual stats accumulated per game
5. **Championship**: Best record wins national title (Phase 1 simple version)

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 54-63, 442-575)

### Player Morale and Satisfaction

After the season, player morale is updated based on:

1. **Individual Performance**
   - Stats relative to position benchmarks
   - Award winners get bonus

2. **Team Success**
   - Win-loss record
   - Championship wins
   - Playoff appearances

3. **Playing Time**
   - Starters are happier than bench players

**Morale Impact**: Low morale increases transfer portal probability

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 69-76, 578-654)

### Transfer Portal

Players with low satisfaction may enter the transfer portal:

**Transfer Decision Factors**:
- Satisfaction < 50: High transfer probability
- Satisfaction 50-70: Medium transfer probability
- Satisfaction > 70: Low transfer probability

**Current Implementation**: Phase 1 tracks transfer portal entries but doesn't process transfers yet (future feature).

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 79-84, 657-710)

### Draft Eligibility

Players become draft eligible when:

1. **Seniors (Year 4+)**:
   - Must have rating >= 65 (configurable threshold)
   - Prevents low-quality players from cluttering draft pool
   - Expected: ~520 seniors declare per year (out of ~2,763 total)

2. **Juniors (Year 3)** - Early Declaration:
   - Must have rating >= 85 (elite threshold)
   - Base chance: 15%
   - Bonus per rating point above 85: +1%
   - Expected: ~100-150 early declarations per year

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 126-148, 248-272)

```gdscript
if new_year >= 4:
    // Seniors: Only declare if rating >= threshold
    var rating_threshold := 65.0
    var player_rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)
    if player_rating >= rating_threshold:
        is_draft_eligible = true
elif new_year == 3:
    // Juniors: Check early declaration
    if _check_early_declaration(p, early_decl_cfg, early_decl_rng, positions_cfg, main_cfg):
        is_draft_eligible = true
```

### Draft Pool

Draft-eligible players are stored in `world_state["draft_pool"][year]`:

**Expected Pool Size**: ~520-650 players per year
- ~400-500 seniors with rating >= 65
- ~100-150 early-declaring juniors

**Historical Context**: Before optimization, ALL seniors auto-declared (~2,900 per year), creating massive waste. The rating threshold reduces draft pool by 82%.

**Code Reference**: `scripts/world/CollegeSeason.gd` (lines 159-161)

---

## NFL Draft

### Draft Structure

The NFL draft consists of:

- **7 rounds**
- **32 picks per round** (one per team)
- **224 total picks**

**Configuration**: `configs/sports/american_football/world/league.json`
```json
"draft": {
    "rounds": 7,
    "picks_per_round": 32
}
```

**Code Reference**: `scripts/world/NflDraft.gd` (lines 42-43)

### Draft Order

Teams draft in order of draft_order (worst team picks first):

**Current Implementation**: Simple ranking (1-32)
**Future**: Will use previous season record to determine order

**Code Reference**: `scripts/world/NflDraft.gd` (lines 271-276)

### Scout Evaluation

Each NFL team has a scouting department that evaluates draft prospects:

1. **Generate Team Scouts** (one per team)
   - Based on national scout templates
   - Slight variation per team (different philosophies)

2. **Score All Prospects**
   - Uses same scout evaluation system as college recruiting
   - Cached for performance (224 × 32 × 7 = ~50,000 evaluations without cache)

3. **Apply Position Needs**
   - Calculate roster depth by position
   - Multiply base score by need multiplier (0.85x - 1.5x)

**Code Reference**: `scripts/world/NflDraft.gd` (lines 225-250, 279-331)

### Position Need Calculation

Teams prioritize positions where they're thin:

**Ideal Roster Composition**:
```
QB: 3
RB: 4
WR: 6
TE: 3
OL: 9
DL: 6
EDGE: 4
LB: 6
CB: 5
S: 4
K: 1
P: 1
```

**Need Multipliers**:
- 0 players at position: 1.5x (critical need)
- Below ideal count: 1.0-1.3x (based on deficit)
- At/above ideal: 0.85x (slight penalty)

**Code Reference**: `scripts/world/NflDraft.gd` (lines 334-367)

### Pick Selection Algorithm

For each pick:

1. **Score all remaining players** (using cached scout evaluations)
2. **Apply position need multiplier** to base score
3. **Sort by weighted score** (descending)
4. **Select highest-scoring player**
5. **Update roster** with drafted player
6. **Remove from pool**

**Code Reference**: `scripts/world/NflDraft.gd` (lines 79-149)

### Rookie Contracts

Drafted players receive 4-year rookie contracts:

**Contract Structure**:
```gdscript
{
    "type": "rookie",
    "years_total": 4,
    "years_remaining": 4,
    "base_salary": calculated,        // Based on draft position
    "signing_bonus": base_salary × (0.8 - (round - 1) × 0.1),
    "cap_hit": base_salary + (signing_bonus / 4),
    "fifth_year_option": (round == 1),  // Only 1st rounders
    "gtd_remaining": signing_bonus
}
```

**Salary Calculation**:
- 1st overall pick: ~5% of salary cap
- Exponential decay by pick number
- 7th round picks: ~0.2% of salary cap

**Code Reference**: `scripts/world/NflDraft.gd` (lines 385-426)

### Draft History Tracking

All picks are recorded in `world_state["draft_history"][year]`:

```gdscript
{
    "pick_number": 1,
    "round": 1,
    "team_id": "team_sf",
    "player_id": "player_12345",
    "position": "QB",
    "college": "college_alabama",
    "traded": false,           // Future: trade system
    "original_team_id": null   // Future: original pick owner
}
```

**Code Reference**: `scripts/world/NflDraft.gd` (lines 157-200)

### Undrafted Free Agents

Players not drafted are stored in `world_state["undrafted_pool"][year]`:

**Expected Size**: ~300-400 undrafted players
**Future Phase**: UDFA signing phase will add top ~176 undrafted players to practice squads

**Code Reference**: `scripts/world/NflDraft.gd` (lines 152-154)

---

## NFL Player Lifecycle

### Roster Structure

Each NFL team maintains an 84-player roster:

```
Active Roster:    53 players
Practice Squad:   16 players
Injured Reserve:  15 players
───────────────────────────
Total:            84 players
```

**Code Reference**: `docs/architecture/BACKWARD_CLASS_SIZING.md` (lines 11-19)

### NFL Season Progression

Each season, NFL players:

1. **Game Simulation** (before lifecycle)
   - 17-game regular season
   - Playoffs (simplified in Phase 1)
   - Super Bowl winner determined

2. **Player Development**
   - Advanced by one year via `PlayerLifecycle.advance_one_year_parallel()`
   - NFL development context applied

3. **Contract Management**
   - Years remaining decrements
   - Free agency determined

4. **Retirement Evaluation**
   - Age-based retirement probability
   - Performance-based (low rating increases chance)

**Code Reference**: `scripts/world/NflSeason.gd`

### NFL Development Context

NFL players receive maximum-quality development:

```gdscript
var context := {
    "program_quality": 1.0,     // NFL is top tier
    "competition_tier": 1.1,    // Highest competition
    "usage": 0.85-1.3,          // Based on depth chart position
    "season": "nfl",
    "year": year
}
```

**Usage Calculation**:
- Rookies (year 0): 0.85 usage (backup role)
- 2nd year: 0.95 usage (rotational)
- Veterans (4+ years): 1.1 usage (starter)
- Randomness added: ±0.1

**Code Reference**: `scripts/world/NflSeason.gd` (lines 191-236)

### Contract Expiration

Each season, player contracts decrement:

```gdscript
var years_remaining := int(contract.get("years_remaining", 0))
years_remaining = max(0, years_remaining - 1)
contract["years_remaining"] = years_remaining
```

When `years_remaining` reaches 0:
- Player becomes free agent
- Added to `world_state["free_agents"][year]`
- Removed from team roster

**Code Reference**: `scripts/world/NflSeason.gd` (lines 239-253)

### Free Agency

Players with expiring contracts enter free agency:

**Free Agent Pool**: ~1,075 players per year (assuming 2.5 year average contract length)

**Current Implementation**: Players stored in free agent pool (future: re-signing logic)

**Proposed Attrition**: Bottom 30% of free agents (rating < 55 or age 35+ with rating < 65) retire instead of re-signing.

**Code Reference**:
- `scripts/world/NflSeason.gd` (lines 134-140, 164-166)
- `docs/architecture/BACKWARD_CLASS_SIZING.md` (lines 387-425)

### Retirement System

Players can retire in two ways:

**1. Natural Retirement** (via PlayerLifecycle):
- Automatic retirement based on age and performance
- Handled internally by lifecycle system
- Players marked as retired and removed from roster

**2. NFL-Specific Retirement** (additional check):
- **Minimum Age**: 27 (config: `retirement.min_age`)
- **Soft Cap Age**: 33 (retirement probability increases)
- **Maximum Age**: 40 (forced retirement)

**Retirement Probability Formula**:
```
base_chance = 2%
if age >= soft_cap_age:
    chance += (age - soft_cap_age) × 4%
if rating < 55:
    chance += 8%
if injury_count >= 3:
    chance += 5%
```

**Expected Retirement Rates**:
- Age 27-32: ~2% per year
- Age 33: 2%
- Age 34: 6%
- Age 35: 10%
- Age 36+: 14%, 18%, 22%, etc.

**Total Retirements**: ~150-180 players per year

**Code Reference**: `scripts/world/NflSeason.gd` (lines 256-293)

### Roster Turnover

NFL rosters have high annual turnover:

```
Retirements:          ~150-180 players
Contract Expirations: ~1,075 players (70% re-sign)
Cuts:                 ~200-300 players
──────────────────────────────────────
Total Roster Churn:   ~400-500 spots per year
```

Filled by:
```
Draft Picks:      224 players
UDFA Signings:    ~176 players (future)
Free Agent Re-Signs: ~753 players
──────────────────────────────────────
Total:            ~1,153 players
```

**Code Reference**: `docs/architecture/BACKWARD_CLASS_SIZING.md` (lines 79-109)

### NFL Awards

After each season, awards are selected:

**Award Types**:
- MVP (Most Valuable Player)
- Offensive/Defensive Player of Year
- Offensive/Defensive Rookie of Year
- Coach of Year
- All-Pro Teams (1st and 2nd team)
- Pro Bowl Rosters

**Selection Criteria**: Based on player stats, team success, and position

**Code Reference**: `scripts/world/NflSeason.gd` (lines 662-665)

### Team History Tracking

Each season updates team history:

**Tracked Stats**:
- All-time wins/losses (H4.1)
- Championship count and years (H4.2)
- Playoff appearances (H4.3)
- Winning/losing streaks (H4.4)
- Years since championship (H4.6)

**Code Reference**: `scripts/world/NflSeason.gd` (lines 354-472)

---

## Player Development System

### PlayerLifecycle Overview

The core development engine is `PlayerLifecycle.advance_one_year()` and its parallel variant.

**Location**: `scripts/world/PlayerLifecycle.gd`

### Development Process

Each year, for each stat, the system:

1. **Calculate Base Growth/Decline**
   - Younger players (<25): Growth phase
   - Prime players (25-30): Maintenance phase
   - Older players (>30): Decline phase

2. **Apply Development Multipliers**
   - Program quality (0.2-1.0)
   - Competition tier (0.9-1.2)
   - Usage (0.8-1.2)

3. **Add Randomness**
   - Gaussian noise for realistic variation
   - Some players develop faster/slower than expected

4. **Apply Bounds**
   - Stats clamped to 0-100 range
   - Diminishing returns at high levels (harder to grow from 90 to 95 than 50 to 55)

### Development Curve

**Growth Phases**:
```
Age 18-22 (HS/College): Rapid growth (+5-10 points/year)
Age 23-27 (Early NFL):  Moderate growth (+2-5 points/year)
Age 28-30 (Prime):      Slow growth/maintenance (±1 point/year)
Age 31-35 (Decline):    Moderate decline (-2-5 points/year)
Age 36+ (Veteran):      Rapid decline (-5-10 points/year)
```

### Wear and Tear

Players accumulate wear over time:

**Tracked Metrics**:
```gdscript
"wear": {
    "snaps": 0,          // Total plays participated in
    "collisions": 0,     // Contact events (tackles, blocks)
    "injury_count": 0    // Number of injuries sustained
}
```

**Impact**:
- High wear increases injury probability
- Severe injuries can suppress development
- Multiple injuries accelerate decline phase

**Code Reference**: `scripts/world/PlayerLifecycle.gd`

### Potential vs Current Stats

Players have two stat sets:

1. **Current Stats** (`stats`): Their actual ability right now
2. **Potential Stats** (`potential`): Their ceiling if fully developed

**Development Trajectory**:
- Young players start with current < potential
- Development closes the gap over time
- Prime players: current ≈ potential
- Declining players: current declines, potential remains fixed

### Development Reports

Each development cycle generates a report:

```gdscript
"development_report": [
    {
        "year": 2025,
        "age": 20,
        "college_year": 2,
        "stats_before": {...},
        "stats_after": {...},
        "stat_changes": {
            "speed": +3.2,
            "strength": +2.1,
            ...
        },
        "development_context": {...}
    }
]
```

**Memory Optimization**: Reports can be skipped during bootstrap to reduce memory usage.

**Code Reference**: `scripts/world/PlayerLifecycle.gd`

---

## Complete Pipeline Flow

### Year-by-Year Simulation

Each simulation year follows this sequence:

```
1. hs_generation
   ↓ Generate 2,000 new HS players

2. hs_assignment
   ↓ Assign players to high schools by region

3. hs_season
   ↓ Age players, develop skills, identify graduates

4. college_recruiting
   ↓ Colleges evaluate and sign recruits (~2,860 players)

5. college_season
   ↓ Age players, play games, develop skills, identify draft-eligible

6. draft_prep
   ↓ Prepare draft pool (~520 players with rating >= 65)

7. nfl_draft
   ↓ 32 teams × 7 rounds = 224 picks

8. nfl_season
   ↓ Age players, play games, develop skills, handle retirements/free agency
```

**Code Reference**: `scripts/pipelines/AdvanceWorldYear.gd`

### Player Journey Example

Let's trace a single player's journey:

**Year 2020 (Age 14)**: Generated as HS Freshman
- Position: QB
- Initial rating: 68 (3-star recruit)
- Height: 6'2", Weight: 190 lbs
- Core stats: Speed 72, Arm Strength 75, Accuracy 65

**Years 2020-2023**: High School Career
- Develops each year (+5-8 points per stat)
- By senior year: Speed 85, Arm Strength 88, Accuracy 82
- Rating: 84 (4-star recruit)

**Year 2024**: College Recruiting
- Receives offers from 40+ schools
- Commits to USC (elite tier)
- Joins as freshman

**Years 2024-2027**: College Career
- Freshman: Backup QB, limited development (usage 0.8x)
- Sophomore: Starts 8 games, good development (usage 1.2x)
- Junior: Full starter, elite competition, major growth
- Senior: Final rating 91, declares for draft

**Year 2028**: NFL Draft
- Rated as top QB prospect
- 32 teams evaluate (scout scores vary by team philosophy)
- Selected 3rd overall by Indianapolis Colts
- Signs 4-year rookie contract ($8.5M/year)

**Years 2028-2031**: NFL Rookie Contract
- Year 1: Backup, learns system, minimal play (usage 0.85x)
- Year 2: Starts final 6 games, shows promise
- Year 3: Full starter, makes Pro Bowl
- Year 4: Rating peaks at 95, throws 35 TDs

**Year 2032**: Contract Expiration
- Becomes unrestricted free agent
- (Future: Re-signing or moving to new team)

**Years 2032-2038**: Prime Years
- Maintains 92-96 rating range
- Wins MVP (2034)
- Makes Super Bowl (2036)

**Years 2039-2041**: Decline Phase
- Rating drops to 88, then 84, then 79
- Considers retirement after age 37
- Retires at age 38 after 14-year career

**Total Career**: 4 years HS + 4 years college + 14 years NFL = 22-year journey

---

## Technical Reference

### Key Files

**Generation**:
- `scripts/generation/DraftClassGenerator.gd` - Main class generation
- `scripts/generation/PlayerGenerator.gd` - Individual player creation
- `scripts/generation/helpers/StatsHelper.gd` - Stat rolling algorithms
- `scripts/generation/helpers/PhysicalsHelper.gd` - Physical attribute generation

**High School**:
- `scripts/world/HighSchoolGenerator.gd` - Generate HS schools
- `scripts/world/HighSchoolAssignment.gd` - Assign players to schools
- `scripts/world/HighSchoolSeason.gd` - HS season simulation

**College**:
- `scripts/world/CollegeGenerator.gd` - Generate colleges
- `scripts/pipelines/CollegeRecruiting.gd` - Recruiting pipeline
- `scripts/world/CollegeSeason.gd` - College season simulation
- `scripts/core/scouting/ScoutRuntime.gd` - Scout evaluation system
- `scripts/core/scouting/RecruitingScoreCache.gd` - Evaluation caching

**NFL**:
- `scripts/world/NflTeamGenerator.gd` - Generate NFL teams
- `scripts/world/NflDraft.gd` - Draft simulation
- `scripts/world/NflSeason.gd` - NFL season simulation

**Player Development**:
- `scripts/world/PlayerLifecycle.gd` - Core development engine
- `scripts/support/config/DevelopmentConfig.gd` - Development parameters
- `scripts/support/config/RetirementConfig.gd` - Retirement logic

**Pipeline**:
- `scripts/pipelines/BootstrapGameWorld.gd` - Multi-year bootstrap
- `scripts/pipelines/AdvanceWorldYear.gd` - Single year orchestrator
- `scripts/world/WorldCalendar.gd` - Phase sequencing

### Configuration Files

**Main Config**: `configs/sports/american_football/main.json`
```json
{
    "starting_year": 2025,
    "random_seed": 0,
    "class_rules": {
        "class_size": 2000,
        "gaussian_share": 0.75,
        "max_freaks_per_class": 5
    },
    "retirement": {
        "min_age": 27,
        "soft_cap_age": 33,
        "max_age": 40,
        "base_chance": 0.02,
        "age_chance_per_year": 0.04
    }
}
```

**Position Config**: `configs/sports/american_football/positions.json`
- Defines all 40+ player stats
- Position-specific stat weights
- Core stats per position

**College Config**: `configs/sports/american_football/world/colleges.json`
- 130 FBS colleges
- Tier classification (elite/mid/low)
- Recruiting parameters

**NFL Config**: `configs/sports/american_football/world/league.json`
- 32 NFL teams
- Draft parameters (7 rounds)
- Salary cap settings
- Contract structures

### Optimization Strategies

**Bootstrap Optimization**:
- Year 1: Generate full NFL rosters (2,688 players)
- Years 2-20: Generate only replacements (400/year)
- Total: 10,288 players (vs 40,000 unoptimized)
- Memory savings: 119MB (74% reduction)

**Code Reference**: `docs/architecture/BACKWARD_CLASS_SIZING.md` (lines 429-461)

**Draft Pool Optimization**:
- Threshold: Only players with rating >= 65 declare
- Reduces pool from ~2,900 to ~520 (82% reduction)
- Speeds up draft processing
- Eliminates unrealistic "career backup" draftees

**Code Reference**: `docs/architecture/BACKWARD_CLASS_SIZING.md` (lines 123-163)

**Parallel Processing**:
- PlayerLifecycle uses parallel processing for rosters > 100 players
- NFL rosters: ~1,700 total players benefit from threading
- College rosters: 50-100 per school benefit from threading
- Auto-detects CPU cores for optimal thread count

**Code Reference**: `scripts/world/PlayerLifecycle.gd` (lines 97-116)

### Determinism

The simulation is fully deterministic:

**Seed Hierarchy**:
```
Base Seed (from config or parameter)
  ↓ Splitmix64 hash
Year Seed (base_seed ^ year)
  ↓ Splitmix64 hash
Phase Seed (year_seed ^ phase_id_hash)
  ↓ Splitmix64 hash
Step Seed (phase_seed ^ step_id_hash)
  ↓ Per-player seed derivation
Player Seed (master_seed + player_index)
```

**Guarantees**:
- Same base seed → identical world state across runs
- Different phases use independent RNG streams
- Parallel processing maintains determinism via seed derivation
- Timing capture doesn't affect determinism (observability is separate from execution)

**Code Reference**: `scripts/pipelines/AdvanceWorldYear.gd` (lines 87-130)

### Memory Management

**Per-Player Memory**:
- Average player dictionary: ~4KB
- Includes stats, potential, development_report, physicals, tags, wear

**World State Memory** (steady state):
```
HS Players:        8,000 × 4KB = 32MB
College Players:   11,050 × 4KB = 44MB
NFL Players:       2,688 × 4KB = 11MB
Retired Players:   Growing pool (cleared periodically)
────────────────────────────────────
Total Active:      ~87MB player data
```

**Bootstrap Memory** (20-year simulation):
- Unoptimized: 40,000 players × 4KB = 160MB
- Optimized: 10,288 players × 4KB = 41MB
- Savings: 119MB (74% reduction)

---

## Future Enhancements

### Planned Features

**Transfer Portal System**:
- Players with low satisfaction can transfer
- Receive offers from new schools
- Re-recruiting process

**UDFA Signing Phase**:
- Top ~176 undrafted players sign to practice squads
- Bottom players exit football

**Free Agency System**:
- Contract negotiations
- Free agent signings
- Salary cap management

**Redshirt System**:
- College players can redshirt (sit out year, preserve eligibility)
- Extends career to 5 years instead of 4

**Draft Trades**:
- Teams can trade draft picks
- Track original pick owner
- Affects draft order

**Injuries**:
- Players can suffer injuries during games
- Injury duration (games/weeks missed)
- Long-term impact on career

**Coaching System**:
- Coaches affect development quality
- Recruiting prowess
- Game strategy

---

## Glossary

**Class**: A cohort of players generated in the same year (e.g., "Class of 2025")

**Draft Eligible**: College players who declare for the NFL draft (seniors with rating >= 65, or elite juniors)

**Eliteness**: A 0-100 rating of college program quality (affects recruiting and development)

**Freak**: Elite athlete with exceptional physical attributes (speed, agility, strength)

**Gaussian Share**: Percentage of players with normally-distributed stats (creates realistic bell curve)

**Lifecycle**: The annual process of aging, developing, and retiring players

**Position Need**: How much a team needs players at a specific position (affects draft priorities)

**Potential**: A player's maximum possible stat values if fully developed

**Scout**: An AI agent that evaluates players with bias and noise (simulates real scouting imperfections)

**Star Rating**: 2-5 star rating system for high school recruits (based on percentile)

**Tier**: College classification (elite/mid/low) based on program quality

**UDFA**: Undrafted Free Agent (player not selected in draft but signs with team)

**Usage**: Playing time multiplier (starters get 1.2x, bench players get 0.8x)

**Wear**: Accumulated physical damage from snaps, collisions, and injuries

---

## Conclusion

Gridiron Dynasty's player lifecycle system creates a realistic, deterministic simulation of football careers from high school through retirement. The system balances realism (proper roster sizes, realistic development curves) with performance (optimized generation, parallel processing, evaluation caching).

Key design principles:

1. **Determinism**: Same seed always produces identical results
2. **Realism**: Models actual football career progressions and roster needs
3. **Performance**: Optimized to handle 20+ years of simulation efficiently
4. **Modularity**: Clean separation between generation, development, and management
5. **Observability**: Rich tracking of stats, history, and player journeys

For new contributors, the best starting points are:

- **Understanding generation**: `scripts/generation/PlayerGenerator.gd`
- **Understanding development**: `scripts/world/PlayerLifecycle.gd`
- **Understanding pipeline flow**: `scripts/pipelines/AdvanceWorldYear.gd`
- **Understanding optimization strategies**: `docs/architecture/BACKWARD_CLASS_SIZING.md`

The system is designed to be extended with new features (transfers, free agency, injuries) while maintaining backward compatibility and deterministic behavior.
