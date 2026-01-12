# Player Growth Depth Architecture

## Executive Summary

This document defines an enhanced player development system that introduces contextual depth factors while maintaining the system's core strengths: determinism, performance, and balance. The enhancement adds six factor categories that affect player development trajectories, creating diverse career arcs without introducing runaway complexity or min-maxing incentives.

**Design Philosophy**: Add depth through multiplicative factors with hard caps to prevent extreme outcomes. Each factor should feel impactful but never dominate. The system must remain deterministic (RNG-seeded), performant (no >20% bootstrap slowdown), and backward compatible.

## Current System Analysis

### Existing Architecture (PlayerLifecycle.gd:455-730)

**Core Mechanics**:
- **Phase-based development**: Growth (age < peak), Prime (peak to decline_start), Decline (decline_start+)
- **Base progress ranges**: 4.5-9.5 points annual growth, 0.5-1.5 prime, 0.4-1.6 decline
- **Curve multipliers**: Early/Mid/Late position-specific curves (e.g., RB = early, QB = late)
- **Development context**: Existing modifiers (program_quality, usage, competition_tier, scheme_fit)
- **Combined multiplier capping**: Currently clamped to [0.7, 1.5] to prevent crushing penalties

**Existing Context Factors** (main.json:28-45):
```json
{
  "program_quality": 1.0,        // Team/program quality
  "coach_specialization": 1.0,   // Position coach quality (placeholder)
  "usage": 1.0,                  // Playing time multiplier
  "competition_tier": 1.0,       // Competition level
  "rehab_quality": 1.0           // Injury recovery support
}
```

**Current Data Model** (Player.gd:54-57):
```gdscript
@export var wear: Dictionary = {"snaps": 0, "collisions": 0, "injury_count": 0}
@export var development_report: Array = []
var injuries: Array[Dictionary] = []
// stats include: work_ethic, coachability (lines 34-35 in stats.json)
```

**Performance Characteristics**:
- Processes ~6000 players/year during bootstrap
- Parallel processing enabled (100+ player threshold)
- Config-optimized with pre-extracted values (DevelopmentConfig)
- Selective copying reduces memory allocations by 70%

### Strengths to Preserve

1. **Determinism**: Identical seed produces identical results across runs
2. **Performance**: Sub-second processing for thousands of players
3. **Balance**: Combined multiplier caps prevent extreme outcomes
4. **Clarity**: Development reports track all changes with rationale
5. **Flexibility**: Context-based modifiers support different career phases

### Gaps to Address

1. **Personality traits exist but aren't used**: work_ethic, coachability in stats but no development impact
2. **No coaching system**: coach_specialization is a placeholder (always 1.0)
3. **Program quality is one-dimensional**: Single float doesn't capture program complexity
4. **Limited situational factors**: No age-curve variation, peer competition, or academic factors
5. **Position-specific curves are static**: All QBs develop identically, no late bloomers

## Enhanced System Design

### Factor Taxonomy

The enhanced system introduces six contextual factor categories, each contributing to the combined development multiplier:

```
combined_multiplier = base_multiplier
                    × personality_multiplier
                    × coaching_multiplier
                    × environment_multiplier
                    × situational_multiplier
                    × age_adjustment_multiplier
                    × position_curve_multiplier
```

All multipliers are **clamped at the factor level** before combination, and the final combined multiplier maintains the existing [0.7, 1.5] cap.

### 1. Personality Traits System

**Location**: Player stats (already exist: work_ethic, coachability)

**Design Principles**:
- Traits are **immutable after generation** (no trait evolution to maintain determinism)
- Normal distribution (mean=50, σ=15) ensures most players are average
- Multiplicative impact with diminishing returns (logarithmic scaling)
- Traits interact with contextual factors (e.g., coachability amplifies coaching quality)

**Mathematical Model**:

```gdscript
# Work Ethic: Base development rate modifier
# Range: 30-70 for 95% of players (mean=50, σ=15)
# Effect: ±15% development rate at extremes

func _work_ethic_multiplier(work_ethic: float) -> float:
    # Normalized to 0-1 scale, then scaled to [0.85, 1.15]
    var normalized := (work_ethic - 30.0) / 40.0  # 30-70 → 0-1
    normalized = clamp(normalized, 0.0, 1.0)
    return 0.85 + (normalized * 0.30)  # 0.85-1.15 range

# Coachability: Coaching effectiveness amplifier
# Interacts with coaching_quality to modulate coaching impact
# High coachability makes great coaching more valuable

func _coachability_multiplier(coachability: float, coaching_quality: float) -> float:
    # Coachability affects how much coaching quality matters
    var coachability_factor := (coachability - 50.0) / 50.0  # -1 to +1
    var coaching_impact := (coaching_quality - 1.0)  # e.g., 1.15 - 1.0 = 0.15

    # High coachability amplifies coaching impact by up to 50%
    # Low coachability dampens coaching impact by up to 50%
    var adjusted_impact := coaching_impact * (1.0 + coachability_factor * 0.5)
    return 1.0 + adjusted_impact

# Combined personality multiplier (capped before combination)
func _personality_multiplier(stats: Dictionary, coaching_quality: float) -> float:
    var work_ethic := float(stats.get("work_ethic", 50.0))
    var coachability := float(stats.get("coachability", 50.0))

    var work_mult := _work_ethic_multiplier(work_ethic)
    var coach_mult := _coachability_multiplier(coachability, coaching_quality)

    var combined := work_mult * coach_mult
    return clamp(combined, 0.80, 1.25)  # Cap at factor level
```

