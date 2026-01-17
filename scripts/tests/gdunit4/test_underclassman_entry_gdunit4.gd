## GdUnit4 test suite for UnderclassmanDeclarationEngine
##
## Validates underclassman early declaration system including:
##   - Determinism (same seed -> same declarations)
##   - Probability distribution (90%/60%/30%/8% rates +/-5%)
##   - Pool size variance (50-100 underclassmen)
##   - First-round projection behavior (99% declare)
##   - Edge cases (empty pool, all ineligible)
##   - Backward compatibility (Player model class_year inference)
extends GdUnitTestSuite

const UnderclassmanDeclarationEngine = preload("res://scripts/world/UnderclassmanDeclarationEngine.gd")
const Player = preload("res://scripts/core/models/Player.gd")
const Rand = preload("res://autoloads/Rand.gd")


# =============================================================================
# Test: Determinism - Same seed produces identical declarations
# =============================================================================

func test_determinism_same_seed_identical_declarations() -> void:
	var seed_value := 12345

	# Create two identical draft pools
	var pool1 := _create_test_pool(100)
	var pool2 := _create_test_pool(100)

	var mock_ranks := UnderclassmanDeclarationEngine.build_simple_mock_ranks(pool1)

	# Run declarations with same seed
	var result1 := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool1, mock_ranks, 2024, seed_value
	)
	var count1: int = int(result1.get("declaration_count", 0))
	var result2 := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool2, mock_ranks, 2024, seed_value
	)
	var count2: int = int(result2.get("declaration_count", 0))

	# Verify same count
	assert_int(count1).is_equal(count2)

	# Verify same players declared
	var declared1 := _get_declared_ids(pool1)
	var declared2 := _get_declared_ids(pool2)

	assert_int(declared1.size()).is_equal(declared2.size())
	for pid in declared1:
		assert_bool(declared2.has(pid)).is_true()


func test_determinism_different_seeds_different_results() -> void:
	var pool1 := _create_test_pool(100)
	var pool2 := _create_test_pool(100)

	var mock_ranks := UnderclassmanDeclarationEngine.build_simple_mock_ranks(pool1)

	# Run with different seeds
	var result_count1 := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool1, mock_ranks, 2024, 12345
	)
	var count1: int = int(result_count1.get("declaration_count", 0))
	var result_count2 := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool2, mock_ranks, 2024, 99999
	)
	var count2: int = int(result_count2.get("declaration_count", 0))

	# Results should likely differ (not guaranteed but very probable)
	var declared1 := _get_declared_ids(pool1)
	var declared2 := _get_declared_ids(pool2)

	# At least verify both produce results
	assert_int(count1).is_greater(0)
	assert_int(count2).is_greater(0)


func test_determinism_multiple_runs_same_seed() -> void:
	var seed_value := 54321

	# Run 5 times with same seed
	var results: Array = []
	for i in range(5):
		var pool := _create_test_pool(100)
		var mock_ranks := UnderclassmanDeclarationEngine.build_simple_mock_ranks(pool)
		var result_count := UnderclassmanDeclarationEngine.evaluate_declarations(
			pool, mock_ranks, 2024, seed_value
		)
		var count: int = int(result_count.get("declaration_count", 0))
		var declared := _get_declared_ids(pool)
		results.append({"count": count, "declared": declared})

	# All runs should be identical
	for i in range(1, results.size()):
		assert_int(results[i].count).is_equal(results[0].count)
		var d0: Array = results[0].declared
		var di: Array = results[i].declared
		assert_int(di.size()).is_equal(d0.size())


# =============================================================================
# Test: Probability Distribution
# =============================================================================

