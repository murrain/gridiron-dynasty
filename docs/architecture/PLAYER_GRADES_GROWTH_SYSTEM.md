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

### 1.9 College Performance Grades

College grades serve a different purpose than NFL grades - they help scouts evaluate draft prospects beyond just their composite rating and combine numbers.

#### 1.9.1 Design Goals for College Grades

| Goal | Description |
|------|-------------|
| **Draft Evaluation** | Scouts can identify players who consistently outperform their measurables |
| **Production Trends** | Track year-over-year grade improvement/regression through college |
| **Competition Context** | Adjust grades based on conference strength (SEC vs MAC) |
| **Projection Tool** | Help predict which college performers will translate to NFL |
| **Bust Detection** | Identify players whose production relies on weak competition |

#### 1.9.2 College Grade Differences from NFL

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    College vs NFL Performance Grades                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ASPECT              COLLEGE                         NFL                        │
│  ─────────────────   ─────────────────────────────   ─────────────────────────  │
│  Visibility          Partial - requires scouting     Fully public               │
│  Comparison Pool     Within conference tier          League-wide                │
│  Games Sampled       May not have full game film     All games graded           │
│  Competition Adj     Heavy (SEC vs FCS matters)      None needed                │
│  Scheme Inflation    Accounts for system players     Less relevant              │
│  Sample Size         12 games/year                   17 games/year              │
│  Grade Confidence    Lower (more variance)           Higher (more data)         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 1.9.3 College Grade Schema

```gdscript
## CollegeSeasonGrade Schema (stored per player per year)
{
    "player_id": String,
    "year": int,                        # College year (freshman=1, etc.)
    "school_id": String,
    "conference": String,
    "position": String,

    # Raw grade (before adjustments)
    "raw_grade": float,                 # 0-100, based on pure production

    # Adjusted grade (accounts for competition)
    "adjusted_grade": float,            # 0-100, normalized for competition level
    "competition_adjustment": float,    # Multiplier applied (0.8 - 1.2)

    # Grade components (position-specific)
    "component_grades": {
        # Example for WR:
        "route_running_grade": float,
        "catch_grade": float,
        "yards_after_catch_grade": float,
        "contested_catch_grade": float
    },

    # Context for scouts
    "games_graded": int,
    "snaps_graded": int,
    "starter_status": bool,
    "scheme_type": String,              # "spread", "pro_style", "run_heavy", etc.

    # Trend data (valuable for projecting development)
    "grade_trend": String,              # "improving", "steady", "declining"
    "year_over_year_delta": float,      # Grade change from previous year

    # Scouting confidence
    "grade_confidence": float,          # 0.5-1.0 based on sample size, game quality
    "film_reviewed_pct": float,         # How much film scouts actually watched

    # Comparison rankings
    "conference_rank": int,             # Rank within conference at position
    "national_rank": int,               # Rank nationally at position
    "class_percentile": float           # Percentile within draft class
}
```

#### 1.9.4 Competition Level Adjustments

```gdscript
## Conference tier multipliers for grade adjustment
const CONFERENCE_GRADE_ADJUSTMENTS := {
    # Power conferences (tougher competition = grades mean more)
    "SEC": 1.15,
    "Big Ten": 1.12,
    "Big 12": 1.08,
    "ACC": 1.05,
    "Pac-12": 1.05,

    # Group of 5 (easier competition = grades discounted)
    "AAC": 0.95,
    "Mountain West": 0.92,
    "Sun Belt": 0.88,
    "MAC": 0.85,
    "Conference USA": 0.85,

    # FCS (heavily discounted)
    "FCS": 0.70,
    "D2": 0.55,
    "D3": 0.45
}

## Opponent-specific adjustment (per game)
## Playing against top-25 team = grade boost
## Playing against FCS = grade penalty
func _adjust_for_opponent(raw_grade: float, opponent_tier: String) -> float:
    var multiplier := 1.0
    match opponent_tier:
        "top_10": multiplier = 1.20
        "top_25": multiplier = 1.10
        "ranked": multiplier = 1.05
        "power_conf": multiplier = 1.00
        "group_of_5": multiplier = 0.95
        "fcs": multiplier = 0.80
    return raw_grade * multiplier
```

#### 1.9.5 Draft Evaluation Integration

```gdscript
## How college grades influence draft evaluation
func evaluate_prospect_grades(player: Dictionary) -> Dictionary:
    var college_grades: Array = player.get("college_grades", [])

    if college_grades.is_empty():
        return {"grade_evaluation": "no_data"}

    # Get trend over college career
    var trend := _calculate_grade_trend(college_grades)

    # Compare final grade to composite rating
    var final_grade := float(college_grades[-1]["adjusted_grade"])
    var composite := _get_composite_rating(player)
    var production_delta := final_grade - composite

    # Key insights for scouts
    return {
        "final_college_grade": final_grade,
        "grade_trend": trend,  # "rising_star", "steady", "declining", "inconsistent"
        "production_vs_rating": production_delta,
        "overproducer": production_delta > 10.0,
        "underproducer": production_delta < -10.0,
        "conference_context": college_grades[-1]["conference"],
        "competition_adjusted": true,

        # Red flags
        "red_flags": _identify_grade_red_flags(college_grades),

        # Projection confidence
        "nfl_projection_confidence": _calculate_projection_confidence(college_grades)
    }

## Identify concerning patterns in college grades
func _identify_grade_red_flags(grades: Array) -> Array:
    var flags := []

    # Declining grades = concerning
    if grades.size() >= 2:
        var latest := float(grades[-1]["adjusted_grade"])
        var previous := float(grades[-2]["adjusted_grade"])
        if latest < previous - 5.0:
            flags.append("declining_production")

    # High raw grade but low adjusted = weak competition
    var latest_grade := grades[-1]
    var raw := float(latest_grade["raw_grade"])
    var adjusted := float(latest_grade["adjusted_grade"])
    if raw - adjusted > 10.0:
        flags.append("inflated_by_weak_competition")

    # Low game sample
    if int(latest_grade["games_graded"]) < 8:
        flags.append("limited_sample_size")

    # Inconsistent grades across years
    if _calculate_grade_variance(grades) > 15.0:
        flags.append("inconsistent_performance")

    return flags
```

#### 1.9.6 Grade Visibility and Scouting

Unlike NFL grades which are fully public, college grades require scouting effort to reveal:

