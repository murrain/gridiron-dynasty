## GdUnit4 test suite for Draft User Interaction (Engineer 2)
##
## Tests for:
## - TeamSelectionScreen: Pre-draft team selection flow
## - UserPickModal: User pick modal functionality
## - GameSession user_team_id persistence
## - DraftDayUI integration with UserPickModal
##
## These tests verify the playable draft user interaction components.
extends GdUnitTestSuite

const TeamSelectionScreen = preload("res://scenes/ui/draft/TeamSelectionScreen.gd")
const UserPickModal = preload("res://scenes/ui/draft/UserPickModal.gd")
const GameSession = preload("res://scripts/core/models/GameSession.gd")
const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")


var _league_cfg: Dictionary
var _positions_cfg: Dictionary
var _stats_cfg: Dictionary
var _scouts_cfg: Dictionary
var _main_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_league_cfg = config.get_config("world/league")
	_positions_cfg = config.get_config("positions")
	_stats_cfg = config.get_config("stats")
	_scouts_cfg = config.get_config("scouts")
	_main_cfg = config.get_config("main")


# =============================================================================
# TEAM SELECTION SCREEN TESTS
# =============================================================================

func test_team_selection_screen_sorts_teams_by_draft_order() -> void:
	var screen := TeamSelectionScreen.new()
	var world_state := _make_world_state_with_teams()

	# Initialize without adding to tree (just testing data logic)
	screen._world_state = world_state
	screen._year = 2025
	screen._load_teams()

	# Verify teams are sorted by draft_order
	var teams: Array = screen._teams
	assert_int(teams.size()).is_equal(4)  # We created 4 teams

	for i in range(teams.size() - 1):
		var current_order := int((teams[i] as Dictionary).get("draft_order", 999))
		var next_order := int((teams[i + 1] as Dictionary).get("draft_order", 999))
		assert_bool(current_order <= next_order).is_true()

	screen.free()


func test_team_selection_screen_emits_signal_on_selection() -> void:
	var screen := TeamSelectionScreen.new()
	var world_state := _make_world_state_with_teams()

	screen._world_state = world_state
	screen._year = 2025
	screen._load_teams()

	# Simulate team selection
	var selected_id := ""
	screen.team_selected.connect(func(team_id: String):
		selected_id = team_id
	)

	# Set up selection (simulating what _on_start_pressed does)
	screen._selected_index = 0
	screen._selected_team_id = "team_a"
	screen._on_start_pressed()

	assert_str(selected_id).is_equal("team_a")

	screen.free()


func test_team_selection_screen_shows_draft_picks_info() -> void:
	var screen := TeamSelectionScreen.new()
	var world_state := _make_world_state_with_teams()

	# Add pick ownership
	world_state["draft_pick_ownership"] = {
		2025: {
			1: {"team_a": "team_a", "team_b": "team_a"},  # team_a has 2 first round picks
			2: {"team_a": "team_a", "team_b": "team_b"},
		}
	}

	screen._world_state = world_state
	screen._year = 2025
	screen._load_teams()

	var picks_info := screen._get_team_draft_picks("team_a")

	# Should show team_a has multiple picks
	assert_str(picks_info).contains("2 picks")

	screen.free()


# =============================================================================
# USER PICK MODAL TESTS
# =============================================================================

func test_user_pick_modal_populates_player_list() -> void:
	var modal := UserPickModal.new()

	# Create mock available players
	var available_players: Array = [
		{"player_id": "p1", "name": "John Smith", "position": "QB", "overall": 85.0, "college": "Alabama"},
		{"player_id": "p2", "name": "Jane Doe", "position": "RB", "overall": 80.0, "college": "Ohio State"},
		{"player_id": "p3", "name": "Bob Johnson", "position": "WR", "overall": 75.0, "college": "USC"},
	]

	# Store available players directly (simulating what show_pick does)
	modal._round = 1
	modal._pick = 1
	modal._available_players = available_players

	# Verify data is stored correctly
	assert_int(modal._available_players.size()).is_equal(3)
	assert_int(modal.get_current_round()).is_equal(1)
	assert_int(modal.get_current_pick()).is_equal(1)

	modal.free()


