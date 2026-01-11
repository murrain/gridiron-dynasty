# Game Simulation Architecture

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Context**: Bootstrap 20-year history generation

---

## Executive Summary

This document specifies the architecture for simulating college and NFL games during world bootstrapping. The system generates realistic season outcomes through simple math-based winner determination without implementing a full play-by-play game engine. The design prioritizes determinism, parallelizability, and minimal bootstrap overhead while maintaining architectural coherence with existing simulation systems.

**Key Decisions**:
- **Scope**: College and NFL only (not high school)
- **Timing**: Integrated into existing `college_season` and `nfl_season` phases
- **Complexity**: Probabilistic winner determination based on team strength
- **Performance**: Week-level parallelization with game-level batching
- **Target**: <5% bootstrap overhead for full 20-year simulation

---

## Design Philosophy

### 1. Architectural Coherence

The game simulation system must feel native to the existing architecture, not bolted-on:

**Integration Points**:
- Extends existing `CollegeSeason` and `NflSeason` classes (no new phase in calendar)
- Follows established RNG patterns (seed derivation, deterministic random)
- Uses existing `world_state` dictionary for persistence
- Aligns with `PlayerLifecycle` development context model

**Pattern Consistency**:
- Season classes own simulation logic (not separate orchestrators)
- Configuration-driven behavior (JSON files, not hardcoded rules)
- Stateless functions with explicit RNG passing
- In-place world_state mutation (standard pattern)

### 2. Complexity Management

Resist premature complexity. Build incrementally:

**Phase 1 (MVP)**: Simple schedule + probabilistic winner
- Fixed schedules (no conference logic yet)
- Team strength = mean roster rating
- Win probability from logistic curve
- Store W/L records only

**Phase 2 (Realism)**: Conference-aware schedules
- Conference structures from config
- Playoff/bowl game selection
- Division-based NFL schedules

**Phase 3 (Integration)**: Player development feedback
- Winning teams get minor dev bonuses
- Playoff experience multipliers
- Performance tracking per player

**Phase 4 (Optimization)**: Parallelization
- Week-level parallel execution
- Lock-free game result aggregation

**CRITICAL**: Do not implement Phase 2+ until Phase 1 is validated in production.

### 3. Boundary Definition

Clear separation of concerns:

```
┌─────────────────────────────────────────────────┐
│           AdvanceWorldYear Pipeline              │
│  (Orchestrates phases, no game logic)           │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼────────┐    ┌────────▼────────┐
│  CollegeSeason  │    │   NflSeason     │
│  - run()        │    │   - run()       │
│  - simulate()   │    │   - simulate()  │
└────────┬────────┘    └────────┬────────┘
         │                      │
         └──────────┬───────────┘
                    │
         ┌──────────▼──────────┐
         │  GameSimulator      │
         │  (Pure functions)   │
         │  - schedule()       │
         │  - determine_winner()│
         │  - aggregate_results()│
         └─────────────────────┘
```

**Responsibilities**:
- **Season classes**: Orchestrate simulation, manage world_state integration
- **GameSimulator**: Pure game logic (schedules, winner determination, scoring)
- **Config files**: Define league structures, simulation parameters
- **World state**: Persist season results, not intermediate game states

### 4. Lifecycle Analysis

Long-term maintenance considerations:

**Version 1 Constraints**:
- No detailed play-by-play logs (memory intensive)
- No per-player game stats (complexity explosion)
- No injury simulation during games (separate concern)
- No coaching AI decisions (out of scope)

**Future Expansion Hooks**:
- Game result model includes optional `score` field (unused in Phase 1)
- Team strength calculation pluggable (can add depth chart logic later)
- Schedule generation abstracted (can swap algorithms)
- Result aggregation supports arbitrary metrics (extendable)

**Migration Strategy**:
- Config version fields allow backwards compatibility
- World state format supports schema evolution
- Season classes can detect missing simulation data (graceful degradation)

---

## Data Models

