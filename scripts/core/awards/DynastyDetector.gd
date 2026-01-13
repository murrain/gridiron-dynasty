extends RefCounted
class_name DynastyDetector

## Dynasty Era Detection System
##
## Identifies periods of sustained team excellence (dynasties) based on championship success.
## A dynasty is defined as winning 3+ championships within a 5-year window.
##
## Implements Feature 5: Dynasty Era Detection
##   - Dynasty identification (3+ titles in 5 years)
##   - Era tracking (start year, end year, championship count)
##   - Active dynasty monitoring (ongoing dynasties)
##   - Historical dynasty records (completed dynasties)
##
## Data Model:
##   world_state["dynasty_eras"] = {
##     "active_dynasties": [
##       {team_id, start_year, championship_years: [year, year, ...], championship_count},
##       ...
##     ],
##     "completed_dynasties": [
##       {team_id, start_year, end_year, championship_years: [year, ...], championship_count},
##       ...
##     ]
##   }
##
## Dynasty Criteria:
##   - Minimum 3 championships within a 5-year span
##   - Dynasty starts with first championship in the window
##   - Dynasty ends when team fails to win championship for 3 consecutive years
##
## Performance: O(t) where t = teams with recent championships (~32 max)
## RNG Pattern: None (pure analysis of championship history)

## Dynasty criteria constants
const MIN_CHAMPIONSHIPS_FOR_DYNASTY := 3
const DYNASTY_WINDOW_YEARS := 5
const DYNASTY_END_THRESHOLD_YEARS := 3  # Years without title to end dynasty


## Detects and updates dynasty eras based on championship results.
##
## This is the main entry point called from NflSeason after championship tracking.
## Analyzes championship history to identify new dynasties and update active ones.
##
## Parameters:
##   world_state: Dictionary containing championships and team_history
##   year: Current season year
##
## Side Effects:
##   - Modifies world_state["dynasty_eras"]
##   - Updates active_dynasties and completed_dynasties
##
## Performance: O(t × w) where t = teams, w = window size (5 years)
static func detect_dynasties(world_state: Dictionary, year: int) -> Dictionary:
	var championships: Dictionary = world_state.get("championships", {})
	var team_history: Dictionary = world_state.get("team_history", {})

	# Initialize dynasty structure if not exists
	if not world_state.has("dynasty_eras"):
		world_state["dynasty_eras"] = {
			"active_dynasties": [],
			"completed_dynasties": []
		}

	var dynasties: Dictionary = world_state["dynasty_eras"]
	var active_dynasties: Array = dynasties.get("active_dynasties", [])
	var completed_dynasties: Array = dynasties.get("completed_dynasties", [])

	var new_dynasties := 0
	var ended_dynasties := 0

	# Get all Super Bowl winners
	var super_bowl_winners: Dictionary = championships.get("nfl", {}).get("super_bowl_winners", {})

	# Build championship history per team
	var team_championships := _build_team_championship_history(super_bowl_winners)

	# Check each team for dynasty potential
	for team_id in team_championships.keys():
		var champ_years: Array = team_championships[team_id]

		# Check if team is in an active dynasty
		var existing_dynasty := _find_active_dynasty(active_dynasties, team_id)

		if existing_dynasty != null:
			# Update existing dynasty
			var updated := _update_active_dynasty(existing_dynasty, year, champ_years, super_bowl_winners)

			if updated["ended"]:
				# Dynasty ended, move to completed
				completed_dynasties.append(updated["dynasty"])
				active_dynasties.erase(existing_dynasty)
				ended_dynasties += 1
		else:
			# Check if team qualifies for new dynasty
			var dynasty := _check_for_new_dynasty(team_id, champ_years, year)

			if dynasty != null:
				# New dynasty detected
				active_dynasties.append(dynasty)
				new_dynasties += 1

	# Save updated dynasty data
	dynasties["active_dynasties"] = active_dynasties
	dynasties["completed_dynasties"] = completed_dynasties
	world_state["dynasty_eras"] = dynasties

	return {
		"year": year,
		"new_dynasties": new_dynasties,
		"ended_dynasties": ended_dynasties,
		"active_dynasties": active_dynasties.size(),
		"total_dynasties": completed_dynasties.size() + active_dynasties.size()
	}


