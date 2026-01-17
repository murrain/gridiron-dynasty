## Tests for DraftDecisionEngine
##
## Tests the underclassman draft declaration processing:
##   - process_declarations() - main entry point
##   - calculate_declaration_probability() - probability calculation
##   - estimate_draft_pool_size() - estimation utility
##   - Determinism verification (same seed -> same result)
##
## Test count: 7 tests as specified in DRAFT-002

extends RefCounted

const DraftDecisionEngine = preload("res://scripts/world/DraftDecisionEngine.gd")
const Player = preload("res://scripts/core/models/Player.gd")


func run(t) -> void:
	test_seniors_auto_declare(t)
	test_underclassmen_probability_based(t)
	test_elite_underclassman_high_declare_rate(t)
	test_low_rated_underclassman_low_declare_rate(t)
	test_years_remaining_modifier(t)
	test_process_declarations_determinism(t)
	test_estimate_draft_pool_size(t)


## Helper to create a test player dictionary
func _make_player(
	player_id: String,
	position: String,
	years_remaining: int,
	stats: Dictionary = {}
) -> Dictionary:
	return {
		"player_id": player_id,
		"position": position,
		"stage": Player.PlayerStage.COLLEGE,
		"years_remaining": years_remaining,
		"declared_for_draft": false,
		"stats": stats
	}


## Test 1: Seniors (years_remaining = 0) always declare
func test_seniors_auto_declare(t) -> void:
	var senior := _make_player("senior-1", "QB", 0)
	var pool := [senior]

	var result := DraftDecisionEngine.process_declarations(
		pool,
		2025,
		12345,  # seed
		{},     # config
		{},     # positions_cfg
		{}      # class_rules
	)

	t.assert_eq(result.get("declared_count"), 1,
		"Senior should auto-declare")
	t.assert_eq(result.get("returning_count"), 0,
		"Senior should not return to school")
	t.assert_eq(bool(senior.get("declared_for_draft")), true,
		"Senior should have declared_for_draft = true")


## Test 2: Underclassmen declaration is probability-based
func test_underclassmen_probability_based(t) -> void:
	# Create multiple juniors with same rating
	var pool := []
	for i in range(100):
		var player := _make_player("junior-%d" % i, "WR", 1, {"speed": 70.0, "strength": 70.0})
		pool.append(player)

	var result := DraftDecisionEngine.process_declarations(
		pool,
		2025,
		12345,
		{},
		{},
		{}
	)

	# With mid-tier rating (~70), expect ~35% declaration rate
	# Allow some variance: 20-50 declarations out of 100
	var declared := int(result.get("declared_count"))
	var returning := int(result.get("returning_count"))

	t.assert_eq(declared + returning, 100,
		"Total should equal pool size")
	t.assert_true(declared > 15 and declared < 55,
		"Declaration count should be in expected range (got %d)" % declared)


## Test 3: Elite underclassmen have high declaration rate
func test_elite_underclassman_high_declare_rate(t) -> void:
	# Create 50 elite juniors (rating ~90)
	var pool := []
	for i in range(50):
		var elite_stats := {"speed": 90.0, "strength": 88.0, "agility": 92.0}
		var player := _make_player("elite-%d" % i, "QB", 1, elite_stats)
		pool.append(player)

	var result := DraftDecisionEngine.process_declarations(
		pool,
		2025,
		12345,
		{},
		{},
		{}
	)

	var declared := int(result.get("declared_count"))

	# Elite (85+) should declare at ~90% rate
	# Expect 40-50 out of 50 to declare
	t.assert_true(declared >= 38,
		"Elite underclassmen should mostly declare (got %d/50)" % declared)


## Test 4: Low-rated underclassmen have low declaration rate
func test_low_rated_underclassman_low_declare_rate(t) -> void:
	# Create 50 low-rated juniors (rating ~55)
	var pool := []
	for i in range(50):
		var low_stats := {"speed": 55.0, "strength": 52.0, "agility": 58.0}
		var player := _make_player("low-%d" % i, "RB", 1, low_stats)
		pool.append(player)

	var result := DraftDecisionEngine.process_declarations(
		pool,
		2025,
		67890,
		{},
		{},
		{}
	)

	var declared := int(result.get("declared_count"))

	# Low (<65) should declare at ~15% rate
	# Expect 3-15 out of 50 to declare
	t.assert_true(declared <= 15,
		"Low-rated underclassmen should rarely declare (got %d/50)" % declared)


