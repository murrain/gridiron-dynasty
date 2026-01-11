extends Node
class_name WorldExplorerMain

## Main entry point for World Explorer UI
## Handles bootstrap → WorldExplorer workflow
##
## Architecture:
## 1. Shows loading screen
## 2. Runs BootstrapGameWorld to generate world
## 3. Dynamically integrates all panels into WorldExplorer
## 4. Loads world_state and shows explorer
##
## Usage in scene tree:
##   Node (WorldExplorerMain)
##   ├── MarginContainer/VBoxContainer
##   │   ├── LoadingPanel (PanelContainer) - shown during bootstrap
##   │   └── Explorer (WorldExplorer) - shown after bootstrap
##   └── Bootstrap (BootstrapGameWorld) - not in visual tree

@export var bootstrap_years: int = 20
@export var base_seed: int = 0

@onready var loading_panel: PanelContainer = $MarginContainer/VBoxContainer/LoadingPanel
@onready var loading_label: Label = $MarginContainer/VBoxContainer/LoadingPanel/MarginContainer/VBoxContainer/LoadingLabel
@onready var loading_progress: ProgressBar = $MarginContainer/VBoxContainer/LoadingPanel/MarginContainer/VBoxContainer/LoadingProgress
@onready var explorer = $MarginContainer/VBoxContainer/Explorer  # WorldExplorer
@onready var bootstrap = $Bootstrap  # BootstrapGameWorld

var world_state: Dictionary = {}

func _ready() -> void:
	# Show loading screen
	loading_panel.visible = true
	explorer.visible = false
	loading_progress.value = 0

	# Defer bootstrap to next frame to allow UI to initialize
	call_deferred("_run_bootstrap")

func _run_bootstrap() -> void:
	print("[WorldExplorerMain] Starting %d-year bootstrap with seed %d..." % [bootstrap_years, base_seed])
	loading_label.text = "Generating %d-year world..." % bootstrap_years

	# Configure bootstrap
	bootstrap.years_to_simulate = bootstrap_years

	# Run bootstrap (this may take 30-90 seconds for 20 years)
	var start_time := Time.get_ticks_usec()
	var result: Dictionary = bootstrap.run(base_seed)
	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000

	if result.is_empty() or not result.has("world_state"):
		push_error("[WorldExplorerMain] Bootstrap failed to produce world_state")
		_show_error("Bootstrap failed - check console for details")
		return

	world_state = result["world_state"]

	print("[WorldExplorerMain] Bootstrap complete in %.2fs" % (elapsed_ms / 1000.0))
	print("[WorldExplorerMain] Generated:")
	var summary = result.get("summary", {})
	for key in summary.keys():
		print("  %s: %s" % [key, summary[key]])

	# Update loading screen
	loading_label.text = "Integrating panels..."
	loading_progress.value = 50

	# Wire panels into WorldExplorer
	_integrate_panels()

	# Update loading screen
	loading_label.text = "Loading world state..."
	loading_progress.value = 75

	# Load world state into explorer
	explorer.load_world_state(world_state)

	# Show explorer
	loading_progress.value = 100
	loading_panel.visible = false
	explorer.visible = true

	print("[WorldExplorerMain] World Explorer ready!")

func _integrate_panels() -> void:
	# Get NavigationTabs from WorldExplorer
	# Path: MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/SidebarBox/NavigationTabs
	var tabs = explorer.get_node_or_null("MarginContainer/VBoxContainer/MainContent/SidebarPanel/MarginContainer/SidebarBox/NavigationTabs")

	if tabs == null:
		push_error("[WorldExplorerMain] Could not find NavigationTabs in WorldExplorer")
		_show_error("Failed to find NavigationTabs")
		return

	# Clear any existing children (in case of re-initialization)
	for child in tabs.get_children():
		child.queue_free()

	# Add all panels in order
	var panel_count := 0
	panel_count += _add_panel(tabs, "res://scenes/ui/world_explorer/panels/nfl_panel.tscn", "NFL")
	panel_count += _add_panel(tabs, "res://scenes/ui/world_explorer/panels/college_panel.tscn", "College")
	panel_count += _add_panel(tabs, "res://scenes/ui/world_explorer/panels/hs_panel.tscn", "High Schools")
	panel_count += _add_panel(tabs, "res://scenes/ui/world_explorer/panels/draft_panel.tscn", "Draft")
	panel_count += _add_panel(tabs, "res://scenes/ui/world_explorer/panels/retired_panel.tscn", "Retired")

	print("[WorldExplorerMain] Integrated %d panels into WorldExplorer" % panel_count)

func _add_panel(tabs: TabContainer, scene_path: String, tab_name: String) -> int:
	var panel_scene = load(scene_path)
	if panel_scene == null:
		push_warning("[WorldExplorerMain] Could not load panel scene: %s" % scene_path)
		return 0

	var panel = panel_scene.instantiate()
	tabs.add_child(panel)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tab_name)

	return 1

func _show_error(message: String) -> void:
	loading_label.text = "ERROR: %s" % message
	loading_label.add_theme_color_override("font_color", Color.RED)
	loading_progress.visible = false
