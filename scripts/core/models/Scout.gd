extends "res://scripts/core/models/Person.gd"
class_name Scout

## Scout - Rich Entity with Pure Methods
##
## Architectural Pattern: Rich Entity
## Scout is a "rich entity" that contains both data and behavior. Unlike pure data
## models, Scout includes methods (score_player, estimate_stat) that operate on its
## own state plus passed parameters. This is acceptable because:
##
## 1. Methods are PURE FUNCTIONS - they don't modify Scout's state, only read it
## 2. Methods don't have external dependencies - they only use passed parameters
## 3. The behavior is tightly coupled to the entity's identity (a scout's skill determines scoring)
## 4. Keeping methods on Scout improves code locality and discoverability
##
## This pattern differs from extracting a separate ScoutingService because Scout's
## methods are stateless computations that depend heavily on Scout's configuration
## (skills, biases, weights). Keeping them together maintains cohesion.

const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")

# --- Identity (inherited from Person: id, first_name, last_name, get_full_name()) ---
@export var role: String = "Regional"
@export var years_exp: int = 0

# Backward compatibility property for code that uses scout.name
# This allows ScoutFactory and other generation code to work without changes
var name: String:
	get:
		return get_full_name()
	set(value):
		# Parse name into first_name and last_name
		var parts = value.strip_edges().split(" ", false, 2)
		first_name = parts[0] if parts.size() > 0 else "Unknown"
		last_name = parts[1] if parts.size() > 1 else ""

var base_skill: float = 0.6
var overrate_athletes: float = 0.0
var tape_grinder: float = 0.3
var risk_aversion: float = 0.1

# perception + valuation
var stat_skill: Dictionary = {}
var valuation_multipliers: Dictionary = {}
var estimation_multipliers: Dictionary = {}
var stat_bias_mean: Dictionary = {}
var stat_bias_sigma: Dictionary = {}

# bucket weights (these change how the rater “feels” after perception)
# e.g. athletic 0.50, core 0.25, secondary 0.15, mentals 0.10 for a traits-first scout
var bucket_weights: Dictionary = { "athletic": 0.40, "core": 0.30, "secondary": 0.20, "mentals": 0.10 }

# current vs potential blend
var current_weight: float = 0.80
var potential_weight: float = 0.20
var weight_jitter_sigma: float = 0.03

# board calibration (per-scout)
var board_offset_pts: float = 0.0      # add/subtract points after composite
var board_slope: float = 1.00          # >1 exaggerates highs/lows
var board_noise_sigma: float = 1.8     # spread between scouts on same player

# optional per-position lean (points)
var pos_bias_pts: Dictionary = {}      # e.g. {"RB": +0.8, "OL": -0.6}

# measurement difficulty map from stats_cfg
var _meas: Dictionary = {}
var _obs_cfg := { "sigma_min": 1.0, "sigma_max": 12.0, "quality_floor": 0.15, "bounded_min": 0.0, "bounded_max": 100.0 }
var _context_q := { "combine": 0.95, "practice": 0.65, "game": 0.80, "rumor": 0.30 }

func setup(stats_cfg: Dictionary, defaults: Dictionary, rng: RandomNumberGenerator) -> void:
	# measurability
	_meas.clear()
	for sd in stats_cfg.get("stats", []):
		var d: Dictionary = sd
		_meas[String(d.get("name",""))] = float(d.get("measurement_difficulty", 0.5))
	# defaults (context + current/potential)
	if defaults.has("context_quality"):
		_context_q = defaults["context_quality"]
	# small jitter so scouts don’t tie perfectly
	if weight_jitter_sigma > 0.0:
		var j := rng.randfn(0.0, weight_jitter_sigma)
		current_weight = clamp(current_weight + j, 0.55, 0.95)
		potential_weight = clamp(1.0 - current_weight, 0.05, 0.45)

func estimate_stat(
	true_value: float,
	stat: String,
	rng: RandomNumberGenerator,
	context_quality: float = 0.75
) -> float:
	var m := float(_meas.get(stat, 0.5))
	var skill := float(stat_skill.get(stat, base_skill))
	var sigma_span : float = max(0.0, _obs_cfg["sigma_max"] - _obs_cfg["sigma_min"])
	var sigma : float = _obs_cfg["sigma_min"] + sigma_span * (1.0 - skill) * (1.0 - clamp(context_quality, _obs_cfg["quality_floor"], 1.0)) * (1.0 + (1.0 - m))
	var mult := float(estimation_multipliers.get(stat, 1.0))
	var noise: float = rng.randfn(0.0, sigma)
	var est := true_value * mult + noise
	return clamp(est, _obs_cfg["bounded_min"], _obs_cfg["bounded_max"])

