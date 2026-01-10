@icon("res://icon.svg")
# res://scripts/core/trades/Pick.gd
extends Resource
class_name Pick

## Represents a draft pick with explicit ownership and slot metadata.
@export var year: int = 0
@export var round: int = 0
@export var slot: int = 0
@export var original_team_id: String = ""
@export var current_owner_id: String = ""

func to_dict() -> Dictionary:
	return {
		"year": year,
		"round": round,
		"slot": slot,
		"original_team_id": original_team_id,
		"current_owner_id": current_owner_id
	}

static func from_dict(data: Dictionary) -> Pick:
	var pick := Pick.new()
	pick.year = int(data.get("year", 0))
	pick.round = int(data.get("round", 0))
	pick.slot = int(data.get("slot", 0))
	pick.original_team_id = str(data.get("original_team_id", ""))
	pick.current_owner_id = str(data.get("current_owner_id", ""))
	return pick
