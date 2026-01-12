# Quick Wins List - High Impact, Low Complexity Features

**Document Version**: 1.0
**Date**: 2026-01-11
**Author**: Architecture Guardian
**Purpose**: Implementation guide for 18 Quadrant 1 features (Phase 1)

---

## Overview

This document provides detailed implementation guidance for all 18 **High Impact + Low/Medium Complexity** features identified in the Feature Priority Matrix. These are the "quick wins" that deliver maximum realism improvement for minimal development effort.

**Total Timeline**: 11 weeks (~54 implementation days)
**Expected Realism Gain**: 60% (from "roster generator" to "has season outcomes")
**Performance Target**: <90 seconds for 20-year bootstrap (<20% overhead)

---

## Week 1-2: Game Simulation Foundation

### G1.1: Game Simulation
**Status**: ALREADY DESIGNED
**Complexity**: Medium (15 days, but design complete)
**Impact**: CRITICAL - Unblocks 40+ features

**Implementation**:
1. Create `/scripts/core/game_simulation/GameSimulator.gd`
2. Implement functions per `/docs/tasks/GAME_SIMULATION_SPECS.md`:
   - `calculate_team_strength()`
   - `calculate_win_probability()`
   - `determine_winner()`
   - `generate_college_schedule()`
   - `generate_nfl_schedule()`
   - `aggregate_season_results()`
3. Integrate into `CollegeSeason.run()`:
   - Add `_simulate_season()` method
   - Call after roster loading, before player lifecycle
   - Store results in `world_state["season_records"]`
4. Integrate into `NflSeason.run()`:
   - Add `_simulate_nfl_season()` method
   - Similar pattern to college
5. Update configs:
   - Add `game_simulation` section to `configs/sports/american_football/world/colleges.json` (v2)
   - Add `game_simulation` section to `configs/sports/american_football/world/league.json` (v3)
6. Tests:
   - `test_calculate_team_strength_various_rosters.gd`
   - `test_determine_winner_determinism.gd`
   - `test_college_season_simulation_integration.gd`
   - `test_nfl_season_simulation_integration.gd`

**Acceptance Criteria**:
- [ ] 20-year bootstrap completes with game simulation
- [ ] Home team win rate 55-65% (realistic)
- [ ] Upset frequency 15-25% (favored team by 10+ loses)
- [ ] Deterministic (same seed = same results)
- [ ] Performance <5% overhead (estimate: 3.15%)

