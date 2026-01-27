extends GdUnitTestSuite
class_name TestRosterModelGdUnit4

const Roster = preload("res://scripts/core/models/Roster.gd")
const DepthChart = preload("res://scripts/core/models/DepthChart.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_roster_initialization() -> void:
	var roster = Roster.new()
	assert_array(roster.entries).is_empty()
	assert_object(roster.depth_chart).is_null()

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_roster_serialization_roundtrip() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"status": "active",
			"cap_exempt": false,
			"contract": {
				"base_salary": 1000000.0,
				"signing_bonus_proration": 200000.0,
				"guaranteed": 0.0,
				"incentives": 50000.0,
				"dead_money": 0.0
			}
		},
		{
			"player_id": "P002",
			"status": "practice_squad",
			"cap_exempt": true,
			"cap_exempt_reason": "Practice squad",
			"contract": {
				"base_salary": 100000.0
			}
		}
	]

	var dict = roster.to_dict()
	var restored = Roster.new()
	restored.from_dict(dict)

	assert_array(restored.entries).has_size(2)
	assert_str(restored.entries[0]["player_id"]).is_equal("P001")
	assert_str(restored.entries[1]["player_id"]).is_equal("P002")

func test_roster_serialization_with_depth_chart() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "active"}
	]
	roster.depth_chart = DepthChart.new()
	roster.depth_chart.set_depth("QB", ["P001", "P002"])

	var dict = roster.to_dict()
	var restored = Roster.new()
	restored.from_dict(dict)

	assert_object(restored.depth_chart).is_not_null()
	assert_str(restored.depth_chart.get_starter("QB")).is_equal("P001")

func test_roster_to_dict_schema() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001"}]

	var dict = roster.to_dict()

	assert_bool(dict.has("format_version")).is_true()
	assert_bool(dict.has("entries")).is_true()
	assert_int(dict["format_version"]).is_equal(2)

func test_roster_from_dict_empty() -> void:
	var roster = Roster.new()
	roster.from_dict({})

	assert_array(roster.entries).is_empty()
	assert_object(roster.depth_chart).is_null()

func test_roster_backward_compatibility_no_depth_chart() -> void:
	var roster = Roster.new()
	var old_format = {
		"entries": [
			{"player_id": "P001", "status": "active"}
		]
	}

	roster.from_dict(old_format)

	assert_array(roster.entries).has_size(1)
	assert_object(roster.depth_chart).is_null()

# =============================================================================
# CAP CALCULATION TESTS
# =============================================================================

func test_roster_get_cap_used_single_player() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"status": "active",
			"cap_exempt": false,
			"contract": {
				"base_salary": 1000000.0,
				"signing_bonus_proration": 200000.0,
				"guaranteed": 0.0,
				"incentives": 50000.0
			}
		}
	]

	var cap_used = roster.get_cap_used()
	assert_float(cap_used).is_equal(1250000.0)

func test_roster_get_cap_used_multiple_players() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"cap_exempt": false,
			"contract": {"base_salary": 1000000.0}
		},
		{
			"player_id": "P002",
			"cap_exempt": false,
			"contract": {"base_salary": 2000000.0}
		}
	]

	var cap_used = roster.get_cap_used()
	assert_float(cap_used).is_equal(3000000.0)

func test_roster_get_cap_used_excludes_exempt() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"cap_exempt": false,
			"contract": {"base_salary": 1000000.0}
		},
		{
			"player_id": "P002",
			"cap_exempt": true,
			"contract": {"base_salary": 500000.0}
		}
	]

	var cap_used = roster.get_cap_used()
	assert_float(cap_used).is_equal(1000000.0)

func test_roster_get_cap_used_empty_roster() -> void:
	var roster = Roster.new()
	var cap_used = roster.get_cap_used()
	assert_float(cap_used).is_equal(0.0)

func test_roster_contract_cap_charge_static() -> void:
	var contract = {
		"base_salary": 1000000.0,
		"signing_bonus_proration": 250000.0,
		"guaranteed": 500000.0,
		"incentives": 100000.0,
		"dead_money": 200000.0  # Should not be included
	}

	var charge = Roster.contract_cap_charge(contract)
	assert_float(charge).is_equal(1850000.0)

