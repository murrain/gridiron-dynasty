extends SceneTree

## DIAGNOSTIC: Analyze why no releases occur in roster management
##
## This diagnostic script will:
## 1. Load actual simulation state from year 20+
## 2. Analyze player data distribution (eval_score, annual_value, age)
## 3. Calculate cap inefficiency for all players
## 4. Identify why no candidates meet the threshold

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("ROSTER RELEASE DIAGNOSTIC ANALYSIS")
	print("=".repeat(80))

	# Load configuration
	var cfg_path := "res://configs/sports/american_football/main.json"
	var cfg_file := FileAccess.open(cfg_path, FileAccess.READ)
	if not cfg_file:
		push_error("Cannot open config file: " + cfg_path)
		quit(1)
		return

	var main_cfg: Dictionary = JSON.parse_string(cfg_file.get_as_text())
	cfg_file.close()

	var rm_cfg: Dictionary = main_cfg.get("roster_management", {})
	print("\n[CONFIG VALUES]")
	print("  value_threshold: %.2f" % rm_cfg.get("value_threshold", 1.5))
	print("  age_decline_factor: %.3f" % rm_cfg.get("age_decline_factor", 0.02))
	print("  min_roster_size: %d" % rm_cfg.get("min_roster_size", 45))
	print("  target_fa_budget_min: $%.1fM" % rm_cfg.get("target_fa_budget_min", 30.0))
	print("  target_fa_budget_max: $%.1fM" % rm_cfg.get("target_fa_budget_max", 50.0))

	# Try to load world state from save file
	var world_state: Dictionary = {}

	# Check for saved world state
	var save_path := "user://world_state_year_20.json"
	if FileAccess.file_exists(save_path):
		print("\n[LOADING WORLD STATE]")
		print("  Loading from: %s" % save_path)
		var save_file := FileAccess.open(save_path, FileAccess.READ)
		if save_file:
			world_state = JSON.parse_string(save_file.get_as_text())
			save_file.close()
			print("  ✓ Loaded world state")
		else:
			print("  ✗ Failed to load save file")
	else:
		print("\n[WARNING] No saved world state found at: %s" % save_path)
		print("  Run integration test first to generate data")
		print("  This diagnostic will use SYNTHETIC test data instead")
		world_state = _create_synthetic_data()

	# Analyze roster data
	_analyze_rosters(world_state, main_cfg)

	print("\n" + "=".repeat(80))
	print("DIAGNOSTIC COMPLETE")
	print("=".repeat(80))

	quit()

func _create_synthetic_data() -> Dictionary:
	"""Create synthetic data that mimics year 20+ characteristics"""
	print("\n[CREATING SYNTHETIC TEST DATA]")

	var world_state := {
		"nfl_teams": [],
		"nfl_rosters": {},
		"league": {"cap_limit": 180.0}
	}

	# Create 2 test teams
	for team_idx in range(2):
		var team_id := "team_%03d" % team_idx
		world_state["nfl_teams"].append({"id": team_id, "name": "Team %d" % team_idx})

		# Create roster with diverse player profiles
		var players: Array = []

		# Profile 1: Young starter with good value
		for i in range(5):
			players.append({
				"id": "p_young_%d_%d" % [team_idx, i],
				"name": "Young Starter %d" % i,
				"position": ["QB", "WR", "CB", "EDGE", "OL"][i % 5],
				"age": 24 + (i % 4),
				"eval_score": 70.0 + randf() * 15.0,
				"draft_year": 18 + i,
				"contract": {
					"annual_value": 3.0 + randf() * 5.0,
					"signed_year": 20 + i,
					"years_remaining": 3
				}
			})

		# Profile 2: Prime veterans (27-30) with moderate contracts
		for i in range(8):
			players.append({
				"id": "p_prime_%d_%d" % [team_idx, i],
				"name": "Prime Vet %d" % i,
				"position": ["WR", "RB", "TE", "DL", "LB", "S", "CB", "OL"][i % 8],
				"age": 27 + (i % 4),
				"eval_score": 65.0 + randf() * 20.0,
				"draft_year": 12 + i,
				"contract": {
					"annual_value": 5.0 + randf() * 8.0,
					"signed_year": 18 + i,
					"years_remaining": 2
				}
			})

		# Profile 3: Aging veterans (31+) - potential release candidates
		for i in range(5):
			var age := 31 + (i % 7)
			var eval_score := 55.0 + randf() * 15.0
			players.append({
				"id": "p_aging_%d_%d" % [team_idx, i],
				"name": "Aging Vet %d" % i,
				"position": ["QB", "WR", "OL", "DL", "LB"][i % 5],
				"age": age,
				"eval_score": eval_score,
				"draft_year": 20 - age + 22,
				"contract": {
					"annual_value": 8.0 + randf() * 8.0,
					"signed_year": 15 + i,
					"years_remaining": 1
				}
			})

		world_state["nfl_rosters"][team_id] = {"players": players}

	print("  Created %d teams with synthetic rosters" % world_state["nfl_teams"].size())
	return world_state

