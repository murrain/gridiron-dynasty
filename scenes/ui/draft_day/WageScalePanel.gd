## WageScalePanel - UI Panel for displaying rookie contract information
##
## This panel displays the contract details for a specific draft pick,
## including year-by-year breakdown, signing bonus, and 5th year option.
##
## Used during the draft to inform trade and pick decisions.
##
## Usage:
##   wage_panel.set_cap_limit(200.0)
##   wage_panel.display_for_pick(1)  # Show Pick #1 contract
##
extends PanelContainer
class_name WageScalePanel

const RookieWageScale = preload("res://scripts/core/contracts/RookieWageScale.gd")

signal pick_comparison_requested(pick_a: int, pick_b: int)

## Configuration
var cap_limit: float = 200.0
var current_pick: int = 0

## UI References (assigned in _ready or via unique names)
@onready var header_label: Label = %HeaderLabel
@onready var total_value_label: Label = %TotalValueLabel
@onready var annual_hit_label: Label = %AnnualHitLabel
@onready var signing_bonus_label: Label = %SigningBonusLabel
@onready var fifth_year_container: HBoxContainer = %FifthYearContainer
@onready var fifth_year_label: Label = %FifthYearLabel
@onready var year_breakdown_container: VBoxContainer = %YearBreakdownContainer
@onready var context_label: Label = %ContextLabel
@onready var guaranteed_label: Label = %GuaranteedLabel


func _ready() -> void:
	_clear_display()


## Set the salary cap limit for calculations
func set_cap_limit(limit: float) -> void:
	cap_limit = limit
	if current_pick > 0:
		display_for_pick(current_pick)


## Display contract details for a specific pick number
func display_for_pick(pick_number: int) -> void:
	current_pick = pick_number

	if pick_number < 1:
		_clear_display()
		return

	var contract := RookieWageScale.get_contract_for_pick(pick_number, cap_limit)
	if contract.is_empty():
		_clear_display()
		return

	# Update header
	var round_num := int(contract.get("round", 1))
	header_label.text = "PICK #%d (Round %d) - ROOKIE CONTRACT" % [pick_number, round_num]

	# Update main values
	var total_value := float(contract.get("total_value", 0))
	var years := int(contract.get("years_total", 4))
	total_value_label.text = "Total Value: $%.2fM over %d years" % [total_value, years]

	var annual_hit := float(contract.get("annual_cap_hit", 0))
	annual_hit_label.text = "Annual Cap Hit: $%.3fM average" % annual_hit

	var signing_bonus := float(contract.get("signing_bonus", 0))
	signing_bonus_label.text = "Signing Bonus: $%.2fM (prorated over %d years)" % [signing_bonus, years]

	var gtd_remaining := float(contract.get("gtd_remaining", 0))
	guaranteed_label.text = "Guaranteed: $%.2fM" % gtd_remaining

	# Update 5th year option
	var has_fifth_year := bool(contract.get("fifth_year_option", false))
	if has_fifth_year:
		var fifth_year_value := float(contract.get("fifth_year_value", 0))
		fifth_year_label.text = "5th Year Option Available (est. $%.2fM)" % fifth_year_value
		fifth_year_container.visible = true
	else:
		fifth_year_container.visible = false

	# Build year-by-year breakdown
	_populate_year_breakdown(contract)

	# Show context comparison
	_show_context_comparison(pick_number)


## Display UDFA contract information
func display_udfa_contract(year: int) -> void:
	current_pick = 0

	var contract := RookieWageScale.create_udfa_contract(year, cap_limit)

	header_label.text = "UNDRAFTED FREE AGENT - MINIMUM CONTRACT"

	var base_salary := float(contract.get("base_salary", 0))
	var years := int(contract.get("years_total", 3))
	total_value_label.text = "Total Value: $%.3fM over %d years" % [base_salary * years, years]

	annual_hit_label.text = "Annual Cap Hit: $%.3fM" % base_salary
	signing_bonus_label.text = "Signing Bonus: $0 (no bonus)"
	guaranteed_label.text = "Guaranteed: $0 (no guarantees)"

	fifth_year_container.visible = false

	# Clear year breakdown
	for child in year_breakdown_container.get_children():
		child.queue_free()

	# Add simple year breakdown
	for yr in range(1, years + 1):
		var year_label := Label.new()
		year_label.text = "Year %d: $%.3fM" % [yr, base_salary]
		year_breakdown_container.add_child(year_label)

	context_label.text = "UDFA contracts: No bonus, no options, no guarantees"
	context_label.visible = true


## Display comparison between two picks
func display_comparison(pick_a: int, pick_b: int) -> void:
	var comparison := RookieWageScale.compare_picks(pick_a, pick_b, cap_limit)

	if comparison.has("error"):
		context_label.text = "Comparison error: %s" % comparison.get("error", "")
		return

	var savings := float(comparison.get("savings_total", 0))
	var savings_per_year := float(comparison.get("savings_per_year", 0))

	var text := comparison.get("comparison_text", "")
	context_label.text = text
	context_label.visible = true

	# Also update main display for pick_a
	display_for_pick(pick_a)


## Clear the display
func _clear_display() -> void:
	header_label.text = "Select a Pick"
	total_value_label.text = ""
	annual_hit_label.text = ""
	signing_bonus_label.text = ""
	guaranteed_label.text = ""
	fifth_year_container.visible = false
	context_label.text = ""
	context_label.visible = false

	for child in year_breakdown_container.get_children():
		child.queue_free()


## Populate year-by-year breakdown
func _populate_year_breakdown(contract: Dictionary) -> void:
	# Clear existing
	for child in year_breakdown_container.get_children():
		child.queue_free()

	var breakdown: Array = contract.get("year_breakdown", [])
	for entry in breakdown:
		var e: Dictionary = entry
		var year := int(e.get("year", 0))
		var cap_hit := float(e.get("cap_hit", 0))
		var base := float(e.get("base_salary", 0))
		var bonus := float(e.get("bonus_proration", 0))

		var year_label := Label.new()
		year_label.text = "Year %d: $%.3fM (base $%.3fM + bonus $%.3fM)" % [
			year, cap_hit, base, bonus
		]
		year_breakdown_container.add_child(year_label)


## Show contextual comparison with nearby picks
func _show_context_comparison(pick_number: int) -> void:
	# Compare with pick 10 spots later (if exists)
	var compare_pick := pick_number + 10
	if compare_pick > 262:
		compare_pick = pick_number + 5
	if compare_pick > 262:
		context_label.visible = false
		return

	var comparison := RookieWageScale.compare_picks(pick_number, compare_pick, cap_limit)
	if comparison.has("error"):
		context_label.visible = false
		return

	context_label.text = comparison.get("comparison_text", "")
	context_label.visible = true


## Get contract for the currently displayed pick
func get_current_contract() -> Dictionary:
	if current_pick < 1:
		return {}
	return RookieWageScale.get_contract_for_pick(current_pick, cap_limit)


## Get wage scale summary for display
func get_wage_scale_summary() -> Dictionary:
	return RookieWageScale.get_wage_scale_summary(cap_limit)
