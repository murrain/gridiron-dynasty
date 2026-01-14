# Player Generation System Rework

## Overview

This document outlines the architectural changes to the player generation system, moving from a per-stat mixture distribution to a per-player generation mode split, and introducing "positional freaks" with unusual stat combinations.

---

## Current System (Problems)

The current system uses `gaussian_share: 0.75` to determine, **per stat**, whether to use:
- Gaussian distribution (75%) - position-specific parameters
- Uniform distribution (25%) - random "chaos" value

**Issues:**
1. **No true chaos players** - Every player gets a mix of templated and random stats, rather than some players being fully position-molded and others being true statistical outliers
2. **Freak system is boring** - Current freaks just get +3-7 to athletic stats, creating slightly faster versions of normal players
3. **No hidden gems** - No mechanism for players with unusual skill combinations that creative coaches could exploit

---

## Proposed System

### Generation Mode Split (80/20)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Player Generation Modes                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  TEMPLATED (80%)                         CHAOS (20%)                             │
│  ───────────────                         ──────────                              │
│  • Position assigned first               • Stats generated first                 │
│  • All stats use position-specific       • Position best-fit afterward           │
│  • Gaussian distributions                • Uniform distributions                  │
│  • Produces "typical" players            • Produces statistical outliers         │
│  • Reliable for roster building          • Diamonds in the rough                 │
│                                                                                  │
│  Example: QB with high throw_accuracy,   Example: Player with 85 speed,          │
│  decision_making, awareness              78 blocking, 72 catching → TE?          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Templated Generation (80%)

Players are generated with a specific position in mind. All stats use the position's configured distributions.

```gdscript
## Templated player generation
## Position is chosen first, then stats are generated to fit
static func generate_templated_player(
    position: String,
    positions_cfg: Dictionary,
    main_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var pos_config := positions_cfg[position]
    var stats := {}

    # Generate ALL stats using position-specific Gaussian distributions
    for stat_name in pos_config["distributions"].keys():
        var dist := pos_config["distributions"][stat_name]
        stats[stat_name] = _sample_gauss(
            float(dist["mu"]),
            float(dist["sigma"]),
            0.0,
            100.0,
            rng
        )

    return {
        "position": position,
        "stats": stats,
        "generation_mode": "templated"
    }
```

### 1.2 Chaos Generation (20%)

Stats are generated first using uniform distributions, then the player is assigned to their best-fit position.

```gdscript
## Chaos player generation
## Stats are generated randomly, then best position is determined
static func generate_chaos_player(
    all_stats: Array,
    positions_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var stats := {}

    # Generate ALL stats using uniform distribution across full range
    for stat_name in all_stats:
        # Use wider range for more variance
        stats[stat_name] = rng.randf_range(25.0, 95.0)

    # Find best-fit position based on generated stats
    var best_position := _find_best_fit_position(stats, positions_cfg)

    return {
        "position": best_position,
        "stats": stats,
        "generation_mode": "chaos"
    }

## Determine best position fit based on core stat alignment
static func _find_best_fit_position(
    stats: Dictionary,
    positions_cfg: Dictionary
) -> String:
    var best_position := ""
    var best_score := -INF

    for position in positions_cfg.keys():
        var pos_config := positions_cfg[position]
        var score := 0.0

        # Score based on how well stats match position's core stats
        for core_stat in pos_config.get("core_stats", []):
            if stats.has(core_stat):
                var stat_value := float(stats[core_stat])
                var expected_mu := float(pos_config["distributions"][core_stat]["mu"])
                # Higher score if stat is above position's expected mean
                score += (stat_value - expected_mu) / 10.0

        # Penalty for missing viability minimums
        for stat_name in pos_config["distributions"].keys():
            var dist := pos_config["distributions"][stat_name]
            if dist.has("viability_min"):
                var viability_min := float(dist["viability_min"])
                if float(stats.get(stat_name, 0)) < viability_min:
                    score -= 20.0  # Heavy penalty

        if score > best_score:
            best_score = score
            best_position = position

    return best_position
```

---

## 2. Random Freaks System

### 2.1 Design Philosophy

