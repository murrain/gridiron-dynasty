## TradeValuePanel - Real-time trade value display component (DRAFT-012)
##
## Shows pick values during draft trading and calculates fairness.
## Uses existing TradeValuation.evaluate_offer() for calculations.
##
## Features:
## - Real-time pick value display (updated <16ms for UI)
## - Live calculation as picks added to trade
## - Value differential visualization (bar chart)
## - Fair trade indicator (green/yellow/red)
## - Integration with TradeProposalDialog
##
extends PanelContainer
class_name TradeValuePanel

const TradeValuation = preload("res://scripts/world/trade/TradeValuation.gd")

## Trade fairness thresholds
const FAIR_TRADE_THRESHOLD := 0.95  # Incoming >= 95% of outgoing = fair
const GOOD_TRADE_THRESHOLD := 1.05  # Incoming >= 105% of outgoing = good deal
const GREAT_TRADE_THRESHOLD := 1.20 # Incoming >= 120% of outgoing = great deal

## Color constants for visualization
const COLOR_GREAT := Color(0.2, 0.8, 0.2)   # Green - great deal
const COLOR_GOOD := Color(0.3, 0.7, 0.3)    # Light green - good deal
const COLOR_FAIR := Color(0.7, 0.7, 0.3)    # Yellow - fair trade
const COLOR_BAD := Color(0.8, 0.3, 0.3)     # Red - bad deal

## Emitted when trade value changes (for external listeners)
signal value_changed(incoming_value: float, outgoing_value: float, differential: float)

## Trade context (provided externally)
var _pick_value_curve: Dictionary = {}
var _player_values: Dictionary = {}

## Current trade state
var _incoming_picks: Array = []
var _outgoing_picks: Array = []
var _incoming_players: Array = []
var _outgoing_players: Array = []

## Calculated values (cached for performance)
var _incoming_value: float = 0.0
var _outgoing_value: float = 0.0
var _value_differential: float = 0.0
var _fairness_rating: String = "N/A"

## UI elements
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var incoming_label: Label = $VBoxContainer/ValuesContainer/IncomingPanel/IncomingLabel
@onready var incoming_value_label: Label = $VBoxContainer/ValuesContainer/IncomingPanel/IncomingValueLabel
@onready var outgoing_label: Label = $VBoxContainer/ValuesContainer/OutgoingPanel/OutgoingLabel
@onready var outgoing_value_label: Label = $VBoxContainer/ValuesContainer/OutgoingPanel/OutgoingValueLabel
@onready var differential_bar: ProgressBar = $VBoxContainer/DifferentialContainer/DifferentialBar
@onready var differential_label: Label = $VBoxContainer/DifferentialContainer/DifferentialLabel
@onready var fairness_indicator: Label = $VBoxContainer/FairnessIndicator


func _ready() -> void:
	# Validate critical UI nodes
	if not incoming_value_label:
		push_warning("[TradeValueCalculator] incoming_value_label node not found - incoming value display missing")

	if not outgoing_value_label:
		push_warning("[TradeValueCalculator] outgoing_value_label node not found - outgoing value display missing")

	if not differential_bar:
		push_warning("[TradeValueCalculator] differential_bar node not found - differential visualization missing")

	if not differential_label:
		push_warning("[TradeValueCalculator] differential_label node not found - differential text missing")

	if not fairness_indicator:
		push_warning("[TradeValueCalculator] fairness_indicator node not found - fairness rating missing")

	if not title_label:
		push_warning("[TradeValueCalculator] title_label node not found - title display missing")

	_initialize_default_pick_values()
	_update_display()


## Initialize calculator (can be called to reset state)
func initialize() -> void:
	_initialize_default_pick_values()
	clear_trade()
	_update_display()


## Initialize with default pick value curve (can be overridden)
func _initialize_default_pick_values() -> void:
	# Standard NFL draft pick value chart (simplified version)
	# Based on classic "Jimmy Johnson" chart, normalized
	_pick_value_curve = {
		"round_defaults": {
			"1": 1000.0,
			"2": 500.0,
			"3": 250.0,
			"4": 100.0,
			"5": 50.0,
			"6": 30.0,
			"7": 15.0
		}
	}


