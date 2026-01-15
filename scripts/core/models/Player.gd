@icon("res://icon.svg")
# res://scripts/core/models/Player.gd
extends "res://scripts/core/models/Person.gd"
class_name Player

const Contract = preload("res://scripts/core/models/Contract.gd")
const Injury = preload("res://scripts/core/models/Injury.gd")

## Player lifecycle stages
## Provides type-level discrimination of player state
enum PlayerStage {
	HIGH_SCHOOL = 0,      # High school player
	COLLEGE = 1,          # College player
	DRAFT_ELIGIBLE = 2,   # Declared for draft/eligible
	NFL_ROOKIE = 3,       # First year in NFL
	NFL_VETERAN = 4,      # Multi-year NFL player
	NFL_FREE_AGENT = 5,   # Free agent (unsigned)
	RETIRED = 6           # Retired from play
}

# --- Identity (inherited from Person: id, first_name, last_name, get_full_name()) ---
@export var position: String = "ATH"
@export var age: int = 18
@export var stage: PlayerStage = PlayerStage.HIGH_SCHOOL
@export var class_tag: String = "" # e.g., "CLASS_OF_2033" or recruiting class label
@export var jersey_number: int = 0  # Player's jersey number (0 = unassigned)

# --- Physical Attributes ---
# Keep raw measurements in native units; you can format/UI-convert elsewhere.
@export var height_in: float = 72.0        # inches
@export var weight_lb: float = 200.0       # pounds
@export var hand_size_in: float = 9.5
@export var arm_length_in: float = 32.0
@export var wingspan_in: float = 78.0

# --- Combine / Testing Metrics ---
# Timed drills (seconds)
@export var forty_sec: float
@export var shuttle20_sec: float
@export var cone3_sec: float
@export var shuttle60_sec: float

@export var vertical_in: float
@export var broad_in: float
@export var bench_225_reps: int

@export var wonderlic: int
@export var cybex_index: float

@export var injury_eval: String
@export var drug_screen: String

# --- Stats (gameplay ratings) ---
# Use 0–100 scale (or whatever your engine expects). Derived stats can be recomputed from base.
var stats: Dictionary = {}        # current playable ratings (HS/college/NFL depending on context)
var potential: Dictionary = {}    # prime caps (finished product ceiling)
var derived: Dictionary = {}      # cached computed values (e.g., catch_radius, burst)

# --- Traits ---
@export var traits: Array[String] = []         # visible traits: ["Ball Hawk", "Sure Hands", ...]
var hidden_traits: Array[String] = []          # hidden: ["Freak:speed", "InjuryFlag:Hamstring", ...]

# --- Provenance / Flags ---
@export var gen_mode: String = ""              # "quota" | "gauss" | "chaos" | etc.
@export var school_tag: String = ""            # where they currently are (optional)
@export var notes: String = ""                 # debug or scout notes

# --- Career Achievements ---
# Track cumulative awards and honors earned throughout a player's career
@export var career_awards: Dictionary = {
	"opoy": 0,              # Offensive Player of the Year
	"dpoy": 0,              # Defensive Player of the Year
	"all_pro_first": 0,     # First-team All-Pro selections
	"all_pro_second": 0,    # Second-team All-Pro selections
	"pro_bowl": 0,          # Pro Bowl selections
	"rookie_of_year": 0,    # Rookie of the Year (should be 0 or 1)
	"championships": 0      # Championship wins
}

# --- Wear / Development ---
@export var wear: Dictionary = {"snaps": 0, "collisions": 0, "injury_count": 0}
@export var development_report: Array = []
# --- Health / Lifecycle ---
var injuries: Array[Injury] = []

# --- Contract ---
# Typed contract resource for type safety and validation
# Contract lifecycle is deterministic and replayable when the input decisions
# are logged; do not derive hidden randomness at mutation time.
# - Signing: set current_year = 1 and total_years > 0 with explicit values for
#   annual_value/guaranteed/range_min/range_max and the source_eval_id.
# - Extension: update total_years and financial fields explicitly; never
#   increment current_year implicitly.
# - Release: clear current_year/total_years and zero out financials explicitly.
@export var contract: Contract = null

