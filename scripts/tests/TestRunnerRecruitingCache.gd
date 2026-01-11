## Test runner for RecruitingScoreCache tests
##
## Usage:
##   godot --headless -s res://scripts/tests/TestRunnerRecruitingCache.gd
extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const RecruitingScoreCacheTest = preload("res://scripts/tests/test_recruiting_score_cache.gd")

func _init() -> void:
	print("=" .repeat(80))
	print("Running RecruitingScoreCache Tests (Task P2)")
	print("=" .repeat(80))

	var helper := TestHelpers.new()
	var test := RecruitingScoreCacheTest.new()

	var start_time := Time.get_ticks_msec()
	test.run(helper)
	var elapsed := Time.get_ticks_msec() - start_time

	print("\n" + "=" .repeat(80))
	print("Test Results:")
	print("  Failures: %d" % helper.failures.size())
	print("  Time: %.2fs" % (elapsed / 1000.0))
	print("=" .repeat(80))

	if helper.failures.is_empty():
		print("\nALL TESTS PASSED!")
		quit(0)
	else:
		print("\nFAILURES:")
		for failure in helper.failures:
			print("  - %s" % failure)
		quit(1)
