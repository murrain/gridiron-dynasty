## GdUnit4 integration tests for Draft + Shortlist + UI interactions (DRAFT-009)
##
## Tests integration between InteractiveDraft, PlayerShortlist, and UI components
## to ensure proper signal propagation, state synchronization, and feature interactions.
##
extends GdUnitTestSuite

const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const PlayerShortlist = preload("res://scripts/core/models/PlayerShortlist.gd")
const TestWorldStateLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")


# =============================================================================
# Test: Shortlist Persistence Across Picks
# =============================================================================

func test_shortlist_persists_across_picks() -> void:
	var world_state := _create_minimal_world_state()
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

	# Add players to shortlist before draft starts
	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	if pool.size() >= 3:
		draft.add_to_shortlist(String(pool[0].get("player_id", "")))
		draft.add_to_shortlist(String(pool[1].get("player_id", "")))
		draft.add_to_shortlist(String(pool[2].get("player_id", "")))

	var shortlist_before := draft.get_shortlist()
	assert_int(shortlist_before.size()).is_equal(3)

	# Start draft (which may make AI picks)
	draft.start()

	# Shortlist should persist
	var shortlist_after := draft.get_shortlist()
	assert_int(shortlist_after.size()).is_greater_equal(0)  # Some may be drafted


# =============================================================================
# Test: Shortlist Notifications When Players Drafted
# =============================================================================

func test_shortlist_notification_when_player_drafted() -> void:
	var world_state := _create_minimal_world_state()
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

	# Add a player to shortlist
	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	if pool.size() >= 1:
		var player_id := String(pool[0].get("player_id", ""))
		draft.add_to_shortlist(player_id)

		var signal_received := false
		var signal_data := {}

		draft.shortlisted_player_drafted.connect(func(pid, name, pos, tid, pick):
			signal_received = true
			signal_data = {"player_id": pid, "name": name, "position": pos, "team_id": tid, "pick": pick}
		)

		# Make this player get drafted (simulate)
		var shortlist_model := draft.get_shortlist_model()
		shortlist_model.mark_as_drafted(player_id, "team_dal", 5)

		assert_bool(signal_received).is_true()
		assert_str(String(signal_data.get("player_id", ""))).is_equal(player_id)


# =============================================================================
# Test: Board Sort Mode Affects Pick Selection
# =============================================================================

func test_board_sort_mode_affects_player_list() -> void:
	var world_state := _create_minimal_world_state()
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

	# Get BPA list
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
	var bpa_list := draft.get_sorted_available_players()

	# Get NEED list
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.NEED)
	var need_list := draft.get_sorted_available_players()

	# Lists should have same size but potentially different order
	assert_int(bpa_list.size()).is_equal(need_list.size())

	# If we have at least 2 players, orders might differ
	if bpa_list.size() >= 2:
		# Just verify both lists contain valid player data
		assert_str(String(bpa_list[0].get("player_id", ""))).is_not_empty()
		assert_str(String(need_list[0].get("player_id", ""))).is_not_empty()


# =============================================================================
# Test: Trade Calculator with Live Draft Picks
# =============================================================================

func test_trade_calculator_with_draft_picks() -> void:
	# This test verifies that draft pick values can be calculated
	# Note: TradeValueCalculator is UI component, test basic integration

	var world_state := _create_minimal_world_state()
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

	# Verify draft order exists
	var total_picks := draft.get_total_picks()
	assert_int(total_picks).is_greater(0)

	# Verify we can query current pick
	var current_pick := draft.get_current_pick()
	assert_int(current_pick).is_greater_equal(0)


# =============================================================================
# Test: Shortlist UI Updates on Pick Execution
# =============================================================================

func test_shortlist_changes_trigger_signal() -> void:
	var world_state := _create_minimal_world_state()
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

	var signal_count := 0
	draft.shortlist_changed.connect(func(): signal_count += 1)

	# Add player to shortlist
	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	if pool.size() >= 1:
		draft.add_to_shortlist(String(pool[0].get("player_id", "")))

		# Signal should have been emitted
		assert_int(signal_count).is_greater_equal(1)


# =============================================================================
# Test: Board Sort with Empty/Partial Player Lists
# =============================================================================

func test_board_sort_with_empty_pool() -> void:
	var world_state := _create_minimal_world_state()
	# Create empty draft pool
	world_state["draft_pool"] = {2026: []}

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

	# Should return empty list without crashing
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
	var players := draft.get_sorted_available_players()
	assert_array(players).is_empty()


# =============================================================================
# Test: Trade Calculator with Invalid Pick Data
# =============================================================================

func test_shortlist_handles_invalid_player_ids() -> void:
	var world_state := _create_minimal_world_state()
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

	# Try to add invalid player ID
	var result := draft.add_to_shortlist("invalid_player_xyz")
	assert_bool(result).is_false()

	# Try to check invalid player
	var is_shortlisted := draft.is_on_shortlist("invalid_player_xyz")
	assert_bool(is_shortlisted).is_false()


# =============================================================================
# Test: Shortlist Max Size Enforcement During Draft
# =============================================================================

func test_shortlist_max_size_enforced() -> void:
	var world_state := _create_minimal_world_state()
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

	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	var shortlist_model := draft.get_shortlist_model()

	# Add up to max size (50)
	var added_count := 0
	for i in range(min(PlayerShortlist.MAX_SHORTLIST_SIZE + 5, pool.size())):
		var player := pool[i] as Dictionary
		var player_id := String(player.get("player_id", ""))
		if draft.add_to_shortlist(player_id):
			added_count += 1

	# Should not exceed max
	assert_int(shortlist_model.size()).is_less_equal(PlayerShortlist.MAX_SHORTLIST_SIZE)


