extends RefCounted
class_name ValuationFlow

# Valuation is anchored to the offseason "draft_prep" phase.
# This keeps contract valuation deterministic and repeatable: roster changes
# settle first, then valuation outputs feed signing decisions and cap updates.
# See scripts/pipelines/AdvanceWorldYear.gd for the phase hook.

const DEFAULT_PHASE_ID := "draft_prep"

static func run(
	world_state: Dictionary,
	year: int,
	phase_id: String,
	seed: int
) -> Dictionary:
	# Determinism: the caller provides the phase seed; no global RNG usage.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	# Data flow (deterministic ordering):
	# 1) Evaluation: scouting or performance snapshots per player/team.
	# 2) Valuation range: translate evaluations into min/max contract asks.
	# 3) Signing decision: resolve offers using seeded RNG when needed.
	# 4) Cap accounting update: apply contract lifecycle cap deltas.
	# This module only scaffolds the flow; concrete logic lands in later steps.
	return {
		"phase_id": phase_id,
		"year": year,
		"seed": seed,
		"valuation_stub": true,
		"data_flow": [
			"evaluation",
			"valuation_range",
			"signing_decision",
			"cap_accounting_update"
		],
		"note": "Valuation scaffolding only; no RNG consumed beyond seeding."
	}