Freaks get a **completely random stat** boosted to ~90, regardless of whether it makes any positional sense. This creates truly weird, unpredictable players that clever coaches might find uses for.

**No position-specific rules** - the freak stat is pure chaos.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Random Freak Examples (Actual Possibilities)                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  PLAYER           FREAK STAT              WHAT COULD YOU DO WITH THIS?           │
│  ──────           ──────────              ────────────────────────────           │
│  TE               kick_power: 92          Emergency kicker? Onside kicks?        │
│  WR               pass_rush: 88           Blitz package from slot?               │
│  QB               run_stuffing: 91        Goal line QB sneak defense? lol        │
│  K                catching: 90            Fake field goal receiver               │
│  CB               throw_accuracy: 89      Trick play corner pass                 │
│  OL               coverage: 87            Tackle-eligible coverage LB?           │
│  RB               kick_accuracy: 93       Drop kick specialist                   │
│  DL               route_running: 86       Fat guy touchdown package              │
│  P                blocking: 91            Punt protection becomes punt offense   │
│  LB               throw_power: 88         Wildcat linebacker                     │
│                                                                                  │
│  These are WEIRD. Most coaches will ignore them. Creative coaches find gold.    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Freak Generation Algorithm

```gdscript
## Generate freak by boosting a RANDOM low stat to elite level
## No position-specific logic - pure chaos
static func apply_freak_boost(
    player: Dictionary,
    all_stats: Array,
    rng: RandomNumberGenerator
) -> Dictionary:
    var stats: Dictionary = player["stats"]

    # Find all stats that are currently LOW for this player (below 50)
    # These are candidates for the freak boost
    var low_stats := []
    for stat_name in all_stats:
        if stats.has(stat_name):
            var value := float(stats[stat_name])
            if value < 50.0:
                low_stats.append(stat_name)

    if low_stats.is_empty():
        return player  # No low stats to boost (rare)

    # Randomly pick 1 low stat to boost to elite level
    var stat_to_boost: String = low_stats[rng.randi() % low_stats.size()]
    var current_value := float(stats[stat_to_boost])

    # Boost to elite level (88-95 range)
    var boost_target := rng.randf_range(88.0, 95.0)
    stats[stat_to_boost] = boost_target

    # Tag the player as a freak
    var tags: Array = player.get("tags", [])
    tags.append("Freak")
    player["tags"] = tags

    player["freak_data"] = {
        "boosted_stat": stat_to_boost,
        "from": current_value,
        "to": boost_target,
        "discovery_difficulty": "hard"
    }

    player["stats"] = stats
    return player
```

### 2.3 Why Pure Randomness?

Position-specific "unusual stats" are predictable:
- Scout sees TE → checks throw_accuracy for trick play potential
- Scout sees WR → checks blocking for run support

**Pure randomness creates genuine surprises:**
- Scout sees TE → has to check ALL stats to find the hidden gem
- Maybe this TE has 92 kick_power and your kicker just got hurt
- Maybe this CB has 89 throw_accuracy and you're playing for a trick play

The value is in the **discovery** - coaches who invest in deep scouting find weird tools. Coaches who don't will never know what they're missing.

### 2.4 Freak Selection Criteria

Not every player can become a freak. Selection criteria:

```gdscript
## Select candidates for freak boosts
static func select_freak_candidates(
    players: Array,
    max_freaks: int,
    rng: RandomNumberGenerator
) -> Array:
    var candidates := []

    for player in players:
        # Can be either templated OR chaos player
        # Chaos players with a freak stat are extra weird

        # Must have solid core stats (not a bust with a gimmick)
        var position: String = player["position"]
        var core_stat_avg := _get_core_stat_average(player, position)
        if core_stat_avg < 60.0:
            continue  # Below average players don't become freaks

        # Must have at least one low stat to boost
        var has_low_stat := false
        for stat_name in player["stats"].keys():
            if float(player["stats"][stat_name]) < 50.0:
                has_low_stat = true
                break
        if not has_low_stat:
            continue

        candidates.append(player)

    # Randomly select from candidates
    candidates.shuffle()
    return candidates.slice(0, min(max_freaks, candidates.size()))
```

---

## 3. Configuration

### 3.1 main.json Updates

