extends RefCounted
class_name CapAccounting

static func cap_used(roster: Array) -> float:
	var total := 0.0
	for entry in roster:
		var row: Dictionary = entry as Dictionary
		if bool(row.get("cap_exempt", false)):
			continue
		var contract: Dictionary = row.get("contract", {})
		total += (
			float(contract.get("base_salary", 0.0))
			+ float(contract.get("signing_bonus_proration", 0.0))
			+ float(contract.get("guaranteed", 0.0))
			+ float(contract.get("incentives", 0.0))
		)
	return total
