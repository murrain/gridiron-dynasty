## DraftGrader - Calculate draft pick and team draft grades
##
## ARCHITECTURAL PATTERN: Stateless Service
##
## Provides real-time grading for draft picks based on value, need, and fit.
## All calculations are purely deterministic (no RNG).
##
## Grading Factors:
##   - Value (50%): How player's talent compares to draft position
##   - Need (30%): How well pick addresses team positional needs
##   - Fit (20%): How well player fits team's scheme
##
## Letter Grades: A+, A, A-, B+, B, B-, C+, C, C-, D, F
##
## Design Philosophy:
##   - NO RNG - Pure formula-based grading
##   - Stateless - All context passed as parameters
##   - Immediate feedback - Grades calculated in <10ms per pick
##   - Consistent criteria across all picks
##
## Integration Points:
##   - InteractiveDraft: Calculates grade after each pick
##   - DraftDayUI: Displays grades inline with picks
##   - DraftAnalysisScreen: Shows team grades and steals/reaches
##
## Usage:
##   var grader = DraftGrader.new()
##   var grade = grader.grade_pick(player, pick_number, round, needs, scheme, rank, cfg, rules)
##
extends RefCounted
class_name DraftGrader

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Grade thresholds (numeric score to letter grade conversion)
## Scores are 0-100 scale, grades awarded based on threshold
const GRADE_THRESHOLDS := {
	"A+": 95.0,
	"A": 90.0,
	"A-": 87.0,
	"B+": 83.0,
	"B": 80.0,
	"B-": 77.0,
	"C+": 73.0,
	"C": 70.0,
	"C-": 65.0,
	"D": 60.0,
	# Below 60 = F
}

## Grading weights - how much each factor contributes to overall grade
## These must sum to 1.0
const WEIGHT_VALUE := 0.50  # Value: How player's talent compares to pick slot
const WEIGHT_NEED := 0.30   # Need: How well pick addresses team needs
const WEIGHT_FIT := 0.20    # Fit: How well player fits team's scheme

## Rating expectations by pick number
## Used to determine if a pick is good/bad value
const ELITE_PICK_THRESHOLD := 5      # Picks 1-5 expect elite talent (85+)
const FIRST_ROUND_THRESHOLD := 32    # Picks 1-32 expect first-round talent
const DAY_TWO_THRESHOLD := 100       # Picks 33-100 expect day-two talent
const DAY_THREE_THRESHOLD := 224     # Picks 101-224 expect day-three talent

## Expected ratings at various pick slots (linear interpolation between)
const EXPECTED_RATING_PICK_1 := 95.0
const EXPECTED_RATING_PICK_262 := 50.0

## Steal/Reach thresholds for identification
const STEAL_THRESHOLD := 15   # Drafted 15+ spots below consensus = steal
const REACH_THRESHOLD := 15   # Drafted 15+ spots above consensus = reach


