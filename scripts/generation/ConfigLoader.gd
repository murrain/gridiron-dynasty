extends Node
class_name ConfigLoader

func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ConfigLoader: cannot open " + path)
		return null
	return JSON.parse_string(f.get_as_text())

func load_main() -> Dictionary:
	return load_json("res://configs/sports/american_football/main.json") as Dictionary

func load_stats() -> Dictionary:
	return load_json("res://configs/sports/american_football/stats.json") as Dictionary

func load_positions() -> Dictionary:
	return load_json("res://configs/sports/american_football/positions.json")

func load_school_tiers() -> Dictionary:
	return load_json("res://configs/sports/american_football/school_tiers.json") as Dictionary

func load_names() -> Dictionary:
	return load_json("res://configs/sports/american_football/names.json") as Dictionary
