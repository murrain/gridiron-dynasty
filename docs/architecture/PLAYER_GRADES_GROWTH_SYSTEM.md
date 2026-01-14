# Player Grades and Growth System Architecture

## Overview

This document outlines the architectural design for three interconnected features:
1. **PFF-Style Performance Grades** - Post-season performance evaluation system
2. **Non-Linear Player Growth** - Variable, unpredictable player development paths
3. **Career Life Events** - Dynamic stat changes based on contract, team, and personal events

These features work together to create emergent gameplay where:
- Players can outperform their measurable attributes due to high "football IQ"
- Two identically-rated prospects can have vastly different career trajectories
- Coaches must scout and predict hard-to-measure "Potential"
- Contract decisions can be based on actual performance vs raw ratings

---

## Feature 1: PFF-Style Performance Grades

### 1.1 Design Goals

| Goal | Description |
|------|-------------|
| **Surface Hidden Gems** | A CB with average measurables but high football IQ gets lots of interceptions, receiving elite grade despite mediocre composite rating |
| **Performance vs Expectation** | Grade measures how well a player performed relative to their expected production |
| **Public Information (NFL)** | Grades are nationally available at the Pro level - all scouts and coaches can see them |
| **Contract Implications** | Teams can restructure deals based on graded performance vs composite rating |
| **Scouting Value** | Helps identify players whose immeasurables (awareness, anticipation, decision_making) drive outcomes |

### 1.2 Grade Calculation Philosophy

Unlike the existing `composite_score` which measures **attributes**, the Performance Grade measures **outcomes**:

```
                                     ┌─────────────────────────┐
                                     │   Composite Rating      │
                                     │   (What they CAN do)    │
                                     │   - Speed: 85           │
                                     │   - Strength: 72        │
                                     │   - Awareness: 90       │
                                     └───────────┬─────────────┘
                                                 │
                                                 ▼
                                     ┌─────────────────────────┐
                                     │   Season Performance    │
                                     │   (What they DID do)    │
                                     │   - Stats accumulated   │
                                     │   - Context adjustments │
                                     └───────────┬─────────────┘
                                                 │
                                                 ▼
                                     ┌─────────────────────────┐
                                     │   Performance Grade     │
                                     │   (How well they played)│
                                     │   - 0-100 scale         │
                                     │   - Position-relative   │
                                     └─────────────────────────┘
```

### 1.3 Data Model: SeasonGrade

**Location**: Add to player's season data or as separate `season_grades` structure in `world_state`

```gdscript
## SeasonGrade Schema
{
    "player_id": String,
    "year": int,
    "team_id": String,
    "position": String,

    # Core Grade (0-100 scale, 60 = average starter)
    "overall_grade": float,           # Final performance grade
    "offensive_grade": float,         # For offensive players (null for defense)
    "defensive_grade": float,         # For defensive players (null for offense)

    # Grade Components (position-specific)
    "component_grades": {
        # QB example:
        "passing_grade": float,
        "decision_making_grade": float,
        "pressure_grade": float,       # Performance under pressure

        # CB example:
        "coverage_grade": float,
        "ball_skills_grade": float,    # INTs, PBUs relative to targets
        "tackling_grade": float
    },

    # Context (for grade interpretation)
    "games_graded": int,
    "snaps_graded": int,
    "expected_production": Dictionary, # Baseline based on rating
    "actual_production": Dictionary,   # What they actually produced

    # Performance vs Expectation
    "production_delta": float,         # (actual - expected) / expected
    "overperformer": bool,             # True if actual >> expected
    "underperformer": bool,            # True if actual << expected

    # Ranking
    "position_rank": int,              # Rank among all players at position
    "league_percentile": float         # Percentile among all NFL players
}
```

### 1.4 Grade Calculation Algorithm

```gdscript
## PerformanceGrader.gd (new file)
class_name PerformanceGrader

## Calculate performance grade for a player's season
##
## Algorithm:
##   1. Calculate expected production based on composite rating
##   2. Get actual production from accumulated stats
##   3. Compute production delta (actual vs expected)
##   4. Apply position-specific weighting
##   5. Scale to 0-100 grade
##
## Immeasurables that boost grades:
##   - High football IQ (awareness, anticipation) -> better positioning
##   - Elite decision_making -> fewer mistakes, more opportunistic plays
##   - High composure -> clutch performances
##
## RNG Consumption: None (pure calculation post-season)
static func calculate_season_grade(
    player: Dictionary,
    season_stats: Dictionary,
    positions_cfg: Dictionary,
    main_cfg: Dictionary
) -> Dictionary:
    pass
```

### 1.5 Position-Specific Grade Formulas

**CB Grade Example** (showing how immeasurables surface):

```gdscript
## CB Performance Grade
##
## A CB with high awareness/anticipation will:
##   - Generate more interceptions per coverage snap
##   - Have better ball skills grade despite average speed
##
## Expected INTs = f(coverage, speed, ball_skills)
## Actual INTs = season_stats["interceptions"]
##
## The delta reveals the "football IQ factor"
func _grade_cb(player, stats, positions_cfg) -> Dictionary:
    var rating := _get_composite_rating(player, positions_cfg)

    # Expected production (based purely on measurables)
    var expected_ints := _expected_cb_ints(rating)  # ~2-4 per season for starter
    var expected_pbus := _expected_cb_pbus(rating)  # ~8-15 per season
    var expected_tackles := _expected_cb_tackles(rating)  # ~40-60 per season

    # Actual production
    var actual_ints := float(stats.get("interceptions", 0))
    var actual_pbus := float(stats.get("pass_breakups", 0))
    var actual_tackles := float(stats.get("tackles", 0))

    # Production deltas (positive = overperformance)
    var int_delta := (actual_ints - expected_ints) / max(1.0, expected_ints)
    var pbu_delta := (actual_pbus - expected_pbus) / max(1.0, expected_pbus)
    var tackle_delta := (actual_tackles - expected_tackles) / max(1.0, expected_tackles)

    # Weighted grade (INTs heavily weighted for "playmaker" identification)
    var ball_skills_grade := 60.0 + (int_delta * 25.0) + (pbu_delta * 10.0)
    var coverage_grade := 60.0 + (pbu_delta * 15.0) - (stats.get("completions_allowed", 0) * 0.5)
    var tackling_grade := 60.0 + (tackle_delta * 10.0)

    # Overall: Ball skills weighted heavily to surface "Ball Hawk" type players
    var overall := (ball_skills_grade * 0.45) + (coverage_grade * 0.40) + (tackling_grade * 0.15)

    return {
        "overall_grade": clamp(overall, 0.0, 100.0),
        "ball_skills_grade": clamp(ball_skills_grade, 0.0, 100.0),
        "coverage_grade": clamp(coverage_grade, 0.0, 100.0),
        "tackling_grade": clamp(tackling_grade, 0.0, 100.0),
        "overperformer": int_delta > 0.5,  # 50%+ more INTs than expected
        "production_delta": (int_delta + pbu_delta + tackle_delta) / 3.0
    }
```

### 1.6 Integration Points

| System | Integration |
|--------|-------------|
| **NflSeason.gd** | Call `PerformanceGrader.grade_all_players()` at end of season |
| **AwardSelector.gd** | Use grades as input for All-Pro, Pro Bowl selections |
| **PlayerValue.gd** | Factor performance grades into contract negotiations |
| **Scouting** | Scouts can compare grade vs composite to identify "hidden gems" |
| **UI** | Display grades alongside composite rating on player cards |

### 1.7 Grade Storage in world_state

```gdscript
## Storage location
world_state["performance_grades"] = {
    2025: {  # Year
        "player_001": {grade_data...},
        "player_002": {grade_data...}
    },
    2026: {...}
}

## Also write to player's career record for historical tracking
player["career_grades"] = [
    {year: 2025, grade: 85.5, rank: 12},
    {year: 2026, grade: 78.2, rank: 28}
]
```

