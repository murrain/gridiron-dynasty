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

## 3. Stat Inheritance System

### 3.1 Problem: Repeated Definitions

Currently, stats like `work_ethic`, `discipline`, `maturity` would need to be defined for every position. This is:
- Redundant (same mu/sigma for most positions)
- Error-prone (easy to forget a stat)
- Unrealistic (a 10 work_ethic player wouldn't survive college, let alone make the NFL)

### 3.2 Solution: Base Template + Position Overrides

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Stat Inheritance Hierarchy                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  BASE_PLAYER_TEMPLATE                                                            │
│  ───────────────────                                                             │
│  Common stats ALL players have, regardless of position.                          │
│  mu: 50 = average NFL player (not average human - average among NFL players)     │
│  Floors prevent unrealistic extremes (lazy players get cut before NFL)           │
│                                                                                  │
│    work_ethic:      mu: 50, sigma: 12, floor: 35                                 │
│    discipline:      mu: 50, sigma: 14, floor: 30                                 │
│    maturity:        mu: 50, sigma: 15  (no floor - young players can be immature)│
│    composure:       mu: 50, sigma: 14  (no floor - some crumble under pressure)  │
│    ambition:        mu: 50, sigma: 15                                            │
│    competitiveness: mu: 50, sigma: 12, floor: 35                                 │
│    confidence:      mu: 50, sigma: 16  (wide variance)                           │
│    coachability:    mu: 50, sigma: 14                                            │
│    adaptability:    mu: 50, sigma: 13                                            │
│    focus:           mu: 50, sigma: 14                                            │
│    stamina:         mu: 50, sigma: 12  (positions override)                      │
│                                                                                  │
│         ↓ INHERITED BY ↓                                                         │
│                                                                                  │
│  POSITION TEMPLATES (QB, WR, TE, etc.)                                           │
│  ─────────────────────────────────────                                           │
│  Inherit base stats, then ADD position-specific stats.                           │
│  Can OVERRIDE base stats if position selects for different averages:             │
│                                                                                  │
│    QB.composure:    mu: 58  (QBs who can't handle pressure don't make it)        │
│    OL.discipline:   mu: 55  (OL is a disciplined position)                       │
│    WR.confidence:   mu: 55  (WRs tend to be confident divas)                     │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Base Player Template

**Key principle**: `mu: 50` = average NFL player. Not average human, average among the NFL population. Floors prevent unrealistic extremes.

```json
{
    "base_player": {
        "description": "Common stats for all NFL-caliber players",
        "note": "50 = average NFL player. Floors filter out extremes that wouldn't survive to the NFL.",

        "mental_stats": {
            "work_ethic": {
                "mu": 50, "sigma": 12,
                "floor": 35,
                "description": "50 = average NFL work ethic. Floor 35 = lazy players get cut in college."
            },
            "discipline": {
                "mu": 50, "sigma": 14,
                "floor": 30,
                "description": "50 = average discipline. Floor 30 = undisciplined players don't make it."
            },
            "maturity": {
                "mu": 50, "sigma": 15,
                "description": "No floor - young players can be very immature, talent overcomes it."
            },
            "composure": {
                "mu": 50, "sigma": 14,
                "description": "No floor - some NFL players crumble under pressure."
            },
            "ambition": {
                "mu": 50, "sigma": 15,
                "description": "Drive to achieve greatness. Some are content, some want rings."
            },
            "competitiveness": {
                "mu": 50, "sigma": 12,
                "floor": 35,
                "description": "Floor 35 = non-competitive people don't pursue NFL careers."
            },
            "confidence": {
                "mu": 50, "sigma": 16,
                "description": "Wide variance - imposter syndrome to extreme cockiness."
            },
            "coachability": {
                "mu": 50, "sigma": 14,
                "description": "Some players are uncoachable but talented enough to stick."
            },
            "adaptability": {
                "mu": 50, "sigma": 13,
                "description": "Ability to adjust to new schemes, teams, situations."
            },
            "focus": {
                "mu": 50, "sigma": 14,
                "description": "Mental concentration ability."
            }
        },

        "physical_baseline": {
            "stamina": {
                "mu": 50, "sigma": 12,
                "description": "Positions override significantly (WR higher, OL higher, etc.)"
            },
            "injury_resistance": {
                "mu": 50, "sigma": 15,
                "description": "Durability varies widely, no selection pressure."
            }
        }
    }
}
```

### 3.4 Position Template Structure

Positions inherit from base and can override **only if the position genuinely selects for different averages**. Most positions use base mu: 50.

```json
{
    "QB": {
        "inherits": "base_player",

        "overrides": {
            "composure": { "mu": 58, "sigma": 12 },
            "note": "QBs who can't handle pressure get filtered out - slightly higher avg"
        },

        "core_stats": ["throw_accuracy", "decision_making", "awareness", "anticipation", "composure"],

        "position_specific": {
            "throw_accuracy": { "mu": 50, "sigma": 12, "viability_min": 45 },
            "throw_power": { "mu": 50, "sigma": 12, "viability_min": 40 },
            "decision_making": { "mu": 50, "sigma": 10 },
            "awareness": { "mu": 50, "sigma": 10, "viability_min": 35 },
            "anticipation": { "mu": 50, "sigma": 10 }
        }
    },

    "WR": {
        "inherits": "base_player",

        "overrides": {
            "confidence": { "mu": 55, "sigma": 14 },
            "note": "WRs tend to be confident - diva stereotype has some truth"
        },

        "core_stats": ["speed", "agility", "route_running", "catching"],

        "position_specific": {
            "speed": { "mu": 50, "sigma": 10, "viability_min": 45 },
            "agility": { "mu": 50, "sigma": 10, "viability_min": 40 },
            "route_running": { "mu": 50, "sigma": 12 },
            "catching": { "mu": 50, "sigma": 12, "viability_min": 35 }
        }
    },

    "OL": {
        "inherits": "base_player",

        "overrides": {
            "discipline": { "mu": 55, "sigma": 10 },
            "note": "OL is a disciplined, team-first position - slightly higher avg"
        },

        "core_stats": ["strength", "blocking", "anchor"],

        "position_specific": {
            "strength": { "mu": 50, "sigma": 10, "viability_min": 50 },
            "blocking": { "mu": 50, "sigma": 12, "viability_min": 45 },
            "anchor": { "mu": 50, "sigma": 12 }
        }
    }
}
```

### 3.5 Stat Resolution Algorithm

```gdscript
## Resolve final stat distributions for a position
static func resolve_position_stats(
    position: String,
    base_template: Dictionary,
    positions_cfg: Dictionary
) -> Dictionary:
    var pos_config := positions_cfg[position]
    var resolved := {}

    # Start with all base stats
    for category in base_template.keys():
        for stat_name in base_template[category].keys():
            resolved[stat_name] = base_template[category][stat_name].duplicate()

    # Apply position overrides
    var overrides: Dictionary = pos_config.get("overrides", {})
    for stat_name in overrides.keys():
        if resolved.has(stat_name):
            # Merge override into existing stat
            for key in overrides[stat_name].keys():
                resolved[stat_name][key] = overrides[stat_name][key]
        else:
            resolved[stat_name] = overrides[stat_name].duplicate()

    # Add position-specific stats
    var pos_specific: Dictionary = pos_config.get("position_specific", {})
    for stat_name in pos_specific.keys():
        resolved[stat_name] = pos_specific[stat_name].duplicate()

    return resolved
```

### 3.6 Why Floors Matter

With mu: 50 as average, the distribution naturally produces players from ~20 to ~80. Floors cut off the unrealistic bottom end for stats where the NFL selection process filters out extremes:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Stat Floors (NFL Selection Filter)                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  STAT              MU    FLOOR    EFFECT                                         │
│  ────              ──    ─────    ──────                                         │
│  work_ethic        50    35       Range: 35-80ish. No truly lazy NFL players.    │
│  discipline        50    30       Range: 30-80ish. Undisciplined get cut early.  │
│  competitiveness   50    35       Range: 35-80ish. Non-competitive don't try.    │
│                                                                                  │
│  NO FLOOR (can be very low):                                                     │
│  ───────────────────────────                                                     │
│  maturity          50    --       Range: 15-85. Young players can be very dumb.  │
│  composure         50    --       Range: 15-85. Some crumble under pressure.     │
│  coachability      50    --       Range: 15-85. Talent overcomes being stubborn. │
│  confidence        50    --       Range: 15-85. Imposter syndrome to delusional. │
│  ambition          50    --       Range: 15-85. Some just want a paycheck.       │
│                                                                                  │
│  50 = average NFL player. Below 50 = below average. Above 50 = above average.    │
│  Simple, intuitive, consistent.                                                  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.7 Chaos Generation with Inheritance

For chaos players, base stats still use the base template (not random 0-100):

```gdscript
## Chaos generation respects base template for mental stats
static func generate_chaos_player(
    all_physical_stats: Array,
    base_template: Dictionary,
    positions_cfg: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var stats := {}

    # Mental stats: Use base template distributions (NOT random)
    # These represent "NFL-caliber human being" regardless of position
    for stat_name in base_template["mental_stats"].keys():
        var dist := base_template["mental_stats"][stat_name]
        var floor_val := float(dist.get("floor", 0.0))
        stats[stat_name] = max(
            floor_val,
            _sample_gauss(float(dist["mu"]), float(dist["sigma"]), 0.0, 100.0, rng)
        )

    # Physical/skill stats: Random uniform (the chaos part)
    for stat_name in all_physical_stats:
        if not stats.has(stat_name):
            stats[stat_name] = rng.randf_range(25.0, 95.0)

    # Find best-fit position
    var best_position := _find_best_fit_position(stats, positions_cfg)

    return {
        "position": best_position,
        "stats": stats,
        "generation_mode": "chaos"
    }
```

---

## 4. Configuration

### 4.1 main.json Updates

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

### 4.2 positions.json Updates

Rework to use inheritance system. See Section 3 for new structure.

---

## 5. Integration Points

### 5.1 PlayerGenerator.gd Changes

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

### 5.2 Scouting Integration

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

## 6. Example Scenarios

### 6.1 The Kicking TE

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

### 6.2 The Coverage DL

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

### 6.3 The Chaos Player

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

### 6.4 The Chaos Freak (Double Weird)

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

## 7. Implementation Phases

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

## 8. Files to Modify

| File | Changes |
|------|---------|
| `scripts/generation/PlayerGenerator.gd` | New generation modes, random freak system, stat inheritance |
| `scripts/generation/StatsHelper.gd` | Separate templated vs chaos sampling, resolve inheritance |
| `configs/sports/american_football/main.json` | Add `player_generation` config block |
| `configs/sports/american_football/base_player.json` | **NEW** - Base template for common stats |
| `configs/sports/american_football/positions.json` | Rework to use `inherits` + `overrides` structure |
| `scripts/core/models/Player.gd` | Add `freak_data`, `generation_mode` fields |

---

## 9. Open Questions

1. **Chaos stat range**: Should chaos players use full 0-100 range or constrained 25-95?
2. **Freak visibility**: Should freak stats be visible at combine, or require deep scouting/game film?
3. **Chaos position weights**: Should chaos best-fit favor certain positions?
4. **Freak + Chaos combo**: Can chaos-generated players also become freaks? (Currently: yes)
5. **Historical players**: Should we retroactively assign freak traits to existing players?
6. **Freak stat pool**: Should ALL stats be eligible for freak boost, or exclude some (like kick stats for non-special teams)?
