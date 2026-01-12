extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

const TEST_SCRIPTS := [
	"res://scripts/tests/test_a1_starter_cache.gd"
]

func _init() -> void:
	var total_failures: Array = []
	for path in TEST_SCRIPTS:
		print("\nRunning: %s" % path)
		var script = load(path)
		if script == null:
			total_failures.append("Failed to load %s" % path)
			continue
		var test_instance = script.new()
		var helper = TestHelpers.new()
		test_instance.run(helper)
		for failure in helper.failures:
			total_failures.append("%s: %s" % [path, failure])

	print("\n" + "=".repeat(60))
	if total_failures.is_empty():
		print("All A1 optimization tests passed (%d)." % TEST_SCRIPTS.size())
		quit(0)
		return

	print("Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
