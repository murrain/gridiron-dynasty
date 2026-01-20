extends RefCounted
class_name DraftTransformations

## Pure transformation functions for draft operations.
## All functions are side-effect-free and deterministic.
##
## CRITICAL: All functions are PURE - they never modify input dictionaries.
## They always return NEW dictionaries with the updated values.
##
## This module contains transformation logic for:
## - Scouting quality generation (team-specific deterministic quality metrics)
## - Draft pick allocation (initial ownership structures)
## - Pick execution (recording picks in draft state)
## - Pick trading (ownership transfers)

const Rand = preload("res://autoloads/Rand.gd")

# ============================================================================
# PURE FUNCTIONS - Draft Transformations
# ============================================================================

## Generate team scouting quality metrics (pure function).
##
## Quality determines scout skill (higher = better board accuracy) and
## board noise (higher = more variance in evaluations). Each team is assigned
## to a tier (elite/good/average/poor/terrible) based on configuration, then
## small jitter is added for deterministic variance.
##
## RNG consumption pattern:
## - 1 randf_range() call per team (for base_quality jitter)
##
## @param teams: Array of team dictionaries with "id" fields (unchanged)
## @param class_rules: Configuration dictionary with "draft_team_quality" section (unchanged)
## @param world_seed: Seed used for deterministic generation (hashed with team_id)
## @return: NEW Dictionary mapping team_id -> {
##   base_quality: float (0.0-1.0),
##   noise_modifier: float (multiplier for board_noise_sigma),
##   skill_modifier: float (multiplier for base_skill),
##   tier: String (quality tier name)
## }
##
## Algorithm:
##   1. Load quality tier configuration
##   2. For each team, determine tier assignment
##   3. Create team-specific RNG from world_seed XOR team_id hash
##   4. Apply small jitter to base_quality for variance within tier
##   5. Return NEW quality map (original inputs unchanged)
##
## Example:
##   var quality := DraftTransformations.generate_scouting_quality(teams, class_rules, 42)
##   assert(quality["BAL"]["tier"] == "elite")  # Ravens have elite scouting
##   assert(quality["CLE"]["tier"] == "terrible")  # Browns have terrible scouting
static func generate_scouting_quality(
	teams: Array,
	class_rules: Dictionary,
	world_seed: int
) -> Dictionary:
	var quality_cfg: Dictionary = class_rules.get("draft_team_quality", {})

	# If disabled, return neutral quality for all teams
	if not bool(quality_cfg.get("enabled", true)):
		var neutral := {}
		for team in teams:
			var t: Dictionary = team
			neutral[String(t.get("id", ""))] = {
				"base_quality": 0.50,
				"noise_modifier": 1.0,
				"skill_modifier": 1.0,
				"tier": "average"
			}
		return neutral

	var tiers: Dictionary = quality_cfg.get("quality_tiers", {})
	var quality_map := {}

	# Build tier lookup: team_id -> tier_name
	var team_to_tier := {}
	for tier_name in tiers.keys():
		var tier: Dictionary = tiers[tier_name]
		var team_list: Array = tier.get("teams", [])
		for tm in team_list:
			team_to_tier[String(tm)] = tier_name

	# Assign quality with deterministic jitter to avoid exact ties
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var tier_name := String(team_to_tier.get(team_id, "average"))
		var tier: Dictionary = tiers.get(tier_name, {})

		# Create team-specific RNG from world_seed XOR team_id hash
		# This ensures same seed + team always produces same quality
		var team_rng := RandomNumberGenerator.new()
		team_rng.seed = Rand.splitmix64(world_seed ^ hash(team_id))

		# Extract tier base values
		var base := float(tier.get("base_quality", 0.50))
		var noise := float(tier.get("noise_modifier", 1.0))
		var skill := float(tier.get("skill_modifier", 1.0))

		# Add small jitter to base_quality for variance within tier
		# RNG consumption: 1 randf_range() per team
		base += team_rng.randf_range(-0.05, 0.05)
		base = clamp(base, 0.2, 0.9)

		quality_map[team_id] = {
			"base_quality": base,
			"noise_modifier": noise,
			"skill_modifier": skill,
			"tier": tier_name
		}

	return quality_map


