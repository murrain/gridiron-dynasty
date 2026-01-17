@icon("res://icon.svg")
# res://scripts/core/models/Player.gd
extends "res://scripts/core/models/Person.gd"
class_name Player

const Contract = preload("res://scripts/core/models/Contract.gd")
const Injury = preload("res://scripts/core/models/Injury.gd")
const PlayerPhysicals = preload("res://scripts/core/models/PlayerPhysicals.gd")
const CombineResults = preload("res://scripts/core/models/CombineResults.gd")
const TraitSet = preload("res://scripts/core/models/TraitSet.gd")
const CareerRecord = preload("res://scripts/core/models/CareerRecord.gd")
const HealthStatus = preload("res://scripts/core/models/HealthStatus.gd")
const StatsProfile = preload("res://scripts/core/models/StatsProfile.gd")

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

# --- College Academic Year ---
# Represents college class standing for draft eligibility:
#   1 = Freshman, 2 = Sophomore, 3 = Junior, 4 = Senior
# Underclassmen (1-3) can declare early for the draft.
# Default is 4 (senior) for backward compatibility with existing saves.
@export var class_year: int = 4

# --- Early Entry Flag ---
# Indicates whether an underclassman has declared early for the NFL draft.
# Set by UnderclassmanDeclarationEngine during Phase 0.5 of PreDraftProcess.
# When true, player transitions to DRAFT_ELIGIBLE stage.
@export var declared_for_draft: bool = false

# --- Physical Attributes ---
# Extracted to PlayerPhysicals resource for better organization
@export var physicals: PlayerPhysicals = null

# --- Combine / Testing Metrics ---
# Extracted to CombineResults resource
# Nullable - null means player hasn't done a combine yet
@export var combine: CombineResults = null

# --- Stats (gameplay ratings) ---
# Extracted to StatsProfile resource for better organization
@export var stats_profile: StatsProfile = null

# --- Traits ---
# Extracted to TraitSet resource for better encapsulation
@export var trait_set: TraitSet = null

# --- Provenance / Flags ---
@export var gen_mode: String = ""              # "quota" | "gauss" | "chaos" | etc.
@export var school_tag: String = ""            # where they currently are (optional)
@export var notes: String = ""                 # debug or scout notes

# --- Career Record ---
# Extracted to CareerRecord resource for better encapsulation
@export var career: CareerRecord = null

# --- Health Status ---
# Extracted to HealthStatus resource for better encapsulation
@export var health: HealthStatus = null