### Core Entities

#### GameResult

Represents the outcome of a single game.

```gdscript
{
  "game_id": String,           # "college_2025_week_1_game_3"
  "year": int,                 # 2025
  "week": int,                 # 1-15 (college), 1-18 (NFL)
  "home_team_id": String,      # Team identifier
  "away_team_id": String,      # Team identifier
  "winner_id": String,         # home_team_id or away_team_id
  "loser_id": String,          # The other team
  "home_score": int,           # Points scored (Phase 2+)
  "away_score": int,           # Points scored (Phase 2+)
  "game_type": String,         # "regular", "conference_championship", "bowl", "playoff", "super_bowl"
  "is_overtime": bool,         # Phase 2+ feature
  "upset": bool,               # True if underdog won
  "strength_differential": float  # Winner strength - Loser strength
}
```

**Storage**: NOT persisted individually (too many games). Only aggregated results stored.

#### SeasonRecord

Aggregated season results per team.

```gdscript
{
  "team_id": String,
  "year": int,
  "wins": int,
  "losses": int,
  "conference_wins": int,      # Phase 2+
  "conference_losses": int,    # Phase 2+
  "strength_of_schedule": float,  # Mean opponent strength
  "point_differential": int,   # Phase 2+: total points for - against
  "playoff_appearance": bool,
  "bowl_game": String,         # Bowl game name (college) or "" if none
  "championship_winner": bool, # Won conference/division championship
  "super_bowl_winner": bool    # NFL only
}
```

**Storage**: `world_state["season_records"][year][team_id]`

#### TeamStrength

Cached team strength calculation (recomputed weekly in Phase 3+).

```gdscript
{
  "team_id": String,
  "year": int,
  "week": int,
  "strength": float,           # 0.0-100.0 scale
  "offensive_strength": float, # Phase 2+ breakdown
  "defensive_strength": float, # Phase 2+ breakdown
  "depth_penalty": float,      # Phase 3+: injury/depth impact
  "roster_size": int,          # For validation
  "calculation_method": String # "mean_rating", "weighted_rating", etc.
}
```

**Storage**: Computed on-demand in Phase 1, cached in Phase 3+.

---

## Schedule Generation

### College Schedule (Phase 1: Simplified)

**Approach**: Round-robin with random matchups.

```gdscript
# colleges.json additions (Phase 1)
{
  "schedule": {
    "regular_season_weeks": 12,
    "conference_championship_week": 13,
    "bowl_season_start_week": 14,
    "bowl_season_end_week": 15,
    "games_per_week": 65  # 130 teams / 2
  }
}
```

**Algorithm**:
1. Shuffle teams using year_seed
2. For each week, pair teams sequentially (team[0] vs team[1], team[2] vs team[3], etc.)
3. Rotate teams for next week (keep team[0] fixed, rotate others)
4. Repeat for `regular_season_weeks`
5. No conference championship or bowl games in Phase 1

**Determinism**: Same seed produces identical matchups across runs.

**Home/Away**: Alternate each week (team with lower index is home in odd weeks, away in even weeks).

### NFL Schedule (Phase 1: Simplified)

**Approach**: Division-based rotation.

```gdscript
# league.json additions (Phase 1)
{
  "schedule": {
    "regular_season_weeks": 17,
    "playoff_start_week": 18,
    "super_bowl_week": 21,
    "bye_weeks": [6, 7, 8, 9, 10, 11, 12, 13, 14]  # Phase 2+
  },
  "divisions": [
    {"id": "afc_east", "teams": ["nfl_001", "nfl_002", "nfl_003", "nfl_004"]},
    {"id": "afc_north", "teams": ["nfl_005", "nfl_006", "nfl_007", "nfl_008"]},
    // ... 8 divisions total
  ]
}
```

**Algorithm (Phase 1: Simplified)**:
1. Load divisions from config
2. Generate 17 weeks of matchups:
   - Weeks 1-6: Intra-division games (each team plays divisional opponents twice)
   - Weeks 7-17: Inter-division rotation (based on seed)
