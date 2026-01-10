@icon("res://icon.svg")
# res://scripts/core/models/Coach.gd
extends Resource
class_name Coach

@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""
@export var role: String = ""

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	first_name = String(d.get("first_name", first_name))
	last_name = String(d.get("last_name", last_name))
	role = String(d.get("role", role))

func to_dict() -> Dictionary:
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"role": role
	}
