# class_name Person removed to avoid conflict with scripts/core/models/Person.gd
extends Resource


func name() -> String:
	return "Hoschi"

func last_name() -> String:
	return "Horst"

func age() -> int:
	return 42

func street() -> String:
	return "Route 66"
