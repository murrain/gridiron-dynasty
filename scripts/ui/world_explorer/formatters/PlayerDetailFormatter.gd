class_name PlayerDetailFormatter
extends RefCounted

## Formats player data into BBCode for RichTextLabel display
##
## Generates comprehensive player detail view with header, stats, traits,
## contract info, and career history

## Main entry point - format complete player detail
## Returns BBCode string ready for RichTextLabel
static func format(player: Dictionary, world_state: Dictionary) -> String:
	var bb := ""

	bb += _format_header(player)
	bb += "\n"
	bb += _format_physicals(player)
	bb += "\n"
	bb += _format_core_stats(player)
	bb += "\n"
	bb += _format_all_stats(player)
	bb += "\n"
	bb += _format_traits(player)
	bb += "\n"

	if player.has("contract"):
		bb += _format_contract(player)
		bb += "\n"

	bb += _format_career_info(player, world_state)

	return bb

## Format player header with name, position, age, and overall rating
static func _format_header(player: Dictionary) -> String:
	var bb := ""
	var name = PlayerQueries.get_player_name(player)
	bb += "[center][font_size=20][b]%s[/b][/font_size][/center]\n" % name

	var position = player.get("position", "?")
	var age = player.get("age", 0)
	bb += "[center][font_size=16]%s • Age %d[/font_size][/center]\n" % [position, age]

	# Composite rating
	var rating = StatQueries.calculate_composite_rating(player)
	var color = StatQueries.get_stat_color_hex(rating)
	bb += "[center][bgcolor=%s] %.0f Overall [/bgcolor][/center]\n" % [color, rating]

	return bb

## Format physical attributes (height, weight, measurements)
static func _format_physicals(player: Dictionary) -> String:
	var physicals = player.get("physicals", {})
	if physicals.is_empty():
		return "[b]Physical Attributes[/b]\n[i][color=#999999]No physical data available[/color][/i]\n\n"

	var bb := ""
	bb += "[b]Physical Attributes[/b]\n"
	bb += "[table=2]"

	var height_in = physicals.get("height_in", 0.0)
	bb += "[cell]Height:[/cell][cell]%d' %d\"[/cell]" % [
		int(height_in) / 12,
		int(height_in) % 12
	]
	bb += "[cell]Weight:[/cell][cell]%.0f lbs[/cell]" % physicals.get("weight_lb", 0.0)

	if physicals.has("hand_size_in"):
		bb += "[cell]Hand Size:[/cell][cell]%.1f in[/cell]" % physicals.get("hand_size_in", 0.0)

	if physicals.has("arm_length_in"):
		bb += "[cell]Arm Length:[/cell][cell]%.1f in[/cell]" % physicals.get("arm_length_in", 0.0)

	bb += "[/table]\n"
	return bb

## Format core stats for the player's position
static func _format_core_stats(player: Dictionary) -> String:
	var position = player.get("position", "")
	var core_stat_names = StatQueries.get_core_stats_for_position(position)
	if core_stat_names.is_empty():
		return "[b]Core Stats[/b]\n[i][color=#999999]No core stats defined for position: %s[/color][/i]\n\n" % position

	var stats = player.get("stats", {})
	if stats.is_empty():
		return "[b]Core Stats[/b]\n[i][color=#999999]No stats available[/color][/i]\n\n"

	var bb := ""
	bb += "[b]Core Stats[/b]\n"
	bb += "[table=3]"

	for stat_name in core_stat_names:
		var value = stats.get(stat_name, 0.0)
		var color = StatQueries.get_stat_color_hex(value)
		bb += "[cell]%s:[/cell][cell][color=%s]%.0f[/color][/cell][cell]%s[/cell]" % [
			stat_name.capitalize().replace("_", " "),
			color,
			value,
			StatsFormatter.format_stat_bar(value)
		]

	bb += "[/table]\n"
	return bb

## Format all stats in alphabetical order
static func _format_all_stats(player: Dictionary) -> String:
	var stats = player.get("stats", {})
	if stats.is_empty():
		return "[b]All Stats[/b]\n[i][color=#999999]No stats available[/color][/i]\n\n"

	var bb := ""
	bb += "[b]All Stats[/b]\n"

	var stat_names = stats.keys()
	stat_names.sort()

	bb += "[table=4]"
	for stat_name in stat_names:
		var value = stats[stat_name]
		var color = StatQueries.get_stat_color_hex(value)
		bb += "[cell]%s:[/cell][cell][color=%s]%.0f[/color][/cell]" % [
			stat_name.capitalize().replace("_", " "),
			color,
			value
		]
	bb += "[/table]\n"

	return bb

## Format player traits list
static func _format_traits(player: Dictionary) -> String:
	var traits = player.get("traits", [])
	if traits.is_empty():
		return ""

	var bb := ""
	bb += "[b]Traits[/b]\n"
	for trait_name in traits:
		bb += "★ %s\n" % trait_name
	bb += "\n"

	return bb

## Format contract details (NFL players only)
static func _format_contract(player: Dictionary) -> String:
	var contract = player.get("contract", {})
	if contract.is_empty():
		return "[b]Contract[/b]\n[i][color=#999999]No contract information available[/color][/i]\n\n"

	var bb := ""
	bb += "[b]Contract[/b]\n"
	bb += "[table=2]"
	bb += "[cell]Annual Value:[/cell][cell]$%.2fM[/cell]" % contract.get("annual_value", 0.0)
	bb += "[cell]Total Years:[/cell][cell]%d[/cell]" % contract.get("total_years", 0)
	bb += "[cell]Current Year:[/cell][cell]%d[/cell]" % contract.get("current_year", 0)
	bb += "[cell]Guaranteed:[/cell][cell]$%.2fM[/cell]" % contract.get("guaranteed", 0.0)
	bb += "[/table]\n"

	return bb

## Format career information (team/school, draft info)
static func _format_career_info(player: Dictionary, world_state: Dictionary) -> String:
	var bb := ""
	bb += "[b]Career Info[/b]\n"

	var has_career_info := false

	# Current team/school
	if player.has("nfl_team_id"):
		var team = TeamQueries.get_nfl_team(world_state, player["nfl_team_id"])
		if team:
			bb += "Team: %s\n" % team.get("name", "Unknown")
			has_career_info = true
	elif player.has("college_id"):
		var college = TeamQueries.get_college(world_state, player["college_id"])
		if college:
			bb += "College: %s (Year %d)\n" % [college.get("name", "Unknown"), player.get("college_year", 0)]
			has_career_info = true
	elif player.has("hs_school_id"):
		var school = TeamQueries.get_hs_school(world_state, player["hs_school_id"])
		if school:
			bb += "High School: %s (Year %d)\n" % [school.get("name", "Unknown"), player.get("hs_year", 0)]
			has_career_info = true

	# Draft info
	if player.has("draft_info"):
		var draft = player["draft_info"]
		bb += "Drafted: Round %d, Pick %d (%d)\n" % [
			draft.get("round", 0),
			draft.get("pick", 0),
			draft.get("year", 0)
		]
		has_career_info = true

	if not has_career_info:
		bb += "[i][color=#999999]No career information available[/color][/i]\n"

	return bb