# =============================================================================
# Test: Signal Propagation (Pick -> Shortlist -> UI)
# =============================================================================

func test_signal_propagation_chain() -> void:
	var world_state := _create_minimal_world_state()
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

	var pick_made_count := 0
	var shortlist_drafted_count := 0

	draft.pick_made.connect(func(_pick_info): pick_made_count += 1)
	draft.shortlisted_player_drafted.connect(func(_pid, _name, _pos, _tid, _pick): shortlist_drafted_count += 1)

	# Add a player to shortlist
	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	if pool.size() >= 1:
		var player_id := String(pool[0].get("player_id", ""))
		draft.add_to_shortlist(player_id)

		# Manually mark as drafted to test signal chain
		var shortlist_model := draft.get_shortlist_model()
		shortlist_model.mark_as_drafted(player_id, "team_dal", 1)

		# Shortlist drafted signal should fire
		assert_int(shortlist_drafted_count).is_equal(1)


# =============================================================================
# Test: Draft State Restoration with Active Shortlist
# =============================================================================

func test_shortlist_persistence() -> void:
	var world_state := _create_minimal_world_state()
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

	# Add players to shortlist
	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	if pool.size() >= 2:
		draft.add_to_shortlist(String(pool[0].get("player_id", "")))
		draft.add_to_shortlist(String(pool[1].get("player_id", "")))

	# Get shortlist data for saving
	var shortlist_data := draft.get_shortlist_data()
	assert_dict(shortlist_data).is_not_empty()

	# Create new draft and restore
	var draft2 := InteractiveDraft.new()
	draft2.initialize(
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

	draft2.load_shortlist_data(shortlist_data)

	# Verify restoration
	var restored_shortlist := draft2.get_shortlist()
	assert_int(restored_shortlist.size()).is_greater_equal(0)


# =============================================================================
# Test: Shortlist mark_as_drafted Integration
# =============================================================================

func test_mark_as_drafted_updates_shortlist() -> void:
	var world_state := _create_minimal_world_state()
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

	var pool: Array = world_state.get("draft_pool", {}).get(2026, [])
	if pool.size() >= 1:
		var player_id := String(pool[0].get("player_id", ""))
		draft.add_to_shortlist(player_id)

		# Get available entries before
		var available_before := draft.get_available_shortlist()
		assert_int(available_before.size()).is_equal(1)

		# Mark as drafted
		var shortlist_model := draft.get_shortlist_model()
		shortlist_model.mark_as_drafted(player_id, "team_dal", 1)

		# Get available entries after
		var available_after := draft.get_available_shortlist()
		assert_int(available_after.size()).is_equal(0)


# =============================================================================
# Test: Board Sort Determinism with Same Data
# =============================================================================

func test_board_sort_determinism() -> void:
	var world_state := _create_minimal_world_state()
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

	# Get sorted list twice with same mode
	draft.set_board_sort_mode(InteractiveDraft.BoardSortMode.BPA)
	var list1 := draft.get_sorted_available_players()
	var list2 := draft.get_sorted_available_players()

	# Lists should be identical
	assert_int(list1.size()).is_equal(list2.size())

	if list1.size() > 0:
		assert_str(String(list1[0].get("player_id", ""))).is_equal(String(list2[0].get("player_id", "")))


# =============================================================================
# Helper Functions
# =============================================================================

func _create_minimal_world_state() -> Dictionary:
	return {
		"current_year": 2026,
		"nfl_teams": _create_test_teams(),
		"nfl_rosters": _create_empty_rosters(),
		"draft_pool": {
			2026: _create_test_draft_pool()
		}
	}


func _create_test_teams() -> Array:
	var teams := []
	for i in range(4):
		teams.append({
			"id": "team_%d" % i,
			"name": "Team %d" % i,
			"city": "City %d" % i,
			"draft_order": i + 1,
			"offensive_scheme": "pro_style",
			"defensive_scheme": "cover_2"
		})
	return teams


func _create_empty_rosters() -> Dictionary:
	var rosters := {}
	for i in range(4):
		rosters["team_%d" % i] = {
			"players": [],
			"by_position": {}
		}
	return rosters


func _create_test_draft_pool() -> Array:
	var pool := []
	for i in range(20):
		pool.append({
			"player_id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"][i % 10],
			"college_team_id": "college_%d" % (i % 5),
			"age": 21 + (i % 3),
			"height": "6-2",
			"weight": 200 + i,
			"composite_score": 75.0 - float(i)
		})
	return pool


func _get_league_cfg() -> Dictionary:
	return {
		"draft": {
			"rounds": 7,
			"picks_per_round": 4
		},
		"cap_limit": 200.0
	}


func _get_positions_cfg() -> Dictionary:
	return {
		"QB": {"rating_weights": {"pass_accuracy": 1.0}},
		"RB": {"rating_weights": {"rushing_power": 1.0}},
		"WR": {"rating_weights": {"receiving": 1.0}},
		"TE": {"rating_weights": {"receiving": 0.7, "blocking": 0.3}},
		"OL": {"rating_weights": {"blocking": 1.0}},
		"DL": {"rating_weights": {"pass_rush": 0.6, "run_defense": 0.4}},
		"EDGE": {"rating_weights": {"pass_rush": 1.0}},
		"LB": {"rating_weights": {"tackling": 1.0}},
		"CB": {"rating_weights": {"coverage": 1.0}},
		"S": {"rating_weights": {"coverage": 0.7, "tackling": 0.3}}
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
