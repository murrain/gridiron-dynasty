# Scheme Fit Evaluation System

## Overview

Teams evaluate players differently based on their offensive and defensive schemes. A receiving TE is more valuable to a West Coast offense than a Power Run offense. This system creates meaningful evaluation divergence between teams without adding explicit tags to players.

## Core Principle

**Schemes define stat weights, not player types.** A player's "type" emerges naturally from their stat distribution. Two TEs with identical overall ratings but different stat profiles will be valued differently by different teams.

## Data Model

### Team Schemes

Teams have separate offensive and defensive schemes:

```gdscript
# In Team.gd or via coach assignment
var offensive_scheme: String = "west_coast"  # References scheme config
var defensive_scheme: String = "cover_2"     # References scheme config
```

### Coach Scheme Assignment

Coaches bring schemes to teams:

```gdscript
# In Coach.gd
var offensive_scheme: String = ""  # For offensive coordinators / head coaches
var defensive_scheme: String = ""  # For defensive coordinators / head coaches
var scheme_rigidity: float = 1.0   # 0.5 = flexible, 1.0 = normal, 1.2 = rigid
```

## Scheme Configuration

Located in `configs/sports/american_football/schemes.json`:

```json
{
  "offensive_schemes": {
    "west_coast": {
      "philosophy": "Short timing routes, YAC, ball control",
      "position_stat_weights": {
        "QB": {
          "throw_accuracy": 1.25,
          "decision_making": 1.20,
          "reaction_time": 1.15,
          "throw_power": 0.90,
          "speed": 0.95
        },
        "TE": {
          "catching": 1.30,
          "route_running": 1.25,
          "agility": 1.15,
          "awareness": 1.10,
          "blocking": 0.75,
          "strength": 0.85
        },
        "RB": {
          "catching": 1.25,
          "route_running": 1.20,
          "agility": 1.15,
          "blocking": 1.10,
          "strength": 0.90
        },
        "WR": {
          "route_running": 1.25,
          "catching": 1.20,
          "agility": 1.15,
          "speed": 0.95
        },
        "OL": {}
      }
    },

    "power_run": {
      "philosophy": "Physical, downhill running, heavy personnel",
      "position_stat_weights": {
        "QB": {
          "decision_making": 1.15,
          "awareness": 1.10,
          "throw_power": 1.05,
          "speed": 0.85,
          "agility": 0.85
        },
        "TE": {
          "blocking": 1.35,
          "strength": 1.30,
          "balance": 1.15,
          "catching": 0.80,
          "route_running": 0.70,
          "speed": 0.85
        },
        "RB": {
          "strength": 1.25,
          "balance": 1.20,
          "stamina": 1.15,
          "catching": 0.85,
          "speed": 0.95
        },
        "WR": {
          "blocking": 1.20,
          "strength": 1.10,
          "catching": 1.05,
          "speed": 0.95
        },
        "OL": {
          "strength": 1.20,
          "blocking": 1.15,
          "balance": 1.10,
          "agility": 0.85
        }
      }
    },

    "spread_option": {
      "philosophy": "RPO, QB run threat, space creation",
      "position_stat_weights": {
        "QB": {
          "speed": 1.30,
          "agility": 1.25,
          "decision_making": 1.20,
          "throw_accuracy": 1.10,
          "throw_power": 0.95
        },
        "TE": {
          "speed": 1.20,
          "agility": 1.15,
          "catching": 1.15,
          "route_running": 1.10,
          "blocking": 0.80
        },
        "RB": {
          "speed": 1.20,
          "agility": 1.20,
          "catching": 1.10,
          "strength": 0.90
        },
        "WR": {
          "blocking": 1.20,
          "speed": 1.10,
          "agility": 1.10
        },
        "OL": {
          "agility": 1.15,
          "speed": 1.10,
          "blocking": 1.05,
          "strength": 0.95
        }
      }
    },

    "air_raid": {
      "philosophy": "Vertical passing, 4-5 wide, stretch the field",
      "position_stat_weights": {
        "QB": {
          "throw_power": 1.30,
          "throw_accuracy": 1.20,
          "decision_making": 1.15,
          "speed": 0.85
        },
        "TE": {
          "speed": 1.25,
          "catching": 1.25,
          "route_running": 1.20,
          "blocking": 0.65,
          "strength": 0.75
        },
        "WR": {
          "speed": 1.25,
          "catching": 1.20,
          "route_running": 1.15
        },
        "RB": {
          "catching": 1.20,
          "route_running": 1.15,
          "blocking": 1.10,
          "strength": 0.90
        },
        "OL": {
          "agility": 1.10,
          "awareness": 1.10,
          "blocking": 1.05
        }
      }
    },

    "zone_run": {
      "philosophy": "Outside zone, cutback lanes, athletic OL",
      "position_stat_weights": {
        "QB": {
          "decision_making": 1.15,
          "throw_accuracy": 1.10,
          "awareness": 1.10
        },
        "TE": {
          "blocking": 1.20,
          "agility": 1.15,
          "speed": 1.10,
          "catching": 1.05,
          "strength": 0.95
        },
        "RB": {
          "agility": 1.25,
          "awareness": 1.20,
          "balance": 1.15,
          "speed": 1.10
        },
        "WR": {
          "blocking": 1.15,
          "speed": 1.05
        },
        "OL": {
          "agility": 1.25,
          "speed": 1.20,
          "balance": 1.15,
          "strength": 0.90
        }
      }
    },

    "pro_style": {
      "philosophy": "Balanced, multiple formations, adaptable",
      "position_stat_weights": {
        "QB": {
          "awareness": 1.10,
          "decision_making": 1.10,
          "throw_accuracy": 1.05,
          "throw_power": 1.05
        },
        "TE": {
          "catching": 1.10,
          "blocking": 1.10,
          "route_running": 1.05,
          "strength": 1.05
        },
        "RB": {
          "balance": 1.10,
          "agility": 1.05,
          "catching": 1.05,
          "blocking": 1.05
        },
        "WR": {
          "route_running": 1.10,
          "catching": 1.05,
          "speed": 1.05
        },
        "OL": {
          "blocking": 1.10,
          "awareness": 1.05,
          "strength": 1.05
        }
      }
    }
  },

  "defensive_schemes": {
    "4_3_under": {
      "philosophy": "DE pass rush, athletic LBs, single-gap",
      "position_stat_weights": {
        "EDGE": {
          "pass_rush": 1.30,
          "acceleration": 1.25,
          "speed": 1.20,
          "agility": 1.15,
          "run_defense": 0.85,
          "strength": 0.90
        },
        "DL": {
          "pass_rush": 1.20,
          "acceleration": 1.15,
          "shedding_blocks": 1.10,
          "run_defense": 0.95,
          "strength": 0.95
        },
        "LB": {
          "coverage": 1.25,
          "speed": 1.20,
          "agility": 1.15,
          "tackling": 1.00,
          "strength": 0.90
        },
        "CB": {},
        "S": {}
      }
    },

    "3_4_two_gap": {
      "philosophy": "Space-eating DL, versatile OLBs, two-gap",
      "position_stat_weights": {
        "EDGE": {
          "pass_rush": 1.15,
          "coverage": 1.15,
          "run_defense": 1.10,
          "strength": 1.10,
          "speed": 0.95
        },
        "DL": {
          "strength": 1.35,
          "run_defense": 1.30,
          "shedding_blocks": 1.20,
          "pass_rush": 0.80,
          "speed": 0.75
        },
        "LB": {
          "tackling": 1.20,
          "run_defense": 1.15,
          "strength": 1.15,
          "shedding_blocks": 1.10,
          "coverage": 0.90
        },
        "CB": {},
        "S": {}
      }
    },

    "cover_2": {
      "philosophy": "Zone coverage, split safeties, CBs play flats",
      "position_stat_weights": {
        "CB": {
          "tackling": 1.25,
          "awareness": 1.20,
          "coverage": 1.15,
          "press_coverage": 0.85,
          "speed": 0.95
        },
        "S": {
          "coverage": 1.25,
          "awareness": 1.20,
          "speed": 1.15,
          "tackling": 0.95
        },
        "LB": {
          "coverage": 1.30,
          "speed": 1.25,
          "awareness": 1.20,
          "strength": 0.85
        },
        "EDGE": {},
        "DL": {}
      }
    },

    "cover_3": {
      "philosophy": "Single high safety, CBs play deep thirds",
      "position_stat_weights": {
        "CB": {
          "coverage": 1.25,
          "speed": 1.20,
          "awareness": 1.15,
          "press_coverage": 0.90
        },
        "S": {
          "speed": 1.30,
          "coverage": 1.25,
          "awareness": 1.20,
          "tackling": 0.90
        },
        "LB": {
          "coverage": 1.15,
          "speed": 1.10,
          "tackling": 1.05
        },
        "EDGE": {},
        "DL": {}
      }
    },

    "press_man": {
      "philosophy": "Physical CBs, man coverage, aggressive",
      "position_stat_weights": {
        "CB": {
          "press_coverage": 1.35,
          "speed": 1.25,
          "agility": 1.20,
          "strength": 1.15,
          "coverage": 1.10,
          "awareness": 0.85
        },
        "S": {
          "speed": 1.20,
          "tackling": 1.15,
          "coverage": 1.10,
          "awareness": 0.90
        },
        "LB": {
          "coverage": 1.15,
          "speed": 1.10,
          "tackling": 1.05
        },
        "EDGE": {},
        "DL": {}
      }
    },

    "tampa_2": {
      "philosophy": "Cover 2 with MLB dropping deep middle",
      "position_stat_weights": {
        "LB": {
          "speed": 1.35,
          "coverage": 1.30,
          "awareness": 1.20,
          "agility": 1.15,
          "strength": 0.80,
          "tackling": 0.90
        },
        "CB": {
          "tackling": 1.20,
          "awareness": 1.15,
          "coverage": 1.10,
          "press_coverage": 0.80
        },
        "S": {
          "coverage": 1.20,
          "awareness": 1.20,
          "speed": 1.15
        },
        "EDGE": {},
        "DL": {}
      }
    },

    "aggressive_blitz": {
      "philosophy": "Pressure-heavy, disguised blitzes, risk/reward",
      "position_stat_weights": {
        "LB": {
          "pass_rush": 1.25,
          "acceleration": 1.20,
          "speed": 1.15,
          "coverage": 1.10,
          "tackling": 1.05
        },
        "CB": {
          "press_coverage": 1.20,
          "speed": 1.20,
          "coverage": 1.15,
          "awareness": 0.90
        },
        "S": {
          "tackling": 1.20,
          "speed": 1.15,
          "coverage": 1.10
        },
        "EDGE": {
          "pass_rush": 1.25,
          "speed": 1.20,
          "acceleration": 1.15
        },
        "DL": {
          "pass_rush": 1.20,
          "acceleration": 1.15
        }
      }
    }
  }
}
```

