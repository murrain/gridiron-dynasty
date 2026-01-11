## Dry-run scene helper to bootstrap a pro-level player pool and summarize output.
extends Node
class_name BootstrapPreview

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

const DEFAULT_YEARS_BACK: int = 20

class OutputConfig:
	extends Resource

	@export var auto_scroll: bool = true
	@export var append_newline: bool = true
	@export var clear_on_run: bool = true
	@export var max_lines: int = 0

@export var years_back: int = DEFAULT_YEARS_BACK
@export var output_label_path: NodePath = NodePath("OutputPanel/OutputScroll/OutputText")
@export var output_config: OutputConfig = OutputConfig.new()

var output_label: RichTextLabel

func _ready() -> void:
	output_label = get_node_or_null(output_label_path) as RichTextLabel
	run()

func run() -> Dictionary:
	if output_label != null and output_config.clear_on_run:
		output_label.clear()

	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = max(1, years_back)
	var result := bootstrap.run()

	var world_state: Dictionary = result.get("world_state", {})
	var summary: Dictionary = result.get("summary", {})
	var current_year := int(result.get("start_year", 0))

	_emit_output("🏈 Bootstrapped game world (%d years)" % bootstrap.years_to_simulate)
	_emit_output("Current year: %d" % current_year)
	_emit_output("")
	_emit_output("=== World Population ===")
	_emit_output("HS Schools: %d | HS Players: %d" % [
		int(summary.get("hs_schools", 0)),
		int(summary.get("hs_players", 0))
	])
	_emit_output("Colleges: %d | College Players: %d" % [
		int(summary.get("colleges", 0)),
		int(summary.get("college_players", 0))
	])
	_emit_output("NFL Teams: %d | NFL Players: %d" % [
		int(summary.get("nfl_teams", 0)),
		int(summary.get("nfl_players", 0))
	])
	_emit_output("Retired: %d" % int(summary.get("retired_players", 0)))
	_emit_output("")
	_emit_output("Draft pool years: %d" % int(summary.get("draft_pool_years", 0)))
	_emit_output("")
	_emit_output("✓ Bootstrap complete! Launching World Explorer...")

	# Launch World Explorer UI after a short delay
	await get_tree().create_timer(1.0).timeout
	_launch_world_explorer(world_state)

	return result

func _launch_world_explorer(world_state: Dictionary) -> void:
	"""Launch the World Explorer UI with the bootstrapped world state"""
	# Load the World Explorer launcher utility
	var WorldExplorerLauncher = load("res://scripts/ui/world_explorer/WorldExplorerLauncher.gd")

	if WorldExplorerLauncher == null:
		push_error("Could not load WorldExplorerLauncher")
		_emit_output("[color=#ff0000]Error: Could not load World Explorer[/color]")
		return

	# Create and configure the explorer
	var explorer = WorldExplorerLauncher.launch_with_world_state(world_state)

	if explorer == null:
		push_error("Failed to create World Explorer instance")
		_emit_output("[color=#ff0000]Error: Failed to create World Explorer[/color]")
		return

	# Add explorer to the scene tree
	get_tree().root.add_child(explorer)

	# Hide this bootstrap preview window
	var parent = get_parent()
	if parent:
		parent.visible = false

	print("World Explorer launched successfully!")

func _emit_output(text: String) -> void:
	if output_label == null:
		print(text)
		return
	var line := text
	if output_config.append_newline:
		line += "\n"
	output_label.append_text(line)
	_trim_output_lines()
	if output_config.auto_scroll:
		output_label.scroll_to_line(output_label.get_line_count())

func _trim_output_lines() -> void:
	if output_label == null:
		return
	if output_config.max_lines <= 0:
		return
	var lines := output_label.get_line_count()
	if lines <= output_config.max_lines:
		return
	var excess := lines - output_config.max_lines
	var buffer := output_label.get_parsed_text().split("\n", false)
	if excess >= buffer.size():
		output_label.clear()
		return
	buffer = buffer.slice(excess, buffer.size())
	output_label.clear()
	output_label.append_text("\n".join(buffer) + "\n")
