extends RefCounted
class_name DraftRumorEngine

## Draft Rumor Engine - Draft Day Intelligence and Speculation
##
## Generates realistic draft day rumors and intel drops that create atmosphere
## and uncertainty. Rumors span multiple types (trade talks, team interest,
## medical updates, surprise picks) with varying accuracy levels.
##
## Design:
##   - Stateless service (all state in caller)
##   - Deterministic via explicit RNG seeding
##   - Template-based text generation
##   - Pre-generates all rumors at draft start for performance
##
## Integration:
##   - Called by InteractiveDraft at draft initialization
##   - Rumors stored in InteractiveDraft._rumor_feed
##   - Emitted via rumor_published signal on timeline
##
## RNG Pattern:
##   - Uses context-derived seed: base_seed ^ 0xRUMOR000
##   - Per-rumor: 4-5 rolls for type, accuracy, player, team, template

const Rand = preload("res://autoloads/Rand.gd")

## Rumor type constants
const TYPE_TRADE_TALK := "trade_talk"
const TYPE_TEAM_INTEREST := "team_interest"
const TYPE_MEDICAL_UPDATE := "medical_update"
const TYPE_SURPRISE_PICK := "surprise_pick"

## Accuracy level constants
const ACCURACY_CONFIRMED := "confirmed"
const ACCURACY_LIKELY := "likely"
const ACCURACY_SPECULATION := "speculation"

## Default configuration values
const DEFAULT_TOTAL_COUNT := 120
const DEFAULT_ACCURACY_DIST := {
	"confirmed": 0.30,
	"likely": 0.50,
	"speculation": 0.20
}

## Time periods for rumor distribution (hours before draft)
const TIME_PERIODS := [24, 12, 6, 3, 1, 0]

## Accuracy level prefixes for display
const ACCURACY_PREFIXES := {
	"confirmed": "[CONFIRMED] ",
	"likely": "[REPORT] ",
	"speculation": "[RUMOR] "
}

## Template definitions by rumor type
const TEMPLATES := {
	"trade_talk": [
		"%s exploring trade up to draft %s %s",
		"%s in talks to move up for %s %s",
		"%s discussing trade package for top-%d range",
		"Sources: %s gauging interest in trading up",
		"%s offering future picks to move up for %s %s",
		"Trade talks intensifying between %s and multiple teams"
	],
	"team_interest": [
		"%s showing strong interest in %s %s",
		"%s met with %s %s multiple times",
		"Sources: %s high on %s %s",
		"%s has %s %s atop their board",
		"Expect %s to target %s %s if available",
		"%s brass impressed by %s %s workout"
	],
	"medical_update": [
		"%s %s passed team medical with no concerns",
		"%s %s medical recheck scheduled",
		"Teams monitoring %s %s medical situation",
		"%s %s cleared after second medical exam",
		"Positive medical news for %s %s",
		"Teams satisfied with %s %s injury rehab progress"
	],
	"surprise_pick": [
		"%s may target %s %s earlier than expected",
		"%s could reach for %s %s",
		"Don't sleep on %s drafting %s %s",
		"Sleeper alert: %s high on %s %s",
		"%s has %s %s higher than consensus",
		"Surprise pick possibility: %s eyeing %s %s"
	]
}


