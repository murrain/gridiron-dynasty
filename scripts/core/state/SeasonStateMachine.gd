extends RefCounted
class_name SeasonStateMachine

## SeasonStateMachine - Formal state machine for season lifecycle transitions
##
## Single source of truth for valid season phase transitions and season management.
## Ensures all transitions follow defined rules and provides clear season lifecycle path.
##
## Usage:
##   # Check if transition is valid
##   if SeasonStateMachine.can_transition(SeasonPhase.PRE_SEASON, SeasonPhase.REGULAR_SEASON):
##       # Perform transition
##
##   # Get valid next phases
##   var next_phases = SeasonStateMachine.get_valid_transitions(SeasonPhase.REGULAR_SEASON)
##
##   # Get phase name for logging
##   var phase_name = SeasonStateMachine.get_phase_name(SeasonPhase.PLAYOFFS)

## Season phase enumeration
## Defines the lifecycle stages of a season
enum SeasonPhase {
	PRE_SEASON = 0,      ## Before regular season starts (training camp, preseason games)
	REGULAR_SEASON = 1,  ## Regular season in progress
	PLAYOFFS = 2,        ## Playoff games in progress
	POST_SEASON = 3,     ## After playoffs, before off-season (awards, retirements)
	OFF_SEASON = 4,      ## Off-season activities (free agency, training)
	DRAFT_PREP = 5,      ## Draft preparation (scouting, combine)
	DRAFT = 6,           ## Draft in progress
	FREE_AGENCY = 7      ## Free agency period
}

## Valid phase transitions map
## Each phase maps to array of phases it can transition to
const VALID_TRANSITIONS := {
	SeasonPhase.PRE_SEASON: [
		SeasonPhase.REGULAR_SEASON
	],
	SeasonPhase.REGULAR_SEASON: [
		SeasonPhase.PLAYOFFS,     # If playoffs exist
		SeasonPhase.POST_SEASON   # If no playoffs (e.g., regular season only)
	],
	SeasonPhase.PLAYOFFS: [
		SeasonPhase.POST_SEASON
	],
	SeasonPhase.POST_SEASON: [
		SeasonPhase.OFF_SEASON
	],
	SeasonPhase.OFF_SEASON: [
		SeasonPhase.DRAFT_PREP,
		SeasonPhase.FREE_AGENCY   # Some leagues might do FA before draft
	],
	SeasonPhase.DRAFT_PREP: [
		SeasonPhase.DRAFT
	],
	SeasonPhase.DRAFT: [
		SeasonPhase.FREE_AGENCY,  # Post-draft free agency
		SeasonPhase.PRE_SEASON    # Or directly to next pre-season
	],
	SeasonPhase.FREE_AGENCY: [
		SeasonPhase.PRE_SEASON    # Back to start of new season
	]
}

## Phase name mapping for logging and display
const PHASE_NAMES := {
	SeasonPhase.PRE_SEASON: "PRE_SEASON",
	SeasonPhase.REGULAR_SEASON: "REGULAR_SEASON",
	SeasonPhase.PLAYOFFS: "PLAYOFFS",
	SeasonPhase.POST_SEASON: "POST_SEASON",
	SeasonPhase.OFF_SEASON: "OFF_SEASON",
	SeasonPhase.DRAFT_PREP: "DRAFT_PREP",
	SeasonPhase.DRAFT: "DRAFT",
	SeasonPhase.FREE_AGENCY: "FREE_AGENCY"
}

## Standard season lifecycle path (most common progression)
const STANDARD_LIFECYCLE := [
	SeasonPhase.PRE_SEASON,
	SeasonPhase.REGULAR_SEASON,
	SeasonPhase.PLAYOFFS,
	SeasonPhase.POST_SEASON,
	SeasonPhase.OFF_SEASON,
	SeasonPhase.DRAFT_PREP,
	SeasonPhase.DRAFT,
	SeasonPhase.FREE_AGENCY
]

## Check if a transition from one phase to another is valid
##
## @param from: Current season phase
## @param to: Desired target phase
## @return bool: True if transition is valid, false otherwise
static func can_transition(from: SeasonPhase, to: SeasonPhase) -> bool:
	if not VALID_TRANSITIONS.has(from):
		return false

	var valid_next: Array = VALID_TRANSITIONS.get(from, [])
	return to in valid_next

