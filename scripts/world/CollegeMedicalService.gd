extends RefCounted
class_name CollegeMedicalService

## College Medical Service
##
## Purpose: Medical evaluation layer for draft prospects based on college injury history.
##
## This service wraps the existing PlayerLifecycle injury system (PlayerLifecycle._apply_injury,
## _generate_injury) and adds:
##   1. College context annotation (year, games_missed) to injuries
##   2. Pre-draft medical evaluation and grading
##   3. Hype impact from injuries (affects draft stock via media perception)
##   4. Player history tracking for injuries
##
## Hype Integration:
##   - Injuries reduce hype based on severity and timing
##   - Recent injuries (close to draft) have larger immediate impact
##   - Halflife allows hype recovery as player demonstrates health
##   - Teams have separate medical tolerance from character tolerance
##
## Key Design Decision: This service does NOT generate injuries - that's handled by
## PlayerLifecycle.advance_one_year(). This service only analyzes existing injury data
## and annotates it with college-specific context.
##
## RNG Pattern: None - all functions are deterministic analysis of existing data
## Integration Points: CollegeSeason (context annotation), NflDraft (evaluation)

## Annotates the most recent injury with college-specific context.
##
## Called by CollegeSeason after PlayerLifecycle generates injuries during yearly progression.
## Adds college year and games missed to the injury record for draft evaluation.
## Also applies hype impact and adds injury to player history.
##
## Algorithm:
##   1. Get most recent injury from player's injuries array
##   2. Add college_injury_context with year and games_missed
##   3. Calculate games_missed based on severity and recovery timeline
##   4. Apply hype impact based on injury severity
##   5. Add injury to player history
##
## RNG: None (deterministic annotation)
##
## @param player: Player dictionary with injuries array
## @param year: Current college year (1-4)
## @param games_in_season: Number of games in college season (typically 12)
## @param config: Medical configuration with hype impact settings
static func apply_college_injury_context(
	player: Dictionary,
	year: int,
	games_in_season: int,
	config: Dictionary = {}
) -> void:
	var injuries: Array = player.get("injuries", []) as Array
	if injuries.is_empty():
		return

	# Get most recent injury (last in array)
	var recent_injury: Dictionary = injuries[injuries.size() - 1] as Dictionary

	# Skip if already annotated (prevents double-annotation)
	if recent_injury.has("college_injury_context"):
		return

	# Calculate games missed based on severity and recovery years
	var severity := float(recent_injury.get("severity", 1.0))
	var recovery: Dictionary = recent_injury.get("recovery_timeline", {}) as Dictionary
	var recovery_years := int(recovery.get("years_total", 0))
	var injury_type := String(recent_injury.get("type", "general"))
	var body_part := String(recent_injury.get("body_part", ""))

	# Games missed formula: severity * 2 (immediate impact) + recovery_years * games_in_season
	# Examples:
	#   - Minor injury (severity 1.0, 0 year recovery): 2 games
	#   - Moderate injury (severity 2.0, 1 year recovery): 4 + 12 = 16 games
	#   - Major injury (severity 3.0, 2 year recovery): 6 + 24 = 30 games
	var immediate_games_missed := int(round(severity * 2.0))
	var extended_games_missed := recovery_years * games_in_season
	var total_games_missed := immediate_games_missed + extended_games_missed

	# Cap at reasonable maximum (4 seasons worth)
	total_games_missed = min(total_games_missed, games_in_season * 4)

	# Calculate hype impact based on severity
	var hype_cfg: Dictionary = config.get("injury_hype_impact", {})
	var hype_impact := _calculate_injury_hype_impact(severity, injury_type, hype_cfg)
	var halflife := _calculate_injury_halflife(severity, hype_cfg)

	# Add college context to injury
	recent_injury["college_injury_context"] = {
		"year": year,
		"games_missed": total_games_missed,
		"hype_impact": hype_impact,
		"halflife_years": halflife
	}

	# Apply hype impact
	var current_hype := float(player.get("hype", 50.0))
	player["hype"] = clamp(current_hype + hype_impact, 0.0, 100.0)

	# Track decaying hype modifier
	if not player.has("hype_modifiers"):
		player["hype_modifiers"] = []
	var modifiers: Array = player["hype_modifiers"]
	modifiers.append({
		"source": "injury_" + injury_type,
		"year_applied": year,
		"initial_impact": hype_impact,
		"halflife_years": halflife
	})

	# Add to player history
	if not player.has("history"):
		player["history"] = []
	var history: Array = player["history"]
	var injury_desc := _get_injury_description(injury_type, body_part, severity)
	history.append({
		"type": "injury",
		"year": year,
		"event": injury_type,
		"description": injury_desc,
		"severity": severity,
		"games_missed": total_games_missed,
		"hype_impact": hype_impact,
		"halflife_years": halflife
	})


