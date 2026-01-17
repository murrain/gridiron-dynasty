## GdUnit4 performance tests for Draft Phase 2 features
##
## Tests performance requirements:
## - Board sort <50ms with 250 players
## - Shortlist lookup <5ms for 1000 lookups
## - Trade calculator <16ms for value update
##
extends GdUnitTestSuite

const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const PlayerShortlist = preload("res://scripts/core/models/PlayerShortlist.gd")
const TradeValueCalculator = preload("res://scenes/ui/draft_day/TradeValueCalculator.gd")


# =============================================================================
# Test: Board Sort Performance <50ms with 250 Players
# =============================================================================

func test_board_sort_under_50ms_with_250_players() -> void:
	var world_state := _create_large_world_state(250)
	var draft := InteractiveDraft.new()

	draft.initialize(
		world_state,
		2026,
		12345,
		"team_phi",
		_get_league_cfg(),
		_get_positions_cfg(),
		{},
		_get_scouts_cfg(),
		_get_main_cfg()
	)

	# Warm up
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
	var _warmup := draft.get_sorted_available_players()

	# Measure BPA sort
	var start := Time.get_ticks_usec()
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
	var _bpa_result := draft.get_sorted_available_players()
	var elapsed_bpa := (Time.get_ticks_usec() - start) / 1000.0

	assert_float(elapsed_bpa).is_less(50.0)
	print("[PERF] BPA sort with 250 players: %.2f ms" % elapsed_bpa)

	# Measure NEED sort
	start = Time.get_ticks_usec()
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.NEED)
	var _need_result := draft.get_sorted_available_players()
	var elapsed_need := (Time.get_ticks_usec() - start) / 1000.0

	assert_float(elapsed_need).is_less(50.0)
	print("[PERF] NEED sort with 250 players: %.2f ms" % elapsed_need)

	# Measure SCHEME_FIT sort
	start = Time.get_ticks_usec()
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.SCHEME_FIT)
	var _scheme_result := draft.get_sorted_available_players()
	var elapsed_scheme := (Time.get_ticks_usec() - start) / 1000.0

	assert_float(elapsed_scheme).is_less(50.0)
	print("[PERF] SCHEME_FIT sort with 250 players: %.2f ms" % elapsed_scheme)


# =============================================================================
# Test: Shortlist Lookup <5ms for 1000 Lookups
# =============================================================================

func test_shortlist_lookup_under_5ms_for_1000_lookups() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	# Add 50 players (max shortlist size)
	for i in range(PlayerShortlist.MAX_SHORTLIST_SIZE):
		shortlist.add_player("player_%d" % i, "Player %d" % i, "QB", "College")

	# Measure 1000 lookups
	var start := Time.get_ticks_usec()
	for i in range(1000):
		var _result := shortlist.is_shortlisted("player_%d" % (i % 50))
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	assert_float(elapsed).is_less(5.0)
	print("[PERF] 1000 shortlist lookups: %.2f ms (%.4f ms per lookup)" % [elapsed, elapsed / 1000.0])


# =============================================================================
# Test: Trade Calculator <16ms for Value Update
# =============================================================================

func test_trade_calculator_under_16ms_for_value_update() -> void:
	var calc := TradeValueCalculator.new()

	# Add some picks
	calc.add_incoming_pick(1, 1)
	calc.add_incoming_pick(2, 15)
	calc.add_outgoing_pick(3, 10)

	# Measure value update time
	var start := Time.get_ticks_usec()
	for _i in range(100):
		calc.add_incoming_pick(4, 20)
		var _summary := calc.get_trade_summary()
		calc.remove_incoming_pick(4, 20)
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	var per_update := elapsed / 100.0
	assert_float(per_update).is_less(16.0)
	print("[PERF] Trade calculator update: %.2f ms average" % per_update)

	calc.free()


# =============================================================================
# Test: get_sorted_available_players() at Max Scale
# =============================================================================

func test_get_sorted_available_players_at_max_scale() -> void:
	var world_state := _create_large_world_state(250)
	var draft := InteractiveDraft.new()

	draft.initialize(
		world_state,
		2026,
		12345,
		"team_phi",
		_get_league_cfg(),
		_get_positions_cfg(),
		{},
		_get_scouts_cfg(),
		_get_main_cfg()
	)

	# Test all three sort modes at max scale
	var modes := [
		InteractiveDraft.BoardSortMode.BPA,
		InteractiveDraft.BoardSortMode.NEED,
		InteractiveDraft.BoardSortMode.SCHEME_FIT
	]

	for mode in modes:
		draft.set_board_sort_mode(mode)

		var start := Time.get_ticks_usec()
		var players := draft.get_sorted_available_players()
		var elapsed := (Time.get_ticks_usec() - start) / 1000.0

		assert_int(players.size()).is_greater(0)
		assert_float(elapsed).is_less(50.0)
		print("[PERF] get_sorted_available_players (mode %d): %.2f ms" % [mode, elapsed])


# =============================================================================
# Test: Shortlist Add/Remove at Max Size
# =============================================================================

func test_shortlist_add_remove_at_max_size() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	# Fill to max capacity
	for i in range(PlayerShortlist.MAX_SHORTLIST_SIZE):
		shortlist.add_player("player_%d" % i, "Player %d" % i, "QB", "College")

	assert_bool(shortlist.is_full()).is_true()

	# Measure add/remove operations at max size
	var start := Time.get_ticks_usec()
	for i in range(100):
		# Remove one
		shortlist.remove_player("player_0")
		# Add it back
		shortlist.add_player("player_0", "Player 0", "QB", "College")
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	var per_operation := elapsed / 200.0  # 100 removes + 100 adds
	assert_float(per_operation).is_less(1.0)  # Should be very fast
	print("[PERF] Shortlist add/remove at max size: %.4f ms per operation" % per_operation)


