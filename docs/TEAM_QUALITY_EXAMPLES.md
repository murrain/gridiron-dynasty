# Team Quality Integration: Concrete Examples

## Overview

This document shows concrete examples of how team quality modifiers affect scout attributes in the NFL draft system.

## Configuration

From `/home/patrick/Documents/code/gridiron-dynasty/configs/sports/american_football/main.json`:

```json
"draft_team_quality": {
    "enabled": true,
    "quality_tiers": {
        "elite": {
            "teams": ["BAL", "SF", "GB", "PIT"],
            "base_quality": 0.75,
            "noise_modifier": 0.80,
            "skill_modifier": 1.15
        },
        "good": {
            "teams": ["KC", "BUF", "PHI", "DAL", "MIN", "DET"],
            "base_quality": 0.60,
            "noise_modifier": 0.95,
            "skill_modifier": 1.05
        },
        "average": {
            "teams": ["CIN", "LAC", "MIA", ...],
            "base_quality": 0.50,
            "noise_modifier": 1.0,
            "skill_modifier": 1.0
        },
        "poor": {
            "teams": ["HOU", "IND", "DEN", ...],
            "base_quality": 0.40,
            "noise_modifier": 1.15,
            "skill_modifier": 0.92
        },
        "terrible": {
            "teams": ["CLE"],
            "base_quality": 0.28,
            "noise_modifier": 1.35,
            "skill_modifier": 0.85
        }
    }
}
```

## Baseline Scout Template

Default national scout attributes (before quality modifiers):
- `base_skill`: 0.55 (baseline talent evaluation accuracy)
- `board_noise_sigma`: 1.8 (variance in player evaluations)
- `tape_grinder`: 0.25 (preference for film study over athleticism)

## Quality Modifier Application

### Formula

```gdscript
# 1. Skill modifier
modified_skill = clamp(base_skill * skill_modifier, 0.3, 0.9)

# 2. Noise modifier
modified_noise = clamp(board_noise_sigma * noise_modifier, 0.8, 3.5)

# 3. Tape grinder bonus (elite teams only)
if base_quality > 0.65:
    modified_tape = clamp(tape_grinder + random(0.05, 0.15), 0.0, 1.0)
```

## Concrete Examples

### Baltimore Ravens (Elite Tier)

**Configuration:**
- `base_quality`: 0.75
- `skill_modifier`: 1.15 (15% better evaluation)
- `noise_modifier`: 0.80 (20% less noise)

**Scout Attributes:**

| Attribute | Before | Calculation | After |
|-----------|--------|-------------|-------|
| base_skill | 0.55 | 0.55 × 1.15 | **0.632** |
| board_noise_sigma | 1.8 | 1.8 × 0.80 | **1.44** |
| tape_grinder | 0.25 | 0.25 + ~0.10 | **0.325** |

**Impact:**
- 15% more accurate talent evaluation
- 20% tighter rating distributions (less disagreement)
- 30% higher preference for film study

### Cleveland Browns (Terrible Tier)

**Configuration:**
- `base_quality`: 0.28
- `skill_modifier`: 0.85 (15% worse evaluation)
- `noise_modifier`: 1.35 (35% more noise)

**Scout Attributes:**

| Attribute | Before | Calculation | After |
|-----------|--------|-------------|-------|
| base_skill | 0.55 | 0.55 × 0.85 | **0.468** |
| board_noise_sigma | 1.8 | 1.8 × 1.35 | **2.43** |
| tape_grinder | 0.25 | No bonus | **0.25** |

**Impact:**
- 15% less accurate talent evaluation
- 35% wider rating distributions (more disagreement)
- No film study preference bonus

### Kansas City Chiefs (Good Tier)

**Configuration:**
- `base_quality`: 0.60
- `skill_modifier`: 1.05 (5% better evaluation)
- `noise_modifier`: 0.95 (5% less noise)

**Scout Attributes:**

| Attribute | Before | Calculation | After |
|-----------|--------|-------------|-------|
| base_skill | 0.55 | 0.55 × 1.05 | **0.578** |
| board_noise_sigma | 1.8 | 1.8 × 0.95 | **1.71** |
| tape_grinder | 0.25 | No bonus | **0.25** |