```json
{
    "player_generation": {
        "templated_share": 0.80,
        "chaos_share": 0.20,

        "freaks": {
            "max_per_class": 5,
            "min_core_stat_avg": 60.0,
            "boost_range": [88.0, 95.0],
            "low_stat_threshold": 50.0,
            "note": "Freak stat is chosen randomly from any stat below threshold"
        },

        "chaos_stat_range": {
            "min": 25.0,
            "max": 95.0
        }
    }
}
```

### 3.2 positions.json Updates

No changes needed for freak system - freaks are position-agnostic. The existing `core_stats` and `distributions` are sufficient.

---

## 4. Integration Points

### 4.1 PlayerGenerator.gd Changes

```gdscript
## Main generation entry point
func generate_player_class(
    class_size: int,
    positions_cfg: Dictionary,
    main_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Array:
    var players := []
    var gen_cfg := main_cfg.get("player_generation", {})

    var templated_share := float(gen_cfg.get("templated_share", 0.80))
    var templated_count := int(class_size * templated_share)
    var chaos_count := class_size - templated_count

    # Generate templated players (80%)
    for i in range(templated_count):
        var position := _select_position_for_templated(positions_cfg, rng)
        var player := generate_templated_player(position, positions_cfg, main_cfg, rng)
        players.append(player)

    # Generate chaos players (20%)
    var all_stats := _get_all_stat_names(positions_cfg)
    for i in range(chaos_count):
        var player := generate_chaos_player(all_stats, positions_cfg, rng)
        players.append(player)

    # Apply freak boosts to selected candidates
    var freak_cfg := gen_cfg.get("freaks", {})
    var max_freaks := int(freak_cfg.get("max_per_class", 5))
    var freak_candidates := select_freak_candidates(players, max_freaks, rng)

    for candidate in freak_candidates:
        apply_freak_boost(candidate, positions_cfg, rng)

    return players
```

### 4.2 Scouting Integration

Freak stats should be **hidden by default** and require scouting to discover:

```gdscript
## Freak stat visibility
const FREAK_STAT_SCOUTING := {
    "default_visibility": "hidden",
    "discovery_methods": [
        "deep_scout",           # Dedicated scouting effort
        "game_film_review",     # Noticed during film study
        "workout_observation",  # Seen during combine/pro day
        "coach_tip"             # Other coaches mention it
    ],
    "discovery_difficulty": "hard",
    "scout_time_required": 3   # Weeks of dedicated scouting
}
```

---

## 5. Example Scenarios

