# Coaching System Design

## Executive Summary

This document specifies the coaching system that serves as a critical multiplier in the enhanced player development architecture. The coaching system models head coaches and position coaches as independent entities with attributes, specializations, and career lifecycles. Coaches affect player development through teaching ability, motivational skills, and personality fit with players.

**Design Goals**:
- Coaching quality provides 10-25% development variation (not 2x or 0.5x)
- Coach-player fit matters but doesn't dominate (2-5% bonus)
- Coach turnover creates program stability variation (realistic 70-85% annual retention)
- Deterministic simulation (all coach actions seeded via RNG)

## Data Model

### Coach Entity

```gdscript
# scripts/core/models/Coach.gd
extends Resource
class_name Coach

# === Identity ===
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""
@export var age: int = 35

# === Role & Assignment ===
@export var role: String = "position_coach"  # "head_coach" | "position_coach"
@export var position_group: String = ""      # "QB" | "RB" | "WR" | "OL" | "DL" | "LB" | "DB" | "SPEC"
@export var team_id: String = ""             # Current team assignment
@export var league: String = "college"       # "college" | "nfl"

# === Coaching Attributes (0-100 scale, normal distribution) ===
# These attributes drive development multipliers
@export var teaching_ability: float = 50.0      # Technical instruction quality
@export var motivational_skill: float = 50.0    # Player engagement and effort
@export var scheme_innovation: float = 50.0     # Scheme fit optimization
@export var player_evaluation: float = 50.0     # Talent identification (recruiting/scouting)

# === Personality Traits (0-100 scale) ===
# Used for coach-player fit calculations
@export var demanding_level: float = 50.0       # High-demand coach fits high work_ethic players
@export var communication_style: float = 50.0   # Good communicator fits high coachability players

# === Specializations (binary flags) ===
# Provide +5% bonus to specific stat categories
@export var speed_specialist: bool = false      # Speed, acceleration development
@export var strength_specialist: bool = false   # Strength, blocking development
@export var technique_specialist: bool = false  # Position-core skills development

# === Career & Experience ===
@export var years_experience: int = 0           # Total coaching career length
@export var tenure_at_current_program: int = 0  # Years at current team
@export var career_wins: int = 0                # Historical success metric
@export var career_losses: int = 0

# === Contract & Stability ===
@export var contract_years_remaining: int = 0   # Contract security affects retention
@export var salary: float = 0.0                 # Coaching salary (affects recruiting/poaching)

# === Derived Properties ===
func get_full_name() -> String:
    return "%s %s" % [first_name, last_name]

func get_win_percentage() -> float:
    var total := career_wins + career_losses
    if total == 0:
        return 0.5
    return float(career_wins) / float(total)

func get_coaching_quality() -> float:
    # Average of core attributes, normalized to multiplier range
    var avg := (teaching_ability + motivational_skill + scheme_innovation) / 3.0
    return avg / 50.0  # 50 → 1.0, 75 → 1.5, 25 → 0.5

# === Serialization ===
func to_dict() -> Dictionary:
    return {
        "id": id,
        "first_name": first_name,
        "last_name": last_name,
        "age": age,
        "role": role,
        "position_group": position_group,
        "team_id": team_id,
        "league": league,
        "attributes": {
            "teaching_ability": teaching_ability,
            "motivational_skill": motivational_skill,
            "scheme_innovation": scheme_innovation,
            "player_evaluation": player_evaluation
        },
        "personality": {
            "demanding_level": demanding_level,
            "communication_style": communication_style
        },
        "specializations": {
            "speed_specialist": speed_specialist,
            "strength_specialist": strength_specialist,
            "technique_specialist": technique_specialist
        },
        "career": {
            "years_experience": years_experience,
            "tenure_at_current_program": tenure_at_current_program,
            "career_wins": career_wins,
            "career_losses": career_losses,
            "win_percentage": get_win_percentage()
        },
        "contract": {
            "years_remaining": contract_years_remaining,
            "salary": salary
        }
    }

func from_dict(d: Dictionary) -> void:
    id = String(d.get("id", id))
    first_name = String(d.get("first_name", first_name))
    last_name = String(d.get("last_name", last_name))
    age = int(d.get("age", age))
    role = String(d.get("role", role))
    position_group = String(d.get("position_group", position_group))
    team_id = String(d.get("team_id", team_id))
    league = String(d.get("league", league))

    var attrs: Dictionary = d.get("attributes", {}) as Dictionary
    teaching_ability = float(attrs.get("teaching_ability", teaching_ability))
    motivational_skill = float(attrs.get("motivational_skill", motivational_skill))
    scheme_innovation = float(attrs.get("scheme_innovation", scheme_innovation))
    player_evaluation = float(attrs.get("player_evaluation", player_evaluation))

    var personality: Dictionary = d.get("personality", {}) as Dictionary
    demanding_level = float(personality.get("demanding_level", demanding_level))
    communication_style = float(personality.get("communication_style", communication_style))

    var specs: Dictionary = d.get("specializations", {}) as Dictionary
    speed_specialist = bool(specs.get("speed_specialist", speed_specialist))
    strength_specialist = bool(specs.get("strength_specialist", strength_specialist))
    technique_specialist = bool(specs.get("technique_specialist", technique_specialist))

    var career: Dictionary = d.get("career", {}) as Dictionary
    years_experience = int(career.get("years_experience", years_experience))
    tenure_at_current_program = int(career.get("tenure_at_current_program", tenure_at_current_program))
    career_wins = int(career.get("career_wins", career_wins))
    career_losses = int(career.get("career_losses", career_losses))

    var contract: Dictionary = d.get("contract", {}) as Dictionary
    contract_years_remaining = int(contract.get("years_remaining", contract_years_remaining))
    salary = float(contract.get("salary", salary))
```