### 1.8 Configuration

Add to `main.json` or new `grading.json`:

```json
{
    "performance_grading": {
        "enabled": true,
        "grade_scale": {
            "min": 0.0,
            "max": 100.0,
            "average_starter": 60.0,
            "elite_threshold": 85.0,
            "poor_threshold": 45.0
        },
        "position_weights": {
            "CB": {
                "ball_skills": 0.45,
                "coverage": 0.40,
                "tackling": 0.15
            },
            "QB": {
                "passing": 0.50,
                "decision_making": 0.30,
                "pressure_performance": 0.20
            }
        },
        "overperformer_threshold": 0.3,
        "underperformer_threshold": -0.3
    }
}
```

---

## Feature 2: Non-Linear Player Growth

### 2.1 Design Goals

| Goal | Description |
|------|-------------|
| **Unpredictable Trajectories** | Two 70-rated rookies could end up at 72 vs 85 years later |
| **Late Bloomers** | Some players develop slowly through college but flourish at the Pro level |
| **Early Peakers** | Some players reach their ceiling quickly, then plateau or decline |
| **Hidden Potential** | Coaches must scout hard-to-measure "development potential" |
| **Emergent Stories** | Creates narrative moments: "Nobody expected him to become elite" |

### 2.2 Current Growth System (for reference)

The existing `PlayerLifecycle` already provides:
- Position-specific peak/decline ages
- Three development curves (early, mid, late)
- Context modifiers (program quality, usage, etc.)
- Potential caps per stat

**What's Missing:**
- Per-player growth variance (currently position-based only)
- Hidden "development potential" that affects growth rate
- Breakthrough/plateau events
- Non-linear growth trajectories

### 2.3 Data Model: DevelopmentProfile

**Location**: Add to player as `development_profile` Dictionary

```gdscript
## DevelopmentProfile Schema (hidden from scouting by default)
{
    # Core development traits (generated at player creation)
    "growth_rate_modifier": float,     # 0.7 - 1.3 (multiplies base growth)
    "prime_potential": float,          # 0.8 - 1.2 (how much of potential they'll reach)
    "bloom_age_offset": int,           # -2 to +4 years (when they "click")

    # Development type (determines growth curve shape)
    "development_type": String,        # "steady", "late_bloomer", "early_peak", "erratic"

    # Hidden talent indicators (correlate with development outcomes)
    "raw_talent": float,               # 50-100 (natural ceiling indicator)
    "work_ethic_hidden": float,        # 0.7 - 1.3 (affects consistency)
    "football_iq_hidden": float,       # 0.7 - 1.3 (affects learning rate)

    # Event probabilities (per-year chances)
    "breakthrough_chance": float,      # 0.02 - 0.15 (chance of sudden improvement)
    "plateau_chance": float,           # 0.05 - 0.20 (chance of stagnation)

    # State tracking
    "has_broken_through": bool,        # True after a breakthrough year
    "plateau_years": int,              # Consecutive years of minimal growth
    "development_events": Array        # History of breakthrough/plateau events
}
```

### 2.4 Development Types

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                        Development Type Curves                                  │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Rating                                                                         │
│    100 ┤                                                                        │
│        │                           early_peak (reaches potential fast)          │
│     90 ┤                     ╭─────────────────────────────                     │
│        │                   ╱                                                    │
│     80 ┤                 ╱      steady (linear growth)                          │
│        │         ╭─────────────────────────────────────                         │
│     70 ┤        ╱                                                               │
│        │      ╱                                                                 │
│     60 ┤    ╱         late_bloomer (slow start, rapid mid-career)               │
│        │  ╱                  ╭───────────────────────────                       │
│     50 ┤ ╱             ╭───╯                                                    │
│        │╱         ╭───╯                                                         │
│     40 ┼────╮╱───╯                                                              │
│        │                                                                        │
│     30 ┤    erratic (unpredictable swings)                                      │
│        │      ╭─╮    ╭───╮                                                      │
│     20 ┤─────╯  ╰──╯     ╰───────                                               │
│        │                                                                        │
│        └────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬                 │
│             21   22   23   24   25   26   27   28   29   30   31   Age          │
│             │─────── College ──────│──────── NFL ─────────────│                 │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 2.5 Development Type Definitions

```gdscript
## Development type configuration
const DEVELOPMENT_TYPES := {
    "steady": {
        "description": "Consistent, predictable growth",
        "growth_variance": 0.1,        # Low variance year-to-year
        "breakthrough_chance": 0.03,   # Low breakthrough chance
        "plateau_chance": 0.08,        # Low plateau chance
        "college_growth_mult": 1.0,
        "pro_growth_mult": 1.0
    },
    "late_bloomer": {
        "description": "Slow early development, rapid improvement in prime years",
        "growth_variance": 0.2,
        "breakthrough_chance": 0.12,   # High breakthrough chance
        "plateau_chance": 0.05,        # Low plateau (they just haven't peaked)
        "college_growth_mult": 0.7,    # Grows slowly in college
        "pro_growth_mult": 1.4,        # Flourishes in pros
        "bloom_age_range": [24, 27]    # When breakthrough likely happens
    },
    "early_peak": {
        "description": "Reaches ceiling quickly, minimal improvement after",
        "growth_variance": 0.15,
        "breakthrough_chance": 0.02,   # Already peaked
        "plateau_chance": 0.25,        # High plateau chance
        "college_growth_mult": 1.3,    # Grows fast in college
        "pro_growth_mult": 0.6,        # Slows down in pros
        "peak_age_offset": -2          # Peaks earlier than position average
    },
    "erratic": {
        "description": "Unpredictable swings in performance and development",
        "growth_variance": 0.4,        # High variance
        "breakthrough_chance": 0.10,
        "plateau_chance": 0.15,
        "regression_chance": 0.08,     # Can actually lose rating
        "college_growth_mult": 1.0,
        "pro_growth_mult": 1.0
    }
}
```

### 2.6 Modified Growth Algorithm

```gdscript
## Enhanced _apply_development (conceptual)
static func _apply_development_enhanced(
    player: Dictionary,
    dev_config: DevelopmentConfig,
    positions_cfg: Dictionary,
    stats_cfg: Dictionary,
    rng: RandomNumberGenerator,
    development_context: Dictionary
) -> Dictionary:
    # Get development profile (or generate if missing)
    var profile := _ensure_development_profile(player, rng)

    # Base growth from existing algorithm
    var base_growth := _calculate_base_growth(player, dev_config, positions_cfg, rng)

    # Apply development type modifiers
    var type_config := DEVELOPMENT_TYPES.get(profile["development_type"], DEVELOPMENT_TYPES["steady"])
    var age := int(player.get("age", 18))

    # College vs Pro growth multiplier
    var level_mult := 1.0
    if age <= 22:  # College
        level_mult = float(type_config["college_growth_mult"])
    else:  # Pro
        level_mult = float(type_config["pro_growth_mult"])

    # Apply individual growth rate modifier
    var individual_mult := float(profile["growth_rate_modifier"])

    # Check for breakthrough event
    var breakthrough_roll := rng.randf()
    if breakthrough_roll < float(profile["breakthrough_chance"]):
        if not profile["has_broken_through"]:
            # BREAKTHROUGH! Significant one-time boost
            base_growth *= 2.5
            profile["has_broken_through"] = true
            profile["development_events"].append({
                "type": "breakthrough",
                "age": age,
                "growth_boost": base_growth
            })

    # Check for plateau event
    var plateau_roll := rng.randf()
    if plateau_roll < float(profile["plateau_chance"]):
        # PLATEAU - minimal growth this year
        base_growth *= 0.2
        profile["plateau_years"] = int(profile.get("plateau_years", 0)) + 1
        profile["development_events"].append({
            "type": "plateau",
            "age": age,
            "consecutive_years": profile["plateau_years"]
        })
    else:
        profile["plateau_years"] = 0  # Reset streak

    # Final growth calculation
    var final_growth := base_growth * level_mult * individual_mult

    # Apply variance based on development type
    var variance := rng.randf_range(
        -float(type_config["growth_variance"]),
        float(type_config["growth_variance"])
    )
    final_growth *= (1.0 + variance)

    # Cap by prime_potential (not all players reach full potential)
    var potential_ceiling := float(profile["prime_potential"])
    # This affects the final potential cap check later

    player["development_profile"] = profile

    return {
        "base_growth": base_growth,
        "final_growth": final_growth,
        "development_type": profile["development_type"],
        "breakthrough": breakthrough_roll < float(profile["breakthrough_chance"]),
        "plateau": plateau_roll < float(profile["plateau_chance"])
    }
```

