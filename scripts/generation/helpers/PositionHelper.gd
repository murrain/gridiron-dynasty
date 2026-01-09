extends RefCounted
class_name PositionHelper
## PositionHelper
## - pick_position(positions_data, class_rules) -> String
## Uses weights if provided; otherwise uniform over positions_data keys.

static func pick_position(
	positions_data: Dictionary,
	class_rules: Dictionary,
	rng: RandomNumberGenerator = null
) -> String:
	var keys: Array = positions_data.keys()
	keys.sort() # stable
	if keys.is_empty():
		return "ATH"

	var weights: Dictionary = class_rules.get("position_weights", {}) as Dictionary
	if weights.is_empty():
		# fall back to equal chance
		var idx: int = int((rng.randi() if rng != null else randi()) % keys.size())
		return String(keys[idx])

	# Build weight vector in positions order
	var wsum := 0.0
	var w: Array = []
	for k in keys:
		var v: float = float(weights.get(String(k), 1.0))
		v = max(0.0, v)
		w.append(v)
		wsum += v
	if wsum <= 0.0:
		var idx2: int = int((rng.randi() if rng != null else randi()) % keys.size())
		return String(keys[idx2])

	var r := (rng.randf() if rng != null else randf()) * wsum
	for i in range(keys.size()):
		if r < w[i]:
			return String(keys[i])
		r -= w[i]
	return String(keys.back())