### Coaching Staff Structure

```gdscript
# Team coaching staff organization
var coaching_staff: Dictionary = {
    "head_coach": Coach,  # One head coach per team
    "position_coaches": {
        "QB": Coach,
        "RB": Coach,
        "WR": Coach,
        "OL": Coach,
        "DL": Coach,
        "LB": Coach,
        "DB": Coach,
        "SPEC": Coach
    }
}
```

### Position Group Mapping

```gdscript
# Position to position group mapping
const POSITION_GROUPS = {
    "QB": "QB",
    "RB": "RB",
    "WR": "WR",
    "TE": "WR",  # TEs coached by WR coach
    "OL": "OL",
    "DL": "DL",
    "EDGE": "DL",  # EDGE coached by DL coach
    "LB": "LB",
    "CB": "DB",
    "S": "DB",
    "K": "SPEC",
    "P": "SPEC"
}

func get_position_group(position: String) -> String:
    return POSITION_GROUPS.get(position, "")
```

## Coaching Impact Formulas

### 1. Head Coach Multiplier

```gdscript
# Head Coach: Program-wide culture and organization
# Range: [0.95, 1.10] (moderate impact, broad influence)
func calculate_head_coach_multiplier(head_coach: Coach) -> float:
    if head_coach == null:
        return 1.0  # No head coach defaults to neutral

    var teaching := head_coach.teaching_ability
    var motivation := head_coach.motivational_skill
    var innovation := head_coach.scheme_innovation

    # Average of three core attributes
    var avg := (teaching + motivation + innovation) / 3.0

    # Normalize to [0, 1] range (40-60 covers ~80% of coaches)
    var normalized := (avg - 40.0) / 20.0
    normalized = clamp(normalized, 0.0, 1.0)

    # Map to [0.95, 1.10] multiplier range
    return 0.95 + (normalized * 0.15)

# Example outputs:
# Elite HC (avg=70): (70-40)/20 = 1.5 → clamped to 1.0 → 0.95 + 0.15 = 1.10
# Good HC (avg=60): (60-40)/20 = 1.0 → 0.95 + 0.15 = 1.10
# Average HC (avg=50): (50-40)/20 = 0.5 → 0.95 + 0.075 = 1.025
# Below Avg HC (avg=40): (40-40)/20 = 0.0 → 0.95 + 0.0 = 0.95
# Poor HC (avg=30): (30-40)/20 = -0.5 → clamped to 0.0 → 0.95
```