## Get valid transitions from current phase
##
## @param from: Current season phase
## @return Array: Array of valid next SeasonPhase values
static func get_valid_transitions(from: SeasonPhase) -> Array:
	if not VALID_TRANSITIONS.has(from):
		return []

	return VALID_TRANSITIONS.get(from, []).duplicate()

## Get human-readable name for a phase
##
## @param phase: SeasonPhase enum value
## @return String: Human-readable phase name
static func get_phase_name(phase: SeasonPhase) -> String:
	return PHASE_NAMES.get(phase, "UNKNOWN")

## Get the standard lifecycle path
##
## Returns the standard progression path for most seasons:
## PRE_SEASON -> REGULAR_SEASON -> PLAYOFFS -> POST_SEASON -> OFF_SEASON ->
## DRAFT_PREP -> DRAFT -> FREE_AGENCY -> (back to PRE_SEASON)
##
## @return Array: Array of SeasonPhase values in order
static func get_standard_lifecycle() -> Array:
	return STANDARD_LIFECYCLE.duplicate()

## Check if a phase is terminal (no valid transitions out)
##
## Note: In a cyclical season system, no phase is truly terminal.
## This is provided for completeness but should typically return false.
##
## @param phase: Phase to check
## @return bool: True if phase is terminal (no valid next phases)
static func is_terminal_phase(phase: SeasonPhase) -> bool:
	var valid_next := get_valid_transitions(phase)
	return valid_next.is_empty()

## Validate transition with detailed error reporting
##
## Similar to can_transition() but provides detailed error messages
## for debugging and validation.
##
## @param from: Current season phase
## @param to: Desired target phase
## @param context: Optional context string for error messages (e.g., "team_id: SF")
## @return Dictionary: {"valid": bool, "error": String}
static func validate_transition(
	from: SeasonPhase,
	to: SeasonPhase,
	context: String = ""
) -> Dictionary:
	if not VALID_TRANSITIONS.has(from):
		return {
			"valid": false,
			"error": "Invalid source phase: %s%s" % [
				get_phase_name(from),
				" (%s)" % context if not context.is_empty() else ""
			]
		}

	if not can_transition(from, to):
		var valid_next := get_valid_transitions(from)
		var valid_names := []
		for phase in valid_next:
			valid_names.append(get_phase_name(phase))

		return {
			"valid": false,
			"error": "Invalid transition %s -> %s%s. Valid transitions: [%s]" % [
				get_phase_name(from),
				get_phase_name(to),
				" (%s)" % context if not context.is_empty() else "",
				", ".join(valid_names)
			]
		}

	return {"valid": true, "error": ""}

## Check if phase requires standings calculation
##
## Some phases (like regular season end, playoffs start) require
## standings to be calculated or updated.
##
## @param phase: SeasonPhase to check
## @return bool: True if standings should be calculated
static func requires_standings_calculation(phase: SeasonPhase) -> bool:
	return phase in [
		SeasonPhase.PLAYOFFS,      # Need standings to determine playoff seeding
		SeasonPhase.POST_SEASON    # Final standings for records
	]

## Check if phase allows game simulation
##
## Only certain phases allow games to be simulated.
##
## @param phase: SeasonPhase to check
## @return bool: True if games can be simulated in this phase
static func allows_game_simulation(phase: SeasonPhase) -> bool:
	return phase in [
		SeasonPhase.PRE_SEASON,    # Preseason games
		SeasonPhase.REGULAR_SEASON,
		SeasonPhase.PLAYOFFS
	]

## Check if phase is part of active season
##
## Determines if phase is during the competitive season vs off-season
##
## @param phase: SeasonPhase to check
## @return bool: True if phase is active season (games being played)
static func is_active_season(phase: SeasonPhase) -> bool:
	return phase in [
		SeasonPhase.PRE_SEASON,
		SeasonPhase.REGULAR_SEASON,
		SeasonPhase.PLAYOFFS
	]

## Check if phase is part of off-season
##
## Determines if phase is during off-season activities
##
## @param phase: SeasonPhase to check
## @return bool: True if phase is off-season
static func is_off_season(phase: SeasonPhase) -> bool:
	return phase in [
		SeasonPhase.POST_SEASON,
		SeasonPhase.OFF_SEASON,
		SeasonPhase.DRAFT_PREP,
		SeasonPhase.DRAFT,
		SeasonPhase.FREE_AGENCY
	]
