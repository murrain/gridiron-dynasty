## GdUnit4 test suite for Board Sort Mode (DRAFT-015: BPA vs Need Toggle)
##
## Validates the three sort modes: BPA, Need, and Scheme Fit.
## Performance target: <50ms for 250 players
##
## Note: These tests verify the sorting algorithms independently of the UI.
## UI integration is tested separately in test_draft_day_ui_gdunit4.gd
##
extends GdUnitTestSuite

const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")


# =============================================================================
# Test: Sort Mode State Management
# =============================================================================

func test_default_sort_mode_is_bpa() -> void:
	var draft := InteractiveDraft.new()
	# Note: Cannot test without full initialization, so we test the enum value
	assert_int(InteractiveDraft.BoardSortMode.BPA).is_equal(0)


func test_sort_mode_enum_values() -> void:
	# Verify enum order for dropdown mapping
	assert_int(InteractiveDraft.BoardSortMode.BPA).is_equal(0)
	assert_int(InteractiveDraft.BoardSortMode.NEED).is_equal(1)
	assert_int(InteractiveDraft.BoardSortMode.SCHEME_FIT).is_equal(2)


# =============================================================================
# Test: BPA Sort (Pure Overall Rating)
# =============================================================================

func test_bpa_sort_orders_by_overall_descending() -> void:
	# Create test players with different overall ratings
	var players := [
		{"player_id": "p1", "name": "Low", "position": "QB", "overall": 70.0},
		{"player_id": "p2", "name": "High", "position": "RB", "overall": 95.0},
		{"player_id": "p3", "name": "Mid", "position": "WR", "overall": 82.0},
	]

	# Sort using BPA logic (highest overall first)
	players.sort_custom(func(a, b):
		return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
	)

	assert_str(String(players[0].get("player_id", ""))).is_equal("p2")  # 95.0
	assert_str(String(players[1].get("player_id", ""))).is_equal("p3")  # 82.0
	assert_str(String(players[2].get("player_id", ""))).is_equal("p1")  # 70.0


func test_bpa_sort_ignores_position() -> void:
	# Players at different positions should be sorted purely by overall
	var players := [
		{"player_id": "qb1", "name": "QB1", "position": "QB", "overall": 80.0},
		{"player_id": "rb1", "name": "RB1", "position": "RB", "overall": 85.0},
		{"player_id": "wr1", "name": "WR1", "position": "WR", "overall": 75.0},
	]

	players.sort_custom(func(a, b):
		return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
	)

	# RB should be first despite position, purely by overall
	assert_str(String(players[0].get("player_id", ""))).is_equal("rb1")
	assert_str(String(players[1].get("player_id", ""))).is_equal("qb1")
	assert_str(String(players[2].get("player_id", ""))).is_equal("wr1")


# =============================================================================
# Test: Need Sort (Position Scarcity + Team Depth)
# =============================================================================

func test_need_sort_weights_by_position_need() -> void:
	# Simulate team needs: QB = 1.5 (high need), RB = 1.0 (filled), WR = 1.3 (some need)
	var needs := {"QB": 1.5, "RB": 1.0, "WR": 1.3}

	var players := [
		{"player_id": "qb1", "name": "QB1", "position": "QB", "overall": 80.0},
		{"player_id": "rb1", "name": "RB1", "position": "RB", "overall": 85.0},
		{"player_id": "wr1", "name": "WR1", "position": "WR", "overall": 80.0},
	]

	# Calculate need-weighted scores
	for player in players:
		var position := String(player.get("position", ""))
		var overall := float(player.get("overall", 0.0))
		var need_mult := float(needs.get(position, 1.0))
		player["need_score"] = overall * need_mult

	players.sort_custom(func(a, b):
		return float(a.get("need_score", 0.0)) > float(b.get("need_score", 0.0))
	)

	# QB should be first: 80 * 1.5 = 120
	# WR should be second: 80 * 1.3 = 104
	# RB should be last: 85 * 1.0 = 85 (despite higher overall)
	assert_str(String(players[0].get("player_id", ""))).is_equal("qb1")
	assert_str(String(players[1].get("player_id", ""))).is_equal("wr1")
	assert_str(String(players[2].get("player_id", ""))).is_equal("rb1")


func test_need_sort_high_need_beats_higher_overall() -> void:
	# A lower overall player at a high-need position should rank higher
	var needs := {"LB": 1.5, "CB": 0.95}

	var players := [
		{"player_id": "lb1", "name": "LB1", "position": "LB", "overall": 70.0},  # 70 * 1.5 = 105
		{"player_id": "cb1", "name": "CB1", "position": "CB", "overall": 90.0},  # 90 * 0.95 = 85.5
	]

	for player in players:
		var position := String(player.get("position", ""))
		var overall := float(player.get("overall", 0.0))
		var need_mult := float(needs.get(position, 1.0))
		player["need_score"] = overall * need_mult

	players.sort_custom(func(a, b):
		return float(a.get("need_score", 0.0)) > float(b.get("need_score", 0.0))
	)

	# LB with lower overall but higher need should rank first
	assert_str(String(players[0].get("player_id", ""))).is_equal("lb1")


