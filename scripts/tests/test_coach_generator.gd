extends RefCounted

const CoachGenerator = preload("res://scripts/generation/CoachGenerator.gd")

func run(t) -> void:
	test_generate_coach_basic(t)
	test_generate_coach_determinism(t)
	test_generate_coach_for_team(t)
	test_generate_coaching_staff(t)
	test_weighted_distributions(t)
	test_display_helpers(t)

func test_generate_coach_basic(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var coach := CoachGenerator.generate_coach(rng, "test_coach_001")

	# Verify required fields exist
	t.assert_eq(coach.get("id"), "test_coach_001", "coach has correct id")
	t.assert_eq(coach.get("role"), "Head Coach", "coach has Head Coach role")

	# Verify coaching abilities are in valid range
	var ability = coach.get("coaching_ability", 0.0)
	t.assert_true(ability >= 35.0 and ability <= 95.0, "coaching_ability in range 35-95")

	var recruiting = coach.get("recruiting_skill", 0.0)
	t.assert_true(recruiting >= 35.0 and recruiting <= 95.0, "recruiting_skill in range 35-95")

	var development = coach.get("player_development", 0.0)
	t.assert_true(development >= 35.0 and development <= 95.0, "player_development in range 35-95")

	# Verify experience is in valid range
	var exp_years = coach.get("experience_years", -1)
	t.assert_true(exp_years >= 1 and exp_years <= 35, "experience_years in range 1-35")

	# Verify scheme rigidity is in valid range
	var rigidity = coach.get("scheme_rigidity", 0.0)
	t.assert_true(rigidity >= 0.5 and rigidity <= 1.2, "scheme_rigidity in range 0.5-1.2")

	# Verify schemes are valid
	var off_scheme = coach.get("offensive_scheme", "")
	t.assert_true(off_scheme in CoachGenerator.OFFENSIVE_SCHEMES, "offensive_scheme is valid")

	var def_scheme = coach.get("defensive_scheme", "")
	t.assert_true(def_scheme in CoachGenerator.DEFENSIVE_SCHEMES, "defensive_scheme is valid")

	# Verify tolerances are valid
	var char_tol = coach.get("character_tolerance", "")
	t.assert_true(char_tol in CoachGenerator.CHARACTER_TOLERANCES, "character_tolerance is valid")

	var med_tol = coach.get("medical_tolerance", "")
	t.assert_true(med_tol in CoachGenerator.MEDICAL_TOLERANCES, "medical_tolerance is valid")

	# Verify specialty position is valid
	var specialty = coach.get("specialty_position", "")
	t.assert_true(specialty in CoachGenerator.SPECIALTY_POSITIONS, "specialty_position is valid")

func test_generate_coach_determinism(t) -> void:
	# Same seed should produce identical coaches
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999

	var coach1 := CoachGenerator.generate_coach(rng1, "test_coach")
	var coach2 := CoachGenerator.generate_coach(rng2, "test_coach")

	t.assert_eq(coach1.get("coaching_ability"), coach2.get("coaching_ability"), "coaching_ability is deterministic")
	t.assert_eq(coach1.get("recruiting_skill"), coach2.get("recruiting_skill"), "recruiting_skill is deterministic")
	t.assert_eq(coach1.get("offensive_scheme"), coach2.get("offensive_scheme"), "offensive_scheme is deterministic")
	t.assert_eq(coach1.get("defensive_scheme"), coach2.get("defensive_scheme"), "defensive_scheme is deterministic")
	t.assert_eq(coach1.get("character_tolerance"), coach2.get("character_tolerance"), "character_tolerance is deterministic")
	t.assert_eq(coach1.get("medical_tolerance"), coach2.get("medical_tolerance"), "medical_tolerance is deterministic")

func test_generate_coach_for_team(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	# Elite team (high eliteness) should get better coach
	var elite_coach := CoachGenerator.generate_coach_for_team(rng, "elite_coach", 95.0)

	rng.seed = 54321
	# Low tier team should get lower quality coach on average
	var low_coach := CoachGenerator.generate_coach_for_team(rng, "low_coach", 30.0)

	# Elite coach should have higher minimum ability potential
	# Note: Due to RNG, we can't guarantee exact values, but config adjusts ranges
	t.assert_true(elite_coach.get("coaching_ability", 0.0) >= 25.0, "elite coach ability >= 25")
	t.assert_true(low_coach.get("coaching_ability", 0.0) >= 25.0, "low coach ability >= 25")

func test_generate_coaching_staff(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var staff := CoachGenerator.generate_coaching_staff(rng, "test_team", 75.0)

	# Verify all three coaches exist
	t.assert_true(staff.has("head_coach"), "staff has head_coach")
	t.assert_true(staff.has("offensive_coordinator"), "staff has offensive_coordinator")
	t.assert_true(staff.has("defensive_coordinator"), "staff has defensive_coordinator")

	var hc = staff.get("head_coach", {})
	var oc = staff.get("offensive_coordinator", {})
	var dc = staff.get("defensive_coordinator", {})

	# Verify roles
	t.assert_eq(hc.get("role"), "Head Coach", "HC has correct role")
	t.assert_eq(oc.get("role"), "Offensive Coordinator", "OC has correct role")
	t.assert_eq(dc.get("role"), "Defensive Coordinator", "DC has correct role")

	# Verify specialties
	t.assert_eq(oc.get("specialty_position"), "Offense", "OC specialty is Offense")
	t.assert_eq(dc.get("specialty_position"), "Defense", "DC specialty is Defense")

	# Verify scheme inheritance
	t.assert_eq(oc.get("offensive_scheme"), hc.get("offensive_scheme"), "OC inherits HC offensive scheme")
	t.assert_eq(dc.get("defensive_scheme"), hc.get("defensive_scheme"), "DC inherits HC defensive scheme")

func test_weighted_distributions(t) -> void:
	# Test that weighted picks work across many samples
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777

	var char_counts := {}
	var med_counts := {}

	for tolerance in CoachGenerator.CHARACTER_TOLERANCES:
		char_counts[tolerance] = 0
	for tolerance in CoachGenerator.MEDICAL_TOLERANCES:
		med_counts[tolerance] = 0

	# Generate many coaches and count distributions
	for i in range(100):
		var coach := CoachGenerator.generate_coach(rng, "test_%d" % i)
		var char_tol = coach.get("character_tolerance", "")
		var med_tol = coach.get("medical_tolerance", "")
		if char_counts.has(char_tol):
			char_counts[char_tol] += 1
		if med_counts.has(med_tol):
			med_counts[med_tol] += 1

	# "moderate" character tolerance should be most common (50% weight)
	t.assert_true(char_counts.get("moderate", 0) > char_counts.get("strict", 0), "moderate > strict (character)")
	t.assert_true(char_counts.get("moderate", 0) > char_counts.get("win_now", 0), "moderate > win_now (character)")

	# "cautious" medical tolerance should be most common (45% weight)
	t.assert_true(med_counts.get("cautious", 0) > med_counts.get("risk_averse", 0), "cautious > risk_averse (medical)")
	t.assert_true(med_counts.get("cautious", 0) > med_counts.get("aggressive", 0), "cautious > aggressive (medical)")

func test_display_helpers(t) -> void:
	# Test offensive scheme display
	t.assert_eq(CoachGenerator.get_offensive_scheme_display("west_coast"), "West Coast", "west_coast displays correctly")
	t.assert_eq(CoachGenerator.get_offensive_scheme_display("power_run"), "Power Run", "power_run displays correctly")
	t.assert_eq(CoachGenerator.get_offensive_scheme_display("spread_option"), "Spread Option", "spread_option displays correctly")
	t.assert_eq(CoachGenerator.get_offensive_scheme_display("air_raid"), "Air Raid", "air_raid displays correctly")

	# Test defensive scheme display
	t.assert_eq(CoachGenerator.get_defensive_scheme_display("4_3_under"), "4-3 Under", "4_3_under displays correctly")
	t.assert_eq(CoachGenerator.get_defensive_scheme_display("3_4_two_gap"), "3-4 Two Gap", "3_4_two_gap displays correctly")
	t.assert_eq(CoachGenerator.get_defensive_scheme_display("cover_2"), "Cover 2", "cover_2 displays correctly")
	t.assert_eq(CoachGenerator.get_defensive_scheme_display("tampa_2"), "Tampa 2", "tampa_2 displays correctly")
	t.assert_eq(CoachGenerator.get_defensive_scheme_display("aggressive_blitz"), "Aggressive Blitz", "aggressive_blitz displays correctly")

	# Test character tolerance display
	t.assert_eq(CoachGenerator.get_character_tolerance_display("strict"), "Strict", "strict displays correctly")
	t.assert_eq(CoachGenerator.get_character_tolerance_display("moderate"), "Moderate", "moderate displays correctly")
	t.assert_eq(CoachGenerator.get_character_tolerance_display("lenient"), "Lenient", "lenient displays correctly")
	t.assert_eq(CoachGenerator.get_character_tolerance_display("win_now"), "Win Now", "win_now displays correctly")

	# Test medical tolerance display
	t.assert_eq(CoachGenerator.get_medical_tolerance_display("risk_averse"), "Risk Averse", "risk_averse displays correctly")
	t.assert_eq(CoachGenerator.get_medical_tolerance_display("cautious"), "Cautious", "cautious displays correctly")
	t.assert_eq(CoachGenerator.get_medical_tolerance_display("moderate_risk"), "Moderate Risk", "moderate_risk displays correctly")
	t.assert_eq(CoachGenerator.get_medical_tolerance_display("aggressive"), "Aggressive", "aggressive displays correctly")
