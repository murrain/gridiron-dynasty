# Valuation System Tasks (Track E)

## Overview

The valuation system provides comprehensive player value assessment for contracts, trades, draft decisions, and market dynamics. This track implements economic simulation on top of the existing player generation and lifecycle systems.

## Foundation Components (Already Completed)

These components already exist in the codebase and serve as building blocks:

1. **ValueCurve** (`scripts/core/valuation/ValueCurve.gd`)
   - Non-linear score-to-value curve
   - Exponential scaling for elite players
   - Diminishing returns below replacement level

2. **ReplacementLevel** (`scripts/core/valuation/ReplacementLevel.gd`)
   - Position-specific replacement thresholds
   - Value-over-replacement (VOR) calculations
   - Baseline for free agents and minimum contracts

3. **PositionalScarcity** (`scripts/core/valuation/PositionalScarcity.gd`)
   - Market-wide supply/demand analysis
   - Scarcity multipliers by position
   - Year-over-year trend tracking

4. **TeamImpact** (`scripts/core/valuation/TeamImpact.gd`)
   - Roster context evaluation
   - Starter vs depth value adjustments
   - Team-specific need multipliers

## Task Sequence

### E5: Unified PlayerValue Calculator (READY)
**Status**: 🟢 Ready to start
**Dependencies**: None (foundation components complete)
**Effort**: 1-2 days

Creates the main `PlayerValue` class that orchestrates all valuation components into a single authoritative value calculation.

**Key Deliverable**: `scripts/core/valuation/PlayerValue.gd`

**Inputs**:
- Player dictionary (stats, position, age)
- Context (team roster, market data, year)
- Config (value curve, scarcity weights)
- RNG (for noise/uncertainty)

**Outputs**:
- Total value (market value in abstract currency)
- Component breakdown (VOR, curve, scarcity, team impact, age adjustment)
- Contract range (min/max/expected)

### E6: Update Contract Valuation (BLOCKED - needs E5)
**Status**: 🟡 Blocked by E5
**Effort**: 1 day

Updates contract generation to use the new unified valuation system instead of ad-hoc calculations.

**Key Changes**:
- `ContractGenerator.gd` - Use `PlayerValue.calculate()`
- `NflFreeAgency.gd` - Market-driven contract offers
- `CollegeScholarship.gd` - Value-based scholarship allocation

### E7: Market Supply (BLOCKED - needs E5)
**Status**: 🟡 Blocked by E5
**Effort**: 1-2 days

Models market supply/demand dynamics for free agency and trades.

**Key Deliverable**: `scripts/core/valuation/MarketSupply.gd`

**Features**:
- Available player pools (free agents, draft prospects)
- Team needs analysis (roster gaps, cap space)
- Supply/demand equilibrium calculations
- Market trends over time

### E8: Wire Valuation Flow (BLOCKED - needs E5, E6, E7)
**Status**: 🟡 Blocked by E5, E6, E7
**Effort**: 2-3 days

Integrates valuation system into world generation pipeline phases.

**Integration Points**:
- NFL Draft - Value-based draft strategies
- Free Agency - Market-driven signings
- Trade Logic - Fair trade evaluation
- Retirement Decisions - Value vs cost considerations

### E9: Valuation Configs (BLOCKED - needs E5-E8)
**Status**: 🟡 Blocked by E5-E8
**Effort**: 1 day

Creates configuration files for tuning valuation parameters.

**Config Files**:
- `data/configs/valuation/value_curve.json` - Curve shape, inflection points
- `data/configs/valuation/scarcity_weights.json` - Position importance
- `data/configs/valuation/age_curves.json` - Age-based value adjustments
- `data/configs/valuation/market_dynamics.json` - Supply/demand parameters

### E10: Valuation Tests (BLOCKED - needs E5-E9)
**Status**: 🟡 Blocked by E5-E9
**Effort**: 2-3 days

Comprehensive test suite for valuation system.

**Test Coverage**:
- Unit tests for each component
- Integration tests for full pipeline
- Regression tests for known scenarios
- Market equilibrium validation
- Contract range verification

## Success Metrics

### Functionality
- [ ] All contracts generated through unified valuation
- [ ] Market prices reflect supply/demand dynamics
- [ ] Draft strategies consider player value
- [ ] Trade logic evaluates fairness correctly

### Quality
- [ ] 95%+ test coverage for valuation code
- [ ] No hardcoded values (all config-driven)
- [ ] Clear separation of concerns (each component single-purpose)
- [ ] Deterministic for same seed (no RNG leakage)

### Performance
- [ ] Valuation calculation < 1ms per player
- [ ] No significant impact on world generation time
- [ ] Market analysis < 100ms per free agency phase

## Architecture Notes

### Design Principles
1. **Composability**: Each component (VOR, curve, scarcity) works independently
2. **Configurability**: All parameters tunable without code changes
3. **Determinism**: Same inputs + seed = same outputs
4. **Transparency**: Breakdown shows contribution of each factor

### Data Flow
```
Player Stats → ReplacementLevel.value_over_replacement() → VOR score
VOR score → ValueCurve.score_to_market_value() → Base value
Base value → PositionalScarcity.apply_multiplier() → Scarcity-adjusted value
Adjusted value → TeamImpact.context_multiplier() → Team-specific value
Team value → Age adjustment → Final value
```

### Integration Points
- **Draft**: Use valuation to determine pick value and team strategy
- **Free Agency**: Market value determines contract offers
- **Trades**: Compare values to evaluate fairness
- **Retirement**: Value threshold influences retirement decisions
- **UI**: Display value breakdown in player cards

## Common Pitfalls to Avoid

1. **Circular Dependencies**: Don't let valuation depend on contracts that depend on valuation
2. **RNG Coupling**: Keep valuation deterministic, noise should be explicit parameter
3. **Hardcoded Constants**: All tuning parameters should be in configs
4. **Position String Matching**: Use position enums or config-driven lookups
5. **Unbounded Growth**: Cap maximum values to prevent overflow/absurdity

## Testing Strategy

### Unit Tests (Fast)
- Each component in isolation
- Edge cases (position="ATH", age=0, etc.)
- Config validation

### Integration Tests (Medium)
- Full valuation pipeline
- Contract generation
- Market equilibrium

### Regression Tests (Slow)
- Known player scenarios
- Historical draft classes
- Multi-year market trends

## Related Documentation

- Foundation components: See existing `scripts/core/valuation/*.gd` files
- Contract system: See `scripts/world/ContractGenerator.gd`
- Market dynamics: See `scripts/world/NflFreeAgency.gd`
- Performance patterns: See `docs/tasks/archive/2026-01/README.md`
