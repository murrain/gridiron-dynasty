# Multi-Factor Draft Evaluation System Design

## Executive Summary

This document designs a comprehensive draft evaluation system that combines four factors:
1. **Best Player Available (BPA)** - Raw talent assessment
2. **Team Need** - Positional roster gaps
3. **Scouting Knowledge** - Team-specific evaluation accuracy
4. **Hype** - Media attention and narrative bias

The system preserves player quality as the dominant factor while introducing realistic NFL-style decision-making where teams balance talent with need, trust their scouts, and are influenced by media narratives.

---

## Current State Analysis

### Existing Evaluation Flow

```
NflDraft._score_draft_pool()
    |
    v
ScoutRuntime.score_player() -> base_score (with scout perception noise)
    |
    v
EvaluationModifierStack.evaluate() -> applies modifiers:
    - PositionTierModifier (additive: -20 to +3 OVR)
    - PositionValueModifier (additive: -5 to +5 OVR)
    - PositionNeedModifier (multiplicative: 0.0 to 1.5x)
    - SchemeFitModifier (multiplicative: 0.9 to 1.15x)
    - CoachMindsetModifier (multiplicative: 0.95 to 1.18x)
    |
    v
Final: weighted_score = base_score * final_multiplier
```

### Current Formula
```
final_score = (base_ovr + additive_total) * multiplicative_total
```

### What Works
- Position tier bonuses are now additive (fixed from multiplicative)
- Player quality dominates (a 15-point OVR gap matters more than position bonuses)
- Scheme fit and coach mindset provide meaningful variation

### What's Missing
1. **Team Need** is implemented as PositionNeedModifier but not integrated with depth analysis
2. **Scouting Knowledge** exists in ScoutRuntime but doesn't affect draft selection confidence
3. **Hype** is generated and affects scout bias, but NOT draft selection directly
4. **No team-specific hype susceptibility** - all teams treat hype the same

---

## Design Principles

### 1. Player Quality Dominates
A 15-point OVR gap should override need and hype. The #1 overall talent should go top 5 regardless of position, unless evaluated inaccurately by poor scouts.

### 2. Factors Are Additive, Not Multiplicative
Converting factors to additive OVR bonuses ensures predictable, bounded effects that don't compound unexpectedly.

### 3. Uncertainty Creates Variance
Poor scouting and high hype increase variance, causing occasional "reaches" and "steals."

### 4. Team Personality Matters
Different teams weight factors differently based on organizational philosophy.

### 5. Config-Driven Tuning
All weights and thresholds live in configuration files for easy balancing.

---

## Four-Factor Architecture

### Overview

Each factor contributes an **additive OVR bonus** that shifts the player's perceived value:

```
perceived_ovr = true_ovr
              + bpa_adjustment
              + need_bonus
              + scouting_adjustment
              + hype_bias
```

This perceived OVR is then processed through existing modifiers (position tier, scheme fit, etc.).

### Factor 1: Best Player Available (BPA)

**Status:** Already working correctly.

**Current Behavior:**
- Scout evaluates player stats with perception noise
- Returns composite score reflecting perceived talent

**Proposed Enhancement:**
- BPA is the **base score**, not a separate factor
- No changes needed - this is the foundation that other factors modify

**Weight:** 100% (implicit baseline)

---

### Factor 2: Team Need Modifier (Enhanced)

**Status:** Partially implemented in PositionNeedModifier.

**Current Behavior:**
- Checks roster count vs ideal depth
- Returns multiplier 0.0 to 1.5x

**Problem:**
- Doesn't consider starter quality (need for upgrade vs depth)
- Doesn't scale need bonus by round (reach prevention)
- Doesn't differentiate between "no starter" vs "weak starter"

**Proposed Enhancement:**

Create `TeamNeedModifier` that returns an **additive OVR bonus**:

```gdscript
# team_need_config.json
{
  "need_bonuses": {
    "critical": {
      "description": "No starter at position",
      "bonus_ovr": 8.0,
      "round_scaling": {
        "round_1": 0.6,   # +4.8 OVR in round 1 (don't reach too far)
        "round_2": 0.75,  # +6.0 OVR in round 2
        "round_3": 0.9,   # +7.2 OVR in round 3
        "round_4_plus": 1.0  # Full +8.0 OVR later
      }
    },
    "high": {
      "description": "Starter below 65 OVR or only 1 player at position",
      "bonus_ovr": 5.0,
      "round_scaling": {
        "round_1": 0.5,
        "round_2": 0.7,
        "round_3": 0.85,
        "round_4_plus": 1.0
      }
    },
    "moderate": {
      "description": "Starter 65-72 OVR or below ideal depth",
      "bonus_ovr": 3.0,
      "round_scaling": {
        "round_1": 0.4,
        "round_2": 0.6,
        "round_3": 0.8,
        "round_4_plus": 1.0
      }
    },
    "low": {
      "description": "Starter adequate but no quality backup",
      "bonus_ovr": 1.0,
      "round_scaling": {
        "round_1": 0.3,
        "round_2": 0.5,
        "round_3": 0.7,
        "round_4_plus": 1.0
      }
    },
    "none": {
      "description": "Position is well-stocked",
      "bonus_ovr": 0.0
    }
  },
  "position_importance_multipliers": {
    "QB": 1.5,    # QB need is 50% more important
    "EDGE": 1.2,  # Pass rusher need elevated
    "CB": 1.1,
    "OL": 1.0,
    "WR": 1.0,
    "LB": 0.9,
    "DL": 0.9,
    "TE": 0.8,
    "RB": 0.7,    # RB need discounted (replaceable position)
    "S": 0.8,
    "K": 0.3,     # Specialists almost never "need" driven
    "P": 0.3
  },
  "reach_prevention": {
    "description": "Minimum OVR gap to consider for need in early rounds",
    "round_1_min_ovr": 70,
    "round_2_min_ovr": 65,
    "round_3_min_ovr": 60,
    "round_4_plus_min_ovr": 50
  }
}
```

**Algorithm:**

```gdscript
func calculate_need_bonus(
    position: String,
    roster: Dictionary,
    draft_round: int,
    player_ovr: float,
    config: Dictionary
) -> float:
    # Step 1: Determine need level
    var need_level := _assess_need_level(position, roster, positions_cfg)

    # Step 2: Get base bonus for need level
    var base_bonus := config.need_bonuses[need_level].bonus_ovr

    # Step 3: Apply round scaling (prevents early-round reaches)
    var round_key := "round_1" if draft_round == 1 else \
                     "round_2" if draft_round == 2 else \
                     "round_3" if draft_round == 3 else \
                     "round_4_plus"
    var round_scale := config.need_bonuses[need_level].round_scaling[round_key]

    # Step 4: Apply position importance
    var position_mult := config.position_importance_multipliers.get(position, 1.0)

    # Step 5: Apply reach prevention floor
    var min_ovr := config.reach_prevention.get("round_%d_min_ovr" % min(draft_round, 4), 50)
    if player_ovr < min_ovr:
        return 0.0  # Don't boost clearly inferior players

    return base_bonus * round_scale * position_mult
```

**Example Scenarios:**

| Scenario | Position | Round | Base | Scale | Pos Mult | Result |
|----------|----------|-------|------|-------|----------|--------|
| No QB, elite prospect | QB | 1 | 8.0 | 0.6 | 1.5 | +7.2 OVR |
| No QB, average prospect (68 OVR) | QB | 1 | 8.0 | 0.6 | 1.5 | +7.2 OVR |
| No QB, weak prospect (62 OVR) | QB | 1 | 8.0 | -- | -- | 0.0 (below round 1 floor) |
| Weak CB (62 OVR starter) | CB | 2 | 5.0 | 0.7 | 1.1 | +3.85 OVR |
| Need depth at RB | RB | 4 | 1.0 | 1.0 | 0.7 | +0.7 OVR |

---

### Factor 3: Scouting Knowledge Modifier

**Status:** ScoutRuntime exists but knowledge level doesn't affect draft decisions.

**Current Behavior:**
- Teams scout players to improve evaluation accuracy
- Knowledge levels affect perception noise in ScoutRuntime.score_player()
- High hype causes overrating (already implemented)

**Problem:**
- Draft selection doesn't consider scouting confidence
- Unscouted players carry same weight as heavily scouted ones
- No "uncertainty penalty" for unknown quantities

**Proposed Enhancement:**

