@icon("res://icon.svg")
# res://scripts/core/models/PlayerPhysicals.gd
extends Resource
class_name PlayerPhysicals

## Physical measurements for a player
## Extracted from Player.gd to reduce complexity and improve cohesion
## All measurements use native units (inches, pounds)

@export var height_in: float = 72.0       # Height in inches (default: 6'0")
@export var weight_lb: float = 200.0      # Weight in pounds
@export var hand_size_in: float = 9.5     # Hand size in inches
@export var arm_length_in: float = 32.0   # Arm length in inches
@export var wingspan_in: float = 78.0     # Wingspan in inches

## Format height as feet and inches (e.g., "6'2"")
func get_height_feet_inches() -> String:
	var feet = int(height_in / 12)
	var inches = int(height_in) % 12
	return "%d'%d\"" % [feet, inches]

## Calculate Body Mass Index
## BMI = (weight in pounds * 703) / (height in inches)^2
func get_bmi() -> float:
	if height_in <= 0:
		return 0.0
	return (weight_lb * 703.0) / (height_in * height_in)

## Deserialize from dictionary
func from_dict(d: Dictionary) -> void:
	height_in = float(d.get("height_in", height_in))
	weight_lb = float(d.get("weight_lb", weight_lb))
	hand_size_in = float(d.get("hand_size_in", hand_size_in))
	arm_length_in = float(d.get("arm_length_in", arm_length_in))
	wingspan_in = float(d.get("wingspan_in", wingspan_in))

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"height_in": height_in,
		"weight_lb": weight_lb,
		"hand_size_in": hand_size_in,
		"arm_length_in": arm_length_in,
		"wingspan_in": wingspan_in
	}
