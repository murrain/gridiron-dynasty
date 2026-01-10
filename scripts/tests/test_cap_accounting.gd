extends RefCounted

const CapAccounting = preload("res://scripts/core/finance/CapAccounting.gd")

func run(t) -> void:
	var roster := [
		{"name": "QB1", "annual_value": 3.25},
		{"name": "RB1", "annual_value": 1.75},
		{"name": "LB1", "annual_value": 2.00}
	]
	var cap_used := CapAccounting.cap_used(roster)
	t.assert_approx(cap_used, 7.0, 0.0001, "cap used sums annual_value")