```gdscript
## College grade scouting tiers
const COLLEGE_GRADE_SCOUTING := {
    # Free information (public)
    "public": [
        "national_rank",           # Mock draft rankings
        "conference_rank",         # All-conference teams
        "starter_status"           # Depth chart position
    ],

    # Basic scouting (low effort)
    "basic_scout": [
        "raw_grade",               # Pure production numbers
        "games_graded",
        "grade_trend"              # General direction
    ],

    # Detailed scouting (medium effort)
    "detailed_scout": [
        "adjusted_grade",          # Competition-adjusted
        "competition_adjustment",
        "component_grades",        # Position-specific breakdowns
        "scheme_type"
    ],

    # Deep dive (high effort, limited capacity)
    "deep_scout": [
        "year_over_year_delta",
        "film_reviewed_pct",       # Your scouts' actual coverage
        "grade_confidence",
        "red_flags",               # Identified concerns
        "nfl_projection_confidence"
    ]
}
```

#### 1.9.7 College to NFL Grade Translation

Not all college production translates to the NFL. The system tracks historical translation rates:

```gdscript
## Translation factors by position
const COLLEGE_TO_NFL_TRANSLATION := {
    # Positions that translate well
    "EDGE": {
        "translation_rate": 0.85,
        "description": "Pass rush production translates well"
    },
    "OL": {
        "translation_rate": 0.80,
        "description": "Technique matters, athleticism secondary"
    },

    # Positions with moderate translation
    "QB": {
        "translation_rate": 0.65,
        "description": "System QBs often struggle, arm talent matters"
    },
    "WR": {
        "translation_rate": 0.60,
        "description": "Speed and separation translate, scheme production doesn't"
    },

    # Positions with poor translation
    "RB": {
        "translation_rate": 0.50,
        "description": "College production rarely predicts NFL success"
    },
    "CB": {
        "translation_rate": 0.55,
        "description": "Competition level matters hugely"
    }
}

## Calculate expected NFL grade based on college performance
func project_nfl_grade(college_grade: float, position: String, conference: String) -> Dictionary:
    var translation := COLLEGE_TO_NFL_TRANSLATION.get(position, {"translation_rate": 0.65})
    var conf_adj := CONFERENCE_GRADE_ADJUSTMENTS.get(conference, 1.0)

    # Base projection
    var projected := college_grade * float(translation["translation_rate"]) * conf_adj

    # Add uncertainty range (wider for low-translation positions)
    var uncertainty := (1.0 - float(translation["translation_rate"])) * 15.0

    return {
        "projected_nfl_grade": projected,
        "confidence_range": [projected - uncertainty, projected + uncertainty],
        "translation_note": translation["description"]
    }
```

#### 1.9.8 Integration with CollegeSeason.gd

```gdscript
## CollegeSeason.gd modification
func run(...) -> Dictionary:
    # ... existing season simulation ...

    # After season simulation, grade all players
    if not options.get("skip_grading", false):
        var grading_result := PerformanceGrader.grade_college_season(
            world_state,
            year,
            positions_cfg,
            main_cfg
        )

        # Store grades
        _store_college_grades(world_state, year, grading_result)

    return result
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
    "breakthrough_chance": float,      # 0.03 - 0.10 (chance of sudden improvement, ~5% base)
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
        "breakthrough_chance": 0.04,   # Below average breakthrough chance
        "plateau_chance": 0.08,        # Low plateau chance
        "college_growth_mult": 1.0,
        "pro_growth_mult": 1.0
    },
    "late_bloomer": {
        "description": "Slow early development, rapid improvement in prime years",
        "growth_variance": 0.2,
        "breakthrough_chance": 0.10,   # Higher breakthrough chance (the whole point)
        "plateau_chance": 0.05,        # Low plateau (they just haven't peaked)
        "college_growth_mult": 0.7,    # Grows slowly in college
        "pro_growth_mult": 1.4,        # Flourishes in pros
        "bloom_age_range": [24, 27]    # When breakthrough likely happens
    },
    "early_peak": {
        "description": "Reaches ceiling quickly, minimal improvement after",
        "growth_variance": 0.15,
        "breakthrough_chance": 0.02,   # Very low - already peaked
        "plateau_chance": 0.25,        # High plateau chance
        "college_growth_mult": 1.3,    # Grows fast in college
        "pro_growth_mult": 0.6,        # Slows down in pros
        "peak_age_offset": -2          # Peaks earlier than position average
    },
    "erratic": {
        "description": "Unpredictable swings in performance and development",
        "growth_variance": 0.4,        # High variance
        "breakthrough_chance": 0.07,   # Moderate - could go either way
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

### 3.2 Personality Stats for Event System

The stat-driven event system uses mental stats to determine how players respond to career events. Most required stats **already exist** in the base player template (see PLAYER_GENERATION_REWORK.md Section 3.3). We add only two new stats to complete the system.

#### 3.2.1 Existing Stats (from Base Template)

These stats are already defined in the base player template and drive event responses:

| Stat | Description | Event Role |
|------|-------------|------------|
| `work_ethic` | Effort put into improvement | Development rate, recovery speed, response to competition |
| `discipline` | Self-control, adherence to routines | Response to money/success, off-field behavior |
| `composure` | Ability to stay calm under pressure | Response to negative events, clutch performance |
| `maturity` | Emotional intelligence, perspective | Response to personal events, decision making |
| `coachability` | Responsiveness to coaching | Learning rate, scheme adaptation |
| `adaptability` | Ability to adjust to new situations | Response to trades, coaching changes |
| `focus` | Mental concentration ability | In-season performance consistency |

#### 3.2.2 New Stats for Event System

Only **two new stats** are added specifically for the career event system:

```gdscript
## New personality stats for event system (add to base_player template)
const NEW_EVENT_STATS := {
    "competitiveness": {
        "mu": 50, "sigma": 12,
        "floor": 35,  # Non-competitive players don't pursue NFL careers
        "description": "Drive to win, response to competition and challenges",
        "affects": ["response to prove-it deals", "response to being replaced", "clutch moments"],
        "examples": {
            "high": "Michael Jordan - used any slight as motivation",
            "low": "Coasts when comfortable, satisfied with 'good enough'"
        }
    },
    "confidence": {
        "mu": 50, "sigma": 16,  # Wide variance - imposter syndrome to extreme cockiness
        "description": "Self-belief, how they view their own abilities",
        "affects": ["response to failure", "recovery from mistakes", "handling criticism"],
        "volatility": "Can swing significantly based on recent performance and events"
    }
}
```

#### 3.2.3 Why Only Two New Stats?

Adding more stats (ambition, responsibility, team_loyalty) was considered but **deferred** to avoid premature complexity:

1. **Existing stats cover most scenarios** - `work_ethic`, `discipline`, `composure`, and `maturity` handle 80% of event responses
2. **Competitiveness fills the key gap** - captures "chip on shoulder" and "prove doubters wrong" mentality
3. **Confidence enables volatility** - allows for players whose self-belief swings based on circumstances
4. **Simpler = testable** - fewer stats means easier to validate and tune the system

**Future consideration**: If specific event types require nuance that existing stats can't capture, additional stats can be added in a targeted way.

#### 3.2.4 Stat Interactions

These stats often work together to determine outcomes:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Stat Clusters for Common Scenarios                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  "Handles Money Well"          "Responds to Adversity"    "Clutch Performer"     │
│  ───────────────────           ──────────────────────     ─────────────────      │
│  discipline (primary)          composure (primary)        composure (primary)    │
│  work_ethic                    work_ethic                 confidence             │
│  maturity                      competitiveness            competitiveness        │
│                                confidence                                        │
│                                                                                  │
│  "Driven to Improve"           "Self-Motivated"           "Coachable"            │
│  ────────────────              ───────────────            ───────────            │
│  work_ethic (primary)          competitiveness (primary)  coachability           │
│  competitiveness               work_ethic                 discipline             │
│  discipline                    discipline                 maturity               │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 3.2.5 Stat Correlations

Mental stats have correlations (not fully independent). These should be applied during player generation:

```gdscript
## Personality stat correlations for generation
const STAT_CORRELATIONS := {
    # High work_ethic tends to correlate with discipline
    ["work_ethic", "discipline"]: 0.6,

    # High competitiveness correlates with confidence
    ["competitiveness", "confidence"]: 0.3,

    # Maturity correlates with composure
    ["maturity", "composure"]: 0.4,

    # Discipline correlates with focus
    ["discipline", "focus"]: 0.5,

    # Confidence and work_ethic are more independent
    # (can be confident but lazy, or hardworking but insecure)
    ["confidence", "work_ethic"]: 0.1
}
```

Note: The new stats (`competitiveness`, `confidence`) should be added to the base player template defined in PLAYER_GENERATION_REWORK.md Section 3.3.

### 3.3 Event Categories

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

### 3.4 Data Model: CareerEvent

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

### 3.5 Generalized Event Response System

Rather than hardcoding probability modifiers per event, player reactions are driven by their stats. Events define a range of possible outcomes, and the player's current stats determine where they land in that range.

#### 3.4.1 Core Philosophy

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Stat-Driven Event Response                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  EVENT: "Got Paid" (big contract)                                                │
│                                                                                  │
│  Potential work_ethic change: [-35 ←────────────────────────────────→ +5]        │
│                                                                                  │
│  Where you land depends on YOUR stats:                                           │
│                                                                                  │
│    Low discipline (30)  ────→  lands around -25 to -35                           │
│    Average (50)         ────→  lands around -10 to -20                           │
│    High discipline (80) ────→  lands around -5 to +5                             │
│                                                                                  │
│  Same event, different outcomes based on who the player IS                       │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 3.4.2 Event Response Calculation

```gdscript
## Calculate where a player lands in an event's outcome range
## based on their current stats
static func calculate_event_outcome(
    player: Dictionary,
    event: Dictionary,
    stat_name: String,
    rng: RandomNumberGenerator
) -> float:
    var stats: Dictionary = player.get("stats", {})
    var change_config: Dictionary = event["stat_changes"][stat_name]

    var range_min: float = change_config["range"][0]
    var range_max: float = change_config["range"][1]
    var range_size: float = range_max - range_min

    # Calculate player's "resistance" to negative outcomes
    # based on relevant stats for this type of change
    var relevant_stats: Array = change_config.get("relevant_stats", ["discipline", "composure", "maturity"])
    var resistance := 0.0

    for relevant_stat in relevant_stats:
        var stat_value := float(stats.get(relevant_stat, 50.0))
        resistance += (stat_value - 50.0) / 50.0  # -1.0 to +1.0 per stat

    resistance = resistance / relevant_stats.size()  # Average

    # Map resistance to position in range
    # resistance of -1.0 → bottom of range (worst outcome)
    # resistance of +1.0 → top of range (best outcome)
    var base_position := (resistance + 1.0) / 2.0  # 0.0 to 1.0

    # Add randomness (±20% variance)
    var variance := rng.randf_range(-0.2, 0.2)
    var final_position := clamp(base_position + variance, 0.0, 1.0)

    # Calculate actual change
    return range_min + (range_size * final_position)
