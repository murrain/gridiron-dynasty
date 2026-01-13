extends Node
## Unit tests for ContractNegotiation module
##
## Tests contract demand generation, offer creation, and offer evaluation.

var tests_passed := 0
var tests_failed := 0


func _ready() -> void:
	print("\n=== ContractNegotiation Unit Tests ===\n")

	_test_generate_player_demand_elite_qb()
	_test_generate_player_demand_aging_rb()
	_test_generate_player_demand_young_depth()
	_test_generate_offer_fair()
	_test_generate_offer_aggressive()
	_test_generate_offer_insufficient_cap()
	_test_evaluate_offer_accepts_fair()
	_test_evaluate_offer_rejects_low()
	_test_evaluate_offer_rejects_low_guarantees()

	print("\n=== Test Summary ===")
	print("PASSED: %d" % tests_passed)
	print("FAILED: %d" % tests_failed)
	print("TOTAL:  %d" % (tests_passed + tests_failed))

	if tests_failed == 0:
		print("\n✓ All tests PASSED!")
	else:
		print("\n✗ Some tests FAILED")

	get_tree().quit()


func _assert(condition: bool, test_name: String, message: String) -> void:
	if condition:
		tests_passed += 1
		print("[PASS] %s: %s" % [test_name, message])
	else:
		tests_failed += 1
		print("[FAIL] %s: %s" % [test_name, message])


func _test_generate_player_demand_elite_qb() -> void:
	var test_name := "generate_player_demand_elite_qb"

	# Setup: Elite QB in prime (age 27)
	var player := {
		"id": "player-qb-elite",
		"position": "QB",
		"age": 27,
		"eval_score": 88.0
	}

	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()

	var demand := ContractNegotiation.generate_player_demand(player, positions_cfg, main_cfg)

	# Verify demand structure
	_assert(demand.has("minimum_annual_value"), test_name, "Has minimum_annual_value")
	_assert(demand.has("desired_years"), test_name, "Has desired_years")
	_assert(demand.has("guaranteed_demand"), test_name, "Has guaranteed_demand")

	# Verify elite QB gets premium value
	var aav := float(demand.get("minimum_annual_value", 0.0))
	_assert(aav > 10.0, test_name, "Elite QB AAV > 10M (got %.2f)" % aav)

	# Verify elite player wants longer deal
	var years := int(demand.get("desired_years", 0))
	_assert(years >= 4, test_name, "Elite QB wants 4+ years (got %d)" % years)

	# Verify high guarantee percentage
	var guaranteed := float(demand.get("guaranteed_demand", 0.0))
	var total_value := aav * years
	var guarantee_pct := guaranteed / total_value if total_value > 0 else 0.0
	_assert(guarantee_pct >= 0.55, test_name, "Elite QB guarantees >= 55%% (got %.1f%%)" % (guarantee_pct * 100))


func _test_generate_player_demand_aging_rb() -> void:
	var test_name := "generate_player_demand_aging_rb"

	# Setup: Aging RB (age 30, past decline)
	var player := {
		"id": "player-rb-aging",
		"position": "RB",
		"age": 30,
		"eval_score": 72.0
	}

	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()

	var demand := ContractNegotiation.generate_player_demand(player, positions_cfg, main_cfg)

	var aav := float(demand.get("minimum_annual_value", 0.0))
	var years := int(demand.get("desired_years", 0))

	# Verify RB position discount applies
	# RBs get 0.8x multiplier, and age 30 is past decline start (27 for RBs)
	_assert(aav < 8.0, test_name, "Aging RB AAV discounted (got %.2f)" % aav)

	# Verify shorter contract for aging player
	_assert(years <= 2, test_name, "Aging RB wants short deal (got %d years)" % years)


func _test_generate_player_demand_young_depth() -> void:
	var test_name := "generate_player_demand_young_depth"

	# Setup: Young depth player
	var player := {
		"id": "player-depth",
		"position": "LB",
		"age": 24,
		"eval_score": 62.0
	}

	var positions_cfg := _load_positions_config()
	var main_cfg := _load_main_config()

	var demand := ContractNegotiation.generate_player_demand(player, positions_cfg, main_cfg)

	var aav := float(demand.get("minimum_annual_value", 0.0))
	var years := int(demand.get("desired_years", 0))

	# Verify depth discount applies
	_assert(aav < 5.0, test_name, "Depth player AAV low (got %.2f)" % aav)
	_assert(aav >= 0.5, test_name, "Depth player AAV above minimum (got %.2f)" % aav)

	# Verify reasonable contract length
	_assert(years >= 2 and years <= 3, test_name, "Depth player wants 2-3 years (got %d)" % years)


func _test_generate_offer_fair() -> void:
	var test_name := "generate_offer_fair"

	# Setup: Team makes fair offer matching demand
	var team := {
		"id": "NYJ",
		"cap_space": 50.0
	}

	var player := {
		"id": "player-wr",
		"position": "WR",
		"age": 26,
		"eval_score": 75.0
	}

	var demand := {
		"minimum_annual_value": 12.0,
		"desired_years": 4,
		"guaranteed_demand": 24.0
	}

	var aggression := 1.0  # Neutral: meet demand exactly

	var offer := ContractNegotiation.generate_offer(team, player, demand, aggression)

	# Verify offer structure
	_assert(not offer.is_empty(), test_name, "Offer generated successfully")
	_assert(offer.has("annual_value"), test_name, "Has annual_value")
	_assert(offer.has("cap_hit_year_1"), test_name, "Has cap_hit_year_1")

	var aav := float(offer.get("annual_value", 0.0))
	var cap_hit := float(offer.get("cap_hit_year_1", 0.0))

	# Verify offer meets demand
	_assert(abs(aav - 12.0) < 0.1, test_name, "AAV matches demand (got %.2f)" % aav)

	# Verify cap compliance
	_assert(cap_hit <= team.cap_space, test_name, "Cap hit within cap space (%.2f <= %.2f)" % [cap_hit, team.cap_space])

	# Verify offer quality
	var quality := float(offer.get("offer_quality", 0.0))
	_assert(abs(quality - 1.0) < 0.01, test_name, "Offer quality = 1.0 for fair offer (got %.2f)" % quality)