**Files to Create**:
- `/scripts/core/game_simulation/GameSimulator.gd`

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`
- `/configs/sports/american_football/world/colleges.json`
- `/configs/sports/american_football/world/league.json`

---

### G1.2: Season W-L Records
**Complexity**: Small (2 days)
**Impact**: CRITICAL - Foundation for all historical tracking
**Depends on**: G1.1

**Implementation**:
1. Extend `world_state` schema:
   ```gdscript
   world_state["season_records"] = {
     2025: {
       "college_001": {
         "team_id": "college_001",
         "year": 2025,
         "wins": 10,
         "losses": 2,
         "conference_wins": 0,  # Phase 2
         "conference_losses": 0,
         "strength_of_schedule": 68.3,
         "point_differential": 0,  # Phase 2
         "playoff_appearance": false,
         "bowl_game": "",
         "championship_winner": false,
         "super_bowl_winner": false
       },
       "nfl_001": {...},
       # ... all teams
     },
     2026: {...}
   }
   ```
2. Update `GameSimulator.aggregate_season_results()` to return SeasonRecord format
3. Store in season phases:
   ```gdscript
   # In CollegeSeason.run()
   var season_results := _simulate_season(world_state, year, seed, config)
   var season_records: Dictionary = world_state.get("season_records", {})
   if not season_records.has(year):
     season_records[year] = {}
   for team_id in season_results.keys():
     season_records[year][team_id] = season_results[team_id]
   world_state["season_records"] = season_records
   ```
4. Tests:
   - `test_season_records_stored_all_teams.gd`
   - `test_season_records_correct_wl_counts.gd`

**Acceptance Criteria**:
- [ ] `world_state["season_records"]` exists after bootstrap
- [ ] Every team has W-L for all 20 years
- [ ] W+L = games played (12 for college, 17 for NFL)

**Files to Modify**:
- `/scripts/core/game_simulation/GameSimulator.gd` (aggregate function)
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### G1.5: Championship Tracking
**Complexity**: Small (2 days)
**Impact**: CRITICAL - Most visible historical outcome
**Depends on**: G1.2

**Implementation**:
1. Extend `world_state` schema:
   ```gdscript
   world_state["championships"] = {
     "college": {
       "national_champions": {2025: "college_042", 2026: "college_089", ...}
     },
     "nfl": {
       "super_bowl_winners": {2025: "nfl_015", 2026: "nfl_007", ...}
     }
   }
   ```
2. Determine champions:
   ```gdscript
   # In CollegeSeason.run() after season simulation
   var best_record := {"team_id": "", "wins": 0}
   for team_id in season_results.keys():
     var record: Dictionary = season_results[team_id]
     if int(record["wins"]) > int(best_record["wins"]):
       best_record = record

   var championships: Dictionary = world_state.get("championships", {})
   if not championships.has("college"):
     championships["college"] = {"national_champions": {}}
   championships["college"]["national_champions"][year] = String(best_record["team_id"])
   world_state["championships"] = championships
   ```
3. Similar logic for NFL (best record = Super Bowl winner in Phase 1, proper playoffs in Phase 2)
4. Tests:
   - `test_national_champion_determined.gd`
   - `test_super_bowl_winner_determined.gd`

**Acceptance Criteria**:
- [ ] One national champion per year (college)
- [ ] One Super Bowl winner per year (NFL)
- [ ] Winner has best or tied-best record

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

## Week 3-4: Historical Tracking

### H4.1: Franchise Win Totals
**Complexity**: Small (2 days)
**Impact**: Important - All-time records
**Depends on**: G1.2

**Implementation**:
1. Create `world_state["team_history"]`:
   ```gdscript
   world_state["team_history"] = {
     "college_001": {
       "team_id": "college_001",
       "all_time_wins": 187,
       "all_time_losses": 53,
       "first_season": 2025,
       "last_season": 2044
     },
     # ... all teams
   }
   ```
2. Update incrementally in season phases:
   ```gdscript
   # After storing season_records
   var team_history: Dictionary = world_state.get("team_history", {})
   for team_id in season_results.keys():
     if not team_history.has(team_id):
       team_history[team_id] = {
         "team_id": team_id,
         "all_time_wins": 0,
         "all_time_losses": 0,
         "first_season": year,
         "last_season": year
       }
     var record: Dictionary = season_results[team_id]
     team_history[team_id]["all_time_wins"] += int(record["wins"])
     team_history[team_id]["all_time_losses"] += int(record["losses"])
     team_history[team_id]["last_season"] = year
   world_state["team_history"] = team_history
   ```
3. Tests:
   - `test_franchise_win_totals_accurate.gd`

**Acceptance Criteria**:
- [ ] All teams have all-time W-L
- [ ] Sum of wins across all seasons matches individual season records

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### H4.2: Championship History
**Complexity**: Small (2 days)
**Impact**: Important - Dynasty tracking
**Depends on**: G1.5

**Implementation**:
1. Extend `team_history`:
   ```gdscript
   team_history[team_id] = {
     "team_id": team_id,
     "all_time_wins": 187,
     "all_time_losses": 53,
     "championship_count": 3,  # NEW
     "championship_years": [2027, 2029, 2031],  # NEW
     # ...
   }
   ```
2. Update when championship determined:
   ```gdscript
   # After setting championship winner
   var champion_id := championships["college"]["national_champions"][year]
   team_history[champion_id]["championship_count"] += 1
   var champ_years: Array = team_history[champion_id].get("championship_years", [])
   champ_years.append(year)
   team_history[champion_id]["championship_years"] = champ_years
   ```
3. Tests:
   - `test_championship_history_accurate.gd`

**Acceptance Criteria**:
- [ ] Teams with championships have correct count
- [ ] Championship years list matches annual winners

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### H4.3: Playoff Appearance Count
**Complexity**: Small (2 days)
**Impact**: Important - Postseason success metric
**Depends on**: G1.2

**Implementation**:
1. Extend `team_history`:
   ```gdscript
   team_history[team_id] = {
     # ...
     "playoff_appearances": 8,  # NEW
     "playoff_years": [2025, 2027, 2028, ...],  # NEW
   }
   ```
2. Determine playoff teams (Phase 1: simple threshold):
   ```gdscript
   # In CollegeSeason: Top 4 teams by wins
   # In NflSeason: Top 7 per conference (simple version)
   var playoff_teams := _determine_playoff_teams(season_results)
   for team_id in playoff_teams:
     team_history[team_id]["playoff_appearances"] += 1
     var playoff_years: Array = team_history[team_id].get("playoff_years", [])
     playoff_years.append(year)
     team_history[team_id]["playoff_years"] = playoff_years
   ```
3. Tests:
   - `test_playoff_appearances_tracked.gd`

**Acceptance Criteria**:
- [ ] Playoff teams identified each year
- [ ] Counts match annual selections

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### H4.4: Winning Streaks
**Complexity**: Small (2 days)
**Impact**: Important - Narrative moments
**Depends on**: G1.2

**Implementation**:
1. Extend `team_history`:
   ```gdscript
   team_history[team_id] = {
     # ...
     "longest_win_streak": 15,  # NEW
     "longest_loss_streak": 8,  # NEW
     "current_win_streak": 0,  # NEW
     "current_loss_streak": 0,  # NEW
   }
   ```
2. Track during season (not per-game, per-season approximation):
   ```gdscript
   # Simple version: Track if team had winning season (>50% wins)
   var wins := int(record["wins"])
   var losses := int(record["losses"])
   if wins > losses:
     team_history[team_id]["current_win_streak"] += 1
     team_history[team_id]["current_loss_streak"] = 0
     var longest := int(team_history[team_id].get("longest_win_streak", 0))
     if team_history[team_id]["current_win_streak"] > longest:
       team_history[team_id]["longest_win_streak"] = team_history[team_id]["current_win_streak"]
   elif losses > wins:
     # Similar for loss streaks
   ```
3. Tests:
   - `test_winning_streaks_tracked.gd`

**Acceptance Criteria**:
- [ ] Streaks calculated for all teams
- [ ] Longest streaks reasonable (not all teams undefeated)

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### H4.6: Drought Tracking
**Complexity**: Small (1 day)
**Impact**: Important - Narrative context
**Depends on**: H4.2

**Implementation**:
1. Extend `team_history`:
   ```gdscript
   team_history[team_id] = {
     # ...
     "years_since_championship": 13,  # NEW (0 if won this year)
   }
   ```
2. Calculate:
   ```gdscript
   # After championship determined
   for team_id in team_history.keys():
     var last_championship_year := 0
     var champ_years: Array = team_history[team_id].get("championship_years", [])
     if not champ_years.is_empty():
       last_championship_year = int(champ_years[champ_years.size() - 1])

     if last_championship_year == 0:
       team_history[team_id]["years_since_championship"] = -1  # Never won
     else:
       team_history[team_id]["years_since_championship"] = year - last_championship_year
   ```
3. Tests:
   - `test_drought_tracking_accurate.gd`

**Acceptance Criteria**:
- [ ] Teams with no championships show -1
- [ ] Recent champions show 0
- [ ] Droughts calculated correctly

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### D5.1: Draft History
**Complexity**: Small (3 days)
**Impact**: Important - Team-building evaluation
**Depends on**: None (independent)

**Implementation**:
1. Create `world_state["draft_history"]`:
   ```gdscript
   world_state["draft_history"] = {
     2025: [
       {
         "pick_number": 1,
         "round": 1,
         "team_id": "nfl_001",
         "player_id": "player_12345",
         "position": "QB",
         "college": "college_042"
       },
       # ... 250 picks
     ],
     2026: [...]
   }
   ```
2. Record in `NflDraft.run()`:
   ```gdscript
   # After draft completes
   var draft_history: Dictionary = world_state.get("draft_history", {})
   draft_history[year] = []
   for pick in draft_results:
     draft_history[year].append({
       "pick_number": int(pick["pick_number"]),
       "round": int(pick["round"]),
       "team_id": String(pick["team_id"]),
       "player_id": String(pick["player_id"]),
       "position": String(pick["position"]),
       "college": String(pick["college"])
     })
   world_state["draft_history"] = draft_history
   ```
3. Tests:
   - `test_draft_history_all_picks_recorded.gd`
   - `test_draft_history_correct_pick_order.gd`

**Acceptance Criteria**:
- [ ] All 250 picks per year recorded
- [ ] Pick order matches draft execution
- [ ] All 20 years have draft history

**Files to Modify**:
- `/scripts/world/NflDraft.gd`

---

### D5.5: Draft Pick Trades
**Complexity**: Small (3 days)
**Impact**: Important - Trade history
**Depends on**: D5.1

**Implementation**:
1. Extend draft history:
   ```gdscript
   draft_history[year].append({
     # ... existing fields
     "original_team_id": "nfl_005",  # NEW (if traded)
     "traded": true,  # NEW
   })
   ```
2. Track trades (if trade system exists):
   ```gdscript
   # If pick was traded (from trade system)
   if pick.has("original_team_id"):
     draft_pick["original_team_id"] = String(pick["original_team_id"])
     draft_pick["traded"] = true
   else:
     draft_pick["traded"] = false
   ```
3. Tests:
   - `test_draft_trades_recorded.gd`

**Note**: If trade system doesn't exist yet, set `traded: false` for all picks (Phase 1), implement fully when trades added (Phase 3).

**Acceptance Criteria**:
- [ ] Traded picks flagged
- [ ] Original team tracked

**Files to Modify**:
- `/scripts/world/NflDraft.gd`

---

## Week 5-6: Player Stats Infrastructure

### S2.1: Career Stat Totals
**Complexity**: Medium (12 days)
**Impact**: HIGH - Foundation for awards, evaluation
**Depends on**: G1.1

**Implementation**:
1. Create `world_state["player_career_stats"]`:
   ```gdscript
   world_state["player_career_stats"] = {
     "player_12345": {
       2025: {
         "year": 2025,
         "team_id": "nfl_001",
         "games_played": 16,
         "games_started": 14,
         "position": "QB",
         # Position-specific stats
         "pass_attempts": 520,
         "pass_completions": 340,
         "pass_yards": 4200,
         "pass_tds": 28,
         "interceptions": 10
       },
       2026: {...}
     },
     "player_67890": {...}
   }
   ```
2. Accumulate during game simulation:
   ```gdscript
   # After game simulation, before returning results
   func _accumulate_player_stats(game_results: Array, rosters: Dictionary, world_state: Dictionary) -> void:
     var player_stats: Dictionary = world_state.get("player_career_stats", {})

     for result in game_results:
       var home_id := String(result["home_team_id"])
       var away_id := String(result["away_team_id"])
       var home_roster: Dictionary = rosters.get(home_id, {})
       var away_roster: Dictionary = rosters.get(away_id, {})

       # For each player on both teams
       for player in home_roster.get("players", []):
         var p: Dictionary = player
         var player_id := String(p["id"])
         # Generate stats based on position and game outcome
         var stat_line := _generate_player_stat_line(p, result, true)  # is_home
         _update_player_career_stats(player_stats, player_id, year, stat_line)

       # Repeat for away team
   ```
3. Stat generation algorithm (Phase 1: simple):
   ```gdscript
   func _generate_player_stat_line(player: Dictionary, game_result: Dictionary, is_home: bool) -> Dictionary:
     # Simple algorithm: Base stats on player rating + team outcome
     var position := String(player.get("position", ""))
     var rating := float(player.get("overall_rating", 50.0))
     var won := (is_home and game_result["winner_id"] == game_result["home_team_id"]) or \
                (not is_home and game_result["winner_id"] == game_result["away_team_id"])

     var stats := {}
     match position:
       "QB":
         stats["pass_attempts"] = int(25 + (rating - 50) * 0.5)  # 25-50 attempts
         stats["pass_completions"] = int(stats["pass_attempts"] * (0.55 + rating / 200.0))  # 55-75% completion
         stats["pass_yards"] = stats["pass_completions"] * int(10 + rating / 10)  # 10-20 yards per completion
         stats["pass_tds"] = int((rating / 20) + (1 if won else 0))  # 1-6 TDs, bonus if won
         stats["interceptions"] = max(0, int((100 - rating) / 15))  # 0-3 INTs
       "RB":
         stats["rush_attempts"] = int(15 + (rating - 50) * 0.3)
         stats["rush_yards"] = stats["rush_attempts"] * int(3 + rating / 25)  # 3-7 YPC
         stats["rush_tds"] = int(rating / 30)  # 0-3 TDs
       # ... other positions

     return stats
   ```
4. Tests:
   - `test_player_stats_accumulated.gd`
   - `test_stat_generation_realistic.gd`

**Acceptance Criteria**:
- [ ] All active players have career stats
- [ ] Stats accumulate across multiple seasons
- [ ] Position-specific stats present (QB, RB, WR, etc.)
- [ ] Stats correlate with player rating (higher rating = better stats)

**Files to Create**:
- `/scripts/core/game_simulation/StatGenerator.gd` (stat generation logic)

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/scripts/world/NflSeason.gd`

