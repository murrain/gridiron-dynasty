extends RefCounted

## DraftRumorEngine Test Suite
##
## Tests for the draft day rumor generation system.
## Verifies:
##   - Deterministic generation with same seed
##   - Correct rumor count (default 120)
##   - All 4 rumor types generated
##   - Accuracy distribution (30% confirmed, 50% likely, 20% speculation)
##   - Timeline distribution across time periods
##   - Filtering by player, team, type, and time
##
## 12 tests as specified in IMPLEMENTATION_SPECIFICATION.md

const DraftRumorEngine = preload("res://scripts/world/DraftRumorEngine.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	test_rumor_generation_determinism(t)
	test_rumor_count(t)
	test_rumor_types(t)
	test_accuracy_distribution(t)
	test_rumor_timeline(t)
	test_rumor_text_format(t)
	test_visible_rumors_filter(t)
	test_player_rumors_filter(t)
	test_team_rumors_filter(t)
	test_rumor_persistence(t)
	test_rumor_subject_validity(t)
	test_rumor_sorting(t)


## Test 1: Same seed produces identical rumors (determinism)
func test_rumor_generation_determinism(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)  # 7 rounds x 32 teams
	var config := _create_test_config()

	var seed_val := 12345

	var rumors1 := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, seed_val)
	var rumors2 := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, seed_val)

	t.assert_eq(rumors1.size(), rumors2.size(), "same seed produces same rumor count")

	# Verify each rumor matches
	for i in range(min(rumors1.size(), 10)):  # Check first 10
		var r1: Dictionary = rumors1[i]
		var r2: Dictionary = rumors2[i]

		t.assert_eq(r1.get("type"), r2.get("type"), "rumor %d type matches" % i)
		t.assert_eq(r1.get("accuracy"), r2.get("accuracy"), "rumor %d accuracy matches" % i)
		t.assert_eq(r1.get("subject_player_id"), r2.get("subject_player_id"), "rumor %d player matches" % i)
		t.assert_eq(r1.get("text"), r2.get("text"), "rumor %d text matches" % i)


## Test 2: Rumor count matches configuration (default 120)
func test_rumor_count(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 120}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 54321)

	t.assert_eq(rumors.size(), 120, "generates exactly 120 rumors")

	# Test custom count
	config["rumors"]["total_count"] = 60
	var rumors_custom := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 54321)
	t.assert_eq(rumors_custom.size(), 60, "generates custom count (60)")


## Test 3: All 4 rumor types generated
func test_rumor_types(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 200}}  # More rumors for better coverage

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 99999)

	var type_counts := {}
	for rumor in rumors:
		var r: Dictionary = rumor
		var rtype := String(r.get("type", ""))
		if not type_counts.has(rtype):
			type_counts[rtype] = 0
		type_counts[rtype] += 1

	t.assert_true(type_counts.has("trade_talk"), "has trade_talk rumors")
	t.assert_true(type_counts.has("team_interest"), "has team_interest rumors")
	t.assert_true(type_counts.has("medical_update"), "has medical_update rumors")
	t.assert_true(type_counts.has("surprise_pick"), "has surprise_pick rumors")

	# Each type should have at least some representation (>5%)
	for rtype in type_counts.keys():
		var ratio := float(type_counts[rtype]) / float(rumors.size())
		t.assert_true(ratio >= 0.05, "%s has at least 5%% (got %.1f%%)" % [rtype, ratio * 100])


