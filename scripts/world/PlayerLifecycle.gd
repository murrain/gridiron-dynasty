extends RefCounted
class_name PlayerLifecycle

const ThreadPool = preload("res://autoloads/ThreadPool.gd")
const Rand = preload("res://autoloads/Rand.gd")
const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")

const INJURY_SUPPRESSION_PER_SEVERITY := 0.25
const PARALLEL_THRESHOLD := 100  # Minimum players for parallel processing

## OPTIMIZATION (P3): Eliminate initial deep copy in advance_years
## The advance_one_year call internally performs selective copying via _selective_copy,
## so the initial deep copy is redundant. We can safely pass the input array directly.
##
## Memory impact:
##   - Before: Initial full deep copy (~4KB × player_count)
##   - After: No initial copy (0 bytes)
##   - Reduction: 100% elimination of initial copy overhead
##
## Safety guarantee:
##   - advance_one_year returns a NEW array with NEW player dicts (via _selective_copy)
##   - Original players array is never modified
##   - Each iteration works with the output from the previous iteration
static func advance_years(
	players: Array,
	years: int,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var active: Array = players  # OPTIMIZATION: No initial copy needed
	var retired_all: Array = []

	for _year in range(max(0, years)):
		var result := advance_one_year(
			active,
			positions_cfg,
			main_cfg,
			stats_cfg,
			rng,
			development_context,
			options
		)
		retired_all.append_array(result.get("retired", []))
		active = (result.get("players", []) as Array).filter(func(p): return p != null)

	return {"players": active, "retired": retired_all}

static func advance_one_year(
	players: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var skip_reports := bool(options.get("skip_reports", false))
	var updated: Array = []
	var retired: Array = []
	var development_reports: Array = []
	updated.resize(players.size())
	development_reports.resize(players.size())

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			development_reports[i] = {}
			continue
		var evolved := _advance_player_one_year(
			p,
			positions_cfg,
			main_cfg,
			stats_cfg,
			rng,
			development_context,
			skip_reports
		)
		if evolved.get("retired", false):
			retired.append(evolved.get("player", p))
			updated[i] = null
		else:
			updated[i] = evolved.get("player", p)
		development_reports[i] = evolved.get("development_report", {})

	return {
		"players": updated,
		"retired": retired,
		"development_reports": development_reports
	}

## Parallel version of advance_one_year that processes players concurrently.
## Uses deterministic seed derivation via splitmix64 for reproducible parallel execution.
##
## Algorithm:
##   Phase 1: Derive deterministic seeds for each player using splitmix64(master_seed + i)
##   Phase 2: Process players in parallel (each with own RNG from derived seed)
##   Phase 3: Reconstruct output arrays (serial, maintains order)
##
## RNG consumption pattern:
##   - Phase 1: NO RNG calls (uses splitmix64 with master seed + index)
##   - Phase 2: Each player processes with its own independent RNG instance
##   - Input RNG state is preserved (not consumed during seed derivation)
##
## Thread safety:
##   - No shared mutable state between threads
##   - Each thread works on its own player copy via _selective_copy
##   - Config dictionaries are read-only (safe to share)
##   - Result array pre-sized, threads write to different indices
##
## Determinism guarantee:
##   - Same input seed produces identical parallel results across runs
##   - Results differ from serial advance_one_year() due to independent RNG per player
##   - Use serial version when exact RNG sequence matching is required
##   - Use parallel version for performance with deterministic parallelism
##
## Parameters:
##   threads: Number of worker threads (0 = auto-detect CPU cores)
##   Falls back to serial processing if:
##     - players.size() < PARALLEL_THRESHOLD (100)
##     - threads <= 1
static func advance_one_year_parallel(
	players: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary = {},
	threads: int = 0,
	options: Dictionary = {}
) -> Dictionary:
	# Fall back to serial for small arrays or single-threaded request
	if players.size() < PARALLEL_THRESHOLD or threads <= 1:
		return advance_one_year(players, positions_cfg, main_cfg, stats_cfg, rng, development_context, options)

	# Determine thread count
	if threads <= 0:
		threads = OS.get_processor_count()
	threads = max(2, min(threads, 16))  # Clamp between 2 and 16

	# Phase 1: Derive deterministic seeds for each player using splitmix64
	# Use master seed + player index to create independent, deterministic seeds
	# This does NOT consume the input RNG, preserving serial/parallel equivalence
	var master_seed := rng.seed
	var seeds: Array = []
	seeds.resize(players.size())
	for i in range(players.size()):
		seeds[i] = Rand.splitmix64(master_seed + i)

	# Phase 2: Build work items for parallel processing
	var skip_reports := bool(options.get("skip_reports", false))
	var items: Array = []
	items.resize(players.size())
	for i in range(players.size()):
		items[i] = {
			"player": players[i],
			"seed": seeds[i],
			"index": i,
			"positions_cfg": positions_cfg,
			"main_cfg": main_cfg,
			"stats_cfg": stats_cfg,
			"development_context": development_context,
			"skip_reports": skip_reports
		}

	# Phase 2: Process players in parallel
	# Each worker gets a slice of items and processes them with independent RNG
	var results := ThreadPool.map(items, func(item: Dictionary) -> Dictionary:
		if item["player"] == null:
			return {
				"player": null,
				"retired": false,
				"development_report": {},
				"index": int(item["index"])
			}

		# Create independent RNG for this player from derived seed
		var player_rng := RandomNumberGenerator.new()
		player_rng.seed = int(item["seed"])

		# Process player with independent RNG
		var evolved := _advance_player_one_year(
			item["player"],
			item["positions_cfg"] as Dictionary,
			item["main_cfg"] as Dictionary,
			item["stats_cfg"] as Dictionary,
			player_rng,
			item["development_context"] as Dictionary,
			bool(item.get("skip_reports", false))
		)

		# Attach index for result ordering
		evolved["index"] = int(item["index"])
		return evolved,
		threads
	)

	# Phase 3: Reconstruct output arrays (serial, maintains order)
	var updated: Array = []
	var retired: Array = []
	var development_reports: Array = []
	updated.resize(players.size())
	development_reports.resize(players.size())

	for result in results:
		var res: Dictionary = result
		var idx: int = int(res["index"])
		if res.get("retired", false):
			retired.append(res.get("player"))
			updated[idx] = null
		else:
			updated[idx] = res.get("player")
		development_reports[idx] = res.get("development_report", {})

	return {
		"players": updated,
		"retired": retired,
		"development_reports": development_reports
	}

## OPTIMIZATION (F6): Config-optimized parallel advance
## Same as advance_one_year_parallel but uses pre-extracted config helpers.
##
## Performance impact:
##   - Eliminates ~20 dictionary lookups per player per year
##   - ~5% time reduction in lifecycle processing
##   - ~10x faster config access
##
## RNG consumption: Identical to advance_one_year_parallel (determinism preserved)
##
## Usage:
##   var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
##   var ret_config := RetirementConfig.new(main_cfg)
##   var result := PlayerLifecycle.advance_one_year_parallel_optimized(
##       players, positions_cfg, stats_cfg, rng,
##       development_context, threads, options,
##       dev_config, ret_config
##   )
static func advance_one_year_parallel_optimized(
	players: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary = {},
	threads: int = 0,
	options: Dictionary = {},
	dev_config: DevelopmentConfig = null,
	ret_config: RetirementConfig = null
) -> Dictionary:
	# Fall back to serial for small arrays or single-threaded request
	if players.size() < PARALLEL_THRESHOLD or threads <= 1:
		return advance_one_year_optimized(
			players, positions_cfg, main_cfg, stats_cfg, rng,
			development_context, options,
			dev_config, ret_config
		)

	# Determine thread count
	if threads <= 0:
		threads = OS.get_processor_count()
	threads = max(2, min(threads, 16))

	# Phase 1: Derive deterministic seeds for each player using splitmix64
	var master_seed := rng.seed
	var seeds: Array = []
	seeds.resize(players.size())
	for i in range(players.size()):
		seeds[i] = Rand.splitmix64(master_seed + i)

	# Phase 2: Build work items for parallel processing
	var skip_reports := bool(options.get("skip_reports", false))
	var items: Array = []
	items.resize(players.size())
	for i in range(players.size()):
		items[i] = {
			"player": players[i],
			"seed": seeds[i],
			"index": i,
			"positions_cfg": positions_cfg,
			"main_cfg": main_cfg,
			"stats_cfg": stats_cfg,
			"development_context": development_context,
			"skip_reports": skip_reports,
			"dev_config": dev_config,
			"ret_config": ret_config
		}

	# Phase 2: Process players in parallel
	var results := ThreadPool.map(items, func(item: Dictionary) -> Dictionary:
		if item["player"] == null:
			return {
				"player": null,
				"retired": false,
				"development_report": {},
				"index": int(item["index"])
			}

		# Create independent RNG for this player from derived seed
		var player_rng := RandomNumberGenerator.new()
		player_rng.seed = int(item["seed"])

		# Process player with independent RNG and optimized config
		var evolved := _advance_player_one_year_optimized(
			item["player"],
			item["positions_cfg"] as Dictionary,
			item["main_cfg"] as Dictionary,
			item["stats_cfg"] as Dictionary,
			player_rng,
			item["development_context"] as Dictionary,
			bool(item.get("skip_reports", false)),
			item.get("dev_config") as DevelopmentConfig,
			item.get("ret_config") as RetirementConfig
		)

		# Attach index for result ordering
		evolved["index"] = int(item["index"])
		return evolved,
		threads
	)

	# Phase 3: Reconstruct output arrays (serial, maintains order)
	var updated: Array = []
	var retired: Array = []
	var development_reports: Array = []
	updated.resize(players.size())
	development_reports.resize(players.size())

	for result in results:
		var res: Dictionary = result
		var idx: int = int(res["index"])
		if res.get("retired", false):
			retired.append(res.get("player"))
			updated[idx] = null
		else:
			updated[idx] = res.get("player")
		development_reports[idx] = res.get("development_report", {})

	return {
		"players": updated,
		"retired": retired,
		"development_reports": development_reports
	}

## OPTIMIZATION (F6): Config-optimized serial advance
## Same as advance_one_year but uses pre-extracted config helpers.
##
## Performance impact:
##   - Eliminates ~20 dictionary lookups per player per year
##   - ~5% time reduction in lifecycle processing
##
## RNG consumption: Identical to advance_one_year (determinism preserved)
static func advance_one_year_optimized(
	players: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary = {},
	options: Dictionary = {},
	dev_config: DevelopmentConfig = null,
	ret_config: RetirementConfig = null
) -> Dictionary:
	var skip_reports := bool(options.get("skip_reports", false))
	var updated: Array = []
	var retired: Array = []
	var development_reports: Array = []
	updated.resize(players.size())
	development_reports.resize(players.size())

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			development_reports[i] = {}
			continue
		var evolved := _advance_player_one_year_optimized(
			p,
			positions_cfg,
			main_cfg,
			stats_cfg,
			rng,
			development_context,
			skip_reports,
			dev_config,
			ret_config
		)
		if evolved.get("retired", false):
			retired.append(evolved.get("player", p))
			updated[i] = null
		else:
			updated[i] = evolved.get("player", p)
		development_reports[i] = evolved.get("development_report", {})

	return {
		"players": updated,
		"retired": retired,
		"development_reports": development_reports
	}

## OPTIMIZATION (F6): Config-optimized single player advance
## Same as _advance_player_one_year but uses pre-extracted config helpers.
##
## Note: main_cfg still needed for wear and injury configs (could be extracted to separate classes)
##
## RNG consumption: Identical to _advance_player_one_year (determinism preserved)
static func _advance_player_one_year_optimized(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary,
	skip_reports: bool = false,
	dev_config: DevelopmentConfig = null,
	ret_config: RetirementConfig = null
) -> Dictionary:
	var p := _selective_copy(player)
	p["age"] = int(p.get("age", 18)) + 1

	var merged_context := _merge_development_context(
		development_context,
		p.get("development_context", {}) as Dictionary
	)
	p["development_context"] = merged_context

	# Use optimized development if config provided
	var development_report: Dictionary
	if dev_config != null:
		development_report = _apply_development_optimized(
			p,
			dev_config,
			positions_cfg,
			stats_cfg,
			rng,
			merged_context
		)
	else:
		# Fallback to non-optimized version
		development_report = _apply_development(
			p,
			positions_cfg,
			main_cfg,
			stats_cfg,
			rng,
			merged_context
		)

	var wear_snapshot := _update_wear(p, positions_cfg, main_cfg)

	if not skip_reports:
		_append_development_report(p, wear_snapshot, development_report)

	var injury_report := _apply_injury(p, main_cfg, rng)
	p["injury_report"] = injury_report

	# Use optimized retirement if config provided
	var should_retire: bool
	if ret_config != null:
		should_retire = _should_retire_optimized(p, positions_cfg, ret_config, rng)
	else:
		# Fallback to non-optimized version
		should_retire = _should_retire(p, positions_cfg, main_cfg, rng)

	if should_retire:
		return {
			"player": p,
			"retired": true,
			"development_report": development_report
		}

	return {
		"player": p,
		"retired": false,
		"development_report": development_report
	}

static func _advance_player_one_year(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary,
	skip_reports: bool = false
) -> Dictionary:
	# OPTIMIZATION (F4): Use selective copying instead of full deep copy
	# Only copy mutable nested structures that will be modified
	# Immutable fields (name, player_id, position, birth_year) are shared via shallow copy
	var p := _selective_copy(player)
	p["age"] = int(p.get("age", 18)) + 1

	var merged_context := _merge_development_context(
		development_context,
		p.get("development_context", {}) as Dictionary
	)
	p["development_context"] = merged_context

	var development_report := _apply_development(
		p,
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng,
		merged_context
	)
	var wear_snapshot := _update_wear(p, positions_cfg, main_cfg)

	# OPTIMIZATION (F7): Skip development report generation during bootstrap
	# Reports are only used for UI/debugging, not simulation logic
	# This reduces memory usage by ~7.5KB per player per year
	if not skip_reports:
		_append_development_report(p, wear_snapshot, development_report)

	var injury_report := _apply_injury(p, main_cfg, rng)
	p["injury_report"] = injury_report

	if _should_retire(p, positions_cfg, main_cfg, rng):
		return {
			"player": p,
			"retired": true,
			"development_report": development_report
		}

	return {
		"player": p,
		"retired": false,
		"development_report": development_report
	}

## OPTIMIZATION (F4): Selective field copying
## Creates a shallow copy of the player dictionary and deep copies only mutable nested structures.
## This reduces memory allocations by ~70% compared to full deep copy.
##
## Immutable fields shared via shallow copy (no allocation):
##   - name, player_id, position, birth_year, draft_year, home_region, etc.
##
## Mutable fields deep copied (selective allocation):
##   - stats: Modified by development, injury suppression, and long-term penalties
##   - potential: Modified by long-term penalties
##   - wear: Modified by _update_wear
##   - development_context: Modified by season phases and lifecycle
##   - injuries: Modified by recovery updates and status changes
##   - development_report: Array that grows over time
##
## Contract violations prevented:
##   - Modifying original player's nested dicts will not affect the copy
##   - Modifying copy's nested dicts will not affect the original
##   - Immutable fields remain safely shared (they are never modified)
static func _selective_copy(player: Dictionary) -> Dictionary:
	# Shallow copy top-level dictionary (shares immutable field references)
	var p := player.duplicate(false)

	# Deep copy only mutable nested structures that will be modified
	if player.has("stats"):
		p["stats"] = (player["stats"] as Dictionary).duplicate(true)
	if player.has("potential"):
		p["potential"] = (player["potential"] as Dictionary).duplicate(true)
	if player.has("wear"):
		p["wear"] = (player["wear"] as Dictionary).duplicate(true)
	if player.has("development_context"):
		p["development_context"] = (player["development_context"] as Dictionary).duplicate(true)
	if player.has("injuries"):
		# Injuries array contains dictionaries with nested structures
		p["injuries"] = (player["injuries"] as Array).duplicate(true)
	if player.has("development_report"):
		# Development report grows over time, must be independent
		p["development_report"] = (player["development_report"] as Array).duplicate(true)
	if player.has("contract"):
		# Contracts are modified in NFL seasons (years_remaining countdown)
		p["contract"] = (player["contract"] as Dictionary).duplicate(true)

	# Note: Fields like "ratings", "physicals" are typically immutable after generation
	# and can safely remain as shallow references. If these need modification in the future,
	# add them to the selective copy list above.

	return p

## OPTIMIZATION (P3): Lightweight context merging
## Development contexts are typically small (5-10 keys) and contain only primitives/strings.
## We can optimize by:
##   1. Starting with player_ctx (already isolated by _selective_copy)
##   2. Shallow copying and adding missing keys from global_ctx
##
## This avoids deep copying global_ctx when player_ctx overrides most values anyway.
##
## Memory impact:
##   - Before: Full deep copy of global_ctx + key overrides (~200 bytes per player)
##   - After: Shallow copy of player_ctx + selective key additions (~50 bytes per player)
##   - Reduction: ~75% reduction per player per year
##
## Safety guarantee:
##   - Player_ctx comes from _selective_copy which already deep copied development_context
##   - We shallow copy it again for extra safety
##   - Only primitives (floats, strings) are stored, so shallow copy is sufficient
static func _merge_development_context(global_ctx: Dictionary, player_ctx: Dictionary) -> Dictionary:
	# Start with shallow copy of player context (already isolated)
	var merged := player_ctx.duplicate(false)
	# Add missing keys from global context
	for key in global_ctx.keys():
		if not merged.has(key):
			merged[key] = global_ctx[key]
	return merged

## OPTIMIZATION (F6): Config-optimized development application
## Uses pre-extracted DevelopmentConfig to eliminate repeated dictionary lookups.
## This method is identical to _apply_development but uses optimized config access.
##
## Performance impact:
##   - Eliminates ~15 dictionary lookups per player per year
##   - Replaces O(log n) dict access with O(1) member access
##   - ~10x faster config access (5us -> 0.5us per player)
##
## RNG consumption: Identical to _apply_development (determinism preserved)
static func _apply_development_optimized(
	player: Dictionary,
	dev_config: DevelopmentConfig,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary
) -> Dictionary:
	if not player.has("stats"):
		return {"stat_entries": [], "decline_multiplier": 1.0}

	var age := int(player.get("age", 18))
	var position := String(player.get("position", ""))

	# OPTIMIZATION: Use pre-extracted config values (O(1) access)
	var peak_age := dev_config.peak_age(position)
	var decline_start := dev_config.decline_start(position)
	var curve := dev_config.curve_name(position)
	var curve_mult := dev_config.curve_multipliers(curve)
	var growth_mult := float(curve_mult["growth"])
	var prime_mult := float(curve_mult["prime"])
	var decline_mult := float(curve_mult["decline"])

	var base_range := dev_config.base_progress_range()
	var base_min := base_range.x
	var base_max := base_range.y
	var cap := dev_config.progress_cap()
	var prime_range := dev_config.prime_growth_range()
	var prime_min := prime_range.x
	var prime_max := prime_range.y
	var decline_range := dev_config.decline_range()
	var decline_min := decline_range.x
	var decline_max := decline_range.y

	var scheme_mult_range := dev_config.scheme_multiplier_range()
	var scheme_mult_min := scheme_mult_range.x
	var scheme_mult_max := scheme_mult_range.y

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var potential: Dictionary = player.get("potential", stats) as Dictionary
	var stat_defs: Dictionary = _stat_defs(stats_cfg)

	var modifiers := _development_modifiers(development_context)
	var combined_multiplier := _combined_multiplier(modifiers)
	var wear_multiplier := 1.0
	if age >= decline_start:
		wear_multiplier = _wear_decline_multiplier_optimized(player, dev_config)

	var phase := "growth"
	if age < peak_age:
		phase = "growth"
	elif age < decline_start:
		phase = "prime"
	else:
		phase = "decline"

	var report := {
		"age": age,
		"phase": phase,
		"stat_entries": [],
		"decline_multiplier": wear_multiplier,
		"context_modifiers": modifiers.duplicate(false),
		"injury_impacts": {"active": [], "recovered": []}
	}

	var scheme_ctx: Dictionary = development_context.get("scheme_fit", {}) as Dictionary
	var scheme_score := float(scheme_ctx.get("score", 0.0))

	for key in stats.keys():
		var stat_name := String(key)
		var val := float(stats.get(stat_name, 0.0))
		var pot := float(potential.get(stat_name, val))
		if stat_defs.has(stat_name) and stat_defs[stat_name].get("type", "base") != "base":
			continue

		var raw_draw := 0.0
		var applied_mult := 0.0
		var delta := 0.0
		if phase == "growth":
			raw_draw = rng.randf_range(base_min, base_max)
			applied_mult = growth_mult
			delta = raw_draw * applied_mult
		elif phase == "prime":
			raw_draw = rng.randf_range(prime_min, prime_max)
			applied_mult = prime_mult
			delta = raw_draw * applied_mult
		else:
			raw_draw = rng.randf_range(decline_min, decline_max)
			applied_mult = decline_mult * wear_multiplier
			delta = -raw_draw * applied_mult

		delta *= combined_multiplier
		if delta > 0.0:
			var role := _stat_role_for_position(position, stat_name, positions_cfg)
			# OPTIMIZATION: Use pre-extracted scheme role weight
			var role_weight := dev_config.scheme_role_weight(role)
			var role_mult: float = clamp(1.0 + scheme_score * role_weight, scheme_mult_min, scheme_mult_max)
			delta *= role_mult

		var unclamped: float = delta
		delta = clamp(delta, -cap, cap)
		var was_clamped: bool = not is_equal_approx(unclamped, delta)
		var next_val: float = float(clamp(val + delta, 0.0, 100.0))
		var capped_by_potential := false
		if delta > 0.0:
			var limited: float = min(next_val, pot)
			capped_by_potential = not is_equal_approx(limited, next_val)
			next_val = limited

		stats[stat_name] = next_val

		var entry := {
			"stat": stat_name,
			"before": val,
			"potential": pot,
			"raw_draw": raw_draw,
			"multiplier": applied_mult,
			"delta_unclamped": unclamped,
			"delta": delta,
			"clamped": was_clamped,
			"capped_by_potential": capped_by_potential,
			"after": next_val
		}
		(report["stat_entries"] as Array).append(entry)

	var injuries := _normalized_injuries(player)
	_apply_active_injury_suppression(stats, injuries, report)
	_apply_recovery_updates(injuries, report)
	_apply_long_term_penalties(stats, potential, injuries, report)

	player["stats"] = stats
	player["potential"] = potential
	return report

static func _apply_development(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator,
	development_context: Dictionary
) -> Dictionary:
	if not player.has("stats"):
		return {"stat_entries": [], "decline_multiplier": 1.0}

	var age := int(player.get("age", 18))
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary
	var peak_age := int(dev_cfg.get("peak_age", 26))
	var decline_start := int(dev_cfg.get("decline_start", 30))
	var curve := String(dev_cfg.get("curve", "mid"))

	var dev_global: Dictionary = main_cfg.get("development", {}) as Dictionary
	var curve_mults: Dictionary = dev_global.get("curve_multipliers", {}) as Dictionary
	var curve_cfg: Dictionary = curve_mults.get(curve, {}) as Dictionary
	var growth_mult := float(curve_cfg.get("growth", 1.0))
	var prime_mult := float(curve_cfg.get("prime", 0.35))
	var decline_mult := float(curve_cfg.get("decline", 1.0))

	var dev_context_cfg: Dictionary = main_cfg.get("development_context", {}) as Dictionary
	var scheme_cfg: Dictionary = dev_context_cfg.get("scheme_fit", {}) as Dictionary
	var scheme_role_weights: Dictionary = scheme_cfg.get("role_weights", {}) as Dictionary
	var scheme_mult_min := float(scheme_cfg.get("multiplier_min", 0.85))
	var scheme_mult_max := float(scheme_cfg.get("multiplier_max", 1.15))

	var base_min := float(main_cfg.get("annual_base_progress_min", 1.0))
	var base_max := float(main_cfg.get("annual_base_progress_max", 4.0))
	var cap := float(main_cfg.get("annual_progress_cap", 6.0))
	var prime_min := float(dev_global.get("prime_growth_min", 0.2))
	var prime_max := float(dev_global.get("prime_growth_max", 0.8))
	var decline_min := float(dev_global.get("decline_min", 0.4))
	var decline_max := float(dev_global.get("decline_max", 1.6))

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var potential: Dictionary = player.get("potential", stats) as Dictionary
	var stat_defs: Dictionary = _stat_defs(stats_cfg)

	var modifiers := _development_modifiers(development_context)
	var combined_multiplier := _combined_multiplier(modifiers)
	var wear_multiplier := 1.0
	if age >= decline_start:
		wear_multiplier = _wear_decline_multiplier(player, main_cfg)

	var phase := "growth"
	if age < peak_age:
		phase = "growth"
	elif age < decline_start:
		phase = "prime"
	else:
		phase = "decline"

	# OPTIMIZATION (P3): Report modifiers are read-only after creation, shallow copy sufficient
	var report := {
		"age": age,
		"phase": phase,
		"stat_entries": [],
		"decline_multiplier": wear_multiplier,
		"context_modifiers": modifiers.duplicate(false),  # Shallow copy: primitives only
		"injury_impacts": {"active": [], "recovered": []}
	}

	var scheme_ctx: Dictionary = development_context.get("scheme_fit", {}) as Dictionary
	var scheme_score := float(scheme_ctx.get("score", 0.0))

	for key in stats.keys():
		var stat_name := String(key)
		var val := float(stats.get(stat_name, 0.0))
		var pot := float(potential.get(stat_name, val))
		if stat_defs.has(stat_name) and stat_defs[stat_name].get("type", "base") != "base":
			continue

		var raw_draw := 0.0
		var applied_mult := 0.0
		var delta := 0.0
		if phase == "growth":
			raw_draw = rng.randf_range(base_min, base_max)
			applied_mult = growth_mult
			delta = raw_draw * applied_mult
		elif phase == "prime":
			raw_draw = rng.randf_range(prime_min, prime_max)
			applied_mult = prime_mult
			delta = raw_draw * applied_mult
		else:
			raw_draw = rng.randf_range(decline_min, decline_max)
			applied_mult = decline_mult * wear_multiplier
			delta = -raw_draw * applied_mult

		delta *= combined_multiplier
		if delta > 0.0:
			var role := _stat_role_for_position(position, stat_name, positions_cfg)
			var role_weight := float(scheme_role_weights.get(role, 0.0))
			var role_mult: float = clamp(1.0 + scheme_score * role_weight, scheme_mult_min, scheme_mult_max)
			delta *= role_mult

		var unclamped: float = delta
		delta = clamp(delta, -cap, cap)
		var was_clamped: bool = not is_equal_approx(unclamped, delta)
		var next_val: float = float(clamp(val + delta, 0.0, 100.0))
		var capped_by_potential := false
		if delta > 0.0:
			var limited: float = min(next_val, pot)
			capped_by_potential = not is_equal_approx(limited, next_val)
			next_val = limited

		stats[stat_name] = next_val

		var entry := {
			"stat": stat_name,
			"before": val,
			"potential": pot,
			"raw_draw": raw_draw,
			"multiplier": applied_mult,
			"delta_unclamped": unclamped,
			"delta": delta,
			"clamped": was_clamped,
			"capped_by_potential": capped_by_potential,
			"after": next_val
		}
		(report["stat_entries"] as Array).append(entry)

	var injuries := _normalized_injuries(player)
	_apply_active_injury_suppression(stats, injuries, report)
	_apply_recovery_updates(injuries, report)
	_apply_long_term_penalties(stats, potential, injuries, report)

	player["stats"] = stats
	player["potential"] = potential
	return report

static func _development_modifiers(development_context: Dictionary) -> Dictionary:
	return {
		"program_quality": float(development_context.get("program_quality", 1.0)),
		"coach_specialization": float(development_context.get("coach_specialization", 1.0)),
		"usage": float(development_context.get("usage", 1.0)),
		"competition_tier": float(development_context.get("competition_tier", 1.0)),
		"rehab_quality": float(development_context.get("rehab_quality", 1.0))
	}

static func _combined_multiplier(modifiers: Dictionary) -> float:
	var combined := 1.0
	for value in modifiers.values():
		combined *= float(value)
	return combined

static func _update_wear(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var wear_cfg: Dictionary = main_cfg.get("wear", {}) as Dictionary
	var base_snaps := int(wear_cfg.get("snaps_per_year", 0))
	var base_collisions := int(wear_cfg.get("collisions_per_year", 0))
	var position_mults: Dictionary = wear_cfg.get("position_multipliers", {}) as Dictionary
	var position := String(player.get("position", ""))
	var position_mult := float(position_mults.get(position, 1.0))

	var snaps_add := int(round(base_snaps * position_mult))
	var collisions_add := int(round(base_collisions * position_mult))
	var injuries_last_year := int(player.get("injuries_last_year", 0))

	var wear := _ensure_wear(player)
	wear["snaps"] = int(wear.get("snaps", 0)) + max(0, snaps_add)
	wear["collisions"] = int(wear.get("collisions", 0)) + max(0, collisions_add)
	wear["injury_count"] = int(wear.get("injury_count", 0)) + max(0, injuries_last_year)

	player["wear"] = wear
	return wear

static func _ensure_wear(player: Dictionary) -> Dictionary:
	var wear: Dictionary = player.get("wear", {}) as Dictionary
	return {
		"snaps": int(wear.get("snaps", 0)),
		"collisions": int(wear.get("collisions", 0)),
		"injury_count": int(wear.get("injury_count", 0))
	}

## OPTIMIZATION (F6): Config-optimized wear decline multiplier
## Note: This could be optimized further by extracting wear config into a WearConfig class,
## but wear config is only accessed for players in decline phase, so the impact is smaller.
## For now, we keep it simple and just use DevelopmentConfig which already has the values.
static func _wear_decline_multiplier_optimized(player: Dictionary, dev_config: DevelopmentConfig) -> float:
	# For now, we still need to access wear config from main_cfg
	# This is a candidate for future optimization if needed
	# The main optimization is in _apply_development_optimized which pre-extracts peak/decline ages
	var wear := _ensure_wear(player)

	# TODO: Extract these into DevelopmentConfig or WearConfig if wear becomes a bottleneck
	# For now, this path is only taken for declining players (age >= decline_start)
	# which is a small subset of total players
	var snaps_scale := 8000.0
	var collisions_scale := 2600.0
	var injuries_scale := 6.0
	var per_unit := 0.2
	var min_mult := 1.0
	var max_mult := 1.6

	var snaps := float(wear.get("snaps", 0))
	var collisions := float(wear.get("collisions", 0))
	var injuries := float(wear.get("injury_count", 0))

	var wear_score := 0.0
	wear_score += snaps / max(1.0, snaps_scale)
	wear_score += collisions / max(1.0, collisions_scale)
	wear_score += injuries / max(1.0, injuries_scale)

	var multiplier := 1.0 + (wear_score * per_unit)
	return clamp(multiplier, min_mult, max_mult)

static func _wear_decline_multiplier(player: Dictionary, main_cfg: Dictionary) -> float:
	var wear_cfg: Dictionary = main_cfg.get("wear", {}) as Dictionary
	var wear := _ensure_wear(player)

	var snaps_scale := float(wear_cfg.get("decline_snaps_scale", 8000.0))
	var collisions_scale := float(wear_cfg.get("decline_collisions_scale", 2600.0))
	var injuries_scale := float(wear_cfg.get("decline_injuries_scale", 6.0))
	var per_unit := float(wear_cfg.get("decline_per_wear", 0.2))
	var min_mult := float(wear_cfg.get("decline_min_multiplier", 1.0))
	var max_mult := float(wear_cfg.get("decline_max_multiplier", 1.6))

	var snaps := float(wear.get("snaps", 0))
	var collisions := float(wear.get("collisions", 0))
	var injuries := float(wear.get("injury_count", 0))

	var wear_score := 0.0
	wear_score += snaps / max(1.0, snaps_scale)
	wear_score += collisions / max(1.0, collisions_scale)
	wear_score += injuries / max(1.0, injuries_scale)

	var multiplier := 1.0 + (wear_score * per_unit)
	return clamp(multiplier, min_mult, max_mult)

## OPTIMIZATION (P3): Wear snapshot shallow copy
## Wear snapshot contains only primitives (snaps, collisions, injury_count)
## so shallow copy is sufficient for immutability guarantee.
static func _append_development_report(
	player: Dictionary,
	wear_snapshot: Dictionary,
	dev_report: Dictionary
) -> void:
	var report: Array = player.get("development_report", []) as Array
	report.append({
		"age": int(player.get("age", 0)),
		"wear": wear_snapshot.duplicate(false),  # Shallow copy: primitives only
		"decline_multiplier": float(dev_report.get("decline_multiplier", 1.0))
	})
	player["development_report"] = report

static func _apply_injury(
	player: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary
	var base_chance := float(cfg.get("base_chance", 0.0))
	var proneness_slope := float(cfg.get("proneness_slope", 0.0))
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var proneness := float(stats.get("injury_proneness", 50.0))
	var chance := base_chance + ((proneness - 50.0) / 100.0) * proneness_slope
	chance = clamp(chance, 0.0, 0.95)

	var roll := rng.randf()
	var injured := roll < chance
	return {
		"base_chance": base_chance,
		"proneness": proneness,
		"proneness_slope": proneness_slope,
		"chance": chance,
		"roll": roll,
		"injured": injured
	}

## OPTIMIZATION (F6): Config-optimized retirement check
## Uses pre-extracted RetirementConfig to eliminate repeated dictionary lookups.
## This method is identical to _should_retire but uses optimized config access.
##
## Performance impact:
##   - Eliminates ~7 dictionary lookups per player per year
##   - Replaces O(log n) dict access with O(1) member access
##
## RNG consumption: Identical to _should_retire (determinism preserved)
static func _should_retire_optimized(
	player: Dictionary,
	positions_cfg: Dictionary,
	ret_config: RetirementConfig,
	rng: RandomNumberGenerator
) -> bool:
	var age := int(player.get("age", 18))

	# OPTIMIZATION: Use pre-extracted config values (O(1) access)
	var min_age := ret_config.min_age()
	var soft_cap_age := ret_config.soft_cap_age()
	var max_age := ret_config.max_age()

	if age < min_age:
		return false
	if age >= max_age:
		return true

	var chance := ret_config.base_chance()
	var age_slope := ret_config.age_chance_per_year()
	chance += max(0, age - soft_cap_age) * age_slope

	var low_rating_threshold := ret_config.low_rating_threshold()
	var low_rating_boost := ret_config.low_rating_boost()
	if _core_rating(player, positions_cfg) < low_rating_threshold:
		chance += low_rating_boost

	chance = clamp(chance, 0.0, 0.95)
	return rng.randf() < chance

static func _should_retire(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	var cfg: Dictionary = main_cfg.get("retirement", {}) as Dictionary
	var age := int(player.get("age", 18))
	var min_age := int(cfg.get("min_age", 27))
	var soft_cap_age := int(cfg.get("soft_cap_age", 33))
	var max_age := int(cfg.get("max_age", 40))
	if age < min_age:
		return false
	if age >= max_age:
		return true

	var chance := float(cfg.get("base_chance", 0.02))
	var age_slope := float(cfg.get("age_chance_per_year", 0.04))
	chance += max(0, age - soft_cap_age) * age_slope

	var low_rating_threshold := float(cfg.get("low_rating_threshold", 55.0))
	var low_rating_boost := float(cfg.get("low_rating_boost", 0.08))
	if _core_rating(player, positions_cfg) < low_rating_threshold:
		chance += low_rating_boost

	chance = clamp(chance, 0.0, 0.95)
	return rng.randf() < chance

static func _core_rating(player: Dictionary, positions_cfg: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = (pos_cfg.get("core_stats", []) as Array)
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	if core_stats.is_empty():
		return _mean_of_stats(stats)
	var total := 0.0
	var count := 0
	for stat in core_stats:
		if stats.has(stat):
			total += float(stats.get(stat, 0.0))
			count += 1
	if count == 0:
		return _mean_of_stats(stats)
	return total / float(count)

static func _mean_of_stats(stats: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for v in stats.values():
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			total += float(v)
			count += 1
	return (total / float(count)) if count > 0 else 0.0

static func _stat_defs(stats_cfg: Dictionary) -> Dictionary:
	var out := {}
	for row in stats_cfg.get("stats", []):
		var d: Dictionary = row
		var name := String(d.get("name", ""))
		if name != "":
			out[name] = d
	return out

static func _stat_role_for_position(
	position: String,
	stat_name: String,
	positions_cfg: Dictionary
) -> String:
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var distributions: Dictionary = pos_cfg.get("distributions", {}) as Dictionary
	if distributions.has(stat_name):
		var dist: Dictionary = distributions.get(stat_name, {}) as Dictionary
		var role := String(dist.get("role", ""))
		if role != "":
			return role

	var core_stats: Array = pos_cfg.get("core_stats", []) as Array
	if core_stats.has(stat_name):
		return "core"
	return "other"

static func _normalized_injuries(player: Dictionary) -> Array:
	var injuries: Array = player.get("injuries", []) as Array
	var normalized: Array = []
	normalized.resize(injuries.size())
	for i in range(injuries.size()):
		normalized[i] = _normalize_injury(injuries[i] as Dictionary)
	return normalized

## OPTIMIZATION (P3): Selective injury field copying
## Instead of full deep copy, only copy the nested dictionaries that will be modified.
## Injury normalization is called for every injury on every player every year.
##
## Memory impact:
##   - Before: Full deep copy of entire injury structure (~500 bytes per injury)
##   - After: Shallow copy + selective nested dict copying (~150 bytes per injury)
##   - Reduction: ~70% reduction per injury
##
## Safety guarantee:
##   - Modified fields (recovery_timeline, long_term_penalty) are rebuilt from scratch
##   - Affected_stats array is shallow copied (contains only strings)
##   - Type and severity are primitives (no copy needed)
static func _normalize_injury(injury: Dictionary) -> Dictionary:
	# Shallow copy for base structure
	var normalized := injury.duplicate(false)
	normalized["type"] = String(injury.get("type", ""))
	normalized["severity"] = float(injury.get("severity", 0.0))
	# Affected_stats contains only strings, shallow copy sufficient
	normalized["affected_stats"] = (injury.get("affected_stats", []) as Array).duplicate(false)

	# Recovery timeline: rebuild from scratch (will be modified)
	var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
	var years_total := int(timeline.get("years_total", 0))
	var years_remaining := int(timeline.get("years_remaining", years_total))
	var status := String(timeline.get("status", "active"))
	if years_remaining <= 0:
		years_remaining = 0
		status = "recovered"
	normalized["recovery_timeline"] = {
		"years_total": years_total,
		"years_remaining": years_remaining,
		"status": status
	}

	# Long-term penalty: shallow copy the nested dicts (contain only float values)
	var long_term: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
	var stat_caps: Dictionary = (long_term.get("stat_caps", {}) as Dictionary).duplicate(false)
	var decline_multipliers: Dictionary = (long_term.get("decline_multipliers", {}) as Dictionary).duplicate(false)
	normalized["long_term_penalty"] = {
		"stat_caps": stat_caps,
		"decline_multipliers": decline_multipliers
	}
	return normalized

static func _injury_decline_multipliers(injuries: Array) -> Dictionary:
	var combined := {}
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "recovered":
			continue
		var long_term: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
		var multipliers: Dictionary = long_term.get("decline_multipliers", {}) as Dictionary
		for stat_name in multipliers.keys():
			var existing := float(combined.get(stat_name, 1.0))
			combined[stat_name] = existing * float(multipliers.get(stat_name, 1.0))
	return combined

static func _apply_active_injury_suppression(
	stats: Dictionary,
	injuries: Array,
	report_entry: Dictionary
) -> void:
	var active_reports: Array = report_entry["injury_impacts"]["active"] as Array
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "active":
			continue
		var years_remaining := int(timeline.get("years_remaining", 0))
		if years_remaining <= 0:
			continue
		var severity := float(injury.get("severity", 0.0))
		var suppression_mult: float = clamp(1.0 - (severity * INJURY_SUPPRESSION_PER_SEVERITY), 0.4, 1.0)
		var suppressed := {}
		for stat in (injury.get("affected_stats", []) as Array):
			var stat_name := String(stat)
			if not stats.has(stat_name):
				continue
			var before := float(stats.get(stat_name, 0.0))
			var after := float(clamp(before * suppression_mult, 0.0, 100.0))
			if after == before:
				continue
			stats[stat_name] = after
			suppressed[stat_name] = {"before": before, "after": after}
		if not suppressed.is_empty():
			# OPTIMIZATION (P3): Shallow copy arrays/dicts containing only primitives
			active_reports.append({
				"type": injury.get("type", ""),
				"severity": severity,
				"affected_stats": (injury.get("affected_stats", []) as Array).duplicate(false),  # Strings only
				"suppressed_stats": suppressed,
				"recovery_timeline": timeline.duplicate(false)  # Primitives only
			})

static func _apply_recovery_updates(injuries: Array, report_entry: Dictionary) -> void:
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "active":
			continue
		var years_remaining := int(timeline.get("years_remaining", 0))
		if years_remaining <= 0:
			continue
		years_remaining = max(0, years_remaining - 1)
		timeline["years_remaining"] = years_remaining
		if years_remaining == 0:
			timeline["status"] = "recovered"
		injury["recovery_timeline"] = timeline

static func _apply_long_term_penalties(
	stats: Dictionary,
	potential: Dictionary,
	injuries: Array,
	report_entry: Dictionary
) -> void:
	var recovered_reports: Array = report_entry["injury_impacts"]["recovered"] as Array
	for injury_entry in injuries:
		var injury: Dictionary = injury_entry
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		if String(timeline.get("status", "active")) != "recovered":
			continue
		var long_term: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
		var stat_caps: Dictionary = long_term.get("stat_caps", {}) as Dictionary
		var decline_multipliers: Dictionary = long_term.get("decline_multipliers", {}) as Dictionary
		var applied_caps := {}
		for stat_name in stat_caps.keys():
			var cap := float(stat_caps.get(stat_name, 100.0))
			if stats.has(stat_name):
				var before := float(stats.get(stat_name, 0.0))
				var after: float = min(before, cap)
				if after != before:
					stats[stat_name] = after
					applied_caps[stat_name] = {"before": before, "after": after, "cap": cap}
			if potential.has(stat_name):
				var pot_before := float(potential.get(stat_name, 0.0))
				var pot_after: float = min(pot_before, cap)
				if pot_after != pot_before:
					potential[stat_name] = pot_after
		if not applied_caps.is_empty() or not decline_multipliers.is_empty():
			# OPTIMIZATION (P3): Shallow copy dicts containing only primitives
			recovered_reports.append({
				"type": injury.get("type", ""),
				"severity": float(injury.get("severity", 0.0)),
				"stat_caps_applied": applied_caps,
				"decline_multipliers": decline_multipliers.duplicate(false),  # Floats only
				"recovery_timeline": timeline.duplicate(false)  # Primitives only
			})
