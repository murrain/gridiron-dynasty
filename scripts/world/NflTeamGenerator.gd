extends RefCounted
class_name NflTeamGenerator

const ConfigService = preload("res://autoloads/Config.gd")
const CoachGenerator = preload("res://scripts/generation/CoachGenerator.gd")

const DEFAULT_CONFIG_KEY := "world/league"

## Scouting philosophy options
## - analytics_heavy: Trust data over gut, comfortable with unknowns if metrics are good
## - traditional: Trust scouts' eyes, want certainty on picks
## - aggressive: Swing for the fences, willing to gamble on upside
const SCOUTING_PHILOSOPHIES := ["analytics_heavy", "traditional", "aggressive"]

## Weights for scouting philosophy generation (matches config)
const PHILOSOPHY_WEIGHTS := {
	"analytics_heavy": 0.25,  # 25% of teams
	"traditional": 0.50,      # 50% of teams (most common)
	"aggressive": 0.25        # 25% of teams
}

## Hype susceptibility ranges by category
const HYPE_SUSCEPTIBILITY_RANGES := {
	"analytics_focused": {"min": 0.15, "max": 0.35},
	"balanced": {"min": 0.40, "max": 0.60},
	"narrative_driven": {"min": 0.65, "max": 0.85}
}

## Hype category weights for generation
const HYPE_CATEGORY_WEIGHTS := {
	"analytics_focused": 0.20,  # 20% of teams
	"balanced": 0.55,           # 55% of teams
	"narrative_driven": 0.25    # 25% of teams
}

var _config: Node = null

func _get_config_service() -> Node:
	if _config == null:
		_config = ConfigService.new()
	return _config

func generate(seed: int, config_key: String = DEFAULT_CONFIG_KEY) -> Dictionary:
	var cfg: Dictionary = _get_config_service().get_config(config_key)
	if cfg.is_empty():
		push_error("NflTeamGenerator: missing config '%s'." % config_key)
		return {"teams": [], "config": {}}
	if not _validate_config(cfg):
		return {"teams": [], "config": cfg}

	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	var team_count := int(cfg.get("team_count", 0))
	var name_format := String(cfg.get("name_format", "Team %03d"))
	var cap_limit := float(cfg.get("cap_limit", 0.0))

	var regions: Array = cfg.get("regions", []) as Array
	var region_weights := _weights_for(regions)

	var teams: Array = []
	teams.resize(team_count)
	for i in range(team_count):
		var region: Dictionary = _weighted_pick(regions, region_weights, rng)
		var team_id := "nfl_%03d" % (i + 1)
		var team := {
			"id": team_id,
			"name": name_format % (i + 1),
			"region": String(region.get("id", "")),
			"cap_space": cap_limit,
			"roster": [],
			"draft_order": i + 1
		}

		# Generate coaching staff for this NFL team
		# NFL teams get higher quality coaches (base eliteness 70)
		var coaching_staff := CoachGenerator.generate_coaching_staff(rng, team_id, 70.0)
		team["coach"] = coaching_staff["head_coach"]
		team["coaching_staff"] = coaching_staff

		# Generate draft evaluation attributes
		# RNG: 2 calls for scouting_philosophy, 2 calls for hype_susceptibility
		var draft_attrs := _generate_draft_evaluation_attributes(rng)
		team["scouting_philosophy"] = draft_attrs["scouting_philosophy"]
		team["hype_susceptibility"] = draft_attrs["hype_susceptibility"]
		team["hype_category"] = draft_attrs["hype_category"]

		teams[i] = team

	return {"teams": teams, "config": cfg}