## Test 4: Accuracy distribution matches configuration (30/50/20)
func test_accuracy_distribution(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {
		"rumors": {
			"total_count": 300,  # More for statistics
			"accuracy_distribution": {
				"confirmed": 0.30,
				"likely": 0.50,
				"speculation": 0.20
			}
		}
	}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 77777)

	var stats := DraftRumorEngine.get_rumor_stats(rumors)
	var by_accuracy: Dictionary = stats.get("by_accuracy", {})
	var total := float(rumors.size())

	var confirmed_ratio := float(by_accuracy.get("confirmed", 0)) / total
	var likely_ratio := float(by_accuracy.get("likely", 0)) / total
	var speculation_ratio := float(by_accuracy.get("speculation", 0)) / total

	# Allow variance of +/- 10%
	t.assert_true(confirmed_ratio >= 0.20, "confirmed at least 20%% (got %.1f%%)" % (confirmed_ratio * 100))
	t.assert_true(confirmed_ratio <= 0.40, "confirmed at most 40%% (got %.1f%%)" % (confirmed_ratio * 100))

	t.assert_true(likely_ratio >= 0.40, "likely at least 40%% (got %.1f%%)" % (likely_ratio * 100))
	t.assert_true(likely_ratio <= 0.60, "likely at most 60%% (got %.1f%%)" % (likely_ratio * 100))

	t.assert_true(speculation_ratio >= 0.10, "speculation at least 10%% (got %.1f%%)" % (speculation_ratio * 100))
	t.assert_true(speculation_ratio <= 0.30, "speculation at most 30%% (got %.1f%%)" % (speculation_ratio * 100))


## Test 5: Rumors span all time periods
func test_rumor_timeline(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 120}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 11111)

	var stats := DraftRumorEngine.get_rumor_stats(rumors)
	var by_time: Dictionary = stats.get("by_time_period", {})

	# Expected time periods: 24, 12, 6, 3, 1, 0
	var expected_periods := [24, 12, 6, 3, 1, 0]

	for period in expected_periods:
		t.assert_true(by_time.has(period), "has rumors for %d hours before" % period)
		var count := int(by_time.get(period, 0))
		t.assert_true(count > 0, "period %d has at least 1 rumor (got %d)" % [period, count])


## Test 6: Rumor text includes accuracy prefix
func test_rumor_text_format(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 50}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 22222)

	for rumor in rumors:
		var r: Dictionary = rumor
		var text := String(r.get("text", ""))
		var accuracy := String(r.get("accuracy", ""))

		# Check that text starts with appropriate prefix
		var has_prefix := false
		if accuracy == "confirmed":
			has_prefix = text.begins_with("[CONFIRMED]")
		elif accuracy == "likely":
			has_prefix = text.begins_with("[REPORT]")
		elif accuracy == "speculation":
			has_prefix = text.begins_with("[RUMOR]")

		t.assert_true(has_prefix, "text has correct prefix for %s: %s" % [accuracy, text.left(30)])

		# Check timestamp label exists
		t.assert_true(r.has("timestamp_label"), "rumor has timestamp_label")


## Test 7: Visible rumors filter works correctly
func test_visible_rumors_filter(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 120}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 33333)

	# At 24h before, only 24h rumors should be visible
	var visible_24h := DraftRumorEngine.get_visible_rumors(rumors, 24)
	for r in visible_24h:
		var rumor: Dictionary = r
		t.assert_eq(int(rumor.get("hours_before", 0)), 24, "at 24h only 24h rumors visible")

	# At 12h before, 24h and 12h rumors should be visible
	var visible_12h := DraftRumorEngine.get_visible_rumors(rumors, 12)
	for r in visible_12h:
		var rumor: Dictionary = r
		var hours := int(rumor.get("hours_before", 0))
		t.assert_true(hours >= 12, "at 12h shows 12h+ rumors (got %d)" % hours)

	# At 0h (draft start), all rumors should be visible
	var visible_0h := DraftRumorEngine.get_visible_rumors(rumors, 0)
	t.assert_eq(visible_0h.size(), rumors.size(), "at 0h all rumors visible")


## Test 8: Player rumors filter works
func test_player_rumors_filter(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 100}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 44444)

	# Pick a player that appears in rumors
	var test_player_id := ""
	for rumor in rumors:
		var r: Dictionary = rumor
		var pid := String(r.get("subject_player_id", ""))
		if not pid.is_empty():
			test_player_id = pid
			break

	if test_player_id.is_empty():
		t.skip("No player found in rumors")
		return

	var player_rumors := DraftRumorEngine.get_player_rumors(rumors, test_player_id)

	t.assert_true(player_rumors.size() > 0, "found rumors for player %s" % test_player_id)

	for rumor in player_rumors:
		var r: Dictionary = rumor
		t.assert_eq(String(r.get("subject_player_id", "")), test_player_id, "all filtered rumors match player")


