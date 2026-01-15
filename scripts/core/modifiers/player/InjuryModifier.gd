## InjuryModifier - Reduces player stats while injured
##
## Attached to specific players when they get injured.
## Has a duration and affects in-game performance.
##
## Example injuries:
##   - Hand injury: -20% catching, -10% blocking
##   - Leg injury: -30% speed, -20% agility
##   - Shoulder injury: -25% throw_power, -15% blocking
extends "res://scripts/core/modifiers/Modifier.gd"


## Injury severity affects stat penalties
enum Severity {
	MINOR,      ## Small penalty, short duration
	MODERATE,   ## Medium penalty, medium duration
	MAJOR,      ## Large penalty, long duration
	SEVERE,     ## Very large penalty, season-ending
}

## Body part affects which stats are impacted
enum BodyPart {
	HAND,
	ARM,
	SHOULDER,
	LEG,
	ANKLE,
	KNEE,
	BACK,
	HEAD,
}

var _severity: Severity = Severity.MINOR
var _body_part: BodyPart = BodyPart.LEG
var _days_remaining: int = 7
var _affected_stats: Dictionary = {}


func _init(
	severity: Severity = Severity.MINOR,
	body_part: BodyPart = BodyPart.LEG,
	duration_days: int = 7
) -> void:
	_severity = severity
	_body_part = body_part
	_days_remaining = duration_days
	_affected_stats = _calculate_affected_stats()


func get_id() -> String:
	return "injury_%s_%s" % [_body_part_name(), _severity_name()]


func get_display_name() -> String:
	return "%s %s Injury" % [_severity_name().capitalize(), _body_part_name().capitalize()]


func get_description() -> String:
	return "Player has a %s %s injury (%d days remaining)" % [
		_severity_name(), _body_part_name(), _days_remaining
	]


func get_target() -> Target:
	return Target.PLAYER_PERFORMANCE


func get_contexts() -> Array:
	return [Context.GAME]


func get_priority() -> int:
	return 20  # Injuries apply early


func get_tags() -> Array:
	return ["injury", "temporary", "negative"]


func is_stackable() -> bool:
	return true  # Multiple injuries can affect a player


func get_duration() -> int:
	return _days_remaining


func is_active() -> bool:
	return _days_remaining > 0


func is_applicable(context_data: Dictionary) -> bool:
	return is_active()


func calculate(context_data: Dictionary) -> ModifierResult:
	# This modifier returns a multiplier per affected stat
	# The game simulation should query for specific stats

	var requested_stat := String(context_data.get("stat", ""))
	if requested_stat.is_empty():
		# Return overall penalty
		return ModifierResult.new(_get_overall_penalty(), 0.0, get_description())

	# Check if this stat is affected
	var stat_penalty := float(_affected_stats.get(requested_stat, 1.0))

	return ModifierResult.new(stat_penalty, 0.0, "%s affected by %s injury" % [
		requested_stat, _body_part_name()
	], {
		"stat": requested_stat,
		"penalty": stat_penalty,
		"body_part": _body_part_name(),
		"severity": _severity_name()
	})


func on_tick(days_passed: int) -> void:
	_days_remaining = max(0, _days_remaining - days_passed)


func to_dict() -> Dictionary:
	return {
		"id": get_id(),
		"type": "injury",
		"severity": _severity,
		"body_part": _body_part,
		"days_remaining": _days_remaining,
	}


func from_dict(data: Dictionary) -> void:
	_severity = int(data.get("severity", Severity.MINOR)) as Severity
	_body_part = int(data.get("body_part", BodyPart.LEG)) as BodyPart
	_days_remaining = int(data.get("days_remaining", 7))
	_affected_stats = _calculate_affected_stats()


