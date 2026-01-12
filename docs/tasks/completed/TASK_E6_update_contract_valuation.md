# Task E6: Update ContractValuation to Use PlayerValue

**Track**: Player Valuation (Track E)
**Dependencies**: E5 (PlayerValue) - Must be completed first
**Status**: Not started
**Estimated Effort**: 1 day

## Goal

Migrate the existing `ContractValuation.gd` to use the new unified `PlayerValue` calculator instead of its legacy linear scoring system.

## Current State

`scripts/core/valuation/ContractValuation.gd` currently uses:
```gdscript
est_value = base_value * pos_mult * age_mult * blend_mult
# where base_value = base + eval_score * per_point (purely linear)
```

This is **linear** and doesn't account for:
- Value-over-replacement (VOR)
- Non-linear elite player premium
- Positional scarcity
- Team-specific impact

## Implementation

### File to Modify

`scripts/core/valuation/ContractValuation.gd`

### Changes Required

1. **Replace `_score_to_value` internal method**
   ```gdscript
   # REMOVE old linear calculation
   # ADD call to PlayerValue.calculate()
   ```

2. **Add optional team context parameter**
   ```gdscript
   # Before:
   static func estimate_value(player: Dictionary, config: Dictionary, rng: RNG) -> Dictionary

   # After (backwards compatible):
   static func estimate_value(
       player: Dictionary,
       config: Dictionary,
       rng: RNG,
       context: Dictionary = {}  # Optional: team_roster, position_supply
   ) -> Dictionary
   ```

3. **Preserve existing API for backwards compatibility**
   - If `context` is empty, use market value only (no team premium)
   - If `context` has `team_roster`, include team-specific valuation

4. **Update return value to include new fields**
   ```gdscript
   return {
       "apy": market_value,  # Existing field (average per year)
       "total": market_value * years,  # Existing field
       "years": years,  # Existing field

       # NEW fields from PlayerValue:
       "market_value": valuation.market_value,
       "team_value": valuation.team_value,
       "team_premium": valuation.team_premium,
       "vor": valuation.vor,
       "components": valuation.components
   }
   ```

### Example Usage

```gdscript
# Without team context (market value only)
var contract := ContractValuation.estimate_value(player, config, rng)
print("Market APY: ", contract.market_value)

# With team context (team-specific value)
var context := {"team_roster": current_roster, "position_supply": supply}
var contract := ContractValuation.estimate_value(player, config, rng, context)
print("Team APY: ", contract.team_value)
print("Premium for keeping: ", contract.team_premium)
```

## Test Coverage

**File**: `scripts/tests/test_contract_valuation.gd` (update existing)

**New Test Cases**:
1. Verify backwards compatibility (calls without context still work)
2. Verify market_value matches PlayerValue calculation
3. Verify team_value includes depth premium when context provided
4. Verify existing callers (draft, free agency) still work

## Acceptance Criteria

- [ ] `estimate_value()` uses PlayerValue.calculate() internally
- [ ] Backwards compatible with existing callers (context optional)
- [ ] Market value and team value correctly distinguished
- [ ] All existing tests still pass
- [ ] New tests verify PlayerValue integration

## Files to Modify

- `scripts/core/valuation/ContractValuation.gd`

## Files to Update Tests

- `scripts/tests/test_contract_valuation.gd`

## Files to Reference

- `scripts/core/valuation/PlayerValue.gd` - For unified valuation

## Next Task

After completing E6, proceed to **TASK_E7_market_supply.md** to implement market supply tracking for scarcity calculations.
