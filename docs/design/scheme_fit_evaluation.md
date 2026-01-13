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

---

# Stat Visibility & Scouting System

## Overview

Stats have different visibility levels that affect how they contribute to player ratings and how scouts can evaluate them. This creates information asymmetry between teams with different scouting investments.

## Visibility Tiers

| Tier | Description | Rating Impact | Scouting |
|------|-------------|---------------|----------|
| **Public** | Combine/pro day measurable, obvious on tape | Always included in displayed rating | Always known |
| **Scoutable** | Requires film study, interviews, deeper evaluation | Included in rating once scouted | Revealed through scouting investment |
| **Hidden** | Only revealed through actual gameplay over time | **Never** in displayed rating | Never directly revealed |

### Key Principle

**Hidden stats affect simulation performance but NOT displayed ratings.** This means:
- A player's rating reflects what scouts can reasonably evaluate
- Hidden traits like `clutch_factor` create "paper tigers" or "clutch performers" that emerge through gameplay
- Teams learn hidden traits through experience, not scouting

## Scouting Difficulty

Scoutable stats have varying difficulty levels affecting evaluation accuracy:

| Difficulty | Base Accuracy | Scout Investment | Examples |
|------------|--------------|------------------|----------|
| **Easy** | 85% | Minimal film | Aggression, footwork, tackling form |
| **Medium** | 70% | Standard evaluation | Coverage technique, awareness, blocking |
| **Hard** | 50% | Deep dive required | Composure, leadership, work ethic |
| **Very Hard** | 35% | Extensive, still uncertain | Football IQ, anticipation |

### Scouting Accuracy Formula

```gdscript
func scout_stat(true_value: float, difficulty: String, scout_skill: float) -> float:
    var base_accuracy = {
        "easy": 0.85,
        "medium": 0.70,
        "hard": 0.50,
        "very_hard": 0.35
    }[difficulty]

    var effective_accuracy = base_accuracy * scout_skill  # scout_skill typically 0.6-1.2
    var noise_sigma = (1.0 - effective_accuracy) * 15.0
    var noise = randfn(0, noise_sigma)

    return clamp(true_value + noise, 0, 100)
```

## Complete Stat Classification

### Physical/Athletic Stats

| Stat | Visibility | Scout Difficulty | Rationale |
|------|-----------|------------------|-----------|
| `speed` | Public | - | 40-yard dash |
| `acceleration` | Public | - | 10-yard split |
| `agility` | Public | - | Shuttle, 3-cone |
| `balance` | Scoutable | Medium | Film - contact absorption |
| `strength` | Public | - | Bench press |
| `core_strength` | Scoutable | Hard | Shows in pad level, leverage |
| `stamina` | Scoutable | Hard | 4th quarter tape, full game film |

### Technical Skills - Passing/Receiving

| Stat | Visibility | Scout Difficulty | Rationale |
|------|-----------|------------------|-----------|
| `throw_power` | Public | - | Radar gun, velocity |
| `throw_accuracy` | Public | - | Combine drills, completion % |
| `catching` | Public | - | Drop rate, catch radius tests |
| `route_running` | Scoutable | Medium | Film - technique, breaks |
| `blocking` | Scoutable | Medium | Film - sustain, technique |
| `footwork` | Scoutable | Easy | Clearly visible on film |

### Technical Skills - Defense

| Stat | Visibility | Scout Difficulty | Rationale |
|------|-----------|------------------|-----------|
| `tackling` | Scoutable | Easy | Film - wrap up, missed tackles |
| `coverage` | Scoutable | Medium | Film - positioning, technique |
| `press_coverage` | Scoutable | Medium | Film - jam, recovery |
| `run_defense` | Scoutable | Medium | Film - gap discipline |
| `pass_rush` | Scoutable | Medium | Film - moves, bend |
| `shedding_blocks` | Scoutable | Medium | Film - hand usage |
| `hand_fighting` | Scoutable | Medium | Film - technique at LOS |

### Special Teams

| Stat | Visibility | Scout Difficulty | Rationale |
|------|-----------|------------------|-----------|
| `kick_power` | Public | - | Distance measurable |
| `kick_accuracy` | Public | - | Make %, direction |

### Mental - Processing

