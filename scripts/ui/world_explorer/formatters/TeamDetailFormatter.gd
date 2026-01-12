class_name TeamDetailFormatter
extends RefCounted

## Formats team/school data into BBCode for RichTextLabel display
##
## Handles formatting for NFL teams, colleges, and high schools with
## appropriate level-specific details
##
## Dependencies:
## - TeamQueries: for get_nfl_roster(), get_roster_by_position()
## - PlayerQueries: for sort_players_by_rating(), get_player_name()
## - StatQueries: for calculate_composite_rating(), get_stat_color_hex()
## - RosterQueries: for position group analysis, depth analysis, demographics

## Salary cap thresholds for color coding (in millions)
const CAP_SPACE_HEALTHY = 10.0  # Green - comfortable room for signings
const CAP_SPACE_TIGHT = 0.0     # Yellow/Red threshold - no room

## Color codes for cap space status
const COLOR_CAP_HEALTHY = "#00ff00"  # Green
const COLOR_CAP_TIGHT = "#ffff00"    # Yellow
const COLOR_CAP_OVER = "#ff0000"     # Red

## Main entry point - format team detail based on level
## level: "nfl", "college", or "hs"
## Returns BBCode string ready for RichTextLabel
static func format(team: Dictionary, world_state: Dictionary, level: String) -> String:
	match level.to_lower():
		"nfl":
			return format_nfl_team(team, world_state)
		"college":
			return format_college(team, world_state)
		"hs", "high_school":
			return format_hs_school(team, world_state)
		_:
			return "[color=#ff0000]Unknown level: %s[/color]" % level

## Format NFL team with salary cap, roster composition, and top players
static func format_nfl_team(team: Dictionary, world_state: Dictionary) -> String:
	var bb := ""

	# Header
	bb += "[center][font_size=20][b]%s[/b][/font_size][/center]\n" % team.get("name", "Unknown Team")
	bb += "[center][font_size=14]%s[/font_size][/center]\n\n" % team.get("region", "").capitalize().replace("_", " ")

	# Salary Cap
	bb += "[b]Salary Cap[/b]\n"
	bb += "[table=2]"
	var league_cap = team.get("league_cap", 200.0)
	var cap_space = team.get("cap_space", 0.0)
	var cap_used = league_cap - cap_space

	bb += "[cell]League Cap:[/cell][cell]$%.1fM[/cell]" % league_cap
	bb += "[cell]Cap Used:[/cell][cell]$%.1fM[/cell]" % cap_used

	var cap_color = COLOR_CAP_HEALTHY if cap_space > CAP_SPACE_HEALTHY else (COLOR_CAP_TIGHT if cap_space > CAP_SPACE_TIGHT else COLOR_CAP_OVER)
	bb += "[cell]Cap Space:[/cell][cell][color=%s]$%.1fM[/color][/cell]" % [cap_color, cap_space]
	bb += "[/table]\n\n"

	# Roster composition
	var roster = TeamQueries.get_nfl_roster(world_state, team.get("id", ""))
	if roster == null:
		roster = []  # Fallback to empty array
	bb += "[b]Roster Composition[/b]\n"
	bb += "Total Players: %d\n\n" % roster.size()

	var by_position = TeamQueries.get_roster_by_position(world_state, team.get("id", ""), "nfl")
	bb += "[table=2]"
	var positions = by_position.keys()
	positions.sort()
	for pos in positions:
		bb += "[cell]%s:[/cell][cell]%d[/cell]" % [pos, by_position[pos].size()]
	bb += "[/table]\n\n"

	# Position group strength
	bb += _format_position_group_strength(roster)

	# Depth analysis
	bb += _format_depth_analysis(roster)

	# Roster demographics
	bb += _format_roster_demographics(roster, "nfl")

	# Full roster
	bb += _format_full_roster(roster, "nfl")

	# Top players
	bb += "[b]Top 5 Players[/b]\n"
	var sorted_roster = PlayerQueries.sort_players_by_rating(roster, false)
	for i in range(mini(5, sorted_roster.size())):
		var player = sorted_roster[i]
		var rating = StatQueries.calculate_composite_rating(player)
		var color = StatQueries.get_stat_color_hex(rating)
		bb += "%d. %s (%s) - [color=%s]%.0f[/color]\n" % [
			i + 1,
			PlayerQueries.get_player_name(player),
			player.get("position", "?"),
			color,
			rating
		]

	return bb