### 2. Position Coach Multiplier

```gdscript
# Position Coach: Position-specific technique and scheme expertise
# Range: [0.90, 1.20] (stronger impact, narrow focus)
func calculate_position_coach_multiplier(
    position_coach: Coach,
    player_position: String
) -> float:
    if position_coach == null:
        return 1.0

    # Verify coach specializes in player's position group
    var player_group := get_position_group(player_position)
    var coach_group := position_coach.position_group

    if player_group != coach_group:
        return 1.0  # Wrong position coach has no impact

    var teaching := position_coach.teaching_ability

    # Check for specializations
    var specialization_bonus := 0.0
    if position_coach.speed_specialist:
        specialization_bonus = 0.05
    elif position_coach.strength_specialist:
        specialization_bonus = 0.05
    elif position_coach.technique_specialist:
        specialization_bonus = 0.05

    # Normalize teaching ability to [0, 1]
    var normalized := (teaching - 40.0) / 20.0
    normalized = clamp(normalized, 0.0, 1.0)

    # Map to [0.90, 1.20] base range
    var base := 0.90 + (normalized * 0.30)

    # Add specialization bonus
    return base + specialization_bonus

# Example outputs:
# Elite PC with specialization (teaching=70, specialist=true):
#   (70-40)/20 = 1.5 → clamped to 1.0 → 0.90 + 0.30 + 0.05 = 1.25
# Good PC (teaching=60): (60-40)/20 = 1.0 → 0.90 + 0.30 = 1.20
# Average PC (teaching=50): (50-40)/20 = 0.5 → 0.90 + 0.15 = 1.05
# Poor PC (teaching=35): (35-40)/20 = -0.25 → clamped to 0.0 → 0.90
```

### 3. Coach-Player Fit

```gdscript
# Coach-Player Fit: Personality alignment bonus
# Range: [0.98, 1.05] (small but meaningful impact)
func calculate_coach_player_fit(
    position_coach: Coach,
    player: Dictionary
) -> float:
    if position_coach == null:
        return 1.0

    var coach_demanding := position_coach.demanding_level
    var coach_communication := position_coach.communication_style

    var stats: Dictionary = player.get("stats", {}) as Dictionary
    var work_ethic := float(stats.get("work_ethic", 50.0))
    var coachability := float(stats.get("coachability", 50.0))

    # Fit calculation: Lower difference = better fit
    # Demanding coach + high work_ethic player = good fit
    # Good communicator + high coachability player = good fit

    var demanding_fit := 1.0 - abs(coach_demanding - work_ethic) / 50.0
    var communication_fit := 1.0 - abs(coach_communication - coachability) / 50.0

    # Average the two fit dimensions
    var avg_fit := (demanding_fit + communication_fit) / 2.0
    avg_fit = clamp(avg_fit, 0.0, 1.0)

    # Map to [0.98, 1.05] range
    return 0.98 + (avg_fit * 0.07)

# Example outputs:
# Perfect fit (diff=0 for both): 1.0 + 1.0 → avg=1.0 → 0.98 + 0.07 = 1.05
# Good fit (avg diff=10): (1.0-0.2) + (1.0-0.2) → avg=0.8 → 0.98 + 0.056 = 1.036
# Poor fit (avg diff=25): (1.0-0.5) + (1.0-0.5) → avg=0.5 → 0.98 + 0.035 = 1.015
# Terrible fit (diff=50 for both): 0.0 + 0.0 → avg=0.0 → 0.98
```

### 4. Combined Coaching Multiplier

