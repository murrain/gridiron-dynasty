## Test runner for DRAFT-002 (Underclassman Entry System)
##
## Runs all 23 tests for DRAFT-002:
##   - 8 tests: test_player_eligibility.gd
##   - 7 tests: test_draft_decision_engine.gd
##   - 8 tests: test_underclassman_integration.gd (5 integration + 3 determinism)
##
## Usage: godot --headless --script res://scripts/tests/run_draft_002_tests.gd

extends SceneTree

const TestRunner = preload("res://scripts/tests/TestRunner.gd")
const PlayerEligibilityTests = preload("res://scripts/tests/core/models/test_player_eligibility.gd")
const DraftDecisionEngineTests = preload("res://scripts/tests/world/test_draft_decision_engine.gd")
const UnderclassmanIntegrationTests = preload("res://scripts/tests/test_underclassman_integration.gd")


func _init() -> void:
	var runner = TestRunner.new()

	print("\n========================================")
	print("DRAFT-002: Underclassman Entry System Tests")
	print("========================================\n")

	print("--- Player Eligibility Tests (8 tests) ---")
	PlayerEligibilityTests.new().run(runner)

	print("\n--- Draft Decision Engine Tests (7 tests) ---")
	DraftDecisionEngineTests.new().run(runner)

	print("\n--- Integration & Determinism Tests (8 tests) ---")
	UnderclassmanIntegrationTests.new().run(runner)

	print("\n========================================")
	runner.summary()
	print("========================================\n")

	var exit_code = 0 if runner.all_passed() else 1
	quit(exit_code)
