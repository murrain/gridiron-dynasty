extends RefCounted

## Test suite for Task P2: RecruitingScoreCache (Deterministic)
##
## Tests verify:
##   1. Determinism: Same inputs produce byte-identical outputs regardless of cache state
##   2. Year isolation: Different years have independent cache entries
##   3. Phase isolation: Different phases (recruiting, draft) are separated
##   4. Scout isolation: Different scouts get independent evaluations
##   5. RNG consistency: RNG state is preserved correctly with cache hits/misses
##   6. Cache effectiveness: Cache hits reduce computation while maintaining correctness
##   7. Integration: Cache works correctly with CollegeRecruiting and NflDraft

const RecruitingScoreCache = preload("res://scripts/core/scouting/RecruitingScoreCache.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")
const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const ConfigService = preload("res://autoloads/Config.gd")


func run(t) -> void:
	var config := ConfigService.new()
	var stats_cfg := config.get_config("stats")
	var positions_cfg := config.get_config("positions")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	# Core cache tests
	_test_basic_cache_functionality(t, stats_cfg, positions_cfg, class_rules)
	_test_cache_determinism(t, stats_cfg, positions_cfg, class_rules)
	_test_year_isolation(t, stats_cfg, positions_cfg, class_rules)
	_test_phase_isolation(t, stats_cfg, positions_cfg, class_rules)
	_test_scout_isolation(t, stats_cfg, positions_cfg, class_rules)
	_test_player_isolation(t, stats_cfg, positions_cfg, class_rules)
	_test_rng_consistency(t, stats_cfg, positions_cfg, class_rules)
	_test_cache_key_stability(t, stats_cfg, positions_cfg, class_rules)

	# Integration tests
	_test_recruiting_integration(t, config, stats_cfg, positions_cfg, scouts_cfg, class_rules)
	_test_recruiting_determinism_with_cache(t, config, stats_cfg, positions_cfg, scouts_cfg, class_rules)

	# Performance tests
	_test_cache_hit_rate(t, stats_cfg, positions_cfg, class_rules)


## Test 1: Basic cache functionality
func _test_basic_cache_functionality(t, stats_cfg, positions_cfg, class_rules) -> void:
	var cache := RecruitingScoreCache.new(2025)
	var player := _create_test_player("P1", "QB", 75.0, 80.0)
	var scout := _create_test_scout_dict(0.6, 0.3)

	# First call (cache miss)
	var score1 := cache.get_or_compute(
		player, scout, "scout_001", "recruiting",
		positions_cfg, stats_cfg, class_rules, 12345
	)

	var stats1: Dictionary = cache.get_stats()
	t.assert_eq(stats1["misses"], 1, "First call is cache miss")
	t.assert_eq(stats1["hits"], 0, "No cache hits yet")
	t.assert_eq(stats1["size"], 1, "Cache has 1 entry")

	# Second call (cache hit)
	var score2 := cache.get_or_compute(
		player, scout, "scout_001", "recruiting",
		positions_cfg, stats_cfg, class_rules, 12345
	)

	var stats2: Dictionary = cache.get_stats()
	t.assert_eq(stats2["misses"], 1, "Still only 1 miss")
	t.assert_eq(stats2["hits"], 1, "Now 1 cache hit")
	t.assert_eq(stats2["size"], 1, "Cache still has 1 entry")

	t.assert_approx(score1, score2, 0.001, "Cache hit returns same score")


