extends RefCounted
class_name ScoreCache

## Scout evaluation caching system for eliminating redundant player evaluations.
##
## Problem: In college recruiting and NFL draft, the same scout evaluates the same
## player multiple times (e.g., 200 players × 7 rounds × 32 teams = 44,800 evaluations).
## Many of these are redundant when player and scout states haven't changed.
##
## Solution: Hash-based cache that keys on player+scout state. Cache hits return
## stored results, preserving determinism while eliminating redundant computation.
##
## Determinism guarantee: Cached results ALWAYS match non-cached results for
## identical inputs. Cache only stores results, never affects RNG state.
##
## Usage:
##   var cache := {}  # Per-phase cache
##   var result := ScoreCache.score_player_cached(
##       player, scout_dict, positions_cfg, stats_cfg, class_rules, rng, cache
##   )
##   # Or with Scout resource:
##   var result := ScoreCache.score_player_cached_resource(
##       player, scout_resource, positions_cfg, stats_cfg, class_rules, rng, cache
##   )

const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")

## Cached evaluation using dictionary-based scout (ScoutRuntime pattern).
##
## Returns the scout evaluation score with caching. If the player+scout combination
## has been evaluated before (cache hit), returns the cached result. Otherwise,
## evaluates the player, stores the result, and returns it (cache miss).
##
## CRITICAL: This function is deterministic. Cached results match non-cached results
## exactly for the same inputs. The RNG state is preserved correctly - on cache hits,
## we consume the exact same number of random values that would have been consumed
## during the original evaluation.
##
## Parameters:
##   player: Player dictionary with stats, potential, position, age, physical attributes
##   scout: Scout dictionary (from scouts.json) with base_skill, stat_skill, etc.
##   positions_cfg: Position configuration
##   stats_cfg: Stats configuration (for measurement difficulty)
##   class_rules: Class rules for rating calculation
##   rng: RandomNumberGenerator - RNG state is consumed consistently
##   cache: Dictionary - mutable cache passed by reference (modified in-place)
##
## Returns: float score (0-100 composite rating)
static func score_player_cached(
	player: Dictionary,
	scout: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator,
	cache: Dictionary
) -> float:
	var key := _cache_key_dict(player, scout, stats_cfg)

	if cache.has(key):
		# Cache hit: Consume RNG to maintain determinism
		# ScoutRuntime.score_player calls _perceive twice, each consuming RNG per stat
		_consume_rng_for_cached_score(player, scout, stats_cfg, rng)
		return float(cache[key])

	# Cache miss: Compute and store
	var result := ScoutRuntime.score_player(
		scout,
		player,
		positions_cfg,
		stats_cfg,
		class_rules,
		rng
	)
	cache[key] = result
	return result


## Cached evaluation using Scout resource (Scout.gd pattern).
##
## Same as score_player_cached but uses Scout resource instead of dictionary.
## Preserves determinism by consuming RNG on cache hits.
##
## Parameters:
##   player: Player dictionary
##   scout: Scout resource instance
##   positions_cfg: Position configuration
##   stats_cfg: Stats configuration
##   class_rules: Class rules
##   rng: RandomNumberGenerator
##   cache: Dictionary - mutable cache (modified in-place)
##
## Returns: float score (0-100 composite rating)
static func score_player_cached_resource(
	player: Dictionary,
	scout: Scout,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator,
	cache: Dictionary
) -> float:
	var key := _cache_key_resource(player, scout, stats_cfg)

	if cache.has(key):
		# Cache hit: Consume RNG to maintain determinism
		_consume_rng_for_cached_score_resource(player, scout, stats_cfg, rng)
		return float(cache[key])

	# Cache miss: Compute and store
	var result := scout.score_player(
		player,
		positions_cfg,
		stats_cfg,
		class_rules,
		rng
	)
	cache[key] = result
	return result