### 2.7 Development Profile Generation

```gdscript
## Generate development profile at player creation
static func generate_development_profile(
    player: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Determine development type (weighted random)
    # Note: Hidden traits can influence this
    var type_weights := {
        "steady": 0.50,      # Most common
        "late_bloomer": 0.20,
        "early_peak": 0.18,
        "erratic": 0.12
    }

    # Hidden traits can shift weights
    var hidden_traits: Array = player.get("hidden_traits", [])
    if "high_ceiling" in hidden_traits:
        type_weights["late_bloomer"] += 0.15
        type_weights["steady"] -= 0.10
    if "polished" in hidden_traits:
        type_weights["early_peak"] += 0.12
        type_weights["late_bloomer"] -= 0.08
    if "project" in hidden_traits:
        type_weights["late_bloomer"] += 0.20
        type_weights["early_peak"] -= 0.15

    var dev_type := _weighted_random_choice(type_weights, rng)

    # Generate individual modifiers
    var growth_rate := rng.randf_range(0.7, 1.3)
    var prime_potential := rng.randf_range(0.8, 1.2)

    # Hidden traits affect modifiers
    var stats: Dictionary = player.get("stats", {})
    var work_ethic := float(stats.get("work_ethic", 50.0))
    var coachability := float(stats.get("coachability", 50.0))

    # High work ethic = more likely to reach potential
    prime_potential *= (0.9 + work_ethic / 500.0)  # 0.9 - 1.1 modifier

    # High coachability = faster growth
    growth_rate *= (0.9 + coachability / 500.0)

    return {
        "development_type": dev_type,
        "growth_rate_modifier": clamp(growth_rate, 0.6, 1.5),
        "prime_potential": clamp(prime_potential, 0.7, 1.3),
        "bloom_age_offset": rng.randi_range(-2, 4),
        "raw_talent": rng.randf_range(50.0, 100.0),
        "work_ethic_hidden": float(stats.get("work_ethic", 50.0)) / 50.0,
        "football_iq_hidden": float(stats.get("awareness", 50.0)) / 50.0,
        "breakthrough_chance": _calculate_breakthrough_chance(dev_type, stats),
        "plateau_chance": _calculate_plateau_chance(dev_type, stats),
        "has_broken_through": false,
        "plateau_years": 0,
        "development_events": []
    }
```

### 2.8 Scouting Integration

The `development_profile` should be **hidden by default** but partially revealable through scouting:

```gdscript
## ScoutingReport schema addition
{
    # Existing scouting data...

    # Development projection (partially observable)
    "development_projection": {
        "type_guess": String,          # Scout's guess at development type
        "type_confidence": float,      # 0.3 - 0.9 confidence
        "ceiling_projection": String,  # "low", "medium", "high", "elite"
        "bloom_projection": String,    # "early", "normal", "late", "unknown"
        "risk_assessment": String      # "safe", "moderate", "high", "boom_or_bust"
    }
}
```

### 2.9 Configuration

Add to `main.json`:

```json
{
    "development": {
        "existing_config...": "...",

        "non_linear_growth": {
            "enabled": true,
            "profile_generation": {
                "type_weights": {
                    "steady": 0.50,
                    "late_bloomer": 0.20,
                    "early_peak": 0.18,
                    "erratic": 0.12
                },
                "growth_rate_range": [0.7, 1.3],
                "prime_potential_range": [0.8, 1.2],
                "bloom_age_offset_range": [-2, 4]
            },
            "events": {
                "breakthrough_growth_mult": 2.5,
                "plateau_growth_mult": 0.2,
                "max_plateau_years": 3
            },
            "trait_influences": {
                "high_ceiling_late_bloomer_boost": 0.15,
                "polished_early_peak_boost": 0.12,
                "project_late_bloomer_boost": 0.20
            }
        }
    }
}
```

---

## Feature 3: Career Life Events

### 3.1 Design Goals

| Goal | Description |
|------|-------------|
| **Dynamic Psychology** | Player mentality stats change based on career circumstances |
| **Realistic Motivation** | "Prove it" deals motivate, big paydays can create complacency |
| **Emergent Narratives** | Creates stories: "He got hungry after being cut" |
| **Consequences** | Contract and roster decisions have psychological ripple effects |
| **Unpredictability** | Same event can affect different personality types differently |

### 3.2 Event Categories

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        Career Life Event Categories                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  CONTRACT EVENTS          TEAM EVENTS              PERSONAL EVENTS              │
│  ─────────────────        ───────────              ───────────────              │
│  • Prove-it deal          • Traded                 • Marriage/Divorce           │
│  • Got paid (big $$$)     • Released/Cut           • New child                  │
│  • Contract year          • Benched                • Death in family            │
│  • Franchise tagged       • Named captain          • Off-field trouble          │
│  • Pay cut                • New coaching staff     • Financial issues           │
│  • Restructure            • Team drafts replacement• Charity/Community work    │
│  • Holdout                • Locker room drama      • Found religion             │
│                           • Veteran mentor                                      │
│                                                                                 │
│  PERFORMANCE EVENTS       COMPETITION EVENTS       MILESTONE EVENTS             │
│  ──────────────────       ──────────────────       ────────────────             │
│  • Career game            • Lost starting job      • First Pro Bowl             │
│  • Costly mistake         • Won starting job       • First All-Pro              │
│  • Injury comeback        • Rival signed           • Won championship           │
│  • Playoff failure        • Team signs star        • Hall of Fame eligible      │
│  • Super Bowl loss        • Position competition   • Record broken              │
│  • Award snub                                      • Jersey retired             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Data Model: CareerEvent

```gdscript
## CareerEvent Schema
{
    "event_type": String,           # Category.specific (e.g., "contract.prove_it_deal")
    "year": int,
    "age": int,
    "team_id": String,

    # What triggered the event
    "trigger": {
        "type": String,             # "contract_signed", "roster_move", "performance", etc.
        "details": Dictionary       # Event-specific context
    },

    # Stat modifications applied
    "stat_changes": {
        "work_ethic": float,        # Delta (e.g., +15, -25)
        "discipline": float,
        "composure": float,
        "focus": float,
        "coachability": float,
        "confidence": float         # New hidden stat
    },

    # Duration and decay
    "duration": String,             # "permanent", "seasonal", "temporary"
    "decay_rate": float,            # How fast temporary effects fade (0.0-1.0 per year)
    "years_remaining": int,         # For non-permanent effects

    # Narrative
    "headline": String,             # "Williams signs prove-it deal, has chip on shoulder"
    "description": String
}
```

### 3.4 Contract Events (Detailed)

#### 3.4.1 Prove-It Deal

**Trigger**: Player signs 1-year contract worth less than their market value (typically after injury, poor performance, or age concerns).

