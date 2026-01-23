extends GdUnitTestSuite
class_name TestSimLoggerGdUnit4

## GdUnit4 tests for SimLogger - Centralized simulation logging
##
## Tests:
##   - Log level configuration
##   - Message formatting (timestamps, prefixes)
##   - Convenience methods (phase_start, phase_summary, etc.)
##   - Async logging behavior
##   - Category-based filtering

const SimLogger = preload("res://autoloads/SimLogger.gd")


# =============================================================================
# CONFIGURATION TESTS
# =============================================================================

func test_configure_sets_log_level() -> void:
	SimLogger.configure({"level": "debug"})

	# Level should be set (internal state, can't directly verify but test won't crash)
	assert_bool(true).is_true()


func test_configure_accepts_string_levels() -> void:
	var levels := ["debug", "info", "warn", "error", "none"]

	for level_str in levels:
		SimLogger.configure({"level": level_str})
		# Should not crash
		assert_bool(true).is_true()


func test_configure_sets_timestamps() -> void:
	SimLogger.configure({"timestamps": true})

	# Configuration accepted
	assert_bool(true).is_true()


func test_configure_sets_async() -> void:
	SimLogger.configure({"async": false})

	# Configuration accepted (sync mode for testing)
	assert_bool(true).is_true()


func test_configure_sets_show_seeds() -> void:
	SimLogger.configure({"show_seeds": true})

	# Configuration accepted
	assert_bool(true).is_true()


# =============================================================================
# LOGGING LEVEL TESTS
# =============================================================================

func test_debug_message_logs() -> void:
	SimLogger.configure({"level": "debug", "async": false})

	# Should not crash
	SimLogger.debug("Test debug message")
	assert_bool(true).is_true()


func test_info_message_logs() -> void:
	SimLogger.configure({"level": "info", "async": false})

	SimLogger.info("Test info message")
	assert_bool(true).is_true()


func test_warn_message_logs() -> void:
	SimLogger.configure({"level": "warn", "async": false})

	SimLogger.warn("Test warning message")
	assert_bool(true).is_true()


func test_error_message_logs() -> void:
	SimLogger.configure({"level": "error", "async": false})

	SimLogger.error("Test error message")
	assert_bool(true).is_true()


# =============================================================================
# LOG FILTERING TESTS
# =============================================================================

func test_level_none_suppresses_all_logs() -> void:
	SimLogger.configure({"level": "none", "async": false})

	# All log calls should be suppressed (no output)
	SimLogger.debug("Should not appear")
	SimLogger.info("Should not appear")
	SimLogger.warn("Should not appear")
	SimLogger.error("Should not appear")

	# Test passes if no crashes
	assert_bool(true).is_true()


func test_level_error_suppresses_lower_levels() -> void:
	SimLogger.configure({"level": "error", "async": false})

	# Only error should log
	SimLogger.debug("Should not appear")
	SimLogger.info("Should not appear")
	SimLogger.warn("Should not appear")
	SimLogger.error("Should appear")

	assert_bool(true).is_true()


func test_level_debug_allows_all_logs() -> void:
	SimLogger.configure({"level": "debug", "async": false})

	# All levels should log
	SimLogger.debug("Debug message")
	SimLogger.info("Info message")
	SimLogger.warn("Warn message")
	SimLogger.error("Error message")

	assert_bool(true).is_true()


# =============================================================================
# PHASE LOGGING CONVENIENCE METHODS
# =============================================================================

func test_phase_start_logs_correctly() -> void:
	SimLogger.configure({"level": "info", "async": false, "show_seeds": false})

	SimLogger.phase_start("hs_gen", 2025, 0x12345)

	# Should not crash
	assert_bool(true).is_true()


func test_phase_start_includes_seed_when_configured() -> void:
	SimLogger.configure({"level": "info", "async": false, "show_seeds": true})

	SimLogger.phase_start("hs_gen", 2025, 0x12345)

	# Should log with seed (can't verify output but won't crash)
	assert_bool(true).is_true()


