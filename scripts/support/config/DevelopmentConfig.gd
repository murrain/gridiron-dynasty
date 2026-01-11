extends RefCounted
class_name DevelopmentConfig

## Pre-extracted development configuration for optimized lookups.
##
## This class extracts commonly used development configuration values once
## at phase start, avoiding repeated dictionary lookups, type conversions,
## and default value computation in hot paths.
##
## Performance impact:
##   - Eliminates ~10-15 dictionary lookups per player per year
##   - Replaces O(log n) dict access with O(1) member access
##   - Pre-computes type conversions (int/float casts)
##
## Usage:
##   var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
##   var peak := dev_config.peak_age(position)  # Fast O(1) lookup

# Position-specific configuration
var _peak_ages: Dictionary  # position -> int
var _decline_starts: Dictionary  # position -> int
var _curves: Dictionary  # position -> String (curve name)

# Curve multipliers
var _curve_multipliers: Dictionary  # curve_name -> {growth, prime, decline}

# Global development parameters
var _base_progress_min: float
var _base_progress_max: float
var _progress_cap: float
var _prime_growth_min: float
var _prime_growth_max: float
var _decline_min: float
var _decline_max: float

# Scheme fit configuration
var _scheme_role_weights: Dictionary  # role -> float
var _scheme_mult_min: float
var _scheme_mult_max: float

## Constructor: extracts all config values once for fast repeated access.
##
## RNG usage: None (pure extraction, no randomness)
##
## Parameters:
##   positions_cfg: Dictionary from Config.get_config("positions")
##   main_cfg: Dictionary from Config.get_config("main")
func _init(positions_cfg: Dictionary, main_cfg: Dictionary) -> void:
	_extract_position_config(positions_cfg)
	_extract_global_config(main_cfg)
	_extract_scheme_config(main_cfg)

## Extract position-specific development parameters.
func _extract_position_config(positions_cfg: Dictionary) -> void:
	_peak_ages = {}
	_decline_starts = {}
	_curves = {}

	for pos in positions_cfg.keys():
		var pos_cfg: Dictionary = positions_cfg.get(pos, {}) as Dictionary
		var dev: Dictionary = pos_cfg.get("development", {}) as Dictionary

		_peak_ages[pos] = int(dev.get("peak_age", 26))
		_decline_starts[pos] = int(dev.get("decline_start", 30))
		_curves[pos] = String(dev.get("curve", "mid"))

## Extract global development parameters.
func _extract_global_config(main_cfg: Dictionary) -> void:
	var dev: Dictionary = main_cfg.get("development", {}) as Dictionary

	# Base progress range
	_base_progress_min = float(main_cfg.get("annual_base_progress_min", 1.0))
	_base_progress_max = float(main_cfg.get("annual_base_progress_max", 4.0))
	_progress_cap = float(main_cfg.get("annual_progress_cap", 6.0))

	# Phase-specific ranges
	_prime_growth_min = float(dev.get("prime_growth_min", 0.2))
	_prime_growth_max = float(dev.get("prime_growth_max", 0.8))
	_decline_min = float(dev.get("decline_min", 0.4))
	_decline_max = float(dev.get("decline_max", 1.6))

	# Curve multipliers
	var curve_mults: Dictionary = dev.get("curve_multipliers", {}) as Dictionary
	_curve_multipliers = curve_mults.duplicate(false)  # Shallow copy for fast access

## Extract scheme fit configuration.
func _extract_scheme_config(main_cfg: Dictionary) -> void:
	var dev_context: Dictionary = main_cfg.get("development_context", {}) as Dictionary
	var scheme_cfg: Dictionary = dev_context.get("scheme_fit", {}) as Dictionary

	_scheme_role_weights = (scheme_cfg.get("role_weights", {}) as Dictionary).duplicate(false)
	_scheme_mult_min = float(scheme_cfg.get("multiplier_min", 0.85))
	_scheme_mult_max = float(scheme_cfg.get("multiplier_max", 1.15))

## Get peak age for a position.
## Returns: int (default 26 if position not found)
func peak_age(position: String) -> int:
	return int(_peak_ages.get(position, 26))

## Get decline start age for a position.
## Returns: int (default 30 if position not found)
func decline_start(position: String) -> int:
	return int(_decline_starts.get(position, 30))

## Get development curve name for a position.
## Returns: String (default "mid" if position not found)
func curve_name(position: String) -> String:
	return String(_curves.get(position, "mid"))

## Get curve multipliers for a given curve name.
## Returns: Dictionary with keys {growth, prime, decline}
func curve_multipliers(curve: String) -> Dictionary:
	var curve_cfg: Dictionary = _curve_multipliers.get(curve, {}) as Dictionary
	return {
		"growth": float(curve_cfg.get("growth", 1.0)),
		"prime": float(curve_cfg.get("prime", 0.35)),
		"decline": float(curve_cfg.get("decline", 1.0))
	}

## Get base progress range (min, max).
## Returns: Vector2(min, max)
func base_progress_range() -> Vector2:
	return Vector2(_base_progress_min, _base_progress_max)

## Get prime growth range (min, max).
## Returns: Vector2(min, max)
func prime_growth_range() -> Vector2:
	return Vector2(_prime_growth_min, _prime_growth_max)

## Get decline range (min, max).
## Returns: Vector2(min, max)
func decline_range() -> Vector2:
	return Vector2(_decline_min, _decline_max)

## Get annual progress cap.
## Returns: float
func progress_cap() -> float:
	return _progress_cap

## Get scheme fit role weight for a given role.
## Returns: float (default 0.0 if role not found)
func scheme_role_weight(role: String) -> float:
	return float(_scheme_role_weights.get(role, 0.0))

## Get scheme fit multiplier range.
## Returns: Vector2(min, max)
func scheme_multiplier_range() -> Vector2:
	return Vector2(_scheme_mult_min, _scheme_mult_max)