func _analyze_rosters(world_state: Dictionary, main_cfg: Dictionary):
	print("\n[ROSTER ANALYSIS]")

	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	var rm_cfg: Dictionary = main_cfg.get("roster_management", {})

	var value_threshold := float(rm_cfg.get("value_threshold", 1.5))
	var age_decline_factor := float(rm_cfg.get("age_decline_factor", 0.02))

	var all_players: Array = []
	var total_candidates := 0
	var total_protected := 0
	var total_no_contract := 0

	print("  Teams: %d" % nfl_rosters.size())

	# Collect all players
	for team_id in nfl_rosters:
		var roster: Dictionary = nfl_rosters[team_id]
		var players: Array = roster.get("players", [])
		all_players.append_array(players)

	print("  Total players: %d" % all_players.size())

	if all_players.is_empty():
		print("  ✗ NO PLAYERS FOUND - Cannot analyze empty rosters!")
		return

	# Analyze player statistics
	var eval_scores: Array = []
	var annual_values: Array = []
	var ages: Array = []
	var cap_inefficiencies: Array = []

	var year := 20  # Assumed current year for diagnostic

	print("\n[PLAYER PROFILE BREAKDOWN]")
	print("  %-20s %4s %4s %8s %8s %8s" % ["Category", "Age", "Eval", "AnnVal", "ExpVal", "CapInef"])
	print("  " + "-".repeat(70))

	for player in all_players:
		var p: Dictionary = player
		var contract: Dictionary = p.get("contract", {})

		if contract.is_empty():
			total_no_contract += 1
			continue

		# Check rookie protection
		var signed_year := int(contract.get("signed_year", 0))
		var draft_year := int(p.get("draft_year", 0))
		var is_rookie := (signed_year == draft_year)
		var years_since_draft := year - draft_year

		if is_rookie and years_since_draft < 3:
			total_protected += 1
			continue

		var annual_value := float(contract.get("annual_value", 0.0))
		var eval_score := float(p.get("eval_score", 50.0))
		var age := int(p.get("age", 22))

		eval_scores.append(eval_score)
		annual_values.append(annual_value)
		ages.append(age)

		# Calculate cap inefficiency (same formula as RosterManagement)
		var age_penalty := 1.0
		if age > 30:
			age_penalty = 1.0 + (float(age - 30) * age_decline_factor)

		var expected_value := (eval_score / 100.0) * value_threshold
		var cap_inefficiency := 0.0
		if expected_value > 0.0:
			cap_inefficiency = (annual_value / expected_value) * age_penalty

		cap_inefficiencies.append(cap_inefficiency)

		# Show some examples
		if cap_inefficiencies.size() <= 10 or cap_inefficiency > 1.0:
			var status := "GOOD VALUE" if cap_inefficiency <= 1.0 else "RELEASE CANDIDATE"
			print("  %-20s %4d %4.0f $%7.2fM $%7.2fM %8.3f  %s" % [
				p.get("position", "??"),
				age,
				eval_score,
				annual_value,
				expected_value,
				cap_inefficiency,
				status
			])

	total_candidates = cap_inefficiencies.size()

	print("\n[SUMMARY STATISTICS]")
	print("  Total players analyzed: %d" % all_players.size())
	print("  Players w/o contracts: %d" % total_no_contract)
	print("  Protected rookies: %d" % total_protected)
	print("  Eligible for evaluation: %d" % total_candidates)

	if eval_scores.is_empty():
		print("  ✗ NO PLAYERS ELIGIBLE FOR EVALUATION")
		return

	# Calculate statistics
	var avg_eval := _calc_mean(eval_scores)
	var avg_annual := _calc_mean(annual_values)
	var avg_age := _calc_mean(ages)
	var avg_ineff := _calc_mean(cap_inefficiencies)

	print("\n  Average eval_score: %.1f" % avg_eval)
	print("  Average annual_value: $%.2fM" % avg_annual)
	print("  Average age: %.1f" % avg_age)
	print("  Average cap_inefficiency: %.3f" % avg_ineff)

	# Count release candidates (inefficiency > 1.0)
	var release_candidate_count := 0
	for ineff in cap_inefficiencies:
		if float(ineff) > 1.0:
			release_candidate_count += 1

	print("\n[RELEASE CANDIDATE THRESHOLD ANALYSIS]")
	print("  Threshold: cap_inefficiency > 1.0")
	print("  Players exceeding threshold: %d / %d (%.1f%%)" % [
		release_candidate_count,
		total_candidates,
		100.0 * release_candidate_count / max(1, total_candidates)
	])

	if release_candidate_count == 0:
		print("\n[ROOT CAUSE IDENTIFIED]")
		print("  ✗ NO PLAYERS EXCEED THRESHOLD")
		print("\n  DIAGNOSIS:")
		print("    The cap_inefficiency formula is:")
		print("      (annual_value / expected_value) * age_penalty")
		print("    Where:")
		print("      expected_value = (eval_score / 100) * value_threshold")
		print("      value_threshold = %.2f" % value_threshold)
		print("      age_penalty = 1.0 + (age - 30) * %.3f (if age > 30)" % age_decline_factor)
		print("\n    For a player to be a release candidate:")
		print("      cap_inefficiency > 1.0")
		print("      => annual_value / expected_value > 1.0 / age_penalty")
		print("      => annual_value > expected_value / age_penalty")
		print("\n    Example for average player:")
		print("      eval_score = %.1f" % avg_eval)
		print("      expected_value = (%.1f / 100) * %.2f = %.3f" % [avg_eval, value_threshold, (avg_eval / 100.0) * value_threshold])
		print("      age = %.0f, age_penalty = %.3f" % [avg_age, 1.0 if avg_age <= 30 else 1.0 + (avg_age - 30) * age_decline_factor])
		print("      threshold_cap = %.3f" % ((avg_eval / 100.0) * value_threshold))
		print("      actual_cap = $%.2fM" % avg_annual)
		print("\n    ISSUE: Annual values are likely TOO LOW compared to eval scores!")
		print("    OR: value_threshold (%.2f) is TOO HIGH" % value_threshold)
	else:
		print("\n[GOOD NEWS]")
		print("  ✓ System is identifying release candidates correctly")
		print("  Next: Check why releases aren't executing")

func _calc_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / values.size()