## Test 2: Cache determinism - same inputs produce identical outputs
func _test_cache_determinism(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := _create_test_player("P2", "RB", 80.0, 85.0)
	var scout := _create_test_scout_dict(0.55, 0.25)
	var seed := 99999

	# Run 1: Fresh cache
	var cache1 := RecruitingScoreCache.new(2025)
	var score1 := cache1.get_or_compute(
		player, scout, "scout_002", "recruiting",
		positions_cfg, stats_cfg, class_rules, seed
	)

	# Run 2: Fresh cache (should be identical)
	var cache2 := RecruitingScoreCache.new(2025)
	var score2 := cache2.get_or_compute(
		player, scout, "scout_002", "recruiting",
		positions_cfg, stats_cfg, class_rules, seed
	)

	# Run 3: Reuse cache (cache hit)
	var score3 := cache2.get_or_compute(
		player, scout, "scout_002", "recruiting",
		positions_cfg, stats_cfg, class_rules, seed
	)

	t.assert_approx(score1, score2, 0.001, "Fresh cache produces identical score")
	t.assert_approx(score1, score3, 0.001, "Cache hit produces identical score")


## Test 3: Year isolation - different years have separate caches
func _test_year_isolation(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := _create_test_player("P3", "WR", 70.0, 75.0)
	var scout := _create_test_scout_dict(0.6, 0.3)

	var cache_2025 := RecruitingScoreCache.new(2025)
	var cache_2026 := RecruitingScoreCache.new(2026)

	var score_2025 := cache_2025.get_or_compute(
		player, scout, "scout_003", "recruiting",
		positions_cfg, stats_cfg, class_rules, 11111
	)

	var score_2026 := cache_2026.get_or_compute(
		player, scout, "scout_003", "recruiting",
		positions_cfg, stats_cfg, class_rules, 11111
	)

	var stats_2025 := cache_2025.get_stats()
	var stats_2026 := cache_2026.get_stats()

	t.assert_eq(stats_2025["year"], 2025, "Cache 2025 has correct year")
	t.assert_eq(stats_2026["year"], 2026, "Cache 2026 has correct year")
	t.assert_eq(stats_2025["size"], 1, "Cache 2025 has 1 entry")
	t.assert_eq(stats_2026["size"], 1, "Cache 2026 has 1 entry")

	# Scores should be identical (same inputs)
	t.assert_approx(score_2025, score_2026, 0.001, "Same inputs produce same score across years")


## Test 4: Phase isolation - different phases are separated
func _test_phase_isolation(t, stats_cfg, positions_cfg, class_rules) -> void:
	var cache := RecruitingScoreCache.new(2025)
	var player := _create_test_player("P4", "QB", 72.0, 78.0)
	var scout := _create_test_scout_dict(0.6, 0.3)

	var score_recruiting := cache.get_or_compute(
		player, scout, "scout_004", "recruiting",
		positions_cfg, stats_cfg, class_rules, 22222
	)

	var score_draft := cache.get_or_compute(
		player, scout, "scout_004", "draft_round_1",
		positions_cfg, stats_cfg, class_rules, 22222
	)

	var stats := cache.get_stats()
	t.assert_eq(stats["size"], 2, "Different phases create separate cache entries")

	# Scores should be identical (same player/scout, just different phase keys)
	t.assert_approx(score_recruiting, score_draft, 0.001, "Same evaluation produces same score")


## Test 5: Scout isolation - different scouts get independent evaluations
func _test_scout_isolation(t, stats_cfg, positions_cfg, class_rules) -> void:
	var cache := RecruitingScoreCache.new(2025)
	var player := _create_test_player("P5", "RB", 75.0, 80.0)

	var scout_a := _create_test_scout_dict(0.6, 0.3)  # Good scout
	var scout_b := _create_test_scout_dict(0.4, 0.5)  # Different skills

	var score_a := cache.get_or_compute(
		player, scout_a, "scout_005a", "recruiting",
		positions_cfg, stats_cfg, class_rules, 33333
	)

	var score_b := cache.get_or_compute(
		player, scout_b, "scout_005b", "recruiting",
		positions_cfg, stats_cfg, class_rules, 33333
	)

	var stats: Dictionary = cache.get_stats()
	t.assert_eq(stats["size"], 2, "Different scouts create separate cache entries")

	# Scores should differ (different scout skills)
	# Note: Difference may be small due to RNG variance, so we just check they're different
	var score_diff: float = abs(score_a - score_b)
	t.assert_true(score_diff > 0.01, "Different scouts produce different scores (diff: %.2f)" % score_diff)


## Test 6: Player isolation - different players get independent evaluations
func _test_player_isolation(t, stats_cfg, positions_cfg, class_rules) -> void:
	var cache := RecruitingScoreCache.new(2025)
	var scout := _create_test_scout_dict(0.6, 0.3)

	var player_a := _create_test_player("P6a", "QB", 75.0, 80.0)
	var player_b := _create_test_player("P6b", "QB", 85.0, 90.0)  # Better player

	var score_a := cache.get_or_compute(
		player_a, scout, "scout_006", "recruiting",
		positions_cfg, stats_cfg, class_rules, 44444
	)

	var score_b := cache.get_or_compute(
		player_b, scout, "scout_006", "recruiting",
		positions_cfg, stats_cfg, class_rules, 44444
	)

	var stats := cache.get_stats()
	t.assert_eq(stats["size"], 2, "Different players create separate cache entries")

	# Better player should have higher score
	t.assert_true(score_b > score_a, "Better player has higher score (%.2f > %.2f)" % [score_b, score_a])


## Test 7: RNG consistency - cache hits consume correct RNG
func _test_rng_consistency(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player1 := _create_test_player("P7a", "QB", 70.0, 75.0)
	var player2 := _create_test_player("P7b", "RB", 80.0, 85.0)
	var scout := _create_test_scout_dict(0.6, 0.3)
	var seed := 55555

	# Path 1: No cache (evaluate twice)
	var cache1 := RecruitingScoreCache.new(2025)
	var s1_p1_a: float = cache1.get_or_compute(player1, scout, "scout_007", "recruiting", positions_cfg, stats_cfg, class_rules, seed)
	var s1_p1_b: float = cache1.get_or_compute(player1, scout, "scout_007", "recruiting", positions_cfg, stats_cfg, class_rules, seed)  # Cache hit
	var s1_p2: float = cache1.get_or_compute(player2, scout, "scout_007", "recruiting", positions_cfg, stats_cfg, class_rules, seed)

	# Path 2: Fresh cache (evaluate same sequence)
	var cache2 := RecruitingScoreCache.new(2025)
	var s2_p1_a: float = cache2.get_or_compute(player1, scout, "scout_007", "recruiting", positions_cfg, stats_cfg, class_rules, seed)
	var s2_p1_b: float = cache2.get_or_compute(player1, scout, "scout_007", "recruiting", positions_cfg, stats_cfg, class_rules, seed)  # Cache hit
	var s2_p2: float = cache2.get_or_compute(player2, scout, "scout_007", "recruiting", positions_cfg, stats_cfg, class_rules, seed)

	# All scores should match
	t.assert_approx(s1_p1_a, s2_p1_a, 0.001, "RNG: player1 first eval matches")
	t.assert_approx(s1_p1_b, s2_p1_b, 0.001, "RNG: player1 cache hit matches")
	t.assert_approx(s1_p2, s2_p2, 0.001, "RNG: player2 eval matches")

	# Cache hit should return same as first eval
	t.assert_approx(s1_p1_a, s1_p1_b, 0.001, "RNG: cache hit returns same score")


## Test 8: Cache key stability - same inputs produce same keys
func _test_cache_key_stability(t, stats_cfg, positions_cfg, class_rules) -> void:
	var player := _create_test_player("P8", "WR", 77.0, 82.0)
	var scout := _create_test_scout_dict(0.6, 0.3)

	# Generate key multiple times
	var key1 := RecruitingScoreCache._make_cache_key(
		2025, "scout_008", "P8", "recruiting", player, scout, stats_cfg
	)
	var key2 := RecruitingScoreCache._make_cache_key(
		2025, "scout_008", "P8", "recruiting", player, scout, stats_cfg
	)
	var key3 := RecruitingScoreCache._make_cache_key(
		2025, "scout_008", "P8", "recruiting", player, scout, stats_cfg
	)

	t.assert_eq(key1, key2, "Cache key is stable (run 1 vs 2)")
	t.assert_eq(key1, key3, "Cache key is stable (run 1 vs 3)")
	t.assert_true(key1.length() > 0, "Cache key is non-empty")

	# Different inputs should produce different keys
	var key_different_year := RecruitingScoreCache._make_cache_key(
		2026, "scout_008", "P8", "recruiting", player, scout, stats_cfg
	)
	var key_different_scout := RecruitingScoreCache._make_cache_key(
		2025, "scout_009", "P8", "recruiting", player, scout, stats_cfg
	)
	var key_different_phase := RecruitingScoreCache._make_cache_key(
		2025, "scout_008", "P8", "draft_round_1", player, scout, stats_cfg
	)

	t.assert_ne(key1, key_different_year, "Different year produces different key")
	t.assert_ne(key1, key_different_scout, "Different scout_id produces different key")
	t.assert_ne(key1, key_different_phase, "Different phase produces different key")


## Test 9: Integration with CollegeRecruiting
func _test_recruiting_integration(t, config, stats_cfg, positions_cfg, scouts_cfg, class_rules) -> void:
	var recruits := _create_test_recruits(30)
	var colleges := _create_test_colleges(5)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	# Run recruiting (should use cache internally)
	var result := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false  # Sequential for predictable testing
	)

	var commitments: Array = result.get("commitments", []) as Array
	t.assert_true(commitments.size() > 0, "Recruiting produces commitments")
	t.assert_eq(result.get("year", 0), 2025, "Result has correct year")


## Test 10: Recruiting determinism with cache
func _test_recruiting_determinism_with_cache(t, config, stats_cfg, positions_cfg, scouts_cfg, class_rules) -> void:
	var recruits := _create_test_recruits(20)
	var colleges := _create_test_colleges(4)
	var pipeline_cfg := _create_test_config()
	var seed := 99999

	var pipeline := CollegeRecruiting.new()

	# Run 1
	var result1 := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		seed, 2025, false
	)

	# Run 2 (should be byte-identical)
	var result2 := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		seed, 2025, false
	)

	# Run 3 (should be byte-identical)
	var result3 := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		seed, 2025, false
	)

	var commits1 := JSON.stringify(result1.get("commitments", []))
	var commits2 := JSON.stringify(result2.get("commitments", []))
	var commits3 := JSON.stringify(result3.get("commitments", []))

	t.assert_eq(commits1, commits2, "Recruiting is deterministic (run 1 vs 2)")
	t.assert_eq(commits1, commits3, "Recruiting is deterministic (run 1 vs 3)")