## Set custom pick value curve
func set_pick_value_curve(curve: Dictionary) -> void:
	_pick_value_curve = curve
	_recalculate()


## Set player values lookup
func set_player_values(values: Dictionary) -> void:
	_player_values = values
	_recalculate()


## Add incoming pick to trade
func add_incoming_pick(round_num: int, slot: int) -> void:
	_incoming_picks.append({"round": round_num, "slot": slot})
	_recalculate()


## Remove incoming pick from trade
func remove_incoming_pick(round_num: int, slot: int) -> void:
	for i in range(_incoming_picks.size() - 1, -1, -1):
		var pick: Dictionary = _incoming_picks[i]
		if pick.get("round") == round_num and pick.get("slot") == slot:
			_incoming_picks.remove_at(i)
			break
	_recalculate()


## Add outgoing pick to trade
func add_outgoing_pick(round_num: int, slot: int) -> void:
	_outgoing_picks.append({"round": round_num, "slot": slot})
	_recalculate()


## Remove outgoing pick from trade
func remove_outgoing_pick(round_num: int, slot: int) -> void:
	for i in range(_outgoing_picks.size() - 1, -1, -1):
		var pick: Dictionary = _outgoing_picks[i]
		if pick.get("round") == round_num and pick.get("slot") == slot:
			_outgoing_picks.remove_at(i)
			break
	_recalculate()


## Add incoming player to trade
func add_incoming_player(player_id: String, position: String) -> void:
	_incoming_players.append({"id": player_id, "position": position})
	_recalculate()


## Remove incoming player from trade
func remove_incoming_player(player_id: String) -> void:
	for i in range(_incoming_players.size() - 1, -1, -1):
		var player: Dictionary = _incoming_players[i]
		if player.get("id") == player_id:
			_incoming_players.remove_at(i)
			break
	_recalculate()


## Add outgoing player to trade
func add_outgoing_player(player_id: String, position: String) -> void:
	_outgoing_players.append({"id": player_id, "position": position})
	_recalculate()


## Remove outgoing player from trade
func remove_outgoing_player(player_id: String) -> void:
	for i in range(_outgoing_players.size() - 1, -1, -1):
		var player: Dictionary = _outgoing_players[i]
		if player.get("id") == player_id:
			_outgoing_players.remove_at(i)
			break
	_recalculate()


## Clear all trade items
func clear_trade() -> void:
	_incoming_picks.clear()
	_outgoing_picks.clear()
	_incoming_players.clear()
	_outgoing_players.clear()
	_recalculate()


## Recalculate trade values
## Performance target: <16ms for UI responsiveness
func _recalculate() -> void:
	var start := Time.get_ticks_usec()

	# Build offer structure for TradeValuation
	var offer := {
		"incoming": {
			"players": _incoming_players,
			"picks": _incoming_picks
		},
		"outgoing": {
			"players": _outgoing_players,
			"picks": _outgoing_picks
		}
	}

	# Build context
	var context := {
		"player_values": _player_values,
		"pick_value_curve": _pick_value_curve,
		"team_needs": {},  # Could be populated for more accurate valuation
		"threshold": FAIR_TRADE_THRESHOLD
	}

	# Evaluate using existing TradeValuation
	var result := TradeValuation.evaluate_offer(offer, context)

	_incoming_value = float(result.get("incoming_value", 0.0))
	_outgoing_value = float(result.get("outgoing_value", 0.0))

	# Calculate differential
	if _outgoing_value > 0:
		_value_differential = (_incoming_value / _outgoing_value) - 1.0
	else:
		_value_differential = 1.0 if _incoming_value > 0 else 0.0

	# Determine fairness rating
	_fairness_rating = _calculate_fairness_rating()

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	if elapsed > 16.0:
		push_warning("[TradeValueCalculator] Calculation took %.2fms (target: <16ms)" % elapsed)

	_update_display()
	value_changed.emit(_incoming_value, _outgoing_value, _value_differential)