---

### S2.4: Games Played/Started
**Complexity**: Small (3 days)
**Impact**: HIGH - Availability tracking
**Depends on**: S2.1

**Implementation**:
Already included in S2.1 stat line:
```gdscript
"games_played": 16,
"games_started": 14,
```

Logic:
- All players on roster get `games_played += 1` per game (Phase 1: everyone plays)
- Starters (top N by rating per position) get `games_started += 1`
- Phase 2+: Reduce games_played if injured

Tests:
- `test_games_played_equals_season_length.gd`
- `test_starters_have_more_starts.gd`

**Acceptance Criteria**:
- [ ] games_played ~= season length (12-17 depending on league)
- [ ] games_started <= games_played
- [ ] Starters have higher games_started

**Files to Modify**:
- Integrated with S2.1 implementation

---

### G1.8: Strength of Schedule
**Complexity**: Small (3 days)
**Impact**: Important - Quality of opponents metric
**Depends on**: G1.2

**Implementation**:
Already calculated in `GameSimulator.aggregate_season_results()`:
```gdscript
# Calculate SOS for each team
for result in game_results:
  var home_id := String(result["home_team_id"])
  var away_id := String(result["away_team_id"])

  # Add opponent strength to SOS accumulator
  if season_records.has(home_id):
    var home_record: Dictionary = season_records[home_id]
    var opp_strength := float(team_strengths.get(away_id, 50.0))
    home_record["strength_of_schedule"] = float(home_record.get("strength_of_schedule", 0.0)) + opp_strength

# Normalize SOS (divide by number of games)
for team_id in season_records.keys():
  var record: Dictionary = season_records[team_id]
  var total_games := int(record["wins"]) + int(record["losses"])
  if total_games > 0:
    record["strength_of_schedule"] = float(record.get("strength_of_schedule", 0.0)) / float(total_games)
```