3. No bye weeks or playoffs in Phase 1

**Determinism**: Seed-based rotation ensures consistency.

**Home/Away**: Teams alternate home/away in divisional matchups.

### Schedule Storage

**NOT stored in world_state** (can regenerate from seed). Only results persisted.

Exception: If schedule needs to be queryable (Phase 3+), store in:
```gdscript
world_state["schedules"] = {
  "college": {
    year: [GameResult, ...],  # Pre-simulated results
  },
  "nfl": {
    year: [GameResult, ...]
  }
}
```

---

## Winner Determination Algorithm

### Team Strength Calculation

**Phase 1 (MVP)**: Mean roster rating.

```gdscript
func calculate_team_strength(roster: Dictionary, positions_cfg: Dictionary, main_cfg: Dictionary) -> float:
  var players: Array = roster.get("players", [])
  if players.is_empty():
    return 50.0  # Default strength for empty rosters

  var total := 0.0
  var count := 0
  var class_rules: Dictionary = main_cfg.get("class_rules", {})

  for player in players:
    var p: Dictionary = player
    var rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)
    total += rating
    count += 1

  return total / float(count) if count > 0 else 50.0
```

**Phase 2 (Weighted)**: Position importance + depth chart.

```gdscript
# positions.json additions (Phase 2)
{
  "QB": {
    "importance_weight": 1.5,  # QB more important than other positions
    "starter_weight": 1.0,
    "backup_weight": 0.3
  }
}
```

**Phase 3 (Contextual)**: Injuries, suspensions, home field.

### Win Probability Model

**Phase 1**: Logistic function based on strength differential.

```gdscript
func calculate_win_probability(team_a_strength: float, team_b_strength: float, is_home: bool, cfg: Dictionary) -> float:
  var diff := team_a_strength - team_b_strength

  # Apply home field advantage (Phase 1: +3 point equivalent = +4.2% strength)
  if is_home:
    var home_advantage := float(cfg.get("home_field_advantage", 3.0))
    diff += home_advantage

  # Logistic curve: P(win) = 1 / (1 + exp(-k * diff))
  # k = 0.1 gives reasonable spread (50% at diff=0, 73% at diff=10, 88% at diff=20)
  var k := float(cfg.get("strength_sensitivity", 0.1))
  var exponent := -k * diff
  var probability := 1.0 / (1.0 + exp(exponent))

  return clamp(probability, 0.01, 0.99)  # Never 100% certain
```

**Justification**:
- Logistic curve models diminishing returns (20-point advantage not 2x better than 10-point)
- Prevents deterministic outcomes (upsets possible)
- Realistic: ~65% home team win rate matches NCAA/NFL stats

### Winner Determination

```gdscript
func determine_winner(game_matchup: Dictionary, team_strengths: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
  var home_id := String(game_matchup.get("home_team_id", ""))
  var away_id := String(game_matchup.get("away_team_id", ""))

  var home_strength := float(team_strengths.get(home_id, 50.0))
  var away_strength := float(team_strengths.get(away_id, 50.0))

  var home_win_prob := calculate_win_probability(home_strength, away_strength, true, cfg)
  var roll := rng.randf()

  var home_wins := (roll < home_win_prob)
  var upset := false

  if home_wins and away_strength > home_strength + 5.0:
    upset = true  # Away team was favored but lost
  elif not home_wins and home_strength > away_strength + 5.0:
    upset = true  # Home team was favored but lost

  return {
    "game_id": String(game_matchup.get("game_id", "")),
    "year": int(game_matchup.get("year", 0)),
    "week": int(game_matchup.get("week", 0)),
    "home_team_id": home_id,
    "away_team_id": away_id,
    "winner_id": home_id if home_wins else away_id,
    "loser_id": away_id if home_wins else home_id,
    "home_score": 0,  # Phase 2+
    "away_score": 0,  # Phase 2+
    "game_type": String(game_matchup.get("game_type", "regular")),
    "is_overtime": false,  # Phase 2+
    "upset": upset,
    "strength_differential": abs(home_strength - away_strength),
    "win_probability": home_win_prob if home_wins else (1.0 - home_win_prob)
  }
```