```gdscript
const PROVE_IT_DEAL := {
    "event_type": "contract.prove_it_deal",
    "stat_changes": {
        "work_ethic": [+10, +20],       # Range based on personality
        "focus": [+5, +15],
        "discipline": [+5, +10],
        "composure": [-5, +5]           # Pressure can help or hurt
    },
    "duration": "seasonal",
    "conditions": {
        "contract_years": 1,
        "contract_value_vs_market": "<0.7"  # Less than 70% of market value
    },
    "personality_modifiers": {
        "high_work_ethic_base": 1.3,    # Already hard workers get bigger boost
        "low_discipline_base": 0.7      # Undisciplined players less affected
    }
}
```

#### 3.4.2 Got Paid (Big Contract)

**Trigger**: Player signs contract significantly above market value or receives massive guaranteed money.

```gdscript
const GOT_PAID := {
    "event_type": "contract.got_paid",
    "stat_changes": {
        "work_ethic": [-15, -30],       # Complacency risk
        "discipline": [-10, -20],
        "focus": [-5, -15],
        "hunger": [-20, -35]            # New stat: motivation to improve
    },
    "duration": "permanent",            # Effect persists but can be countered
    "probability_modifiers": {
        # Not everyone gets complacent - personality matters
        "high_work_ethic": 0.3,         # 30% chance if already hard worker
        "low_work_ethic": 0.8,          # 80% chance if already lazy
        "veteran_leader_trait": 0.2,    # Leaders less likely to slack
        "me_first_trait": 0.9           # Selfish players very likely
    },
    "conditions": {
        "contract_value_vs_market": ">1.2",  # 120%+ of market value
        "guaranteed_money": ">$30M"          # Or large guarantees
    }
}
```

#### 3.4.3 Contract Year

**Trigger**: Player is in final year of contract (playing for next deal).

```gdscript
const CONTRACT_YEAR := {
    "event_type": "contract.contract_year",
    "stat_changes": {
        "work_ethic": [+5, +15],
        "focus": [+10, +20],
        "effort": [+10, +15],           # In-game effort stat
        "injury_risk": [+5, +10]        # Playing through pain = injury risk
    },
    "duration": "seasonal",
    "notes": "The 'contract year phenomenon' - players often have career years when playing for next deal"
}
```

#### 3.4.4 Franchise Tagged

**Trigger**: Team applies franchise tag instead of long-term deal.

```gdscript
const FRANCHISE_TAGGED := {
    "event_type": "contract.franchise_tag",
    "stat_changes": {
        # Depends heavily on player's reaction
        "work_ethic": [-10, +10],       # Wide range
        "discipline": [-15, +5],
        "focus": [-10, +5],
        "team_loyalty": [-20, -5]       # Almost always hurts loyalty
    },
    "duration": "seasonal",
    "personality_splits": {
        "team_first": {                 # Team players accept it
            "work_ethic": [+5, +10],
            "discipline": [0, +5]
        },
        "me_first": {                   # Selfish players resent it
            "work_ethic": [-15, -5],
            "discipline": [-20, -10],
            "holdout_chance": 0.4
        }
    }
}
```

#### 3.4.5 Took Pay Cut

**Trigger**: Player restructures or signs below market to stay with contender.

```gdscript
const TOOK_PAY_CUT := {
    "event_type": "contract.pay_cut",
    "stat_changes": {
        "team_loyalty": [+15, +25],
        "focus": [+5, +15],             # Focused on winning
        "composure": [+5, +10],         # Mature decision
        "work_ethic": [+5, +10]
    },
    "duration": "permanent",
    "triggers_trait": "team_first",     # Can earn this trait
    "conditions": {
        "team_playoff_contender": true,
        "salary_reduction": ">20%"
    }
}
```

### 3.5 Team/Roster Events (Detailed)

#### 3.5.1 Released/Cut

```gdscript
const RELEASED := {
    "event_type": "team.released",
    "stat_changes": {
        # Humbling experience - usually motivates
        "work_ethic": [+10, +25],
        "discipline": [+5, +15],
        "composure": [-10, +5],         # Can shake confidence or motivate
        "confidence": [-15, +10]
    },
    "duration": "seasonal",             # Chip on shoulder fades over time
    "decay_rate": 0.3,                  # Loses 30% per year
    "personality_splits": {
        "resilient": {
            "work_ethic": [+15, +25],
            "confidence": [+5, +10],
            "triggers_trait": "chip_on_shoulder"
        },
        "fragile": {
            "work_ethic": [0, +10],
            "confidence": [-20, -10],
            "composure": [-15, -5]
        }
    }
}
```

#### 3.5.2 Named Team Captain

```gdscript
const NAMED_CAPTAIN := {
    "event_type": "team.named_captain",
    "stat_changes": {
        "leadership": [+10, +20],       # New stat
        "composure": [+5, +15],
        "discipline": [+5, +10],
        "work_ethic": [+5, +10],
        "focus": [+5, +10]
    },
    "duration": "permanent",
    "triggers_trait": "leader",
    "team_effects": {
        # Captain can influence teammates
        "locker_room_presence": +15,
        "young_player_development": +0.1  # 10% boost to young players' growth
    }
}
```

#### 3.5.3 Traded

```gdscript
const TRADED := {
    "event_type": "team.traded",
    "stat_changes": {
        "focus": [-10, +10],            # Adjustment period
        "composure": [-5, +5],
        "discipline": [-5, +5]
    },
    "duration": "temporary",
    "years_remaining": 1,               # Adjustment period
    "context_modifiers": {
        "traded_to_contender": {
            "focus": [+5, +15],
            "work_ethic": [+5, +10]
        },
        "traded_to_rebuilder": {
            "focus": [-10, -5],
            "work_ethic": [-5, +5]
        },
        "requested_trade": {
            "focus": [+10, +15],        # Got what they wanted
            "discipline": [+5, +10]
        },
        "surprised_by_trade": {
            "composure": [-15, -5],
            "focus": [-15, -5]
        }
    }
}
```

#### 3.5.4 Team Drafts Replacement

```gdscript
const TEAM_DRAFTS_REPLACEMENT := {
    "event_type": "team.drafted_replacement",
    "stat_changes": {
        # Competition can motivate or demoralize
        "work_ethic": [-10, +20],
        "focus": [-5, +15],
        "composure": [-10, +5]
    },
    "duration": "seasonal",
    "personality_splits": {
        "competitive": {
            "work_ethic": [+10, +20],
            "focus": [+10, +15],
            "triggers_event": "mentor_or_compete"  # Player choice
        },
        "insecure": {
            "work_ethic": [-5, +5],
            "composure": [-15, -5],
            "confidence": [-20, -10]
        }
    },
    "conditions": {
        "draft_pick_round": [1, 3],     # High draft pick = bigger threat
        "same_position": true
    }
}
```

#### 3.5.5 Veteran Mentor Assigned

```gdscript
const VETERAN_MENTOR := {
    "event_type": "team.veteran_mentor",
    "stat_changes": {
        # Young player benefits
        "awareness": [+3, +8],
        "decision_making": [+3, +8],
        "discipline": [+5, +10],
        "coachability": [+5, +10],
        "development_rate": [+0.1, +0.2]  # 10-20% faster development
    },
    "duration": "seasonal",
    "conditions": {
        "mentee_age": "<25",
        "mentor_has_trait": ["leader", "veteran_presence", "high_football_iq"],
        "mentor_years_in_league": ">=8"
    },
    "mentor_effects": {
        # Mentor also benefits
        "leadership": [+3, +5],
        "legacy_score": [+5, +10]        # For Hall of Fame consideration
    }
}
```

### 3.6 Personal Life Events (Detailed)

#### 3.6.1 Marriage

```gdscript
const MARRIAGE := {
    "event_type": "personal.marriage",
    "stat_changes": {
        "discipline": [+5, +15],
        "composure": [+5, +10],
        "focus": [-5, +10],             # Honeymoon phase can distract
        "stability": [+10, +20]         # New hidden stat
    },
    "duration": "permanent",
    "first_year_modifier": {
        "focus": -5                     # Adjustment year
    }
}
```

