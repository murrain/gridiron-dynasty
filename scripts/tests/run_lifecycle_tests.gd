extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestPlayerLifecycle = preload("res://scripts/tests/test_player_lifecycle.gd")
const TestParallelLifecycle = preload("res://scripts/tests/test_parallel_lifecycle.gd")

func _init() -> void:
	print("Running lifecycle tests...")

	var all_failures: Array = []

	# Run original lifecycle tests
	var test1 = TestPlayerLifecycle.new()
	var helper1 = TestHelpers.new()
	test1.run(helper1)
	for failure in helper1.failures:
		all_failures.append("test_player_lifecycle.gd: %s" % failure)

	# Run parallel lifecycle tests
	var test2 = TestParallelLifecycle.new()
	var helper2 = TestHelpers.new()
	test2.run(helper2)
	for failure in helper2.failures:
		all_failures.append("test_parallel_lifecycle.gd: %s" % failure)

	if all_failures.is_empty():
		print("All lifecycle tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % all_failures.size())
		for failure in all_failures:
			print("- %s" % failure)
		quit(1)
