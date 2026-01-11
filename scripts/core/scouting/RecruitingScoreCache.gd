extends RefCounted
class_name RecruitingScoreCache

## Year-scoped recruiting score cache for deterministic scout evaluations.
##
## Task P2: Recruiting Score Cache (Deterministic)
##
## This cache memoizes scout evaluations per recruit within a year, reducing
## hot-path costs while preserving identical outcomes. Cache entries are keyed
## by (year, scout_id, player_id, phase) to avoid cross-year contamination.
##
## Key Features:
##   1. Per-year isolation: Cache automatically scoped by year
##   2. Per-phase support: Different phases (recruiting, draft) use separate keys
##   3. Deterministic seeding: Each scout/player gets deterministic RNG seed
##   4. RNG preservation: Cache hits consume identical RNG as cache misses
##
## Usage:
##   # Create cache for a year
##   var cache := RecruitingScoreCache.new(2025)
##
##   # Score player with automatic caching
##   var score := cache.get_or_compute(
##       player_dict,
##       scout_dict,
##       "scout_001",
##       "recruiting",
##       positions_cfg,
##       stats_cfg,
##       class_rules,
##       base_rng
##   )
##
## Determinism Guarantee:
##   For fixed inputs (year, seed, player, scout), outputs are byte-identical
##   regardless of cache state. This is achieved by:
##     1. Deriving per-scout/per-player seeds from base seed
##     2. Consuming RNG on cache hits to match cache misses
##     3. Using stable hash keys based only on evaluation-relevant fields

const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")
const Rand = preload("res://autoloads/Rand.gd")

## Year this cache is scoped to
var year: int

## Internal cache storage: {cache_key: float}
var _cache: Dictionary = {}

## Cache statistics
var _hits: int = 0
var _misses: int = 0


## Initialize cache for a specific year.
##
## Parameters:
##   p_year: Year this cache applies to (e.g., 2025)
func _init(p_year: int) -> void:
	year = p_year


## Get or compute scout evaluation score with automatic caching.
##
## This is the main entry point for cached evaluations. It handles:
##   1. Cache key generation from (year, scout_id, player_id, phase)
##   2. Cache hit/miss detection
##   3. Deterministic seed derivation for evaluation
##   4. RNG state preservation on cache hits
##
## RNG BEHAVIOR:
##   - On cache miss: Creates deterministic RNG from base_seed + cache_key_hash
##   - On cache hit: Consumes same RNG calls to maintain determinism
##   - base_rng is NEVER consumed by this function (isolated evaluation)
##
## Parameters:
##   player: Player dictionary with stats, potential, position
##   scout: Scout dictionary (from scouts.json) or Scout resource
##   scout_id: Unique scout identifier (e.g., "college_001", "nfl_team_sf")
##   phase: Evaluation phase (e.g., "recruiting", "draft_round_1")
##   positions_cfg: Position configuration
##   stats_cfg: Stats configuration (for measurement difficulty)
##   class_rules: Class rules for rating calculation
##   base_seed: Base RNG seed (NOT consumed, used for derivation only)
##
## Returns: float score (0-100 composite rating)
func get_or_compute(
	player: Dictionary,
	scout: Variant,  # Dictionary or Scout resource
	scout_id: String,
	phase: String,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	base_seed: int
) -> float:
	var player_id := String(player.get("player_id", ""))

	# Generate cache key
	var key := _make_cache_key(year, scout_id, player_id, phase, player, scout, stats_cfg)

	# Check cache
	if _cache.has(key):
		_hits += 1
		# Cache hit: Consume RNG to maintain determinism
		var eval_seed := _derive_evaluation_seed_from_state(base_seed, player, scout, stats_cfg)
		var eval_rng := RandomNumberGenerator.new()
		eval_rng.seed = eval_seed
		_consume_rng_for_evaluation(player, scout, stats_cfg, eval_rng)
		return float(_cache[key])

	# Cache miss: Compute score with deterministic seed
	_misses += 1
	var eval_seed := _derive_evaluation_seed_from_state(base_seed, player, scout, stats_cfg)
	var eval_rng := RandomNumberGenerator.new()
	eval_rng.seed = eval_seed

	var score: float
	if scout is Scout:
		score = scout.score_player(player, positions_cfg, stats_cfg, class_rules, eval_rng)
	else:
		score = ScoutRuntime.score_player(scout, player, positions_cfg, stats_cfg, class_rules, eval_rng)

	# Store in cache
	_cache[key] = score
	return score