func _perceived_player(
	src: Dictionary,
	which: String,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# which == "current" uses src.stats, "potential" uses src.potential (fallback to stats)
	var p := src.duplicate(true)
	var stats: Dictionary = (src.get("stats", {}) as Dictionary).duplicate()
	var pot: Dictionary = src.get("potential", {}) as Dictionary
	var target := pot if which == "potential" and not pot.is_empty() else stats

	var out := {}
	for sd in stats_cfg.get("stats", []):
		var row: Dictionary = sd
		var k := String(row.get("name",""))
		var true_v := float(target.get(k, float(stats.get(k, 50.0))))
		var cq : float = _context_q.get("game", 0.8) # default use “game tape”
		var est := estimate_stat(true_v, k, rng, cq)
		# valuation multipliers as a lens on the number itself (keeps downstream simple)
		est *= float(valuation_multipliers.get(k, 1.0))
		out[k] = clamp(est, 0.0, 100.0)
	p["stats"] = out
	return p

# Central single-entry scout grade (returns a composite-like 0..100)
func score_player(
	player: Dictionary,
	positions_data: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator
) -> float:
	# perceived profiles
	var view_now := _perceived_player(player, "current", stats_cfg, rng)
	var view_pot := _perceived_player(player, "potential", stats_cfg, rng)

	# per-scout bucket weights drive the rater
	var tmp_rules := class_rules.duplicate(true)
	(tmp_rules["recruiting"] as Dictionary)["composite_weights"] = {
		"athletic": float(bucket_weights.get("athletic", 0.40)),
		"core":     float(bucket_weights.get("core", 0.30)),
		"secondary":float(bucket_weights.get("secondary", 0.20)),
		"mentals":  float(bucket_weights.get("mentals", 0.10))
	}

	var res_now: Dictionary = RecruitRater.compute(view_now, positions_data, {}, tmp_rules, {})
	var res_pot: Dictionary = RecruitRater.compute(view_pot, positions_data, {}, tmp_rules, {})
	var comp_now := float(res_now.get("composite", 0.0))
	var comp_pot := float(res_pot.get("composite", 0.0))

	var raw: float = current_weight * comp_now + potential_weight * comp_pot

	# board calibration (no position bias)
	raw = board_offset_pts + board_slope * raw
	var board_noise: float = rng.randfn(0.0, board_noise_sigma)
	raw += board_noise

	return clamp(raw, 30.0, 95.0)


## Returns the number of randf() calls consumed by score_player().
##
## This is used by RecruitingScoreCache to maintain determinism on cache hits.
## Co-locating this with score_player() prevents silent determinism breaks.
##
## RNG consumption pattern:
##   - _perceived_player(current): num_stats randfn calls (line 108)
##   - _perceived_player(potential): num_stats randfn calls (line 109)
##   - board_noise: 1 randfn call (line 129)
##   - Each randfn uses Box-Muller transform: 2 randf calls
##
## Total: (2 * num_stats + 1) * 2 randf calls
##
## Parameters:
##   num_stats: Number of stats being evaluated
##
## Returns: int number of randf() calls
static func get_rng_calls_per_evaluation(num_stats: int) -> int:
	var total_randfn := (2 * num_stats) + 1
	return total_randfn * 2

## Load scout data from dictionary with backward compatibility
## Migrates old "name" field to first_name/last_name
func from_dict(d: Dictionary) -> void:
	# Migration: old saves have "name", new saves have first_name/last_name
	if d.has("name") and not d.has("first_name"):
		var parts = String(d.get("name", "")).split(" ", false, 2)
		first_name = parts[0] if parts.size() > 0 else "Unknown"
		last_name = parts[1] if parts.size() > 1 else ""
		id = String(d.get("id", id))
	else:
		# Load person fields using base class method
		from_dict_person(d)

	# Load scout-specific fields
	role = String(d.get("role", role))
	years_exp = int(d.get("years_exp", years_exp))
	base_skill = float(d.get("base_skill", base_skill))
	overrate_athletes = float(d.get("overrate_athletes", overrate_athletes))
	tape_grinder = float(d.get("tape_grinder", tape_grinder))
	risk_aversion = float(d.get("risk_aversion", risk_aversion))

	# Load dictionaries
	stat_skill = (d.get("stat_skill", stat_skill) as Dictionary).duplicate(true)
	valuation_multipliers = (d.get("valuation_multipliers", valuation_multipliers) as Dictionary).duplicate(true)
	estimation_multipliers = (d.get("estimation_multipliers", estimation_multipliers) as Dictionary).duplicate(true)
	stat_bias_mean = (d.get("stat_bias_mean", stat_bias_mean) as Dictionary).duplicate(true)
	stat_bias_sigma = (d.get("stat_bias_sigma", stat_bias_sigma) as Dictionary).duplicate(true)
	bucket_weights = (d.get("bucket_weights", bucket_weights) as Dictionary).duplicate(true)
	pos_bias_pts = (d.get("pos_bias_pts", pos_bias_pts) as Dictionary).duplicate(true)

	# Load calibration fields
	current_weight = float(d.get("current_weight", current_weight))
	potential_weight = float(d.get("potential_weight", potential_weight))
	weight_jitter_sigma = float(d.get("weight_jitter_sigma", weight_jitter_sigma))
	board_offset_pts = float(d.get("board_offset_pts", board_offset_pts))
	board_slope = float(d.get("board_slope", board_slope))
	board_noise_sigma = float(d.get("board_noise_sigma", board_noise_sigma))

## Serialize scout data to dictionary
func to_dict() -> Dictionary:
	# Start with person fields
	var result = to_dict_person()

	# Add scout-specific fields
	result["role"] = role
	result["years_exp"] = years_exp
	result["base_skill"] = base_skill
	result["overrate_athletes"] = overrate_athletes
	result["tape_grinder"] = tape_grinder
	result["risk_aversion"] = risk_aversion
	result["stat_skill"] = stat_skill.duplicate(true)
	result["valuation_multipliers"] = valuation_multipliers.duplicate(true)
	result["estimation_multipliers"] = estimation_multipliers.duplicate(true)
	result["stat_bias_mean"] = stat_bias_mean.duplicate(true)
	result["stat_bias_sigma"] = stat_bias_sigma.duplicate(true)
	result["bucket_weights"] = bucket_weights.duplicate(true)
	result["pos_bias_pts"] = pos_bias_pts.duplicate(true)
	result["current_weight"] = current_weight
	result["potential_weight"] = potential_weight
	result["weight_jitter_sigma"] = weight_jitter_sigma
	result["board_offset_pts"] = board_offset_pts
	result["board_slope"] = board_slope
	result["board_noise_sigma"] = board_noise_sigma

	return result
