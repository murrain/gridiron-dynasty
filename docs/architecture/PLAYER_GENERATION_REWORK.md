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

## 2. Positional Freaks System

### 2.1 Design Philosophy

Instead of just boosting athletic stats, freaks have **unusual stat combinations** that are outside their positional norm but could be exploited by creative coaches.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Positional Freak Examples                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  POSITION    FREAK STAT              USE CASE                                    │
│  ────────    ──────────              ────────                                    │
│  TE          throw_accuracy: 90      Trick plays, Philly Special                 │
│  WR          blocking: 90            Elite run-game receiver, jet sweeps         │
│  RB          throw_accuracy: 85      Halfback pass plays                         │
│  CB          catching: 88            Ball hawk, pick-six threat                  │
│  OL          agility: 85             Pull blocks, screen plays                   │
│  LB          coverage: 88            Hybrid safety/LB, modern defense            │
│  DL          speed: 88               Edge rusher flexibility                     │
│  QB          blocking: 80            Actually helps in run game (lol)            │
│  K/P         tackling: 85            Last line of defense on returns             │
│                                                                                  │
│  These players look "normal" at their position but have hidden utility          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Freak Stat Configuration

Define which stats are "unusual" for each position:

```gdscript
## Stats that are unusual/valuable outliers for each position
## These are stats with low mu (<50) for the position but high utility if boosted
const POSITIONAL_FREAK_STATS := {
    "QB": {
        "unusual_stats": ["blocking", "tackling", "speed"],
        "description": "Mobile QB who can block on designed runs or make tackles"
    },
    "RB": {
        "unusual_stats": ["throw_accuracy", "throw_power", "route_running"],
        "description": "Versatile back who can throw or line up as receiver"
    },
    "WR": {
        "unusual_stats": ["blocking", "throw_accuracy", "tackling"],
        "description": "Physical receiver for run support or trick plays"
    },
    "TE": {
        "unusual_stats": ["throw_accuracy", "throw_power", "speed"],
        "description": "Athletic TE for trick plays or mismatch creation"
    },
    "OL": {
        "unusual_stats": ["speed", "agility", "catching"],
        "description": "Athletic lineman for screens or tackle-eligible plays"
    },
    "DL": {
        "unusual_stats": ["speed", "coverage", "catching"],
        "description": "Versatile lineman who can drop into coverage or tip passes"
    },
    "LB": {
        "unusual_stats": ["coverage", "catching", "speed"],
        "description": "Modern hybrid LB who can cover TEs and RBs"
    },
    "CB": {
        "unusual_stats": ["catching", "return_ability", "tackling"],
        "description": "Ball-hawk corner or physical run-support DB"
    },
    "S": {
        "unusual_stats": ["pass_rush", "run_stuffing", "catching"],
        "description": "Versatile safety who can blitz or play center field"
    },
    "K": {
        "unusual_stats": ["tackling", "speed"],
        "description": "Kicker who won't get trucked on returns"
    },
    "P": {
        "unusual_stats": ["tackling", "throw_accuracy", "speed"],
        "description": "Punter who can make plays on fakes or tackles"
    }
}
```

### 2.3 Freak Generation Algorithm

