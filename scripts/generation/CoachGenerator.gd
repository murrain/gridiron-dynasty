extends RefCounted
class_name CoachGenerator

## Coach Generator
##
## Generates coaches with varied personality types, schemes, and tolerances.
##
## Coach Properties Generated:
##   - Coaching ability (0-100): Overall coaching skill
##   - Recruiting skill (0-100): Ability to attract talent
##   - Player development (0-100): Ability to improve players
##   - Experience years: Years of coaching experience
##   - Offensive scheme: west_coast, power_run, spread_option, air_raid, zone_run, pro_style
##   - Defensive scheme: 4_3_under, 3_4_two_gap, cover_2, cover_3, press_man, tampa_2, aggressive_blitz
##   - Character tolerance: strict, moderate, lenient, win_now
##   - Medical tolerance: risk_averse, cautious, moderate_risk, aggressive
##   - Scheme rigidity: 0.5 (flexible) to 1.2 (rigid)
##
## RNG Pattern: ~8-10 calls per coach
##   - Call 1: Coaching ability
##   - Call 2: Recruiting skill
##   - Call 3: Player development
##   - Call 4: Experience years
##   - Call 5: Offensive scheme
##   - Call 6: Defensive scheme
##   - Call 7: Character tolerance
##   - Call 8: Medical tolerance
##   - Call 9: Scheme rigidity
##   - Call 10: Specialty position

const OFFENSIVE_SCHEMES := [
	"west_coast",
	"power_run",
	"spread_option",
	"air_raid",
	"zone_run",
	"pro_style"
]

const DEFENSIVE_SCHEMES := [
	"4_3_under",
	"3_4_two_gap",
	"cover_2",
	"cover_3",
	"press_man",
	"tampa_2",
	"aggressive_blitz"
]

const CHARACTER_TOLERANCES := [
	"strict",
	"moderate",
	"lenient",
	"win_now"
]

const MEDICAL_TOLERANCES := [
	"risk_averse",
	"cautious",
	"moderate_risk",
	"aggressive"
]

const SPECIALTY_POSITIONS := [
	"QB",
	"Offense",
	"Defense",
	"RB",
	"WR",
	"OL",
	"DL",
	"LB",
	"DB"
]

## Weighted distributions for tolerances
## Higher weight = more likely
const CHARACTER_TOLERANCE_WEIGHTS := {
	"strict": 0.15,
	"moderate": 0.50,
	"lenient": 0.25,
	"win_now": 0.10
}

const MEDICAL_TOLERANCE_WEIGHTS := {
	"risk_averse": 0.15,
	"cautious": 0.45,
	"moderate_risk": 0.30,
	"aggressive": 0.10
}


## Generate a coach dictionary with randomized attributes
##
## @param rng: RandomNumberGenerator for determinism
## @param coach_id: Unique identifier for the coach
## @param config: Optional configuration overrides
## @return Dictionary: Coach data ready for assignment to team
static func generate_coach(
	rng: RandomNumberGenerator,
	coach_id: String,
	config: Dictionary = {}
) -> Dictionary:
	# Get config parameters with defaults
	var ability_min := float(config.get("ability_min", 35.0))
	var ability_max := float(config.get("ability_max", 95.0))
	var exp_min := int(config.get("experience_min", 1))
	var exp_max := int(config.get("experience_max", 35))
	var rigidity_min := float(config.get("rigidity_min", 0.5))
	var rigidity_max := float(config.get("rigidity_max", 1.2))

	# RNG Call 1-3: Core coaching abilities
	var coaching_ability := rng.randf_range(ability_min, ability_max)
	var recruiting_skill := rng.randf_range(ability_min, ability_max)
	var player_development := rng.randf_range(ability_min, ability_max)

	# RNG Call 4: Experience (correlated with coaching ability)
	var exp_base := rng.randi_range(exp_min, exp_max)
	# Higher ability coaches tend to have more experience
	var exp_bonus := int((coaching_ability - 50.0) / 10.0)
	var experience_years := clampi(exp_base + exp_bonus, exp_min, exp_max)

	# RNG Call 5-6: Schemes (uniform random)
	var offensive_scheme := OFFENSIVE_SCHEMES[rng.randi() % OFFENSIVE_SCHEMES.size()]
	var defensive_scheme := DEFENSIVE_SCHEMES[rng.randi() % DEFENSIVE_SCHEMES.size()]

	# RNG Call 7-8: Tolerances (weighted random)
	var character_tolerance := _weighted_pick(CHARACTER_TOLERANCES, CHARACTER_TOLERANCE_WEIGHTS, rng)
	var medical_tolerance := _weighted_pick(MEDICAL_TOLERANCES, MEDICAL_TOLERANCE_WEIGHTS, rng)

	# RNG Call 9: Scheme rigidity
	var scheme_rigidity := rng.randf_range(rigidity_min, rigidity_max)

	# RNG Call 10: Specialty position
	var specialty_position := SPECIALTY_POSITIONS[rng.randi() % SPECIALTY_POSITIONS.size()]

	return {
		"id": coach_id,
		"first_name": "",  # To be filled by name generator
		"last_name": "",   # To be filled by name generator
		"role": "Head Coach",
		"coaching_ability": coaching_ability,
		"recruiting_skill": recruiting_skill,
		"player_development": player_development,
		"experience_years": experience_years,
		"specialty_position": specialty_position,
		"offensive_scheme": offensive_scheme,
		"defensive_scheme": defensive_scheme,
		"scheme_rigidity": scheme_rigidity,
		"character_tolerance": character_tolerance,
		"medical_tolerance": medical_tolerance
	}


