extends GdUnitTestSuite
class_name TestHypeGeneratorGdUnit4

const HypeGenerator = preload("res://scripts/generation/HypeGenerator.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_initial_hype_generation_is_deterministic() -> void:
	var player := {"position": "QB", "stats": {"speed": 75.0}}

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return HypeGenerator.generate_initial_hype(player, 4, "south", 0.75, rng),
		0xHYPE01,
		"initial hype generation should be deterministic"
	)

func test_hype_event_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return HypeGenerator.apply_hype_event(65.0, "heisman_finalist", rng),
		0xHYPE02,
		"hype event application should be deterministic"
	)

func test_combine_hype_is_deterministic() -> void:
	var player := {
		"position": "WR",
		"stats": {
			"speed": 88.0,
			"agility": 85.0,
			"strength": 60.0,
			"charisma": 70.0
		}
	}

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return HypeGenerator.apply_combine_hype(60.0, player, "WR", rng),
		0xHYPE03,
		"combine hype should be deterministic"
	)

func test_boring_prospect_penalty_is_deterministic() -> void:
	var player := {
		"position": "OL",
		"stats": {"charisma": 35.0}
	}

	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return HypeGenerator.calculate_boring_prospect_penalty(
				player, 0.25, "pro_style", rng
			),
		0xHYPE04,
		"boring prospect penalty should be deterministic"
	)


# ============================================================================
# INITIAL HYPE GENERATION TESTS
# ============================================================================

func test_initial_hype_in_valid_range() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0001)
	var player := {"position": "QB", "stats": {}}

	var hype = HypeGenerator.generate_initial_hype(player, 3, "midwest", 0.5, rng)

	assert_float(hype).is_greater_equal(15.0)
	assert_float(hype).is_less_equal(95.0)

func test_five_star_gets_higher_hype() -> void:
	var player := {"position": "QB", "stats": {}}

	var five_star_total := 0.0
	var two_star_total := 0.0
	var count := 30

	for i in count:
		var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xF5000 + i)
		five_star_total += HypeGenerator.generate_initial_hype(player, 5, "south", 0.5, rng1)

		var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xF2000 + i)
		two_star_total += HypeGenerator.generate_initial_hype(player, 2, "south", 0.5, rng2)

	var five_star_avg := five_star_total / float(count)
	var two_star_avg := two_star_total / float(count)

	# 5-stars should average higher hype
	assert_float(five_star_avg).is_greater(two_star_avg + 10.0)

func test_qb_gets_position_hype_bonus() -> void:
	var qb_player := {"position": "QB", "stats": {}}
	var ol_player := {"position": "OL", "stats": {}}

	var qb_total := 0.0
	var ol_total := 0.0
	var count := 30

	for i in count:
		var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xQB00 + i)
		qb_total += HypeGenerator.generate_initial_hype(qb_player, 3, "south", 0.5, rng1)

		var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xOL00 + i)
		ol_total += HypeGenerator.generate_initial_hype(ol_player, 3, "south", 0.5, rng2)

	var qb_avg := qb_total / float(count)
	var ol_avg := ol_total / float(count)

	# QBs should average higher hype than OL
	assert_float(qb_avg).is_greater(ol_avg)

func test_higher_media_tier_increases_hype() -> void:
	var player := {"position": "QB", "stats": {}}

	var high_media_total := 0.0
	var low_media_total := 0.0
	var count := 30

	for i in count:
		var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xHM00 + i)
		high_media_total += HypeGenerator.generate_initial_hype(player, 3, "south", 0.9, rng1)

		var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xLM00 + i)
		low_media_total += HypeGenerator.generate_initial_hype(player, 3, "south", 0.1, rng2)

	var high_media_avg := high_media_total / float(count)
	var low_media_avg := low_media_total / float(count)

	assert_float(high_media_avg).is_greater(low_media_avg)


# ============================================================================
# HYPE EVENT TESTS
# ============================================================================

func test_heisman_finalist_increases_hype() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0002)
	var initial_hype := 60.0

	var new_hype = HypeGenerator.apply_hype_event(initial_hype, "heisman_finalist", rng)

	assert_float(new_hype).is_greater(initial_hype)
	assert_float(new_hype).is_less_equal(98.0)