#### 3.6.2 Divorce

```gdscript
const DIVORCE := {
    "event_type": "personal.divorce",
    "stat_changes": {
        "focus": [-20, -10],
        "composure": [-15, -5],
        "discipline": [-15, -5],
        "stability": [-25, -15]
    },
    "duration": "temporary",
    "years_remaining": 2,               # Takes time to recover
    "decay_rate": 0.4,                  # 40% recovery per year
    "risk_factors": {
        "financial_distraction": 0.3,   # 30% chance of money issues
        "off_field_trouble": 0.15       # 15% chance of incidents
    }
}
```

#### 3.6.3 New Child

```gdscript
const NEW_CHILD := {
    "event_type": "personal.new_child",
    "stat_changes": {
        "composure": [+5, +15],         # Maturity
        "discipline": [+5, +10],
        "focus": [-10, +5],             # Sleep deprivation vs motivation
        "work_ethic": [-5, +10]         # Depends on personality
    },
    "duration": "permanent",
    "personality_splits": {
        "family_first": {
            "composure": [+10, +15],
            "work_ethic": [+5, +10],    # Motivated to provide
            "focus": [+5, +10]
        },
        "career_focused": {
            "focus": [-10, -5],         # Distracted
            "discipline": [-5, 0]
        }
    }
}
```

#### 3.6.4 Off-Field Trouble

```gdscript
const OFF_FIELD_TROUBLE := {
    "event_type": "personal.off_field_trouble",
    "stat_changes": {
        "discipline": [-20, -10],
        "focus": [-15, -5],
        "composure": [-10, -5],
        "reputation": [-25, -10]        # New stat: affects contracts, endorsements
    },
    "duration": "permanent",            # Reputation sticks
    "severity_levels": {
        "minor": {                      # Bar fight, traffic incident
            "discipline": -10,
            "suspension_games": [0, 2]
        },
        "moderate": {                   # DUI, substance violation
            "discipline": -20,
            "suspension_games": [4, 8],
            "triggers_trait": "character_concern"
        },
        "severe": {                     # Felony, assault
            "discipline": -30,
            "suspension_games": [8, 17],
            "career_ending_chance": 0.1
        }
    },
    "recovery_path": {
        "community_service": {
            "reputation": [+5, +15],
            "discipline": [+5, +10]
        },
        "counseling_program": {
            "discipline": [+10, +20],
            "composure": [+5, +10]
        }
    }
}
```

#### 3.6.5 Found Religion/Purpose

```gdscript
const FOUND_PURPOSE := {
    "event_type": "personal.found_purpose",
    "stat_changes": {
        "discipline": [+10, +20],
        "composure": [+10, +15],
        "focus": [+5, +15],
        "work_ethic": [+5, +15],
        "stability": [+15, +25]
    },
    "duration": "permanent",
    "triggers_trait": "high_character",
    "conditions": {
        "prior_off_field_trouble": true,  # Often follows rock bottom
        "age_range": [24, 32]
    }
}
```

### 3.7 Performance Events (Detailed)

#### 3.7.1 Costly Mistake (Game-Losing Play)

```gdscript
const COSTLY_MISTAKE := {
    "event_type": "performance.costly_mistake",
    "stat_changes": {
        "composure": [-15, +5],         # Wide range - can break or build
        "confidence": [-20, -5],
        "focus": [-10, +10]
    },
    "duration": "temporary",
    "years_remaining": 1,
    "personality_splits": {
        "resilient": {
            "composure": [0, +5],
            "focus": [+5, +10],
            "work_ethic": [+10, +15],   # Uses it as motivation
            "triggers_trait": "clutch"   # Can develop clutch gene
        },
        "fragile": {
            "composure": [-20, -10],
            "confidence": [-25, -15],
            "triggers_trait": "chokes_in_big_moments"
        }
    },
    "examples": [
        "Interception in end zone with game on line",
        "Fumble inside 5 yard line",
        "Missed game-winning field goal",
        "Dropped sure touchdown"
    ]
}
```

#### 3.7.2 Injury Comeback

```gdscript
const INJURY_COMEBACK := {
    "event_type": "performance.injury_comeback",
    "stat_changes": {
        "composure": [-10, +15],
        "confidence": [-15, +10],
        "work_ethic": [+5, +15],        # Rehab builds discipline
        "discipline": [+5, +10]
    },
    "duration": "seasonal",
    "injury_severity_modifiers": {
        "minor": {
            "composure": [0, +5],
            "confidence": [0, +5]
        },
        "major": {                       # ACL, Achilles, etc.
            "composure": [-15, +10],
            "confidence": [-20, +5],
            "anxiety_chance": 0.25       # 25% chance of lingering doubt
        },
        "career_threatening": {
            "composure": [-20, +15],
            "confidence": [-25, +10],
            "work_ethic": [+15, +25],   # Survivors often have renewed drive
            "triggers_trait": "comeback_player"
        }
    }
}
```

#### 3.7.3 Super Bowl Loss

```gdscript
const SUPER_BOWL_LOSS := {
    "event_type": "performance.super_bowl_loss",
    "stat_changes": {
        "composure": [-10, +10],
        "focus": [+5, +20],             # Hunger to get back
        "work_ethic": [+5, +15],
        "legacy_anxiety": [+10, +25]    # Pressure to win one
    },
    "duration": "permanent",
    "personality_splits": {
        "motivated": {
            "focus": [+15, +20],
            "work_ethic": [+10, +15],
            "next_season_performance": +0.05  # 5% boost
        },
        "haunted": {
            "composure": [-15, -5],
            "focus": [-5, +5],
            "playoff_composure": -0.1   # 10% penalty in playoffs
        }
    }
}
```

### 3.8 Milestone Events (Detailed)

#### 3.8.1 First Pro Bowl Selection

```gdscript
const FIRST_PRO_BOWL := {
    "event_type": "milestone.first_pro_bowl",
    "stat_changes": {
        "confidence": [+10, +20],
        "composure": [+5, +10],
        "work_ethic": [-5, +10]         # Can motivate or satisfy
    },
    "duration": "permanent",
    "personality_splits": {
        "hungry": {
            "work_ethic": [+5, +10],    # Wants more
            "focus": [+5, +10]
        },
        "satisfied": {
            "work_ethic": [-10, -5],    # Got what they wanted
            "focus": [-5, 0]
        }
    }
}
```

#### 3.8.2 Won Championship

```gdscript
const WON_CHAMPIONSHIP := {
    "event_type": "milestone.championship",
    "stat_changes": {
        "composure": [+10, +20],
        "confidence": [+15, +25],
        "legacy_score": [+30, +50]
    },
    "duration": "permanent",
    "subsequent_effects": {
        "first_ring": {
            "work_ethic": [-10, +15],   # Wide range
            "hunger": [-20, +10]        # Some get complacent
        },
        "multiple_rings": {
            "work_ethic": [+5, +15],    # Dynasty mindset
            "focus": [+10, +15],
            "triggers_trait": "winner"
        }
    },
    "role_modifiers": {
        "key_contributor": {
            "confidence": [+20, +25],
            "legacy_score": [+40, +50]
        },
        "role_player": {
            "confidence": [+10, +15],
            "legacy_score": [+20, +30]
        }
    }
}
```

### 3.9 Event Processing System

