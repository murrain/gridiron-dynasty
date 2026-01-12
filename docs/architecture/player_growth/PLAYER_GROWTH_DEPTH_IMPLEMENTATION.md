# Player Growth Depth Implementation Guide

## Overview

This document provides a phased implementation plan for the enhanced player development system with contextual depth. The implementation is divided into 5 phases, each delivering incremental value while maintaining system stability and backward compatibility.

**Total Estimated Effort**: 8-12 weeks (2-3 weeks per phase)

**Prerequisites**:
- Existing PlayerLifecycle.gd working (✓)
- Player model with stats including work_ethic, coachability (✓)
- Development context system in place (✓)
- Parallel processing infrastructure (✓)

## Phase Overview

| Phase | Focus | Complexity | Risk | Value |
|-------|-------|------------|------|-------|
| 1 | Personality Traits | Low | Low | Medium |
| 2 | Coaching System | High | Medium | High |
| 3 | Environment Enhancement | Medium | Low | Medium |
| 4 | Situational Factors | Medium | Medium | High |
| 5 | Age/Position Curves | Medium | Low | Medium |

## Phase 1: Personality Traits Integration

**Goal**: Make existing work_ethic and coachability stats affect player development

**Duration**: 2 weeks

**Dependencies**: None (uses existing player stats)

### Tasks

#### 1.1: Add Personality Multiplier Functions (Day 1-2)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

**Location**: Add after `_combined_multiplier` function (line 770)

```gdscript
## Personality-based development multiplier
## Work ethic affects base development rate
## Coachability affects response to coaching quality
##
## RNG consumption: None (uses existing player stats)
static func _personality_multiplier(
    stats: Dictionary,
    coaching_quality: float
) -> float:
    var work_ethic := float(stats.get("work_ethic", 50.0))
    var coachability := float(stats.get("coachability", 50.0))

    # Work ethic: Normalized to 0-1, scaled to [0.85, 1.15]
    var work_normalized := (work_ethic - 30.0) / 40.0  # 30-70 → 0-1
    work_normalized = clamp(work_normalized, 0.0, 1.0)
    var work_mult := 0.85 + (work_normalized * 0.30)

    # Coachability: Amplifies coaching quality effect
    var coachability_factor := (coachability - 50.0) / 50.0  # -1 to +1
    var coaching_impact := (coaching_quality - 1.0)  # deviation from baseline
    var adjusted_impact := coaching_impact * (1.0 + coachability_factor * 0.5)
    var coach_mult := 1.0 + adjusted_impact

    # Combine and cap
    var combined := work_mult * coach_mult
    return clamp(combined, 0.80, 1.25)
```

#### 1.2: Integrate Personality into Development Flow (Day 3-4)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

**Location**: Modify `_apply_development` function (line 455)

Add after line 498 (`var modifiers := _development_modifiers(development_context)`):

```gdscript
# NEW: Personality-based multiplier
var coaching_quality := float(development_context.get("coach_specialization", 1.0))
var personality_mult := _personality_multiplier(stats, coaching_quality)

# Combine with existing modifiers
var combined_multiplier := _combined_multiplier(modifiers) * personality_mult
combined_multiplier = clamp(combined_multiplier, 0.7, 1.5)  # Master cap
```

**Replace line 499** with the above `combined_multiplier` calculation.

#### 1.3: Update Development Report Schema (Day 5)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

**Location**: Modify report creation (line 516)

Add to report dictionary:

```gdscript
var report := {
    "age": age,
    "phase": phase,
    "stat_entries": [],
    "decline_multiplier": wear_multiplier,
    "context_modifiers": modifiers.duplicate(false),
    "injury_impacts": {"active": [], "recovered": []},
    # NEW: Personality impact tracking
    "personality_impact": {
        "work_ethic": float(stats.get("work_ethic", 50.0)),
        "coachability": float(stats.get("coachability", 50.0)),
        "personality_multiplier": personality_mult
    }
}
```

#### 1.4: Add Unit Tests (Day 6-7)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/tests/test_personality_traits.gd`

