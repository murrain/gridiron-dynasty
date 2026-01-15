## GdUnit4 test suite for RosterComposition position caps and scheme awareness
##
## Tests that position hard caps are enforced and scheme-aware depth calculations
## work correctly.
extends GdUnitTestSuite

const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")


# =============================================================================
# MAX_DEPTH TESTS
# =============================================================================

func test_max_depth_exists_for_all_positions() -> void:
	# Verify MAX_DEPTH constant has all positions
	assert_bool(RosterComposition.MAX_DEPTH.has("QB")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("RB")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("WR")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("TE")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("OL")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("DL")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("EDGE")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("LB")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("CB")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("S")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("K")).is_true()
	assert_bool(RosterComposition.MAX_DEPTH.has("P")).is_true()


func test_get_max_depth_returns_correct_values() -> void:
	assert_int(RosterComposition.get_max_depth("QB")).is_equal(3)
	assert_int(RosterComposition.get_max_depth("RB")).is_equal(4)
	assert_int(RosterComposition.get_max_depth("WR")).is_equal(7)
	assert_int(RosterComposition.get_max_depth("TE")).is_equal(4)
	assert_int(RosterComposition.get_max_depth("K")).is_equal(1)
	assert_int(RosterComposition.get_max_depth("P")).is_equal(1)


func test_max_depth_greater_or_equal_to_ideal() -> void:
	# MAX_DEPTH should always be >= IDEAL_DEPTH
	for pos in RosterComposition.IDEAL_DEPTH.keys():
		var ideal := RosterComposition.get_ideal_depth(pos)
		var max_allowed := RosterComposition.get_max_depth(pos)
		assert_int(max_allowed).is_greater_equal(ideal)


# =============================================================================
# POSITION CAP TESTS
# =============================================================================

func test_is_position_at_cap_returns_true_when_at_max() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2", "qb3"]  # 3 QBs = at max
		}
	}

	assert_bool(RosterComposition.is_position_at_cap(roster, "QB")).is_true()


func test_is_position_at_cap_returns_true_when_above_max() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2", "qb3", "qb4", "qb5"]  # 5 QBs > max of 3
		}
	}

	assert_bool(RosterComposition.is_position_at_cap(roster, "QB")).is_true()


func test_is_position_at_cap_returns_false_when_below_max() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2"]  # 2 QBs < max of 3
		}
	}

	assert_bool(RosterComposition.is_position_at_cap(roster, "QB")).is_false()


func test_is_position_at_cap_handles_empty_position() -> void:
	var roster := {
		"by_position": {}
	}

	assert_bool(RosterComposition.is_position_at_cap(roster, "QB")).is_false()


func test_get_available_slots_returns_correct_count() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2"]  # 2 QBs, max 3
		}
	}

	assert_int(RosterComposition.get_available_slots(roster, "QB")).is_equal(1)


func test_get_available_slots_returns_zero_at_cap() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2", "qb3"]  # 3 QBs = at max
		}
	}

	assert_int(RosterComposition.get_available_slots(roster, "QB")).is_equal(0)


func test_get_available_slots_returns_zero_above_cap() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2", "qb3", "qb4", "qb5"]  # 5 QBs > max
		}
	}

	assert_int(RosterComposition.get_available_slots(roster, "QB")).is_equal(0)


# =============================================================================
# SCHEME-AWARE DEPTH TESTS
# =============================================================================

func test_scheme_adjusted_ideal_depth_air_raid_more_wrs() -> void:
	var schemes_cfg := _make_test_schemes_cfg()

	var wr_depth := RosterComposition.get_scheme_adjusted_ideal_depth(
		"WR", "air_raid", "cover_2", schemes_cfg
	)

	# Air raid should want 7 WRs (vs default 6)
	assert_int(wr_depth).is_equal(7)


func test_scheme_adjusted_ideal_depth_air_raid_fewer_rbs() -> void:
	var schemes_cfg := _make_test_schemes_cfg()

	var rb_depth := RosterComposition.get_scheme_adjusted_ideal_depth(
		"RB", "air_raid", "cover_2", schemes_cfg
	)

	# Air raid should want 3 RBs (vs default 4)
	assert_int(rb_depth).is_equal(3)


