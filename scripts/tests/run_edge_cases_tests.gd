extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestEdgeCases = preload("res://scripts/tests/test_edge_cases_comprehensive.gd")

func _init() -> void:
	print("Running comprehensive edge case tests...")

	var test = TestEdgeCases.new()
	var helper = TestHelpers.new()
	test.run(helper)

	if helper.failures.is_empty():
		print("All edge case tests passed! (%d test functions)" % _count_test_functions())
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)

func _count_test_functions() -> int:
	# Count test functions in test_edge_cases_comprehensive.gd
	# Based on the categories:
	# Cat 1: 4, Cat 2: 4, Cat 3: 4, Cat 4: 4, Cat 5: 4, Cat 6: 4, Cat 7: 4, Cat 8: 3
	return 31