# =============================================================================
# Test: Board Sort Mode Switch with Full Draft Board
# =============================================================================

func test_board_sort_mode_switch_performance() -> void:
	var world_state := _create_large_world_state(250)
	var draft := InteractiveDraft.new()

	draft.initialize(
		world_state,
		2026,
		12345,
		"team_phi",
		_get_league_cfg(),
		_get_positions_cfg(),
		{},
		_get_scouts_cfg(),
		_get_main_cfg()
	)

	# Measure rapid mode switching
	var start := Time.get_ticks_usec()
	for _i in range(10):
		draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
		var _players1 := draft.get_sorted_available_players()
		draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.NEED)
		var _players2 := draft.get_sorted_available_players()
		draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.SCHEME_FIT)
		var _players3 := draft.get_sorted_available_players()
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	var per_switch := elapsed / 30.0  # 10 iterations * 3 switches
	assert_float(per_switch).is_less(50.0)
	print("[PERF] Board sort mode switch: %.2f ms average" % per_switch)


# =============================================================================
# Helper Functions
# =============================================================================

func _create_large_world_state(player_count: int) -> Dictionary:
	return {
		"current_year": 2026,
		"nfl_teams": _create_test_teams(32),
		"nfl_rosters": _create_test_rosters(32),
		"draft_pool": {
			2026: _create_large_draft_pool(player_count)
		}
	}


func _create_test_teams(count: int) -> Array:
	var teams := []
	for i in range(count):
		teams.append({
			"id": "team_%d" % i,
			"name": "Team %d" % i,
			"city": "City %d" % i,
			"draft_order": i + 1,
			"offensive_scheme": ["pro_style", "spread", "west_coast"][i % 3],
			"defensive_scheme": ["cover_2", "cover_3", "man_press"][i % 3],
			"coach": {
				"name": "Coach %d" % i,
				"offensive_style": "balanced",
				"defensive_style": "balanced"
			}
		})
	return teams


func _create_test_rosters(team_count: int) -> Dictionary:
	var rosters := {}
	for i in range(team_count):
		# Create rosters with some existing players to test position needs
		var roster_players := []
		var by_position := {}

		# Add a few players at each position
		var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
		for pos_idx in range(positions.size()):
			var pos: String = positions[pos_idx]
			by_position[pos] = []
			# Add 2-3 players per position
			for j in range(2 + (i % 2)):
				var player_id := "existing_team%d_pos%d_%d" % [i, pos_idx, j]
				roster_players.append({
					"player_id": player_id,
					"name": "Existing Player",
					"position": pos,
					"age": 25,
					"composite_score": 70.0
				})
				by_position[pos].append(player_id)

		rosters["team_%d" % i] = {
			"players": roster_players,
			"by_position": by_position
		}
	return rosters


func _create_large_draft_pool(player_count: int) -> Array:
	var pool := []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

	for i in range(player_count):
		var pos: String = positions[i % positions.size()]
		pool.append({
			"player_id": "player_%d" % i,
			"id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": pos,
			"college_team_id": "college_%d" % (i % 50),
			"age": 21 + (i % 3),
			"height": "6-%d" % (1 + (i % 5)),
			"weight": 180 + (i % 100),
			"composite_score": 90.0 - (float(i) / 3.0),
			"scheme_fit": {
				"pro_style": 70.0 + (i % 30),
				"spread": 70.0 + ((i + 10) % 30),
				"west_coast": 70.0 + ((i + 20) % 30),
				"cover_2": 70.0 + ((i + 5) % 30),
				"cover_3": 70.0 + ((i + 15) % 30),
				"man_press": 70.0 + ((i + 25) % 30)
			}
		})
	return pool


func _get_league_cfg() -> Dictionary:
	return {
		"draft": {
			"rounds": 7,
			"picks_per_round": 32
		},
		"cap_limit": 200.0
	}


func _get_positions_cfg() -> Dictionary:
	return {
		"QB": {"rating_weights": {"pass_accuracy": 0.4, "pass_power": 0.3, "mobility": 0.3}},
		"RB": {"rating_weights": {"rushing_power": 0.5, "speed": 0.3, "receiving": 0.2}},
		"WR": {"rating_weights": {"receiving": 0.6, "speed": 0.3, "route_running": 0.1}},
		"TE": {"rating_weights": {"receiving": 0.5, "blocking": 0.3, "speed": 0.2}},
		"OL": {"rating_weights": {"blocking": 0.7, "strength": 0.3}},
		"DL": {"rating_weights": {"pass_rush": 0.5, "run_defense": 0.3, "strength": 0.2}},
		"EDGE": {"rating_weights": {"pass_rush": 0.7, "speed": 0.3}},
		"LB": {"rating_weights": {"tackling": 0.5, "coverage": 0.3, "speed": 0.2}},
		"CB": {"rating_weights": {"coverage": 0.6, "speed": 0.4}},
		"S": {"rating_weights": {"coverage": 0.5, "tackling": 0.3, "speed": 0.2}},
		"K": {"rating_weights": {"kicking_power": 0.6, "kicking_accuracy": 0.4}},
		"P": {"rating_weights": {"punting_power": 0.6, "punting_accuracy": 0.4}}
	}


func _get_scouts_cfg() -> Dictionary:
	return {
		"national_scouts": [
			{"base_skill": 0.55, "board_noise_sigma": 1.8}
		]
	}


func _get_main_cfg() -> Dictionary:
	return {
		"class_rules": {
			"class_years": ["FR", "SO", "JR", "SR"],
			"age_ranges": {"FR": [18, 19], "SO": [19, 20], "JR": [20, 21], "SR": [21, 23]}
		}
	}
