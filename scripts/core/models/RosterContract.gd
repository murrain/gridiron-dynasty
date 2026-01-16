@icon("res://icon.svg")
# res://scripts/core/models/RosterContract.gd
extends Resource
class_name RosterContract

## Roster-level contract information for cap accounting
## Separate from Player.contract which contains full contract details
## This tracks the current year's cap impact

@export var base_salary: float = 0.0              # Base salary for current year
@export var signing_bonus_proration: float = 0.0  # Prorated signing bonus charge
@export var guaranteed: float = 0.0               # Guaranteed money for CURRENT YEAR ONLY (not remaining)
@export var incentives: float = 0.0               # Performance incentives
@export var dead_money: float = 0.0               # Dead money (excluded from active cap)

## Get total cap charge (excluding dead money)
func get_cap_charge() -> float:
	return base_salary + signing_bonus_proration + guaranteed + incentives

## Deserialize from dictionary
func from_dict(d: Dictionary) -> void:
	base_salary = float(d.get("base_salary", base_salary))
	signing_bonus_proration = float(d.get("signing_bonus_proration", signing_bonus_proration))
	guaranteed = float(d.get("guaranteed", guaranteed))
	incentives = float(d.get("incentives", incentives))
	dead_money = float(d.get("dead_money", dead_money))

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"base_salary": base_salary,
		"signing_bonus_proration": signing_bonus_proration,
		"guaranteed": guaranteed,
		"incentives": incentives,
		"dead_money": dead_money
	}
