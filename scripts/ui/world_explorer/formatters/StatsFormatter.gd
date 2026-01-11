class_name StatsFormatter
extends RefCounted

## Generic stat display formatting helpers
##
## Provides reusable BBCode formatting functions for stats, ratings,
## progress bars, and comparisons

## Format a stat bar (visual progress bar using Unicode characters)
## value: Current stat value (0-max_value)
## max_value: Maximum value for the bar (default 100.0)
## width: Number of characters wide (default 20)
## Returns BBCode string with filled and empty bar segments
static func format_stat_bar(value: float, max_value: float = 100.0, width: int = 20) -> String:
	var filled = int((value / max_value) * width)
	filled = clampi(filled, 0, width)
	var empty = width - filled

	return "[color=#666666]%s%s[/color]" % [
		"█".repeat(filled),
		"░".repeat(empty)
	]

## Format a rating badge with colored background
## rating: Numeric rating value (0-100)
## Returns BBCode string with colored background
static func format_rating_badge(rating: float) -> String:
	var color = StatQueries.get_stat_color_hex(rating)
	return "[bgcolor=%s] %.0f [/bgcolor]" % [color, rating]

## Format a stat comparison between two values
## Shows difference with color coding (green=positive, red=negative, yellow=equal)
## Returns BBCode string showing both values and the difference
static func format_stat_comparison(value_a: float, value_b: float, stat_name: String) -> String:
	var diff = value_a - value_b
	var color = "#00ff00" if diff > 0 else ("#ff0000" if diff < 0 else "#ffff00")
	return "%s: %.0f vs %.0f ([color=%s]%+.0f[/color])" % [
		stat_name.capitalize(),
		value_a,
		value_b,
		color,
		diff
	]

## Format a stat table (simple 2-column layout)
## stats: Dictionary mapping stat_name -> value
## Returns BBCode table string with color-coded stat values
static func format_stat_table(stats: Dictionary) -> String:
	var bb := "[table=2]"

	var keys = stats.keys()
	keys.sort()

	for key in keys:
		var value = stats[key]
		var color = StatQueries.get_stat_color_hex(value)
		bb += "[cell]%s:[/cell][cell][color=%s]%.0f[/color][/cell]" % [
			key.capitalize().replace("_", " "),
			color,
			value
		]

	bb += "[/table]"
	return bb
