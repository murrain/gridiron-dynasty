class_name WorldExplorerLauncher
extends RefCounted

## Convenience class for launching World Explorer from code
##
## Provides static methods for:
## 1. Launching with pre-existing world_state
## 2. Launching from bootstrap with custom parameters
##
## Usage Examples:
##
## From existing world_state:
##   var explorer = WorldExplorerLauncher.launch_with_world_state(my_world_state)
##   get_tree().root.add_child(explorer)
##
## From bootstrap:
##   var result = WorldExplorerLauncher.launch_from_bootstrap(20, 12345)
##   if result.has("explorer"):
##     get_tree().root.add_child(result["explorer"])
##     print("Loaded %d NFL teams" % result["summary"].get("nfl_teams", 0))

## Launch with a pre-existing world_state
##
## Parameters:
##   ws: Dictionary - Complete world_state from BootstrapGameWorld
##
## Returns:
##   WorldExplorer - Configured instance ready to add to scene tree
static func launch_with_world_state(ws: Dictionary):
	# Load and instantiate WorldExplorer scene
	var explorer_scene = load("res://scenes/ui/world_explorer/world_explorer.tscn")
	if explorer_scene == null:
		push_error("[WorldExplorerLauncher] Failed to load world_explorer.tscn")
		return null

	var explorer = explorer_scene.instantiate()  # WorldExplorer instance

	# Wire panels (same logic as WorldExplorerMain)
	var tabs = explorer.get_node_or_null("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/VBoxContainer/NavigationTabs")

	if tabs:
		_integrate_panels(tabs)
	else:
		push_warning("[WorldExplorerLauncher] Could not find NavigationTabs - panels not integrated")

	# Load world state
	explorer.load_world_state(ws)

	return explorer

## Launch from bootstrap with custom parameters
##
## Parameters:
##   years: int - Number of years to simulate (default: 20)
##   seed_val: int - Deterministic seed for world generation (default: 0)
##
## Returns:
##   Dictionary with:
##     - explorer: WorldExplorer instance (ready to add to scene tree)
##     - world_state: Dictionary of generated world
##     - summary: Dictionary of entity counts
##
## Returns empty Dictionary on failure
static func launch_from_bootstrap(years: int = 20, seed_val: int = 0) -> Dictionary:
	print("[WorldExplorerLauncher] Starting %d-year bootstrap with seed %d..." % [years, seed_val])

	var bootstrap = BootstrapGameWorld.new()
	bootstrap.years_to_simulate = years

	var start_time := Time.get_ticks_usec()
	var result := bootstrap.run(seed_val)
	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000

	print("[WorldExplorerLauncher] Bootstrap complete in %.2fs" % (elapsed_ms / 1000.0))

	if not result.has("world_state"):
		push_error("[WorldExplorerLauncher] Bootstrap failed to produce world_state")
		return {}

	var summary = result.get("summary", {})
	print("[WorldExplorerLauncher] Generated:")
	for key in summary.keys():
		print("  %s: %s" % [key, summary[key]])

	var explorer = launch_with_world_state(result["world_state"])
	if explorer == null:
		return {}

	return {
		"explorer": explorer,
		"world_state": result["world_state"],
		"summary": summary
	}

## Internal: Integrate all panels into TabContainer
static func _integrate_panels(tabs: TabContainer) -> void:
	var panels = [
		{"path": "res://scenes/ui/world_explorer/panels/nfl_panel.tscn", "name": "NFL"},
		{"path": "res://scenes/ui/world_explorer/panels/college_panel.tscn", "name": "College"},
		{"path": "res://scenes/ui/world_explorer/panels/hs_panel.tscn", "name": "High Schools"},
		{"path": "res://scenes/ui/world_explorer/panels/draft_panel.tscn", "name": "Draft"},
		{"path": "res://scenes/ui/world_explorer/panels/retired_panel.tscn", "name": "Retired"}
	]

	for panel_info in panels:
		var panel_scene = load(panel_info["path"])
		if panel_scene:
			var panel = panel_scene.instantiate()
			tabs.add_child(panel)
			tabs.set_tab_title(tabs.get_tab_count() - 1, panel_info["name"])
		else:
			push_warning("[WorldExplorerLauncher] Could not load panel: %s" % panel_info["path"])
