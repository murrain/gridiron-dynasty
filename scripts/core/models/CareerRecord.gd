@icon("res://icon.svg")
# res://scripts/core/models/CareerRecord.gd
extends Resource
class_name CareerRecord

## Player career tracking (awards, wear, development history)
## Extracted from Player.gd to encapsulate career-related data

# --- Award Type Constants ---
const AWARD_MVP = "mvp"
const AWARD_OPOY = "opoy"
const AWARD_DPOY = "dpoy"
const AWARD_ALL_PRO_FIRST = "all_pro_first"
const AWARD_ALL_PRO_SECOND = "all_pro_second"
const AWARD_PRO_BOWL = "pro_bowl"
const AWARD_ROOKIE_OF_YEAR = "rookie_of_year"
const AWARD_CHAMPIONSHIPS = "championships"

# --- Career Achievements ---
@export var awards: Dictionary = {
	"mvp": 0,                # MVP awards
	"opoy": 0,              # Offensive Player of the Year
	"dpoy": 0,              # Defensive Player of the Year
	"all_pro_first": 0,     # First-team All-Pro selections
	"all_pro_second": 0,    # Second-team All-Pro selections
	"pro_bowl": 0,          # Pro Bowl selections
	"rookie_of_year": 0,    # Rookie of the Year (should be 0 or 1)
	"championships": 0      # Championship wins
}

# --- Physical Wear Tracking ---
@export var wear: Dictionary = {
	"snaps": 0,           # Total snaps played
	"collisions": 0,      # Total collisions/contacts
	"injury_count": 0     # Number of injuries sustained
}

# --- Development History ---
@export var development_history: Array = []  # Historical development records by season

## Add an award to the player's career record
## @param count: Number of times to add the award (default 1)
func add_award(award_type: String, count: int = 1) -> void:
	if awards.has(award_type):
		awards[award_type] += count

## Get the count of a specific award type
func get_award_count(award_type: String) -> int:
	return int(awards.get(award_type, 0))

## Get total number of accolades across all award types
func get_total_accolades() -> int:
	var total = 0
	for count in awards.values():
		total += int(count)
	return total

## Add snap wear to the player's career
## @param snaps: Number of snaps to add
## @param collisions: Number of collisions to add (default 0)
func add_snap_wear(snaps: int, collisions: int = 0) -> void:
	wear["snaps"] += snaps
	wear["collisions"] += collisions

## Record an injury occurrence
func record_injury() -> void:
	wear["injury_count"] += 1

## Add a development entry to the player's history
func add_development_entry(entry: Dictionary) -> void:
	development_history.append(entry)

## Deserialize from dictionary
## Supports legacy field names: "career_awards" → "awards", "development_report" → "development_history"
func from_dict(d: Dictionary) -> void:
	# Load awards (support legacy "career_awards" key)
	var awards_data: Dictionary = d.get("awards", d.get("career_awards", {})) as Dictionary
	if not awards_data.is_empty():
		for award_key in awards_data.keys():
			# Ensure non-negative integers
			awards[award_key] = max(0, int(awards_data[award_key]))

	# Load wear
	var wear_data: Dictionary = d.get("wear", {}) as Dictionary
	if not wear_data.is_empty():
		wear["snaps"] = int(wear_data.get("snaps", wear["snaps"]))
		wear["collisions"] = int(wear_data.get("collisions", wear["collisions"]))
		wear["injury_count"] = int(wear_data.get("injury_count", wear["injury_count"]))

	# Load development history (support legacy "development_report" key)
	development_history.clear()
	for entry in d.get("development_history", d.get("development_report", [])):
		development_history.append(entry)

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"awards": awards.duplicate(true),
		"wear": wear.duplicate(true),
		"development_history": development_history.duplicate(true)
	}