Create `ScoutingKnowledgeModifier` that adjusts confidence/variance:

```gdscript
# scouting_config.json
{
  "knowledge_levels": {
    "comprehensive": {
      "description": "Multiple in-person workouts, medical, interviews",
      "confidence_bonus_ovr": 0.0,
      "variance_reduction": 0.9,
      "minimum_scouting_hours": 40
    },
    "solid": {
      "description": "Film study + combine data + one meeting",
      "confidence_bonus_ovr": 0.0,
      "variance_reduction": 0.7,
      "minimum_scouting_hours": 20
    },
    "limited": {
      "description": "Film study + combine only",
      "confidence_bonus_ovr": -1.0,
      "variance_reduction": 0.5,
      "minimum_scouting_hours": 8
    },
    "minimal": {
      "description": "Combine data only",
      "confidence_bonus_ovr": -2.0,
      "variance_reduction": 0.3,
      "minimum_scouting_hours": 2
    },
    "unknown": {
      "description": "No direct scouting",
      "confidence_bonus_ovr": -4.0,
      "variance_reduction": 0.0,
      "minimum_scouting_hours": 0
    }
  },
  "round_risk_tolerance": {
    "round_1": {
      "unknown_penalty_multiplier": 2.0,
      "description": "High picks require certainty"
    },
    "round_2": {
      "unknown_penalty_multiplier": 1.5
    },
    "round_3": {
      "unknown_penalty_multiplier": 1.2
    },
    "round_4_plus": {
      "unknown_penalty_multiplier": 0.8,
      "description": "Late rounds tolerate more risk"
    }
  },
  "team_scouting_philosophy": {
    "analytics_heavy": {
      "description": "Trust data over gut",
      "unknown_tolerance": 0.7,
      "variance_sensitivity": 1.3
    },
    "traditional": {
      "description": "Trust scouts' eyes",
      "unknown_tolerance": 0.5,
      "variance_sensitivity": 1.0
    },
    "aggressive": {
      "description": "Swing for the fences",
      "unknown_tolerance": 1.2,
      "variance_sensitivity": 0.7
    }
  }
}
```

**Algorithm:**

```gdscript
func calculate_scouting_adjustment(
    player_id: String,
    team_id: String,
    draft_round: int,
    scouting_data: Dictionary,
    config: Dictionary
) -> float:
    # Step 1: Get knowledge level for this player
    var team_scouting := scouting_data.get(team_id, {})
    var player_knowledge := team_scouting.get(player_id, {})
    var knowledge_level := _determine_knowledge_level(player_knowledge, config)

    # Step 2: Get base confidence adjustment
    var base_adjustment := config.knowledge_levels[knowledge_level].confidence_bonus_ovr

    # Step 3: Apply round-based risk tolerance
    var round_key := "round_%d" % min(draft_round, 4)
    if draft_round >= 4:
        round_key = "round_4_plus"
    var risk_mult := config.round_risk_tolerance[round_key].unknown_penalty_multiplier

    # Step 4: Apply team philosophy
    var team := _get_team(team_id)
    var philosophy := team.get("scouting_philosophy", "traditional")
    var tolerance := config.team_scouting_philosophy[philosophy].unknown_tolerance

    # Penalties are amplified by risk_mult, reduced by tolerance
    if base_adjustment < 0:
        return base_adjustment * risk_mult * (1.0 / tolerance)

    return base_adjustment
```

**Example Scenarios:**

| Knowledge Level | Round | Risk Mult | Philosophy | Adjustment |
|-----------------|-------|-----------|------------|------------|
| Unknown | 1 | 2.0 | Traditional (0.5) | -16.0 OVR |
| Unknown | 1 | 2.0 | Analytics (0.7) | -11.4 OVR |
| Unknown | 5 | 0.8 | Aggressive (1.2) | -2.7 OVR |
| Limited | 2 | 1.5 | Traditional | -4.0 OVR |
| Comprehensive | 1 | -- | -- | 0.0 OVR |

This ensures:
- Unknown players rarely go in round 1 unless team is aggressive
- Later rounds tolerate more uncertainty (where steals happen)
- Analytics teams are more comfortable with limited data

---

### Factor 4: Hype Modifier

