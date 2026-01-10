extends Resource
class_name Injury

@export var type: String = ""
@export var severity: float = 0.0
@export var affected_stats: Array[String] = []
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