**Trait Distribution Strategy**:
- Generate during player creation (PlayerGenerator._make_single_player)
- Use Gaussian distribution: `rng.randfn(50.0, 15.0)` clamped to [20, 80]
- Most players (68%) fall in 35-65 range (modest impact)
- Extremes (2.5%) at 20-30 or 70-80 (noticeable but not dominating)

**Trait Interaction Examples**:
- High work ethic (70) + Low coachability (30) = 1.10 × 0.90 = 0.99x (solid baseline, coach-agnostic)
- Average traits (50/50) + Great coach (1.15) = 1.00 × 1.15 = 1.15x (standard improvement)
- Low work ethic (30) + High coachability (70) + Elite coach (1.20) = 0.85 × 1.20 = 1.02x (coach rescues poor work ethic)

### 2. Coaching System

**Location**: New Coach model (separate from Team), referenced in development_context

**Design Principles**:
- Head coach provides program-wide multiplier (culture, organization)
- Position coaches provide position-group-specific multipliers (technique, scheme)
- Coach quality follows normal distribution (like players)
- Coach turnover occurs probabilistically (stability impacts programs)
- Coach-player fit is calculated via personality alignment

**Data Model**:

```gdscript
# Coach model (new file: scripts/core/models/Coach.gd)
class_name Coach extends Resource

@export var id: String = ""
@export var name: String = ""
@export var role: String = ""  # "head_coach", "position_coach"
@export var position_group: String = ""  # "QB", "OL", "DB", etc. (for position coaches)

# Coaching attributes (0-100 scale, normal distribution)
@export var teaching_ability: float = 50.0      # How well they teach technique
@export var motivational_skill: float = 50.0    # Player buy-in and effort
@export var scheme_innovation: float = 50.0     # Scheme fit optimization
@export var player_evaluation: float = 50.0     # Talent identification (recruiting)

# Personality (for coach-player fit)
@export var demanding_level: float = 50.0       # Fits with high work_ethic players
@export var communication_style: float = 50.0   # Fits with high coachability players

# Specializations (binary flags)
@export var speed_specialist: bool = false      # +10% speed/acceleration development
@export var strength_specialist: bool = false   # +10% strength/blocking development
@export var technique_specialist: bool = false  # +10% position-core skills

# Experience and stability
@export var years_experience: int = 0
@export var tenure_at_current_program: int = 0
```

**Mathematical Model**:

```gdscript
# Head Coach Impact: Program-wide culture multiplier
func _head_coach_multiplier(coach: Dictionary) -> float:
    var teaching := float(coach.get("teaching_ability", 50.0))
    var motivation := float(coach.get("motivational_skill", 50.0))
    var innovation := float(coach.get("scheme_innovation", 50.0))

    # Average of three attributes, normalized to multiplier
    var avg := (teaching + motivation + innovation) / 3.0
    var normalized := (avg - 40.0) / 20.0  # 40-60 → 0-1 (covers ~80% of coaches)
    normalized = clamp(normalized, 0.0, 1.0)

    # Head coach impact range: [0.95, 1.10]
    # Smaller than position coach (broader influence, less specialization)
    return 0.95 + (normalized * 0.15)

# Position Coach Impact: Position-specific technique multiplier
func _position_coach_multiplier(coach: Dictionary, player: Dictionary) -> float:
    var teaching := float(coach.get("teaching_ability", 50.0))
    var position_group := String(coach.get("position_group", ""))
    var player_pos := String(player.get("position", ""))

    # Verify coach specializes in player's position group
    if not _position_matches_group(player_pos, position_group):
        return 1.0  # No impact if wrong position coach

    # Check for specializations
    var specialization_bonus := 0.0
    if bool(coach.get("speed_specialist", false)):
        specialization_bonus = 0.05
    elif bool(coach.get("strength_specialist", false)):
        specialization_bonus = 0.05
    elif bool(coach.get("technique_specialist", false)):
        specialization_bonus = 0.05

    var normalized := (teaching - 40.0) / 20.0
    normalized = clamp(normalized, 0.0, 1.0)

    # Position coach impact range: [0.90, 1.20]
    # Larger than head coach (narrow focus, deep expertise)
    var base := 0.90 + (normalized * 0.30)
    return base + specialization_bonus

# Coach-Player Fit: Personality alignment bonus
func _coach_player_fit(coach: Dictionary, player: Dictionary) -> float:
    var coach_demanding := float(coach.get("demanding_level", 50.0))
    var coach_communication := float(coach.get("communication_style", 50.0))
    var work_ethic := float(player.get("stats", {}).get("work_ethic", 50.0))
    var coachability := float(player.get("stats", {}).get("coachability", 50.0))

    # High-demanding coach + high work_ethic player = good fit
    # Good communicator + high coachability = good fit
    var demanding_fit := 1.0 - abs(coach_demanding - work_ethic) / 50.0  # 0-1
    var communication_fit := 1.0 - abs(coach_communication - coachability) / 50.0

    var avg_fit := (demanding_fit + communication_fit) / 2.0

    # Fit provides small bonus: [0.98, 1.05]
    # Good fit matters, but not dramatically
    return 0.98 + (avg_fit * 0.07)

# Combined coaching multiplier (includes head coach + position coach + fit)
func _coaching_multiplier(
    head_coach: Dictionary,
    position_coach: Dictionary,
    player: Dictionary
) -> float:
    var hc_mult := _head_coach_multiplier(head_coach)
    var pc_mult := _position_coach_multiplier(position_coach, player)
    var fit_mult := _coach_player_fit(position_coach, player)

    var combined := hc_mult * pc_mult * fit_mult
    return clamp(combined, 0.85, 1.25)  # Cap at factor level
```

