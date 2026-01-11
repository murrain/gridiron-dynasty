# Task P3: Lifecycle Copy Reduction

**Status**: Not started
**Phase**: P (Performance Follow-ups)
**Priority**: Medium
**Dependencies**: F4 (Deep Copy Reduction)

## Goal
Reduce allocation pressure during world generation by minimizing deep-copy churn in `PlayerLifecycle` while keeping outputs identical.

## Motivation
BenchmarkRunner shows lifecycle advancement as a recurring cost and the 20-year bootstrap still exceeds the 150s target. The lifecycle step currently performs deep copies per player, which compounds over multi-year simulation.

## Scope
- Identify hotspots in `PlayerLifecycle.advance_one_year()` and `advance_years()` where deep copies are unnecessary.
- Introduce copy-on-write semantics or targeted cloning for modified sections only (stats/ratings/physicals).
- Maintain clear immutability boundaries so callers still receive isolated player dictionaries.

## Implementation Notes
1. Add helper utilities to clone only updated sub-dictionaries (e.g., stats, ratings, physicals).
2. Replace `player.duplicate(true)` with explicit copy paths where safe.
3. Update high-school, college, and NFL season pipelines to adopt the new lifecycle output format if needed.
4. Add tests asserting that lifecycle outputs are identical to the pre-change behavior.

## Determinism
- No RNG changes. Ensure seed usage and stat noise are untouched.
- Determinism tests must pass with the new copy strategy.

## Acceptance Criteria
- Lifecycle tests pass with identical results.
- BenchmarkRunner shows a measurable reduction in lifecycle timing.
- World generation output remains deterministic with fixed seeds.

## Files to Touch
- `scripts/world/PlayerLifecycle.gd`
- `scripts/world/HighSchoolSeason.gd`
- `scripts/world/CollegeSeason.gd`
- `scripts/world/NflSeason.gd`
- `scripts/tests/` (determinism regression tests)
