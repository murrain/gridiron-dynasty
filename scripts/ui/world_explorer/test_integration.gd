extends SceneTree

## Integration test for World Explorer
## Validates all components can be loaded and initialized

func _init() -> void:
	print("============================================================")
	print("World Explorer Integration Test")
	print("============================================================")

	var errors: Array[String] = []

	# Test 1: Load main scene
	print("\n[Test 1] Loading world_explorer_main.tscn...")
	var main_scene = load("res://scenes/main/world_explorer_main.tscn")
	if main_scene == null:
		errors.append("Failed to load world_explorer_main.tscn")
	else:
		print("  PASS: Main scene loaded")

	# Test 2: Load WorldExplorer scene
	print("\n[Test 2] Loading world_explorer.tscn...")
	var explorer_scene = load("res://scenes/ui/world_explorer/world_explorer.tscn")
	if explorer_scene == null:
		errors.append("Failed to load world_explorer.tscn")
	else:
		print("  PASS: WorldExplorer scene loaded")

	# Test 3: Load all panel scenes
	print("\n[Test 3] Loading panel scenes...")
	var panels = [
		"res://scenes/ui/world_explorer/panels/nfl_panel.tscn",
		"res://scenes/ui/world_explorer/panels/college_panel.tscn",
		"res://scenes/ui/world_explorer/panels/hs_panel.tscn",
		"res://scenes/ui/world_explorer/panels/draft_panel.tscn",
		"res://scenes/ui/world_explorer/panels/retired_panel.tscn"
	]

	for panel_path in panels:
		var panel_scene = load(panel_path)
		if panel_scene == null:
			errors.append("Failed to load %s" % panel_path)
			print("  FAIL: %s" % panel_path)
		else:
			print("  PASS: %s" % panel_path.get_file())

	# Test 4: Load query utilities
	print("\n[Test 4] Loading query utilities...")
	var queries = [
		"res://scripts/ui/world_explorer/queries/PlayerQueries.gd",
		"res://scripts/ui/world_explorer/queries/TeamQueries.gd",
		"res://scripts/ui/world_explorer/queries/StatQueries.gd",
		"res://scripts/ui/world_explorer/queries/DraftQueries.gd"
	]

	for query_path in queries:
		var query_script = load(query_path)
		if query_script == null:
			errors.append("Failed to load %s" % query_path)
			print("  FAIL: %s" % query_path)
		else:
			print("  PASS: %s" % query_path.get_file())

	# Test 5: Load formatters
	print("\n[Test 5] Loading formatters...")
	var formatters = [
		"res://scripts/ui/world_explorer/formatters/PlayerDetailFormatter.gd",
		"res://scripts/ui/world_explorer/formatters/TeamDetailFormatter.gd",
		"res://scripts/ui/world_explorer/formatters/StatsFormatter.gd"
	]

	for formatter_path in formatters:
		var formatter_script = load(formatter_path)
		if formatter_script == null:
			errors.append("Failed to load %s" % formatter_path)
			print("  FAIL: %s" % formatter_path)
		else:
			print("  PASS: %s" % formatter_path.get_file())

	# Test 6: Load bootstrap pipeline
	print("\n[Test 6] Loading bootstrap pipeline...")
	var bootstrap_script = load("res://scripts/pipelines/BootstrapGameWorld.gd")
	if bootstrap_script == null:
		errors.append("Failed to load BootstrapGameWorld.gd")
	else:
		print("  PASS: BootstrapGameWorld.gd loaded")

	# Test 7: Load WorldExplorerLauncher
	print("\n[Test 7] Loading WorldExplorerLauncher...")
	var launcher_script = load("res://scripts/ui/world_explorer/WorldExplorerLauncher.gd")
	if launcher_script == null:
		errors.append("Failed to load WorldExplorerLauncher.gd")
	else:
		print("  PASS: WorldExplorerLauncher.gd loaded")

	# Summary
	print("\n============================================================")
	if errors.is_empty():
		print("ALL TESTS PASSED!")
		print("Integration is complete and ready to use.")
		print("\nTo launch World Explorer:")
		print("  godot scenes/main/world_explorer_main.tscn")
	else:
		print("TESTS FAILED: %d errors" % errors.size())
		for error in errors:
			print("  - %s" % error)
	print("============================================================")

	quit(0 if errors.is_empty() else 1)