# =========================
# Lifecycle / Utilities
# =========================

func _init() -> void:
	contract = Contract.new()

func from_dict(d: Dictionary) -> void:
	# Load person fields first
	from_dict_person(d)
	# Safe loader; ignores unknown keys so you can evolve schema without breaking saves.
	position = String(d.get("position", position))
	age = int(d.get("age", age))

	# Load stage with backward compatibility
	if d.has("stage"):
		stage = d["stage"] as PlayerStage
	else:
		# Infer stage from context for old saves
		stage = _infer_stage_from_fields(d)
	class_tag = String(d.get("class_tag", class_tag))
	# Valid range: 0-99 (0 = unassigned)
	jersey_number = clampi(int(d.get("jersey_number", jersey_number)), 0, 99)
	gen_mode = String(d.get("gen_mode", gen_mode))
	school_tag = String(d.get("school_tag", school_tag))
	notes = String(d.get("notes", notes))
	wear = (d.get("wear", wear) as Dictionary).duplicate(true)
	development_report = (d.get("development_report", development_report) as Array).duplicate(true)

	# Physicals
	var phys: Dictionary = d.get("physicals", {})
	height_in = float(phys.get("height_in", height_in))
	weight_lb = float(phys.get("weight_lb", weight_lb))
	hand_size_in = float(phys.get("hand_size_in", hand_size_in))
	arm_length_in = float(phys.get("arm_length_in", arm_length_in))
	wingspan_in = float(phys.get("wingspan_in", wingspan_in))

	# Combine
	var cmb: Dictionary = d.get("combine", {})
	forty_sec = float(cmb.get("forty_sec", forty_sec))
	shuttle20_sec = float(cmb.get("shuttle20_sec", shuttle20_sec))
	cone3_sec = float(cmb.get("cone3_sec", cone3_sec))
	shuttle60_sec = float(cmb.get("shuttle60_sec", shuttle60_sec))
	vertical_in = float(cmb.get("vertical_in", vertical_in))
	broad_in = float(cmb.get("broad_in", broad_in))
	bench_225_reps = int(cmb.get("bench_225_reps", bench_225_reps))
	wonderlic = int(cmb.get("wonderlic", wonderlic))
	cybex_index = float(cmb.get("cybex_index", cybex_index))
	injury_eval = String(cmb.get("injury_eval", injury_eval))
	drug_screen = String(cmb.get("drug_screen", drug_screen))

	# Ratings & traits
	stats = (d.get("stats", stats) as Dictionary).duplicate(true)
	potential = (d.get("potential", potential) as Dictionary).duplicate(true)
	derived = (d.get("derived", derived) as Dictionary).duplicate(true)
	traits = (d.get("traits", traits) as Array).duplicate()
	hidden_traits = (d.get("hidden_traits", hidden_traits) as Array).duplicate()

	# Injuries - backward compatible with Dictionary array
	injuries.clear()
	for injury_data in d.get("injuries", []):
		var injury = Injury.new()
		if injury_data is Dictionary:
			injury.from_dict(injury_data)
		injuries.append(injury)

	development_report = (d.get("development_report", development_report) as Array).duplicate(true)

	# Contract - backward compatible with both Dictionary and Contract
	var contract_data: Dictionary = d.get("contract", {}) as Dictionary
	if contract == null:
		contract = Contract.new()
	contract.from_dict(contract_data)

	# Career awards
	var awards_data: Dictionary = d.get("career_awards", {}) as Dictionary
	if not awards_data.is_empty():
		for award_key in awards_data.keys():
			# Ensure non-negative integers
			career_awards[award_key] = max(0, int(awards_data[award_key]))

