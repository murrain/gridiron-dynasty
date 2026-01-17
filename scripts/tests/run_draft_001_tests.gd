## Test runner for DRAFT-001 (Draft Day Trading)
##
## Runs all 23 tests for DRAFT-001:
##   - 11 tests: test_draft_trade_engine.gd (unit tests)
##   - 12 tests: test_draft_trading_integration.gd (5 integration + 3 determinism + 4 performance)
##
## Usage: godot --headless --script res://scripts/tests/run_draft_001_tests.gd

extends SceneTree

const TestRunner = preload("res://scripts/tests/TestRunner.gd")
const DraftTradeEngineTests = preload("res://scripts/tests/world/test_draft_trade_engine.gd")
const DraftTradingIntegrationTests = preload("res://scripts/tests/test_draft_trading_integration.gd")


func _init() -> void:
	var runner = TestRunner.new()

	print("\n========================================")
	print("DRAFT-001: Draft Day Trading Tests")
	print("========================================\n")

	print("--- Draft Trade Engine Unit Tests (11 tests) ---")
	DraftTradeEngineTests.new().run(runner)

	print("\n--- Integration, Determinism & Performance Tests (12 tests) ---")
	DraftTradingIntegrationTests.new().run(runner)

	print("\n========================================")
	runner.summary()
	print("========================================\n")

	var exit_code = 0 if runner.all_passed() else 1
	quit(exit_code)