## Builds a mapping of team_id -> [championship_years].
##
## Parameters:
##   super_bowl_winners: Dictionary mapping year -> team_id
##
## Returns: Dictionary mapping team_id -> Array of years won
static func _build_team_championship_history(super_bowl_winners: Dictionary) -> Dictionary:
	var history := {}

	for year_key in super_bowl_winners.keys():
		var team_id := String(super_bowl_winners[year_key])
		if team_id == "":
			continue

		if not history.has(team_id):
			history[team_id] = []

		var year_value := int(year_key)
		(history[team_id] as Array).append(year_value)

	# Sort championship years for each team
	for team_id in history.keys():
		var years: Array = history[team_id]
		years.sort()

	return history


## Finds an active dynasty for a specific team.
##
## Parameters:
##   active_dynasties: Array of active dynasty dictionaries
##   team_id: Team identifier to search for
##
## Returns: Dynasty dictionary if found, null otherwise
static func _find_active_dynasty(active_dynasties: Array, team_id: String) -> Dictionary:
	for dynasty in active_dynasties:
		var d: Dictionary = dynasty
		if String(d.get("team_id", "")) == team_id:
			return d

	return {}


## Updates an existing active dynasty with new championship data.
##
## Parameters:
##   dynasty: Dictionary containing dynasty data
##   year: Current season year
##   champ_years: Array of all championship years for this team
##   super_bowl_winners: Dictionary mapping year -> team_id
##
## Returns: Dictionary with "ended" flag and updated "dynasty" data
static func _update_active_dynasty(
	dynasty: Dictionary,
	year: int,
	champ_years: Array,
	super_bowl_winners: Dictionary
) -> Dictionary:
	var team_id := String(dynasty.get("team_id", ""))
	var start_year := int(dynasty.get("start_year", 0))
	var championship_years: Array = dynasty.get("championship_years", [])

	# Check if team won this year
	var won_this_year := (String(super_bowl_winners.get(year, "")) == team_id)

	if won_this_year:
		# Add championship to dynasty
		if not championship_years.has(year):
			championship_years.append(year)
			championship_years.sort()
			dynasty["championship_years"] = championship_years
			dynasty["championship_count"] = championship_years.size()
			dynasty["last_championship_year"] = year

		return {"ended": false, "dynasty": dynasty}

	# Team didn't win - check if dynasty should end
	var last_championship := int(dynasty.get("last_championship_year", start_year))
	var years_since_last := year - last_championship

	if years_since_last >= DYNASTY_END_THRESHOLD_YEARS:
		# Dynasty ended
		var completed_dynasty := dynasty.duplicate(true)
		completed_dynasty["end_year"] = year
		return {"ended": true, "dynasty": completed_dynasty}

	# Dynasty continues despite not winning
	return {"ended": false, "dynasty": dynasty}


## Checks if a team qualifies for a new dynasty.
##
## Parameters:
##   team_id: Team identifier
##   champ_years: Array of all championship years for this team (sorted)
##   current_year: Current season year
##
## Returns: Dynasty dictionary if qualified, null otherwise
static func _check_for_new_dynasty(team_id: String, champ_years: Array, current_year: int) -> Dictionary:
	if champ_years.size() < MIN_CHAMPIONSHIPS_FOR_DYNASTY:
		return {}

	# Check recent windows (sliding 5-year windows)
	for i in range(champ_years.size() - MIN_CHAMPIONSHIPS_FOR_DYNASTY + 1):
		var window_start := int(champ_years[i])
		var window_end := window_start + DYNASTY_WINDOW_YEARS - 1

		# Count championships in this window
		var window_champs := []
		for year in champ_years:
			var y := int(year)
			if y >= window_start and y <= window_end:
				window_champs.append(y)

		# Check if window qualifies as dynasty
		if window_champs.size() >= MIN_CHAMPIONSHIPS_FOR_DYNASTY:
			# Dynasty detected
			return {
				"team_id": team_id,
				"start_year": window_start,
				"championship_years": window_champs,
				"championship_count": window_champs.size(),
				"last_championship_year": int(window_champs[window_champs.size() - 1])
			}

	return {}


