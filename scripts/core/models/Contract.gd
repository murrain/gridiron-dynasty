@icon("res://icon.svg")
# res://scripts/core/models/Contract.gd
extends Resource
class_name Contract

## Player contract representation with typed fields
## Replaces Dictionary-based contract storage for type safety and validation

@export var current_year: int = 0
@export var total_years: int = 0
@export var annual_value: float = 0.0
@export var guaranteed: float = 0.0
@export var range_min: float = 0.0
@export var range_max: float = 0.0
@export var valuation_source: String = ""
@export var valuation_seed: int = 0
@export var source_eval_id: String = ""

## Check if contract is currently active
## Returns true if player is under contract (current_year within total_years)
func is_active() -> bool:
	return current_year > 0 and current_year <= total_years

## Check if contract has expired
## Returns true if player completed all contract years
func is_expired() -> bool:
	return total_years > 0 and current_year > total_years

## Get remaining years on contract
## Returns number of years left (0 if expired or no contract)
func years_remaining() -> int:
	return max(0, total_years - current_year)

## Advance contract by one year
## Only advances if contract is currently active
func advance_year() -> void:
	if is_active():
		current_year += 1

## Load contract data from dictionary
func from_dict(d: Dictionary) -> void:
	current_year = int(d.get("current_year", 0))
	total_years = int(d.get("total_years", 0))
	annual_value = float(d.get("annual_value", 0.0))
	guaranteed = float(d.get("guaranteed", 0.0))
	range_min = float(d.get("range_min", 0.0))
	range_max = float(d.get("range_max", 0.0))
	valuation_source = String(d.get("valuation_source", ""))
	valuation_seed = int(d.get("valuation_seed", 0))
	source_eval_id = String(d.get("source_eval_id", ""))

## Serialize contract to dictionary
func to_dict() -> Dictionary:
	return {
		"current_year": current_year,
		"total_years": total_years,
		"annual_value": annual_value,
		"guaranteed": guaranteed,
		"range_min": range_min,
		"range_max": range_max,
		"valuation_source": valuation_source,
		"valuation_seed": valuation_seed,
		"source_eval_id": source_eval_id
	}
