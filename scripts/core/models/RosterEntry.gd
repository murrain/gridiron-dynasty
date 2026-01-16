@icon("res://icon.svg")
# res://scripts/core/models/RosterEntry.gd
extends Resource
class_name RosterEntry

## Roster entry for a single player
## Tracks roster status, cap impact, and IR eligibility

const RosterContract = preload("res://scripts/core/models/RosterContract.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")

@export var player_id: String = ""
@export var status: Roster.RosterStatus = Roster.RosterStatus.ACTIVE
@export var cap_exempt: bool = false
@export var cap_exempt_reason: String = ""        # e.g., "IR exception", "practice squad"
@export var ir_eligible_week: int = 0             # Week when player can return from IR (0 = not on IR)
@export var roster_contract: RosterContract = null

func _init() -> void:
	roster_contract = RosterContract.new()

## Check if player is on active roster
func is_active() -> bool:
	return status == Roster.RosterStatus.ACTIVE

## Check if player is on injured reserve
func is_on_ir() -> bool:
	return status == Roster.RosterStatus.INJURED_RESERVE

## Check if player counts against cap
func counts_against_cap() -> bool:
	return not cap_exempt

## Get the cap charge for this roster entry
func get_cap_charge() -> float:
	if cap_exempt or roster_contract == null:
		return 0.0
	return roster_contract.get_cap_charge()

## Deserialize from dictionary
## Supports legacy string-based status and nested/flat contract formats
func from_dict(d: Dictionary) -> void:
	player_id = String(d.get("player_id", player_id))

	# Parse status (support both string and enum)
	if d.has("status"):
		var status_value = d["status"]
		if status_value is String:
			status = _parse_status_string(status_value)
		else:
			status = status_value as Roster.RosterStatus

	cap_exempt = bool(d.get("cap_exempt", cap_exempt))
	cap_exempt_reason = String(d.get("cap_exempt_reason", cap_exempt_reason))
	ir_eligible_week = int(d.get("ir_eligible_week", ir_eligible_week))

	# Load contract
	if roster_contract == null:
		roster_contract = RosterContract.new()

	if d.has("roster_contract") and d["roster_contract"] is Dictionary:
		# New nested format
		roster_contract.from_dict(d["roster_contract"])
	elif d.has("contract") and d["contract"] is Dictionary:
		# Legacy format - contract was nested under "contract" key
		roster_contract.from_dict(d["contract"])
	else:
		# No contract data found - log warning for debugging
		if not d.is_empty():  # Only warn if we're loading real data, not default initialization
			push_warning("RosterEntry.from_dict: No contract data found for player %s" % player_id)

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"status": _status_to_string(status),  # Save as string for readability
		"cap_exempt": cap_exempt,
		"cap_exempt_reason": cap_exempt_reason,
		"ir_eligible_week": ir_eligible_week,
		"roster_contract": roster_contract.to_dict() if roster_contract != null else {}
	}

## Parse status string to enum (for backward compatibility)
func _parse_status_string(status_str: String) -> Roster.RosterStatus:
	match status_str.to_lower():
		"active":
			return Roster.RosterStatus.ACTIVE
		"practice_squad", "practice squad":
			return Roster.RosterStatus.PRACTICE_SQUAD
		"ir", "injured_reserve", "injured reserve":
			return Roster.RosterStatus.INJURED_RESERVE
		"suspended":
			return Roster.RosterStatus.SUSPENDED
		_:
			return Roster.RosterStatus.ACTIVE  # Default to active

## Convert status enum to string
func _status_to_string(status_enum: Roster.RosterStatus) -> String:
	match status_enum:
		Roster.RosterStatus.ACTIVE:
			return "active"
		Roster.RosterStatus.PRACTICE_SQUAD:
			return "practice_squad"
		Roster.RosterStatus.INJURED_RESERVE:
			return "ir"
		Roster.RosterStatus.SUSPENDED:
			return "suspended"
		_:
			return "active"
