extends GdUnitTestSuite
class_name TestPlayerModelGdUnit4

const Player = preload("res://scripts/core/models/Player.gd")
const Contract = preload("res://scripts/core/models/Contract.gd")
const PlayerPhysicals = preload("res://scripts/core/models/PlayerPhysicals.gd")
const StatsProfile = preload("res://scripts/core/models/StatsProfile.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_player_initialization() -> void:
	var player = Player.new()
	assert_str(player.id).is_equal("")
	assert_str(player.position).is_equal("ATH")
	assert_int(player.age).is_equal(18)
	assert_int(player.stage).is_equal(Player.PlayerStage.HIGH_SCHOOL)
	assert_str(player.class_tag).is_equal("")
	assert_int(player.jersey_number).is_equal(0)
	assert_int(player.class_year).is_equal(4)
	assert_bool(player.declared_for_draft).is_false()

func test_player_sub_resources_initialized() -> void:
	var player = Player.new()
	assert_object(player.contract).is_not_null()
	assert_object(player.physicals).is_not_null()
	assert_object(player.combine).is_not_null()
	assert_object(player.trait_set).is_not_null()
	assert_object(player.career).is_not_null()
	assert_object(player.health).is_not_null()
	assert_object(player.stats_profile).is_not_null()

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_player_serialization_roundtrip() -> void:
	var player = Player.new()
	player.id = "P001"
	player.first_name = "John"
	player.last_name = "Doe"
	player.position = "QB"
	player.age = 22
	player.stage = Player.PlayerStage.COLLEGE
	player.jersey_number = 12
	player.class_year = 3

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.id).is_equal("P001")
	assert_str(restored.first_name).is_equal("John")
	assert_str(restored.last_name).is_equal("Doe")
	assert_str(restored.position).is_equal("QB")
	assert_int(restored.age).is_equal(22)
	assert_int(restored.stage).is_equal(Player.PlayerStage.COLLEGE)
	assert_int(restored.jersey_number).is_equal(12)
	assert_int(restored.class_year).is_equal(3)

func test_player_to_dict_schema() -> void:
	var player = Player.new()
	player.id = "P002"

	var dict = player.to_dict()

	# Person fields
	assert_bool(dict.has("id")).is_true()
	assert_bool(dict.has("first_name")).is_true()
	assert_bool(dict.has("last_name")).is_true()
	# Player fields
	assert_bool(dict.has("position")).is_true()
	assert_bool(dict.has("age")).is_true()
	assert_bool(dict.has("stage")).is_true()
	assert_bool(dict.has("class_tag")).is_true()
	assert_bool(dict.has("jersey_number")).is_true()
	assert_bool(dict.has("class_year")).is_true()
	assert_bool(dict.has("declared_for_draft")).is_true()
	# Sub-resources
	assert_bool(dict.has("contract")).is_true()
	assert_bool(dict.has("physicals")).is_true()
	assert_bool(dict.has("combine")).is_true()
	assert_bool(dict.has("stats_profile")).is_true()
	assert_bool(dict.has("trait_set")).is_true()
	assert_bool(dict.has("career")).is_true()
	assert_bool(dict.has("health")).is_true()
	assert_bool(dict.has("draft_intelligence")).is_true()

func test_player_from_dict_empty() -> void:
	var player = Player.new()
	player.from_dict({})

	# Should preserve default values
	assert_str(player.position).is_equal("ATH")
	assert_int(player.age).is_equal(18)
	assert_int(player.stage).is_equal(Player.PlayerStage.HIGH_SCHOOL)

func test_player_physicals_nested_format() -> void:
	var player = Player.new()
	player.physicals.height_in = 76.0
	player.physicals.weight_lb = 225.0

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_float(restored.physicals.height_in).is_equal(76.0)
	assert_float(restored.physicals.weight_lb).is_equal(225.0)

func test_player_stats_profile_nested_format() -> void:
	var player = Player.new()
	player.stats_profile.current = {"speed": 85.0, "strength": 70.0}
	player.stats_profile.potential = {"speed": 92.0, "strength": 80.0}

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_float(restored.stats_profile.get_stat("speed")).is_equal(85.0)
	assert_float(restored.stats_profile.get_potential("strength")).is_equal(80.0)

