## Player Data Access Object
## Handles all database operations for Player entity and its 8 component resources:
## - PlayerPhysicals, CombineResults, StatsProfile, TraitSet, CareerRecord,
##   HealthStatus, Contract (+ base Person identity)
##
## CRUD Operations:
## - save(player) - INSERT OR REPLACE player + all components
## - load(player_id) - SELECT player + JOIN all components
## - load_batch(player_ids) - Efficient batch loading
## - query(filters) - SELECT with WHERE clause
## - delete(player_id) - CASCADE delete player + components
##
## Transaction Support:
## All operations assume caller manages transactions via PersistenceLayer
extends RefCounted
class_name PlayerDAO

const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")

# Preload Player model and all component resources
const Player = preload("res://scripts/core/models/Player.gd")
const PlayerPhysicals = preload("res://scripts/core/models/PlayerPhysicals.gd")
const CombineResults = preload("res://scripts/core/models/CombineResults.gd")
const StatsProfile = preload("res://scripts/core/models/StatsProfile.gd")
const TraitSet = preload("res://scripts/core/models/TraitSet.gd")
const CareerRecord = preload("res://scripts/core/models/CareerRecord.gd")
const HealthStatus = preload("res://scripts/core/models/HealthStatus.gd")
const Contract = preload("res://scripts/core/models/Contract.gd")
const Injury = preload("res://scripts/core/models/Injury.gd")

var _db: SQLite = null

## Initialize DAO with database connection
func _init(db: SQLite) -> void:
	_db = db

# =========================
# Create Operations
# =========================

## Save player and all component resources to database
## Performs INSERT OR REPLACE to handle both create and update
## @param player: Player resource to save
## @return: true on success, false on failure
func save(player: Player) -> bool:
	if not player or player.id.is_empty():
		push_error("PlayerDAO.save: Invalid player or empty ID")
		return false

	# Save main player record
	if not _save_player_main(player):
		return false

	# Save all component resources
	if not _save_physicals(player):
		return false
	if not _save_combine(player):
		return false
	if not _save_stats(player):
		return false
	if not _save_traits(player):
		return false
	if not _save_contract(player):
		return false
	if not _save_career(player):
		return false
	if not _save_injuries(player):
		return false

	return true

## Save multiple players in batch (more efficient than individual saves)
## @param players: Array of Player resources
## @return: Number of successfully saved players
func save_batch(players: Array) -> int:
	var saved_count = 0
	for player in players:
		if save(player):
			saved_count += 1
	return saved_count

# =========================
# Read Operations
# =========================

## Load player by ID with all component resources
## @param player_id: Player ID to load
## @return: Player resource, or null if not found
func load(player_id: String) -> Player:
	if player_id.is_empty():
		push_error("PlayerDAO.load: Empty player_id")
		return null

	# Load main player record
	var player = _load_player_main(player_id)
	if not player:
		return null

	# Load all component resources
	_load_physicals(player)
	_load_combine(player)
	_load_stats(player)
	_load_traits(player)
	_load_contract(player)
	_load_career(player)
	_load_injuries(player)

	return player

## Load multiple players by IDs (efficient batch loading)
## @param player_ids: Array of player IDs
## @return: Array of Player resources
func load_batch(player_ids: Array) -> Array:
	var players = []
	for player_id in player_ids:
		var player = load(player_id)
		if player:
			players.append(player)
	return players

## Load all players (use with caution for large datasets)
## @return: Array of Player resources
func load_all() -> Array:
	_db.query("SELECT id FROM player")
	var result = _db.query_result

	var players = []
	for row in result:
		var player = load(row["id"])
		if player:
			players.append(player)
	return players

## Query players with filters
## @param filters: Query filters {position: "QB", age_min: 21, age_max: 25, stage: 3}
## @return: Array of Player resources
func query(filters: Dictionary) -> Array:
	var where_clauses = []
	var params = []

	# Build WHERE clause from filters
	if filters.has("position"):
		where_clauses.append("position = ?")
		params.append(filters["position"])

	if filters.has("age"):
		where_clauses.append("age = ?")
		params.append(filters["age"])
	elif filters.has("age_min") or filters.has("age_max"):
		if filters.has("age_min"):
			where_clauses.append("age >= ?")
			params.append(filters["age_min"])
		if filters.has("age_max"):
			where_clauses.append("age <= ?")
			params.append(filters["age_max"])

	if filters.has("stage"):
		where_clauses.append("stage = ?")
		params.append(filters["stage"])

	if filters.has("school_tag"):
		where_clauses.append("school_tag = ?")
		params.append(filters["school_tag"])

	if filters.has("class_tag"):
		where_clauses.append("class_tag = ?")
		params.append(filters["class_tag"])

	# Build query
	var sql = "SELECT id FROM player"
	if where_clauses.size() > 0:
		sql += " WHERE " + " AND ".join(where_clauses)

	# Add limit if specified
	if filters.has("limit"):
		sql += " LIMIT " + str(filters["limit"])

	# Execute query
	_db.query_with_bindings(sql, params)
	var result = _db.query_result

	# Load full player objects
	var players = []
	for row in result:
		var player = load(row["id"])
		if player:
			players.append(player)

	return players

