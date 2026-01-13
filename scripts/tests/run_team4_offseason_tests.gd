extends SceneTree

## Test runner for Team 4 Offseason & Transactions features
##
## Runs all unit tests for Features 4-5:
##   - Feature 4: Compensatory Picks
##   - Feature 5: Draft Pick Trading
##
## Usage:
##   godot --headless --script scripts/tests/run_team4_offseason_tests.gd

const TestDraftPickTrading = preload("res://scripts/tests/test_draft_pick_trading.gd")
const TestCompensatoryPicks = preload("res://scripts/tests/test_compensatory_picks.gd")

func _init() -> void:
	print("\n" + "=" * 80)
	print("Team 4: Offseason & Transactions - Unit Test Suite")
	print("=" * 80 + "\n")

	var all_passed := true

	# Run Feature 5 tests
	print("Running Feature 5: Draft Pick Trading Tests")
	print("-" * 80)
	var pick_trading_results := TestDraftPickTrading.run_all_tests()
	_print_test_results(pick_trading_results)
	if pick_trading_results.get("failed", 0) > 0:
		all_passed = false

	print("\n")

	# Run Feature 4 tests
	print("Running Feature 4: Compensatory Picks Tests")
	print("-" * 80)
	var comp_picks_results := TestCompensatoryPicks.run_all_tests()
	_print_test_results(comp_picks_results)
	if comp_picks_results.get("failed", 0) > 0:
		all_passed = false

	print("\n" + "=" * 80)
	if all_passed:
		print("SUCCESS: All tests passed!")
		print("=" * 80 + "\n")
		quit(0)
	else:
		print("FAILURE: Some tests failed. See above for details.")
		print("=" * 80 + "\n")
		quit(1)


func _print_test_results(results: Dictionary) -> void:
	var total := int(results.get("total", 0))
	var passed := int(results.get("passed", 0))
	var failed := int(results.get("failed", 0))

	print("Total: %d | Passed: %d | Failed: %d" % [total, passed, failed])

	if failed > 0:
		print("\nFailed tests:")
		var test_results: Array = results.get("results", [])
		for result in test_results:
			var r: Dictionary = result as Dictionary
			if not r.get("passed", false):
				print("  - %s" % r.get("message", "Unknown test"))