### RNG Consumption Pattern

**Critical for determinism**:

```gdscript
# Per-week seed derivation (example for college week 5, year 2025)
var week_seed := Rand.splitmix64(season_seed ^ week_number)
var week_rng := RandomNumberGenerator.new()
week_rng.seed = week_seed

# Per-game RNG consumption (MUST be sequential, not parallel)
for game in week_matchups:
  var result := determine_winner(game, team_strengths, week_rng, cfg)
  # week_rng advances by 1 call (randf inside determine_winner)
  results.append(result)
```

**Why sequential within week**: Ensures deterministic RNG state progression regardless of thread scheduling.

---

## Integration with Existing Systems

### CollegeSeason Integration

**Current `CollegeSeason.run()` flow**:
1. Load rosters from `world_state["college_rosters"]`
2. Apply development context (usage, competition tier)
3. Call `PlayerLifecycle.advance_one_year_parallel()`
4. Process graduations and draft declarations
5. Update rosters, draft pool

**Enhanced flow with game simulation (Phase 1)**:

```gdscript
func run(world_state: Dictionary, year: int, seed: int, config: Dictionary, ...) -> Dictionary:
  # ... existing roster loading and context application ...

  # NEW: Simulate season BEFORE player lifecycle
  var sim_seed := _derive_seed(seed, "game_simulation")
  var season_results := _simulate_season(world_state, year, sim_seed, config)

  # Store season records (for historical tracking)
  var season_records: Dictionary = world_state.get("season_records", {})
  if not season_records.has(year):
    season_records[year] = {}
  for team_id in season_results.keys():
    season_records[year][team_id] = season_results[team_id]
  world_state["season_records"] = season_records

  # FUTURE (Phase 3): Apply development context based on W/L record
  # var winning_teams := _extract_winning_teams(season_results)
  # _apply_winning_bonus(players, winning_teams)

  # ... existing player lifecycle advancement ...
  # ... existing graduation/draft logic ...

  return {
    # ... existing fields ...
    "season_simulation": {
      "games_simulated": int(season_results.get("total_games", 0)),
      "upsets": int(season_results.get("upsets", 0)),
      "avg_strength_differential": float(season_results.get("avg_diff", 0.0))
    }
  }
```

**Key integration points**:
- Simulation runs BEFORE player lifecycle (W/L record informs development in Phase 3+)
- Uses existing seed derivation pattern (`_derive_seed`)
- Stores results in standard `world_state` dictionary
- Returns summary statistics in phase output (for logging/debugging)

### NflSeason Integration

**Similar pattern to CollegeSeason**:

```gdscript
func run(world_state: Dictionary, year: int, seed: int, league_cfg: Dictionary, ...) -> Dictionary:
  # ... existing roster loading and context application ...

  # NEW: Simulate NFL season (17 weeks + playoffs)
  var sim_seed := _derive_seed(seed, "game_simulation")
  var season_results := _simulate_nfl_season(world_state, year, sim_seed, league_cfg)

  # Store season records
  var season_records: Dictionary = world_state.get("season_records", {})
  if not season_records.has(year):
    season_records[year] = {}
  for team_id in season_results.keys():
    season_records[year][team_id] = season_results[team_id]
  world_state["season_records"] = season_records

  # ... existing player lifecycle advancement ...
  # ... existing retirement/free agency logic ...

  return {
    # ... existing fields ...
    "season_simulation": {
      "regular_season_games": 272,  # 32 teams * 17 weeks / 2
      "playoff_games": int(season_results.get("playoff_games", 0)),
      "super_bowl_winner": String(season_results.get("super_bowl_winner", ""))
    }
  }
```