## Format college with program info, roster breakdown, and top players
static func format_college(college: Dictionary, world_state: Dictionary) -> String:
	var bb := ""

	# Header
	bb += "[center][font_size=20][b]%s[/b][/font_size][/center]\n" % college.get("name", "Unknown College")
	bb += "[center][font_size=14]%s • %s[/font_size][/center]\n\n" % [
		college.get("tier", "").capitalize(),
		college.get("region", "").capitalize().replace("_", " ")
	]

	# Program info
	bb += "[b]Program Info[/b]\n"
	bb += "[table=2]"
	bb += "[cell]Eliteness:[/cell][cell]%.0f[/cell]" % college.get("eliteness", 0.0)
	bb += "[cell]Tier:[/cell][cell]%s[/cell]" % college.get("tier", "Unknown")
	bb += "[cell]Capacity:[/cell][cell]%d[/cell]" % college.get("capacity", 50)
	bb += "[/table]\n\n"

	# Roster
	var roster = TeamQueries.get_college_roster(world_state, college.get("id", ""))
	if roster == null:
		roster = []  # Fallback to empty array
	bb += "[b]Roster[/b]\n"
	bb += "Total Players: %d\n" % roster.size()

	# Count by class year
	var by_year: Dictionary = {"1": 0, "2": 0, "3": 0, "4": 0}
	for player in roster:
		var year = str(player.get("college_year", 0))
		if by_year.has(year):
			by_year[year] += 1

	bb += "[table=2]"
	bb += "[cell]Freshmen:[/cell][cell]%d[/cell]" % by_year["1"]
	bb += "[cell]Sophomores:[/cell][cell]%d[/cell]" % by_year["2"]
	bb += "[cell]Juniors:[/cell][cell]%d[/cell]" % by_year["3"]
	bb += "[cell]Seniors:[/cell][cell]%d[/cell]" % by_year["4"]
	bb += "[/table]\n\n"

	# Position group strength
	bb += _format_position_group_strength(roster)

	# Depth analysis
	bb += _format_depth_analysis(roster)

	# Roster demographics
	bb += _format_roster_demographics(roster, "college")

	# Recruiting class strength (college only)
	bb += _format_recruiting_class_strength(college, world_state)

	# Full roster
	bb += _format_full_roster(roster, "college")

	# Top players
	bb += "[b]Top 5 Players[/b]\n"
	var sorted_roster = PlayerQueries.sort_players_by_rating(roster, false)
	for i in range(mini(5, sorted_roster.size())):
		var player = sorted_roster[i]
		var rating = StatQueries.calculate_composite_rating(player)
		var color = StatQueries.get_stat_color_hex(rating)
		bb += "%d. %s (%s, Year %d) - [color=%s]%.0f[/color]\n" % [
			i + 1,
			PlayerQueries.get_player_name(player),
			player.get("position", "?"),
			player.get("college_year", 0),
			color,
			rating
		]

	return bb

