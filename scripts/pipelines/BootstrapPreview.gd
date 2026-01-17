## Dry-run scene helper to bootstrap a pro-level player pool and summarize output.
extends Node
class_name BootstrapPreview

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
const DraftDayLauncher = preload("res://scripts/ui/draft_day/DraftDayLauncher.gd")

const DEFAULT_YEARS_BACK: int = 20

## Launch mode determines what UI to show after bootstrap completes
enum LaunchMode {
	WORLD_EXPLORER,  ## Launch World Explorer (original behavior)
	DRAFT_DAY        ## Launch Draft Day with random team (new testing mode)
}

class OutputConfig:
	extends Resource

	@export var auto_scroll: bool = true
	@export var append_newline: bool = true
	@export var clear_on_run: bool = true
	@export var max_lines: int = 0

@export var years_back: int = DEFAULT_YEARS_BACK
@export var output_label_path: NodePath = NodePath("OutputPanel/OutputScroll/OutputText")
@export var output_config: OutputConfig = OutputConfig.new()
@export var launch_mode: LaunchMode = LaunchMode.DRAFT_DAY  ## Default to draft for testing

var output_label: RichTextLabel
var _world_state: Dictionary = {}
var _current_year: int = 0

func _ready() -> void:
	output_label = get_node_or_null(output_label_path) as RichTextLabel
	run()

func run() -> Dictionary:
	if output_label != null and output_config.clear_on_run:
		output_label.clear()

	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = max(1, years_back)
	var result := bootstrap.run()

	_world_state = result.get("world_state", {})
	var summary: Dictionary = result.get("summary", {})
	_current_year = int(result.get("start_year", 0))

	# Add current_year to world_state for downstream consumers
	_world_state["current_year"] = _current_year

	_emit_output("🏈 Bootstrapped game world (%d years)" % bootstrap.years_to_simulate)
	_emit_output("Current year: %d" % _current_year)
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

	# Dispatch based on launch mode
	match launch_mode:
		LaunchMode.WORLD_EXPLORER:
			_emit_output("✓ Bootstrap complete! Launching World Explorer...")
			await get_tree().create_timer(1.0).timeout
			_launch_world_explorer()
		LaunchMode.DRAFT_DAY:
			_emit_output("✓ Bootstrap complete! Launching Draft Day...")
			await get_tree().create_timer(1.0).timeout
			_launch_draft_day()

	return result

func _launch_world_explorer() -> void:
	"""Launch the World Explorer UI with the bootstrapped world state"""
	# Load the World Explorer launcher utility
	var WorldExplorerLauncher = load("res://scripts/ui/world_explorer/WorldExplorerLauncher.gd")

	if WorldExplorerLauncher == null:
		push_error("[BootstrapPreview] Could not load WorldExplorerLauncher")
		_emit_output("[color=#ff0000]Error: Could not load World Explorer[/color]")
		return

	# Create and configure the explorer
	var explorer = WorldExplorerLauncher.launch_with_world_state(_world_state)

	if explorer == null:
		push_error("[BootstrapPreview] Failed to create World Explorer instance")
		_emit_output("[color=#ff0000]Error: Failed to create World Explorer[/color]")
		return

	# Add explorer to the scene tree
	get_tree().root.add_child(explorer)

	# Hide this bootstrap preview window (only in GUI mode, not headless)
	if DisplayServer.get_name() != "headless":
		var parent = get_parent()
		if parent and parent != get_tree().root:
			if parent is Window and parent.get_parent() != null:
				parent.visible = false

	print("[BootstrapPreview] World Explorer launched successfully!")


func _launch_draft_day() -> void:
	"""Launch Draft Day UI with random team assignment"""
	print("[BootstrapPreview] Launching Draft Day with random team assignment...")

	var result := DraftDayLauncher.launch_with_random_team(
		_world_state,
		_current_year,
		get_tree().root
	)

	if result.is_empty():
		push_error("[BootstrapPreview] Failed to launch Draft Day")
		_emit_output("[color=#ff0000]Error: Failed to launch Draft Day[/color]")
		return

	var session: GameSession = result.get("session")
	print("[BootstrapPreview] User assigned to: %s" % session.user_team_name)
	_emit_output("✓ Draft Day launched! You are the GM of: %s" % session.user_team_name)

	# Hide this bootstrap preview window (only in GUI mode, not headless)
	if DisplayServer.get_name() != "headless":
		var parent = get_parent()
		if parent and parent != get_tree().root:
			if parent is Window and parent.get_parent() != null:
				parent.visible = false

	print("[BootstrapPreview] Draft Day launched successfully!")

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
