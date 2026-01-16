@icon("res://icon.svg")
# res://scripts/core/models/CombineResults.gd
extends Resource
class_name CombineResults

## NFL Combine test results and medical evaluation
## Extracted from Player.gd to reduce complexity
## Nullable - players who haven't done a combine have null combine field

# --- Timed Drills (seconds) ---
@export var forty_sec: float = 0.0          # 40-yard dash time
@export var shuttle20_sec: float = 0.0      # 20-yard shuttle time
@export var cone3_sec: float = 0.0          # 3-cone drill time
@export var shuttle60_sec: float = 0.0      # 60-yard shuttle time

# --- Strength & Athleticism ---
@export var vertical_in: float = 0.0        # Vertical jump (inches)
@export var broad_in: float = 0.0           # Broad jump (inches)
@export var bench_225_reps: int = 0         # Bench press reps at 225 lbs

# --- Cognitive & Medical ---
@export var wonderlic: int = 0              # Wonderlic test score (0-50)
@export var cybex_index: float = 0.0        # Cybex strength index

@export var injury_eval: String = "normal"  # Injury evaluation result
@export var drug_screen: String = "negative" # Drug screening result

@export var combine_year: int = 0           # Year player participated (0 = not done)

## Check if player has completed a combine
func has_completed_combine() -> bool:
	return combine_year > 0

## Calculate composite athleticism score (0-100 scale)
## Based on 40-yard dash, vertical jump, and broad jump
func get_athleticism_score() -> float:
	if not has_completed_combine():
		return 0.0

	# Lower times are better for 40-yard dash (4.2-5.2 range)
	var forty_score = remap(forty_sec, 5.2, 4.2, 0, 100)

	# Higher is better for jumps
	var vert_score = remap(vertical_in, 24, 44, 0, 100)
	var broad_score = remap(broad_in, 96, 132, 0, 100)

	# Clamp all scores
	forty_score = clamp(forty_score, 0, 100)
	vert_score = clamp(vert_score, 0, 100)
	broad_score = clamp(broad_score, 0, 100)

	# Average the three
	return (forty_score + vert_score + broad_score) / 3.0

## Deserialize from dictionary
func from_dict(d: Dictionary) -> void:
	forty_sec = float(d.get("forty_sec", forty_sec))
	shuttle20_sec = float(d.get("shuttle20_sec", shuttle20_sec))
	cone3_sec = float(d.get("cone3_sec", cone3_sec))
	shuttle60_sec = float(d.get("shuttle60_sec", shuttle60_sec))
	vertical_in = float(d.get("vertical_in", vertical_in))
	broad_in = float(d.get("broad_in", broad_in))
	bench_225_reps = int(d.get("bench_225_reps", bench_225_reps))
	wonderlic = int(d.get("wonderlic", wonderlic))
	cybex_index = float(d.get("cybex_index", cybex_index))
	injury_eval = String(d.get("injury_eval", injury_eval))
	drug_screen = String(d.get("drug_screen", drug_screen))
	combine_year = int(d.get("combine_year", combine_year))

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"forty_sec": forty_sec,
		"shuttle20_sec": shuttle20_sec,
		"cone3_sec": cone3_sec,
		"shuttle60_sec": shuttle60_sec,
		"vertical_in": vertical_in,
		"broad_in": broad_in,
		"bench_225_reps": bench_225_reps,
		"wonderlic": wonderlic,
		"cybex_index": cybex_index,
		"injury_eval": injury_eval,
		"drug_screen": drug_screen,
		"combine_year": combine_year
	}
