@icon("res://icon.svg")
# res://scripts/core/models/TraitSet.gd
extends Resource
class_name TraitSet

## Player traits (visible and hidden)
## Extracted from Player.gd to encapsulate trait-related logic
## Traits affect player ratings and behavior

@export var visible: Array[String] = []   # Publicly known traits (e.g., "Ball Hawk", "Leader")
@export var hidden: Array[String] = []    # Hidden traits (e.g., "Freak:speed", "InjuryFlag:Hamstring")

## Check if player has a specific trait (visible or hidden)
func has_trait(trait_name: String) -> bool:
	return visible.has(trait_name) or hidden.has(trait_name)

## Check if player has a specific visible trait
func has_visible_trait(trait_name: String) -> bool:
	return visible.has(trait_name)

## Check if player has a specific hidden trait
func has_hidden_trait(trait_name: String) -> bool:
	return hidden.has(trait_name)

## Add a trait (visible or hidden)
## @param is_hidden: If true, adds to hidden traits; otherwise adds to visible
func add_trait(trait_name: String, is_hidden: bool = false) -> void:
	if is_hidden:
		if not hidden.has(trait_name):
			hidden.append(trait_name)
	else:
		if not visible.has(trait_name):
			visible.append(trait_name)

## Remove a trait from both visible and hidden arrays
func remove_trait(trait_name: String) -> void:
	visible.erase(trait_name)
	hidden.erase(trait_name)

## Reveal a hidden trait (move from hidden to visible)
## @return: True if trait was successfully revealed, false if not found
func reveal_trait(trait_name: String) -> bool:
	if hidden.has(trait_name):
		hidden.erase(trait_name)
		if not visible.has(trait_name):
			visible.append(trait_name)
		return true
	return false

## Get all traits (both visible and hidden combined)
func get_all_traits() -> Array[String]:
	var all: Array[String] = []
	all.append_array(visible)
	all.append_array(hidden)
	return all

## Deserialize from dictionary
## Supports legacy field names: "traits" → "visible", "hidden_traits" → "hidden"
func from_dict(d: Dictionary) -> void:
	visible.clear()
	hidden.clear()

	# Load visible traits (support legacy "traits" key)
	for t in d.get("visible", d.get("traits", [])):
		visible.append(String(t))

	# Load hidden traits (support legacy "hidden_traits" key)
	for t in d.get("hidden", d.get("hidden_traits", [])):
		hidden.append(String(t))

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"visible": visible.duplicate(),
		"hidden": hidden.duplicate()
	}
