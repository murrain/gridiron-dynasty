# Contract valuation spec (American Football)

## Purpose
Define how a scouting evaluation score is converted into a contract value
range using position weights, age multipliers, and potential deltas. This
spec is data-driven by `contract_valuation.json` and is intended to be
implemented in a deterministic simulation step.

## Inputs

### Primary evaluation input
- **`eval_score`**: Use the composite from
  `ScoutRuntime.score_player(...)` as the primary evaluation score to stay
  aligned with existing scouting math.
- **`eval_source`**: Record the evaluation source as
  `"ScoutRuntime.score_player"` in the output.

### Player data required
- `player["position"]`
- `player["age"]`
- `player["stats"]` and `player["potential"]` (for potential deltas)
- `positions_data` (for `core_stats` if using position core stats)

## Data-driven configuration
Configuration is defined in
`configs/sports/american_football/contract_valuation.json`:

- **Base range curve** (`base_range_curve`): maps `eval_score` buckets to a
  base `range_min`/`range_max` before modifiers.
- **Position tiers + weights**:
  - `position_tiers` groups positions into premium/core/specialist buckets.
  - `position_weights` provides explicit multipliers per position that scale
    the contract range.
- **Age multipliers** (`age_multipliers`): scales range based on player age.
- **Potential delta policy** (`potential_delta`): defines how much potential
  vs. current ratings should influence the final value, with a stronger
  bias for younger players.
- **Range spread** (`range_spread`): post-modifier min/max spread to preserve
  a consistent band.
- **Range jitter** (`range_jitter`): optional randomness applied to the
  final range (disabled by default).

## Computation steps

### 1) Base range from evaluation score
1. Clamp `eval_score` to `eval_score_bounds`.
2. Find the matching `base_range_curve` bucket and get `range_min` and
   `range_max`.

### 2) Apply position weight
1. Determine the player’s position weight:
   - Look up `position_weights[position]`.
   - If missing, fall back to `1.0`.
2. Multiply both `range_min` and `range_max` by this weight.

### 3) Apply age multiplier
1. Find the matching `age_multipliers` bucket for `player["age"]`.
2. Multiply both `range_min` and `range_max` by the bucket’s multiplier.

### 4) Apply potential delta
Potential deltas should **not** replace `eval_score`; they are a secondary
adjustment that stays anchored to the scout composite.

1. Compute a **current core average**:
   - If `potential_delta.use_position_core_stats` is true, use
     `positions_data[position].core_stats`.
   - Otherwise, compute an average across all stats.
2. Compute a **potential core average** using the same stat list.
3. `raw_delta = (potential_avg - current_avg) / 100.0`.
4. Compute the **age-based potential weight** using
   `potential_delta.weight_curve` (linear interpolation between knots).
5. `weighted_delta = raw_delta * age_weight * potential_delta.delta_scale`.
6. Clamp the delta to `[max_penalty_pct, max_bonus_pct]`.
7. Apply to range: `range_min *= (1 + weighted_delta)` and
   `range_max *= (1 + weighted_delta)`.

This keeps the scout composite as the primary evaluation and uses potential
only as a bounded adjustment that is stronger for younger players.

### 5) Apply range spread
After all modifiers, apply `range_spread` to preserve an intentional band:
- `range_min *= range_spread.min_pct`
- `range_max *= range_spread.max_pct`

### 6) Optional deterministic jitter
If `range_jitter.enabled` is true:
- Use **only** the RNG passed into the valuation step.
- Apply jitter with `rng.randf_range(-pct, pct)`.
- Do **not** use global randomness.
- Record the RNG lineage (seed source + step ID) in the output.

## Output format
Store results on the player record under `player["contract_valuation"]`.
Recommended output payload:

```json
{
  "range_min": 3.25,
  "range_max": 4.10,
  "est_value": 3.67,
  "eval_score": 78.3,
  "eval_source": "ScoutRuntime.score_player",
  "position_weight": 1.05,
  "age_multiplier": 0.90,
  "potential_delta": 0.04,
  "rng_seed_source": "world_seed:year_2026",
  "currency_unit": "cap_units"
}
```

- `est_value` should be the midpoint of the final range unless overridden
  by future rule changes.
- `rng_seed_source` is required only if jitter is enabled.

## Determinism notes
- Any randomness must use an explicitly passed-in RNG.
- If jitter is enabled, log the seed lineage in the output and ensure the
  valuation step is reproducible given the same seed.