## Format high school with program quality, roster breakdown, and top players
static func format_hs_school(school: Dictionary, world_state: Dictionary) -> String:
	var bb := ""

	# Header
	bb += "[center][font_size=20][b]%s[/b][/font_size][/center]\n" % school.get("name", "Unknown School")
	bb += "[center][font_size=14]%s[/font_size][/center]\n\n" % school.get("region", "").capitalize().replace("_", " ")

	# Program info
	bb += "[b]Program Info[/b]\n"
	bb += "[table=2]"
	bb += "[cell]Tier:[/cell][cell]%s[/cell]" % school.get("tier", "Unknown")
	bb += "[cell]Program Quality:[/cell][cell]%s[/cell]" % school.get("program_quality_tier", "Unknown")
	bb += "[cell]Quality Multiplier:[/cell][cell]%.2fx[/cell]" % school.get("program_quality_multiplier", 1.0)
	bb += "[/table]\n\n"

	# Roster
	var roster = TeamQueries.get_hs_roster(world_state, school.get("id", ""))
	if roster == null:
		roster = []  # Fallback to empty array
	bb += "[b]Roster[/b]\n"
	bb += "Total Players: %d\n" % roster.size()

	# Count by year
	var by_year: Dictionary = {"1": 0, "2": 0, "3": 0, "4": 0}
	for player in roster:
		var year = str(player.get("hs_year", 0))
		if by_year.has(year):
			by_year[year] += 1

	bb += "[table=2]"
	bb += "[cell]Year 1:[/cell][cell]%d[/cell]" % by_year["1"]
	bb += "[cell]Year 2:[/cell][cell]%d[/cell]" % by_year["2"]
	bb += "[cell]Year 3:[/cell][cell]%d[/cell]" % by_year["3"]
	bb += "[cell]Year 4 (Seniors):[/cell][cell]%d[/cell]" % by_year["4"]
	bb += "[/table]\n\n"

	# Position group strength
	bb += _format_position_group_strength(roster)

	# Depth analysis
	bb += _format_depth_analysis(roster)

	# Roster demographics
	bb += _format_roster_demographics(roster, "hs")

	# Full roster
	bb += _format_full_roster(roster, "hs")

	# Top players
	bb += "[b]Top Players[/b]\n"
	var sorted_roster = PlayerQueries.sort_players_by_rating(roster, false)
	for i in range(mini(5, sorted_roster.size())):
		var player = sorted_roster[i]
		var rating = StatQueries.calculate_composite_rating(player)
		var color = StatQueries.get_stat_color_hex(rating)
		bb += "%d. %s (%s, Year %d) - [color=%s]%.0f[/color]\n" % [
			i + 1,
			PlayerQueries.get_player_name(player),
			player.get("position", "?"),
			player.get("hs_year", 0),
			color,
			rating
		]

	return bb

## Format position group strength (Offense/Defense/Special Teams ratings)
##
## Displays average ratings for each position group with color-coded indicators.
## Uses RosterQueries to calculate group strengths.
##
## Parameters:
## - roster: Array of player Dictionaries
##
## Returns: BBCode string with position group strength table
##
## Example output:
## [b]Position Group Strength[/b]
## [table=2]
## [cell]Offense:[/cell][cell]75 [color=#00ff00]●[/color][/cell]
## [cell]Defense:[/cell][cell]68 [color=#ffff00]●[/color][/cell]
## [cell]Special Teams:[/cell][cell]72 [color=#99ff99]●[/color][/cell]
## [/table]
static func _format_position_group_strength(roster: Array) -> String:
	if roster.is_empty():
		return ""

	var bb := "[b]Position Group Strength[/b]\n"
	bb += "[table=2]"

	# Get position groups from RosterQueries
	var groups = RosterQueries.get_position_groups(roster)

	# Calculate and display strength for each group
	for group_name in ["offense", "defense", "special_teams"]:
		var group_players = groups.get(group_name, [])
		var display_name = group_name.capitalize().replace("_", " ")

		if group_players.is_empty():
			bb += "[cell]%s:[/cell][cell]N/A[/cell]" % display_name
			continue

		# Calculate average rating for this group
		var total_rating: float = 0.0
		for player in group_players:
			total_rating += StatQueries.calculate_composite_rating(player)

		var avg_rating = total_rating / group_players.size()
		var color = StatQueries.get_stat_color_hex(avg_rating)

		bb += "[cell]%s:[/cell][cell]%.0f [color=%s]●[/color][/cell]" % [
			display_name,
			avg_rating,
			color
		]

	bb += "[/table]\n\n"
	return bb

