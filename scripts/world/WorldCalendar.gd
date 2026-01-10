extends RefCounted
class_name WorldCalendar

const DEFAULT_CONFIG_KEY := "world/calendar"

func phases_for_year(
	year: int,
	config_key: String = DEFAULT_CONFIG_KEY,
	config_provider: Object = null
) -> Array:
	var config = _resolve_config(config_provider)
	if config == null:
		push_error("WorldCalendar: Config provider not available.")
		return []

	var cfg: Dictionary = config.get_config(config_key)
	if cfg.is_empty():
		push_error("WorldCalendar: missing calendar config at '%s'." % config_key)
		return []

	if not _validate_calendar(cfg):
		return []

	var phases: Array = []
	var raw_phases: Array = cfg.get("phases", []) as Array
	for i in raw_phases.size():
		var phase: Dictionary = raw_phases[i]
		var descriptor := {
			"year": year,
			"phase_id": String(phase.get("id", "")),
			"index": i,
			"label": String(phase.get("label", "")),
			"start_tick": int(phase.get("start_tick", 0)),
			"end_tick": int(phase.get("end_tick", 0)),
			"tags": phase.get("tags", []) as Array,
			"placeholder": bool(phase.get("placeholder", false))
		}
		phases.append(descriptor)

	return phases

func _resolve_config(config_provider: Object) -> Object:
	if config_provider != null:
		return config_provider

	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var root := (main_loop as SceneTree).root
		if root.has_node("Config"):
			return root.get_node("Config")

	return null

func _validate_calendar(cfg: Dictionary) -> bool:
	if not cfg.has("phases"):
		push_error("WorldCalendar: calendar config missing 'phases' array.")
		return false

	var phases: Array = cfg.get("phases", []) as Array
	if phases.is_empty():
		push_error("WorldCalendar: calendar config has no phases.")
		return false

	var seen := {}
	for idx in phases.size():
		var phase: Dictionary = phases[idx]
		if not _validate_phase(phase, idx):
			return false
		var phase_id := String(phase.get("id", ""))
		if seen.has(phase_id):
			push_error("WorldCalendar: duplicate phase id '%s'." % phase_id)
			return false
		seen[phase_id] = true

	return true

func _validate_phase(phase: Dictionary, index: int) -> bool:
	var phase_id := String(phase.get("id", ""))
	if phase_id == "":
		push_error("WorldCalendar: phase %d missing 'id'." % index)
		return false

	if not phase.has("start_tick") or not phase.has("end_tick"):
		push_error("WorldCalendar: phase '%s' missing start_tick/end_tick." % phase_id)
		return false

	var start_tick := int(phase.get("start_tick", 0))
	var end_tick := int(phase.get("end_tick", 0))
	if end_tick < start_tick:
		push_error("WorldCalendar: phase '%s' end_tick before start_tick." % phase_id)
		return false

	return true
