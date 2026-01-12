extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestDraftFixes = preload("res://scripts/tests/test_draft_fixes.gd")

func _init() -> void:
	print("=== Draft Fixes Test Suite ===\n")

	var test = TestDraftFixes.new()
	var helper = TestHelpers.new()
	test.run(helper)

	if helper.failures.is_empty():
		print("\n=== All Tests Passed ===")
		quit(0)
	else:
		print("\n=== FAILURES (%d) ===" % helper.failures.size())
		for failure in helper.failures:
			print("  ✗ %s" % failure)
		quit(1)