## Format depth analysis (player counts by position)
##
## Shows how many players are at each position on the roster.
## Uses RosterQueries to analyze position depth.
##
## Parameters:
## - roster: Array of player Dictionaries
##
## Returns: BBCode string with depth analysis
##
## Example output:
## [b]Depth Chart[/b]
## QB: 3 | RB: 5 | WR: 8 | TE: 4 | OL: 12
## DL: 8 | EDGE: 6 | LB: 10 | CB: 8 | S: 6
## K: 1 | P: 1
static func _format_depth_analysis(roster: Array) -> String:
	if roster.is_empty():
		return ""

	var bb := "[b]Depth Chart[/b]\n"

	# Get position depth from RosterQueries
	var depth = RosterQueries.analyze_position_depth(roster)

	if depth.is_empty():
		bb += "No position data available\n\n"
		return bb

	# Group positions by unit for better readability
	var offense_positions = ["QB", "RB", "WR", "TE", "OL"]
	var defense_positions = ["DL", "EDGE", "LB", "CB", "S"]
	var special_positions = ["K", "P"]

	# Format offense line
	var offense_parts: Array = []
	for pos in offense_positions:
		if depth.has(pos):
			offense_parts.append("%s: %d" % [pos, depth[pos]])
	if not offense_parts.is_empty():
		bb += " | ".join(offense_parts) + "\n"

	# Format defense line
	var defense_parts: Array = []
	for pos in defense_positions:
		if depth.has(pos):
			defense_parts.append("%s: %d" % [pos, depth[pos]])
	if not defense_parts.is_empty():
		bb += " | ".join(defense_parts) + "\n"

	# Format special teams line
	var special_parts: Array = []
	for pos in special_positions:
		if depth.has(pos):
			special_parts.append("%s: %d" % [pos, depth[pos]])
	if not special_parts.is_empty():
		bb += " | ".join(special_parts) + "\n"

	bb += "\n"
	return bb

## Format roster demographics (age and experience distribution)
##
## Shows age range, average age, and experience breakdown.
## Uses RosterQueries to calculate demographics.
##
## Parameters:
## - roster: Array of player Dictionaries
## - level: "nfl", "college", or "hs" (determines experience classification)
##
## Returns: BBCode string with demographics information
##
## Example output (NFL):
## [b]Roster Demographics[/b]
## Age Range: 18-35 (avg 23.5)
## Experience: 15 rookies, 30 veterans, 8 experienced
##
## Example output (College):
## [b]Roster Demographics[/b]
## Age Range: 18-23 (avg 20.2)
## Experience: 20 freshmen, 18 sophomores, 15 juniors, 12 seniors
static func _format_roster_demographics(roster: Array, level: String) -> String:
	if roster.is_empty():
		return ""

	var bb := "[b]Roster Demographics[/b]\n"

	# Get age distribution
	var age_dist = RosterQueries.get_age_distribution(roster)
	if age_dist["max"] > 0:
		bb += "Age Range: %d-%d (avg %.1f)\n" % [
			age_dist["min"],
			age_dist["max"],
			age_dist["avg"]
		]
	else:
		bb += "Age Range: N/A\n"

	# Get experience distribution
	var exp_dist = RosterQueries.get_experience_distribution(roster, level)

	if not exp_dist.is_empty():
		bb += "Experience: "
		var exp_parts: Array = []

		match level.to_lower():
			"nfl":
				if exp_dist.has("rookies") and exp_dist["rookies"] > 0:
					exp_parts.append("%d rookies" % exp_dist["rookies"])
				if exp_dist.has("year_2") and exp_dist["year_2"] > 0:
					exp_parts.append("%d 2nd year" % exp_dist["year_2"])
				if exp_dist.has("year_3") and exp_dist["year_3"] > 0:
					exp_parts.append("%d 3rd year" % exp_dist["year_3"])
				if exp_dist.has("year_4") and exp_dist["year_4"] > 0:
					exp_parts.append("%d 4th year" % exp_dist["year_4"])
				if exp_dist.has("year_5_plus") and exp_dist["year_5_plus"] > 0:
					exp_parts.append("%d veterans (5+ yrs)" % exp_dist["year_5_plus"])

			"college":
				if exp_dist.has("freshmen") and exp_dist["freshmen"] > 0:
					exp_parts.append("%d freshmen" % exp_dist["freshmen"])
				if exp_dist.has("sophomores") and exp_dist["sophomores"] > 0:
					exp_parts.append("%d sophomores" % exp_dist["sophomores"])
				if exp_dist.has("juniors") and exp_dist["juniors"] > 0:
					exp_parts.append("%d juniors" % exp_dist["juniors"])
				if exp_dist.has("seniors") and exp_dist["seniors"] > 0:
					exp_parts.append("%d seniors" % exp_dist["seniors"])
				if exp_dist.has("fifth_year") and exp_dist["fifth_year"] > 0:
					exp_parts.append("%d fifth-year" % exp_dist["fifth_year"])

			"hs", "high_school":
				if exp_dist.has("year_1") and exp_dist["year_1"] > 0:
					exp_parts.append("%d year 1" % exp_dist["year_1"])
				if exp_dist.has("year_2") and exp_dist["year_2"] > 0:
					exp_parts.append("%d year 2" % exp_dist["year_2"])
				if exp_dist.has("year_3") and exp_dist["year_3"] > 0:
					exp_parts.append("%d year 3" % exp_dist["year_3"])
				if exp_dist.has("year_4") and exp_dist["year_4"] > 0:
					exp_parts.append("%d year 4" % exp_dist["year_4"])

		if not exp_parts.is_empty():
			bb += ", ".join(exp_parts) + "\n"
		else:
			bb += "N/A\n"
	else:
		bb += "Experience: N/A\n"

	bb += "\n"
	return bb