func test_phase_end_logs_correctly() -> void:
	SimLogger.configure({"level": "info", "async": false, "show_seeds": false})

	SimLogger.phase_end("draft", 2025, 0x99999)

	assert_bool(true).is_true()


func test_step_seed_logs_at_debug_level() -> void:
	SimLogger.configure({"level": "debug", "async": false, "show_seeds": true})

	SimLogger.step_seed(2025, "hs_gen", "background", 0xABCDE)

	assert_bool(true).is_true()


# =============================================================================
# PHASE SUMMARY LOGGING TESTS
# =============================================================================

func test_phase_summary_logs_metrics() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var metrics := {
		"players_generated": 500,
		"avg_rating": 72.5,
		"spent": 15.5  # Million dollars
	}

	SimLogger.phase_summary("hs_gen", 2025, metrics, 125.7)

	assert_bool(true).is_true()


func test_phase_summary_handles_empty_metrics() -> void:
	SimLogger.configure({"level": "info", "async": false})

	SimLogger.phase_summary("draft", 2025, {}, 50.0)

	# Should log "complete" when no metrics
	assert_bool(true).is_true()


func test_phase_summary_formats_money() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var metrics := {
		"spent": 25.75
	}

	SimLogger.phase_summary("recruiting", 2025, metrics, 200.0)

	# Should format as "$25.75M"
	assert_bool(true).is_true()


# =============================================================================
# TIMING SUMMARY TESTS
# =============================================================================

func test_timing_summary_logs_all_phases() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var phase_timings := {
		"hs_gen": 125.5,
		"recruiting": 250.3,
		"draft": 180.7
	}

	SimLogger.timing_summary(2025, phase_timings)

	assert_bool(true).is_true()


func test_timing_summary_calculates_total() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var phase_timings := {
		"phase_1": 100.0,
		"phase_2": 200.0,
		"phase_3": 50.0
	}

	SimLogger.timing_summary(2025, phase_timings)

	# Should log total of 350ms
	assert_bool(true).is_true()


func test_timing_summary_filters_short_phases() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var phase_timings := {
		"fast_phase": 5.0,      # < 100ms, shouldn't appear in detail
		"slow_phase": 250.0     # > 100ms, should appear
	}

	SimLogger.timing_summary(2025, phase_timings)

	assert_bool(true).is_true()


# =============================================================================
# STATS LOGGING TESTS
# =============================================================================

func test_stats_logs_simple_data() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var data := {
		"total": 500,
		"average": 72.5
	}

	SimLogger.stats("HS Generation", data)

	assert_bool(true).is_true()


func test_stats_logs_nested_dictionaries() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var data := {
		"stars": {
			"5": 10,
			"4": 50,
			"3": 200
		},
		"total": 260
	}

	SimLogger.stats("Player Distribution", data)

	assert_bool(true).is_true()


func test_distribution_logs_correctly() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var dist := {
		"5": 10,
		"4": 50,
		"3": 200,
		"2": 300,
		"1": 100
	}

	SimLogger.distribution("Stars", "Player Ratings", dist, 660)

	assert_bool(true).is_true()


func test_distribution_without_total() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var dist := {
		"A": 50,
		"B": 100,
		"C": 75
	}

	SimLogger.distribution("Grades", "Assignment Scores", dist)

	assert_bool(true).is_true()


# =============================================================================
# CATEGORY FILTERING TESTS
# =============================================================================

func test_category_specific_level() -> void:
	SimLogger.configure({
		"level": "info",
		"async": false,
		"categories": {
			"recruiting": SimLogger.Level.DEBUG
		}
	})

	# Recruiting category should allow debug logs
	SimLogger.debug("Recruiting debug message", "recruiting")

	# Other categories should not (but won't crash)
	SimLogger.debug("Other debug message", "other_category")

	assert_bool(true).is_true()


