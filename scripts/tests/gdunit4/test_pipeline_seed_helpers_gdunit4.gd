## GdUnit4 test suite for pipeline seed helpers
##
## Validates seed resolution and step RNG creation in pipeline components.
## Migrated from test_pipeline_seed_helpers.gd
extends GdUnitTestSuite

const BootstrapWorld = preload("res://scripts/pipelines/BootstrapWorld.gd")
const GenerateFutureDraftClasses = preload("res://scripts/pipelines/GenerateFutureDraftClasses.gd")
const GenerateClassOnce = preload("res://scripts/pipelines/GenerateClassOnce.gd")


func test_bootstrap_resolves_seeds_deterministically() -> void:
	var bootstrap := BootstrapWorld.new()
	var seed_a := bootstrap._resolve_seed(1234, 2025)
	var seed_b := bootstrap._resolve_seed(1234, 2025)
	assert_int(seed_a).is_equal(seed_b)


func test_bootstrap_seed_changes_with_year() -> void:
	var bootstrap := BootstrapWorld.new()
	var seed_a := bootstrap._resolve_seed(1234, 2025)
	var seed_c := bootstrap._resolve_seed(1234, 2026)
	assert_int(seed_a).is_not_equal(seed_c)


func test_future_draft_classes_resolves_seeds_deterministically() -> void:
	var future := GenerateFutureDraftClasses.new()
	var f_seed_a := future._resolve_seed(4321, 2030)
	var f_seed_b := future._resolve_seed(4321, 2030)
	assert_int(f_seed_a).is_equal(f_seed_b)


func test_generate_once_resolves_random_seed() -> void:
	var once := GenerateClassOnce.new()
	var main_cfg := {"random_seed": 555, "starting_year": 2025}
	var resolved := once._resolve_seed(main_cfg)
	assert_int(resolved).is_equal(555)


func test_generate_once_step_rng_is_deterministic() -> void:
	var once := GenerateClassOnce.new()
	var rng := once._step_rng(555, "generate")
	var rng_again := once._step_rng(555, "generate")
	assert_int(rng.randi()).is_equal(rng_again.randi())