## Generate cache key from year, scout, player, and phase.
##
## Key format: "Y{year}_S{scout_hash}_P{player_hash}_PH{phase_hash}"
##
## This ensures:
##   1. Year isolation: Different years never share cache entries
##   2. Scout isolation: Different scouts get independent evaluations
##   3. Player isolation: Different players get independent evaluations
##   4. Phase isolation: Different phases (recruiting vs draft) are separated
##
## The key includes hashes of player and scout state to detect changes while
## keeping keys reasonably sized.
##
## Parameters:
##   p_year: Year
##   p_scout_id: Scout identifier string
##   p_player_id: Player identifier string
##   p_phase: Phase identifier string
##   player: Player dictionary (for state hash)
##   scout: Scout dictionary or resource (for state hash)
##   stats_cfg: Stats configuration
##
## Returns: String cache key
static func _make_cache_key(
	p_year: int,
	p_scout_id: String,
	p_player_id: String,
	p_phase: String,
	player: Dictionary,
	scout: Variant,
	stats_cfg: Dictionary
) -> String:
	# Hash player state (stats, potential, position)
	var player_hash := _hash_player_state(player, stats_cfg)

	# Hash scout state
	var scout_hash: String
	if scout is Scout:
		scout_hash = _hash_scout_resource_state(scout)
	else:
		scout_hash = _hash_scout_dict_state(scout)

	# Hash phase for collision resistance
	var phase_hash := _fnv1a_32(p_phase)

	# Combine into cache key
	return "Y%d_S%s_%s_P%s_%s_PH%s" % [
		p_year,
		p_scout_id,
		scout_hash,
		p_player_id,
		player_hash,
		phase_hash
	]


## Derive deterministic evaluation seed from player and scout state.
##
## This creates a reproducible RNG seed based ONLY on player and scout state,
## NOT on year/phase/scout_id. This ensures that:
##   1. Same player + same scout skills = same evaluation score
##   2. Year, phase, and scout_id affect cache isolation but not evaluation
##   3. Seed derivation is order-independent (parallelizable)
##
## The seed is derived using:
##   eval_seed = splitmix64(base_seed XOR hash(player_state + scout_state))
##
## Parameters:
##   base_seed: Base RNG seed
##   player: Player dictionary
##   scout: Scout (dict or resource)
##   stats_cfg: Stats configuration
##
## Returns: int evaluation seed
static func _derive_evaluation_seed_from_state(
	base_seed: int,
	player: Dictionary,
	scout: Variant,
	stats_cfg: Dictionary
) -> int:
	# Hash player and scout state (not year/phase/scout_id)
	var player_hash := _hash_player_state(player, stats_cfg)
	var scout_hash: String
	if scout is Scout:
		scout_hash = _hash_scout_resource_state(scout)
	else:
		scout_hash = _hash_scout_dict_state(scout)

	# Combine hashes for seed derivation
	var combined := "%s_%s" % [player_hash, scout_hash]
	var combined_hash := _fnv1a_64(combined)
	return Rand.splitmix64(base_seed ^ combined_hash)