## Test 5: Years remaining affects declaration probability
func test_years_remaining_modifier(t) -> void:
	# Calculate probabilities for same player at different years
	var player_1yr := _make_player("p1", "WR", 1, {"speed": 78.0, "strength": 75.0})
	var player_2yr := _make_player("p2", "WR", 2, {"speed": 78.0, "strength": 75.0})
	var player_3yr := _make_player("p3", "WR", 3, {"speed": 78.0, "strength": 75.0})

	var prob_1yr := DraftDecisionEngine.calculate_declaration_probability(
		player_1yr, {}, {}, {}
	)
	var prob_2yr := DraftDecisionEngine.calculate_declaration_probability(
		player_2yr, {}, {}, {}
	)
	var prob_3yr := DraftDecisionEngine.calculate_declaration_probability(
		player_3yr, {}, {}, {}
	)

	# Junior (1 year) should have highest probability
	# Sophomore (2 years) should have ~70% of junior's probability
	# Freshman (3 years) should have ~40% of junior's probability
	t.assert_true(prob_1yr > prob_2yr,
		"Junior should have higher probability than sophomore")
	t.assert_true(prob_2yr > prob_3yr,
		"Sophomore should have higher probability than freshman")

	# Check the multipliers are applied correctly
	var expected_2yr := prob_1yr * 0.7
	var expected_3yr := prob_1yr * 0.4
	t.assert_true(abs(prob_2yr - expected_2yr) < 0.01,
		"Sophomore probability should be ~70%% of junior")
	t.assert_true(abs(prob_3yr - expected_3yr) < 0.01,
		"Freshman probability should be ~40%% of junior")


## Test 6: Same seed produces identical results (determinism)
func test_process_declarations_determinism(t) -> void:
	# Create a pool of varied players
	var pool_template := []
	for i in range(20):
		var rating := 60.0 + float(i) * 2.0
		var stats := {"speed": rating, "strength": rating - 5.0}
		var years := 1 + (i % 3)
		pool_template.append(_make_player("player-%d" % i, "LB", years, stats))

	# Run with same seed 3 times
	var results := []
	for run_num in range(3):
		# Create fresh copy of pool (since process_declarations modifies in place)
		var pool := []
		for p in pool_template:
			pool.append(p.duplicate(true))

		var result := DraftDecisionEngine.process_declarations(
			pool,
			2025,
			99999,  # Same seed for all runs
			{},
			{},
			{}
		)
		results.append(result)

	# All runs should produce identical counts
	t.assert_eq(results[0].get("declared_count"), results[1].get("declared_count"),
		"Run 1 and 2 should have same declared count")
	t.assert_eq(results[1].get("declared_count"), results[2].get("declared_count"),
		"Run 2 and 3 should have same declared count")

	# Different seed should produce different result (with high probability)
	var pool_different_seed := []
	for p in pool_template:
		pool_different_seed.append(p.duplicate(true))

	var result_different := DraftDecisionEngine.process_declarations(
		pool_different_seed,
		2025,
		11111,  # Different seed
		{},
		{},
		{}
	)

	# Note: Extremely unlikely to match (1/20! chance of identical player ordering)
	# We don't assert this since theoretically they could match
	# Just document the behavior


## Test 7: Draft pool size estimation
func test_estimate_draft_pool_size(t) -> void:
	# Estimate pool size with known inputs
	var estimate := DraftDecisionEngine.estimate_draft_pool_size(
		100,  # seniors (all declare)
		80,   # juniors (~55% weighted avg * 1.0 = ~44)
		50,   # sophomores (~55% * 0.7 = ~19)
		{}    # default config
	)

	var expected_min := int(estimate.get("expected_min"))
	var expected_max := int(estimate.get("expected_max"))
	var expected_avg := float(estimate.get("expected_avg"))

	# Seniors always: 100
	# Juniors: ~44 (55% * 80)
	# Sophomores: ~19 (55% * 0.7 * 50)
	# Total expected: ~163

	t.assert_true(expected_avg > 120 and expected_avg < 200,
		"Expected average should be reasonable range (got %.1f)" % expected_avg)
	t.assert_true(expected_min < expected_avg,
		"Expected min should be less than average")
	t.assert_true(expected_max > expected_avg,
		"Expected max should be greater than average")
	t.assert_true(expected_max > expected_min,
		"Expected max should be greater than min")
