extends Resource
class_name SportTeam

@export var id: String = ""
@export var name: String = ""

# --- Cap accounting ---
# cap_used = sum(contract.annual_value for active roster players)
# cap_space = cap_limit - cap_used
@export var cap_limit: float = 0.0
@export var cap_used: float = 0.0
@export var cap_space: float = 0.0
@export var is_over_cap: bool = false

# Roster scaffolding
@export var player_ids: Array[String] = []

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	name = String(d.get("name", name))

	var cap: Dictionary = d.get("cap", {})
	cap_limit = float(cap.get("cap_limit", cap_limit))
	cap_used = float(cap.get("cap_used", cap_used))
	cap_space = float(cap.get("cap_space", cap_space))
	is_over_cap = bool(d.get("is_over_cap", is_over_cap))

	player_ids = (d.get("player_ids", player_ids) as Array).duplicate()

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"cap": {
			"cap_limit": cap_limit,
			"cap_used": cap_used,
			"cap_space": cap_space
		},
		"is_over_cap": is_over_cap,
		"player_ids": player_ids.duplicate()
	}
