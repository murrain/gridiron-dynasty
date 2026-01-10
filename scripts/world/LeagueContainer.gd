@icon("res://icon.svg")
# res://scripts/world/LeagueContainer.gd
extends Resource
class_name LeagueContainer

@export var id: String = ""
@export var name: String = ""

# Scaffold containers for phase 4; kept explicit to enable deterministic loads.
@export var team_ids: Array[String] = []
@export var roster_ids: Array[String] = []
@export var coach_ids: Array[String] = []

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	name = String(d.get("name", name))
	team_ids = (d.get("team_ids", team_ids) as Array).duplicate()
	roster_ids = (d.get("roster_ids", roster_ids) as Array).duplicate()
	coach_ids = (d.get("coach_ids", coach_ids) as Array).duplicate()

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"team_ids": team_ids.duplicate(),
		"roster_ids": roster_ids.duplicate(),
		"coach_ids": coach_ids.duplicate()
	}
