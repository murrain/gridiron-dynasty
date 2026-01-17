## DraftAnalysisScreen - Post-draft analysis and report display
##
## Shows comprehensive draft analysis after draft completes including:
## - Team draft grades
## - Steals and reaches
## - Best and worst picks
## - User's draft summary
## - League-wide draft statistics
##
## Integration:
## - Receives draft report from InteractiveDraft.generate_draft_report()
## - Displays grades using DraftGrader color coding
## - Allows export of draft report card
##
extends Control
class_name DraftAnalysisScreen

const DraftGrader = preload("res://scripts/world/DraftGrader.gd")

signal view_world_requested()
signal report_exported(filepath: String)

## Draft report data
var _report: Dictionary = {}
var _user_team_id: String = ""
var _year: int = 0

## UI References (created dynamically)
var _main_container: VBoxContainer
var _header_label: Label
var _team_grades_list: VBoxContainer
var _steals_list: VBoxContainer
var _reaches_list: VBoxContainer
var _user_summary_panel: PanelContainer


func _ready() -> void:
	_setup_ui()


## Setup the analysis screen UI
func _setup_ui() -> void:
	# Create main layout
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)

	_main_container = VBoxContainer.new()
	_main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_main_container)

	# Header
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 24)
	_main_container.add_child(_header_label)

	var sep := HSeparator.new()
	_main_container.add_child(sep)

	# User summary panel
	_user_summary_panel = PanelContainer.new()
	_main_container.add_child(_user_summary_panel)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	_main_container.add_child(spacer1)

	# Team grades section
	var grades_header := Label.new()
	grades_header.text = "Team Draft Grades"
	grades_header.add_theme_font_size_override("font_size", 18)
	_main_container.add_child(grades_header)

	_team_grades_list = VBoxContainer.new()
	_main_container.add_child(_team_grades_list)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	_main_container.add_child(spacer2)

	# Steals section
	var steals_header := Label.new()
	steals_header.text = "Draft Steals"
	steals_header.add_theme_font_size_override("font_size", 18)
	_main_container.add_child(steals_header)

	_steals_list = VBoxContainer.new()
	_main_container.add_child(_steals_list)

	# Spacer
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	_main_container.add_child(spacer3)

	# Reaches section
	var reaches_header := Label.new()
	reaches_header.text = "Draft Reaches"
	reaches_header.add_theme_font_size_override("font_size", 18)
	_main_container.add_child(reaches_header)

	_reaches_list = VBoxContainer.new()
	_main_container.add_child(_reaches_list)

	# Action buttons
	var spacer4 := Control.new()
	spacer4.custom_minimum_size = Vector2(0, 30)
	_main_container.add_child(spacer4)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_container.add_child(button_row)

	var continue_btn := Button.new()
	continue_btn.text = "Continue to Season"
	continue_btn.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_btn)

	var spacer_btn := Control.new()
	spacer_btn.custom_minimum_size = Vector2(20, 0)
	button_row.add_child(spacer_btn)

	var export_btn := Button.new()
	export_btn.text = "Export Report"
	export_btn.pressed.connect(_on_export_pressed)
	button_row.add_child(export_btn)


## Display draft analysis report
func display_report(report: Dictionary, user_team_id: String) -> void:
	_report = report
	_user_team_id = user_team_id
	_year = int(report.get("year", 0))

	_header_label.text = "%d NFL Draft Analysis" % _year

	_populate_user_summary()
	_populate_team_grades()
	_populate_steals()
	_populate_reaches()


