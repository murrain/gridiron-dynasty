# Task E5: Unified PlayerValue Calculator

**Track**: Player Valuation (Track E)
**Dependencies**: E1 (ValueCurve), E2 (ReplacementLevel), E3 (PositionalScarcity), E4 (TeamImpact) - ✅ All completed
**Status**: Not started
**Estimated Effort**: 1-2 days

## Goal

Create a unified `PlayerValue` calculator that combines all valuation components (VOR, non-linear curve, scarcity, team impact, age) into a single authoritative valuation system.

## Implementation

### File to Create

`scripts/core/valuation/PlayerValue.gd`

### Core Logic

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

## Test Coverage

**File**: `scripts/tests/test_player_value.gd`

**Test Cases**:
1. Verify all components integrate correctly
2. Verify elite player premium (top 5% should be worth 5-10x mid-tier)
3. Verify team premium for irreplaceable players (no backup)
4. Verify market_value and team_value are distinct and correct
5. Verify range_min and range_max provide reasonable variance
6. Assert determinism with fixed seeds

## Acceptance Criteria

- [ ] `PlayerValue.calculate()` returns complete valuation dictionary
- [ ] Elite players (95+ rating) valued 5-10x more than average (75 rating)
- [ ] Team premium correctly reflects depth (no backup = higher team value)
- [ ] All tests pass with deterministic seeds
- [ ] No magic numbers (all values from config)

## Files to Create

- `scripts/core/valuation/PlayerValue.gd`
- `scripts/tests/test_player_value.gd`

## Files to Reference

- `scripts/core/valuation/ValueCurve.gd` - For curved_value calculation
- `scripts/core/valuation/ReplacementLevel.gd` - For VOR calculation
- `scripts/core/valuation/PositionalScarcity.gd` - For scarcity_mult
- `scripts/core/valuation/TeamImpact.gd` - For team-specific value
- `scripts/core/valuation/ContractValuation.gd` - For age_multiplier

## Next Task

After completing E5, proceed to **TASK_E6_update_contract_valuation.md** to integrate PlayerValue into the existing contract system.