```

#### 3.4.3 Event Definition Format

Events now define outcome ranges and which stats influence the response:

```gdscript
## Simplified event schema - stats drive outcomes
const EVENT_SCHEMA := {
    "event_type": String,
    "stat_changes": {
        "stat_name": {
            "range": [min_change, max_change],
            "relevant_stats": Array,  # Stats that determine where in range player lands
            "direction": String       # "positive" events vs "negative" events
        }
    },
    "duration": String,
    "conditions": Dictionary
}
```

### 3.6 Contract Events

#### 3.5.1 Prove-It Deal

**Trigger**: Team believes player COULD be great, but instead of committing to a long-term deal at that projected value, offers ~90% of value for 1 year with incentives. The player gets the opportunity to prove they can hit that performance level.

**Key distinction**: This is NOT about a player being "washed" or below market - it's about a team seeing upside but wanting proof before committing long-term. Common scenarios:
- Young player with flashes of brilliance but inconsistency
- Player changing teams/schemes who needs to show he fits
- Coming off injury but expected to return to form
- Breakout candidate the team believes in

```gdscript
const PROVE_IT_DEAL := {
    "event_type": "contract.prove_it_deal",
    "stat_changes": {
        "work_ethic": {
            "range": [+5, +25],         # Positive event - but how much depends on player
            "relevant_stats": ["work_ethic", "competitiveness", "discipline"],
            "direction": "positive"
        },
        "focus": {
            "range": [0, +20],
            "relevant_stats": ["focus", "discipline"],
            "direction": "positive"
        },
        "discipline": {
            "range": [0, +15],
            "relevant_stats": ["discipline", "maturity"],
            "direction": "positive"
        },
        "composure": {
            "range": [-10, +10],        # Pressure affects people differently
            "relevant_stats": ["composure", "confidence"],
            "direction": "neutral"
        }
    },
    "duration": "seasonal",
    "conditions": {
        "contract_years": 1,
        "contract_value_vs_projected": "~0.90",
        "has_incentives": true,
        "team_believes_upside": true
    }
}