func _validate_config(cfg: Dictionary) -> bool:
	var team_count := int(cfg.get("team_count", 0))
	if team_count <= 0:
		push_error("NflTeamGenerator: 'team_count' must be > 0.")
		return false

	var regions: Array = cfg.get("regions", []) as Array
	if regions.is_empty():
		push_error("NflTeamGenerator: config must include non-empty 'regions'.")
		return false

	var region_ids := {}
	var region_weight_total := 0.0
	for region in regions:
		var region_dict: Dictionary = region
		var region_id := String(region_dict.get("id", ""))
		var weight := float(region_dict.get("weight", 0.0))
		if region_id == "":
			push_error("NflTeamGenerator: region missing 'id'.")
			return false
		if region_ids.has(region_id):
			push_error("NflTeamGenerator: duplicate region id '%s'." % region_id)
			return false
		if weight <= 0.0:
			push_error("NflTeamGenerator: region '%s' has non-positive weight." % region_id)
			return false
		region_ids[region_id] = true
		region_weight_total += weight

	if region_weight_total <= 0.0:
		push_error("NflTeamGenerator: region weights must sum > 0.")
		return false
	if abs(region_weight_total - 1.0) > 0.01:
		push_error("NflTeamGenerator: region weights must sum to 1.0 (got %.3f)." % region_weight_total)
		return false

	var roster_limits: Dictionary = cfg.get("roster_limits", {}) as Dictionary
	if not roster_limits.is_empty():
		var active := int(roster_limits.get("active", 0))
		if active <= 0:
			push_error("NflTeamGenerator: 'roster_limits.active' must be > 0.")
			return false

	var draft: Dictionary = cfg.get("draft", {}) as Dictionary
	if not draft.is_empty():
		var rounds := int(draft.get("rounds", 0))
		var picks_per_round := int(draft.get("picks_per_round", 0))
		if rounds <= 0:
			push_error("NflTeamGenerator: 'draft.rounds' must be > 0.")
			return false
		if picks_per_round <= 0:
			push_error("NflTeamGenerator: 'draft.picks_per_round' must be > 0.")
			return false

	return true

func _weights_for(items: Array) -> Array:
	var weights: Array = []
	weights.resize(items.size())
	for i in range(items.size()):
		weights[i] = float((items[i] as Dictionary).get("weight", 0.0))
	return weights

func _weighted_pick(items: Array, weights: Array, rng: RandomNumberGenerator) -> Dictionary:
	if items.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return items[0] as Dictionary

	var roll := rng.randf() * total
	var running := 0.0
	for i in range(items.size()):
		running += float(weights[i])
		if roll <= running:
			return items[i] as Dictionary

	return items[items.size() - 1] as Dictionary


## Generate draft evaluation attributes for a team
##
## Generates two key attributes that affect how a team evaluates draft prospects:
##
## 1. scouting_philosophy: How the team approaches unknown players
##    - analytics_heavy: Trust data, tolerant of unknowns (25% of teams)
##    - traditional: Trust scouts' eyes, want certainty (50% of teams)
##    - aggressive: Swing for the fences, gamble on upside (25% of teams)
##
## 2. hype_susceptibility: How much the team is influenced by media narratives
##    - analytics_focused (20%): 0.15-0.35 (largely ignore hype)
##    - balanced (55%): 0.40-0.60 (moderate influence)
##    - narrative_driven (25%): 0.65-0.85 (chase names and stories)
##
## RNG consumption pattern:
##   - 1 randf() call for philosophy category selection
##   - 1 randf() call for hype category selection
##   - 1 randf_range() call for hype susceptibility value within range
##
## Returns: Dictionary with keys:
##   - scouting_philosophy: String
##   - hype_susceptibility: float (0.15 to 0.85)
##   - hype_category: String (for debugging/display)
func _generate_draft_evaluation_attributes(rng: RandomNumberGenerator) -> Dictionary:
	# RNG Call 1: Select scouting philosophy
	var philosophy_roll := rng.randf()
	var philosophy := "traditional"  # Default
	var cumulative := 0.0
	for p in PHILOSOPHY_WEIGHTS.keys():
		cumulative += float(PHILOSOPHY_WEIGHTS[p])
		if philosophy_roll <= cumulative:
			philosophy = p
			break

	# RNG Call 2: Select hype category
	var hype_roll := rng.randf()
	var hype_category := "balanced"  # Default
	cumulative = 0.0
	for cat in HYPE_CATEGORY_WEIGHTS.keys():
		cumulative += float(HYPE_CATEGORY_WEIGHTS[cat])
		if hype_roll <= cumulative:
			hype_category = cat
			break

	# RNG Call 3: Generate susceptibility value within category range
	var range_data: Dictionary = HYPE_SUSCEPTIBILITY_RANGES.get(hype_category, {"min": 0.4, "max": 0.6})
	var min_val := float(range_data["min"])
	var max_val := float(range_data["max"])
	var susceptibility := rng.randf_range(min_val, max_val)

	return {
		"scouting_philosophy": philosophy,
		"hype_susceptibility": susceptibility,
		"hype_category": hype_category
	}