## Checks if a team is currently in a dynasty era.
##
## Parameters:
##   world_state: Dictionary containing dynasty_eras
##   team_id: Team identifier
##
## Returns: true if team has an active dynasty
static func is_in_dynasty(world_state: Dictionary, team_id: String) -> bool:
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	var active_dynasties: Array = dynasties.get("active_dynasties", [])

	return not _find_active_dynasty(active_dynasties, team_id).is_empty()


## Gets the active dynasty for a specific team.
##
## Parameters:
##   world_state: Dictionary containing dynasty_eras
##   team_id: Team identifier
##
## Returns: Dynasty dictionary if active, empty dict otherwise
static func get_active_dynasty(world_state: Dictionary, team_id: String) -> Dictionary:
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	var active_dynasties: Array = dynasties.get("active_dynasties", [])

	return _find_active_dynasty(active_dynasties, team_id)


## Gets all dynasties (active and completed) for a specific team.
##
## Parameters:
##   world_state: Dictionary containing dynasty_eras
##   team_id: Team identifier
##
## Returns: Array of dynasty dictionaries
static func get_team_dynasties(world_state: Dictionary, team_id: String) -> Array:
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	var active_dynasties: Array = dynasties.get("active_dynasties", [])
	var completed_dynasties: Array = dynasties.get("completed_dynasties", [])
	var result := []

	# Add active dynasty if exists
	var active := _find_active_dynasty(active_dynasties, team_id)
	if not active.is_empty():
		result.append(active)

	# Add completed dynasties
	for dynasty in completed_dynasties:
		var d: Dictionary = dynasty
		if String(d.get("team_id", "")) == team_id:
			result.append(d)

	return result


## Gets all active dynasties in the league.
##
## Parameters:
##   world_state: Dictionary containing dynasty_eras
##
## Returns: Array of active dynasty dictionaries
static func get_all_active_dynasties(world_state: Dictionary) -> Array:
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	return dynasties.get("active_dynasties", [])


## Gets all completed dynasties in league history.
##
## Parameters:
##   world_state: Dictionary containing dynasty_eras
##
## Returns: Array of completed dynasty dictionaries
static func get_all_completed_dynasties(world_state: Dictionary) -> Array:
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	return dynasties.get("completed_dynasties", [])


## Gets dynasty statistics for display/analysis.
##
## Parameters:
##   dynasty: Dynasty dictionary
##
## Returns: Dictionary with formatted statistics
static func get_dynasty_stats(dynasty: Dictionary) -> Dictionary:
	var start_year := int(dynasty.get("start_year", 0))
	var end_year := int(dynasty.get("end_year", 0))
	var championship_years: Array = dynasty.get("championship_years", [])
	var is_active := (end_year == 0)

	var duration := 0
	if is_active:
		# Active dynasty: duration from start to last championship
		var last_champ := int(dynasty.get("last_championship_year", start_year))
		duration = last_champ - start_year + 1
	else:
		# Completed dynasty: duration from start to end
		duration = end_year - start_year + 1

	return {
		"team_id": String(dynasty.get("team_id", "")),
		"start_year": start_year,
		"end_year": end_year,
		"duration": duration,
		"championships": championship_years.size(),
		"championship_years": championship_years,
		"is_active": is_active,
		"dynasty_span": "%d-%d" % [start_year, end_year if not is_active else start_year + duration - 1]
	}


## Ranks all dynasties by championship count.
##
## Parameters:
##   world_state: Dictionary containing dynasty_eras
##   include_active: Whether to include active dynasties (default true)
##
## Returns: Array of dynasties sorted by championship count descending
static func rank_dynasties_by_championships(
	world_state: Dictionary,
	include_active: bool = true
) -> Array:
	var dynasties: Dictionary = world_state.get("dynasty_eras", {})
	var all_dynasties := []

	# Collect completed dynasties
	var completed: Array = dynasties.get("completed_dynasties", [])
	all_dynasties.append_array(completed)

	# Optionally include active dynasties
	if include_active:
		var active: Array = dynasties.get("active_dynasties", [])
		all_dynasties.append_array(active)

	# Sort by championship count descending
	all_dynasties.sort_custom(func(a, b):
		var count_a := int(a["championship_count"])
		var count_b := int(b["championship_count"])
		if count_a != count_b:
			return count_a > count_b
		# Tiebreaker: earlier start year first
		return int(a["start_year"]) < int(b["start_year"])
	)

	return all_dynasties