## Example: A player with high competitiveness (85) and work_ethic (75)
## gets a bigger boost from prove-it deal than someone with low stats
## because they're wired to respond to the challenge
```

#### 3.5.2 Got Paid (Big Contract)

**Trigger**: Player signs contract significantly above market value or receives massive guaranteed money.

```gdscript
const GOT_PAID := {
    "event_type": "contract.got_paid",
    "stat_changes": {
        "work_ethic": {
            "range": [-35, +5],         # Wide range - most negative, but disciplined players resist
            "relevant_stats": ["discipline", "work_ethic", "maturity"],
            "direction": "negative"
        },
        "discipline": {
            "range": [-25, +5],
            "relevant_stats": ["discipline", "composure"],
            "direction": "negative"
        },
        "focus": {
            "range": [-20, +5],
            "relevant_stats": ["focus", "discipline", "work_ethic"],
            "direction": "negative"
        },
        "hunger": {
            "range": [-40, 0],          # Always decreases somewhat, question is how much
            "relevant_stats": ["work_ethic", "competitiveness"],
            "direction": "negative"
        }
    },
    "duration": "permanent",
    "conditions": {
        "contract_value_vs_market": ">1.2",
        "guaranteed_money": ">$30M"
    }
}

## Example outcomes for different players:
##
## Nick Bosa (discipline: 85, work_ethic: 90, maturity: 80):
##   - Resistance: high (~0.7)
##   - work_ethic change: likely +0 to -5 (barely affected)
##   - Stays elite
##
## Brandon Aiyuk (discipline: 55, work_ethic: 65, maturity: 50):
##   - Resistance: low (~0.1)
##   - work_ethic change: likely -20 to -30
##   - Falls off significantly
##
## Same event, stats determine outcome
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

#### 3.5.4 Franchise Tagged

**Trigger**: Team applies franchise tag instead of long-term deal.

```gdscript
const FRANCHISE_TAGGED := {
    "event_type": "contract.franchise_tag",
    "stat_changes": {
        "work_ethic": {
            "range": [-15, +15],        # Wide range - team players accept, selfish resent
            "relevant_stats": ["team_loyalty", "maturity", "discipline"],
            "direction": "neutral"
        },
        "discipline": {
            "range": [-20, +10],
            "relevant_stats": ["discipline", "composure", "maturity"],
            "direction": "neutral"
        },
        "focus": {
            "range": [-15, +10],
            "relevant_stats": ["focus", "professionalism"],
            "direction": "neutral"
        },
        "team_loyalty": {
            "range": [-25, -5],         # Almost always hurts loyalty
            "relevant_stats": ["team_loyalty", "maturity"],
            "direction": "negative"
        }
    },
    "duration": "seasonal"
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

### 3.7 Team/Roster Events

#### 3.6.1 Released/Cut

```gdscript
const RELEASED := {
    "event_type": "team.released",
    "stat_changes": {
        "work_ethic": {
            "range": [-5, +30],         # Most get motivated, fragile players may crumble
            "relevant_stats": ["composure", "work_ethic", "confidence"],
            "direction": "positive"     # Generally a motivating event
        },
        "discipline": {
            "range": [0, +20],
            "relevant_stats": ["discipline", "maturity"],
            "direction": "positive"
        },
        "composure": {
            "range": [-20, +10],        # Wide range - tests mental fortitude
            "relevant_stats": ["composure", "confidence", "maturity"],
            "direction": "neutral"
        },
        "confidence": {
            "range": [-25, +15],        # Can break you or fuel you
            "relevant_stats": ["confidence", "composure", "work_ethic"],
            "direction": "neutral"
        }
    },
    "duration": "seasonal",
    "decay_rate": 0.3
}

## Low composure + low confidence player: lands at bottom of ranges
##   → confidence tanks, composure drops, minimal work_ethic boost
## High composure + high work_ethic player: lands at top of ranges
##   → confidence boost, composure maintained, big chip on shoulder
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

#### 3.6.3 Traded

```gdscript
const TRADED := {
    "event_type": "team.traded",
    "stat_changes": {
        "focus": {
            "range": [-15, +15],
            "relevant_stats": ["adaptability", "composure", "maturity"],
            "direction": "neutral"
        },
        "composure": {
            "range": [-15, +10],
            "relevant_stats": ["composure", "confidence"],
            "direction": "neutral"
        },
        "discipline": {
            "range": [-10, +10],
            "relevant_stats": ["discipline", "professionalism"],
            "direction": "neutral"
        }
    },
    "duration": "temporary",
    "years_remaining": 1,
    # Context still matters - applied as range modifiers
    "context_range_shifts": {
        "traded_to_contender": {"focus": +10, "work_ethic": +5},
        "traded_to_rebuilder": {"focus": -10},
        "requested_trade": {"focus": +15, "discipline": +5},
        "surprised_by_trade": {"composure": -10, "focus": -10}
    }
}

## Context shifts the range, stats determine where in shifted range you land
```

#### 3.6.4 Team Drafts Replacement

```gdscript
const TEAM_DRAFTS_REPLACEMENT := {
    "event_type": "team.drafted_replacement",
    "stat_changes": {
        "work_ethic": {
            "range": [-10, +25],        # Competition motivates or demoralizes
            "relevant_stats": ["competitiveness", "confidence", "work_ethic"],
            "direction": "positive"     # Generally should motivate
        },
        "focus": {
            "range": [-10, +20],
            "relevant_stats": ["focus", "competitiveness"],
            "direction": "positive"
        },
        "composure": {
            "range": [-20, +10],
            "relevant_stats": ["composure", "confidence", "maturity"],
            "direction": "neutral"
        },
        "confidence": {
            "range": [-25, +10],
            "relevant_stats": ["confidence", "competitiveness"],
            "direction": "neutral"
        }
    },
    "duration": "seasonal",
    "conditions": {
        "draft_pick_round": [1, 3],
        "same_position": true
    }
}

## High competitiveness player: sees it as a challenge, gets fired up
## Low confidence player: feels threatened, composure/confidence tank
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

### 3.8 Personal Life Events

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

#### 3.7.3 New Child

```gdscript
const NEW_CHILD := {
    "event_type": "personal.new_child",
    "stat_changes": {
        "composure": {
            "range": [0, +20],
            "relevant_stats": ["maturity", "composure"],
            "direction": "positive"
        },
        "discipline": {
            "range": [-5, +15],
            "relevant_stats": ["discipline", "maturity", "responsibility"],
            "direction": "positive"
        },
        "focus": {
            "range": [-15, +10],        # Sleep deprivation vs motivation
            "relevant_stats": ["focus", "discipline", "work_ethic"],
            "direction": "neutral"
        },
        "work_ethic": {
            "range": [-10, +15],        # Motivated to provide vs distracted
            "relevant_stats": ["work_ethic", "maturity", "responsibility"],
            "direction": "positive"
        }
    },
    "duration": "permanent"
}

## Mature, responsible player: new child motivates them, grows up
## Immature, unfocused player: struggles with new responsibility
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

### 3.9 Performance Events

#### 3.8.1 Costly Mistake (Game-Losing Play)

