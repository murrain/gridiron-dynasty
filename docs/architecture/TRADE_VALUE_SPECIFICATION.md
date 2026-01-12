# Trade Value Specification

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: TRADE_SYSTEM_ARCHITECTURE.md

---

## Purpose

This document defines the mathematical formulas, value curves, and fairness bounds for trade valuation. All trade value calculations must be **deterministic** and **auditable**, producing the same results given identical inputs.

---

## Foundation: PlayerValue Integration

The trade system builds on the existing `PlayerValue` calculator, which provides:

```gdscript
# From PlayerValue.calculate()
{
  "market_value": float,      # What other teams would pay (external demand)
  "team_value": float,        # Worth to current team (internal value)
  "team_premium": float,      # Difference (team_value - market_value)
  "vor": float,               # Value over replacement
  "scarcity_multiplier": float,
  "age_multiplier": float
}
```

**Key Insight**: Trade value is NOT just market value. Teams with high `team_premium` (e.g., franchise QB with no backup) will demand more in trades to compensate for losing irreplaceable value.

---

## Trade Value Formula

### Base Trade Value

```gdscript
func calculate_base_trade_value(
  player: Dictionary,
  from_team_roster: Array,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> float:
  # Use PlayerValue to get market value
  var context := {
    "team_roster": from_team_roster,
    "position_supply": _get_league_position_supply(config)
  }

  var valuation := PlayerValue.calculate(player, context, config, rng)

  # Base trade value = market value
  var base_value := valuation.market_value

  # Apply team premium adjustment
  # If team_premium > 0, team values player more than market
  # Asking price increases to compensate for losing internal value
  var team_premium := valuation.team_premium

  if team_premium > 0:
    # Calculate premium factor (capped at 50% of market value)
    var premium_factor := clamp(team_premium / base_value, 0.0, 0.5)

    # Apply premium (max 25% increase to asking price)
    # Example: QB with team_premium = 20, market_value = 40
    # premium_factor = 20 / 40 = 0.5 (capped)
    # premium_adjustment = 0.5 * 0.5 = 0.25 (25% increase)
    base_value *= (1.0 + premium_factor * 0.5)

  return base_value
```

**Rationale**:
- Market value reflects what player is worth league-wide
- Team premium captures positional scarcity WITHIN the team
- Teams won't trade key players unless receiving significant compensation
- Premium is capped to prevent unrealistic asking prices

### Example Calculations

**Case 1: Elite QB with no backup**
```
Player: QB, age 26, eval_score 90
Market value: 45.0
Team value: 67.5 (no backup, critical position)
Team premium: 22.5

Premium factor: 22.5 / 45.0 = 0.5 (capped)
Premium adjustment: 0.5 * 0.5 = 0.25
Trade value: 45.0 * 1.25 = 56.25

Interpretation: Team demands 25% premium to trade franchise QB
```

**Case 2: 3rd String RB (surplus)**
```
Player: RB, age 24, eval_score 65
Market value: 5.0
Team value: 3.5 (surplus, low leverage)
Team premium: -1.5 (negative, team wants to shed)

Premium factor: -1.5 / 5.0 = -0.3 (negative)
Premium adjustment: 0.0 (no adjustment for negative premium)
Trade value: 5.0

Interpretation: Team willing to trade at market value (or less)
```

**Case 3: Starting WR with depth**
```
Player: WR, age 27, eval_score 78
Market value: 18.0
Team value: 19.5 (starter, but depth exists)
Team premium: 1.5

Premium factor: 1.5 / 18.0 = 0.083
Premium adjustment: 0.083 * 0.5 = 0.0415
Trade value: 18.0 * 1.0415 = 18.75

Interpretation: Slight premium for starter, but tradeable
```

---

## Receiving Team Valuation

The receiving team evaluates trade differently based on their needs:

```gdscript
func calculate_receiving_value(
  player: Dictionary,
  to_team_roster: Array,
  to_team_profile: TeamTradeProfile,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> float:
  # Calculate value from receiving team's perspective
  var context := {
    "team_roster": to_team_roster,
    "position_supply": _get_league_position_supply(config)
  }

  var valuation := PlayerValue.calculate(player, context, config, rng)

  # Receiving team values based on team_value (accounts for their needs)
  var receive_value := valuation.team_value

  # Apply motivation multiplier
  # If receiving team has urgent need, player worth more to them
  var position := String(player.get("position", ""))
  if to_team_profile.positional_needs.has(position):
    var need: Dictionary = to_team_profile.positional_needs[position]
    var severity := float(need.get("severity", 0.0))

    # Urgent need increases perceived value (up to 30%)
    var need_multiplier := 1.0 + (severity * 0.3)
    receive_value *= need_multiplier

  return receive_value
```

