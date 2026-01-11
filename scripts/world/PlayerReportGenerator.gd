extends RefCounted
class_name PlayerReportGenerator

## Generates development reports on-demand from player data.
##
## Development reports are typically generated during player lifecycle progression,
## but during bootstrap they are skipped to save memory. This class can reconstruct
## basic reports from available player data when needed for UI/debugging.
##
## Note: On-demand reports are approximations based on current player state,
## not historical snapshots. For full accuracy, disable skip_reports mode.

## Generates a basic development report from current player state.
##
## Parameters:
##   player: Player dictionary with stats, age, wear, etc.
##   world_state: World state dictionary (unused currently, reserved for future)
##
## Returns:
##   Array of report entries, one per year since career start.
##   Each entry contains: age, phase, wear snapshot, decline_multiplier
##
## Note: This is a reconstruction based on current state, not historical data.
static func generate_development_report(
	player: Dictionary,
	_world_state: Dictionary = {}
) -> Array:
	# Check if player already has a report
	var existing_report: Array = player.get("development_report", []) as Array
	if not existing_report.is_empty():
		return existing_report

	# Reconstruct basic report from player data
	var reports: Array = []
	var current_age := int(player.get("age", 18))
	var career_start_age := int(player.get("career_start_age", 0))

	# If no career_start_age is set, estimate from birth_year
	if career_start_age == 0:
		if player.has("birth_year") and player.has("draft_year"):
			var birth_year := int(player.get("birth_year", 2000))
			var draft_year := int(player.get("draft_year", 0))
			if draft_year > 0:
				career_start_age = draft_year - birth_year
		else:
			# Default to current age if we can't determine start
			career_start_age = current_age

	# Generate one entry per year of career
	for age in range(career_start_age, current_age + 1):
		var phase := _estimate_phase(age, player)
		var wear_snapshot := _estimate_wear_snapshot(player, age)
		var decline_mult := _estimate_decline_multiplier(player, age)

		reports.append({
			"age": age,
			"phase": phase,
			"wear": wear_snapshot,
			"decline_multiplier": decline_mult,
			"reconstructed": true  # Mark as reconstructed vs. historical
		})

	return reports

## Estimates the development phase based on age and position.
##
## Parameters:
##   age: Player's age
##   player: Player dictionary with position info
##
## Returns:
##   String: "growth", "prime", or "decline"
static func _estimate_phase(age: int, player: Dictionary) -> String:
	var position := String(player.get("position", ""))

	# Default thresholds (can be refined based on position)
	var peak_age := 26
	var decline_start := 30

	# Position-specific adjustments
	match position:
		"QB":
			peak_age = 27
			decline_start = 32
		"RB":
			peak_age = 24
			decline_start = 28
		"WR", "TE":
			peak_age = 26
			decline_start = 30
		"OL":
			peak_age = 27
			decline_start = 31
		"DL", "LB":
			peak_age = 26
			decline_start = 30
		"DB":
			peak_age = 25
			decline_start = 29

	if age < peak_age:
		return "growth"
	elif age < decline_start:
		return "prime"
	else:
		return "decline"

## Estimates wear snapshot based on current wear and age.
##
## Parameters:
##   player: Player dictionary with wear data
##   age: Age at which to estimate wear
##
## Returns:
##   Dictionary with snaps, collisions, injury_count estimates
static func _estimate_wear_snapshot(player: Dictionary, age: int) -> Dictionary:
	var current_wear: Dictionary = player.get("wear", {}) as Dictionary
	var current_age := int(player.get("age", 18))
	var career_start_age := int(player.get("career_start_age", 18))

	# If wear data exists, estimate historical wear
	if not current_wear.is_empty() and current_age > career_start_age:
		var years_played := current_age - career_start_age
		var year_index := age - career_start_age

		if years_played > 0:
			# Linear interpolation of wear (simplified model)
			var snaps := int(current_wear.get("snaps", 0))
			var collisions := int(current_wear.get("collisions", 0))
			var injuries := int(current_wear.get("injury_count", 0))

			var ratio := float(year_index) / float(years_played)
			return {
				"snaps": int(snaps * ratio),
				"collisions": int(collisions * ratio),
				"injury_count": int(injuries * ratio)
			}

	# Default empty wear snapshot
	return {
		"snaps": 0,
		"collisions": 0,
		"injury_count": 0
	}

## Estimates decline multiplier based on wear and age.
##
## Parameters:
##   player: Player dictionary with wear data
##   age: Age at which to estimate decline
##
## Returns:
##   Float: Decline multiplier (1.0 = no decline, higher = more decline)
static func _estimate_decline_multiplier(player: Dictionary, age: int) -> float:
	var position := String(player.get("position", ""))
	var decline_start := 30

	# Position-specific decline age
	match position:
		"QB":
			decline_start = 32
		"RB":
			decline_start = 28
		"WR", "TE":
			decline_start = 30
		"OL":
			decline_start = 31
		"DL", "LB":
			decline_start = 30
		"DB":
			decline_start = 29

	if age < decline_start:
		return 1.0

	# Simple linear decline model
	var years_past_decline := age - decline_start
	var base_mult := 1.0 + (years_past_decline * 0.1)

	# Factor in wear if available
	var wear: Dictionary = player.get("wear", {}) as Dictionary
	if not wear.is_empty():
		var injury_count := int(wear.get("injury_count", 0))
		if injury_count > 5:
			base_mult += 0.1 * (injury_count - 5)

	return clamp(base_mult, 1.0, 1.6)

## Generates a summary string for a report entry.
##
## Parameters:
##   report_entry: Dictionary with phase, age, decline_multiplier
##
## Returns:
##   String: Human-readable summary of the report entry
static func generate_summary(report_entry: Dictionary) -> String:
	var phase := String(report_entry.get("phase", ""))
	var age := int(report_entry.get("age", 0))
	var decline_mult := float(report_entry.get("decline_multiplier", 1.0))

	match phase:
		"growth":
			return "Age %d: Developing skills" % age
		"prime":
			return "Age %d: Peak performance" % age
		"decline":
			if decline_mult > 1.3:
				return "Age %d: Significant age-related regression" % age
			else:
				return "Age %d: Managing age-related regression" % age
		_:
			return "Age %d: Unknown phase" % age