| Stat | Visibility | Scout Difficulty | Rationale |
|------|-----------|------------------|-----------|
| `awareness` | Scoutable | Medium | Film - positioning, pre-snap |
| `reaction_time` | Public | - | Release timing, tests exist |
| `decision_making` | Scoutable | Medium | Film - reads, turnover-worthy |
| `anticipation` | Scoutable | Very Hard | Timing throws, expert eye needed |
| `football_IQ` | Scoutable | Very Hard | Wonderlic limited, needs deep film |
| `focus` | Scoutable | Medium | Film - consistency |

### Mental - Character

| Stat | Visibility | Scout Difficulty | Rationale |
|------|-----------|------------------|-----------|
| `composure` | Scoutable | Hard | Pressure tape, big games |
| `confidence` | Scoutable | Medium | Interviews, body language |
| `aggression` | Scoutable | Easy | Obvious playing style |
| `discipline` | Scoutable | Hard | Penalties, interviews |
| `leadership` | Scoutable | Hard | Coach/teammate interviews |
| `work_ethic` | Scoutable | Hard | Facility visits, references |
| `coachability` | Scoutable | Hard | College coach interviews |
| `charisma` | Scoutable | Easy | Interviews, media presence |

### Hidden Stats (Simulation Only - Never in Rating)

| Stat | Why Hidden | How It Manifests |
|------|-----------|------------------|
| `clutch_factor` | No predictive test exists | Big moment performance |
| `morale` | Internal, fluctuates | Effort, consistency |
| `loyalty` | True feelings hidden | Contract negotiations |
| `fatigue` | Game state variable | In-game stamina |
| `recovery_rate` | Internal physical trait | Week-to-week availability |
| `durability` | Part medical, part luck | Injury frequency |
| `pain_tolerance` | Cannot ethically test | Playing through injury |
| `flexibility` | Rarely evaluated | Injury prevention |
| `medical_history_score` | Separate medical eval | Injury risk |
| `hype` | Meta-stat affecting perception | Scout bias, contract demands |

### Hype: A Special Hidden Stat

`hype` is unique among hidden stats because it affects **evaluation**, not performance. It represents the buzz, media attention, and perceived "heat" around a player that can cause scouts to buy into narratives.

**What Hype Affects:**
- Scout evaluation bias (positive noise toward high-hype players)
- Contract negotiation demands (high-hype players expect more money)
- Draft position expectations (GMs feel pressure to take hyped players)
- Media/fan pressure after picks

**What Hype Does NOT Affect:**
- Actual on-field performance (a hyped player with 70 speed still has 70 speed)
- True player rating
- Hidden performance stats like clutch_factor

**Hype Sources (can fluctuate):**
- Combine performance (great 40 time creates hype)
- Media market (USC QB vs Idaho QB)
- Highlight-reel plays vs consistent grinder
- Draft analyst rankings
- Social media presence
- Previous draft position (1st rounders carry hype baggage)

#### Hype Mechanics

```gdscript
func apply_hype_bias(base_evaluation: float, player_hype: float, scout_hype_susceptibility: float) -> float:
    # hype ranges 0-100, 50 = neutral
    # scout_hype_susceptibility ranges 0.0-1.0 (how much they buy into narratives)

    var hype_modifier = (player_hype - 50.0) / 100.0  # -0.5 to +0.5
    var bias = hype_modifier * scout_hype_susceptibility * 8.0  # Max ±4 points

    return base_evaluation + bias
```

**Example:**
- Player true rating: 72
- Player hype: 85 (lots of buzz)
- Scout A (hype_susceptibility: 0.8): Evaluates at 72 + 2.8 = **74.8**
- Scout B (hype_susceptibility: 0.2): Evaluates at 72 + 0.7 = **72.7**
- Scout C (veteran, hype_susceptibility: 0.0): Evaluates at **72.0** (sees through it)

#### Hype Decay

Hype naturally decays over time if not reinforced:

```gdscript
func decay_hype(current_hype: float, years_in_league: int) -> float:
    # Rookies maintain hype, veterans' hype fades toward neutral
    var decay_rate = 0.15 * years_in_league
    var neutral = 50.0
    return lerp(current_hype, neutral, min(decay_rate, 0.8))
```