## Calculation Algorithm

### Step 1: Calculate Base Rating

Use existing `PlayerRatingCalculator` to get position-neutral overall rating.

```gdscript
var base_rating = PlayerRatingCalculator.calculate_overall(player, position)
```

### Step 2: Calculate Scheme-Weighted Rating

For the relevant scheme (offensive for offensive positions, defensive for defensive positions):

```gdscript
func calculate_scheme_rating(player: Player, position: String, scheme_weights: Dictionary) -> float:
    var position_weights = scheme_weights.get(position, {})
    var weighted_sum = 0.0
    var weight_total = 0.0

    for stat_name in player.stats.keys():
        var stat_value = player.stats[stat_name]
        var weight = position_weights.get(stat_name, 1.0)  # Unmapped stats = 1.0
        weighted_sum += stat_value * weight
        weight_total += weight

    return weighted_sum / weight_total if weight_total > 0 else base_rating
```

### Step 3: Calculate Scheme Fit Delta

```gdscript
var scheme_fit_delta = (scheme_rating - base_rating) / base_rating
# Typically ranges from -0.20 to +0.20 (±20%)
```

### Step 4: Apply Elite Player Protection

Elite players transcend scheme. A generational talent is valuable regardless of fit because:
- Teams can adapt their scheme around elite players
- Elite players can learn new systems
- Passing on generational talent is organizational malpractice