```gdscript
extends GutTest

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func test_personality_multiplier_ranges():
    # Test work ethic range
    var stats_low_work := {"work_ethic": 30.0, "coachability": 50.0}
    var stats_high_work := {"work_ethic": 70.0, "coachability": 50.0}

    var low_mult := PlayerLifecycle._personality_multiplier(stats_low_work, 1.0)
    var high_mult := PlayerLifecycle._personality_multiplier(stats_high_work, 1.0)

    assert_between(low_mult, 0.80, 0.90, "Low work ethic should reduce development")
    assert_between(high_mult, 1.10, 1.25, "High work ethic should boost development")

func test_coachability_amplifies_coaching():
    # High coachability with great coaching
    var stats_high_coach := {"work_ethic": 50.0, "coachability": 70.0}
    var great_coaching := 1.15

    var mult := PlayerLifecycle._personality_multiplier(stats_high_coach, great_coaching)

    # Expected: work_mult=1.0, coachability amplifies 1.15 → ~1.23
    assert_between(mult, 1.18, 1.25, "High coachability should amplify great coaching")

func test_personality_combined_cap():
    # Extreme case: max work ethic + max coachability + elite coaching
    var stats_max := {"work_ethic": 80.0, "coachability": 80.0}
    var elite_coaching := 1.25

    var mult := PlayerLifecycle._personality_multiplier(stats_max, elite_coaching)

    # Should be capped at 1.25
    assert_eq(mult, 1.25, "Personality multiplier should cap at 1.25")

func test_personality_integration_determinism():
    # Verify deterministic behavior with same seed
    var rng1 := RandomNumberGenerator.new()
    rng1.seed = 12345

    var rng2 := RandomNumberGenerator.new()
    rng2.seed = 12345

    var player := {
        "age": 20,
        "position": "QB",
        "stats": {
            "work_ethic": 65.0,
            "coachability": 55.0,
            "speed": 75.0,
            "throw_power": 80.0
        },
        "potential": {
            "speed": 85.0,
            "throw_power": 90.0
        }
    }

    var positions_cfg := load_positions_config()
    var main_cfg := load_main_config()
    var stats_cfg := load_stats_config()

    var result1 := PlayerLifecycle._apply_development_fallback(
        player.duplicate(true),
        positions_cfg,
        main_cfg,
        stats_cfg,
        rng1,
        {"coach_specialization": 1.1}
    )

    var result2 := PlayerLifecycle._apply_development_fallback(
        player.duplicate(true),
        positions_cfg,
        main_cfg,
        stats_cfg,
        rng2,
        {"coach_specialization": 1.1}
    )

    # Results should be identical
    assert_eq(result1["stat_entries"].size(), result2["stat_entries"].size())
    for i in range(result1["stat_entries"].size()):
        var entry1 := result1["stat_entries"][i]
        var entry2 := result2["stat_entries"][i]
        assert_eq(entry1["after"], entry2["after"], "Stats should be deterministic")
```

#### 1.5: Integration Testing (Day 8-10)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/tests/test_personality_integration.gd`

Test scenarios:
1. Generate 1000 players with random work_ethic/coachability
2. Advance 10 years with varying coaching quality
3. Verify combined multiplier distribution:
   - 80% of players within [0.85, 1.20] range
   - No players exceed [0.70, 1.50] master cap
4. Verify high work ethic players reach higher ratings
5. Verify high coachability players benefit more from good coaching

### Configuration Changes

**File**: `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`

Add to `"development"` section:

```json
{
  "development": {
    "personality_traits": {
      "work_ethic_range": [0.85, 1.15],
      "coachability_amplification": 0.5,
      "trait_interaction_cap": [0.80, 1.25]
    }
  }
}
```

### Success Criteria

- [ ] Personality multiplier function passes all unit tests
- [ ] Integration tests verify determinism maintained
- [ ] Development reports include personality impact
- [ ] Performance regression <3% (Phase 1 adds minimal overhead)
- [ ] High work ethic players (70+) develop 10-15% faster than low (30)
- [ ] High coachability players benefit 5-10% more from elite coaching

### Rollback Plan

If issues arise:
1. Remove personality multiplier from `combined_multiplier` calculation
2. Revert to baseline: `combined_multiplier = _combined_multiplier(modifiers)`
3. Personality traits remain in data but have no effect (safe degradation)

---

## Phase 2: Coaching System Implementation

**Goal**: Implement head coach and position coach models with hiring/firing mechanics

**Duration**: 3 weeks

**Dependencies**: Phase 1 complete (personality traits active)

### Tasks

#### 2.1: Create Coach Model (Day 1-2)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/models/Coach.gd`

See COACHING_SYSTEM_DESIGN.md for complete model specification.

Key fields:
- Identity: id, name, age, role, position_group
- Attributes: teaching_ability, motivational_skill, scheme_innovation, player_evaluation
- Personality: demanding_level, communication_style
- Specializations: speed_specialist, strength_specialist, technique_specialist
- Career: years_experience, tenure, wins/losses

#### 2.2: Create Coach Generator (Day 3-5)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/generation/CoachGenerator.gd`

Functions:
- `generate_coaching_staff(team_id, league, program_quality, rng) -> Dictionary`
- `generate_head_coach(...) -> Coach`
- `generate_position_coach(...) -> Coach`

Algorithm:
1. Use Gaussian distribution (mean=50, σ=15) for attributes
2. Apply program quality bias: `quality_bias = (program_quality - 1.0) * 15.0`
3. Assign specializations (10% HC, 15% PC per specialization)
4. Generate contract duration based on program quality

#### 2.3: Add Coach Lifecycle (Day 6-8)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CoachLifecycle.gd`

Functions:
- `process_coach_retention(coaching_staff, program, year, rng) -> Dictionary`
- `_check_retention(coach, program, rng) -> bool`
- `_hire_replacement(departing_coach, program, rng) -> Coach`
- `age_coaches(coaching_staff, team_record) -> void`

Retention factors:
- Base: 80% retention
- Tenure: -12% new, +8% veteran
- Contract: -25% expired, +5% secure
- Performance: -25% losing HC, +8% winning HC
- Program quality: -5% elite (poaching), +5% weak (stability)

#### 2.4: Integrate Coaching into Team Model (Day 9-10)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/models/Team.gd`

Add field:

```gdscript
@export var coaching_staff: Dictionary = {}
```

Serialization:

```gdscript
func to_dict() -> Dictionary:
    var dict := {
        # ... existing fields ...
        "coaching_staff": _serialize_coaching_staff(coaching_staff)
    }
    return dict

func _serialize_coaching_staff(staff: Dictionary) -> Dictionary:
    var serialized := {}

    if staff.has("head_coach"):
        var hc: Coach = staff["head_coach"]
        serialized["head_coach"] = hc.to_dict() if hc else {}

    if staff.has("position_coaches"):
        serialized["position_coaches"] = {}
        var pcs: Dictionary = staff["position_coaches"]
        for group in pcs.keys():
            var pc: Coach = pcs[group]
            serialized["position_coaches"][group] = pc.to_dict() if pc else {}

    return serialized
```