### World State Schema Evolution

**New top-level keys**:

```gdscript
world_state = {
  # Existing keys (unchanged)
  "hs_players": [...],
  "hs_schools": [...],
  "colleges": [...],
  "college_rosters": {...},
  "nfl_teams": [...],
  "nfl_rosters": {...},
  "draft_pool": {...},

  # NEW: Season simulation results
  "season_records": {
    2025: {
      "college_001": SeasonRecord,
      "college_002": SeasonRecord,
      "nfl_001": SeasonRecord,
      # ... all teams
    },
    2026: {...},
    # ... 20 years
  },

  # NEW (Phase 2+): Championship history
  "championships": {
    "college": {
      "national_champions": {2025: "college_042", 2026: "college_089", ...},
      "conference_champions": {2025: {"SEC": "college_042", ...}, ...}
    },
    "nfl": {
      "super_bowl_winners": {2025: "nfl_015", 2026: "nfl_007", ...},
      "conference_champions": {2025: {"AFC": "nfl_015", "NFC": "nfl_022"}, ...}
    }
  }
}
```

**Storage overhead estimate**:
- SeasonRecord: ~200 bytes per team
- 130 colleges + 32 NFL teams = 162 teams per year
- 162 teams * 200 bytes * 20 years = 648 KB (negligible)

---

## Performance Considerations

### Phase 1 Baseline Performance

**Estimate for 20-year bootstrap**:

```
College games per year:
- 130 teams / 2 = 65 games per week
- 12 weeks = 780 games per year
- 20 years = 15,600 total games

NFL games per year:
- 32 teams / 2 * 17 weeks = 272 games per year
- 20 years = 5,440 total games

Total: 21,040 games

Time per game (Phase 1):
- Team strength calculation: 50 µs (mean of roster ratings)
- Win probability calculation: 5 µs (logistic function)
- Winner determination: 2 µs (RNG roll)
- Result aggregation: 3 µs (dictionary updates)
Total: ~60 µs per game

Expected overhead:
- 21,040 games * 60 µs = 1.26 seconds
- Current 20-year bootstrap: ~40 seconds
- Overhead: 1.26s / 40s = 3.15% ✅ (well under 10% target)
```

**Validation approach**: Implement timing capture (see `BootstrapGameWorld.run(capture_timing: true)`).

### Parallelization Strategy (Phase 4)

**Week-level parallelization** (not game-level):

```gdscript
func _simulate_season_parallel(world_state: Dictionary, year: int, seed: int, cfg: Dictionary) -> Dictionary:
  var weeks := int(cfg.get("regular_season_weeks", 12))
  var thread_pool := WorkerThreadPool.new()
  var week_results: Array = []
  week_results.resize(weeks)

  # Pre-calculate team strengths (shared read-only data)
  var team_strengths := _calculate_all_team_strengths(world_state, year, cfg)

  # Spawn parallel week simulations
  for week in range(1, weeks + 1):
    var week_seed := Rand.splitmix64(seed ^ week)
    var matchups := _generate_week_matchups(week, team_strengths.keys(), week_seed, cfg)

    # Each week runs in parallel thread
    var task_id := thread_pool.add_task(
      func():
        return _simulate_week(matchups, team_strengths, week_seed, cfg)
    )
    week_results[week - 1] = task_id

  # Wait for all weeks to complete
  for i in range(weeks):
    var task_id = week_results[i]
    var week_result = thread_pool.wait_for_task_completion(task_id)
    week_results[i] = week_result

  # Aggregate results (sequential, fast)
  return _aggregate_season_results(week_results)
```

**Why week-level parallelization**:
- Games within week must be sequential (RNG determinism)
- Weeks are independent (can run in parallel)
- 12-17 weeks = good parallel granularity
- Aggregation overhead minimal (happens once per season)

**Thread safety**:
- `team_strengths` is read-only (no locks needed)
- Each week has isolated RNG state (no shared mutable state)
- Results aggregation is sequential (no race conditions)

