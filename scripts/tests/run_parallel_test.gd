extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestParallelLifecycle = preload("res://scripts/tests/test_parallel_lifecycle.gd")

func _init() -> void:
	print("Running parallel lifecycle tests...")
	var test = TestParallelLifecycle.new()
	var helper = TestHelpers.new()

	test.run(helper)

	if helper.failures.is_empty():
		print("All parallel lifecycle tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)
