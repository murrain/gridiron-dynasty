extends GdUnitTestSuite
class_name TestRandGdUnit4

## GdUnit4 tests for Rand autoload - deterministic RNG utilities
##
## Tests:
##   - SplitMix64 determinism and distribution
##   - Seed derivation consistency
##   - Base seed management
##   - RNG creation and seeding

const Rand = preload("res://autoloads/Rand.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# SPLITMIX64 DETERMINISM TESTS
# =============================================================================

func test_splitmix64_is_deterministic() -> void:
	var seed_value := 0x12345678
	var result1 := Rand.splitmix64(seed_value)
	var result2 := Rand.splitmix64(seed_value)

	assert_int(result1).is_equal(result2)


func test_splitmix64_produces_different_values_for_different_seeds() -> void:
	var result1 := Rand.splitmix64(0x1111)
	var result2 := Rand.splitmix64(0x2222)

	assert_int(result1).is_not_equal(result2)


func test_splitmix64_distribution() -> void:
	# SplitMix64 should produce well-distributed values
	var values := {}
	var base_seed := 0x12345678

	for i in range(100):
		var result := Rand.splitmix64(base_seed + i)
		values[result] = true

	# Should produce 100 unique values (no collisions)
	assert_int(values.size()).is_equal(100)


func test_splitmix64_avalanche_effect() -> void:
	# Small change in input should produce large change in output
	var seed1 := 0x12345678
	var seed2 := 0x12345679  # Only 1 bit different

	var result1 := Rand.splitmix64(seed1)
	var result2 := Rand.splitmix64(seed2)

	# Results should be completely different
	assert_int(result1).is_not_equal(result2)

	# Count differing bits (should be many)
	var xor_result := result1 ^ result2
	var bits_different := 0
	for i in range(64):
		if xor_result & (1 << i):
			bits_different += 1

	# At least 20 bits should differ (good avalanche)
	assert_int(bits_different).is_greater(20)


# =============================================================================
# BASE SEED MANAGEMENT TESTS
# =============================================================================

func test_set_base_seed_and_retrieve() -> void:
	var rand_instance := Rand.new()
	var test_seed := 0xDEADBEEF

	rand_instance.set_base_seed(test_seed)
	var retrieved_seed := rand_instance.base_seed()

	assert_int(retrieved_seed).is_equal(test_seed)


func test_base_seed_masking() -> void:
	var rand_instance := Rand.new()
	# Test that seed is masked to 64-bit
	var large_value := 0x1_0000_0000_0000_0000  # Beyond 64-bit

	rand_instance.set_base_seed(large_value)
	var retrieved := rand_instance.base_seed()

	# Should be masked to 64-bit
	assert_int(retrieved).is_equal(large_value & Rand.MASK_64)


# =============================================================================
# SEED DERIVATION TESTS
# =============================================================================

func test_derive_seeds_produces_correct_count() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x12345)

	var seeds := rand_instance.derive_seeds(10)

	assert_int(seeds.size()).is_equal(10)


func test_derive_seeds_is_deterministic() -> void:
	var rand1 := Rand.new()
	var rand2 := Rand.new()

	rand1.set_base_seed(0xABCDEF)
	rand2.set_base_seed(0xABCDEF)

	var seeds1 := rand1.derive_seeds(20)
	var seeds2 := rand2.derive_seeds(20)

	for i in range(20):
		assert_int(seeds1[i]).is_equal(seeds2[i])


func test_derive_seeds_produces_unique_values() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x12345)

	var seeds := rand_instance.derive_seeds(50)
	var unique_seeds := {}

	for seed in seeds:
		unique_seeds[seed] = true

	# All seeds should be unique
	assert_int(unique_seeds.size()).is_equal(50)


func test_derive_seeds_with_base_override() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x1111)  # Set default base

	# Derive with override
	var seeds_override := rand_instance.derive_seeds(5, 0x9999)

	# Derive using default base
	var seeds_default := rand_instance.derive_seeds(5)

	# Should be different (override used different base)
	assert_int(seeds_override[0]).is_not_equal(seeds_default[0])


func test_derive_seeds_different_bases_produce_different_sequences() -> void:
	var rand_instance := Rand.new()

	var seeds1 := rand_instance.derive_seeds(10, 0xAAAA)
	var seeds2 := rand_instance.derive_seeds(10, 0xBBBB)

	# First seed should be different
	assert_int(seeds1[0]).is_not_equal(seeds2[0])


# =============================================================================
# RNG CREATION TESTS
# =============================================================================

func test_rng_for_seed_creates_seeded_rng() -> void:
	var seed_value := 0x12345678

	var rng1 := Rand.rng_for_seed(seed_value)
	var rng2 := Rand.rng_for_seed(seed_value)

	# Same seed should produce same sequence
	assert_int(rng1.randi()).is_equal(rng2.randi())