**Coach Turnover Model**:

```gdscript
# Annual coach retention check
func _check_coach_retention(coach: Dictionary, program: Dictionary, rng: RandomNumberGenerator) -> bool:
    var tenure := int(coach.get("tenure_at_current_program", 0))
    var program_success := float(program.get("recent_win_pct", 0.5))

    # Base retention: 85% (most coaches stay)
    var retention_chance := 0.85

    # Tenure stabilizes (peak at 5+ years)
    if tenure < 3:
        retention_chance -= 0.10  # New coaches more likely to leave
    elif tenure >= 5:
        retention_chance += 0.05  # Veteran coaches more stable

    # Success affects retention
    if program_success < 0.35:
        retention_chance -= 0.15  # Losing programs lose coaches
    elif program_success > 0.65:
        retention_chance += 0.05  # Winning programs retain coaches

    retention_chance = clamp(retention_chance, 0.50, 0.95)
    return rng.randf() < retention_chance
```

**Position Group Mapping**:
```gdscript
const POSITION_GROUPS = {
    "QB": ["QB"],
    "RB": ["RB"],
    "WR": ["WR", "TE"],
    "OL": ["OL"],
    "DL": ["DL", "EDGE"],
    "LB": ["LB"],
    "DB": ["CB", "S"],
    "SPEC": ["K", "P"]
}
```

### 3. Program Environment System

**Location**: Enhanced Team/Program model with multi-dimensional program strength

**Design Principles**:
- Replace one-dimensional program_quality with multi-factor environment score
- Separate dimensions: Facilities, Tradition, Resources, Academic Support
- Elite programs excel in multiple dimensions but not all
- Conference strength affects competition quality
- Team success provides dynamic bonus (championship runs boost development)

**Enhanced Program Model**:

```gdscript
# Extended Team/Program data (add to existing Team model or program context)
var program_environment: Dictionary = {
    "facilities_quality": 50.0,      # 0-100: Weight room, training equipment, medical staff
    "tradition_strength": 50.0,      # 0-100: Historical success, culture, expectations
    "resource_investment": 50.0,     # 0-100: Budget, staff size, support personnel
    "academic_support": 50.0,        # 0-100: Tutoring, study halls, academic services
    "conference_tier": "mid",        # "elite", "mid", "low"
    "recent_success": 0.5            # 0-1: Rolling 3-year win percentage
}
```

**Mathematical Model**:

```gdscript
# Multi-dimensional environment score
func _environment_multiplier(program: Dictionary) -> float:
    var env: Dictionary = program.get("program_environment", {}) as Dictionary

    var facilities := float(env.get("facilities_quality", 50.0))
    var tradition := float(env.get("tradition_strength", 50.0))
    var resources := float(env.get("resource_investment", 50.0))
    var academics := float(env.get("academic_support", 50.0))

    # Weighted environment score
    # Facilities and resources matter most for development
    var weighted_score := (
        facilities * 0.35 +
        tradition * 0.20 +
        resources * 0.30 +
        academics * 0.15
    )

    # Normalize to [0.90, 1.15] range
    var normalized := (weighted_score - 40.0) / 20.0
    normalized = clamp(normalized, 0.0, 1.0)
    return 0.90 + (normalized * 0.25)

# Conference strength multiplier
func _conference_tier_multiplier(conference_tier: String) -> float:
    match conference_tier:
        "elite": return 1.08  # SEC, Big Ten (better competition drives growth)
        "mid": return 1.00    # ACC, Big 12, Pac-12
        "low": return 0.95    # Group of 5
        _: return 1.00

# Recent success bonus (dynamic, changes with performance)
func _success_bonus(recent_success: float) -> float:
    # Championship-caliber teams (>0.75 win%) get development boost
    # Winning culture, confidence, playoff experience
    if recent_success > 0.75:
        return 1.05
    elif recent_success > 0.60:
        return 1.02
    elif recent_success < 0.35:
        return 0.97  # Losing culture slightly dampens development
    else:
        return 1.00

# Combined environment multiplier
func _combined_environment_multiplier(program: Dictionary) -> float:
    var env: Dictionary = program.get("program_environment", {}) as Dictionary

    var env_mult := _environment_multiplier(program)
    var conf_mult := _conference_tier_multiplier(String(env.get("conference_tier", "mid")))
    var success_mult := _success_bonus(float(env.get("recent_success", 0.5)))

    var combined := env_mult * conf_mult * success_mult
    return clamp(combined, 0.85, 1.20)  # Cap at factor level
```

