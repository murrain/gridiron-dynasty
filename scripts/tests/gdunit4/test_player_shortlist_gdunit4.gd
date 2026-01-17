## GdUnit4 test suite for PlayerShortlist model (DRAFT-009)
##
## Validates shortlist add/remove, priority management, drafted notification,
## and persistence functionality.
##
## Performance target: All shortlist operations <5ms
##
extends GdUnitTestSuite

const PlayerShortlist = preload("res://scripts/core/models/PlayerShortlist.gd")


# =============================================================================
# Test: Add/Remove Players
# =============================================================================

func test_add_player_returns_true_and_adds_to_list() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	var result := shortlist.add_player("player_001", "John Smith", "QB", "State U")

	assert_bool(result).is_true()
	assert_int(shortlist.size()).is_equal(1)
	assert_bool(shortlist.is_shortlisted("player_001")).is_true()


func test_add_duplicate_player_returns_false() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	shortlist.add_player("player_001", "John Smith", "QB", "State U")
	var result := shortlist.add_player("player_001", "John Smith", "QB", "State U")

	assert_bool(result).is_false()
	assert_int(shortlist.size()).is_equal(1)


func test_add_empty_id_returns_false() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	var result := shortlist.add_player("", "John Smith", "QB", "State U")

	assert_bool(result).is_false()
	assert_int(shortlist.size()).is_equal(0)


func test_remove_player_returns_true_and_removes() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")

	var result := shortlist.remove_player("player_001")

	assert_bool(result).is_true()
	assert_int(shortlist.size()).is_equal(0)
	assert_bool(shortlist.is_shortlisted("player_001")).is_false()


func test_remove_nonexistent_player_returns_false() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	var result := shortlist.remove_player("player_999")

	assert_bool(result).is_false()


# =============================================================================
# Test: Priority Management
# =============================================================================

func test_default_priority_is_medium() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")

	var entry := shortlist.get_entry("player_001")

	assert_int(int(entry.get("priority", -1))).is_equal(PlayerShortlist.Priority.MEDIUM)


func test_set_priority_updates_entry() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")

	var result := shortlist.set_priority("player_001", PlayerShortlist.Priority.HIGH)

	assert_bool(result).is_true()
	var entry := shortlist.get_entry("player_001")
	assert_int(int(entry.get("priority", -1))).is_equal(PlayerShortlist.Priority.HIGH)


func test_entries_sorted_by_priority_then_add_time() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	# Add in order: medium, low, high
	shortlist.add_player("player_med", "Medium Guy", "RB", "College A", PlayerShortlist.Priority.MEDIUM)
	shortlist.add_player("player_low", "Low Guy", "WR", "College B", PlayerShortlist.Priority.LOW)
	shortlist.add_player("player_high", "High Guy", "QB", "College C", PlayerShortlist.Priority.HIGH)

	var entries := shortlist.get_all_entries()

	# High priority should be first
	assert_str(String(entries[0].get("player_id", ""))).is_equal("player_high")
	# Medium second
	assert_str(String(entries[1].get("player_id", ""))).is_equal("player_med")
	# Low last
	assert_str(String(entries[2].get("player_id", ""))).is_equal("player_low")


# =============================================================================
# Test: Drafted Status and Alerts
# =============================================================================

func test_mark_as_drafted_updates_status() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")

	shortlist.mark_as_drafted("player_001", "team_phi", 15)

	var entry := shortlist.get_entry("player_001")
	assert_str(String(entry.get("status", ""))).is_equal("drafted")
	assert_str(String(entry.get("drafted_by", ""))).is_equal("team_phi")
	assert_int(int(entry.get("drafted_at_pick", 0))).is_equal(15)


func test_get_available_entries_excludes_drafted() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")
	shortlist.add_player("player_002", "Jane Doe", "WR", "Tech U")
	shortlist.mark_as_drafted("player_001", "team_phi", 15)

	var available := shortlist.get_available_entries()

	assert_int(available.size()).is_equal(1)
	assert_str(String(available[0].get("player_id", ""))).is_equal("player_002")