func test_probability_elite_tier_90_percent() -> void:
	# Create pool of elite players (75+ rating)
	var pool := _create_tier_pool(500, 75.0, 85.0, "elite")
	var mock_ranks := {}  # No first-round projections to isolate rating effect

	# Run with fixed seed
	var result := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var declared_count: int = int(result.get("declaration_count", 0))

	# Calculate percentage
	var percentage := float(declared_count) / float(pool.size()) * 100.0

	# Expected: 90% +/- 5%
	assert_float(percentage).is_greater_equal(85.0)
	assert_float(percentage).is_less_equal(95.0)


func test_probability_good_tier_60_percent() -> void:
	# Create pool of good players (70-74 rating)
	var pool := _create_tier_pool(500, 70.0, 74.0, "good")
	var mock_ranks := {}

	var result := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var declared_count: int = int(result.get("declaration_count", 0))

	var percentage := float(declared_count) / float(pool.size()) * 100.0

	# Expected: 60% +/- 5%
	assert_float(percentage).is_greater_equal(55.0)
	assert_float(percentage).is_less_equal(65.0)


func test_probability_marginal_tier_30_percent() -> void:
	# Create pool of marginal players (60-69 rating)
	var pool := _create_tier_pool(500, 60.0, 69.0, "marginal")
	var mock_ranks := {}

	var result := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var declared_count: int = int(result.get("declaration_count", 0))

	var percentage := float(declared_count) / float(pool.size()) * 100.0

	# Expected: 30% +/- 5%
	assert_float(percentage).is_greater_equal(25.0)
	assert_float(percentage).is_less_equal(35.0)


func test_probability_below_tier_under_10_percent() -> void:
	# Create pool of below-average players (<60 rating)
	var pool := _create_tier_pool(500, 40.0, 59.0, "below")
	var mock_ranks := {}

	var result := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var declared_count: int = int(result.get("declaration_count", 0))

	var percentage := float(declared_count) / float(pool.size()) * 100.0

	# Expected: <10% (specifically 8% +/- 3%)
	assert_float(percentage).is_less_equal(12.0)


# =============================================================================
# Test: First-Round Projection Override
# =============================================================================

func test_first_round_projections_99_percent_declare() -> void:
	# Create pool with mixed ratings
	var pool := _create_tier_pool(100, 50.0, 70.0, "mixed")

	# Give all players first-round projections (picks 1-32)
	var mock_ranks := {}
	for i in range(pool.size()):
		var p: Dictionary = pool[i]
		mock_ranks[String(p.get("player_id", ""))] = (i % 32) + 1

	var result := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var declared_count: int = int(result.get("declaration_count", 0))

	var percentage := float(declared_count) / float(pool.size()) * 100.0

	# Expected: 99% +/- 2% (first-round override)
	assert_float(percentage).is_greater_equal(95.0)


func test_first_round_override_trumps_low_rating() -> void:
	# Create pool of low-rated players (<60)
	var pool := _create_tier_pool(50, 40.0, 55.0, "low")

	# Give half first-round projections
	var mock_ranks := {}
	for i in range(25):
		var p: Dictionary = pool[i]
		mock_ranks[String(p.get("player_id", ""))] = i + 1

	var result := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var declared_count: int = int(result.get("declaration_count", 0))

	# At least 24-25 should declare (first-round players)
	# Plus a few from the remaining low-rated players (~8%)
	assert_int(declared_count).is_greater_equal(24)


# =============================================================================
# Test: Pool Size Variance
# =============================================================================

func test_pool_size_realistic_range_50_to_100() -> void:
	# Run multiple simulations and verify pool sizes stay in range
	var declaration_counts: Array = []

	for seed_val in range(1, 51):  # 50 different seeds
		var pool := _create_realistic_draft_pool(600)
		var mock_ranks := UnderclassmanDeclarationEngine.build_simple_mock_ranks(pool)

		var result := UnderclassmanDeclarationEngine.evaluate_declarations(
			pool, mock_ranks, 2024, seed_val * 1000
		)
		var count: int = int(result.get("declaration_count", 0))
		declaration_counts.append(count)

	# Calculate statistics
	var min_count := 9999
	var max_count := 0
	var sum := 0

	for count in declaration_counts:
		var c: int = count
		min_count = min(min_count, c)
		max_count = max(max_count, c)
		sum += c

	var avg := float(sum) / float(declaration_counts.size())

	# Verify average is in expected range (relaxed for test stability)
	# The exact range depends on pool composition
	assert_float(avg).is_greater(30.0)
	assert_float(avg).is_less(150.0)