## Allocate draft pick ownership structure (pure function).
##
## Creates the initial ownership ledger where each team owns their own picks.
## This ledger is later modified by pick trades via apply_pick_trade().
##
## RNG consumption: NONE (deterministic initialization)
##
## @param teams: Array of team dictionaries with "id" fields (unchanged)
## @param year: Draft year to allocate picks for
## @param rounds: Number of draft rounds (typically 7)
## @return: NEW Dictionary structure:
##   {
##     year: {
##       round_num: {
##         original_team_id: current_owner_id
##       }
##     }
##   }
##
## Algorithm:
##   1. Create nested dictionary structure
##   2. For each round, initialize ownership mapping
##   3. Set each team to own their own picks by default
##   4. Return NEW ownership structure (original inputs unchanged)
##
## Example:
##   var ownership := DraftTransformations.allocate_draft_picks(teams, 2025, 7)
##   assert(ownership[2025][1]["SF"] == "SF")  # 49ers own their round 1 pick
##   assert(ownership[2025][3]["BAL"] == "BAL")  # Ravens own their round 3 pick
static func allocate_draft_picks(
	teams: Array,
	year: int,
	rounds: int
) -> Dictionary:
	var ownership := {}
	ownership[year] = {}

	var year_ownership: Dictionary = ownership[year]

	# Initialize each round
	for round_num in range(1, rounds + 1):
		year_ownership[round_num] = {}
		var round_ownership: Dictionary = year_ownership[round_num]

		# Each team owns their own pick by default
		for team in teams:
			var t: Dictionary = team
			var team_id := String(t.get("id", ""))
			if team_id != "":
				round_ownership[team_id] = team_id

	return ownership


## Apply a draft pick to the draft state (pure function).
##
## Records a completed draft pick by updating the undrafted pool and roster.
## Does NOT modify inputs - returns NEW dictionaries with changes applied.
##
## RNG consumption: NONE (deterministic state update)
##
## @param draft_pool: Array of eligible players (unchanged)
## @param rosters: Dictionary mapping team_id -> roster (unchanged)
## @param picked_player_id: ID of player being drafted
## @param team_id: ID of team making the pick
## @param draft_info: Dictionary with pick metadata (year, round, pick, team_id)
## @param contract: Contract dictionary for the drafted player
## @return: NEW Dictionary with keys:
##   {
##     "updated_pool": Array (players minus drafted player),
##     "updated_rosters": Dictionary (rosters with new player added),
##     "drafted_player": Dictionary (player with updated fields)
##   }
##
## Algorithm:
##   1. Deep copy draft_pool and rosters (immutability)
##   2. Find and remove picked player from pool
##   3. Update player with NFL team, contract, draft info
##   4. Add player to team roster
##   5. Update by_position mapping
##   6. Return NEW structures (original inputs unchanged)
##
## Example:
##   var result := DraftTransformations.apply_draft_pick(
##       pool, rosters, "player_123", "SF",
##       {"year": 2025, "round": 1, "pick": 13, "team_id": "SF"},
##       contract
##   )
##   assert(result.updated_pool.size() == pool.size() - 1)  # Player removed
##   assert(result.drafted_player["nfl_team_id"] == "SF")  # Player updated
static func apply_draft_pick(
	draft_pool: Array,
	rosters: Dictionary,
	picked_player_id: String,
	team_id: String,
	draft_info: Dictionary,
	contract: Dictionary
) -> Dictionary:
	# Step 1: Deep copy inputs (immutability)
	var new_pool := draft_pool.duplicate(true)
	var new_rosters := rosters.duplicate(true)

	# Step 2: Find and extract player from pool
	var picked_player: Dictionary = {}
	var new_pool_filtered: Array = []

	for player in new_pool:
		var p: Dictionary = player
		var pid := String(p.get("player_id", ""))
		if pid == picked_player_id:
			picked_player = p.duplicate(true)
		else:
			new_pool_filtered.append(p)

	if picked_player.is_empty():
		push_error("DraftTransformations.apply_draft_pick: Player %s not found in draft pool" % picked_player_id)
		return {
			"updated_pool": new_pool,
			"updated_rosters": new_rosters,
			"drafted_player": {}
		}

	# Step 3: Update player with NFL info
	picked_player["nfl_team_id"] = team_id
	picked_player["nfl_status"] = "active"
	picked_player["contract"] = contract
	picked_player["draft_info"] = draft_info.duplicate(true)

	# Flatten draft_year for RosterManagement compatibility
	picked_player["draft_year"] = int(draft_info.get("year", 0))

	# Initialize eval_score using composite_score for RosterManagement
	var composite := float(picked_player.get("composite_score", 50.0))
	picked_player["eval_score"] = composite

	# Step 4: Add to roster
	if not new_rosters.has(team_id):
		new_rosters[team_id] = {
			"players": [],
			"by_position": {}
		}

	var roster: Dictionary = new_rosters[team_id]
	var players: Array = roster.get("players", [])
	players.append(picked_player)
	roster["players"] = players

	# Step 5: Update by_position mapping
	var by_position: Dictionary = roster.get("by_position", {})
	var position := String(picked_player.get("position", ""))

	if position != "":
		if not by_position.has(position):
			by_position[position] = []
		(by_position[position] as Array).append(picked_player_id)
		roster["by_position"] = by_position

	new_rosters[team_id] = roster

	# Step 6: Return NEW structures (original inputs unchanged)
	return {
		"updated_pool": new_pool_filtered,
		"updated_rosters": new_rosters,
		"drafted_player": picked_player
	}