```gdscript
const COSTLY_MISTAKE := {
    "event_type": "performance.costly_mistake",
    "stat_changes": {
        "composure": {
            "range": [-25, +10],        # Wide range - breaks some, builds others
            "relevant_stats": ["composure", "confidence", "maturity"],
            "direction": "neutral"
        },
        "confidence": {
            "range": [-30, +5],
            "relevant_stats": ["confidence", "composure", "work_ethic"],
            "direction": "negative"
        },
        "focus": {
            "range": [-15, +15],
            "relevant_stats": ["focus", "work_ethic", "competitiveness"],
            "direction": "neutral"
        },
        "work_ethic": {
            "range": [-5, +20],         # Can motivate to never let it happen again
            "relevant_stats": ["work_ethic", "competitiveness", "composure"],
            "direction": "positive"
        }
    },
    "duration": "temporary",
    "years_remaining": 1,
    "examples": [
        "Interception in end zone with game on line",
        "Fumble inside 5 yard line",
        "Missed game-winning field goal",
        "Dropped sure touchdown"
    ]
}

## High composure + high work_ethic: uses it as fuel, comes back stronger
## Low confidence + low composure: can develop "yips", confidence craters
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

#### 3.8.3 Super Bowl Loss

```gdscript
const SUPER_BOWL_LOSS := {
    "event_type": "performance.super_bowl_loss",
    "stat_changes": {
        "composure": {
            "range": [-20, +15],
            "relevant_stats": ["composure", "confidence", "maturity"],
            "direction": "neutral"
        },
        "focus": {
            "range": [-5, +25],         # Most get hungry to get back
            "relevant_stats": ["competitiveness", "work_ethic", "focus"],
            "direction": "positive"
        },
        "work_ethic": {
            "range": [0, +20],
            "relevant_stats": ["work_ethic", "competitiveness"],
            "direction": "positive"
        },
        "clutch_factor": {
            "range": [-15, +10],        # Can be haunted or learn from it
            "relevant_stats": ["composure", "confidence", "maturity"],
            "direction": "neutral"
        }
    },
    "duration": "permanent"
}

## High competitiveness + high composure: gets hungry, comes back stronger
## Low composure + low confidence: haunted by the loss, struggles in big games
```

### 3.10 Milestone Events

#### 3.9.1 First Pro Bowl Selection

```gdscript
const FIRST_PRO_BOWL := {
    "event_type": "milestone.first_pro_bowl",
    "stat_changes": {
        "confidence": {
            "range": [+5, +25],
            "relevant_stats": ["confidence", "composure"],
            "direction": "positive"
        },
        "composure": {
            "range": [0, +15],
            "relevant_stats": ["composure", "maturity"],
            "direction": "positive"
        },
        "work_ethic": {
            "range": [-15, +15],        # Can motivate or satisfy
            "relevant_stats": ["work_ethic", "competitiveness", "ambition"],
            "direction": "neutral"
        },
        "focus": {
            "range": [-10, +15],
            "relevant_stats": ["focus", "competitiveness", "ambition"],
            "direction": "neutral"
        }
    },
    "duration": "permanent"
}

## High competitiveness + high ambition: wants more, stays hungry
## Low competitiveness: "made it", coasts on reputation
```

#### 3.9.2 Won Championship

```gdscript
const WON_CHAMPIONSHIP := {
    "event_type": "milestone.championship",
    "stat_changes": {
        "composure": {
            "range": [+5, +25],
            "relevant_stats": ["composure", "maturity"],
            "direction": "positive"
        },
        "confidence": {
            "range": [+10, +30],
            "relevant_stats": ["confidence"],
            "direction": "positive"
        },
        "work_ethic": {
            "range": [-20, +20],        # Big range - dynasty mindset vs complacency
            "relevant_stats": ["work_ethic", "competitiveness", "ambition"],
            "direction": "neutral"
        },
        "hunger": {
            "range": [-25, +15],
            "relevant_stats": ["competitiveness", "ambition", "work_ethic"],
            "direction": "neutral"
        }
    },
    "duration": "permanent",
    "context_range_shifts": {
        "first_ring": {},               # No shift, base ranges
        "multiple_rings": {"work_ethic": +10, "focus": +10},  # Dynasty mindset
        "key_contributor": {"confidence": +10},
        "role_player": {"confidence": -5}
    }
}

## High competitiveness + high ambition: wants more rings, stays hungry
## Low competitiveness: "got my ring", coasts
```

### 3.11 Event Processing System

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

### 3.12 Career Event Lifecycle Integration

This section explicitly defines WHERE and WHEN career events are processed within the simulation lifecycle.

#### 3.12.1 Integration Point: Post-Season Processing

Career events are processed during the **offseason phase**, after the season simulation completes but before the next season begins.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Simulation Lifecycle (Simplified)                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────┐                                                         │
│  │   PRE-SEASON        │  • Free agency, trades, roster cuts                     │
│  │   (Before Week 1)   │  • Training camp modifiers applied                      │
│  └──────────┬──────────┘                                                         │
│             ↓                                                                    │
│  ┌─────────────────────┐                                                         │
│  │   REGULAR SEASON    │  • 17 weeks of games simulated                          │
│  │   (Weeks 1-17)      │  • Stats accumulated, injuries tracked                  │
│  └──────────┬──────────┘                                                         │
│             ↓                                                                    │
│  ┌─────────────────────┐                                                         │
│  │   PLAYOFFS          │  • Postseason games                                     │
│  │   (If applicable)   │  • Championship events                                  │
│  └──────────┬──────────┘                                                         │
│             ↓                                                                    │
│  ┌─────────────────────┐                                                         │
│  │   OFFSEASON         │  1. Performance grades calculated                       │
│  │   PROCESSING        │  2. Awards/milestones determined                        │
│  │   ★ EVENTS HERE ★   │  3. ★ CAREER EVENTS PROCESSED ★ ← Here!                 │
│  │                     │  4. Player development applied                          │
│  │                     │  5. Event recovery/decay applied                        │
│  │                     │  6. Contracts expire, FA begins                         │
│  └──────────┬──────────┘                                                         │
│             ↓                                                                    │
│  ┌─────────────────────┐                                                         │
│  │   NEXT SEASON       │  • Draft, free agency, repeat                           │
│  └─────────────────────┘                                                         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 3.12.2 Offseason Processing Order

The specific order within offseason processing matters:

```gdscript
## NflSeason.gd or SeasonManager.gd - end of season processing
func process_offseason(world_state: Dictionary, rng: RandomNumberGenerator) -> void:
    var players: Array = world_state["players"]
    var season_year := int(world_state["current_year"])

    # Step 1: Calculate performance grades (pure calculation, no RNG)
    var grades := PerformanceGrader.grade_all_players(players, world_state, cfg)
    world_state["performance_grades"][season_year] = grades

    # Step 2: Determine awards and milestones
    var awards := AwardSelector.select_awards(players, grades, world_state)
    _apply_milestone_events(players, awards)

    # Step 3: Process career events (RNG consumed here)
    for player in players:
        var season_context := _build_season_context(player, world_state, grades, awards)
        var events := CareerEventProcessor.process_season_events(player, season_context, rng)

        # Generate headlines for significant events
        for event in events:
            if _is_newsworthy(event):
                NewsGenerator.create_headline(event, player, world_state)

    # Step 4: Apply player development (RNG consumed here)
    for player in players:
        PlayerLifecycle.advance_one_year(player, dev_config, positions_cfg, rng, context)

    # Step 5: Apply event recovery/decay
    for player in players:
        _process_event_recovery(player, rng)

    # Step 6: Handle contract expirations, begin FA period
    ContractManager.process_expirations(world_state)
