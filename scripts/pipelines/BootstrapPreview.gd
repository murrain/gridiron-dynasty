## Dry-run scene helper to bootstrap a pro-level player pool and summarize output.
extends Node
class_name BootstrapPreview

const BootstrapWorld = preload("res://scripts/pipelines/BootstrapWorld.gd")

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

	var bootstrap := BootstrapWorld.new()
	bootstrap.years_back = max(1, years_back)
	var result := bootstrap.run()

	var active_players: Array = result.get("active_players", []) as Array
	var retired_players: Array = result.get("retired_players", []) as Array
	var classes: Array = result.get("classes", []) as Array
	var current_year := int(result.get("current_year", 0))

	_emit_output("🏈 Bootstrapped pro pool through %d seasons." % bootstrap.years_back)
	_emit_output("Current year: %d" % current_year)
	_emit_output("Active players: %d" % active_players.size())
	_emit_output("Retired players: %d" % retired_players.size())
	_emit_output("Classes generated: %d" % classes.size())

	var range := _class_year_range(classes)
	if range.size() == 2:
		_emit_output("Class years: %d → %d" % [int(range[0]), int(range[1])])

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

func _class_year_range(classes: Array) -> Array:
	if classes.is_empty():
		return []
	var min_year := INF
	var max_year := -INF
	for entry in classes:
		var row: Dictionary = entry
		var year := int(row.get("year", 0))
		min_year = min(min_year, year)
		max_year = max(max_year, year)
	if min_year == INF or max_year == -INF:
		return []
	return [min_year, max_year]