## Generate a head coach with attributes influenced by team tier/eliteness
##
## Elite programs attract better coaches with higher abilities.
##
## @param rng: RandomNumberGenerator for determinism
## @param coach_id: Unique identifier for the coach
## @param eliteness: Team eliteness (0-100), affects coach quality
## @param config: Optional configuration overrides
## @return Dictionary: Coach data
static func generate_coach_for_team(
	rng: RandomNumberGenerator,
	coach_id: String,
	eliteness: float,
	config: Dictionary = {}
) -> Dictionary:
	# Scale ability ranges based on eliteness
	# Elite programs (90+) get coaches with higher min abilities
	var eliteness_bonus := (eliteness - 50.0) / 100.0 * 20.0  # -10 to +10 range

	var base_ability_min := float(config.get("ability_min", 35.0))
	var base_ability_max := float(config.get("ability_max", 95.0))

	var adjusted_config := config.duplicate()
	adjusted_config["ability_min"] = clampf(base_ability_min + eliteness_bonus, 25.0, 75.0)
	adjusted_config["ability_max"] = clampf(base_ability_max + eliteness_bonus * 0.5, 60.0, 99.0)

	return generate_coach(rng, coach_id, adjusted_config)


## Generate coaching staff for a team (head coach + coordinators)
##
## @param rng: RandomNumberGenerator for determinism
## @param team_id: Team identifier prefix for coach IDs
## @param eliteness: Team eliteness (0-100)
## @param config: Optional configuration
## @return Dictionary: Coaching staff with head_coach, oc, dc keys
static func generate_coaching_staff(
	rng: RandomNumberGenerator,
	team_id: String,
	eliteness: float,
	config: Dictionary = {}
) -> Dictionary:
	var head_coach := generate_coach_for_team(rng, "%s_hc" % team_id, eliteness, config)
	head_coach["role"] = "Head Coach"

	# Coordinators are slightly less skilled than HC
	var coord_config := config.duplicate()
	var base_min := float(config.get("ability_min", 35.0))
	var base_max := float(config.get("ability_max", 95.0))
	coord_config["ability_min"] = maxf(base_min - 10.0, 25.0)
	coord_config["ability_max"] = maxf(base_max - 5.0, 50.0)

	var oc := generate_coach_for_team(rng, "%s_oc" % team_id, eliteness * 0.9, coord_config)
	oc["role"] = "Offensive Coordinator"
	oc["specialty_position"] = "Offense"
	# OC inherits HC's offensive scheme
	oc["offensive_scheme"] = head_coach["offensive_scheme"]

	var dc := generate_coach_for_team(rng, "%s_dc" % team_id, eliteness * 0.9, coord_config)
	dc["role"] = "Defensive Coordinator"
	dc["specialty_position"] = "Defense"
	# DC inherits HC's defensive scheme
	dc["defensive_scheme"] = head_coach["defensive_scheme"]

	return {
		"head_coach": head_coach,
		"offensive_coordinator": oc,
		"defensive_coordinator": dc
	}


## Weighted random selection helper
##
## @param items: Array of items to pick from
## @param weights: Dictionary mapping items to their weights
## @param rng: RandomNumberGenerator for determinism
## @return: Selected item
static func _weighted_pick(items: Array, weights: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var total_weight := 0.0
	for item in items:
		total_weight += float(weights.get(item, 1.0))

	var roll := rng.randf() * total_weight
	var accumulated := 0.0

	for item in items:
		accumulated += float(weights.get(item, 1.0))
		if roll <= accumulated:
			return item

	return items[items.size() - 1]


## Get human-readable display name for offensive scheme
static func get_offensive_scheme_display(scheme: String) -> String:
	match scheme:
		"west_coast": return "West Coast"
		"power_run": return "Power Run"
		"spread_option": return "Spread Option"
		"air_raid": return "Air Raid"
		"zone_run": return "Zone Run"
		"pro_style": return "Pro Style"
		_: return scheme.capitalize().replace("_", " ")


## Get human-readable display name for defensive scheme
static func get_defensive_scheme_display(scheme: String) -> String:
	match scheme:
		"4_3_under": return "4-3 Under"
		"3_4_two_gap": return "3-4 Two Gap"
		"cover_2": return "Cover 2"
		"cover_3": return "Cover 3"
		"press_man": return "Press Man"
		"tampa_2": return "Tampa 2"
		"aggressive_blitz": return "Aggressive Blitz"
		_: return scheme.capitalize().replace("_", " ")


## Get human-readable display name for character tolerance
static func get_character_tolerance_display(tolerance: String) -> String:
	match tolerance:
		"strict": return "Strict"
		"moderate": return "Moderate"
		"lenient": return "Lenient"
		"win_now": return "Win Now"
		_: return tolerance.capitalize().replace("_", " ")


## Get human-readable display name for medical tolerance
static func get_medical_tolerance_display(tolerance: String) -> String:
	match tolerance:
		"risk_averse": return "Risk Averse"
		"cautious": return "Cautious"
		"moderate_risk": return "Moderate Risk"
		"aggressive": return "Aggressive"
		_: return tolerance.capitalize().replace("_", " ")