**Program Archetypes**:

```gdscript
# "Blue Blood" - Elite in all dimensions
{
    "facilities_quality": 85.0,
    "tradition_strength": 90.0,
    "resource_investment": 88.0,
    "academic_support": 70.0,
    "conference_tier": "elite",
    "recent_success": 0.72
}
# Environment multiplier: ~1.12, Conference: 1.08, Success: 1.02 → Combined: ~1.23 (capped to 1.20)

# "Development Program" - Strong coaching, modest resources
{
    "facilities_quality": 55.0,
    "tradition_strength": 45.0,
    "resource_investment": 52.0,
    "academic_support": 65.0,
    "conference_tier": "mid",
    "recent_success": 0.58
}
# Environment multiplier: ~0.97, Conference: 1.00, Success: 1.00 → Combined: ~0.97

# "Rebuilding Program" - Poor recent results
{
    "facilities_quality": 48.0,
    "tradition_strength": 55.0,
    "resource_investment": 50.0,
    "academic_support": 50.0,
    "conference_tier": "mid",
    "recent_success": 0.28
}
# Environment multiplier: ~0.95, Conference: 1.00, Success: 0.97 → Combined: ~0.92
```

### 4. Situational Factors System

**Location**: Calculated dynamically in development_context based on player/team state

**Design Principles**:
- Context-dependent modifiers that change over player's career
- Competition quality matters (starter vs backup, team strength)
- Playoff/championship experience provides one-time growth spurts
- Injuries slow development during recovery (already partially implemented)
- Academic struggles reduce development (time management, eligibility pressure)

**Mathematical Model**:

```gdscript
# Playoff/Championship Experience Bonus (one-time per occurrence)
# Applied as a flat bonus to specific stats after playoff run
func _playoff_experience_bonus(
    player: Dictionary,
    playoff_depth: String,  # "conference_champ", "playoff_semifinal", "national_champ"
    rng: RandomNumberGenerator
) -> Dictionary:
    # Check if player already has this experience tag
    var tags: Array = player.get("tags", []) as Array
    var experience_key := "playoff_exp_%s" % playoff_depth

    if tags.has(experience_key):
        return {}  # Already applied this bonus

    # Add tag to prevent double-application
    tags.append(experience_key)
    player["tags"] = tags

    # Mental stats benefit most (composure, awareness, decision_making)
    var mental_stats := ["composure", "awareness", "decision_making", "confidence"]
    var bonus_range: Vector2

    match playoff_depth:
        "conference_champ":
            bonus_range = Vector2(1.0, 2.5)
        "playoff_semifinal":
            bonus_range = Vector2(2.0, 4.0)
        "national_champ":
            bonus_range = Vector2(3.0, 5.0)
        _:
            bonus_range = Vector2(0.0, 0.0)

    var bonuses := {}
    for stat in mental_stats:
        if player.get("stats", {}).has(stat):
            var bonus := rng.randf_range(bonus_range.x, bonus_range.y)
            bonuses[stat] = bonus

    return bonuses

# Starting vs Backup Impact (already partially implemented via usage)
# Enhanced: Starter quality matters more than just playing time
func _competition_quality_multiplier(
    player: Dictionary,
    roster: Array,
    usage: float
) -> float:
    var position := String(player.get("position", ""))
    var player_rating := float(player.get("overall_rating", 65.0))

    # Find other players at same position
    var position_peers := roster.filter(func(p):
        return String(p.get("position", "")) == position
    )

    if position_peers.size() <= 1:
        return 1.0  # No competition

    # Calculate average rating of position peers
    var peer_avg := 0.0
    for peer in position_peers:
        if peer != player:
            peer_avg += float(peer.get("overall_rating", 65.0))
    peer_avg /= max(1.0, float(position_peers.size() - 1))

    # High-quality competition drives growth
    var rating_gap := peer_avg - player_rating

    if usage > 1.1:  # Starter
        if rating_gap > 5.0:
            # Starter with good backup pushing them
            return 1.05
        else:
            return 1.00
    else:  # Backup
        if rating_gap < -5.0:
            # Backup behind weaker starter (should be starting)
            return 0.95  # Frustration/limited reps
        elif rating_gap > 10.0:
            # Backup behind much better starter (learning)
            return 1.03
        else:
            return 1.00

# Injury Recovery Penalty (enhance existing injury system)
func _injury_recovery_multiplier(injuries: Array, recovery_phase: String) -> float:
    if injuries.is_empty():
        return 1.0

    # Find active or recently recovered injuries
    var active_count := 0
    var recent_recovery_count := 0

    for injury in injuries:
        var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
        var status := String(timeline.get("status", "recovered"))
        var years_remaining := int(timeline.get("years_remaining", 0))

        if status == "active":
            active_count += 1
        elif status == "recovered" and years_remaining == 0:
            recent_recovery_count += 1

    # Active injuries: significant penalty (already implemented via suppression)
    # First year after recovery: moderate penalty (still regaining form)
    var penalty := 1.0

    if recent_recovery_count > 0:
        penalty -= 0.08 * float(recent_recovery_count)  # -8% per recent injury

    return clamp(penalty, 0.85, 1.0)

# Academic Performance Impact (new)
# Poor academic performance reduces development (stress, time management)
func _academic_performance_multiplier(
    player: Dictionary,
    program_academic_support: float
) -> float:
    var focus := float(player.get("stats", {}).get("focus", 50.0))
    var discipline := float(player.get("stats", {}).get("discipline", 50.0))
    var football_iq := float(player.get("stats", {}).get("football_IQ", 50.0))

    # Academic risk score (0-100, lower is riskier)
    var academic_score := (focus + discipline + football_iq) / 3.0

    # Good academic support mitigates risk
    var support_factor := program_academic_support / 100.0  # 0-1
    var adjusted_score := academic_score + (100.0 - academic_score) * support_factor * 0.3

    # Convert to multiplier
    if adjusted_score < 40.0:
        return 0.90  # Struggling academically, less time for football
    elif adjusted_score < 50.0:
        return 0.95
    else:
        return 1.00  # No academic issues

# Combined situational multiplier
func _situational_multiplier(
    player: Dictionary,
    context: Dictionary,
    roster: Array
) -> float:
    var usage := float(context.get("usage", 1.0))
    var injuries: Array = player.get("injuries", []) as Array
    var program_support := float(context.get("program_academic_support", 50.0))

    var comp_mult := _competition_quality_multiplier(player, roster, usage)
    var injury_mult := _injury_recovery_multiplier(injuries, "recovery")
    var academic_mult := _academic_performance_multiplier(player, program_support)

    var combined := comp_mult * injury_mult * academic_mult
    return clamp(combined, 0.85, 1.15)  # Cap at factor level
```

