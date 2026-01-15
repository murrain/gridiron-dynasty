## GdUnit4 test suite for RecruitRater
##
## Validates recruit rating and ranking functionality.
## Migrated from test_recruit_rater.gd
extends GdUnitTestSuite

const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")

const ATH_KEYS := [
	"speed", "acceleration", "agility", "balance", "vertical_jump", "broad_jump", "strength"
]
const MENTAL_KEYS := [
	"awareness", "decision_making", "discipline", "work_ethic",
	"coachability", "focus", "composure", "anticipation"
]


func test_recruit_rating_and_ranking() -> void:
	var positions_data := {
		"QB": {
			"core_stats": ["throw_accuracy"],
			"distributions": {"throw_power": {"role": "secondary"}}
		},
		"K": {
			"core_stats": ["kick_power"],
			"distributions": {"kick_accuracy": {"role": "secondary"}}
		}
	}

	var class_rules := {
		"recruiting": {
			"athletic_keys": ATH_KEYS,
			"mental_keys": MENTAL_KEYS,
			"star_thresholds": {"5": 0.98, "4": 0.90, "3": 0.70, "2": 0.40, "1": 0.15},
			"cap_specialists_to_3_stars": true,
			"star_weights": {"core": 0.60, "composite": 0.40}
		}
	}

	var players: Array = []
	for i in range(5):
		players.append(_make_player("QB", 60 + i * 8, 55 + i * 4))
	for i in range(5):
		players.append(_make_player("K", 62 + i * 8, 58 + i * 4))

	var rater: RecruitRater = RecruitRater.new()
	rater.rate_and_rank(players, positions_data, class_rules)

	var qb_stars := _max_star_for_pos(players, "QB")
	var k_stars := _max_star_for_pos(players, "K")

	assert_int(qb_stars).is_equal(5)
	assert_int(k_stars).is_less_equal(3)

	var sample := players[0] as Dictionary
	assert_bool(sample.has("composite_score")).is_true()
	assert_bool(sample.has("rank_overall")).is_true()
	assert_bool(sample.has("rank_in_pos")).is_true()


func test_percentile_affects_composite() -> void:
	var positions_data := {
		"QB": {
			"core_stats": ["throw_accuracy"],
			"distributions": {"throw_power": {"role": "secondary"}}
		}
	}

	var class_rules := {
		"recruiting": {
			"athletic_keys": ATH_KEYS,
			"mental_keys": MENTAL_KEYS,
			"star_thresholds": {"5": 0.98, "4": 0.90, "3": 0.70, "2": 0.40, "1": 0.15},
			"cap_specialists_to_3_stars": true,
			"star_weights": {"core": 0.60, "composite": 0.40}
		}
	}

	var sample := _make_player("QB", 70, 60)

	var percentile_hi: Dictionary = RecruitRater.compute(sample, positions_data, {}, class_rules, {
		"pos": "QB",
		"core_pct": 1.0,
		"sec_pct": 1.0,
		"men_pct": 1.0,
		"ath_pct": 1.0
	})

	var percentile_lo: Dictionary = RecruitRater.compute(sample, positions_data, {}, class_rules, {
		"pos": "QB",
		"core_pct": 0.1,
		"sec_pct": 0.1,
		"men_pct": 0.1,
		"ath_pct": 0.1
	})

	var hi_score := float(percentile_hi.get("composite", 0.0))
	var lo_score := float(percentile_lo.get("composite", 0.0))

	assert_float(hi_score).is_greater(lo_score)


# --- Helper functions ---

func _make_player(pos: String, core_val: float, secondary_val: float) -> Dictionary:
	var stats := _base_stats(50.0)
	if pos == "QB":
		stats["throw_accuracy"] = core_val
		stats["throw_power"] = secondary_val
	elif pos == "K":
		stats["kick_power"] = core_val
		stats["kick_accuracy"] = secondary_val

	return {
		"position": pos,
		"stats": stats,
		"physicals": {"weight_lb": 200.0}
	}


func _base_stats(base: float) -> Dictionary:
	var stats := {}
	for key in ATH_KEYS:
		stats[key] = base
	for key in MENTAL_KEYS:
		stats[key] = base
	return stats


func _max_star_for_pos(players: Array, pos: String) -> int:
	var best := 0
	for p in players:
		var d: Dictionary = p
		if String(d.get("position", "")) != pos:
			continue
		best = max(best, int(d.get("star_rating", 0)))
	return best