## Generate cache key for dictionary-based scout.
##
## Key format: "{player_hash}_{scout_hash}"
##
## Player hash includes ONLY fields that affect evaluation:
##   - stats (current ratings)
##   - potential (future ratings)
##   - position (affects composite calculation)
##   - age (if used in evaluation)
##   - physical attributes (if used)
##
## Player hash EXCLUDES fields that don't affect scoring:
##   - player_id (identity, not evaluation)
##   - name (cosmetic)
##   - development_reports (not used in scoring)
##   - home_region (used in recruiting offers, not in base scoring)
##
## Scout hash includes ONLY fields that affect perception/evaluation:
##   - base_skill
##   - tape_grinder, risk_aversion, overrate_athletes
##   - stat_skill, estimation_multipliers, valuation_multipliers
##
## Returns: String cache key
static func _cache_key_dict(player: Dictionary, scout: Dictionary, stats_cfg: Dictionary) -> String:
	var player_hash := _hash_player_state(player, stats_cfg)
	var scout_hash := _hash_scout_dict_state(scout)
	return "%s_%s" % [player_hash, scout_hash]


## Generate cache key for resource-based scout.
##
## Same as _cache_key_dict but extracts state from Scout resource.
##
## Returns: String cache key
static func _cache_key_resource(player: Dictionary, scout: Scout, stats_cfg: Dictionary) -> String:
	var player_hash := _hash_player_state(player, stats_cfg)
	var scout_hash := _hash_scout_resource_state(scout)
	return "%s_%s" % [player_hash, scout_hash]


## Hash player state for cache key.
##
## Includes only fields that affect scout evaluation:
##   - stats: Current ratings (all stats that affect composite)
##   - potential: Future ratings
##   - position: Affects position-specific weights
##   - age: May affect evaluation (if implemented)
##
## Excludes identity/cosmetic fields (id, name, etc.).
##
## Hash algorithm: FNV-1a 64-bit for fast, collision-resistant hashing.
##
## Returns: String hex hash of player state
static func _hash_player_state(player: Dictionary, stats_cfg: Dictionary) -> String:
	# Extract evaluation-relevant fields
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var potential: Dictionary = player.get("potential", {}) as Dictionary
	var position := String(player.get("position", ""))
	var age := int(player.get("age", 0))

	# Build canonical representation
	# Sort stat keys for deterministic ordering
	var stat_keys := stats.keys()
	stat_keys.sort()

	var parts: Array = []
	parts.append("pos:%s" % position)
	parts.append("age:%d" % age)

	# Add stats in sorted order
	parts.append("stats:")
	for key in stat_keys:
		var value := float(stats.get(key, 0.0))
		# Use fixed precision to avoid floating-point drift
		parts.append("%s=%.2f" % [key, value])

	# Add potential in sorted order
	var pot_keys := potential.keys()
	pot_keys.sort()
	parts.append("pot:")
	for key in pot_keys:
		var value := float(potential.get(key, 0.0))
		parts.append("%s=%.2f" % [key, value])

	var canonical := "|".join(parts)
	return _fnv1a_64_hex(canonical)


