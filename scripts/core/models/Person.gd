@icon("res://icon.svg")
# res://scripts/core/models/Person.gd
extends Resource
class_name Person

## Base class for all person entities (Player, Coach, Scout)
## Provides shared identity fields and serialization logic

# --- Identity ---
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""

## Get the person's full name (first + last)
## Returns a formatted string with extra whitespace stripped
func get_full_name() -> String:
	return ("%s %s" % [first_name, last_name]).strip_edges()

## Load identity fields from dictionary
## Subclasses should call this from their from_dict() implementations
func from_dict_person(d: Dictionary) -> void:
	id = String(d.get("id", id))
	first_name = String(d.get("first_name", first_name))
	last_name = String(d.get("last_name", last_name))

## Serialize identity fields to dictionary
## Subclasses should call this from their to_dict() implementations
func to_dict_person() -> Dictionary:
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name
	}
