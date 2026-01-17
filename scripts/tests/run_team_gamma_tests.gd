## Combined test runner for Team Gamma features (DRAFT-013, DRAFT-006, DRAFT-016)
##
## Run with: godot --headless --script scripts/tests/run_team_gamma_tests.gd
##
## Features tested:
## - DRAFT-013: Rookie Wage Scale (6 tests)
## - DRAFT-006: UDFA Bidding Engine (12 tests)
## - DRAFT-016: Draft History Analyzer (10 tests)
## Total: 28 tests
##
extends SceneTree

const TestRookieWageScale = preload("res://scripts/tests/test_rookie_wage_scale.gd")
const TestUDFABiddingEngine = preload("res://scripts/tests/test_udfa_bidding_engine.gd")
const TestDraftHistoryAnalyzer = preload("res://scripts/tests/test_draft_history_analyzer.gd")


func _init() -> void:
	print("\n" + "=".repeat(60))
	print("TEAM GAMMA: Post-Draft & Advanced Features Test Suite")
	print("=".repeat(60))

	var total_passed := 0
	var total_failed := 0

	# DRAFT-013: Rookie Wage Scale
	print("\n" + "-".repeat(40))
	print("DRAFT-013: Rookie Wage Scale")
	print("-".repeat(40))
	var wage_results := TestRookieWageScale.run_all_tests()
	total_passed += wage_results.passed
	total_failed += wage_results.failed

	# DRAFT-006: UDFA Bidding Engine
	print("\n" + "-".repeat(40))
	print("DRAFT-006: UDFA Bidding Engine")
	print("-".repeat(40))
	var udfa_results := TestUDFABiddingEngine.run_all_tests()
	total_passed += udfa_results.passed
	total_failed += udfa_results.failed

	# DRAFT-016: Draft History Analyzer
	print("\n" + "-".repeat(40))
	print("DRAFT-016: Draft History Analyzer")
	print("-".repeat(40))
	var history_results := TestDraftHistoryAnalyzer.run_all_tests()
	total_passed += history_results.passed
	total_failed += history_results.failed

	# Summary
	print("\n" + "=".repeat(60))
	print("TEAM GAMMA TEST SUMMARY")
	print("=".repeat(60))
	print("DRAFT-013 (Wage Scale): %d passed, %d failed" % [wage_results.passed, wage_results.failed])
	print("DRAFT-006 (UDFA):       %d passed, %d failed" % [udfa_results.passed, udfa_results.failed])
	print("DRAFT-016 (History):    %d passed, %d failed" % [history_results.passed, history_results.failed])
	print("-".repeat(40))
	print("TOTAL: %d passed, %d failed" % [total_passed, total_failed])

	if total_failed == 0:
		print("\nALL 28 TESTS PASSED - READY FOR MERGE")
	else:
		print("\n%d TESTS FAILED - REVIEW REQUIRED" % total_failed)

	print("=".repeat(60))

	quit(total_failed)
