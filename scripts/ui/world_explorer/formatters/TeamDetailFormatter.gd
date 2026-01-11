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
	bb += "[b]Roster Composition[/b]\n"
	bb += "Total Players: %d\n\n" % roster.size()

	var by_position = TeamQueries.get_roster_by_position(world_state, team.get("id", ""), "nfl")
	bb += "[table=2]"
	var positions = by_position.keys()
	positions.sort()
	for pos in positions:
		bb += "[cell]%s:[/cell][cell]%d[/cell]" % [pos, by_position[pos].size()]
	bb += "[/table]\n\n"

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
