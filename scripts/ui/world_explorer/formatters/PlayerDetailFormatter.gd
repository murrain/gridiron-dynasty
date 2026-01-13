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
	bb += _format_combine_results(player)
	bb += "\n"
	bb += _format_core_stats(player)
	bb += "\n"
	bb += _format_secondary_stats(player)
	bb += "\n"
	bb += _format_other_stats(player)
	bb += "\n"
	bb += _format_traits(player)
	bb += "\n"
	bb += _format_hype_info(player)
	bb += "\n"

	if player.has("contract"):
		bb += _format_contract(player)
		bb += "\n"

	bb += _format_career_info(player, world_state)
	bb += "\n"
	bb += _format_player_history(player)

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

## Format secondary stats for the player's position (with bars)
static func _format_secondary_stats(player: Dictionary) -> String:
	var position = player.get("position", "")
	var secondary_stat_names = StatQueries.get_secondary_stats_for_position(position)
	if secondary_stat_names.is_empty():
		return ""  # No secondary stats section if none defined

	var stats = player.get("stats", {})
	if stats.is_empty():
		return ""

	var bb := ""
	bb += "[b]Secondary Stats[/b]\n"
	bb += "[table=3]"

	for stat_name in secondary_stat_names:
		if not stats.has(stat_name):
			continue  # Skip if player doesn't have this stat
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

## Format other stats (role="other" or not in core/secondary, no bars)
static func _format_other_stats(player: Dictionary) -> String:
	var position = player.get("position", "")
	var core_stat_names = StatQueries.get_core_stats_for_position(position)
	var secondary_stat_names = StatQueries.get_secondary_stats_for_position(position)

	# Combine core and secondary to filter them out
	var primary_stats := {}
	for stat in core_stat_names:
		primary_stats[stat] = true
	for stat in secondary_stat_names:
		primary_stats[stat] = true

	var stats = player.get("stats", {})
	if stats.is_empty():
		return ""

	# Get stats that are not core or secondary
	var other_stat_names: Array = []
	for stat_name in stats.keys():
		if not primary_stats.has(stat_name):
			other_stat_names.append(stat_name)

	if other_stat_names.is_empty():
		return ""  # No other stats to display

	other_stat_names.sort()

	var bb := ""
	bb += "[b]Other Stats[/b]\n"
	bb += "[table=2]"

	for stat_name in other_stat_names:
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


## Format combine results (40 time, vertical, bench, etc.)
static func _format_combine_results(player: Dictionary) -> String:
	var combine = player.get("combine_results", {})
	if combine.is_empty():
		return ""

	var bb := "[b]Combine Results[/b]\n"
	bb += "[table=2]"

	# 40-yard dash
	if combine.has("forty_time"):
		var time = combine.get("forty_time", 0.0)
		var color := "#ffffff"
		if time < 4.4:
			color = "#00ff00"  # Elite
		elif time < 4.5:
			color = "#99ff99"  # Very good
		elif time > 4.8:
			color = "#ff6666"  # Below average
		bb += "[cell]40-Yard Dash:[/cell][cell][color=%s]%.2fs[/color][/cell]" % [color, time]

	# Vertical jump
	if combine.has("vertical_jump"):
		var jump = combine.get("vertical_jump", 0.0)
		var color := "#ffffff"
		if jump > 40:
			color = "#00ff00"
		elif jump > 36:
			color = "#99ff99"
		elif jump < 30:
			color = "#ff6666"
		bb += "[cell]Vertical Jump:[/cell][cell][color=%s]%.1f\"[/color][/cell]" % [color, jump]

	# Broad jump
	if combine.has("broad_jump"):
		var jump = combine.get("broad_jump", 0.0)
		bb += "[cell]Broad Jump:[/cell][cell]%.0f\"[/cell]" % jump

	# Bench press
	if combine.has("bench_press"):
		var reps = combine.get("bench_press", 0)
		var color := "#ffffff"
		if reps > 30:
			color = "#00ff00"
		elif reps > 25:
			color = "#99ff99"
		elif reps < 15:
			color = "#ff6666"
		bb += "[cell]Bench Press:[/cell][cell][color=%s]%d reps[/color][/cell]" % [color, reps]

	# 3-cone drill
	if combine.has("three_cone"):
		var time = combine.get("three_cone", 0.0)
		bb += "[cell]3-Cone Drill:[/cell][cell]%.2fs[/cell]" % time

	# 20-yard shuttle
	if combine.has("shuttle"):
		var time = combine.get("shuttle", 0.0)
		bb += "[cell]20-Yard Shuttle:[/cell][cell]%.2fs[/cell]" % time

	bb += "[/table]\n"
	return bb