func _calculate_affected_stats() -> Dictionary:
	var base_penalty := _get_severity_penalty()
	var stats := {}

	match _body_part:
		BodyPart.HAND:
			stats["catching"] = 1.0 - (base_penalty * 0.8)
			stats["blocking"] = 1.0 - (base_penalty * 0.4)
			stats["ball_security"] = 1.0 - (base_penalty * 0.6)

		BodyPart.ARM:
			stats["throw_power"] = 1.0 - (base_penalty * 0.7)
			stats["throw_accuracy"] = 1.0 - (base_penalty * 0.5)
			stats["blocking"] = 1.0 - (base_penalty * 0.4)

		BodyPart.SHOULDER:
			stats["throw_power"] = 1.0 - (base_penalty * 0.8)
			stats["blocking"] = 1.0 - (base_penalty * 0.5)
			stats["tackling"] = 1.0 - (base_penalty * 0.4)

		BodyPart.LEG, BodyPart.KNEE, BodyPart.ANKLE:
			stats["speed"] = 1.0 - (base_penalty * 0.9)
			stats["agility"] = 1.0 - (base_penalty * 0.8)
			stats["acceleration"] = 1.0 - (base_penalty * 0.7)
			stats["jumping"] = 1.0 - (base_penalty * 0.6)

		BodyPart.BACK:
			stats["blocking"] = 1.0 - (base_penalty * 0.6)
			stats["tackling"] = 1.0 - (base_penalty * 0.5)
			stats["strength"] = 1.0 - (base_penalty * 0.4)

		BodyPart.HEAD:
			stats["awareness"] = 1.0 - (base_penalty * 0.7)
			stats["decision_making"] = 1.0 - (base_penalty * 0.6)
			stats["football_IQ"] = 1.0 - (base_penalty * 0.4)

	return stats


func _get_severity_penalty() -> float:
	match _severity:
		Severity.MINOR:
			return 0.15
		Severity.MODERATE:
			return 0.30
		Severity.MAJOR:
			return 0.50
		Severity.SEVERE:
			return 0.75
	return 0.15


func _get_overall_penalty() -> float:
	# Average of all affected stats
	if _affected_stats.is_empty():
		return 1.0
	var total := 0.0
	for stat in _affected_stats.keys():
		total += float(_affected_stats[stat])
	return total / float(_affected_stats.size())


func _severity_name() -> String:
	match _severity:
		Severity.MINOR: return "minor"
		Severity.MODERATE: return "moderate"
		Severity.MAJOR: return "major"
		Severity.SEVERE: return "severe"
	return "unknown"


func _body_part_name() -> String:
	match _body_part:
		BodyPart.HAND: return "hand"
		BodyPart.ARM: return "arm"
		BodyPart.SHOULDER: return "shoulder"
		BodyPart.LEG: return "leg"
		BodyPart.ANKLE: return "ankle"
		BodyPart.KNEE: return "knee"
		BodyPart.BACK: return "back"
		BodyPart.HEAD: return "head"
	return "unknown"


## Factory for creating injuries from configuration
static func create_from_config(injury_cfg: Dictionary) -> InjuryModifier:
	var severity_str := String(injury_cfg.get("severity", "minor"))
	var body_part_str := String(injury_cfg.get("body_part", "leg"))
	var duration := int(injury_cfg.get("duration_days", 7))

	var severity: Severity
	match severity_str:
		"minor": severity = Severity.MINOR
		"moderate": severity = Severity.MODERATE
		"major": severity = Severity.MAJOR
		"severe": severity = Severity.SEVERE
		_: severity = Severity.MINOR

	var body_part: BodyPart
	match body_part_str:
		"hand": body_part = BodyPart.HAND
		"arm": body_part = BodyPart.ARM
		"shoulder": body_part = BodyPart.SHOULDER
		"leg": body_part = BodyPart.LEG
		"ankle": body_part = BodyPart.ANKLE
		"knee": body_part = BodyPart.KNEE
		"back": body_part = BodyPart.BACK
		"head": body_part = BodyPart.HEAD
		_: body_part = BodyPart.LEG

	return InjuryModifier.new(severity, body_part, duration)
