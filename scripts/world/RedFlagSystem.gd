extends RefCounted
class_name RedFlagSystem

## Red Flag System - Medical and Character Concerns
##
## Generates realistic red flags that affect draft stock and create risk/reward
## decisions for teams. Red flags are discovered during pre-draft process based
## on medical evaluations, combine performance, interviews, and background checks.
##
## Design:
##   - Stateless service (all state in player data)
##   - Deterministic via explicit RNG seeding
##   - Configuration-driven probabilities and impacts
##
## Integration:
##   - Called by PreDraftProcess during draft_prep phase
##   - Influences AI team draft boards in InteractiveDraft
##   - Displayed in player cards during draft
##
## RNG Pattern:
##   - Uses context-derived seed: base_seed ^ 0xRED_FLAG0
##   - Per-player: 1 roll for red flag occurrence
##   - Per-flag: 2-4 rolls for type, severity, description variant, impact magnitude

const Rand = preload("res://autoloads/Rand.gd")

## Red flag type constants
const TYPE_MEDICAL := "medical"
const TYPE_CHARACTER := "character"

## Severity level constants
const SEVERITY_MINOR := "minor"
const SEVERITY_MAJOR := "major"

## Default configuration values
const DEFAULT_FREQUENCY := 0.03  # 3% of players get red flags
const DEFAULT_SEVERITY_DIST := {
	"minor": 0.7,
	"major": 0.3
}

## Draft impact ranges by type and severity (pick position drop)
const IMPACT_RANGES := {
	"medical_major": {"min": -20.0, "max": -15.0},
	"medical_minor": {"min": -10.0, "max": -5.0},
	"character_major": {"min": -15.0, "max": -10.0},
	"character_minor": {"min": -8.0, "max": -3.0}
}

## Medical red flag templates with placeholder for injury type
const MEDICAL_TEMPLATES := [
	"History of %s injuries",
	"Failed medical evaluation - %s concern",
	"Surgery recovery - %s",
	"Injury-prone player - %s risk",
	"Recurring %s issues reported",
	"Medical recheck required - %s"
]

## Injury types for medical red flags
const INJURY_TYPES := ["knee", "shoulder", "ankle", "concussion", "back", "hip", "hamstring", "foot"]

## Character red flag templates (some with placeholder, some without)
const CHARACTER_TEMPLATES := [
	"Work ethic concerns reported by scouts",
	"Off-field incident - %s",
	"Locker room chemistry questions",
	"Maturity concerns - %s",
	"Inconsistent effort on tape",
	"Leadership questions from coaches",
	"Coachability concerns - %s"
]

## Incident types for character red flags
const INCIDENT_TYPES := ["discipline issue", "legal matter", "team conflict", "attitude", "suspension history", "academic issues"]