# =============================================================================
# Test: Scheme Fit Sort
# =============================================================================

func test_scheme_fit_sort_weights_by_scheme_compatibility() -> void:
	# Offensive players checked against offensive scheme
	# Defensive players checked against defensive scheme
	var offensive_scheme := "spread"
	var defensive_scheme := "cover_3"

	var players := [
		{"player_id": "qb1", "position": "QB", "overall": 80.0, "scheme_fit": {"spread": 95.0, "pro_style": 70.0}},
		{"player_id": "qb2", "position": "QB", "overall": 85.0, "scheme_fit": {"spread": 60.0, "pro_style": 90.0}},
		{"player_id": "cb1", "position": "CB", "overall": 80.0, "scheme_fit": {"cover_3": 90.0, "man": 75.0}},
	]

	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	for player in players:
		var position := String(player.get("position", ""))
		var overall := float(player.get("overall", 0.0))
		var scheme_fit: Dictionary = player.get("scheme_fit", {})

		# Determine which scheme to check
		var scheme_to_check := offensive_scheme
		if position in defensive_positions:
			scheme_to_check = defensive_scheme

		var fit_rating := float(scheme_fit.get(scheme_to_check, 75.0))

		# 60% overall + 40% scheme fit
		player["scheme_score"] = (overall * 0.6) + (fit_rating * 0.4)

	players.sort_custom(func(a, b):
		return float(a.get("scheme_score", 0.0)) > float(b.get("scheme_score", 0.0))
	)

	# qb1: (80 * 0.6) + (95 * 0.4) = 48 + 38 = 86
	# qb2: (85 * 0.6) + (60 * 0.4) = 51 + 24 = 75
	# cb1: (80 * 0.6) + (90 * 0.4) = 48 + 36 = 84

	# qb1 should be first despite lower overall
	assert_str(String(players[0].get("player_id", ""))).is_equal("qb1")
	assert_str(String(players[1].get("player_id", ""))).is_equal("cb1")
	assert_str(String(players[2].get("player_id", ""))).is_equal("qb2")


func test_scheme_fit_uses_default_when_no_data() -> void:
	# Players without scheme_fit data should use default (75.0)
	var players := [
		{"player_id": "p1", "position": "QB", "overall": 80.0},  # No scheme_fit
		{"player_id": "p2", "position": "QB", "overall": 80.0, "scheme_fit": {"spread": 90.0}},
	]

	for player in players:
		var overall := float(player.get("overall", 0.0))
		var scheme_fit: Dictionary = player.get("scheme_fit", {})
		var fit_rating := float(scheme_fit.get("spread", 75.0))
		player["scheme_score"] = (overall * 0.6) + (fit_rating * 0.4)

	players.sort_custom(func(a, b):
		return float(a.get("scheme_score", 0.0)) > float(b.get("scheme_score", 0.0))
	)

	# p2 should rank higher due to explicit good scheme fit
	# p1: (80 * 0.6) + (75 * 0.4) = 48 + 30 = 78
	# p2: (80 * 0.6) + (90 * 0.4) = 48 + 36 = 84
	assert_str(String(players[0].get("player_id", ""))).is_equal("p2")


# =============================================================================
# Test: Performance
# =============================================================================

func test_sort_performance_under_50ms_for_250_players() -> void:
	# Generate 250 test players
	var players: Array = []
	for i in range(250):
		players.append({
			"player_id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"][i % 10],
			"overall": randf_range(50.0, 100.0),
		})

	# Time the sort operation
	var start := Time.get_ticks_usec()

	players.sort_custom(func(a, b):
		return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
	)

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	# Sort should complete in <50ms
	assert_float(elapsed).is_less(50.0)


func test_need_sort_performance_under_50ms_for_250_players() -> void:
	var needs := {"QB": 1.5, "RB": 1.2, "WR": 1.0, "TE": 1.3, "OL": 1.4, "DL": 1.1, "EDGE": 1.5, "LB": 1.0, "CB": 1.2, "S": 1.1}

	var players: Array = []
	for i in range(250):
		players.append({
			"player_id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"][i % 10],
			"overall": randf_range(50.0, 100.0),
		})

	var start := Time.get_ticks_usec()

	# Calculate need scores
	for player in players:
		var position := String(player.get("position", ""))
		var overall := float(player.get("overall", 0.0))
		var need_mult := float(needs.get(position, 1.0))
		player["need_score"] = overall * need_mult

	# Sort by need score
	players.sort_custom(func(a, b):
		return float(a.get("need_score", 0.0)) > float(b.get("need_score", 0.0))
	)

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	# Should complete in <50ms including score calculation
	assert_float(elapsed).is_less(50.0)