**Example: Injury Crisis**
```
Player: QB, age 28, eval_score 82
Receiving team's situation:
- Starting QB on IR
- Backup is eval_score 55
- Positional need severity: 0.9 (critical)

Base team_value: 30.0 (would be valuable on any team)
Need multiplier: 1.0 + (0.9 * 0.3) = 1.27
Receiving value: 30.0 * 1.27 = 38.1

Interpretation: Desperate team values QB 27% higher than normal
```

---

## Fair Trade Bounds

### Tolerance Calculation

```gdscript
func calculate_trade_tolerance(
  team_a_profile: TeamTradeProfile,
  team_b_profile: TeamTradeProfile,
  config: Dictionary
) -> float:
  # Base tolerance from config (default 30%)
  var base := float(config.get("trade_value_tolerance", 0.30))

  # Urgency increases tolerance
  # High urgency = willing to accept worse value to get deal done
  var max_urgency := max(
    team_a_profile.temperature_score,
    team_b_profile.temperature_score
  )

  # Each 0.1 urgency adds 1.5% tolerance
  # Example: urgency 0.8 adds 12% tolerance
  var urgency_bonus := max_urgency * 0.15

  return base + urgency_bonus
```

**Tolerance Table**:
| Urgency | Base | Bonus | Total | Interpretation |
|---------|------|-------|-------|----------------|
| 0.0 | 30% | 0% | 30% | Normal market conditions |
| 0.3 | 30% | 4.5% | 34.5% | Slight pressure to trade |
| 0.5 | 30% | 7.5% | 37.5% | Moderate urgency |
| 0.7 | 30% | 10.5% | 40.5% | High urgency (injury crisis) |
| 0.9 | 30% | 13.5% | 43.5% | Desperate (cap crisis, deadline) |
| 1.0 | 30% | 15% | 45% | Maximum tolerance |

### Fairness Check

```gdscript
func is_trade_fair(
  value_given_a: float,
  value_received_a: float,
  tolerance: float
) -> Dictionary:
  # Calculate percentage difference
  # Use max of given/received as denominator (larger value = more conservative)
  var max_val := max(value_given_a, value_received_a)

  if max_val == 0:
    return {"fair": false, "reason": "zero_value"}

  var pct_diff := abs(value_received_a - value_given_a) / max_val

  if pct_diff <= tolerance:
    return {
      "fair": true,
      "pct_diff": pct_diff * 100.0,  # Convert to percentage
      "tolerance": tolerance * 100.0,
      "winner": _determine_winner(value_given_a, value_received_a, 0.05)
    }
  else:
    return {
      "fair": false,
      "reason": "value_imbalance",
      "pct_diff": pct_diff * 100.0,
      "tolerance": tolerance * 100.0,
      "excess": (pct_diff - tolerance) * 100.0
    }

func _determine_winner(val_a: float, val_b: float, threshold: float) -> String:
  var diff := abs(val_a - val_b) / max(val_a, val_b)
  if diff < threshold:
    return "balanced"
  elif val_a > val_b:
    return "team_a"
  else:
    return "team_b"
```

### Trade Fairness Examples

**Example 1: Balanced Trade**
```
Team A gives: WR (value 20.0)
Team A receives: CB (value 19.0)
Tolerance: 30%

Value diff: |19.0 - 20.0| = 1.0
Pct diff: 1.0 / 20.0 = 5%
Result: FAIR (5% < 30%)
Winner: Team A (slight edge)
```

**Example 2: High Urgency Trade**
```
Team A gives: QB (value 50.0)
Team A receives: QB (value 38.0)
Team A urgency: 0.9 (injury crisis)
Tolerance: 30% + 13.5% = 43.5%

Value diff: |38.0 - 50.0| = 12.0
Pct diff: 12.0 / 50.0 = 24%
Result: FAIR (24% < 43.5%)
Winner: Team B (got better player)
Interpretation: Team A desperate, accepts worse value to fill need
```

**Example 3: Unfair Trade (Rejected)**
```
Team A gives: EDGE (value 25.0)
Team A receives: RB (value 10.0)
Tolerance: 30%

Value diff: |10.0 - 25.0| = 15.0
Pct diff: 15.0 / 25.0 = 60%
Result: UNFAIR (60% > 30%)
Excess: 30% over tolerance
```

---

## Special Value Adjustments

### Contract Considerations

