extends RefCounted
class_name CharacterService

const Rand = preload("res://autoloads/Rand.gd")

## Character Service
##
## Purpose: Track discipline events and character grading for draft prospects.
##
## This service handles:
##   1. Random discipline event generation during college years
##   2. Character grade evaluation based on discipline history
##   3. Draft impact calculation based on character concerns
##
## Design Philosophy:
##   - Discipline events are rare (2% base chance per year) but impactful
##   - Character grades range from "exemplary" (bonus) to "red_flag" (major penalty)
##   - Severity escalates: academic < team_rules < substance < conduct < legal
##
## RNG Pattern: 2-3 calls per player per year (if event occurs)
##   - Call 1: Event occurrence roll (randf)
##   - Call 2: Event type selection (weighted random)
##   - Call 3: Games suspended (randi_range)
##
## Integration Points: CollegeSeason (event generation), NflDraft (evaluation)

## Applies random discipline events during college season.
##
## Called by CollegeSeason after player lifecycle progression.
## Rolls for discipline event occurrence and generates event details if triggered.
##
## Algorithm:
##   1. Initialize character_profile if not exists
##   2. Roll for event occurrence (base 2% chance)
##   3. If event occurs, select type via weighted random
##   4. Roll for games suspended based on type's range
##   5. Append event to discipline_record
##
## RNG Consumption:
##   - Call 1: Event occurrence (randf)
##   - Call 2: Event type selection (weighted randf)
##   - Call 3: Games suspended (randi_range)
##   Total: 3 calls if event occurs, 1 call if no event
##
## @param player: Player dictionary
## @param year: Current college year (1-4)
## @param config: Character system configuration
## @param rng: Explicit RNG instance for determinism
## @return Dictionary: Event details if occurred, empty dict otherwise
static func apply_discipline_events(
	player: Dictionary,
	year: int,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# Initialize character_profile if not exists
	if not player.has("character_profile"):
		player["character_profile"] = {
			"discipline_record": [],
			"character_grade": "clean",
			"character_draft_impact": 1.0
		}

	var discipline_cfg: Dictionary = config.get("discipline_events", {}) as Dictionary
	var base_chance := float(discipline_cfg.get("base_chance_per_year", 0.02))
	var event_types: Array = discipline_cfg.get("types", []) as Array

	if event_types.is_empty():
		return {}

	# RNG Call 1: Event occurrence roll
	var roll := rng.randf()
	if roll >= base_chance:
		return {}  # No event this year

	# Event occurred - select type via weighted random
	# RNG Call 2: Weighted type selection
	var total_weight := 0.0
	for event_def in event_types:
		total_weight += float((event_def as Dictionary).get("weight", 0.0))

	var type_roll := rng.randf() * total_weight
	var accumulated := 0.0
	var selected_type: Dictionary = {}

	for event_def in event_types:
		var def: Dictionary = event_def as Dictionary
		accumulated += float(def.get("weight", 0.0))
		if type_roll <= accumulated:
			selected_type = def
			break

	if selected_type.is_empty():
		return {}  # Shouldn't happen, but safety check

	# RNG Call 3: Games suspended (random in range)
	var games_range: Array = selected_type.get("games_range", [1, 2]) as Array
	var games_min := int(games_range[0])
	var games_max := int(games_range[1])
	var games_suspended := rng.randi_range(games_min, games_max)

	# Create event record
	var event := {
		"year": year,
		"type": String(selected_type.get("type", "unknown")),
		"games": games_suspended,
		"severity": String(selected_type.get("severity", "minor")),
		"reason": _generate_reason(selected_type.get("type", ""), rng)
	}

	# Append to discipline record
	var profile: Dictionary = player["character_profile"] as Dictionary
	var discipline_record: Array = profile.get("discipline_record", []) as Array
	discipline_record.append(event)
	profile["discipline_record"] = discipline_record

	return event


## Evaluates character grade based on discipline history.
##
## Called by NflDraft before scout evaluation to assign character grade.
## Analyzes complete discipline record to determine character concerns.
##
## Character Grade Logic:
##   - "exemplary": No incidents, high character
##   - "clean": 0-1 minor incident only
##   - "concern": 2+ minor or 1 moderate incident
##   - "red_flag": Legal trouble, multiple major incidents, or pattern
##
## Algorithm:
##   1. Count incidents by severity level
##   2. Check for legal trouble (automatic red flag)
##   3. Check for pattern (multiple similar incidents)
##   4. Apply grade criteria from config
##
## RNG: None (deterministic evaluation)
##
## @param player: Player dictionary with character_profile
## @param config: Character system configuration
## @return String: Character grade
static func evaluate_character_grade(
	player: Dictionary,
	config: Dictionary
) -> String:
	var profile: Dictionary = player.get("character_profile", {}) as Dictionary
	var discipline_record: Array = profile.get("discipline_record", []) as Array

	# No incidents = exemplary
	if discipline_record.is_empty():
		return "exemplary"

	var grade_criteria: Dictionary = config.get("character_grades", {}) as Dictionary

	# Count incidents by severity
	var severity_counts := {
		"minor": 0,
		"moderate": 0,
		"major": 0,
		"severe": 0
	}

	var incident_types := {}
	var has_legal_trouble := false

	for event_entry in discipline_record:
		var event: Dictionary = event_entry as Dictionary
		var severity := String(event.get("severity", "minor"))
		var event_type := String(event.get("type", ""))

		# Count severity
		if severity_counts.has(severity):
			severity_counts[severity] = int(severity_counts[severity]) + 1

		# Track incident types for pattern detection
		incident_types[event_type] = int(incident_types.get(event_type, 0)) + 1

		# Check for legal trouble
		if event_type == "legal_trouble":
			has_legal_trouble = true

	# Apply red flag criteria
	var red_flag_triggers: Array = (grade_criteria.get("red_flag", {}) as Dictionary).get("triggers", []) as Array

	if has_legal_trouble and "legal_trouble" in red_flag_triggers:
		return "red_flag"

	# Check for multiple major incidents (2+ major or severe)
	var major_count := int(severity_counts.get("major", 0)) + int(severity_counts.get("severe", 0))
	if major_count >= 2 and "multiple_major" in red_flag_triggers:
		return "red_flag"

	# Check for pattern (3+ incidents of same type)
	for type_name in incident_types.keys():
		if int(incident_types[type_name]) >= 3 and "pattern" in red_flag_triggers:
			return "red_flag"

	# Apply concern criteria
	var concern_criteria: Dictionary = grade_criteria.get("concern", {}) as Dictionary
	var concern_max_incidents := int(concern_criteria.get("max_incidents", 2))
	var concern_max_severity := String(concern_criteria.get("max_severity", "moderate"))

	var total_incidents := discipline_record.size()
	var has_moderate_or_worse := (
		int(severity_counts.get("moderate", 0)) > 0 or
		int(severity_counts.get("major", 0)) > 0 or
		int(severity_counts.get("severe", 0)) > 0
	)

	if total_incidents > concern_max_incidents:
		return "concern"
	if has_moderate_or_worse and concern_max_severity == "minor":
		return "concern"

	# Apply clean criteria
	var clean_criteria: Dictionary = grade_criteria.get("clean", {}) as Dictionary
	var clean_max_incidents := int(clean_criteria.get("max_incidents", 1))
	var clean_max_severity := String(clean_criteria.get("max_severity", "minor"))

	if total_incidents <= clean_max_incidents:
		# Check severity constraint
		var only_minor := (
			int(severity_counts.get("minor", 0)) == total_incidents
		)
		if only_minor or clean_max_severity != "minor":
			return "clean"

	# Default to concern if no criteria matched
	return "concern"


## Calculates draft impact multiplier from character grade.
##
## Called by NflDraft during scout evaluation to adjust draft score.
## Applies configured multipliers based on character grade.
##
## Multiplier Examples:
##   - exemplary: 1.02 (2% boost)
##   - clean: 1.0 (no change)
##   - concern: 0.95 (5% penalty)
##   - red_flag: 0.70-0.90 (10-30% penalty, varies by severity)
##
## Algorithm:
##   1. Get character grade from player's character_profile
##   2. Look up multiplier from config
##   3. For red_flag, calculate penalty based on incident severity
##
## RNG: None (deterministic calculation)
##
## @param player: Player dictionary with character_profile
## @param config: Character system configuration
## @return float: Draft impact multiplier
static func calculate_character_draft_impact(
	player: Dictionary,
	config: Dictionary
) -> float:
	var profile: Dictionary = player.get("character_profile", {}) as Dictionary
	var grade := String(profile.get("character_grade", "clean"))
	var grade_criteria: Dictionary = config.get("character_grades", {}) as Dictionary

	# Get base multiplier for grade
	var grade_config: Dictionary = grade_criteria.get(grade, {}) as Dictionary

	# Handle different grade types
	if grade == "exemplary":
		return float(grade_config.get("draft_boost", 1.02))
	elif grade == "clean":
		return float(grade_config.get("draft_impact", 1.0))
	elif grade == "concern":
		return float(grade_config.get("draft_penalty", 0.95))
	elif grade == "red_flag":
		# Red flag penalty varies by severity of incidents
		var penalty_range: Array = grade_config.get("draft_penalty_range", [0.70, 0.90]) as Array
		var min_penalty := float(penalty_range[0])
		var max_penalty := float(penalty_range[1])

		# Calculate penalty based on incident severity
		var discipline_record: Array = profile.get("discipline_record", []) as Array
		var severity_score := _calculate_severity_score(discipline_record)

		# Map severity score (0-10+) to penalty range
		# Low severity (0-3): closer to max_penalty (0.90)
		# High severity (7-10): closer to min_penalty (0.70)
		var penalty_ratio := clamp(severity_score / 10.0, 0.0, 1.0)
		return max_penalty - (penalty_ratio * (max_penalty - min_penalty))

	# Default to 1.0 if grade not recognized
	return 1.0


## Simulates pre-draft interview red flag detection.
##
## PHASE 2 FEATURE - Currently stub for future extensibility.
## Will be implemented when interview system is added.
##
## Intended behavior:
##   - Scout conducts interview with player
##   - Scout skill affects detection chance
##   - Returns array of detected red flags
##
## RNG: Will use rng when implemented (1 call per potential red flag)
##
## @param player: Player dictionary with character_profile
## @param scout: Scout dictionary with skill attributes
## @param config: Character system configuration
## @param rng: RNG instance for random detection
## @return Array: Detected red flags (empty for now)
static func simulate_interview_red_flag_detection(
	player: Dictionary,
	scout: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> Array:
	# Phase 2 stub - return empty array
	# Future implementation will:
	#   1. Check if interviews enabled in config
	#   2. Calculate detection chance based on scout skill
	#   3. Roll for each potential red flag
	#   4. Return array of detected flags

	return []


## Calculates severity score from discipline record.
##
## Internal helper for calculate_character_draft_impact().
## Maps incident types and counts to severity score (0-10+ scale).
##
## Severity Weights:
##   - minor (academic, team_rules): 1 point each
##   - moderate (substance_abuse): 2 points each
##   - major (conduct): 3 points each
##   - severe (legal_trouble): 5 points each
##
## RNG: None (deterministic calculation)
##
## @param discipline_record: Array of discipline events
## @return float: Severity score
static func _calculate_severity_score(discipline_record: Array) -> float:
	var score := 0.0

	var severity_weights := {
		"minor": 1.0,
		"moderate": 2.0,
		"major": 3.0,
		"severe": 5.0
	}

	for event_entry in discipline_record:
		var event: Dictionary = event_entry as Dictionary
		var severity := String(event.get("severity", "minor"))
		score += float(severity_weights.get(severity, 1.0))

	return score


## Generates a contextual reason string for discipline event.
##
## Internal helper for apply_discipline_events().
## Creates human-readable reason based on event type.
##
## RNG: Uses rng for variety in reason selection (1 call)
##
## @param event_type: Type of discipline event
## @param rng: RNG instance for reason variety
## @return String: Reason description
static func _generate_reason(event_type: String, rng: RandomNumberGenerator) -> String:
	var reasons := {
		"academic": [
			"Failed to maintain minimum GPA",
			"Academic dishonesty",
			"Missed required classes",
			"Tutoring violations"
		],
		"team_rules": [
			"Missed team meeting",
			"Violated curfew",
			"Dress code violation",
			"Unauthorized social media post"
		],
		"substance_abuse": [
			"Failed drug test",
			"Alcohol violation",
			"Performance enhancing drug suspension",
			"Substance policy violation"
		],
		"conduct": [
			"Unsportsmanlike conduct",
			"Altercation with teammate",
			"Violated team code of conduct",
			"Disrespectful behavior"
		],
		"legal_trouble": [
			"Arrested for misdemeanor",
			"Criminal investigation",
			"DUI charge",
			"Assault charges"
		]
	}

	var reason_list: Array = reasons.get(event_type, ["Unspecified violation"]) as Array
	if reason_list.is_empty():
		return "Unspecified violation"

	# Use RNG to select random reason for variety
	var idx := rng.randi_range(0, reason_list.size() - 1)
	return String(reason_list[idx])