Tests:
- `test_sos_calculated_all_teams.gd`
- `test_sos_correlates_with_opponent_quality.gd`

**Acceptance Criteria**:
- [ ] All teams have SOS value
- [ ] SOS in range 0-100
- [ ] Teams playing strong opponents have higher SOS

**Files to Modify**:
- `/scripts/core/game_simulation/GameSimulator.gd` (already part of aggregate function)

---

## Week 7-9: Award Systems

### A3.2: Offensive/Defensive Player of the Year
**Complexity**: Medium (6 days)
**Impact**: HIGH - Major recognition
**Depends on**: S2.1

**Implementation**:
1. Create `/scripts/core/awards/AwardCalculator.gd`:
   ```gdscript
   extends RefCounted
   class_name AwardCalculator

   static func calculate_opoy(player_stats: Dictionary, positions_cfg: Dictionary) -> String:
     var candidates := {}

     # Find top offensive players by position
     for player_id in player_stats.keys():
       var career: Dictionary = player_stats[player_id]
       var latest_year := _get_latest_year(career)
       if latest_year == 0:
         continue

       var stats: Dictionary = career[latest_year]
       var position := String(stats.get("position", ""))

       # Only offensive positions
       if position not in ["QB", "RB", "WR", "TE"]:
         continue

       # Calculate score based on stats
       var score := _calculate_offensive_score(stats, position)
       candidates[player_id] = score

     # Return player with highest score
     var best_player := ""
     var best_score := 0.0
     for player_id in candidates.keys():
       if float(candidates[player_id]) > best_score:
         best_score = float(candidates[player_id])
         best_player = String(player_id)

     return best_player

   static func _calculate_offensive_score(stats: Dictionary, position: String) -> float:
     var score := 0.0
     match position:
       "QB":
         score = float(stats.get("pass_yards", 0)) / 10.0 + \
                 float(stats.get("pass_tds", 0)) * 40.0 - \
                 float(stats.get("interceptions", 0)) * 20.0
       "RB":
         score = float(stats.get("rush_yards", 0)) / 10.0 + \
                 float(stats.get("rush_tds", 0)) * 60.0 + \
                 float(stats.get("receptions", 0)) * 5.0
       # ... other positions
     return score
   ```
