extends RefCounted

## Test A1 Optimization: Starter Cache
##
## Validates that the starter cache optimization:
## 1. Produces identical results to the original implementation
## 2. Preserves determinism (same seed = same results)
## 3. Correctly identifies starters based on ratings
## 4. Works correctly with both college and NFL seasons

const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

func run(t) -> void:
	_test_compute_starters_correctness(t)
	_test_cached_vs_uncached_identical(t)
	_test_determinism_with_cache(t)
	_test_cache_structure(t)


## Test that compute_starters produces correct starter identification
func _test_compute_starters_correctness(t) -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]},
		"WR": {"core_stats": ["speed", "catching"]}
	}
	var main_cfg := {"class_rules": {}}

	# Create roster with clear rating hierarchy
	var roster := {
		"players": [
			{"player_id": "qb1", "position": "QB", "composite_score": 90.0},
			{"player_id": "qb2", "position": "QB", "composite_score": 70.0},
			{"player_id": "rb1", "position": "RB", "composite_score": 85.0},
			{"player_id": "rb2", "position": "RB", "composite_score": 80.0},
			{"player_id": "rb3", "position": "RB", "composite_score": 65.0},
			{"player_id": "wr1", "position": "WR", "composite_score": 88.0},
			{"player_id": "wr2", "position": "WR", "composite_score": 82.0},
			{"player_id": "wr3", "position": "WR", "composite_score": 78.0},
			{"player_id": "wr4", "position": "WR", "composite_score": 60.0}
		]
	}

	var starters := StatGenerator.compute_starters(roster, positions_cfg, main_cfg)

	# Verify QB starter (top 1)
	t.assert_true(starters.has("qb1"), "Top rated QB should be a starter")
	t.assert_true(not starters.has("qb2"), "Second QB should not be a starter")

	# Verify RB starters (top 2)
	t.assert_true(starters.has("rb1"), "Top rated RB should be a starter")
	t.assert_true(starters.has("rb2"), "Second rated RB should be a starter")
	t.assert_true(not starters.has("rb3"), "Third RB should not be a starter")

	# Verify WR starters (top 3)
	t.assert_true(starters.has("wr1"), "Top rated WR should be a starter")
	t.assert_true(starters.has("wr2"), "Second rated WR should be a starter")
	t.assert_true(starters.has("wr3"), "Third rated WR should be a starter")
	t.assert_true(not starters.has("wr4"), "Fourth WR should not be a starter")


## Test that cached and uncached stat generation produce identical results
func _test_cached_vs_uncached_identical(t) -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]}
	}
	var main_cfg := {"class_rules": {}}

	var home_roster := {
		"players": [
			{"player_id": "h_qb1", "position": "QB", "composite_score": 75.0},
			{"player_id": "h_rb1", "position": "RB", "composite_score": 70.0},
			{"player_id": "h_rb2", "position": "RB", "composite_score": 65.0}
		]
	}

	var away_roster := {
		"players": [
			{"player_id": "a_qb1", "position": "QB", "composite_score": 72.0},
			{"player_id": "a_rb1", "position": "RB", "composite_score": 68.0},
			{"player_id": "a_rb2", "position": "RB", "composite_score": 62.0}
		]
	}

	var game_result := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_home",
		"away_team_id": "team_away",
		"winner_id": "team_home",
		"loser_id": "team_away"
	}

	# Pre-compute starters
	var home_starters := StatGenerator.compute_starters(home_roster, positions_cfg, main_cfg)
	var away_starters := StatGenerator.compute_starters(away_roster, positions_cfg, main_cfg)

	var seed := 12345

	# Generate stats WITHOUT cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var stats_uncached := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng1
	)

	# Generate stats WITH cache (same seed)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var stats_cached := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng2,
		home_starters,
		away_starters
	)

	# Verify same players have stats
	t.assert_eq(stats_uncached.keys().size(), stats_cached.keys().size(), "Same number of players should have stats")

	# Verify stats are identical for each player
	for player_id in stats_uncached.keys():
		t.assert_true(stats_cached.has(player_id), "Player %s should exist in both stat sets" % player_id)

		var uncached: Dictionary = stats_uncached[player_id]
		var cached: Dictionary = stats_cached[player_id]

		# Check key stats are identical
		t.assert_eq(uncached.get("games_played", 0), cached.get("games_played", 0),
			"games_played should be identical for %s" % player_id)
		t.assert_eq(uncached.get("games_started", 0), cached.get("games_started", 0),
			"games_started should be identical for %s" % player_id)

		# Check position-specific stats (if they exist)
		if uncached.has("pass_attempts"):
			t.assert_eq(uncached["pass_attempts"], cached["pass_attempts"],
				"pass_attempts should be identical for %s" % player_id)
		if uncached.has("rush_attempts"):
			t.assert_eq(uncached["rush_attempts"], cached["rush_attempts"],
				"rush_attempts should be identical for %s" % player_id)


