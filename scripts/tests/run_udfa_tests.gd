## Test runner for UDFABiddingEngine tests (DRAFT-006)
##
## Run with: godot --headless --script scripts/tests/run_udfa_tests.gd
##
extends SceneTree

const TestUDFABiddingEngine = preload("res://scripts/tests/test_udfa_bidding_engine.gd")


func _init() -> void:
	print("\n========================================")
	print("DRAFT-006: UDFA Bidding Engine Tests")
	print("========================================\n")

	var results := TestUDFABiddingEngine.run_all_tests()

	print("\n========================================")
	if results.failed == 0:
		print("ALL TESTS PASSED")
	else:
		print("TESTS FAILED: %d failures" % results.failed)
	print("========================================\n")

	quit(results.failed)