## Generate all rumors for draft day
##
## Creates a timeline of rumors from 24 hours before draft to draft start.
## Rumors are pre-generated for determinism and performance.
##
## RNG consumption:
##   - total_count / 6 rumors per time period
##   - Per rumor: 4-5 rolls for type, accuracy, player, team, template
##
## @param draft_pool: Array of draft-eligible player dictionaries
## @param teams: Array of NFL team dictionaries
## @param draft_order: Draft order array (for pick range context)
## @param config: Configuration with optional "rumors" section
## @param seed: Base seed for determinism
## @return Array[Dictionary]: All rumors sorted by timestamp (reverse chronological)
static func generate_all_rumors(
	draft_pool: Array,
	teams: Array,
	draft_order: Array,
	config: Dictionary,
	seed: int
) -> Array:
	if draft_pool.is_empty() or teams.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	# Seed constant: 0x00CAFEEE (chosen as unique identifier for rumor system)
	rng.seed = Rand.splitmix64(seed ^ 0x00CAFEEE)

	var rumor_cfg: Dictionary = config.get("rumors", {})
	var total_count := int(rumor_cfg.get("total_count", DEFAULT_TOTAL_COUNT))
	var accuracy_dist: Dictionary = rumor_cfg.get("accuracy_distribution", DEFAULT_ACCURACY_DIST)

	var all_rumors: Array = []

	# Calculate rumors per time period (distribute evenly)
	var rumors_per_period := int(ceil(float(total_count) / float(TIME_PERIODS.size())))

	# Generate rumors for each time period
	for hours_before in TIME_PERIODS:
		for i in range(rumors_per_period):
			if all_rumors.size() >= total_count:
				break

			var rumor := _generate_single_rumor(
				draft_pool,
				teams,
				draft_order,
				hours_before,
				accuracy_dist,
				rng
			)
			all_rumors.append(rumor)

	# Sort by timestamp (reverse chronological: 24h first, 0h last)
	all_rumors.sort_custom(func(a, b):
		return int(a.get("hours_before", 0)) > int(b.get("hours_before", 0))
	)

	return all_rumors