```gdscript
# Combined Coaching Multiplier: Integrates all coaching factors
# Range: [0.85, 1.25] (capped at factor level)
func calculate_combined_coaching_multiplier(
    head_coach: Coach,
    position_coach: Coach,
    player: Dictionary
) -> float:
    var hc_mult := calculate_head_coach_multiplier(head_coach)
    var pc_mult := calculate_position_coach_multiplier(
        position_coach,
        String(player.get("position", ""))
    )
    var fit_mult := calculate_coach_player_fit(position_coach, player)

    var combined := hc_mult * pc_mult * fit_mult

    # Cap at factor level (prevents extreme coaching impact)
    return clamp(combined, 0.85, 1.25)

# Example outputs:
# Elite coaching + perfect fit:
#   1.10 (HC) × 1.25 (PC+spec) × 1.05 (fit) = 1.44 → capped to 1.25
#
# Good coaching + good fit:
#   1.05 (HC) × 1.15 (PC) × 1.03 (fit) = 1.25
#
# Average coaching + average fit:
#   1.00 (HC) × 1.05 (PC) × 1.00 (fit) = 1.05
#
# Poor coaching + poor fit:
#   0.95 (HC) × 0.90 (PC) × 0.98 (fit) = 0.84 → capped to 0.85
```

## Coach Generation

### Generation Strategy

```gdscript
# scripts/generation/CoachGenerator.gd
extends RefCounted
class_name CoachGenerator

const NamesHelper = preload("res://scripts/generation/helpers/NamesHelper.gd")

# Generate a full coaching staff for a team
func generate_coaching_staff(
    team_id: String,
    league: String,
    program_quality: float,  # 0.5-1.5 range (affects coach quality)
    rng: RandomNumberGenerator
) -> Dictionary:
    var staff := {
        "head_coach": generate_head_coach(team_id, league, program_quality, rng),
        "position_coaches": {}
    }

    # Generate position coaches for each group
    for group in ["QB", "RB", "WR", "OL", "DL", "LB", "DB", "SPEC"]:
        staff["position_coaches"][group] = generate_position_coach(
            team_id,
            league,
            group,
            program_quality,
            rng
        )

    return staff

# Generate head coach
func generate_head_coach(
    team_id: String,
    league: String,
    program_quality: float,
    rng: RandomNumberGenerator
) -> Coach:
    var coach := Coach.new()
    coach.id = "HC_%s_%s" % [team_id, rng.randi()]
    coach.first_name = NamesHelper.random_first_name(rng)
    coach.last_name = NamesHelper.random_last_name(rng)
    coach.age = rng.randi_range(35, 65)
    coach.role = "head_coach"
    coach.team_id = team_id
    coach.league = league

    # Attribute generation (Gaussian distribution, biased by program quality)
    var quality_bias := (program_quality - 1.0) * 15.0  # -7.5 to +7.5 bias

    coach.teaching_ability = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)
    coach.motivational_skill = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)
    coach.scheme_innovation = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)
    coach.player_evaluation = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)

    # Personality (no program bias, pure Gaussian)
    coach.demanding_level = _clamped_gaussian(50.0, 15.0, rng)
    coach.communication_style = _clamped_gaussian(50.0, 15.0, rng)

    # Specializations (10% chance for each, mutually exclusive)
    var spec_roll := rng.randf()
    if spec_roll < 0.10:
        coach.speed_specialist = true
    elif spec_roll < 0.20:
        coach.strength_specialist = true
    elif spec_roll < 0.30:
        coach.technique_specialist = true

    # Experience (correlated with age)
    coach.years_experience = max(0, coach.age - 25 + rng.randi_range(-5, 5))
    coach.tenure_at_current_program = rng.randi_range(0, 5)

    # Contract (higher quality programs offer longer contracts)
    coach.contract_years_remaining = int(2 + program_quality * 2)  # 2-5 years

    return coach

# Generate position coach
func generate_position_coach(
    team_id: String,
    league: String,
    position_group: String,
    program_quality: float,
    rng: RandomNumberGenerator
) -> Coach:
    var coach := Coach.new()
    coach.id = "PC_%s_%s_%s" % [team_id, position_group, rng.randi()]
    coach.first_name = NamesHelper.random_first_name(rng)
    coach.last_name = NamesHelper.random_last_name(rng)
    coach.age = rng.randi_range(28, 55)
    coach.role = "position_coach"
    coach.position_group = position_group
    coach.team_id = team_id
    coach.league = league

    var quality_bias := (program_quality - 1.0) * 15.0

    coach.teaching_ability = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)
    coach.motivational_skill = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)
    coach.scheme_innovation = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)
    coach.player_evaluation = _clamped_gaussian(50.0 + quality_bias, 15.0, rng)

    coach.demanding_level = _clamped_gaussian(50.0, 15.0, rng)
    coach.communication_style = _clamped_gaussian(50.0, 15.0, rng)

    # Position coaches more likely to have specializations (15% each)
    var spec_roll := rng.randf()
    if spec_roll < 0.15:
        coach.speed_specialist = true
    elif spec_roll < 0.30:
        coach.strength_specialist = true
    elif spec_roll < 0.45:
        coach.technique_specialist = true

    coach.years_experience = max(0, coach.age - 25 + rng.randi_range(-3, 3))
    coach.tenure_at_current_program = rng.randi_range(0, 4)
    coach.contract_years_remaining = int(1 + program_quality * 2)  # 1-4 years

    return coach

# Helper: Gaussian distribution clamped to [20, 80]
func _clamped_gaussian(mean: float, stddev: float, rng: RandomNumberGenerator) -> float:
    var value := rng.randfn(mean, stddev)
    return clamp(value, 20.0, 80.0)
```