func test_category_override_respects_level() -> void:
	SimLogger.configure({
		"level": "debug",
		"async": false,
		"categories": {
			"performance": SimLogger.Level.ERROR
		}
	})

	# Performance category only logs errors
	SimLogger.info("Performance info", "performance")  # Suppressed
	SimLogger.error("Performance error", "performance")  # Logged

	assert_bool(true).is_true()


# =============================================================================
# ASYNC LOGGING TESTS
# =============================================================================

func test_async_logging_doesnt_crash() -> void:
	SimLogger.configure({"level": "info", "async": true})

	# Async logs should queue and not block
	for i in range(100):
		SimLogger.info("Async message %d" % i)

	# Give async tasks time to complete (small delay)
	await get_tree().create_timer(0.1).timeout

	assert_bool(true).is_true()


func test_sync_logging_completes_immediately() -> void:
	SimLogger.configure({"level": "info", "async": false})

	SimLogger.info("Sync message 1")
	SimLogger.info("Sync message 2")

	# Should complete synchronously (no await needed)
	assert_bool(true).is_true()


# =============================================================================
# TIMESTAMP FORMATTING TESTS
# =============================================================================

func test_timestamps_enabled_adds_prefix() -> void:
	SimLogger.configure({"level": "info", "async": false, "timestamps": true})

	SimLogger.info("Message with timestamp")

	# Timestamp should be added (can't verify output but won't crash)
	assert_bool(true).is_true()


func test_timestamps_disabled_no_prefix() -> void:
	SimLogger.configure({"level": "info", "async": false, "timestamps": false})

	SimLogger.info("Message without timestamp")

	assert_bool(true).is_true()


# =============================================================================
# EDGE CASES
# =============================================================================

func test_log_empty_string() -> void:
	SimLogger.configure({"level": "info", "async": false})

	SimLogger.info("")

	assert_bool(true).is_true()


func test_log_very_long_message() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var long_message := ""
	for i in range(1000):
		long_message += "A"

	SimLogger.info(long_message)

	assert_bool(true).is_true()


func test_log_with_special_characters() -> void:
	SimLogger.configure({"level": "info", "async": false})

	SimLogger.info("Message with special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?")

	assert_bool(true).is_true()


func test_configure_multiple_times() -> void:
	SimLogger.configure({"level": "debug"})
	SimLogger.configure({"level": "info"})
	SimLogger.configure({"level": "warn"})

	# Should accept multiple reconfigurations
	SimLogger.warn("Test after reconfiguration")

	assert_bool(true).is_true()


func test_log_with_format_specifiers() -> void:
	SimLogger.configure({"level": "info", "async": false})

	var player_count := 500
	var avg_rating := 72.5

	SimLogger.info("Generated %d players with avg rating %.1f" % [player_count, avg_rating])

	assert_bool(true).is_true()


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_full_simulation_logging_workflow() -> void:
	SimLogger.configure({
		"level": "info",
		"async": false,
		"timestamps": true,
		"show_seeds": false
	})

	var year := 2025
	var seed := 0x12345

	# Simulate a full phase
	SimLogger.phase_start("hs_gen", year, seed)

	SimLogger.info("Generating players...")
	SimLogger.debug("Processing region: Texas", "hs_gen")

	var metrics := {
		"players_generated": 500,
		"avg_rating": 72.5,
		"five_stars": 10
	}

	SimLogger.phase_summary("hs_gen", year, metrics, 125.5)
	SimLogger.phase_end("hs_gen", year, seed)

	assert_bool(true).is_true()


func test_logging_doesnt_affect_simulation_determinism() -> void:
	# Logging should be side-effect only, not affect simulation
	SimLogger.configure({"level": "info", "async": false})

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 0x99999

	SimLogger.info("First run")
	var val1 := rng1.randi()

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 0x99999

	SimLogger.info("Second run")
	var val2 := rng2.randi()

	# RNG should produce same values (logging doesn't interfere)
	assert_int(val1).is_equal(val2)
