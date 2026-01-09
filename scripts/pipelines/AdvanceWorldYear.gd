extends Node
class_name AdvanceWorldYear

func run(world_state: Dictionary, year: int, year_seed: int) -> Dictionary:
	var calendar := WorldCalendar.new()
	var phases := calendar.phases_for_year(year)
	var results: Array = []
	var state := world_state if world_state != null else {}

	var rng := RandomNumberGenerator.new()
	if year_seed != 0:
		rng.seed = year_seed
	else:
		rng.randomize()

	var handlers := _phase_handlers()
	for phase in phases:
		var phase_id := String(phase.get("phase_id", ""))
		var phase_seed := rng.randi()
		_log_phase_start(year, phase_id, phase_seed)
		var handler: Callable = handlers.get(phase_id, _handle_unknown_phase)
		var output: Dictionary = handler.call(state, year, phase_seed, phase)
		_log_phase_end(year, phase_id, phase_seed)
		results.append({
			"phase_id": phase_id,
			"seed": phase_seed,
			"seed_lineage": {
				"year_seed": year_seed,
				"phase_index": int(phase.get("index", 0))
			},
			"output": output
		})

	return {
		"year": year,
		"year_seed": year_seed,
		"phases": results,
		"world_state": state
	}

func _phase_handlers() -> Dictionary:
	return {
		"hs_generation": Callable(self, "_handle_hs_generation"),
		"hs_season": Callable(self, "_handle_hs_season"),
		"hs_assignment": Callable(self, "_handle_hs_assignment"),
		"college_season": Callable(self, "_handle_placeholder_phase"),
		"draft_prep": Callable(self, "_handle_placeholder_phase"),
		"nfl_draft": Callable(self, "_handle_placeholder_phase")
	}

func _handle_hs_generation(world_state: Dictionary, year: int, seed: int, _phase: Dictionary) -> Dictionary:
	# Use the year as a stand-in for HS class tagging until explicit HS grad rules exist.
	var generator := DraftClassGenerator.new()
	var players := generator.generate_for_year(year, seed)

	var hs_classes: Dictionary = world_state.get("hs_classes", {}) as Dictionary
	hs_classes[year] = players
	world_state["hs_classes"] = hs_classes

	return {
		"class_year": year,
		"count": players.size()
	}

func _handle_hs_season(world_state: Dictionary, year: int, _seed: int, _phase: Dictionary) -> Dictionary:
	# Placeholder: HS season progression is defined in Phase 2.
	# TODO: Advance HS players with explicit lifecycle rules and seeded RNG.
	# Determinism: no RNG is consumed here until the Phase 2 handler exists.
	var hs_classes: Dictionary = world_state.get("hs_classes", {}) as Dictionary
	var players: Array = hs_classes.get(year, []) as Array

	return {
		"class_year": year,
		"count": players.size(),
		"placeholder": true,
		"note": "HS season progression not yet implemented."
	}

func _handle_hs_assignment(world_state: Dictionary, year: int, _seed: int, _phase: Dictionary) -> Dictionary:
	# Placeholder: HS assignment logic is defined in Phase 2.
	# TODO: Assign HS players to schools with seeded RNG and explicit weights.
	# Determinism: no RNG is consumed here until the Phase 2 handler exists.
	var hs_classes: Dictionary = world_state.get("hs_classes", {}) as Dictionary
	var players: Array = hs_classes.get(year, []) as Array

	return {
		"class_year": year,
		"count": players.size(),
		"placeholder": true,
		"note": "HS assignment not yet implemented."
	}

func _handle_placeholder_phase(_world_state: Dictionary, _year: int, _seed: int, phase: Dictionary) -> Dictionary:
	# TODO: Implement phase handler with explicit RNG usage and output schema.
	# Determinism: this placeholder does not consume RNG.
	return {
		"placeholder": true,
		"note": "Phase '%s' not yet implemented." % String(phase.get("phase_id", ""))
	}

func _handle_unknown_phase(_world_state: Dictionary, _year: int, _seed: int, phase: Dictionary) -> Dictionary:
	return {
		"error": "No handler for phase '%s'." % String(phase.get("phase_id", ""))
	}

func _log_phase_start(year: int, phase_id: String, seed: int) -> void:
	print("WorldYear: start phase %s year=%d seed=%d" % [phase_id, year, seed])

func _log_phase_end(year: int, phase_id: String, seed: int) -> void:
	print("WorldYear: end phase %s year=%d seed=%d" % [phase_id, year, seed])