## Test 11: Cache hit rate effectiveness
func _test_cache_hit_rate(t, stats_cfg, positions_cfg, class_rules) -> void:
	var cache := RecruitingScoreCache.new(2025)
	var player := _create_test_player("P11", "QB", 75.0, 80.0)
	var scout := _create_test_scout_dict(0.6, 0.3)

	# Simulate multiple colleges evaluating same player
	var num_colleges := 10
	for i in range(num_colleges):
		var college_id := "college_%03d" % i
		cache.get_or_compute(
			player, scout, college_id, "recruiting",
			positions_cfg, stats_cfg, class_rules, 66666
		)

	var stats := cache.get_stats()

	# Each college has different scout_id, so no cache hits expected
	# (This is correct behavior - each college gets independent evaluation)
	t.assert_eq(stats["misses"], num_colleges, "Each college creates separate cache entry")
	t.assert_eq(stats["size"], num_colleges, "Cache has entry per college")

	# Now test with same college evaluating multiple players
	var cache2 := RecruitingScoreCache.new(2025)
	var num_players := 10
	for i in range(num_players):
		var p := _create_test_player("P11_%d" % i, "QB", 75.0, 80.0)
		# First evaluation
		cache2.get_or_compute(p, scout, "college_001", "recruiting", positions_cfg, stats_cfg, class_rules, 66666)
		# Second evaluation (cache hit)
		cache2.get_or_compute(p, scout, "college_001", "recruiting", positions_cfg, stats_cfg, class_rules, 66666)

	var stats2 := cache2.get_stats()
	t.assert_eq(stats2["misses"], num_players, "First eval per player is cache miss")
	t.assert_eq(stats2["hits"], num_players, "Second eval per player is cache hit")
	t.assert_approx(stats2["hit_rate"], 0.5, 0.01, "Hit rate is 50%% (10 hits / 20 total)")


