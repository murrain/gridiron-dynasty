extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const GrowthTests = preload("res://scripts/tests/test_player_growth_trajectories.gd")

func _init() -> void:
	print("=" . repeat(80))
	print("PLAYER GROWTH TRAJECTORY TESTS - BASELINE RUN")
	print("=" .repeat(80))
	print()

	var helper := TestHelpers.new()
	var test_instance := GrowthTests.new()

	print("Running growth trajectory tests...")
	test_instance.run(helper)

	print()
	print("=".repeat(80))
	print("TEST RESULTS")
	print("=".repeat(80))

	if helper.failures.is_empty():
		print("✅ All growth trajectory tests PASSED (%d tests)" % 10)
		quit(0)
	else:
		print("❌ FAILURES (%d):" % helper.failures.size())
		print()
		for failure in helper.failures:
			print("  • %s" % failure)
			print()
		quit(1)