```gdscript
## CareerEventProcessor.gd
class_name CareerEventProcessor

## Process all potential events for a player after a season
##
## RNG Consumption: Variable (1-5 calls depending on events triggered)
##
## Algorithm:
##   1. Check contract triggers (new deal, contract year, etc.)
##   2. Check roster triggers (traded, cut, captain, etc.)
##   3. Check performance triggers (awards, mistakes, comebacks)
##   4. Check personal triggers (based on personality + random chance)
##   5. Apply stat modifications
##   6. Store events in player history
##
## Returns: Array of CareerEvent dictionaries
static func process_season_events(
    player: Dictionary,
    season_context: Dictionary,  # Team results, player stats, contract changes
    rng: RandomNumberGenerator
) -> Array:
    var events := []

    # Contract events
    events.append_array(_check_contract_events(player, season_context, rng))

    # Team/roster events
    events.append_array(_check_team_events(player, season_context, rng))

    # Performance events
    events.append_array(_check_performance_events(player, season_context, rng))

    # Personal events (probabilistic based on personality)
    events.append_array(_check_personal_events(player, rng))

    # Milestone events
    events.append_array(_check_milestone_events(player, season_context))

    # Apply all stat changes
    for event in events:
        _apply_event_stat_changes(player, event, rng)

    # Store in player history
    var history: Array = player.get("career_events", [])
    history.append_array(events)
    player["career_events"] = history

    return events


## Apply stat changes from an event, respecting personality modifiers
static func _apply_event_stat_changes(
    player: Dictionary,
    event: Dictionary,
    rng: RandomNumberGenerator
) -> void:
    var stats: Dictionary = player.get("stats", {})
    var changes: Dictionary = event.get("stat_changes", {})
    var personality := _get_personality_type(player)

    for stat_name in changes.keys():
        var change_range = changes[stat_name]
        if change_range is Array and change_range.size() == 2:
            # Roll within range, modified by personality
            var base_change := rng.randf_range(
                float(change_range[0]),
                float(change_range[1])
            )

            # Personality modifiers
            base_change *= _get_personality_modifier(personality, stat_name, event)

            # Apply change
            if stats.has(stat_name):
                stats[stat_name] = clamp(
                    float(stats[stat_name]) + base_change,
                    0.0,
                    100.0
                )

    player["stats"] = stats
```

### 3.10 Personality System Integration

Events interact with a player's personality to determine outcomes:

```gdscript
## Personality archetypes that affect event responses
const PERSONALITY_TYPES := {
    "competitor": {
        "description": "Thrives on competition, uses adversity as fuel",
        "event_modifiers": {
            "contract.prove_it_deal": {"work_ethic": 1.5, "focus": 1.3},
            "team.drafted_replacement": {"work_ethic": 1.4},
            "performance.costly_mistake": {"work_ethic": 1.5, "composure": 1.2}
        },
        "base_traits": ["competitive", "resilient"]
    },
    "front_runner": {
        "description": "Performs when things are going well, struggles with adversity",
        "event_modifiers": {
            "contract.got_paid": {"work_ethic": 0.7},  # More likely to slack
            "team.released": {"composure": 0.6, "confidence": 0.5},
            "milestone.championship": {"work_ethic": 0.6}  # Gets complacent
        },
        "base_traits": ["confidence_dependent", "needs_validation"]
    },
    "steady_eddie": {
        "description": "Consistent, unaffected by external circumstances",
        "event_modifiers": {
            # All modifiers closer to 1.0 - less affected by events
            "contract.prove_it_deal": {"work_ethic": 0.8},
            "contract.got_paid": {"work_ethic": 0.8},
            "team.released": {"composure": 0.9}
        },
        "base_traits": ["consistent", "professional"]
    },
    "volatile": {
        "description": "Extreme reactions to events, unpredictable",
        "event_modifiers": {
            # Higher variance in both directions
            "contract.prove_it_deal": {"work_ethic": 1.8, "variance": 2.0},
            "contract.got_paid": {"work_ethic": 1.5, "variance": 2.0},
            "performance.costly_mistake": {"composure": 0.5, "variance": 2.0}
        },
        "base_traits": ["emotional", "unpredictable"]
    }
}
```

### 3.11 Configuration

Add to `main.json`:

```json
{
    "career_events": {
        "enabled": true,
        "event_probabilities": {
            "personal_events_per_year": 0.15,
            "off_field_trouble_base": 0.03,
            "found_purpose_after_trouble": 0.25
        },
        "stat_change_caps": {
            "single_event_max": 25,
            "cumulative_year_max": 40
        },
        "personality_distribution": {
            "competitor": 0.25,
            "front_runner": 0.20,
            "steady_eddie": 0.40,
            "volatile": 0.15
        },
        "contract_thresholds": {
            "prove_it_deal_market_ratio": 0.7,
            "got_paid_market_ratio": 1.2,
            "big_guaranteed_money": 30000000
        },
        "decay_rates": {
            "temporary_event_default": 0.4,
            "chip_on_shoulder": 0.3,
            "personal_crisis": 0.5
        }
    }
}
```

### 3.12 Event History Storage

```gdscript
## Player career_events array
player["career_events"] = [
    {
        "event_type": "contract.prove_it_deal",
        "year": 2025,
        "age": 28,
        "team_id": "DET",
        "stat_changes": {"work_ethic": +18, "focus": +12},
        "duration": "seasonal",
        "headline": "Jones signs one-year deal to prove doubters wrong"
    },
    {
        "event_type": "performance.career_game",
        "year": 2025,
        "age": 28,
        "team_id": "DET",
        "stat_changes": {"confidence": +15, "composure": +8},
        "headline": "Jones posts career-high 156 yards, 2 TDs"
    },
    {
        "event_type": "contract.got_paid",
        "year": 2026,
        "age": 29,
        "team_id": "DET",
        "stat_changes": {"work_ethic": -22, "discipline": -15},
        "duration": "permanent",
        "headline": "Jones signs 4-year, $72M extension"
    }
    # ... his work_ethic drops, becomes cautionary tale
]
```

---

## Integration: How Features Work Together

