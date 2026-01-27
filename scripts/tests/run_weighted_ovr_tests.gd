## Test runner for Weighted OVR System tests
##
## Usage: godot --headless --script res://scripts/tests/run_weighted_ovr_tests.gd
##
## Tests the Phase 1 Weighted OVR calculation system:
##   - calculate_weighted_ovr() function
##   - validate_ovr_config() function
##   - Weight inheritance cascade
##   - Feature flag integration

extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")


func _init() -> void:
	print("\n=== Weighted OVR System Tests ===\n")

	var t := TestHelpers.new()

	# Load and run the test suite
	var test_suite := preload("res://scripts/tests/test_weighted_ovr.gd").new()
	test_suite.run(t)

	# Report results
	print("")
	if t.failures.is_empty():
		print("All tests passed!")
	else:
		print("FAILURES:")
		for failure in t.failures:
			print("  - " + failure)
		print("")
		print("%d test(s) failed" % t.failures.size())

	print("\n=== End Weighted OVR Tests ===\n")

	# Exit with appropriate code
	quit(0 if t.failures.is_empty() else 1)