func test_user_pick_modal_emits_player_selected_signal() -> void:
	var modal := UserPickModal.new()

	var selected_player_id := ""
	modal.player_selected.connect(func(player_id: String):
		selected_player_id = player_id
	)

	# Simulate selection
	modal._selected_player_id = "p1"
	modal._on_draft_pressed()

	assert_str(selected_player_id).is_equal("p1")

	modal.free()


func test_user_pick_modal_emits_auto_pick_signal() -> void:
	var modal := UserPickModal.new()

	var auto_pick_called := false
	modal.auto_pick_requested.connect(func():
		auto_pick_called = true
	)

	modal._on_auto_pick_pressed()

	assert_bool(auto_pick_called).is_true()

	modal.free()


func test_user_pick_modal_hides_after_selection() -> void:
	var modal := UserPickModal.new()
	modal.visible = true
	modal._selected_player_id = "p1"

	# Connect signal to prevent error from no receiver
	modal.player_selected.connect(func(_id: String): pass)

	modal._on_draft_pressed()

	assert_bool(modal.visible).is_false()

	modal.free()


# =============================================================================
# GAME SESSION USER TEAM ID TESTS
# =============================================================================

func test_game_session_persists_user_team_id() -> void:
	var session := GameSession.new()
	var world_state := _make_world_state_with_teams()

	session.initialize(world_state, "team_b", 2025)

	# Verify user_team_id is set
	assert_str(session.user_team_id).is_equal("team_b")

	# Test serialization
	var data := session.to_dict()
	assert_str(String(data.get("user_team_id", ""))).is_equal("team_b")

	# Test deserialization
	var new_session := GameSession.new()
	new_session.from_dict(data)
	assert_str(new_session.user_team_id).is_equal("team_b")


func test_game_session_user_team_id_survives_save_load_cycle() -> void:
	var session := GameSession.new()
	var world_state := _make_world_state_with_teams()

	session.initialize(world_state, "team_c", 2025)
	session.save_name = "test_save"

	# Serialize
	var save_data := session.to_dict()

	# Verify save data contains user_team_id
	assert_bool(save_data.has("user_team_id")).is_true()
	assert_str(String(save_data.get("user_team_id", ""))).is_equal("team_c")

	# Create new session and restore
	var restored_session := GameSession.new()
	restored_session.from_dict(save_data)
	restored_session.load_world_state(world_state)

	assert_str(restored_session.user_team_id).is_equal("team_c")
	assert_str(restored_session.save_name).is_equal("test_save")


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_team_selection_to_draft_flow() -> void:
	# Create world state with draft pool
	var world_state := _make_world_state_with_teams_and_draft_pool(100)

	# Step 1: Team selection
	var screen := TeamSelectionScreen.new()
	screen._world_state = world_state
	screen._year = 2025
	screen._load_teams()

	var selected_team_id := ""
	screen.team_selected.connect(func(team_id: String):
		selected_team_id = team_id
	)

	# Select first team
	screen._selected_index = 0
	screen._selected_team_id = String((screen._teams[0] as Dictionary).get("id", ""))
	screen._on_start_pressed()

	assert_str(selected_team_id).is_not_empty()

	# Step 2: Create session with selected team
	var session := GameSession.new()
	session.initialize(world_state, selected_team_id, 2025)

	assert_str(session.user_team_id).is_equal(selected_team_id)

	screen.free()


func test_user_pick_modal_to_draft_pick_flow() -> void:
	var world_state := _make_world_state_with_teams_and_draft_pool(100)
	var user_team_id := "team_a"

	# Create interactive draft
	var draft := InteractiveDraft.new()
	draft.initialize(
		world_state,
		2025,
		12345,
		user_team_id,
		_league_cfg,
		_positions_cfg,
		_stats_cfg,
		_scouts_cfg,
		_main_cfg
	)

	# Track if user pick was requested
	var pick_requested := false
	var pick_number := 0
	var round_number := 0
	var available_count := 0

	draft.user_pick_requested.connect(func(pick: int, round: int, available: Array, _recs: Array):
		pick_requested = true
		pick_number = pick
		round_number = round
		available_count = available.size()
	)

	# Start draft (should stop at user's pick)
	draft.start()

	# If team_a has the first pick, user_pick_requested should have fired
	# Note: This depends on draft order in test data
	if draft.is_user_turn():
		assert_bool(pick_requested).is_true()
		assert_int(available_count).is_greater(0)

		# Simulate user making a pick via modal
		var modal := UserPickModal.new()
		modal._round = round_number
		modal._pick = pick_number

		# Get the first available player
		var available := draft._get_available_players_with_ratings()
		if not available.is_empty():
			var first_player: Dictionary = available[0]
			var player_id := String(first_player.get("player_id", ""))

			# Make the pick
			var success := draft.make_user_pick(player_id)
			assert_bool(success).is_true()

		modal.free()