func test_rng_for_seed_produces_deterministic_sequence() -> void:
	var seed_value := 0xABCDEF

	var rng1 := Rand.rng_for_seed(seed_value)
	var rng2 := Rand.rng_for_seed(seed_value)

	# Generate 10 values from each RNG
	for i in range(10):
		var val1 := rng1.randi()
		var val2 := rng2.randi()
		assert_int(val1).is_equal(val2)


func test_rng_for_index_determinism() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x999)

	var rng1 := rand_instance.rng_for_index(5)
	var rng2 := rand_instance.rng_for_index(5)

	# Same index should produce same RNG sequence
	assert_int(rng1.randi()).is_equal(rng2.randi())


func test_rng_for_index_different_indices_produce_different_sequences() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x777)

	var rng_index_0 := rand_instance.rng_for_index(0)
	var rng_index_1 := rand_instance.rng_for_index(1)

	# Different indices should produce different sequences
	assert_int(rng_index_0.randi()).is_not_equal(rng_index_1.randi())


func test_rng_for_index_with_base_override() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x1111)

	var rng_default := rand_instance.rng_for_index(0)
	var rng_override := rand_instance.rng_for_index(0, 0x9999)

	# Different bases should produce different sequences
	assert_int(rng_default.randi()).is_not_equal(rng_override.randi())


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_full_workflow_seed_derivation_to_rng_usage() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x42424242)

	# Derive 5 seeds
	var seeds := rand_instance.derive_seeds(5)

	# Create RNGs from derived seeds
	var rngs := []
	for seed in seeds:
		rngs.append(Rand.rng_for_seed(seed))

	# Generate values
	var first_values := []
	for rng in rngs:
		first_values.append((rng as RandomNumberGenerator).randi())

	# Repeat workflow with same base seed
	rand_instance.set_base_seed(0x42424242)
	var seeds2 := rand_instance.derive_seeds(5)
	var rngs2 := []
	for seed in seeds2:
		rngs2.append(Rand.rng_for_seed(seed))

	var second_values := []
	for rng in rngs2:
		second_values.append((rng as RandomNumberGenerator).randi())

	# Should produce identical sequences
	for i in range(5):
		assert_int(first_values[i]).is_equal(second_values[i])


func test_rand_utility_supports_simulation_seeding() -> void:
	# Simulate what a real simulation phase would do
	var rand_instance := Rand.new()
	var master_seed := 0x2025_SEASON
	rand_instance.set_base_seed(master_seed)

	# Derive seeds for different simulation phases
	var phase_seeds := rand_instance.derive_seeds(10)

	# Phase 0: HS generation
	var hs_rng := Rand.rng_for_seed(phase_seeds[0])
	var hs_player_count := hs_rng.randi_range(1000, 5000)

	# Phase 1: College recruiting
	var recruiting_rng := Rand.rng_for_seed(phase_seeds[1])
	var recruit_decisions := recruiting_rng.randi_range(100, 300)

	# Repeat simulation with same seed
	rand_instance.set_base_seed(master_seed)
	var phase_seeds2 := rand_instance.derive_seeds(10)

	var hs_rng2 := Rand.rng_for_seed(phase_seeds2[0])
	var hs_player_count2 := hs_rng2.randi_range(1000, 5000)

	var recruiting_rng2 := Rand.rng_for_seed(phase_seeds2[1])
	var recruit_decisions2 := recruiting_rng2.randi_range(100, 300)

	# Should produce identical results
	assert_int(hs_player_count).is_equal(hs_player_count2)
	assert_int(recruit_decisions).is_equal(recruit_decisions2)


# =============================================================================
# EDGE CASES AND VALIDATION
# =============================================================================

func test_derive_seeds_with_zero_count() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x123)

	var seeds := rand_instance.derive_seeds(0)

	assert_int(seeds.size()).is_equal(0)


func test_derive_seeds_with_large_count() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(0x456)

	var seeds := rand_instance.derive_seeds(1000)

	assert_int(seeds.size()).is_equal(1000)

	# Check uniqueness (no collisions in 1000 seeds)
	var unique := {}
	for seed in seeds:
		unique[seed] = true
	assert_int(unique.size()).is_equal(1000)


func test_splitmix64_with_zero_seed() -> void:
	var result := Rand.splitmix64(0)

	# Should still produce a value
	assert_int(result).is_not_equal(0)


func test_splitmix64_with_negative_seed() -> void:
	var result1 := Rand.splitmix64(-12345)
	var result2 := Rand.splitmix64(-12345)

	# Should be deterministic even with negative seeds
	assert_int(result1).is_equal(result2)
