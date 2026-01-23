extends GdUnitTestSuite
class_name TestTeamModelGdUnit4

const Team = preload("res://scripts/core/models/Team.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_team_initialization() -> void:
	var team = Team.new()
	assert_str(team.id).is_equal("")
	assert_str(team.name).is_equal("")
	assert_str(team.offensive_scheme).is_equal("pro_style")
	assert_str(team.defensive_scheme).is_equal("cover_2")
	assert_float(team.cap_limit).is_equal(0.0)
	assert_bool(team.is_over_cap).is_false()
	assert_float(team.league_cap).is_equal(0.0)
	assert_object(team.roster).is_not_null()

func test_team_scouting_budget_defaults() -> void:
	var team = Team.new()
	assert_bool(team.scouting_budget.has("annual_hours")).is_true()
	assert_bool(team.scouting_budget.has("spent_hours")).is_true()
	assert_int(team.scouting_budget["annual_hours"]).is_equal(8000)
	assert_int(team.scouting_budget["spent_hours"]).is_equal(0)

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_team_serialization_roundtrip() -> void:
	var team = Team.new()
	team.id = "TEAM_001"
	team.name = "Test Team"
	team.offensive_scheme = "spread"
	team.defensive_scheme = "cover_3"
	team.cap_limit = 10000000.0
	team.league_cap = 12000000.0
	team.is_over_cap = false
	team.roster.entries = [
		{
			"player_id": "P001",
			"status": "active",
			"cap_exempt": false,
			"contract": {"base_salary": 1000000.0}
		}
	]

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_str(restored.id).is_equal("TEAM_001")
	assert_str(restored.name).is_equal("Test Team")
	assert_str(restored.offensive_scheme).is_equal("spread")
	assert_str(restored.defensive_scheme).is_equal("cover_3")
	assert_float(restored.league_cap).is_equal(12000000.0)
	assert_bool(restored.is_over_cap).is_false()
	assert_array(restored.roster.entries).has_size(1)

func test_team_to_dict_schema() -> void:
	var team = Team.new()
	team.id = "TEAM_002"
	team.name = "Team 2"

	var dict = team.to_dict()

	assert_bool(dict.has("id")).is_true()
	assert_bool(dict.has("name")).is_true()
	assert_bool(dict.has("offensive_scheme")).is_true()
	assert_bool(dict.has("defensive_scheme")).is_true()
	assert_bool(dict.has("cap")).is_true()
	assert_bool(dict.has("is_over_cap")).is_true()
	assert_bool(dict.has("roster")).is_true()
	assert_bool(dict.has("scouting_data")).is_true()
	assert_bool(dict.has("scouting_budget")).is_true()

func test_team_to_dict_cap_structure() -> void:
	var team = Team.new()
	team.league_cap = 15000000.0
	team.roster.entries = [
		{
			"player_id": "P001",
			"cap_exempt": false,
			"contract": {"base_salary": 2000000.0}
		}
	]

	var dict = team.to_dict()
	var cap_dict = dict["cap"]

	assert_bool(cap_dict.has("league_cap")).is_true()
	assert_bool(cap_dict.has("cap_used")).is_true()
	assert_bool(cap_dict.has("cap_space")).is_true()
	assert_float(cap_dict["league_cap"]).is_equal(15000000.0)
	assert_float(cap_dict["cap_used"]).is_equal(2000000.0)
	assert_float(cap_dict["cap_space"]).is_equal(13000000.0)

func test_team_from_dict_empty() -> void:
	var team = Team.new()
	team.from_dict({})

	# Should preserve default values
	assert_str(team.id).is_equal("")
	assert_str(team.offensive_scheme).is_equal("pro_style")
	assert_object(team.roster).is_not_null()

func test_team_from_dict_backward_compatibility_cap_limit() -> void:
	var team = Team.new()
	var old_format = {
		"id": "TEAM_OLD",
		"cap": {
			"cap_limit": 10000000.0
		}
	}

	team.from_dict(old_format)

	# Old format should set league_cap from cap_limit
	assert_float(team.league_cap).is_equal(10000000.0)

# =============================================================================
# CAP CALCULATION TESTS
# =============================================================================

func test_team_cap_used_property() -> void:
	var team = Team.new()
	team.roster.entries = [
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

	assert_float(team.cap_used).is_equal(3000000.0)

func test_team_cap_space_property() -> void:
	var team = Team.new()
	team.league_cap = 15000000.0
	team.roster.entries = [
		{
			"player_id": "P001",
			"cap_exempt": false,
			"contract": {"base_salary": 5000000.0}
		}
	]

	assert_float(team.cap_space).is_equal(10000000.0)

func test_team_cap_used_null_roster() -> void:
	var team = Team.new()
	team.roster = null

	assert_float(team.cap_used).is_equal(0.0)

func test_team_cap_space_negative_when_over_cap() -> void:
	var team = Team.new()
	team.league_cap = 10000000.0
	team.roster.entries = [
		{
			"player_id": "P001",
			"cap_exempt": false,
			"contract": {"base_salary": 12000000.0}
		}
	]

	assert_float(team.cap_space).is_equal(-2000000.0)
	# Note: is_over_cap is a manual flag, not automatically updated

# =============================================================================
# PLAYER ID QUERY TESTS
# =============================================================================

func test_team_get_player_ids_active_only() -> void:
	var team = Team.new()
	team.roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "practice_squad"},
		{"player_id": "P003", "status": "active"}
	]

	var player_ids = team.get_player_ids(false)

	assert_array(player_ids).has_size(2)
	assert_array(player_ids).contains("P001")
	assert_array(player_ids).contains("P003")

