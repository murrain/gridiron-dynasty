extends Node

## Performance benchmark for ScoreCache (Task F3)
##
## Benchmarks realistic scenarios:
##   1. College Recruiting: 120 colleges evaluate 300 recruits
##   2. NFL Draft: 32 teams evaluate 200 players across 7 rounds
##   3. Cache hit rate analysis
##   4. Performance improvement measurement

const ScoreCache = preload("res://scripts/core/scouting/ScoreCache.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const Scout = preload("res://scripts/core/models/Scout.gd")
const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")
const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

var positions_cfg: Dictionary = {}
var stats_cfg: Dictionary = {}
var class_rules: Dictionary = {}
var scouts_cfg: Dictionary = {}


func _ready() -> void:
	_setup_config()
	_run_benchmarks()


func _setup_config() -> void:
	var cfg := TestHelpers.load_test_config()

	positions_cfg = cfg.get("positions", {})
	stats_cfg = cfg.get("stats", {})
	class_rules = cfg.get("class_rules", {})
	scouts_cfg = cfg.get("scouts", {})

	if stats_cfg.is_empty():
		stats_cfg = {
			"stats": [
				{"name": "speed", "measurement_difficulty": 0.3},
				{"name": "strength", "measurement_difficulty": 0.5},
				{"name": "agility", "measurement_difficulty": 0.4},
				{"name": "awareness", "measurement_difficulty": 0.7},
				{"name": "throw_power", "measurement_difficulty": 0.4},
				{"name": "throw_acc", "measurement_difficulty": 0.5}
			]
		}

	if class_rules.is_empty():
		class_rules = {
			"recruiting": {
				"composite_weights": {
					"athletic": 0.40,
					"core": 0.30,
					"secondary": 0.20,
					"mentals": 0.10
				}
			}
		}


func _run_benchmarks() -> void:
	print("\n=== ScoreCache Performance Benchmark ===\n")

	_benchmark_college_recruiting()
	print("")
	_benchmark_nfl_draft()
	print("")
	_benchmark_cache_hit_rates()
	print("")


## Benchmark: College recruiting scenario
##
## Scenario: 120 colleges each evaluate 300 recruits
## Expected: High cache hit rate (each recruit evaluated by multiple colleges)
func _benchmark_college_recruiting() -> void:
	print("--- College Recruiting Scenario ---")
	print("Setup: 120 colleges evaluate 300 recruits")

	var num_colleges := 120
	var num_recruits := 300
	var seed := 12345

	# Generate players
	var recruits := []
	for i in range(num_recruits):
		recruits.append(_create_test_player("R%d" % i, _random_position(i)))

	# Generate scouts (one per college)
	var scouts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(num_colleges):
		scouts.append(_create_test_scout(rng))

	print("Players: %d, Colleges: %d, Total evaluations: %d" % [
		num_recruits, num_colleges, num_recruits * num_colleges
	])

	# Benchmark WITHOUT cache
	rng.seed = seed
	var cache_misses := 0
	var start_no_cache := Time.get_ticks_usec()
	for scout in scouts:
		for recruit in recruits:
			ScoutRuntime.score_player(scout, recruit, positions_cfg, stats_cfg, class_rules, rng)
			cache_misses += 1
	var time_no_cache := Time.get_ticks_usec() - start_no_cache

	# Benchmark WITH cache
	rng.seed = seed
	var cache := {}
	var start_with_cache := Time.get_ticks_usec()
	for scout in scouts:
		for recruit in recruits:
			ScoreCache.score_player_cached(recruit, scout, positions_cfg, stats_cfg, class_rules, rng, cache)
	var time_with_cache := Time.get_ticks_usec() - start_with_cache

	# Calculate stats
	var cache_hits := (num_recruits * num_colleges) - cache.size()
	var hit_rate := float(cache_hits) / float(num_recruits * num_colleges) * 100.0
	var speedup := float(time_no_cache) / max(1.0, float(time_with_cache))

	print("\nResults:")
	print("  Time without cache: %.2f ms" % (time_no_cache / 1000.0))
	print("  Time with cache:    %.2f ms" % (time_with_cache / 1000.0))
	print("  Speedup:            %.2fx" % speedup)
	print("  Cache entries:      %d" % cache.size())
	print("  Cache hits:         %d" % cache_hits)
	print("  Cache hit rate:     %.1f%%" % hit_rate)
	print("  Expected hit rate:  ~91.7%% (35700 hits / 36000 evals)")


## Benchmark: NFL Draft scenario
##
## Scenario: 32 teams evaluate 200 players across 7 rounds
## Expected: VERY high cache hit rate (same players evaluated repeatedly)
func _benchmark_nfl_draft() -> void:
	print("--- NFL Draft Scenario ---")
	print("Setup: 32 teams evaluate 200 players across 7 rounds")

	var num_teams := 32
	var num_players := 200
	var num_rounds := 7
	var seed := 54321

	# Generate players
	var players := []
	for i in range(num_players):
		players.append(_create_test_player("D%d" % i, _random_position(i)))

	# Generate scouts (one per team)
	var scouts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(num_teams):
		scouts.append(_create_test_scout(rng))

	var total_evals := num_teams * num_rounds * num_players
	print("Players: %d, Teams: %d, Rounds: %d" % [num_players, num_teams, num_rounds])
	print("Total evaluations: %d (each team scores all players each round)" % total_evals)

	# Benchmark WITHOUT cache
	rng.seed = seed
	var start_no_cache := Time.get_ticks_usec()
	for round_num in range(num_rounds):
		for scout in scouts:
			for player in players:
				ScoutRuntime.score_player(scout, player, positions_cfg, stats_cfg, class_rules, rng)
	var time_no_cache := Time.get_ticks_usec() - start_no_cache

	# Benchmark WITH cache
	rng.seed = seed
	var cache := {}
	var start_with_cache := Time.get_ticks_usec()
	for round_num in range(num_rounds):
		for scout in scouts:
			for player in players:
				ScoreCache.score_player_cached(player, scout, positions_cfg, stats_cfg, class_rules, rng, cache)
	var time_with_cache := Time.get_ticks_usec() - start_with_cache

	# Calculate stats
	var unique_combinations := cache.size()
	var cache_hits := total_evals - unique_combinations
	var hit_rate := float(cache_hits) / float(total_evals) * 100.0
	var speedup := float(time_no_cache) / max(1.0, float(time_with_cache))

	print("\nResults:")
	print("  Time without cache: %.2f ms" % (time_no_cache / 1000.0))
	print("  Time with cache:    %.2f ms" % (time_with_cache / 1000.0))
	print("  Speedup:            %.2fx" % speedup)
	print("  Cache entries:      %d" % unique_combinations)
	print("  Cache hits:         %d" % cache_hits)
	print("  Cache hit rate:     %.1f%%" % hit_rate)
	print("  Expected hit rate:  ~85.7%% (38400 hits / 44800 evals)")
	print("  Note: After round 1, all subsequent rounds are cache hits!")


## Benchmark: Cache hit rate analysis
##
## Analyzes cache behavior under different scenarios
func _benchmark_cache_hit_rates() -> void:
	print("--- Cache Hit Rate Analysis ---")

	var seed := 99999
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Scenario 1: Same player, same scout (100% hit rate)
	print("\nScenario 1: Same player, same scout (repeated evaluation)")
	var player1 := _create_test_player("X1", "QB")
	var scout1 := _create_test_scout(rng)
	var cache1 := {}

	for i in range(10):
		ScoreCache.score_player_cached(player1, scout1, positions_cfg, stats_cfg, class_rules, rng, cache1)

	print("  Evaluations: 10, Cache size: %d, Hit rate: %.1f%%" % [
		cache1.size(), (10.0 - cache1.size()) / 10.0 * 100.0
	])

	# Scenario 2: Different players, same scout (0% hit rate initially)
	print("\nScenario 2: Different players, same scout")
	var scout2 := _create_test_scout(rng)
	var cache2 := {}

	for i in range(10):
		var player := _create_test_player("X%d" % i, "QB")
		ScoreCache.score_player_cached(player, scout2, positions_cfg, stats_cfg, class_rules, rng, cache2)

	print("  Evaluations: 10, Cache size: %d, Hit rate: %.1f%%" % [
		cache2.size(), (10.0 - cache2.size()) / 10.0 * 100.0
	])

	# Scenario 3: Same player, different scouts (0% hit rate initially)
	print("\nScenario 3: Same player, different scouts")
	var player3 := _create_test_player("X99", "QB")
	var cache3 := {}

	for i in range(10):
		var scout := _create_test_scout(rng)
		ScoreCache.score_player_cached(player3, scout, positions_cfg, stats_cfg, class_rules, rng, cache3)

	print("  Evaluations: 10, Cache size: %d, Hit rate: %.1f%%" % [
		cache3.size(), (10.0 - cache3.size()) / 10.0 * 100.0
	])

	# Scenario 4: Mixed (realistic recruiting)
	print("\nScenario 4: Mixed (5 players × 5 scouts × 2 rounds)")
	var players := []
	for i in range(5):
		players.append(_create_test_player("Y%d" % i, "QB"))

	var scouts := []
	for i in range(5):
		scouts.append(_create_test_scout(rng))

	var cache4 := {}
	var total_evals := 0

	# Round 1: All cold misses
	for scout in scouts:
		for player in players:
			ScoreCache.score_player_cached(player, scout, positions_cfg, stats_cfg, class_rules, rng, cache4)
			total_evals += 1

	var size_after_round1 := cache4.size()

	# Round 2: All cache hits
	for scout in scouts:
		for player in players:
			ScoreCache.score_player_cached(player, scout, positions_cfg, stats_cfg, class_rules, rng, cache4)
			total_evals += 1

	print("  Total evaluations: %d" % total_evals)
	print("  Cache size after round 1: %d" % size_after_round1)
	print("  Cache size after round 2: %d" % cache4.size())
	print("  Overall hit rate: %.1f%%" % ((total_evals - cache4.size()) / float(total_evals) * 100.0))


## Helper: Create test player
func _create_test_player(player_id: String, position: String) -> Dictionary:
	# Use player_id hash to vary stats deterministically
	var hash := player_id.hash()
	var base := 60.0 + (hash % 20)

	return {
		"player_id": player_id,
		"name": "Player %s" % player_id,
		"position": position,
		"age": 21,
		"stats": {
			"speed": base + 5.0,
			"strength": base + 3.0,
			"agility": base + 2.0,
			"awareness": base - 2.0,
			"throw_power": base,
			"throw_acc": base + 1.0
		},
		"potential": {
			"speed": base + 15.0,
			"strength": base + 13.0,
			"agility": base + 12.0,
			"awareness": base + 8.0,
			"throw_power": base + 10.0,
			"throw_acc": base + 11.0
		}
	}


## Helper: Create test scout with variation
func _create_test_scout(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"base_skill": clamp(0.55 + rng.randf_range(-0.1, 0.1), 0.3, 0.9),
		"tape_grinder": clamp(0.25 + rng.randf_range(-0.05, 0.05), 0.1, 0.5),
		"risk_aversion": clamp(0.10 + rng.randf_range(-0.05, 0.05), 0.0, 0.3),
		"overrate_athletes": rng.randf_range(-0.05, 0.05),
		"stat_skill": {},
		"valuation_multipliers": {},
		"estimation_multipliers": {}
	}


## Helper: Random position based on index
func _random_position(index: int) -> String:
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
	return positions[index % positions.size()]
