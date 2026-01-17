extends RefCounted
class_name ScoutingReportGenerator

## Scouting Report Generator - Template-Based Player Reports
##
## Generates realistic scouting reports with strengths, weaknesses, pro comparisons,
## and draft grades. Uses template-based generation with player stats to create
## contextual descriptions.
##
## Report Components:
##   - Strengths (3-5 bullet points based on top stats)
##   - Weaknesses (2-4 bullet points based on low stats)
##   - Pro Comparison (similar NFL player based on position/archetype)
##   - Draft Grade (round projection based on overall rating)
##   - Confidence (0.0-1.0 based on data availability)
##
## Design:
##   - Stateless RefCounted service
##   - Deterministic via explicit RNG seeding: seed ^ hash(player_id)
##   - Template-based (no complex NLG)
##   - Performance: <100ms for full draft pool
##
## Integration:
##   - Called by PreDraftProcess during draft_prep phase
##   - Stores report in player["draft_intelligence"]["scouting_report"]
##   - Used by UI to display player evaluations
##
## RNG Consumption Pattern:
##   - generate_report:
##     - 1 RNG init per player
##     - 3-5 randi calls for strength template selection
##     - 2-4 randi calls for weakness template selection
##     - 1 randi call for pro comparison selection

const Rand = preload("res://autoloads/Rand.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Magic number for scouting report seed derivation
const SCOUT_SEED_MAGIC := 0x5C0D7100

## Stat threshold for identifying strengths (must be >= this to highlight)
const STRENGTH_THRESHOLD := 70.0

## Stat threshold for identifying weaknesses (must be <= this to flag)
const WEAKNESS_THRESHOLD := 65.0

## Minimum strengths to generate
const MIN_STRENGTHS := 3

## Maximum strengths to generate
const MAX_STRENGTHS := 5

## Minimum weaknesses to generate
const MIN_WEAKNESSES := 2

## Maximum weaknesses to generate
const MAX_WEAKNESSES := 4

## Stat-to-strength template mappings
## Keys are stat names, values are arrays of descriptive phrases
const STRENGTH_TEMPLATES := {
	"speed": [
		"Elite speed for position",
		"Outstanding acceleration",
		"Track star speed",
		"Game-changing straight-line speed",
		"Blazing fast"
	],
	"strength": [
		"Exceptional strength",
		"Powerful at point of attack",
		"Physical specimen",
		"Dominant in the trenches",
		"Overwhelming power"
	],
	"agility": [
		"Excellent agility",
		"Fluid movement",
		"Quick feet",
		"Explosive lateral quickness",
		"Smooth change of direction"
	],
	"awareness": [
		"High football IQ",
		"Reads the game well",
		"Instinctive player",
		"Outstanding field vision",
		"Cerebral approach"
	],
	"acceleration": [
		"Explosive first step",
		"Quick burst",
		"Gets to top speed fast",
		"Electric off the snap",
		"Devastating acceleration"
	],
	"arm_strength": [
		"Cannon arm",
		"Can make every throw",
		"Effortless deep ball",
		"Plus arm strength",
		"NFL-caliber arm"
	],
	"accuracy": [
		"Pinpoint accuracy",
		"Excellent ball placement",
		"Throws with anticipation",
		"Tight spiral",
		"Consistently on target"
	],
	"catching": [
		"Sure hands",
		"Reliable pass catcher",
		"Strong catch radius",
		"Soft hands",
		"Makes difficult catches look easy"
	],
	"route_running": [
		"Crisp route runner",
		"Creates separation",
		"Polished routes",
		"Sells routes effectively",
		"Elite route tree"
	],
	"blocking": [
		"Dominant blocker",
		"Excellent technique",
		"Anchor in pass protection",
		"Punishing run blocker",
		"Technical fundamentals"
	],
	"coverage": [
		"Lockdown coverage",
		"Blankets receivers",
		"Ball hawk in zone",
		"Sticky in man coverage",
		"Shutdown corner potential"
	],
	"tackling": [
		"Sure tackler",
		"Wraps up consistently",
		"Physical in run support",
		"Reliable in space",
		"Textbook technique"
	],
	"pass_rush": [
		"Elite edge rusher",
		"Dominant pass rusher",
		"Disruptive off the edge",
		"Natural bend",
		"Relentless motor"
	]
}

## Stat-to-weakness template mappings
const WEAKNESS_TEMPLATES := {
	"speed": [
		"Below-average speed",
		"Lacks ideal speed",
		"Speed is a concern",
		"Limited top-end speed",
		"May struggle vs NFL speed"
	],
	"strength": [
		"Needs to add strength",
		"Lacks power",
		"Can be overpowered",
		"Must get stronger",
		"Thin frame concerns"
	],
	"agility": [
		"Limited agility",
		"Stiff in movement",
		"Needs to improve flexibility",
		"Tight hips",
		"Struggles with direction changes"
	],
	"awareness": [
		"Inconsistent reads",
		"Needs to improve instincts",
		"Processing speed concerns",
		"Mental lapses",
		"Slow to diagnose"
	],
	"acceleration": [
		"Slow to accelerate",
		"Lacks explosion",
		"Needs quicker first step",
		"Takes time to get going",
		"Lacks burst"
	],
	"arm_strength": [
		"Limited arm strength",
		"Struggles on deep balls",
		"Ball dies on long throws",
		"Arm may not translate",
		"Velocity concerns"
	],
	"accuracy": [
		"Inconsistent accuracy",
		"Misses high too often",
		"Ball placement issues",
		"Struggles under pressure",
		"Must tighten mechanics"
	],
	"catching": [
		"Concentration drops",
		"Hands are inconsistent",
		"Body catches too often",
		"Struggles with contested balls",
		"Focus lapses"
	],
	"route_running": [
		"Raw route runner",
		"Rounds off routes",
		"Limited route tree",
		"Needs refinement",
		"Telegraphs routes"
	],
	"blocking": [
		"Blocking needs work",
		"Struggles with technique",
		"Inconsistent effort",
		"Gets pushed back",
		"Blocking liability"
	],
	"coverage": [
		"Coverage concerns",
		"Gets beat deep",
		"Struggles in zone",
		"Hip tightness limits coverage",
		"Ball skills need work"
	],
	"tackling": [
		"Tackling is inconsistent",
		"Misses in space",
		"Avoids contact at times",
		"Arm tackler",
		"Must improve angles"
	],
	"pass_rush": [
		"Limited pass rush moves",
		"Gets washed out",
		"Lacks counter moves",
		"Inconsistent effort",
		"Needs better technique"
	]
}

## Generic strengths when stat-specific ones not available
const GENERIC_STRENGTHS := [
	"Solid fundamentals",
	"Good work ethic",
	"Coachable player",
	"Team captain",
	"High motor",
	"Competitive spirit",
	"Film junkie",
	"Leader on and off field"
]

## Generic weaknesses when stat-specific ones not available
const GENERIC_WEAKNESSES := [
	"Needs refinement",
	"Raw prospect",
	"Inconsistent tape",
	"Developmental player",
	"Limited experience",
	"Must improve consistency",
	"Learning curve ahead",
	"Needs NFL coaching"
]

## Pro comparisons by position and tier
## Tiers: elite (85+), starter (75-84), developmental (<75)
const PRO_COMPARISONS := {
	"QB": {
		"elite": ["Patrick Mahomes", "Josh Allen", "Joe Burrow", "Lamar Jackson", "Justin Herbert"],
		"starter": ["Jared Goff", "Kirk Cousins", "Derek Carr", "Geno Smith", "Jalen Hurts"],
		"developmental": ["Baker Mayfield", "Sam Darnold", "Mac Jones", "Daniel Jones", "Tua Tagovailoa"]
	},
	"RB": {
		"elite": ["Christian McCaffrey", "Derrick Henry", "Nick Chubb", "Jonathan Taylor", "Saquon Barkley"],
		"starter": ["Aaron Jones", "Josh Jacobs", "Joe Mixon", "Alvin Kamara", "Travis Etienne"],
		"developmental": ["Damien Harris", "Tony Pollard", "AJ Dillon", "Raheem Mostert", "Antonio Gibson"]
	},
	"WR": {
		"elite": ["Justin Jefferson", "Tyreek Hill", "Ja'Marr Chase", "Davante Adams", "CeeDee Lamb"],
		"starter": ["Tyler Lockett", "Amari Cooper", "Mike Evans", "DJ Moore", "Terry McLaurin"],
		"developmental": ["Josh Palmer", "Nico Collins", "Rondale Moore", "Treylon Burks", "Jahan Dotson"]
	},
	"TE": {
		"elite": ["Travis Kelce", "George Kittle", "T.J. Hockenson", "Mark Andrews", "Dallas Goedert"],
		"starter": ["Pat Freiermuth", "David Njoku", "Evan Engram", "Cole Kmet", "Dalton Schultz"],
		"developmental": ["Isaiah Likely", "Trey McBride", "Greg Dulcich", "Chigoziem Okonkwo", "Cade Otton"]
	},
	"OT": {
		"elite": ["Trent Williams", "Penei Sewell", "Tristan Wirfs", "Laremy Tunsil", "Lane Johnson"],
		"starter": ["Andrew Thomas", "Dion Dawkins", "Rashawn Slater", "Christian Darrisaw", "Tyron Smith"],
		"developmental": ["Peter Skoronski", "Paris Johnson", "Broderick Jones", "Dawand Jones", "Anton Harrison"]
	},
	"OG": {
		"elite": ["Quenton Nelson", "Zack Martin", "Joel Bitonio", "Chris Lindstrom", "Kevin Zeitler"],
		"starter": ["Landon Dickerson", "Tyler Smith", "Elgton Jenkins", "Dalton Risner", "Austin Jackson"],
		"developmental": ["O'Cyrus Torrence", "Steve Avila", "Matthew Bergeron", "Joe Tippmann", "Cody Mauch"]
	},
	"C": {
		"elite": ["Jason Kelce", "Creed Humphrey", "Frank Ragnow", "Tyler Linderbaum", "Corey Linsley"],
		"starter": ["Erik McCoy", "Cesar Ruiz", "Connor McGovern", "Lloyd Cushenberry", "Cam Jurgens"],
		"developmental": ["Luke Fortner", "Olusegun Oluwatimi", "John Michael Schmitz", "Drew Dalman", "Nick Gates"]
	},
	"DE": {
		"elite": ["Myles Garrett", "Nick Bosa", "Micah Parsons", "Maxx Crosby", "T.J. Watt"],
		"starter": ["Josh Sweat", "Haason Reddick", "Rashan Gary", "Brian Burns", "Montez Sweat"],
		"developmental": ["Will Anderson Jr", "Tyree Wilson", "Lukas Van Ness", "Nolan Smith", "Myles Murphy"]
	},
	"DT": {
		"elite": ["Aaron Donald", "Chris Jones", "Quinnen Williams", "Javon Hargrave", "DeForest Buckner"],
		"starter": ["Daron Payne", "Derrick Brown", "Jonathan Allen", "Grady Jarrett", "Jeffery Simmons"],
		"developmental": ["Jalen Carter", "Bryan Bresee", "Calijah Kancey", "Siaki Ika", "Keeanu Benton"]
	},
	"LB": {
		"elite": ["Fred Warner", "Roquan Smith", "Lavonte David", "Devin White", "Bobby Wagner"],
		"starter": ["Foyesade Oluokun", "Tremaine Edmunds", "Zack Baun", "Pete Werner", "Jordyn Brooks"],
		"developmental": ["Jack Campbell", "Drew Sanders", "Daiyan Henley", "Trenton Simpson", "Owen Pappoe"]
	},
	"CB": {
		"elite": ["Jalen Ramsey", "Patrick Surtain II", "Sauce Gardner", "Denzel Ward", "Tre'Davious White"],
		"starter": ["Darius Slay", "Trevon Diggs", "Carlton Davis", "James Bradberry", "Jaycee Horn"],
		"developmental": ["Christian Gonzalez", "Devon Witherspoon", "Joey Porter Jr", "Kelee Ringo", "Cam Smith"]
	},
	"S": {
		"elite": ["Jessie Bates", "Minkah Fitzpatrick", "Derwin James", "Kyle Hamilton", "Antoine Winfield Jr"],
		"starter": ["Jordan Poyer", "Marcus Williams", "Talanoa Hufanga", "Julian Love", "Justin Simmons"],
		"developmental": ["Brian Branch", "Ji'Ayir Brown", "Antonio Johnson", "Sydney Brown", "Jordan Battle"]
	},
	"K": {
		"elite": ["Justin Tucker", "Harrison Butker", "Evan McPherson", "Tyler Bass", "Jake Elliott"],
		"starter": ["Graham Gano", "Brandon McManus", "Jason Myers", "Cairo Santos", "Matt Gay"],
		"developmental": ["Cade York", "Jake Moody", "Chad Ryland", "Anders Carlson", "Blake Grupe"]
	},
	"P": {
		"elite": ["Tommy Townsend", "AJ Cole", "Jake Bailey", "Bryan Anger", "Tress Way"],
		"starter": ["Michael Dickson", "Riley Dixon", "Jordan Stout", "Braden Mann", "Logan Cooke"],
		"developmental": ["Bryce Baringer", "Brad Robbins", "Ethan Evans", "Jack Podlesny", "Michael Turk"]
	}
}

## Draft grade thresholds (overall rating -> grade string)
const DRAFT_GRADE_THRESHOLDS := [
	{"min": 90.0, "grade": "Early 1st"},
	{"min": 85.0, "grade": "Mid 1st"},
	{"min": 80.0, "grade": "Late 1st"},
	{"min": 75.0, "grade": "Early 2nd"},
	{"min": 70.0, "grade": "Mid 2nd - Early 3rd"},
	{"min": 65.0, "grade": "Mid 3rd - 4th"},
	{"min": 60.0, "grade": "5th - 6th"},
	{"min": 0.0, "grade": "Late Round / Undrafted"}
]


## Generate all scouting reports for draft pool.
##
## Primary entry point for batch generation. Processes entire draft pool
## in a single pass.
##
## Performance: <100ms for ~250 player draft pool
##
## Side effects:
##   - Adds "scouting_report" to player["draft_intelligence"]
##
## RNG consumption:
##   - 1 RNG init per player
##   - ~8-15 randi calls per player (template selection)
##
## @param draft_pool: Array of draft-eligible players (mutated in place)
## @param positions_cfg: Position configuration for rating calculation
## @param class_rules: Class rules configuration
## @param seed: Base seed for determinism
static func generate_all_reports(
	draft_pool: Array,
	positions_cfg: Dictionary,
	class_rules: Dictionary,
	seed: int
) -> void:
	for player in draft_pool:
		var p: Dictionary = player

		if not p.has("draft_intelligence"):
			p["draft_intelligence"] = {}

		var report := generate_report(p, positions_cfg, class_rules, seed)
		(p["draft_intelligence"] as Dictionary)["scouting_report"] = report


## Generate scouting report for single player.
##
## Creates a complete scouting report with strengths, weaknesses,
## pro comparison, draft grade, and confidence level.
##
## RNG consumption:
##   - 1 seed initialization
##   - 3-5 randi calls for strengths
##   - 2-4 randi calls for weaknesses
##   - 1 randi call for pro comparison
##
## @param player: Player dictionary
## @param positions_cfg: Position configuration
## @param class_rules: Class rules configuration
## @param seed: Base seed for deterministic generation
## @return Dictionary: Complete scouting report
static func generate_report(
	player: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary,
	seed: int
) -> Dictionary:
	# Initialize RNG with player-specific seed
	var rng := RandomNumberGenerator.new()
	var player_id := String(player.get("player_id", player.get("id", "")))
	rng.seed = Rand.splitmix64(seed ^ (SCOUT_SEED_MAGIC + hash(player_id)))

	var position := String(player.get("position", "ATH"))
	var overall := PlayerRatingCalculator.calculate_overall_rating(
		player, positions_cfg, class_rules
	)

	# Generate report components
	var strengths := _generate_strengths(player, position, rng)
	var weaknesses := _generate_weaknesses(player, position, rng)
	var pro_comp := _generate_pro_comparison(player, position, overall, rng)
	var draft_grade := _calculate_draft_grade(overall)
	var confidence := _calculate_confidence(player)

	return {
		"strengths": strengths,
		"weaknesses": weaknesses,
		"pro_comparison": pro_comp,
		"draft_grade": draft_grade,
		"confidence": confidence,
		"overall_grade": overall,
		"generated_week": 7  # Draft prep week
	}


## Generate strength bullet points based on player stats.
##
## Identifies top stats and generates appropriate descriptions.
## Guarantees MIN_STRENGTHS to MAX_STRENGTHS items.
##
## RNG consumption: 1 randi call per strength generated
##
## @param player: Player dictionary
## @param position: Player position
## @param rng: RNG instance
## @return Array[String]: 3-5 strength descriptions
static func _generate_strengths(
	player: Dictionary,
	position: String,
	rng: RandomNumberGenerator
) -> Array:
	var strengths: Array = []
	var stats: Dictionary = player.get("stats", {})

	if stats.is_empty():
		stats = _extract_stats_from_player(player)

	# Sort stats by value (highest first)
	var stat_pairs: Array = []
	for stat_name in stats.keys():
		stat_pairs.append({
			"name": String(stat_name),
			"value": float(stats[stat_name])
		})

	stat_pairs.sort_custom(func(a, b):
		return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
	)

	# Generate strengths from top stats
	var used_templates: Dictionary = {}  # Avoid duplicates

	for stat in stat_pairs:
		if strengths.size() >= MAX_STRENGTHS:
			break

		var stat_name := String(stat.get("name", ""))
		var value := float(stat.get("value", 0.0))

		if value < STRENGTH_THRESHOLD:
			break  # Only highlight high stats

		var strength := _stat_to_strength(stat_name, value, position, rng)
		if not strength.is_empty() and not used_templates.has(strength):
			strengths.append(strength)
			used_templates[strength] = true

	# Ensure minimum strengths with generics
	while strengths.size() < MIN_STRENGTHS:
		var generic := _get_generic_strength(position, rng)
		if not used_templates.has(generic):
			strengths.append(generic)
			used_templates[generic] = true

	return strengths


## Generate weakness bullet points based on player stats.
##
## Identifies low stats and generates appropriate descriptions.
## Guarantees MIN_WEAKNESSES to MAX_WEAKNESSES items.
##
## RNG consumption: 1 randi call per weakness generated
##
## @param player: Player dictionary
## @param position: Player position
## @param rng: RNG instance
## @return Array[String]: 2-4 weakness descriptions
static func _generate_weaknesses(
	player: Dictionary,
	position: String,
	rng: RandomNumberGenerator
) -> Array:
	var weaknesses: Array = []
	var stats: Dictionary = player.get("stats", {})

	if stats.is_empty():
		stats = _extract_stats_from_player(player)

	# Sort stats by value (lowest first)
	var stat_pairs: Array = []
	for stat_name in stats.keys():
		stat_pairs.append({
			"name": String(stat_name),
			"value": float(stats[stat_name])
		})

	stat_pairs.sort_custom(func(a, b):
		return float(a.get("value", 0.0)) < float(b.get("value", 0.0))
	)

	# Generate weaknesses from low stats
	var used_templates: Dictionary = {}

	for stat in stat_pairs:
		if weaknesses.size() >= MAX_WEAKNESSES:
			break

		var stat_name := String(stat.get("name", ""))
		var value := float(stat.get("value", 0.0))

		if value > WEAKNESS_THRESHOLD:
			break  # Only flag low stats

		var weakness := _stat_to_weakness(stat_name, value, position, rng)
		if not weakness.is_empty() and not used_templates.has(weakness):
			weaknesses.append(weakness)
			used_templates[weakness] = true

	# Ensure minimum weaknesses with generics
	while weaknesses.size() < MIN_WEAKNESSES:
		var generic := _get_generic_weakness(position, rng)
		if not used_templates.has(generic):
			weaknesses.append(generic)
			used_templates[generic] = true

	return weaknesses


## Convert stat to strength description.
##
## RNG: 1 randi call
##
## @param stat_name: Stat name
## @param value: Stat value
## @param position: Player position
## @param rng: RNG instance
## @return String: Strength description or empty if no template
static func _stat_to_strength(
	stat_name: String,
	value: float,
	position: String,
	rng: RandomNumberGenerator
) -> String:
	var templates: Array = STRENGTH_TEMPLATES.get(stat_name, [])
	if templates.is_empty():
		return ""

	return templates[rng.randi() % templates.size()] as String


## Convert stat to weakness description.
##
## RNG: 1 randi call
##
## @param stat_name: Stat name
## @param value: Stat value
## @param position: Player position
## @param rng: RNG instance
## @return String: Weakness description or empty if no template
static func _stat_to_weakness(
	stat_name: String,
	value: float,
	position: String,
	rng: RandomNumberGenerator
) -> String:
	var templates: Array = WEAKNESS_TEMPLATES.get(stat_name, [])
	if templates.is_empty():
		return ""

	return templates[rng.randi() % templates.size()] as String


## Get generic strength template.
##
## RNG: 1 randi call
##
## @param position: Player position
## @param rng: RNG instance
## @return String: Generic strength
static func _get_generic_strength(position: String, rng: RandomNumberGenerator) -> String:
	return GENERIC_STRENGTHS[rng.randi() % GENERIC_STRENGTHS.size()] as String


## Get generic weakness template.
##
## RNG: 1 randi call
##
## @param position: Player position
## @param rng: RNG instance
## @return String: Generic weakness
static func _get_generic_weakness(position: String, rng: RandomNumberGenerator) -> String:
	return GENERIC_WEAKNESSES[rng.randi() % GENERIC_WEAKNESSES.size()] as String


## Generate pro comparison based on position and rating tier.
##
## RNG: 1 randi call
##
## @param player: Player dictionary
## @param position: Player position
## @param overall: Overall rating
## @param rng: RNG instance
## @return String: Pro comparison text ("Similar to [Player]")
static func _generate_pro_comparison(
	player: Dictionary,
	position: String,
	overall: float,
	rng: RandomNumberGenerator
) -> String:
	# Determine tier based on overall rating
	var tier := "developmental"
	if overall >= 85.0:
		tier = "elite"
	elif overall >= 75.0:
		tier = "starter"

	# Get position comparisons (fallback to generic if position not found)
	var pos_comps: Dictionary = PRO_COMPARISONS.get(position, {})
	if pos_comps.is_empty():
		# Try to map to a common position
		pos_comps = PRO_COMPARISONS.get("WR", {})  # Default fallback

	var tier_comps: Array = pos_comps.get(tier, ["Generic NFL Player"])
	var comp := tier_comps[rng.randi() % tier_comps.size()] as String

	return "Similar to %s" % comp


## Calculate draft grade from overall rating.
##
## @param overall: Overall rating
## @return String: Draft grade ("Early 1st", "Mid 2nd", etc.)
static func _calculate_draft_grade(overall: float) -> String:
	for threshold in DRAFT_GRADE_THRESHOLDS:
		var t: Dictionary = threshold
		if overall >= float(t.get("min", 0.0)):
			return String(t.get("grade", "Undrafted"))

	return "Late Round / Undrafted"


## Calculate report confidence based on data availability.
##
## Factors:
##   - Combine data: +0.20
##   - All-star games: +0.15
##   - Team visits: +0.15
##   - Base: 0.50
##
## @param player: Player dictionary
## @return float: Confidence (0.0-1.0)
static func _calculate_confidence(player: Dictionary) -> float:
	var confidence := 0.5  # Base confidence

	# Higher confidence if player has combine data
	if player.has("combine"):
		var combine_data: Dictionary = player.get("combine", {})
		if not combine_data.is_empty():
			confidence += 0.2

	# Check pre_draft_process for additional data
	var pre_draft: Dictionary = player.get("pre_draft_process", {})

	# Higher confidence if combine invited
	if bool(pre_draft.get("combine_invited", false)):
		confidence += 0.1

	# Higher confidence if attended all-star games
	var all_star_games: Array = pre_draft.get("all_star_games", [])
	if not all_star_games.is_empty():
		confidence += 0.15

	# Higher confidence if had team visits
	var team_visits: Array = pre_draft.get("team_visits", [])
	if not team_visits.is_empty():
		confidence += 0.15

	return clamp(confidence, 0.0, 1.0)


## Extract stats from player when not in nested "stats" dict.
##
## @param player: Player dictionary
## @return Dictionary: Stats dictionary
static func _extract_stats_from_player(player: Dictionary) -> Dictionary:
	var stats := {}
	var skip_keys := ["player_id", "id", "name", "position", "age", "year",
					  "college_year", "hs_year", "draft_intelligence",
					  "pre_draft_process", "contract", "draft_info",
					  "combine", "physicals", "traits", "hidden_traits"]

	for key in player.keys():
		if key in skip_keys:
			continue
		var value = player[key]
		if value is float or value is int:
			# Skip non-rating fields
			if float(value) >= 0.0 and float(value) <= 100.0:
				stats[key] = float(value)

	return stats


## Get report summary for quick display.
##
## @param player: Player dictionary with scouting report
## @return String: Brief summary of player
static func get_report_summary(player: Dictionary) -> String:
	var di: Dictionary = player.get("draft_intelligence", {})
	var report: Dictionary = di.get("scouting_report", {})

	if report.is_empty():
		return "No scouting report available"

	var grade := String(report.get("draft_grade", "Unknown"))
	var comparison := String(report.get("pro_comparison", "Unknown comparison"))
	var confidence := float(report.get("confidence", 0.0))

	var conf_text := "Low"
	if confidence >= 0.8:
		conf_text = "High"
	elif confidence >= 0.6:
		conf_text = "Medium"

	return "%s | %s | Confidence: %s" % [grade, comparison, conf_text]


## Get full report as formatted text.
##
## @param player: Player dictionary with scouting report
## @return String: Full formatted report
static func get_formatted_report(player: Dictionary) -> String:
	var di: Dictionary = player.get("draft_intelligence", {})
	var report: Dictionary = di.get("scouting_report", {})

	if report.is_empty():
		return "No scouting report available"

	var name := String(player.get("name", "Unknown"))
	var position := String(player.get("position", "ATH"))

	var lines: Array = []
	lines.append("=== SCOUTING REPORT ===")
	lines.append("%s - %s" % [name, position])
	lines.append("")
	lines.append("Grade: %s" % String(report.get("draft_grade", "Unknown")))
	lines.append("Pro Comparison: %s" % String(report.get("pro_comparison", "Unknown")))
	lines.append("")
	lines.append("STRENGTHS:")
	for strength in report.get("strengths", []):
		lines.append("  - %s" % String(strength))
	lines.append("")
	lines.append("WEAKNESSES:")
	for weakness in report.get("weaknesses", []):
		lines.append("  - %s" % String(weakness))
	lines.append("")
	var conf := float(report.get("confidence", 0.0))
	lines.append("Confidence: %.0f%%" % (conf * 100.0))

	return "\n".join(lines)
