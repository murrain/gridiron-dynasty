class_name RosterQueries
extends RefCounted

## Static utility class for roster analysis and queries
##
## Provides functions to analyze roster composition, position groups,
## depth charts, and player distribution metrics.
##
## Dependencies:
## - StatQueries: for calculate_composite_rating()
## - PlayerQueries: for player validation and name formatting

## Position group mappings for American football
const POSITION_GROUPS := {
	"offense": ["QB", "RB", "WR", "TE", "OL"],
	"defense": ["DL", "EDGE", "LB", "CB", "S"],
	"special_teams": ["K", "P"]
}

## College year classifications
const COLLEGE_YEAR_NAMES := {
	1: "freshmen",
	2: "sophomores",
	3: "juniors",
	4: "seniors",
	5: "fifth_year"
}

## NFL year classifications (simplified)
const NFL_YEAR_NAMES := {
	1: "rookies",
	2: "year_2",
	3: "year_3",
	4: "year_4",
	5: "year_5_plus"
}

## High school year classifications
const HS_YEAR_NAMES := {
	1: "year_1",
	2: "year_2",
	3: "year_3",
	4: "year_4"
}

## Group players into position groups (offense/defense/special_teams)
##
## Categorizes roster players into three primary groups based on their position.
## Position mappings:
## - Offense: QB, RB, WR, TE, OL
## - Defense: DL, EDGE, LB, CB, S
## - Special Teams: K, P
##
## Parameters:
##   roster: Array of player Dictionaries (must have "position" field)
##
## Returns:
##   Dictionary with keys "offense", "defense", "special_teams"
##   Each value is an Array of player Dictionaries
##   Players with unknown positions are excluded
##
## Performance: O(N) where N = roster size
##
## Example:
##     var groups = RosterQueries.get_position_groups(roster)
##     print("Offense count: ", groups["offense"].size())
##     print("Defense count: ", groups["defense"].size())
static func get_position_groups(roster: Array) -> Dictionary:
	var groups := {
		"offense": [],
		"defense": [],
		"special_teams": []
	}

	if roster.is_empty():
		return groups

	# Build reverse lookup map for efficient categorization
	var position_to_group := {}
	for group_name in POSITION_GROUPS.keys():
		var positions: Array = POSITION_GROUPS[group_name]
		for pos in positions:
			position_to_group[pos] = group_name

	# Categorize each player
	for player in roster:
		if not player is Dictionary:
			continue

		var position := String(player.get("position", ""))
		if position.is_empty():
			continue

		var group_name = position_to_group.get(position, "")
		if not group_name.is_empty():
			groups[group_name].append(player)

	return groups

## Calculate average rating for all players at a specific position
##
## Computes the mean composite rating for all players matching the given position.
## Uses StatQueries.calculate_composite_rating() for individual player ratings.
##
## Parameters:
##   roster: Array of player Dictionaries
##   position: Position code (e.g., "QB", "RB", "WR")
##
## Returns:
##   float: Average overall rating (0-100 range)
##   Returns 0.0 if no players found at position or roster is empty
##
## Performance: O(N) where N = roster size
##
## Example:
##     var qb_strength = RosterQueries.calculate_position_strength(roster, "QB")
##     print("QB average rating: %.1f" % qb_strength)
static func calculate_position_strength(roster: Array, position: String) -> float:
	if roster.is_empty() or position.is_empty():
		return 0.0

	var total_rating := 0.0
	var player_count := 0

	for player in roster:
		if not player is Dictionary:
			continue

		var player_pos := String(player.get("position", ""))
		if player_pos != position:
			continue

		var rating := StatQueries.calculate_composite_rating(player)
		total_rating += rating
		player_count += 1

	if player_count == 0:
		return 0.0

	return total_rating / float(player_count)

## Analyze position depth (count players by position)
##
## Counts the number of players at each position on the roster.
## Useful for identifying depth chart gaps and roster imbalances.
##
## Parameters:
##   roster: Array of player Dictionaries
##
## Returns:
##   Dictionary mapping position code (String) -> player count (int)
##   Example: {"QB": 3, "RB": 5, "WR": 8, "TE": 4, ...}
##   Positions with 0 players are not included in result
##
## Performance: O(N) where N = roster size
##
## Example:
##     var depth = RosterQueries.analyze_position_depth(roster)
##     for pos in depth.keys():
##         print("%s: %d players" % [pos, depth[pos]])
static func analyze_position_depth(roster: Array) -> Dictionary:
	var depth := {}

	if roster.is_empty():
		return depth

	for player in roster:
		if not player is Dictionary:
			continue

		var position := String(player.get("position", ""))
		if position.is_empty():
			continue

		if not depth.has(position):
			depth[position] = 0
		depth[position] += 1

	return depth