## Format recruiting class strength (college only)
##
## Shows most recent recruiting class statistics including star ratings
## and national ranking. Only applicable to college teams.
##
## Parameters:
## - college: College Dictionary with "id" field
## - world_state: Global world state Dictionary
##
## Returns: BBCode string with recruiting class info, or empty string if N/A
##
## Example output:
## [b]2025 Recruiting Class[/b]
## 15 commits (2x 5★, 5x 4★, 8x 3★)
## Ranked #12 nationally
static func _format_recruiting_class_strength(college: Dictionary, world_state: Dictionary) -> String:
	var college_id = college.get("id", "")
	if college_id.is_empty():
		return ""

	# Check if recruiting data exists
	var recruiting_data = world_state.get("recruiting", {})
	if recruiting_data.is_empty():
		return ""

	# Get the most recent year's data
	var current_year = world_state.get("current_year", 0)
	var recent_year = current_year

	# Try current year, then previous year
	var year_data = recruiting_data.get(str(current_year), {})
	if year_data.is_empty():
		recent_year = current_year - 1
		year_data = recruiting_data.get(str(recent_year), {})

	if year_data.is_empty():
		return ""

	# Get this college's commits
	var commits_by_school = year_data.get("commits", {})
	var college_commits = commits_by_school.get(college_id, [])

	if college_commits.is_empty():
		return ""

	var bb := "[b]%d Recruiting Class[/b]\n" % recent_year

	# Count star ratings
	var five_star = 0
	var four_star = 0
	var three_star = 0
	var two_star = 0

	for commit in college_commits:
		var stars = commit.get("stars", 0)
		match stars:
			5: five_star += 1
			4: four_star += 1
			3: three_star += 1
			2: two_star += 1

	# Format commit line with star breakdown
	var star_parts: Array = []
	if five_star > 0:
		star_parts.append("%dx 5★" % five_star)
	if four_star > 0:
		star_parts.append("%dx 4★" % four_star)
	if three_star > 0:
		star_parts.append("%dx 3★" % three_star)
	if two_star > 0:
		star_parts.append("%dx 2★" % two_star)

	bb += "%d commits" % college_commits.size()
	if not star_parts.is_empty():
		bb += " (%s)" % ", ".join(star_parts)
	bb += "\n"

	# Add national ranking if available
	var rankings = year_data.get("team_rankings", {})
	var national_rank = rankings.get(college_id, 0)
	if national_rank > 0:
		bb += "Ranked #%d nationally\n" % national_rank

	bb += "\n"
	return bb