func test_player_contract_nested_format() -> void:
	var player = Player.new()
	player.contract.current_year = 2
	player.contract.total_years = 5
	player.contract.annual_value = 5000000.0

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_int(restored.contract.current_year).is_equal(2)
	assert_int(restored.contract.total_years).is_equal(5)
	assert_float(restored.contract.annual_value).is_equal(5000000.0)

# =============================================================================
# BACKWARD COMPATIBILITY TESTS
# =============================================================================

func test_player_from_dict_legacy_physicals_flat() -> void:
	var player = Player.new()
	var legacy_dict = {
		"id": "P_OLD",
		"height_in": 74.0,
		"weight_lb": 210.0,
		"hand_size_in": 9.5
	}

	player.from_dict(legacy_dict)

	assert_float(player.physicals.height_in).is_equal(74.0)
	assert_float(player.physicals.weight_lb).is_equal(210.0)
	assert_float(player.physicals.hand_size_in).is_equal(9.5)

func test_player_from_dict_legacy_stats_flat() -> void:
	var player = Player.new()
	var legacy_dict = {
		"id": "P_OLD",
		"stats": {"speed": 80.0, "strength": 75.0},
		"potential": {"speed": 90.0, "strength": 85.0}
	}

	player.from_dict(legacy_dict)

	assert_float(player.stats_profile.get_stat("speed")).is_equal(80.0)
	assert_float(player.stats_profile.get_potential("strength")).is_equal(85.0)

func test_player_from_dict_stage_inference() -> void:
	var player = Player.new()
	var old_dict = {
		"id": "P_OLD",
		"age": 20,
		"school_tag": "COLLEGE_A"
		# No stage field
	}

	player.from_dict(old_dict)

	# Should infer COLLEGE stage
	assert_int(player.stage).is_equal(Player.PlayerStage.COLLEGE)

func test_player_from_dict_class_year_inference() -> void:
	var player = Player.new()
	var old_dict = {
		"id": "P_OLD",
		"age": 19
		# No class_year field
	}

	player.from_dict(old_dict)

	# Should infer class_year = 2 (age 19 -> sophomore)
	assert_int(player.class_year).is_equal(2)

# =============================================================================
# STAGE TRANSITION TESTS
# =============================================================================

func test_player_transition_high_school_to_college() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.HIGH_SCHOOL

	var success = player.transition_to(Player.PlayerStage.COLLEGE)

	assert_bool(success).is_true()
	assert_int(player.stage).is_equal(Player.PlayerStage.COLLEGE)

func test_player_transition_college_to_draft_eligible() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.COLLEGE

	var success = player.transition_to(Player.PlayerStage.DRAFT_ELIGIBLE)

	assert_bool(success).is_true()
	assert_int(player.stage).is_equal(Player.PlayerStage.DRAFT_ELIGIBLE)

func test_player_transition_draft_eligible_to_nfl_rookie() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.DRAFT_ELIGIBLE

	var success = player.transition_to(Player.PlayerStage.NFL_ROOKIE)

	assert_bool(success).is_true()
	assert_int(player.stage).is_equal(Player.PlayerStage.NFL_ROOKIE)

func test_player_transition_nfl_rookie_to_veteran() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.NFL_ROOKIE

	var success = player.transition_to(Player.PlayerStage.NFL_VETERAN)

	assert_bool(success).is_true()
	assert_int(player.stage).is_equal(Player.PlayerStage.NFL_VETERAN)

func test_player_transition_veteran_to_free_agent() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.NFL_VETERAN

	var success = player.transition_to(Player.PlayerStage.NFL_FREE_AGENT)

	assert_bool(success).is_true()
	assert_int(player.stage).is_equal(Player.PlayerStage.NFL_FREE_AGENT)

func test_player_transition_to_retired() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.NFL_VETERAN

	var success = player.transition_to(Player.PlayerStage.RETIRED)

	assert_bool(success).is_true()
	assert_int(player.stage).is_equal(Player.PlayerStage.RETIRED)

func test_player_transition_invalid() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.HIGH_SCHOOL

	# Cannot transition directly to NFL_ROOKIE from HIGH_SCHOOL
	var success = player.transition_to(Player.PlayerStage.NFL_ROOKIE)

	assert_bool(success).is_false()
	assert_int(player.stage).is_equal(Player.PlayerStage.HIGH_SCHOOL)