#### 2.5: Add Coaching Multiplier Functions (Day 11-12)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

Add functions (see COACHING_SYSTEM_DESIGN.md for specifications):
- `_head_coach_multiplier(head_coach: Dictionary) -> float`
- `_position_coach_multiplier(position_coach: Dictionary, player_position: String) -> float`
- `_coach_player_fit(coach: Dictionary, player: Dictionary) -> float`
- `_coaching_multiplier(head_coach: Dictionary, position_coach: Dictionary, player: Dictionary) -> float`

#### 2.6: Enrich Development Context with Coaching (Day 13-14)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd`

Modify `_apply_development_context` function:

```gdscript
func _apply_development_context(
    players: Array,
    college: Dictionary,
    config: Dictionary,
    rng: RandomNumberGenerator,
    year: int
) -> Array:
    var coaching_staff: Dictionary = college.get("coaching_staff", {}) as Dictionary
    var head_coach: Dictionary = coaching_staff.get("head_coach", {}) as Dictionary
    var position_coaches: Dictionary = coaching_staff.get("position_coaches", {}) as Dictionary

    for i in range(players.size()):
        var p: Dictionary = players[i]
        var position := String(p.get("position", ""))
        var position_group := _position_to_group(position)
        var position_coach: Dictionary = position_coaches.get(position_group, {}) as Dictionary

        var context := {
            # ... existing context fields ...

            # NEW: Coaching context
            "coaching": {
                "head_coach": head_coach,
                "position_coach": position_coach,
                "coaching_quality": _calculate_coaching_quality(head_coach, position_coach)
            }
        }

        p["development_context"] = context

    return players

func _calculate_coaching_quality(head_coach: Dictionary, position_coach: Dictionary) -> float:
    var hc_attrs := head_coach.get("attributes", {}) as Dictionary
    var pc_attrs := position_coach.get("attributes", {}) as Dictionary

    var hc_avg := (
        float(hc_attrs.get("teaching_ability", 50.0)) +
        float(hc_attrs.get("motivational_skill", 50.0)) +
        float(hc_attrs.get("scheme_innovation", 50.0))
    ) / 3.0

    var pc_teaching := float(pc_attrs.get("teaching_ability", 50.0))

    # Average HC and PC quality, normalized to 1.0 baseline
    return ((hc_avg + pc_teaching) / 2.0) / 50.0

func _position_to_group(position: String) -> String:
    const POSITION_GROUPS = {
        "QB": "QB", "RB": "RB", "WR": "WR", "TE": "WR",
        "OL": "OL", "DL": "DL", "EDGE": "DL", "LB": "LB",
        "CB": "DB", "S": "DB", "K": "SPEC", "P": "SPEC"
    }
    return POSITION_GROUPS.get(position, "")
```

#### 2.7: Integrate Coaching into Development (Day 15-16)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

Modify `_apply_development` to use coaching multiplier:

```gdscript
# After personality multiplier calculation:
var coaching_ctx: Dictionary = development_context.get("coaching", {}) as Dictionary
var head_coach: Dictionary = coaching_ctx.get("head_coach", {}) as Dictionary
var position_coach: Dictionary = coaching_ctx.get("position_coach", {}) as Dictionary

var coaching_mult := _coaching_multiplier(head_coach, position_coach, player)

# Combine with personality and existing modifiers
var combined_multiplier := (
    _combined_multiplier(modifiers) *
    personality_mult *
    coaching_mult
)
combined_multiplier = clamp(combined_multiplier, 0.7, 1.5)  # Master cap
```

#### 2.8: Bootstrap Coaching Staffs (Day 17-18)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/WorldBootstrap.gd`

Add after college generation:

```gdscript
# Generate coaching staffs for all programs
var coach_generator := CoachGenerator.new()
for college in colleges:
    var team_id := String(college.get("id", ""))
    var program_quality := float(college.get("program_quality", 1.0))

    college["coaching_staff"] = coach_generator.generate_coaching_staff(
        team_id,
        "college",
        program_quality,
        rng
    )
```

#### 2.9: Integrate Coach Retention into Season Cycle (Day 19-20)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd`

Add at end of `run()` function:

```gdscript
# Process coaching staff changes
var coach_lifecycle := CoachLifecycle.new()
for college_id in rosters.keys():
    var college: Dictionary = college_index.get(college_id, {}) as Dictionary
    var coaching_staff: Dictionary = college.get("coaching_staff", {}) as Dictionary

    # Age coaches and update career stats
    var team_record := _get_team_record(college, year)
    coach_lifecycle.age_coaches(coaching_staff, team_record)

    # Check retention
    var changes := coach_lifecycle.process_coach_retention(
        coaching_staff,
        college,
        year,
        rng
    )

    # Log significant changes
    if changes["head_coach_changed"]:
        print("Head coach changed at %s" % college.get("name", college_id))

    college["coaching_staff"] = coaching_staff
```

#### 2.10: Unit and Integration Tests (Day 21)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/tests/test_coaching_system.gd`

