extends GdUnitTestSuite
class_name TestCoachGeneratorGdUnit4

const CoachGenerator = preload("res://scripts/generation/CoachGenerator.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

var _names_cfg: Dictionary = {}

func before_test() -> void:
	var loader = ConfigLoader.new()
	loader.configure("res://configs/sports/american_football", "", false)
	_names_cfg = loader.get_config("names")


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_coach_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return CoachGenerator.generate_coach(rng, "COACH001", _names_cfg),
		0xC0ACH01,
		"coach generation should be deterministic"
	)

func test_coaching_staff_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return CoachGenerator.generate_coaching_staff(rng, "TEAM001", 75.0),
		0xC0ACH02,
		"coaching staff generation should be deterministic"
	)


# ============================================================================
# GENERATED DATA VALIDITY TESTS
# ============================================================================

func test_generated_coach_has_required_fields() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0001)
	var coach = CoachGenerator.generate_coach(rng, "COACH001", _names_cfg)

	var required := [
		"id", "first_name", "last_name", "role",
		"coaching_ability", "recruiting_skill", "player_development",
		"experience_years", "specialty_position",
		"offensive_scheme", "defensive_scheme", "scheme_rigidity",
		"character_tolerance", "medical_tolerance"
	]
	TestHelpersGdUnit4.assert_schema(self, coach, required, "generated coach")

func test_coach_abilities_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0002)
	var coach = CoachGenerator.generate_coach(rng, "COACH002", _names_cfg)

	var coaching_ability = float(coach["coaching_ability"])
	var recruiting_skill = float(coach["recruiting_skill"])
	var player_development = float(coach["player_development"])

	assert_float(coaching_ability).is_greater_equal(35.0)
	assert_float(coaching_ability).is_less_equal(95.0)
	assert_float(recruiting_skill).is_greater_equal(35.0)
	assert_float(recruiting_skill).is_less_equal(95.0)
	assert_float(player_development).is_greater_equal(35.0)
	assert_float(player_development).is_less_equal(95.0)

func test_coach_experience_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0003)
	var coach = CoachGenerator.generate_coach(rng, "COACH003", _names_cfg)

	var experience = int(coach["experience_years"])
	assert_int(experience).is_greater_equal(1)
	assert_int(experience).is_less_equal(35)

func test_coach_has_valid_offensive_scheme() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0004)
	var coach = CoachGenerator.generate_coach(rng, "COACH004", _names_cfg)

	var scheme = String(coach["offensive_scheme"])
	var valid_schemes := [
		"west_coast", "power_run", "spread_option",
		"air_raid", "zone_run", "pro_style"
	]
	assert_bool(scheme in valid_schemes).override_failure_message(
		"Invalid offensive scheme: %s" % scheme
	).is_true()

func test_coach_has_valid_defensive_scheme() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0005)
	var coach = CoachGenerator.generate_coach(rng, "COACH005", _names_cfg)

	var scheme = String(coach["defensive_scheme"])
	var valid_schemes := [
		"4_3_under", "3_4_two_gap", "cover_2", "cover_3",
		"press_man", "tampa_2", "aggressive_blitz"
	]
	assert_bool(scheme in valid_schemes).override_failure_message(
		"Invalid defensive scheme: %s" % scheme
	).is_true()

func test_coach_has_valid_character_tolerance() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0006)
	var coach = CoachGenerator.generate_coach(rng, "COACH006", _names_cfg)

	var tolerance = String(coach["character_tolerance"])
	var valid_tolerances := ["strict", "moderate", "lenient", "win_now"]
	assert_bool(tolerance in valid_tolerances).is_true()

func test_coach_has_valid_medical_tolerance() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0007)
	var coach = CoachGenerator.generate_coach(rng, "COACH007", _names_cfg)

	var tolerance = String(coach["medical_tolerance"])
	var valid_tolerances := ["risk_averse", "cautious", "moderate_risk", "aggressive"]
	assert_bool(tolerance in valid_tolerances).is_true()

func test_coach_scheme_rigidity_in_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0008)
	var coach = CoachGenerator.generate_coach(rng, "COACH008", _names_cfg)

	var rigidity = float(coach["scheme_rigidity"])
	assert_float(rigidity).is_greater_equal(0.5)
	assert_float(rigidity).is_less_equal(1.2)

func test_coach_has_name() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0009)
	var coach = CoachGenerator.generate_coach(rng, "COACH009", _names_cfg)

	var first_name = String(coach["first_name"])
	var last_name = String(coach["last_name"])

	assert_bool(first_name.length() > 0).is_true()
	assert_bool(last_name.length() > 0).is_true()


# ============================================================================
# TEAM-BASED GENERATION TESTS
# ============================================================================