## Hash scout dictionary state for cache key.
##
## Includes fields that affect perception/evaluation:
##   - base_skill: Overall perception accuracy
##   - tape_grinder: Potential weight
##   - risk_aversion: Affects potential blend
##   - overrate_athletes: Athleticism bias
##   - stat_skill: Per-stat perception accuracy
##   - estimation_multipliers: Perception modifiers
##   - valuation_multipliers: Evaluation modifiers
##
## Returns: String hex hash of scout state
static func _hash_scout_dict_state(scout: Dictionary) -> String:
	var parts: Array = []

	# Core attributes
	parts.append("base:%.3f" % float(scout.get("base_skill", 0.55)))
	parts.append("tape:%.3f" % float(scout.get("tape_grinder", 0.25)))
	parts.append("risk:%.3f" % float(scout.get("risk_aversion", 0.10)))
	parts.append("ath:%.3f" % float(scout.get("overrate_athletes", 0.0)))

	# Dictionaries in sorted order
	var stat_skill: Dictionary = scout.get("stat_skill", {}) as Dictionary
	if not stat_skill.is_empty():
		var keys := stat_skill.keys()
		keys.sort()
		parts.append("ss:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(stat_skill.get(k, 0.0))])

	var est_mult: Dictionary = scout.get("estimation_multipliers", {}) as Dictionary
	if not est_mult.is_empty():
		var keys := est_mult.keys()
		keys.sort()
		parts.append("em:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(est_mult.get(k, 0.0))])

	var val_mult: Dictionary = scout.get("valuation_multipliers", {}) as Dictionary
	if not val_mult.is_empty():
		var keys := val_mult.keys()
		keys.sort()
		parts.append("vm:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(val_mult.get(k, 0.0))])

	var canonical := "|".join(parts)
	return _fnv1a_64_hex(canonical)


## Hash scout resource state for cache key.
##
## Extracts state from Scout resource and hashes relevant fields.
##
## Returns: String hex hash of scout state
static func _hash_scout_resource_state(scout: Scout) -> String:
	var parts: Array = []

	# Core attributes
	parts.append("base:%.3f" % scout.base_skill)
	parts.append("tape:%.3f" % scout.tape_grinder)
	parts.append("risk:%.3f" % scout.risk_aversion)
	parts.append("ath:%.3f" % scout.overrate_athletes)

	# Current/potential weights
	parts.append("cur:%.3f" % scout.current_weight)
	parts.append("pot:%.3f" % scout.potential_weight)

	# Board calibration
	parts.append("off:%.3f" % scout.board_offset_pts)
	parts.append("slope:%.3f" % scout.board_slope)
	parts.append("noise:%.3f" % scout.board_noise_sigma)

	# Dictionaries in sorted order
	if not scout.stat_skill.is_empty():
		var keys := scout.stat_skill.keys()
		keys.sort()
		parts.append("ss:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(scout.stat_skill.get(k, 0.0))])

	if not scout.estimation_multipliers.is_empty():
		var keys := scout.estimation_multipliers.keys()
		keys.sort()
		parts.append("em:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(scout.estimation_multipliers.get(k, 0.0))])

	if not scout.valuation_multipliers.is_empty():
		var keys := scout.valuation_multipliers.keys()
		keys.sort()
		parts.append("vm:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(scout.valuation_multipliers.get(k, 0.0))])

	if not scout.bucket_weights.is_empty():
		var keys := scout.bucket_weights.keys()
		keys.sort()
		parts.append("bw:")
		for k in keys:
			parts.append("%s=%.3f" % [k, float(scout.bucket_weights.get(k, 0.0))])

	var canonical := "|".join(parts)
	return _fnv1a_64_hex(canonical)


## Consume RNG to maintain determinism on cache hits (dict-based scout).
##
## When we get a cache hit, we must consume the same number of random values
## that would have been consumed during the original evaluation. This ensures
## that subsequent RNG calls produce the same results regardless of cache state.
##
## ScoutRuntime.score_player workflow:
##   1. _perceive(current): Consumes RNG per stat
##   2. _perceive_potential(potential): Consumes RNG per stat
##   3. Final board_noise (not in dict-based, but in resource-based)
##
## Total RNG calls: 2 × num_stats (one gaussian() per stat per perception)
##
## Parameters:
##   player: Player being evaluated
##   scout: Scout performing evaluation
##   stats_cfg: Stats configuration (determines number of stats)
##   rng: RandomNumberGenerator to advance
static func _consume_rng_for_cached_score(
	player: Dictionary,
	scout: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	# ScoutRuntime.score_player calls _perceive twice (current + potential)
	# Each _perceive calls StatHelpers.gaussian() once per stat (if sigma > 0)
	var stats_list: Array = stats_cfg.get("stats", []) as Array
	var num_stats := stats_list.size()

	# 2 perceptions × num_stats gaussians
	# Each gaussian consumes 2 randf() calls (Box-Muller transform)
	var total_randf_calls := 2 * num_stats * 2

	for i in range(total_randf_calls):
		rng.randf()  # Consume random value


## Consume RNG to maintain determinism on cache hits (resource-based scout).
##
## Scout.score_player workflow:
##   1. _perceived_player(current): Consumes RNG per stat (randfn)
##   2. _perceived_player(potential): Consumes RNG per stat (randfn)
##   3. Final board_noise: Consumes 1 randfn
##
## Each randfn() call consumes 2 randf() calls internally (Box-Muller transform)
## Total RNG calls: (2 × num_stats + 1) × 2 randf per randfn
##
## Parameters:
##   player: Player being evaluated
##   scout: Scout resource performing evaluation
##   stats_cfg: Stats configuration
##   rng: RandomNumberGenerator to advance
static func _consume_rng_for_cached_score_resource(
	player: Dictionary,
	scout: Scout,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	# Scout.score_player calls _perceived_player twice + board_noise
	var stats_list: Array = stats_cfg.get("stats", []) as Array
	var num_stats := stats_list.size()

	# 2 perceptions × num_stats randfn calls
	var perception_randfn_calls := 2 * num_stats

	# 1 board_noise randfn call
	var board_noise_randfn_calls := 1

	# Each randfn consumes 2 randf calls
	var total_randfn_calls := perception_randfn_calls + board_noise_randfn_calls
	var total_randf_calls := total_randfn_calls * 2

	for i in range(total_randf_calls):
		rng.randf()  # Consume random value


## FNV-1a 64-bit hash (returns hex string).
##
## Fast, collision-resistant hash for cache keys.
## Returns hex string instead of int to avoid Godot integer overflow issues.
##
## Algorithm: FNV-1a (Fowler-Noll-Vo)
##   offset_basis = 14695981039346656037
##   prime = 1099511628211
##   hash = offset_basis
##   for each byte:
##     hash ^= byte
##     hash *= prime
##
## Returns: String hex hash (16 characters)
static func _fnv1a_64_hex(text: String) -> String:
	# FNV-1a 64-bit constants
	var hash: int = -3750763034362895579  # 0xcbf29ce484222325 as signed int64
	var prime: int = 1099511628211        # 0x100000001b3

	for byte in text.to_utf8_buffer():
		hash = (hash ^ byte) & 0x7FFFFFFFFFFFFFFF  # XOR and mask to prevent overflow
		hash = (hash * prime) & 0x7FFFFFFFFFFFFFFF  # Multiply and mask

	# Convert to hex string (unsigned representation)
	return "%016x" % (hash & 0x7FFFFFFFFFFFFFFF)


## Get cache statistics for performance monitoring.
##
## Returns dictionary with:
##   - size: Number of cached entries
##   - keys: Sample of cache keys (for debugging)
##
## Parameters:
##   cache: Cache dictionary
##   sample_size: Number of sample keys to include (default 5)
##
## Returns: Dictionary with cache stats
static func get_cache_stats(cache: Dictionary, sample_size: int = 5) -> Dictionary:
	var keys := cache.keys()
	var sample := []
	for i in range(min(sample_size, keys.size())):
		sample.append(keys[i])

	return {
		"size": cache.size(),
		"sample_keys": sample
	}


## Clear cache (call between phases to invalidate stale entries).
##
## Cache should be cleared when player or scout states might have changed:
##   - Between recruiting phases
##   - Between draft rounds (if player states change)
##   - After contract negotiations
##   - On season transitions
##
## Parameters:
##   cache: Cache dictionary to clear
static func clear_cache(cache: Dictionary) -> void:
	cache.clear()