2. Award in season phases:
   ```gdscript
   # In NflSeason.run(), after stats accumulated
   var awards: Dictionary = world_state.get("awards", {})
   if not awards.has(year):
     awards[year] = {}

   var player_stats: Dictionary = world_state.get("player_career_stats", {})
   var opoy := AwardCalculator.calculate_opoy(player_stats, positions_cfg)
   var dpoy := AwardCalculator.calculate_dpoy(player_stats, positions_cfg)

   awards[year]["opoy"] = opoy
   awards[year]["dpoy"] = dpoy
   world_state["awards"] = awards
   ```
3. Tests:
   - `test_opoy_award_to_top_offensive_player.gd`
   - `test_dpoy_award_to_top_defensive_player.gd`

**Acceptance Criteria**:
- [ ] One OPOY per year (offensive position only)
- [ ] One DPOY per year (defensive position only)
- [ ] Winners have elite stats for their position

**Files to Create**:
- `/scripts/core/awards/AwardCalculator.gd`

**Files to Modify**:
- `/scripts/world/NflSeason.gd`

---

### A3.3: All-Pro Teams
**Complexity**: Medium (6 days)
**Impact**: HIGH - Broader recognition (22 players vs 2)
**Depends on**: S2.1

**Implementation**:
1. Extend `AwardCalculator`:
   ```gdscript
   static func select_all_pro_teams(player_stats: Dictionary, positions_cfg: Dictionary) -> Dictionary:
     var all_pro := {
       "first_team": {},  # position -> player_id
       "second_team": {}
     }

     # For each position, find top 2 players
     var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
     for position in positions:
       var candidates := _get_position_candidates(player_stats, position)
       var ranked := _rank_by_score(candidates)

       if ranked.size() >= 1:
         all_pro["first_team"][position] = ranked[0]
       if ranked.size() >= 2:
         all_pro["second_team"][position] = ranked[1]

     return all_pro
   ```