func test_elite_team_gets_better_coach() -> void:
	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xC0010)
	var elite_coach = CoachGenerator.generate_coach_for_team(rng1, "COACH_ELITE", 95.0, _names_cfg)

	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xC0011)
	var poor_coach = CoachGenerator.generate_coach_for_team(rng2, "COACH_POOR", 30.0, _names_cfg)

	# Elite team coaches should generally have higher abilities (not guaranteed per coach, but trend)
	# Test this by generating multiple and comparing averages
	var elite_total := 0.0
	var poor_total := 0.0
	var count := 20

	for i in count:
		var rng_e = TestHelpersGdUnit4.create_seeded_rng(0xE0000 + i)
		var coach_e = CoachGenerator.generate_coach_for_team(rng_e, "E_%d" % i, 95.0, _names_cfg)
		elite_total += float(coach_e["coaching_ability"])

		var rng_p = TestHelpersGdUnit4.create_seeded_rng(0xP0000 + i)
		var coach_p = CoachGenerator.generate_coach_for_team(rng_p, "P_%d" % i, 30.0, _names_cfg)
		poor_total += float(coach_p["coaching_ability"])

	var elite_avg := elite_total / float(count)
	var poor_avg := poor_total / float(count)

	assert_float(elite_avg).is_greater(poor_avg)

func test_coaching_staff_has_three_coaches() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0012)
	var staff = CoachGenerator.generate_coaching_staff(rng, "TEAM001", 75.0)

	assert_that(staff).contains_key("head_coach")
	assert_that(staff).contains_key("offensive_coordinator")
	assert_that(staff).contains_key("defensive_coordinator")

func test_coordinators_have_correct_roles() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0013)
	var staff = CoachGenerator.generate_coaching_staff(rng, "TEAM002", 75.0)

	var hc: Dictionary = staff["head_coach"]
	var oc: Dictionary = staff["offensive_coordinator"]
	var dc: Dictionary = staff["defensive_coordinator"]

	assert_str(hc["role"]).is_equal("Head Coach")
	assert_str(oc["role"]).is_equal("Offensive Coordinator")
	assert_str(dc["role"]).is_equal("Defensive Coordinator")

func test_coordinators_inherit_schemes() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0014)
	var staff = CoachGenerator.generate_coaching_staff(rng, "TEAM003", 75.0)

	var hc: Dictionary = staff["head_coach"]
	var oc: Dictionary = staff["offensive_coordinator"]
	var dc: Dictionary = staff["defensive_coordinator"]

	# OC inherits HC's offensive scheme
	assert_str(oc["offensive_scheme"]).is_equal(String(hc["offensive_scheme"]))
	# DC inherits HC's defensive scheme
	assert_str(dc["defensive_scheme"]).is_equal(String(hc["defensive_scheme"]))


# ============================================================================
# CONFIG OVERRIDE TESTS
# ============================================================================

func test_coach_generation_with_custom_ability_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0015)
	var config := {
		"ability_min": 70.0,
		"ability_max": 90.0
	}
	var coach = CoachGenerator.generate_coach(rng, "COACH_CUSTOM", _names_cfg, config)

	var ability = float(coach["coaching_ability"])
	assert_float(ability).is_greater_equal(70.0)
	assert_float(ability).is_less_equal(90.0)

func test_coach_generation_with_custom_experience_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xC0016)
	var config := {
		"experience_min": 15,
		"experience_max": 25
	}
	var coach = CoachGenerator.generate_coach(rng, "COACH_EXP", _names_cfg, config)

	var experience = int(coach["experience_years"])
	assert_int(experience).is_greater_equal(15)
	assert_int(experience).is_less_equal(25)


# ============================================================================
# DISPLAY NAME TESTS
# ============================================================================

func test_offensive_scheme_display_names() -> void:
	assert_str(CoachGenerator.get_offensive_scheme_display("west_coast")).is_equal("West Coast")
	assert_str(CoachGenerator.get_offensive_scheme_display("air_raid")).is_equal("Air Raid")
	assert_str(CoachGenerator.get_offensive_scheme_display("pro_style")).is_equal("Pro Style")

func test_defensive_scheme_display_names() -> void:
	assert_str(CoachGenerator.get_defensive_scheme_display("4_3_under")).is_equal("4-3 Under")
	assert_str(CoachGenerator.get_defensive_scheme_display("tampa_2")).is_equal("Tampa 2")
	assert_str(CoachGenerator.get_defensive_scheme_display("cover_3")).is_equal("Cover 3")

func test_character_tolerance_display_names() -> void:
	assert_str(CoachGenerator.get_character_tolerance_display("strict")).is_equal("Strict")
	assert_str(CoachGenerator.get_character_tolerance_display("win_now")).is_equal("Win Now")

func test_medical_tolerance_display_names() -> void:
	assert_str(CoachGenerator.get_medical_tolerance_display("risk_averse")).is_equal("Risk Averse")
	assert_str(CoachGenerator.get_medical_tolerance_display("moderate_risk")).is_equal("Moderate Risk")