func test_team_get_player_ids_include_inactive() -> void:
	var team = Team.new()
	team.roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "practice_squad"},
		{"player_id": "P003", "status": "ir"}
	]

	var player_ids = team.get_player_ids(true)

	assert_array(player_ids).has_size(3)
	assert_array(player_ids).contains("P001")
	assert_array(player_ids).contains("P002")
	assert_array(player_ids).contains("P003")

func test_team_get_active_player_ids() -> void:
	var team = Team.new()
	team.roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "ir"}
	]

	var active_ids = team.get_active_player_ids()

	assert_array(active_ids).has_size(1)
	assert_array(active_ids).contains("P001")

func test_team_get_all_player_ids() -> void:
	var team = Team.new()
	team.roster.entries = [
		{"player_id": "P001", "status": "active"},
		{"player_id": "P002", "status": "practice_squad"}
	]

	var all_ids = team.get_all_player_ids()

	assert_array(all_ids).has_size(2)

func test_team_get_player_ids_empty_roster() -> void:
	var team = Team.new()
	var player_ids = team.get_player_ids()

	assert_array(player_ids).is_empty()

func test_team_get_player_ids_missing_status() -> void:
	var team = Team.new()
	team.roster.entries = [
		{"player_id": "P001"}  # Missing status field
	]

	var player_ids = team.get_player_ids(false)

	# Should default to active
	assert_array(player_ids).has_size(1)

# =============================================================================
# SCHEME TESTS
# =============================================================================

func test_team_offensive_schemes() -> void:
	var schemes = ["pro_style", "spread", "west_coast", "air_raid"]

	for scheme in schemes:
		var team = Team.new()
		team.offensive_scheme = scheme

		var dict = team.to_dict()
		var restored = Team.new()
		restored.from_dict(dict)

		assert_str(restored.offensive_scheme).is_equal(scheme)

func test_team_defensive_schemes() -> void:
	var schemes = ["cover_2", "cover_3", "cover_4", "man_blitz"]

	for scheme in schemes:
		var team = Team.new()
		team.defensive_scheme = scheme

		var dict = team.to_dict()
		var restored = Team.new()
		restored.from_dict(dict)

		assert_str(restored.defensive_scheme).is_equal(scheme)

# =============================================================================
# SCOUTING TESTS
# =============================================================================

func test_team_scouting_data_serialization() -> void:
	var team = Team.new()
	team.scouting_data = {
		"P001": {"grade": 85, "notes": "Great prospect"},
		"P002": {"grade": 70, "notes": "Solid backup"}
	}

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_bool(restored.scouting_data.has("P001")).is_true()
	assert_bool(restored.scouting_data.has("P002")).is_true()
	assert_int(restored.scouting_data["P001"]["grade"]).is_equal(85)