### 5. Age & Career Stage Adjustments

**Location**: Extends existing phase-based development in PlayerLifecycle

**Design Principles**:
- Physical vs Mental stat development varies by age
- "Late bloomer" potential encoded during generation
- Experience accumulation provides IQ/awareness bonuses
- Prime age varies by position (already implemented, enhance with stat-specific curves)

**Mathematical Model**:

```gdscript
# Stat-type age curves (physical vs mental development)
func _age_curve_modifier(age: int, stat_name: String, stat_type: String) -> float:
    # Physical stats peak earlier, mental stats peak later
    match stat_type:
        "physical":  # speed, acceleration, agility, strength
            if age < 23:
                return 1.10  # Rapid physical development
            elif age < 26:
                return 1.00  # Peak physical development
            elif age < 30:
                return 0.90  # Physical maintenance
            else:
                return 0.75  # Physical decline

        "mental":  # awareness, decision_making, football_IQ, anticipation
            if age < 23:
                return 0.85  # Mental stats develop slowly early
            elif age < 26:
                return 1.05  # Prime mental growth
            elif age < 30:
                return 1.10  # Peak mental development (experience accumulation)
            else:
                return 1.00  # Mental stats stable late career

        "technique":  # route_running, coverage, footwork
            if age < 23:
                return 0.95  # Technique learned over time
            elif age < 30:
                return 1.05  # Consistent technique improvement
            else:
                return 0.95  # Technique decline with physical tools

        _:
            return 1.00

# Late bloomer detection (determined at generation)
func _is_late_bloomer(player: Dictionary) -> bool:
    # Check for "LateBloomer" tag set during generation
    var tags: Array = player.get("tags", []) as Array
    return tags.has("LateBloomer")

# Late bloomer growth curve adjustment
func _late_bloomer_adjustment(player: Dictionary, age: int, base_delta: float) -> float:
    if not _is_late_bloomer(player):
        return base_delta

    # Late bloomers: -20% growth before age 24, +15% growth age 24-28
    if age < 24:
        return base_delta * 0.80
    elif age < 28:
        return base_delta * 1.15
    else:
        return base_delta

# Experience-based awareness bonus (cumulative)
func _experience_bonus(years_played: int, stat_name: String) -> float:
    # Mental stats gain small bonus per year of experience
    if stat_name not in ["awareness", "decision_making", "anticipation", "football_IQ"]:
        return 0.0

    # +0.3 points per year, capping at +3.0 after 10 years
    return min(3.0, float(years_played) * 0.3)
```

**Late Bloomer Generation Strategy**:
```gdscript
# In PlayerGenerator._make_single_player()
# 5% of players are late bloomers (identified during generation)
func _assign_late_bloomer_tag(player: Dictionary, rng: RandomNumberGenerator) -> void:
    if rng.randf() < 0.05:  # 5% chance
        if not player.has("tags"):
            player["tags"] = []
        var tags: Array = player["tags"] as Array
        tags.append("LateBloomer")
        player["tags"] = tags
```

### 6. Position-Specific Development Curves

**Location**: Extends existing position curves (already in positions.json)

**Design Principles**:
- QB mental stat development accelerates after age 24 (experience matters)
- RB physical decline starts earlier (wear accumulation)
- OL/DL develop slowly but peak later (technique + size maturation)
- WR/DB peak earlier (speed-dependent positions)

**Mathematical Model**:

```gdscript
# Position-specific stat growth modifiers
func _position_stat_multiplier(position: String, stat_name: String, age: int) -> float:
    match position:
        "QB":
            if stat_name in ["awareness", "decision_making", "anticipation", "football_IQ"]:
                # QB mental stats accelerate after age 24
                if age < 24:
                    return 0.90
                elif age < 28:
                    return 1.15  # Prime QB mental development
                else:
                    return 1.05
            return 1.00

        "RB":
            if stat_name in ["speed", "acceleration", "agility"]:
                # RB speed peaks early, declines faster
                if age < 24:
                    return 1.10
                elif age < 27:
                    return 1.00
                elif age < 30:
                    return 0.85  # Rapid decline
                else:
                    return 0.70  # Severe decline
            return 1.00

        "OL", "DL":
            if stat_name in ["strength", "blocking", "shedding_blocks"]:
                # Linemen develop slowly but peak later
                if age < 24:
                    return 0.95  # Slow early development
                elif age < 29:
                    return 1.10  # Extended prime
                else:
                    return 0.95
            return 1.00

        "WR", "CB":
            if stat_name in ["speed", "acceleration", "route_running", "coverage"]:
                # Speed positions peak early
                if age < 25:
                    return 1.08
                elif age < 29:
                    return 1.00
                else:
                    return 0.88
            return 1.00

        _:
            return 1.00
```

## Integration with Existing System

### Modified Development Flow

```gdscript
# Enhanced _apply_development (PlayerLifecycle.gd:455-592)
static func _apply_development_enhanced(
    player: Dictionary,
    dev_config: DevelopmentConfig,
    positions_cfg: Dictionary,
    stats_cfg: Dictionary,
    rng: RandomNumberGenerator,
    development_context: Dictionary,
    coaching_context: Dictionary,  # NEW: head_coach, position_coach
    environment_context: Dictionary,  # NEW: program environment
    roster_context: Array,  # NEW: full roster for peer competition
    wear_config: WearConfig = null
) -> Dictionary:
    # ... existing phase determination logic ...

    # ENHANCED: Multi-factor development modifiers
    var personality_mult := _personality_multiplier(
        player.get("stats", {}),
        float(coaching_context.get("coaching_quality", 1.0))
    )

    var coaching_mult := _coaching_multiplier(
        coaching_context.get("head_coach", {}),
        coaching_context.get("position_coach", {}),
        player
    )

    var environment_mult := _combined_environment_multiplier(
        environment_context
    )

    var situational_mult := _situational_multiplier(
        player,
        development_context,
        roster_context
    )

    # Combine all multipliers (each already capped at factor level)
    var enhanced_multiplier := (
        personality_mult *
        coaching_mult *
        environment_mult *
        situational_mult
    )

    # Apply existing combined multiplier cap [0.7, 1.5]
    enhanced_multiplier = clamp(enhanced_multiplier, 0.7, 1.5)

    # ... existing stat update logic with enhanced_multiplier ...

    # Per-stat modifiers for age/position curves
    for stat_name in stats.keys():
        # ... existing delta calculation ...

        # NEW: Age-curve adjustment
        var age_curve := _age_curve_modifier(age, stat_name, _stat_type(stat_name))
        delta *= age_curve

        # NEW: Position-specific curve
        var pos_curve := _position_stat_multiplier(position, stat_name, age)
        delta *= pos_curve

        # NEW: Late bloomer adjustment
        delta = _late_bloomer_adjustment(player, age, delta)

        # ... existing clamping and potential cap logic ...
    }

    # ... rest of existing logic ...
}
```

### Context Enrichment (CollegeSeason.gd)

```gdscript
# Enhanced _apply_development_context (CollegeSeason.gd:144-186)
func _apply_development_context_enhanced(
    players: Array,
    college: Dictionary,
    coaching_staff: Dictionary,  # NEW: head coach + position coaches
    config: Dictionary,
    rng: RandomNumberGenerator,
    year: int
) -> Array:
    var env: Dictionary = college.get("program_environment", {}) as Dictionary

    # ... existing usage/competition logic ...

    for i in range(players.size()):
        var p: Dictionary = players[i]
        var position := String(p.get("position", ""))

        # Find position coach for this player
        var position_group := _position_to_group(position)
        var position_coach: Dictionary = coaching_staff.get(position_group, {}) as Dictionary

        var context := {
            # Existing
            "program_quality": program_quality,
            "competition_tier": competition_tier,
            "usage": usage,
            "season": "college",
            "year": year,

            # NEW: Enhanced context
            "coaching": {
                "head_coach": coaching_staff.get("head_coach", {}),
                "position_coach": position_coach,
                "coaching_quality": _calculate_coaching_quality(
                    coaching_staff.get("head_coach", {}),
                    position_coach
                )
            },
            "environment": {
                "facilities_quality": float(env.get("facilities_quality", 50.0)),
                "tradition_strength": float(env.get("tradition_strength", 50.0)),
                "resource_investment": float(env.get("resource_investment", 50.0)),
                "academic_support": float(env.get("academic_support", 50.0)),
                "conference_tier": String(env.get("conference_tier", "mid")),
                "recent_success": float(env.get("recent_success", 0.5))
            },
            "roster": players  # Full roster for peer competition analysis
        }

        p["development_context"] = context

    return players
```

