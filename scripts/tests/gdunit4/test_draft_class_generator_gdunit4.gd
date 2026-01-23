extends GdUnitTestSuite
class_name TestDraftClassGeneratorGdUnit4

const DraftClassGenerator = preload("res://scripts/generation/DraftClassGenerator.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_draft_class_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng_unused):
			var gen = DraftClassGenerator.new()
			return gen.generate_for_year(2030, 0xDRAFT1, 100),
		0,  # Unused since we pass seed directly
		"draft class generation should be deterministic"
	)

func test_same_year_same_seed_produces_same_class() -> void:
	var gen1 = DraftClassGenerator.new()
	var class1 = gen1.generate_for_year(2028, 0x123456, 150)

	var gen2 = DraftClassGenerator.new()
	var class2 = gen2.generate_for_year(2028, 0x123456, 150)

	assert_that(class1).is_equal(class2)

func test_different_seeds_produce_different_classes() -> void:
	var gen1 = DraftClassGenerator.new()
	var class1 = gen1.generate_for_year(2028, 0x111111, 100)

	var gen2 = DraftClassGenerator.new()
	var class2 = gen2.generate_for_year(2028, 0x222222, 100)

	assert_that(class1).is_not_equal(class2)


# ============================================================================
# GENERATED CLASS VALIDITY TESTS
# ============================================================================

func test_generated_class_has_correct_size() -> void:
	var gen = DraftClassGenerator.new()
	var target_size := 200
	var players = gen.generate_for_year(2029, 0xDRAFT2, target_size)

	assert_int(players.size()).is_equal(target_size)

func test_generated_players_have_class_tag() -> void:
	var gen = DraftClassGenerator.new()
	var target_year := 2031
	var players = gen.generate_for_year(target_year, 0xDRAFT3, 50)

	for player in players:
		var p: Dictionary = player
		assert_that(p).contains_key("class_tag")
		assert_str(p["class_tag"]).is_equal("CLASS_OF_%d" % target_year)

func test_generated_players_have_draft_year() -> void:
	var gen = DraftClassGenerator.new()
	var target_year := 2032
	var players = gen.generate_for_year(target_year, 0xDRAFT4, 50)

	for player in players:
		var p: Dictionary = player
		assert_that(p).contains_key("draft_year")
		assert_int(p["draft_year"]).is_equal(target_year)

func test_generated_players_have_ratings() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFT5, 100)

	for player in players:
		var p: Dictionary = player
		# Should have been rated and ranked
		assert_that(p).contains_key("composite_score")
		assert_that(p).contains_key("star_rating")

func test_generated_players_are_de_aged() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFT6, 100)

	# After de-aging, most players should be younger
	var young_count := 0
	for player in players:
		var p: Dictionary = player
		if p.has("age") and int(p["age"]) <= 19:
			young_count += 1

	# Most should be young after de-aging
	assert_int(young_count).is_greater(80)

func test_generated_players_have_potential() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFT7, 50)

	for player in players:
		var p: Dictionary = player
		assert_that(p).contains_key("potential")
		var potential: Dictionary = p["potential"]
		assert_int(potential.size()).is_greater(0)


# ============================================================================
# CLASS SIZE TESTS
# ============================================================================

func test_uses_default_class_size_when_not_specified() -> void:
	var gen = DraftClassGenerator.new()
	# Pass -1 to use default from config
	var players = gen.generate_for_year(2030, 0xDRAFT8, -1)

	# Should use default from class_rules (typically 2000)
	# We just verify it's a reasonable size
	assert_int(players.size()).is_greater(100)

func test_respects_custom_class_size() -> void:
	var gen = DraftClassGenerator.new()
	var custom_size := 75
	var players = gen.generate_for_year(2030, 0xDRAFT9, custom_size)

	assert_int(players.size()).is_equal(custom_size)

func test_handles_small_class_size() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFTA, 10)

	assert_int(players.size()).is_equal(10)

func test_handles_large_class_size() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFTB, 500)

	assert_int(players.size()).is_equal(500)


# ============================================================================
# YEAR VARIATION TESTS
# ============================================================================

func test_different_years_produce_different_classes() -> void:
	var gen = DraftClassGenerator.new()
	var seed := 0x555555

	var class_2028 = gen.generate_for_year(2028, seed, 100)
	var class_2029 = gen.generate_for_year(2029, seed, 100)

	# Same seed but different year should produce different results
	assert_that(class_2028).is_not_equal(class_2029)


# ============================================================================
# SAVE FUNCTIONALITY TESTS
# ============================================================================

func test_save_class_returns_path() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2035, 0xDRAFTC, 10)
	var path = gen.save_class(players, 2035)

	assert_str(path).is_not_empty()
	assert_bool(path.contains("CLASS_OF_2035")).is_true()

func test_save_path_includes_year() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2040, 0xDRAFTD, 10)
	var path = gen.save_class(players, 2040)

	assert_bool(path.contains("2040")).is_true()


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_full_generation_pipeline_completes() -> void:
	var gen = DraftClassGenerator.new()

	# Generate class
	var players = gen.generate_for_year(2033, 0xDRAFTE, 150)

	# Verify all pipeline steps completed
	assert_int(players.size()).is_equal(150)

	# Check first player has all required data
	var first_player: Dictionary = players[0]
	var required := [
		"name", "position", "stats", "physicals",
		"class_tag", "draft_year", "composite_score",
		"star_rating", "potential"
	]
	TestHelpersGdUnit4.assert_schema(self, first_player, required, "draft class player")

func test_generates_star_rating_distribution() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFTF, 500)

	var star_counts := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for player in players:
		var p: Dictionary = player
		var stars := int(p.get("star_rating", 0))
		if stars >= 1 and stars <= 5:
			star_counts[stars] = star_counts[stars] + 1

	# Should have distribution across star ratings
	# Most should be 2-3 stars
	assert_int(star_counts[2] + star_counts[3]).is_greater(250)
	# Some 4-stars
	assert_int(star_counts[4]).is_greater(0)
	# Few 5-stars
	assert_int(star_counts[5]).is_greater_equal(0)

func test_generates_position_distribution() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFT10, 300)

	var position_counts := {}
	for player in players:
		var p: Dictionary = player
		var pos = String(p.get("position", ""))
		position_counts[pos] = position_counts.get(pos, 0) + 1

	# Should have multiple positions
	assert_int(position_counts.size()).is_greater(8)


# ============================================================================
# EDGE CASES
# ============================================================================

func test_handles_zero_class_size() -> void:
	var gen = DraftClassGenerator.new()
	var players = gen.generate_for_year(2030, 0xDRAFT11, 0)

	assert_int(players.size()).is_equal(0)

func test_handles_very_old_year() -> void:
	var gen = DraftClassGenerator.new()
	# Should not crash with old year
	var players = gen.generate_for_year(1950, 0xDRAFT12, 50)

	assert_int(players.size()).is_equal(50)

func test_handles_far_future_year() -> void:
	var gen = DraftClassGenerator.new()
	# Should not crash with far future year
	var players = gen.generate_for_year(2100, 0xDRAFT13, 50)

	assert_int(players.size()).is_equal(50)