Test scenarios:
1. Coach generation (attributes, specializations, contracts)
2. Coaching multiplier calculations (HC, PC, fit, combined)
3. Retention logic (tenure, performance, contract effects)
4. Coaching staff serialization/deserialization
5. Full season cycle with coaching (generation → development → retention)

### Configuration Changes

**File**: `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`

Add `"coaching"` section (see COACHING_SYSTEM_DESIGN.md for complete schema).

### Success Criteria

- [ ] Coach model implemented with all attributes
- [ ] Coaching staff generation works for all teams
- [ ] Coaching multipliers function correctly (ranges verified)
- [ ] Retention system produces realistic turnover (75-85% annual retention)
- [ ] Elite programs have 15-20% better coaches on average
- [ ] Coaching integration adds <5% to bootstrap time
- [ ] All coaching tests pass (unit + integration)
- [ ] Determinism maintained (same seed = same coaches + same retention)

### Rollback Plan

If Phase 2 fails:
1. Remove coaching multiplier from combined calculation
2. Coaching staff remains in data but doesn't affect development
3. Revert to Phase 1 state (personality only)
4. Fix issues before re-enabling coaching impact

---

## Phase 3: Environment Enhancement

**Goal**: Replace one-dimensional program_quality with multi-factor environment model

**Duration**: 2 weeks

**Dependencies**: Phase 2 complete (coaching system active)

### Tasks

#### 3.1: Define Program Environment Schema (Day 1)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`

Add to `"development"` section:

```json
{
  "development": {
    "environment_factors": {
      "dimension_weights": {
        "facilities": 0.35,
        "tradition": 0.20,
        "resources": 0.30,
        "academics": 0.15
      },
      "environment_range": [0.90, 1.15],
      "conference_tier_multipliers": {
        "elite": 1.08,
        "mid": 1.00,
        "low": 0.95
      },
      "success_bonus_thresholds": {
        "elite": 0.75,
        "good": 0.60,
        "poor": 0.35
      },
      "combined_environment_cap": [0.85, 1.20]
    }
  }
}
```

#### 3.2: Add Environment Model to Team (Day 2-3)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/models/Team.gd`

Add environment field:

```gdscript
@export var program_environment: Dictionary = {}

func to_dict() -> Dictionary:
    return {
        # ... existing fields ...
        "program_environment": program_environment.duplicate(true)
    }

func from_dict(d: Dictionary) -> void:
    # ... existing field loading ...
    program_environment = (d.get("program_environment", {}) as Dictionary).duplicate(true)
```

#### 3.3: Generate Environment Data for Programs (Day 4-5)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/generation/ProgramEnvironmentGenerator.gd`

```gdscript
extends RefCounted
class_name ProgramEnvironmentGenerator

# Generate program environment based on existing program_quality
func generate_environment(
    program_quality: float,
    conference_tier: String,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Base scores from program quality (0.7-1.5 → 35-75)
    var base_score := 50.0 + (program_quality - 1.0) * 50.0

    # Add variation (σ=10) to create non-uniform profiles
    var facilities := rng.randfn(base_score, 10.0)
    var tradition := rng.randfn(base_score, 10.0)
    var resources := rng.randfn(base_score, 10.0)
    var academics := rng.randfn(base_score, 10.0)

    # Clamp to [30, 90] range
    facilities = clamp(facilities, 30.0, 90.0)
    tradition = clamp(tradition, 30.0, 90.0)
    resources = clamp(resources, 30.0, 90.0)
    academics = clamp(academics, 30.0, 90.0)

    return {
        "facilities_quality": facilities,
        "tradition_strength": tradition,
        "resource_investment": resources,
        "academic_support": academics,
        "conference_tier": conference_tier,
        "recent_success": 0.5  # Initialize to average
    }

# Update recent success based on team record
func update_recent_success(
    environment: Dictionary,
    win_pct: float,
    decay_factor: float = 0.6
) -> void:
    var current_success := float(environment.get("recent_success", 0.5))

    # Rolling average with decay (emphasize recent seasons)
    var new_success := current_success * decay_factor + win_pct * (1.0 - decay_factor)

    environment["recent_success"] = clamp(new_success, 0.0, 1.0)
```

#### 3.4: Add Environment Multiplier Functions (Day 6-8)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

See PLAYER_GROWTH_DEPTH_ARCHITECTURE.md section 3 for complete formulas.

Functions:
- `_environment_multiplier(program: Dictionary) -> float`
- `_conference_tier_multiplier(conference_tier: String) -> float`
- `_success_bonus(recent_success: float) -> float`
- `_combined_environment_multiplier(program: Dictionary) -> float`

#### 3.5: Bootstrap Environment Data (Day 9-10)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/WorldBootstrap.gd`

Add after coaching staff generation:

```gdscript
# Generate program environments
var env_generator := ProgramEnvironmentGenerator.new()
for college in colleges:
    var program_quality := float(college.get("program_quality", 1.0))
    var conference_tier := _determine_conference_tier(college)

    college["program_environment"] = env_generator.generate_environment(
        program_quality,
        conference_tier,
        rng
    )

func _determine_conference_tier(college: Dictionary) -> String:
    var conference := String(college.get("conference", ""))

    # Elite conferences
    if conference in ["SEC", "Big Ten"]:
        return "elite"

    # Group of 5
    if conference in ["MAC", "Sun Belt", "CUSA", "AAC", "MWC"]:
        return "low"

    # Power 5 (non-elite)
    return "mid"
```

