extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestReportDeferral = preload("res://scripts/tests/test_report_deferral.gd")

func _init() -> void:
	print("Running report deferral tests (Task F7)...")

	var test = TestReportDeferral.new()
	var helper = TestHelpers.new()
	test.run(helper)

	if helper.failures.is_empty():
		print("All report deferral tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)
