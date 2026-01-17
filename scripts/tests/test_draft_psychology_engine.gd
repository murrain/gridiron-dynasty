## Test suite for DraftPsychologyEngine
##
## Tests run detection, urgency calculation, panic modes, and cooldown behavior.
## All tests verify determinism (no RNG in the psychology engine).
##
## Coverage: 16 tests
##   - Run detection: 5 tests
##   - Urgency calculation: 5 tests
##   - Panic trade logic: 3 tests
##   - Cooldown behavior: 2 tests
##   - Determinism verification: 1 test
##
extends RefCounted

const DraftPsychologyEngine = preload("res://scripts/world/DraftPsychologyEngine.gd")


func run(t) -> void:
	# Run detection tests
	_test_record_pick_adds_to_tracking(t)
	_test_run_detection_false_below_threshold(t)
	_test_run_detection_true_at_threshold(t)
	_test_run_detection_respects_window(t)
	_test_multiple_positions_tracked_independently(t)

	# Urgency calculation tests
	_test_urgency_baseline_no_run(t)
	_test_urgency_panic_mode_few_remaining(t)
	_test_urgency_elevated_mode(t)
	_test_urgency_no_urgency_without_need(t)
	_test_urgency_scales_with_need_level(t)

	# Panic trade tests
	_test_panic_trade_requires_all_conditions(t)
	_test_panic_trade_false_without_capital(t)
	_test_panic_trade_false_without_high_need(t)

	# Cooldown tests
	_test_cooldown_reduces_urgency(t)
	_test_run_cooldown_signal_emitted(t)

	# Determinism test
	_test_determinism_same_inputs_same_outputs(t)


## Test: Recording a pick adds it to position tracking
func _test_record_pick_adds_to_tracking(t) -> void:
	var engine := DraftPsychologyEngine.new()

	engine.record_pick("QB", 1, "team1")
	engine.record_pick("QB", 3, "team2")
	engine.record_pick("WR", 2, "team3")

	var debug := engine.get_debug_state()
	var qb_picks: Array = debug["position_picks"].get("QB", [])
	var wr_picks: Array = debug["position_picks"].get("WR", [])

	t.assert_eq(qb_picks.size(), 2, "Should have 2 QB picks tracked")
	t.assert_true(1 in qb_picks, "Pick 1 should be in QB tracking")
	t.assert_true(3 in qb_picks, "Pick 3 should be in QB tracking")
	t.assert_eq(wr_picks.size(), 1, "Should have 1 WR pick tracked")


