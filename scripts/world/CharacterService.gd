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
##   3. Hype impact from character events (positive and negative media attention)
##
## Design Philosophy:
##   - Discipline events are rare (2% base chance per year) but impactful
##   - Character grades range from "exemplary" (bonus) to "red_flag" (major concern)
##   - Severity escalates: academic < team_rules < substance < conduct < legal
##   - Character events directly affect player hype (media attention)
##
## Hype Integration:
##   - Negative events (arrests, suspensions) reduce hype
##   - Hype scale: 0-100 with 50 as neutral
##   - Draft evaluation already uses hype, so no separate draft_impact needed
##
## RNG Pattern: 2-3 calls per player per year (if event occurs)
##   - Call 1: Event occurrence roll (randf)
##   - Call 2: Event type selection (weighted random)
##   - Call 3: Games suspended (randi_range)
##
## Integration Points: CollegeSeason (event generation), CollegeAwardsService (hype usage)

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
			"character_grade": "clean"
		}

	# Initialize player history if not exists
	if not player.has("history"):
		player["history"] = []

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

	# Get hype impact and halflife from config
	var hype_impact := float(selected_type.get("hype_impact", -5.0))
	var halflife_years := float(selected_type.get("halflife_years", 0.5))

	# Create event record
	var event_type := String(selected_type.get("type", "unknown"))
	var event := {
		"year": year,
		"type": event_type,
		"games": games_suspended,
		"severity": String(selected_type.get("severity", "minor")),
		"reason": _generate_reason(event_type, rng),
		"hype_impact": hype_impact,
		"halflife_years": halflife_years
	}

	# Append to discipline record
	var profile: Dictionary = player["character_profile"] as Dictionary
	var discipline_record: Array = profile.get("discipline_record", []) as Array
	discipline_record.append(event)
	profile["discipline_record"] = discipline_record

	# Apply hype impact (immediate effect)
	var current_hype := float(player.get("hype", 50.0))
	player["hype"] = clamp(current_hype + hype_impact, 0.0, 100.0)

	# Track decaying hype modifier for recovery over time
	if not player.has("hype_modifiers"):
		player["hype_modifiers"] = []
	var modifiers: Array = player["hype_modifiers"]
	modifiers.append({
		"source": event_type,
		"year_applied": year,
		"initial_impact": hype_impact,
		"halflife_years": halflife_years
	})

	# Add to player history
	var history: Array = player["history"] as Array
	history.append({
		"type": "discipline",
		"year": year,
		"event": event_type,
		"description": event["reason"],
		"games_suspended": games_suspended,
		"hype_impact": hype_impact,
		"halflife_years": halflife_years
	})

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


## Calculates total hype impact from character events.
##
## NOTE: Draft impact now flows through the player's hype stat.
## This function returns the cumulative hype impact from all discipline events
## for informational purposes. The actual draft evaluation uses the hype stat
## which is already modified when events occur.
##
## @param player: Player dictionary with character_profile
## @param _config: Character system configuration (unused, kept for API compat)
## @return float: Total hype impact from discipline events
static func calculate_character_hype_impact(
	player: Dictionary,
	_config: Dictionary
) -> float:
	var profile: Dictionary = player.get("character_profile", {}) as Dictionary
	var discipline_record: Array = profile.get("discipline_record", []) as Array

	var total_impact := 0.0
	for event_entry in discipline_record:
		var event: Dictionary = event_entry as Dictionary
		total_impact += float(event.get("hype_impact", 0.0))

	return total_impact


## DEPRECATED: Use calculate_character_hype_impact instead.
## Draft impact now flows through the hype stat.
##
## Returns 1.0 for backward compatibility.
static func calculate_character_draft_impact(
	_player: Dictionary,
	_config: Dictionary
) -> float:
	return 1.0


## Calculates the current effective hype modifier after decay.
##
## Applies exponential decay based on halflife to all active modifiers.
## Formula: remaining_impact = initial_impact * (0.5 ^ (years_elapsed / halflife))
##
## This should be called periodically (e.g., yearly) to update player hype
## as negative events fade from public memory.
##
## @param player: Player dictionary with hype_modifiers
## @param current_year: Current simulation year
## @return float: Net hype adjustment from all decaying modifiers
static func calculate_decayed_hype_modifier(
	player: Dictionary,
	current_year: int
) -> float:
	var modifiers: Array = player.get("hype_modifiers", [])
	if modifiers.is_empty():
		return 0.0

	var total_modifier := 0.0
	for mod in modifiers:
		var m: Dictionary = mod
		var year_applied := int(m.get("year_applied", current_year))
		var initial_impact := float(m.get("initial_impact", 0.0))
		var halflife := float(m.get("halflife_years", 1.0))

		if halflife <= 0.0:
			# Permanent modifier (no decay)
			total_modifier += initial_impact
		else:
			var years_elapsed := float(current_year - year_applied)
			var decay_factor := pow(0.5, years_elapsed / halflife)
			total_modifier += initial_impact * decay_factor

	return total_modifier


## Updates player hype based on decayed modifiers.
##
## Call this at the start of each year to apply hype recovery/decay.
## Recalculates hype from base + all decayed modifiers.
##
## @param player: Player dictionary
## @param current_year: Current simulation year
## @param base_hype: Player's base hype without modifiers (default 50)
static func apply_hype_decay(
	player: Dictionary,
	current_year: int,
	base_hype: float = 50.0
) -> void:
	var decayed_modifier := calculate_decayed_hype_modifier(player, current_year)
	player["hype"] = clamp(base_hype + decayed_modifier, 0.0, 100.0)


## Evaluates how a specific team views a player's character concerns.
##
## Some teams are more willing to draft players with character issues
## if they believe the talent is worth the risk. This function returns
## a multiplier that adjusts how much the team penalizes character concerns.
##
## Team tolerance levels:
##   - "strict": 1.5x penalty (character is paramount)
##   - "moderate": 1.0x penalty (normal evaluation)
##   - "lenient": 0.5x penalty (talent over character)
##   - "win_now": 0.25x penalty (desperate for talent)
##
## @param player: Player dictionary with character_profile
## @param team: Team dictionary with character_tolerance setting
## @param config: Character system configuration
## @return float: Adjusted character evaluation score (0-100)
static func evaluate_for_team(
	player: Dictionary,
	team: Dictionary,
	config: Dictionary
) -> float:
	var tolerance := String(team.get("character_tolerance", "moderate"))
	var tolerance_cfg: Dictionary = config.get("team_tolerance_levels", {})
	var tolerance_settings: Dictionary = tolerance_cfg.get(tolerance, {})

	var penalty_multiplier := float(tolerance_settings.get("penalty_multiplier", 1.0))
	var grade := evaluate_character_grade(player, config)

	# Base score: 100 for exemplary, lower for concerns
	var base_scores := {
		"exemplary": 100.0,
		"clean": 90.0,
		"concern": 70.0,
		"red_flag": 40.0
	}
	var base_score := float(base_scores.get(grade, 70.0))

	# Apply tolerance - lenient teams see less penalty
	var penalty := 100.0 - base_score
	var adjusted_penalty := penalty * penalty_multiplier
	return 100.0 - adjusted_penalty


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
