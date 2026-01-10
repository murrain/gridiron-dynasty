extends RefCounted
class_name CapAccounting

static func cap_used(roster: Array) -> float:
	var total := 0.0
	for entry in roster:
		var row: Dictionary = entry as Dictionary
		total += float(row.get("annual_value", 0.0))
	return total