```

#### 3.12.3 Why This Order?

1. **Grades before events**: Performance grades inform which milestone events trigger (Pro Bowl, All-Pro)
2. **Events before development**: Stat changes from events affect the development calculations
3. **Development before recovery**: Recovery applies to event stat changes, not development gains
4. **Everything before FA**: Player valuations need updated stats for contract negotiations

#### 3.12.4 Contract-Triggered Events

Some events trigger **immediately** when contracts are signed, not during offseason:

```gdscript
## ContractNegotiator.gd - called when contract is signed
func on_contract_signed(player: Dictionary, contract: Dictionary, rng: RandomNumberGenerator) -> void:
    var event_type := _determine_contract_event_type(player, contract)

    if event_type != "":
        var event := CareerEventProcessor.create_contract_event(
            player, contract, event_type, rng
        )
        # Apply immediately, don't wait for offseason
        CareerEventProcessor._apply_event_stat_changes(player, event, rng)

        # Store in history
        var history: Array = player.get("career_events", [])
        history.append(event)
        player["career_events"] = history

## Determine what type of contract event this is
func _determine_contract_event_type(player: Dictionary, contract: Dictionary) -> String:
    var market_value := PlayerValue.calculate_market_value(player)
    var contract_aav := float(contract["total_value"]) / float(contract["years"])
    var ratio := contract_aav / market_value

    var years := int(contract["years"])
    var guaranteed := float(contract.get("guaranteed", 0))

    # Prove-it deal: Short-term, below market, with incentives
    if years == 1 and ratio < 0.95 and contract.get("has_incentives", false):
        return "contract.prove_it_deal"

    # Got paid: Above market or huge guaranteed
    if ratio > 1.2 or guaranteed > 30_000_000:
        return "contract.got_paid"

    # Contract year detection happens at season start, not here
    return ""
```

#### 3.12.5 In-Season Event Triggers

Some events can trigger during the season (not just offseason):

| Event Type | When Triggered | Processing |
|------------|----------------|------------|
| Contract signed (prove-it, got-paid) | Immediately on signing | Applied right away |
| Traded | Immediately on trade | Applied right away |
| Released/Cut | Immediately on release | Applied right away |
| Injury comeback | Start of season after injury | Applied at season start |
| Contract year | Start of final contract year | Applied at season start |
| Performance events (costly mistake) | End of game | Queued for offseason |
| Personal events | Offseason only | Applied during offseason |
| Milestone events | End of season | Applied during offseason |

### 3.13 Recovery Mechanics

Negative events don't have to be permanent. Players can recover from setbacks, and their recovery speed is influenced by their stats and circumstances.

#### 3.13.1 Recovery Speed Factors

```gdscript
## RecoveryCalculator - determines how quickly a player bounces back from negative events
const RECOVERY_STAT_INFLUENCES := {
    # High work_ethic = faster recovery (putting in the work to improve)
    "work_ethic": {
        "weight": 0.35,
        "description": "Hard workers grind their way back faster",
        "recovery_bonus_per_10_points": 0.08  # 8% faster recovery per 10 work_ethic points
    },

    # High discipline = more structured recovery
    "discipline": {
        "weight": 0.25,
        "description": "Disciplined players follow recovery programs better",
        "recovery_bonus_per_10_points": 0.06
    },

    # High composure = doesn't let setbacks snowball
    "composure": {
        "weight": 0.20,
        "description": "Mentally tough players don't spiral after bad events",
        "recovery_bonus_per_10_points": 0.05
    },

    # High coachability = responds well to help
    "coachability": {
        "weight": 0.20,
        "description": "Coachable players accept help and guidance",
        "recovery_bonus_per_10_points": 0.05
    }
}

## Calculate recovery multiplier for a player
## Returns: multiplier where 1.0 = normal, >1.0 = faster recovery, <1.0 = slower
static func calculate_recovery_multiplier(player: Dictionary) -> float:
    var stats: Dictionary = player.get("stats", {})
    var multiplier := 1.0

    for stat_name in RECOVERY_STAT_INFLUENCES.keys():
        var influence := RECOVERY_STAT_INFLUENCES[stat_name]
        var stat_value := float(stats.get(stat_name, 50.0))
        var stat_delta := stat_value - 50.0  # Deviation from average
        var bonus := (stat_delta / 10.0) * float(influence["recovery_bonus_per_10_points"])
        multiplier += bonus * float(influence["weight"])

    return clamp(multiplier, 0.5, 2.0)  # 0.5x to 2.0x recovery speed