func test_scheme_adjusted_ideal_depth_power_run_more_tes() -> void:
	var schemes_cfg := _make_test_schemes_cfg()

	var te_depth := RosterComposition.get_scheme_adjusted_ideal_depth(
		"TE", "power_run", "cover_2", schemes_cfg
	)

	# Power run should want 4 TEs (vs default 3)
	assert_int(te_depth).is_equal(4)


func test_scheme_adjusted_ideal_depth_3_4_more_lbs() -> void:
	var schemes_cfg := _make_test_schemes_cfg()

	var lb_depth := RosterComposition.get_scheme_adjusted_ideal_depth(
		"LB", "pro_style", "3_4_two_gap", schemes_cfg
	)

	# 3-4 defense should want 7 LBs (vs default 6)
	assert_int(lb_depth).is_equal(7)


func test_scheme_adjusted_ideal_depth_never_exceeds_max() -> void:
	var schemes_cfg := _make_test_schemes_cfg()

	# Even if scheme wants more, should not exceed MAX_DEPTH
	for pos in RosterComposition.MAX_DEPTH.keys():
		var adjusted := RosterComposition.get_scheme_adjusted_ideal_depth(
			pos, "air_raid", "aggressive_blitz", schemes_cfg
		)
		var max_allowed := RosterComposition.get_max_depth(pos)
		assert_int(adjusted).is_less_equal(max_allowed)


# =============================================================================
# POSITION NEED MULTIPLIER TESTS
# =============================================================================

func test_position_need_multiplier_zero_at_cap() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2", "qb3"]  # 3 QBs = at max
		}
	}
	var schemes_cfg := _make_test_schemes_cfg()

	var mult := RosterComposition.calculate_position_need_multiplier(
		roster, "QB", "pro_style", "cover_2", schemes_cfg
	)

	assert_float(mult).is_equal(0.0)


func test_position_need_multiplier_low_when_overstocked() -> void:
	var roster := {
		"by_position": {
			"WR": ["wr1", "wr2", "wr3", "wr4", "wr5", "wr6", "wr7"]  # 7 WRs (at max, above ideal of 6)
		}
	}
	var schemes_cfg := _make_test_schemes_cfg()

	var mult := RosterComposition.calculate_position_need_multiplier(
		roster, "WR", "pro_style", "cover_2", schemes_cfg
	)

	# At max cap = 0.0
	assert_float(mult).is_equal(0.0)


func test_position_need_multiplier_high_when_empty() -> void:
	var roster := {
		"by_position": {}  # No players at any position
	}
	var schemes_cfg := _make_test_schemes_cfg()

	var mult := RosterComposition.calculate_position_need_multiplier(
		roster, "QB", "pro_style", "cover_2", schemes_cfg
	)

	# Empty position = critical need
	assert_float(mult).is_equal(2.0)


func test_position_need_multiplier_neutral_at_ideal() -> void:
	var roster := {
		"by_position": {
			"QB": ["qb1", "qb2", "qb3"]  # 3 QBs = ideal AND max for QB
		}
	}
	var schemes_cfg := _make_test_schemes_cfg()

	# For QB, ideal=3 and max=3, so at ideal = at cap = 0.0
	var mult := RosterComposition.calculate_position_need_multiplier(
		roster, "QB", "pro_style", "cover_2", schemes_cfg
	)

	# At cap = 0.0
	assert_float(mult).is_equal(0.0)


func test_position_need_multiplier_moderate_when_below_ideal() -> void:
	var roster := {
		"by_position": {
			"WR": ["wr1", "wr2", "wr3", "wr4"]  # 4 WRs (below ideal of 6)
		}
	}
	var schemes_cfg := _make_test_schemes_cfg()

	var mult := RosterComposition.calculate_position_need_multiplier(
		roster, "WR", "pro_style", "cover_2", schemes_cfg
	)

	# Below ideal = need (should be > 1.0)
	assert_float(mult).is_greater(1.0)


# =============================================================================
# HELPERS
# =============================================================================