## Helper: Create test player
func _create_test_player(id: String, pos: String, current_rating: float, potential_rating: float) -> Dictionary:
	return {
		"player_id": id,
		"position": pos,
		"age": 21,
		"stats": {
			"speed": current_rating,
			"strength": current_rating - 2.0,
			"agility": current_rating + 1.0,
			"awareness": current_rating - 3.0,
			"acceleration": current_rating + 2.0
		},
		"potential": {
			"speed": potential_rating,
			"strength": potential_rating - 2.0,
			"agility": potential_rating + 1.0,
			"awareness": potential_rating - 3.0,
			"acceleration": potential_rating + 2.0
		}
	}


## Helper: Create test scout dictionary
func _create_test_scout_dict(base_skill: float, tape_grinder: float) -> Dictionary:
	return {
		"base_skill": base_skill,
		"tape_grinder": tape_grinder,
		"risk_aversion": 0.1,
		"overrate_athletes": 0.0,
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}


## Helper: Create test recruits
func _create_test_recruits(count: int) -> Array:
	var recruits: Array = []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]
	var regions := ["north", "south", "east", "west", "midwest"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 999999

	for i in range(count):
		var player_id := "recruit_%03d" % i
		var position: String = positions[rng.randi() % positions.size()]
		var baseline := rng.randf_range(50.0, 90.0)

		recruits.append({
			"player_id": player_id,
			"name": "Recruit %d" % i,
			"position": position,
			"home_region": regions[rng.randi() % regions.size()],
			"proximity_bias": rng.randf_range(0.3, 0.9),
			"stats": {
				"speed": rng.randf_range(50.0, 90.0),
				"acceleration": rng.randf_range(50.0, 90.0),
				"agility": rng.randf_range(50.0, 90.0),
				"strength": rng.randf_range(50.0, 90.0),
				"awareness": rng.randf_range(50.0, 90.0)
			},
			"potential": {
				"speed": rng.randf_range(60.0, 95.0),
				"acceleration": rng.randf_range(60.0, 95.0),
				"agility": rng.randf_range(60.0, 95.0),
				"strength": rng.randf_range(60.0, 95.0),
				"awareness": rng.randf_range(60.0, 95.0)
			},
			"ratings": {
				"composite_score": baseline
			}
		})

	return recruits


## Helper: Create test colleges
func _create_test_colleges(count: int) -> Array:
	var colleges: Array = []
	var regions := ["north", "south", "east", "west", "midwest"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 888888

	for i in range(count):
		colleges.append({
			"id": "college_%02d" % i,
			"name": "University %d" % i,
			"region": regions[i % regions.size()],
			"eliteness": rng.randf_range(40.0, 95.0)
		})

	return colleges


## Helper: Create test configuration
func _create_test_config() -> Dictionary:
	return {
		"recruiting": {
			"offer_limit": 25,
			"board_limit": 100,
			"class_size_min": 15,
			"class_size_max": 25,
			"rating_weight": 0.55,
			"eliteness_weight": 0.25,
			"proximity_weight": 0.20,
			"region_match_multiplier": 1.35,
			"scout_weight": 0.70,
			"baseline_weight": 0.30,
			"visit_chance": 0.20,
			"visit_bonus": 0.06
		}
	}
