extends RefCounted

## Test suite for ScoreCache (Task F3: Scout Evaluation Caching)
##
## Tests verify:
##   1. Cache correctness: Cached results match non-cached results exactly
##   2. Determinism: Same inputs produce same outputs regardless of cache state
##   3. Cache hits: Cache successfully stores and retrieves evaluations
##   4. RNG consistency: RNG state is identical with/without caching
##   5. Hash key generation: Different players/scouts produce different keys

const ScoreCache = preload("res://scripts/core/scouting/ScoreCache.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")


func run(t) -> void:
	var stats_cfg := {
		"stats": [
			{"name": "speed", "measurement_difficulty": 0.3},
			{"name": "strength", "measurement_difficulty": 0.5},
			{"name": "agility", "measurement_difficulty": 0.4},
			{"name": "awareness", "measurement_difficulty": 0.7}
		]
	}

	var positions_cfg := {
		"QB": {
			"core_stats": ["awareness"],
			"distributions": {"speed": {"role": "athletic"}}
		},
		"RB": {
			"core_stats": ["agility"],
			"distributions": {"speed": {"role": "athletic"}}
		}
	}

	var class_rules := {
		"recruiting": {
			"composite_weights": {
				"athletic": 0.40,
				"core": 0.30,
				"secondary": 0.20,
				"mentals": 0.10
			},
			"athletic_keys": ["speed", "agility"],
			"mental_keys": ["awareness"]
		}
	}

	# Test 1: Cache correctness (dict-based scout)
	_test_cache_correctness_dict(t, stats_cfg, positions_cfg, class_rules)

	# Test 2: Cache correctness (resource-based scout)
	_test_cache_correctness_resource(t, stats_cfg, positions_cfg, class_rules)

	# Test 3: Determinism with cache
	_test_determinism_with_cache(t, stats_cfg, positions_cfg, class_rules)

	# Test 4: Cache hit behavior
	_test_cache_hit_behavior(t, stats_cfg, positions_cfg, class_rules)

	# Test 5: RNG consistency
	_test_rng_consistency(t, stats_cfg, positions_cfg, class_rules)

	# Test 6: Hash key uniqueness
	_test_hash_key_uniqueness(t, stats_cfg)

	# Test 7: Hash key stability
	_test_hash_key_stability(t, stats_cfg)

	# Test 8: Cache invalidation
	_test_cache_invalidation(t, stats_cfg, positions_cfg, class_rules)


## Test: Cached results match non-cached results (dict-based scout)
func _test_cache_correctness_dict(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := {
		"player_id": "P1",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 75.0, "strength": 70.0, "agility": 72.0, "awareness": 68.0},
		"potential": {"speed": 82.0, "strength": 78.0, "agility": 80.0, "awareness": 75.0}
	}

	var scout := {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var seed := 12345

	# Evaluate without cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var score_no_cache := ScoutRuntime.score_player(
		scout, player, positions_cfg, stats_cfg, class_rules, rng1
	)

	# Evaluate with cache (cold)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var cache := {}
	var score_with_cache := ScoreCache.score_player_cached(
		player, scout, positions_cfg, stats_cfg, class_rules, rng2, cache
	)

	t.assert_approx(score_with_cache, score_no_cache, 0.001,
		"ScoreCache (dict): cached score matches non-cached score")
	t.assert_equal(cache.size(), 1, "ScoreCache (dict): cache populated with 1 entry")


## Test: Cached results match non-cached results (resource-based scout)
func _test_cache_correctness_resource(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := {
		"player_id": "P2",
		"position": "RB",
		"age": 20,
		"stats": {"speed": 80.0, "strength": 75.0, "agility": 78.0, "awareness": 65.0},
		"potential": {"speed": 85.0, "strength": 80.0, "agility": 82.0, "awareness": 70.0}
	}

	var scout := Scout.new()
	scout.base_skill = 0.6
	scout.tape_grinder = 0.3
	scout.risk_aversion = 0.1
	scout.current_weight = 0.75
	scout.potential_weight = 0.25
	scout.board_noise_sigma = 1.5
	scout.setup(stats_cfg, {}, RandomNumberGenerator.new())

	var seed := 54321

	# Evaluate without cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var score_no_cache := scout.score_player(
		player, positions_cfg, stats_cfg, class_rules, rng1
	)

	# Evaluate with cache (cold)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var cache := {}
	var score_with_cache := ScoreCache.score_player_cached_resource(
		player, scout, positions_cfg, stats_cfg, class_rules, rng2, cache
	)

	t.assert_approx(score_with_cache, score_no_cache, 0.001,
		"ScoreCache (resource): cached score matches non-cached score")


