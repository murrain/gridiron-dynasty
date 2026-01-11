# Game Simulation Technical Specifications

**Task ID**: GAME_SIM_1 (Phase 1 - MVP)
**Version**: 1.0
**Date**: 2026-01-11
**Author**: Architecture Guardian

---

## Purpose

This document provides detailed technical specifications for implementing the game simulation system Phase 1 (MVP). All algorithms, data structures, and implementation details are specified here.

---

## Table of Contents

1. [Data Structures](#data-structures)
2. [Algorithm Specifications](#algorithm-specifications)
3. [RNG Determinism Patterns](#rng-determinism-patterns)
4. [Configuration Schema](#configuration-schema)
5. [World State Schema](#world-state-schema)
6. [API Reference](#api-reference)
7. [Implementation Examples](#implementation-examples)

---

## Data Structures

### GameMatchup

Represents a scheduled game before simulation.

```gdscript
{
  "game_id": String,           # Unique identifier: "college_2025_w1_g3"
  "year": int,                 # 2025
  "week": int,                 # 1-12 (college), 1-17 (NFL)
  "home_team_id": String,      # "college_042"
  "away_team_id": String,      # "college_089"
  "game_type": String,         # "regular", "conference_championship", "bowl", "playoff", "super_bowl"
}
```

### GameResult

Represents the outcome of a simulated game.

```gdscript
{
  "game_id": String,           # Same as GameMatchup
  "year": int,
  "week": int,
  "home_team_id": String,
  "away_team_id": String,
  "winner_id": String,         # home_team_id or away_team_id
  "loser_id": String,          # The other team
  "home_score": int,           # 0 in Phase 1 (not implemented yet)
  "away_score": int,           # 0 in Phase 1
  "game_type": String,
  "is_overtime": bool,         # false in Phase 1
  "upset": bool,               # true if underdog by >5 points won
  "strength_differential": float,  # abs(winner_strength - loser_strength)
  "win_probability": float     # Probability of winner winning (0.0-1.0)
}
```

### SeasonRecord

Aggregated season results for a single team.

```gdscript
{
  "team_id": String,           # "college_042"
  "year": int,                 # 2025
  "wins": int,                 # 10
  "losses": int,               # 2
  "conference_wins": int,      # 0 in Phase 1 (not implemented)
  "conference_losses": int,    # 0 in Phase 1
  "strength_of_schedule": float,  # Mean opponent strength (0.0-100.0)
  "point_differential": int,   # 0 in Phase 1 (no scores yet)
  "playoff_appearance": bool,  # false in Phase 1
  "bowl_game": String,         # "" in Phase 1
  "championship_winner": bool, # false in Phase 1
  "super_bowl_winner": bool    # false in Phase 1 (NFL only)
}
```

### TeamStrength

Cached team strength calculation.

```gdscript
{
  "team_id": String,           # "college_042"
  "year": int,                 # 2025
  "week": int,                 # 0 in Phase 1 (pre-season calculation)
  "strength": float,           # 72.5 (0.0-100.0 scale)
  "offensive_strength": float, # 0.0 in Phase 1 (not implemented)
  "defensive_strength": float, # 0.0 in Phase 1
  "depth_penalty": float,      # 0.0 in Phase 1
  "roster_size": int,          # 85
  "calculation_method": String # "mean_rating"
}
```

---

## Algorithm Specifications

### 1. Team Strength Calculation

**Method**: `GameSimulator.calculate_team_strength()`

**Purpose**: Compute a single numeric strength value (0.0-100.0) representing a team's quality based on roster composition.

**Phase 1 Algorithm**: Mean of all player overall ratings.

**Inputs**:
- `roster`: Dictionary with `"players"` array
- `positions_cfg`: Dictionary mapping positions to core stats
- `main_cfg`: Dictionary with `"class_rules"` for rating calculation

**Outputs**:
- `float`: Team strength (0.0-100.0)

**Algorithm**:

```gdscript
func calculate_team_strength(
  roster: Dictionary,
  positions_cfg: Dictionary,
  main_cfg: Dictionary
) -> float:
  var players: Array = roster.get("players", [])

  # Edge case: Empty roster
  if players.is_empty():
    return 50.0  # Default to neutral strength

  var class_rules: Dictionary = main_cfg.get("class_rules", {})
  var total := 0.0
  var count := 0

  # Calculate overall rating for each player
  for player in players:
    var p: Dictionary = player
    var rating := PlayerRatingCalculator.calculate_overall_rating(
      p,
      positions_cfg,
      class_rules
    )
    total += rating
    count += 1

  # Return mean rating
  return total / float(count) if count > 0 else 50.0
```

**Performance**: O(n) where n = roster size. ~50 µs for 85-player roster.

**Edge Cases**:
- Empty roster: Return 50.0 (neutral strength)
- Single player: Return that player's rating
- All players rated 0: Return 0.0 (possible but unlikely)

**Future Enhancements (Phase 2+)**:
- Weight by position importance (QB more valuable than special teams)
- Account for depth chart (starters vs backups)
- Apply context multipliers (injuries, suspensions)

---

### 2. Win Probability Calculation

**Method**: `GameSimulator.calculate_win_probability()`

**Purpose**: Compute the probability that team A beats team B using a logistic function based on strength differential and home field advantage.

**Inputs**:
- `team_a_strength`: float (0.0-100.0)
- `team_b_strength`: float (0.0-100.0)
- `is_home`: bool (is team_a playing at home?)
- `cfg`: Dictionary with `"home_field_advantage"` and `"strength_sensitivity"`

**Outputs**:
- `float`: Probability team A wins (0.01-0.99, clamped)

**Algorithm**:

```gdscript
func calculate_win_probability(
  team_a_strength: float,
  team_b_strength: float,
  is_home: bool,
  cfg: Dictionary
) -> float:
  var diff := team_a_strength - team_b_strength

  # Apply home field advantage (Phase 1: +3 points equivalent)
  if is_home:
    var home_advantage := float(cfg.get("home_field_advantage", 3.0))
    diff += home_advantage

  # Logistic function: P(win) = 1 / (1 + e^(-k * diff))
  # k = 0.1 gives reasonable spread:
  #   diff=0  -> P=0.50 (50/50 game)
  #   diff=10 -> P=0.73 (73% favorite)
  #   diff=20 -> P=0.88 (88% favorite)
  #   diff=30 -> P=0.95 (95% favorite)
  var k := float(cfg.get("strength_sensitivity", 0.1))
  var exponent := -k * diff
  var probability := 1.0 / (1.0 + exp(exponent))

  # Clamp to prevent 100% certainty (upsets always possible)
  return clamp(probability, 0.01, 0.99)
```

**Mathematical Properties**:
- **Symmetric**: `P(A beats B) = 1 - P(B beats A)`
- **Monotonic**: Higher strength differential = higher win probability
- **Bounded**: Always in range (0.01, 0.99)
- **Home advantage**: +3 strength equivalent to ~58% win rate for equal teams

**Parameter Tuning**:
- `home_field_advantage`: 2.5 (NFL) to 3.5 (college)
- `strength_sensitivity`: 0.08 (more upsets) to 0.12 (fewer upsets)

**Performance**: O(1), ~5 µs per call.

**Edge Cases**:
- Equal strength, no home advantage: Returns 0.50
- Extreme differential (>50 points): Returns 0.99 (not 1.00)
- Negative differential: Works correctly (team B favored)

---

### 3. Winner Determination

**Method**: `GameSimulator.determine_winner()`

**Purpose**: Simulate a single game by rolling RNG against win probability and returning the result.

**Inputs**:
- `game_matchup`: Dictionary (GameMatchup structure)
- `team_strengths`: Dictionary mapping team_id -> strength
- `rng`: RandomNumberGenerator (explicitly passed)
- `cfg`: Dictionary with simulation config

**Outputs**:
- `Dictionary`: GameResult structure

**Algorithm**:

```gdscript
func determine_winner(
  game_matchup: Dictionary,
  team_strengths: Dictionary,
  rng: RandomNumberGenerator,
  cfg: Dictionary
) -> Dictionary:
  var home_id := String(game_matchup.get("home_team_id", ""))
  var away_id := String(game_matchup.get("away_team_id", ""))

  # Fetch team strengths (default to 50.0 if missing)
  var home_strength := float(team_strengths.get(home_id, 50.0))
  var away_strength := float(team_strengths.get(away_id, 50.0))

  # Calculate win probability for home team
  var home_win_prob := calculate_win_probability(
    home_strength,
    away_strength,
    true,  # is_home = true
    cfg
  )

  # RNG roll (CRITICAL: This is the only RNG consumption in this function)
  var roll := rng.randf()  # 0.0-1.0

  # Determine winner
  var home_wins := (roll < home_win_prob)

  # Detect upsets (underdog by >5 points wins)
  var upset := false
  var upset_threshold := float(cfg.get("upset_threshold", 5.0))
  if home_wins and away_strength > home_strength + upset_threshold:
    upset = true  # Away team was favored but lost
  elif not home_wins and home_strength > away_strength + upset_threshold:
    upset = true  # Home team was favored but lost

  # Construct result
  return {
    "game_id": String(game_matchup.get("game_id", "")),
    "year": int(game_matchup.get("year", 0)),
    "week": int(game_matchup.get("week", 0)),
    "home_team_id": home_id,
    "away_team_id": away_id,
    "winner_id": home_id if home_wins else away_id,
    "loser_id": away_id if home_wins else home_id,
    "home_score": 0,  # Phase 1: Not implemented
    "away_score": 0,  # Phase 1: Not implemented
    "game_type": String(game_matchup.get("game_type", "regular")),
    "is_overtime": false,  # Phase 1: Not implemented
    "upset": upset,
    "strength_differential": abs(home_strength - away_strength),
    "win_probability": home_win_prob if home_wins else (1.0 - home_win_prob)
  }
```

**RNG Consumption**: Exactly 1 call (`randf()`). This is critical for determinism.

**Performance**: O(1), ~2 µs per call.

**Edge Cases**:
- Missing team strengths: Default to 50.0
- Identical teams: 50/50 outcome (with home advantage applied)
- RNG roll exactly at threshold: Home wins (roll < prob)

---

### 4. Schedule Generation (College)

**Method**: `GameSimulator.generate_college_schedule()`

**Purpose**: Generate a fixed schedule of matchups for the college regular season using round-robin rotation.

**Phase 1 Algorithm**: Simplified round-robin (no conference structure).

**Inputs**:
- `colleges`: Array of college dictionaries with `"id"` field
- `year`: int (for game_id generation)
- `weeks`: int (typically 12)
- `seed`: int (for deterministic shuffling)

**Outputs**:
- `Array[Dictionary]`: Array of GameMatchup structures

**Algorithm**:

```gdscript
func generate_college_schedule(
  colleges: Array,
  year: int,
  weeks: int,
  seed: int
) -> Array[Dictionary]:
  var schedule: Array[Dictionary] = []

  # Extract college IDs
  var team_ids: Array = []
  for college in colleges:
    var c: Dictionary = college
    team_ids.append(String(c.get("id", "")))

  # Ensure even number of teams (add bye if necessary)
  if team_ids.size() % 2 != 0:
    team_ids.append("BYE")  # Bye week placeholder

  # Shuffle teams for randomness (deterministic based on seed)
  var rng := RandomNumberGenerator.new()
  rng.seed = seed
  team_ids.shuffle()  # GDScript's shuffle uses internal RNG state

  var num_teams := team_ids.size()
  var games_per_week := num_teams / 2

  # Round-robin rotation algorithm
  # Team at index 0 stays fixed, others rotate clockwise
  for week in range(1, weeks + 1):
    # Generate matchups for this week
    for game_idx in range(games_per_week):
      var home_idx := game_idx
      var away_idx := num_teams - 1 - game_idx

      var home_id := team_ids[home_idx]
      var away_id := team_ids[away_idx]

      # Skip bye games
      if home_id == "BYE" or away_id == "BYE":
        continue

      # Alternate home/away each week (home team has lower index in odd weeks)
      if week % 2 == 0:
        var temp := home_id
        home_id = away_id
        away_id = temp

      var game_id := "college_%d_w%d_g%d" % [year, week, game_idx]
      schedule.append({
        "game_id": game_id,
        "year": year,
        "week": week,
        "home_team_id": home_id,
        "away_team_id": away_id,
        "game_type": "regular"
      })

    # Rotate teams (keep index 0 fixed, rotate others)
    if week < weeks:
      var last := team_ids.pop_back()
      team_ids.insert(1, last)

  return schedule
```

**Properties**:
- **Coverage**: Each team plays `weeks` games
- **Balance**: Home/away alternates each week
- **Determinism**: Same seed + colleges = same schedule
- **Performance**: O(weeks * teams), ~1 ms for 130 teams * 12 weeks

**Edge Cases**:
- Odd number of teams: Add "BYE" placeholder (filtered out)
- 0 weeks: Return empty schedule
- 1 team: Cannot generate schedule (minimum 2 teams)

**Limitations (Phase 1)**:
- No conference structure (all teams play each other randomly)
- No rivalry games (fixed rotation)
- No conference championship or bowl games

---

### 5. Schedule Generation (NFL)

**Method**: `GameSimulator.generate_nfl_schedule()`

**Purpose**: Generate a simplified NFL schedule with division-based matchups.

**Phase 1 Algorithm**: 6 intra-division games + 11 inter-division games (random rotation).

**Inputs**:
- `teams`: Array of team dictionaries with `"id"` and `"region"` fields
- `divisions`: Array of division dictionaries (from config regions)
- `year`: int (for game_id generation)
- `seed`: int (for deterministic rotation)

**Outputs**:
- `Array[Dictionary]`: Array of GameMatchup structures

**Algorithm**:

```gdscript
func generate_nfl_schedule(
  teams: Array,
  divisions: Array,
  year: int,
  seed: int
) -> Array[Dictionary]:
  var schedule: Array[Dictionary] = []

  # Build division map (team_id -> division_id)
  var team_to_division := {}
  for team in teams:
    var t: Dictionary = team
    var team_id := String(t.get("id", ""))
    var region := String(t.get("region", ""))
    team_to_division[team_id] = region

  # Group teams by division
  var divisions_map := {}  # division_id -> [team_ids]
  for team in teams:
    var t: Dictionary = team
    var team_id := String(t.get("id", ""))
    var division_id := String(t.get("region", ""))
    if not divisions_map.has(division_id):
      divisions_map[division_id] = []
    (divisions_map[division_id] as Array).append(team_id)

  var rng := RandomNumberGenerator.new()
  rng.seed = seed
  var week := 1
  var game_counter := 0

  # Phase 1: Intra-division games (weeks 1-6)
  # Each team plays division opponents twice (home and away)
  for division_id in divisions_map.keys():
    var div_teams: Array = divisions_map[division_id]
    if div_teams.size() < 2:
      continue  # Skip invalid divisions

    # Round 1: Home games
    for i in range(div_teams.size()):
      for j in range(i + 1, div_teams.size()):
        var home_id := String(div_teams[i])
        var away_id := String(div_teams[j])

        var game_id := "nfl_%d_w%d_g%d" % [year, week, game_counter]
        schedule.append({
          "game_id": game_id,
          "year": year,
          "week": week,
          "home_team_id": home_id,
          "away_team_id": away_id,
          "game_type": "regular"
        })
        game_counter += 1

        # Advance week periodically (distribute games)
        if game_counter % 8 == 0:
          week += 1

    # Round 2: Away games (return matchups)
    for i in range(div_teams.size()):
      for j in range(i + 1, div_teams.size()):
        var home_id := String(div_teams[j])  # Reversed
        var away_id := String(div_teams[i])

        var game_id := "nfl_%d_w%d_g%d" % [year, week, game_counter]
        schedule.append({
          "game_id": game_id,
          "year": year,
          "week": week,
          "home_team_id": home_id,
          "away_team_id": away_id,
          "game_type": "regular"
        })
        game_counter += 1

        if game_counter % 8 == 0:
          week += 1

  # Phase 2: Inter-division games (weeks 7-17)
  # Simplified: Random matchups across divisions
  var all_teams := []
  for team in teams:
    var t: Dictionary = team
    all_teams.append(String(t.get("id", "")))

  all_teams.shuffle()  # Deterministic shuffle (RNG from seed)

  while week <= 17:
    for i in range(0, all_teams.size(), 2):
      if i + 1 >= all_teams.size():
        break

      var home_id := all_teams[i]
      var away_id := all_teams[i + 1]

      var game_id := "nfl_%d_w%d_g%d" % [year, week, game_counter]
      schedule.append({
        "game_id": game_id,
        "year": year,
        "week": week,
        "home_team_id": home_id,
        "away_team_id": away_id,
        "game_type": "regular"
      })
      game_counter += 1

    week += 1
    all_teams.shuffle()  # Re-shuffle for next week

  return schedule
```

**Properties**:
- **Division matchups**: Each team plays division opponents 2x (home/away)
- **Inter-division**: Random rotation for remaining games
- **Total games**: 17 per team (6 divisional + 11 inter-divisional)
- **Determinism**: Same seed = same schedule
- **Performance**: O(teams^2), ~2 ms for 32 teams

**Limitations (Phase 1)**:
- No realistic NFL schedule rotation (division vs division)
- No bye weeks
- No playoffs or Super Bowl

---

### 6. Season Result Aggregation

**Method**: `GameSimulator.aggregate_season_results()`

**Purpose**: Convert array of GameResult into per-team SeasonRecord dictionaries.

**Inputs**:
- `game_results`: Array[Dictionary] (GameResult structures)
- `team_ids`: Array (all team IDs in league)

**Outputs**:
- `Dictionary`: Mapping team_id -> SeasonRecord

**Algorithm**:

```gdscript
func aggregate_season_results(
  game_results: Array[Dictionary],
  team_ids: Array
) -> Dictionary:
  # Initialize season records for all teams
  var season_records := {}
  for team_id in team_ids:
    season_records[team_id] = {
      "team_id": team_id,
      "year": 0,  # Will be set from first game
      "wins": 0,
      "losses": 0,
      "conference_wins": 0,     # Phase 1: Not implemented
      "conference_losses": 0,   # Phase 1: Not implemented
      "strength_of_schedule": 0.0,  # Computed below
      "point_differential": 0,  # Phase 1: Not implemented
      "playoff_appearance": false,
      "bowl_game": "",
      "championship_winner": false,
      "super_bowl_winner": false
    }

  # Aggregate W/L from game results
  for result in game_results:
    var r: Dictionary = result
    var winner_id := String(r.get("winner_id", ""))
    var loser_id := String(r.get("loser_id", ""))
    var year := int(r.get("year", 0))

    if season_records.has(winner_id):
      var winner_record: Dictionary = season_records[winner_id]
      winner_record["wins"] += 1
      winner_record["year"] = year

    if season_records.has(loser_id):
      var loser_record: Dictionary = season_records[loser_id]
      loser_record["losses"] += 1
      loser_record["year"] = year

  # Compute strength of schedule (mean opponent strength)
  # For Phase 1: Use win percentage as proxy for strength
  var team_strengths := {}
  for team_id in season_records.keys():
    var record: Dictionary = season_records[team_id]
    var total_games := int(record["wins"]) + int(record["losses"])
    var win_pct := float(record["wins"]) / float(max(1, total_games))
    team_strengths[team_id] = win_pct * 100.0

  # Calculate SOS for each team
  for result in game_results:
    var r: Dictionary = result
    var home_id := String(r.get("home_team_id", ""))
    var away_id := String(r.get("away_team_id", ""))

    # Add opponent strength to SOS accumulator
    if season_records.has(home_id):
      var home_record: Dictionary = season_records[home_id]
      var opp_strength := float(team_strengths.get(away_id, 50.0))
      home_record["strength_of_schedule"] = float(home_record.get("strength_of_schedule", 0.0)) + opp_strength

    if season_records.has(away_id):
      var away_record: Dictionary = season_records[away_id]
      var opp_strength := float(team_strengths.get(home_id, 50.0))
      away_record["strength_of_schedule"] = float(away_record.get("strength_of_schedule", 0.0)) + opp_strength

  # Normalize SOS (divide by number of games)
  for team_id in season_records.keys():
    var record: Dictionary = season_records[team_id]
    var total_games := int(record["wins"]) + int(record["losses"])
    if total_games > 0:
      record["strength_of_schedule"] = float(record.get("strength_of_schedule", 0.0)) / float(total_games)

  return season_records
```

**Performance**: O(n) where n = number of games. ~10 µs for 1000 games.

**Edge Cases**:
- Team with 0 games: W/L = 0, SOS = 0.0
- All teams undefeated: SOS based on circular logic (acceptable approximation)

---

## RNG Determinism Patterns

### Seed Derivation

**Pattern**: Use existing `Rand.splitmix64()` with XOR for domain separation.

**Example**:

```gdscript
# In CollegeSeason.run()
var season_seed := Rand.splitmix64(seed ^ 0xC011E6E4)  # Unique salt for game simulation

# Per-week seed (if needed)
var week_seed := Rand.splitmix64(season_seed ^ week_number)
```

**Domain Salts**:
- CollegeSeason simulation: `0xC011E6E4`
- NflSeason simulation: `0x5EA50004`
- Per-week (if parallelized): `season_seed ^ week_number`

### RNG Consumption Order

**Critical**: Games within a week must be simulated sequentially to maintain determinism.

**Pattern**:

```gdscript
# CORRECT: Sequential simulation
var rng := RandomNumberGenerator.new()
rng.seed = week_seed
for game in week_matchups:
  var result := determine_winner(game, strengths, rng, cfg)
  # rng state advances by 1 call (randf)
  results.append(result)

# INCORRECT: Parallel simulation (non-deterministic)
# Thread 1 and Thread 2 may call randf in arbitrary order
# DO NOT DO THIS in Phase 1
```

**Validation**: Unit test runs simulation twice with same seed, asserts identical results.

---

## Configuration Schema

### colleges.json (Phase 1 additions)

```json
{
  "version": 2,
  "college_count": 130,
  "game_simulation": {
    "enabled": true,
    "regular_season_weeks": 12,
    "home_field_advantage": 3.0,
    "strength_sensitivity": 0.1,
    "upset_threshold": 5.0,
    "calculation_method": "mean_rating"
  }
}
```

**Fields**:
- `enabled`: bool - Feature flag to enable/disable simulation
- `regular_season_weeks`: int - Number of weeks in regular season (12)
- `home_field_advantage`: float - Strength boost for home team (2.5-3.5)
- `strength_sensitivity`: float - Logistic curve steepness (0.08-0.12)
- `upset_threshold`: float - Strength differential for upset detection (5.0)
- `calculation_method`: String - Always "mean_rating" in Phase 1

### league.json (Phase 1 additions)

```json
{
  "version": 3,
  "team_count": 32,
  "game_simulation": {
    "enabled": true,
    "regular_season_weeks": 17,
    "home_field_advantage": 2.5,
    "strength_sensitivity": 0.1,
    "upset_threshold": 7.0,
    "calculation_method": "mean_rating"
  }
}
```

**Differences from college**:
- `regular_season_weeks`: 17 (NFL)
- `home_field_advantage`: 2.5 (slightly lower than college)
- `upset_threshold`: 7.0 (NFL has more parity)

---

## World State Schema

### New Top-Level Keys

```gdscript
world_state = {
  # Existing keys (unchanged)
  "hs_players": [...],
  "colleges": [...],
  "college_rosters": {...},
  "nfl_teams": [...],
  "nfl_rosters": {...},

  # NEW: Season simulation results
  "season_records": {
    2025: {
      "college_001": {
        "team_id": "college_001",
        "year": 2025,
        "wins": 10,
        "losses": 2,
        "conference_wins": 0,
        "conference_losses": 0,
        "strength_of_schedule": 68.3,
        "point_differential": 0,
        "playoff_appearance": false,
        "bowl_game": "",
        "championship_winner": false,
        "super_bowl_winner": false
      },
      "college_002": {...},
      "nfl_001": {...},
      # ... all teams
    },
    2026: {...},
    # ... 20 years
  }
}
```

**Storage Size Estimate**:
- SeasonRecord: ~200 bytes per team
- 162 teams (130 college + 32 NFL) * 200 bytes * 20 years = 648 KB
- Total world_state increase: <1 MB

---

## API Reference

### GameSimulator Class

```gdscript
extends RefCounted
class_name GameSimulator

## Calculates team strength from roster (Phase 1: mean rating)
## RNG consumption: None (pure calculation)
## Performance: O(n) where n = roster size (~50 µs for 85 players)
static func calculate_team_strength(
  roster: Dictionary,
  positions_cfg: Dictionary,
  main_cfg: Dictionary
) -> float

## Calculates win probability using logistic curve
## RNG consumption: None (pure math)
## Performance: O(1) (~5 µs)
static func calculate_win_probability(
  team_a_strength: float,
  team_b_strength: float,
  is_home: bool,
  cfg: Dictionary
) -> float

## Determines winner for a single game
## RNG consumption: 1 call (randf)
## Performance: O(1) (~2 µs)
static func determine_winner(
  game_matchup: Dictionary,
  team_strengths: Dictionary,
  rng: RandomNumberGenerator,
  cfg: Dictionary
) -> Dictionary

## Generates round-robin schedule for college (simplified)
## RNG consumption: N calls for shuffle (N = team count)
## Performance: O(weeks * teams) (~1 ms for 130 teams * 12 weeks)
static func generate_college_schedule(
  colleges: Array,
  year: int,
  weeks: int,
  seed: int
) -> Array[Dictionary]

## Generates simplified NFL schedule
## RNG consumption: N calls for shuffle (N = team count * weeks)
## Performance: O(teams^2) (~2 ms for 32 teams)
static func generate_nfl_schedule(
  teams: Array,
  divisions: Array,
  year: int,
  seed: int
) -> Array[Dictionary]

## Aggregates game results into season records
## RNG consumption: None (pure aggregation)
## Performance: O(n) where n = number of games (~10 µs for 1000 games)
static func aggregate_season_results(
  game_results: Array[Dictionary],
  team_ids: Array
) -> Dictionary
```

---

## Implementation Examples

### Example 1: Calculate Team Strength

```gdscript
# Load roster from world_state
var rosters: Dictionary = world_state.get("college_rosters", {})
var roster: Dictionary = rosters.get("college_042", {})

# Load configs
var positions_cfg: Dictionary = _get_config().get_config("positions")
var main_cfg: Dictionary = _get_config().get_config("main")

# Calculate strength
var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
print("Team strength: %.1f" % strength)  # e.g., "Team strength: 72.5"
```

### Example 2: Simulate Single Game

```gdscript
# Setup
var matchup := {
  "game_id": "college_2025_w1_g1",
  "year": 2025,
  "week": 1,
  "home_team_id": "college_042",
  "away_team_id": "college_089",
  "game_type": "regular"
}

var team_strengths := {
  "college_042": 75.0,
  "college_089": 68.0
}

var rng := RandomNumberGenerator.new()
rng.seed = 12345

var cfg := {
  "home_field_advantage": 3.0,
  "strength_sensitivity": 0.1,
  "upset_threshold": 5.0
}

# Simulate
var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)

print("Winner: %s" % result["winner_id"])
print("Upset: %s" % ("Yes" if result["upset"] else "No"))
print("Win probability: %.1f%%" % (result["win_probability"] * 100.0))
```

### Example 3: Full Season Simulation

```gdscript
# In CollegeSeason.run()
func _simulate_season(world_state: Dictionary, year: int, seed: int, config: Dictionary) -> Dictionary:
  var game_sim_cfg: Dictionary = config.get("game_simulation", {})
  if not bool(game_sim_cfg.get("enabled", false)):
    return {}

  # Load data
  var colleges: Array = world_state.get("colleges", [])
  var rosters: Dictionary = world_state.get("college_rosters", {})
  var positions_cfg: Dictionary = _get_config().get_config("positions")
  var main_cfg: Dictionary = _get_config().get_config("main")

  # Calculate team strengths (cache)
  var team_strengths := {}
  for college in colleges:
    var c: Dictionary = college
    var college_id := String(c.get("id", ""))
    if rosters.has(college_id):
      var roster: Dictionary = rosters[college_id]
      var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
      team_strengths[college_id] = strength

  # Generate schedule
  var weeks := int(game_sim_cfg.get("regular_season_weeks", 12))
  var schedule := GameSimulator.generate_college_schedule(colleges, year, weeks, seed)

  # Simulate games (sequential for determinism)
  var rng := RandomNumberGenerator.new()
  rng.seed = seed
  var all_results: Array[Dictionary] = []

  for matchup in schedule:
    var result := GameSimulator.determine_winner(matchup, team_strengths, rng, game_sim_cfg)
    all_results.append(result)

  # Aggregate results
  var college_ids := colleges.map(func(c): return String(c.get("id", "")))
  var season_results := GameSimulator.aggregate_season_results(all_results, college_ids)

  return season_results
```

---

## Testing Checklist

### Unit Tests

- [ ] `test_calculate_team_strength_empty_roster`
- [ ] `test_calculate_team_strength_single_player`
- [ ] `test_calculate_team_strength_full_roster`
- [ ] `test_calculate_win_probability_equal_teams`
- [ ] `test_calculate_win_probability_home_advantage`
- [ ] `test_calculate_win_probability_strong_favorite`
- [ ] `test_determine_winner_determinism`
- [ ] `test_determine_winner_upset_detection`
- [ ] `test_generate_college_schedule_coverage`
- [ ] `test_generate_college_schedule_determinism`
- [ ] `test_generate_nfl_schedule_divisions`
- [ ] `test_aggregate_season_results_wl_counts`

### Integration Tests

- [ ] `test_college_season_simulation_integration`
- [ ] `test_nfl_season_simulation_integration`
- [ ] `test_simulation_determinism`
- [ ] `test_simulation_disabled_feature_flag`

### Performance Tests

- [ ] `benchmark_20_year_bootstrap_overhead`
- [ ] `benchmark_single_season_simulation`

### Validation Tests

- [ ] `test_home_win_rate_realistic`
- [ ] `test_upset_frequency_realistic`
- [ ] `test_strength_correlation`

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial technical specifications |

---

**Next Steps**: Begin implementation with `GameSimulator` class creation.
