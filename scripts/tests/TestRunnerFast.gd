## Fast test runner - runs only unit tests (< 1 second each).
## Use this for rapid development feedback loop.
##
## Usage:
##   godot --headless -s res://scripts/tests/TestRunnerFast.gd
##
## For full test suite including slow integration tests, use TestRunner.gd instead.
extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

# Fast unit tests only (~20 tests, < 10 seconds total)
# These tests verify logic without expensive generation or simulation
const FAST_TESTS := [
	"res://scripts/tests/test_rand.gd",
	"res://scripts/tests/test_threadpool.gd",
	"res://scripts/tests/test_core_utilities.gd",
	"res://scripts/tests/test_config.gd",
	"res://scripts/tests/test_config_loader.gd",
	"res://scripts/tests/test_helpers.gd",
	"res://scripts/tests/test_testhelpers_enhancement.gd",  # NEW: Validates enhanced TestHelpers
	"res://scripts/tests/test_deager.gd",
	"res://scripts/tests/test_stathelpers.gd",
	"res://scripts/tests/test_combine_calculator.gd",
	"res://scripts/tests/test_player_model.gd",
	"res://scripts/tests/test_copy_optimization.gd",
	"res://scripts/tests/test_lifecycle_p3_optimizations.gd",
	"res://scripts/tests/test_world_calendar.gd",
	"res://scripts/tests/test_advance_world_year_helpers.gd",
	"res://scripts/tests/test_pipeline_seed_helpers.gd",
	"res://scripts/tests/test_valuation_helpers.gd",
	"res://scripts/tests/test_value_curve.gd",
	"res://scripts/tests/test_replacement_level.gd",
	"res://scripts/tests/test_positional_scarcity.gd",
	"res://scripts/tests/test_team_impact.gd",
	"res://scripts/tests/test_cap_accounting.gd",
	"res://scripts/tests/test_phase4_scaffolding.gd",
	"res://scripts/tests/test_scouting_resource_manager.gd",
	"res://scripts/tests/test_coach_generator.gd"
]

func _init() -> void:
	var total_failures: Array = []
	for path in FAST_TESTS:
		var script = load(path)
		if script == null:
			total_failures.append("Failed to load %s" % path)
			continue
		var test_instance = script.new()
		var helper = TestHelpers.new()
		test_instance.run(helper)
		for failure in helper.failures:
			total_failures.append("%s: %s" % [path, failure])

	if total_failures.is_empty():
		print("✅ All fast tests passed (%d tests)." % FAST_TESTS.size())
		quit(0)
		return

	print("❌ Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