**Impact:**
- 5% more accurate talent evaluation
- 5% tighter rating distributions
- No film study preference bonus (not elite)

### Cincinnati Bengals (Average Tier)

**Configuration:**
- `base_quality`: 0.50
- `skill_modifier`: 1.0 (neutral)
- `noise_modifier`: 1.0 (neutral)

**Scout Attributes:**

| Attribute | Before | Calculation | After |
|-----------|--------|-------------|-------|
| base_skill | 0.55 | 0.55 × 1.0 | **0.55** |
| board_noise_sigma | 1.8 | 1.8 × 1.0 | **1.8** |
| tape_grinder | 0.25 | No bonus | **0.25** |

**Impact:**
- No modifiers applied (baseline performance)

## Comparative Analysis

### Skill Accuracy Rankings

1. **Ravens (Elite)**: 0.632 → Most accurate evaluations
2. **Chiefs (Good)**: 0.578 → Above average
3. **Bengals (Average)**: 0.550 → Baseline
4. **Browns (Terrible)**: 0.468 → Least accurate evaluations

**Difference:** Ravens have 35% higher skill than Browns (0.632 vs 0.468)

### Board Noise Rankings

1. **Ravens (Elite)**: 1.44 → Tightest consensus
2. **Chiefs (Good)**: 1.71 → Good consensus
3. **Bengals (Average)**: 1.80 → Baseline
4. **Browns (Terrible)**: 2.43 → Most disagreement

**Difference:** Browns have 69% more noise than Ravens (2.43 vs 1.44)

### Tape Grinder Preference

1. **Ravens (Elite)**: 0.325 → Strong film emphasis
2. **Chiefs (Good)**: 0.250 → No bonus (base_quality ≤ 0.65)
3. **Browns (Terrible)**: 0.250 → No bonus

**Threshold:** Only teams with `base_quality > 0.65` receive tape_grinder bonus

## Real-World Implications

### Elite Teams (Ravens)
- See talent more accurately (fewer busts)
- Scouts agree more (clearer consensus)
- Favor film over combine metrics
- **Result:** Better draft outcomes, fewer reaches

### Terrible Teams (Browns)
- Miss talent more often (more busts)
- Scouts disagree more (conflicting reports)
- Rely more on raw athleticism
- **Result:** Worse draft outcomes, more reaches

### Average Teams (Bengals)
- Baseline performance
- Standard scouting processes
- **Result:** League-average draft outcomes

## Clamping Safeguards

All values are clamped to prevent extreme outliers:

| Attribute | Min | Max | Reason |
|-----------|-----|-----|--------|
| base_skill | 0.3 | 0.9 | Prevents scouts from being useless or omniscient |
| board_noise_sigma | 0.8 | 3.5 | Prevents zero variance or complete chaos |
| tape_grinder | 0.0 | 1.0 | Valid probability range |

## Determinism Guarantee

All modifiers are applied deterministically:
- Same seed → Same team quality
- Same seed → Same scout attributes
- Same seed → Same draft outcomes

**Verified:** All unit tests pass determinism checks.

## Integration Points

1. **Phase 1 (Caching)**: Lines 54-59 in NflDraft.gd
   - Generates team quality once per world
   - Cached in `world_state["nfl_scouting_quality"]`

2. **Phase 4 (Application)**: Lines 381-385 in NflDraft.gd
   - Applies quality to each team's scout
   - Called during scout generation (line 72)

3. **Helper Function**: Lines 442-465 in NflDraft.gd
   - `_apply_team_quality_to_scout()`
   - Modifies base_skill, board_noise_sigma, tape_grinder

## Test Results

All tests pass:
- ✓ Quality modifiers applied correctly
- ✓ Elite teams have better scouts than poor teams
- ✓ Clamping prevents extreme values
- ✓ Determinism maintained across runs
- ✓ RNG consumption is predictable and documented

## Files Modified

1. `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflDraft.gd`
   - Added `team_quality` parameter to `_generate_team_scouts()`
   - Created `_apply_team_quality_to_scout()` helper function
   - Comprehensive documentation and RNG tracking

## Status

**Phase 4 Integration: COMPLETE**

The team quality configuration is now fully integrated and active. Better teams draft better, poor teams make more mistakes, and all behavior is deterministic and testable.