# =============================================================================
# STATUS QUERY TESTS
# =============================================================================

func test_roster_get_players_by_status_active() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "practice_squad"},
		{"player_id": "P003", "status": "active"}
	]

	var active_players = roster.get_players_by_status(Roster.RosterStatus.ACTIVE)

	assert_array(active_players).has_size(2)

func test_roster_get_players_by_status_practice_squad() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "practice_squad"}
	]

	var ps_players = roster.get_players_by_status(Roster.RosterStatus.PRACTICE_SQUAD)

	assert_array(ps_players).has_size(1)
	assert_str(ps_players[0]["player_id"]).is_equal("P002")

func test_roster_get_status_count() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "active"},
		{"player_id": "P003", "status": "ir"}
	]

	assert_int(roster.get_status_count(Roster.RosterStatus.ACTIVE)).is_equal(2)
	assert_int(roster.get_status_count(Roster.RosterStatus.INJURED_RESERVE)).is_equal(1)
	assert_int(roster.get_status_count(Roster.RosterStatus.PRACTICE_SQUAD)).is_equal(0)

# =============================================================================
# ROSTER MOVEMENT TESTS
# =============================================================================

func test_roster_move_to_practice_squad() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active", "cap_exempt": false}
	]

	var success = roster.move_to_practice_squad("P001")

	assert_bool(success).is_true()
	assert_str(roster.entries[0]["status"]).is_equal("practice_squad")
	assert_bool(roster.entries[0]["cap_exempt"]).is_true()
	assert_str(roster.entries[0]["cap_exempt_reason"]).is_equal("Practice squad")

func test_roster_move_to_practice_squad_removes_from_depth_chart() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001", "status": "active"}]
	roster.depth_chart = DepthChart.new()
	roster.depth_chart.set_depth("QB", ["P001"])

	roster.move_to_practice_squad("P001")

	assert_array(roster.depth_chart.get_depth("QB")).is_empty()

func test_roster_move_to_practice_squad_player_not_found() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001"}]

	var success = roster.move_to_practice_squad("P999")

	assert_bool(success).is_false()

func test_roster_promote_from_practice_squad() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"status": "practice_squad",
			"cap_exempt": true,
			"cap_exempt_reason": "Practice squad"
		}
	]

	var success = roster.promote_from_practice_squad("P001")

	assert_bool(success).is_true()
	assert_str(roster.entries[0]["status"]).is_equal("active")
	assert_bool(roster.entries[0]["cap_exempt"]).is_false()
	assert_str(roster.entries[0]["cap_exempt_reason"]).is_equal("")

func test_roster_promote_from_practice_squad_non_ps_player() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001", "status": "active"}]

	var success = roster.promote_from_practice_squad("P001")

	assert_bool(success).is_false()

func test_roster_place_on_ir() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active", "cap_exempt": false}
	]

	var success = roster.place_on_ir("P001", 8)

	assert_bool(success).is_true()
	assert_str(roster.entries[0]["status"]).is_equal("ir")
	assert_bool(roster.entries[0]["cap_exempt"]).is_true()
	assert_str(roster.entries[0]["cap_exempt_reason"]).is_equal("Injured reserve")
	assert_int(roster.entries[0]["ir_eligible_week"]).is_equal(8)

func test_roster_place_on_ir_removes_from_depth_chart() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001", "status": "active"}]
	roster.depth_chart = DepthChart.new()
	roster.depth_chart.set_depth("RB", ["P001", "P002"])

	roster.place_on_ir("P001", 0)

	assert_array(roster.depth_chart.get_depth("RB")).contains_exactly(["P002"])

func test_roster_place_on_ir_season_ending() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001", "status": "active"}]

	roster.place_on_ir("P001", 0)  # 0 = season-ending

	assert_int(roster.entries[0]["ir_eligible_week"]).is_equal(0)