func test_player_transition_retired_to_any() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.RETIRED

	var success = player.transition_to(Player.PlayerStage.NFL_VETERAN)

	# Retired players cannot transition to any stage
	assert_bool(success).is_false()

func test_player_transition_college_stays_in_college() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.COLLEGE

	# Valid to stay in COLLEGE (multi-year)
	var success = player.transition_to(Player.PlayerStage.COLLEGE)

	assert_bool(success).is_true()

# =============================================================================
# STAGE QUERY TESTS
# =============================================================================

func test_player_is_nfl_player_rookie() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.NFL_ROOKIE

	assert_bool(player.is_nfl_player()).is_true()

func test_player_is_nfl_player_veteran() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.NFL_VETERAN

	assert_bool(player.is_nfl_player()).is_true()

func test_player_is_nfl_player_college() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.COLLEGE

	assert_bool(player.is_nfl_player()).is_false()

func test_player_is_available_for_draft() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.DRAFT_ELIGIBLE

	assert_bool(player.is_available_for_draft()).is_true()

func test_player_is_college_player() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.COLLEGE

	assert_bool(player.is_college_player()).is_true()

func test_player_is_high_school_player() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.HIGH_SCHOOL

	assert_bool(player.is_high_school_player()).is_true()

func test_player_is_free_agent() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.NFL_FREE_AGENT

	assert_bool(player.is_free_agent()).is_true()

func test_player_is_retired() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.RETIRED

	assert_bool(player.is_retired()).is_true()

# =============================================================================
# STATS TESTS
# =============================================================================

func test_player_get_stat() -> void:
	var player = Player.new()
	player.stats_profile.current = {"speed": 85.0}

	var stat = player.get_stat("speed")

	assert_float(stat).is_equal(85.0)

func test_player_get_stat_missing() -> void:
	var player = Player.new()

	var stat = player.get_stat("nonexistent")

	assert_float(stat).is_equal(0.0)

func test_player_set_stat() -> void:
	var player = Player.new()
	player.set_stat("strength", 90.0)

	assert_float(player.stats_profile.current["strength"]).is_equal(90.0)

func test_player_set_stat_null_stats_profile() -> void:
	var player = Player.new()
	player.stats_profile = null

	# Should not crash
	player.set_stat("speed", 85.0)

	assert_object(player.stats_profile).is_null()

# =============================================================================
# BUSINESS LOGIC TESTS
# =============================================================================

func test_player_get_full_name() -> void:
	var player = Player.new()
	player.first_name = "Tom"
	player.last_name = "Brady"

	assert_str(player.get_full_name()).is_equal("Tom Brady")

func test_player_jersey_number_clamped() -> void:
	var player = Player.new()
	var dict = {"jersey_number": 150}

	player.from_dict(dict)

	# Should be clamped to 0-99
	assert_int(player.jersey_number).is_equal(99)

func test_player_jersey_number_negative_clamped() -> void:
	var player = Player.new()
	var dict = {"jersey_number": -5}

	player.from_dict(dict)

	# Should be clamped to 0-99
	assert_int(player.jersey_number).is_equal(0)

func test_player_class_year_clamped() -> void:
	var player = Player.new()
	var dict = {"class_year": 10}

	player.from_dict(dict)

	# Should be clamped to 1-4
	assert_int(player.class_year).is_equal(4)

func test_player_class_year_zero_clamped() -> void:
	var player = Player.new()
	var dict = {"class_year": 0}

	player.from_dict(dict)

	# Should be clamped to 1-4
	assert_int(player.class_year).is_equal(1)

func test_player_declared_for_draft_flag() -> void:
	var player = Player.new()
	player.declared_for_draft = true

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_bool(restored.declared_for_draft).is_true()