#### 3.6: Integrate Environment into Development (Day 11-12)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

Modify `_apply_development` to use environment multiplier:

```gdscript
# After coaching multiplier calculation:
var environment_mult := _combined_environment_multiplier(
    development_context.get("program", {}) as Dictionary
)

# Combine all multipliers
var combined_multiplier := (
    _combined_multiplier(modifiers) *
    personality_mult *
    coaching_mult *
    environment_mult
)
combined_multiplier = clamp(combined_multiplier, 0.7, 1.5)  # Master cap
```

#### 3.7: Update Season Cycle for Success Tracking (Day 13)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd`

Add at end of `run()`:

```gdscript
# Update program recent_success
for college_id in rosters.keys():
    var college: Dictionary = college_index.get(college_id, {}) as Dictionary
    var team_record := _get_team_record(college, year)
    var win_pct := _calculate_win_percentage(team_record)

    var env: Dictionary = college.get("program_environment", {}) as Dictionary
    var env_generator := ProgramEnvironmentGenerator.new()
    env_generator.update_recent_success(env, win_pct)
```

#### 3.8: Migration for Existing Programs (Day 14)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/DataMigration.gd`

```gdscript
func migrate_program_environments_v2(programs: Array, rng: RandomNumberGenerator) -> void:
    var env_generator := ProgramEnvironmentGenerator.new()

    for program in programs:
        var p: Dictionary = program as Dictionary

        # Skip if already has environment
        if p.has("program_environment") and not p["program_environment"].is_empty():
            continue

        # Generate from existing program_quality
        var program_quality := float(p.get("program_quality", 1.0))
        var conference := String(p.get("conference", ""))
        var conference_tier := _determine_conference_tier_from_name(conference)

        p["program_environment"] = env_generator.generate_environment(
            program_quality,
            conference_tier,
            rng
        )
```

### Success Criteria

- [ ] Program environment model implemented with 4 dimensions
- [ ] Environment multipliers calculate correctly (range [0.85, 1.20])
- [ ] Elite programs show 12-18% environment advantage
- [ ] Conference tiers affect development (elite +8%, low -5%)
- [ ] Recent success dynamically updates and affects development
- [ ] Migration works for existing saves
- [ ] Performance impact <2% (environment calculations are lightweight)

---

## Phase 4: Situational Factors

**Goal**: Add dynamic contextual factors (injuries, competition, academic performance)

**Duration**: 2.5 weeks

**Dependencies**: Phase 3 complete (environment system active)

### Tasks

#### 4.1: Playoff Experience Bonus System (Day 1-3)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

```gdscript
## Playoff experience bonus (one-time per achievement)
## Mental stats gain bonus after deep playoff runs
##
## RNG consumption: 4 RNG calls per player (one per mental stat)
static func _apply_playoff_experience_bonus(
    player: Dictionary,
    playoff_depth: String,
    rng: RandomNumberGenerator
) -> Dictionary:
    var tags: Array = player.get("tags", []) as Array
    var experience_key := "playoff_exp_%s" % playoff_depth

    # Already applied this bonus
    if tags.has(experience_key):
        return {}

    # Add tag to prevent re-application
    tags.append(experience_key)
    player["tags"] = tags

    # Determine bonus range based on playoff depth
    var bonus_range: Vector2
    match playoff_depth:
        "conference_champ":
            bonus_range = Vector2(1.0, 2.5)
        "playoff_semifinal":
            bonus_range = Vector2(2.0, 4.0)
        "national_champ":
            bonus_range = Vector2(3.0, 5.0)
        _:
            return {}

    # Apply to mental stats
    var mental_stats := ["composure", "awareness", "decision_making", "confidence"]
    var bonuses := {}
    var stats: Dictionary = player.get("stats", {}) as Dictionary

    for stat in mental_stats:
        if stats.has(stat):
            var bonus := rng.randf_range(bonus_range.x, bonus_range.y)
            var current := float(stats[stat])
            stats[stat] = clamp(current + bonus, 0.0, 100.0)
            bonuses[stat] = bonus

    player["stats"] = stats
    return bonuses
```

**Integration**: Call during season advancement when team achieves playoff milestone.

#### 4.2: Peer Competition Multiplier (Day 4-6)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

```gdscript
## Peer competition quality multiplier
## High-quality backups push starters to improve
## Backups behind great starters learn and develop
##
## RNG consumption: None (deterministic calculation)
static func _competition_quality_multiplier(
    player: Dictionary,
    roster: Array,
    usage: float
) -> float:
    var position := String(player.get("position", ""))
    var player_rating := float(player.get("overall_rating", 65.0))

    # Find position peers
    var position_peers := roster.filter(func(p):
        return String(p.get("position", "")) == position and p != player
    )

    if position_peers.is_empty():
        return 1.0  # No competition

    # Calculate average peer rating
    var peer_avg := 0.0
    for peer in position_peers:
        peer_avg += float(peer.get("overall_rating", 65.0))
    peer_avg /= float(position_peers.size())

    var rating_gap := peer_avg - player_rating

    # Starter (usage > 1.1)
    if usage > 1.1:
        if rating_gap > 5.0:
            return 1.05  # Good backup pushing starter
        else:
            return 1.00

    # Backup (usage <= 1.1)
    else:
        if rating_gap < -5.0:
            return 0.95  # Backup better than starter (frustration)
        elif rating_gap > 10.0:
            return 1.03  # Backup learning from elite starter
        else:
            return 1.00
```