```

#### 3.13.2 Recovery Application

```gdscript
## Apply recovery to temporary events during offseason
static func process_event_recovery(
    player: Dictionary,
    event: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    if event.get("duration") == "permanent":
        return event  # Permanent events don't decay

    var recovery_mult := calculate_recovery_multiplier(player)
    var base_decay := float(event.get("decay_rate", 0.4))
    var effective_decay := base_decay * recovery_mult

    # Apply recovery to each affected stat
    var original_changes: Dictionary = event.get("stat_changes", {})
    var recovered_changes := {}

    for stat_name in original_changes.keys():
        var original_change := float(original_changes[stat_name])
        if original_change < 0:  # Only recover from negative changes
            var recovery_amount := abs(original_change) * effective_decay
            recovered_changes[stat_name] = original_change + recovery_amount

            # Apply the recovery to player stats
            var stats: Dictionary = player.get("stats", {})
            if stats.has(stat_name):
                stats[stat_name] = clamp(
                    float(stats[stat_name]) + recovery_amount,
                    0.0,
                    100.0
                )
            player["stats"] = stats

    # Update event with remaining impact
    event["stat_changes"] = recovered_changes
    event["years_remaining"] = max(0, int(event.get("years_remaining", 1)) - 1)

    return event
```

#### 3.13.3 Recovery Examples

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│              Recovery Speed by Player Type                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  PLAYER TYPE               STATS                          RECOVERY MULT          │
│  ─────────────────────     ─────────────────────────      ──────────────         │
│  Hard Worker               work_ethic: 85, discipline: 75  1.42x (fast)          │
│  Average Player            work_ethic: 50, discipline: 50  1.00x (normal)        │
│  Lazy Talent               work_ethic: 30, discipline: 35  0.72x (slow)          │
│  Mental Fortress           composure: 90, coachability: 80 1.28x (fast)          │
│  Fragile Star              composure: 30, work_ethic: 40   0.65x (very slow)     │
│                                                                                  │
│  Example: "Divorce" event with -20 focus, -15 composure                          │
│  ─────────────────────────────────────────────────────────                       │
│  Hard Worker (1.42x):     Recovers in ~1.5 years                                 │
│  Average Player (1.0x):   Recovers in ~2 years                                   │
│  Fragile Star (0.65x):    Recovers in ~3+ years (may never fully recover)        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 3.13.4 Support System Bonuses

External factors can also accelerate recovery:

```gdscript
const RECOVERY_SUPPORT_BONUSES := {
    # Team environment
    "veteran_mentor_present": {
        "bonus": 0.15,
        "description": "Veteran helps player through tough times"
    },
    "strong_coaching_staff": {
        "bonus": 0.10,
        "description": "Good coaches provide structure"
    },
    "team_culture_high": {
        "bonus": 0.12,
        "description": "Supportive team environment"
    },

    # Personal support
    "married": {
        "bonus": 0.08,
        "description": "Stable home life aids recovery"
    },
    "faith_community": {
        "bonus": 0.10,
        "description": "Spiritual support network"
    },

    # Professional help
    "in_counseling_program": {
        "bonus": 0.20,
        "description": "Professional mental health support"
    },
    "sports_psychologist": {
        "bonus": 0.15,
        "description": "Performance-focused mental training"
    }
}
```

### 3.14 Personality Evolution

Personality types are not fixed for life. People can change, and significant events can reshape a player's core personality over their career.

#### 3.14.1 Personality Change Triggers

```gdscript
const PERSONALITY_CHANGE_TRIGGERS := {
    # Major life events can shift personality
    "found_purpose": {
        "from": ["volatile", "front_runner"],
        "to": "steady_eddie",
        "chance": 0.40,
        "description": "Finding meaning brings stability"
    },

    "championship_win": {
        "from": ["front_runner"],
        "to": "competitor",
        "chance": 0.25,
        "description": "Winning can build lasting confidence"
    },

    "career_threatening_injury_comeback": {
        "from": ["front_runner", "volatile"],
        "to": "competitor",
        "chance": 0.35,
        "description": "Surviving adversity builds resilience"
    },

    "multiple_releases": {
        "from": ["competitor", "steady_eddie"],
        "to": "front_runner",
        "chance": 0.20,
        "description": "Repeated rejection can damage confidence"
    },

    "massive_contract_complacency": {
        "from": ["competitor"],
        "to": "front_runner",
        "chance": 0.15,
        "description": "Success can breed complacency even in competitors"
    },

    "veteran_mentor_influence": {
        "from": ["volatile", "front_runner"],
        "to": "steady_eddie",
        "chance": 0.20,
        "description": "Great mentors can stabilize young players"
    },

    "captain_responsibility": {
        "from": ["volatile"],
        "to": "competitor",
        "chance": 0.30,
        "description": "Leadership responsibility can focus a player"
    },

    "repeated_clutch_performances": {
        "from": ["front_runner", "steady_eddie"],
        "to": "competitor",
        "chance": 0.25,
        "description": "Proving yourself in big moments builds competitor mentality"
    },

    "repeated_playoff_failures": {
        "from": ["competitor"],
        "to": "front_runner",
        "chance": 0.15,
        "description": "Repeated failures can erode confidence"
    }
}
```

#### 3.14.2 Gradual Personality Drift

Beyond triggered changes, personality can drift gradually based on sustained patterns:

```gdscript
## Check for gradual personality evolution during offseason
static func check_personality_evolution(
    player: Dictionary,
    season_context: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var current_personality: String = player.get("personality_type", "steady_eddie")
    var career_events: Array = player.get("career_events", [])
    var new_personality := current_personality

    # Count recent positive vs negative outcomes (last 3 years)
    var recent_events := _get_recent_events(career_events, 3)
    var adversity_count := _count_adversity_events(recent_events)
    var success_count := _count_success_events(recent_events)

    # Gradual drift based on sustained patterns
    if adversity_count >= 3 and success_count == 0:
        # Lots of adversity, no success
        match current_personality:
            "competitor":
                # Even competitors can be worn down
                if rng.randf() < 0.10:  # 10% chance per year of sustained adversity
                    new_personality = "front_runner"
            "steady_eddie":
                # Steady players can become fragile
                if rng.randf() < 0.08:
                    new_personality = "front_runner"

    elif success_count >= 3 and adversity_count == 0:
        # Sustained success
        match current_personality:
            "front_runner":
                # Success can build genuine confidence
                if rng.randf() < 0.12:
                    new_personality = "steady_eddie"
            "volatile":
                # Success can stabilize volatile players
                if rng.randf() < 0.10:
                    new_personality = "competitor"

    # Check for age-related maturation (players often mellow with age)
    var age := int(player.get("age", 22))
    if age >= 30 and current_personality == "volatile":
        if rng.randf() < 0.15:  # 15% chance per year after 30
            new_personality = "steady_eddie"

    if new_personality != current_personality:
        return {
            "changed": true,
            "from": current_personality,
            "to": new_personality,
            "reason": _determine_change_reason(adversity_count, success_count, age)
        }

    return {"changed": false}
```

#### 3.14.3 Personality Evolution Tracking

```gdscript
## Store personality changes in player history
player["personality_history"] = [
    {
        "type": "volatile",
        "from_age": 22,
        "to_age": 25
    },
    {
        "type": "competitor",
        "from_age": 25,
        "to_age": null,  # Current
        "trigger": "career_threatening_injury_comeback",
        "description": "ACL comeback built mental toughness"
    }
]
```

#### 3.14.4 Personality Change Visibility

```gdscript
const PERSONALITY_CHANGE_VISIBILITY := {
    # Some changes are publicly observable
    "public": [
        "found_purpose",           # Often discussed in media
        "captain_responsibility",  # Public announcement
        "repeated_playoff_failures"  # Performance is public
    ],

    # Some require scouting/intel to detect
    "requires_scouting": [
        "gradual_drift",           # Subtle changes
        "veteran_mentor_influence",  # Internal team dynamics
        "locker_room_evolution"    # Behind closed doors
    ]
}
```

### 3.15 Personality as Emergent from Stats

Rather than hardcoding personality types with special event modifiers, personality emerges naturally from a player's stat combination. The same stats that determine event outcomes also define who the player "is".

```gdscript
## Personality is DESCRIPTIVE, not prescriptive
## It's a label we apply based on stats, not a separate system
##
## The stats ARE the personality:
##
## "Competitor" profile:
##   - High competitiveness (75+)
##   - High work_ethic (70+)
##   - High composure (65+)
##   → These stats naturally cause positive event responses
##
## "Front Runner" profile:
##   - Low composure (40-)
##   - Low work_ethic (45-)
##   - Average/high confidence (60+)
##   → These stats naturally cause negative event responses
##
## "Steady Eddie" profile:
##   - High discipline (70+)
##   - High maturity (70+)
##   - Average everything else
##   → These stats naturally dampen event swings
##
## "Volatile" profile:
##   - Low composure (35-)
##   - Low discipline (40-)
##   - High variance in other stats
##   → These stats naturally cause extreme swings

## We can still LABEL players for UI/scouting purposes:
static func get_personality_label(player: Dictionary) -> String:
    var stats: Dictionary = player.get("stats", {})
    var competitiveness := float(stats.get("competitiveness", 50))
    var work_ethic := float(stats.get("work_ethic", 50))
    var composure := float(stats.get("composure", 50))
    var discipline := float(stats.get("discipline", 50))
    var maturity := float(stats.get("maturity", 50))

    # High competitiveness + high work_ethic + decent composure = competitor
    if competitiveness >= 75 and work_ethic >= 70 and composure >= 60:
        return "competitor"

    # Low composure + low discipline = volatile
    if composure < 40 and discipline < 45:
        return "volatile"

    # High discipline + high maturity = steady
    if discipline >= 70 and maturity >= 70:
        return "steady_eddie"

    # Low work_ethic + low composure = front_runner
    if work_ethic < 50 and composure < 50:
        return "front_runner"

    return "balanced"  # No strong archetype
```

This approach means:
- **No special event modifiers per personality type**
- **Stats directly determine outcomes**
- **Personality labels are descriptive, not mechanical**
- **Players can "change personality" by changing their stats over time**

### 3.16 Configuration

Add to `main.json`:

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
        "overperformer_threshold": 0.3,
        "underperformer_threshold": -0.3,
        "position_weights": {
            "CB": {
                "ball_skills": 0.45,
                "coverage": 0.40,
                "tackling": 0.15
            }
        }
    },

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
        "contract_thresholds": {
            "prove_it_deal_max_years": 1,
            "prove_it_deal_max_ratio": 0.95,
            "got_paid_min_ratio": 1.2,
            "big_guaranteed_money": 30000000
        },
        "decay_rates": {
            "temporary_event_default": 0.4,
            "chip_on_shoulder": 0.3,
            "personal_crisis": 0.5
        },
        "personality_drift": {
            "adversity_threshold_years": 3,
            "success_threshold_years": 3,
            "competitor_erosion_chance": 0.10,
            "steady_erosion_chance": 0.08,
            "front_runner_improvement_chance": 0.12,
            "volatile_improvement_chance": 0.10,
            "age_mellowing_chance": 0.15,
            "age_mellowing_starts": 30
        }
    },

    "recovery": {
        "stat_influences": {
            "work_ethic": { "weight": 0.35, "bonus_per_10": 0.08 },
            "discipline": { "weight": 0.25, "bonus_per_10": 0.06 },
            "composure": { "weight": 0.20, "bonus_per_10": 0.05 },
            "coachability": { "weight": 0.20, "bonus_per_10": 0.05 }
        },
        "multiplier_bounds": { "min": 0.5, "max": 2.0 },
        "support_bonuses": {
            "veteran_mentor": 0.15,
            "strong_coaching": 0.10,
            "team_culture_high": 0.12,
            "married": 0.08,
            "counseling_program": 0.20,
            "sports_psychologist": 0.15
        }
    }
}
```

Note: Code examples in this document use constants with these config values as defaults. Actual implementations should read from config and fall back to constants only if config is missing.

### 3.17 Event History Storage

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
| `scripts/world/CollegeSeason.gd` | Call college grading at end of season |
| `scripts/core/contracts/ContractNegotiator.gd` | Trigger contract events (prove-it, got-paid, etc.) |
| `scripts/core/drafting/ProspectEvaluator.gd` | Use college grades for draft evaluation |
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
1. ~~**Grade visibility in College**~~: *Resolved - College grades included with scouting-gated visibility*
2. ~~**Historical grades**~~: *Resolved - Store full grade history. Useful for tracking career arcs and identifying patterns.*
3. ~~**Grade decay**~~: *Resolved - Coach personality affects this. Some coaches enjoy the challenge of rehabilitating "washed" players back to former glory. Grade history matters for these coaches when evaluating reclamation projects.*
4. ~~**High School grades**~~: *Resolved - Rather than HS grades, use college grade trends to identify players who "flash" elite potential but don't sustain it. Scouts look for consistency vs one-off performances.*

### Development Profiles
5. **Scouting cost**: How much scouting effort to reveal development type predictions?
6. ~~**Breakthrough frequency**~~: *Resolved - Start at ~5% base chance. Should be uncommon enough to feel special when it happens.*

### Career Events
7. ~~**Event frequency cap**~~: *Resolved - No maximum. Events happen as the dice roll. Some seasons will be eventful, others quiet.*
8. ~~**Cascading events**~~: *Resolved - Yes, one event can lead to another (e.g., divorce → increased off_field_trouble chance). Creates realistic downward spirals and comeback arcs.*
9. ~~**Event visibility**~~: *Resolved - Context-dependent. Public events: DUI, arrests, suspensions, awards, contract signings. Private events: locker room incidents, family issues, internal team matters. Teams only learn about other teams' private events through scouting/intel.*
10. ~~**Recovery mechanics**~~: *Resolved - Recovery speed is linked to player stats. High work_ethic players grind their way back faster (~1.4x recovery rate). Discipline, composure, and coachability also contribute. External factors like veteran mentors, team culture, and counseling programs provide additional recovery bonuses. See Section 3.10.*
11. ~~**Personality stability**~~: *Resolved - Personality CAN change over career. Major events (championship wins, career-threatening injury comebacks, repeated failures) can trigger personality shifts. Gradual drift also occurs based on sustained patterns of adversity or success. Players often mellow with age. See Section 3.11.*
12. **Contract event thresholds**: What dollar amounts define "prove-it" vs "got paid"?
13. **Team-wide events**: Should events like "locker room drama" affect multiple players?
14. **Agent influence**: Should player agents affect contract event outcomes?
