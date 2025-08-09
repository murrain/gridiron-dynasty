@icon("res://icon.svg")
# res://scripts/models/Player.gd
extends Resource
class_name SportPlayer

# --- Identity ---
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""
@export var position: String = "ATH"
@export var age: int = 18
@export var class_tag: String = "" # e.g., "CLASS_OF_2033" or recruiting class label

# --- Physical Attributes ---
# Keep raw measurements in native units; you can format/UI-convert elsewhere.
@export var height_in: float = 72.0        # inches
@export var weight_lb: float = 200.0       # pounds
@export var hand_size_in: float = 9.5
@export var arm_length_in: float = 32.0
@export var wingspan_in: float = 78.0

# --- Combine / Testing Metrics ---
# Timed drills (seconds)
@export var forty_yd_dash_s: float = 4.65
@export var twenty_yd_shuttle_s: float = 4.35
@export var three_cone_s: float = 7.2
@export var sixty_yd_shuttle_s: float = 11.5

# Explosives (inches)
@export var vertical_jump_in: float = 32.0
@export var broad_jump_in: float = 120.0   # inches

# Strength
@export var bench_reps_225: int = 10

# Evaluations / Screens
@export var injury_eval: String = ""       # free-form or code, e.g., "CLEARED", "FLAGGED: AC joint"
@export var drug_screen: String = ""       # "PASS", "FAIL", "N/A"
@export var cybex_score: float = 0.0       # if used
@export var wonderlic: int = 0             # or any cognitive metric you prefer

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

# =========================
# Lifecycle / Utilities
# =========================

func get_full_name() -> String:
    return ("%s %s" % [first_name, last_name]).strip_edges()

func from_dict(d: Dictionary) -> void:
    # Safe loader; ignores unknown keys so you can evolve schema without breaking saves.
    # Identity
    id = str(d.get("id", id))
    first_name = String(d.get("first_name", first_name))
    last_name = String(d.get("last_name", last_name))
    position = String(d.get("position", position))
    age = int(d.get("age", age))
    class_tag = String(d.get("class_tag", class_tag))
    gen_mode = String(d.get("gen_mode", gen_mode))
    school_tag = String(d.get("school_tag", school_tag))
    notes = String(d.get("notes", notes))

    # Physicals
    var phys: Dictionary = d.get("physicals", {})
    height_in = float(phys.get("height_in", height_in))
    weight_lb = float(phys.get("weight_lb", weight_lb))
    hand_size_in = float(phys.get("hand_size_in", hand_size_in))
    arm_length_in = float(phys.get("arm_length_in", arm_length_in))
    wingspan_in = float(phys.get("wingspan_in", wingspan_in))

    # Combine
    var cmb: Dictionary = d.get("combine", {})
    forty_yd_dash_s = float(cmb.get("forty_yd_dash_s", forty_yd_dash_s))
    bench_reps_225 = int(cmb.get("bench_reps_225", bench_reps_225))
    vertical_jump_in = float(cmb.get("vertical_jump_in", vertical_jump_in))
    broad_jump_in = float(cmb.get("broad_jump_in", broad_jump_in))
    twenty_yd_shuttle_s = float(cmb.get("twenty_yd_shuttle_s", twenty_yd_shuttle_s))
    three_cone_s = float(cmb.get("three_cone_s", three_cone_s))
    sixty_yd_shuttle_s = float(cmb.get("sixty_yd_shuttle_s", sixty_yd_shuttle_s))
    injury_eval = String(cmb.get("injury_eval", injury_eval))
    drug_screen = String(cmb.get("drug_screen", drug_screen))
    cybex_score = float(cmb.get("cybex_score", cybex_score))
    wonderlic = int(cmb.get("wonderlic", wonderlic))

    # Ratings & traits
    stats = (d.get("stats", stats) as Dictionary).duplicate(true)
    potential = (d.get("potential", potential) as Dictionary).duplicate(true)
    derived = (d.get("derived", derived) as Dictionary).duplicate(true)
    traits = (d.get("traits", traits) as Array).duplicate()
    hidden_traits = (d.get("hidden_traits", hidden_traits) as Array).duplicate()

func to_dict() -> Dictionary:
    return {
        "id": id,
        "first_name": first_name,
        "last_name": last_name,
        "position": position,
        "age": age,
        "class_tag": class_tag,
        "gen_mode": gen_mode,
        "school_tag": school_tag,
        "notes": notes,
        "physicals": {
            "height_in": height_in,
            "weight_lb": weight_lb,
            "hand_size_in": hand_size_in,
            "arm_length_in": arm_length_in,
            "wingspan_in": wingspan_in
        },
        "combine": {
            "forty_yd_dash_s": forty_yd_dash_s,
            "bench_reps_225": bench_reps_225,
            "vertical_jump_in": vertical_jump_in,
            "broad_jump_in": broad_jump_in,
            "twenty_yd_shuttle_s": twenty_yd_shuttle_s,
            "three_cone_s": three_cone_s,
            "sixty_yd_shuttle_s": sixty_yd_shuttle_s,
            "injury_eval": injury_eval,
            "drug_screen": drug_screen,
            "cybex_score": cybex_score,
            "wonderlic": wonderlic
        },
        "stats": stats.duplicate(true),
        "potential": potential.duplicate(true),
        "derived": derived.duplicate(true),
        "traits": traits.duplicate(),
        "hidden_traits": hidden_traits.duplicate()
    }

# --- Derived stat recompute ---
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
        "height": height_in, "weight": weight_lb,
        "hand_size": hand_size_in, "arm_length": arm_length_in, "wingspan": wingspan_in,
        # combine (expose some under simpler names if you like)
        "forty": forty_yd_dash_s, "bench_reps": bench_reps_225,
        "vert": vertical_jump_in, "broad": broad_jump_in,
        "shuttle20": twenty_yd_shuttle_s, "cone3": three_cone_s, "shuttle60": sixty_yd_shuttle_s,
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