#### 4.3: Injury Recovery Penalty (Day 7-8)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

```gdscript
## Injury recovery penalty multiplier
## First year after recovery shows reduced development
##
## RNG consumption: None (uses existing injury data)
static func _injury_recovery_multiplier(injuries: Array) -> float:
    if injuries.is_empty():
        return 1.0

    # Find recent recoveries (status="recovered", years_remaining=0 means recovered this year)
    var recent_recovery_count := 0

    for injury in injuries:
        var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
        var status := String(timeline.get("status", "recovered"))
        var years_total := int(timeline.get("years_total", 0))
        var years_remaining := int(timeline.get("years_remaining", 0))

        # Recovered this year if: status=recovered AND years_remaining=0 AND years_total>0
        if status == "recovered" and years_remaining == 0 and years_total > 0:
            recent_recovery_count += 1

    if recent_recovery_count == 0:
        return 1.0

    # Penalty: -8% per recent injury recovery
    var penalty := 1.0 - (0.08 * float(recent_recovery_count))
    return clamp(penalty, 0.85, 1.0)
```

#### 4.4: Academic Performance Multiplier (Day 9-10)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

```gdscript
## Academic performance multiplier
## Poor academic performance reduces development (stress, time management)
## Strong academic support mitigates risk
##
## RNG consumption: None (uses player stats)
static func _academic_performance_multiplier(
    player: Dictionary,
    program_academic_support: float
) -> float:
    var stats: Dictionary = player.get("stats", {}) as Dictionary
    var focus := float(stats.get("focus", 50.0))
    var discipline := float(stats.get("discipline", 50.0))
    var football_iq := float(stats.get("football_IQ", 50.0))

    # Academic risk score (higher is better)
    var academic_score := (focus + discipline + football_iq) / 3.0

    # Academic support mitigates risk
    var support_factor := program_academic_support / 100.0
    var adjusted_score := academic_score + (100.0 - academic_score) * support_factor * 0.3

    # Convert to multiplier
    if adjusted_score < 40.0:
        return 0.90  # Academic struggle
    elif adjusted_score < 50.0:
        return 0.95  # Borderline academics
    else:
        return 1.00  # No academic issues
```

#### 4.5: Combined Situational Multiplier (Day 11-12)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

```gdscript
## Combined situational factors multiplier
## Integrates competition, injury, academic factors
##
## RNG consumption: None (uses deterministic calculations)
static func _situational_multiplier(
    player: Dictionary,
    context: Dictionary,
    roster: Array
) -> float:
    var usage := float(context.get("usage", 1.0))
    var injuries: Array = player.get("injuries", []) as Array
    var program_env: Dictionary = context.get("program_environment", {}) as Dictionary
    var academic_support := float(program_env.get("academic_support", 50.0))

    var comp_mult := _competition_quality_multiplier(player, roster, usage)
    var injury_mult := _injury_recovery_multiplier(injuries)
    var academic_mult := _academic_performance_multiplier(player, academic_support)

    var combined := comp_mult * injury_mult * academic_mult
    return clamp(combined, 0.85, 1.15)
```

#### 4.6: Integrate Situational Factors into Development (Day 13-14)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

Modify `_apply_development`:

```gdscript
# After environment multiplier:
var roster: Array = development_context.get("roster", []) as Array
var situational_mult := _situational_multiplier(player, development_context, roster)

# Combine all multipliers
var combined_multiplier := (
    _combined_multiplier(modifiers) *
    personality_mult *
    coaching_mult *
    environment_mult *
    situational_mult
)
combined_multiplier = clamp(combined_multiplier, 0.7, 1.5)  # Master cap
```

#### 4.7: Pass Roster Context in Season Advancement (Day 15-16)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd`

Modify `_apply_development_context`:

```gdscript
func _apply_development_context(
    players: Array,
    college: Dictionary,
    config: Dictionary,
    rng: RandomNumberGenerator,
    year: int
) -> Array:
    # ... existing context preparation ...

    for i in range(players.size()):
        var p: Dictionary = players[i]

        var context := {
            # ... existing context fields ...

            # NEW: Roster for peer competition
            "roster": players,

            # NEW: Program environment for academic support
            "program_environment": college.get("program_environment", {})
        }

        p["development_context"] = context

    return players
```

#### 4.8: Testing (Day 17-18)

Test scenarios:
1. Playoff experience bonuses apply once per achievement
2. Peer competition affects starters and backups correctly
3. Injury recovery reduces development for one year
4. Academic struggles affect players with low focus/discipline
5. Academic support mitigates academic performance penalty
6. Combined situational factors don't exceed [0.85, 1.15] cap

### Success Criteria

- [ ] Playoff experience bonuses work (3-5 points to mental stats)
- [ ] Peer competition affects 15-20% of players (edge cases)
- [ ] Injury recovery penalty applies correctly (one year after recovery)
- [ ] Academic performance correlates with focus/discipline/IQ
- [ ] All situational factors integrated without performance regression
- [ ] Determinism maintained

---

## Phase 5: Age & Position Curves

**Goal**: Add stat-specific age curves and position-specific development patterns

**Duration**: 2 weeks

**Dependencies**: Phase 4 complete

### Tasks

#### 5.1: Add Stat Type Classification (Day 1-2)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/stats.json`

Add `"stat_type"` field to each stat:

```json
{
  "stats": [
    {"name": "speed", "type": "base", "stat_type": "physical"},
    {"name": "acceleration", "type": "base", "stat_type": "physical"},
    {"name": "awareness", "type": "base", "stat_type": "mental"},
    {"name": "decision_making", "type": "base", "stat_type": "mental"},
    {"name": "route_running", "type": "base", "stat_type": "technique"},
    {"name": "coverage", "type": "base", "stat_type": "technique"}
  ]
}
```

#### 5.2: Implement Age Curve Modifiers (Day 3-5)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

See PLAYER_GROWTH_DEPTH_ARCHITECTURE.md section 5 for complete formulas.

```gdscript
## Age-based stat type curve modifier
## Physical stats peak early, mental stats peak late
static func _age_curve_modifier(age: int, stat_type: String) -> float:
    match stat_type:
        "physical":
            if age < 23: return 1.10
            elif age < 26: return 1.00
            elif age < 30: return 0.90
            else: return 0.75

        "mental":
            if age < 23: return 0.85
            elif age < 26: return 1.05
            elif age < 30: return 1.10
            else: return 1.00

        "technique":
            if age < 23: return 0.95
            elif age < 30: return 1.05
            else: return 0.95

        _: return 1.00
```

#### 5.3: Implement Position-Specific Curves (Day 6-8)

```gdscript
## Position-specific stat development curves
## QB mental stats accelerate after age 24
## RB physical stats decline earlier
static func _position_stat_multiplier(position: String, stat_name: String, age: int) -> float:
    match position:
        "QB":
            if stat_name in ["awareness", "decision_making", "anticipation", "football_IQ"]:
                if age < 24: return 0.90
                elif age < 28: return 1.15
                else: return 1.05
            return 1.00

        "RB":
            if stat_name in ["speed", "acceleration", "agility"]:
                if age < 24: return 1.10
                elif age < 27: return 1.00
                elif age < 30: return 0.85
                else: return 0.70
            return 1.00

        "OL", "DL":
            if stat_name in ["strength", "blocking", "shedding_blocks"]:
                if age < 24: return 0.95
                elif age < 29: return 1.10
                else: return 0.95
            return 1.00

        "WR", "CB":
            if stat_name in ["speed", "acceleration", "route_running", "coverage"]:
                if age < 25: return 1.08
                elif age < 29: return 1.00
                else: return 0.88
            return 1.00

        _: return 1.00
```

#### 5.4: Late Bloomer System (Day 9-11)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/generation/PlayerGenerator.gd`

Add late bloomer tagging during generation:

```gdscript
func _make_single_player(gaussian_share: float, rng: RandomNumberGenerator) -> Dictionary:
    var p: Dictionary = {}

    # ... existing player generation ...

    # Assign late bloomer tag (5% chance)
    if rng.randf() < 0.05:
        if not p.has("tags"):
            p["tags"] = []
        var tags: Array = p["tags"] as Array
        tags.append("LateBloomer")

    return p
```

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

```gdscript
## Late bloomer adjustment
## Reduces early development, enhances mid-career development
static func _late_bloomer_adjustment(player: Dictionary, age: int, base_delta: float) -> float:
    var tags: Array = player.get("tags", []) as Array

    if not tags.has("LateBloomer"):
        return base_delta

    # Late bloomers: -20% before age 24, +15% age 24-28
    if age < 24:
        return base_delta * 0.80
    elif age < 28:
        return base_delta * 1.15
    else:
        return base_delta
```

#### 5.5: Experience-Based Awareness Bonus (Day 12-13)

```gdscript
## Experience-based awareness bonus
## Mental stats gain small bonus per year of experience
static func _experience_bonus(years_played: int, stat_name: String) -> float:
    if stat_name not in ["awareness", "decision_making", "anticipation", "football_IQ"]:
        return 0.0

    # +0.3 points per year, capping at +3.0 after 10 years
    return min(3.0, float(years_played) * 0.3)
```

#### 5.6: Integrate Age/Position Curves into Development (Day 14)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/PlayerLifecycle.gd`

Modify stat update loop in `_apply_development`:

```gdscript
for key in stats.keys():
    var stat_name := String(key)

    # ... existing delta calculation ...

    # Apply age-based stat type curve
    var stat_type := _get_stat_type(stat_name, stats_cfg)
    var age_curve := _age_curve_modifier(age, stat_type)
    delta *= age_curve

    # Apply position-specific curve
    var pos_curve := _position_stat_multiplier(position, stat_name, age)
    delta *= pos_curve

    # Apply late bloomer adjustment
    delta = _late_bloomer_adjustment(player, age, delta)

    # Apply experience bonus (additive, not multiplicative)
    var years_played := age - 18
    var exp_bonus := _experience_bonus(years_played, stat_name)
    delta += exp_bonus

    # ... rest of existing clamping and potential cap logic ...
}

func _get_stat_type(stat_name: String, stats_cfg: Dictionary) -> String:
    var stat_defs := _stat_defs(stats_cfg)
    var stat_def: Dictionary = stat_defs.get(stat_name, {}) as Dictionary
    return String(stat_def.get("stat_type", "physical"))
```

### Success Criteria

- [ ] Physical stats develop faster early career (ages 18-22)
- [ ] Mental stats develop faster late career (ages 26-30)
- [ ] QB mental stats show accelerated growth after age 24
- [ ] RB speed stats show early decline (age 27+)
- [ ] Late bloomers develop slowly early, fast mid-career
- [ ] Experience bonuses accumulate correctly (+0.3/year mental stats)
- [ ] Position-specific curves verified across all positions