## Calculate fairness rating string
func _calculate_fairness_rating() -> String:
	if _outgoing_value <= 0:
		if _incoming_value > 0:
			return "FREE ASSETS"
		return "EMPTY TRADE"

	var ratio := _incoming_value / _outgoing_value

	if ratio >= GREAT_TRADE_THRESHOLD:
		return "STEAL"
	elif ratio >= GOOD_TRADE_THRESHOLD:
		return "GOOD DEAL"
	elif ratio >= FAIR_TRADE_THRESHOLD:
		return "FAIR TRADE"
	elif ratio >= 0.80:
		return "SLIGHT OVERPAY"
	elif ratio >= 0.60:
		return "BAD DEAL"
	else:
		return "TERRIBLE DEAL"


## Get fairness color
func _get_fairness_color() -> Color:
	if _outgoing_value <= 0:
		return COLOR_FAIR

	var ratio := _incoming_value / _outgoing_value

	if ratio >= GREAT_TRADE_THRESHOLD:
		return COLOR_GREAT
	elif ratio >= GOOD_TRADE_THRESHOLD:
		return COLOR_GOOD
	elif ratio >= FAIR_TRADE_THRESHOLD:
		return COLOR_FAIR
	else:
		return COLOR_BAD


## Update all display elements
func _update_display() -> void:
	if not is_inside_tree():
		return

	# Update value labels
	if incoming_value_label:
		incoming_value_label.text = "%.0f" % _incoming_value
	if outgoing_value_label:
		outgoing_value_label.text = "%.0f" % _outgoing_value

	# Update differential bar
	if differential_bar:
		# Bar shows 0-200% range (0.0-2.0 ratio), centered at 100% (1.0)
		var ratio := 1.0
		if _outgoing_value > 0:
			ratio = _incoming_value / _outgoing_value
		differential_bar.value = clamp(ratio * 50.0, 0.0, 100.0)  # Map 0-2 to 0-100

	# Update differential label
	if differential_label:
		var pct := _value_differential * 100.0
		if pct >= 0:
			differential_label.text = "+%.0f%%" % pct
		else:
			differential_label.text = "%.0f%%" % pct

	# Update fairness indicator
	if fairness_indicator:
		fairness_indicator.text = _fairness_rating
		fairness_indicator.add_theme_color_override("font_color", _get_fairness_color())


## Get current trade summary for external use
func get_trade_summary() -> Dictionary:
	return {
		"incoming_picks": _incoming_picks.duplicate(true),
		"outgoing_picks": _outgoing_picks.duplicate(true),
		"incoming_players": _incoming_players.duplicate(true),
		"outgoing_players": _outgoing_players.duplicate(true),
		"incoming_value": _incoming_value,
		"outgoing_value": _outgoing_value,
		"value_differential": _value_differential,
		"fairness_rating": _fairness_rating,
		"is_fair": _incoming_value >= _outgoing_value * FAIR_TRADE_THRESHOLD
	}


## Check if current trade is fair (for trade proposal validation)
func is_fair_trade() -> bool:
	if _outgoing_value <= 0:
		return true
	return _incoming_value >= _outgoing_value * FAIR_TRADE_THRESHOLD


## Get the pick value for a specific pick
func get_pick_value(round_num: int, slot: int) -> float:
	var pick := {"round": round_num, "slot": slot}
	var context := {"pick_value_curve": _pick_value_curve}

	# Use TradeValuation's pick value calculation
	# This is a bit roundabout but ensures consistency
	var offer := {"incoming": {"picks": [pick], "players": []}, "outgoing": {"picks": [], "players": []}}
	var result := TradeValuation.evaluate_offer(offer, context)
	return float(result.get("incoming_value", 0.0))


## Get value for a specific round (average/default)
func get_round_value(round_num: int) -> float:
	return get_pick_value(round_num, 1)