## Check if player exists
## @param player_id: Player ID to check
## @return: true if player exists, false otherwise
func exists(player_id: String) -> bool:
	_db.query_with_bindings("SELECT 1 FROM player WHERE id = ? LIMIT 1", [player_id])
	return _db.query_result.size() > 0

# =========================
# Update Operations
# =========================

## Update player (alias for save - uses INSERT OR REPLACE)
func update(player: Player) -> bool:
	return save(player)

# =========================
# Delete Operations
# =========================

## Delete player and all component resources (CASCADE handled by foreign keys)
## @param player_id: Player ID to delete
## @return: true on success, false on failure
func delete(player_id: String) -> bool:
	if player_id.is_empty():
		push_error("PlayerDAO.delete: Empty player_id")
		return false

	_db.query_with_bindings("DELETE FROM player WHERE id = ?", [player_id])
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO.delete: Failed to delete player %s: %s" % [player_id, _db.query_result_error])
		return false

	return true

## Delete multiple players by IDs
## @param player_ids: Array of player IDs to delete
## @return: Number of successfully deleted players
func delete_batch(player_ids: Array) -> int:
	var deleted_count = 0
	for player_id in player_ids:
		if delete(player_id):
			deleted_count += 1
	return deleted_count

# =========================
# Private: Save Components
# =========================