---

## Testing Strategy

### Unit Testing (Per-Phase)

Each phase includes unit tests for new functions:
- Multiplier calculations (range verification)
- Edge cases (null inputs, extreme values)
- Determinism (same seed = same result)

### Integration Testing (End-to-End)

After Phase 5 complete:

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/tests/test_enhanced_development_integration.gd`

1. **Career Arc Simulation**:
   - Generate 1000 players with diverse attributes
   - Simulate 15-year careers with varying contexts
   - Verify career arcs match expected patterns:
     - Early bloomers peak by age 24
     - Late bloomers peak by age 27
     - QBs mental stats increase significantly age 24-28
     - RBs decline faster than other positions

2. **Multiplier Distribution Validation**:
   - Track combined multipliers across 10,000 player-years
   - Verify 80% fall within [0.85, 1.20]
   - Verify no player exceeds [0.70, 1.50] master cap

3. **Determinism Validation**:
   - Run 5 bootstrap simulations with same seed
   - Verify identical player development outcomes
   - Verify identical coaching hires/fires

### Performance Benchmarking

**Baseline** (current system): ~X seconds for bootstrap

**Phase 1**: Target <+3% (personality minimal overhead)
**Phase 2**: Target <+5% (coaching adds context lookups)
**Phase 3**: Target <+2% (environment lightweight)
**Phase 4**: Target <+5% (situational includes roster traversal)
**Phase 5**: Target <+3% (age/position curves per-stat multipliers)

**Total Target**: <+20% bootstrap time increase

### Balance Validation

After Phase 5:

1. **Player Rating Distribution**:
   - Generate 10,000 players, simulate 10 years
   - Verify final rating distribution:
     - Elite programs: Mean rating +5-8 points vs average programs
     - Elite coaching: Mean rating +3-5 points vs poor coaching
     - No single factor dominates (2x improvement impossible)

2. **Career Diversity**:
   - Verify presence of diverse career arcs:
     - 5% late bloomers (identified by tag)
     - 10-15% early retirements (injury/low rating)
     - Position-specific peak ages (QB 27-29, RB 24-26)

## Rollback & Risk Mitigation

### Phase Independence

Each phase can be rolled back independently:
- Remove multiplier from `combined_multiplier` calculation
- Data remains in place but has no effect
- Revert to previous phase state

### Feature Flags

**File**: `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`

```json
{
  "development": {
    "enhanced_features": {
      "personality_traits_enabled": true,
      "coaching_system_enabled": true,
      "environment_factors_enabled": true,
      "situational_factors_enabled": true,
      "age_position_curves_enabled": true
    }
  }
}
```

Each feature can be toggled off if issues arise.

### Monitoring

Track key metrics during rollout:
- Bootstrap time (must stay <+20%)
- Combined multiplier distribution (80% in [0.85, 1.20])
- Coaching retention rates (75-85% annual)
- Player rating progression (elite programs +5-8 vs average)

## Configuration Schema (Complete)

**File**: `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`

See PLAYER_GROWTH_DEPTH_ARCHITECTURE.md for complete schema.

## Migration Plan

### For Existing Saves

**File**: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/DataMigration.gd`

```gdscript
func migrate_to_enhanced_development_v2(world_state: Dictionary, rng: RandomNumberGenerator) -> void:
    # Phase 1: Personality traits (already in stats, no migration needed)

    # Phase 2: Coaching staffs
    var programs: Array = world_state.get("colleges", []) as Array
    for program in programs:
        var p: Dictionary = program as Dictionary
        if not p.has("coaching_staff") or p["coaching_staff"].is_empty():
            _generate_coaching_staff(p, rng)

    # Phase 3: Program environments
    for program in programs:
        var p: Dictionary = program as Dictionary
        if not p.has("program_environment") or p["program_environment"].is_empty():
            _generate_program_environment(p, rng)

    # Phase 4: Situational factors (no migration, applied dynamically)

    # Phase 5: Late bloomer tags (assign based on player_id hash)
    var players: Array = _all_players_in_world(world_state)
    for player in players:
        var pl: Dictionary = player as Dictionary
        var player_id := String(pl.get("player_id", ""))
        var id_hash := hash(player_id)

        # Deterministically assign late bloomer (5% of players)
        if id_hash % 100 < 5:
            if not pl.has("tags"):
                pl["tags"] = []
            var tags: Array = pl["tags"] as Array
            if not tags.has("LateBloomer"):
                tags.append("LateBloomer")
```

## Summary

This implementation guide provides a phased rollout strategy for the enhanced player development system:

1. **Phase 1 (2 weeks)**: Personality traits (low risk, moderate value)
2. **Phase 2 (3 weeks)**: Coaching system (high complexity, high value)
3. **Phase 3 (2 weeks)**: Environment enhancement (medium complexity, medium value)
4. **Phase 4 (2.5 weeks)**: Situational factors (medium complexity, high value)
5. **Phase 5 (2 weeks)**: Age/position curves (medium complexity, medium value)

**Total Duration**: 11.5 weeks (conservative estimate)

Each phase builds on previous phases, delivers incremental value, and can be independently rolled back if issues arise. Feature flags allow selective enabling/disabling of components. Comprehensive testing ensures determinism, balance, and performance targets are met.