## Evaluates a player's medical status for draft evaluation.
##
## Called by NflDraft before scout evaluation to assign medical grade.
## Analyzes complete college injury history to determine draft risk.
##
## Medical Grade Criteria:
##   - "clean": ≤1 injury, no surgeries, low severity sum
##   - "minor_concern": ≤2 injuries, ≤1 surgery, moderate severity
##   - "major_concern": ≤4 injuries, ≤2 surgeries, high severity
##   - "failed": Career-ending injury, recurring major injuries, multiple surgeries
##
## Algorithm:
##   1. Count total injuries, surgeries, and sum severity
##   2. Check for career-ending injuries (automatic fail)
##   3. Check for recurring injury patterns (same type 2+ times)
##   4. Apply grade criteria from config
##   5. Calculate durability projection and draft impact
##
## RNG: None (deterministic evaluation)
##
## @param player: Player dictionary with injuries array
## @param config: Main configuration with medical_evaluation section
## @return Dictionary: medical_evaluation structure
static func evaluate_medical_status(
	player: Dictionary,
	config: Dictionary
) -> Dictionary:
	var medical_cfg: Dictionary = config.get("medical_evaluation", {}) as Dictionary
	var injuries: Array = player.get("injuries", []) as Array

	# Initialize evaluation structure
	var evaluation := {
		"grade": "clean",
		"red_flags": [],
		"durability_projection": 1.0,
		"draft_impact": 1.0,
		"injury_count": 0,
		"surgery_count": 0,
		"severity_sum": 0.0,
		"recurring_injuries": []
	}

	# Empty injury history = clean bill of health
	if injuries.is_empty():
		return evaluation

	# Analyze injury history
	var surgery_types: Array = medical_cfg.get("surgery_required_types", ["knee", "shoulder", "back"]) as Array
	var injury_type_counts := {}
	var surgery_count := 0
	var severity_sum := 0.0

	for injury_entry in injuries:
		var injury: Dictionary = injury_entry as Dictionary
		var injury_type := String(injury.get("type", ""))
		var severity := float(injury.get("severity", 0.0))
		var career_ending := bool(injury.get("career_ending", false))

		# Count injury types for recurring pattern detection
		if injury_type != "":
			injury_type_counts[injury_type] = int(injury_type_counts.get(injury_type, 0)) + 1

		# Check for surgery requirement
		if injury_type in surgery_types and severity >= 2.0:
			surgery_count += 1

		# Accumulate severity
		severity_sum += severity

		# Career-ending injury = automatic medical fail
		if career_ending:
			evaluation["grade"] = "failed"
			evaluation["red_flags"].append("career_ending_injury")
			evaluation["durability_projection"] = 0.0
			evaluation["draft_impact"] = 0.70  # Major draft penalty
			evaluation["injury_count"] = injuries.size()
			evaluation["surgery_count"] = surgery_count
			evaluation["severity_sum"] = severity_sum
			return evaluation

	# Check for recurring injuries (same type 2+ times)
	var recurring_mult := float(medical_cfg.get("recurring_injury_multiplier", 1.5))
	for injury_type in injury_type_counts.keys():
		var count := int(injury_type_counts[injury_type])
		if count >= 2:
			evaluation["recurring_injuries"].append(injury_type)
			severity_sum += (float(count) - 1.0) * recurring_mult  # Penalty for recurring

	evaluation["injury_count"] = injuries.size()
	evaluation["surgery_count"] = surgery_count
	evaluation["severity_sum"] = severity_sum

	# Apply grade criteria
	var grade_criteria: Dictionary = medical_cfg.get("grade_criteria", {}) as Dictionary
	var grade := _determine_medical_grade(
		injuries.size(),
		surgery_count,
		severity_sum,
		evaluation["recurring_injuries"].size() > 0,
		grade_criteria
	)

	evaluation["grade"] = grade

	# Add red flags based on grade
	if grade == "failed":
		if evaluation["recurring_injuries"].size() > 0:
			evaluation["red_flags"].append("recurring_major_injuries")
		if surgery_count >= 3:
			evaluation["red_flags"].append("multiple_surgeries")
	elif grade == "major_concern":
		if evaluation["recurring_injuries"].size() > 0:
			evaluation["red_flags"].append("recurring_injuries")
		if surgery_count >= 2:
			evaluation["red_flags"].append("multiple_surgeries")

	# Calculate durability projection (0.0-1.0)
	# Formula: Base 1.0, reduced by injuries and severity
	var durability := 1.0
	durability -= float(injuries.size()) * 0.08  # -8% per injury
	durability -= severity_sum * 0.02  # -2% per severity point
	durability -= float(surgery_count) * 0.12  # -12% per surgery
	if evaluation["recurring_injuries"].size() > 0:
		durability -= 0.15  # -15% for recurring pattern
	durability = clamp(durability, 0.3, 1.0)

	evaluation["durability_projection"] = durability

	# Calculate draft impact multiplier
	var impact_multipliers: Dictionary = medical_cfg.get("draft_impact_multipliers", {}) as Dictionary
	evaluation["draft_impact"] = float(impact_multipliers.get(grade, 1.0))

	return evaluation