A hyped rookie (85 hype) after 3 years with average performance: 85 → 70 → 60 → 54

#### Hype vs Performance Divergence

The most interesting scenarios occur when hype diverges from reality:

| Scenario | Hype | True Rating | Result |
|----------|------|-------------|--------|
| **Bust** | 90 | 65 | Overdrafted, overpaid, fan disappointment |
| **Hidden Gem** | 35 | 80 | Falls in draft, team gets value pick |
| **Justified Star** | 85 | 88 | Hype matches reality, everyone happy |
| **Known Quantity** | 50 | 72 | Fairly evaluated, market-rate contract |

This creates realistic draft narratives:
- The "can't miss prospect" who misses
- The "overlooked" player who becomes a star
- The late-round pick who outperforms their draft slot
- The team that trades the farm for a hyped prospect who busts

#### Real-World Parallel: The "Trade Up" Trap

High hype creates pressure that leads to bad decisions:

```
Scenario: "Trey Lance" situation
- Player hype: 92 (elite tools, upside narrative, limited tape)
- True rating: 68 (raw, unproven, small sample)
- Scoutable stats accuracy: Very low (few college starts to evaluate)

Team A (hype_susceptibility: 0.85):
  - Perceives player as ~78 overall
  - Trades 3 first-round picks to move up
  - Reality: Player was a 68 all along

Team B (hype_susceptibility: 0.20):
  - Perceives player as ~70 overall
  - Passes, takes "boring" prospect at original pick
  - Reality: Made the right call
```

The system naturally creates these situations because:
1. Limited college tape → higher scouting noise on mental stats
2. Elite measurables → public stats look great (speed, arm strength)
3. High hype → susceptible scouts add positive bias
4. Result: Massive gap between perceived and true value

#### Scout Hype Susceptibility

Different scouts have different susceptibility to hype:

```json
{
  "scout_archetypes": {
    "old_school_tape_grinder": {
      "hype_susceptibility": 0.15,
      "description": "Trusts film over buzz"
    },
    "analytics_focused": {
      "hype_susceptibility": 0.25,
      "description": "Numbers over narratives"
    },
    "consensus_builder": {
      "hype_susceptibility": 0.70,
      "description": "Influenced by industry groupthink"
    },
    "media_connected": {
      "hype_susceptibility": 0.85,
      "description": "Buys into draft Twitter narratives"
    }
  }
}
```

Teams with "tape grinder" scouts are less likely to reach on hyped players. Teams with "media connected" scouts might overdraft based on buzz.

#### Hype Generation & Assignment

Hype is generated at key moments in a prospect's journey and modified by events.

##### Initial Hype Assignment (High School → College)

When a player enters college recruiting, base hype is calculated:

```gdscript
func generate_initial_hype(player: Dictionary, school: Dictionary) -> float:
    var base_hype = 50.0  # Neutral starting point

    # Factor 1: Recruiting ranking creates initial buzz
    var recruiting_rank_bonus = 0.0
    if player.get("star_rating", 0) == 5:
        recruiting_rank_bonus = randf_range(25, 35)  # 5-stars get major hype
    elif player.get("star_rating", 0) == 4:
        recruiting_rank_bonus = randf_range(10, 20)
    elif player.get("star_rating", 0) == 3:
        recruiting_rank_bonus = randf_range(-5, 8)
    else:
        recruiting_rank_bonus = randf_range(-15, 0)  # Low-rated = low hype

    # Factor 2: School media market
    var market_bonus = school.get("media_market_modifier", 0.0) * 10.0
    # USC/Alabama/Ohio State: +8 to +12
    # Mid-majors: -5 to +2
    # Small schools: -10 to -5

    # Factor 3: Position visibility (QBs get more attention)
    var position_modifier = {
        "QB": 12.0, "RB": 6.0, "WR": 5.0,
        "TE": 2.0, "OL": -3.0, "DL": 1.0,
        "EDGE": 4.0, "LB": 2.0, "CB": 3.0,
        "S": 1.0, "K": -8.0, "P": -10.0
    }.get(player.position, 0.0)

    # Factor 4: Random "it factor" variance
    var it_factor = randf_range(-8, 12)

    return clamp(base_hype + recruiting_rank_bonus + market_bonus + position_modifier + it_factor, 15, 95)
```

