# World State & Simulation Pipeline Guide

**Version**: 1.0
**Date**: 2026-01-11
**Target Audience**: New contributors understanding core simulation architecture
**Estimated Reading Time**: 25-30 minutes

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [World State Architecture](#world-state-architecture)
3. [World Bootstrap Process](#world-bootstrap-process)
4. [Season Simulation Pipeline](#season-simulation-pipeline)
5. [Game Simulation System](#game-simulation-system)
6. [Historical Data Tracking](#historical-data-tracking)
7. [Determinism & RNG](#determinism--rng)
8. [Code Navigation Guide](#code-navigation-guide)

---

## Executive Summary

Gridiron Dynasty simulates a complete football universe spanning 20+ years across three competitive levels: high school, college, and NFL. The system generates thousands of players annually, tracks their progression through the pipeline, simulates games with realistic outcomes, accumulates career statistics, and records historical achievements.

**Key Design Principles**:
- **Single Source of Truth**: `world_state` dictionary contains all entities and relationships
- **Deterministic**: Same seed always produces identical outcomes
- **Performance**: <90 seconds to bootstrap 20 years of history
- **Incremental**: State evolves year-by-year through structured phases
- **Realistic**: Statistical outcomes match real-world football distributions

**What Gets Simulated**:
- 750+ high school players generated annually
- 130 college teams with 85-player rosters
- 32 NFL teams with 53-player rosters
- ~1,050 games per season (780 college + 272 NFL)
- Career statistics for all active players
- Awards (MVP, All-Pro, Pro Bowl, Rookie of the Year)
- Team history (wins, losses, championships, streaks)
- Draft history (all picks, rounds, teams)

---

## World State Architecture

### Philosophy: Single Source of Truth

The `world_state` is a **single, mutable Dictionary** that contains all entities, rosters, statistics, and historical records. It is passed through each simulation phase, which reads and writes to it incrementally.

**Critical Insight**: There is no separate database layer. World state is the database. All queries, reports, and UI displays read directly from this structure.

### Core Structure

```gdscript
world_state = {
    # ====== ACTIVE ENTITIES ======
    # High School System
    "hs_schools": Array[Dictionary],           # 1,000+ high schools
    "hs_players": Array[Dictionary],           # ~2,250 active HS players (3 classes)
    "hs_school_index": Dictionary,             # school_id -> school data (cache)

    # College System
    "colleges": Array[Dictionary],             # 130 college teams
    "college_rosters": Dictionary,             # college_id -> {players: [], class_years: {}}

    # NFL System
    "nfl_teams": Array[Dictionary],            # 32 NFL teams
    "nfl_rosters": Dictionary,                 # team_id -> {players: [], by_position: {}}

    # ====== TRANSITION POOLS ======
    "hs_recruit_pool": Dictionary,             # year -> Array[recruit profiles]
    "draft_pool": Dictionary,                  # year -> Array[draft-eligible players]
    "undrafted_pool": Dictionary,              # year -> Array[undrafted players]
    "free_agents": Dictionary,                 # year -> Array[free agents]
    "retired_players": Array[Dictionary],      # All-time retired players
    "transfer_portal": Dictionary,             # year -> Array[transfer players]

    # ====== HISTORICAL DATA ======
    "season_records": Dictionary,              # year -> {team_id -> {wins, losses, SOS, ...}}
    "championships": Dictionary,               # {college: {national_champions: {year -> team_id}}, nfl: {...}}
    "team_history": Dictionary,                # team_id -> {all_time_wins, championships, streaks, ...}
    "draft_history": Dictionary,               # year -> Array[{pick, round, team_id, player_id, ...}]
    "player_career_stats": Dictionary,         # player_id -> {year -> {stat_line}}
    "awards": Dictionary,                      # year -> {opoy, dpoy, oroy, droy}
    "all_pro_teams": Dictionary,               # year -> {first_team, second_team}
    "pro_bowl_rosters": Dictionary             # year -> {afc, nfc}
}
```

### Entity Schemas

#### Player Dictionary
Every player (HS, college, NFL) shares a common base schema:

```gdscript
player = {
    # Identity
    "player_id": "P_2025_001234",           # Unique identifier
    "first_name": "John",
    "last_name": "Smith",
    "age": 18,
    "position": "QB",

    # Attributes (0-99 scale)
    "stats": {
        "speed": 75,
        "strength": 68,
        "awareness": 82,
        # ... position-specific stats
    },

    # Lifecycle State
    "college_team_id": "college_042",       # Current team (or null)
    "college_year": 2,                      # 1=Fr, 2=So, 3=Jr, 4=Sr
    "college_eligibility_status": "sophomore",
    "nfl_team_id": null,                    # null until drafted
    "nfl_status": "inactive",               # "inactive"|"active"|"free_agent"|"retired"

    # Context
    "development_context": {
        "program_quality": 0.75,            # 0-1 scale
        "competition_tier": 1.1,            # Multiplier
        "usage": 1.2,                       # Starter vs bench
        "season": "college",
        "year": 2025
    },

    # Draft/Contract
    "draft_eligible": false,
    "draft_year": 0,
    "draft_info": {                         # Set after draft
        "year": 2025,
        "round": 1,
        "pick": 15,
        "team_id": "nfl_007"
    },
    "contract": {                           # NFL only
        "type": "rookie",
        "years_total": 4,
        "years_remaining": 3,
        "base_salary": 8.5,                 # Millions
        "signing_bonus": 15.2,
        "cap_hit": 12.3
    },

    # Agency (Phase 3+)
    "satisfaction": 0.0,                    # -100 to +100
    "morale": 0.0,                          # -100 to +100
    "hidden_traits": ["InjuryFlag:Prone"]   # Trait flags
}
```

#### Team Dictionary

```gdscript
team = {
    # College or NFL team
    "id": "college_042" | "nfl_007",
    "name": "Alabama Crimson Tide" | "Dallas Cowboys",
    "abbreviation": "ALA" | "DAL",

    # College-specific
    "tier": "elite",                        # "elite"|"mid"|"weak"
    "eliteness": 85.0,                      # 0-100 quality rating
    "conference": "SEC",

    # NFL-specific
    "region": "nfc_east",                   # Conference/division
    "cap_space": 45.2,                      # Millions available
    "draft_order": 15                       # Position in draft order
}
```

#### Season Record Dictionary

```gdscript
season_record = {
    "team_id": "college_042",
    "year": 2025,
    "wins": 11,
    "losses": 2,
    "conference_wins": 8,                   # Phase 2
    "conference_losses": 1,
    "strength_of_schedule": 72.3,           # Average opponent strength (0-100)
    "point_differential": 0,                # Phase 2
    "playoff_appearance": true,
    "bowl_game": "College Football Playoff",
    "championship_winner": false,
    "super_bowl_winner": false
}
```

### Memory Footprint

**Estimated world_state size after 20-year bootstrap**:
- Active players: ~15,000 players × 5KB = 75 MB
- Retired players: ~8,000 players × 5KB = 40 MB
- Season records: 162 teams × 20 years × 200B = 650 KB
- Career stats: 23,000 players × 20 years × 150B = 69 MB
- Historical data: ~5 MB (draft history, awards, team history)

**Total**: ~190 MB (well under 200 MB target)

---

## World Bootstrap Process

### Overview

Bootstrapping creates a realistic football universe by simulating N years of history before player interaction begins. The default is 20 years, creating a mature world with established dynasties, veteran players, and rich history.

### Entry Point: `BootstrapGameWorld.gd`

```gdscript
# Usage
var bootstrap := BootstrapGameWorld.new()
bootstrap.years_to_simulate = 20
var result := bootstrap.run(base_seed, capture_timing)

# Returns
{
    "years_simulated": 20,
    "start_year": 2025,
    "first_year": 2006,
    "world_state": {...},
    "summary": {
        "hs_schools": 1000,
        "college_players": 11050,
        "nfl_players": 1696,
        "retired_players": 8234
    }
}
```

**Performance Target**: <90 seconds for 20 years (<4.5s per year average)

### Year Simulation Flow

Each year is simulated through `AdvanceWorldYear.run()`, which executes a series of **phases** defined in the calendar configuration.

```
Year 2025 Phases (Sequential):
┌─────────────────────────────────────────────┐
│ 1. hs_generation                            │  Generate new HS class (750 players)
│ 2. hs_assignment                            │  Assign players to schools
│ 3. hs_season                                │  Age/develop HS players
│ 4. college_generation                       │  Create colleges (first year only)
│ 5. college_recruiting                       │  Recruit HS graduates
│ 6. college_season                           │  Simulate college games & player development
│ 7. nfl_team_generation                      │  Create NFL teams (first year only)
│ 8. draft_prep                               │  Identify draft-eligible players
│ 9. cap_validation                           │  Validate NFL salary cap compliance
│ 10. nfl_draft                               │  Execute draft (7 rounds, 32 picks each)
│ 11. nfl_season                              │  Simulate NFL games & player development
└─────────────────────────────────────────────┘
```

**Critical Ordering**:
- HS players must exist before college recruiting
- College season must complete before draft prep
- Draft must complete before NFL season
- Game simulation happens BEFORE player lifecycle in both college/NFL seasons

### Phase Deep Dive: High School Generation

**File**: `AdvanceWorldYear._handle_hs_generation()`

```gdscript
# Seed Derivation (deterministic)
step_seeds = {
    "hs_school_gen": Rand.splitmix64(year_seed ^ "hs_generation" ^ "hs_school_gen"),
    "hs_player_gen": Rand.splitmix64(year_seed ^ "hs_generation" ^ "hs_player_gen"),
    "hs_player_meta": Rand.splitmix64(year_seed ^ "hs_generation" ^ "hs_player_meta")
}

# Generate schools (first year only)
if world_state["hs_schools"].is_empty():
    schools = HighSchoolGenerator.generate(step_seeds["hs_school_gen"])
    world_state["hs_schools"] = schools  # ~1,000 schools

# Generate players (every year)
players = DraftClassGenerator.generate_for_year(year, step_seeds["hs_player_gen"])
# ~750 players with ratings (50-99), positions, ages

# Apply HS-specific fields
for player in players:
    player["hs_year"] = 1  # Freshman
    player["hs_school_id"] = null  # Assigned in next phase

world_state["hs_players"].append_array(players)
```

**Output**: 750 new freshmen added to `hs_players` pool

### Phase Deep Dive: College Season

**File**: `CollegeSeason.run()` (scripts/world/CollegeSeason.gd)

This is one of the most complex phases. It orchestrates:
1. Game simulation (12-week season)
2. Team history updates
3. Player morale calculations
4. Transfer portal decisions
5. Player lifecycle advancement
6. Early draft declarations
7. Graduation and draft eligibility

**Execution Order** (critical for correctness):

```gdscript
# 1. GAME SIMULATION (before player lifecycle)
#    Why: Stats accumulated during games affect morale/awards
var game_sim_summary = _simulate_college_season(
    world_state, year, seed, config, positions_cfg, main_cfg
)
# - Simulates 780 games (130 teams × 12 weeks / 2)
# - Updates world_state["season_records"][year][team_id]
# - Determines national champion
# - Accumulates player stats in world_state["player_career_stats"]

# 2. MORALE UPDATE (after games, before lifecycle)
#    Why: Season outcomes affect satisfaction/morale for next year
var morale_summary = _update_all_team_morale(
    world_state, year, rosters, college_index
)
# - Calculates satisfaction based on team performance, stats, awards
# - Updates player["satisfaction"] and player["morale"] in-place

# 3. TRANSFER PORTAL DECISIONS (before graduation)
#    Why: Dissatisfied players enter portal before advancing year
var transfer_entries = _process_transfer_decisions(
    world_state, year, rosters, transfer_rng
)
# - Players with low satisfaction have chance to transfer
# - Added to world_state["transfer_portal"][year]

# 4. PLAYER LIFECYCLE ADVANCEMENT (parallel for performance)
#    Why: Age players, develop stats, check retirement
for college_id in rosters:
    players = rosters[college_id]["players"]

    # Apply development context (usage, program quality, competition)
    _apply_development_context(players, college, config, rng, year)

    # Parallel lifecycle processing (50-100 players per roster)
    progressed = PlayerLifecycle.advance_one_year_parallel(
        players, positions_cfg, main_cfg, stats_cfg, lifecycle_rng
    )

    updated_players = progressed["players"]

    # 5. GRADUATION & DRAFT ELIGIBILITY
    for player in updated_players:
        player["college_year"] += 1  # Fr->So, So->Jr, etc.

        if player["college_year"] >= 4:
            # Seniors auto-declare if rating >= threshold (65)
            if player_rating >= 65:
                draft_eligible.append(player)
                graduates += 1
        elif player["college_year"] == 3:
            # Juniors can declare early (rating >= 85, 15% base chance)
            if _check_early_declaration(player, config, rng):
                draft_eligible.append(player)
                early_declares += 1

# 6. UPDATE ROSTERS
#    Remove graduated/declared players, keep active
rosters[college_id]["players"] = active_players
world_state["draft_pool"][year] = draft_eligible
```

**Performance**: ~8-12 seconds per year for college season (largest phase)

### Phase Deep Dive: NFL Draft

**File**: `NflDraft.run()` (scripts/world/NflDraft.gd)

The draft is a 7-round selection process where 32 NFL teams pick players from the draft pool.

```gdscript
# Setup
draft_pool = world_state["draft_pool"][year]  # ~250-520 players
rounds = 7
picks_per_round = 32

# Generate scouts for each team (deterministic)
team_scouts = _generate_team_scouts(teams, stats_cfg, scouts_cfg, scout_rng)

# Cache for performance (prevent redundant evaluations)
score_cache = RecruitingScoreCache.new(year)

for round in range(1, 8):
    for team in sorted_by_draft_order:
        # Score all remaining players
        scored_players = _score_draft_pool(
            remaining_pool, roster, team_id, scout,
            positions_cfg, stats_cfg, round, seed, score_cache
        )
        # Uses cached evaluation to avoid 44,800 redundant calculations
        # (200 players × 7 rounds × 32 teams)

        # Apply position need weighting
        needs = _calculate_position_needs(roster, positions_cfg)
        for scored in scored_players:
            scored["score"] *= needs[scored["position"]]

        # Select best available
        selected = scored_players[0]

        # Create rookie contract (4 years, salary by pick slot)
        contract = _create_rookie_contract(round, overall_pick, league_cfg, rng)

        # Update player
        player["nfl_team_id"] = team_id
        player["nfl_status"] = "active"
        player["contract"] = contract
        player["draft_info"] = {year, round, pick, team_id}

        # Add to roster
        rosters[team_id]["players"].append(player)
        remaining_pool.remove(player)

# Store draft history (D5.1)
world_state["draft_history"][year] = picks  # All 224 picks
world_state["undrafted_pool"][year] = remaining_pool
```

**Performance**: ~2-4 seconds per year for draft

---

## Season Simulation Pipeline

### Game Simulation Integration Points

Game simulation occurs in two places:
1. **CollegeSeason** (line 56-63): Before player lifecycle
2. **NflSeason** (line 61-68): Before player lifecycle

**Why Before Lifecycle?**
- Stats accumulated during games affect morale calculations
- Season performance influences player decisions (transfers, early entry)
- Awards require complete season statistics

### College Season Game Flow

```
_simulate_college_season() in CollegeSeason.gd
├─ 1. Calculate team strengths (cache)
│     For each college:
│         strength = mean(player ratings)  # O(n) per roster
│
├─ 2. Generate schedule (deterministic)
│     GameSimulator.generate_college_schedule()
│     - Round-robin rotation (12 weeks)
│     - Shuffle teams using sim_seed
│     - Home/away alternates by week
│     Result: ~780 games
│
├─ 3. Simulate games (sequential for determinism)
│     For each matchup:
│         ├─ Determine winner (logistic win probability)
│         │    P(home wins) = 1 / (1 + e^(-k * (strength_diff + home_adv)))
│         │    RNG roll: home wins if roll < probability
│         │    Upset: underdog wins by >5 points
│         │
│         ├─ Accumulate player stats
│         │    StatGenerator.generate_game_stats()
│         │    - QB: pass_yards, pass_tds, interceptions
│         │    - RB: rush_yards, rush_tds, receptions
│         │    - WR/TE: receptions, rec_yards, rec_tds
│         │    - DEF: tackles, sacks, interceptions, pass_breakups
│         │    Updates world_state["player_career_stats"][player_id][year]
│         │
│         └─ Record result
│
├─ 4. Aggregate season results
│     GameSimulator.aggregate_season_results()
│     - Wins/Losses per team
│     - Strength of Schedule (mean opponent strength)
│     Store in world_state["season_records"][year]
│
├─ 5. Determine national champion
│     Phase 1: Best record wins (simple)
│     Phase 2: Top 4 playoff bracket (future)
│     Store in world_state["championships"]["college"]["national_champions"][year]
│
└─ 6. Update team history
      _update_team_history()
      - Franchise win totals (H4.1)
      - Championship history (H4.2)
      - Playoff appearances (H4.3)
      - Winning/losing streaks (H4.4)
      - Championship droughts (H4.6)
```

### NFL Season Game Flow

```
_simulate_nfl_season() in NflSeason.gd
├─ 1. Calculate team strengths
│     (same as college)
│
├─ 2. Generate schedule
│     GameSimulator.generate_nfl_schedule()
│     - Intra-division: 6 games (home/away vs division)
│     - Inter-division: 11 games (rotational)
│     Result: ~272 games (32 teams × 17 weeks / 2)
│
├─ 3. Simulate games
│     (same as college, different parameters)
│     - Home advantage: 2.5 (vs 3.0 for college)
│     - Upset threshold: 7.0 (vs 5.0 for college)
│
├─ 4. Aggregate season results
│     (same as college)
│
├─ 5. Determine Super Bowl winner
│     Phase 1: Best record wins
│     Phase 2: 14-team playoff bracket (future)
│     Store in world_state["championships"]["nfl"]["super_bowl_winners"][year]
│
├─ 6. Update team history
│     (same as college)
│
└─ 7. Select NFL Awards
      AwardSelector.select_all_awards()
      - OPOY/DPOY (A3.2)
      - All-Pro Teams (A3.3)
      - Pro Bowl Rosters (A3.4)
      - OROY/DROY (A3.8)
```

---

## Game Simulation System

### Core Algorithm: Win Probability

Gridiron Dynasty uses a **logistic function** to model win probability based on team strength differential.

```gdscript
# Formula
P(team_a wins) = 1 / (1 + e^(-k * (strength_diff + home_advantage)))

where:
    strength_diff = team_a_strength - team_b_strength
    k = strength_sensitivity (default: 0.1)
    home_advantage = 3.0 (college) or 2.5 (NFL)
```

**Calibration Examples**:

| Strength Diff | Home Advantage | Win Probability |
|---------------|----------------|-----------------|
| 0             | No             | 50%             |
| 0             | Yes (+3)       | 58%             |
| +10           | No             | 73%             |
| +20           | No             | 88%             |
| +30           | No             | 95%             |

**Why Logistic?**
- Realistic: Matches real-world win rates for favorites
- Bounded: Always 1-99% (upsets always possible)
- Symmetric: P(A beats B) = 1 - P(B beats A)
- Monotonic: Stronger team always has higher win probability

### Team Strength Calculation

**Phase 1 (Current)**:
```gdscript
team_strength = mean(player_overall_ratings)
```

**Future Enhancements (Phase 2+)**:
- Position importance weighting (QB worth 3x punter)
- Depth chart consideration (starters vs backups)
- Injury impact (missing star player)
- Coaching quality multiplier

### Schedule Generation

#### College Schedule (Round-Robin)

```
Algorithm: Circular rotation with fixed pivot
- Team 0 stays fixed at top
- Other teams rotate clockwise each week
- Home/away alternates by week

Example (8 teams, 7 weeks):
Week 1: T0 vs T7, T1 vs T6, T2 vs T5, T3 vs T4
Week 2: T0 vs T6, T7 vs T5, T1 vs T4, T2 vs T3
Week 3: T0 vs T5, T6 vs T4, T7 vs T3, T1 vs T2
...

Properties:
- Each team plays (n-1) games
- Home/away balanced over season
- Deterministic with seed-based shuffle
```

#### NFL Schedule (Division-Based)

```
Phase 1 (Simplified):
- Weeks 1-6: Intra-division (2x home, 2x away vs each division opponent)
- Weeks 7-17: Inter-division (random rotation, re-shuffled each week)

Phase 2 (Realistic):
- Division games (6 games)
- Conference games (4 games vs one division)
- Cross-conference games (4 games vs one division)
- Intra-conference games (3 games by previous year standings)
```

### Statistical Output

After each game, `StatGenerator` creates position-specific stat lines:

```gdscript
# QB Example
{
    "player_id": "P_2025_001234",
    "year": 2025,
    "team_id": "college_042",
    "position": "QB",
    "games_played": 1,
    "games_started": 1,
    "pass_attempts": 35,
    "pass_completions": 23,
    "pass_yards": 287,
    "pass_tds": 2,
    "interceptions": 1,
    "sacks_taken": 2
}

# Accumulated into world_state["player_career_stats"]["P_2025_001234"][2025]
# Each game adds to season totals
```

**Stat Generation Algorithm**:
1. Base production = f(player_rating, position, team_strength)
2. Game outcome modifier (winners get 10% boost)
3. Randomness (±20% variance per game)
4. Accumulate into career totals

**Realism Validation**:
- Elite QBs (90+ rating) average 3,500+ yards/season
- Star RBs (85+ rating) average 1,200+ yards/season
- Top WRs (85+ rating) average 80+ receptions/season

---

## Historical Data Tracking

### Team History (H4.1-H4.6)

Stored in `world_state["team_history"][team_id]`:

```gdscript
{
    "team_id": "college_042",
    "all_time_wins": 234,              # H4.1
    "all_time_losses": 89,
    "first_season": 2006,
    "last_season": 2025,
    "championship_count": 3,           # H4.2
    "championship_years": [2010, 2018, 2023],
    "playoff_appearances": 12,         # H4.3
    "playoff_years": [2006, 2008, 2009, ...],
    "longest_win_streak": 5,           # H4.4 (consecutive winning seasons)
    "longest_loss_streak": 2,
    "current_win_streak": 3,
    "current_loss_streak": 0,
    "years_since_championship": 2      # H4.6 (drought tracking)
}
```

**Update Timing**: End of each season (after game simulation, before player lifecycle)

**Streak Definition**: Consecutive SEASONS with winning/losing record (not games)
- Winning season: wins > losses
- Losing season: losses > wins
- .500 season: Resets both streaks

### Draft History (D5.1, D5.5)

Stored in `world_state["draft_history"][year]`:

```gdscript
[
    {
        "pick_number": 1,
        "round": 1,
        "team_id": "nfl_007",
        "player_id": "P_2025_000042",
        "position": "QB",
        "college": "college_089",
        "traded": false,               # D5.5 (placeholder for trade system)
        "original_team_id": null       # D5.5 (null if not traded)
    },
    # ... 223 more picks (7 rounds × 32 teams)
]
```

**Uses**:
- Historical analysis ("Who drafted Tom Brady?")
- Team draft performance tracking
- Player origin tracing
- Future trade tracking (Phase 3)

### Player Career Statistics (S2.1, S2.4)

Stored in `world_state["player_career_stats"][player_id]`:

```gdscript
{
    # Year-indexed stat lines
    2023: {
        "year": 2023,
        "team_id": "college_042",
        "position": "QB",
        "games_played": 12,
        "games_started": 12,
        "pass_yards": 3421,
        "pass_tds": 28,
        "interceptions": 9,
        # ... all position-specific stats
    },
    2024: {
        "year": 2024,
        "team_id": "college_042",
        "position": "QB",
        "games_played": 13,
        "games_started": 13,
        "pass_yards": 3789,
        "pass_tds": 32,
        "interceptions": 7
    },
    2025: {
        # NFL rookie season
        "year": 2025,
        "team_id": "nfl_007",
        "position": "QB",
        "games_played": 16,
        "games_started": 16,
        "pass_yards": 3156,
        "pass_tds": 22,
        "interceptions": 12
    }
}
```

**Career Totals**: Sum across all years
**Peak Season**: Max single-year total (for awards, Hall of Fame)

### Awards (A3.2-A3.8)

Stored in `world_state["awards"][year]`:

```gdscript
{
    "opoy": {                          # Offensive Player of the Year
        "player_id": "P_2023_000156",
        "position": "QB",
        "score": 1847.3,               # Weighted stat score
        "stats_summary": {
            "pass_yards": 4523,
            "pass_tds": 38,
            "interceptions": 9,
            "games_played": 16
        },
        "team_id": "nfl_015"
    },
    "dpoy": {...},                     # Defensive Player of the Year
    "oroy": {...},                     # Offensive Rookie of the Year
    "droy": {...}                      # Defensive Rookie of the Year
}
```

Stored in `world_state["all_pro_teams"][year]`:

```gdscript
{
    "first_team": [
        {
            "player_id": "P_2023_000156",
            "position": "QB",
            "score": 1847.3,
            "team_id": "nfl_015"
        },
        # ... 21 more positions (22 total)
    ],
    "second_team": [
        # ... 22 players
    ]
}
```

**Selection Algorithm** (deterministic, no RNG):
```gdscript
# 1. Filter to offensive/defensive positions
# 2. Calculate position-specific score
#    QB: pass_yards/10 + pass_tds×40 - INTs×20
#    RB: rush_yards/10 + rush_tds×60 + receptions×5
#    WR: receptions×10 + rec_yards/10 + rec_tds×60
# 3. Sort by score descending
# 4. Select top player (for awards) or top N (for All-Pro/Pro Bowl)
```

---

## Determinism & RNG

### Why Determinism Matters

Gridiron Dynasty is **fully deterministic**: the same seed produces the exact same 20-year simulation every time. This is critical for:

1. **Testing**: Regression tests validate identical outputs
2. **Debugging**: Reproduce bugs by re-running same seed
3. **Performance**: Compare timing across runs without data variance
4. **Fairness**: User choices are meaningful, not random luck

### Seed Derivation Hierarchy

```
base_seed (user-provided or config default: 12345)
    ↓
year_seed = Rand.splitmix64(base_seed ^ year)
    ↓
phase_seed = Rand.splitmix64(year_seed ^ phase_id ^ "phase")
    ↓
step_seed = Rand.splitmix64(phase_seed ^ step_id)
```

**Example for College Season 2025**:
```gdscript
base_seed = 12345
year_seed = Rand.splitmix64(12345 ^ 2025)  # = 9847321...
phase_seed = Rand.splitmix64(year_seed ^ "college_season" ^ "phase")
step_seeds = {
    "lifecycle": Rand.splitmix64(phase_seed ^ 0xC011E6E1),
    "context": Rand.splitmix64(phase_seed ^ 0xC011E6E2),
    "early_declaration": Rand.splitmix64(phase_seed ^ 0xC011E6E3),
    "transfer": Rand.splitmix64(phase_seed ^ 0xC011E6E5),
    "game_simulation": Rand.splitmix64(phase_seed ^ 0xC011E6E4)
}
```

### RNG Consumption Patterns

Every function that uses RNG **must document its consumption**:

```gdscript
## RNG Consumption: Exactly 1 call (randf) per player
## Pattern: roll < probability → true
func _check_early_declaration(player, config, rng) -> bool:
    var rating = calculate_rating(player)
    if rating < 85:
        return false

    var chance = 0.15 + (rating - 85) * 0.01  # 15% base, +1% per point
    return rng.randf() < chance  # SINGLE RNG CALL
```

**Critical Rules**:
1. Never create `RandomNumberGenerator.new()` without explicit seed
2. Always receive RNG as parameter (caller controls seed)
3. Document exact RNG consumption (e.g., "1 randf() per player")
4. Consume RNG in deterministic order (sequential, not parallel)

### Testing Determinism

```gdscript
# test_determinism.gd
func test_identical_runs():
    var seed = 12345

    # Run 1
    var bootstrap1 = BootstrapGameWorld.new()
    var result1 = bootstrap1.run(seed)

    # Run 2
    var bootstrap2 = BootstrapGameWorld.new()
    var result2 = bootstrap2.run(seed)

    # Assert byte-for-byte identical
    assert_eq(result1.world_state, result2.world_state)
    assert_eq(result1.summary, result2.summary)
```

**If Determinism Breaks**:
1. Check for new RNG usage without explicit seed
2. Verify RNG consumption order hasn't changed
3. Look for non-deterministic operations (time, random, parallel execution)
4. Review recent changes to phase handlers

---

## Code Navigation Guide

### Primary Entry Points

| File | Purpose | Entry Function |
|------|---------|----------------|
| `scripts/pipelines/BootstrapGameWorld.gd` | Multi-year bootstrap | `run(seed, capture_timing)` |
| `scripts/pipelines/AdvanceWorldYear.gd` | Single year simulation | `run(world_state, year, seed)` |
| `scripts/world/CollegeSeason.gd` | College season phase | `run(world_state, year, seed, ...)` |
| `scripts/world/NflSeason.gd` | NFL season phase | `run(world_state, year, seed, ...)` |
| `scripts/world/NflDraft.gd` | NFL draft phase | `run(world_state, year, seed, ...)` |

### Game Simulation Stack

```
CollegeSeason.run()
    └─ _simulate_college_season()
        └─ GameSimulator.generate_college_schedule()
        └─ GameSimulator.determine_winner() [for each game]
        │   └─ calculate_win_probability()
        └─ GameSimulator.accumulate_player_stats()
        │   └─ StatGenerator.generate_game_stats()
        └─ GameSimulator.aggregate_season_results()
```

| File | Purpose |
|------|---------|
| `scripts/core/game_simulation/GameSimulator.gd` | Game outcome determination |
| `scripts/core/game_simulation/StatGenerator.gd` | Position-specific stat generation |
| `scripts/core/awards/AwardSelector.gd` | Award selection algorithms |
| `scripts/core/rating/PlayerRatingCalculator.gd` | Player overall rating calculation |

### Player Lifecycle Stack

```
CollegeSeason.run()
    └─ _apply_development_context()
    └─ PlayerLifecycle.advance_one_year_parallel()
        └─ DevelopmentEngine.apply_development()
        └─ RetirementEngine.check_retirement()
```

| File | Purpose |
|------|---------|
| `scripts/world/PlayerLifecycle.gd` | Player aging and development orchestration |
| `scripts/support/config/DevelopmentConfig.gd` | Cached development config |
| `scripts/support/config/RetirementConfig.gd` | Cached retirement config |

### Historical Tracking

| File | Purpose | Updated When |
|------|---------|--------------|
| `CollegeSeason._update_team_history()` | Team history (H4.1-H4.6) | After game simulation |
| `NflDraft.run()` | Draft history (D5.1, D5.5) | End of draft phase |
| `GameSimulator.accumulate_player_stats()` | Career stats (S2.1, S2.4) | After each game |
| `AwardSelector.select_all_awards()` | Awards (A3.2-A3.8) | End of NFL season |

### Configuration Files

| File | Contains |
|------|----------|
| `configs/sports/american_football/world/main.json` | Year, seed, class rules, retirement |
| `configs/sports/american_football/world/colleges.json` | College config, game simulation params |
| `configs/sports/american_football/world/league.json` | NFL teams, draft config, game simulation |
| `configs/sports/american_football/world/calendar.json` | Phase ordering and timing |
| `configs/sports/american_football/positions.json` | Position-specific stat weights |

### Key Data Structures

```gdscript
# Phase Descriptor (from WorldCalendar)
{
    "year": 2025,
    "phase_id": "college_season",
    "index": 6,
    "label": "College Season",
    "start_tick": 140,
    "end_tick": 170,
    "tags": ["league:college", "type:season"],
    "placeholder": false
}

# Game Matchup (input to GameSimulator)
{
    "game_id": "college_2025_w1_g12",
    "year": 2025,
    "week": 1,
    "home_team_id": "college_042",
    "away_team_id": "college_089",
    "game_type": "regular"
}

# Game Result (output from GameSimulator)
{
    "game_id": "college_2025_w1_g12",
    "year": 2025,
    "week": 1,
    "home_team_id": "college_042",
    "away_team_id": "college_089",
    "winner_id": "college_042",
    "loser_id": "college_089",
    "home_score": 0,              # Phase 2
    "away_score": 0,              # Phase 2
    "game_type": "regular",
    "is_overtime": false,
    "upset": false,
    "strength_differential": 12.3,
    "win_probability": 0.77
}
```

---

## Quick Reference: Common Queries

### "How do I find a player's career stats?"

```gdscript
var player_id = "P_2023_000156"
var career_stats: Dictionary = world_state["player_career_stats"].get(player_id, {})

# Single season
var season_2025 = career_stats.get(2025, {})
var pass_yards = season_2025.get("pass_yards", 0)

# Career totals
var total_yards = 0
for year in career_stats.keys():
    total_yards += career_stats[year].get("pass_yards", 0)
```

### "How do I find who won the Super Bowl in year X?"

```gdscript
var year = 2025
var championships: Dictionary = world_state["championships"]
var sb_winners: Dictionary = championships["nfl"]["super_bowl_winners"]
var winner_team_id: String = sb_winners.get(year, "")
```

### "How do I find a team's all-time record?"

```gdscript
var team_id = "nfl_007"
var team_history: Dictionary = world_state["team_history"].get(team_id, {})
var all_time_wins = team_history.get("all_time_wins", 0)
var all_time_losses = team_history.get("all_time_losses", 0)
var championships = team_history.get("championship_count", 0)
```

### "How do I find all players on a roster?"

```gdscript
# NFL Roster
var team_id = "nfl_007"
var nfl_rosters: Dictionary = world_state["nfl_rosters"]
var roster: Dictionary = nfl_rosters.get(team_id, {})
var players: Array = roster.get("players", [])

# College Roster
var college_id = "college_042"
var college_rosters: Dictionary = world_state["college_rosters"]
var roster: Dictionary = college_rosters.get(college_id, {})
var players: Array = roster.get("players", [])
```

### "How do I trace a player's journey (HS → College → NFL)?"

```gdscript
var player_id = "P_2023_000156"
var player: Dictionary  # Find player in rosters or retired_players

# High School
var hs_school_id = player.get("hs_school_id", "")

# College
var college_team_id = player.get("college_team_id", "")
var college_year = player.get("college_year", 0)

# Draft
var draft_info: Dictionary = player.get("draft_info", {})
var drafted_by = draft_info.get("team_id", "")
var draft_round = draft_info.get("round", 0)
var draft_pick = draft_info.get("pick", 0)

# NFL
var nfl_team_id = player.get("nfl_team_id", "")
var nfl_status = player.get("nfl_status", "")
```

---

## Performance Optimization Notes

### Bottlenecks

1. **PlayerLifecycle**: ~60% of total time
   - Mitigation: Parallel processing via `advance_one_year_parallel()`
   - 4-8 threads on 50-100 player rosters

2. **Game Simulation**: ~15% of total time
   - 21,040 games across 20 years
   - Mitigation: Cached team strengths, sequential execution

3. **Stat Generation**: ~10% of total time
   - Position-specific formulas for 15,000+ active players
   - Mitigation: Simple formulas, no complex physics

4. **Draft**: ~8% of total time
   - Scout evaluation cache prevents 44,800 redundant calculations
   - Mitigation: `RecruitingScoreCache` for deterministic caching

5. **Memory Allocation**: ~7% of total time
   - 190 MB world_state created incrementally
   - Mitigation: In-place modifications where safe, `.duplicate()` minimized

### Performance Targets

| Operation | Target | Current |
|-----------|--------|---------|
| 20-year bootstrap | <90s | ~60-75s ✅ |
| Single year | <4.5s | ~3-4s ✅ |
| College season | <2s | ~1-1.5s ✅ |
| NFL season | <1.5s | ~0.8-1.2s ✅ |
| Draft | <1s | ~0.5-0.8s ✅ |

### Timing Capture

```gdscript
var bootstrap = BootstrapGameWorld.new()
bootstrap.years_to_simulate = 20
var result = bootstrap.run(12345, true)  # capture_timing=true

var timings = result["world_generation"]["total_phase_timings_ms"]
# {
#   "hs_generation": 1234.5,
#   "college_season": 18567.2,
#   "nfl_draft": 8234.1,
#   ...
# }
```

---

## Related Documentation

- **Implementation Plan**: `/docs/planning/MASTER_IMPLEMENTATION_PLAN.md`
- **Game Simulation**: `/docs/implementation/TRACK_1_COMPLETION_SUMMARY.md`
- **Missing Features Audit**: `/docs/analysis/MISSING_FEATURES_AUDIT.md`
- **Feature Priority Matrix**: `/docs/analysis/FEATURE_PRIORITY_MATRIX.md`
- **WorldBootstrap Resolution**: `/docs/architecture/worldbootstrap_resolution.md`

---

**Document Version**: 1.0
**Last Updated**: 2026-01-11
**Maintainer**: Development Team
**Feedback**: Submit issues or improvements via PR to `/docs/guides/`