### 5.1 The Kicking TE

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Marcus Johnson - TE (Random Freak)                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  CORE STATS (Normal TE)           FREAK STAT (Hidden)                            │
│  ─────────────────────            ───────────────────                            │
│  Strength: 72                     Kick Power: 92  ← Was 28, randomly boosted     │
│  Blocking: 68                                                                    │
│  Catching: 71                     Nobody knows why this TE can kick 60-yarders.  │
│                                   Maybe he played soccer? Who cares.             │
│  Generation: Templated (80%)                                                     │
│  Freak Selection: Random stat     USAGE: Emergency kicker, surprise onside kicks │
│                                                                                  │
│  COACH VALUE: Your kicker gets hurt in the playoffs? This guy saves you.         │
│               99% of the time this stat is worthless. 1% it wins a game.         │
│                                                                                  │
│  SCOUTING: Most scouts will NEVER check a TE's kick_power.                       │
│            Only obsessive deep-divers find this.                                 │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 The Coverage DL

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    DeShawn Williams - DL (Random Freak)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  CORE STATS (Normal DL)           FREAK STAT (Hidden)                            │
│  ─────────────────────            ───────────────────                            │
│  Strength: 85                     Coverage: 89  ← Was 31, randomly boosted       │
│  Pass Rush: 74                                                                   │
│  Run Stuffing: 78                 A 290lb DL who can cover tight ends???         │
│  Speed: 62                        Sounds insane. Might be a secret weapon.       │
│                                                                                  │
│  Generation: Templated (80%)      Drop him into zone on obvious passing downs.   │
│  Freak Selection: Random stat     Confuse the hell out of opposing QBs.          │
│                                                                                  │
│  SCOUT TAKE: "I was reviewing film and saw him drop into coverage once.          │
│               Thought it was a mistake. Checked his workout... he can move.      │
│               This is either genius or insanity."                                │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 The Chaos Player

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Tyler Chen - TE (Chaos Generated)                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  GENERATED STATS (Random)         BEST-FIT ANALYSIS                              │
│  ───────────────────────          ──────────────────                             │
│  Speed: 67                        Best fit: TE                                   │
│  Strength: 81                       - High strength (81) matches TE core         │
│  Blocking: 74                       - Good blocking (74)                         │
│  Catching: 69                       - Decent catching (69)                       │
│  Agility: 58                        - Speed too low for WR (67)                  │
│  Throw Accuracy: 45                 - Not enough arm for QB                      │
│  Route Running: 52                                                               │
│                                                                                  │
│  Generation: Chaos (20%)          This player doesn't fit any mold perfectly.    │
│  Position Assignment: TE          He's a "tweener" - not elite at anything       │
│                                   but useful in multiple roles.                  │
│                                                                                  │
│  SCOUT TAKE: "Developmental prospect. Unusual athlete who could carve            │
│               out a role in the right system. High-floor, low-ceiling."          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 The Chaos Freak (Double Weird)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Jerome Patterson - S (Chaos + Freak)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  CHAOS GENERATED STATS            FREAK BOOST APPLIED                            │
│  ────────────────────             ───────────────────                            │
│  Speed: 78                        Throw Power: 91  ← Was 34, randomly boosted    │
│  Tackling: 71                                                                    │
│  Coverage: 68                     A safety who can throw the ball 60 yards???    │
│  Awareness: 74                    This is a chaos player who ALSO got freaked.   │
│  Catching: 65                                                                    │
│  Strength: 55                     Double weird. Wildcat safety package?          │
│  Throw Power: 91 (FREAK!)         Fake punt return throw? Who knows.             │
│                                                                                  │
│  Generation: Chaos (20%)          This player is a statistical anomaly.          │
│  Also: Freak boosted              Best fit said Safety, but he's got an arm.     │
│                                                                                  │
│  COACH TAKE: "I have no idea what to do with this guy, but I'm not cutting       │
│               him until I figure it out."                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Implementation Phases

### Phase 1: Core Generation Split
1. Add `templated_share` / `chaos_share` config to main.json
2. Implement `generate_templated_player()` - pure Gaussian generation
3. Implement `generate_chaos_player()` - uniform generation + best-fit
4. Update `PlayerGenerator.generate_player_class()` to use split

### Phase 2: Freak System Rework
1. Add `unusual_stats` to positions.json for each position
2. Implement `select_freak_candidates()` with core stat filters
3. Implement `apply_freak_boost()` to boost unusual stats to 85-95
4. Add `freak_data` to player schema with discovery info

### Phase 3: Scouting Integration
1. Make freak stats hidden by default
2. Add scouting mechanics to discover freak stats
3. Update UI to show freak stats when discovered

### Phase 4: Testing & Tuning
1. Verify 80/20 split produces expected distribution
2. Tune freak selection criteria (min/max core stat averages)
3. Balance unusual stat boost ranges
4. Ensure chaos players are viable but not OP

---

## 7. Files to Modify

| File | Changes |
|------|---------|
| `scripts/generation/PlayerGenerator.gd` | New generation modes, random freak system |
| `scripts/generation/StatsHelper.gd` | Separate templated vs chaos sampling |
| `configs/sports/american_football/main.json` | Add `player_generation` config block |
| `scripts/core/models/Player.gd` | Add `freak_data`, `generation_mode` fields |

---

## 8. Open Questions

1. **Chaos stat range**: Should chaos players use full 0-100 range or constrained 25-95?
2. **Freak visibility**: Should freak stats be visible at combine, or require deep scouting/game film?
3. **Chaos position weights**: Should chaos best-fit favor certain positions?
4. **Freak + Chaos combo**: Can chaos-generated players also become freaks? (Currently: yes)
5. **Historical players**: Should we retroactively assign freak traits to existing players?
6. **Freak stat pool**: Should ALL stats be eligible for freak boost, or exclude some (like kick stats for non-special teams)?
