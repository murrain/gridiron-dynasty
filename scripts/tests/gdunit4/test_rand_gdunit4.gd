## GdUnit4 POC Test 1: Simple Unit Test
##
## Validates RNG utilities are deterministic and produce expected outputs.
## Migrated from test_rand.gd to demonstrate GdUnit4 fluent assertion syntax.
##
## POC Category: Simple Unit Test
extends GdUnitTestSuite

const Rand = preload("res://autoloads/Rand.gd")


func test_splitmix64_is_deterministic() -> void:
	var seed_val := 123456789
	var a := Rand.splitmix64(seed_val)
	var b := Rand.splitmix64(seed_val)

	assert_that(a).is_equal(b)


func test_splitmix64_changes_with_input() -> void:
	var seed_val := 123456789
	var a := Rand.splitmix64(seed_val)
	var c := Rand.splitmix64(seed_val + 1)

	assert_that(a).is_not_equal(c)


func test_derive_seeds_returns_requested_count() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(42)
	var seeds := rand_instance.derive_seeds(3)

	assert_int(seeds.size()).is_equal(3)


func test_derive_seeds_values_vary_per_index() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(42)
	var seeds := rand_instance.derive_seeds(3)

	assert_that(seeds[0]).is_not_equal(seeds[1])


func test_rng_for_seed_is_deterministic() -> void:
	var rng1 := Rand.rng_for_seed(99)
	var rng2 := Rand.rng_for_seed(99)

	assert_int(rng1.randi()).is_equal(rng2.randi())


func test_rng_for_index_is_stable_per_index() -> void:
	var rand_instance := Rand.new()
	rand_instance.set_base_seed(77)

	var rng_index_a := rand_instance.rng_for_index(0)
	var rng_index_b := rand_instance.rng_for_index(0)

	assert_int(rng_index_a.randi()).is_equal(rng_index_b.randi())