```gdscript
func calculate_elite_dampening(base_rating: float) -> float:
    # Elite players (90+): scheme matters 20% as much
    # Very good players (80-90): scheme matters 50% as much
    # Average players (70-80): scheme matters fully
    # Below average (<70): scheme matters fully

    if base_rating >= 90.0:
        return 0.2
    elif base_rating >= 80.0:
        # Linear interpolation: 90->0.2, 80->0.5
        return 0.5 - ((base_rating - 80.0) / 10.0) * 0.3
    elif base_rating >= 70.0:
        # Linear interpolation: 80->0.5, 70->1.0
        return 1.0 - ((base_rating - 70.0) / 10.0) * 0.5
    else:
        return 1.0
```

### Step 5: Calculate Final Adjusted Rating

```gdscript
func calculate_scheme_adjusted_rating(
    player: Player,
    position: String,
    scheme_weights: Dictionary,
    coach_rigidity: float = 1.0
) -> float:
    var base_rating = PlayerRatingCalculator.calculate_overall(player, position)
    var scheme_rating = calculate_scheme_rating(player, position, scheme_weights)
    var scheme_fit_delta = (scheme_rating - base_rating) / base_rating

    var elite_dampening = calculate_elite_dampening(base_rating)
    var effective_delta = scheme_fit_delta * elite_dampening * coach_rigidity

    return base_rating * (1.0 + effective_delta)
```

