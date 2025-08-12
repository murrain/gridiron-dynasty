# player_generation_benchmark.gd
# -----------------------------------------------------------------------------
# Measures players/second for your pipeline with:
#   (a) single worker thread
#   (b) max threads (<= 8 by default)
#
# By default: times generation only.
# Toggle exported flags to include rating and/or scout scoring.
#
# Usage:
#   - Attach to a Node in a dev scene and hit Play, or call run() manually.
#
extends Node
class_name PlayerGenerationBenchmark

# ---------- Tunables ----------
@export var class_size: int = 10000
@export var trials: int = 3
@export var include_rating: bool = true
@export var include_scouts: bool = true
@export var max_threads_cap: int = 0   # 0 = auto(min(cores, 8))
@export var scout_sample_cap: int = 250

# ---------- Private state ----------
var _positions: Dictionary
var _stats_cfg: Dictionary
var _main_cfg: Dictionary
var _scouts_cfg: Dictionary
var _scouts_built: Array = []   # Array[Scout]

func _ready() -> void:
	run()

func run() -> void:
	# Load configs once
	var all_cfg: Dictionary = Config.get_all()
	_positions  = all_cfg.get("positions", {})
	_stats_cfg  = all_cfg.get("stats", {})
	_main_cfg   = all_cfg.get("main", {})
	_scouts_cfg = all_cfg.get("scouts", {})

	# Build scouts if we’ll need them
	_scouts_built.clear()
	if include_scouts:
		_build_scouts_from_config()

	# Determine thread counts
	var cores: int = OS.get_processor_count()
	var max_threads: int = min(cores, 8)
	if max_threads_cap > 0:
		max_threads = min(max_threads_cap, cores)
	if max_threads < 1:
		max_threads = 1
	var one_thread: int = 1
	var many_threads: int = max_threads

	print("\n──────── BENCHMARK: players/sec ────────")
	print("class_size=%d  trials=%d  include_rating=%s  include_scouts=%s" %
		[class_size, trials, str(include_rating), str(include_scouts)])
	print("CPU cores=%d  max_threads(used)=%d" % [cores, many_threads])

	# Warmup
	_do_one_trial(500, one_thread)
	_do_one_trial(500, many_threads)

	# Timed: 1-thread
	var t1_sum: float = 0.0
	for i in range(trials):
		t1_sum += _do_one_trial(class_size, one_thread)

	# Timed: max-threads
	var tN_sum: float = 0.0
	for j in range(trials):
		tN_sum += _do_one_trial(class_size, many_threads)

	var avg1: float = t1_sum / float(max(1, trials))
	var avgN: float = tN_sum / float(max(1, trials))
	var pps1: float = class_size / max(0.000001, avg1)
	var ppsN: float = class_size / max(0.000001, avgN)
	var speedup: float = ppsN / max(0.000001, pps1)

	print("\nResults (avg over %d trials):" % trials)
	print(" - 1 thread:     %7.2f ms  |  %8.1f players/sec" % [avg1 * 1000.0, pps1])
	print(" - %d threads:  %7.2f ms  |  %8.1f players/sec" % [many_threads, avgN * 1000.0, ppsN])
	print(" - Speedup: ×%.2f" % speedup)
	print("────────────────────────────────────────\n")


# ---------- One trial (returns elapsed seconds) ----------
func _do_one_trial(size: int, threads: int) -> float:
	# Save current threads and set runtime override
	var prev_threads: int = _read_current_threads()
	Config.set_threads_runtime(threads)

	# Fresh generator
	var gen := PlayerGenerator.new()
	gen.main_cfg = _main_cfg
	gen.positions_data = _positions
	gen.stats_cfg = _stats_cfg
	gen.names_cfg = {}  # skip heavy name gen for benchmark
	gen.class_rules = _main_cfg.get("class_rules", {})

	# Stable RNG if desired
	if _main_cfg.has("random_seed"):
		seed(int(_main_cfg["random_seed"]))
	else:
		randomize()

	var gaussian_share: float = float(gen.class_rules.get("gaussian_share", 0.75))

	var t0 := Time.get_ticks_msec()

	# Generation (threading happens inside via Config.threads_count())
	var players: Array = gen.generate_class(size, gaussian_share)

	# Optionally include rating + scouts in the timed window
	if include_rating or include_scouts:
		var rater := RecruitRater.new()
		rater.rate_and_rank(players, _positions, gen.class_rules)

		if include_scouts and not _scouts_built.is_empty():
			var sample_n: int = min(scout_sample_cap, players.size())
			for i in range(sample_n):
				var p: Dictionary = players[i]
				for s in _scouts_built:
					s.score_player(p, _positions, _stats_cfg, gen.class_rules)

	var t1 := Time.get_ticks_msec()

	# Restore previous thread setting
	Config.set_threads_runtime(prev_threads)

	return (t1 - t0) / 1000.0


# ---------- Helpers ----------
func _read_current_threads() -> int:
	var eg := Config.engine_cfg()
	if eg.has("threads"):
		return int(eg["threads"])
	var cores: int = max(1, OS.get_processor_count())
	return min(cores, 8)

func _build_scouts_from_config() -> void:
	var defaults: Dictionary = _scouts_cfg.get("defaults", {}) as Dictionary
	var list: Array = (_scouts_cfg.get("national_scouts", []) as Array)
	for d in list:
		var row: Dictionary = d as Dictionary
		var s := Scout.new()
		_apply_scout_dict(s, row)
		# Important: two-arg setup as per your Scout.gd
		s.setup(_stats_cfg, defaults)
		_scouts_built.append(s)

func _apply_scout_dict(s: Scout, row: Dictionary) -> void:
	if row.has("name"): s.name = String(row["name"])
	if row.has("role"): s.role = String(row["role"])
	if row.has("years_exp"): s.years_exp = int(row["years_exp"])

	if row.has("base_skill"): s.base_skill = float(row["base_skill"])
	if row.has("overrate_athletes"): s.overrate_athletes = float(row["overrate_athletes"])
	if row.has("tape_grinder"): s.tape_grinder = float(row["tape_grinder"])
	if row.has("risk_aversion"): s.risk_aversion = float(row["risk_aversion"])

	if row.has("stat_skill"): s.stat_skill = (row["stat_skill"] as Dictionary).duplicate(true)
	if row.has("valuation_multipliers"): s.valuation_multipliers = (row["valuation_multipliers"] as Dictionary).duplicate(true)
	if row.has("estimation_multipliers"): s.estimation_multipliers = (row["estimation_multipliers"] as Dictionary).duplicate(true)
	if row.has("stat_bias_mean"): s.stat_bias_mean = (row["stat_bias_mean"] as Dictionary).duplicate(true)
	if row.has("stat_bias_sigma"): s.stat_bias_sigma = (row["stat_bias_sigma"] as Dictionary).duplicate(true)