## Format player hype information
static func _format_hype_info(player: Dictionary) -> String:
	var hype = player.get("hype", -1.0)
	if hype < 0:
		return ""

	var bb := "[b]Draft Stock[/b]\n"

	# Hype rating with color
	var color := "#ffffff"
	if hype >= 80:
		color = "#00ff00"  # Top prospect
	elif hype >= 60:
		color = "#99ff99"  # Rising star
	elif hype >= 40:
		color = "#ffff00"  # Average buzz
	elif hype >= 20:
		color = "#ff9900"  # Falling
	else:
		color = "#ff0000"  # Major concerns

	bb += "Hype: [color=%s]%.0f[/color]\n" % [color, hype]

	# Character grade if available
	var char_profile = player.get("character_profile", {})
	var char_grade = char_profile.get("character_grade", "")
	if not char_grade.is_empty():
		var grade_color := "#ffffff"
		match char_grade:
			"exemplary": grade_color = "#00ff00"
			"clean": grade_color = "#99ff99"
			"concern": grade_color = "#ff9900"
			"red_flag": grade_color = "#ff0000"
		bb += "Character: [color=%s]%s[/color]\n" % [grade_color, char_grade.capitalize()]

	bb += "\n"
	return bb


## Format player history (awards, injuries, discipline, contracts, milestones)
##
## Event Types:
##   Career Milestones (cyan):
##     - college_commit: Committed to college
##     - redshirt: Took redshirt year
##     - transfer: Transferred to another school
##     - draft_declaration: Declared for draft (early or senior)
##     - draft: Selected in NFL draft
##     - undrafted_signing: Signed as undrafted free agent
##     - combine_invite: Invited to NFL Combine
##
##   Contract Events (green):
##     - rookie_contract: Signed rookie contract
##     - contract_extension: Signed contract extension
##     - contract_signing: Signed with team (free agency)
##     - franchise_tag: Franchise tagged
##     - released: Released/waived
##     - traded: Traded to another team
##     - retirement: Retired from NFL
##
##   Achievements (purple):
##     - pro_bowl: Pro Bowl selection
##     - all_pro: All-Pro selection
##     - super_bowl: Super Bowl champion
##     - mvp: MVP/OPOY/DPOY award
##     - milestone: Career statistical milestone
##     - first_start: First NFL start
##
##   Awards (gold): award
##   Discipline (orange): discipline
##   Injuries (red): injury
static func _format_player_history(player: Dictionary) -> String:
	var history: Array = player.get("history", [])
	if history.is_empty():
		return ""

	var bb := "[b]Career History[/b]\n"

	# Group events by category for cleaner display
	var career_milestones: Array = []  # College commit, draft, etc.
	var contract_events: Array = []     # Contracts, trades, releases
	var achievements: Array = []        # Pro Bowl, All-Pro, milestones
	var awards: Array = []              # College awards (Heisman, etc.)
	var discipline: Array = []          # Discipline issues
	var injuries: Array = []            # Injury history
	var other: Array = []               # Uncategorized

	for event in history:
		var event_dict: Dictionary = event
		var event_type = event_dict.get("type", "")
		match event_type:
			# Career milestones
			"college_commit", "redshirt", "transfer", "draft_declaration", \
			"draft", "undrafted_signing", "combine_invite":
				career_milestones.append(event_dict)
			# Contract events
			"rookie_contract", "contract_extension", "contract_signing", \
			"franchise_tag", "released", "traded", "retirement":
				contract_events.append(event_dict)
			# Achievements
			"pro_bowl", "all_pro", "super_bowl", "mvp", "milestone", "first_start":
				achievements.append(event_dict)
			# Awards
			"award":
				awards.append(event_dict)
			# Discipline
			"discipline":
				discipline.append(event_dict)
			# Injuries
			"injury":
				injuries.append(event_dict)
			_:
				other.append(event_dict)

	# Career Milestones (cyan)
	if not career_milestones.is_empty():
		bb += "\n[color=#00ccff]Career Timeline[/color]\n"
		for event in career_milestones:
			bb += _format_career_milestone_event(event)

	# Contract Events (green)
	if not contract_events.is_empty():
		bb += "\n[color=#00cc66]Transactions[/color]\n"
		for event in contract_events:
			bb += _format_contract_event(event)

	# Achievements (purple)
	if not achievements.is_empty():
		bb += "\n[color=#cc66ff]Achievements[/color]\n"
		for event in achievements:
			bb += _format_achievement_event(event)

	# Awards (gold)
	if not awards.is_empty():
		bb += "\n[color=#ffcc00]Awards & Honors[/color]\n"
		for event in awards:
			bb += _format_award_event(event)

	# Discipline events (orange)
	if not discipline.is_empty():
		bb += "\n[color=#ff6600]Discipline Record[/color]\n"
		for event in discipline:
			bb += _format_discipline_event(event)

	# Injuries (red)
	if not injuries.is_empty():
		bb += "\n[color=#ff3333]Injury History[/color]\n"
		for event in injuries:
			bb += _format_injury_event(event)

	# Other/uncategorized events
	if not other.is_empty():
		bb += "\n[color=#999999]Other Events[/color]\n"
		for event in other:
			var year = event.get("year", 0)
			var description = event.get("description", "Unknown event")
			bb += "  Year %d: %s\n" % [year, description]

	return bb