## Example Calculations

### Two TEs with 75 Overall Rating

| Stat | "Kelce" Type | "Gronk" Type |
|------|-------------|--------------|
| catching | 88 | 62 |
| route_running | 85 | 55 |
| blocking | 58 | 90 |
| strength | 62 | 88 |
| speed | 78 | 65 |
| agility | 80 | 60 |
| awareness | 72 | 70 |

#### West Coast Offense Evaluation

Weights: catching 1.30, route_running 1.25, agility 1.15, awareness 1.10, blocking 0.75, strength 0.85

**Kelce Type:**
- Scheme rating ≈ 82 (high catching/route_running boosted)
- Delta = +9.3%
- Elite dampening = 1.0 (75 overall)
- **Final: 82**

**Gronk Type:**
- Scheme rating ≈ 67 (high blocking/strength penalized)
- Delta = -10.7%
- Elite dampening = 1.0
- **Final: 67**

**Spread: 15 points** between same-overall players.

#### Power Run Offense Evaluation

Weights: blocking 1.35, strength 1.30, balance 1.15, catching 0.80, route_running 0.70, speed 0.85

**Kelce Type:**
- Scheme rating ≈ 66
- **Final: 66**

**Gronk Type:**
- Scheme rating ≈ 84
- **Final: 84**

**The rankings flip completely.**

### Elite Player Example (92 Overall TE)

Same stat distribution as "Kelce Type" but scaled to 92 overall.

**Power Run Offense Evaluation (bad scheme fit):**
- Base: 92
- Scheme rating: ~84 (poor fit)
- Raw delta: -8.7%
- Elite dampening: 0.2 (92 overall → scheme barely matters)
- Effective delta: -1.7%
- **Final: 90**

The team still sees a 90-rated player. They're not passing on this guy.

## Integration Points

### Draft Evaluation (NflDraft.gd)

```gdscript
func evaluate_prospect(player: Player, team: Team) -> float:
    var position = player.position
    var scheme = get_relevant_scheme(team, position)
    var scheme_weights = load_scheme_weights(scheme)
    var coach_rigidity = team.head_coach.scheme_rigidity

    return calculate_scheme_adjusted_rating(player, position, scheme_weights, coach_rigidity)
```

### Free Agency (FreeAgency.gd)

Same calculation - teams value free agents through their scheme lens.

### Trade Evaluation

When evaluating incoming players, apply scheme fit. This creates realistic trade value disparities.

### Scouting Reports

Scout reports can show "Scheme Fit: Good/Average/Poor" based on delta magnitude.

## Future Considerations (TODO)

### Derived Stats
Currently ignoring derived stats (catch_radius, burst, etc.). These could be incorporated:
- `catch_radius` valuable for contested catch schemes
- `burst` valuable for zone run schemes
- Consider adding these once base system is validated

### Physical Attributes
Height/weight/wingspan could factor into scheme fit:
- Spread schemes might prefer lighter, faster OL
- Power schemes might prefer heavier personnel
- Press man coverage might value longer CBs

### Scheme Learning
Players could have a `scheme_familiarity` that improves over time:
- First year in new scheme: additional penalty
- 2-3 years: neutral
- 4+ years: small bonus

### Positional Flexibility
Some players can play multiple positions with different scheme fits:
- A TE might be a poor fit as inline TE but good fit as big slot WR
- This adds draft intrigue ("we'll use him differently")

## Configuration Defaults

```json
{
  "scheme_fit": {
    "weight_range": {
      "min": 0.65,
      "max": 1.35
    },
    "elite_thresholds": {
      "elite": 90,
      "very_good": 80,
      "average": 70
    },
    "elite_dampening": {
      "elite": 0.2,
      "very_good": 0.5,
      "average": 1.0
    },
    "coach_rigidity": {
      "min": 0.5,
      "max": 1.2,
      "default": 1.0
    }
  }
}
```