## Performance Considerations

### Computational Complexity

**Current System**:
- O(n) per player: 5-10 dictionary lookups, ~20 float operations per stat
- Total: ~1000 operations per player (20 stats × 50 operations)

**Enhanced System**:
- Added operations per player:
  - Personality: +10 operations (2 trait lookups, 1 multiplication)
  - Coaching: +50 operations (coach lookups, fit calculation, specialization checks)
  - Environment: +30 operations (4 dimension lookups, weighted average)
  - Situational: +100 operations (peer comparison, injury checks, academic calc)
  - Age curves: +60 operations (3 stat types × 20 stats)
  - Position curves: +40 operations (2 stat types × 20 stats)
- **Total added: ~290 operations per player** (29% increase)

**Expected Impact**:
- Best case: +15% processing time (efficient cache hits)
- Worst case: +25% processing time (cache misses, roster traversals)
- **Within 20% constraint**: Yes, with optimization

### Optimization Strategies

1. **Pre-compute coaching context** (once per roster, not per player)
2. **Cache position group mappings** (avoid repeated lookups)
3. **Batch roster peer comparisons** (single sort, multiple uses)
4. **Use stat type cache** (pre-classify physical/mental/technique stats)
5. **Defer non-critical calculations** (academic performance only every 2-3 years)

### Memory Impact

**Current System**: ~4KB per player (selective copy)

**Enhanced System**:
- Coaching context: +200 bytes (2 coach references)
- Environment context: +300 bytes (6 floats + 2 strings)
- Roster reference: +8 bytes (pointer)
- **Total: ~500 bytes per player** (12.5% increase)

**Acceptable**: Yes, 500 bytes × 6000 players = 3MB total

## Balance & Tuning

### Factor Weight Analysis

**Target outcome distribution** (80% of players should fall within):
- Combined multiplier: 0.85 - 1.20 range (baseline 1.0)
- Development rate variation: ±20% from baseline
- Elite combination (top 5%): 1.35x multiplier (capped to 1.5)
- Poor combination (bottom 5%): 0.72x multiplier (capped to 0.7)

**Factor contribution targets**:
- Personality: ±10% impact (0.90 - 1.10 typical range)
- Coaching: ±15% impact (0.88 - 1.18 typical range)
- Environment: ±12% impact (0.92 - 1.15 typical range)
- Situational: ±8% impact (0.94 - 1.08 typical range)
- Age/Position curves: ±10% per stat (stat-specific, not global)

### Validation Scenarios

**Scenario 1: Elite Program + Great Coaching + High Work Ethic**
- Personality: 1.10 (work_ethic=70)
- Coaching: 1.18 (elite HC + elite PC)
- Environment: 1.15 (blue blood program)
- Situational: 1.05 (starter, good competition)
- Combined: 1.10 × 1.18 × 1.15 × 1.05 = 1.61 → **capped to 1.50**

**Scenario 2: Average Program + Average Coaching + Average Traits**
- Personality: 1.00 (work_ethic=50)
- Coaching: 1.00 (average all around)
- Environment: 1.00 (mid-tier program)
- Situational: 1.00 (backup, no issues)
- Combined: 1.00 × 1.00 × 1.00 × 1.00 = **1.00**

**Scenario 3: Weak Program + Poor Coaching + Low Work Ethic**
- Personality: 0.87 (work_ethic=30, low coachability)
- Coaching: 0.90 (poor HC + mediocre PC)
- Environment: 0.92 (rebuilding program)
- Situational: 0.93 (injury recovery)
- Combined: 0.87 × 0.90 × 0.92 × 0.93 = 0.67 → **capped to 0.70**

**Scenario 4: High Coachability + Elite Coach (rescues poor work ethic)**
- Personality: 0.85 × 1.15 = 0.98 (work_ethic=30, coachability=70, coaching_quality=1.20)
- Coaching: 1.20 (elite coaching)
- Environment: 1.05 (above average program)
- Situational: 1.00 (average)
- Combined: 0.98 × 1.20 × 1.05 × 1.00 = 1.23

**Scenario 5: Late Bloomer QB at Age 25**
- Base development: 0.8x before age 24, 1.15x age 24-28
- Mental stat age curve: 1.10 at age 25
- QB position mental multiplier: 1.15 at age 25
- Combined stat-specific: 1.15 × 1.10 × 1.15 = 1.45x for mental stats
- Physical stats: 1.15 × 0.90 = 1.04x (late bloomer + physical peak)

### Realism Checks

**Real-world parallels**:
- Tom Brady: Late bloomer (age 27+ peak), elite coaching (Belichick), high work ethic
- Randy Moss: Elite physical tools (age 22-28 peak), variable coachability impact
- Derrick Henry: Late bloomer (age 25+ peak), position-specific prime extension

**Expected career arcs**:
- **Fast riser**: High traits + elite program → 85 rating by age 24
- **Solid starter**: Average traits + good program → 75 rating by age 26
- **Late bloomer**: Poor early + great coaching → 72 rating by age 27
- **Bust**: Low traits + poor program → 65 rating peak, early retirement

## Backward Compatibility

### Data Migration Strategy