## Generate red flags for entire draft pool
##
## Scans all players and assigns red flags based on:
##   - Configurable frequency (default ~3%)
##   - Severity distribution (default 70% minor, 30% major)
##   - Type distribution (60% medical, 40% character)
##
## Side effects:
##   - Initializes player["draft_intelligence"] if not exists
##   - Adds entries to player["draft_intelligence"]["red_flags"]
##
## RNG consumption per player:
##   - 1 roll for occurrence check
##   - If flagged: 3-4 rolls for type, severity, template, impact
##
## @param draft_pool: Array of draft-eligible player dictionaries
## @param config: Configuration dictionary with optional "red_flags" section
## @param rng: RNG instance seeded with context-derived value (seed ^ 0xRED_FLAG0)
## @return int: Number of red flags generated (for logging/testing)
static func generate_red_flags(
	draft_pool: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> int:
	var red_flag_cfg: Dictionary = config.get("red_flags", {})
	var frequency := float(red_flag_cfg.get("frequency", DEFAULT_FREQUENCY))
	var severity_dist: Dictionary = red_flag_cfg.get("severity_distribution", DEFAULT_SEVERITY_DIST)

	var flags_generated := 0

	for player in draft_pool:
		var p: Dictionary = player

		# Initialize draft_intelligence structure if needed
		_ensure_draft_intelligence(p)

		# RNG roll 1: Check for red flag occurrence
		if rng.randf() > frequency:
			continue

		# RNG roll 2: Determine flag type (60% medical, 40% character)
		var flag_type := TYPE_MEDICAL if rng.randf() < 0.6 else TYPE_CHARACTER

		# RNG roll 3: Determine severity based on configured distribution
		var severity := _select_severity(severity_dist, rng)

		# RNG rolls 4-6: Generate the flag with description and impact
		var flag := _create_red_flag(p, flag_type, severity, rng)

		var di: Dictionary = p["draft_intelligence"]
		(di["red_flags"] as Array).append(flag)
		flags_generated += 1

	return flags_generated


## Create a specific red flag entry
##
## Generates a complete red flag with:
##   - Type-appropriate description from templates
##   - Severity-appropriate draft impact
##   - Discovery timestamp (draft prep week)
##
## RNG consumption:
##   - 1-2 rolls for template/incident selection
##   - 1 roll for impact magnitude within range
##
## @param player: Player dictionary (for potential position-specific logic)
## @param flag_type: "medical" or "character"
## @param severity: "minor" or "major"
## @param rng: RNG instance for deterministic generation
## @return Dictionary: Complete red flag entry
static func _create_red_flag(
	player: Dictionary,
	flag_type: String,
	severity: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	var description := ""
	var draft_impact := 0.0

	if flag_type == TYPE_MEDICAL:
		# Select injury type and template
		var injury := String(INJURY_TYPES[rng.randi() % INJURY_TYPES.size()])
		var template := String(MEDICAL_TEMPLATES[rng.randi() % MEDICAL_TEMPLATES.size()])
		description = template % injury

		# Calculate impact from severity-appropriate range
		var range_key := "medical_" + severity
		var impact_range: Dictionary = IMPACT_RANGES.get(range_key, IMPACT_RANGES["medical_minor"])
		draft_impact = rng.randf_range(float(impact_range["min"]), float(impact_range["max"]))

	elif flag_type == TYPE_CHARACTER:
		# Select template and potentially incident type
		var template := String(CHARACTER_TEMPLATES[rng.randi() % CHARACTER_TEMPLATES.size()])

		if "%s" in template:
			var incident := String(INCIDENT_TYPES[rng.randi() % INCIDENT_TYPES.size()])
			description = template % incident
		else:
			description = template

		# Calculate impact from severity-appropriate range
		var range_key := "character_" + severity
		var impact_range: Dictionary = IMPACT_RANGES.get(range_key, IMPACT_RANGES["character_minor"])
		draft_impact = rng.randf_range(float(impact_range["min"]), float(impact_range["max"]))

	return {
		"type": flag_type,
		"severity": severity,
		"description": description,
		"draft_impact": draft_impact,
		"discovered_week": 7  # Draft prep phase (tick 7)
	}


## Select severity level based on configured distribution
##
## Uses cumulative probability distribution to select severity.
##
## RNG consumption: 1 roll
##
## @param severity_dist: Dictionary with "minor" and "major" probabilities
## @param rng: RNG instance
## @return String: "minor" or "major"
static func _select_severity(
	severity_dist: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var roll := rng.randf()
	var cumulative := 0.0

	# Check major first since it's typically less probable
	var major_prob := float(severity_dist.get("major", 0.3))
	if roll < major_prob:
		return SEVERITY_MAJOR

	return SEVERITY_MINOR


## Ensure player has properly initialized draft_intelligence structure
##
## Initializes the full draft_intelligence dictionary structure if missing.
##
## @param player: Player dictionary to initialize
static func _ensure_draft_intelligence(player: Dictionary) -> void:
	if not player.has("draft_intelligence"):
		player["draft_intelligence"] = {}

	var di: Dictionary = player["draft_intelligence"]
	if not di.has("red_flags"):
		di["red_flags"] = []
	if not di.has("mock_history"):
		di["mock_history"] = []
	if not di.has("scouting_report"):
		di["scouting_report"] = {}
	if not di.has("shortlisted_by"):
		di["shortlisted_by"] = []


## Calculate total draft impact from all red flags
##
## Sums all red flag impacts for a player. Used by AI teams to
## adjust draft board rankings.
##
## @param player: Player dictionary
## @return float: Total pick position adjustment (negative value, 0 if no flags)
static func get_total_draft_impact(player: Dictionary) -> float:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])

	if flags.is_empty():
		return 0.0

	var total := 0.0
	for flag in flags:
		var f: Dictionary = flag
		total += float(f.get("draft_impact", 0.0))

	return total


## Check if player has major red flags
##
## Returns true if player has any red flag with "major" severity.
## Used for quick filtering in draft decisions.
##
## @param player: Player dictionary
## @return bool: True if player has any major red flags
static func has_major_red_flags(player: Dictionary) -> bool:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])

	for flag in flags:
		var f: Dictionary = flag
		if String(f.get("severity", "")) == SEVERITY_MAJOR:
			return true

	return false