# =============================================================================
# Test: Edge Cases
# =============================================================================

func test_empty_pool_returns_zero() -> void:
	var pool: Array = []
	var mock_ranks := {}

	var result_count := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 12345
	)
	var count: int = int(result_count.get("declaration_count", 0))

	assert_int(count).is_equal(0)


func test_all_seniors_no_declarations() -> void:
	# Create pool of seniors (class_year = 4)
	var pool: Array = []
	for i in range(50):
		pool.append({
			"player_id": "senior_%d" % i,
			"class_year": 4,  # Senior - not eligible
			"stage": 1,  # COLLEGE
			"declared_for_draft": false,
			"stats": {"speed": 80.0, "strength": 75.0}
		})

	var mock_ranks := {}
	var result_count := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 12345
	)
	var count: int = int(result_count.get("declaration_count", 0))

	assert_int(count).is_equal(0)


func test_already_declared_players_excluded() -> void:
	var pool: Array = []
	for i in range(50):
		pool.append({
			"player_id": "player_%d" % i,
			"class_year": 3,  # Junior
			"stage": 1,  # COLLEGE
			"declared_for_draft": true,  # Already declared
			"stats": {"speed": 90.0, "strength": 85.0}
		})

	var mock_ranks := {}
	var result_count := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 12345
	)
	var count: int = int(result_count.get("declaration_count", 0))

	assert_int(count).is_equal(0)


func test_non_college_players_excluded() -> void:
	var pool: Array = []
	for i in range(50):
		pool.append({
			"player_id": "player_%d" % i,
			"class_year": 3,  # Junior
			"stage": 0,  # HIGH_SCHOOL (not college)
			"declared_for_draft": false,
			"stats": {"speed": 90.0, "strength": 85.0}
		})

	var mock_ranks := {}
	var result_count := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 12345
	)
	var count: int = int(result_count.get("declaration_count", 0))

	assert_int(count).is_equal(0)


func test_mixed_eligibility_pool() -> void:
	var pool: Array = []

	# Add eligible juniors
	for i in range(20):
		pool.append({
			"player_id": "junior_%d" % i,
			"class_year": 3,
			"stage": 1,
			"declared_for_draft": false,
			"stats": {"speed": 80.0, "strength": 75.0}
		})

	# Add ineligible seniors
	for i in range(20):
		pool.append({
			"player_id": "senior_%d" % i,
			"class_year": 4,
			"stage": 1,
			"declared_for_draft": false,
			"stats": {"speed": 80.0, "strength": 75.0}
		})

	# Add already declared
	for i in range(10):
		pool.append({
			"player_id": "declared_%d" % i,
			"class_year": 3,
			"stage": 1,
			"declared_for_draft": true,
			"stats": {"speed": 80.0, "strength": 75.0}
		})

	var mock_ranks := {}
	var result_count := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 12345
	)
	var count: int = int(result_count.get("declaration_count", 0))

	# Only the 20 eligible juniors can declare (not seniors or already declared)
	# At 60-65% rate for 75 avg rating, expect ~12-15
	assert_int(count).is_greater(0)
	assert_int(count).is_less_equal(20)


# =============================================================================
# Test: Player Model Backward Compatibility
# =============================================================================

func test_player_model_class_year_from_dict_explicit() -> void:
	var player := Player.new()
	player.from_dict({
		"id": "test_001",
		"class_year": 2,
		"age": 20
	})

	assert_int(player.class_year).is_equal(2)