### Memory Optimization

**Phase 1**: Store only aggregated SeasonRecords (not individual GameResults).

**Phase 3+ (if detailed history needed)**:
- Store championship games only (5-10 games per year)
- Use ring buffer for recent years (keep last 5 years of detailed results)
- Archive older results to disk (optional save files)

---

## Testing Strategy

### Unit Tests

**GameSimulator functions**:
- `calculate_team_strength()`: Various roster compositions
- `calculate_win_probability()`: Boundary cases (equal teams, large differentials, home advantage)
- `determine_winner()`: RNG determinism, upset detection
- `aggregate_results()`: W/L counting, tiebreakers

**Schedule generation**:
- Determinism (same seed = same schedule)
- Coverage (all teams play correct number of games)
- Balance (home/away distribution)

### Integration Tests

**CollegeSeason with simulation**:
- World state correctly updated with season_records
- Player lifecycle still deterministic (seed derivation unchanged)
- Bootstrap completes without errors

**NflSeason with simulation**:
- Similar to college tests
- Division structure respected

### Performance Tests

**Benchmark suite** (see `scripts/tests/benchmark/`):
- 20-year bootstrap with simulation enabled
- Compare to baseline (no simulation)
- Validate <10% overhead constraint

### Validation Tests

**Statistical sanity checks**:
- Home team win rate ~60% (NCAA/NFL expected range)
- Upset rate ~15-20% (favored team by 10+ points loses)
- Team strength distribution (no all-0 or all-100 teams)
- W/L record correlation with team strength (Pearson r > 0.7)

---

## Configuration Files

### Phase 1 Config Additions

**File**: `configs/sports/american_football/world/colleges.json`

```json
{
  "version": 2,
  // ... existing fields ...
  "game_simulation": {
    "enabled": true,
    "regular_season_weeks": 12,
    "home_field_advantage": 3.0,
    "strength_sensitivity": 0.1,
    "calculation_method": "mean_rating"
  }
}
```

**File**: `configs/sports/american_football/world/league.json`

```json
{
  "version": 3,
  // ... existing fields ...
  "game_simulation": {
    "enabled": true,
    "regular_season_weeks": 17,
    "home_field_advantage": 2.5,
    "strength_sensitivity": 0.1,
    "calculation_method": "mean_rating"
  }
}
```

### Feature Flag

**Purpose**: Allow disabling simulation during testing or if bugs discovered.

```gdscript
# In CollegeSeason.run()
var game_sim_cfg: Dictionary = config.get("game_simulation", {})
if not bool(game_sim_cfg.get("enabled", false)):
  # Skip simulation, existing behavior
  pass
else:
  # Run simulation
  var season_results := _simulate_season(world_state, year, seed, config)
```

---

## Migration and Backward Compatibility

### Versioning Strategy

**Config version increments**:
- `colleges.json`: v1 → v2 (adds game_simulation section)
- `league.json`: v2 → v3 (adds game_simulation section)

**World state version**:
- Add `world_state["schema_version"] = 2` when game simulation active
- Loader checks version, skips season_records parsing if schema_version < 2

### Graceful Degradation

**Missing simulation data**:
```gdscript
# UI or export logic
var season_records: Dictionary = world_state.get("season_records", {})
if season_records.is_empty():
  # No simulation ran (older save or disabled feature)
  return "Simulation data not available"
```

**Config migration**:
```gdscript
# Season classes check for game_simulation section
var game_sim_cfg: Dictionary = config.get("game_simulation", {})
if game_sim_cfg.is_empty():
  # Older config, disable simulation
  return _run_without_simulation(world_state, year, seed, config)
```

---

## Future Expansion Hooks

### Phase 2: Conference-Aware Schedules

