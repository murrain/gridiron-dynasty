extends RefCounted
class_name PhysicalsHelper
## PhysicalsHelper
## - roll_for_position(pos, positions_data) -> Dictionary
## Expects positions_data[pos].physicals like:
## { "height_in": {"mu": 74, "sigma": 1.5, "min": 68, "max": 80}, ... }

static func _sample_gauss(mu: float, sigma: float, lo: float, hi: float) -> float:
	if sigma <= 0.0:
		return clamp(mu, lo, hi)
	return clamp(mu + randfn(0.0, sigma), lo, hi)

static func roll_for_position(pos: String, positions_data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var pdef: Dictionary = positions_data.get(pos, {}) as Dictionary
	var phys: Dictionary = pdef.get("physicals", {}) as Dictionary
	for key in phys.keys():
		var d: Dictionary = phys[key] as Dictionary
		var mu := float(d.get("mu", 0.0))
		var sigma := float(d.get("sigma", 0.0))
		var lo := float(d.get("min", -1e9))
		var hi := float(d.get("max",  1e9))
		out[key] = _sample_gauss(mu, sigma, lo, hi)
	return out