## Test: Determinism with cache (multiple evaluations)
func _test_determinism_with_cache(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := {
		"player_id": "P3",
		"position": "QB",
		"age": 22,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 72.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 78.0}
	}

	var scout := {
		"base_skill": 0.55,
		"tape_grinder": 0.25,
		"risk_aversion": 0.15,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var seed := 99999

	# Run 1: Fresh cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var cache1 := {}
	var score1 := ScoreCache.score_player_cached(
		player, scout, positions_cfg, stats_cfg, class_rules, rng1, cache1
	)

	# Run 2: Fresh cache (different instance)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var cache2 := {}
	var score2 := ScoreCache.score_player_cached(
		player, scout, positions_cfg, stats_cfg, class_rules, rng2, cache2
	)

	# Run 3: Use existing cache (cache hit)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = seed
	var score3 := ScoreCache.score_player_cached(
		player, scout, positions_cfg, stats_cfg, class_rules, rng3, cache2
	)

	t.assert_approx(score1, score2, 0.001, "ScoreCache: deterministic across fresh caches")
	t.assert_approx(score1, score3, 0.001, "ScoreCache: cache hit produces same result")


## Test: Cache hit behavior
func _test_cache_hit_behavior(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := {
		"player_id": "P4",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 72.0, "strength": 71.0, "agility": 70.0, "awareness": 73.0},
		"potential": {"speed": 77.0, "strength": 76.0, "agility": 75.0, "awareness": 79.0}
	}

	var scout := {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var seed := 22222
	var cache := {}

	# First evaluation (cache miss)
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var score1 := ScoreCache.score_player_cached(
		player, scout, positions_cfg, stats_cfg, class_rules, rng1, cache
	)

	t.assert_equal(cache.size(), 1, "ScoreCache: cache populated after first eval")

	# Second evaluation (cache hit)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var score2 := ScoreCache.score_player_cached(
		player, scout, positions_cfg, stats_cfg, class_rules, rng2, cache
	)

	t.assert_equal(cache.size(), 1, "ScoreCache: cache size unchanged after hit")
	t.assert_approx(score1, score2, 0.001, "ScoreCache: cache hit returns same score")


## Test: RNG consistency across cached/non-cached paths
func _test_rng_consistency(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player1 := {
		"player_id": "P5",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}

	var player2 := {
		"player_id": "P6",
		"position": "RB",
		"age": 20,
		"stats": {"speed": 82.0, "strength": 78.0, "agility": 80.0, "awareness": 67.0},
		"potential": {"speed": 86.0, "strength": 82.0, "agility": 84.0, "awareness": 72.0}
	}

	var scout := {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var seed := 33333

	# Path 1: No cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var score1a := ScoutRuntime.score_player(scout, player1, positions_cfg, stats_cfg, class_rules, rng1)
	var score1b := ScoutRuntime.score_player(scout, player2, positions_cfg, stats_cfg, class_rules, rng1)
	var rng1_final := rng1.state

	# Path 2: With cache (both cold)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var cache := {}
	var score2a := ScoreCache.score_player_cached(player1, scout, positions_cfg, stats_cfg, class_rules, rng2, cache)
	var score2b := ScoreCache.score_player_cached(player2, scout, positions_cfg, stats_cfg, class_rules, rng2, cache)
	var rng2_final := rng2.state

	t.assert_approx(score1a, score2a, 0.001, "ScoreCache: RNG consistency - first score matches")
	t.assert_approx(score1b, score2b, 0.001, "ScoreCache: RNG consistency - second score matches")
	t.assert_equal(rng1_final, rng2_final, "ScoreCache: RNG state matches after cold misses")

	# Path 3: With cache (one repeated, one new)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = seed
	var cache3 := {}
	var score3a := ScoreCache.score_player_cached(player1, scout, positions_cfg, stats_cfg, class_rules, rng3, cache3)
	var score3a_hit := ScoreCache.score_player_cached(player1, scout, positions_cfg, stats_cfg, class_rules, rng3, cache3)  # Cache hit
	var score3b := ScoreCache.score_player_cached(player2, scout, positions_cfg, stats_cfg, class_rules, rng3, cache3)
	var rng3_final := rng3.state

	# After cache hit, RNG state should be as if we evaluated twice
	t.assert_equal(rng1_final, rng3_final, "ScoreCache: RNG state correct after cache hit")


## Test: Hash key uniqueness
func _test_hash_key_uniqueness(t, stats_cfg) -> void:
	var player1 := {
		"player_id": "P7",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}

	var player2 := {
		"player_id": "P8",
		"position": "RB",  # Different position
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}

	var player3 := {
		"player_id": "P7",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 90.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},  # Different speed
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}

	var scout1 := {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var scout2 := {
		"base_skill": 0.8,  # Different skill
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var key1 := ScoreCache._cache_key_dict(player1, scout1, stats_cfg)
	var key2 := ScoreCache._cache_key_dict(player2, scout1, stats_cfg)
	var key3 := ScoreCache._cache_key_dict(player1, scout2, stats_cfg)
	var key4 := ScoreCache._cache_key_dict(player3, scout1, stats_cfg)

	t.assert_not_equal(key1, key2, "ScoreCache: different positions produce different keys")
	t.assert_not_equal(key1, key3, "ScoreCache: different scouts produce different keys")
	t.assert_not_equal(key1, key4, "ScoreCache: different stats produce different keys")


## Test: Hash key stability
func _test_hash_key_stability(t, stats_cfg) -> void:
	var player := {
		"player_id": "P9",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}

	var scout := {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var key1 := ScoreCache._cache_key_dict(player, scout, stats_cfg)
	var key2 := ScoreCache._cache_key_dict(player, scout, stats_cfg)
	var key3 := ScoreCache._cache_key_dict(player, scout, stats_cfg)

	t.assert_equal(key1, key2, "ScoreCache: hash keys are stable (same inputs)")
	t.assert_equal(key1, key3, "ScoreCache: hash keys are stable (repeated)")
	t.assert_true(key1.length() > 0, "ScoreCache: hash key is non-empty")


## Test: Cache invalidation
func _test_cache_invalidation(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := {
		"player_id": "P10",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}

	var scout := {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}

	var seed := 44444
	var cache := {}

	# Populate cache
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	ScoreCache.score_player_cached(player, scout, positions_cfg, stats_cfg, class_rules, rng, cache)

	t.assert_equal(cache.size(), 1, "ScoreCache: cache populated")

	# Clear cache
	ScoreCache.clear_cache(cache)

	t.assert_equal(cache.size(), 0, "ScoreCache: cache cleared")
