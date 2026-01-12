extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestPlayerModel = preload("res://scripts/tests/test_player_model.gd")

func _init() -> void:
	print("Running Player model tests...")
	var test = TestPlayerModel.new()
	var helper = TestHelpers.new()

	test.run(helper)

	if helper.failures.is_empty():
		print("All Player model tests passed!")
		quit(0)
	else:
		print("Failures (%d):" % helper.failures.size())
		for failure in helper.failures:
			print("- %s" % failure)
		quit(1)