## Apply a pick trade to ownership structure (pure function).
##
## Transfers ownership of a draft pick from one team to another.
## Does NOT modify input - returns NEW ownership dictionary with transfer applied.
##
## RNG consumption: NONE (deterministic update)
##
## @param ownership: Current pick ownership dictionary (unchanged)
## @param year: Draft year of the pick
## @param round_num: Round number (1-7)
## @param original_team_id: Team that originally owned the pick
## @param new_owner_id: Team that now owns the pick
## @return: NEW ownership Dictionary with transfer applied
##
## Algorithm:
##   1. Deep copy ownership structure (immutability)
##   2. Navigate to year -> round -> original_team_id
##   3. Update ownership to new_owner_id
##   4. Return NEW ownership structure (original unchanged)
##
## Example:
##   var new_ownership := DraftTransformations.apply_pick_trade(
##       ownership, 2025, 1, "SF", "CHI"
##   )
##   assert(ownership[2025][1]["SF"] == "SF")  # Original unchanged
##   assert(new_ownership[2025][1]["SF"] == "CHI")  # New ownership updated
static func apply_pick_trade(
	ownership: Dictionary,
	year: int,
	round_num: int,
	original_team_id: String,
	new_owner_id: String
) -> Dictionary:
	# Step 1: Deep copy ownership (immutability)
	var new_ownership := ownership.duplicate(true)

	# Step 2: Ensure structure exists
	if not new_ownership.has(year):
		new_ownership[year] = {}

	var year_ownership: Dictionary = new_ownership[year]

	if not year_ownership.has(round_num):
		year_ownership[round_num] = {}

	var round_ownership: Dictionary = year_ownership[round_num]

	# Step 3: Update ownership
	round_ownership[original_team_id] = new_owner_id

	# Step 4: Return NEW ownership (original unchanged)
	return new_ownership


## Generate draft history record from picks array (pure function).
##
## Creates a structured draft history entry for a given year by processing
## the picks array and extracting relevant player information.
##
## RNG consumption: NONE (deterministic processing)
##
## @param picks: Array of pick dictionaries from draft execution (unchanged)
## @param rosters: Dictionary of team rosters for player lookup (unchanged)
## @param year: Draft year
## @return: NEW Array of draft history entries:
##   [{
##     pick_number: int,
##     round: int,
##     team_id: String,
##     player_id: String,
##     position: String,
##     college: String,
##     traded: bool,
##     original_team_id: String | null,
##     compensatory: bool
##   }]
##
## Algorithm:
##   1. Build player lookup index from rosters
##   2. For each pick, extract metadata
##   3. Look up college from player record
##   4. Create history entry with all relevant fields
##   5. Return NEW history array (original inputs unchanged)
##
## Example:
##   var history := DraftTransformations.generate_draft_history(picks, rosters, 2025)
##   assert(history[0]["pick_number"] == 1)  # First overall pick
##   assert(history[0]["round"] == 1)  # Round 1
static func generate_draft_history(
	picks: Array,
	rosters: Dictionary,
	year: int
) -> Array:
	# Step 1: Build player lookup index for efficient college extraction
	var player_lookup := {}
	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var roster_players: Array = roster.get("players", [])
		for roster_player in roster_players:
			var rp: Dictionary = roster_player
			var pid := String(rp.get("player_id", ""))
			if pid != "":
				player_lookup[pid] = rp

	# Step 2: Build history entries
	var history: Array = []

	for pick in picks:
		var p: Dictionary = pick
		var player_id := String(p.get("player_id", ""))
		var team_id := String(p.get("team_id", ""))
		var is_traded := bool(p.get("traded", false))
		var original_team_id: Variant = p.get("original_team_id", null)
		var is_compensatory := bool(p.get("compensatory", false))

		# Extract college from player record (O(1) lookup)
		var player_college := ""
		if player_lookup.has(player_id):
			var player_record: Dictionary = player_lookup[player_id]
			player_college = String(player_record.get("college_team_id", ""))

		history.append({
			"pick_number": int(p.get("pick", 0)),
			"round": int(p.get("round", 0)),
			"team_id": team_id,
			"player_id": player_id,
			"position": String(p.get("position", "")),
			"college": player_college,
			"traded": is_traded,
			"original_team_id": original_team_id,
			"compensatory": is_compensatory
		})

	return history


# ============================================================================
# IMMUTABILITY HELPERS - Pure Function Utilities
# ============================================================================

## Verify that a transformation preserved input immutability (testing helper).
##
## This is a testing utility to verify pure function contracts. It compares
## a hash of the input before and after a transformation to ensure the
## transformation didn't mutate the original data.
##
## @param original_hash: Hash of input before transformation
## @param current_value: Input value after transformation
## @return: bool - true if input was preserved, false if mutated
static func verify_immutability(original_hash: int, current_value: Variant) -> bool:
	return hash(current_value) == original_hash
