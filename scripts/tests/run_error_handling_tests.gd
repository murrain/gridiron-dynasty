extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestErrorHandling = preload("res://scripts/tests/test_error_handling.gd")

func _init() -> void:
	print("Running error handling tests...")

	var test = TestErrorHandling.new()
	var helper = TestHelpers.new()
	test.run(helper)

	if helper.failures.is_empty():
		print("All error handling tests passed! (%d test functions)" % _count_test_functions())
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)

func _count_test_functions() -> int:
	# Count test functions in test_error_handling.gd
	# Based on the categories: 7 + 8 + 3 + 3 + 3 = 24 test functions
	return 24