### Program Quality Bias

**Elite programs attract better coaches**:
- Program quality 1.5 → +7.5 attribute bias → Average coach attributes ~57.5
- Program quality 1.0 → +0.0 attribute bias → Average coach attributes ~50.0
- Program quality 0.7 → -4.5 attribute bias → Average coach attributes ~45.5

**Distribution examples**:
```
Elite program (quality=1.5):
  - Average HC attributes: 57.5 (σ=15) → 42.5-72.5 for 68% of coaches
  - Elite HCs (top 5%): 82.5+ (clamped to 80)
  - Coaching multiplier: ~1.07 average, 1.10 for elite

Average program (quality=1.0):
  - Average HC attributes: 50.0 (σ=15) → 35-65 for 68% of coaches
  - Coaching multiplier: ~1.00 average, 1.08 for elite

Weak program (quality=0.7):
  - Average HC attributes: 45.5 (σ=15) → 30.5-60.5 for 68% of coaches
  - Coaching multiplier: ~0.98 average, 1.05 for best coaches
```

## Coach Lifecycle

### Annual Retention Check

```gdscript
# scripts/world/CoachLifecycle.gd
extends RefCounted
class_name CoachLifecycle

# Annual retention check for all coaches
func process_coach_retention(
    coaching_staff: Dictionary,
    program: Dictionary,
    year: int,
    rng: RandomNumberGenerator
) -> Dictionary:
    var changes := {
        "head_coach_changed": false,
        "position_coaches_changed": []
    }

    # Check head coach retention
    var head_coach: Coach = coaching_staff.get("head_coach")
    if head_coach != null:
        if not _check_retention(head_coach, program, rng):
            changes["head_coach_changed"] = true
            coaching_staff["head_coach"] = _hire_replacement(
                head_coach,
                program,
                rng
            )

    # Check position coach retention
    var position_coaches: Dictionary = coaching_staff.get("position_coaches", {}) as Dictionary
    for group in position_coaches.keys():
        var coach: Coach = position_coaches[group]
        if coach != null:
            if not _check_retention(coach, program, rng):
                changes["position_coaches_changed"].append(group)
                position_coaches[group] = _hire_replacement(
                    coach,
                    program,
                    rng
                )

    return changes

# Retention probability calculation
func _check_retention(
    coach: Coach,
    program: Dictionary,
    rng: RandomNumberGenerator
) -> bool:
    var tenure := coach.tenure_at_current_program
    var contract_years := coach.contract_years_remaining
    var program_success := float(program.get("recent_win_pct", 0.5))
    var program_quality := float(program.get("program_quality", 1.0))

    # Base retention: 80% (most coaches stay)
    var retention_chance := 0.80

    # Tenure stability (veteran coaches more stable)
    if tenure < 2:
        retention_chance -= 0.12  # New coaches higher turnover
    elif tenure < 4:
        retention_chance -= 0.05
    elif tenure >= 6:
        retention_chance += 0.08  # Veteran coaches very stable

    # Contract security
    if contract_years == 0:
        retention_chance -= 0.25  # Expired contract, likely to leave
    elif contract_years == 1:
        retention_chance -= 0.10  # Last year, uncertain future
    elif contract_years >= 4:
        retention_chance += 0.05  # Long contract, secure

    # Program success (wins matter most for HC retention)
    if coach.role == "head_coach":
        if program_success < 0.35:
            retention_chance -= 0.25  # Losing HCs get fired
        elif program_success < 0.45:
            retention_chance -= 0.12  # Below average HCs at risk
        elif program_success > 0.70:
            retention_chance += 0.08  # Winning HCs stay (or get poached)
    else:
        # Position coaches less affected by win/loss
        if program_success < 0.30:
            retention_chance -= 0.10  # Staff turnover on bad teams
        elif program_success > 0.75:
            retention_chance += 0.03  # Good programs retain staff

    # Program quality (elite programs have more turnover due to poaching)
    if program_quality > 1.3:
        retention_chance -= 0.05  # Elite programs: coaches get poached
    elif program_quality < 0.8:
        retention_chance += 0.05  # Weak programs: coaches stay (fewer opportunities)

    # Clamp to reasonable range [0.50, 0.95]
    retention_chance = clamp(retention_chance, 0.50, 0.95)

    return rng.randf() < retention_chance

# Hire replacement coach (deterministic based on program quality)
func _hire_replacement(
    departing_coach: Coach,
    program: Dictionary,
    rng: RandomNumberGenerator
) -> Coach:
    var program_quality := float(program.get("program_quality", 1.0))
    var team_id := String(program.get("id", ""))
    var league := String(program.get("league", "college"))

    var generator := CoachGenerator.new()

    if departing_coach.role == "head_coach":
        return generator.generate_head_coach(team_id, league, program_quality, rng)
    else:
        return generator.generate_position_coach(
            team_id,
            league,
            departing_coach.position_group,
            program_quality,
            rng
        )

# Age coaches and update career stats
func age_coaches(coaching_staff: Dictionary, team_record: Dictionary) -> void:
    var head_coach: Coach = coaching_staff.get("head_coach")
    if head_coach != null:
        head_coach.age += 1
        head_coach.years_experience += 1
        head_coach.tenure_at_current_program += 1
        head_coach.contract_years_remaining = max(0, head_coach.contract_years_remaining - 1)

        var wins := int(team_record.get("wins", 0))
        var losses := int(team_record.get("losses", 0))
        head_coach.career_wins += wins
        head_coach.career_losses += losses

    var position_coaches: Dictionary = coaching_staff.get("position_coaches", {}) as Dictionary
    for coach in position_coaches.values():
        if coach != null:
            coach.age += 1
            coach.years_experience += 1
            coach.tenure_at_current_program += 1
            coach.contract_years_remaining = max(0, coach.contract_years_remaining - 1)
```