## Determines medical grade based on injury metrics and criteria.
##
## Internal helper for evaluate_medical_status().
## Applies cascading grade logic from failed → major → minor → clean.
##
## RNG: None (deterministic logic)
##
## @param injury_count: Total number of injuries
## @param surgery_count: Number of surgeries required
## @param severity_sum: Sum of all injury severity values
## @param has_recurring: Whether player has recurring injury pattern
## @param criteria: Grade criteria from config
## @return String: Medical grade ("clean", "minor_concern", "major_concern", "failed")
static func _determine_medical_grade(
	injury_count: int,
	surgery_count: int,
	severity_sum: float,
	has_recurring: bool,
	criteria: Dictionary
) -> String:
	# Failed criteria (most restrictive)
	var failed_triggers: Array = criteria.get("failed", {}).get("triggers", []) as Array
	if has_recurring and "recurring_major" in failed_triggers:
		return "failed"
	if surgery_count >= 3 and "multiple_surgeries" in failed_triggers:
		return "failed"

	# Major concern criteria
	var major: Dictionary = criteria.get("major_concern", {}) as Dictionary
	var major_max_injuries := int(major.get("max_injuries", 4))
	var major_max_surgeries := int(major.get("max_surgeries", 2))
	var major_max_severity := float(major.get("max_severity_sum", 12.0))
	if injury_count > major_max_injuries or surgery_count > major_max_surgeries or severity_sum > major_max_severity:
		return "major_concern"

	# Minor concern criteria
	var minor: Dictionary = criteria.get("minor_concern", {}) as Dictionary
	var minor_max_injuries := int(minor.get("max_injuries", 2))
	var minor_max_surgeries := int(minor.get("max_surgeries", 1))
	var minor_max_severity := float(minor.get("max_severity_sum", 6.0))
	if injury_count > minor_max_injuries or surgery_count > minor_max_surgeries or severity_sum > minor_max_severity:
		return "minor_concern"

	# Clean criteria (least restrictive)
	var clean: Dictionary = criteria.get("clean", {}) as Dictionary
	var clean_max_injuries := int(clean.get("max_injuries", 1))
	var clean_max_surgeries := int(clean.get("max_surgeries", 0))
	var clean_max_severity := float(clean.get("max_severity_sum", 3.0))
	if injury_count <= clean_max_injuries and surgery_count <= clean_max_surgeries and severity_sum <= clean_max_severity:
		return "clean"

	# Default to minor_concern if no criteria matched
	return "minor_concern"


## Calculates draft impact multiplier from medical evaluation.
##
## Simple helper that extracts draft_impact from medical_evaluation.
## Included for API consistency with CharacterService.
##
## RNG: None (deterministic lookup)
##
## @param player: Player dictionary with medical_evaluation field
## @param config: Configuration (unused, kept for API consistency)
## @return float: Draft impact multiplier (0.7-1.0)
static func calculate_draft_medical_impact(
	player: Dictionary,
	config: Dictionary
) -> float:
	var medical_eval: Dictionary = player.get("medical_evaluation", {}) as Dictionary
	return float(medical_eval.get("draft_impact", 1.0))


## Checks if a player has a recurring injury pattern.
##
## Called during injury generation to detect if new injury is a repeat.
## Used for additional medical red flags and draft evaluation.
##
## Algorithm:
##   1. Count occurrences of new_injury_type in injury history
##   2. If count >= 2, player has recurring pattern
##
## RNG: None (deterministic count)
##
## @param player: Player dictionary with injuries array
## @param new_injury_type: Type of new injury to check
## @param config: Configuration (unused, kept for future extensibility)
## @return bool: True if player has 2+ injuries of this type
static func check_for_recurring_injury(
	player: Dictionary,
	new_injury_type: String,
	config: Dictionary
) -> bool:
	var injuries: Array = player.get("injuries", []) as Array
	var count := 0

	for injury_entry in injuries:
		var injury: Dictionary = injury_entry as Dictionary
		if String(injury.get("type", "")) == new_injury_type:
			count += 1

	# 2+ injuries of same type = recurring pattern
	return count >= 2


