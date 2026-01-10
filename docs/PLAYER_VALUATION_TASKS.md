# Player Valuation Implementation Tasks

## Status Assessment

### Current State
The existing valuation system (`ContractValuation.gd`) uses **linear multipliers**:
```gdscript
est_value = base_value * pos_mult * age_mult * blend_mult
# where base_value = base + eval_score * per_point (purely linear)
```

### Key Gaps
1. **Linear valuation curve** - A 95-rated player is only marginally worth more than a 90-rated player
2. **No replacement-level baseline** - Cannot calculate value-over-replacement (VOR)
3. **No positional scarcity** - Market depth varies by position
4. **No team-specific impact** - Players valued in isolation, not considering what they mean to their team
5. **No performance-based adjustments** - Currently talent-only (acceptable for now with 1:1 talent:performance)

---

## Track E: Player Valuation System

### E1. Implement Non-Linear Value Curve

**Goal**: Elite players (#1 at position) should be worth significantly more than #20.

**File**: `scripts/core/valuation/ValueCurve.gd` (new)

**Implementation**:
```gdscript
# Instead of linear: value = base + score * per_point
# Use exponential curve: value = base * pow(score / 50.0, exponent)
# Or sigmoid with heavy top-end weighting

static func score_to_market_value(eval_score: float, config: Dictionary) -> float:
    var curve_type := config.get("curve_type", "exponential")
    var base := float(config.get("base_value", 1.0))

    match curve_type:
        "exponential":
            # Scores 90-100 are worth exponentially more
            var exponent := float(config.get("exponent", 2.5))
            var normalized := eval_score / 100.0
            return base * pow(normalized, exponent) * 100.0
        "tiered_exponential":
            # Different growth rates for different tiers
            return _tiered_exponential(eval_score, config)
        _:
            return eval_score  # fallback linear
```

**Config** (add to `valuation.json`):
```json
{
  "value_curve": {
    "curve_type": "tiered_exponential",
    "tiers": [
      {"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
      {"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
      {"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
      {"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
      {"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
    ],
    "elite_threshold": 92,
    "elite_multiplier_boost": 1.5
  }
}
```

**Expected Outcome**:
- Score 60 player → ~$1M/yr equivalent
- Score 75 player → ~$4M/yr equivalent
- Score 85 player → ~$12M/yr equivalent
- Score 92 player → ~$30M/yr equivalent
- Score 98 player → ~$55M/yr equivalent

**Tests**: `scripts/tests/test_value_curve.gd`
- Verify exponential growth at high end
- Verify determinism
- Verify elite threshold behavior

---

### E2. Implement Positional Replacement Level

**Goal**: Define baseline "replacement level" talent by position (what a team could get for minimum salary).

**File**: `scripts/core/valuation/ReplacementLevel.gd` (new)

**Implementation**:
```gdscript
class_name ReplacementLevel

# Replacement level = the talent available at league minimum cost
# Based on typical practice squad / street free agent quality by position
static var REPLACEMENT_LEVELS: Dictionary = {
    "QB": 55.0,   # Backup QBs are scarce, replacement level is higher
    "RB": 62.0,   # RBs are abundant, easy to replace
    "WR": 58.0,
    "TE": 56.0,
    "OL": 54.0,   # O-line depth is thin
    "DL": 57.0,
    "EDGE": 52.0, # Elite edge rushers are rare
    "LB": 58.0,
    "CB": 53.0,   # Good corners are scarce
    "S": 57.0,
    "K": 65.0,    # Kickers are very replaceable
    "P": 65.0     # Punters are very replaceable
}

static func get_replacement_level(position: String) -> float:
    return REPLACEMENT_LEVELS.get(position, 55.0)

static func value_over_replacement(player_score: float, position: String) -> float:
    var repl := get_replacement_level(position)
    return max(0.0, player_score - repl)
```

**Config**: Add to `contract_valuation.json`:
```json
{
  "replacement_levels": {
    "QB": 55.0,
    "RB": 62.0,
    "WR": 58.0,
    "TE": 56.0,
    "OL": 54.0,
    "DL": 57.0,
    "EDGE": 52.0,
    "LB": 58.0,
    "CB": 53.0,
    "S": 57.0,
    "K": 65.0,
    "P": 65.0
  }
}
```

**Tests**: `scripts/tests/test_replacement_level.gd`
- Verify VOR calculation
- Verify position-specific baselines
- Verify below-replacement players have 0 VOR

---

### E3. Implement Positional Scarcity Factor

**Goal**: Account for supply/demand at each position based on roster needs and talent distribution.

**File**: `scripts/core/valuation/PositionalScarcity.gd` (new)

**Implementation**:
```gdscript
class_name PositionalScarcity

# How many starters needed per team × 32 teams = total demand
# Supply is the number of players rated above replacement level
static var STARTER_SLOTS: Dictionary = {
    "QB": 1,    # 32 total needed
    "RB": 1,    # 32 (ignoring committees for simplicity)
    "WR": 3,    # 96
    "TE": 1,    # 32
    "OL": 5,    # 160
    "DL": 2,    # 64
    "EDGE": 2,  # 64
    "LB": 3,    # 96
    "CB": 2,    # 64
    "S": 2,     # 64
    "K": 1,     # 32
    "P": 1      # 32
}

static func compute_scarcity_multiplier(
    position: String,
    players_above_replacement: int,
    config: Dictionary
) -> float:
    var slots := STARTER_SLOTS.get(position, 1) * 32
    var supply := float(players_above_replacement)
    var demand := float(slots)

    # Scarcity = demand / supply (clamped)
    # If supply < demand, scarcity > 1.0 (premium)
    # If supply > demand, scarcity < 1.0 (discount)
    var ratio := demand / max(supply, 1.0)
    var min_mult := float(config.get("scarcity_min", 0.7))
    var max_mult := float(config.get("scarcity_max", 1.5))
    return clamp(ratio, min_mult, max_mult)
```

**Tests**: `scripts/tests/test_positional_scarcity.gd`
- Verify scarcity calculation with various supply/demand ratios
- Verify clamping behavior

---

### E4. Implement Team-Specific Impact Valuation

**Goal**: A player's value to their current team should account for how hard they are to replace on that specific roster.

**File**: `scripts/core/valuation/TeamImpact.gd` (new)

**Implementation**:
```gdscript
class_name TeamImpact

static func compute_team_value(
    player: Dictionary,
    team_roster: Array,
    config: Dictionary
) -> Dictionary:
    var position := String(player.get("position", "ATH"))
    var player_score := float(player.get("eval_score", 0.0))
    var player_id := String(player.get("id", ""))

    # Find other players at same position on roster
    var position_mates: Array = []
    for p in team_roster:
        if String(p.get("position", "")) == position and String(p.get("id", "")) != player_id:
            position_mates.append(p)

    # Sort by score descending
    position_mates.sort_custom(func(a, b):
        return float(a.get("eval_score", 0)) > float(b.get("eval_score", 0))
    )

    # Find best replacement on roster (or replacement level if none)
    var replacement_score := ReplacementLevel.get_replacement_level(position)
    if position_mates.size() > 0:
        replacement_score = max(replacement_score, float(position_mates[0].get("eval_score", 0)))

    # Impact = how much better than the replacement
    var impact := max(0.0, player_score - replacement_score)

    # Leverage: if team has no backup, impact is amplified
    var depth := position_mates.size()
    var leverage_mult := 1.0
    if depth == 0:
        leverage_mult = float(config.get("no_backup_multiplier", 1.4))
    elif depth == 1:
        leverage_mult = float(config.get("thin_depth_multiplier", 1.15))

    # Position importance for wins
    var pos_importance := _get_position_win_impact(position, config)

    return {
        "player_id": player_id,
        "position": position,
        "player_score": player_score,
        "replacement_score": replacement_score,
        "raw_impact": impact,
        "depth": depth,
        "leverage_multiplier": leverage_mult,
        "position_importance": pos_importance,
        "team_value": impact * leverage_mult * pos_importance
    }

# Win impact by position (based on NFL analytics)
static func _get_position_win_impact(position: String, config: Dictionary) -> float:
    var impacts: Dictionary = config.get("position_win_impacts", {
        "QB": 2.5,    # QB has outsized impact on wins
        "EDGE": 1.4,
        "CB": 1.3,
        "WR": 1.2,
        "OL": 1.1,
        "DL": 1.1,
        "LB": 1.0,
        "S": 0.95,
        "TE": 0.9,
        "RB": 0.8,    # RBs are more replaceable
        "K": 0.5,
        "P": 0.4
    })
    return float(impacts.get(position, 1.0))
```

**Config** (add to `valuation.json`):
```json
{
  "team_impact": {
    "no_backup_multiplier": 1.4,
    "thin_depth_multiplier": 1.15,
    "position_win_impacts": {
      "QB": 2.5,
      "EDGE": 1.4,
      "CB": 1.3,
      "WR": 1.2,
      "OL": 1.1,
      "DL": 1.1,
      "LB": 1.0,
      "S": 0.95,
      "TE": 0.9,
      "RB": 0.8,
      "K": 0.5,
      "P": 0.4
    }
  }
}
```

**Tests**: `scripts/tests/test_team_impact.gd`
- Verify impact increases with no backup
- Verify position importance weighting
- Verify replacement score uses best available teammate

---

### E5. Create Unified PlayerValue Calculator

**Goal**: Combine all valuation components into a single, authoritative value calculation.

**File**: `scripts/core/valuation/PlayerValue.gd` (new)

**Implementation**:
```gdscript
class_name PlayerValue

static func calculate(
    player: Dictionary,
    context: Dictionary,  # Contains team_roster, market_data, etc.
    config: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var position := String(player.get("position", "ATH"))
    var age := int(player.get("age", 22))
    var eval_score := float(player.get("eval_score", 50.0))

    # 1. Value-over-replacement (VOR)
    var vor := ReplacementLevel.value_over_replacement(eval_score, position)

    # 2. Non-linear curve applied to VOR
    var curved_value := ValueCurve.score_to_market_value(vor, config.get("value_curve", {}))

    # 3. Positional scarcity multiplier (market-wide)
    var scarcity_mult := 1.0
    if context.has("position_supply"):
        var supply := int(context.get("position_supply", {}).get(position, 100))
        scarcity_mult = PositionalScarcity.compute_scarcity_multiplier(
            position, supply, config.get("scarcity", {})
        )

    # 4. Age multiplier (existing logic)
    var age_mult := ContractValuation._age_multiplier(age, config)

    # 5. Team-specific impact (if on a team)
    var team_impact := {"team_value": curved_value}
    if context.has("team_roster"):
        team_impact = TeamImpact.compute_team_value(
            player, context.get("team_roster", []), config.get("team_impact", {})
        )

    # Final market value (what other teams would pay)
    var market_value := curved_value * scarcity_mult * age_mult

    # Team value (what this player is worth to current team)
    var team_value := team_impact.get("team_value", market_value) * age_mult

    # Contract range (with variance)
    var spread := float(config.get("range_spread_pct", 0.15))
    var range_min := market_value * (1.0 - spread)
    var range_max := market_value * (1.0 + spread)

    return {
        "player_id": String(player.get("id", "")),
        "position": position,
        "age": age,
        "eval_score": eval_score,
        "vor": vor,
        "curved_value": curved_value,
        "scarcity_multiplier": scarcity_mult,
        "age_multiplier": age_mult,
        "market_value": market_value,
        "team_value": team_value,
        "team_premium": team_value - market_value,  # How much more to current team
        "range_min": range_min,
        "range_max": range_max,
        "components": {
            "vor": vor,
            "curve_output": curved_value,
            "scarcity": scarcity_mult,
            "age": age_mult,
            "team_impact": team_impact
        }
    }
```

**Tests**: `scripts/tests/test_player_value.gd`
- Verify all components integrate correctly
- Verify elite player premium (top 5% should be worth 5-10x mid-tier)
- Verify team premium for irreplaceable players
- Verify determinism

---

### E6. Update ContractValuation to Use PlayerValue

**Goal**: Migrate existing contract generation to use the new unified valuation.

**File**: `scripts/core/valuation/ContractValuation.gd` (modify)

**Changes**:
1. Replace `_score_to_value` with `ValueCurve.score_to_market_value`
2. Add optional team context for team-specific valuation
3. Preserve backwards compatibility for callers without team context

---

### E7. Implement Market Supply Calculator

**Goal**: Track how many players are above replacement level at each position for scarcity calculations.

**File**: `scripts/core/valuation/MarketSupply.gd` (new)

**Implementation**:
```gdscript
class_name MarketSupply

static func compute_position_supply(
    all_players: Array,
    config: Dictionary
) -> Dictionary:
    var supply: Dictionary = {}

    for player in all_players:
        var position := String(player.get("position", "ATH"))
        var score := float(player.get("eval_score", 0.0))
        var repl := ReplacementLevel.get_replacement_level(position)

        if score > repl:
            supply[position] = supply.get(position, 0) + 1

    return supply
```

---

### E8. Wire Valuation into ValuationFlow

**Goal**: Connect the new valuation system to the game loop.

**File**: `scripts/world/ValuationFlow.gd` (modify)

**Changes**:
1. Replace stub with actual valuation logic
2. For each player entering free agency:
   - Calculate market value using PlayerValue
   - Store valuation on player contract data
3. For each team's roster:
   - Calculate team-specific values for retention decisions

---

### E9. Update Configuration Files

**Goal**: Add all new config values in a consolidated, documented format.

**Files to modify**:
- `configs/sports/american_football/valuation.json`
- `configs/sports/american_football/contract_valuation.json`

**New sections**:
```json
{
  "value_curve": { ... },
  "replacement_levels": { ... },
  "scarcity": { ... },
  "team_impact": { ... }
}
```

---

### E10. Add Comprehensive Test Suite

**Goal**: Full coverage of valuation edge cases.

**Files**:
- `scripts/tests/test_value_curve.gd`
- `scripts/tests/test_replacement_level.gd`
- `scripts/tests/test_positional_scarcity.gd`
- `scripts/tests/test_team_impact.gd`
- `scripts/tests/test_player_value.gd`
- `scripts/tests/test_valuation_integration.gd`

**Key test cases**:
1. Elite QB (score 98) should be worth ~5-8x a good QB (score 80)
2. Player with no backup should have higher team value than market value
3. Position with thin supply should have scarcity premium
4. Below-replacement players should have 0 VOR but still have minimum value
5. Determinism with fixed seeds

---

## Implementation Order

```
E1 (Value Curve) ─────────────────┐
E2 (Replacement Level) ───────────┼──→ E5 (PlayerValue) ──→ E6 (Update ContractValuation)
E3 (Positional Scarcity) ─────────┤                              │
E4 (Team Impact) ─────────────────┘                              ▼
                                                           E8 (ValuationFlow)
E7 (Market Supply) ──────────────────────────────────────────────┘
                                                                  │
E9 (Config Updates) ──────────────────────────────────────────────┤
E10 (Test Suite) ─────────────────────────────────────────────────┘
```

**Recommended sequence**:
1. E1, E2, E3, E4 can be developed in parallel
2. E5 integrates all of the above
3. E6, E7, E8 wire into existing systems
4. E9, E10 finalize and validate

---

## Acceptance Criteria

- [ ] Elite players (top 5%) worth 5-10x mid-tier players
- [ ] Non-linear valuation curve demonstrates expected growth
- [ ] VOR correctly calculated per position
- [ ] Team-specific value accounts for depth and replacement difficulty
- [ ] All tests pass with deterministic seeds
- [ ] Configuration fully externalized (no magic numbers)
- [ ] Existing ContractValuation API preserved for backwards compatibility

---

## Notes for 1:1 Talent:Performance

Since we are not yet simulating individual plays, we use `eval_score` directly as the performance measure. When play simulation is added later, this can be replaced with:
- Actual game stats (yards, touchdowns, etc.)
- Win shares / WAR calculations
- EPA (Expected Points Added)
- Situational performance metrics

For now, the system assumes `talent == performance`, which is acceptable for simulating game outcomes without play-by-play detail.