2. Store in awards:
   ```gdscript
   awards[year]["all_pro"] = AwardCalculator.select_all_pro_teams(player_stats, positions_cfg)
   ```
3. Tests:
   - `test_all_pro_teams_selected.gd`
   - `test_first_team_better_than_second_team.gd`

**Acceptance Criteria**:
- [ ] First and second team selected each year
- [ ] All positions represented
- [ ] First team players have better stats than second team

**Files to Modify**:
- `/scripts/core/awards/AwardCalculator.gd`
- `/scripts/world/NflSeason.gd`

---

### A3.4: Pro Bowl Selections
**Complexity**: Small (4 days)
**Impact**: HIGH - Broad player recognition (88 players)
**Depends on**: S2.1

**Implementation**:
1. Extend `AwardCalculator`:
   ```gdscript
   static func select_pro_bowl(player_stats: Dictionary, positions_cfg: Dictionary) -> Dictionary:
     var pro_bowl := {
       "afc": {},  # position -> [player_ids]
       "nfc": {}
     }

     # For each conference and position, select top N players
     var roster_sizes := {
       "QB": 4, "RB": 6, "WR": 6, "TE": 3, "OL": 6,
       "DL": 6, "LB": 6, "CB": 6, "S": 4, "K": 2, "P": 2
     }

     for conference in ["afc", "nfc"]:
       for position in roster_sizes.keys():
         var count := int(roster_sizes[position])
         var candidates := _get_conference_position_candidates(player_stats, conference, position)
         var ranked := _rank_by_score(candidates)
         pro_bowl[conference][position] = ranked.slice(0, count - 1)

     return pro_bowl
   ```
2. Store in awards:
   ```gdscript
   awards[year]["pro_bowl"] = AwardCalculator.select_pro_bowl(player_stats, positions_cfg)
   ```
3. Tests:
   - `test_pro_bowl_rosters_complete.gd`
   - `test_pro_bowl_selections_by_conference.gd`

**Acceptance Criteria**:
- [ ] AFC and NFC rosters selected
- [ ] Rosters have correct position counts
- [ ] Top performers selected

**Files to Modify**:
- `/scripts/core/awards/AwardCalculator.gd`
- `/scripts/world/NflSeason.gd`

---

### A3.8: Rookie of the Year
**Complexity**: Medium (5 days)
**Impact**: Important - Rookie recognition
**Depends on**: S2.1

