## Dry-run scene helper to bootstrap a full game world and summarize output.
extends Node
class_name BootstrapPreview

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

const DEFAULT_YEARS_TO_SIMULATE: int = 20

class OutputConfig:
	extends Resource

	@export var auto_scroll: bool = true
	@export var append_newline: bool = true
	@export var clear_on_run: bool = true
	@export var max_lines: int = 0

@export var years_to_simulate: int = DEFAULT_YEARS_TO_SIMULATE
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
	bootstrap.years_to_simulate = max(1, years_to_simulate)
	var result := bootstrap.run()

	var summary: Dictionary = result.get("summary", {}) as Dictionary
	var start_year := int(result.get("start_year", 0))
	var first_year := int(result.get("first_year", 0))
	var years_simulated := int(result.get("years_simulated", 0))

	_emit_output("Bootstrapped game world (%d years)" % years_simulated)
	_emit_output("Simulated years: %d -> %d" % [first_year, start_year])
	_emit_output("")
	_emit_output("HS Schools: %d | HS Players: %d" % [
		int(summary.get("hs_schools", 0)),
		int(summary.get("hs_players", 0))
	])
	_emit_output("Colleges: %d | College Players: %d" % [
		int(summary.get("colleges", 0)),
		int(summary.get("college_rosters", 0))
	])
	_emit_output("NFL Teams: %d | NFL Players: %d" % [
		int(summary.get("nfl_teams", 0)),
		int(summary.get("nfl_players", 0))
	])
	_emit_output("Retired: %d" % int(summary.get("retired_players", 0)))

	return result

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