### Retention Probability Examples

**Elite Program (quality=1.5), New Head Coach (tenure=1), Winning (win%=0.68)**:
- Base: 0.80
- New coach: -0.12
- Winning: +0.08
- Elite program: -0.05
- **Final: 0.71 (71% retention)**

**Average Program (quality=1.0), Veteran Position Coach (tenure=6), Average Record (win%=0.52)**:
- Base: 0.80
- Veteran: +0.08
- Average record: +0.00
- **Final: 0.88 (88% retention)**

**Weak Program (quality=0.7), Losing Head Coach (tenure=3, win%=0.28), Expired Contract**:
- Base: 0.80
- Moderate tenure: -0.05
- Losing: -0.25
- Expired contract: -0.25
- Weak program: +0.05
- **Final: 0.50 (50% retention) → Capped minimum**

## Integration with Development System

### Context Enrichment

```gdscript
# In CollegeSeason.gd or development context preparation
func enrich_development_context_with_coaching(
    players: Array,
    coaching_staff: Dictionary,
    program: Dictionary
) -> Array:
    var head_coach: Coach = coaching_staff.get("head_coach")
    var position_coaches: Dictionary = coaching_staff.get("position_coaches", {}) as Dictionary

    for player in players:
        var p: Dictionary = player as Dictionary
        var position := String(p.get("position", ""))
        var position_group := get_position_group(position)
        var position_coach: Coach = position_coaches.get(position_group)

        # Calculate coaching quality for this player
        var coaching_quality := _calculate_coaching_quality(
            head_coach,
            position_coach
        )

        # Add coaching context
        var context: Dictionary = p.get("development_context", {}) as Dictionary
        context["coaching"] = {
            "head_coach": head_coach.to_dict() if head_coach else {},
            "position_coach": position_coach.to_dict() if position_coach else {},
            "coaching_quality": coaching_quality,
            "head_coach_multiplier": calculate_head_coach_multiplier(head_coach),
            "position_coach_multiplier": calculate_position_coach_multiplier(position_coach, position),
            "coach_player_fit": calculate_coach_player_fit(position_coach, p)
        }

        p["development_context"] = context

    return players

func _calculate_coaching_quality(head_coach: Coach, position_coach: Coach) -> float:
    var hc_quality := head_coach.get_coaching_quality() if head_coach else 1.0
    var pc_quality := position_coach.get_coaching_quality() if position_coach else 1.0

    # Average of HC and PC quality
    return (hc_quality + pc_quality) / 2.0
```