**Implementation**:
1. Extend `AwardCalculator`:
   ```gdscript
   static func calculate_oroy(player_stats: Dictionary, draft_history: Dictionary, year: int) -> String:
     # Get this year's draft class
     var draft_class: Array = draft_history.get(year, [])
     var rookie_ids := []
     for pick in draft_class:
       rookie_ids.append(String(pick["player_id"]))

     # Find best offensive rookie
     var candidates := {}
     for player_id in rookie_ids:
       if not player_stats.has(player_id):
         continue
       var career: Dictionary = player_stats[player_id]
       if not career.has(year):
         continue
       var stats: Dictionary = career[year]
       var position := String(stats.get("position", ""))
       if position not in ["QB", "RB", "WR", "TE"]:
         continue
       candidates[player_id] = _calculate_offensive_score(stats, position)

     # Return best
     return _get_best_candidate(candidates)
   ```
2. Store in awards:
   ```gdscript
   awards[year]["oroy"] = AwardCalculator.calculate_oroy(player_stats, draft_history, year)
   awards[year]["droy"] = AwardCalculator.calculate_droy(player_stats, draft_history, year)
   ```
3. Tests:
   - `test_oroy_is_rookie.gd`
   - `test_droy_is_rookie.gd`

**Acceptance Criteria**:
- [ ] Winners are from current year's draft class
- [ ] Winners have strong rookie season stats

**Files to Modify**:
- `/scripts/core/awards/AwardCalculator.gd`
- `/scripts/world/NflSeason.gd`

---

## Week 10-11: Player Agency

### P13.1: Early Draft Entry (Enhancement)
**Complexity**: Small (4 days)
**Impact**: HIGH - College eligibility decisions
**Depends on**: Partial (already exists, needs enhancement)

**Implementation**:
Current system in `CollegeSeason.gd` handles seniors automatically. Enhance for underclassmen:
```gdscript
# In _eligibility_status()
if new_year >= 3:  # Juniors eligible for early entry
  var rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)
  var early_threshold := float(early_decl_cfg.get("junior_threshold", 75.0))

  if rating >= early_threshold:
    var roll := early_decl_rng.randf()
    var early_chance := float(early_decl_cfg.get("junior_early_chance", 0.5))  # 50% if elite

    if roll < early_chance:
      is_draft_eligible = true
      p["draft_eligibility_reason"] = "early_entry_junior"
```

Config addition:
```json
// colleges.json
"early_declaration": {
  "senior_threshold": 60.0,
  "junior_threshold": 75.0,
  "junior_early_chance": 0.5
}
```

Tests:
- `test_elite_juniors_declare_early.gd`
- `test_non_elite_juniors_stay.gd`

**Acceptance Criteria**:
- [ ] Juniors with rating >75 have chance to declare
- [ ] Seniors with rating >60 declare
- [ ] Declaration rate realistic (50-100 early entries per year)

**Files to Modify**:
- `/scripts/world/CollegeSeason.gd`
- `/configs/sports/american_football/world/colleges.json`

---

### B8.5: Retirement Decisions (Enhancement)
**Complexity**: Small (3 days)
**Impact**: Important - Non-age retirement
**Depends on**: Partial (age-based retirement exists)

**Implementation**:
Extend `RetirementConfig` and `PlayerLifecycle`:
```gdscript
# In PlayerLifecycle.advance_one_year()
if not _should_retire_age(player, ret_config):
  # Check for injury retirement
  var injury_history := player.get("injuries", [])
  if _should_retire_injury(player, injury_history, ret_config):
    retired.append(_create_retirement_record(player, "injury"))
    continue

  # Check for performance retirement (rating declined too much)
  var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
  if _should_retire_performance(player, rating, ret_config):
    retired.append(_create_retirement_record(player, "performance_decline"))
    continue

func _should_retire_injury(player: Dictionary, injuries: Array, ret_config: RetirementConfig) -> bool:
  # If 3+ season-ending injuries, high retirement chance
  var severe_injuries := 0
  for injury in injuries:
    if float(injury.get("severity", 0.0)) > 0.8:
      severe_injuries += 1
  return severe_injuries >= 3 and rng.randf() < 0.7

func _should_retire_performance(player: Dictionary, rating: float, ret_config: RetirementConfig) -> bool:
  var age := int(player.get("age", 20))
  if age < 30:
    return false  # Too young to retire from performance

  # If rating dropped below 50 and age >32, consider retirement
  if rating < 50.0 and age > 32:
    return rng.randf() < 0.3  # 30% chance
  return false
```

Tests:
- `test_injury_retirement.gd`
- `test_performance_retirement.gd`

**Acceptance Criteria**:
- [ ] Players with 3+ severe injuries have high retirement chance
- [ ] Aging players with low rating can retire early
- [ ] Retirement reasons tracked

