extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestFreeAgency = preload("res://scripts/tests/test_free_agency.gd")

func _init() -> void:
	print("Running Free Agency tests...")

	var all_failures: Array = []

	# Run free agency tests
	var test = TestFreeAgency.new()
	var helper = TestHelpers.new()
	test.run(helper)
	for failure in helper.failures:
		all_failures.append("test_free_agency.gd: %s" % failure)

	if all_failures.is_empty():
		print("All Free Agency tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % all_failures.size())
		for failure in all_failures:
			print("- %s" % failure)
		quit(1)