func to_dict() -> Dictionary:
	# Start with person fields
	var result = to_dict_person()
	# Add player-specific fields
	result["position"] = position
	result["age"] = age
	result["stage"] = stage
	result["class_tag"] = class_tag
	result["jersey_number"] = jersey_number
	result["gen_mode"] = gen_mode
	result["school_tag"] = school_tag
	result["notes"] = notes
	result["wear"] = wear.duplicate(true)
	result["development_report"] = development_report.duplicate(true)
	result["contract"] = contract.to_dict() if contract != null else {}
	result["career_awards"] = career_awards.duplicate(true)
	result["physicals"] = {
		"height_in": height_in,
		"weight_lb": weight_lb,
		"hand_size_in": hand_size_in,
		"arm_length_in": arm_length_in,
		"wingspan_in": wingspan_in
	}
	result["combine"] = {
		"forty_sec": forty_sec,
		"bench_225_reps": bench_225_reps,
		"vertical_in": vertical_in,
		"broad_in": broad_in,
		"shuttle20_sec": shuttle20_sec,
		"cone3_sec": cone3_sec,
		"shuttle60_sec": shuttle60_sec,
		"injury_eval": injury_eval,
		"drug_screen": drug_screen,
		"cybex_index": cybex_index,
		"wonderlic": wonderlic
	}
	result["stats"] = stats.duplicate(true)
	result["potential"] = potential.duplicate(true)
	result["derived"] = derived.duplicate(true)
	result["traits"] = traits.duplicate()
	result["hidden_traits"] = hidden_traits.duplicate()

	# Serialize injuries
	var injuries_array: Array = []
	for injury in injuries:
		injuries_array.append(injury.to_dict())
	result["injuries"] = injuries_array

	return result

# =========================
# Player Stage Methods
# =========================

## Check if player is currently in NFL (rookie or veteran)
func is_nfl_player() -> bool:
	return stage in [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_VETERAN]

## Check if player is draft eligible
func is_available_for_draft() -> bool:
	return stage == PlayerStage.DRAFT_ELIGIBLE

## Check if player is in college
func is_college_player() -> bool:
	return stage == PlayerStage.COLLEGE

## Check if player is in high school
func is_high_school_player() -> bool:
	return stage == PlayerStage.HIGH_SCHOOL

## Check if player is a free agent
func is_free_agent() -> bool:
	return stage == PlayerStage.NFL_FREE_AGENT

## Check if player is retired
func is_retired() -> bool:
	return stage == PlayerStage.RETIRED

## Transition player to a new stage with validation
## Returns true if transition is valid, false otherwise
## Invalid transitions will log a warning
func transition_to(new_stage: PlayerStage) -> bool:
	# Define valid transitions for each stage
	var valid_transitions = {
		PlayerStage.HIGH_SCHOOL: [PlayerStage.COLLEGE],
		PlayerStage.COLLEGE: [PlayerStage.DRAFT_ELIGIBLE, PlayerStage.COLLEGE],
		PlayerStage.DRAFT_ELIGIBLE: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_FREE_AGENT],
		PlayerStage.NFL_ROOKIE: [PlayerStage.NFL_VETERAN, PlayerStage.NFL_FREE_AGENT, PlayerStage.RETIRED],
		PlayerStage.NFL_VETERAN: [PlayerStage.NFL_FREE_AGENT, PlayerStage.RETIRED],
		PlayerStage.NFL_FREE_AGENT: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_VETERAN, PlayerStage.RETIRED],
		PlayerStage.RETIRED: []
	}

	if new_stage in valid_transitions.get(stage, []):
		stage = new_stage
		return true
	else:
		push_warning("Invalid stage transition: %s -> %s for player %s" % [
			PlayerStage.keys()[stage],
			PlayerStage.keys()[new_stage],
			get_full_name()
		])
		return false

# =========================
# Derived stat recompute
# =========================
# Pass in your stats.json "derived formulas" (pre-parsed into tokens or safe eval).
func recompute_derived(derived_specs: Array[Dictionary]) -> void:
	# expected spec: [{name:"catch_radius", formula:"(wingspan * 0.5) + (hand_size * 5.0)"}, ...]
	# This example supports a limited variable set: stats + physicals; replace with your own safe-eval.
	var scope := _build_formula_scope()
	for spec in derived_specs:
		var name := String(spec.get("name", ""))
		var formula := String(spec.get("formula", ""))
		if name.is_empty() or formula.is_empty():
			continue
		# Implement a real safe expression evaluator in your project.
		# Placeholder: interpret known symbols manually (you can swap this with your StatCalculator).
		var val := _eval_simple_formula(formula, scope)
		derived[name] = clamp(val, 0.0, 100000.0) # some derived can exceed 100 (e.g., radius in inches)