### Development Application

```gdscript
# In PlayerLifecycle._apply_development_enhanced
func _apply_coaching_multiplier(
    player: Dictionary,
    development_context: Dictionary
) -> float:
    var coaching_ctx: Dictionary = development_context.get("coaching", {}) as Dictionary

    # Use pre-calculated multipliers from context enrichment
    var hc_mult := float(coaching_ctx.get("head_coach_multiplier", 1.0))
    var pc_mult := float(coaching_ctx.get("position_coach_multiplier", 1.0))
    var fit_mult := float(coaching_ctx.get("coach_player_fit", 1.0))

    var combined := hc_mult * pc_mult * fit_mult
    return clamp(combined, 0.85, 1.25)
```

## Performance Considerations

### Coaching Staff Storage

**Memory footprint per team**:
- 1 head coach: ~500 bytes
- 8 position coaches: ~4000 bytes
- **Total: ~4.5KB per team**

**Storage for 128 college teams**: 576KB (negligible)

### Retention Processing

**Annual retention check**:
- Per coach: 10 float operations + 1 RNG call
- Per team: 9 coaches × 11 operations = 99 operations
- **128 teams: ~12,700 operations** (sub-millisecond)

### Context Enrichment

**Per-player coaching context**:
- Head coach lookup: O(1)
- Position coach lookup: O(1)
- Multiplier calculation: ~20 float operations
- **Per player: ~50 operations** (minimal overhead)

## Configuration Schema

### Coaching Config (main.json)

```json
{
  "coaching": {
    "retention": {
      "base_retention_chance": 0.80,
      "tenure_modifiers": {
        "new_coach_penalty": -0.12,
        "moderate_penalty": -0.05,
        "veteran_bonus": 0.08,
        "tenure_thresholds": [2, 4, 6]
      },
      "contract_modifiers": {
        "expired_penalty": -0.25,
        "last_year_penalty": -0.10,
        "secure_bonus": 0.05,
        "secure_threshold": 4
      },
      "performance_modifiers": {
        "head_coach": {
          "losing_penalty": -0.25,
          "below_avg_penalty": -0.12,
          "winning_bonus": 0.08,
          "thresholds": [0.35, 0.45, 0.70]
        },
        "position_coach": {
          "bad_team_penalty": -0.10,
          "great_team_bonus": 0.03,
          "thresholds": [0.30, 0.75]
        }
      },
      "program_quality_modifiers": {
        "elite_poaching_penalty": -0.05,
        "weak_stability_bonus": 0.05,
        "thresholds": [0.8, 1.3]
      },
      "retention_range": [0.50, 0.95]
    },

    "impact_multipliers": {
      "head_coach_range": [0.95, 1.10],
      "position_coach_range": [0.90, 1.20],
      "specialization_bonus": 0.05,
      "coach_fit_range": [0.98, 1.05],
      "combined_coaching_cap": [0.85, 1.25]
    },

    "generation": {
      "attribute_mean": 50.0,
      "attribute_stddev": 15.0,
      "attribute_range": [20.0, 80.0],
      "program_quality_bias_factor": 15.0,
      "specialization_chance_head_coach": 0.30,
      "specialization_chance_position_coach": 0.45,
      "age_range_head_coach": [35, 65],
      "age_range_position_coach": [28, 55],
      "contract_duration_factor": 2.0
    }
  }
}
```

