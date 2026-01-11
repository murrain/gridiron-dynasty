extends RefCounted
class_name WearConfig

## Pre-extracted wear configuration for O(1) access.
##
## Task F6: Configuration Access Optimization
##
## This class extracts wear-related configuration values from main config
## dictionary at initialization, providing O(1) member access instead of
## O(log n) dictionary lookups during player lifecycle advancement.
##
## While wear config is only accessed for players in decline phase (smaller
## impact than development config), pre-extraction still provides:
##   1. Performance: Direct member access vs dictionary lookups
##   2. Type safety: Explicit types vs Variant dictionary values
##   3. Maintainability: Clear interface for wear configuration
##
## Usage:
##   var main_cfg := Config.get_config("main")
##   var wear_config := WearConfig.new(main_cfg)
##   var snaps := wear_config.snaps_per_year()
##   var multiplier := wear_config.decline_multiplier(player)

## Annual base snaps
var _snaps_per_year: int

## Annual base collisions
var _collisions_per_year: int

## Position-specific multipliers (empty dict = no position adjustments)
var _position_multipliers: Dictionary

## Decline calculation scales
var _decline_snaps_scale: float
var _decline_collisions_scale: float
var _decline_injuries_scale: float
var _decline_per_wear: float

## Decline multiplier bounds
var _decline_min_multiplier: float
var _decline_max_multiplier: float


## Initialize wear config from main configuration.
##
## Parameters:
##   main_cfg: Main configuration dictionary
func _init(main_cfg: Dictionary) -> void:
	var wear_cfg: Dictionary = main_cfg.get("wear", {}) as Dictionary

	# Annual base values
	_snaps_per_year = int(wear_cfg.get("snaps_per_year", 650))
	_collisions_per_year = int(wear_cfg.get("collisions_per_year", 220))

	# Position multipliers (empty by default)
	_position_multipliers = (wear_cfg.get("position_multipliers", {}) as Dictionary).duplicate()

	# Decline scales
	_decline_snaps_scale = float(wear_cfg.get("decline_snaps_scale", 8000.0))
	_decline_collisions_scale = float(wear_cfg.get("decline_collisions_scale", 2600.0))
	_decline_injuries_scale = float(wear_cfg.get("decline_injuries_scale", 6.0))
	_decline_per_wear = float(wear_cfg.get("decline_per_wear", 0.2))

	# Decline multiplier bounds
	_decline_min_multiplier = float(wear_cfg.get("decline_min_multiplier", 1.0))
	_decline_max_multiplier = float(wear_cfg.get("decline_max_multiplier", 1.6))


## Get annual base snaps.
##
## Returns: int snaps per year
func snaps_per_year() -> int:
	return _snaps_per_year


## Get annual base collisions.
##
## Returns: int collisions per year
func collisions_per_year() -> int:
	return _collisions_per_year


## Get position multipliers dictionary.
##
## Returns: Dictionary of position-specific wear multipliers
func position_multipliers() -> Dictionary:
	return _position_multipliers


## Get decline snaps scale factor.
##
## Returns: float scale for snaps in decline calculation
func decline_snaps_scale() -> float:
	return _decline_snaps_scale


## Get decline collisions scale factor.
##
## Returns: float scale for collisions in decline calculation
func decline_collisions_scale() -> float:
	return _decline_collisions_scale


## Get decline injuries scale factor.
##
## Returns: float scale for injuries in decline calculation
func decline_injuries_scale() -> float:
	return _decline_injuries_scale


## Get decline per-wear factor.
##
## Returns: float multiplier applied per wear unit
func decline_per_wear() -> float:
	return _decline_per_wear


## Get decline minimum multiplier.
##
## Returns: float minimum wear decline multiplier
func decline_min_multiplier() -> float:
	return _decline_min_multiplier


## Get decline maximum multiplier.
##
## Returns: float maximum wear decline multiplier
func decline_max_multiplier() -> float:
	return _decline_max_multiplier


## Calculate wear decline multiplier for a player.
##
## This combines all wear factors (snaps, collisions, injuries) into a single
## multiplier that increases decline rate for players with high wear accumulation.
##
## Parameters:
##   player: Player dictionary with wear stats
##
## Returns: float multiplier (typically 1.0-1.6)
func decline_multiplier(player: Dictionary) -> float:
	var wear: Dictionary = player.get("wear", {}) as Dictionary
	var snaps := int(wear.get("snaps", 0))
	var collisions := int(wear.get("collisions", 0))
	var injuries := int(wear.get("injury_count", 0))

	var snaps_factor := float(snaps) / _decline_snaps_scale
	var collisions_factor := float(collisions) / _decline_collisions_scale
	var injuries_factor := float(injuries) / _decline_injuries_scale

	var total_wear := snaps_factor + collisions_factor + injuries_factor
	var multiplier := 1.0 + (total_wear * _decline_per_wear)

	return clamp(multiplier, _decline_min_multiplier, _decline_max_multiplier)
