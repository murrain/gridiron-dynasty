# College Simulation Features - Implementation Plan

## Executive Summary

This plan covers 8 major feature areas to improve NFL draft realism through enhanced college simulation. The implementation follows existing architectural patterns in the codebase.

---

## Phase 1: College Performance Statistics

### Data Model Changes

**New player fields:**
```gdscript
"college_career_stats": {
    "seasons": {
        year: {
            "games_played": int,
            "games_started": int,
            "position": String,
            "team_id": String,
            # Position-specific stats
        }
    },
    "career_totals": {...},
    "production_trajectory": [float, float, ...]  # composite score per year
}
```

### New Files
- `scripts/world/CollegeStatsService.gd` - Season/career stat tracking
- `configs/sports/american_football/college_stats.json` - Efficiency metrics config

### Key Functions
```gdscript
static func update_player_season_stats(player: Dictionary, year: int, game_stats: Dictionary) -> void
static func calculate_efficiency_metrics(player: Dictionary, positions_cfg: Dictionary) -> Dictionary
static func analyze_production_trajectory(player: Dictionary) -> Dictionary
```

### Integration Points
- `CollegeSeason.run()`: After game simulation, accumulate stats
- `NflDraft._score_draft_pool()`: Use trajectory analysis as scoring factor

---

## Phase 2: Conference/Competition Level Weighting

### Data Model Changes

**New college fields:**
```gdscript
{
    "conference": "sec",
    "conference_tier": "power_5",  # "power_5", "group_5", "fcs"
    "strength_of_schedule": 0.0
}
```

### Configuration
```json
{
    "conferences": [
        {"id": "sec", "tier": "power_5", "draft_weight_multiplier": 1.15},
        {"id": "big_ten", "tier": "power_5", "draft_weight_multiplier": 1.12}
    ],
    "tier_weights": {
        "power_5": {"base_draft_multiplier": 1.10},
        "group_5": {"base_draft_multiplier": 0.95},
        "fcs": {"base_draft_multiplier": 0.80}
    }
}
```

### New Files
- `scripts/world/ConferenceService.gd` - Conference assignment and SOS calculation

### Integration Points
- `CollegeGenerator.generate()`: Assign conferences
- `NflDraft._score_draft_pool()`: Apply conference tier weighting

---

## Phase 3: Pre-Draft Process Simulation

### Data Model Changes

**New player fields:**
```gdscript
"pre_draft_process": {
    "combine_invited": bool,
    "combine_performance": {
        "overall_performance_grade": float  # -10 to +10 impact
    },
    "pro_day_attended": bool,
    "all_star_games": ["senior_bowl", "east_west_shrine"],
    "team_visits": ["team_id_1", ...],  # Max 30
    "interview_scores": {"team_id": float},
    "draft_stock_movement": float
}
```

### Configuration
```json
{
    "combine": {
        "invite_count": 330,
        "invite_criteria": {"min_rating_threshold": 68.0},
        "performance_impact": {
            "elite_performance_boost": {"threshold_percentile": 90, "draft_boost": 0.08},
            "poor_performance_penalty": {"threshold_percentile": 25, "draft_penalty": 0.05}
        }
    },
    "all_star_games": {
        "senior_bowl": {"invite_count": 110, "min_rating": 72.0},
        "east_west_shrine": {"invite_count": 100, "min_rating": 65.0}
    },
    "team_visits": {"max_per_player": 30}
}
```

### New Files
- `scripts/world/PreDraftProcess.gd` - Main orchestration
- `configs/sports/american_football/pre_draft_process.json`

### Key Functions
```gdscript
static func run(world_state: Dictionary, year: int, seed: int, config: Dictionary) -> Dictionary
static func _select_combine_invitees(pool: Array, config: Dictionary, rng) -> Array
static func _simulate_combine(players: Array, config: Dictionary, rng) -> void
static func _simulate_pro_days(players: Array, config: Dictionary, rng) -> void
static func _simulate_all_star_games(pool: Array, config: Dictionary, rng) -> void
static func _simulate_team_visits(pool: Array, world_state: Dictionary, config: Dictionary, rng) -> void
```

---

## Phase 4: Medical & Injury System

### Data Model Changes

**New player fields:**
```gdscript
"college_injury_history": [
    {"year": int, "type": String, "severity": float, "games_missed": int, "surgery_required": bool}
],
"medical_evaluation": {
    "grade": String,  # "clean", "minor_concern", "major_concern", "failed"
    "red_flags": ["acl_history", "back_issues"],
    "durability_projection": float,
    "draft_impact": float
}
```