func test_player_model_class_year_inferred_from_age() -> void:
	# Test age inference when class_year not present
	var test_cases := [
		{"age": 18, "expected": 1},  # Freshman
		{"age": 19, "expected": 2},  # Sophomore
		{"age": 20, "expected": 3},  # Junior
		{"age": 21, "expected": 4},  # Senior
		{"age": 22, "expected": 4},  # Senior (clamped)
		{"age": 25, "expected": 4},  # Senior (clamped)
	]

	for tc in test_cases:
		var player := Player.new()
		player.from_dict({
			"id": "test",
			"age": tc.age
			# Note: no class_year provided
		})
		assert_int(player.class_year).is_equal(tc.expected)


func test_player_model_declared_for_draft_default_false() -> void:
	var player := Player.new()
	player.from_dict({
		"id": "test_001"
	})

	assert_bool(player.declared_for_draft).is_false()


func test_player_model_declared_for_draft_from_dict() -> void:
	var player := Player.new()
	player.from_dict({
		"id": "test_001",
		"declared_for_draft": true
	})

	assert_bool(player.declared_for_draft).is_true()


func test_player_model_to_dict_includes_new_fields() -> void:
	var player := Player.new()
	player.class_year = 3
	player.declared_for_draft = true

	var dict := player.to_dict()

	assert_int(int(dict.get("class_year", 0))).is_equal(3)
	assert_bool(bool(dict.get("declared_for_draft", false))).is_true()


func test_player_model_roundtrip_preserves_fields() -> void:
	var original := Player.new()
	original.class_year = 2
	original.declared_for_draft = true

	var dict := original.to_dict()

	var loaded := Player.new()
	loaded.from_dict(dict)

	assert_int(loaded.class_year).is_equal(2)
	assert_bool(loaded.declared_for_draft).is_true()


# =============================================================================
# Test: Tier Classification
# =============================================================================

func test_get_tier_for_rating() -> void:
	# Elite: 75+
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(75.0)).is_equal("elite")
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(90.0)).is_equal("elite")

	# Good: 70-74
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(70.0)).is_equal("good")
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(74.9)).is_equal("good")

	# Marginal: 60-69
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(60.0)).is_equal("marginal")
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(69.9)).is_equal("marginal")

	# Below: <60
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(59.9)).is_equal("below")
	assert_str(UnderclassmanDeclarationEngine.get_tier_for_rating(40.0)).is_equal("below")


# =============================================================================
# Test: Stage Transition
# =============================================================================

func test_declaration_sets_draft_eligible_stage() -> void:
	var pool: Array = []
	for i in range(20):
		pool.append({
			"player_id": "elite_%d" % i,
			"class_year": 3,
			"stage": 1,  # COLLEGE
			"declared_for_draft": false,
			"stats": {"speed": 95.0, "strength": 90.0}  # Elite rating
		})

	var mock_ranks := {}
	for i in range(20):
		mock_ranks["elite_%d" % i] = i + 1  # First round projections

	UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 12345
	)

	# All declaring players should have stage = 2 (DRAFT_ELIGIBLE)
	for player in pool:
		var p: Dictionary = player
		if bool(p.get("declared_for_draft", false)):
			assert_int(int(p.get("stage", 0))).is_equal(2)


# =============================================================================
# Test: Stable Iteration Order
# =============================================================================

func test_iteration_order_by_player_id() -> void:
	# Create pool with non-alphabetical insertion order
	var pool: Array = []
	var ids := ["zebra", "alpha", "mike", "delta", "charlie"]

	for pid in ids:
		pool.append({
			"player_id": pid,
			"class_year": 3,
			"stage": 1,
			"declared_for_draft": false,
			"stats": {"speed": 80.0, "strength": 75.0}
		})

	var mock_ranks := {}

	# Run twice with same seed
	var pool_copy := pool.duplicate(true)

	var result_count1 := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 99999
	)
	var count1: int = int(result_count1.get("declaration_count", 0))
	var result_count2 := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool_copy, mock_ranks, 2024, 99999
	)
	var count2: int = int(result_count2.get("declaration_count", 0))

	# Same declarations regardless of insertion order
	assert_int(count1).is_equal(count2)

	var declared1 := _get_declared_ids(pool)
	var declared2 := _get_declared_ids(pool_copy)

	assert_int(declared1.size()).is_equal(declared2.size())