**Status:** HypeGenerator creates hype, ScoutRuntime.apply_hype_bias() biases perception, but draft selection doesn't use hype directly.

**Current Behavior:**
- Hype ranges 0-100 (50 = neutral)
- Heisman winner gets +25-35 hype
- All-American 1st team gets +12-18 hype
- ScoutRuntime.apply_hype_bias() adds up to +/- 4 points based on scout's hype_susceptibility

**Problem:**
- Hype only affects individual scout perception, not team draft decision
- No team-level hype susceptibility
- Award signals (Heisman) should be stronger than general buzz
- Hype shouldn't overwhelm actual talent

**Proposed Enhancement:**

Create `HypeModifier` with team-specific susceptibility and award-based signal strength:

```gdscript
# hype_draft_config.json
{
  "base_hype_effect": {
    "description": "How much raw hype affects draft evaluation",
    "max_bonus_ovr": 5.0,
    "max_penalty_ovr": -3.0,
    "neutral_hype": 50.0,
    "formula": "bonus = ((hype - 50) / 50) * max_bonus * susceptibility"
  },

  "award_signal_bonuses": {
    "description": "Direct bonuses for verified awards (on top of hype)",
    "heisman_winner": {
      "bonus_ovr": 3.0,
      "description": "Heisman validates talent, reduces risk perception"
    },
    "heisman_finalist": {
      "bonus_ovr": 1.5
    },
    "all_american_first": {
      "bonus_ovr": 1.5
    },
    "all_american_second": {
      "bonus_ovr": 0.5
    },
    "conference_poy": {
      "bonus_ovr": 1.0
    },
    "combine_standout": {
      "bonus_ovr": 0.5,
      "description": "Verified 4.3 speed, etc."
    }
  },

  "team_hype_susceptibility": {
    "description": "How much each team buys into media narratives (0.0-1.0)",
    "ranges": {
      "analytics_focused": {
        "min": 0.15,
        "max": 0.35,
        "description": "Data-driven teams largely ignore hype"
      },
      "balanced": {
        "min": 0.40,
        "max": 0.60,
        "description": "Most teams fall here"
      },
      "narrative_driven": {
        "min": 0.65,
        "max": 0.85,
        "description": "Teams that chase names and stories"
      }
    },
    "generation_weights": {
      "analytics_focused": 0.20,
      "balanced": 0.55,
      "narrative_driven": 0.25
    }
  },

  "round_hype_scaling": {
    "description": "Hype matters more in early rounds (media pressure)",
    "round_1": 1.2,
    "round_2": 1.0,
    "round_3": 0.8,
    "round_4_plus": 0.5
  },

  "hype_vs_talent_guard": {
    "description": "Prevents hype from overriding large talent gaps",
    "max_hype_boost_vs_better_player": 10.0,
    "description_detail": "A hyped 70 OVR can beat unhyped 75, but not unhyped 82"
  }
}
```

**Algorithm:**

```gdscript
func calculate_hype_adjustment(
    player: Dictionary,
    team: Dictionary,
    draft_round: int,
    config: Dictionary
) -> float:
    var hype := float(player.get("hype", 50.0))
    var awards := player.get("awards", []) as Array

    # Step 1: Calculate raw hype bonus
    var neutral := config.base_hype_effect.neutral_hype
    var max_bonus := config.base_hype_effect.max_bonus_ovr
    var max_penalty := config.base_hype_effect.max_penalty_ovr

    var hype_delta := (hype - neutral) / 50.0  # -1.0 to +1.0
    var raw_hype_bonus := 0.0
    if hype_delta >= 0:
        raw_hype_bonus = hype_delta * max_bonus
    else:
        raw_hype_bonus = hype_delta * abs(max_penalty)

    # Step 2: Apply team susceptibility
    var susceptibility := float(team.get("hype_susceptibility", 0.5))
    var hype_bonus := raw_hype_bonus * susceptibility

    # Step 3: Apply round scaling
    var round_key := "round_%d" % min(draft_round, 4)
    if draft_round >= 4:
        round_key = "round_4_plus"
    var round_scale := config.round_hype_scaling.get(round_key, 1.0)
    hype_bonus *= round_scale

    # Step 4: Add award signal bonuses (independent of susceptibility)
    var award_bonus := 0.0
    for award in awards:
        var award_key := String(award)
        if config.award_signal_bonuses.has(award_key):
            award_bonus += config.award_signal_bonuses[award_key].bonus_ovr

    # Step 5: Cap award bonus to prevent award stacking
    award_bonus = minf(award_bonus, 4.0)

    return hype_bonus + award_bonus
```

