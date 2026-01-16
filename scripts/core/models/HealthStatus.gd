@icon("res://icon.svg")
# res://scripts/core/models/HealthStatus.gd
extends Resource
class_name HealthStatus

## Player health and injury tracking
## Extracted from Player.gd to encapsulate health-related data

const Injury = preload("res://scripts/core/models/Injury.gd")

# --- Injury Management ---
var injuries: Array[Injury] = []           # Active injuries
var injury_prone: bool = false             # Player has injury-prone trait
var career_ending_injury: bool = false     # Player has suffered career-ending injury

## Check if player currently has any active injuries
func is_injured() -> bool:
	return injuries.size() > 0

## Add an injury to the player's active injuries
func add_injury(injury: Injury) -> void:
	injuries.append(injury)

## Remove a specific injury by type
## @return: True if injury was found and removed
func remove_injury(injury_type: String) -> bool:
	for i in range(injuries.size() - 1, -1, -1):
		if injuries[i].type == injury_type:
			injuries.remove_at(i)
			return true
	return false

## Clear all active injuries
func clear_all_injuries() -> void:
	injuries.clear()

## Get a specific injury by type
## @return: Injury object if found, null otherwise
func get_injury_by_type(injury_type: String) -> Injury:
	for injury in injuries:
		if injury.type == injury_type:
			return injury
	return null

## Calculate total severity across all active injuries
func get_total_severity() -> float:
	var total = 0.0
	for injury in injuries:
		total += injury.severity
	return total

## Check if any injury requires injured reserve (IR)
func requires_ir() -> bool:
	for injury in injuries:
		if injury.requires_ir():
			return true
	return false

## Deserialize from dictionary
func from_dict(d: Dictionary) -> void:
	# Load injuries
	injuries.clear()
	for injury_data in d.get("injuries", []):
		var injury = Injury.new()
		if injury_data is Dictionary:
			injury.from_dict(injury_data)
		injuries.append(injury)

	# Load injury flags
	injury_prone = bool(d.get("injury_prone", injury_prone))
	career_ending_injury = bool(d.get("career_ending_injury", career_ending_injury))

## Serialize to dictionary
func to_dict() -> Dictionary:
	# Serialize injuries
	var injury_dicts = []
	for injury in injuries:
		injury_dicts.append(injury.to_dict())

	return {
		"injuries": injury_dicts,
		"injury_prone": injury_prone,
		"career_ending_injury": career_ending_injury
	}
