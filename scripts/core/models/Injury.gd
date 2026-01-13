extends Resource
class_name Injury

## Severity threshold for IR placement (range 0.0-1.0)
## Values >=0.7 indicate injuries severe enough to warrant IR designation
## Based on NFL IR rules for season-ending or multi-week injuries
const IR_SEVERITY_THRESHOLD := 0.7

@export var type: String = ""
@export var severity: float = 0.0
@export var affected_stats: Array[String] = []
## Recovery timeline structure:
## {
##   "weeks_total": int,      # Total weeks to full recovery
##   "weeks_elapsed": int,    # Weeks already recovered (for tracking)
##   "ir_eligible_week": int  # Week number when eligible to return from IR (0 = not on IR)
## }
@export var recovery_timeline: Dictionary = {}
@export var long_term_penalty: Dictionary = {}

func from_dict(data: Dictionary) -> void:
	type = String(data.get("type", type))
	severity = float(data.get("severity", severity))
	affected_stats = (data.get("affected_stats", affected_stats) as Array).duplicate()
	recovery_timeline = (data.get("recovery_timeline", recovery_timeline) as Dictionary).duplicate(true)
	long_term_penalty = (data.get("long_term_penalty", long_term_penalty) as Dictionary).duplicate(true)

func to_dict() -> Dictionary:
	return {
		"type": type,
		"severity": severity,
		"affected_stats": affected_stats.duplicate(),
		"recovery_timeline": recovery_timeline.duplicate(true),
		"long_term_penalty": long_term_penalty.duplicate(true)
	}

## Determines if this injury is severe enough to require IR placement
## Based on severity threshold and recovery timeline
## Returns true if player should be placed on injured reserve
func requires_ir() -> bool:
	# High severity injuries require IR
	if severity >= IR_SEVERITY_THRESHOLD:
		return true

	# Also check recovery timeline if available
	var weeks_total := int(recovery_timeline.get("weeks_total", 0))
	# Injuries requiring 4+ weeks typically warrant IR designation
	if weeks_total >= 4:
		return true

	return false

## Get the week when player becomes eligible to return from IR
## Returns 0 if injury is season-ending or timeline not specified
func get_ir_eligible_week(current_week: int) -> int:
	var weeks_total := int(recovery_timeline.get("weeks_total", 0))
	if weeks_total == 0:
		return 0  # Season-ending or unspecified

	var weeks_elapsed := int(recovery_timeline.get("weeks_elapsed", 0))

	# IR designation requires minimum 4 weeks out
	var ir_min_weeks := 4
	# Calculate from when injury occurred (current_week - weeks_elapsed)
	var week_occurred := current_week - weeks_elapsed
	var eligible_week := week_occurred + max(weeks_total, ir_min_weeks)

	return eligible_week

## Check if injury has healed enough to return from IR
## current_week: the current week number in season
## Returns true if player is eligible to return
func is_ir_eligible(current_week: int) -> bool:
	var eligible_week := int(recovery_timeline.get("ir_eligible_week", 0))
	if eligible_week == 0:
		return false  # Season-ending or not on IR

	return current_week >= eligible_week