**College conferences**:
```json
// colleges.json additions
{
  "conferences": [
    {
      "id": "sec",
      "name": "Southeastern Conference",
      "teams": ["college_001", "college_002", ...],
      "divisions": [
        {"id": "east", "teams": ["college_001", ...]},
        {"id": "west", "teams": ["college_002", ...]}
      ]
    }
  ],
  "bowl_games": [
    {
      "id": "rose_bowl",
      "name": "Rose Bowl",
      "week": 15,
      "selection_criteria": {
        "conference": ["big_ten", "pac_12"],
        "rank_requirement": "top_2_in_conference"
      }
    }
  ]
}
```

**NFL playoffs**:
```json
// league.json additions
{
  "playoffs": {
    "teams_per_conference": 7,
    "wildcard_round_week": 18,
    "divisional_round_week": 19,
    "conference_championship_week": 20,
    "super_bowl_week": 21,
    "seeding_criteria": {
      "division_winners": 4,
      "wildcards": 3,
      "tiebreakers": ["head_to_head", "division_record", "conference_record", "strength_of_victory"]
    }
  }
}
```

### Phase 3: Player-Level Impact

**Development context from season success**:
```gdscript
# In CollegeSeason._apply_development_context()
var team_record := season_results.get(college_id, {})
var win_pct := float(team_record.get("wins", 0)) / float(team_record.get("wins", 0) + team_record.get("losses", 1))

var winning_bonus := 1.0
if win_pct >= 0.75:
  winning_bonus = 1.05  # 5% dev boost for winning teams
elif win_pct >= 0.60:
  winning_bonus = 1.02

context["winning_bonus"] = winning_bonus
```

**Per-player game stats** (memory intensive, opt-in):
```gdscript
{
  "player_game_stats": {
    "player_123": {
      2025: {
        "games_played": 12,
        "starts": 10,
        "performance_scores": [85.3, 72.1, 91.4, ...]  # Per-game ratings
      }
    }
  }
}
```

### Phase 4: Advanced Scoring

**Score generation algorithm**:
```gdscript
func generate_score(winner_strength: float, loser_strength: float, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
  # Expected points based on team strength
  var winner_expected := 17.0 + (winner_strength - 50.0) * 0.5  # Range: ~0-42 points
  var loser_expected := 17.0 + (loser_strength - 50.0) * 0.5

  # Add variance (games aren't perfectly predictable)
  var winner_variance := rng.randf_range(-7.0, 14.0)  # Offense can have big days
  var loser_variance := rng.randf_range(-7.0, 7.0)

  var winner_score := int(max(0.0, winner_expected + winner_variance))
  var loser_score := int(max(0.0, loser_expected + loser_variance))

  # Ensure winner actually won
  if loser_score >= winner_score:
    loser_score = winner_score - rng.randi_range(1, 7)

  return {
    "winner_score": winner_score,
    "loser_score": max(0, loser_score)
  }
```

---

## Acceptance Criteria

### Phase 1 (MVP) Definition of Done

- [ ] `GameSimulator` class with pure functions (schedule, winner determination, aggregation)
- [ ] `CollegeSeason.run()` calls `_simulate_season()` and stores season_records
- [ ] `NflSeason.run()` calls `_simulate_nfl_season()` and stores season_records
- [ ] Config files updated with `game_simulation` sections
- [ ] World state includes `season_records` with W/L for all teams across 20 years
- [ ] Unit tests for all GameSimulator functions (>95% coverage)
- [ ] Integration test: 20-year bootstrap completes with simulation enabled
- [ ] Performance test: Bootstrap overhead <10% compared to baseline
- [ ] Statistical validation: Home win rate 55-65%, upset rate 10-25%
- [ ] Documentation: Code comments explain RNG patterns and determinism

### Phase 2 Criteria (Future)

- [ ] Conference structures loaded from config
- [ ] Conference championship games simulated (college)
- [ ] Bowl game selection based on conference standings
- [ ] NFL playoff bracket generation and simulation
- [ ] Super Bowl winner stored in world_state
- [ ] Historical championship tracking in `world_state["championships"]`

### Phase 3 Criteria (Future)

