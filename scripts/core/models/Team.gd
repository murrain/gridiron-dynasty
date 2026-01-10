@icon("res://icon.svg")
# res://scripts/core/models/Team.gd
extends Resource
class_name Team

@export var id: String = ""
@export var name: String = ""

# Salary cap scaffold (Phase 4)
@export var cap_limit: float = 0.0
@export var cap_used: float = 0.0

# References to related scaffolds
@export var roster_id: String = ""
@export var coach_id: String = ""

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	name = String(d.get("name", name))
	cap_limit = float(d.get("cap_limit", cap_limit))
	cap_used = float(d.get("cap_used", cap_used))
	roster_id = String(d.get("roster_id", roster_id))
	coach_id = String(d.get("coach_id", coach_id))

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"cap_limit": cap_limit,
		"cap_used": cap_used,
		"roster_id": roster_id,
		"coach_id": coach_id
	}