### Configuration
```json
{
    "college_injury_system": {
        "yearly_injury_chance": 0.15,
        "recurring_injury_chance_increase": 0.10
    },
    "medical_evaluation": {
        "grade_criteria": {
            "clean": {"max_injuries": 1, "no_surgeries": true},
            "minor_concern": {"max_injuries": 2, "max_surgeries": 1},
            "major_concern": {"max_injuries": 4},
            "failed": {"triggers": ["career_ending_risk", "multiple_acl"]}
        },
        "draft_slide_ranges": {
            "clean": [0, 0],
            "minor_concern": [0, 5],
            "major_concern": [10, 30],
            "failed": [50, 100]
        }
    }
}
```

### New Files
- `scripts/world/CollegeMedicalService.gd`

---

## Phase 5: Character/Off-Field Issues

### Data Model Changes

**New player fields:**
```gdscript
"character_profile": {
    "discipline_record": [{"year": int, "type": "suspension", "games": int, "reason": String}],
    "arrests": [{"year": int, "charge": String, "outcome": String}],
    "character_grade": String,  # "exemplary", "clean", "concern", "red_flag"
    "interview_red_flags": [],
    "character_draft_impact": float
}
```

### Configuration
```json
{
    "discipline_events": {
        "base_suspension_chance": 0.02,
        "types": [
            {"type": "academic", "weight": 0.4, "games_range": [1, 4], "severity": "minor"},
            {"type": "team_rules", "weight": 0.3, "games_range": [1, 2], "severity": "minor"},
            {"type": "substance_abuse", "weight": 0.15, "games_range": [2, 6], "severity": "moderate"},
            {"type": "conduct", "weight": 0.1, "games_range": [1, 8], "severity": "major"},
            {"type": "legal_trouble", "weight": 0.05, "games_range": [4, 16], "severity": "severe"}
        ]
    },
    "character_grades": {
        "exemplary": {"max_incidents": 0, "draft_boost": 0.02},
        "clean": {"max_incidents": 1, "draft_impact": 0},
        "concern": {"max_incidents": 2, "draft_penalty": 0.05},
        "red_flag": {"draft_penalty_range": [0.10, 0.30]}
    }
}
```

### New Files
- `scripts/world/CharacterService.gd`
- `configs/sports/american_football/character_system.json`

---

## Phase 6: College Awards & Media Hype

### Data Model Changes

**New player fields:**
```gdscript
"college_awards": {
    "heisman_votes": {year: {"rank": int, "votes": int}},
    "all_american": {year: {"team": "first"|"second"|"third"}},
    "conference_awards": {year: ["offensive_poy", "defensive_poy"]}
},
"media_profile": {
    "hype": float,
    "mock_draft_positions": {year: {"espn": int, "nfl_network": int}},
    "consensus_ranking": int,
    "hype_vs_talent_gap": float
}
```

### Configuration
```json
{
    "heisman": {
        "eligible_positions": ["QB", "RB", "WR"],
        "finalist_count": 4,
        "voting_weights": {
            "stats": 0.4,
            "team_success": 0.25,
            "narrative": 0.2,
            "hype": 0.15
        }
    },
    "mock_draft": {
        "sources": ["espn", "nfl_network", "pff"],
        "noise_sigma": 15,
        "hype_susceptibility_by_source": {"espn": 0.7, "nfl_network": 0.5, "pff": 0.3}
    }
}
```

### New Files
- `scripts/world/CollegeAwardsService.gd`
- `configs/sports/american_football/college_awards.json`

---

## Phase 7: Draft Stock Movement Over Time

### Data Model Changes

**New player fields:**
```gdscript
"draft_stock_timeline": {
    "pre_season_rank": int,
    "post_season_rank": int,
    "post_combine_rank": int,
    "final_rank": int,
    "movement_events": [
        {"event": "combine_riser", "impact": +15, "timestamp": "post_combine"}
    ],
    "total_movement": int
}
```

### Configuration
```json
{
    "draft_stock_movement": {
        "evaluation_windows": ["pre_season", "post_season", "post_combine", "post_medical", "final"],
        "event_impacts": {
            "combine_standout": [8, 20],
            "combine_disappointment": [-15, -5],
            "senior_bowl_star": [5, 12],
            "medical_concern_revealed": [-25, -10],
            "character_issue_surfaced": [-30, -15]
        }
    }
}
```

