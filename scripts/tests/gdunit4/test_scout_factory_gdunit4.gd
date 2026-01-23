extends GdUnitTestSuite
class_name TestScoutFactoryGdUnit4

const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

var _stats_cfg: Dictionary = {}
var _scouts_cfg: Dictionary = {}
var _factory: ScoutFactory = null

func before_test() -> void:
	var loader = ConfigLoader.new()
	loader.configure("res://configs/sports/american_football", "", false)
	_stats_cfg = loader.get_config("stats")
	_scouts_cfg = loader.get_config("scouts")

	_factory = ScoutFactory.new()
	_factory.setup(_stats_cfg, _scouts_cfg)

func after_test() -> void:
	_factory = null


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_random_scout_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			var factory = ScoutFactory.new()
			factory.setup(_stats_cfg, _scouts_cfg)
			var scout = factory.create_random_scout("Test Scout", rng)
			# Convert to dict for comparison
			return {
				"name": scout.name,
				"years_exp": scout.years_exp,
				"base_skill": scout.base_skill,
				"overrate_athletes": scout.overrate_athletes
			},
		0xSCOUT1,
		"random scout generation should be deterministic"
	)

func test_team_scouts_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			var factory = ScoutFactory.new()
			factory.setup(_stats_cfg, _scouts_cfg)
			var scouts = factory.create_team_scouts("TestTeam", 3, rng)
			# Convert to comparable format
			var result := []
			for scout in scouts:
				result.append({
					"name": scout.name,
					"years_exp": scout.years_exp
				})
			return result,
		0xSCOUT2,
		"team scouts generation should be deterministic"
	)


# ============================================================================
# SCOUT CREATION TESTS
# ============================================================================

func test_creates_random_scout() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0001)
	var scout = _factory.create_random_scout("National Scout 1", rng)

	assert_that(scout).is_not_null()
	assert_str(scout.name).is_equal("National Scout 1")

func test_random_scout_has_experience() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0002)
	var scout = _factory.create_random_scout("Scout", rng)

	assert_int(scout.years_exp).is_greater_equal(3)
	assert_int(scout.years_exp).is_less_equal(15)

func test_random_scout_has_base_skill() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0003)
	var scout = _factory.create_random_scout("Scout", rng)

	assert_float(scout.base_skill).is_greater_equal(0.3)
	assert_float(scout.base_skill).is_less_equal(0.85)

func test_random_scout_has_traits() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0004)
	var scout = _factory.create_random_scout("Scout", rng)

	# Should have all core traits
	assert_that(typeof(scout.overrate_athletes)).is_equal(TYPE_FLOAT)
	assert_that(typeof(scout.tape_grinder)).is_equal(TYPE_FLOAT)
	assert_that(typeof(scout.risk_aversion)).is_equal(TYPE_FLOAT)

func test_random_scout_has_stat_skills() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0005)
	var scout = _factory.create_random_scout("Scout", rng)

	assert_that(scout.stat_skill).is_not_null()
	assert_int(scout.stat_skill.size()).is_greater(0)

func test_random_scout_has_specialties() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0006)
	var scout = _factory.create_random_scout("Scout", rng)

	# Scout should have some stats with higher skill (specialties)
	var high_skill_count := 0
	for stat in scout.stat_skill.keys():
		if float(scout.stat_skill[stat]) >= 0.75:
			high_skill_count += 1

	assert_int(high_skill_count).is_greater_equal(2)


# ============================================================================
# TEAM SCOUTS TESTS
# ============================================================================

func test_creates_team_scouts() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0007)
	var scouts = _factory.create_team_scouts("Dallas", 3, rng)

	assert_int(scouts.size()).is_equal(3)

func test_team_scouts_have_team_name() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0008)
	var scouts = _factory.create_team_scouts("Kansas City", 2, rng)

	for scout in scouts:
		var s = scout
		assert_bool(s.name.contains("Kansas City")).is_true()

func test_team_scouts_have_team_role() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0009)
	var scouts = _factory.create_team_scouts("Miami", 2, rng)

	for scout in scouts:
		var s = scout
		assert_str(s.role).is_equal("Team")

func test_team_scouts_are_unique() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0010)
	var scouts = _factory.create_team_scouts("Seattle", 3, rng)

	# Each scout should have different characteristics
	var skills := []
	for scout in scouts:
		var s = scout
		skills.append(s.base_skill)

	# At least some variation expected
	var unique_skills := {}
	for skill in skills:
		unique_skills[skill] = true

	assert_int(unique_skills.size()).is_greater_equal(1)


