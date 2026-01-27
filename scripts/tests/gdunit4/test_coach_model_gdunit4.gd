extends GdUnitTestSuite
class_name TestCoachModelGdUnit4

const Coach = preload("res://scripts/core/models/Coach.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_coach_initialization() -> void:
	var coach = Coach.new()
	assert_str(coach.id).is_equal("")
	assert_str(coach.first_name).is_equal("")
	assert_str(coach.last_name).is_equal("")
	assert_str(coach.role).is_equal("")
	assert_float(coach.coaching_ability).is_equal(50.0)
	assert_float(coach.recruiting_skill).is_equal(50.0)
	assert_float(coach.player_development).is_equal(50.0)
	assert_int(coach.experience_years).is_equal(0)
	assert_str(coach.specialty_position).is_equal("")
	assert_str(coach.scheme_preference).is_equal("")

func test_coach_new_with_scheme_system() -> void:
	var coach = Coach.new()
	assert_str(coach.offensive_scheme).is_equal("")
	assert_str(coach.defensive_scheme).is_equal("")
	assert_float(coach.scheme_rigidity).is_equal(1.0)

func test_coach_new_with_evaluation_philosophy() -> void:
	var coach = Coach.new()
	assert_str(coach.character_tolerance).is_equal("moderate")
	assert_str(coach.medical_tolerance).is_equal("cautious")

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_coach_serialization_roundtrip() -> void:
	var coach = Coach.new()
	coach.id = "COACH_001"
	coach.first_name = "John"
	coach.last_name = "Smith"
	coach.role = "Head Coach"
	coach.coaching_ability = 85.0
	coach.recruiting_skill = 75.0
	coach.player_development = 80.0
	coach.experience_years = 15
	coach.specialty_position = "QB"
	coach.offensive_scheme = "west_coast"
	coach.defensive_scheme = "cover_3"
	coach.scheme_rigidity = 1.2
	coach.character_tolerance = "strict"
	coach.medical_tolerance = "risk_averse"

	var dict = coach.to_dict()
	var restored = Coach.new()
	restored.from_dict(dict)

	# Person fields
	assert_str(restored.id).is_equal("COACH_001")
	assert_str(restored.first_name).is_equal("John")
	assert_str(restored.last_name).is_equal("Smith")
	# Coach fields
	assert_str(restored.role).is_equal("Head Coach")
	assert_float(restored.coaching_ability).is_equal(85.0)
	assert_float(restored.recruiting_skill).is_equal(75.0)
	assert_float(restored.player_development).is_equal(80.0)
	assert_int(restored.experience_years).is_equal(15)
	assert_str(restored.specialty_position).is_equal("QB")
	assert_str(restored.offensive_scheme).is_equal("west_coast")
	assert_str(restored.defensive_scheme).is_equal("cover_3")
	assert_float(restored.scheme_rigidity).is_equal(1.2)
	assert_str(restored.character_tolerance).is_equal("strict")
	assert_str(restored.medical_tolerance).is_equal("risk_averse")

func test_coach_to_dict_schema() -> void:
	var coach = Coach.new()
	coach.id = "COACH_002"
	coach.first_name = "Jane"
	coach.last_name = "Doe"

	var dict = coach.to_dict()

	# Person fields
	assert_bool(dict.has("id")).is_true()
	assert_bool(dict.has("first_name")).is_true()
	assert_bool(dict.has("last_name")).is_true()
	# Coach fields
	assert_bool(dict.has("role")).is_true()
	assert_bool(dict.has("coaching_ability")).is_true()
	assert_bool(dict.has("recruiting_skill")).is_true()
	assert_bool(dict.has("player_development")).is_true()
	assert_bool(dict.has("experience_years")).is_true()
	assert_bool(dict.has("specialty_position")).is_true()
	assert_bool(dict.has("scheme_preference")).is_true()
	assert_bool(dict.has("offensive_scheme")).is_true()
	assert_bool(dict.has("defensive_scheme")).is_true()
	assert_bool(dict.has("scheme_rigidity")).is_true()
	assert_bool(dict.has("character_tolerance")).is_true()
	assert_bool(dict.has("medical_tolerance")).is_true()

func test_coach_from_dict_with_missing_fields() -> void:
	var coach = Coach.new()
	var partial_dict = {
		"id": "COACH_003",
		"first_name": "Bob",
		"coaching_ability": 70.0
	}

	coach.from_dict(partial_dict)

	assert_str(coach.id).is_equal("COACH_003")
	assert_str(coach.first_name).is_equal("Bob")
	assert_float(coach.coaching_ability).is_equal(70.0)
	# Missing fields should have defaults
	assert_str(coach.last_name).is_equal("")
	assert_float(coach.recruiting_skill).is_equal(50.0)

func test_coach_from_dict_empty() -> void:
	var coach = Coach.new()
	coach.from_dict({})

	# Should preserve default values
	assert_str(coach.id).is_equal("")
	assert_str(coach.role).is_equal("")
	assert_float(coach.coaching_ability).is_equal(50.0)

# =============================================================================
# BUSINESS LOGIC TESTS
# =============================================================================

func test_coach_get_full_name() -> void:
	var coach = Coach.new()
	coach.first_name = "Bill"
	coach.last_name = "Belichick"

	assert_str(coach.get_full_name()).is_equal("Bill Belichick")

func test_coach_get_full_name_with_extra_spaces() -> void:
	var coach = Coach.new()
	coach.first_name = "  Mike  "
	coach.last_name = "  Tomlin  "

	# get_full_name should strip edges
	assert_str(coach.get_full_name()).is_equal("Mike   Tomlin")

func test_coach_get_full_name_missing_last_name() -> void:
	var coach = Coach.new()
	coach.first_name = "Andy"
	coach.last_name = ""

	assert_str(coach.get_full_name()).is_equal("Andy")

func test_coach_get_full_name_missing_first_name() -> void:
	var coach = Coach.new()
	coach.first_name = ""
	coach.last_name = "Reid"

	assert_str(coach.get_full_name()).is_equal("Reid")

func test_coach_get_full_name_both_empty() -> void:
	var coach = Coach.new()
	coach.first_name = ""
	coach.last_name = ""

	assert_str(coach.get_full_name()).is_equal("")

# =============================================================================
# COACHING ATTRIBUTES TESTS
# =============================================================================

func test_coach_attributes_within_valid_range() -> void:
	var coach = Coach.new()
	coach.coaching_ability = 75.0
	coach.recruiting_skill = 60.0
	coach.player_development = 85.0

	assert_float(coach.coaching_ability).is_between(0.0, 100.0)
	assert_float(coach.recruiting_skill).is_between(0.0, 100.0)
	assert_float(coach.player_development).is_between(0.0, 100.0)

func test_coach_minimum_attributes() -> void:
	var coach = Coach.new()
	coach.coaching_ability = 0.0
	coach.recruiting_skill = 0.0
	coach.player_development = 0.0

	assert_float(coach.coaching_ability).is_equal(0.0)
	assert_float(coach.recruiting_skill).is_equal(0.0)
	assert_float(coach.player_development).is_equal(0.0)

func test_coach_maximum_attributes() -> void:
	var coach = Coach.new()
	coach.coaching_ability = 100.0
	coach.recruiting_skill = 100.0
	coach.player_development = 100.0

	assert_float(coach.coaching_ability).is_equal(100.0)
	assert_float(coach.recruiting_skill).is_equal(100.0)
	assert_float(coach.player_development).is_equal(100.0)

# =============================================================================
# SCHEME SYSTEM TESTS
# =============================================================================

func test_coach_scheme_preferences() -> void:
	var coach = Coach.new()
	coach.offensive_scheme = "spread"
	coach.defensive_scheme = "cover_2"

	var dict = coach.to_dict()
	var restored = Coach.new()
	restored.from_dict(dict)

	assert_str(restored.offensive_scheme).is_equal("spread")
	assert_str(restored.defensive_scheme).is_equal("cover_2")

func test_coach_scheme_rigidity_flexible() -> void:
	var coach = Coach.new()
	coach.scheme_rigidity = 0.5

	assert_float(coach.scheme_rigidity).is_equal(0.5)

func test_coach_scheme_rigidity_rigid() -> void:
	var coach = Coach.new()
	coach.scheme_rigidity = 1.5

	assert_float(coach.scheme_rigidity).is_equal(1.5)

# =============================================================================
# EVALUATION PHILOSOPHY TESTS
# =============================================================================

func test_coach_character_tolerance_variants() -> void:
	var tolerance_levels = ["strict", "moderate", "lenient", "win_now"]

	for level in tolerance_levels:
		var coach = Coach.new()
		coach.character_tolerance = level

		var dict = coach.to_dict()
		var restored = Coach.new()
		restored.from_dict(dict)

		assert_str(restored.character_tolerance).is_equal(level)

func test_coach_medical_tolerance_variants() -> void:
	var tolerance_levels = ["risk_averse", "cautious", "moderate_risk", "aggressive"]

	for level in tolerance_levels:
		var coach = Coach.new()
		coach.medical_tolerance = level

		var dict = coach.to_dict()
		var restored = Coach.new()
		restored.from_dict(dict)

		assert_str(restored.medical_tolerance).is_equal(level)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_coach_with_special_characters_in_name() -> void:
	var coach = Coach.new()
	coach.first_name = "José"
	coach.last_name = "O'Brien"

	var dict = coach.to_dict()
	var restored = Coach.new()
	restored.from_dict(dict)

	assert_str(restored.first_name).is_equal("José")
	assert_str(restored.last_name).is_equal("O'Brien")

func test_coach_with_long_names() -> void:
	var coach = Coach.new()
	coach.first_name = "Maximillian-Alexander-Friedrich"
	coach.last_name = "von Hohenstein-Württemberg"

	var dict = coach.to_dict()
	var restored = Coach.new()
	restored.from_dict(dict)

	assert_str(restored.first_name).is_equal("Maximillian-Alexander-Friedrich")
	assert_str(restored.last_name).is_equal("von Hohenstein-Württemberg")

func test_coach_experience_years_negative() -> void:
	var coach = Coach.new()
	var dict = {"experience_years": -5}

	coach.from_dict(dict)

	# Model doesn't clamp, so negative values are possible
	assert_int(coach.experience_years).is_equal(-5)

func test_coach_experience_years_large() -> void:
	var coach = Coach.new()
	coach.experience_years = 50

	var dict = coach.to_dict()
	var restored = Coach.new()
	restored.from_dict(dict)

	assert_int(restored.experience_years).is_equal(50)

func test_coach_attributes_above_100() -> void:
	var coach = Coach.new()
	coach.coaching_ability = 150.0

	var dict = coach.to_dict()
	var restored = Coach.new()
	restored.from_dict(dict)

	# Model doesn't clamp, so values above 100 are preserved
	assert_float(restored.coaching_ability).is_equal(150.0)

func test_coach_backward_compatibility_scheme_preference() -> void:
	var coach = Coach.new()
	var dict = {
		"id": "COACH_OLD",
		"scheme_preference": "pro_style"  # Legacy field
	}

	coach.from_dict(dict)

	assert_str(coach.scheme_preference).is_equal("pro_style")

func test_coach_multiple_roles() -> void:
	var roles = ["Head Coach", "Offensive Coordinator", "Defensive Coordinator", "Position Coach"]

	for role_name in roles:
		var coach = Coach.new()
		coach.role = role_name

		var dict = coach.to_dict()
		var restored = Coach.new()
		restored.from_dict(dict)

		assert_str(restored.role).is_equal(role_name)
