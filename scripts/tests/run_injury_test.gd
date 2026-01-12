extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestInjury = preload("res://scripts/tests/test_injury_system.gd")

func _init() -> void:
	var helper = TestHelpers.new()
	var test = TestInjury.new()
	test.run(helper)

	if helper.failures.is_empty():
		print("All injury tests passed.")
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)