## Format career milestone event (commit, draft, transfer, etc.)
static func _format_career_milestone_event(event: Dictionary) -> String:
	var year = event.get("year", 0)
	var event_type = event.get("type", "")
	var bb := "  %d: " % year

	match event_type:
		"college_commit":
			var college = event.get("college", "Unknown")
			var stars = event.get("stars", 0)
			bb += "Committed to %s" % college
			if stars > 0:
				bb += " (%d-star recruit)" % stars
		"redshirt":
			bb += "Redshirt season"
		"transfer":
			var from_school = event.get("from", "")
			var to_school = event.get("to", "Unknown")
			if not from_school.is_empty():
				bb += "Transferred from %s to %s" % [from_school, to_school]
			else:
				bb += "Transferred to %s" % to_school
		"draft_declaration":
			var early = event.get("early", false)
			if early:
				bb += "Declared for NFL Draft (early entry)"
			else:
				bb += "Entered NFL Draft"
		"draft":
			var round_num = event.get("round", 0)
			var pick = event.get("pick", 0)
			var team = event.get("team", "Unknown")
			bb += "Drafted by %s (Round %d, Pick %d)" % [team, round_num, pick]
		"undrafted_signing":
			var team = event.get("team", "Unknown")
			bb += "Signed with %s as undrafted free agent" % team
		"combine_invite":
			bb += "Invited to NFL Combine"
		_:
			bb += event.get("description", event_type)

	bb += "\n"
	return bb


## Format contract/transaction event
static func _format_contract_event(event: Dictionary) -> String:
	var year = event.get("year", 0)
	var event_type = event.get("type", "")
	var bb := "  %d: " % year

	match event_type:
		"rookie_contract":
			var team = event.get("team", "")
			var years = event.get("years", 0)
			var value = event.get("value", 0.0)
			bb += "Signed rookie contract"
			if not team.is_empty():
				bb += " with %s" % team
			if years > 0 and value > 0:
				bb += " (%d yr, $%.1fM)" % [years, value]
			elif years > 0:
				bb += " (%d years)" % years
		"contract_extension":
			var team = event.get("team", "")
			var years = event.get("years", 0)
			var value = event.get("value", 0.0)
			var guaranteed = event.get("guaranteed", 0.0)
			bb += "Signed contract extension"
			if not team.is_empty():
				bb += " with %s" % team
			if years > 0 and value > 0:
				bb += " (%d yr, $%.1fM" % [years, value]
				if guaranteed > 0:
					bb += ", $%.1fM guaranteed" % guaranteed
				bb += ")"
		"contract_signing":
			var team = event.get("team", "")
			var years = event.get("years", 0)
			var value = event.get("value", 0.0)
			bb += "Signed"
			if not team.is_empty():
				bb += " with %s" % team
			if years > 0 and value > 0:
				bb += " (%d yr, $%.1fM)" % [years, value]
		"franchise_tag":
			var team = event.get("team", "")
			var tag_type = event.get("tag_type", "franchise")
			bb += "%s tagged" % tag_type.capitalize()
			if not team.is_empty():
				bb += " by %s" % team
		"released":
			var team = event.get("team", "")
			var reason = event.get("reason", "")
			bb += "Released"
			if not team.is_empty():
				bb += " by %s" % team
			if not reason.is_empty():
				bb += " (%s)" % reason
		"traded":
			var from_team = event.get("from", "")
			var to_team = event.get("to", "Unknown")
			if not from_team.is_empty():
				bb += "Traded from %s to %s" % [from_team, to_team]
			else:
				bb += "Traded to %s" % to_team
		"retirement":
			bb += "Retired from NFL"
			var reason = event.get("reason", "")
			if not reason.is_empty():
				bb += " (%s)" % reason
		_:
			bb += event.get("description", event_type)

	bb += "\n"
	return bb