## Testing Strategy

### Unit Tests

1. **Coach generation**:
   - Verify attribute distributions (mean=50, σ=15)
   - Verify program quality bias (elite programs get better coaches)
   - Verify specialization rates (10% HC, 15% PC)

2. **Multiplier calculations**:
   - Test head coach multiplier range [0.95, 1.10]
   - Test position coach multiplier range [0.90, 1.20]
   - Test coach-player fit range [0.98, 1.05]
   - Test combined cap [0.85, 1.25]

3. **Retention logic**:
   - Test tenure effects (new vs veteran coaches)
   - Test contract effects (expired vs secure)
   - Test performance effects (winning vs losing)
   - Test program quality effects (elite vs weak)

### Integration Tests

1. **Full season coaching lifecycle**:
   - Generate coaching staff → Process season → Check retention → Hire replacements
   - Verify determinism (same seed = same hires/fires)
   - Verify retention rates match expected distribution (75-85% average)

2. **Development integration**:
   - Apply coaching multipliers to player development
   - Verify elite coaching produces 15-20% better development
   - Verify poor coaching produces 10-15% worse development

### Performance Tests

1. **Coaching staff generation**: <5ms for 128 teams (1152 coaches)
2. **Annual retention processing**: <10ms for 128 teams
3. **Context enrichment**: <1ms for 50-player roster

## Migration Strategy

### Backward Compatibility

```gdscript
# Migrate existing programs to have coaching staffs
func migrate_program_coaching(program: Dictionary, rng: RandomNumberGenerator) -> void:
    if program.has("coaching_staff"):
        return  # Already migrated

    var team_id := String(program.get("id", ""))
    var league := String(program.get("league", "college"))
    var program_quality := float(program.get("program_quality", 1.0))

    var generator := CoachGenerator.new()
    program["coaching_staff"] = generator.generate_coaching_staff(
        team_id,
        league,
        program_quality,
        rng
    )

# Graceful degradation (if coaching staff missing)
func get_coaching_multiplier_safe(player: Dictionary) -> float:
    var context: Dictionary = player.get("development_context", {}) as Dictionary
    var coaching_ctx: Dictionary = context.get("coaching", {}) as Dictionary

    if coaching_ctx.is_empty():
        return 1.0  # No coaching staff defaults to neutral

    return float(coaching_ctx.get("coaching_quality", 1.0))
```

## Summary

The coaching system provides 10-25% development variation through three multiplier types: head coach (±5%), position coach (±10%), and coach-player fit (±2.5%). Coaches have realistic career lifecycles with 75-85% annual retention rates influenced by tenure, performance, and program quality. The system integrates seamlessly with the enhanced player development architecture, adding minimal performance overhead (<5% processing time increase) while creating meaningful strategic depth.

Key design achievements:
- **Balanced impact**: Coaching matters but doesn't dominate (no 2x multipliers)
- **Realistic careers**: Coach turnover matches real-world patterns (20-25% annual)
- **Deterministic simulation**: All coach actions seeded via RNG
- **Performance-conscious**: <10ms annual processing for 128 teams
- **Backward compatible**: Existing saves work with default neutral coaching