**Example Scenarios:**

| Player | Hype | Awards | Team Susceptibility | Round | Result |
|--------|------|--------|---------------------|-------|--------|
| Heisman winner | 95 | heisman_winner | 0.5 (balanced) | 1 | +5.4 OVR |
| Heisman winner | 95 | heisman_winner | 0.2 (analytics) | 1 | +4.1 OVR |
| 5-star bust | 80 | none | 0.8 (narrative) | 1 | +3.5 OVR |
| Small school stud | 35 | none | 0.5 | 1 | -1.1 OVR |
| Small school stud | 35 | none | 0.2 | 4 | -0.2 OVR |
| All-American | 70 | all_american_first | 0.5 | 2 | +1.7 OVR |

---

## Combined Evaluation Formula

### Final Formula

```
final_perceived_ovr = scout_evaluation
                    + need_bonus
                    + scouting_adjustment
                    + hype_adjustment

draft_score = (final_perceived_ovr + position_tier_bonus + position_value_bonus)
            * scheme_fit_mult
            * coach_mindset_mult
```

### Weight Summary

| Factor | Type | Range | Dominance |
|--------|------|-------|-----------|
| Scout Evaluation (BPA) | Base | 40-99 | Dominant |
| Team Need | Additive | -0 to +12 OVR | Secondary |
| Scouting Knowledge | Additive | -16 to 0 OVR | Gating |
| Hype | Additive | -3 to +9 OVR | Marginal |
| Position Tier | Additive | -20 to +3 OVR | Contextual |
| Position Value | Additive | -5 to +5 OVR | Minor |
| Scheme Fit | Multiplicative | 0.9x to 1.15x | Scaling |
| Coach Mindset | Multiplicative | 0.95x to 1.18x | Scaling |

### Maximum Total Adjustment

- **Best case:** 12 + 0 + 9 + 3 + 5 = +29 OVR, then x1.15 x1.18 = +39 OVR effective
- **Worst case:** 0 - 16 - 3 - 20 - 5 = -44 OVR, then x0.9 x0.95 = -37 OVR effective
- **Typical variance:** +/- 10 OVR (keeps talent as primary factor)

---

## Implementation Plan

### Phase 1: Config Files

Create new configuration files:

1. `configs/sports/american_football/draft_evaluation.json`
   - Team need config
   - Scouting knowledge config
   - Hype config
   - Round scaling tables

2. Update `configs/sports/american_football/college_awards.json`
   - Add award_signal_bonuses section

### Phase 2: New Modifiers

Create new modifier classes:

1. `TeamNeedModifierV2.gd` (replaces PositionNeedModifier)
   - Uses TeamNeeds.assess_team_needs() for need level
   - Applies round scaling and reach prevention
   - Additive OVR bonus

2. `ScoutingKnowledgeModifier.gd`
   - Reads team scouting data from world_state
   - Applies uncertainty penalty for unknown players
   - Round-based risk tolerance

3. `HypeModifier.gd`
   - Reads player hype from stats
   - Applies team susceptibility
   - Adds award signal bonuses

### Phase 3: Team Attributes

Add team-level attributes:

1. `hype_susceptibility: float` (0.15-0.85)
2. `scouting_philosophy: String` ("analytics_heavy", "traditional", "aggressive")

Generate these in NflTeamGenerator.

### Phase 4: Integration

Update NflDraft._score_draft_pool():

1. Add new modifiers to EvaluationModifierStack.create_draft_stack()
2. Pass scouting data and hype through EvaluationContext
3. Update logging to show factor breakdown

### Phase 5: Testing

1. **Determinism test:** Same seed produces identical results
2. **Distribution test:** Round 1 position distribution matches NFL (~15-18% EDGE, not 53%)
3. **Reach prevention test:** 60 OVR QB doesn't go top 10 due to need
4. **Hype validation test:** Heisman winner gets drafted slightly higher
5. **Scouting impact test:** Teams with comprehensive scouting trust their picks more