## Format achievement event (Pro Bowl, All-Pro, milestones)
static func _format_achievement_event(event: Dictionary) -> String:
	var year = event.get("year", 0)
	var event_type = event.get("type", "")
	var bb := "  %d: " % year

	match event_type:
		"pro_bowl":
			var times = event.get("career_total", 0)
			bb += "Pro Bowl selection"
			if times > 1:
				bb += " (%dx)" % times
		"all_pro":
			var team_type = event.get("team", "First")  # First or Second
			bb += "%s-Team All-Pro" % team_type
		"super_bowl":
			var sb_number = event.get("number", "")
			bb += "Super Bowl Champion"
			if not str(sb_number).is_empty():
				bb += " (Super Bowl %s)" % str(sb_number)
		"mvp":
			var award_type = event.get("award", "MVP")
			bb += "%s" % award_type
		"milestone":
			var milestone_type = event.get("milestone", "")
			var value = event.get("value", 0)
			if not milestone_type.is_empty():
				bb += "Career milestone: %s" % milestone_type
				if value > 0:
					bb += " (%d)" % value
			else:
				bb += event.get("description", "Career milestone")
		"first_start":
			var team = event.get("team", "")
			bb += "First NFL start"
			if not team.is_empty():
				bb += " (%s)" % team
		_:
			bb += event.get("description", event_type)

	bb += "\n"
	return bb


## Format award event (Heisman, conference awards, etc.)
static func _format_award_event(event: Dictionary) -> String:
	var year = event.get("year", 0)
	var award_name = event.get("award", event.get("description", "Unknown Award"))
	var hype_impact = event.get("hype_impact", 0.0)

	var bb := "  %d: %s" % [year, award_name]
	if hype_impact != 0:
		var impact_color = "#00ff00" if hype_impact > 0 else "#ff0000"
		bb += " [color=%s](%+.0f hype)[/color]" % [impact_color, hype_impact]
	bb += "\n"
	return bb


## Format discipline event
static func _format_discipline_event(event: Dictionary) -> String:
	var year = event.get("year", 0)
	var event_name = event.get("event", "Unknown")
	var description = event.get("description", "")
	var games = event.get("games_suspended", 0)
	var hype_impact = event.get("hype_impact", 0.0)

	var bb := "  %d: %s" % [year, _format_discipline_type(event_name)]
	if games > 0:
		bb += " (%d games)" % games
	if hype_impact != 0:
		bb += " [color=#ff0000](%+.0f hype)[/color]" % hype_impact
	bb += "\n"
	if not description.is_empty():
		bb += "    [color=#999999]%s[/color]\n" % description
	return bb


## Format injury event
static func _format_injury_event(event: Dictionary) -> String:
	var year = event.get("year", 0)
	var injury_type = event.get("injury_type", "Unknown")
	var severity = event.get("severity", 0.0)
	var games_missed = event.get("games_missed", 0)
	var hype_impact = event.get("hype_impact", 0.0)

	var bb := "  %d: %s" % [year, injury_type.capitalize().replace("_", " ")]
	if severity > 0:
		bb += " (severity %.1f)" % severity
	if games_missed > 0:
		bb += " - %d games missed" % games_missed
	if hype_impact != 0:
		bb += " [color=#ff0000](%+.0f hype)[/color]" % hype_impact
	bb += "\n"
	return bb


## Format discipline event type for display
static func _format_discipline_type(event_type: String) -> String:
	match event_type:
		"academic": return "Academic Violation"
		"team_rules": return "Team Rules Violation"
		"substance_abuse": return "Substance Policy Violation"
		"conduct": return "Conduct Violation"
		"legal_trouble": return "Legal Trouble"
		_: return event_type.capitalize().replace("_", " ")