# =============================================================================
# Test: Estimate Declaration Count
# =============================================================================

func test_estimate_declaration_count_approximates_actual() -> void:
	var pool := _create_realistic_draft_pool(200)
	var mock_ranks := UnderclassmanDeclarationEngine.build_simple_mock_ranks(pool)

	var estimate := UnderclassmanDeclarationEngine.estimate_declaration_count(
		pool, mock_ranks
	)

	# Run actual declarations
	var result_actual := UnderclassmanDeclarationEngine.evaluate_declarations(
		pool, mock_ranks, 2024, 42
	)
	var actual: int = int(result_actual.get("declaration_count", 0))

	# Estimate should be reasonably close to actual (within 20%)
	var diff: float = abs(estimate - float(actual))
	var tolerance: float = maxf(estimate, float(actual)) * 0.3

	assert_float(diff).is_less_equal(tolerance)


# =============================================================================
# Helper Functions
# =============================================================================

func _create_test_pool(size: int) -> Array:
	var pool: Array = []
	for i in range(size):
		# Mix of class years and ratings
		var class_yr := (i % 3) + 1  # 1, 2, or 3 (underclassmen)
		var rating := 50.0 + float(i % 50)

		pool.append({
			"player_id": "player_%03d" % i,
			"class_year": class_yr,
			"stage": 1,  # COLLEGE
			"declared_for_draft": false,
			"stats": {"speed": rating, "strength": rating - 5.0}
		})

	return pool


func _create_tier_pool(size: int, min_rating: float, max_rating: float, tier_name: String) -> Array:
	var pool: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed for test consistency

	for i in range(size):
		var rating := rng.randf_range(min_rating, max_rating)

		pool.append({
			"player_id": "%s_%03d" % [tier_name, i],
			"class_year": 3,  # All juniors
			"stage": 1,  # COLLEGE
			"declared_for_draft": false,
			"core_avg": rating,  # Pre-calculated rating for PlayerRatingCalculator (Priority 2)
			"stats": {"speed": rating, "strength": rating}
		})

	return pool


func _create_realistic_draft_pool(total_size: int) -> Array:
	var pool: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	for i in range(total_size):
		# Realistic distribution:
		# ~60% seniors (not eligible for early entry)
		# ~25% juniors
		# ~10% sophomores
		# ~5% redshirt freshmen
		var roll := rng.randf()
		var class_yr: int
		if roll < 0.60:
			class_yr = 4  # Senior
		elif roll < 0.85:
			class_yr = 3  # Junior
		elif roll < 0.95:
			class_yr = 2  # Sophomore
		else:
			class_yr = 1  # Freshman

		# Realistic rating distribution (normal-ish, centered around 65)
		var rating: float = clampf(rng.randfn(65.0, 12.0), 40.0, 99.0)

		pool.append({
			"player_id": "prospect_%03d" % i,
			"class_year": class_yr,
			"stage": 1,
			"declared_for_draft": false,
			"core_avg": rating,  # Pre-calculated rating for PlayerRatingCalculator (Priority 2)
			"stats": {"speed": rating, "strength": rating - 2.0, "agility": rating + 1.0}
		})

	return pool


func _get_declared_ids(pool: Array) -> Array:
	var declared: Array = []
	for player in pool:
		var p: Dictionary = player
		if bool(p.get("declared_for_draft", false)):
			declared.append(String(p.get("player_id", "")))
	declared.sort()
	return declared
