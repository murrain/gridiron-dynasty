extends RefCounted

func run(t: TestHelpers) -> void:
	var seed_val := 123456789
	var a := Rand.splitmix64(seed_val)
	var b := Rand.splitmix64(seed_val)
	var c := Rand.splitmix64(seed_val + 1)
	t.assert_eq(a, b, "splitmix64 should be deterministic")
	t.assert_ne(a, c, "splitmix64 should change with input")

	var rand_instance := Rand.new()
	rand_instance.set_base_seed(42)
	var seeds := rand_instance.derive_seeds(3)
	t.assert_eq(seeds.size(), 3, "derive_seeds returns requested count")
	t.assert_ne(seeds[0], seeds[1], "derive_seeds should vary per index")

	var rng1 := Rand.rng_for_seed(99)
	var rng2 := Rand.rng_for_seed(99)
	t.assert_eq(rng1.randi(), rng2.randi(), "rng_for_seed should be deterministic")

	rand_instance.set_base_seed(77)
	var rng_index_a := rand_instance.rng_for_index(0)
	var rng_index_b := rand_instance.rng_for_index(0)
	t.assert_eq(rng_index_a.randi(), rng_index_b.randi(), "rng_for_index should be stable per index")