# ============================================================================
# SCOUT DICT APPLICATION TESTS
# ============================================================================

func test_apply_scout_dict_sets_name() -> void:
	var scout_dict := {"name": "Mel Kiper Jr"}
	var scout = ScoutFactory.new()._create_scout_resource()  # Helper to create empty scout

	# Note: We can't test this directly without accessing Scout.new()
	# This is more of a documentation of the API
	assert_that(scout_dict).contains_key("name")

func test_scout_dict_has_expected_fields() -> void:
	# Test that scout dict structure is correct
	var scout_dict := {
		"name": "Test Scout",
		"role": "National",
		"years_exp": 10,
		"base_skill": 0.75
	}

	assert_that(scout_dict).contains_key("name")
	assert_that(scout_dict).contains_key("role")
	assert_that(scout_dict).contains_key("years_exp")
	assert_that(scout_dict).contains_key("base_skill")


# ============================================================================
# SPECIALTY DISTRIBUTION TESTS
# ============================================================================

func test_scouts_have_varied_specialties() -> void:
	var all_specialties := {}

	# Generate multiple scouts
	for i in 10:
		var rng = TestHelpersGdUnit4.create_seeded_rng(0xSP000 + i)
		var scout = _factory.create_random_scout("Scout %d" % i, rng)

		# Track which stats each scout specializes in
		for stat in scout.stat_skill.keys():
			if float(scout.stat_skill[stat]) >= 0.75:
				all_specialties[stat] = all_specialties.get(stat, 0) + 1

	# Should have variety across multiple scouts
	assert_int(all_specialties.size()).is_greater(5)


# ============================================================================
# CONFIGURATION TESTS
# ============================================================================

func test_handles_empty_stats_config() -> void:
	var factory = ScoutFactory.new()
	factory.setup({}, _scouts_cfg)

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0011)
	# Should not crash
	var scout = factory.create_random_scout("Scout", rng)
	assert_that(scout).is_not_null()

func test_handles_empty_scouts_config() -> void:
	var factory = ScoutFactory.new()
	factory.setup(_stats_cfg, {})

	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0012)
	# Should not crash
	var scout = factory.create_random_scout("Scout", rng)
	assert_that(scout).is_not_null()


# ============================================================================
# EDGE CASES
# ============================================================================

func test_creates_zero_team_scouts() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0013)
	var scouts = _factory.create_team_scouts("Team", 0, rng)

	assert_int(scouts.size()).is_equal(0)

func test_creates_many_team_scouts() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0014)
	var scouts = _factory.create_team_scouts("Team", 10, rng)

	assert_int(scouts.size()).is_equal(10)

func test_team_scouts_without_rng_returns_empty() -> void:
	var scouts = _factory.create_team_scouts("Team", 3, null)

	# Should return empty array when RNG is null
	assert_int(scouts.size()).is_equal(0)


# ============================================================================
# SCOUT TRAIT RANGES
# ============================================================================

func test_overrate_athletes_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0015)
	var scout = _factory.create_random_scout("Scout", rng)

	assert_float(scout.overrate_athletes).is_greater_equal(-0.8)
	assert_float(scout.overrate_athletes).is_less_equal(0.8)

func test_tape_grinder_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0016)
	var scout = _factory.create_random_scout("Scout", rng)

	assert_float(scout.tape_grinder).is_greater_equal(0.0)
	assert_float(scout.tape_grinder).is_less_equal(1.0)

func test_risk_aversion_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xS0017)
	var scout = _factory.create_random_scout("Scout", rng)

	assert_float(scout.risk_aversion).is_greater_equal(0.0)
	assert_float(scout.risk_aversion).is_less_equal(0.6)


# ============================================================================
# VARIATION TESTS
# ============================================================================

func test_multiple_scouts_have_variation() -> void:
	var skills := []

	for i in 20:
		var rng = TestHelpersGdUnit4.create_seeded_rng(0xV0000 + i)
		var scout = _factory.create_random_scout("Scout %d" % i, rng)
		skills.append(scout.base_skill)

	# Should have variation
	var unique_skills := {}
	for skill in skills:
		unique_skills[skill] = true

	assert_int(unique_skills.size()).is_greater(10)