func test_major_injury_decreases_hype() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0003)
	var initial_hype := 70.0

	var new_hype = HypeGenerator.apply_hype_event(initial_hype, "major_injury", rng)

	assert_float(new_hype).is_less(initial_hype)
	assert_float(new_hype).is_greater_equal(10.0)

func test_off_field_issue_significantly_decreases_hype() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0004)
	var initial_hype := 80.0

	var new_hype = HypeGenerator.apply_hype_event(initial_hype, "off_field_issue", rng)

	assert_float(new_hype).is_less(initial_hype - 10.0)

func test_viral_highlight_increases_hype() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0005)
	var initial_hype := 50.0

	var new_hype = HypeGenerator.apply_hype_event(initial_hype, "viral_highlight", rng)

	assert_float(new_hype).is_greater(initial_hype)

func test_unknown_event_returns_unchanged_hype() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0006)
	var initial_hype := 60.0

	var new_hype = HypeGenerator.apply_hype_event(initial_hype, "unknown_event_xyz", rng)

	assert_float(new_hype).is_equal(initial_hype)

func test_hype_events_stay_in_bounds() -> void:
	var events := [
		"heisman_finalist", "conference_poy", "bowl_mvp", "viral_highlight",
		"natl_championship", "major_injury", "off_field_issue",
		"underwhelming_season", "transfer_up", "limited_snaps"
	]

	for event in events:
		var rng = TestHelpersGdUnit4.create_seeded_rng(0xEV000 + event.hash())
		var new_hype = HypeGenerator.apply_hype_event(50.0, event, rng)

		assert_float(new_hype).is_greater_equal(10.0)
		assert_float(new_hype).is_less_equal(98.0)


# ============================================================================
# COMBINE HYPE TESTS
# ============================================================================

func test_elite_speed_increases_hype() -> void:
	var player := {
		"position": "WR",
		"stats": {
			"speed": 95.0,  # Elite
			"agility": 70.0,
			"strength": 60.0,
			"charisma": 60.0
		}
	}
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0007)
	var initial_hype := 60.0

	var new_hype = HypeGenerator.apply_combine_hype(initial_hype, player, "WR", rng)

	assert_float(new_hype).is_greater(initial_hype)

func test_slow_speed_decreases_hype() -> void:
	var player := {
		"position": "WR",
		"stats": {
			"speed": 50.0,  # Slow for WR
			"agility": 70.0,
			"strength": 60.0,
			"charisma": 60.0
		}
	}
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0008)
	var initial_hype := 70.0

	var new_hype = HypeGenerator.apply_combine_hype(initial_hype, player, "WR", rng)

	assert_float(new_hype).is_less(initial_hype)

func test_elite_strength_increases_hype_for_linemen() -> void:
	var player := {
		"position": "OL",
		"stats": {
			"speed": 40.0,
			"agility": 45.0,
			"strength": 95.0,  # Elite
			"charisma": 60.0
		}
	}
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0009)
	var initial_hype := 55.0

	var new_hype = HypeGenerator.apply_combine_hype(initial_hype, player, "OL", rng)

	assert_float(new_hype).is_greater(initial_hype)

func test_elite_agility_increases_hype_for_skill_positions() -> void:
	var player := {
		"position": "CB",
		"stats": {
			"speed": 75.0,
			"agility": 92.0,  # Elite
			"strength": 60.0,
			"charisma": 60.0
		}
	}
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0010)
	var initial_hype := 60.0

	var new_hype = HypeGenerator.apply_combine_hype(initial_hype, player, "CB", rng)

	assert_float(new_hype).is_greater(initial_hype)

func test_good_interview_increases_hype() -> void:
	var player := {
		"position": "QB",
		"stats": {
			"speed": 60.0,
			"agility": 65.0,
			"strength": 70.0,
			"charisma": 92.0  # High charisma
		}
	}
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0011)
	var initial_hype := 65.0

	var new_hype = HypeGenerator.apply_combine_hype(initial_hype, player, "QB", rng)

	# High charisma should help in interviews
	assert_float(new_hype).is_greater_equal(initial_hype)


# ============================================================================
# HYPE DECAY TESTS
# ============================================================================

