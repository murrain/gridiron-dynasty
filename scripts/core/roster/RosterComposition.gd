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

## Maximum roster depth by position (HARD CAPS)
##
## These are absolute limits that cannot be exceeded under any circumstances.
## No team should ever have more than this many players at a position.
## Used to prevent unrealistic roster compositions (e.g., 5 QBs).
##
## DESIGN RATIONALE:
##   - QB: 3 max (starter + backup + developmental) - no team carries 4+ QBs
##   - RB: 5 max (RBBC committees rarely exceed 4, with 1 FB/special teams)
##   - WR: 7 max (even pass-heavy offenses cap at 6-7 active receivers)
##   - TE: 4 max (2-TE sets + backups is the ceiling)
##   - OL: 10 max (5 starters + 5 backups covers all contingencies)
##   - DL: 7 max (rotational players in base + nickel packages)
##   - EDGE: 5 max (2 starters + situational pass rushers)
##   - LB: 7 max (3-4 schemes need more, but 7 is ceiling)
##   - CB: 6 max (2 outside + nickel + dime + 2 backups)
##   - S: 5 max (2 starters + big nickel + 2 backups)
##   - K/P: 1 each (never roster 2 kickers/punters)
const MAX_DEPTH := {
	"QB": 3,
	"RB": 5,
	"WR": 7,
	"TE": 4,
	"OL": 10,
	"DL": 7,
	"EDGE": 5,
	"LB": 7,
	"CB": 6,
	"S": 5,
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

## Get maximum depth for a position (hard cap)
##
## @param position: Position abbreviation (QB, RB, etc.)
## @return int: Maximum allowed roster depth for that position
static func get_max_depth(position: String) -> int:
	return int(MAX_DEPTH.get(position, 3))


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


## Check if position is at or above maximum capacity (hard cap)
##
## This is the primary gatekeeper for preventing position overstocking.
## Returns true if the team cannot add any more players at this position.
##
## @param roster: Team roster dictionary with "by_position" field
## @param position: Position to check
## @return bool: True if position is at or above max depth
static func is_position_at_cap(roster: Dictionary, position: String) -> bool:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var current := (by_position.get(position, []) as Array).size()
	var max_allowed := get_max_depth(position)
	return current >= max_allowed


## Check how many slots are available at a position before hitting the cap
##
## @param roster: Team roster dictionary with "by_position" field
## @param position: Position to check
## @return int: Number of available slots (0 if at/above cap)
static func get_available_slots(roster: Dictionary, position: String) -> int:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var current := (by_position.get(position, []) as Array).size()
	var max_allowed := get_max_depth(position)
	return maxi(0, max_allowed - current)


## Get scheme-adjusted ideal depth for a position
##
## Offensive and defensive schemes affect how many players are needed
## at each position. For example, air raid offenses need more WRs,
## while 3-4 defenses need more LBs.
##
## @param position: Position abbreviation
## @param offensive_scheme: Team's offensive scheme (e.g., "air_raid", "power_run")
## @param defensive_scheme: Team's defensive scheme (e.g., "4_3_under", "3_4_two_gap")
## @param schemes_cfg: Schemes configuration from schemes.json
## @return int: Scheme-adjusted ideal depth (never exceeds MAX_DEPTH)
static func get_scheme_adjusted_ideal_depth(
	position: String,
	offensive_scheme: String,
	defensive_scheme: String,
	schemes_cfg: Dictionary
) -> int:
	var base_ideal := get_ideal_depth(position)
	var max_allowed := get_max_depth(position)

	# Check offensive scheme for offensive positions
	if position in ["RB", "WR", "TE", "OL"]:
		var off_schemes := schemes_cfg.get("offensive_schemes", {}) as Dictionary
		var scheme := off_schemes.get(offensive_scheme, {}) as Dictionary
		var roster_req := scheme.get("roster_requirements", {}) as Dictionary
		var ideal_depths := roster_req.get("ideal_depth", {}) as Dictionary
		if ideal_depths.has(position):
			base_ideal = int(ideal_depths[position])

	# Check defensive scheme for defensive positions
	if position in ["DL", "EDGE", "LB", "CB", "S"]:
		var def_schemes := schemes_cfg.get("defensive_schemes", {}) as Dictionary
		var scheme := def_schemes.get(defensive_scheme, {}) as Dictionary
		var roster_req := scheme.get("roster_requirements", {}) as Dictionary
		var ideal_depths := roster_req.get("ideal_depth", {}) as Dictionary
		if ideal_depths.has(position):
			base_ideal = int(ideal_depths[position])

	# Never exceed max depth
	return mini(base_ideal, max_allowed)


## Get scheme-adjusted minimum depth for a position
##
## @param position: Position abbreviation
## @param offensive_scheme: Team's offensive scheme
## @param defensive_scheme: Team's defensive scheme
## @param schemes_cfg: Schemes configuration from schemes.json
## @return int: Scheme-adjusted minimum depth
static func get_scheme_adjusted_minimum_depth(
	position: String,
	offensive_scheme: String,
	defensive_scheme: String,
	schemes_cfg: Dictionary
) -> int:
	var base_minimum := get_minimum_depth(position)

	# Check offensive scheme for offensive positions
	if position in ["RB", "WR", "TE", "OL"]:
		var off_schemes := schemes_cfg.get("offensive_schemes", {}) as Dictionary
		var scheme := off_schemes.get(offensive_scheme, {}) as Dictionary
		var roster_req := scheme.get("roster_requirements", {}) as Dictionary
		var min_depths := roster_req.get("minimum_depth", {}) as Dictionary
		if min_depths.has(position):
			base_minimum = int(min_depths[position])

	# Check defensive scheme for defensive positions
	if position in ["DL", "EDGE", "LB", "CB", "S"]:
		var def_schemes := schemes_cfg.get("defensive_schemes", {}) as Dictionary
		var scheme := def_schemes.get(defensive_scheme, {}) as Dictionary
		var roster_req := scheme.get("roster_requirements", {}) as Dictionary
		var min_depths := roster_req.get("minimum_depth", {}) as Dictionary
		if min_depths.has(position):
			base_minimum = int(min_depths[position])

	return base_minimum


## Calculate position need multiplier for draft/FA considering scheme and caps
##
## Returns a multiplier for draft/FA interest:
##   - 0.0: Position at cap, cannot add players
##   - 0.5: Position overstocked (above ideal), low interest
##   - 1.0: Position at ideal depth, neutral
##   - 1.5+: Position below ideal, high need
##
## @param roster: Team roster dictionary
## @param position: Position to evaluate
## @param offensive_scheme: Team's offensive scheme
## @param defensive_scheme: Team's defensive scheme
## @param schemes_cfg: Schemes configuration
## @return float: Need multiplier (0.0 to 2.0)
static func calculate_position_need_multiplier(
	roster: Dictionary,
	position: String,
	offensive_scheme: String,
	defensive_scheme: String,
	schemes_cfg: Dictionary
) -> float:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var current := (by_position.get(position, []) as Array).size()
	var max_allowed := get_max_depth(position)
	var ideal := get_scheme_adjusted_ideal_depth(position, offensive_scheme, defensive_scheme, schemes_cfg)

	# HARD CAP: At or above max = 0.0 interest (cannot add)
	if current >= max_allowed:
		return 0.0

	# Above ideal but below cap = very low interest (0.3-0.5)
	if current > ideal:
		# Scale from 0.5 (at ideal+1) to 0.3 (near cap)
		var excess := current - ideal
		var slots_to_cap := max_allowed - ideal
		if slots_to_cap > 0:
			var ratio := float(excess) / float(slots_to_cap)
			return 0.5 - (ratio * 0.2)  # 0.5 → 0.3
		return 0.3

	# At ideal = neutral (1.0)
	if current == ideal:
		return 1.0

	# Below ideal = high interest (1.2 to 2.0 based on deficit)
	if current == 0:
		return 2.0  # Critical need

	var deficit := ideal - current
	var deficit_ratio := float(deficit) / float(ideal)
	return 1.0 + deficit_ratio  # 1.0 to ~2.0


## Calculate all position deficits with scheme awareness
##
## @param roster: Team roster dictionary
## @param offensive_scheme: Team's offensive scheme
## @param defensive_scheme: Team's defensive scheme
## @param schemes_cfg: Schemes configuration
## @return Dictionary: Position -> deficit amount (negative = overstocked)
static func calculate_scheme_aware_deficits(
	roster: Dictionary,
	offensive_scheme: String,
	defensive_scheme: String,
	schemes_cfg: Dictionary
) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var deficits := {}

	for pos in IDEAL_DEPTH.keys():
		var current := (by_position.get(pos, []) as Array).size()
		var ideal := get_scheme_adjusted_ideal_depth(pos, offensive_scheme, defensive_scheme, schemes_cfg)
		var deficit := ideal - current
		# Include both deficits (positive) and overstocks (negative)
		deficits[pos] = deficit

	return deficits
