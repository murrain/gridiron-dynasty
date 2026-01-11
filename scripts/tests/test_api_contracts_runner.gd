extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

func _init() -> void:
	var total_failures: Array = []
	var path = "res://scripts/tests/test_api_contracts.gd"

	var script = load(path)
	if script == null:
		print("Failed to load test_api_contracts.gd")
		quit(1)
		return

	var test_instance = script.new()
	var helper = TestHelpers.new()
	test_instance.run(helper)

	for failure in helper.failures:
		total_failures.append("%s: %s" % [path, failure])

	if total_failures.is_empty():
		print("test_api_contracts.gd passed (11 tests)")
		quit(0)
		return

	print("Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
