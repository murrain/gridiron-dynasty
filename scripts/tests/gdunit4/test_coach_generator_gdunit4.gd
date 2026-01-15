## GdUnit4 test suite for CoachGenerator
##
## Validates coach generation, determinism, and weighted distributions.
## Migrated from test_coach_generator.gd
extends GdUnitTestSuite

const CoachGenerator = preload("res://scripts/generation/CoachGenerator.gd")


func test_generate_coach_has_required_fields() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach_001")

	assert_str(String(coach.get("id", ""))).is_equal("test_coach_001")
	assert_str(String(coach.get("role", ""))).is_equal("Head Coach")


func test_coaching_ability_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var ability := float(coach.get("coaching_ability", 0.0))

	assert_float(ability).is_between(35.0, 95.0)


func test_recruiting_skill_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var recruiting := float(coach.get("recruiting_skill", 0.0))

	assert_float(recruiting).is_between(35.0, 95.0)


func test_player_development_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var development := float(coach.get("player_development", 0.0))

	assert_float(development).is_between(35.0, 95.0)


func test_experience_years_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var exp_years := int(coach.get("experience_years", -1))

	assert_int(exp_years).is_between(1, 35)


func test_scheme_rigidity_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var rigidity := float(coach.get("scheme_rigidity", 0.0))

	assert_float(rigidity).is_between(0.5, 1.2)


func test_offensive_scheme_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var off_scheme := String(coach.get("offensive_scheme", ""))

	assert_bool(off_scheme in CoachGenerator.OFFENSIVE_SCHEMES).is_true()


func test_defensive_scheme_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var def_scheme := String(coach.get("defensive_scheme", ""))

	assert_bool(def_scheme in CoachGenerator.DEFENSIVE_SCHEMES).is_true()


func test_character_tolerance_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var char_tol := String(coach.get("character_tolerance", ""))

	assert_bool(char_tol in CoachGenerator.CHARACTER_TOLERANCES).is_true()


func test_medical_tolerance_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var med_tol := String(coach.get("medical_tolerance", ""))

	assert_bool(med_tol in CoachGenerator.MEDICAL_TOLERANCES).is_true()


func test_specialty_position_is_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach")
	var specialty := String(coach.get("specialty_position", ""))

	assert_bool(specialty in CoachGenerator.SPECIALTY_POSITIONS).is_true()


func test_generate_coach_determinism() -> void:
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999

	var coach1 := CoachGenerator.generate_coach(rng1, "test_coach")
	var coach2 := CoachGenerator.generate_coach(rng2, "test_coach")

	assert_float(float(coach1.get("coaching_ability"))).is_equal(float(coach2.get("coaching_ability")))
	assert_float(float(coach1.get("recruiting_skill"))).is_equal(float(coach2.get("recruiting_skill")))
	assert_str(String(coach1.get("offensive_scheme"))).is_equal(String(coach2.get("offensive_scheme")))
	assert_str(String(coach1.get("defensive_scheme"))).is_equal(String(coach2.get("defensive_scheme")))
	assert_str(String(coach1.get("character_tolerance"))).is_equal(String(coach2.get("character_tolerance")))
	assert_str(String(coach1.get("medical_tolerance"))).is_equal(String(coach2.get("medical_tolerance")))


func test_generate_coach_for_elite_team() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var elite_coach := CoachGenerator.generate_coach_for_team(rng, "elite_coach", 95.0)

	assert_float(float(elite_coach.get("coaching_ability", 0.0))).is_greater_equal(25.0)


func test_generate_coach_for_low_team() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var low_coach := CoachGenerator.generate_coach_for_team(rng, "low_coach", 30.0)

	assert_float(float(low_coach.get("coaching_ability", 0.0))).is_greater_equal(25.0)


func test_generate_coaching_staff_has_all_coaches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var staff := CoachGenerator.generate_coaching_staff(rng, "test_team", 75.0)

	assert_bool(staff.has("head_coach")).is_true()
	assert_bool(staff.has("offensive_coordinator")).is_true()
	assert_bool(staff.has("defensive_coordinator")).is_true()


func test_coaching_staff_roles_correct() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var staff := CoachGenerator.generate_coaching_staff(rng, "test_team", 75.0)

	var hc := staff.get("head_coach", {}) as Dictionary
	var oc := staff.get("offensive_coordinator", {}) as Dictionary
	var dc := staff.get("defensive_coordinator", {}) as Dictionary

	assert_str(String(hc.get("role", ""))).is_equal("Head Coach")
	assert_str(String(oc.get("role", ""))).is_equal("Offensive Coordinator")
	assert_str(String(dc.get("role", ""))).is_equal("Defensive Coordinator")