## Grade a single pick
##
## Calculates a comprehensive grade based on value, need, and fit.
## Returns a dictionary with letter grade, numeric scores, and analysis.
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary with stats
## @param pick_number: Overall pick number (1-262)
## @param round_number: Draft round (1-7)
## @param team_needs: Dictionary mapping position -> need multiplier
## @param team_scheme: Team's offensive or defensive scheme
## @param consensus_rank: Player's consensus big board rank
## @param positions_cfg: Position configuration for rating calculation
## @param class_rules: Class rules for rating calculation
## @return Dictionary: Grade information
##   {
##     letter_grade: String,
##     overall_score: float,
##     value_score: float,
##     need_score: float,
##     fit_score: float,
##     pick_number: int,
##     round: int,
##     factors: {value_diff, position_need, scheme_match},
##     analysis: String
##   }
func grade_pick(
	player: Dictionary,
	pick_number: int,
	round_number: int,
	team_needs: Dictionary,
	team_scheme: String,
	consensus_rank: int,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Dictionary:
	# Calculate component scores
	var value_score := _calculate_value_score(
		player, pick_number, consensus_rank, positions_cfg, class_rules
	)
	var need_score := _calculate_need_score(player, team_needs)
	var fit_score := _calculate_fit_score(player, team_scheme)

	# Weighted overall score
	var overall_score := (value_score * WEIGHT_VALUE) + \
						 (need_score * WEIGHT_NEED) + \
						 (fit_score * WEIGHT_FIT)

	# Convert to letter grade
	var letter_grade := _score_to_letter(overall_score)

	# Calculate value differential for analysis
	var value_diff := consensus_rank - pick_number

	return {
		"letter_grade": letter_grade,
		"overall_score": overall_score,
		"value_score": value_score,
		"need_score": need_score,
		"fit_score": fit_score,
		"pick_number": pick_number,
		"round": round_number,
		"factors": {
			"value_diff": value_diff,  # Positive = steal, Negative = reach
			"position_need": team_needs.get(String(player.get("position", "")), 1.0),
			"scheme_match": team_scheme
		},
		"analysis": _generate_pick_analysis(
			player, pick_number, value_score, need_score, fit_score, team_needs, value_diff
		)
	}


## Calculate value score: How player's talent compares to pick position
##
## Considers:
## 1. Player's actual rating vs expected rating at pick slot
## 2. Consensus rank vs actual pick (steal/reach factor)
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary
## @param pick_number: Overall pick number
## @param consensus_rank: Player's consensus big board rank
## @param positions_cfg: Position configuration
## @param class_rules: Class rules
## @return float: Value score (0-100)
func _calculate_value_score(
	player: Dictionary,
	pick_number: int,
	consensus_rank: int,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> float:
	# Calculate player's actual rating
	var player_rating := PlayerRatingCalculator.calculate_overall_rating(
		player, positions_cfg, class_rules
	)

	# Calculate expected rating at this pick position
	# Linear interpolation from 95 at pick 1 to 50 at pick 262
	var pick_position_normalized := float(pick_number - 1) / 261.0
	var expected_rating := EXPECTED_RATING_PICK_1 - \
		(pick_position_normalized * (EXPECTED_RATING_PICK_1 - EXPECTED_RATING_PICK_262))

	# Calculate rating differential
	var rating_diff := player_rating - expected_rating

	# Calculate rank differential (positive = drafted below value = steal)
	var rank_diff := consensus_rank - pick_number

	# Base value score starts at 80 (average)
	var value_score := 80.0

	# Add/subtract based on rating vs expected
	# Each point of rating above expected adds 1 to score
	value_score += rating_diff

	# Add/subtract based on consensus rank differential
	# Each spot below consensus adds 0.5 to score (steals get bonus)
	# Each spot above consensus subtracts 0.5 from score (reaches penalized)
	value_score += (float(rank_diff) * 0.5)

	return clamp(value_score, 0.0, 100.0)


## Calculate need score: How well pick addresses team needs
##
## Based on team's position need multiplier:
##   - High need (1.5) = 100 score
##   - Baseline need (1.0) = 70 score
##   - Low need (0.95) = 40 score
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary
## @param team_needs: Dictionary mapping position -> need multiplier
## @return float: Need score (0-100)
func _calculate_need_score(player: Dictionary, team_needs: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var need_multiplier := float(team_needs.get(position, 1.0))

	# Linear scale: 0.95 need = 40, 1.0 = 70, 1.5 = 100
	# Formula: 70 + ((need - 1.0) * 60)
	var need_score := 70.0 + ((need_multiplier - 1.0) * 60.0)

	return clamp(need_score, 0.0, 100.0)


## Calculate fit score: How well player fits team scheme
##
## Checks player's scheme_fit dictionary for matching scheme.
## Falls back to neutral score (75) if no scheme data available.
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary
## @param team_scheme: Team's offensive or defensive scheme
## @return float: Fit score (0-100)
func _calculate_fit_score(player: Dictionary, team_scheme: String) -> float:
	# Check if player has scheme fit data
	var scheme_fit: Dictionary = player.get("scheme_fit", {})

	if scheme_fit.is_empty() or team_scheme.is_empty():
		# No scheme data = neutral score
		return 75.0

	# Get fit rating for team's scheme, default to 75 if not found
	var fit_rating := float(scheme_fit.get(team_scheme, 75.0))

	return clamp(fit_rating, 0.0, 100.0)


## Convert numeric score to letter grade
##
## Iterates through thresholds from highest (A+) to lowest (D).
## Returns "F" if score is below all thresholds.
##
## RNG: None (pure lookup)
##
## @param score: Numeric score (0-100)
## @return String: Letter grade (A+ through F)
func _score_to_letter(score: float) -> String:
	# Check thresholds from highest to lowest
	var grades_ordered := ["A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D"]

	for grade in grades_ordered:
		if score >= GRADE_THRESHOLDS[grade]:
			return grade

	return "F"


## Generate analysis text for pick
##
## Creates a human-readable summary of the pick quality.
##
## RNG: None (pure string generation)
##
## @param player: Player dictionary
## @param pick_number: Overall pick number
## @param value_score: Calculated value score
## @param need_score: Calculated need score
## @param fit_score: Calculated fit score
## @param team_needs: Team's position needs
## @param value_diff: Consensus rank minus pick number
## @return String: Analysis text
func _generate_pick_analysis(
	player: Dictionary,
	pick_number: int,
	value_score: float,
	need_score: float,
	fit_score: float,
	team_needs: Dictionary,
	value_diff: int
) -> String:
	var position := String(player.get("position", ""))
	var need_mult := float(team_needs.get(position, 1.0))
	var parts: Array = []

	# Value assessment
	if value_diff >= STEAL_THRESHOLD:
		parts.append("Excellent value - steal of %d spots" % value_diff)
	elif value_diff >= 5:
		parts.append("Good value pick")
	elif value_diff <= -REACH_THRESHOLD:
		parts.append("Significant reach of %d spots" % abs(value_diff))
	elif value_diff <= -5:
		parts.append("Slight reach")
	else:
		parts.append("Fair value at pick position")

	# Need assessment
	if need_mult >= 1.4:
		parts.append("addresses critical team need")
	elif need_mult >= 1.2:
		parts.append("fills team need")
	elif need_mult < 1.0:
		parts.append("luxury pick (no pressing need)")
	else:
		parts.append("moderate need")

	# Fit assessment
	if fit_score >= 90:
		parts.append("excellent scheme fit")
	elif fit_score >= 80:
		parts.append("good scheme fit")
	elif fit_score < 65:
		parts.append("questionable scheme fit")

	# Combine with proper capitalization
	var analysis := ", ".join(parts)
	return analysis.capitalize() + "."


## Calculate team's overall draft grade
##
## Aggregates grades across all picks made by a team.
## Identifies best and worst picks for summary.
##
## RNG: None (pure calculation)
##
## @param team_id: Team identifier
## @param team_picks: Array of pick dictionaries with grades
## @param team_needs_pre_draft: Team's needs before draft started
## @return Dictionary: Team grade information
##   {
##     team_id: String,
##     overall_grade: String,
##     overall_score: float,
##     pick_count: int,
##     avg_value: float,
##     avg_need: float,
##     avg_fit: float,
##     best_pick: Dictionary,
##     worst_pick: Dictionary,
##     grade_distribution: Dictionary
##   }
func grade_team_draft(
	team_id: String,
	team_picks: Array,
	team_needs_pre_draft: Dictionary
) -> Dictionary:
	if team_picks.is_empty():
		return {
			"team_id": team_id,
			"overall_grade": "N/A",
			"overall_score": 0.0,
			"pick_count": 0,
			"avg_value": 0.0,
			"avg_need": 0.0,
			"avg_fit": 0.0,
			"best_pick": null,
			"worst_pick": null,
			"grade_distribution": {}
		}

	# Aggregate scores
	var total_value := 0.0
	var total_need := 0.0
	var total_fit := 0.0
	var best_pick: Dictionary = team_picks[0]
	var worst_pick: Dictionary = team_picks[0]
	var grade_distribution := {}

	for pick in team_picks:
		var p: Dictionary = pick
		var grade: Dictionary = p.get("grade", {})
		var overall := float(grade.get("overall_score", 70.0))
		var letter := String(grade.get("letter_grade", "C"))

		total_value += float(grade.get("value_score", 70.0))
		total_need += float(grade.get("need_score", 70.0))
		total_fit += float(grade.get("fit_score", 70.0))

		# Track grade distribution
		if not grade_distribution.has(letter):
			grade_distribution[letter] = 0
		grade_distribution[letter] = int(grade_distribution[letter]) + 1

		# Track best pick
		var best_grade: Dictionary = best_pick.get("grade", {})
		if overall > float(best_grade.get("overall_score", 0.0)):
			best_pick = p

		# Track worst pick
		var worst_grade: Dictionary = worst_pick.get("grade", {})
		if overall < float(worst_grade.get("overall_score", 100.0)):
			worst_pick = p

	var pick_count := team_picks.size()
	var avg_value := total_value / float(pick_count)
	var avg_need := total_need / float(pick_count)
	var avg_fit := total_fit / float(pick_count)

	# Calculate overall score using same weights as individual picks
	var overall_score := (avg_value * WEIGHT_VALUE) + \
						 (avg_need * WEIGHT_NEED) + \
						 (avg_fit * WEIGHT_FIT)

	return {
		"team_id": team_id,
		"overall_grade": _score_to_letter(overall_score),
		"overall_score": overall_score,
		"pick_count": pick_count,
		"avg_value": avg_value,
		"avg_need": avg_need,
		"avg_fit": avg_fit,
		"best_pick": best_pick,
		"worst_pick": worst_pick,
		"grade_distribution": grade_distribution
	}


## Identify steals (drafted significantly below consensus)
##
## Returns picks where value_diff >= threshold (positive = steal).
## Sorted by value differential (biggest steals first).
##
## RNG: None (pure filtering)
##
## @param draft_picks: Array of all pick dictionaries
## @param threshold: Minimum value_diff to qualify as steal (default 15)
## @return Array: Steals sorted by value differential
func identify_steals(draft_picks: Array, threshold: int = STEAL_THRESHOLD) -> Array:
	var steals: Array = []

	for pick in draft_picks:
		var p: Dictionary = pick
		var grade: Dictionary = p.get("grade", {})
		var factors: Dictionary = grade.get("factors", {})
		var value_diff := int(factors.get("value_diff", 0))

		# Positive value_diff = drafted below consensus rank = steal
		if value_diff >= threshold:
			steals.append({
				"player_id": p.get("player_id"),
				"player_name": p.get("player_name"),
				"position": p.get("position"),
				"team_id": p.get("team_id"),
				"pick_number": p.get("pick"),
				"consensus_rank": int(p.get("pick")) - value_diff,
				"value_diff": value_diff,
				"grade": grade.get("letter_grade", "B")
			})

	# Sort by value diff (biggest steals first)
	steals.sort_custom(func(a, b):
		return int(a.get("value_diff", 0)) > int(b.get("value_diff", 0))
	)

	return steals


## Identify reaches (drafted significantly above consensus)
##
## Returns picks where value_diff <= -threshold (negative = reach).
## Sorted by value differential (biggest reaches first).
##
## RNG: None (pure filtering)
##
## @param draft_picks: Array of all pick dictionaries
## @param threshold: Minimum reach magnitude to qualify (default 15)
## @return Array: Reaches sorted by value differential
func identify_reaches(draft_picks: Array, threshold: int = REACH_THRESHOLD) -> Array:
	var reaches: Array = []

	for pick in draft_picks:
		var p: Dictionary = pick
		var grade: Dictionary = p.get("grade", {})
		var factors: Dictionary = grade.get("factors", {})
		var value_diff := int(factors.get("value_diff", 0))

		# Negative value_diff = drafted above consensus rank = reach
		if value_diff <= -threshold:
			reaches.append({
				"player_id": p.get("player_id"),
				"player_name": p.get("player_name"),
				"position": p.get("position"),
				"team_id": p.get("team_id"),
				"pick_number": p.get("pick"),
				"consensus_rank": int(p.get("pick")) - value_diff,
				"value_diff": value_diff,
				"grade": grade.get("letter_grade", "C")
			})

	# Sort by value diff (biggest reaches first, most negative)
	reaches.sort_custom(func(a, b):
		return int(a.get("value_diff", 0)) < int(b.get("value_diff", 0))
	)

	return reaches


## Generate draft report card for export
##
## Creates a comprehensive report of the entire draft including
## team grades, steals, reaches, and notable picks.
##
## RNG: None (pure data aggregation)
##
## @param draft_results: Dictionary with picks array
## @param all_team_needs: Dictionary of team_id -> pre-draft needs
## @return Dictionary: Complete draft report
func generate_draft_report(
	draft_results: Dictionary,
	all_team_needs: Dictionary
) -> Dictionary:
	var all_picks: Array = draft_results.get("picks", [])

	# Group picks by team
	var teams_by_id := {}
	for pick in all_picks:
		var p: Dictionary = pick
		var team_id := String(p.get("team_id", ""))
		if not teams_by_id.has(team_id):
			teams_by_id[team_id] = []
		teams_by_id[team_id].append(p)

	# Grade each team
	var team_grades: Array = []
	for team_id in teams_by_id.keys():
		var team_picks: Array = teams_by_id[team_id]
		var team_needs: Dictionary = all_team_needs.get(team_id, {})
		var grade := grade_team_draft(team_id, team_picks, team_needs)
		team_grades.append(grade)

	# Sort by overall score
	team_grades.sort_custom(func(a, b):
		return float(a.get("overall_score", 0.0)) > float(b.get("overall_score", 0.0))
	)

	# Identify steals and reaches
	var steals := identify_steals(all_picks)
	var reaches := identify_reaches(all_picks)

	# Calculate overall draft statistics
	var total_score := 0.0
	for grade in team_grades:
		total_score += float(grade.get("overall_score", 0.0))
	var avg_score := total_score / float(max(team_grades.size(), 1))

	return {
		"year": draft_results.get("year", 0),
		"total_picks": all_picks.size(),
		"team_grades": team_grades,
		"best_draft": team_grades[0] if not team_grades.is_empty() else null,
		"worst_draft": team_grades[-1] if not team_grades.is_empty() else null,
		"steals": steals,
		"reaches": reaches,
		"steal_of_draft": steals[0] if not steals.is_empty() else null,
		"biggest_reach": reaches[0] if not reaches.is_empty() else null,
		"avg_team_score": avg_score,
		"avg_team_grade": _score_to_letter(avg_score)
	}


## Get grade color for UI display
##
## Returns a color suitable for displaying the grade.
##
## @param letter_grade: The letter grade (A+ through F)
## @return Color: Display color
static func get_grade_color(letter_grade: String) -> Color:
	match letter_grade:
		"A+", "A":
			return Color(0.0, 0.8, 0.0)  # Green
		"A-", "B+":
			return Color(0.4, 0.8, 0.2)  # Light green
		"B", "B-":
			return Color(0.8, 0.8, 0.0)  # Yellow
		"C+", "C":
			return Color(0.9, 0.6, 0.0)  # Orange
		"C-", "D":
			return Color(0.9, 0.3, 0.0)  # Dark orange
		"F":
			return Color(0.8, 0.0, 0.0)  # Red
		_:
			return Color(0.5, 0.5, 0.5)  # Gray


## Get quick summary for a pick grade
##
## Returns a short one-line summary of the pick.
##
## @param grade: Grade dictionary from grade_pick()
## @return String: One-line summary
static func get_quick_summary(grade: Dictionary) -> String:
	var letter := String(grade.get("letter_grade", "C"))
	var factors: Dictionary = grade.get("factors", {})
	var value_diff := int(factors.get("value_diff", 0))

	if value_diff >= 15:
		return "%s - STEAL" % letter
	elif value_diff >= 5:
		return "%s - Good Value" % letter
	elif value_diff <= -15:
		return "%s - REACH" % letter
	elif value_diff <= -5:
		return "%s - Slight Reach" % letter
	else:
		return "%s - Fair" % letter