func _make_test_schemes_cfg() -> Dictionary:
	return {
		"offensive_schemes": {
			"air_raid": {
				"philosophy": "Vertical passing, 4-5 wide, stretch the field",
				"roster_requirements": {
					"ideal_depth": {"WR": 7, "RB": 3, "TE": 2, "OL": 9},
					"minimum_depth": {"WR": 6, "RB": 2, "TE": 2}
				}
			},
			"power_run": {
				"philosophy": "Physical, downhill running, heavy personnel",
				"roster_requirements": {
					"ideal_depth": {"WR": 5, "RB": 4, "TE": 4, "OL": 10},
					"minimum_depth": {"WR": 4, "RB": 3, "TE": 3}
				}
			},
			"pro_style": {
				"philosophy": "Balanced, multiple formations, adaptable",
				"roster_requirements": {
					"ideal_depth": {"WR": 6, "RB": 4, "TE": 3, "OL": 9},
					"minimum_depth": {"WR": 5, "RB": 3, "TE": 2}
				}
			}
		},
		"defensive_schemes": {
			"4_3_under": {
				"philosophy": "DE pass rush, athletic LBs, single-gap",
				"roster_requirements": {
					"ideal_depth": {"DL": 7, "EDGE": 4, "LB": 5, "CB": 5, "S": 4},
					"minimum_depth": {"DL": 6, "EDGE": 3, "LB": 4}
				}
			},
			"3_4_two_gap": {
				"philosophy": "Space-eating DL, versatile OLBs, two-gap",
				"roster_requirements": {
					"ideal_depth": {"DL": 5, "EDGE": 5, "LB": 7, "CB": 5, "S": 4},
					"minimum_depth": {"DL": 4, "EDGE": 4, "LB": 6}
				}
			},
			"cover_2": {
				"philosophy": "Zone coverage, split safeties, CBs play flats",
				"roster_requirements": {
					"ideal_depth": {"DL": 6, "EDGE": 4, "LB": 6, "CB": 5, "S": 4},
					"minimum_depth": {"DL": 5, "EDGE": 3, "LB": 5}
				}
			},
			"aggressive_blitz": {
				"philosophy": "Pressure-heavy, disguised blitzes, risk/reward",
				"roster_requirements": {
					"ideal_depth": {"DL": 6, "EDGE": 5, "LB": 7, "CB": 5, "S": 4},
					"minimum_depth": {"DL": 5, "EDGE": 4, "LB": 6}
				}
			}
		},
		"config": {
			"position_caps": {
				"QB": 3, "RB": 4, "WR": 7, "TE": 4, "OL": 10,
				"DL": 7, "EDGE": 5, "LB": 7, "CB": 6, "S": 5,
				"K": 1, "P": 1
			}
		}
	}


# =============================================================================
# COACH MINDSET TESTS
# =============================================================================

const NflDraft = preload("res://scripts/world/NflDraft.gd")


func test_defensive_coach_boosts_defensive_players() -> void:
	var coach := {"specialty_position": "Defense"}
	var draft_strategy := {"generational_threshold": 78.0}

	# Defensive coach boosts defensive positions
	var edge_mult := NflDraft._calculate_coach_mindset_multiplier("EDGE", 70.0, coach, draft_strategy)
	var lb_mult := NflDraft._calculate_coach_mindset_multiplier("LB", 70.0, coach, draft_strategy)
	var cb_mult := NflDraft._calculate_coach_mindset_multiplier("CB", 70.0, coach, draft_strategy)

	assert_float(edge_mult).is_equal(1.08)
	assert_float(lb_mult).is_equal(1.08)
	assert_float(cb_mult).is_equal(1.08)


func test_defensive_coach_penalizes_offensive_players() -> void:
	var coach := {"specialty_position": "Defense"}
	var draft_strategy := {"generational_threshold": 78.0}

	# Defensive coach slightly penalizes offensive positions
	var wr_mult := NflDraft._calculate_coach_mindset_multiplier("WR", 70.0, coach, draft_strategy)
	var rb_mult := NflDraft._calculate_coach_mindset_multiplier("RB", 70.0, coach, draft_strategy)

	assert_float(wr_mult).is_equal(0.97)
	assert_float(rb_mult).is_equal(0.97)