func test_player_draft_intelligence() -> void:
	var player = Player.new()
	player.draft_intelligence = {
		"red_flags": [{"type": "injury", "severity": "moderate"}],
		"mock_history": [{"round": 2, "pick": 5}],
		"scouting_report": {"grade": 85},
		"shortlisted_by": ["TEAM_001", "TEAM_002"]
	}

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_bool(restored.draft_intelligence.has("red_flags")).is_true()
	assert_array(restored.draft_intelligence["shortlisted_by"]).has_size(2)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_player_position_variants() -> void:
	var positions = ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]

	for pos in positions:
		var player = Player.new()
		player.position = pos

		var dict = player.to_dict()
		var restored = Player.new()
		restored.from_dict(dict)

		assert_str(restored.position).is_equal(pos)

func test_player_special_characters_in_name() -> void:
	var player = Player.new()
	player.first_name = "D'Marcus"
	player.last_name = "O'Brien-Jones"

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.first_name).is_equal("D'Marcus")
	assert_str(restored.last_name).is_equal("O'Brien-Jones")

func test_player_age_boundaries() -> void:
	var player = Player.new()

	# Test young age
	player.age = 16
	assert_int(player.age).is_equal(16)

	# Test old age
	player.age = 45
	assert_int(player.age).is_equal(45)

func test_player_empty_class_tag() -> void:
	var player = Player.new()
	player.class_tag = ""

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.class_tag).is_equal("")

func test_player_long_class_tag() -> void:
	var player = Player.new()
	player.class_tag = "CLASS_OF_2033_EARLY_ENROLLEE"

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.class_tag).is_equal("CLASS_OF_2033_EARLY_ENROLLEE")

func test_player_null_sub_resources_from_dict() -> void:
	var player = Player.new()
	player.contract = null
	player.physicals = null
	player.stats_profile = null

	var dict = {
		"id": "P_NULL",
		"position": "QB"
	}

	# Should create new resources
	player.from_dict(dict)

	assert_object(player.contract).is_not_null()
	assert_object(player.physicals).is_not_null()
	assert_object(player.stats_profile).is_not_null()

func test_player_gen_mode_variants() -> void:
	var modes = ["quota", "gauss", "chaos", "custom"]

	for mode in modes:
		var player = Player.new()
		player.gen_mode = mode

		var dict = player.to_dict()
		var restored = Player.new()
		restored.from_dict(dict)

		assert_str(restored.gen_mode).is_equal(mode)

func test_player_school_tag() -> void:
	var player = Player.new()
	player.school_tag = "ALABAMA"

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.school_tag).is_equal("ALABAMA")

func test_player_notes_field() -> void:
	var player = Player.new()
	player.notes = "Excellent prospect with high upside"

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.notes).is_equal("Excellent prospect with high upside")

func test_player_complex_serialization() -> void:
	var player = Player.new()
	player.id = "P_COMPLEX"
	player.first_name = "Complex"
	player.last_name = "Player"
	player.position = "QB"
	player.age = 21
	player.stage = Player.PlayerStage.DRAFT_ELIGIBLE
	player.class_year = 3
	player.declared_for_draft = true
	player.jersey_number = 7

	# Set physicals
	player.physicals.height_in = 76.0
	player.physicals.weight_lb = 225.0

	# Set stats
	player.stats_profile.current = {"speed": 85.0, "strength": 75.0, "accuracy": 90.0}
	player.stats_profile.potential = {"speed": 92.0, "strength": 82.0, "accuracy": 95.0}

	# Set contract
	player.contract.current_year = 0
	player.contract.total_years = 0

	var dict = player.to_dict()
	var restored = Player.new()
	restored.from_dict(dict)

	assert_str(restored.id).is_equal("P_COMPLEX")
	assert_str(restored.position).is_equal("QB")
	assert_int(restored.age).is_equal(21)
	assert_float(restored.physicals.height_in).is_equal(76.0)
	assert_float(restored.stats_profile.get_stat("accuracy")).is_equal(90.0)
	assert_bool(restored.declared_for_draft).is_true()

func test_player_multiple_stage_queries() -> void:
	var player = Player.new()
	player.stage = Player.PlayerStage.COLLEGE

	assert_bool(player.is_college_player()).is_true()
	assert_bool(player.is_nfl_player()).is_false()
	assert_bool(player.is_high_school_player()).is_false()
	assert_bool(player.is_available_for_draft()).is_false()
	assert_bool(player.is_free_agent()).is_false()
	assert_bool(player.is_retired()).is_false()