## Consume RNG to maintain determinism on cache hits.
##
## When we return a cached score, we must consume the same number of RNG calls
## that would have been consumed during the original evaluation. This ensures
## that subsequent RNG-dependent operations produce identical results regardless
## of cache state.
##
## RNG consumption pattern depends on scout type:
##   - Dictionary scout (ScoutRuntime): 2 perceptions × num_stats × 2 randf per gaussian
##   - Resource scout (Scout): 2 perceptions × num_stats × 2 randf + 1 board_noise × 2 randf
##
## Parameters:
##   player: Player being evaluated (unused, for future optimization)
##   scout: Scout performing evaluation (dict or resource)
##   stats_cfg: Stats configuration (determines num_stats)
##   rng: RandomNumberGenerator to advance
static func _consume_rng_for_evaluation(
	player: Dictionary,
	scout: Variant,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var stats_list: Array = stats_cfg.get("stats", []) as Array
	var num_stats := stats_list.size()

	if scout is Scout:
		# Scout.score_player:
		#   - _perceived_player (current): num_stats randfn calls
		#   - _perceived_player (potential): num_stats randfn calls
		#   - board_noise: 1 randfn call
		# Each randfn consumes 2 randf calls (Box-Muller transform)
		var total_randfn := (2 * num_stats) + 1
		var total_randf := total_randfn * 2
		for i in range(total_randf):
			rng.randf()
	else:
		# ScoutRuntime.score_player:
		#   - _perceive (current): num_stats gaussian calls
		#   - _perceive_potential (potential): num_stats gaussian calls
		# Each gaussian (StatHelpers) consumes 2 randf calls
		var total_randf := 2 * num_stats * 2
		for i in range(total_randf):
			rng.randf()


## Hash player state for cache key.
##
## Includes only fields that affect scout evaluation:
##   - stats: Current ratings
##   - potential: Future ratings
##   - position: Affects position-specific weights
##   - age: May affect evaluation
##
## Excludes identity/cosmetic fields (player_id, name, home_region, etc.).
##
## Returns: String hash (8-character hex)
static func _hash_player_state(player: Dictionary, stats_cfg: Dictionary) -> String:
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var potential: Dictionary = player.get("potential", {}) as Dictionary
	var position := String(player.get("position", ""))
	var age := int(player.get("age", 0))

	# Build canonical representation (sorted keys for stability)
	var parts: Array = []
	parts.append("pos:%s" % position)
	parts.append("age:%d" % age)

	# Stats in sorted order
	var stat_keys := stats.keys()
	stat_keys.sort()
	parts.append("stats:")
	for key in stat_keys:
		parts.append("%s=%.2f" % [key, float(stats.get(key, 0.0))])

	# Potential in sorted order
	var pot_keys := potential.keys()
	pot_keys.sort()
	parts.append("pot:")
	for key in pot_keys:
		parts.append("%s=%.2f" % [key, float(potential.get(key, 0.0))])

	return _fnv1a_32("|".join(parts))


## Hash scout dictionary state for cache key.
##
## Includes fields that affect evaluation:
##   - base_skill, tape_grinder, risk_aversion, overrate_athletes
##   - stat_skill, estimation_multipliers, valuation_multipliers
##
## Returns: String hash (8-character hex)
static func _hash_scout_dict_state(scout: Dictionary) -> String:
	var parts: Array = []
	parts.append("base:%.3f" % float(scout.get("base_skill", 0.55)))
	parts.append("tape:%.3f" % float(scout.get("tape_grinder", 0.25)))
	parts.append("risk:%.3f" % float(scout.get("risk_aversion", 0.10)))
	parts.append("ath:%.3f" % float(scout.get("overrate_athletes", 0.0)))

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

	return _fnv1a_32("|".join(parts))


## Hash scout resource state for cache key.
##
## Extracts and hashes relevant fields from Scout resource.
##
## Returns: String hash (8-character hex)
static func _hash_scout_resource_state(scout: Scout) -> String:
	var parts: Array = []
	parts.append("base:%.3f" % scout.base_skill)
	parts.append("tape:%.3f" % scout.tape_grinder)
	parts.append("risk:%.3f" % scout.risk_aversion)
	parts.append("ath:%.3f" % scout.overrate_athletes)
	parts.append("cur:%.3f" % scout.current_weight)
	parts.append("pot:%.3f" % scout.potential_weight)
	parts.append("off:%.3f" % scout.board_offset_pts)
	parts.append("slope:%.3f" % scout.board_slope)
	parts.append("noise:%.3f" % scout.board_noise_sigma)

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

	return _fnv1a_32("|".join(parts))


## FNV-1a 64-bit hash (returns int).
##
## Used for seed derivation (XOR with base seed).
##
## Returns: int hash
static func _fnv1a_64(text: String) -> int:
	var hash: int = -3750763034362895579  # 0xcbf29ce484222325 as signed int64
	var prime: int = 1099511628211        # 0x100000001b3
	for byte in text.to_utf8_buffer():
		hash = (hash ^ byte) & 0x7FFFFFFFFFFFFFFF
		hash = (hash * prime) & 0x7FFFFFFFFFFFFFFF
	return hash


## FNV-1a 32-bit hash (returns 8-char hex string).
##
## Used for compact cache keys. 32-bit provides sufficient collision resistance
## for cache keys while keeping them shorter.
##
## Returns: String hex hash (8 characters)
static func _fnv1a_32(text: String) -> String:
	var hash: int = 0x811c9dc5  # FNV-1a 32-bit offset basis
	var prime: int = 0x01000193 # FNV-1a 32-bit prime
	for byte in text.to_utf8_buffer():
		hash = ((hash ^ byte) * prime) & 0xFFFFFFFF
	return "%08x" % hash


## Get cache statistics for performance monitoring.
##
## Returns dictionary with:
##   - size: Number of cached entries
##   - hits: Number of cache hits
##   - misses: Number of cache misses
##   - hit_rate: Cache hit rate (0.0 to 1.0)
##
## Returns: Dictionary with cache stats
func get_stats() -> Dictionary:
	var total := _hits + _misses
	var hit_rate := 0.0 if total == 0 else float(_hits) / float(total)
	return {
		"year": year,
		"size": _cache.size(),
		"hits": _hits,
		"misses": _misses,
		"hit_rate": hit_rate
	}


## Clear cache and reset statistics.
##
## Call this when transitioning between years or when player/scout states
## may have changed in ways not reflected in the cache keys.
func clear() -> void:
	_cache.clear()
	_hits = 0
	_misses = 0
