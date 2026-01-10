@icon("res://icon.svg")
# res://scripts/core/models/Roster.gd
extends Resource
class_name Roster

@export var id: String = ""
@export var player_ids: Array[String] = []

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	player_ids = (d.get("player_ids", player_ids) as Array).duplicate()

func to_dict() -> Dictionary:
	return {
		"id": id,
		"player_ids": player_ids.duplicate()
	}
