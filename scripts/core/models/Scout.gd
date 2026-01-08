extends Resource
class_name Scout

@export var name: String = "Scout"
@export var role: String = "Regional"
@export var years_exp: int = 0

var base_skill: float = 0.6
var overrate_athletes: float = 0.0
var tape_grinder: float = 0.3
var risk_aversion: float = 0.1

# perception + valuation
var stat_skill: Dictionary = {}
var valuation_multipliers: Dictionary = {}
var estimation_multipliers: Dictionary = {}

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

func setup(stats_cfg: Dictionary, defaults: Dictionary) -> void:
	# measurability
	_meas.clear()
	for sd in stats_cfg.get("stats", []):
		var d: Dictionary = sd
		_meas[String(d.get("name",""))] = float(d.get("measurement_difficulty", 0.5))
	# defaults (context + current/potential)
	if defaults.has("context_quality"):
		_context_q = defaults["context_quality"]
	if defaults.has("current_vs_potential"):
		var cvp: Dictionary = defaults["current_vs_potential"]
		if not ( "current_weight" in self ):
			pass
	# small jitter so scouts don’t tie perfectly
	if weight_jitter_sigma > 0.0:
		var j := randfn(0.0, weight_jitter_sigma)
		current_weight = clamp(current_weight + j, 0.55, 0.95)
		potential_weight = clamp(1.0 - current_weight, 0.05, 0.45)

func estimate_stat(true_value: float, stat: String, context_quality: float = 0.75) -> float:
	var m := float(_meas.get(stat, 0.5))
	var skill := float(stat_skill.get(stat, base_skill))
	var sigma_span : float = max(0.0, _obs_cfg["sigma_max"] - _obs_cfg["sigma_min"])
	var sigma : float = _obs_cfg["sigma_min"] + sigma_span * (1.0 - skill) * (1.0 - clamp(context_quality, _obs_cfg["quality_floor"], 1.0)) * (1.0 + (1.0 - m))
	var mult := float(estimation_multipliers.get(stat, 1.0))
	var est := true_value * mult + randfn(0.0, sigma)
	return clamp(est, _obs_cfg["bounded_min"], _obs_cfg["bounded_max"])

func _perceived_player(src: Dictionary, which: String, stats_cfg: Dictionary) -> Dictionary:
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
		var est := estimate_stat(true_v, k, cq)
		# valuation multipliers as a lens on the number itself (keeps downstream simple)
		est *= float(valuation_multipliers.get(k, 1.0))
		out[k] = clamp(est, 0.0, 100.0)
	p["stats"] = out
	return p

# Central single-entry scout grade (returns a composite-like 0..100)
func score_player(player: Dictionary, positions_data: Dictionary, stats_cfg: Dictionary, class_rules: Dictionary) -> float:
	# perceived profiles
	var view_now := _perceived_player(player, "current", stats_cfg)
	var view_pot := _perceived_player(player, "potential", stats_cfg)

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

	var raw := current_weight * comp_now + potential_weight * comp_pot

	# board calibration (no position bias)
	raw = board_offset_pts + board_slope * raw
	raw += randfn(0.0, board_noise_sigma)

	return clamp(raw, 30.0, 95.0)