**Existing saves compatibility**:
1. **Graceful defaults**: All new factors default to 1.0 (neutral impact)
2. **Optional context fields**: Check existence before accessing
3. **Gradual enrichment**: Generate coaching staff on next season advance
4. **Preserve existing multipliers**: work_ethic/coachability remain in stats

**Migration pseudocode**:
```gdscript
func migrate_player_development_v2(player: Dictionary) -> void:
    # Add late bloomer tag for 5% of existing players (based on player_id hash)
    if not player.has("tags"):
        player["tags"] = []

    var id_hash := hash(player.get("player_id", ""))
    if id_hash % 100 < 5:  # 5% chance (deterministic)
        var tags: Array = player["tags"] as Array
        if not tags.has("LateBloomer"):
            tags.append("LateBloomer")

    # Personality traits: already exist in stats, no migration needed
    # Coaching context: will be generated on next season advance
    # Environment: will be generated on next season advance

func migrate_program_environment(program: Dictionary) -> void:
    if not program.has("program_environment"):
        # Generate based on existing program_quality
        var quality := float(program.get("program_quality", 1.0))
        var base_score := 50.0 + (quality - 1.0) * 50.0  # 1.0 → 50, 1.5 → 75

        program["program_environment"] = {
            "facilities_quality": base_score,
            "tradition_strength": base_score,
            "resource_investment": base_score,
            "academic_support": base_score,
            "conference_tier": "mid",
            "recent_success": 0.5
        }
```

## Testing Strategy

### Unit Tests

1. **Factor calculation tests**:
   - Test personality multiplier ranges (0.80 - 1.25)
   - Test coaching multiplier with various coach combinations
   - Test environment multiplier for all archetypes
   - Test combined multiplier capping

2. **Integration tests**:
   - Test full development cycle with enhanced factors
   - Verify determinism (same seed = same outcome)
   - Test late bloomer detection and adjustment
   - Test position-specific curves

3. **Performance benchmarks**:
   - Measure processing time increase (must be <20%)
   - Measure memory footprint increase
   - Test parallel processing with enhanced factors

### Validation Tests

1. **Statistical distribution validation**:
   - Generate 10,000 players, advance 10 years
   - Verify combined multiplier distribution matches target (0.85-1.20 for 80%)
   - Verify career arc diversity (early/late bloomers, position-specific)

2. **Realism validation**:
   - Simulate known archetypes (Brady, Moss, Henry)
   - Verify QBs peak later than RBs
   - Verify elite programs produce better players (but not 2x better)

## Configuration Schema

### New Config Structure (main.json)

```json
{
  "development": {
    // Existing fields preserved
    "prime_growth_min": 0.5,
    "prime_growth_max": 1.5,
    "curve_multipliers": { ... },

    // NEW: Enhanced development factors
    "personality_traits": {
      "work_ethic_range": [0.85, 1.15],
      "coachability_amplification": 0.5,
      "trait_interaction_cap": [0.80, 1.25]
    },

    "coaching_impact": {
      "head_coach_range": [0.95, 1.10],
      "position_coach_range": [0.90, 1.20],
      "specialization_bonus": 0.05,
      "coach_fit_range": [0.98, 1.05],
      "combined_coaching_cap": [0.85, 1.25]
    },

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
    },

    "situational_factors": {
      "playoff_experience_bonuses": {
        "conference_champ": [1.0, 2.5],
        "playoff_semifinal": [2.0, 4.0],
        "national_champ": [3.0, 5.0]
      },
      "injury_recovery_penalty": -0.08,
      "academic_struggle_threshold": 40.0,
      "academic_penalty_range": [0.90, 0.95],
      "competition_quality_range": [0.95, 1.05],
      "combined_situational_cap": [0.85, 1.15]
    },

    "age_position_curves": {
      "stat_type_modifiers": {
        "physical_early": 1.10,
        "physical_prime": 1.00,
        "physical_late": 0.75,
        "mental_early": 0.85,
        "mental_prime": 1.05,
        "mental_late": 1.10,
        "technique_prime": 1.05,
        "technique_late": 0.95
      },
      "late_bloomer_adjustment": {
        "early_penalty": 0.80,
        "late_bonus": 1.15,
        "transition_age": 24,
        "peak_age": 28
      },
      "position_specific_modifiers": {
        "QB_mental_prime": 1.15,
        "RB_speed_decline": 0.85,
        "OL_strength_prime": 1.10,
        "WR_speed_prime": 1.08
      }
    },

    // Master cap (applied after all factors combined)
    "combined_multiplier_cap": [0.70, 1.50]
  }
}
```

## Summary

This enhanced player growth system introduces six contextual factor categories that create diverse player development trajectories while maintaining system balance, performance, and determinism. Key achievements:

1. **Depth without complexity**: Each factor is independently understandable
2. **Hard caps prevent extremes**: No runaway growth or crushing penalties
3. **Performance-conscious**: <20% processing time increase
4. **Backward compatible**: Existing saves work with graceful defaults
5. **Balanced outcomes**: 80% of players within ±20% of baseline development

The system enables realistic career arcs (late bloomers, position-specific primes, coaching impact) while preserving the existing architecture's strengths. Implementation can be phased (personality → coaching → environment → situational) to manage complexity and validate balance at each stage.