func _test_generate_offer_aggressive() -> void:
	var test_name := "generate_offer_aggressive"

	var team := {
		"id": "KC",
		"cap_space": 60.0
	}

	var player := {
		"id": "player-edge",
		"position": "EDGE",
		"age": 25,
		"eval_score": 82.0
	}

	var demand := {
		"minimum_annual_value": 15.0,
		"desired_years": 5,
		"guaranteed_demand": 45.0
	}

	var aggression := 1.2  # Aggressive: 20% over demand

	var offer := ContractNegotiation.generate_offer(team, player, demand, aggression)

	_assert(not offer.is_empty(), test_name, "Aggressive offer generated")

	var aav := float(offer.get("annual_value", 0.0))
	var expected_aav := 15.0 * 1.2

	_assert(abs(aav - expected_aav) < 0.1, test_name, "AAV 20%% over demand (got %.2f, expected %.2f)" % [aav, expected_aav])

	var quality := float(offer.get("offer_quality", 0.0))
	_assert(quality > 1.15, test_name, "Offer quality > 1.15 for aggressive offer (got %.2f)" % quality)


func _test_generate_offer_insufficient_cap() -> void:
	var test_name := "generate_offer_insufficient_cap"

	# Setup: Team with insufficient cap space
	var team := {
		"id": "CAP",
		"cap_space": 5.0  # Not enough for a decent offer
	}

	var player := {
		"id": "player-expensive",
		"position": "QB",
		"age": 28,
		"eval_score": 85.0
	}

	var demand := {
		"minimum_annual_value": 25.0,
		"desired_years": 5,
		"guaranteed_demand": 75.0
	}

	var aggression := 1.0

	var offer := ContractNegotiation.generate_offer(team, player, demand, aggression)

	# Verify no offer when team can't afford it
	_assert(offer.is_empty(), test_name, "No offer generated when cap insufficient")


func _test_evaluate_offer_accepts_fair() -> void:
	var test_name := "evaluate_offer_accepts_fair"

	var demand := {
		"minimum_annual_value": 10.0,
		"desired_years": 4,
		"guaranteed_demand": 20.0
	}

	var offer := {
		"annual_value": 10.5,  # 105% of demand
		"guaranteed_value": 21.0,  # 105% of guarantee demand
		"years_total": 4
	}

	var evaluation := ContractNegotiation.evaluate_offer(offer, demand)

	_assert(evaluation.has("accept"), test_name, "Has accept field")
	_assert(evaluation.has("score"), test_name, "Has score field")
	_assert(evaluation.has("reason"), test_name, "Has reason field")

	var accept := bool(evaluation.get("accept", false))
	var score := float(evaluation.get("score", 0.0))
	var reason := String(evaluation.get("reason", ""))

	_assert(accept, test_name, "Player accepts fair offer")
	_assert(score >= 0.85, test_name, "Score >= 0.85 for fair offer (got %.2f)" % score)
	_assert(reason == "accepted", test_name, "Reason is 'accepted' (got '%s')" % reason)


func _test_evaluate_offer_rejects_low() -> void:
	var test_name := "evaluate_offer_rejects_low"

	var demand := {
		"minimum_annual_value": 15.0,
		"desired_years": 4,
		"guaranteed_demand": 30.0
	}

	var offer := {
		"annual_value": 11.0,  # Only 73% of demand
		"guaranteed_value": 22.0,  # Only 73% of guarantee demand
		"years_total": 4
	}

	var evaluation := ContractNegotiation.evaluate_offer(offer, demand)

	var accept := bool(evaluation.get("accept", false))
	var score := float(evaluation.get("score", 0.0))

	_assert(not accept, test_name, "Player rejects low offer")
	_assert(score < 0.85, test_name, "Score < 0.85 for low offer (got %.2f)" % score)


func _test_evaluate_offer_rejects_low_guarantees() -> void:
	var test_name := "evaluate_offer_rejects_low_guarantees"

	var demand := {
		"minimum_annual_value": 12.0,
		"desired_years": 4,
		"guaranteed_demand": 30.0
	}

	var offer := {
		"annual_value": 13.0,  # Good AAV (108%)
		"guaranteed_value": 20.0,  # Low guarantees (67%)
		"years_total": 4
	}

	var evaluation := ContractNegotiation.evaluate_offer(offer, demand)

	var accept := bool(evaluation.get("accept", false))
	var reason := String(evaluation.get("reason", ""))

	_assert(not accept, test_name, "Player rejects offer with low guarantees")
	# Reason might be "low_guarantees" or "overall_insufficient" depending on exact math
	_assert(reason in ["low_guarantees", "overall_insufficient"], test_name, "Reason indicates problem (got '%s')" % reason)


## Load positions config from file
func _load_positions_config() -> Dictionary:
	var config_path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/positions.json"
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("ERROR: Cannot load positions.json")
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		print("ERROR: Cannot parse positions.json")
		return {}

	return json.data


## Load main config from file
func _load_main_config() -> Dictionary:
	var config_path := "/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team4-offseason/architect/configs/sports/american_football/main.json"
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("ERROR: Cannot load main.json")
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		print("ERROR: Cannot parse main.json")
		return {}

	return json.data
