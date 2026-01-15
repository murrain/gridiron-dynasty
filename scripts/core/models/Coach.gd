@icon("res://icon.svg")
# res://scripts/core/models/Coach.gd
extends "res://scripts/core/models/Person.gd"
class_name Coach

# --- Identity (inherited from Person: id, first_name, last_name, get_full_name()) ---
@export var role: String = ""

# --- Coaching Attributes (0-100 scale) ---
@export var coaching_ability: float = 50.0      # Overall coaching skill
@export var recruiting_skill: float = 50.0      # Recruiting success rate
@export var player_development: float = 50.0   # Player growth/progression rate

# --- Experience & Background ---
@export var experience_years: int = 0           # Total years coaching
@export var specialty_position: String = ""     # e.g., "QB", "Defense", "Offense"
@export var scheme_preference: String = ""      # e.g., "spread", "pro_style", "west_coast" (deprecated)

# --- Scheme System ---
@export var offensive_scheme: String = ""       # For offensive coordinators / head coaches
@export var defensive_scheme: String = ""       # For defensive coordinators / head coaches
@export var scheme_rigidity: float = 1.0        # 0.5 = flexible, 1.0 = normal, 1.2 = rigid

# --- Player Evaluation Philosophy ---
# These influence how the coach/team evaluates players for draft, trades, and free agency
@export var character_tolerance: String = "moderate"  # strict, moderate, lenient, win_now
@export var medical_tolerance: String = "cautious"    # risk_averse, cautious, moderate_risk, aggressive

func from_dict(d: Dictionary) -> void:
	# Load person fields first
	from_dict_person(d)
	role = String(d.get("role", role))

	# Coaching attributes
	coaching_ability = float(d.get("coaching_ability", coaching_ability))
	recruiting_skill = float(d.get("recruiting_skill", recruiting_skill))
	player_development = float(d.get("player_development", player_development))

	# Experience & background
	experience_years = int(d.get("experience_years", experience_years))
	specialty_position = String(d.get("specialty_position", specialty_position))
	scheme_preference = String(d.get("scheme_preference", scheme_preference))

	# Scheme system
	offensive_scheme = String(d.get("offensive_scheme", offensive_scheme))
	defensive_scheme = String(d.get("defensive_scheme", defensive_scheme))
	scheme_rigidity = float(d.get("scheme_rigidity", scheme_rigidity))

	# Player evaluation philosophy
	character_tolerance = String(d.get("character_tolerance", character_tolerance))
	medical_tolerance = String(d.get("medical_tolerance", medical_tolerance))

func to_dict() -> Dictionary:
	# Start with person fields
	var result = to_dict_person()
	# Add coach-specific fields
	result["role"] = role
	result["coaching_ability"] = coaching_ability
	result["recruiting_skill"] = recruiting_skill
	result["player_development"] = player_development
	result["experience_years"] = experience_years
	result["specialty_position"] = specialty_position
	result["scheme_preference"] = scheme_preference
	result["offensive_scheme"] = offensive_scheme
	result["defensive_scheme"] = defensive_scheme
	result["scheme_rigidity"] = scheme_rigidity
	result["character_tolerance"] = character_tolerance
	result["medical_tolerance"] = medical_tolerance
	return result
