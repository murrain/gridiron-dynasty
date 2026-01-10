extends RefCounted
## Benchmark script for Task F2: College Recruiting Optimization
##
## Compares performance of original vs optimized implementation.
## Usage: Call run() to execute benchmark and print results.

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const CollegeRecruitingOptimized = preload("res://scripts/pipelines/CollegeRecruitingOptimized.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run() -> Dictionary:
	print("\n" + "=".repeat(70))
	print("TASK F2: COLLEGE RECRUITING OPTIMIZATION BENCHMARK")
	print("=".repeat(70))

	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var pipeline_cfg := {
		"recruiting": {
			"offer_limit": 30,
			"board_limit": 120,
			"class_size_min": 15,
			"class_size_max": 25,
			"rating_weight": 0.55,
			"eliteness_weight": 0.25,
			"proximity_weight": 0.20,
			"region_match_multiplier": 1.35,
			"scout_weight": 0.70,
			"baseline_weight": 0.30,
			"visit_chance": 0.25,
			"visit_bonus": 0.06
		}
	}

	var test_cases := [
		{"name": "Small", "recruits": 100, "colleges": 10},
		{"name": "Medium", "recruits": 500, "colleges": 30},
		{"name": "Large", "recruits": 1000, "colleges": 65},
		{"name": "Realistic", "recruits": 2000, "colleges": 130}
	]

	var results := []

	for test_case in test_cases:
		var tc: Dictionary = test_case
		var name := String(tc.get("name", ""))
		var recruit_count := int(tc.get("recruits", 0))
		var college_count := int(tc.get("colleges", 0))

		print("\n" + "-".repeat(70))
		print("Test Case: %s (%d recruits × %d colleges = %d evaluations)" % [
			name, recruit_count, college_count, recruit_count * college_count
		])
		print("-".repeat(70))

		var recruits := _generate_recruits(recruit_count)
		var colleges := _generate_colleges(college_count)
		var seed := 12345

		# Benchmark original
		var time_orig_start := Time.get_ticks_usec()
		var original := CollegeRecruiting.new()
		var result_orig := original.run(
			recruits, colleges, pipeline_cfg,
			positions_cfg, stats_cfg, class_rules, scouts_cfg,
			seed, 2025
		)
		var time_orig := Time.get_ticks_usec() - time_orig_start

		# Benchmark optimized (sequential)
		var time_opt_seq_start := Time.get_ticks_usec()
		var optimized := CollegeRecruitingOptimized.new()
		var result_opt_seq := optimized.run(
			recruits, colleges, pipeline_cfg,
			positions_cfg, stats_cfg, class_rules, scouts_cfg,
			seed, 2025, false
		)
		var time_opt_seq := Time.get_ticks_usec() - time_opt_seq_start

		# Benchmark optimized (parallel)
		var time_opt_par_start := Time.get_ticks_usec()
		var result_opt_par := optimized.run(
			recruits, colleges, pipeline_cfg,
			positions_cfg, stats_cfg, class_rules, scouts_cfg,
			seed, 2025, true
		)
		var time_opt_par := Time.get_ticks_usec() - time_opt_par_start

		var speedup_seq := float(time_orig) / max(1.0, float(time_opt_seq))
		var speedup_par := float(time_orig) / max(1.0, float(time_opt_par))

		print("  Original:           %8d µs  (%.2f ms)" % [time_orig, time_orig / 1000.0])
		print("  Optimized (seq):    %8d µs  (%.2f ms)  [%.2fx speedup]" % [time_opt_seq, time_opt_seq / 1000.0, speedup_seq])
		print("  Optimized (par):    %8d µs  (%.2f ms)  [%.2fx speedup]" % [time_opt_par, time_opt_par / 1000.0, speedup_par])
		print("")
		print("  Commitments (orig):    %d" % result_orig.get("commitments", []).size())
		print("  Commitments (opt-seq): %d" % result_opt_seq.get("commitments", []).size())
		print("  Commitments (opt-par): %d" % result_opt_par.get("commitments", []).size())

		# Verify correctness
		var correct_seq := _verify_results(result_orig, result_opt_seq)
		var correct_par := _verify_results(result_opt_seq, result_opt_par)

		print("  Correctness (seq):     %s" % ("PASS" if correct_seq else "FAIL"))
		print("  Correctness (par):     %s" % ("PASS" if correct_par else "FAIL"))

		results.append({
			"name": name,
			"recruits": recruit_count,
			"colleges": college_count,
			"time_orig": time_orig,
			"time_opt_seq": time_opt_seq,
			"time_opt_par": time_opt_par,
			"speedup_seq": speedup_seq,
			"speedup_par": speedup_par,
			"correct_seq": correct_seq,
			"correct_par": correct_par
		})

	print("\n" + "=".repeat(70))
	print("SUMMARY")
	print("=".repeat(70))

	var total_orig := 0
	var total_opt_seq := 0
	var total_opt_par := 0

	for result in results:
		var r: Dictionary = result
		total_orig += int(r.get("time_orig", 0))
		total_opt_seq += int(r.get("time_opt_seq", 0))
		total_opt_par += int(r.get("time_opt_par", 0))

	var overall_speedup_seq := float(total_orig) / max(1.0, float(total_opt_seq))
	var overall_speedup_par := float(total_orig) / max(1.0, float(total_opt_par))

	print("\nOverall Performance:")
	print("  Total time (original):      %.2f ms" % (total_orig / 1000.0))
	print("  Total time (opt-seq):       %.2f ms  [%.2fx speedup]" % [total_opt_seq / 1000.0, overall_speedup_seq])
	print("  Total time (opt-par):       %.2f ms  [%.2fx speedup]" % [total_opt_par / 1000.0, overall_speedup_par])
	print("\nExpected impact: 50-70%% reduction in recruiting phase time")
	print("Actual reduction (sequential): %.1f%%" % ((1.0 - 1.0/overall_speedup_seq) * 100.0))
	print("Actual reduction (parallel):   %.1f%%" % ((1.0 - 1.0/overall_speedup_par) * 100.0))

	var all_correct := true
	for result in results:
		var r: Dictionary = result
		if not r.get("correct_seq", false) or not r.get("correct_par", false):
			all_correct = false
			break

	print("\nCorrectness: %s" % ("ALL TESTS PASSED" if all_correct else "SOME TESTS FAILED"))
	print("=".repeat(70) + "\n")

	return {
		"results": results,
		"overall_speedup_seq": overall_speedup_seq,
		"overall_speedup_par": overall_speedup_par,
		"all_correct": all_correct
	}

func _verify_results(result_a: Dictionary, result_b: Dictionary) -> bool:
	var commits_a: Array = result_a.get("commitments", []) as Array
	var commits_b: Array = result_b.get("commitments", []) as Array

	if commits_a.size() != commits_b.size():
		return false

	# Create player->college mappings
	var map_a := {}
	for commit in commits_a:
		var c: Dictionary = commit
		map_a[String(c.get("player_id", ""))] = String(c.get("college_id", ""))

	var map_b := {}
	for commit in commits_b:
		var c: Dictionary = commit
		map_b[String(c.get("player_id", ""))] = String(c.get("college_id", ""))

	return JSON.stringify(map_a) == JSON.stringify(map_b)

func _generate_recruits(count: int) -> Array:
	var recruits: Array = []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K"]
	var regions := ["north", "south", "east", "west", "midwest", "southwest", "northeast", "southeast"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 999999

	for i in range(count):
		var player_id := "p%05d" % i
		var position := positions[rng.randi() % positions.size()]
		var region := regions[rng.randi() % regions.size()]
		var baseline := rng.randf_range(45.0, 92.0)

		recruits.append({
			"player_id": player_id,
			"name": "Player %d" % i,
			"position": position,
			"home_region": region,
			"proximity_bias": rng.randf_range(0.2, 0.95),
			"hs_school_id": "hs_%04d" % (i % 50),
			"stats": {
				"speed": rng.randf_range(45.0, 92.0),
				"acceleration": rng.randf_range(45.0, 92.0),
				"agility": rng.randf_range(45.0, 92.0),
				"strength": rng.randf_range(45.0, 92.0),
				"awareness": rng.randf_range(45.0, 92.0),
				"stamina": rng.randf_range(50.0, 90.0),
				"injury_resistance": rng.randf_range(50.0, 90.0)
			},
			"potential": {
				"speed": rng.randf_range(55.0, 95.0),
				"acceleration": rng.randf_range(55.0, 95.0),
				"agility": rng.randf_range(55.0, 95.0),
				"strength": rng.randf_range(55.0, 95.0),
				"awareness": rng.randf_range(55.0, 95.0),
				"stamina": rng.randf_range(60.0, 95.0),
				"injury_resistance": rng.randf_range(60.0, 95.0)
			},
			"physicals": {
				"weight_lb": rng.randf_range(170.0, 300.0),
				"height_in": rng.randf_range(68.0, 78.0)
			},
			"ratings": {
				"composite_score": baseline
			}
		})

	return recruits

func _generate_colleges(count: int) -> Array:
	var colleges: Array = []
	var regions := ["north", "south", "east", "west", "midwest", "southwest", "northeast", "southeast"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 888888

	for i in range(count):
		colleges.append({
			"id": "c%04d" % i,
			"name": "College %d" % i,
			"region": regions[i % regions.size()],
			"eliteness": rng.randf_range(35.0, 97.0),
			"prestige": rng.randf_range(40.0, 95.0)
		})

	return colleges
