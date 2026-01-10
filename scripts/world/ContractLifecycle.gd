extends RefCounted
class_name ContractLifecycle

const STATUS_UNSIGNED := "unsigned"
const STATUS_SIGNED := "signed"
const STATUS_EXPIRED := "expired"
const STATUS_RELEASED := "released"

# Contract lifecycle transitions are explicit and deterministic. Each transition
# returns a cap impact delta so accounting stays traceable.

static func transition_unsigned_to_signed(
	contract: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	# Trigger examples: free agency offer accepted, draft pick signed, extension accepted.
	# Rationale: signing moves a player onto a roster and activates cap charges.
	var next := contract.duplicate(true)
	next["status"] = STATUS_SIGNED
	next["signed_year"] = year
	next["trigger"] = trigger
	var annual_value := float(next.get("annual_value", 0.0))

	return {
		"transition": "unsigned_to_signed",
		"contract": next,
		"cap_impact": {
			"annual_value_delta": annual_value,
			"dead_money_delta": 0.0
		},
		"note": "Signing adds the annual value to cap accounting."
	}

static func transition_signed_to_expired(
	contract: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	# Trigger examples: contract end_year < current year, season rollover with no options.
	# Rationale: expiration ends active cap charges while guarantees are handled elsewhere.
	var next := contract.duplicate(true)
	next["status"] = STATUS_EXPIRED
	next["expired_year"] = year
	next["trigger"] = trigger
	var annual_value := float(next.get("annual_value", 0.0))

	return {
		"transition": "signed_to_expired",
		"contract": next,
		"cap_impact": {
			"annual_value_delta": -annual_value,
			"dead_money_delta": 0.0
		},
		"note": "Expiration removes the annual value from cap accounting."
	}

static func transition_signed_to_released(
	contract: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	# Trigger examples: roster cut, injury settlement, waived after preseason.
	# Rationale: release removes the active cap hit but may leave guarantees as dead money.
	var next := contract.duplicate(true)
	next["status"] = STATUS_RELEASED
	next["released_year"] = year
	next["trigger"] = trigger
	var annual_value := float(next.get("annual_value", 0.0))
	var guaranteed := float(next.get("guaranteed_value", 0.0))

	return {
		"transition": "signed_to_released",
		"contract": next,
		"cap_impact": {
			"annual_value_delta": -annual_value,
			"dead_money_delta": guaranteed
		},
		"note": "Release drops annual value; guarantees stay as dead money if modeled."
	}
