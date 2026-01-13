extends Node
## Demo script showing Free Agency system in action
##
## This demonstrates the complete FA pipeline with realistic scenarios.

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("FREE AGENCY SYSTEM DEMONSTRATION")
	print("=".repeat(70) + "\n")

	demo_contract_negotiation()
	demo_franchise_tag()
	demo_free_agency_simulation()

	print("\n" + "=".repeat(70))
	print("DEMONSTRATION COMPLETE")
	print("=".repeat(70) + "\n")

	get_tree().quit()


func demo_contract_negotiation() -> void:
	print("\n[DEMO 1] Contract Negotiation\n")

	# Load configs
	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()

	# Create test players
	var elite_qb := {"id": "qb-1", "position": "QB", "age": 27, "eval_score": 88.0}
	var aging_rb := {"id": "rb-1", "position": "RB", "age": 30, "eval_score": 72.0}
	var depth_lb := {"id": "lb-1", "position": "LB", "age": 24, "eval_score": 62.0}

	print("Player Demands:\n")

	# Elite QB demand
	var qb_demand := ContractNegotiation.generate_player_demand(elite_qb, positions_cfg, main_cfg)
	print("  Elite QB (age 27, rating 88):")
	print("    AAV: $%.2fM" % qb_demand.get("minimum_annual_value", 0.0))
	print("    Years: %d" % qb_demand.get("desired_years", 0))
	print("    Guaranteed: $%.2fM" % qb_demand.get("guaranteed_demand", 0.0))

	# Aging RB demand
	var rb_demand := ContractNegotiation.generate_player_demand(aging_rb, positions_cfg, main_cfg)
	print("\n  Aging RB (age 30, rating 72):")
	print("    AAV: $%.2fM" % rb_demand.get("minimum_annual_value", 0.0))
	print("    Years: %d" % rb_demand.get("desired_years", 0))
	print("    Guaranteed: $%.2fM" % rb_demand.get("guaranteed_demand", 0.0))

	# Depth LB demand
	var lb_demand := ContractNegotiation.generate_player_demand(depth_lb, positions_cfg, main_cfg)
	print("\n  Depth LB (age 24, rating 62):")
	print("    AAV: $%.2fM" % lb_demand.get("minimum_annual_value", 0.0))
	print("    Years: %d" % lb_demand.get("desired_years", 0))
	print("    Guaranteed: $%.2fM" % lb_demand.get("guaranteed_demand", 0.0))

	# Generate and evaluate offer
	print("\n\nOffer Evaluation:\n")

	var team := {"id": "KC", "cap_space": 50.0}
	var fair_offer := ContractNegotiation.generate_offer(team, elite_qb, qb_demand, 1.05)

	print("  Kansas City offers Elite QB:")
	print("    AAV: $%.2fM (105%% of demand)" % fair_offer.get("annual_value", 0.0))
	print("    Years: %d" % fair_offer.get("years_total", 0))
	print("    Guaranteed: $%.2fM" % fair_offer.get("guaranteed_value", 0.0))
	print("    Year 1 cap hit: $%.2fM" % fair_offer.get("cap_hit_year_1", 0.0))

	var evaluation := ContractNegotiation.evaluate_offer(fair_offer, qb_demand)
	print("\n  Player Decision:")
	print("    Accept: %s" % ("YES" if evaluation.get("accept", false) else "NO"))
	print("    Score: %.2f (threshold: 0.85)" % evaluation.get("score", 0.0))
	print("    Reason: %s" % evaluation.get("reason", ""))


func demo_franchise_tag() -> void:
	print("\n\n[DEMO 2] Franchise Tag System\n")

	var world_state := _create_demo_world()

	# Add high-salary QBs for tag calculation
	print("Top 5 QB Salaries in League:")
	var qb_salaries := [28.0, 25.0, 22.0, 20.0, 18.0]
	for i in range(qb_salaries.size()):
		var qb := {"id": "qb-top-%d" % i, "position": "QB", "age": 27, "eval_score": 85.0}
		qb["contract"] = {"status": "signed", "annual_value": qb_salaries[i]}
		world_state["nfl_rosters"]["TEAM_%d" % i] = {"players": [qb]}
		print("  %d. $%.2fM" % [i + 1, qb_salaries[i]])

	var average := (28.0 + 25.0 + 22.0 + 20.0 + 18.0) / 5.0
	print("\nTop 5 Average: $%.2fM" % average)

	# Add player to tag
	var target_qb := {"id": "qb-tag-target", "position": "QB", "age": 26, "eval_score": 82.0}
	target_qb["contract"] = {"status": "expired", "years_remaining": 0}
	world_state["nfl_rosters"]["SF"]["players"] = [target_qb]
	world_state["nfl_teams"][0]["cap_space"] = 100.0

	# Apply franchise tag
	print("\nSan Francisco applies non-exclusive franchise tag to QB:")
	var league_cfg := _load_league_config()
	var tag := FreeAgency.apply_franchise_tag(
		world_state,
		"SF",
		"qb-tag-target",
		"non_exclusive",
		2024,
		league_cfg
	)

	if not tag.is_empty():
		print("  Tag Type: %s" % tag.get("tag_type", ""))
		print("  Salary: $%.2fM" % tag.get("salary", 0.0))
		print("  Years: 1 (fully guaranteed)")
		print("\nTag stored in world_state['franchise_tags'][2024]['SF']")
		print("NO modification to Team.gd model!")

		# Verify storage
		var stored := world_state.get("franchise_tags", {}).get(2024, {}).get("SF", {})
		print("\nVerification:")
		print("  Player ID: %s" % stored.get("player_id", ""))
		print("  Stored in world_state: %s" % ("YES" if not stored.is_empty() else "NO"))