```gdscript
func apply_contract_adjustments(
  base_value: float,
  player: Dictionary,
  config: Dictionary
) -> Dictionary:
  var contract: Dictionary = player.get("contract", {})
  var years_remaining := int(contract.get("years_remaining", 0))
  var annual_value := float(contract.get("annual_value", 0.0))

  var adjusted_value := base_value

  # Expiring contract reduces value (short-term rental)
  if years_remaining == 1:
    adjusted_value *= 0.85  # 15% discount for rental
  elif years_remaining == 0:
    adjusted_value *= 0.70  # 30% discount for immediate free agent

  # Bad contract (overpaid relative to value)
  # If player's contract > 2x their market value, it's a negative asset
  if base_value > 0 and annual_value > (base_value * 2.0):
    var overpay_ratio := annual_value / base_value
    var penalty := clamp((overpay_ratio - 2.0) * 0.1, 0.0, 0.4)  # Max 40% penalty
    adjusted_value *= (1.0 - penalty)

  # Good contract (team-friendly deal)
  # If player's value > 2x contract, it's a premium asset
  if annual_value > 0 and base_value > (annual_value * 2.0):
    var value_ratio := base_value / annual_value
    var bonus := clamp((value_ratio - 2.0) * 0.05, 0.0, 0.25)  # Max 25% bonus
    adjusted_value *= (1.0 + bonus)

  return {
    "base_value": base_value,
    "adjusted_value": adjusted_value,
    "contract_multiplier": adjusted_value / base_value if base_value > 0 else 1.0,
    "years_remaining": years_remaining,
    "annual_value": annual_value
  }
```

**Contract Examples**:

**Rental Player (Expiring Contract)**:
```
Player: DE, eval_score 80, market_value 22.0
Contract: 1 year remaining, $8M/year
Adjusted value: 22.0 * 0.85 = 18.7
Interpretation: Acquiring team only gets 1 year, reduced value
```

**Bad Contract (Overpaid)**:
```
Player: RB, eval_score 68, market_value 8.0
Contract: 3 years, $18M/year
Overpay ratio: 18.0 / 8.0 = 2.25
Penalty: (2.25 - 2.0) * 0.1 = 0.025 (2.5%)
Adjusted value: 8.0 * 0.975 = 7.8
Interpretation: Team slightly penalized for taking bad contract
```

**Team-Friendly Deal**:
```
Player: CB, eval_score 85, market_value 28.0
Contract: 4 years, $10M/year (signed as rookie)
Value ratio: 28.0 / 10.0 = 2.8
Bonus: (2.8 - 2.0) * 0.05 = 0.04 (4%)
Adjusted value: 28.0 * 1.04 = 29.12
Interpretation: Premium for acquiring cheap elite player
```

### Age Curve Adjustments

Already handled by `PlayerValue.age_multiplier`, but additional context:

```gdscript
# Age multipliers from PlayerValue (built-in)
# These affect market_value calculation, no additional adjustment needed

# Age 22-24: 1.15x (young, peak ahead)
# Age 25-27: 1.10x (entering prime)
# Age 28-29: 1.00x (prime)
# Age 30-31: 0.90x (decline starting)
# Age 32-33: 0.75x (late career)
# Age 34+: 0.60x (end of career)
```

**Trade Implication**: Older players naturally have lower trade value due to age multiplier. No additional penalty needed.

---

## Division Rival Penalty

### Penalty Application

```gdscript
func apply_division_rival_penalty(
  base_value_required: float,
  team_a: Dictionary,
  team_b: Dictionary,
  config: Dictionary
) -> Dictionary:
  var team_a_div := String(team_a.get("division", ""))
  var team_b_div := String(team_b.get("division", ""))

  if team_a_div == "" or team_b_div == "":
    return {
      "penalty_applied": false,
      "adjusted_value": base_value_required
    }

  if team_a_div != team_b_div:
    return {
      "penalty_applied": false,
      "adjusted_value": base_value_required
    }

  # Same division: apply penalty multiplier
  var penalty_mult := float(config.get("division_rival_penalty", 1.5))

  # Increase value required by multiplier
  # Example: 1.5x means team demands 50% more value to trade to rival
  var adjusted_value := base_value_required * penalty_mult

  return {
    "penalty_applied": true,
    "penalty_multiplier": penalty_mult,
    "base_value": base_value_required,
    "adjusted_value": adjusted_value,
    "premium_pct": (penalty_mult - 1.0) * 100.0
  }
```

**Example: Division Rival Trade**
```
Team A (NFC East): Trades CB (value 20.0)
Team B (NFC East): Same division
Penalty multiplier: 1.5

Team A demands: 20.0 * 1.5 = 30.0 value in return
Team B must offer: Player worth 30.0 to make trade fair

Practical effect:
- Without penalty: 20-for-20 trade is fair
- With penalty: Need 20-for-30 trade
- Rivals must offer 50% more value
```

**Rationale**:
- Teams play division rivals twice per year
- Trading good player to rival strengthens opponent directly
- Psychological: GMs don't want to "help" division foes
- Historical: Division trades are rare in NFL (~5% of all trades)