func test_team_scouting_budget_serialization() -> void:
	var team = Team.new()
	team.scouting_budget = {
		"annual_hours": 10000,
		"spent_hours": 2500
	}

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_int(restored.scouting_budget["annual_hours"]).is_equal(10000)
	assert_int(restored.scouting_budget["spent_hours"]).is_equal(2500)

func test_team_scouting_data_deep_copy() -> void:
	var team = Team.new()
	team.scouting_data = {"P001": {"grade": 80}}

	var dict = team.to_dict()
	dict["scouting_data"]["P001"]["grade"] = 90

	# Original should not be affected
	assert_int(team.scouting_data["P001"]["grade"]).is_equal(80)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_team_empty_name() -> void:
	var team = Team.new()
	team.name = ""

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_str(restored.name).is_equal("")

func test_team_special_characters_in_name() -> void:
	var team = Team.new()
	team.name = "Team @#$% & Co."

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_str(restored.name).is_equal("Team @#$% & Co.")

func test_team_long_name() -> void:
	var team = Team.new()
	team.name = "The Extraordinarily Long Team Name That Goes On And On"

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_str(restored.name).is_equal("The Extraordinarily Long Team Name That Goes On And On")

func test_team_negative_cap_values() -> void:
	var team = Team.new()
	team.league_cap = -1000000.0

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	# Model doesn't clamp, so negative values are preserved
	assert_float(restored.league_cap).is_equal(-1000000.0)

func test_team_large_roster() -> void:
	var team = Team.new()
	for i in range(100):
		team.roster.entries.append({
			"player_id": "P%03d" % i,
			"status": "active",
			"cap_exempt": false,
			"contract": {"base_salary": 1000000.0}
		})

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_array(restored.roster.entries).has_size(100)
	assert_float(restored.cap_used).is_equal(100000000.0)

func test_team_null_roster() -> void:
	var team = Team.new()
	team.roster = null

	var dict = team.to_dict()

	# Should handle null roster gracefully
	assert_bool(dict.has("roster")).is_true()

func test_team_empty_scouting_data() -> void:
	var team = Team.new()
	team.scouting_data = {}

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_bool(restored.scouting_data.is_empty()).is_true()

func test_team_missing_roster_in_from_dict() -> void:
	var team = Team.new()
	var dict = {
		"id": "TEAM_003",
		"name": "Test Team"
		# No roster field
	}

	team.from_dict(dict)

	# Should create or preserve roster
	assert_object(team.roster).is_not_null()

func test_team_get_player_ids_null_roster() -> void:
	var team = Team.new()
	team.roster = null

	var player_ids = team.get_player_ids()

	assert_array(player_ids).is_empty()

func test_team_multiple_cap_calculations() -> void:
	var team = Team.new()
	team.league_cap = 20000000.0
	team.roster.entries = [
		{
			"player_id": "P001",
			"cap_exempt": false,
			"contract": {
				"base_salary": 3000000.0,
				"signing_bonus_proration": 500000.0,
				"guaranteed": 1000000.0,
				"incentives": 200000.0
			}
		},
		{
			"player_id": "P002",
			"cap_exempt": true,  # Should not count
			"contract": {
				"base_salary": 1000000.0
			}
		},
		{
			"player_id": "P003",
			"cap_exempt": false,
			"contract": {
				"base_salary": 2000000.0,
				"guaranteed": 500000.0
			}
		}
	]

	var expected_cap_used = (3000000.0 + 500000.0 + 1000000.0 + 200000.0) + (2000000.0 + 500000.0)
	assert_float(team.cap_used).is_equal(expected_cap_used)
	assert_float(team.cap_space).is_equal(20000000.0 - expected_cap_used)

func test_team_is_over_cap_manual_flag() -> void:
	var team = Team.new()
	team.is_over_cap = true

	var dict = team.to_dict()
	var restored = Team.new()
	restored.from_dict(dict)

	assert_bool(restored.is_over_cap).is_true()