func test_roster_activate_from_ir() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"status": "ir",
			"cap_exempt": true,
			"cap_exempt_reason": "Injured reserve",
			"ir_eligible_week": 8
		}
	]

	var success = roster.activate_from_ir("P001")

	assert_bool(success).is_true()
	assert_str(roster.entries[0]["status"]).is_equal("active")
	assert_bool(roster.entries[0]["cap_exempt"]).is_false()
	assert_str(roster.entries[0]["cap_exempt_reason"]).is_equal("")
	assert_int(roster.entries[0]["ir_eligible_week"]).is_equal(0)

func test_roster_activate_from_ir_non_ir_player() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001", "status": "active"}]

	var success = roster.activate_from_ir("P001")

	assert_bool(success).is_false()

# =============================================================================
# INTERNAL HELPER TESTS
# =============================================================================

func test_roster_status_enum_to_string() -> void:
	assert_str(Roster._status_enum_to_string(Roster.RosterStatus.ACTIVE)).is_equal("active")
	assert_str(Roster._status_enum_to_string(Roster.RosterStatus.PRACTICE_SQUAD)).is_equal("practice_squad")
	assert_str(Roster._status_enum_to_string(Roster.RosterStatus.INJURED_RESERVE)).is_equal("ir")
	assert_str(Roster._status_enum_to_string(Roster.RosterStatus.SUSPENDED)).is_equal("suspended")

func test_roster_status_string_to_enum() -> void:
	assert_int(Roster._status_string_to_enum("active")).is_equal(Roster.RosterStatus.ACTIVE)
	assert_int(Roster._status_string_to_enum("practice_squad")).is_equal(Roster.RosterStatus.PRACTICE_SQUAD)
	assert_int(Roster._status_string_to_enum("ir")).is_equal(Roster.RosterStatus.INJURED_RESERVE)
	assert_int(Roster._status_string_to_enum("suspended")).is_equal(Roster.RosterStatus.SUSPENDED)

func test_roster_status_string_to_enum_unknown_defaults_to_active() -> void:
	assert_int(Roster._status_string_to_enum("unknown")).is_equal(Roster.RosterStatus.ACTIVE)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_roster_empty_contract_in_entry() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "cap_exempt": false}
	]

	var cap_used = roster.get_cap_used()
	assert_float(cap_used).is_equal(0.0)

func test_roster_move_player_with_multiple_cap_exemptions() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"status": "practice_squad",
			"cap_exempt": true,
			"cap_exempt_reason": "Other reason"  # Not "Practice squad"
		}
	]

	roster.promote_from_practice_squad("P001")

	# Should not clear cap_exempt since reason is different
	assert_bool(roster.entries[0]["cap_exempt"]).is_true()

func test_roster_activate_from_ir_with_other_exemption() -> void:
	var roster = Roster.new()
	roster.entries = [
		{
			"player_id": "P001",
			"status": "ir",
			"cap_exempt": true,
			"cap_exempt_reason": "Other reason"  # Not "Injured reserve"
		}
	]

	roster.activate_from_ir("P001")

	# Should not clear cap_exempt since reason is different
	assert_bool(roster.entries[0]["cap_exempt"]).is_true()

func test_roster_duplicate_player_ids() -> void:
	var roster = Roster.new()
	roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P001", "status": "practice_squad"}  # Duplicate
	]

	# Should handle gracefully - first match is used
	var success = roster.move_to_practice_squad("P001")
	assert_bool(success).is_true()

func test_roster_large_roster() -> void:
	var roster = Roster.new()
	for i in range(100):
		roster.entries.append({
			"player_id": "P%03d" % i,
			"status": "active",
			"cap_exempt": false,
			"contract": {"base_salary": 1000000.0}
		})

	var cap_used = roster.get_cap_used()
	assert_float(cap_used).is_equal(100000000.0)

func test_roster_null_depth_chart_operations() -> void:
	var roster = Roster.new()
	roster.entries = [{"player_id": "P001", "status": "active"}]
	roster.depth_chart = null

	# Should not crash when depth_chart is null
	var success = roster.move_to_practice_squad("P001")
	assert_bool(success).is_true()