## Calculates hype impact for an injury based on severity and type.
##
## More severe injuries have larger negative hype impact.
## Certain injury types (knee, back) are viewed more negatively by scouts.
##
## @param severity: Injury severity (1.0-5.0 scale)
## @param injury_type: Type of injury (knee, shoulder, etc.)
## @param config: Hype impact configuration
## @return float: Negative hype impact
static func _calculate_injury_hype_impact(
	severity: float,
	injury_type: String,
	config: Dictionary
) -> float:
	# Base impact scales with severity
	var base_per_severity := float(config.get("base_per_severity", -4.0))
	var base_impact := severity * base_per_severity

	# Type multipliers - some injuries are viewed worse than others
	var type_multipliers: Dictionary = config.get("type_multipliers", {
		"knee": 1.5,      # ACL/MCL tears are draft killers
		"back": 1.4,      # Back issues are chronic concerns
		"shoulder": 1.2,  # Especially for QBs/pitchers
		"ankle": 1.0,     # Standard
		"hamstring": 0.9, # Common, less concerning
		"concussion": 1.3 # CTE concerns
	})

	var multiplier := float(type_multipliers.get(injury_type, 1.0))
	return base_impact * multiplier


## Calculates halflife for injury hype impact based on severity.
##
## Minor injuries fade quickly, major injuries linger in scouts' minds.
##
## @param severity: Injury severity (1.0-5.0 scale)
## @param config: Hype impact configuration
## @return float: Halflife in years
static func _calculate_injury_halflife(
	severity: float,
	config: Dictionary
) -> float:
	# Base halflife + severity modifier
	var base_halflife := float(config.get("base_halflife", 0.5))
	var severity_modifier := float(config.get("halflife_per_severity", 0.25))

	return base_halflife + (severity * severity_modifier)


## Generates a human-readable injury description.
##
## @param injury_type: Type of injury
## @param body_part: Body part affected
## @param severity: Injury severity
## @return String: Description for history
static func _get_injury_description(
	injury_type: String,
	body_part: String,
	severity: float
) -> String:
	var severity_label := "minor"
	if severity >= 4.0:
		severity_label = "severe"
	elif severity >= 3.0:
		severity_label = "major"
	elif severity >= 2.0:
		severity_label = "moderate"

	if body_part != "":
		return "Suffered %s %s injury (%s)" % [severity_label, body_part, injury_type]
	else:
		return "Suffered %s %s injury" % [severity_label, injury_type]


## Evaluates how a specific team views a player's medical concerns.
##
## Some teams are more willing to draft players with injury history
## if they believe the talent is worth the risk. This is separate from
## character tolerance - a team might be strict on character but lenient
## on medical, or vice versa.
##
## Team medical tolerance levels:
##   - "risk_averse": 1.5x penalty (avoid injury-prone players)
##   - "cautious": 1.0x penalty (normal evaluation)
##   - "moderate_risk": 0.7x penalty (willing to take some risk)
##   - "aggressive": 0.4x penalty (talent over durability)
##
## @param player: Player dictionary with medical_evaluation
## @param team: Team dictionary with medical_tolerance setting
## @param config: Medical configuration
## @return float: Adjusted medical evaluation score (0-100)
static func evaluate_for_team(
	player: Dictionary,
	team: Dictionary,
	config: Dictionary
) -> float:
	var tolerance := String(team.get("medical_tolerance", "cautious"))
	var tolerance_cfg: Dictionary = config.get("team_medical_tolerance", {})
	var tolerance_settings: Dictionary = tolerance_cfg.get(tolerance, {})

	var penalty_multiplier := float(tolerance_settings.get("penalty_multiplier", 1.0))

	var medical_eval: Dictionary = player.get("medical_evaluation", {})
	var grade := String(medical_eval.get("grade", "clean"))

	# Base score: 100 for clean, lower for concerns
	var base_scores := {
		"clean": 100.0,
		"minor_concern": 85.0,
		"major_concern": 60.0,
		"failed": 30.0
	}
	var base_score := float(base_scores.get(grade, 70.0))

	# Apply tolerance - aggressive teams see less penalty
	var penalty := 100.0 - base_score
	var adjusted_penalty := penalty * penalty_multiplier
	return 100.0 - adjusted_penalty


## Calculates total hype impact from all injuries.
##
## @param player: Player dictionary with injuries
## @return float: Total cumulative hype impact from injuries
static func calculate_injury_hype_impact(
	player: Dictionary
) -> float:
	var injuries: Array = player.get("injuries", []) as Array
	var total_impact := 0.0

	for injury_entry in injuries:
		var injury: Dictionary = injury_entry as Dictionary
		var context: Dictionary = injury.get("college_injury_context", {})
		total_impact += float(context.get("hype_impact", 0.0))

	return total_impact
