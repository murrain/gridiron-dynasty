extends Node
class_name ConfigLoader

func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ConfigLoader: cannot open " + path)
		return null
	return JSON.parse_string(f.get_as_text())

func load_master() -> Dictionary:
	return load_json("res://configs/engine/master_config.json") as Dictionary

func load_stats() -> Dictionary:
	return load_json("res://configs/sports/american_football/stats.json") as Dictionary

func load_pos_requirements() -> Dictionary:
	return load_json("res://configs/sports/american_football/position_requirements.json") as Dictionary

func load_pos_core() -> Dictionary:
	return load_json("res://configs/sports/american_football/position_core_stats.json") as Dictionary

func load_position_dev() -> Dictionary:
	return load_json("res://configs/sports/american_football/position_dev.json") as Dictionary

func load_school_tiers() -> Dictionary:
	return load_json("res://configs/sports/american_football/school_tiers.json") as Dictionary

func load_names() -> Dictionary:
	return load_json("res://configs/sports/american_football/names.json") as Dictionary
