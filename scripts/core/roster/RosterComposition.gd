extends RefCounted
class_name RosterComposition

## RosterComposition
##
## Centralizes roster composition requirements and analysis.
## Provides canonical depth requirements for all position groups.
##
## DESIGN PRINCIPLE:
##   Single source of truth for "what is a complete roster?"
##   Prevents inconsistency across Draft, FA, Trade systems.
##
## IDEAL DEPTH vs MINIMUM DEPTH:
##   - Ideal: Target depth for competitive team (e.g., 3 QB)
##   - Minimum: Bare minimum to field a team (e.g., 2 QB)
##   - Systems should use ideal for evaluation, minimum for emergency filling

## Ideal roster depth by position
##
## These represent the target depth for a competitive NFL roster:
## - QB: 3 (starter + backup + developmental)
## - RB: 4 (2 starters in RBBC + 2 backups)
## - WR: 6 (3 starters + 3 backups/special teams)
## - TE: 3 (1-2 starters depending on scheme + backups)
## - OL: 9 (5 starters + 4 backups, can cover any position)
## - DL: 6 (rotation of 4-6 depending on scheme)
## - EDGE: 4 (2 starters + 2 backups in 3-4, or rotation in 4-3)
## - LB: 6 (3-4 starters depending on scheme + backups)
## - CB: 5 (2 starters + nickel + 2 backups)
## - S: 4 (2 starters + 2 backups)
## - K: 1 (kicker)
## - P: 1 (punter)
##
## Total: 53 players (NFL roster limit)
const IDEAL_DEPTH := {
	"QB": 3,
	"RB": 4,
	"WR": 6,
	"TE": 3,
	"OL": 9,
	"DL": 6,
	"EDGE": 4,
	"LB": 6,
	"CB": 5,
	"S": 4,
	"K": 1,
	"P": 1
}

## Minimum roster depth by position
##
## Absolute minimum to field a functional team.
## Used for emergency UDFA roster filling when ideal depth can't be met.
const MINIMUM_DEPTH := {
	"QB": 2,  # Need backup in case starter injured
	"RB": 3,  # At least 2 for RBBC + 1 backup
	"WR": 5,  # 3 starters + 2 backups
	"TE": 2,  # 1-2 starters + 1 backup
	"OL": 8,  # 5 starters + 3 backups (tight)
	"DL": 5,  # Minimal rotation
	"EDGE": 4,  # 2 starters + 2 backups
	"LB": 5,  # 3 starters + 2 backups
	"CB": 5,  # 2 starters + nickel + 2 backups (no flexibility)
	"S": 4,   # 2 starters + 2 backups (no flexibility)
	"K": 1,   # One kicker required
	"P": 1    # One punter required
}

## Get ideal depth for a position
##
## @param position: Position abbreviation (QB, RB, etc.)
## @return int: Ideal roster depth for that position
static func get_ideal_depth(position: String) -> int:
	return int(IDEAL_DEPTH.get(position, 2))

## Get minimum depth for a position
##
## @param position: Position abbreviation (QB, RB, etc.)
## @return int: Minimum roster depth for that position
static func get_minimum_depth(position: String) -> int:
	return int(MINIMUM_DEPTH.get(position, 1))

## Calculate position deficits relative to ideal depth
##
## Returns dictionary of positions below ideal depth with deficit amounts.
## Example: {"QB": 1, "WR": 2} means need 1 QB and 2 WRs to reach ideal.
##
## @param roster: Team roster dictionary with "by_position" field
## @return Dictionary: Position -> deficit amount (only includes positions below ideal)
static func calculate_position_deficits(roster: Dictionary) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var deficits := {}

	for pos in IDEAL_DEPTH.keys():
		var current := (by_position.get(pos, []) as Array).size()
		var ideal := int(IDEAL_DEPTH[pos])
		var deficit := ideal - current
		if deficit > 0:
			deficits[pos] = deficit

	return deficits

## Calculate position deficits relative to minimum depth
##
## Used for emergency roster filling (UDFA market).
## Only returns critical deficits where team is below minimum functional depth.
##
## @param roster: Team roster dictionary with "by_position" field
## @return Dictionary: Position -> deficit amount (only includes positions below minimum)
static func calculate_minimum_deficits(roster: Dictionary) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var deficits := {}

	for pos in MINIMUM_DEPTH.keys():
		var current := (by_position.get(pos, []) as Array).size()
		var minimum := int(MINIMUM_DEPTH[pos])
		var deficit := minimum - current
		if deficit > 0:
			deficits[pos] = deficit

	return deficits

## Check if position group is overstocked relative to ideal
##
## @param roster: Team roster dictionary with "by_position" field
## @param position: Position to check
## @return bool: True if position count exceeds ideal depth
static func is_position_overstocked(roster: Dictionary, position: String) -> bool:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var current := (by_position.get(position, []) as Array).size()
	var ideal := get_ideal_depth(position)
	return current > ideal

## Get total roster size
##
## @param roster: Team roster dictionary with "players" field
## @return int: Total number of players on roster
static func get_roster_size(roster: Dictionary) -> int:
	return (roster.get("players", []) as Array).size()

## Check if roster meets minimum viability
##
## A roster is viable if it meets minimum depth at all positions.
##
## @param roster: Team roster dictionary
## @return bool: True if roster meets all minimum depth requirements
static func is_roster_viable(roster: Dictionary) -> bool:
	var min_deficits := calculate_minimum_deficits(roster)
	return min_deficits.is_empty()

## Check if roster is at ideal composition
##
## A roster is ideal if it meets ideal depth at all positions.
##
## @param roster: Team roster dictionary
## @return bool: True if roster meets all ideal depth requirements
static func is_roster_ideal(roster: Dictionary) -> bool:
	var deficits := calculate_position_deficits(roster)
	return deficits.is_empty()