## Populate user's draft summary
func _populate_user_summary() -> void:
	# Clear existing content
	for child in _user_summary_panel.get_children():
		child.queue_free()

	# Find user's team grade
	var team_grades: Array = _report.get("team_grades", [])
	var user_grade: Dictionary = {}
	var user_rank := 0

	for i in range(team_grades.size()):
		var tg: Dictionary = team_grades[i]
		if String(tg.get("team_id", "")) == _user_team_id:
			user_grade = tg
			user_rank = i + 1
			break

	# Create summary container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	_user_summary_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Your Draft Summary"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	if user_grade.is_empty():
		var no_data := Label.new()
		no_data.text = "No draft data available"
		vbox.add_child(no_data)
		return

	# Grade display
	var grade_row := HBoxContainer.new()
	vbox.add_child(grade_row)

	var grade_label := Label.new()
	grade_label.text = "Overall Grade: "
	grade_row.add_child(grade_label)

	var grade_value := Label.new()
	var letter := String(user_grade.get("overall_grade", "C"))
	grade_value.text = letter
	grade_value.add_theme_color_override("font_color", DraftGrader.get_grade_color(letter))
	grade_value.add_theme_font_size_override("font_size", 20)
	grade_row.add_child(grade_value)

	# Rank among teams
	var rank_label := Label.new()
	rank_label.text = "  (Ranked #%d of %d teams)" % [user_rank, team_grades.size()]
	grade_row.add_child(rank_label)

	# Pick count
	var pick_count := Label.new()
	pick_count.text = "Total Picks: %d" % int(user_grade.get("pick_count", 0))
	vbox.add_child(pick_count)

	# Score breakdown
	var scores := Label.new()
	scores.text = "Average Scores - Value: %.1f | Need: %.1f | Fit: %.1f" % [
		float(user_grade.get("avg_value", 0.0)),
		float(user_grade.get("avg_need", 0.0)),
		float(user_grade.get("avg_fit", 0.0))
	]
	vbox.add_child(scores)

	# Best pick
	var best_pick: Dictionary = user_grade.get("best_pick", {})
	if not best_pick.is_empty():
		var best_grade: Dictionary = best_pick.get("grade", {})
		var best_label := Label.new()
		best_label.text = "Best Pick: #%d %s %s (%s)" % [
			best_pick.get("pick", 0),
			best_pick.get("position", ""),
			best_pick.get("player_name", ""),
			best_grade.get("letter_grade", "?")
		]
		vbox.add_child(best_label)

	# Worst pick
	var worst_pick: Dictionary = user_grade.get("worst_pick", {})
	if not worst_pick.is_empty():
		var worst_grade: Dictionary = worst_pick.get("grade", {})
		var worst_label := Label.new()
		worst_label.text = "Worst Pick: #%d %s %s (%s)" % [
			worst_pick.get("pick", 0),
			worst_pick.get("position", ""),
			worst_pick.get("player_name", ""),
			worst_grade.get("letter_grade", "?")
		]
		vbox.add_child(worst_label)


## Populate team grades list
func _populate_team_grades() -> void:
	# Clear existing
	for child in _team_grades_list.get_children():
		child.queue_free()

	var team_grades: Array = _report.get("team_grades", [])

	for i in range(team_grades.size()):
		var tg: Dictionary = team_grades[i]
		var team_id := String(tg.get("team_id", ""))
		var letter := String(tg.get("overall_grade", "C"))
		var score := float(tg.get("overall_score", 70.0))
		var pick_count := int(tg.get("pick_count", 0))

		var row := HBoxContainer.new()
		_team_grades_list.add_child(row)

		# Rank
		var rank_label := Label.new()
		rank_label.text = "%d. " % (i + 1)
		rank_label.custom_minimum_size = Vector2(30, 0)
		row.add_child(rank_label)

		# Team name
		var team_label := Label.new()
		var is_user := team_id == _user_team_id
		team_label.text = team_id + (" *" if is_user else "")
		team_label.custom_minimum_size = Vector2(150, 0)
		if is_user:
			team_label.add_theme_color_override("font_color", Color.GOLD)
		row.add_child(team_label)

		# Grade
		var grade_label := Label.new()
		grade_label.text = letter
		grade_label.custom_minimum_size = Vector2(40, 0)
		grade_label.add_theme_color_override("font_color", DraftGrader.get_grade_color(letter))
		row.add_child(grade_label)

		# Score
		var score_label := Label.new()
		score_label.text = "(%.1f)" % score
		score_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(score_label)

		# Pick count
		var picks_label := Label.new()
		picks_label.text = "%d picks" % pick_count
		row.add_child(picks_label)