**Files to Modify**:
- `/scripts/world/PlayerLifecycle.gd`
- `/scripts/support/config/RetirementConfig.gd`

---

### I6.5: Injury-Prone Trait
**Complexity**: Small (2 days)
**Impact**: Important - Player risk profiling
**Depends on**: None

**Implementation**:
1. Add trait during player generation:
   ```gdscript
   # In PlayerGenerator or ClassGenerator
   if rng.randf() < 0.10:  # 10% of players injury-prone
     player["traits"].append("Injury Prone")
     player["hidden_traits"].append("InjuryFlag:Prone")
   ```
2. Use in injury checks (Phase 3):
   ```gdscript
   # In PlayerLifecycle or future injury system
   var injury_multiplier := 1.0
   if "InjuryFlag:Prone" in player.get("hidden_traits", []):
     injury_multiplier = 2.0  # 2x injury risk

   var injury_chance := base_injury_chance * injury_multiplier
   ```
3. Tests:
   - `test_injury_prone_trait_assigned.gd`
   - `test_injury_prone_frequency.gd`

**Acceptance Criteria**:
- [ ] ~10% of players have injury-prone trait
- [ ] Trait persists across years
- [ ] Ready for use in Phase 3 injury system

**Files to Modify**:
- `/scripts/generation/PlayerGenerator.gd` or `/scripts/generation/ClassGenerator.gd`

---

### S14.3: Combine Measurements (Enhancement)
**Complexity**: Small (2 days)
**Impact**: Important - Public testing data
**Depends on**: Partial (physicals exist)

**Implementation**:
Already exists in Player model:
```gdscript
# SportPlayer.gd
@export var forty_sec: float
@export var shuttle20_sec: float
@export var vertical_in: float
@export var broad_in: float
@export var bench_225_reps: int
```

Just ensure visibility in UI and storage:
```gdscript
# In WorldExplorer player detail views
if player.has("forty_sec") and float(player["forty_sec"]) > 0.0:
  detail_text += "40-Yard Dash: %.2f sec\n" % float(player["forty_sec"])
# ... other combine stats
```

Tests:
- `test_combine_stats_present.gd`
- `test_combine_stats_visible_in_ui.gd`

**Acceptance Criteria**:
- [ ] All draft-eligible players have combine stats
- [ ] Stats visible in UI (draft panel, player pages)

**Files to Modify**:
- `/scripts/ui/world_explorer/formatters/PlayerDetailFormatter.gd` (if exists)
- `/scripts/ui/world_explorer/panels/DraftPanel.gd`

---

## Phase 1 Completion Checklist

### Functional Requirements
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

### Non-Functional Requirements
- [ ] Bootstrap time <90 seconds (20 years)
- [ ] World state size <200 MB
- [ ] Home team win rate 55-65%
- [ ] Upset frequency 15-25%
- [ ] Determinism validated (same seed = same results)
- [ ] All tests passing (83+ existing + ~20 new = 103+ total)

### Documentation
- [ ] Game simulation implementation notes
- [ ] Award calculation formulas documented
- [ ] Stat generation algorithms documented
- [ ] Config changes documented

### Next Phase Prep
- [ ] Playoff system designed (G1.4)
- [ ] Position-specific stats schema designed (S2.3)
- [ ] Injury system architecture designed (I6.1, I6.2)

---

## Implementation Tips

1. **Start with G1.1 (Game Simulation)**: Already designed, just implement per specs
2. **Test incrementally**: After each feature, run full bootstrap to validate
3. **Monitor performance**: Use `capture_timing: true` to track per-phase overhead
4. **Parallelize where safe**: Game simulation within week must be sequential, but weeks can eventually parallelize
5. **Use existing patterns**: Follow RNG derivation, world_state mutation, config-driven behavior
6. **Keep it simple**: Phase 1 is MVP, don't over-engineer
7. **Document decisions**: If you deviate from specs, note why in code comments

---

## Expected Outcomes

After Phase 1 completion:
- **Realism**: 60% improvement (from "roster generator" to "has season outcomes")
- **User Value**: Can answer "Who won championships?" "What are player stats?" "Which teams are successful?"
- **Foundation**: 40+ Phase 2/3 features unblocked
- **Performance**: Still fast (<90s for 20 years, <20% overhead)
- **Confidence**: Validated approach, ready for Phase 2 strategic investments

---

**Next Document**: See `/docs/planning/FEATURE_ROADMAP.md` for Phase 2-4 detailed plans
