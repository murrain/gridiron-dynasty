# Player Development & Growth Systems Guide

## Table of Contents
1. [Development Fundamentals](#development-fundamentals)
2. [College Development Factors](#college-development-factors)
3. [NFL Development Factors](#nfl-development-factors)
4. [Development Algorithms](#development-algorithms)
5. [Special Cases](#special-cases)
6. [Player Morale & Satisfaction](#player-morale--satisfaction)
7. [Technical Implementation](#technical-implementation)

---

## Development Fundamentals

### What is Player Development?

Player development in Gridiron Dynasty is the year-over-year growth (or decline) of individual player stats. Each player has:

- **Stats**: Current ability ratings (0-100 scale)
- **Potential**: Maximum achievable value for each stat (ceiling)
- **Age-based trajectory**: Growth phase → Prime phase → Decline phase

Development is **deterministic** when using the same random seed, making simulations reproducible and testable.

### Stats vs Potential

Every player has two parallel rating dictionaries:

```gdscript
player["stats"] = {
    "speed": 72.0,           # Current ability
    "awareness": 65.0,
    "throw_power": 81.0,
    # ... all other stats
}

player["potential"] = {
    "speed": 85.0,           # Maximum achievable (ceiling)
    "awareness": 78.0,
    "throw_power": 92.0,
    # ... caps for all stats
}
```

**Key Rules:**
- Stats can NEVER exceed their corresponding potential value
- Potential is set at generation and typically remains fixed
- Growth is capped by potential to prevent unrealistic development
- Young players (ages 18-22) start at 55-72% of their potential

### Rating Calculation Methodology

Overall player ratings use a **priority cascade** system:

```gdscript
# Priority 1: Pre-calculated composite_score (if present)
if player.has("composite_score"):
    return player["composite_score"]

# Priority 2: Pre-calculated core_avg (if present)
if player.has("core_avg"):
    return player["core_avg"]

# Priority 3: Position-specific core stats average
var position := player.get("position")
var core_stats := positions_cfg[position]["core_stats"]
var core_sum := 0.0
for stat in core_stats:
    core_sum += player.get(stat, 50.0)
return core_sum / core_stats.size()

# Priority 4: Simple average of all numeric stats (fallback)
```

**Example (QB):**
- Core stats: `["throw_power", "throw_accuracy", "awareness", "decision_making"]`
- QB with stats: [85, 82, 78, 80] → Overall = **81.25**

### How Skills Change Over Time

Player development follows a **three-phase lifecycle**:

1. **Growth Phase** (age < peak_age): Rapid stat increases
2. **Prime Phase** (peak_age to decline_start): Minimal changes, peak performance
3. **Decline Phase** (age >= decline_start): Gradual stat decreases

Each phase has different base progress ranges and multipliers.

---

## College Development Factors

### Age and Experience Effects

College players progress through **four years of eligibility**:

```
Freshman (Year 1) → Sophomore (Year 2) → Junior (Year 3) → Senior (Year 4)
```

**Age-Based Phases:**
- Most college players are in the **Growth Phase** (ages 18-24)
- Rapid stat increases: +4.5 to +9.5 points annually (base range)
- Position-specific peak ages vary (QB: 27, RB: 24)

**Development by College Year:**
- Freshmen: Full growth phase benefits
- Sophomores: Continue rapid development
- Juniors: Peak growth, may declare for NFL draft early if elite (rating 85+)
- Seniors: Final growth year, automatic draft eligibility if rating ≥ 65.0

### Playing Time Impact (Starters vs Backups)

Playing time is modeled via the **usage multiplier**:

```gdscript
# Determined randomly each season
starter_chance = 0.45  # 45% become starters

if random() < starter_chance:
    usage = 1.2  # Starter: +20% development rate
else:
    usage = 0.8  # Backup: -20% development rate
```

**Impact on Development:**
- **Starters** (usage = 1.2): Develop 20% faster due to game experience
- **Backups** (usage = 0.8): Develop 20% slower due to limited reps
- Usage multiplier applies to ALL stats during growth phase

**Example:**
```
Base growth: +6.0 points
Starter: 6.0 × 1.2 = +7.2 points
Backup: 6.0 × 0.8 = +4.8 points
```

### Program Strength Influence

College program quality affects development through **program_quality multiplier**:

```gdscript
# Based on college eliteness rating (0-100)
program_quality = eliteness / 100.0

# Examples:
# Elite program (eliteness = 85): program_quality = 0.85
# Mid-tier program (eliteness = 50): program_quality = 0.50
# Weak program (eliteness = 25): program_quality = 0.25
```

**Combined with other factors**, this can create **significant differences**:
- Elite program + starter: Strong development environment
- Weak program + backup: Stunted growth trajectory

### Coaching Quality Effects

**Current State (Phase 1):**
- Coaching quality is represented by `coach_specialization` multiplier
- Currently a **placeholder** (always = 1.0)
- No actual coaching staff simulation yet

**Planned Implementation (PLAYER_GROWTH_DEPTH_ARCHITECTURE.md):**
- Head coach: Program-wide multiplier (0.95-1.10 range)
- Position coaches: Position-specific multipliers (0.90-1.20 range)
- Coach-player fit: Personality alignment bonuses (0.98-1.05)
- Coaching turnover: Annual retention checks based on program success

### Training/Practice Systems

**Not Currently Implemented.**

Development is driven by:
- Age-based curves
- Usage (playing time)
- Program quality
- Competition tier
- Scheme fit (see below)

### Position-Specific Development

Each position has a **development curve** that defines growth patterns:

```json
{
  "QB": {
    "development": {
      "peak_age": 27,
      "decline_start": 31,
      "curve": "late"  // QBs develop slowly but peak later
    }
  },
  "RB": {
    "development": {
      "peak_age": 24,
      "decline_start": 27,
      "curve": "early"  // RBs peak early, decline faster
    }
  }
}
```

**Three Curve Types:**

| Curve | Growth Mult | Prime Mult | Decline Mult | Position Examples |
|-------|-------------|------------|--------------|-------------------|
| Early | 1.1x        | 0.70x      | 1.15x        | RB, WR, CB        |
| Mid   | 1.0x        | 0.65x      | 1.00x        | Most positions    |
| Late  | 0.9x        | 0.60x      | 0.85x        | QB, OL, DL        |

**Interpretation:**
- **Early curve** (RB): Fast growth in college, peak at 24, rapid decline at 27+
- **Late curve** (QB): Slow growth in college, peak at 27, slower decline at 31+

---

## NFL Development Factors

### Rookie Development Curves

NFL rookies typically enter at **age 21-22** and are still in the **Growth Phase**:

```gdscript
# NFL development context
program_quality = 1.0  # NFL is top tier
competition_tier = 1.1  # Highest competition (10% boost)
usage = 0.85-1.1  # Based on years in league
```

**Rookie Year (Year 0):**
- Base usage = 0.85 (rookie, limited playing time)
- Still in growth phase (age 21-22)
- +4.5 to +9.5 base points × 0.85 = **+3.8 to +8.1 points**

**Second Year:**
- Base usage = 0.95 (more opportunities)
- Growth phase continues
- +4.5 to +9.5 × 0.95 = **+4.3 to +9.0 points**

### Prime Years (Peak Performance)

Players enter **Prime Phase** when reaching position-specific peak age:

- QB: Peak at **27**, prime until **31**
- RB: Peak at **24**, prime until **27**
- WR/CB: Peak at **25**, prime until **29**
- OL/DL: Peak at **26**, prime until **30**

**Prime Phase Characteristics:**
```gdscript
# Much smaller growth range
prime_growth_min = 0.5
prime_growth_max = 1.5

# Position-specific prime multiplier (typically 0.60-0.70)
delta = random(0.5, 1.5) × prime_multiplier
```

**Example (QB in prime):**
```
Random draw: 1.2
Prime multiplier: 0.60
Result: +1.2 × 0.60 = +0.72 points per stat
```

**Purpose:** Maintain peak ability with minimal change.

### Aging Decline

When age >= decline_start, players enter **Decline Phase**:

```gdscript
decline_min = 0.4
decline_max = 1.6

# Decline is NEGATIVE (stat loss)
raw_draw = random(0.4, 1.6)
delta = -raw_draw × decline_mult × wear_multiplier
```

**Wear Accumulation:**
```gdscript
# Wear tracked over career
wear = {
    "snaps": 650 per year × position_multiplier,
    "collisions": 220 per year × position_multiplier,
    "injury_count": injuries accumulated
}

# Wear affects decline rate
wear_multiplier = 1.0 + (
    (snaps / 8000.0) +
    (collisions / 2600.0) +
    (injury_count / 6.0)
) × 0.2
```

**Example (Veteran RB):**
```
Age: 30 (decline phase)
Snaps: 6500 (career)
Collisions: 2200
Injuries: 4
Wear multiplier: 1.0 + (0.81 + 0.85 + 0.67) × 0.2 = 1.47

Decline: -1.2 × 1.15 (early curve) × 1.47 = -2.03 points
```

### Contract Year Motivation

**Not Currently Implemented.**

Contract years do not affect development rates. Contract tracking exists for roster management but does not influence player progression.

### Playing Time Correlation

NFL usage is **years-based** rather than random:

```gdscript
var years_in_nfl = contract.years_total - contract.years_remaining

if years_in_nfl == 0:
    usage = 0.85  # Rookie
elif years_in_nfl == 1:
    usage = 0.95  # Second year
elif years_in_nfl >= 4:
    usage = 1.1   # Veteran starter

# Add randomness: ±0.1
usage = clamp(usage + random(-0.1, 0.1), 0.7, 1.3)
```

**Veteran Advantage:**
- 4+ year veterans get **+10% development boost** (usage = 1.1)
- Rookies face **-15% penalty** (usage = 0.85)
- Reflects depth chart positioning and coaching trust

---

## Development Algorithms

### How is Growth Calculated Each Year?

The development pipeline runs **once per year** for each player in `PlayerLifecycle.gd`:

```gdscript
# 1. Determine phase (growth, prime, or decline)
if age < peak_age:
    phase = "growth"
elif age < decline_start:
    phase = "prime"
else:
    phase = "decline"

# 2. Roll random base progress for each stat
for stat in stats.keys():
    if phase == "growth":
        raw_draw = random(4.5, 9.5)
        delta = raw_draw × growth_multiplier
    elif phase == "prime":
        raw_draw = random(0.5, 1.5)
        delta = raw_draw × prime_multiplier
    else:  # decline
        raw_draw = random(0.4, 1.6)
        delta = -raw_draw × decline_multiplier × wear_multiplier

    # 3. Apply context modifiers
    delta *= combined_multiplier

    # 4. Apply scheme fit (growth phase only)
    if delta > 0 and scheme_score > 0:
        var role = stat_role(position, stat)
        var role_weight = scheme_role_weights[role]
        delta *= (1.0 + scheme_score × role_weight)

    # 5. Cap by annual progress limit
    delta = clamp(delta, -12.0, 12.0)

    # 6. Apply to stat (respecting 0-100 bounds)
    new_value = clamp(current + delta, 0.0, 100.0)

    # 7. Cap by potential (growth only)
    if delta > 0:
        new_value = min(new_value, potential[stat])

    stats[stat] = new_value
```

### RNG Involvement for Variability

**Deterministic RNG Usage:**
```gdscript
# Each stat gets exactly ONE random draw per year
for stat in stats:
    raw_draw = rng.randf_range(base_min, base_max)  # RNG CALL
    # ... apply multipliers ...
```

**Determinism Guarantees:**
- Same seed → Same random draws → Same development outcomes
- Parallel processing uses per-player derived seeds: `splitmix64(master_seed + player_index)`
- Bootstrap mode can skip development reports (memory optimization) without affecting determinism

**Sources of Variance:**
1. **Base progress draw**: Different each year per stat
2. **Usage determination**: Random starter/backup assignment each season
3. **Scheme fit score**: Random compatibility with team scheme
4. **Injury occurrences**: Random injury events affect suppression

### Determinism in Development

**Reproducibility:**
```bash
# Same seed produces identical results
world_seed = 12345
result1 = simulate_years(players, seed=12345)
result2 = simulate_years(players, seed=12345)
assert result1 == result2  # Guaranteed identical
```

**Seed Derivation:**
```gdscript
# World year seed
year_seed = Rand.splitmix64(base_seed + year)

# Phase seed (college_season, nfl_season, etc.)
phase_seed = Rand.splitmix64(year_seed ^ phase_hash)

# Player seed (parallel processing)
player_seed = Rand.splitmix64(master_seed + player_index)
```

### Cap Limits (Can't Exceed Potential)

**Hard Ceiling Enforcement:**
```gdscript
# BEFORE potential check
new_value = 87.3  # Calculated after all modifiers

# AFTER potential check
potential_cap = 85.0
new_value = min(87.3, 85.0)  # Clamped to 85.0

# Flag for reporting
capped_by_potential = true
```

**Development Reports Track This:**
```gdscript
{
    "stat": "speed",
    "before": 82.0,
    "potential": 85.0,
    "delta_unclamped": 5.3,
    "delta": 5.3,
    "after": 85.0,
    "capped_by_potential": true  # Hit ceiling
}
```

**Implication:**
- Players hitting potential ceilings see diminishing returns
- "High floor, low ceiling" players plateau early
- "Low floor, high ceiling" players develop longer

### Position-Specific Growth Rates

Growth rates are modified by **position development curves**:

```json
"curve_multipliers": {
    "early": { "growth": 1.1, "prime": 0.70, "decline": 1.15 },
    "mid":   { "growth": 1.0, "prime": 0.65, "decline": 1.0 },
    "late":  { "growth": 0.9, "prime": 0.60, "decline": 0.85 }
}
```

**RB (Early Curve) vs QB (Late Curve):**

| Phase | RB Growth | QB Growth | Difference |
|-------|-----------|-----------|------------|
| Growth (age 18-24) | +7.5 avg × 1.1 = **+8.25** | +7.5 avg × 0.9 = **+6.75** | RB +22% faster |
| Prime (age 24-27) | +1.0 avg × 0.70 = **+0.70** | +1.0 avg × 0.60 = **+0.60** | RB +17% faster |
| Decline (age 27+) | -1.0 avg × 1.15 = **-1.15** | -1.0 avg × 0.85 = **-0.85** | RB -35% faster decline |

**Result:** RBs develop faster early but burn out quicker. QBs are slower to develop but maintain peak longer.

---

## Special Cases

### Injuries and Recovery

**Active Injury Suppression:**
```gdscript
# When player has active injury
var severity_levels = ["minor", "moderate", "severe", "career_threatening"]
var suppression_per_level = 0.25  # 25% reduction per severity level

if injury.status == "active":
    var severity_index = severity_levels.find(injury.severity)
    var suppression = (severity_index + 1) × 0.25

    # Apply to relevant stats
    for affected_stat in injury.affected_stats:
        stats[affected_stat] *= (1.0 - suppression)
```

**Example (Moderate Hamstring Injury):**
```
Severity: moderate (index 1)
Suppression: (1 + 1) × 0.25 = 0.50 (50% reduction)
Affected stats: ["speed", "agility"]

Before injury:
  speed = 78.0
  agility = 75.0

During injury:
  speed = 78.0 × 0.50 = 39.0 (50% reduced)
  agility = 75.0 × 0.50 = 37.5
```

**Recovery Timeline:**
```gdscript
injury = {
    "recovery_timeline": {
        "status": "active",  // or "recovered"
        "years_remaining": 2  // Years until full recovery
    }
}

# Each year, decrement years_remaining
years_remaining -= 1
if years_remaining <= 0:
    status = "recovered"
```

**Long-Term Penalties (Permanent):**
```gdscript
# After career-threatening injury
if injury.severity == "career_threatening":
    for stat in injury.affected_stats:
        potential[stat] -= 8.0  # Permanent ceiling reduction
        stats[stat] -= 5.0       # Immediate stat loss
```

### Transfers and Adaptation

**Transfer Portal System (PA6.3):**

Players enter transfer portal based on **morale**:

```gdscript
# Calculate transfer probability
var morale = player.morale  # 0-100 scale

if morale > 70:
    transfer_prob = 0.05  # 5% (happy)
elif morale >= 40:
    transfer_prob = 0.15  # 15% (neutral)
else:
    transfer_prob = 0.40  # 40% (unhappy)

# Seniors never transfer (graduating)
if college_year >= 4:
    transfer_prob = 0.0

# Roll for transfer decision
if random() < transfer_prob:
    enter_transfer_portal(player)
```

**Adaptation Period:**
- **Not currently implemented** as a mechanic
- Players transferring do not face explicit development penalties
- Future enhancement could add adaptation modifiers for first year at new school

### Practice Squad Development

**Not currently implemented.**

NFL practice squads are not simulated in Phase 1. All rostered players follow standard development paths regardless of depth chart position (approximated via usage multiplier).

### Redshirt Seasons

**Not explicitly implemented**, but can occur implicitly:

- Players with **no stats** for a year get **neutral satisfaction (50.0)**
- Development still occurs (they still age and develop)
- No special "redshirt" flag or rule
- Could model as: `usage = 0.5` (very limited development)

---

## Player Morale & Satisfaction

### Phase 1 Implementation (PA6.1-PA6.3)

The morale system affects player development and retention. Implemented in `PlayerMorale.gd` as a pure, stateless utility.

### How Satisfaction is Calculated

Satisfaction is calculated **annually after each season** using three weighted factors:

```gdscript
satisfaction = (
    playing_time_score × 0.40 +
    awards_score × 0.30 +
    team_success_score × 0.30
)
```

**1. Playing Time Score (40% weight):**
```gdscript
base = 50.0  # Neutral

if games_started >= 8:
    base += 20.0  # Starter
elif games_started >= 4:
    base += 10.0  # Regular backup
else:
    base -= 10.0  # Rarely plays

# Participation bonus
participation_rate = games_played / expected_season_length
base += participation_rate × 10.0

score = clamp(base, 0.0, 100.0)
```

**2. Awards Score (30% weight):**
```gdscript
score = 0.0

if won_OPOY or won_DPOY:
    score += 25.0
if won_OROY or won_DROY:
    score += 15.0
if All_Pro_First_Team:
    score += 20.0
if All_Pro_Second_Team:
    score += 15.0
if Pro_Bowl:
    score += 10.0

score = clamp(score, 0.0, 100.0)
```

**3. Team Success Score (30% weight):**
```gdscript
score = 50.0  # Neutral

if national_champion:
    score += 20.0
elif playoff_appearance:
    score += 10.0

if wins > 8:
    score += 5.0
elif wins < 5:
    score -= 5.0

score = clamp(score, 0.0, 100.0)
```

### Impact on Development

Morale affects development through a **multiplicative modifier**:

```gdscript
# Morale ranges from 0-100, neutral = 50
dev_rate_multiplier = morale / 50.0

# Examples:
# morale = 75: multiplier = 1.5 (50% faster development)
# morale = 50: multiplier = 1.0 (neutral)
# morale = 25: multiplier = 0.5 (50% slower development)
```

**Applied During Development:**
```gdscript
# In _apply_development
var morale = player.get("morale", 50.0)
var morale_mult = morale / 50.0

# Add to combined multiplier
combined_multiplier *= morale_mult

# Example:
# Base delta = +6.0 points
# Morale = 75 (happy player)
# Final delta = 6.0 × 1.5 = +9.0 points
```

**Multi-Year Cumulative Effect:**
```gdscript
# Morale updates each year based on satisfaction
morale_change = (satisfaction - 50.0) × 0.3

# Example: 3-year trajectory
Year 1: satisfaction = 70, morale = 50 + (70-50)×0.3 = 56
Year 2: satisfaction = 75, morale = 56 + (75-50)×0.3 = 63.5
Year 3: satisfaction = 80, morale = 63.5 + (80-50)×0.3 = 72.5
```

### Transfer Decisions

Transfer probability is determined by morale thresholds:

```gdscript
if college_year >= 4:
    return 0.0  # Seniors never transfer

if morale > 70:
    return 0.05  # 5% chance (happy)
elif morale >= 40:
    return 0.15  # 15% chance (neutral)
else:
    return 0.40  # 40% chance (unhappy)
```

**Process:**
1. Calculate satisfaction after season
2. Update morale based on satisfaction trend
3. Determine transfer probability
4. Roll for transfer decision (1 RNG call per player)
5. Add to transfer portal if triggered

**Transfer Portal Storage:**
```gdscript
world_state["transfer_portal"][year] = [
    {
        "player_id": "hs-2020-1234",
        "transfer_year": 2024,
        "previous_team_id": "team_michigan",
        "morale": 32.0,
        "satisfaction": 28.0,
        # ... full player dict
    }
]
```

### Award Recognition Effects

Awards significantly boost satisfaction:

**Impact Examples:**
```
Scenario 1: Backup with no awards
- Playing time: 40 (backup)
- Awards: 0
- Team success: 55 (winning record)
- Satisfaction: 40×0.4 + 0×0.3 + 55×0.3 = 32.5 (LOW)

Scenario 2: Starter with All-Pro
- Playing time: 70 (starter)
- Awards: 20 (All-Pro 1st)
- Team success: 65 (playoff)
- Satisfaction: 70×0.4 + 20×0.3 + 65×0.3 = 53.5 (NEUTRAL)

Scenario 3: Starter with OPOY + Championship
- Playing time: 80 (full starter)
- Awards: 25 (OPOY)
- Team success: 70 (champion)
- Satisfaction: 80×0.4 + 25×0.3 + 70×0.3 = 60.5 (GOOD)
```

---

## Technical Implementation

### Core Files

**Primary Development Logic:**
- `/scripts/world/PlayerLifecycle.gd` - Core development algorithms (455-730)
  - `advance_one_year()` - Serial processing of players
  - `advance_one_year_parallel()` - Multi-threaded processing
  - `_apply_development()` - Phase-based stat progression
  - `_apply_injury()` - Injury suppression and recovery
  - `_should_retire()` - Retirement probability checks

**Season Handlers:**
- `/scripts/world/CollegeSeason.gd` - College season lifecycle (12-179)
  - `_apply_development_context()` - Usage and competition tier
  - Game simulation integration
  - Draft declaration logic

- `/scripts/world/NflSeason.gd` - NFL season lifecycle (24-181)
  - `_apply_nfl_development_context()` - Years-based usage
  - Contract expiration handling
  - Retirement checks

**Morale System:**
- `/scripts/core/player_agency/PlayerMorale.gd` - Satisfaction calculations (85-467)
  - `calculate_satisfaction()` - Three-factor weighted formula
  - `update_morale()` - Multi-year cumulative tracking
  - `determine_transfers()` - Transfer portal decisions

**Rating Calculations:**
- `/scripts/core/rating/PlayerRatingCalculator.gd` - Overall rating logic (27-72)

### Configuration Structure

**Main Configuration** (`configs/sports/american_football/main.json`):

```json
{
  "annual_base_progress_min": 4.5,
  "annual_base_progress_max": 9.5,
  "annual_progress_cap": 12.0,

  "development": {
    "prime_growth_min": 0.5,
    "prime_growth_max": 1.5,
    "decline_min": 0.4,
    "decline_max": 1.6,
    "curve_multipliers": {
      "early": {"growth": 1.1, "prime": 0.70, "decline": 1.15},
      "mid": {"growth": 1.0, "prime": 0.65, "decline": 1.0},
      "late": {"growth": 0.9, "prime": 0.60, "decline": 0.85}
    }
  },

  "wear": {
    "snaps_per_year": 650,
    "collisions_per_year": 220,
    "decline_per_wear": 0.2
  },

  "retirement": {
    "min_age": 27,
    "soft_cap_age": 33,
    "max_age": 40,
    "base_chance": 0.02,
    "age_chance_per_year": 0.04
  }
}
```

**Position Configuration** (`configs/sports/american_football/positions.json`):

```json
{
  "QB": {
    "core_stats": ["throw_power", "throw_accuracy", "awareness", "decision_making"],
    "development": {
      "peak_age": 27,
      "decline_start": 31,
      "curve": "late"
    }
  },
  "RB": {
    "core_stats": ["speed", "agility", "balance"],
    "development": {
      "peak_age": 24,
      "decline_start": 27,
      "curve": "early"
    }
  }
}
```

### Performance Optimizations

**Parallel Processing** (F6, P3 optimizations):
```gdscript
# Automatic parallelization for large rosters
if players.size() >= 100:
    # Use ThreadPool with per-player derived seeds
    var threads = OS.get_processor_count()
    PlayerLifecycle.advance_one_year_parallel(
        players,
        positions_cfg,
        main_cfg,
        stats_cfg,
        rng,
        development_context,
        threads
    )
```

**Config Caching**:
```gdscript
# Pre-extract config values once per season
var dev_config = DevelopmentConfig.new(positions_cfg, main_cfg)
var ret_config = RetirementConfig.new(main_cfg)

# ~5% time reduction via O(1) member access vs O(log n) dict lookup
```

**Selective Copying** (F4 optimization):
```gdscript
# Only deep-copy mutable nested structures
# Immutable fields (name, position, IDs) use shallow copy
# ~70% reduction in memory allocations
var p = player.duplicate(false)  # Shallow
p["stats"] = player["stats"].duplicate(true)  # Deep
p["potential"] = player["potential"].duplicate(true)
p["wear"] = player["wear"].duplicate(true)
```

### Development Reports

**Report Structure:**
```gdscript
{
    "age": 21,
    "phase": "growth",
    "stat_entries": [
        {
            "stat": "speed",
            "before": 72.0,
            "potential": 85.0,
            "raw_draw": 6.2,
            "multiplier": 1.1,  // Growth curve
            "delta_unclamped": 7.5,
            "delta": 7.5,
            "clamped": false,
            "capped_by_potential": false,
            "after": 79.5
        }
    ],
    "decline_multiplier": 1.0,
    "context_modifiers": {
        "program_quality": 0.85,
        "usage": 1.2,
        "competition_tier": 1.0
    },
    "injury_impacts": {
        "active": [],
        "recovered": []
    }
}
```

**Bootstrap Mode:**
```gdscript
# Skip development reports during world initialization (memory optimization)
options = {"skip_reports": true}
PlayerLifecycle.advance_one_year(players, ..., options)
```

### Example Development Scenarios

**Scenario 1: Elite College QB (Growth Phase)**
```
Age: 20
Position: QB (late curve)
Phase: growth
College: Elite program (quality = 0.90)
Role: Starter (usage = 1.2)

Base draw: random(4.5, 9.5) = 7.0
Growth multiplier: 0.9 (late curve)
Combined context: 0.90 × 1.2 = 1.08

Delta = 7.0 × 0.9 × 1.08 = 6.8 points per stat
```

**Scenario 2: NFL Veteran RB (Decline Phase)**
```
Age: 30
Position: RB (early curve)
Phase: decline
NFL: Top tier (quality = 1.0, competition = 1.1)
Veteran: 6 years (usage = 1.1)
Wear: High (snaps = 5200, collisions = 1800, injuries = 3)

Base draw: random(0.4, 1.6) = 1.1
Decline multiplier: 1.15 (early curve)
Wear multiplier: 1.0 + (0.65 + 0.69 + 0.50) × 0.2 = 1.37
Combined context: 1.0 × 1.1 = 1.1

Delta = -1.1 × 1.15 × 1.37 × 1.1 = -1.90 points per stat
```

**Scenario 3: Unhappy Backup (Morale Impact)**
```
Age: 21
Position: WR
Phase: growth
Satisfaction: 35 (backup, losing team, no awards)
Morale: 40 (accumulated dissatisfaction)

Base draw: 6.5
Growth multiplier: 1.0
Context: 0.50 × 0.8 = 0.40 (weak program + backup)
Morale multiplier: 40 / 50 = 0.80

Delta = 6.5 × 1.0 × 0.40 × 0.80 = 2.08 points
Transfer probability: 40% (low morale)
```

---

## Summary

Player development in Gridiron Dynasty is a **deterministic, multi-factor system** that simulates realistic career trajectories:

- **Three-phase lifecycle**: Growth → Prime → Decline
- **Position-specific curves**: RBs peak early, QBs peak late
- **Context-sensitive**: Program quality, playing time, competition tier
- **Morale-driven**: Player satisfaction affects development and retention
- **Injury-aware**: Active injuries suppress stats, long-term penalties reduce potential
- **Potential-capped**: Stats cannot exceed generated ceilings

The system balances **realism** (position-specific aging, wear accumulation) with **game balance** (combined multiplier caps, potential ceilings) to create diverse player careers without extreme outliers.

**Key Tuning Knobs:**
- `annual_base_progress_min/max`: Base growth rate (currently 4.5-9.5)
- `curve_multipliers`: Position-specific pacing (early/mid/late)
- `combined_multiplier` caps: Prevents runaway growth (0.7-1.5 range)
- `wear.decline_per_wear`: Aging acceleration (currently 0.2)
- Morale weights: Playing time (40%), Awards (30%), Team success (30%)

For technical implementation details, see:
- `/docs/architecture/player_growth/PLAYER_GROWTH_DEPTH_ARCHITECTURE.md` (planned enhancements)
- `/scripts/world/PlayerLifecycle.gd` (core algorithms)
- `/scripts/core/player_agency/PlayerMorale.gd` (satisfaction system)
