## Test runner for Coach model
##
## Usage: godot --headless --script scripts/tests/run_coach_model_test.gd
## Exit code: 0 = all tests passed, 1 = failures detected
extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestCoachModel = preload("res://scripts/tests/test_coach_model.gd")

func _init() -> void:
	print("Running Coach model tests...")
	var test = TestCoachModel.new()
	var helper = TestHelpers.new()

	test.run(helper)

	if helper.failures.is_empty():
		print("All Coach model tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)