func test_defensive_coach_extra_boost_for_elite_defenders() -> void:
	var coach := {"specialty_position": "Defense"}
	var draft_strategy := {"generational_threshold": 78.0}

	# Elite defenders (78+) get bigger boost from defensive coach
	var elite_edge_mult := NflDraft._calculate_coach_mindset_multiplier("EDGE", 85.0, coach, draft_strategy)
	var standard_edge_mult := NflDraft._calculate_coach_mindset_multiplier("EDGE", 70.0, coach, draft_strategy)

	assert_float(elite_edge_mult).is_equal(1.15)
	assert_float(standard_edge_mult).is_equal(1.08)
	assert_float(elite_edge_mult).is_greater(standard_edge_mult)


func test_offensive_coach_boosts_offensive_players() -> void:
	var coach := {"specialty_position": "Offense"}
	var draft_strategy := {"generational_threshold": 78.0}

	# Offensive coach boosts offensive positions
	var qb_mult := NflDraft._calculate_coach_mindset_multiplier("QB", 70.0, coach, draft_strategy)
	var wr_mult := NflDraft._calculate_coach_mindset_multiplier("WR", 70.0, coach, draft_strategy)

	assert_float(qb_mult).is_equal(1.08)
	assert_float(wr_mult).is_equal(1.08)


func test_offensive_coach_penalizes_defensive_players() -> void:
	var coach := {"specialty_position": "Offense"}
	var draft_strategy := {"generational_threshold": 78.0}

	# Offensive coach slightly penalizes defensive positions
	var edge_mult := NflDraft._calculate_coach_mindset_multiplier("EDGE", 70.0, coach, draft_strategy)
	var cb_mult := NflDraft._calculate_coach_mindset_multiplier("CB", 70.0, coach, draft_strategy)

	assert_float(edge_mult).is_equal(0.97)
	assert_float(cb_mult).is_equal(0.97)


func test_position_specialist_coach_big_boost_for_position() -> void:
	var coach := {"specialty_position": "QB"}
	var draft_strategy := {"generational_threshold": 78.0}

	# QB specialist coach heavily boosts QBs
	var qb_mult := NflDraft._calculate_coach_mindset_multiplier("QB", 70.0, coach, draft_strategy)
	var elite_qb_mult := NflDraft._calculate_coach_mindset_multiplier("QB", 85.0, coach, draft_strategy)

	assert_float(qb_mult).is_equal(1.12)
	assert_float(elite_qb_mult).is_equal(1.18)


func test_position_specialist_still_values_own_side() -> void:
	var coach := {"specialty_position": "QB"}  # Offensive position specialist
	var draft_strategy := {"generational_threshold": 78.0}

	# QB specialist still slightly values other offensive players
	var wr_mult := NflDraft._calculate_coach_mindset_multiplier("WR", 70.0, coach, draft_strategy)
	var edge_mult := NflDraft._calculate_coach_mindset_multiplier("EDGE", 70.0, coach, draft_strategy)

	assert_float(wr_mult).is_equal(1.03)  # Slight boost to offense
	assert_float(edge_mult).is_equal(1.0)  # Neutral for defense


func test_no_specialty_returns_neutral() -> void:
	var coach := {"specialty_position": ""}  # No specialty
	var draft_strategy := {"generational_threshold": 78.0}

	# Coach with no specialty evaluates everyone neutrally
	var qb_mult := NflDraft._calculate_coach_mindset_multiplier("QB", 70.0, coach, draft_strategy)
	var edge_mult := NflDraft._calculate_coach_mindset_multiplier("EDGE", 70.0, coach, draft_strategy)

	assert_float(qb_mult).is_equal(1.0)
	assert_float(edge_mult).is_equal(1.0)


func test_empty_coach_returns_neutral() -> void:
	var coach := {}  # Empty coach dictionary
	var draft_strategy := {"generational_threshold": 78.0}

	# Missing coach data = neutral evaluation
	var qb_mult := NflDraft._calculate_coach_mindset_multiplier("QB", 70.0, coach, draft_strategy)

	assert_float(qb_mult).is_equal(1.0)