- [ ] Winning team development bonus applied to player lifecycle
- [ ] Playoff experience multipliers in development context
- [ ] Per-player performance tracking (optional, config-enabled)
- [ ] Injury simulation during games (separate design required)

### Phase 4 Criteria (Future)

- [ ] Week-level parallel execution (thread pool)
- [ ] Performance improvement: >30% speedup for simulation phase
- [ ] Lock-free result aggregation
- [ ] Determinism validation: parallel == sequential results

---

## Risk Assessment

### High Risk Areas

**Determinism violations**:
- Mitigation: Strict RNG patterns, sequential game simulation within weeks
- Validation: Automated tests compare multiple runs with same seed

**Performance regression**:
- Mitigation: Phase 1 overhead estimate (3%), timing capture in bootstrap
- Validation: Benchmark suite with <10% threshold alert

**Architectural drift**:
- Mitigation: Follow existing patterns (Season classes, config-driven, world_state mutation)
- Validation: Architecture review before Phase 2 implementation

### Medium Risk Areas

**Config versioning complexity**:
- Mitigation: Simple version integers, graceful degradation for missing sections
- Validation: Test bootstrap with v1 and v2+ configs

**World state growth**:
- Mitigation: Store only aggregated results in Phase 1, ring buffer in Phase 3+
- Validation: Measure world_state size with simulation enabled (target: <1 MB increase)

### Low Risk Areas

**Schedule generation bugs**:
- Mitigation: Comprehensive unit tests, manual validation of sample schedules
- Impact: Isolated to game simulation, doesn't break existing systems

**Statistical anomalies**:
- Mitigation: Validation tests for win rate, upset frequency, etc.
- Impact: Affects realism but not correctness (can tune parameters)

---

## Appendices

### A. Existing RNG Patterns

**Standard seed derivation**:
```gdscript
# From AdvanceWorldYear._derive_seed()
func _derive_seed(year_seed: int, phase_id: String, step_id: String) -> int:
  var key := "%s:%s" % [phase_id, step_id]
  var hash := _fnv1a_64(key)
  return Rand.splitmix64(year_seed ^ hash)
```

**Season-level RNG usage**:
```gdscript
# From CollegeSeason.run()
var lifecycle_rng := RandomNumberGenerator.new()
lifecycle_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E1)

var context_rng := RandomNumberGenerator.new()
context_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E2)
```

**Game simulation follows same pattern**:
```gdscript
# In CollegeSeason._simulate_season()
var sim_rng := RandomNumberGenerator.new()
sim_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E4)  # Unique salt for simulation
```

### B. Real-World Statistics (for validation)

**NCAA FBS (2023 season)**:
- Home team win rate: 58.3%
- Upset rate (underdog by 10+ points wins): 18.2%
- Average point differential: 14.3 points
- Mean team strength (SP+): 50.0 (by definition)

**NFL (2023 season)**:
- Home team win rate: 57.1%
- Upset rate (underdog by 7+ points wins): 22.4%
- Average point differential: 11.8 points
- Parity index (std dev of W/L): 2.8 wins

**Target for Phase 1**:
- Home win rate: 55-65% (validate with statistical test)
- Upset rate: 15-25% (validate with threshold test)
- Strength correlation: r > 0.6 (validate with Pearson correlation)

### C. References

**Existing architecture**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/HighSchoolSeason.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/pipelines/BootstrapGameWorld.gd`
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/pipelines/AdvanceWorldYear.gd`

**Config files**:
- `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/world/colleges.json`
- `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/world/league.json`
- `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/world/calendar.json`

**Performance optimization patterns**:
- `/home/patrick/Documents/code/gridiron-dynasty/docs/tasks/TASK_F5_parallel_lifecycle.md`
- `/home/patrick/Documents/code/gridiron-dynasty/docs/PHASE_F_ROADMAP.md`

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial design specification |

---

**Next Steps**: Review this architecture document, then proceed to implementation planning document.
