class_name TeamQueries
extends RefCounted

## Static utility class for querying team/school data from world_state
##
## Provides functions to retrieve teams, rosters, and calculate team-level metrics

## Get team by ID and level (nfl, college, hs)
## Returns team/school Dictionary if found, null otherwise
static func get_team(world_state: Dictionary, team_id: String, level: String) -> Variant:
	match level.to_lower():
		"nfl":
			return get_nfl_team(world_state, team_id)
		"college":
			return get_college(world_state, team_id)
		"hs", "high_school":
			return get_hs_school(world_state, team_id)
		_:
			push_error("Unknown level: %s" % level)
			return null

## Get NFL team by ID
## Returns team Dictionary if found, null otherwise
static func get_nfl_team(world_state: Dictionary, team_id: String) -> Variant:
	if team_id.is_empty():
		push_warning("TeamQueries.get_nfl_team: team_id is empty")
		return null

	var nfl_teams = world_state.get("nfl_teams", [])
	for team in nfl_teams:
		if team.get("id", "") == team_id:
			return team

	push_warning("TeamQueries.get_nfl_team: Team '%s' not found" % team_id)
	return null

## Get college by ID
## Returns college Dictionary if found, null otherwise
static func get_college(world_state: Dictionary, college_id: String) -> Variant:
	if college_id.is_empty():
		push_warning("TeamQueries.get_college: college_id is empty")
		return null

	var colleges = world_state.get("colleges", [])
	for college in colleges:
		if college.get("id", "") == college_id:
			return college

	push_warning("TeamQueries.get_college: College '%s' not found" % college_id)
	return null

## Get high school by ID
## Returns school Dictionary if found, null otherwise
static func get_hs_school(world_state: Dictionary, school_id: String) -> Variant:
	if school_id.is_empty():
		push_warning("TeamQueries.get_hs_school: school_id is empty")
		return null

	var hs_schools = world_state.get("hs_schools", [])
	for school in hs_schools:
		if school.get("id", "") == school_id:
			return school

	push_warning("TeamQueries.get_hs_school: School '%s' not found" % school_id)
	return null

## Get NFL roster players
## Returns Array of player Dictionaries
static func get_nfl_roster(world_state: Dictionary, team_id: String) -> Array:
	var nfl_rosters = world_state.get("nfl_rosters", {})
	var roster_data = nfl_rosters.get(team_id, {})
	return roster_data.get("players", [])

## Get college roster players
## Returns Array of player Dictionaries
static func get_college_roster(world_state: Dictionary, college_id: String) -> Array:
	var college_rosters = world_state.get("college_rosters", {})
	var roster_data = college_rosters.get(college_id, {})
	return roster_data.get("players", [])

## Get high school roster players
## HS players are stored in a flat array with school_id reference
## Returns Array of player Dictionaries
static func get_hs_roster(world_state: Dictionary, school_id: String) -> Array:
	var hs_players = world_state.get("hs_players", [])
	return hs_players.filter(func(p): return p.get("hs_school_id", "") == school_id)

## Get roster size
## level: "nfl", "college", or "hs"
## Returns number of players on the roster
static func get_roster_size(world_state: Dictionary, team_id: String, level: String = "nfl") -> int:
	match level.to_lower():
		"nfl":
			return get_nfl_roster(world_state, team_id).size()
		"college":
			return get_college_roster(world_state, team_id).size()
		"hs":
			return get_hs_roster(world_state, team_id).size()
		_:
			return 0

## Calculate salary cap usage for NFL team
## Returns total cap used (league_cap - cap_space)
static func calculate_cap_usage(world_state: Dictionary, team_id: String) -> float:
	var team = get_nfl_team(world_state, team_id)
	if team == null:
		return 0.0

	var league_cap = team.get("league_cap", 200.0)
	var cap_space = team.get("cap_space", 0.0)
	return league_cap - cap_space

## Get roster grouped by position
## level: "nfl", "college", or "hs"
## Returns Dictionary mapping position -> Array[player Dictionary]
static func get_roster_by_position(world_state: Dictionary, team_id: String, level: String = "nfl") -> Dictionary:
	var roster: Array
	match level.to_lower():
		"nfl":
			roster = get_nfl_roster(world_state, team_id)
		"college":
			roster = get_college_roster(world_state, team_id)
		"hs":
			roster = get_hs_roster(world_state, team_id)
		_:
			return {}

	var by_position: Dictionary = {}
	for player in roster:
		var pos = player.get("position", "Unknown")
		if not by_position.has(pos):
			by_position[pos] = []
		by_position[pos].append(player)

	return by_position