func demo_free_agency_simulation() -> void:
	print("\n\n[DEMO 3] Free Agency Simulation\n")

	var world_state := _create_demo_world()

	# Add free agents
	var free_agents := [
		{"id": "fa-wr-1", "position": "WR", "age": 26, "eval_score": 78.0},
		{"id": "fa-edge-1", "position": "EDGE", "age": 25, "eval_score": 82.0},
		{"id": "fa-cb-1", "position": "CB", "age": 27, "eval_score": 75.0}
	]

	print("Free Agents Entering Market:\n")
	for fa in free_agents:
		var fa_dict := fa as Dictionary
		fa_dict["contract"] = {"status": "expired", "years_remaining": 0}
		world_state["nfl_rosters"]["FA"]["players"].append(fa_dict)
		print("  - %s, %s, Age %d, Rating %.1f" % [
			fa_dict.get("id", ""),
			fa_dict.get("position", ""),
			fa_dict.get("age", 0),
			fa_dict.get("eval_score", 0.0)
		])

	# Give teams cap space
	for team in world_state["nfl_teams"]:
		team["cap_space"] = 40.0

	# Run free agency
	print("\nRunning Free Agency Simulation...")
	print("(Seed: 123456 for deterministic results)\n")

	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()
	var stats_cfg := {}
	var league_cfg := _load_league_config()

	var result := FreeAgency.run_free_agency(
		world_state,
		2024,
		123456,
		positions_cfg,
		main_cfg,
		stats_cfg,
		league_cfg
	)

	# Show results
	print("Results:")
	print("  Signings: %d" % result["signings"].size())
	print("  Unsigned: %d" % result["unsigned"].size())
	print("  Total Spent: $%.2fM" % result.get("total_spent", 0.0))

	if result["signings"].size() > 0:
		print("\n  Signed Players:")
		for signing in result["signings"]:
			var signing_dict := signing as Dictionary
			var contract := signing_dict.get("contract", {}) as Dictionary
			print("    - %s → %s ($%.2fM AAV, %d years)" % [
				signing_dict.get("player_id", ""),
				signing_dict.get("team_id", ""),
				contract.get("annual_value", 0.0),
				contract.get("years_total", 0)
			])

	# Verify determinism
	print("\n\nDeterminism Test:")
	print("  Running simulation again with same seed...")

	var world_state_2 := _create_demo_world()
	for fa in free_agents:
		var fa_copy := fa.duplicate(true)
		fa_copy["contract"] = {"status": "expired", "years_remaining": 0}
		world_state_2["nfl_rosters"]["FA"]["players"].append(fa_copy)

	for team in world_state_2["nfl_teams"]:
		team["cap_space"] = 40.0

	var result2 := FreeAgency.run_free_agency(
		world_state_2,
		2024,
		123456,  # Same seed
		positions_cfg,
		main_cfg,
		stats_cfg,
		league_cfg
	)

	var match := (
		result["signings"].size() == result2["signings"].size() and
		result["unsigned"].size() == result2["unsigned"].size()
	)

	print("  Results Match: %s" % ("YES" if match else "NO"))
	print("  Signings: %d vs %d" % [result["signings"].size(), result2["signings"].size()])
	print("  Unsigned: %d vs %d" % [result["unsigned"].size(), result2["unsigned"].size()])


## Helper: Create demo world
func _create_demo_world() -> Dictionary:
	return {
		"nfl_rosters": {
			"KC": {"players": []},
			"SF": {"players": []},
			"BUF": {"players": []},
			"FA": {"players": []}
		},
		"nfl_teams": [
			{"id": "KC", "cap_space": 40.0},
			{"id": "SF", "cap_space": 50.0},
			{"id": "BUF", "cap_space": 30.0}
		],
		"franchise_tags": {},
		"free_agent_pool": {},
		"contract_negotiation_history": {}
	}


## Helper: Load positions config
func _load_positions_config() -> Dictionary:
	var path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/positions.json"
	return _load_json_file(path)


## Helper: Load main config
func _load_main_config() -> Dictionary:
	var path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/main.json"
	return _load_json_file(path)


## Helper: Load league config
func _load_league_config() -> Dictionary:
	var path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/world/league.json"
	return _load_json_file(path)


## Helper: Load JSON file
func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("ERROR: Cannot load %s" % path)
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		print("ERROR: Cannot parse %s" % path)
		return {}

	return json.data
