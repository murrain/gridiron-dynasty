# Task P2: Recruiting Score Cache (Deterministic)

**Status**: Completed
**Phase**: P (Performance Follow-ups)
**Priority**: High
**Dependencies**: F2 (Recruiting Optimization)

## Goal
Reduce recruiting hot-path cost by caching scout score evaluations per recruit within a year, preserving identical outcomes while eliminating redundant scoring.

## Motivation
BenchmarkRunner shows recruiting still costs **~5.0s** in the micro benchmark. Full world generation scales that cost with the number of colleges and recruits. We can retain the same realism by caching identical evaluations rather than recomputing them.

## Scope
- Introduce a deterministic `RecruitingScoreCache` that memoizes scout evaluations.
- Key cache entries by `(year, scout_id, player_id, phase)` to avoid cross-year contamination.
- Integrate cache into recruiting board evaluation and NFL draft scoring.
- Preserve RNG behavior by deriving per-scout/per-player seeds for cached computations, ensuring order-independent determinism.

## Implementation Notes
1. Add `RecruitingScoreCache.gd` in `scripts/core/scouting/` (or similar shared location).
2. Provide `get_or_compute()` that:
   - Builds a deterministic seed from `(base_seed, scout_id, player_id, phase)`.
   - Computes score once using `ScoutRuntime.score_player`.
   - Stores the result for reuse.
3. Update recruiting and draft pipelines to use the cache for repeated evaluations within a year.
4. Add determinism tests comparing cached vs non-cached outputs for identical seeds.

## Determinism
- Cache must be keyed by seed lineage inputs to avoid order dependence.
- Results must match the uncached path exactly.

## Acceptance Criteria
- Recruiting and draft results are byte-identical for fixed seeds.
- BenchmarkRunner shows a measurable reduction in recruiting timing.
- Tests cover cache hit/miss and determinism equivalence.

## Files to Touch
- `scripts/core/scouting/ScoutRuntime.gd`
- `scripts/pipelines/CollegeRecruiting.gd`
- `scripts/world/NflDraft.gd`
- `scripts/tests/` (new deterministic tests)