##### Hype Modifiers During College Career

| Event | Hype Change | Notes |
|-------|-------------|-------|
| Heisman finalist | +15 to +25 | Major national exposure |
| Conference player of year | +8 to +12 | Regional buzz |
| Bowl game MVP | +10 to +18 | Big stage performance |
| Viral highlight play | +5 to +15 | Social media boost |
| National championship starter | +8 to +15 | Peak exposure |
| Injury (major) | -10 to -20 | Concerns emerge |
| Off-field incident | -15 to -30 | Red flags |
| Underwhelming season | -5 to -12 | Hype cools |
| Transfer to bigger program | +5 to +12 | New market exposure |
| Limited playing time | -8 to -15 | "Why isn't he playing?" |

```gdscript
func apply_hype_event(current_hype: float, event_type: String) -> float:
    var modifiers = {
        "heisman_finalist": randf_range(15, 25),
        "conference_poy": randf_range(8, 12),
        "bowl_mvp": randf_range(10, 18),
        "viral_highlight": randf_range(5, 15),
        "natl_championship": randf_range(8, 15),
        "major_injury": randf_range(-20, -10),
        "off_field_issue": randf_range(-30, -15),
        "underwhelming_season": randf_range(-12, -5),
        "transfer_up": randf_range(5, 12),
        "limited_snaps": randf_range(-15, -8)
    }

    var change = modifiers.get(event_type, 0.0)
    return clamp(current_hype + change, 10, 98)
```

##### Combine/Pro Day Hype Spikes

The combine creates massive hype swings based on measurables:

```gdscript
func apply_combine_hype(current_hype: float, player: Dictionary, position: String) -> float:
    var combine_modifier = 0.0

    # Elite 40 time creates buzz
    var forty = player.get("forty_time", 5.0)
    var expected_forty = get_position_expected_forty(position)
    if forty < expected_forty - 0.15:
        combine_modifier += randf_range(8, 18)  # "He ran a 4.3!"
    elif forty > expected_forty + 0.15:
        combine_modifier += randf_range(-12, -5)  # "Slower than expected"

    # Bench press for OL/DL
    if position in ["OL", "DL", "TE", "EDGE"]:
        var bench = player.get("bench_reps", 20)
        if bench >= 30:
            combine_modifier += randf_range(3, 8)
        elif bench < 15:
            combine_modifier += randf_range(-5, -2)

    # Vertical/broad for skill positions
    if position in ["WR", "CB", "RB", "S"]:
        var vertical = player.get("vertical_jump", 32)
        if vertical >= 40:
            combine_modifier += randf_range(5, 12)  # "Elite explosion!"

    # Interview presence (subjective but real)
    var interview_score = player.get("charisma", 50) + randf_range(-10, 10)
    if interview_score >= 75:
        combine_modifier += randf_range(3, 8)  # "Great kid, coaches love him"
    elif interview_score < 40:
        combine_modifier += randf_range(-8, -3)  # "Personality concerns"

    return clamp(current_hype + combine_modifier, 10, 98)
```

##### Hype Distribution by Draft Position