```gdscript
## Generate positional freak by boosting unusual stats
static func apply_freak_boost(
    player: Dictionary,
    positions_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var position: String = player["position"]
    var stats: Dictionary = player["stats"]
    var freak_config := POSITIONAL_FREAK_STATS.get(position, {})

    if freak_config.is_empty():
        return player  # No freak stats defined for this position

    var unusual_stats: Array = freak_config.get("unusual_stats", [])
    if unusual_stats.is_empty():
        return player

    # Pick 1-2 unusual stats to boost
    var num_boosts := rng.randi_range(1, 2)
    unusual_stats.shuffle()  # Randomize which stats get boosted

    var boosted_stats := []
    for i in range(min(num_boosts, unusual_stats.size())):
        var stat_to_boost: String = unusual_stats[i]

        if stats.has(stat_to_boost):
            # Boost to elite level (85-95 range)
            var boost_target := rng.randf_range(85.0, 95.0)
            var current_value := float(stats[stat_to_boost])

            # Only boost if it's actually unusual (below 60 normally)
            if current_value < 60.0:
                stats[stat_to_boost] = boost_target
                boosted_stats.append({
                    "stat": stat_to_boost,
                    "from": current_value,
                    "to": boost_target
                })

    # Tag the player as a freak with details
    if boosted_stats.size() > 0:
        var tags: Array = player.get("tags", [])
        tags.append("PositionalFreak")
        player["tags"] = tags

        player["freak_data"] = {
            "boosted_stats": boosted_stats,
            "description": freak_config.get("description", ""),
            "discovery_difficulty": "hard"  # These are hidden gems
        }

    player["stats"] = stats
    return player
```

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
        # Must be a templated player (chaos players are already unusual)
        if player.get("generation_mode") != "templated":
            continue

        # Must have solid core stats (not a bust with a gimmick)
        var position: String = player["position"]
        var core_stat_avg := _get_core_stat_average(player, position)
        if core_stat_avg < 65.0:
            continue  # Below average players don't become freaks

        # Must not already be exceptional (leave room for the unusual stat)
        if core_stat_avg > 85.0:
            continue  # Already elite, doesn't need gimmick

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
            "min_core_stat_avg": 65.0,
            "max_core_stat_avg": 85.0,
            "boost_range": [85.0, 95.0],
            "max_boosts_per_player": 2
        },

        "chaos_stat_range": {
            "min": 25.0,
            "max": 95.0
        }
    }
}
```

### 3.2 positions.json Updates

Add `unusual_stats` to each position definition:

```json
{
    "TE": {
        "core_stats": ["strength", "blocking", "catching"],
        "unusual_stats": ["throw_accuracy", "throw_power", "speed"],
        "unusual_stat_description": "Athletic TE for trick plays or mismatch creation",
        "distributions": { ... }
    }
}
```

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

### 5.1 The Trick Play TE

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Marcus Johnson - TE (Positional Freak)                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  CORE STATS (Normal TE)           FREAK STAT (Hidden)                            │
│  ─────────────────────            ───────────────────                            │
│  Strength: 72                     Throw Accuracy: 91  ← Was 32, boosted          │
│  Blocking: 68                                                                    │
│  Catching: 71                     This TE played QB in high school.              │
│                                   Can run Philly Special or trick passes.        │
│  Generation: Templated (80%)                                                     │
│  Freak Selection: Core avg 70.3   Scouting Required: Yes (hidden by default)     │
│                                                                                  │
│  COACH VALUE: High for creative offensive coordinators                           │
│               Worthless for traditional coaches who won't use it                 │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 The Blocking WR

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    DeShawn Williams - WR (Positional Freak)                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  CORE STATS (Normal WR)           FREAK STAT (Hidden)                            │
│  ─────────────────────            ───────────────────                            │
│  Speed: 82                        Blocking: 89  ← Was 35, boosted                │
│  Agility: 78                                                                     │
│  Route Running: 74                This WR was an OL in high school.              │
│  Catching: 75                     Elite run-game receiver, jet sweep blocks.     │
│                                                                                  │
│  Generation: Templated (80%)      Perfect for run-heavy offenses.                │
│  Freak Selection: Core avg 77.3   Teams like SF/BAL would love this player.      │
│                                                                                  │
│  SCOUTING NOTE: "Showed surprising physicality in run game during                │
│                  senior bowl. Worth a deeper look at blocking film."             │
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
| `scripts/generation/PlayerGenerator.gd` | New generation modes, freak system |
| `scripts/generation/StatsHelper.gd` | Separate templated vs chaos sampling |
| `configs/sports/american_football/main.json` | Add `player_generation` config block |
| `configs/sports/american_football/positions.json` | Add `unusual_stats` per position |
| `scripts/core/models/Player.gd` | Add `freak_data`, `generation_mode` fields |

---

## 8. Open Questions

1. **Chaos stat range**: Should chaos players use full 0-100 range or constrained 25-95?
2. **Freak visibility**: Should freak stats be visible at combine, or require game film?
3. **Chaos position weights**: Should chaos best-fit favor certain positions?
4. **Freak trait interaction**: Should freaks also get the new personality stats from the grades system?
5. **Historical players**: Should we retroactively assign freak traits to existing players?