func get_stat(name: String, trait_defs: Dictionary = {}) -> float:
	# Return current stat with trait modifiers applied at read-time
	var base := float(stats.get(name, 0.0))
	var mod := _accumulate_trait_mods(name, trait_defs)
	return base * mod.mult + mod.add

func set_stat(name: String, value: float) -> void:
	stats[name] = value

# =========================
# Internals
# =========================

func _build_formula_scope() -> Dictionary:
	return {
		# physicals
		"height": height_in,
		"weight": weight_lb,
		"hand_size": hand_size_in,
		"arm_length": arm_length_in,
		"wingspan": wingspan_in,
		# combine (expose some under simpler names if you like)
		"forty": forty_sec,
		"bench_reps": bench_225_reps,
		"vert": vertical_in,
		"broad": broad_in,
		"shuttle20": shuttle20_sec,
		"cone3": cone3_sec,
		"shuttle60": shuttle60_sec,
		# stats (merge)
		"stats": stats
	}

# Very tiny formula interpreter just for placeholders; replace with your own expression engine.
func _eval_simple_formula(formula: String, scope: Dictionary) -> float:
	# Supports tokens like 'wingspan', 'hand_size', '+-*/()' and 'stats["speed"]'
	# Implement properly for production; here we only handle a couple common derived examples.
	var f := formula
	f = f.replace("wingspan", str(scope["wingspan"]))
	f = f.replace("hand_size", str(scope["hand_size"]))
	f = f.replace("acceleration", str(float(scope["stats"].get("acceleration", 0.0))))
	f = f.replace("agility", str(float(scope["stats"].get("agility", 0.0))))
	# Very naive fallback: try to evaluate using Expression (Godot’s built-in safe evaluator)
	var expr := Expression.new()
	var parse_err := expr.parse(f, [])
	if parse_err != OK:
		return 0.0
	var result = expr.execute([])
	return float(result)

# Trait modifiers: expect a data-driven trait definition dict, e.g.:
# { "Ball Hawk": {"add": {"coverage": 2}, "mult": {"reaction_time": 1.05}}, ... }
func _accumulate_trait_mods(stat_name: String, trait_defs: Dictionary) -> Dictionary:
	var total_add := 0.0
	var total_mult := 1.0
	for t in traits:
		var def: Dictionary = trait_defs.get(t, {})
		if def.has("add"):
			total_add += float((def["add"] as Dictionary).get(stat_name, 0.0))
		if def.has("mult"):
			total_mult *= float((def["mult"] as Dictionary).get(stat_name, 1.0))
	# Hidden traits can also apply:
	for ht in hidden_traits:
		var defh: Dictionary = trait_defs.get(ht, {})
		if defh.has("add"):
			total_add += float((defh["add"] as Dictionary).get(stat_name, 0.0))
		if defh.has("mult"):
			total_mult *= float((defh["mult"] as Dictionary).get(stat_name, 1.0))
	return {"add": total_add, "mult": total_mult}

## Infer player stage from context fields (for backward compatibility)
## Used when loading old save files without explicit stage field
func _infer_stage_from_fields(d: Dictionary) -> PlayerStage:
	# Check contract status
	var contract_data: Dictionary = d.get("contract", {}) as Dictionary
	var has_contract = int(contract_data.get("total_years", 0)) > 0
	var has_school = String(d.get("school_tag", "")) != ""
	var player_age = int(d.get("age", 18))

	# Priority: contract status > school > age
	if has_contract:
		# Has NFL contract - rookie vs veteran based on age
		return PlayerStage.NFL_VETERAN if player_age > 23 else PlayerStage.NFL_ROOKIE
	elif has_school:
		# In school - college vs high school based on age
		return PlayerStage.COLLEGE if player_age >= 18 else PlayerStage.HIGH_SCHOOL
	elif player_age >= 21:
		# Old enough for NFL but no contract - free agent
		return PlayerStage.NFL_FREE_AGENT
	else:
		# Default to high school
		return PlayerStage.HIGH_SCHOOL
