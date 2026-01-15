## GdUnit4 test suite for ContractNegotiation
##
## Tests contract demand generation, offer creation, and offer evaluation.
## Migrated from test_contract_negotiation.gd
extends GdUnitTestSuite

const ContractNegotiation = preload("res://scripts/world/ContractNegotiation.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _positions_cfg: Dictionary
var _main_cfg: Dictionary


func before() -> void:
	var config_service := ConfigService.new()
	_positions_cfg = config_service.get_config("positions")
	_main_cfg = config_service.get_config("main")


func test_generate_player_demand_elite_qb() -> void:
	var player := {
		"id": "player-qb-elite",
		"position": "QB",
		"age": 27,
		"eval_score": 88.0
	}

	var demand := ContractNegotiation.generate_player_demand(player, _positions_cfg, _main_cfg)

	assert_bool(demand.has("minimum_annual_value")).is_true()
	assert_bool(demand.has("desired_years")).is_true()
	assert_bool(demand.has("guaranteed_demand")).is_true()

	var aav := float(demand.get("minimum_annual_value", 0.0))
	assert_float(aav).is_greater(10.0)

	var years := int(demand.get("desired_years", 0))
	assert_int(years).is_greater_equal(4)

	var guaranteed: float = float(demand.get("guaranteed_demand", 0.0))
	var total_value: float = aav * years
	var guarantee_pct: float = guaranteed / total_value if total_value > 0.0 else 0.0
	assert_float(guarantee_pct).is_greater_equal(0.55)


func test_generate_player_demand_aging_rb() -> void:
	var player := {
		"id": "player-rb-aging",
		"position": "RB",
		"age": 30,
		"eval_score": 72.0
	}

	var demand := ContractNegotiation.generate_player_demand(player, _positions_cfg, _main_cfg)

	var aav := float(demand.get("minimum_annual_value", 0.0))
	var years := int(demand.get("desired_years", 0))

	assert_float(aav).is_less(8.0)
	assert_int(years).is_less_equal(2)


func test_generate_player_demand_young_depth() -> void:
	var player := {
		"id": "player-depth",
		"position": "LB",
		"age": 24,
		"eval_score": 62.0
	}

	var demand := ContractNegotiation.generate_player_demand(player, _positions_cfg, _main_cfg)

	var aav := float(demand.get("minimum_annual_value", 0.0))
	var years := int(demand.get("desired_years", 0))

	assert_float(aav).is_less(5.0)
	assert_float(aav).is_greater_equal(0.5)
	assert_int(years).is_between(2, 3)


func test_generate_offer_fair() -> void:
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

	var aggression := 1.0

	var offer := ContractNegotiation.generate_offer(team, player, demand, aggression)

	assert_bool(not offer.is_empty()).is_true()
	assert_bool(offer.has("annual_value")).is_true()
	assert_bool(offer.has("cap_hit_year_1")).is_true()

	var aav := float(offer.get("annual_value", 0.0))
	var cap_hit := float(offer.get("cap_hit_year_1", 0.0))

	assert_float(aav).is_equal_approx(12.0, 0.1)
	assert_float(cap_hit).is_less_equal(team.cap_space)

	var quality := float(offer.get("offer_quality", 0.0))
	assert_float(quality).is_equal_approx(1.0, 0.01)


func test_generate_offer_aggressive() -> void:
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

	var aggression := 1.2

	var offer := ContractNegotiation.generate_offer(team, player, demand, aggression)

	assert_bool(not offer.is_empty()).is_true()

	var aav := float(offer.get("annual_value", 0.0))
	var expected_aav := 15.0 * 1.2

	assert_float(aav).is_equal_approx(expected_aav, 0.1)

	var quality := float(offer.get("offer_quality", 0.0))
	assert_float(quality).is_greater(1.15)


func test_generate_offer_insufficient_cap() -> void:
	var team := {
		"id": "CAP",
		"cap_space": 5.0
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

	assert_bool(offer.is_empty()).is_true()


func test_evaluate_offer_accepts_fair() -> void:
	var demand := {
		"minimum_annual_value": 10.0,
		"desired_years": 4,
		"guaranteed_demand": 20.0
	}

	var offer := {
		"annual_value": 10.5,
		"guaranteed_value": 21.0,
		"years_total": 4
	}

	var evaluation := ContractNegotiation.evaluate_offer(offer, demand)

	assert_bool(evaluation.has("accept")).is_true()
	assert_bool(evaluation.has("score")).is_true()
	assert_bool(evaluation.has("reason")).is_true()

	var accept := bool(evaluation.get("accept", false))
	var score := float(evaluation.get("score", 0.0))
	var reason := String(evaluation.get("reason", ""))

	assert_bool(accept).is_true()
	assert_float(score).is_greater_equal(0.85)
	assert_str(reason).is_equal("accepted")


func test_evaluate_offer_rejects_low() -> void:
	var demand := {
		"minimum_annual_value": 15.0,
		"desired_years": 4,
		"guaranteed_demand": 30.0
	}

	var offer := {
		"annual_value": 11.0,
		"guaranteed_value": 22.0,
		"years_total": 4
	}

	var evaluation := ContractNegotiation.evaluate_offer(offer, demand)

	var accept := bool(evaluation.get("accept", false))
	var score := float(evaluation.get("score", 0.0))

	assert_bool(accept).is_false()
	assert_float(score).is_less(0.85)


func test_evaluate_offer_rejects_low_guarantees() -> void:
	var demand := {
		"minimum_annual_value": 12.0,
		"desired_years": 4,
		"guaranteed_demand": 30.0
	}

	var offer := {
		"annual_value": 13.0,
		"guaranteed_value": 20.0,
		"years_total": 4
	}

	var evaluation := ContractNegotiation.evaluate_offer(offer, demand)

	var accept := bool(evaluation.get("accept", false))
	var reason := String(evaluation.get("reason", ""))

	assert_bool(accept).is_false()
	assert_bool(reason in ["low_guarantees", "overall_insufficient"]).is_true()
