## Test runner for DepthChart model
##
## Usage: godot --headless --script scripts/tests/run_depth_chart_test.gd
## Exit code: 0 = all tests passed, 1 = failures detected
extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestDepthChart = preload("res://scripts/tests/test_depth_chart.gd")

func _init() -> void:
	print("Running DepthChart tests...")
	var test = TestDepthChart.new()
	var helper = TestHelpers.new()

	test.run(helper)

	if helper.failures.is_empty():
		print("All DepthChart tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)
