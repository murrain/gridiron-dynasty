extends Resource
class_name SportRoster

# Roster entries are plain dictionaries to keep persistence explicit and stable.
# Expected shape:
# {
#   "player_id": "player-123",
#   "status": "active", # e.g. active, practice_squad, ir
#   "cap_exempt": false,
#   "cap_exempt_reason": "", # e.g. IR exception, rookie exception
#   "contract": {
#       "base_salary": 0.0,
#       "signing_bonus_proration": 0.0,
#       "guaranteed": 0.0,
#       "incentives": 0.0,
#       "dead_money": 0.0 # stored explicitly but excluded from active cap hits
#   }
# }
#
# Cap-relevant fields are: base_salary, signing_bonus_proration, guaranteed,
# incentives. These sum to the rostered player's current cap charge.
#
# Cap exemptions are not applied unless explicitly marked on the roster entry.
# Examples of cap-exempt scenarios that must be modeled via flags/reasons:
# - Dead money after release/retirement (tracked separately from active roster)
# - IR/disabled list exceptions
# - Practice squad exclusions
# - Offseason roster allowances

@export var entries: Array[Dictionary] = []

static func contract_cap_charge(contract: Dictionary) -> float:
	return (
		float(contract.get("base_salary", 0.0))
		+ float(contract.get("signing_bonus_proration", 0.0))
		+ float(contract.get("guaranteed", 0.0))
		+ float(contract.get("incentives", 0.0))
	)

func get_cap_used() -> float:
	var total := 0.0
	for entry in entries:
		var row: Dictionary = entry as Dictionary
		if bool(row.get("cap_exempt", false)):
			continue
		var contract: Dictionary = row.get("contract", {})
		total += contract_cap_charge(contract)
	return total

func from_dict(d: Dictionary) -> void:
	entries = (d.get("entries", entries) as Array).duplicate(true)

func to_dict() -> Dictionary:
	return {
		"entries": entries.duplicate(true)
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