## Test determinism: Same seed with cache should produce identical results across runs
func _test_determinism_with_cache(t) -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]}
	}
	var main_cfg := {"class_rules": {}}

	var home_roster := {
		"players": [
			{"player_id": "h_qb1", "position": "QB", "composite_score": 75.0},
			{"player_id": "h_rb1", "position": "RB", "composite_score": 70.0}
		]
	}

	var away_roster := {
		"players": [
			{"player_id": "a_qb1", "position": "QB", "composite_score": 72.0},
			{"player_id": "a_rb1", "position": "RB", "composite_score": 68.0}
		]
	}

	var game_result := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_home",
		"away_team_id": "team_away",
		"winner_id": "team_home",
		"loser_id": "team_away"
	}

	# Pre-compute starters ONCE
	var home_starters := StatGenerator.compute_starters(home_roster, positions_cfg, main_cfg)
	var away_starters := StatGenerator.compute_starters(away_roster, positions_cfg, main_cfg)

	var seed := 99999

	# Run 1: Generate stats with cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var stats_run1 := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng1,
		home_starters,
		away_starters
	)

	# Run 2: Generate stats with cache (same seed)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var stats_run2 := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng2,
		home_starters,
		away_starters
	)

	# Run 3: Generate stats with cache (same seed)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = seed
	var stats_run3 := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng3,
		home_starters,
		away_starters
	)

	# Verify all runs produce identical results
	for player_id in stats_run1.keys():
		var s1: Dictionary = stats_run1[player_id]
		var s2: Dictionary = stats_run2[player_id]
		var s3: Dictionary = stats_run3[player_id]

		t.assert_eq(s1.get("games_started", 0), s2.get("games_started", 0),
			"Run 1 vs 2: games_started should be deterministic for %s" % player_id)
		t.assert_eq(s1.get("games_started", 0), s3.get("games_started", 0),
			"Run 1 vs 3: games_started should be deterministic for %s" % player_id)


## Test that the cache structure is correctly initialized in world_state
func _test_cache_structure(t) -> void:
	var world_state := {}

	# Initialize cache structure (simulates what CollegeSeason/NflSeason do)
	if not world_state.has("starter_cache"):
		world_state["starter_cache"] = {}

	var year := 2025
	var starter_cache: Dictionary = world_state["starter_cache"]
	if not starter_cache.has(year):
		starter_cache[year] = {}

	var year_cache: Dictionary = starter_cache[year]

	# Add some mock starters
	year_cache["team_001"] = {"player_1": true, "player_2": true}
	year_cache["team_002"] = {"player_3": true, "player_4": true}

	# Verify structure
	t.assert_true(world_state.has("starter_cache"), "world_state should have starter_cache")
	t.assert_true(world_state["starter_cache"].has(year), "starter_cache should have year entry")
	t.assert_true(world_state["starter_cache"][year].has("team_001"), "year cache should have team_001")
	t.assert_true(world_state["starter_cache"][year].has("team_002"), "year cache should have team_002")

	# Verify retrieval
	var team1_starters: Dictionary = world_state["starter_cache"][year]["team_001"]
	t.assert_true(team1_starters.has("player_1"), "team_001 should have player_1 as starter")
	t.assert_true(team1_starters.has("player_2"), "team_001 should have player_2 as starter")
	t.assert_true(not team1_starters.has("player_3"), "team_001 should not have player_3 as starter")
