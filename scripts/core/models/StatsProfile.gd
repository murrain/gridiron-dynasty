@icon("res://icon.svg")
# res://scripts/core/models/StatsProfile.gd
extends Resource
class_name StatsProfile

## Player stats profile (current, potential, derived)
## Extracted from Player.gd to encapsulate stats-related logic
## Keeps Dictionary format for flexibility with config-driven stats

# --- Core Stat Dictionaries ---
var current: Dictionary = {}      # Current playable ratings (0-100 scale)
var potential: Dictionary = {}    # Ceiling ratings (max development)
var derived: Dictionary = {}      # Computed stats (cached values)

## Get a current stat value
## @param stat_name: Name of the stat to retrieve
## @return: Stat value, or 0.0 if not found
func get_stat(stat_name: String) -> float:
	return float(current.get(stat_name, 0.0))

## Get a potential stat value (ceiling)
## @param stat_name: Name of the stat to retrieve
## @return: Potential value, or 0.0 if not found
func get_potential(stat_name: String) -> float:
	return float(potential.get(stat_name, 0.0))

## Get a derived stat value (computed)
## @param stat_name: Name of the stat to retrieve
## @return: Derived value, or 0.0 if not found
func get_derived(stat_name: String) -> float:
	return float(derived.get(stat_name, 0.0))

## Set a current stat value
func set_stat(stat_name: String, value: float) -> void:
	current[stat_name] = value

## Get the overall rating (commonly used derived stat)
func get_overall_rating() -> float:
	return get_derived("overall")

## Calculate development gap (potential - current)
## @param stat_name: Name of the stat to check
## @return: Gap between potential and current, or 0.0 if not found
func get_development_gap(stat_name: String) -> float:
	return get_potential(stat_name) - get_stat(stat_name)

## Recompute all derived stats based on formulas
## @param derived_specs: Array of formula specifications [{name, formula}, ...]
## @param scope: Variable scope for formula evaluation (physicals, combine, stats)
func recompute_derived(derived_specs: Array[Dictionary], scope: Dictionary) -> void:
	derived.clear()
	for spec in derived_specs:
		var name := String(spec.get("name", ""))
		var formula := String(spec.get("formula", ""))
		if name.is_empty() or formula.is_empty():
			continue
		# Evaluate formula using provided scope
		var val := _eval_simple_formula(formula, scope)
		# Some derived stats can exceed 100 (e.g., catch_radius in inches)
		derived[name] = clamp(val, 0.0, 100000.0)

## Deserialize from dictionary
## Supports legacy field names: "stats" → "current"
func from_dict(d: Dictionary) -> void:
	# Support both new format (current/potential/derived) and legacy (stats/potential/derived)
	current = d.get("current", d.get("stats", {})).duplicate(true)
	potential = d.get("potential", {}).duplicate(true)
	derived = d.get("derived", {}).duplicate(true)

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"current": current.duplicate(true),
		"potential": potential.duplicate(true),
		"derived": derived.duplicate(true)
	}

# =========================
# Internal Formula Evaluation
# =========================

## Very tiny formula interpreter - replace with proper expression engine in production
## Supports tokens like 'wingspan', 'hand_size', 'stats["speed"]', and basic arithmetic
func _eval_simple_formula(formula: String, scope: Dictionary) -> float:
	var f := formula

	# Replace known scope variables
	for key in scope.keys():
		if key != "stats":  # stats is handled separately
			f = f.replace(key, str(scope[key]))

	# Handle stats dictionary access
	if scope.has("stats"):
		var stats_dict: Dictionary = scope["stats"]
		for stat_key in stats_dict.keys():
			f = f.replace(stat_key, str(stats_dict[stat_key]))

	# Use Godot's Expression for safe evaluation
	var expr := Expression.new()
	var parse_err := expr.parse(f, [])
	if parse_err != OK:
		return 0.0

	var result = expr.execute([])
	return float(result)
