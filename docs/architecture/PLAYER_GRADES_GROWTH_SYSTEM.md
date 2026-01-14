# Player Grades and Growth System Architecture

## Overview

This document outlines the architectural design for two interconnected features:
1. **PFF-Style Performance Grades** - Post-season performance evaluation system
2. **Non-Linear Player Growth** - Variable, unpredictable player development paths

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

### Phase 3: Downstream Systems

1. **PlayerValue.gd** - Factor grades into valuation
2. **Scouting** - Reveal partial development profile info
3. **Contract negotiation** - Use grades for restructuring logic
4. **UI** - Display grades alongside ratings

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
| `scripts/support/config/GradingConfig.gd` | Config helper for grading |
| `configs/sports/american_football/grading.json` | Grading configuration |
| `scripts/tests/test_performance_grading.gd` | Grading tests |
| `scripts/tests/test_development_profiles.gd` | Development profile tests |

### Modified Files

| File | Changes |
|------|---------|
| `scripts/core/models/Player.gd` | Add `development_profile` and `career_grades` |
| `scripts/world/PlayerLifecycle.gd` | Apply development profile modifiers |
| `scripts/generation/PlayerGenerator.gd` | Generate development profiles |
| `scripts/world/NflSeason.gd` | Call grading at end of season |
| `configs/sports/american_football/main.json` | Add development config |

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

1. **Grade visibility in College**: Should college players also get performance grades, or NFL only?
2. **Historical grades**: Store full grade history or just recent N years?
3. **Grade decay**: Do old grades matter for evaluation, or just recent performance?
4. **Scouting cost**: How much scouting effort to reveal development type predictions?
5. **Breakthrough frequency**: Is 2-15% per year the right range, or should it be rarer?
