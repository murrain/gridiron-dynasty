extends SceneTree
## Test runner for tier-based recruiting system tests
##
## Runs comprehensive test suite for tier config extraction, filtering,
## eval budgets, regional bias, determinism, backward compatibility, and performance.
##
## Usage:
##   godot --headless --script scripts/tests/run_tier_recruiting_tests.gd

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const TestTierRecruiting = preload("res://scripts/tests/test_tier_recruiting.gd")

func _init() -> void:
	print("\n" + "=".repeat(80))
	print("RUNNING TIER-BASED RECRUITING TESTS")
	print("=".repeat(80) + "\n")

	var test := TestTierRecruiting.new()
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