---

## Configuration Schema

### draft_evaluation.json

```json
{
  "version": 1,

  "team_need": {
    "need_levels": {
      "critical": { "threshold": 0, "bonus_ovr": 8.0 },
      "high": { "threshold": 1, "starter_threshold": 65, "bonus_ovr": 5.0 },
      "moderate": { "threshold": "below_ideal", "starter_threshold": 72, "bonus_ovr": 3.0 },
      "low": { "threshold": "at_ideal", "backup_needed": true, "bonus_ovr": 1.0 },
      "none": { "bonus_ovr": 0.0 }
    },
    "round_scaling": {
      "round_1": { "critical": 0.6, "high": 0.5, "moderate": 0.4, "low": 0.3 },
      "round_2": { "critical": 0.75, "high": 0.7, "moderate": 0.6, "low": 0.5 },
      "round_3": { "critical": 0.9, "high": 0.85, "moderate": 0.8, "low": 0.7 },
      "round_4_plus": { "critical": 1.0, "high": 1.0, "moderate": 1.0, "low": 1.0 }
    },
    "position_importance": {
      "QB": 1.5, "EDGE": 1.2, "CB": 1.1, "OL": 1.0, "WR": 1.0,
      "LB": 0.9, "DL": 0.9, "TE": 0.8, "RB": 0.7, "S": 0.8,
      "K": 0.3, "P": 0.3
    },
    "reach_prevention": {
      "round_1_min_ovr": 70,
      "round_2_min_ovr": 65,
      "round_3_min_ovr": 60,
      "round_4_plus_min_ovr": 50
    }
  },

  "scouting_knowledge": {
    "levels": {
      "comprehensive": { "hours_min": 40, "bonus_ovr": 0.0 },
      "solid": { "hours_min": 20, "bonus_ovr": 0.0 },
      "limited": { "hours_min": 8, "bonus_ovr": -1.0 },
      "minimal": { "hours_min": 2, "bonus_ovr": -2.0 },
      "unknown": { "hours_min": 0, "bonus_ovr": -4.0 }
    },
    "round_risk_multipliers": {
      "round_1": 2.0,
      "round_2": 1.5,
      "round_3": 1.2,
      "round_4_plus": 0.8
    },
    "philosophy_tolerance": {
      "analytics_heavy": 0.7,
      "traditional": 0.5,
      "aggressive": 1.2
    }
  },

  "hype": {
    "max_bonus_ovr": 5.0,
    "max_penalty_ovr": -3.0,
    "neutral_hype": 50.0,
    "round_scaling": {
      "round_1": 1.2,
      "round_2": 1.0,
      "round_3": 0.8,
      "round_4_plus": 0.5
    },
    "award_bonuses": {
      "heisman_winner": 3.0,
      "heisman_finalist": 1.5,
      "all_american_first": 1.5,
      "all_american_second": 0.5,
      "conference_poy": 1.0,
      "combine_standout": 0.5
    },
    "max_award_bonus": 4.0,
    "susceptibility_ranges": {
      "analytics_focused": [0.15, 0.35],
      "balanced": [0.40, 0.60],
      "narrative_driven": [0.65, 0.85]
    }
  },

  "global": {
    "max_total_adjustment": 25.0,
    "min_total_adjustment": -35.0
  }
}
```

---

## Example Draft Scenarios

### Scenario 1: Elite QB vs Elite EDGE (Round 1, Pick 1)

**Setup:**
- Team has no QB (critical need), adequate EDGE
- QB prospect: 88 OVR, hype 90, Heisman winner
- EDGE prospect: 91 OVR, hype 65, All-American 1st

**QB Calculation:**
- Base: 88.0
- Need: 8.0 * 0.6 * 1.5 = +7.2
- Scouting: 0 (comprehensive)
- Hype: (90-50)/50 * 5.0 * 0.5 * 1.2 + 3.0 = +5.4
- Position tier: +3.0
- Position value: +5.0
- **Total: 88 + 7.2 + 0 + 5.4 + 3 + 5 = 108.6**

**EDGE Calculation:**
- Base: 91.0
- Need: 0 (no need)
- Scouting: 0
- Hype: (65-50)/50 * 5.0 * 0.5 * 1.2 + 1.5 = +2.4
- Position tier: +3.0
- Position value: +2.0
- **Total: 91 + 0 + 0 + 2.4 + 3 + 2 = 98.4**

