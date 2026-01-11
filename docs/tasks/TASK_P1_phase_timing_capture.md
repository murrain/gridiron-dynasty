# Task P1: Phase Timing Capture for World Generation

**Status**: Not started
**Phase**: P (Performance Follow-ups)
**Priority**: High
**Dependencies**: F8 (Benchmark Suite)

## Goal
Add deterministic, per-phase timing capture for world generation so we can attribute BootstrapGameWorld runtime to individual phases without altering simulation results.

## Motivation
BenchmarkRunner shows a 20-year bootstrap of **184.72 seconds**, but we lack phase-level attribution inside `AdvanceWorldYear.gd` when running full world generation. We need structured timing data to focus subsequent optimizations without reducing realism or altering RNG usage.

## Scope
- Instrument `AdvanceWorldYear.run()` to record per-phase timings (microseconds) behind a flag.
- Aggregate per-year totals in `BootstrapGameWorld.run()` without mutating `world_state`.
- Extend `BenchmarkRunner.gd` to capture the new timing payload when running bootstrap benchmarks.
- Update `BENCHMARKS.md` to document the new JSON fields.

## Implementation Notes
1. Add an optional `capture_timing: bool = false` parameter to `AdvanceWorldYear.run()`.
2. Wrap each phase execution with `Time.get_ticks_usec()` and store timings in a local dictionary.
3. Return a `timing` field in the result payload only when `capture_timing` is true.
4. In `BootstrapGameWorld.run()`, pass `capture_timing = true` when invoked by BenchmarkRunner and aggregate:
   - `per_year_phase_timings`
   - `total_phase_timings`
5. Ensure timing data is appended to BenchmarkRunner results under a new `world_generation` key.

## Determinism
- Timing collection must not alter RNG usage or phase ordering.
- No new randomness introduced.

## Acceptance Criteria
- BenchmarkRunner outputs phase timing totals and per-year breakdowns in JSON.
- No changes to simulation outputs or determinism tests.
- Timing capture is opt-in and off by default for production use.

## Files to Touch
- `scripts/pipelines/AdvanceWorldYear.gd`
- `scripts/pipelines/BootstrapGameWorld.gd`
- `scripts/tests/BenchmarkRunner.gd`
- `BENCHMARKS.md`
