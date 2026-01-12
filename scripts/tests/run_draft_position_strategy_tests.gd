extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestDraftPositionStrategy = preload("res://scripts/tests/test_draft_position_strategy.gd")

func _init() -> void:
	print("\n" + "=".repeat(80))
	print("RUNNING DRAFT POSITION STRATEGY TESTS")
	print("=".repeat(80) + "\n")

	var test := TestDraftPositionStrategy.new()
	var helper := TestHelpers.new()

	test.run(helper)

	print("\n" + "=".repeat(80))
	if helper.failures.is_empty():
		print("✓ ALL TESTS PASSED")
		print("=".repeat(80) + "\n")
		quit(0)
	else:
		print("✗ TEST FAILURES (%d)" % helper.failures.size())
		print("=".repeat(80))
		for failure in helper.failures:
			print("  - %s" % failure)
		print()
		quit(1)
