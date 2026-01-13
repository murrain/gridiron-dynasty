extends SceneTree
## Test runner for ContractNegotiation unit tests

func _initialize() -> void:
	# Load and run tests
	var test_scene := load("res://scripts/tests/test_contract_negotiation.gd")
	var test_instance := test_scene.new()
	root.add_child(test_instance)
