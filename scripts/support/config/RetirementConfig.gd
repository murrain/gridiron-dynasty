extends RefCounted
class_name RetirementConfig

## Pre-extracted retirement configuration for optimized lookups.
##
## This class extracts retirement parameters once at phase start,
## avoiding repeated dictionary lookups in retirement checks.
##
## Performance impact:
##   - Eliminates ~5 dictionary lookups per player per year
##   - Replaces O(log n) dict access with O(1) member access
##   - Pre-computes type conversions (int/float casts)
##
## Usage:
##   var ret_config := RetirementConfig.new(main_cfg)
##   if age >= ret_config.max_age: return true

var _min_age: int
var _soft_cap_age: int
var _max_age: int
var _base_chance: float
var _age_chance_per_year: float
var _low_rating_threshold: float
var _low_rating_boost: float

## Constructor: extracts retirement config values once.
##
## RNG usage: None (pure extraction, no randomness)
##
## Parameters:
##   main_cfg: Dictionary from Config.get_config("main")
func _init(main_cfg: Dictionary) -> void:
	var cfg: Dictionary = main_cfg.get("retirement", {}) as Dictionary

	_min_age = int(cfg.get("min_age", 27))
	_soft_cap_age = int(cfg.get("soft_cap_age", 33))
	_max_age = int(cfg.get("max_age", 40))
	_base_chance = float(cfg.get("base_chance", 0.02))
	_age_chance_per_year = float(cfg.get("age_chance_per_year", 0.04))
	_low_rating_threshold = float(cfg.get("low_rating_threshold", 55.0))
	_low_rating_boost = float(cfg.get("low_rating_boost", 0.08))

## Minimum age for retirement consideration.
func min_age() -> int:
	return _min_age

## Age at which retirement probability starts increasing significantly.
func soft_cap_age() -> int:
	return _soft_cap_age

## Maximum age (forced retirement).
func max_age() -> int:
	return _max_age

## Base retirement chance per year.
func base_chance() -> float:
	return _base_chance

## Additional retirement chance per year above soft cap.
func age_chance_per_year() -> float:
	return _age_chance_per_year

## Rating threshold below which retirement boost applies.
func low_rating_threshold() -> float:
	return _low_rating_threshold

## Retirement chance boost for low-rated players.
func low_rating_boost() -> float:
	return _low_rating_boost