# --- Draft Intelligence ---
# Consolidated pre-draft intelligence and scouting data
# Generated during PreDraftProcess, consumed during InteractiveDraft
# Structure:
#   {
#     "red_flags": Array[Dictionary],      # Medical/character concerns
#     "mock_history": Array[Dictionary],   # Mock draft projections over time
#     "scouting_report": Dictionary,       # Generated scouting report
#     "shortlisted_by": Array[String]      # Team IDs that have player shortlisted
#   }
@export var draft_intelligence: Dictionary = {}

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
	physicals = PlayerPhysicals.new()
	combine = CombineResults.new()
	trait_set = TraitSet.new()
	career = CareerRecord.new()
	health = HealthStatus.new()
	stats_profile = StatsProfile.new()

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

	# Physicals - Support both nested and flat format (backward compatibility)
	if physicals == null:
		physicals = PlayerPhysicals.new()

	if d.has("physicals") and d["physicals"] is Dictionary:
		# New nested format
		physicals.from_dict(d["physicals"])
	else:
		# Legacy flat format - read directly from player dict
		physicals.height_in = float(d.get("height_in", physicals.height_in))
		physicals.weight_lb = float(d.get("weight_lb", physicals.weight_lb))
		physicals.hand_size_in = float(d.get("hand_size_in", physicals.hand_size_in))
		physicals.arm_length_in = float(d.get("arm_length_in", physicals.arm_length_in))
		physicals.wingspan_in = float(d.get("wingspan_in", physicals.wingspan_in))

	# Combine - Support both nested and flat format (backward compatibility)
	if combine == null:
		combine = CombineResults.new()

	if d.has("combine") and d["combine"] is Dictionary:
		# New nested format
		combine.from_dict(d["combine"])
	else:
		# Legacy flat format - read directly from player dict
		combine.forty_sec = float(d.get("forty_sec", combine.forty_sec))
		combine.shuttle20_sec = float(d.get("shuttle20_sec", combine.shuttle20_sec))
		combine.cone3_sec = float(d.get("cone3_sec", combine.cone3_sec))
		combine.shuttle60_sec = float(d.get("shuttle60_sec", combine.shuttle60_sec))
		combine.vertical_in = float(d.get("vertical_in", combine.vertical_in))
		combine.broad_in = float(d.get("broad_in", combine.broad_in))
		combine.bench_225_reps = int(d.get("bench_225_reps", combine.bench_225_reps))
		combine.wonderlic = int(d.get("wonderlic", combine.wonderlic))
		combine.cybex_index = float(d.get("cybex_index", combine.cybex_index))
		combine.injury_eval = String(d.get("injury_eval", combine.injury_eval))
		combine.drug_screen = String(d.get("drug_screen", combine.drug_screen))

	# Stats Profile - Support both nested and flat format (backward compatibility)
	if stats_profile == null:
		stats_profile = StatsProfile.new()

	if d.has("stats_profile") and d["stats_profile"] is Dictionary:
		# New nested format
		stats_profile.from_dict(d["stats_profile"])
	else:
		# Legacy flat format - read stats/potential/derived directly
		stats_profile.current = (d.get("stats", {}) as Dictionary).duplicate(true)
		stats_profile.potential = (d.get("potential", {}) as Dictionary).duplicate(true)
		stats_profile.derived = (d.get("derived", {}) as Dictionary).duplicate(true)

	# Traits - Support both nested and flat format (backward compatibility)
	if trait_set == null:
		trait_set = TraitSet.new()

	if d.has("trait_set") and d["trait_set"] is Dictionary:
		# New nested format
		trait_set.from_dict(d["trait_set"])
	else:
		# Legacy flat format - read directly from player dict
		trait_set.visible.clear()
		trait_set.hidden.clear()
		for t in d.get("traits", []):
			trait_set.visible.append(String(t))
		for t in d.get("hidden_traits", []):
			trait_set.hidden.append(String(t))

	# Health - Support both nested and flat format (backward compatibility)
	if health == null:
		health = HealthStatus.new()

	if d.has("health") and d["health"] is Dictionary:
		# New nested format
		health.from_dict(d["health"])
	else:
		# Legacy flat format - read injuries directly from player dict
		health.injuries.clear()
		for injury_data in d.get("injuries", []):
			var injury = Injury.new()
			if injury_data is Dictionary:
				injury.from_dict(injury_data)
			health.injuries.append(injury)

	# Contract - backward compatible with both Dictionary and Contract
	var contract_data: Dictionary = d.get("contract", {}) as Dictionary
	if contract == null:
		contract = Contract.new()
	contract.from_dict(contract_data)

	# Career - Support both nested and flat format (backward compatibility)
	if career == null:
		career = CareerRecord.new()

	if d.has("career") and d["career"] is Dictionary:
		# New nested format
		career.from_dict(d["career"])
	else:
		# Legacy flat format - read career_awards, wear, development_report directly
		var awards_data: Dictionary = d.get("career_awards", {}) as Dictionary
		if not awards_data.is_empty():
			for award_key in awards_data.keys():
				career.awards[award_key] = max(0, int(awards_data[award_key]))

		var wear_data: Dictionary = d.get("wear", {}) as Dictionary
		if not wear_data.is_empty():
			career.wear["snaps"] = int(wear_data.get("snaps", 0))
			career.wear["collisions"] = int(wear_data.get("collisions", 0))
			career.wear["injury_count"] = int(wear_data.get("injury_count", 0))

		career.development_history.clear()
		for entry in d.get("development_report", []):
			career.development_history.append(entry)

	# Draft Intelligence - deep copy to preserve nested structure
	if d.has("draft_intelligence") and d["draft_intelligence"] is Dictionary:
		draft_intelligence = (d["draft_intelligence"] as Dictionary).duplicate(true)
	else:
		draft_intelligence = {}

	# Class Year - Support backward compatibility by inferring from age if missing
	if d.has("class_year"):
		class_year = clampi(int(d.get("class_year", 4)), 1, 4)
	else:
		# Backward compatibility: infer class_year from age
		# Age 18-19 = Freshman (1), 20 = Sophomore (2), 21 = Junior (3), 22+ = Senior (4)
		var player_age := int(d.get("age", 22))
		class_year = clampi(player_age - 17, 1, 4)

	# Declared for Draft - Simple boolean with default false
	declared_for_draft = bool(d.get("declared_for_draft", false))

