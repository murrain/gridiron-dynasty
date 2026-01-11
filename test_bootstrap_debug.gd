extends SceneTree

## Debug script to run bootstrap_preview and catch errors

func _init():
	print("Starting bootstrap_preview debug...")

	# Load the bootstrap preview scene
	var scene = load("res://bootstrap_preview.tscn")
	if scene == null:
		push_error("Could not load bootstrap_preview.tscn")
		quit(1)
		return

	var instance = scene.instantiate()
	root.add_child(instance)

	# Let it run
	print("Bootstrap preview instantiated, waiting for completion...")