### Scenario: The "Hidden Gem" CB

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Career Timeline: Marcus Williams (CB)                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  DRAFT DAY (Age 22):                                                            │
│    Composite Rating: 68 (3rd round pick)                                        │
│    Hidden Development Type: "late_bloomer"                                      │
│    Hidden Traits: ["high_ceiling", "Ball Hawk"]                                 │
│    Stats: Speed 70, Coverage 65, Awareness 88, Anticipation 85                  │
│                                                                                 │
│  YEAR 1 (Age 23):                                                               │
│    Composite: 68 → 71 (slow growth, late bloomer penalty)                       │
│    Season Stats: 3 INTs (expected: 1.5 for his rating)                          │
│    Performance Grade: 78.5 (OVERPERFORMER - high awareness pays off)            │
│    → Contract: Rookie deal, no restructure                                      │
│                                                                                 │
│  YEAR 2 (Age 24):                                                               │
│    Composite: 71 → 74 (still growing slowly)                                    │
│    Season Stats: 5 INTs (expected: 2.0)                                         │
│    Performance Grade: 85.2 (ELITE - #8 CB in league)                            │
│    → Scouts notice: "Grade >> Rating, something special here"                   │
│                                                                                 │
│  YEAR 3 (Age 25) - BREAKTHROUGH YEAR:                                           │
│    Development Event: BREAKTHROUGH triggered!                                   │
│    Composite: 74 → 84 (+10 points! Late bloomer + breakthrough)                 │
│    Season Stats: 7 INTs (led league)                                            │
│    Performance Grade: 94.1 (ELITE - #1 CB)                                      │
│    Award: All-Pro First Team                                                    │
│    → Contract Extension: Top-5 CB money based on GRADE not prior composite      │
│                                                                                 │
│  YEAR 4+ (Age 26-30):                                                           │
│    Now recognized as elite                                                      │
│    Composite matches performance: 84-88 range                                   │
│    Consistent high grades                                                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Scenario: The "Bust" QB

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Career Timeline: Jake Morrison (QB)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  DRAFT DAY (Age 22):                                                            │
│    Composite Rating: 82 (1st round pick, 5th overall)                           │
│    Hidden Development Type: "early_peak"                                        │
│    Stats: Throw Power 90, Arm Talent 88, Decision Making 55, Composure 52       │
│    Scouts saw: Elite arm, projected franchise QB                                │
│                                                                                 │
│  YEAR 1 (Age 23):                                                               │
│    Composite: 82 → 83 (early peak - already near ceiling)                       │
│    Season Stats: 22 TDs, 18 INTs (expected: 25 TDs, 12 INTs for 82 rating)      │
│    Performance Grade: 58.2 (BELOW AVERAGE - decision making hurts)              │
│    → "He'll figure it out" - team hopeful                                       │
│                                                                                 │
│  YEAR 2 (Age 24) - PLATEAU:                                                     │
│    Development Event: PLATEAU triggered                                         │
│    Composite: 83 → 83.5 (minimal growth)                                        │
│    Season Stats: 19 TDs, 20 INTs                                                │
│    Performance Grade: 52.4 (POOR - turnover machine)                            │
│    → Contract: Team declines 5th year option                                    │
│                                                                                 │
│  YEAR 3 (Age 25):                                                               │
│    Composite: 83.5 → 82 (early decline starting)                                │
│    Performance Grade: 48.7                                                      │
│    → Released, signs with new team as backup                                    │
│                                                                                 │
│  RESULT: Elite arm talent but low decision_making/composure created             │
│          misleading composite. Performance grades told the real story.          │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Scenario: The "Prove-It to Got Paid" Arc (All Three Features)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Career Timeline: DeAndre Thompson (WR)                            │
│               Showing: Grades + Development + Career Events                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  DRAFT (Age 22):                                                                │
│    Composite: 72 (2nd round pick)                                               │
│    Development Type: "late_bloomer" (hidden)                                    │
│    Personality Type: "competitor" (hidden)                                      │
│    Work Ethic: 75, Discipline: 70, Focus: 68                                    │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 1-3 (Rookie Contract):                                                    │
│    Slow development (late bloomer college penalty)                              │
│    Composite: 72 → 73 → 75 (underwhelming)                                      │
│    Performance Grades: 62, 65, 68 (slightly overperforming)                     │
│    No major career events                                                       │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 4 (Age 25) - Contract Year:                                               │
│    EVENT: "contract.contract_year" triggered                                    │
│      → Work Ethic: 75 → 85 (+10)                                                │
│      → Focus: 68 → 80 (+12)                                                     │
│    Composite: 75 → 79 (late bloomer pro boost kicking in)                       │
│    Performance Grade: 78.5 (career high)                                        │
│    → Hits free agency with momentum                                             │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 5 (Age 26) - Prove-It Deal:                                               │
│    Signs 1-year, $8M deal (market value was $12M)                               │
│    EVENT: "contract.prove_it_deal" triggered                                    │
│      → Work Ethic: 85 → 98 (+13) [competitor personality = 1.5x boost]          │
│      → Focus: 80 → 92 (+12)                                                     │
│      → Discipline: 70 → 78 (+8)                                                 │
│    DEVELOPMENT EVENT: BREAKTHROUGH triggered! (late bloomer + age 26)           │
│    Composite: 79 → 88 (+9! Breakthrough year)                                   │
│    Performance Grade: 91.2 (Elite - #4 WR in league)                            │
│    Season Stats: 98 catches, 1,456 yards, 12 TDs                                │
│    EVENT: "milestone.first_pro_bowl" triggered                                  │
│      → Confidence: +15                                                          │
│      → (Personality: "competitor" → stays hungry, no work_ethic drop)           │
│    → Teams bidding war in free agency                                           │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 6 (Age 27) - Got Paid:                                                    │
│    Signs 4-year, $92M contract ($65M guaranteed)                                │
│    EVENT: "contract.got_paid" triggered                                         │
│      → Personality check: "competitor" = only 30% chance of complacency         │
│      → RNG roll: 0.45 > 0.30 → COMPLACENCY TRIGGERS                             │
│      → Work Ethic: 98 → 78 (-20)                                                │
│      → Discipline: 78 → 65 (-13)                                                │
│      → Focus: 92 → 82 (-10)                                                     │
│    Composite: 88 → 87 (slight regression, still in prime)                       │
│    Performance Grade: 72.4 (significant drop - underperforming rating)          │
│    Season Stats: 71 catches, 987 yards, 6 TDs                                   │
│    → Front office concerned, but locked into contract                           │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 7 (Age 28) - Wake-Up Call:                                                │
│    Team drafts WR in 1st round                                                  │
│    EVENT: "team.drafted_replacement" triggered                                  │
│      → Personality: "competitor" = motivated by competition                     │
│      → Work Ethic: 78 → 92 (+14) [competitor modifier]                          │
│      → Focus: 82 → 90 (+8)                                                      │
│    Composite: 87 → 89 (bounce back, still in prime window)                      │
│    Performance Grade: 85.1 (back to elite)                                      │
│    EVENT: "team.veteran_mentor" - mentors rookie                                │
│      → Leadership: +12                                                          │
│      → Legacy Score: +8                                                         │
│    → Proves he can coexist, earns captain nomination                            │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  SUMMARY:                                                                       │
│    - Late bloomer development → breakthrough at 26                              │
│    - Prove-it deal + competitor personality → career year                       │
│    - Got paid → even competitors can get complacent (30% chance hit)            │
│    - Competition from rookie → competitor personality saves career              │
│    - All three systems interacting to create realistic career arc               │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Scenario: The "Got His Bag" Cautionary Tale

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│               Career Timeline: Marcus Bell (CB)                                 │
│               Showing: How "Got Paid" Can Derail a Career                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  DRAFT (Age 22):                                                                │
│    Composite: 78 (1st round pick, 18th overall)                                 │
│    Development Type: "early_peak"                                               │
│    Personality Type: "front_runner"                                             │
│    Work Ethic: 62, Discipline: 55 (red flags scouts missed)                     │
│                                                                                 │
│  YEARS 1-4 (Rookie Contract):                                                   │
│    Strong early development (early_peak type)                                   │
│    Composite: 78 → 82 → 85 → 86                                                 │
│    Performance Grades: 75, 80, 84, 86 (living up to rating)                     │
│    All-Pro Second Team in Year 4                                                │
│    → Hits free agency as top CB on market                                       │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 5 (Age 26) - The Big Payday:                                              │
│    Signs 5-year, $110M contract ($78M guaranteed)                               │
│    EVENT: "contract.got_paid" triggered                                         │
│      → Personality check: "front_runner" + low work_ethic = 85% chance          │
│      → RNG roll: 0.32 < 0.85 → SEVERE COMPLACENCY                               │
│      → Work Ethic: 62 → 28 (-34) [front_runner amplifies drop]                  │
│      → Discipline: 55 → 25 (-30)                                                │
│      → Focus: 70 → 45 (-25)                                                     │
│    EVENT: "personal.off_field_trouble" (minor) - partying incident              │
│      → Discipline: 25 → 15 (-10)                                                │
│      → Reputation: -15                                                          │
│    DEVELOPMENT: Plateau triggered (early_peak + low work_ethic)                 │
│    Composite: 86 → 84 (regression despite being in "prime")                     │
│    Performance Grade: 58.2 (major underperformance)                             │
│    → "What happened to Marcus Bell?" headlines                                  │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 6 (Age 27):                                                               │
│    EVENT: "personal.off_field_trouble" (moderate) - DUI                         │
│      → Discipline: 15 → 0 (floored)                                             │
│      → 4-game suspension                                                        │
│      → Trait added: "character_concern"                                         │
│    Composite: 84 → 80 (rapid decline, early_peak + zero work_ethic)             │
│    Performance Grade: 45.1 (poor)                                               │
│    → Team tries to trade him, no takers at his salary                           │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 7 (Age 28) - Rock Bottom:                                                 │
│    EVENT: "team.released" - cut with dead cap hit                               │
│      → Personality: "front_runner" = fragile response                           │
│      → Confidence: -25                                                          │
│      → Work Ethic: 0 → 8 (+8) [small humility boost]                            │
│    Signs veteran minimum with new team                                          │
│    EVENT: "contract.prove_it_deal" triggered                                    │
│      → Work Ethic: 8 → 18 (+10)                                                 │
│      → Focus: 45 → 55 (+10)                                                     │
│      [front_runner personality = reduced prove-it boost]                        │
│    Composite: 80 → 76 (still declining, damage done)                            │
│    Performance Grade: 52.4                                                      │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  YEAR 8 (Age 29) - Possible Redemption?:                                        │
│    EVENT: "personal.found_purpose" triggered (rock bottom → change)             │
│      → Discipline: 0 → 18 (+18)                                                 │
│      → Work Ethic: 18 → 35 (+17)                                                │
│      → Stability: +20                                                           │
│      → Trait added: "high_character" (redemption arc)                           │
│    Composite: 76 → 74 (still declining, but slower)                             │
│    Performance Grade: 61.2 (respectable for diminished player)                  │
│    → Becomes valuable veteran mentor despite reduced ability                    │
│                                                                                 │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                 │
│  SUMMARY:                                                                       │
│    - Early peak development = front-loaded career                               │
│    - Front_runner personality + low base work_ethic = high complacency risk     │
│    - $110M contract triggered catastrophic motivation collapse                  │
│    - Cascading events: got_paid → off_field_trouble → released                  │
│    - Partial redemption through found_purpose event                             │
│    - Cautionary tale: scouting personality matters as much as measurables       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation (Recommended First)

1. **PerformanceGrader.gd** - Core grading algorithm
   - Position-specific grade calculation
   - Expected vs actual production formulas
   - Grade storage in world_state

2. **DevelopmentProfile generation** - At player creation
   - Development type assignment
   - Hidden modifier generation
   - Profile storage on player

### Phase 2: Integration

1. **Modify PlayerLifecycle.gd** - Apply development profiles
   - Use growth_rate_modifier
   - Implement breakthrough/plateau events
   - Track development_events

2. **Update NflSeason.gd** - Call grading at end of season
   - Grade all players post-simulation
   - Store grades in world_state

### Phase 3: Career Events

1. **CareerEventProcessor.gd** - Event detection and processing
   - Contract event triggers (prove-it, got-paid, contract year)
   - Team event triggers (traded, released, captain)
   - Performance event triggers (costly mistakes, comebacks)
   - Personal event probabilities

2. **CareerEventDefinitions.gd** - Event configuration
   - Stat change ranges per event type
   - Personality modifiers
   - Duration and decay settings

3. **Personality system** - At player creation
   - Assign personality type (competitor, front_runner, steady_eddie, volatile)
   - Store on player for event processing

### Phase 4: Downstream Systems

1. **PlayerValue.gd** - Factor grades into valuation
2. **Scouting** - Reveal partial development profile and personality info
3. **Contract negotiation** - Use grades for restructuring, trigger contract events
4. **UI** - Display grades, career events timeline, personality indicators

---

## Testing Requirements

### Determinism Tests

```gdscript
## Test that grading produces identical results with same inputs
func test_grading_determinism():
    var player := create_test_player()
    var stats := create_test_season_stats()

    var grade_1 := PerformanceGrader.calculate_season_grade(player, stats, cfg, main)
    var grade_2 := PerformanceGrader.calculate_season_grade(player, stats, cfg, main)

    assert_eq(grade_1["overall_grade"], grade_2["overall_grade"])

## Test development profile determinism with seed
func test_development_profile_determinism():
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    var player := create_test_player()

    var profile_1 := generate_development_profile(player, rng)

    rng.seed = 12345  # Reset
    var profile_2 := generate_development_profile(player, rng)

    assert_eq(profile_1["development_type"], profile_2["development_type"])
```

### Distribution Tests

```gdscript
## Test that development types follow expected distribution
func test_development_type_distribution():
    var counts := {"steady": 0, "late_bloomer": 0, "early_peak": 0, "erratic": 0}
    var rng := RandomNumberGenerator.new()
    rng.seed = 42

    for i in range(1000):
        var profile := generate_development_profile({}, rng)
        counts[profile["development_type"]] += 1

    # Steady should be most common (~50%)
    assert_gt(counts["steady"], 400)
    assert_lt(counts["steady"], 600)
```

### Scenario Tests

```gdscript
## Test late bloomer trajectory
func test_late_bloomer_trajectory():
    var player := create_late_bloomer_player()
    var ratings_by_age := []

    for age in range(22, 32):
        player["age"] = age
        PlayerLifecycle.advance_one_year(player, ...)
        ratings_by_age.append(calculate_composite(player))

    # Late bloomer should have bigger improvement in later years
    var college_growth := ratings_by_age[3] - ratings_by_age[0]  # Age 22-25
    var pro_growth := ratings_by_age[7] - ratings_by_age[3]      # Age 25-29

    assert_gt(pro_growth, college_growth * 1.3)  # Pro growth > college growth
```

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `scripts/core/grading/PerformanceGrader.gd` | Grade calculation engine |
| `scripts/core/events/CareerEventProcessor.gd` | Career event detection and processing |
| `scripts/core/events/CareerEventDefinitions.gd` | Event type definitions and stat changes |
| `scripts/support/config/GradingConfig.gd` | Config helper for grading |
| `scripts/support/config/CareerEventConfig.gd` | Config helper for career events |
| `configs/sports/american_football/grading.json` | Grading configuration |
| `configs/sports/american_football/career_events.json` | Career event configuration |
| `scripts/tests/test_performance_grading.gd` | Grading tests |
| `scripts/tests/test_development_profiles.gd` | Development profile tests |
| `scripts/tests/test_career_events.gd` | Career event tests |

### Modified Files

| File | Changes |
|------|---------|
| `scripts/core/models/Player.gd` | Add `development_profile`, `career_grades`, `career_events`, `personality_type` |
| `scripts/world/PlayerLifecycle.gd` | Apply development profile modifiers, decay temporary events |
| `scripts/generation/PlayerGenerator.gd` | Generate development profiles and personality types |
| `scripts/world/NflSeason.gd` | Call grading and event processing at end of season |
| `scripts/core/contracts/ContractNegotiator.gd` | Trigger contract events (prove-it, got-paid, etc.) |
| `configs/sports/american_football/main.json` | Add development and career_events config |

---

## Architectural Principles Followed

- **Deterministic when seeded**: All RNG usage is explicit and reproducible
- **Data-driven**: Weights, thresholds, and formulas in config files
- **Explicit over implicit**: Development profiles stored on player, not computed on-the-fly
- **Serialization parity**: All new fields have to_dict/from_dict support
- **No premature abstraction**: Start with position-specific formulas, generalize later if needed
- **Lifecycle clarity**: Development events tracked with age and type

---

## Open Questions (for discussion)

### Performance Grades
1. **Grade visibility in College**: Should college players also get performance grades, or NFL only?
2. **Historical grades**: Store full grade history or just recent N years?
3. **Grade decay**: Do old grades matter for evaluation, or just recent performance?

### Development Profiles
4. **Scouting cost**: How much scouting effort to reveal development type predictions?
5. **Breakthrough frequency**: Is 2-15% per year the right range, or should it be rarer?

### Career Events
6. **Event frequency cap**: Should there be a maximum number of events per season per player?
7. **Cascading events**: Can one event trigger another (e.g., divorce → off-field trouble)?
8. **Event visibility**: Which events are public vs private (team-only knowledge)?
9. **Recovery mechanics**: How do players recover from negative events over time?
10. **Personality stability**: Can personality type change over career, or is it fixed?
11. **Contract event thresholds**: What dollar amounts define "prove-it" vs "got paid"?
12. **Team-wide events**: Should events like "locker room drama" affect multiple players?
13. **Agent influence**: Should player agents affect contract event outcomes?