## Populate steals list
func _populate_steals() -> void:
	# Clear existing
	for child in _steals_list.get_children():
		child.queue_free()

	var steals: Array = _report.get("steals", [])

	if steals.is_empty():
		var no_steals := Label.new()
		no_steals.text = "No significant steals identified"
		no_steals.add_theme_color_override("font_color", Color.GRAY)
		_steals_list.add_child(no_steals)
		return

	# Show top 10 steals
	for i in range(min(10, steals.size())):
		var steal: Dictionary = steals[i]
		var is_user := String(steal.get("team_id", "")) == _user_team_id

		var row := HBoxContainer.new()
		_steals_list.add_child(row)

		var label := Label.new()
		label.text = "#%d %s %s to %s - fell %d spots (consensus #%d)" % [
			steal.get("pick_number", 0),
			steal.get("position", ""),
			steal.get("player_name", ""),
			steal.get("team_id", ""),
			steal.get("value_diff", 0),
			steal.get("consensus_rank", 0)
		]
		if is_user:
			label.add_theme_color_override("font_color", Color.GOLD)
		else:
			label.add_theme_color_override("font_color", Color.GREEN)
		row.add_child(label)


## Populate reaches list
func _populate_reaches() -> void:
	# Clear existing
	for child in _reaches_list.get_children():
		child.queue_free()

	var reaches: Array = _report.get("reaches", [])

	if reaches.is_empty():
		var no_reaches := Label.new()
		no_reaches.text = "No significant reaches identified"
		no_reaches.add_theme_color_override("font_color", Color.GRAY)
		_reaches_list.add_child(no_reaches)
		return

	# Show top 10 reaches
	for i in range(min(10, reaches.size())):
		var reach: Dictionary = reaches[i]
		var is_user := String(reach.get("team_id", "")) == _user_team_id

		var row := HBoxContainer.new()
		_reaches_list.add_child(row)

		var label := Label.new()
		label.text = "#%d %s %s by %s - reached %d spots (consensus #%d)" % [
			reach.get("pick_number", 0),
			reach.get("position", ""),
			reach.get("player_name", ""),
			reach.get("team_id", ""),
			abs(int(reach.get("value_diff", 0))),
			reach.get("consensus_rank", 0)
		]
		if is_user:
			label.add_theme_color_override("font_color", Color.GOLD)
		else:
			label.add_theme_color_override("font_color", Color.ORANGE_RED)
		row.add_child(label)


## Handle continue button
func _on_continue_pressed() -> void:
	view_world_requested.emit()


## Handle export button
func _on_export_pressed() -> void:
	var filepath := "user://draft_report_%d.txt" % _year
	var result := _export_report_to_file(filepath)
	if result == OK:
		report_exported.emit(filepath)


## Export report to text file
func _export_report_to_file(filepath: String) -> Error:
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_line("=" * 60)
	file.store_line("%d NFL DRAFT REPORT CARD" % _year)
	file.store_line("=" * 60)
	file.store_line("")

	# Team grades
	file.store_line("TEAM DRAFT GRADES")
	file.store_line("-" * 40)
	var team_grades: Array = _report.get("team_grades", [])
	for i in range(team_grades.size()):
		var tg: Dictionary = team_grades[i]
		var marker := " *" if String(tg.get("team_id", "")) == _user_team_id else ""
		file.store_line("%d. %s - %s (%.1f)%s" % [
			i + 1,
			tg.get("team_id", ""),
			tg.get("overall_grade", "C"),
			float(tg.get("overall_score", 70.0)),
			marker
		])
	file.store_line("")

	# Steals
	file.store_line("DRAFT STEALS")
	file.store_line("-" * 40)
	var steals: Array = _report.get("steals", [])
	if steals.is_empty():
		file.store_line("None identified")
	else:
		for i in range(min(15, steals.size())):
			var s: Dictionary = steals[i]
			file.store_line("#%d %s %s to %s - fell %d spots" % [
				s.get("pick_number", 0),
				s.get("position", ""),
				s.get("player_name", ""),
				s.get("team_id", ""),
				s.get("value_diff", 0)
			])
	file.store_line("")

	# Reaches
	file.store_line("DRAFT REACHES")
	file.store_line("-" * 40)
	var reaches: Array = _report.get("reaches", [])
	if reaches.is_empty():
		file.store_line("None identified")
	else:
		for i in range(min(15, reaches.size())):
			var r: Dictionary = reaches[i]
			file.store_line("#%d %s %s by %s - reached %d spots" % [
				r.get("pick_number", 0),
				r.get("position", ""),
				r.get("player_name", ""),
				r.get("team_id", ""),
				abs(int(r.get("value_diff", 0)))
			])

	file.store_line("")
	file.store_line("=" * 60)
	file.store_line("Generated by Gridiron Dynasty")
	file.store_line("=" * 60)

	file.close()
	return OK