func test_drafted_signal_emitted() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")

	var signal_received := false
	var signal_data := {}

	shortlist.shortlisted_player_drafted.connect(func(pid, name, pos, tid, pick):
		signal_received = true
		signal_data = {"player_id": pid, "name": name, "position": pos, "team_id": tid, "pick": pick}
	)

	shortlist.mark_as_drafted("player_001", "team_phi", 15)

	assert_bool(signal_received).is_true()
	assert_str(String(signal_data.get("player_id", ""))).is_equal("player_001")
	assert_str(String(signal_data.get("name", ""))).is_equal("John Smith")
	assert_str(String(signal_data.get("position", ""))).is_equal("QB")
	assert_str(String(signal_data.get("team_id", ""))).is_equal("team_phi")
	assert_int(int(signal_data.get("pick", 0))).is_equal(15)


# =============================================================================
# Test: Persistence
# =============================================================================

func test_to_dict_serializes_all_data() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U", PlayerShortlist.Priority.HIGH)
	shortlist.add_player("player_002", "Jane Doe", "WR", "Tech U", PlayerShortlist.Priority.LOW)

	var data := shortlist.to_dict()

	assert_str(String(data.get("team_id", ""))).is_equal("team_test")
	assert_int(int(data.get("version", 0))).is_equal(1)
	var entries: Array = data.get("entries", [])
	assert_int(entries.size()).is_equal(2)


func test_from_dict_restores_all_data() -> void:
	var original := PlayerShortlist.new()
	original.initialize("team_test")
	original.add_player("player_001", "John Smith", "QB", "State U", PlayerShortlist.Priority.HIGH)
	original.add_player("player_002", "Jane Doe", "WR", "Tech U", PlayerShortlist.Priority.LOW)
	original.mark_as_drafted("player_002", "team_chi", 42)

	var data := original.to_dict()

	var restored := PlayerShortlist.new()
	restored.from_dict(data)

	assert_int(restored.size()).is_equal(2)
	assert_bool(restored.is_shortlisted("player_001")).is_true()
	assert_bool(restored.is_shortlisted("player_002")).is_true()

	var entry1 := restored.get_entry("player_001")
	assert_int(int(entry1.get("priority", -1))).is_equal(PlayerShortlist.Priority.HIGH)

	var entry2 := restored.get_entry("player_002")
	assert_str(String(entry2.get("status", ""))).is_equal("drafted")


# =============================================================================
# Test: Performance and Edge Cases
# =============================================================================

func test_is_shortlisted_is_o1_lookup() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	# Add many players
	for i in range(50):
		shortlist.add_player("player_%d" % i, "Player %d" % i, "QB", "College")

	# Lookup should be fast (using hash set internally)
	var start := Time.get_ticks_usec()
	for i in range(1000):
		var _result := shortlist.is_shortlisted("player_25")
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	# 1000 lookups should complete in <5ms
	assert_float(elapsed).is_less(5.0)


func test_max_shortlist_size_enforced() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")

	# Add up to max
	for i in range(PlayerShortlist.MAX_SHORTLIST_SIZE):
		shortlist.add_player("player_%d" % i, "Player %d" % i, "QB", "College")

	# Should be full
	assert_bool(shortlist.is_full()).is_true()

	# Adding one more should fail
	var result := shortlist.add_player("player_overflow", "Overflow", "QB", "College")
	assert_bool(result).is_false()
	assert_int(shortlist.size()).is_equal(PlayerShortlist.MAX_SHORTLIST_SIZE)


func test_clear_removes_all_entries() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U")
	shortlist.add_player("player_002", "Jane Doe", "WR", "Tech U")

	shortlist.clear()

	assert_bool(shortlist.is_empty()).is_true()
	assert_int(shortlist.size()).is_equal(0)
	assert_bool(shortlist.is_shortlisted("player_001")).is_false()


func test_promote_demote_operations() -> void:
	var shortlist := PlayerShortlist.new()
	shortlist.initialize("team_test")
	shortlist.add_player("player_001", "John Smith", "QB", "State U", PlayerShortlist.Priority.MEDIUM)

	# Promote to HIGH
	var promote_result := shortlist.promote("player_001")
	assert_bool(promote_result).is_true()
	var entry := shortlist.get_entry("player_001")
	assert_int(int(entry.get("priority", -1))).is_equal(PlayerShortlist.Priority.HIGH)

	# Cannot promote above HIGH
	var promote_again := shortlist.promote("player_001")
	assert_bool(promote_again).is_false()

	# Demote back to MEDIUM
	var demote_result := shortlist.demote("player_001")
	assert_bool(demote_result).is_true()
	entry = shortlist.get_entry("player_001")
	assert_int(int(entry.get("priority", -1))).is_equal(PlayerShortlist.Priority.MEDIUM)
