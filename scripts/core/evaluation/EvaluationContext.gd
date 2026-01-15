## EvaluationContext - Data container for player evaluation
##
## Passed to all evaluation modifiers so they have access to the same
## context without needing different function signatures.
##
## Inspired by Caves of Qud's modifier system where mods receive a
## context object containing all relevant state.
extends RefCounted
class_name EvaluationContext

## The player being evaluated
var player: Dictionary = {}

## Player's position (e.g., "QB", "EDGE")
var position: String = ""

## Player's base overall rating before modifiers
var base_rating: float = 0.0

## The team doing the evaluation
var team: Dictionary = {}

## Team's current roster
var roster: Dictionary = {}

## Team's head coach
var coach: Dictionary = {}

## Team's offensive scheme (e.g., "west_coast", "air_raid")
var offensive_scheme: String = "pro_style"

## Team's defensive scheme (e.g., "cover_2", "3_4_two_gap")
var defensive_scheme: String = "cover_2"

## Evaluation phase: "draft", "free_agency", "trade", "waiver"
var phase: String = "draft"

## Draft round (1-7) if phase == "draft"
var draft_round: int = 0

## Year of evaluation (for age calculations, etc.)
var year: int = 0

## Configuration dictionaries
var positions_cfg: Dictionary = {}
var stats_cfg: Dictionary = {}
var class_rules: Dictionary = {}
var schemes_cfg: Dictionary = {}

## Team's draft strategy configuration (position tiers, etc.)
var draft_strategy: Dictionary = {}

## Team's calculated position needs (position -> need_multiplier)
var position_needs: Dictionary = {}

## Scout evaluating (if applicable)
var scout: Dictionary = {}

## Random seed for deterministic evaluation
var seed: int = 0


## Factory method to create context for draft evaluation
static func for_draft(
	p_player: Dictionary,
	p_team: Dictionary,
	p_roster: Dictionary,
	p_round: int,
	p_year: int,
	p_positions_cfg: Dictionary,
	p_stats_cfg: Dictionary,
	p_class_rules: Dictionary,
	p_draft_strategy: Dictionary = {}
) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.player = p_player
	ctx.position = String(p_player.get("position", ""))
	ctx.team = p_team
	ctx.roster = p_roster
	ctx.coach = p_team.get("coach", {}) as Dictionary
	ctx.offensive_scheme = String(p_team.get("offensive_scheme", "pro_style"))
	ctx.defensive_scheme = String(p_team.get("defensive_scheme", "cover_2"))
	ctx.phase = "draft"
	ctx.draft_round = p_round
	ctx.year = p_year
	ctx.positions_cfg = p_positions_cfg
	ctx.stats_cfg = p_stats_cfg
	ctx.class_rules = p_class_rules
	ctx.draft_strategy = p_draft_strategy
	return ctx


## Factory method to create context for free agency evaluation
static func for_free_agency(
	p_player: Dictionary,
	p_team: Dictionary,
	p_roster: Dictionary,
	p_year: int,
	p_positions_cfg: Dictionary,
	p_class_rules: Dictionary
) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.player = p_player
	ctx.position = String(p_player.get("position", ""))
	ctx.team = p_team
	ctx.roster = p_roster
	ctx.coach = p_team.get("coach", {}) as Dictionary
	ctx.offensive_scheme = String(p_team.get("offensive_scheme", "pro_style"))
	ctx.defensive_scheme = String(p_team.get("defensive_scheme", "cover_2"))
	ctx.phase = "free_agency"
	ctx.year = p_year
	ctx.positions_cfg = p_positions_cfg
	ctx.class_rules = p_class_rules
	return ctx


## Factory method to create context for trade evaluation
static func for_trade(
	p_player: Dictionary,
	p_team: Dictionary,
	p_roster: Dictionary,
	p_year: int,
	p_positions_cfg: Dictionary,
	p_class_rules: Dictionary
) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.player = p_player
	ctx.position = String(p_player.get("position", ""))
	ctx.team = p_team
	ctx.roster = p_roster
	ctx.coach = p_team.get("coach", {}) as Dictionary
	ctx.offensive_scheme = String(p_team.get("offensive_scheme", "pro_style"))
	ctx.defensive_scheme = String(p_team.get("defensive_scheme", "cover_2"))
	ctx.phase = "trade"
	ctx.year = p_year
	ctx.positions_cfg = p_positions_cfg
	ctx.class_rules = p_class_rules
	return ctx


## Helper to check if position is offensive
func is_offensive_position() -> bool:
	return position in ["QB", "RB", "WR", "TE", "OL"]


## Helper to check if position is defensive
func is_defensive_position() -> bool:
	return position in ["DL", "EDGE", "LB", "CB", "S"]


## Helper to check if position is special teams
func is_special_teams_position() -> bool:
	return position in ["K", "P"]


## Helper to get the relevant scheme for this position
func get_scheme_for_position() -> String:
	if is_offensive_position():
		return offensive_scheme
	elif is_defensive_position():
		return defensive_scheme
	return ""


## Helper to get position group classification
func get_position_group() -> String:
	if is_offensive_position():
		return "offense"
	elif is_defensive_position():
		return "defense"
	elif is_special_teams_position():
		return "special_teams"
	return "unknown"