## Test 9: Team rumors filter works
func test_team_rumors_filter(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 100}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 55555)

	# Pick a team that appears in rumors
	var test_team_id := ""
	for rumor in rumors:
		var r: Dictionary = rumor
		var tid := String(r.get("subject_team_id", ""))
		if not tid.is_empty():
			test_team_id = tid
			break

	if test_team_id.is_empty():
		t.skip("No team found in rumors")
		return

	var team_rumors := DraftRumorEngine.get_team_rumors(rumors, test_team_id)

	t.assert_true(team_rumors.size() > 0, "found rumors for team %s" % test_team_id)

	for rumor in team_rumors:
		var r: Dictionary = rumor
		t.assert_eq(String(r.get("subject_team_id", "")), test_team_id, "all filtered rumors match team")


## Test 10: Rumors survive serialization (Dictionary persistence)
func test_rumor_persistence(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 20}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 66666)

	# Simulate serialization by duplicating (deep copy)
	var serialized: Array = []
	for rumor in rumors:
		var r: Dictionary = rumor
		serialized.append(r.duplicate(true))

	t.assert_eq(serialized.size(), rumors.size(), "serialized count matches")

	for i in range(rumors.size()):
		var orig: Dictionary = rumors[i]
		var rest: Dictionary = serialized[i]

		t.assert_eq(orig.get("type"), rest.get("type"), "type preserved for rumor %d" % i)
		t.assert_eq(orig.get("accuracy"), rest.get("accuracy"), "accuracy preserved for rumor %d" % i)
		t.assert_eq(orig.get("text"), rest.get("text"), "text preserved for rumor %d" % i)
		t.assert_eq(orig.get("hours_before"), rest.get("hours_before"), "hours preserved for rumor %d" % i)


## Test 11: All rumors reference valid players and teams
func test_rumor_subject_validity(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 50}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 77777)

	# Build lookup sets
	var player_ids := {}
	for player in pool:
		var p: Dictionary = player
		player_ids[String(p.get("player_id", ""))] = true

	var team_ids := {}
	for team in teams:
		var t_dict: Dictionary = team
		team_ids[String(t_dict.get("id", ""))] = true

	# Check each rumor references valid subjects
	for rumor in rumors:
		var r: Dictionary = rumor
		var player_id := String(r.get("subject_player_id", ""))
		var team_id := String(r.get("subject_team_id", ""))

		t.assert_true(player_ids.has(player_id), "rumor references valid player: %s" % player_id)
		t.assert_true(team_ids.has(team_id), "rumor references valid team: %s" % team_id)


## Test 12: Rumors sorted by timestamp (reverse chronological)
func test_rumor_sorting(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var draft_order := _create_test_draft_order(224)
	var config := {"rumors": {"total_count": 120}}

	var rumors := DraftRumorEngine.generate_all_rumors(pool, teams, draft_order, config, 88888)

	var last_hours := 999
	for rumor in rumors:
		var r: Dictionary = rumor
		var hours := int(r.get("hours_before", 0))

		t.assert_true(hours <= last_hours, "rumors sorted: %d <= %d" % [hours, last_hours])
		last_hours = hours


# =========================
# Helper functions
# =========================

func _create_test_draft_pool(count: int) -> Array:
	var pool := []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]

	for i in range(count):
		pool.append({
			"player_id": "player_%d" % i,
			"id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": positions[i % positions.size()],
			"stats": {
				"speed": 60.0 + float(i % 30),
				"strength": 55.0 + float(i % 30)
			}
		})

	return pool


func _create_test_teams(count: int) -> Array:
	var teams := []
	for i in range(count):
		teams.append({
			"id": "team_%d" % i,
			"name": "Team %d" % i
		})
	return teams


func _create_test_draft_order(count: int) -> Array:
	var order := []
	for i in range(count):
		order.append({
			"overall_pick": i + 1,
			"round": (i / 32) + 1,
			"current_owner_id": "team_%d" % (i % 32)
		})
	return order


func _create_test_config() -> Dictionary:
	return {
		"rumors": {
			"total_count": 120,
			"accuracy_distribution": {
				"confirmed": 0.30,
				"likely": 0.50,
				"speculation": 0.20
			}
		}
	}