## Generate a single rumor
##
## Creates a complete rumor with type, accuracy, subject, and formatted text.
##
## RNG consumption: 4-5 rolls (type, accuracy, player index, team index, template index)
##
## @param draft_pool: Array of draft-eligible players
## @param teams: Array of NFL teams
## @param draft_order: Draft order array
## @param hours_before: Hours before draft for this rumor
## @param accuracy_dist: Accuracy distribution config
## @param rng: RNG instance
## @return Dictionary: Complete rumor entry
static func _generate_single_rumor(
	draft_pool: Array,
	teams: Array,
	draft_order: Array,
	hours_before: int,
	accuracy_dist: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# RNG roll 1: Select rumor type
	var rumor_types: Array[String] = [TYPE_TRADE_TALK, TYPE_TEAM_INTEREST, TYPE_MEDICAL_UPDATE, TYPE_SURPRISE_PICK]
	var rumor_type := String(rumor_types[rng.randi() % rumor_types.size()])

	# RNG roll 2: Select accuracy level based on distribution
	var accuracy := _select_accuracy_level(accuracy_dist, rng)

	# RNG roll 3: Select random player from draft pool
	var player: Dictionary = draft_pool[rng.randi() % draft_pool.size()]

	# RNG roll 4: Select random team
	var team: Dictionary = teams[rng.randi() % teams.size()]

	# RNG roll 5: Generate rumor text using appropriate template
	var text := _generate_rumor_text(rumor_type, player, team, accuracy, draft_order, rng)

	return {
		"type": rumor_type,
		"accuracy": accuracy,
		"subject_player_id": String(player.get("player_id", player.get("id", ""))),
		"subject_player_name": String(player.get("name", "Unknown")),
		"subject_player_position": String(player.get("position", "")),
		"subject_team_id": String(team.get("id", "")),
		"subject_team_name": String(team.get("name", "Team")),
		"text": text,
		"hours_before": hours_before,
		"timestamp_label": _format_timestamp_label(hours_before)
	}


## Select accuracy level based on configured distribution
##
## Uses cumulative probability to select accuracy.
##
## RNG consumption: 1 roll
##
## @param accuracy_dist: Distribution config (confirmed: 0.3, likely: 0.5, speculation: 0.2)
## @param rng: RNG instance
## @return String: Accuracy level constant
static func _select_accuracy_level(
	accuracy_dist: Dictionary,
	rng: RandomNumberGenerator
) -> String:
	var roll := rng.randf()
	var cumulative := 0.0

	for level in [ACCURACY_CONFIRMED, ACCURACY_LIKELY, ACCURACY_SPECULATION]:
		cumulative += float(accuracy_dist.get(level, 0.0))
		if roll < cumulative:
			return level

	return ACCURACY_SPECULATION


## Generate rumor text from template
##
## Selects an appropriate template and fills in placeholders with
## player/team information.
##
## RNG consumption: 1 roll for template selection
##
## @param rumor_type: Type of rumor
## @param player: Player dictionary
## @param team: Team dictionary
## @param accuracy: Accuracy level
## @param draft_order: Draft order for context
## @param rng: RNG instance
## @return String: Formatted rumor text with accuracy prefix
static func _generate_rumor_text(
	rumor_type: String,
	player: Dictionary,
	team: Dictionary,
	accuracy: String,
	draft_order: Array,
	rng: RandomNumberGenerator
) -> String:
	var player_name := String(player.get("name", "Unknown"))
	var team_name := String(team.get("name", "Team"))
	var position := String(player.get("position", ""))

	# Get accuracy prefix
	var prefix := String(ACCURACY_PREFIXES.get(accuracy, "[RUMOR] "))

	# Get templates for this type
	var template_options: Array = TEMPLATES.get(rumor_type, ["Generic rumor about %s"])
	var template := String(template_options[rng.randi() % template_options.size()])

	# Format based on template placeholders
	var text := ""

	if "%d" in template:
		# Template has pick number placeholder
		var pick_range := 10 + rng.randi() % 20  # Pick range 10-30
		if template.count("%s") == 1:
			text = template % [team_name, pick_range]
		else:
			text = template % [team_name, position, player_name, pick_range]
	elif template.count("%s") == 3:
		# Standard 3-placeholder template: team, position, player
		text = template % [team_name, position, player_name]
	elif template.count("%s") == 2:
		# 2-placeholder: position, player or team, player
		if "team" in template.to_lower() or template.begins_with("%s"):
			text = template % [team_name, player_name]
		else:
			text = template % [position, player_name]
	elif template.count("%s") == 1:
		# Single placeholder: team name
		text = template % team_name
	else:
		# No placeholders
		text = template

	return prefix + text


## Format timestamp label for display
##
## Converts hours_before to a human-readable label.
##
## @param hours_before: Hours before draft (0-24)
## @return String: Formatted label (e.g., "24h before", "1h before", "Draft day")
static func _format_timestamp_label(hours_before: int) -> String:
	if hours_before == 0:
		return "Draft day"
	elif hours_before == 1:
		return "1 hour before"
	else:
		return "%d hours before" % hours_before


## Filter rumors by time - returns rumors visible at given time
##
## As the draft approaches, more rumors become visible.
## At 24h before: only 24h rumors visible
## At 12h before: 24h and 12h rumors visible
## At 0h (draft start): all rumors visible
##
## @param all_rumors: Array of all generated rumors
## @param current_hours_before: Current time (hours before draft)
## @return Array[Dictionary]: Visible rumors
static func get_visible_rumors(
	all_rumors: Array,
	current_hours_before: int
) -> Array:
	var visible: Array = []

	for rumor in all_rumors:
		var r: Dictionary = rumor
		var rumor_time := int(r.get("hours_before", 0))

		# Show rumors from time periods that have passed
		# e.g., at 6h before draft, show rumors from 24h, 12h, and 6h
		if rumor_time >= current_hours_before:
			visible.append(r)

	return visible


## Get new rumors since last check
##
## Returns only rumors in the current time period that weren't
## visible in the previous period.
##
## @param all_rumors: Array of all generated rumors
## @param current_hours_before: Current time
## @param last_hours_before: Previous check time
## @return Array[Dictionary]: Newly visible rumors
static func get_new_rumors(
	all_rumors: Array,
	current_hours_before: int,
	last_hours_before: int
) -> Array:
	var new_rumors: Array = []

	for rumor in all_rumors:
		var r: Dictionary = rumor
		var rumor_time := int(r.get("hours_before", 0))

		# Rumor is new if it's visible now but wasn't before
		if rumor_time >= current_hours_before and rumor_time < last_hours_before:
			new_rumors.append(r)

	return new_rumors


## Get rumors about a specific player
##
## Filters all rumors to those mentioning the specified player.
##
## @param all_rumors: Array of all rumors
## @param player_id: Player ID to filter by
## @return Array[Dictionary]: Rumors mentioning player
static func get_player_rumors(
	all_rumors: Array,
	player_id: String
) -> Array:
	var player_rumors: Array = []

	for rumor in all_rumors:
		var r: Dictionary = rumor
		if String(r.get("subject_player_id", "")) == player_id:
			player_rumors.append(r)

	return player_rumors


## Get rumors about a specific team
##
## Filters all rumors to those mentioning the specified team.
##
## @param all_rumors: Array of all rumors
## @param team_id: Team ID to filter by
## @return Array[Dictionary]: Rumors mentioning team
static func get_team_rumors(
	all_rumors: Array,
	team_id: String
) -> Array:
	var team_rumors: Array = []

	for rumor in all_rumors:
		var r: Dictionary = rumor
		if String(r.get("subject_team_id", "")) == team_id:
			team_rumors.append(r)

	return team_rumors


## Get rumors by type
##
## Filters all rumors to those of a specific type.
##
## @param all_rumors: Array of all rumors
## @param rumor_type: Type to filter by (trade_talk, team_interest, etc.)
## @return Array[Dictionary]: Rumors of specified type
static func get_rumors_by_type(
	all_rumors: Array,
	rumor_type: String
) -> Array:
	var typed_rumors: Array = []

	for rumor in all_rumors:
		var r: Dictionary = rumor
		if String(r.get("type", "")) == rumor_type:
			typed_rumors.append(r)

	return typed_rumors


## Get rumors by accuracy level
##
## Filters all rumors to those with specified accuracy.
##
## @param all_rumors: Array of all rumors
## @param accuracy: Accuracy level (confirmed, likely, speculation)
## @return Array[Dictionary]: Rumors with specified accuracy
static func get_rumors_by_accuracy(
	all_rumors: Array,
	accuracy: String
) -> Array:
	var filtered: Array = []

	for rumor in all_rumors:
		var r: Dictionary = rumor
		if String(r.get("accuracy", "")) == accuracy:
			filtered.append(r)

	return filtered


## Get rumor statistics for analytics
##
## Returns summary statistics about the rumor feed.
##
## @param all_rumors: Array of all rumors
## @return Dictionary: Statistics (counts by type, accuracy, time period)
static func get_rumor_stats(all_rumors: Array) -> Dictionary:
	var by_type := {
		TYPE_TRADE_TALK: 0,
		TYPE_TEAM_INTEREST: 0,
		TYPE_MEDICAL_UPDATE: 0,
		TYPE_SURPRISE_PICK: 0
	}

	var by_accuracy := {
		ACCURACY_CONFIRMED: 0,
		ACCURACY_LIKELY: 0,
		ACCURACY_SPECULATION: 0
	}

	var by_time := {}

	for rumor in all_rumors:
		var r: Dictionary = rumor
		var rtype := String(r.get("type", ""))
		var accuracy := String(r.get("accuracy", ""))
		var hours := int(r.get("hours_before", 0))

		if by_type.has(rtype):
			by_type[rtype] += 1

		if by_accuracy.has(accuracy):
			by_accuracy[accuracy] += 1

		if not by_time.has(hours):
			by_time[hours] = 0
		by_time[hours] += 1

	return {
		"total": all_rumors.size(),
		"by_type": by_type,
		"by_accuracy": by_accuracy,
		"by_time_period": by_time
	}


## Format a single rumor for display
##
## Creates a formatted string suitable for UI display.
##
## @param rumor: Single rumor dictionary
## @return String: Formatted display text
static func format_for_display(rumor: Dictionary) -> String:
	var text := String(rumor.get("text", ""))
	var timestamp := String(rumor.get("timestamp_label", ""))
	return "[%s] %s" % [timestamp, text]


## Check if a rumor is about a trade
##
## @param rumor: Rumor dictionary
## @return bool: True if rumor is about a trade
static func is_trade_rumor(rumor: Dictionary) -> bool:
	return String(rumor.get("type", "")) == TYPE_TRADE_TALK


## Check if rumor is confirmed
##
## @param rumor: Rumor dictionary
## @return bool: True if rumor has confirmed accuracy
static func is_confirmed(rumor: Dictionary) -> bool:
	return String(rumor.get("accuracy", "")) == ACCURACY_CONFIRMED
