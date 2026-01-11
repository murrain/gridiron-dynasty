class_name DraftQueries
extends RefCounted

## Static utility class for querying draft pool data
##
## Provides functions to access draft-eligible players and calculate draft grades
##
## Dependencies:
## - StatQueries: for calculate_composite_rating() in calculate_draft_grade()
## - PlayerQueries: for sort_players_by_rating() in get_top_prospects()

## Get draft pool for a specific year
## Returns Array of draft-eligible player Dictionaries
static func get_draft_pool(world_state: Dictionary, year: int) -> Array:
	var draft_pool = world_state.get("draft_pool", {})
	var pool = draft_pool.get(year, [])
	if pool.is_empty():
		push_warning("DraftQueries.get_draft_pool: No draft pool found for year %d" % year)
	return pool

## Get all available draft years
## Returns sorted Array of year integers
static func get_draft_years(world_state: Dictionary) -> Array:
	var draft_pool = world_state.get("draft_pool", {})
	var years = draft_pool.keys()
	years.sort()
	return years

## Get draft-eligible players by position for a year
## position: Position code (e.g., "QB", "RB") or "All" to return all players
## Returns filtered Array of player Dictionaries
static func get_draft_eligible_by_position(world_state: Dictionary, year: int, position: String) -> Array:
	var pool = get_draft_pool(world_state, year)
	if position == "All" or position.is_empty():
		return pool
	return pool.filter(func(p): return p.get("position", "") == position)

## Calculate draft grade (0-100 composite score)
## Returns float rating representing overall draft value
static func calculate_draft_grade(player: Dictionary) -> float:
	# Use composite rating as draft grade
	return StatQueries.calculate_composite_rating(player)

## Get top N prospects from draft pool
## count: Number of top prospects to return (default 100)
## Returns Array of top-rated player Dictionaries
static func get_top_prospects(world_state: Dictionary, year: int, count: int = 100) -> Array:
	var pool = get_draft_pool(world_state, year)
	if pool.is_empty():
		push_warning("DraftQueries.get_top_prospects: No draft pool for year %d" % year)
		return []

	# Can sort in place since we're about to slice it anyway
	var sorted = PlayerQueries.sort_players_by_rating(pool, false, true)
	return sorted.slice(0, mini(count, sorted.size()))
