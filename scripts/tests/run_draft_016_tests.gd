## Test runner for DraftHistoryAnalyzer tests (DRAFT-016)
##
## Run with: godot --headless --script scripts/tests/run_draft_016_tests.gd
##
extends SceneTree

const TestDraftHistoryAnalyzer = preload("res://scripts/tests/test_draft_history_analyzer.gd")


func _init() -> void:
	print("\n========================================")
	print("DRAFT-016: Draft History Analyzer Tests")
	print("========================================\n")

	var results := TestDraftHistoryAnalyzer.run_all_tests()

	print("\n========================================")
	if results.failed == 0:
		print("ALL TESTS PASSED")
	else:
		print("TESTS FAILED: %d failures" % results.failed)
	print("========================================\n")

	quit(results.failed)
