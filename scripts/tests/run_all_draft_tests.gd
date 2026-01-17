## Test runner for DRAFT-001 and DRAFT-002 combined
##
## Runs all 46 tests total:
##
## DRAFT-002 (Underclassman Entry): 23 tests
##   - 8 tests: test_player_eligibility.gd
##   - 7 tests: test_draft_decision_engine.gd
##   - 8 tests: test_underclassman_integration.gd
##
## DRAFT-001 (Draft Trading): 23 tests
##   - 11 tests: test_draft_trade_engine.gd
##   - 12 tests: test_draft_trading_integration.gd
##
## Usage: godot --headless --script res://scripts/tests/run_all_draft_tests.gd

extends SceneTree

const TestRunner = preload("res://scripts/tests/TestRunner.gd")

# DRAFT-002 tests
const PlayerEligibilityTests = preload("res://scripts/tests/core/models/test_player_eligibility.gd")
const DraftDecisionEngineTests = preload("res://scripts/tests/world/test_draft_decision_engine.gd")
const UnderclassmanIntegrationTests = preload("res://scripts/tests/test_underclassman_integration.gd")

# DRAFT-001 tests
const DraftTradeEngineTests = preload("res://scripts/tests/world/test_draft_trade_engine.gd")
const DraftTradingIntegrationTests = preload("res://scripts/tests/test_draft_trading_integration.gd")


func _init() -> void:
	var runner = TestRunner.new()

	print("\n========================================")
	print("DRAFT SYSTEM COMPLETE TEST SUITE")
	print("DRAFT-001 (Trading) + DRAFT-002 (Underclassman)")
	print("========================================\n")

	# DRAFT-002 Tests
	print("=== DRAFT-002: Underclassman Entry System ===\n")

	print("--- Player Eligibility Tests (8 tests) ---")
	PlayerEligibilityTests.new().run(runner)

	print("\n--- Draft Decision Engine Tests (7 tests) ---")
	DraftDecisionEngineTests.new().run(runner)

	print("\n--- Underclassman Integration Tests (8 tests) ---")
	UnderclassmanIntegrationTests.new().run(runner)

	# DRAFT-001 Tests
	print("\n=== DRAFT-001: Draft Day Trading ===\n")

	print("--- Draft Trade Engine Unit Tests (11 tests) ---")
	DraftTradeEngineTests.new().run(runner)

	print("\n--- Trading Integration & Performance Tests (12 tests) ---")
	DraftTradingIntegrationTests.new().run(runner)

	print("\n========================================")
	print("COMPLETE DRAFT SYSTEM TEST RESULTS")
	print("========================================")
	runner.summary()
	print("========================================\n")

	var exit_code = 0 if runner.all_passed() else 1
	quit(exit_code)
