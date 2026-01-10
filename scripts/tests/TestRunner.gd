extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

const TEST_SCRIPTS := [
	"res://scripts/tests/test_rand.gd",
	"res://scripts/tests/test_threadpool.gd",
	"res://scripts/tests/test_config.gd",
	"res://scripts/tests/test_config_loader.gd",
	"res://scripts/tests/test_helpers.gd",
	"res://scripts/tests/test_deager.gd",
	"res://scripts/tests/test_stathelpers.gd",
	"res://scripts/tests/test_combine_calculator.gd",
	"res://scripts/tests/test_high_school_assignment.gd",
	"res://scripts/tests/test_player_lifecycle.gd",
	"res://scripts/tests/test_world_calendar.gd",
	"res://scripts/tests/test_high_school_generator.gd",
	"res://scripts/tests/test_high_school_season.gd",
	"res://scripts/tests/test_player_generator.gd"
]

func _init() -> void:
	var total_failures: Array = []
	for path in TEST_SCRIPTS:
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
		print("All tests passed (%d)." % TEST_SCRIPTS.size())
		quit(0)
		return

	print("Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
