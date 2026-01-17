## Test runner for RookieWageScale tests (DRAFT-013)
##
## Run with: godot --headless --script scripts/tests/run_wage_scale_tests.gd
##
extends SceneTree

const TestRookieWageScale = preload("res://scripts/tests/test_rookie_wage_scale.gd")


func _init() -> void:
	print("\n========================================")
	print("DRAFT-013: Rookie Wage Scale Tests")
	print("========================================\n")

	var results := TestRookieWageScale.run_all_tests()

	print("\n========================================")
	if results.failed == 0:
		print("ALL TESTS PASSED")
	else:
		print("TESTS FAILED: %d failures" % results.failed)
	print("========================================\n")

	quit(results.failed)
