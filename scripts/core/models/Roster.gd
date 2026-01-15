extends Resource
class_name Roster

const DepthChart = preload("res://scripts/core/models/DepthChart.gd")

# Roster entries are plain dictionaries to keep persistence explicit and stable.
# Expected shape:
# {
#   "player_id": "player-123",
#   "status": "active", # e.g. active, practice_squad, ir, suspended
#   "cap_exempt": false,
#   "cap_exempt_reason": "", # e.g. IR exception, rookie exception
#   "ir_eligible_week": 0, # Week when player can return from IR (0 = not on IR)
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

## Roster status constants - formalized from string-based status field
enum RosterStatus {
	ACTIVE = 0,           # Active roster - counts against 53-man limit
	PRACTICE_SQUAD = 1,   # Practice squad - separate limit, cap-exempt
	INJURED_RESERVE = 2,  # Injured reserve - cap-exempt, player ineligible
	SUSPENDED = 3         # Suspended - ineligible but may count against cap
}

@export var entries: Array[Dictionary] = []

## Optional depth chart reference - if null, roster management is position-agnostic
## When set, roster operations should maintain depth chart consistency
@export var depth_chart: DepthChart = null

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

	# Load depth chart if present (backward compatibility: may be null in old saves)
	if d.has("depth_chart"):
		if depth_chart == null:
			depth_chart = DepthChart.new()
		depth_chart.from_dict(d.get("depth_chart", {}))
	else:
		depth_chart = null

func to_dict() -> Dictionary:
	var result := {
		"entries": entries.duplicate(true)
	}
	if depth_chart != null:
		result["depth_chart"] = depth_chart.to_dict()
	return result

## Helper: Get all players with a specific roster status
## Returns array of roster entry dictionaries matching the status
func get_players_by_status(status: RosterStatus) -> Array[Dictionary]:
	var status_str := _status_enum_to_string(status)
	var result: Array[Dictionary] = []
	for entry in entries:
		var row: Dictionary = entry as Dictionary
		if String(row.get("status", "active")) == status_str:
			result.append(row)
	return result

## Helper: Get count of players by status
func get_status_count(status: RosterStatus) -> int:
	return get_players_by_status(status).size()

## Move a player to practice squad
## Automatically sets cap_exempt flag and updates depth chart
## Returns true if successful, false if player not found
func move_to_practice_squad(player_id: String) -> bool:
	var entry := _find_entry(player_id)
	if entry.is_empty():
		return false

	entry["status"] = "practice_squad"
	entry["cap_exempt"] = true
	entry["cap_exempt_reason"] = "Practice squad"

	# Remove from depth chart if present
	if depth_chart != null:
		depth_chart.remove_player_from_all_positions(player_id)

	return true

## Promote a player from practice squad to active roster
## Clears cap_exempt flag unless another exemption applies
## Returns true if successful, false if player not found or not on PS
func promote_from_practice_squad(player_id: String) -> bool:
	var entry := _find_entry(player_id)
	if entry.is_empty():
		return false

	if String(entry.get("status", "")) != "practice_squad":
		push_warning("Roster.promote_from_practice_squad: Player %s is not on practice squad" % player_id)
		return false

	entry["status"] = "active"
	# Only clear cap_exempt if it was set for practice squad
	if String(entry.get("cap_exempt_reason", "")) == "Practice squad":
		entry["cap_exempt"] = false
		entry["cap_exempt_reason"] = ""

	return true

## Place a player on injured reserve
## Sets status to IR, marks as cap-exempt, removes from depth chart
## eligible_week: the week number when player becomes eligible to return (0 = season-ending)
## Returns true if successful, false if player not found
func place_on_ir(player_id: String, eligible_week: int = 0) -> bool:
	var entry := _find_entry(player_id)
	if entry.is_empty():
		return false

	entry["status"] = "ir"
	entry["cap_exempt"] = true
	entry["cap_exempt_reason"] = "Injured reserve"
	entry["ir_eligible_week"] = eligible_week

	# Remove from depth chart - injured players cannot start
	if depth_chart != null:
		depth_chart.remove_player_from_all_positions(player_id)

	return true

## Activate a player from injured reserve to active roster
## Clears IR status and cap exemption, resets eligibility week
## Returns true if successful, false if player not found or not on IR
func activate_from_ir(player_id: String) -> bool:
	var entry := _find_entry(player_id)
	if entry.is_empty():
		return false

	if String(entry.get("status", "")) != "ir":
		push_warning("Roster.activate_from_ir: Player %s is not on IR" % player_id)
		return false

	entry["status"] = "active"
	# Clear IR-specific cap exemption
	if String(entry.get("cap_exempt_reason", "")) == "Injured reserve":
		entry["cap_exempt"] = false
		entry["cap_exempt_reason"] = ""
	entry["ir_eligible_week"] = 0

	return true

## Internal: Find a roster entry by player_id
## Returns the entry dictionary or null if not found
func _find_entry(player_id: String) -> Dictionary:
	for entry in entries:
		var row: Dictionary = entry as Dictionary
		if String(row.get("player_id", "")) == player_id:
			return row
	return {}

## Internal: Convert RosterStatus enum to string representation
static func _status_enum_to_string(status: RosterStatus) -> String:
	match status:
		RosterStatus.ACTIVE:
			return "active"
		RosterStatus.PRACTICE_SQUAD:
			return "practice_squad"
		RosterStatus.INJURED_RESERVE:
			return "ir"
		RosterStatus.SUSPENDED:
			return "suspended"
		_:
			return "active"

## Internal: Convert string status to RosterStatus enum
static func _status_string_to_enum(status_str: String) -> RosterStatus:
	match status_str:
		"practice_squad":
			return RosterStatus.PRACTICE_SQUAD
		"ir":
			return RosterStatus.INJURED_RESERVE
		"suspended":
			return RosterStatus.SUSPENDED
		_:
			return RosterStatus.ACTIVE