func test_coaching_staff_specialties_correct() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var staff := CoachGenerator.generate_coaching_staff(rng, "test_team", 75.0)

	var oc := staff.get("offensive_coordinator", {}) as Dictionary
	var dc := staff.get("defensive_coordinator", {}) as Dictionary

	assert_str(String(oc.get("specialty_position", ""))).is_equal("Offense")
	assert_str(String(dc.get("specialty_position", ""))).is_equal("Defense")


func test_coaching_staff_scheme_inheritance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var staff := CoachGenerator.generate_coaching_staff(rng, "test_team", 75.0)

	var hc := staff.get("head_coach", {}) as Dictionary
	var oc := staff.get("offensive_coordinator", {}) as Dictionary
	var dc := staff.get("defensive_coordinator", {}) as Dictionary

	assert_str(String(oc.get("offensive_scheme"))).is_equal(String(hc.get("offensive_scheme")))
	assert_str(String(dc.get("defensive_scheme"))).is_equal(String(hc.get("defensive_scheme")))


func test_weighted_character_tolerance_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777

	var char_counts := {}
	for tolerance in CoachGenerator.CHARACTER_TOLERANCES:
		char_counts[tolerance] = 0

	for i in range(100):
		var coach := CoachGenerator.generate_coach(rng, "test_%d" % i)
		var char_tol: String = String(coach.get("character_tolerance", ""))
		if char_counts.has(char_tol):
			char_counts[char_tol] += 1

	# "moderate" should be most common (50% weight)
	assert_int(int(char_counts.get("moderate", 0))).is_greater(int(char_counts.get("strict", 0)))
	assert_int(int(char_counts.get("moderate", 0))).is_greater(int(char_counts.get("win_now", 0)))


func test_weighted_medical_tolerance_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777

	var med_counts := {}
	for tolerance in CoachGenerator.MEDICAL_TOLERANCES:
		med_counts[tolerance] = 0

	for i in range(100):
		var coach := CoachGenerator.generate_coach(rng, "test_%d" % i)
		var med_tol: String = String(coach.get("medical_tolerance", ""))
		if med_counts.has(med_tol):
			med_counts[med_tol] += 1

	# "cautious" should be most common (45% weight)
	assert_int(int(med_counts.get("cautious", 0))).is_greater(int(med_counts.get("risk_averse", 0)))
	assert_int(int(med_counts.get("cautious", 0))).is_greater(int(med_counts.get("aggressive", 0)))


func test_offensive_scheme_display_helpers() -> void:
	assert_str(CoachGenerator.get_offensive_scheme_display("west_coast")).is_equal("West Coast")
	assert_str(CoachGenerator.get_offensive_scheme_display("power_run")).is_equal("Power Run")
	assert_str(CoachGenerator.get_offensive_scheme_display("spread_option")).is_equal("Spread Option")
	assert_str(CoachGenerator.get_offensive_scheme_display("air_raid")).is_equal("Air Raid")


func test_defensive_scheme_display_helpers() -> void:
	assert_str(CoachGenerator.get_defensive_scheme_display("4_3_under")).is_equal("4-3 Under")
	assert_str(CoachGenerator.get_defensive_scheme_display("3_4_two_gap")).is_equal("3-4 Two Gap")
	assert_str(CoachGenerator.get_defensive_scheme_display("cover_2")).is_equal("Cover 2")
	assert_str(CoachGenerator.get_defensive_scheme_display("tampa_2")).is_equal("Tampa 2")
	assert_str(CoachGenerator.get_defensive_scheme_display("aggressive_blitz")).is_equal("Aggressive Blitz")


func test_character_tolerance_display_helpers() -> void:
	assert_str(CoachGenerator.get_character_tolerance_display("strict")).is_equal("Strict")
	assert_str(CoachGenerator.get_character_tolerance_display("moderate")).is_equal("Moderate")
	assert_str(CoachGenerator.get_character_tolerance_display("lenient")).is_equal("Lenient")
	assert_str(CoachGenerator.get_character_tolerance_display("win_now")).is_equal("Win Now")


func test_medical_tolerance_display_helpers() -> void:
	assert_str(CoachGenerator.get_medical_tolerance_display("risk_averse")).is_equal("Risk Averse")
	assert_str(CoachGenerator.get_medical_tolerance_display("cautious")).is_equal("Cautious")
	assert_str(CoachGenerator.get_medical_tolerance_display("moderate_risk")).is_equal("Moderate Risk")
	assert_str(CoachGenerator.get_medical_tolerance_display("aggressive")).is_equal("Aggressive")