func to_dict() -> Dictionary:
	# Start with person fields
	var result = to_dict_person()
	# Add player-specific fields
	result["position"] = position
	result["age"] = age
	result["stage"] = stage
	result["class_tag"] = class_tag
	result["jersey_number"] = jersey_number
	result["class_year"] = class_year
	result["declared_for_draft"] = declared_for_draft
	result["gen_mode"] = gen_mode
	result["school_tag"] = school_tag
	result["notes"] = notes
	result["contract"] = contract.to_dict() if contract != null else {}
	result["career"] = career.to_dict() if career != null else {}
	result["physicals"] = physicals.to_dict() if physicals != null else {}
	result["combine"] = combine.to_dict() if combine != null else {}
	result["stats_profile"] = stats_profile.to_dict() if stats_profile != null else {}
	result["trait_set"] = trait_set.to_dict() if trait_set != null else {}
	result["health"] = health.to_dict() if health != null else {}
	result["draft_intelligence"] = draft_intelligence.duplicate(true)

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
	# Delegate to stats_profile with scope built from player's resources
	if stats_profile == null:
		return
	var scope := _build_formula_scope()
	stats_profile.recompute_derived(derived_specs, scope)

func get_stat(name: String, trait_defs: Dictionary = {}) -> float:
	# Return current stat with trait modifiers applied at read-time
	if stats_profile == null:
		return 0.0
	var base := stats_profile.get_stat(name)
	var mod := _accumulate_trait_mods(name, trait_defs)
	return base * mod.mult + mod.add

func set_stat(name: String, value: float) -> void:
	if stats_profile != null:
		stats_profile.set_stat(name, value)

# =========================
# Internals
# =========================

func _build_formula_scope() -> Dictionary:
	return {
		# physicals - use resource fields
		"height": physicals.height_in if physicals != null else 72.0,
		"weight": physicals.weight_lb if physicals != null else 200.0,
		"hand_size": physicals.hand_size_in if physicals != null else 9.5,
		"arm_length": physicals.arm_length_in if physicals != null else 32.0,
		"wingspan": physicals.wingspan_in if physicals != null else 78.0,
		# combine - use resource fields (expose under simpler names)
		"forty": combine.forty_sec if combine != null else 0.0,
		"bench_reps": combine.bench_225_reps if combine != null else 0,
		"vert": combine.vertical_in if combine != null else 0.0,
		"broad": combine.broad_in if combine != null else 0.0,
		"shuttle20": combine.shuttle20_sec if combine != null else 0.0,
		"cone3": combine.cone3_sec if combine != null else 0.0,
		"shuttle60": combine.shuttle60_sec if combine != null else 0.0,
		# stats (merge) - use stats_profile.current
		"stats": stats_profile.current if stats_profile != null else {}
	}


# Trait modifiers: expect a data-driven trait definition dict, e.g.:
# { "Ball Hawk": {"add": {"coverage": 2}, "mult": {"reaction_time": 1.05}}, ... }
func _accumulate_trait_mods(stat_name: String, trait_defs: Dictionary) -> Dictionary:
	var total_add := 0.0
	var total_mult := 1.0

	if trait_set == null:
		return {"add": total_add, "mult": total_mult}

	# Apply visible traits
	for t in trait_set.visible:
		var def: Dictionary = trait_defs.get(t, {})
		if def.has("add"):
			total_add += float((def["add"] as Dictionary).get(stat_name, 0.0))
		if def.has("mult"):
			total_mult *= float((def["mult"] as Dictionary).get(stat_name, 1.0))

	# Apply hidden traits
	for ht in trait_set.hidden:
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