### New Files
- `scripts/world/DraftStockTracker.gd`

---

## Phase 8: Early Declaration Advisory System

### Data Model Changes

**New player fields:**
```gdscript
"declaration_advisory": {
    "nfl_advisory_grade": String,  # "1st_round", "2nd_round", "3rd_day", "return_to_school"
    "projected_draft_position": {"min": int, "max": int},
    "agent_contacted": bool,
    "agent_advice": String,
    "return_to_school_decision": bool
}
```

### Configuration
```json
{
    "nfl_advisory_grades": {
        "1st_round": {"min_rating": 85, "declaration_rate": 0.95},
        "2nd_round": {"min_rating": 78, "declaration_rate": 0.80},
        "3rd_day": {"min_rating": 70, "declaration_rate": 0.45},
        "return_to_school": {"below_rating": 70, "declaration_rate": 0.15}
    },
    "agent_influence": {
        "agent_contact_rating_threshold": 75,
        "agent_push_declaration_rate_boost": 0.15
    },
    "return_to_school_boost": {
        "development_bonus": 1.15,
        "injury_risk_per_year": 0.15
    }
}
```

### New Files
- `scripts/world/EarlyDeclarationService.gd`
- `configs/sports/american_football/early_declaration.json`

---

## Implementation Dependencies

```
Phase 1: College Performance Statistics
    └── Foundation for all other phases

Phase 2: Conference/Competition Weighting
    └── Depends on: Phase 1 (stats for SOS calculation)

Phase 3: Pre-Draft Process
    ├── Depends on: Phase 1 (stats for combine invites)
    └── Depends on: Phase 2 (conference tier for invites)

Phase 4: Medical System
    └── Standalone (integrates with existing injury system)

Phase 5: Character System
    └── Standalone (new parallel system)

Phase 6: Awards & Hype
    ├── Depends on: Phase 1 (stats for award selection)
    └── Extends existing HypeGenerator

Phase 7: Draft Stock Movement
    ├── Depends on: Phase 3 (pre-draft events)
    ├── Depends on: Phase 4 (medical evaluation)
    └── Depends on: Phase 5 (character evaluation)

Phase 8: Early Declaration
    ├── Depends on: Phase 6 (hype affects agent contact)
    └── Depends on: Phase 1 (stats for advisory grade)
```

---

## Recommended Implementation Order

### Milestone 1: Core Stats Foundation
1. Phase 1: College Performance Statistics
2. Phase 2: Conference/Competition Level Weighting

### Milestone 2: Pre-Draft Simulation
3. Phase 3: Pre-Draft Process Simulation
4. Phase 7: Draft Stock Movement Over Time

### Milestone 3: Risk Factors
5. Phase 4: Medical & Injury System
6. Phase 5: Character/Off-Field Issues

### Milestone 4: Media & Decision Systems
7. Phase 6: College Awards & Media Hype
8. Phase 8: Early Declaration Advisory System

---

## New Files Summary

| Path | Purpose |
|------|---------|
| `scripts/world/CollegeStatsService.gd` | Season/career stat tracking |
| `scripts/world/ConferenceService.gd` | Conference assignment and SOS |
| `scripts/world/PreDraftProcess.gd` | Combine, pro days, visits |
| `scripts/world/CollegeMedicalService.gd` | Injury tracking, medical eval |
| `scripts/world/CharacterService.gd` | Discipline and character grading |
| `scripts/world/CollegeAwardsService.gd` | Heisman, All-American, awards |
| `scripts/world/DraftStockTracker.gd` | Draft stock movement |
| `scripts/world/EarlyDeclarationService.gd` | Advisory system |
| `configs/.../college_stats.json` | Efficiency metrics config |
| `configs/.../pre_draft_process.json` | Combine/visits config |
| `configs/.../character_system.json` | Character config |
| `configs/.../college_awards.json` | Awards config |
| `configs/.../early_declaration.json` | Advisory config |

## Modified Files Summary

| Path | Changes |
|------|---------|
| `scripts/world/CollegeSeason.gd` | Add stat accumulation, injuries, character, awards |
| `scripts/world/CollegeGenerator.gd` | Add conference assignment |
| `scripts/world/NflDraft.gd` | Integrate all new scoring factors |
| `scripts/generation/HypeGenerator.gd` | Add award event types |
| `configs/.../world/colleges.json` | Add conferences section |
| `configs/.../main.json` | Add medical evaluation config |
