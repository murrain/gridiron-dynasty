extends RefCounted

const BootstrapWorld = preload("res://scripts/pipelines/BootstrapWorld.gd")
const GenerateFutureDraftClasses = preload("res://scripts/pipelines/GenerateFutureDraftClasses.gd")
const GenerateClassOnce = preload("res://scripts/pipelines/GenerateClassOnce.gd")

func run(t) -> void:
	var bootstrap := BootstrapWorld.new()
	var seed_a := bootstrap._resolve_seed(1234, 2025)
	var seed_b := bootstrap._resolve_seed(1234, 2025)
	var seed_c := bootstrap._resolve_seed(1234, 2026)
	t.assert_eq(seed_a, seed_b, "BootstrapWorld resolves seeds deterministically")
	t.assert_ne(seed_a, seed_c, "BootstrapWorld seed changes with year")

	var future := GenerateFutureDraftClasses.new()
	var f_seed_a := future._resolve_seed(4321, 2030)
	var f_seed_b := future._resolve_seed(4321, 2030)
	t.assert_eq(f_seed_a, f_seed_b, "GenerateFutureDraftClasses resolves seeds deterministically")

	var once := GenerateClassOnce.new()
	var main_cfg := {"random_seed": 555, "starting_year": 2025}
	var resolved := once._resolve_seed(main_cfg)
	t.assert_eq(resolved, 555, "GenerateClassOnce resolves random_seed")
	var rng := once._step_rng(555, "generate")
	var rng_again := once._step_rng(555, "generate")
	t.assert_eq(rng.randi(), rng_again.randi(), "GenerateClassOnce step RNG deterministic")