func test_hype_decay_no_change_first_year() -> void:
	var initial_hype := 75.0
	var decayed = HypeGenerator.decay_hype(initial_hype, 0)

	assert_float(decayed).is_equal(initial_hype)

func test_hype_decay_moves_toward_neutral() -> void:
	var high_hype := 90.0
	var decayed = HypeGenerator.decay_hype(high_hype, 3)

	# Should move toward 50 (neutral)
	assert_float(decayed).is_less(high_hype)
	assert_float(decayed).is_greater(50.0)

func test_low_hype_decay_moves_up_toward_neutral() -> void:
	var low_hype := 20.0
	var decayed = HypeGenerator.decay_hype(low_hype, 3)

	# Should move toward 50 (neutral)
	assert_float(decayed).is_greater(low_hype)
	assert_float(decayed).is_less(50.0)

func test_hype_decay_increases_with_years() -> void:
	var initial_hype := 85.0

	var decay_2yr = HypeGenerator.decay_hype(initial_hype, 2)
	var decay_5yr = HypeGenerator.decay_hype(initial_hype, 5)

	# More years = more decay toward 50
	var distance_2yr = abs(decay_2yr - 50.0)
	var distance_5yr = abs(decay_5yr - 50.0)

	assert_float(distance_5yr).is_less(distance_2yr)


# ============================================================================
# BORING PROSPECT PENALTY TESTS
# ============================================================================

func test_boring_prospect_penalty_is_negative() -> void:
	var player := {"position": "OL", "stats": {"charisma": 40.0}}
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xH0012)

	var penalty = HypeGenerator.calculate_boring_prospect_penalty(
		player, 0.2, "pro_style", rng
	)

	assert_float(penalty).is_less_equal(0.0)

func test_small_school_adds_penalty() -> void:
	var player := {"position": "QB", "stats": {"charisma": 60.0}}

	var small_school_total := 0.0
	var big_school_total := 0.0
	var count := 20

	for i in count:
		var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xSS00 + i)
		small_school_total += HypeGenerator.calculate_boring_prospect_penalty(
			player, 0.1, "explosive", rng1
		)

		var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xBS00 + i)
		big_school_total += HypeGenerator.calculate_boring_prospect_penalty(
			player, 0.8, "explosive", rng2
		)

	# Small school should have larger (more negative) penalty
	assert_float(small_school_total).is_less(big_school_total)

func test_pro_style_adds_penalty() -> void:
	var player := {"position": "QB", "stats": {"charisma": 60.0}}
	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xH0013)
	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xH0014)

	var pro_penalty = HypeGenerator.calculate_boring_prospect_penalty(
		player, 0.5, "pro_style", rng1
	)
	var explosive_penalty = HypeGenerator.calculate_boring_prospect_penalty(
		player, 0.5, "explosive", rng2
	)

	# Pro style should have worse (more negative) penalty
	assert_float(pro_penalty).is_less(explosive_penalty)

func test_low_charisma_adds_penalty() -> void:
	var low_charisma_player := {"position": "QB", "stats": {"charisma": 25.0}}
	var high_charisma_player := {"position": "QB", "stats": {"charisma": 85.0}}

	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xH0015)
	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xH0016)

	var low_penalty = HypeGenerator.calculate_boring_prospect_penalty(
		low_charisma_player, 0.5, "explosive", rng1
	)
	var high_penalty = HypeGenerator.calculate_boring_prospect_penalty(
		high_charisma_player, 0.5, "explosive", rng2
	)

	# Low charisma should have worse penalty
	assert_float(low_penalty).is_less(high_penalty)

func test_boring_positions_get_penalty() -> void:
	var ol_player := {"position": "OL", "stats": {"charisma": 60.0}}
	var qb_player := {"position": "QB", "stats": {"charisma": 60.0}}

	var rng1 = TestHelpersGdUnit4.create_seeded_rng(0xH0017)
	var rng2 = TestHelpersGdUnit4.create_seeded_rng(0xH0018)

	var ol_penalty = HypeGenerator.calculate_boring_prospect_penalty(
		ol_player, 0.5, "explosive", rng1
	)
	var qb_penalty = HypeGenerator.calculate_boring_prospect_penalty(
		qb_player, 0.5, "explosive", rng2
	)

	# OL should have worse penalty than QB
	assert_float(ol_penalty).is_less(qb_penalty)