Expected hype ranges correlate with (but don't guarantee) draft position:

| Draft Range | Typical Hype | Notes |
|-------------|--------------|-------|
| Top 5 | 75-95 | Generational buzz |
| 6-15 | 65-82 | High-profile prospects |
| 16-32 | 55-72 | Solid first-rounders |
| Round 2 | 45-62 | Known quantities |
| Round 3-4 | 35-55 | Role player expectations |
| Round 5-7 | 20-45 | Low profile, camp bodies |
| UDFA | 15-35 | Unknown, prove-it guys |

**Key insight:** Hype and ability are correlated but not identical. A 70-hype player might be a true 80 (hidden gem) or a true 60 (bust). The variance creates draft intrigue.

##### Anti-Hype: The "Boring" Prospect Penalty

Some legitimately good players have LOW hype due to:
- Playing at small schools (no TV exposure)
- "Pro style" game that doesn't create highlights
- Quiet personality, avoids media
- Position that doesn't get attention (guards, safeties)
- Consistent but unspectacular production

```gdscript
func calculate_boring_prospect_penalty(player: Dictionary, school: Dictionary) -> float:
    var penalty = 0.0

    # Small school penalty
    if school.get("media_tier", "small") == "small":
        penalty -= randf_range(8, 15)

    # "Pro style" players don't pop on tape
    if player.get("play_style", "") == "pro_style":
        penalty -= randf_range(3, 8)

    # Low charisma = no media buzz
    if player.get("charisma", 50) < 40:
        penalty -= randf_range(5, 10)

    # Position visibility
    if player.position in ["OL", "S", "K", "P"]:
        penalty -= randf_range(3, 8)

    return penalty
```

This creates situations where good players fall in drafts because nobody's talking about them - just like real life.

## Rating Calculation with Visibility

### Displayed Rating (What Teams See)

```gdscript
func calculate_displayed_rating(player: Player, position: String, scouting_data: Dictionary) -> float:
    var public_stats = get_public_stats_for_position(position)
    var scouted_stats = scouting_data.get("revealed_stats", {})

    var sum = 0.0
    var count = 0

    # Always include public stats
    for stat in public_stats:
        sum += player.stats.get(stat, 50.0)
        count += 1

    # Include scouted stats at their evaluated (possibly inaccurate) values
    for stat in scouted_stats:
        sum += scouted_stats[stat]  # This is the scout's estimate, not true value
        count += 1

    return sum / count if count > 0 else 50.0
```

### True Rating (Internal)

```gdscript
func calculate_true_rating(player: Player, position: String) -> float:
    var public_stats = get_public_stats_for_position(position)
    var scoutable_stats = get_scoutable_stats_for_position(position)
    # Note: Hidden stats intentionally excluded

    var sum = 0.0
    var count = 0

    for stat in public_stats + scoutable_stats:
        sum += player.stats.get(stat, 50.0)
        count += 1

    return sum / count if count > 0 else 50.0
```

## Information Asymmetry Example

**Rookie QB "Marcus Webb"**

| Stat | True Value | Visibility | Unscouted | Scouted (by avg scout) |
|------|-----------|------------|-----------|------------------------|
| throw_power | 88 | Public | 88 | 88 |
| throw_accuracy | 82 | Public | 82 | 82 |
| speed | 72 | Public | 72 | 72 |
| reaction_time | 75 | Public | 75 | 75 |
| decision_making | 68 | Scoutable (Medium) | ? | 71 |
| awareness | 65 | Scoutable (Medium) | ? | 62 |
| anticipation | 58 | Scoutable (Very Hard) | ? | 68 |
| composure | 55 | Scoutable (Hard) | ? | 61 |
| football_IQ | 60 | Scoutable (Very Hard) | ? | 72 |
| clutch_factor | 42 | Hidden | ? | ? |

**Unscouted Rating (Public only):** 79.3 - "Great arm talent!"
**Scouted Rating (with noise):** 74.2 - "Mental game needs work"
**True Rating (all scoutable):** 69.2 - "Significant processing concerns"
**In-Game Performance:** Affected by all stats including clutch_factor = 42

The team that didn't scout sees a 79. The team that scouted sees a 74. The true value is 69. And in big moments, that hidden 42 clutch_factor creates problems nobody predicted.

---

# Position Stat Configurations

## QB (Proposed)

Based on Option B (Mental-Heavy Core), with visibility tiers:

```json
"QB": {
  "core_stats": ["throw_accuracy", "decision_making", "awareness", "anticipation", "composure"],
  "distributions": {
    "throw_accuracy":   { "mu": 78, "sigma": 9,  "cap_pct": 0.99, "role": "core", "visibility": "public" },
    "decision_making":  { "mu": 73, "sigma": 7,  "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "medium" },
    "awareness":        { "mu": 73, "sigma": 7,  "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "medium" },
    "anticipation":     { "mu": 70, "sigma": 8,  "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "very_hard" },
    "composure":        { "mu": 68, "sigma": 9,  "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "hard" },

    "throw_power":      { "mu": 79, "sigma": 9,  "cap_pct": 0.99, "role": "secondary", "visibility": "public" },
    "reaction_time":    { "mu": 72, "sigma": 7,  "cap_pct": 0.99, "role": "secondary", "visibility": "public" },
    "football_IQ":      { "mu": 68, "sigma": 8,  "cap_pct": 0.99, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "very_hard" },
    "speed":            { "mu": 55, "sigma": 10, "cap_pct": 0.97, "role": "secondary", "visibility": "public" },
    "agility":          { "mu": 56, "sigma": 9,  "cap_pct": 0.97, "role": "secondary", "visibility": "public" },

    "focus":            { "mu": 65, "sigma": 8,  "cap_pct": 0.98, "role": "other", "visibility": "scoutable", "scout_difficulty": "medium" },
    "confidence":       { "mu": 68, "sigma": 10, "cap_pct": 0.98, "role": "other", "visibility": "scoutable", "scout_difficulty": "medium" },
    "stamina":          { "mu": 58, "sigma": 8,  "cap_pct": 0.96, "role": "other", "visibility": "scoutable", "scout_difficulty": "hard" },
    "strength":         { "mu": 45, "sigma": 6,  "cap_pct": 0.95, "role": "other", "visibility": "public" },
    "tackling":         { "mu": 30, "sigma": 6,  "cap_pct": 0.95, "role": "other", "visibility": "scoutable", "scout_difficulty": "easy" },
    "blocking":         { "mu": 28, "sigma": 6,  "cap_pct": 0.95, "role": "other", "visibility": "scoutable", "scout_difficulty": "easy" }
  },
  "archetypes": {
    "PocketPasser": {
      "weight": 0.45,
      "core_stats_override": ["throw_accuracy", "decision_making", "awareness", "anticipation", "throw_power"],
      "dist_overrides": {
        "throw_accuracy":  { "mu_add": 4 },
        "throw_power":     { "mu_add": 3, "role": "core" },
        "decision_making": { "mu_add": 3 },
        "awareness":       { "mu_add": 2 },
        "speed":           { "mu_add": -4 },
        "agility":         { "mu_add": -3 },
        "composure":       { "mu_add": 2 }
      }
    },
    "DualThreat": {
      "weight": 0.35,
      "core_stats_override": ["throw_accuracy", "speed", "agility", "decision_making", "anticipation"],
      "dist_overrides": {
        "speed":           { "mu_add": 10, "role": "core", "cap_pct": 1.0 },
        "agility":         { "mu_add": 8, "role": "core" },
        "throw_power":     { "mu_add": 2 },
        "awareness":       { "mu_add": -2 },
        "decision_making": { "mu_add": -1 },
        "composure":       { "mu_add": -2 }
      }
    },
    "FieldGeneral": {
      "weight": 0.20,
      "core_stats_override": ["throw_accuracy", "decision_making", "awareness", "anticipation", "football_IQ"],
      "dist_overrides": {
        "throw_accuracy":  { "mu_add": 5, "cap_pct": 1.0 },
        "decision_making": { "mu_add": 5 },
        "awareness":       { "mu_add": 4 },
        "football_IQ":     { "mu_add": 5, "role": "core" },
        "anticipation":    { "mu_add": 4 },
        "composure":       { "mu_add": 4 },
        "throw_power":     { "mu_add": -3 },
        "speed":           { "mu_add": -2 }
      }
    }
  }
}
```

### QB Rating Impact Analysis

**Public stats only (unscouted):** throw_accuracy, throw_power, reaction_time, speed, agility, strength
- Average: ~65 for a typical QB prospect
- Missing: decision_making, awareness, anticipation, composure, football_IQ

**Fully scouted:** Adds decision_making, awareness, anticipation, composure, football_IQ
- The mental game stats are what separate good from great
- Very Hard stats (anticipation, football_IQ) are often mis-evaluated

This creates meaningful scouting value for QBs specifically.

## K/P (Proposed)

Expanded to prevent inflated ratings:

```json
"K": {
  "core_stats": ["kick_power", "kick_accuracy", "composure", "focus"],
  "distributions": {
    "kick_power":    { "mu": 78, "sigma": 8, "cap_pct": 0.99, "role": "core", "visibility": "public" },
    "kick_accuracy": { "mu": 76, "sigma": 8, "cap_pct": 0.99, "role": "core", "visibility": "public" },
    "composure":     { "mu": 68, "sigma": 12, "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "hard" },
    "focus":         { "mu": 66, "sigma": 10, "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "medium" },

    "awareness":     { "mu": 58, "sigma": 8, "cap_pct": 0.98, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "medium" },
    "confidence":    { "mu": 65, "sigma": 12, "cap_pct": 0.98, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "medium" },
    "discipline":    { "mu": 60, "sigma": 8, "cap_pct": 0.98, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "hard" },

    "strength":      { "mu": 52, "sigma": 8, "cap_pct": 0.96, "role": "other", "visibility": "public" },
    "speed":         { "mu": 45, "sigma": 7, "cap_pct": 0.90, "role": "other", "visibility": "public" },
    "tackling":      { "mu": 32, "sigma": 8, "cap_pct": 0.95, "role": "other", "visibility": "scoutable", "scout_difficulty": "easy" }
  }
},

"P": {
  "core_stats": ["kick_power", "kick_accuracy", "composure", "focus"],
  "distributions": {
    "kick_power":    { "mu": 80, "sigma": 7, "cap_pct": 0.99, "role": "core", "visibility": "public" },
    "kick_accuracy": { "mu": 74, "sigma": 8, "cap_pct": 0.99, "role": "core", "visibility": "public" },
    "composure":     { "mu": 66, "sigma": 10, "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "hard" },
    "focus":         { "mu": 64, "sigma": 10, "cap_pct": 0.99, "role": "core", "visibility": "scoutable", "scout_difficulty": "medium" },

    "awareness":     { "mu": 60, "sigma": 8, "cap_pct": 0.98, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "medium" },
    "confidence":    { "mu": 62, "sigma": 10, "cap_pct": 0.98, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "medium" },
    "tackling":      { "mu": 42, "sigma": 10, "cap_pct": 0.96, "role": "secondary", "visibility": "scoutable", "scout_difficulty": "easy" },

    "speed":         { "mu": 52, "sigma": 8, "cap_pct": 0.95, "role": "other", "visibility": "public" },
    "strength":      { "mu": 48, "sigma": 8, "cap_pct": 0.96, "role": "other", "visibility": "public" },
    "agility":       { "mu": 50, "sigma": 8, "cap_pct": 0.95, "role": "other", "visibility": "public" },
    "throw_accuracy":{ "mu": 38, "sigma": 10, "cap_pct": 0.95, "role": "other", "visibility": "public" }
  }
}
```

### K/P Rating Impact

**Before (2 core stats):**
- Elite kicker: (92 + 90) / 2 = **91 overall**

**After (4 core stats):**
- Elite kicker: (92 + 90 + 80 + 78) / 4 = **85 overall**

More realistic ceiling that doesn't exceed elite QBs/pass rushers.

---

# High School Simulation Simplification

## Current State (Overly Complex)

The current HS system includes:
- 420 individual high schools with capacity tracking
- Per-school program quality tiers
- Position specialist coaches at schools
- Annual performance bundles with games/snaps
- Regional competition tiers
- Scheme fit calculations
- Full eligibility tracking (4 years)

This is too much simulation depth for a level of play that doesn't directly impact the core NFL experience.

## Design Goal

High school should:
1. **Exist** as a player origin point
2. **Affect development** based on program quality
3. **Generate recruiting rankings** (star ratings)
4. **NOT require deep simulation** - no game-by-game tracking

## Simplified HS Model

### What We Keep

**Player attributes assigned at HS entry:**
```gdscript
{
    "hs_program_tier": "elite" | "good" | "avg" | "low",
    "hs_region": "south" | "midwest" | "west" | "northeast",
    "recruiting_star_rating": 2-5,
    "initial_hype": float,  # Based on star rating + region
    "development_modifier": float  # From program tier
}
```

**Development multipliers (simplified):**
```json
{
    "hs_program_tiers": {
        "elite": { "dev_modifier": 1.08, "weight": 0.08 },
        "good": { "dev_modifier": 1.03, "weight": 0.25 },
        "avg": { "dev_modifier": 1.00, "weight": 0.50 },
        "low": { "dev_modifier": 0.95, "weight": 0.17 }
    }
}
```

### What We Remove

- Individual school entities (no more 420 schools)
- School capacity tracking
- Position specialist coaches at HS level
- Per-year performance bundles
- Detailed usage profiles (games, snaps)
- HS school assignment algorithm
- HS season simulation

### Simplified Flow

**Generation (once per player):**
```gdscript
func generate_hs_background(player: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    # Assign region based on weighted distribution
    var region = weighted_pick(["south", "midwest", "west", "northeast"], [0.34, 0.22, 0.18, 0.26], rng)

    # Assign program tier (correlates slightly with player potential)
    var potential_factor = player.get("potential_overall", 50) / 100.0
    var tier_weights = adjust_tier_weights_by_potential(potential_factor)
    var program_tier = weighted_pick(["elite", "good", "avg", "low"], tier_weights, rng)

    # Star rating based on potential + noise
    var star_rating = calculate_star_rating(player, program_tier, rng)

    # Development modifier from program tier
    var dev_modifier = HS_TIER_MODIFIERS[program_tier]

    return {
        "hs_region": region,
        "hs_program_tier": program_tier,
        "recruiting_star_rating": star_rating,
        "development_modifier": dev_modifier,
        "initial_hype": generate_initial_hype_from_stars(star_rating, region, player.position, rng)
    }
```

**Development application (once at college entry):**
```gdscript
func apply_hs_development(player: Dictionary) -> void:
    var hs_years = 4
    var dev_modifier = player.get("development_modifier", 1.0)

    # Apply cumulative development effect
    for stat in player.stats.keys():
        var growth = calculate_hs_growth(stat, hs_years, dev_modifier)
        player.stats[stat] = min(player.stats[stat] + growth, player.potential[stat])
```

### Star Rating Calculation

```gdscript
func calculate_star_rating(player: Dictionary, program_tier: String, rng: RandomNumberGenerator) -> int:
    var base_potential = player.get("potential_overall", 50)

    # Program tier affects visibility (elite programs get more scouts)
    var visibility_bonus = {
        "elite": 8,
        "good": 3,
        "avg": 0,
        "low": -5
    }[program_tier]

    var effective_rating = base_potential + visibility_bonus + rng.randf_range(-10, 10)

    # Convert to stars
    if effective_rating >= 88:
        return 5
    elif effective_rating >= 78:
        return 4
    elif effective_rating >= 65:
        return 3
    else:
        return 2  # Minimum for college prospects
```

### Benefits of Simplification

| Aspect | Before | After |
|--------|--------|-------|
| Schools tracked | 420 entities | 0 (just tier label) |
| Per-player HS data | ~15 fields | ~5 fields |
| Simulation passes | 3 per year | 1 at generation |
| Assignment algorithm | Complex weighted | None |
| Season simulation | Full | None |

**Performance impact:** HS phase goes from O(n × schools) to O(n) where n = players.

### What This Preserves

1. **Regional flavor** - Players still come from different parts of the country
2. **Development variance** - Elite programs still produce better-developed prospects
3. **Recruiting rankings** - Star ratings still exist and affect hype/draft
4. **Hidden gems** - Low-tier program players can still have high potential
5. **Bust potential** - Elite program + high stars doesn't guarantee success

### Migration Path

1. Remove `HighSchoolGenerator.gd` - no longer needed
2. Remove `HighSchoolAssignment.gd` - no longer needed
3. Simplify `HighSchoolSeason.gd` → `HighSchoolBackground.gd` (one-time generation)
4. Update `AdvanceWorldYear.gd` to use simplified flow
5. Remove HS school capacity from world state
6. Update UI to show simplified HS background info

### Example Output

**Before (complex):**
```json
{
    "hs_school_id": "hs_0247",
    "hs_year": 4,
    "eligibility_status": "hs_grad",
    "hs_stats": {
        "year": 2025,
        "performance_score": 72.4,
        "school_id": "hs_0247",
        "rating_basis": 68.2
    },
    "development_context": {
        "program_quality": { "multiplier": 1.04 },
        "position_specialist": { "applies": false },
        "scheme_fit": { "score": 0.08 }
    }
}
```

**After (simplified):**
```json
{
    "hs_region": "south",
    "hs_program_tier": "good",
    "recruiting_star_rating": 4,
    "development_modifier": 1.03,
    "initial_hype": 62
}
```

Much cleaner, same gameplay impact.