### Penalty Overrides

Some situations override division rivalry:

```gdscript
func check_penalty_overrides(
  team_a_profile: TeamTradeProfile,
  team_b_profile: TeamTradeProfile
) -> Dictionary:
  # Cap crisis overrides rivalry (must shed salary)
  if team_a_profile.must_shed_salary:
    return {
      "override": true,
      "reason": "cap_crisis",
      "penalty_reduction": 0.5  # Halve penalty (1.5x -> 1.25x)
    }

  # Both teams rebuilding (not competing, less rivalry)
  if team_a_profile.team_status == "rebuilder" and team_b_profile.team_status == "rebuilder":
    return {
      "override": true,
      "reason": "both_rebuilding",
      "penalty_reduction": 0.3  # Reduce penalty (1.5x -> 1.35x)
    }

  return {"override": false}
```

---

## Draft Pick Value Chart (Phase 2)

**Deferred to Phase 2**, but outline:

### Pick Value by Round

Based on NFL trade value charts (Jimmy Johnson / Rich Hill models):

```
Round 1, Pick 1: 3000 points
Round 1, Pick 15: 1050 points
Round 2, Pick 1: 580 points
Round 3, Pick 1: 265 points
Round 4, Pick 1: 112 points
Round 5, Pick 1: 43 points
Round 6, Pick 1: 16 points
Round 7, Pick 1: 5 points
```

**Conversion to player value**:
```
1st round pick (mid): ~1000 points = ~15-20 player value units
2nd round pick: ~500 points = ~8-10 player value units
3rd round pick: ~250 points = ~4-5 player value units
```

**Phase 2 implementation**: Map draft pick value chart to player value scale for trades.

---

## Value Calculation Performance

### Optimization Strategy

```gdscript
# OPTIMIZATION: Cache PlayerValue results during trade window
var _value_cache := {}  # player_id -> valuation

func get_cached_player_value(
  player_id: String,
  team_roster: Array,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> Dictionary:
  var cache_key := "%s_%d" % [player_id, team_roster.hash()]

  if _value_cache.has(cache_key):
    return _value_cache[cache_key]

  var player := _find_player_by_id(team_roster, player_id)
  var context := {
    "team_roster": team_roster,
    "position_supply": _get_league_position_supply(config)
  }

  var valuation := PlayerValue.calculate(player, context, config, rng)
  _value_cache[cache_key] = valuation

  return valuation

func clear_value_cache() -> void:
  _value_cache.clear()
```

**Cache lifecycle**:
- Created at start of trade window
- Cleared at end of trade window
- Reduces redundant PlayerValue calls (each player valued once per window)

**Performance gain**:
- Without cache: 32 teams * 53 players * 4 partner checks = 6784 valuations
- With cache: 32 teams * 53 players = 1696 valuations
- 4x reduction in valuations

---

## Testing & Validation

### Unit Tests

```gdscript
# Test: Base trade value calculation
func test_base_trade_value():
  var player := {
    "id": "p1",
    "position": "QB",
    "age": 26,
    "eval_score": 90.0
  }
  var roster := [player]  # No backup

  var value := calculate_base_trade_value(player, roster, config, rng)

  # Expect premium for critical position with no backup
  assert(value > PlayerValue.calculate(player, {}, config, rng).market_value)

# Test: Division rival penalty
func test_division_rival_penalty():
  var team_a := {"division": "nfc_east"}
  var team_b := {"division": "nfc_east"}

  var result := apply_division_rival_penalty(20.0, team_a, team_b, config)

  assert(result.penalty_applied == true)
  assert(result.adjusted_value == 30.0)  # 20.0 * 1.5

# Test: Fair trade bounds
func test_fair_trade_bounds():
  var result := is_trade_fair(20.0, 18.0, 0.30)

  assert(result.fair == true)
  assert(result.pct_diff < 30.0)
```

### Integration Tests

```gdscript
# Test: Complete trade valuation pipeline
func test_complete_trade_valuation():
  var trade := {
    "team_a_gives": {"players": ["p1"]},
    "team_b_gives": {"players": ["p2"]}
  }

  var valuation := calculate_trade_valuation(trade, world_state, config, rng)

  assert(valuation.has("team_a_value"))
  assert(valuation.has("team_b_value"))
  assert(valuation.has("fair"))
```

---

## Configuration Reference

All value-related configuration in `league.json`:

```json
{
  "trades": {
    "trade_value_tolerance": 0.30,
    "division_rival_penalty": 1.5,
    "contract_adjustments": {
      "rental_discount": 0.15,
      "free_agent_discount": 0.30,
      "bad_contract_penalty_rate": 0.1,
      "good_contract_bonus_rate": 0.05
    }
  }
}
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial specification |