## Calculate age distribution statistics for a roster
##
## Computes minimum, maximum, average, and median age across all players.
## Age is extracted from the "age" field in player dictionaries.
##
## Parameters:
##   roster: Array of player Dictionaries (must have "age" field)
##
## Returns:
##   Dictionary with keys:
##   - "min": Youngest player age (int)
##   - "max": Oldest player age (int)
##   - "avg": Average age (float, rounded to 1 decimal)
##   - "median": Median age (float, rounded to 1 decimal)
##   Returns {"min": 0, "max": 0, "avg": 0.0, "median": 0.0} for empty rosters
##
## Performance: O(N log N) where N = roster size (due to median calculation sort)
##
## Example:
##     var age_dist = RosterQueries.get_age_distribution(roster)
##     print("Age range: %d - %d (avg: %.1f)" % [age_dist["min"], age_dist["max"], age_dist["avg"]])
static func get_age_distribution(roster: Array) -> Dictionary:
	var result := {
		"min": 0,
		"max": 0,
		"avg": 0.0,
		"median": 0.0
	}

	if roster.is_empty():
		return result

	# Extract all valid ages
	var ages: Array = []
	for player in roster:
		if not player is Dictionary:
			continue

		var age := int(player.get("age", 0))
		if age > 0:
			ages.append(age)

	if ages.is_empty():
		return result

	# Sort for min/max/median
	ages.sort()

	# Calculate statistics
	result["min"] = ages[0]
	result["max"] = ages[ages.size() - 1]

	# Average
	var sum := 0
	for age in ages:
		sum += age
	result["avg"] = round(float(sum) / float(ages.size()) * 10.0) / 10.0

	# Median
	var mid := ages.size() / 2
	if ages.size() % 2 == 0:
		# Even count: average of two middle values
		result["median"] = round(float(ages[mid - 1] + ages[mid]) / 2.0 * 10.0) / 10.0
	else:
		# Odd count: middle value
		result["median"] = float(ages[mid])

	return result

## Calculate experience distribution for a roster
##
## Counts players by their experience level (years at current level).
## Supports college, NFL, and high school classification systems.
##
## College classifications:
## - Year 1: "freshmen"
## - Year 2: "sophomores"
## - Year 3: "juniors"
## - Year 4: "seniors"
## - Year 5+: "fifth_year"
##
## NFL classifications:
## - Year 1: "rookies"
## - Year 2: "year_2"
## - Year 3: "year_3"
## - Year 4: "year_4"
## - Year 5+: "year_5_plus"
##
## High School classifications:
## - Year 1: "year_1"
## - Year 2: "year_2"
## - Year 3: "year_3"
## - Year 4: "year_4"
##
## Parameters:
##   roster: Array of player Dictionaries
##   level: "college", "nfl", or "hs"/"high_school" (determines which year field to use)
##
## Returns:
##   Dictionary mapping classification name (String) -> player count (int)
##   Example (college): {"freshmen": 25, "sophomores": 20, "juniors": 18, ...}
##   Example (nfl): {"rookies": 15, "year_2": 12, "year_3": 10, ...}
##   Example (hs): {"year_1": 8, "year_2": 10, "year_3": 9, "year_4": 7}
##   Returns empty dictionary for invalid level or empty roster
##
## Performance: O(N) where N = roster size
##
## Example:
##     var exp_dist = RosterQueries.get_experience_distribution(roster, "college")
##     print("Freshmen: %d" % exp_dist.get("freshmen", 0))
##     print("Seniors: %d" % exp_dist.get("seniors", 0))
static func get_experience_distribution(roster: Array, level: String) -> Dictionary:
	var distribution := {}

	if roster.is_empty() or level.is_empty():
		return distribution

	var level_lower := level.to_lower()
	var year_field := ""
	var classification_map := {}

	# Determine which field to use and classification map
	match level_lower:
		"college":
			year_field = "college_year"
			classification_map = COLLEGE_YEAR_NAMES
		"nfl":
			year_field = "nfl_year"
			classification_map = NFL_YEAR_NAMES
		"hs", "high_school":
			year_field = "hs_year"
			classification_map = HS_YEAR_NAMES
		_:
			push_warning("RosterQueries: Unknown level '%s'" % level)
			return {}

	# Initialize all classifications to 0
	for classification in classification_map.values():
		distribution[classification] = 0

	# Count players by classification
	for player in roster:
		if not player is Dictionary:
			continue

		var year := int(player.get(year_field, 0))
		if year <= 0:
			continue

		# Determine classification
		var classification: String
		if year >= 5:
			# Handle 5+ years
			if level_lower == "college":
				classification = "fifth_year"
			else:
				classification = "year_5_plus"
		else:
			classification = classification_map.get(year, "")

		if not classification.is_empty():
			distribution[classification] += 1

	return distribution