**Result:** QB wins (108.6 vs 98.4) - need and hype overcome 3-point talent gap.

### Scenario 2: Prevent Reach (Round 1)

**Setup:**
- Team needs QB desperately
- Only QB available: 62 OVR, hype 75
- Available WR: 86 OVR, hype 60

**QB Calculation:**
- Base: 62.0
- Need: 0 (blocked by reach_prevention, 62 < 70 min)
- Scouting: 0
- Hype: blocked (player too low rated)
- **Total: 62.0**

**WR Calculation:**
- Base: 86.0
- Need: 0
- Hype: +1.2
- Position tier: 0
- Position value: +0.5
- **Total: 87.7**

**Result:** WR wins (87.7 vs 62.0) - reach prevention works.

### Scenario 3: Analytics Team vs Narrative Team

**Setup:**
- Same player evaluated by different teams
- Player: 78 OVR, hype 92, minimal scouting by both teams

**Analytics Team (susceptibility 0.25):**
- Base: 78.0
- Hype: (92-50)/50 * 5.0 * 0.25 * 1.0 = +1.05
- Scouting: -2.0 * 1.5 * (1/0.7) = -4.3
- **Total: 74.8**

**Narrative Team (susceptibility 0.75):**
- Base: 78.0
- Hype: (92-50)/50 * 5.0 * 0.75 * 1.0 = +3.15
- Scouting: -2.0 * 1.5 * (1/0.5) = -6.0
- **Total: 75.2**

**Result:** Similar totals but different reasoning - analytics team's hype resistance is offset by less scouting tolerance.

---

## Success Criteria

### Quantitative Metrics

1. **Position Distribution (Round 1):**
   - EDGE: 15-20% (was 53%)
   - QB: 8-15%
   - OL: 15-22%
   - CB: 10-15%
   - WR: 10-15%
   - Others: distributed

2. **Need-Based Drafting:**
   - Teams with critical QB need should draft QB in rounds 1-2 at 60%+ rate
   - But only if QB is above reach_prevention floor

3. **Hype Impact:**
   - Heisman winners should average 2-5 picks higher than raw OVR suggests
   - High-hype busts (70 OVR, 90 hype) should go 5-10 picks earlier than talent

4. **Scouting Impact:**
   - Unscouted players rarely go in top 20 picks
   - Late-round steals more common for unscouted high-talent players

### Qualitative Checks

1. Draft results feel realistic and varied
2. No single factor dominates (except talent)
3. Team personality visible in draft patterns
4. Occasional "reaches" and "steals" add drama

---

## Migration Strategy

### Backward Compatibility

1. Keep existing modifiers functional during transition
2. New modifiers are opt-in via config flag
3. Gradual rollout: Team Need -> Scouting -> Hype

### Config Migration

```json
{
  "draft_evaluation": {
    "use_legacy_need_modifier": false,
    "enable_scouting_knowledge": true,
    "enable_hype_modifier": true,
    "enable_team_susceptibility": true
  }
}
```

### Data Migration

1. Add `hype_susceptibility` to existing teams (random generation on first run)
2. Add `scouting_philosophy` to existing teams
3. Initialize scouting data structure in world_state

---

## Appendix: File Changes Summary

### New Files

1. `configs/sports/american_football/draft_evaluation.json`
2. `scripts/core/evaluation/modifiers/TeamNeedModifierV2.gd`
3. `scripts/core/evaluation/modifiers/ScoutingKnowledgeModifier.gd`
4. `scripts/core/evaluation/modifiers/HypeModifier.gd`

### Modified Files

1. `scripts/core/evaluation/EvaluationContext.gd` - Add hype, scouting_data fields
2. `scripts/core/evaluation/EvaluationModifierStack.gd` - Register new modifiers
3. `scripts/world/NflDraft.gd` - Pass new context data
4. `scripts/world/NflTeamGenerator.gd` - Generate team attributes
5. `configs/sports/american_football/college_awards.json` - Add signal bonuses

### Deprecated Files

1. `scripts/core/evaluation/modifiers/PositionNeedModifier.gd` - Replaced by TeamNeedModifierV2