## Test: Run detection returns false when below threshold
func _test_run_detection_false_below_threshold(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Only 2 QB picks (threshold is 3)
	engine.record_pick("QB", 1, "team1")
	engine.record_pick("QB", 3, "team2")

	t.assert_false(
		engine.is_position_run_active("QB", 5),
		"2 picks should not trigger run (threshold is 3)"
	)


## Test: Run detection returns true at threshold
func _test_run_detection_true_at_threshold(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# 3 QB picks within window (threshold is 3)
	engine.record_pick("QB", 1, "team1")
	engine.record_pick("QB", 2, "team2")
	engine.record_pick("QB", 4, "team3")

	t.assert_true(
		engine.is_position_run_active("QB", 5),
		"3 picks should trigger run at threshold"
	)


## Test: Run detection respects the pick window
func _test_run_detection_respects_window(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# 3 QB picks but spread out (picks 1, 3, 15)
	engine.record_pick("QB", 1, "team1")
	engine.record_pick("QB", 3, "team2")
	engine.record_pick("QB", 15, "team3")

	# At pick 16, only pick 15 is in window (window = 5)
	t.assert_false(
		engine.is_position_run_active("QB", 16),
		"Picks outside window should not count toward run"
	)

	# At pick 6, picks 1, 3 are in window
	var recent := engine.get_recent_picks_at_position("QB", 6)
	t.assert_eq(recent.size(), 2, "Only picks within window should be counted")


## Test: Multiple positions tracked independently
func _test_multiple_positions_tracked_independently(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create run at QB but not WR
	engine.record_pick("QB", 1, "team1")
	engine.record_pick("WR", 2, "team2")
	engine.record_pick("QB", 3, "team3")
	engine.record_pick("WR", 4, "team4")
	engine.record_pick("QB", 5, "team5")

	t.assert_true(
		engine.is_position_run_active("QB", 6),
		"QB should have active run (3 picks in window)"
	)
	t.assert_false(
		engine.is_position_run_active("WR", 6),
		"WR should not have active run (only 2 picks)"
	)


## Test: Urgency multiplier is baseline when no run is active
func _test_urgency_baseline_no_run(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# No picks recorded = no runs
	var needs := {"QB": 1.5}  # High need
	var urgency := engine.get_urgency_multiplier("team1", "QB", 10, 10, needs)

	t.assert_eq(urgency, 1.0, "No run = baseline multiplier of 1.0")


## Test: Urgency multiplier reaches panic mode with few remaining
func _test_urgency_panic_mode_few_remaining(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create active run
	engine.record_pick("QB", 1, "team1")
	engine.record_pick("QB", 2, "team2")
	engine.record_pick("QB", 4, "team3")

	var needs := {"QB": 1.3}  # High need
	# 2 remaining = panic mode
	var urgency := engine.get_urgency_multiplier("team4", "QB", 5, 2, needs)

	t.assert_gt(urgency, 1.5, "Panic mode should have high urgency multiplier")


## Test: Urgency multiplier elevated mode
func _test_urgency_elevated_mode(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create active run
	engine.record_pick("CB", 1, "team1")
	engine.record_pick("CB", 2, "team2")
	engine.record_pick("CB", 3, "team3")

	var needs := {"CB": 1.2}
	# 4 remaining = elevated (between panic and mild)
	var urgency := engine.get_urgency_multiplier("team4", "CB", 5, 4, needs)

	t.assert_gt(urgency, 1.0, "Elevated mode should have multiplier > 1.0")
	t.assert_lt(urgency, 2.5, "Elevated mode should be less than panic mode")


## Test: No urgency applied when team has no need at position
func _test_urgency_no_urgency_without_need(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create active run
	engine.record_pick("QB", 1, "team1")
	engine.record_pick("QB", 2, "team2")
	engine.record_pick("QB", 3, "team3")

	# Low need (below threshold of 1.1)
	var needs := {"QB": 0.95}
	var urgency := engine.get_urgency_multiplier("team4", "QB", 5, 2, needs)

	t.assert_eq(urgency, 1.0, "Team without need should have baseline multiplier")


## Test: Urgency scales with team need level
func _test_urgency_scales_with_need_level(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create active run
	engine.record_pick("RB", 1, "team1")
	engine.record_pick("RB", 2, "team2")
	engine.record_pick("RB", 3, "team3")

	var low_need := {"RB": 1.15}
	var high_need := {"RB": 1.45}

	var urgency_low := engine.get_urgency_multiplier("team4", "RB", 5, 3, low_need)
	var urgency_high := engine.get_urgency_multiplier("team5", "RB", 5, 3, high_need)

	t.assert_gt(urgency_high, urgency_low, "Higher need should produce higher urgency")


## Test: Panic trade requires all conditions to be true
func _test_panic_trade_requires_all_conditions(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create active run
	engine.record_pick("WR", 1, "team1")
	engine.record_pick("WR", 2, "team2")
	engine.record_pick("WR", 3, "team3")

	var needs := {"WR": 1.4}  # High need

	# All conditions met: run active, high need, few remaining, has capital
	var should_trade := engine.should_team_panic_trade(
		"team4", "WR", 5, 2, needs, 5
	)
	t.assert_true(should_trade, "All conditions met should trigger panic trade")


## Test: Panic trade false without draft capital
func _test_panic_trade_false_without_capital(t) -> void:
	var engine := DraftPsychologyEngine.new()

	engine.record_pick("WR", 1, "team1")
	engine.record_pick("WR", 2, "team2")
	engine.record_pick("WR", 3, "team3")

	var needs := {"WR": 1.4}

	# Only 1 pick = not enough capital
	var should_trade := engine.should_team_panic_trade(
		"team4", "WR", 5, 2, needs, 1
	)
	t.assert_false(should_trade, "Without draft capital should not trigger panic trade")


## Test: Panic trade false without high need
func _test_panic_trade_false_without_high_need(t) -> void:
	var engine := DraftPsychologyEngine.new()

	engine.record_pick("TE", 1, "team1")
	engine.record_pick("TE", 2, "team2")
	engine.record_pick("TE", 3, "team3")

	var needs := {"TE": 1.2}  # Need below HIGH_NEED_THRESHOLD of 1.3

	var should_trade := engine.should_team_panic_trade(
		"team4", "TE", 5, 2, needs, 5
	)
	t.assert_false(should_trade, "Without high need should not trigger panic trade")


## Test: Cooldown reduces urgency after saturation
func _test_cooldown_reduces_urgency(t) -> void:
	var engine := DraftPsychologyEngine.new()

	# Create a long run (past cooldown threshold of 6)
	for i in range(7):
		engine.record_pick("CB", i + 1, "team%d" % (i + 1))

	var needs := {"CB": 1.3}

	# Get urgency at pick 8 (7 CB picks in window = past cooldown)
	var urgency := engine.get_urgency_multiplier("team8", "CB", 8, 2, needs)

	# Create fresh run for comparison
	var engine2 := DraftPsychologyEngine.new()
	for i in range(3):
		engine2.record_pick("CB", i + 1, "team%d" % (i + 1))

	var urgency_fresh := engine2.get_urgency_multiplier("team4", "CB", 4, 2, needs)

	t.assert_lt(urgency, urgency_fresh, "Cooldown should reduce urgency compared to fresh run")


## Test: Run cooldown signal is emitted
func _test_run_cooldown_signal_emitted(t) -> void:
	var engine := DraftPsychologyEngine.new()
	var cooldown_emitted := false
	var cooldown_position := ""

	engine.run_cooled_down.connect(func(pos: String):
		cooldown_emitted = true
		cooldown_position = pos
	)

	# Create a run that reaches cooldown threshold (6 picks)
	for i in range(DraftPsychologyEngine.RUN_COOLDOWN_PICKS):
		engine.record_pick("OL", i + 1, "team%d" % (i + 1))

	t.assert_true(cooldown_emitted, "Cooldown signal should be emitted at threshold")
	t.assert_eq(cooldown_position, "OL", "Cooldown should be for correct position")


## Test: Determinism - same inputs always produce same outputs
func _test_determinism_same_inputs_same_outputs(t) -> void:
	# Run the same sequence multiple times and verify identical results
	var results := []

	for iteration in range(3):
		var engine := DraftPsychologyEngine.new()

		# Same pick sequence
		engine.record_pick("QB", 1, "team1")
		engine.record_pick("CB", 2, "team2")
		engine.record_pick("QB", 3, "team3")
		engine.record_pick("QB", 4, "team4")
		engine.record_pick("CB", 5, "team5")

		var needs := {"QB": 1.35, "CB": 1.2}

		var qb_urgency := engine.get_urgency_multiplier("test", "QB", 6, 3, needs)
		var cb_urgency := engine.get_urgency_multiplier("test", "CB", 6, 4, needs)
		var qb_run := engine.is_position_run_active("QB", 6)
		var cb_run := engine.is_position_run_active("CB", 6)
		var active_runs := engine.get_active_runs(6)

		results.append({
			"qb_urgency": qb_urgency,
			"cb_urgency": cb_urgency,
			"qb_run": qb_run,
			"cb_run": cb_run,
			"active_runs_count": active_runs.size()
		})

	# All iterations should be identical
	t.assert_eq(
		results[0]["qb_urgency"],
		results[1]["qb_urgency"],
		"QB urgency should be deterministic (iter 0 vs 1)"
	)
	t.assert_eq(
		results[1]["qb_urgency"],
		results[2]["qb_urgency"],
		"QB urgency should be deterministic (iter 1 vs 2)"
	)
	t.assert_eq(
		results[0]["cb_urgency"],
		results[1]["cb_urgency"],
		"CB urgency should be deterministic"
	)
	t.assert_eq(
		results[0]["qb_run"],
		results[1]["qb_run"],
		"QB run detection should be deterministic"
	)
	t.assert_eq(
		results[0]["active_runs_count"],
		results[1]["active_runs_count"],
		"Active runs count should be deterministic"
	)