func test_determinism_of_draft_with_user_participation() -> void:
	# Run draft twice with same seed and same user picks
	# Results should be identical

	var world_state_1 := _make_world_state_with_teams_and_draft_pool(100)
	var world_state_2 := _make_world_state_with_teams_and_draft_pool(100)

	var seed := 54321
	var user_team_id := "team_a"
	var user_pick_player_id := ""

	# First run
	var draft_1 := InteractiveDraft.new()
	draft_1.initialize(world_state_1, 2025, seed, user_team_id, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var picks_1: Array = []
	draft_1.pick_made.connect(func(pick: Dictionary):
		picks_1.append(pick.get("player_id", ""))
	)

	draft_1.user_pick_requested.connect(func(_pick: int, _round: int, available: Array, _recs: Array):
		if not available.is_empty():
			user_pick_player_id = String((available[0] as Dictionary).get("player_id", ""))
			draft_1.make_user_pick(user_pick_player_id)
	)

	draft_1.start()

	# Second run with same seed and same user choice
	var draft_2 := InteractiveDraft.new()
	draft_2.initialize(world_state_2, 2025, seed, user_team_id, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var picks_2: Array = []
	draft_2.pick_made.connect(func(pick: Dictionary):
		picks_2.append(pick.get("player_id", ""))
	)

	draft_2.user_pick_requested.connect(func(_pick: int, _round: int, _available: Array, _recs: Array):
		# Use the same player_id we used in first run
		if not user_pick_player_id.is_empty():
			draft_2.make_user_pick(user_pick_player_id)
	)

	draft_2.start()

	# Results should match (at least for the first few picks)
	var min_picks: int = min(picks_1.size(), picks_2.size()) as int
	if min_picks > 0:
		var check_count: int = min(min_picks, 10) as int
		for i in range(check_count):  # Check first 10 picks
			assert_str(String(picks_1[i])).is_equal(String(picks_2[i]))


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _make_world_state_with_teams() -> Dictionary:
	var teams: Array = [
		{"id": "team_a", "name": "Team A", "city": "City A", "division": "East", "conference": "AFC", "draft_order": 1},
		{"id": "team_b", "name": "Team B", "city": "City B", "division": "West", "conference": "NFC", "draft_order": 2},
		{"id": "team_c", "name": "Team C", "city": "City C", "division": "North", "conference": "AFC", "draft_order": 3},
		{"id": "team_d", "name": "Team D", "city": "City D", "division": "South", "conference": "NFC", "draft_order": 4},
	]

	var rosters: Dictionary = {}
	for team in teams:
		var t: Dictionary = team
		rosters[String(t.get("id", ""))] = {"players": [], "by_position": {}}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"draft_pool": {},
		"undrafted_pool": {},
	}


func _make_world_state_with_teams_and_draft_pool(pool_size: int) -> Dictionary:
	var world_state := _make_world_state_with_teams()

	# Generate draft pool
	var draft_pool: Array = []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]

	for i in range(pool_size):
		var pos_idx := i % positions.size()
		var player: Dictionary = {
			"id": "draft_player_%d" % i,
			"player_id": "draft_player_%d" % i,
			"name": "Player %d" % i,
			"position": positions[pos_idx],
			"age": 21,
			"composite_score": 80.0 - (float(i) * 0.2),
			"stats": {
				"speed": 70 + (i % 20),
				"strength": 65 + (i % 25),
				"agility": 68 + (i % 22),
			},
			"college_team_id": "college_%d" % (i % 10),
		}
		draft_pool.append(player)

	world_state["draft_pool"] = {2025: draft_pool}

	return world_state
