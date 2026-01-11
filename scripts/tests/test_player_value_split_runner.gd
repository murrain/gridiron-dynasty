extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

const SPLIT_TESTS := [
	"res://scripts/tests/test_player_value_core.gd",
	"res://scripts/tests/test_player_value_scenarios.gd",
	"res://scripts/tests/test_player_value_integration.gd"
]

func _init() -> void:
	var total_failures: Array = []
	for path in SPLIT_TESTS:
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
		print("All split player_value tests passed (3 files, 13 tests total)")
		quit(0)
		return

	print("Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