## Format full roster grouped by position
##
## Displays all players organized by position groups (Offense/Defense/Special Teams)
## with name, position, rating, age, and experience information.
##
## Parameters:
## - roster: Array of player Dictionaries
## - level: "nfl", "college", or "hs" (determines experience format)
##
## Returns: BBCode string with full roster display
##
## Example output:
## [b]Full Roster[/b]
##
## [b]Offense[/b]
## [table=5]
## [cell]Name[/cell][cell]Pos[/cell][cell]Rating[/cell][cell]Age[/cell][cell]Exp[/cell]
## [cell]John Smith[/cell][cell]QB[/cell][cell][color=#00ff00]85[/color][/cell][cell]24[/cell][cell]3 yrs[/cell]
## ...
static func _format_full_roster(roster: Array, level: String) -> String:
	if roster.is_empty():
		return ""

	var bb := "[b]Full Roster[/b]\n\n"

	# Get position groups from RosterQueries
	var groups = RosterQueries.get_position_groups(roster)

	# Define position order for each group
	var offense_positions = ["QB", "RB", "WR", "TE", "OL"]
	var defense_positions = ["DL", "EDGE", "LB", "CB", "S"]
	var special_positions = ["K", "P"]

	# Format each group
	var group_configs = [
		{"name": "Offense", "key": "offense", "positions": offense_positions},
		{"name": "Defense", "key": "defense", "positions": defense_positions},
		{"name": "Special Teams", "key": "special_teams", "positions": special_positions}
	]

	for group_config in group_configs:
		var group_name = group_config["name"]
		var group_key = group_config["key"]
		var positions = group_config["positions"]

		var group_players = groups.get(group_key, [])
		if group_players.is_empty():
			continue

		bb += "[b]%s[/b]\n" % group_name
		bb += "[table=5]"
		bb += "[cell]Name[/cell][cell]Pos[/cell][cell]Rating[/cell][cell]Age[/cell][cell]Exp[/cell]"

		# OPTIMIZATION: Sort once, then group by position (avoids O(N×M) filter+sort pattern)
		# Pre-sort all players by rating (highest first)
		var sorted_by_rating = PlayerQueries.sort_players_by_rating(group_players, false)

		# Group by position while maintaining sort order
		var players_by_pos := {}
		for player in sorted_by_rating:
			var pos = player.get("position", "?")
			if not players_by_pos.has(pos):
				players_by_pos[pos] = []
			players_by_pos[pos].append(player)

		# Display in position order
		for pos in positions:
			if not players_by_pos.has(pos):
				continue

			# Format each player row (already sorted by rating)
			for player in players_by_pos[pos]:
				var name = PlayerQueries.get_player_name(player)
				var position = player.get("position", "?")
				var rating = StatQueries.calculate_composite_rating(player)
				var color = StatQueries.get_stat_color_hex(rating)
				var age = player.get("age", 0)
				var exp_text = _format_experience(player, level)

				bb += "[cell]%s[/cell][cell]%s[/cell][cell][color=%s]%.0f[/color][/cell][cell]%d[/cell][cell]%s[/cell]" % [
					name,
					position,
					color,
					rating,
					age,
					exp_text
				]

		bb += "[/table]\n\n"

	return bb

## Format experience text based on level
##
## Parameters:
## - player: Player Dictionary
## - level: "nfl", "college", or "hs"
##
## Returns: Formatted experience string
static func _format_experience(player: Dictionary, level: String) -> String:
	match level.to_lower():
		"nfl":
			var years = player.get("nfl_years", 0)
			if years == 0:
				return "Rookie"
			elif years == 1:
				return "1 yr"
			else:
				return "%d yrs" % years

		"college":
			var year = player.get("college_year", 0)
			match year:
				1: return "FR"
				2: return "SO"
				3: return "JR"
				4: return "SR"
				5: return "5Y"
				_: return "?"

		"hs", "high_school":
			var year = player.get("hs_year", 0)
			return "Y%d" % year if year > 0 else "?"

		_:
			return "?"
