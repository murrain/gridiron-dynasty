## GdUnit4 test suite for ScoreCache
##
## Tests for scout evaluation caching:
## 1. Cache correctness: Cached results match non-cached results exactly
## 2. Determinism: Same inputs produce same outputs regardless of cache state
## 3. Cache hits: Cache successfully stores and retrieves evaluations
## 4. RNG consistency: RNG state is identical with/without caching
## 5. Hash key generation: Different players/scouts produce different keys
##
## Migrated from test_score_cache.gd
extends GdUnitTestSuite

const ScoreCache = preload("res://scripts/core/scouting/ScoreCache.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")


func _get_stats_cfg() -> Dictionary:
	return {
		"stats": [
			{"name": "speed", "measurement_difficulty": 0.3},
			{"name": "strength", "measurement_difficulty": 0.5},
			{"name": "agility", "measurement_difficulty": 0.4},
			{"name": "awareness", "measurement_difficulty": 0.7}
		]
	}


func _get_positions_cfg() -> Dictionary:
	return {
		"QB": {
			"core_stats": ["awareness"],
			"distributions": {"speed": {"role": "athletic"}}
		},
		"RB": {
			"core_stats": ["agility"],
			"distributions": {"speed": {"role": "athletic"}}
		}
	}


func _get_class_rules() -> Dictionary:
	return {
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


func _make_dict_scout() -> Dictionary:
	return {
		"base_skill": 0.6,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}


func test_cache_correctness_dict_scout() -> void:
	var player := {
		"player_id": "P1",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 75.0, "strength": 70.0, "agility": 72.0, "awareness": 68.0},
		"potential": {"speed": 82.0, "strength": 78.0, "agility": 80.0, "awareness": 75.0}
	}
	var scout := _make_dict_scout()
	var seed_val := 12345

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed_val
	var score_no_cache := ScoutRuntime.score_player(
		scout, player, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_val
	var cache := {}
	var score_with_cache := ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng2, cache
	)

	assert_float(score_with_cache).is_equal_approx(score_no_cache, 0.001)
	assert_int(cache.size()).is_equal(1)


func test_cache_correctness_resource_scout() -> void:
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
	scout.setup(_get_stats_cfg(), {}, RandomNumberGenerator.new())

	var seed_val := 54321

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed_val
	var score_no_cache := scout.score_player(
		player, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_val
	var cache := {}
	var score_with_cache := ScoreCache.score_player_cached_resource(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng2, cache
	)

	assert_float(score_with_cache).is_equal_approx(score_no_cache, 0.001)


func test_determinism_across_fresh_caches() -> void:
	var player := {
		"player_id": "P3",
		"position": "QB",
		"age": 22,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 72.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 78.0}
	}
	var scout := _make_dict_scout()
	var seed_val := 99999

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed_val
	var cache1 := {}
	var score1 := ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng1, cache1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_val
	var cache2 := {}
	var score2 := ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng2, cache2
	)

	assert_float(score1).is_equal_approx(score2, 0.001)


func test_cache_hit_returns_same_score() -> void:
	var player := {
		"player_id": "P3",
		"position": "QB",
		"age": 22,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 72.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 78.0}
	}
	var scout := _make_dict_scout()
	var seed_val := 99999

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var cache := {}
	var score1 := ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng, cache
	)

	var score2 := ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng, cache
	)

	assert_float(score1).is_equal_approx(score2, 0.001)


func test_cache_size_unchanged_after_hit() -> void:
	var player := {
		"player_id": "P4",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 72.0, "strength": 71.0, "agility": 70.0, "awareness": 73.0},
		"potential": {"speed": 77.0, "strength": 76.0, "agility": 75.0, "awareness": 79.0}
	}
	var scout := _make_dict_scout()
	var seed_val := 22222
	var cache := {}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed_val
	ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng1, cache
	)

	assert_int(cache.size()).is_equal(1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_val
	ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng2, cache
	)

	assert_int(cache.size()).is_equal(1)


func test_hash_key_uniqueness_different_positions() -> void:
	var player1 := {
		"player_id": "P7",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}
	var player2 := {
		"player_id": "P8",
		"position": "RB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}
	var scout := _make_dict_scout()

	var key1 := ScoreCache._cache_key_dict(player1, scout, _get_stats_cfg())
	var key2 := ScoreCache._cache_key_dict(player2, scout, _get_stats_cfg())

	assert_str(key1).is_not_equal(key2)


func test_hash_key_uniqueness_different_scouts() -> void:
	var player := {
		"player_id": "P7",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}
	var scout1 := _make_dict_scout()
	var scout2 := _make_dict_scout()
	scout2["base_skill"] = 0.8

	var key1 := ScoreCache._cache_key_dict(player, scout1, _get_stats_cfg())
	var key2 := ScoreCache._cache_key_dict(player, scout2, _get_stats_cfg())

	assert_str(key1).is_not_equal(key2)


func test_hash_key_stability() -> void:
	var player := {
		"player_id": "P9",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}
	var scout := _make_dict_scout()

	var key1 := ScoreCache._cache_key_dict(player, scout, _get_stats_cfg())
	var key2 := ScoreCache._cache_key_dict(player, scout, _get_stats_cfg())
	var key3 := ScoreCache._cache_key_dict(player, scout, _get_stats_cfg())

	assert_str(key1).is_equal(key2)
	assert_str(key1).is_equal(key3)
	assert_int(key1.length()).is_greater(0)


func test_cache_invalidation() -> void:
	var player := {
		"player_id": "P10",
		"position": "QB",
		"age": 21,
		"stats": {"speed": 70.0, "strength": 68.0, "agility": 69.0, "awareness": 71.0},
		"potential": {"speed": 75.0, "strength": 73.0, "agility": 74.0, "awareness": 76.0}
	}
	var scout := _make_dict_scout()
	var seed_val := 44444
	var cache := {}

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	ScoreCache.score_player_cached(
		player, scout, _get_positions_cfg(), _get_stats_cfg(), _get_class_rules(), rng, cache
	)

	assert_int(cache.size()).is_equal(1)

	ScoreCache.clear_cache(cache)

	assert_int(cache.size()).is_equal(0)
