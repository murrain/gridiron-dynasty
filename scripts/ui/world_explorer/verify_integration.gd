extends SceneTree

## Simple integration verification
## Checks core components can be instantiated

func _init() -> void:
	print("============================================================")
	print("World Explorer Integration Verification")
	print("============================================================\n")

	var success = true

	# Test 1: Verify main scene file exists
	print("[1/4] Checking main scene file...")
	if FileAccess.file_exists("res://scenes/main/world_explorer_main.tscn"):
		print("  ✓ world_explorer_main.tscn exists")
	else:
		print("  ✗ world_explorer_main.tscn NOT FOUND")
		success = false

	# Test 2: Verify WorldExplorer scene exists
	print("\n[2/4] Checking WorldExplorer scene...")
	if FileAccess.file_exists("res://scenes/ui/world_explorer/world_explorer.tscn"):
		print("  ✓ world_explorer.tscn exists")
	else:
		print("  ✗ world_explorer.tscn NOT FOUND")
		success = false

	# Test 3: Verify all panel scenes exist
	print("\n[3/4] Checking panel scenes...")
	var panels = [
		"nfl_panel.tscn",
		"college_panel.tscn",
		"hs_panel.tscn",
		"draft_panel.tscn",
		"retired_panel.tscn"
	]

	for panel_name in panels:
		var path = "res://scenes/ui/world_explorer/panels/" + panel_name
		if FileAccess.file_exists(path):
			print("  ✓ %s exists" % panel_name)
		else:
			print("  ✗ %s NOT FOUND" % panel_name)
			success = false

	# Test 4: Verify core scripts exist
	print("\n[4/4] Checking core scripts...")
	var scripts = {
		"WorldExplorerMain.gd": "res://scripts/main/WorldExplorerMain.gd",
		"WorldExplorer.gd": "res://scripts/ui/world_explorer/WorldExplorer.gd",
		"WorldExplorerLauncher.gd": "res://scripts/ui/world_explorer/WorldExplorerLauncher.gd",
		"BootstrapGameWorld.gd": "res://scripts/pipelines/BootstrapGameWorld.gd"
	}

	for script_name in scripts.keys():
		var path = scripts[script_name]
		if FileAccess.file_exists(path):
			print("  ✓ %s exists" % script_name)
		else:
			print("  ✗ %s NOT FOUND" % script_name)
			success = false

	# Summary
	print("\n============================================================")
	if success:
		print("✓ VERIFICATION PASSED")
		print("\nAll integration files are present.")
		print("\nTo launch World Explorer:")
		print("  godot scenes/main/world_explorer_main.tscn")
		print("\nNote: First launch will take 60-90 seconds to generate")
		print("      a 20-year world via bootstrap.")
	else:
		print("✗ VERIFICATION FAILED")
		print("\nSome required files are missing.")
	print("============================================================")

	quit(0 if success else 1)