## Save main player record
func _save_player_main(player: Player) -> bool:
	var sql = """
		INSERT OR REPLACE INTO player (
			id, first_name, last_name, position, age, stage,
			class_tag, jersey_number, gen_mode, school_tag, notes, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
	"""

	var params = [
		player.id,
		player.first_name,
		player.last_name,
		player.position,
		player.age,
		int(player.stage),
		player.class_tag,
		player.jersey_number,
		player.gen_mode,
		player.school_tag,
		player.notes
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO._save_player_main: %s" % _db.query_result_error)
		return false
	return true

## Save PlayerPhysicals component
func _save_physicals(player: Player) -> bool:
	if not player.physicals:
		return true  # Skip if null

	var sql = """
		INSERT OR REPLACE INTO player_physicals (
			player_id, height_in, weight_lb, hand_size_in, arm_length_in, wingspan_in
		) VALUES (?, ?, ?, ?, ?, ?)
	"""

	var params = [
		player.id,
		player.physicals.height_in,
		player.physicals.weight_lb,
		player.physicals.hand_size_in,
		player.physicals.arm_length_in,
		player.physicals.wingspan_in
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO._save_physicals: %s" % _db.query_result_error)
		return false
	return true

## Save CombineResults component (nullable)
func _save_combine(player: Player) -> bool:
	if not player.combine:
		return true  # Skip if null

	var sql = """
		INSERT OR REPLACE INTO player_combine (
			player_id, forty_sec, shuttle20_sec, cone3_sec, vertical_in, broad_in,
			bench_225_reps, wonderlic, cybex_index, injury_eval, drug_screen, combine_year
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	"""

	var params = [
		player.id,
		player.combine.forty_sec,
		player.combine.shuttle20_sec,
		player.combine.cone3_sec,
		player.combine.vertical_in,
		player.combine.broad_in,
		player.combine.bench_225_reps,
		player.combine.wonderlic,
		player.combine.cybex_index,
		player.combine.injury_eval,
		player.combine.drug_screen,
		player.combine.combine_year
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO._save_combine: %s" % _db.query_result_error)
		return false
	return true

## Save StatsProfile component (JSON columns)
func _save_stats(player: Player) -> bool:
	if not player.stats_profile:
		return true

	var sql = """
		INSERT OR REPLACE INTO player_stats (
			player_id, current_stats, potential_stats, derived_stats
		) VALUES (?, ?, ?, ?)
	"""

	var params = [
		player.id,
		JSON.stringify(player.stats_profile.current),
		JSON.stringify(player.stats_profile.potential),
		JSON.stringify(player.stats_profile.derived)
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO._save_stats: %s" % _db.query_result_error)
		return false
	return true

## Save TraitSet component
func _save_traits(player: Player) -> bool:
	if not player.trait_set:
		return true

	# Delete existing traits for this player
	_db.query_with_bindings("DELETE FROM player_trait WHERE player_id = ?", [player.id])

	# Insert visible traits
	for trait_name in player.trait_set.visible:
		_db.query_with_bindings(
			"INSERT INTO player_trait (player_id, trait_name, is_hidden) VALUES (?, ?, 0)",
			[player.id, trait_name]
		)

	# Insert hidden traits
	for trait_name in player.trait_set.hidden:
		_db.query_with_bindings(
			"INSERT INTO player_trait (player_id, trait_name, is_hidden) VALUES (?, ?, 1)",
			[player.id, trait_name]
		)

	return true

## Save Contract component
func _save_contract(player: Player) -> bool:
	if not player.contract:
		return true

	var sql = """
		INSERT OR REPLACE INTO player_contract (
			player_id, current_year, total_years, annual_value, guaranteed,
			range_min, range_max, valuation_source, valuation_seed, source_eval_id
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	"""

	var params = [
		player.id,
		player.contract.current_year,
		player.contract.total_years,
		player.contract.annual_value,
		player.contract.guaranteed,
		player.contract.range_min,
		player.contract.range_max,
		player.contract.valuation_source,
		player.contract.valuation_seed,
		player.contract.source_eval_id
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO._save_contract: %s" % _db.query_result_error)
		return false
	return true

## Save CareerRecord component (JSON columns)
func _save_career(player: Player) -> bool:
	if not player.career:
		return true

	var sql = """
		INSERT OR REPLACE INTO player_career (
			player_id, awards, wear, development_history
		) VALUES (?, ?, ?, ?)
	"""

	var params = [
		player.id,
		JSON.stringify(player.career.awards),
		JSON.stringify(player.career.wear),
		JSON.stringify(player.career.development_history)
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("PlayerDAO._save_career: %s" % _db.query_result_error)
		return false
	return true

## Save HealthStatus component (injuries)
func _save_injuries(player: Player) -> bool:
	if not player.health:
		return true

	# Delete existing injuries for this player
	_db.query_with_bindings("DELETE FROM player_injury WHERE player_id = ?", [player.id])

	# Insert injuries
	for injury in player.health.injuries:
		var sql = """
			INSERT INTO player_injury (
				player_id, injury_type, severity, week_occurred, season_year, is_active
			) VALUES (?, ?, ?, ?, ?, ?)
		"""

		var params = [
			player.id,
			injury.type,
			injury.severity,
			injury.week_occurred if injury.has("week_occurred") else null,
			injury.season_year if injury.has("season_year") else null,
			1 if injury.is_active else 0
		]

		_db.query_with_bindings(sql, params)

	return true

# =========================
# Private: Load Components
# =========================

## Load main player record
func _load_player_main(player_id: String) -> Player:
	_db.query_with_bindings("SELECT * FROM player WHERE id = ?", [player_id])
	var result = _db.query_result

	if result.size() == 0:
		return null

	var row = result[0]
	var player = Player.new()

	# Person fields
	player.id = row["id"]
	player.first_name = row["first_name"]
	player.last_name = row["last_name"]

	# Player fields
	player.position = row["position"]
	player.age = int(row["age"])
	player.stage = int(row["stage"]) as Player.PlayerStage
	player.class_tag = row["class_tag"] if row.has("class_tag") else ""
	player.jersey_number = int(row["jersey_number"]) if row.has("jersey_number") else 0
	player.gen_mode = row["gen_mode"] if row.has("gen_mode") else ""
	player.school_tag = row["school_tag"] if row.has("school_tag") else ""
	player.notes = row["notes"] if row.has("notes") else ""

	return player

## Load PlayerPhysicals component
func _load_physicals(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_physicals WHERE player_id = ?", [player.id])
	var result = _db.query_result

	if result.size() == 0:
		return

	var row = result[0]
	player.physicals.height_in = float(row["height_in"])
	player.physicals.weight_lb = float(row["weight_lb"])
	player.physicals.hand_size_in = float(row["hand_size_in"])
	player.physicals.arm_length_in = float(row["arm_length_in"])
	player.physicals.wingspan_in = float(row["wingspan_in"])

## Load CombineResults component
func _load_combine(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_combine WHERE player_id = ?", [player.id])
	var result = _db.query_result

	if result.size() == 0:
		return

	var row = result[0]
	player.combine.forty_sec = float(row["forty_sec"]) if row.has("forty_sec") and row["forty_sec"] != null else 0.0
	player.combine.shuttle20_sec = float(row["shuttle20_sec"]) if row.has("shuttle20_sec") and row["shuttle20_sec"] != null else 0.0
	player.combine.cone3_sec = float(row["cone3_sec"]) if row.has("cone3_sec") and row["cone3_sec"] != null else 0.0
	player.combine.vertical_in = float(row["vertical_in"]) if row.has("vertical_in") and row["vertical_in"] != null else 0.0
	player.combine.broad_in = float(row["broad_in"]) if row.has("broad_in") and row["broad_in"] != null else 0.0
	player.combine.bench_225_reps = int(row["bench_225_reps"]) if row.has("bench_225_reps") and row["bench_225_reps"] != null else 0
	player.combine.wonderlic = int(row["wonderlic"]) if row.has("wonderlic") and row["wonderlic"] != null else 0
	player.combine.cybex_index = float(row["cybex_index"]) if row.has("cybex_index") and row["cybex_index"] != null else 0.0
	player.combine.injury_eval = row["injury_eval"] if row.has("injury_eval") and row["injury_eval"] != null else ""
	player.combine.drug_screen = row["drug_screen"] if row.has("drug_screen") and row["drug_screen"] != null else ""
	player.combine.combine_year = int(row["combine_year"]) if row.has("combine_year") and row["combine_year"] != null else 0

## Load StatsProfile component
func _load_stats(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_stats WHERE player_id = ?", [player.id])
	var result = _db.query_result

	if result.size() == 0:
		return

	var row = result[0]

	# Parse JSON columns
	var json = JSON.new()

	if row.has("current_stats") and row["current_stats"] != null:
		json.parse(row["current_stats"])
		if json.data is Dictionary:
			player.stats_profile.current = json.data

	if row.has("potential_stats") and row["potential_stats"] != null:
		json.parse(row["potential_stats"])
		if json.data is Dictionary:
			player.stats_profile.potential = json.data

	if row.has("derived_stats") and row["derived_stats"] != null:
		json.parse(row["derived_stats"])
		if json.data is Dictionary:
			player.stats_profile.derived = json.data

## Load TraitSet component
func _load_traits(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_trait WHERE player_id = ?", [player.id])
	var result = _db.query_result

	player.trait_set.visible.clear()
	player.trait_set.hidden.clear()

	for row in result:
		var trait_name = row["trait_name"]
		var is_hidden = bool(row["is_hidden"])

		if is_hidden:
			player.trait_set.hidden.append(trait_name)
		else:
			player.trait_set.visible.append(trait_name)

## Load Contract component
func _load_contract(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_contract WHERE player_id = ?", [player.id])
	var result = _db.query_result

	if result.size() == 0:
		return

	var row = result[0]
	player.contract.current_year = int(row["current_year"])
	player.contract.total_years = int(row["total_years"])
	player.contract.annual_value = float(row["annual_value"])
	player.contract.guaranteed = float(row["guaranteed"])
	player.contract.range_min = float(row["range_min"])
	player.contract.range_max = float(row["range_max"])
	player.contract.valuation_source = row["valuation_source"] if row.has("valuation_source") else ""
	player.contract.valuation_seed = int(row["valuation_seed"]) if row.has("valuation_seed") else 0
	player.contract.source_eval_id = row["source_eval_id"] if row.has("source_eval_id") else ""

## Load CareerRecord component
func _load_career(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_career WHERE player_id = ?", [player.id])
	var result = _db.query_result

	if result.size() == 0:
		return

	var row = result[0]
	var json = JSON.new()

	if row.has("awards") and row["awards"] != null:
		json.parse(row["awards"])
		if json.data is Dictionary:
			player.career.awards = json.data

	if row.has("wear") and row["wear"] != null:
		json.parse(row["wear"])
		if json.data is Dictionary:
			player.career.wear = json.data

	if row.has("development_history") and row["development_history"] != null:
		json.parse(row["development_history"])
		if json.data is Array:
			player.career.development_history = json.data

## Load HealthStatus component (injuries)
func _load_injuries(player: Player) -> void:
	_db.query_with_bindings("SELECT * FROM player_injury WHERE player_id = ?", [player.id])
	var result = _db.query_result

	player.health.injuries.clear()

	for row in result:
		var injury = Injury.new()
		injury.type = row["injury_type"]
		injury.severity = float(row["severity"])
		if row.has("week_occurred") and row["week_occurred"] != null:
			injury.week_occurred = int(row["week_occurred"])
		if row.has("season_year") and row["season_year"] != null:
			injury.season_year = int(row["season_year"])
		injury.is_active = bool(row["is_active"])

		player.health.injuries.append(injury)