## Check if player has any red flags
##
## @param player: Player dictionary
## @return bool: True if player has any red flags
static func has_red_flags(player: Dictionary) -> bool:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])
	return not flags.is_empty()


## Get red flag count for a player
##
## @param player: Player dictionary
## @return int: Number of red flags
static func get_red_flag_count(player: Dictionary) -> int:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])
	return flags.size()


## Get red flags by type
##
## Returns only red flags matching the specified type.
##
## @param player: Player dictionary
## @param flag_type: "medical" or "character"
## @return Array: Red flags of specified type
static func get_red_flags_by_type(player: Dictionary, flag_type: String) -> Array:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])

	var filtered: Array = []
	for flag in flags:
		var f: Dictionary = flag
		if String(f.get("type", "")) == flag_type:
			filtered.append(f)

	return filtered


## Get red flag summary for display
##
## Formats all red flags into a human-readable summary string.
##
## @param player: Player dictionary
## @return String: Formatted summary or "No red flags" if none
static func get_red_flag_summary(player: Dictionary) -> String:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])

	if flags.is_empty():
		return "No red flags"

	var summary_parts: Array = []
	for flag in flags:
		var f: Dictionary = flag
		var severity := String(f.get("severity", "")).to_upper()
		var description := String(f.get("description", "Unknown issue"))
		var impact := float(f.get("draft_impact", 0.0))
		summary_parts.append("[%s] %s (%.0f picks)" % [severity, description, abs(impact)])

	return "\n".join(summary_parts)


## Get short summary for compact display
##
## Returns abbreviated summary for UI display (e.g., "2 flags: 1 major, 1 minor")
##
## @param player: Player dictionary
## @return String: Short summary
static func get_short_summary(player: Dictionary) -> String:
	var di: Dictionary = player.get("draft_intelligence", {})
	var flags: Array = di.get("red_flags", [])

	if flags.is_empty():
		return "Clean"

	var major_count := 0
	var minor_count := 0

	for flag in flags:
		var f: Dictionary = flag
		if String(f.get("severity", "")) == SEVERITY_MAJOR:
			major_count += 1
		else:
			minor_count += 1

	var parts: Array = []
	if major_count > 0:
		parts.append("%d major" % major_count)
	if minor_count > 0:
		parts.append("%d minor" % minor_count)

	return "%d flags: %s" % [flags.size(), ", ".join(parts)]


## Apply red flag impact to a draft evaluation score
##
## Adjusts a player's draft score based on their red flags.
## The impact is additive to pick position (negative = drops in draft).
##
## @param player: Player dictionary
## @param base_score: Original evaluation score
## @param config: Configuration with optional risk_tolerance setting
## @return float: Adjusted score
static func apply_red_flag_impact(
	player: Dictionary,
	base_score: float,
	config: Dictionary = {}
) -> float:
	var total_impact := get_total_draft_impact(player)

	if total_impact == 0.0:
		return base_score

	# Risk tolerance modifies how much teams weight red flags
	# 1.0 = normal, >1.0 = risk-averse, <1.0 = risk-tolerant
	var risk_tolerance := float(config.get("risk_tolerance", 1.0))
	var adjusted_impact := total_impact * risk_tolerance

	# Convert pick position impact to score impact
	# Roughly 1 pick position = 1-2 score points depending on draft range
	var score_adjustment := adjusted_impact * 1.5

	return base_score + score_adjustment
