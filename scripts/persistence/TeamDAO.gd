## Team Data Access Object
## Handles all database operations for Team entity and Roster with RosterEntry components
##
## CRUD Operations:
## - save(team) - INSERT OR REPLACE team + all roster entries
## - load(team_id) - SELECT team + JOIN roster entries
## - load_with_players(team_id) - Load team with full Player objects
## - load_batch(team_ids) - Efficient batch loading
## - query(filters) - SELECT with WHERE clause
## - delete(team_id) - CASCADE delete team + roster entries
##
## Transaction Support:
## All operations assume caller manages transactions via PersistenceLayer
extends RefCounted
class_name TeamDAO

const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")

# Preload Team and Roster models
const Team = preload("res://scripts/core/models/Team.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")
const RosterEntry = preload("res://scripts/core/models/RosterEntry.gd")
const RosterContract = preload("res://scripts/core/models/RosterContract.gd")

# PlayerDAO for loading full player objects (optional)
var _player_dao = null

var _db: SQLite = null

## Initialize DAO with database connection
func _init(db: SQLite, player_dao = null) -> void:
	_db = db
	_player_dao = player_dao

# =========================
# Create Operations
# =========================

## Save team and all roster entries to database
## Performs INSERT OR REPLACE to handle both create and update
## @param team: Team resource to save
## @return: true on success, false on failure
func save(team: Team) -> bool:
	if not team or team.id.is_empty():
		push_error("TeamDAO.save: Invalid team or empty ID")
		return false

	# Save main team record
	if not _save_team_main(team):
		return false

	# Save roster entries
	if not _save_roster_entries(team):
		return false

	return true

## Save multiple teams in batch
## @param teams: Array of Team resources
## @return: Number of successfully saved teams
func save_batch(teams: Array) -> int:
	var saved_count = 0
	for team in teams:
		if save(team):
			saved_count += 1
	return saved_count

# =========================
# Read Operations
# =========================

## Load team by ID with roster entries (player IDs only)
## @param team_id: Team ID to load
## @return: Team resource, or null if not found
func load(team_id: String) -> Team:
	if team_id.is_empty():
		push_error("TeamDAO.load: Empty team_id")
		return null

	# Load main team record
	var team = _load_team_main(team_id)
	if not team:
		return null

	# Load roster entries (player IDs only)
	_load_roster_entries(team, false)

	return team

## Load team by ID with full Player objects
## @param team_id: Team ID to load
## @return: Team resource with roster containing full Player objects, or null if not found
func load_with_players(team_id: String) -> Team:
	if not _player_dao:
		push_warning("TeamDAO.load_with_players: PlayerDAO not provided, loading IDs only")
		return load(team_id)

	var team = _load_team_main(team_id)
	if not team:
		return null

	# Load roster entries with full player objects
	_load_roster_entries(team, true)

	return team

## Load multiple teams by IDs
## @param team_ids: Array of team IDs
## @param with_players: If true, load full Player objects in rosters
## @return: Array of Team resources
func load_batch(team_ids: Array, with_players: bool = false) -> Array:
	var teams = []
	for team_id in team_ids:
		var team = load_with_players(team_id) if with_players else load(team_id)
		if team:
			teams.append(team)
	return teams

## Load all teams (use with caution for large datasets)
## @param with_players: If true, load full Player objects in rosters
## @return: Array of Team resources
func load_all(with_players: bool = false) -> Array:
	_db.query("SELECT id FROM team")
	var result = _db.query_result

	var teams = []
	for row in result:
		var team = load_with_players(row["id"]) if with_players else load(row["id"])
		if team:
			teams.append(team)
	return teams

## Query teams with filters
## @param filters: Query filters {league_level: "nfl", is_user_controlled: true}
## @return: Array of Team resources
func query(filters: Dictionary) -> Array:
	var where_clauses = []
	var params = []

	# Build WHERE clause from filters
	if filters.has("league_level"):
		where_clauses.append("league_level = ?")
		params.append(filters["league_level"])

	if filters.has("is_user_controlled"):
		where_clauses.append("is_user_controlled = ?")
		params.append(1 if filters["is_user_controlled"] else 0)

	if filters.has("conference"):
		where_clauses.append("conference = ?")
		params.append(filters["conference"])

	if filters.has("division"):
		where_clauses.append("division = ?")
		params.append(filters["division"])

	# Build query
	var sql = "SELECT id FROM team"
	if where_clauses.size() > 0:
		sql += " WHERE " + " AND ".join(where_clauses)

	# Add limit if specified
	if filters.has("limit"):
		sql += " LIMIT " + str(filters["limit"])

	# Execute query
	_db.query_with_bindings(sql, params)
	var result = _db.query_result

	# Load full team objects
	var with_players = filters.get("with_players", false)
	var teams = []
	for row in result:
		var team = load_with_players(row["id"]) if with_players else load(row["id"])
		if team:
			teams.append(team)

	return teams

## Check if team exists
## @param team_id: Team ID to check
## @return: true if team exists, false otherwise
func exists(team_id: String) -> bool:
	_db.query_with_bindings("SELECT 1 FROM team WHERE id = ? LIMIT 1", [team_id])
	return _db.query_result.size() > 0

## Get roster player IDs for team
## @param team_id: Team ID
## @param active_only: If true, only return ACTIVE roster status players
## @return: Array of player IDs
func get_roster_player_ids(team_id: String, active_only: bool = false) -> Array[String]:
	var sql = "SELECT player_id FROM roster_entry WHERE team_id = ?"
	if active_only:
		sql += " AND status = 0"  # RosterStatus.ACTIVE

	_db.query_with_bindings(sql, [team_id])
	var result = _db.query_result

	var player_ids: Array[String] = []
	for row in result:
		player_ids.append(row["player_id"])

	return player_ids

# =========================
# Update Operations
# =========================

## Update team (alias for save - uses INSERT OR REPLACE)
func update(team: Team) -> bool:
	return save(team)

## Add player to team roster
## @param team_id: Team ID
## @param player_id: Player ID
## @param status: RosterStatus enum value (0=ACTIVE, 1=PRACTICE_SQUAD, 2=IR, 3=SUSPENDED)
## @return: true on success, false on failure
func add_player_to_roster(team_id: String, player_id: String, status: int = 0) -> bool:
	var sql = """
		INSERT INTO roster_entry (team_id, player_id, status)
		VALUES (?, ?, ?)
	"""

	_db.query_with_bindings(sql, [team_id, player_id, status])
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("TeamDAO.add_player_to_roster: %s" % _db.query_result_error)
		return false

	return true

## Remove player from team roster
## @param team_id: Team ID
## @param player_id: Player ID
## @return: true on success, false on failure
func remove_player_from_roster(team_id: String, player_id: String) -> bool:
	_db.query_with_bindings(
		"DELETE FROM roster_entry WHERE team_id = ? AND player_id = ?",
		[team_id, player_id]
	)
	return true

# =========================
# Delete Operations
# =========================

## Delete team and all roster entries (CASCADE handled by foreign keys)
## @param team_id: Team ID to delete
## @return: true on success, false on failure
func delete(team_id: String) -> bool:
	if team_id.is_empty():
		push_error("TeamDAO.delete: Empty team_id")
		return false

	_db.query_with_bindings("DELETE FROM team WHERE id = ?", [team_id])
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("TeamDAO.delete: Failed to delete team %s: %s" % [team_id, _db.query_result_error])
		return false

	return true

## Delete multiple teams by IDs
## @param team_ids: Array of team IDs to delete
## @return: Number of successfully deleted teams
func delete_batch(team_ids: Array) -> int:
	var deleted_count = 0
	for team_id in team_ids:
		if delete(team_id):
			deleted_count += 1
	return deleted_count

# =========================
# Private: Save Components
# =========================

## Save main team record
func _save_team_main(team: Team) -> bool:
	var sql = """
		INSERT OR REPLACE INTO team (
			id, name, abbreviation, league_level, conference, division,
			offensive_scheme, defensive_scheme, cap_limit, is_user_controlled
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	"""

	var params = [
		team.id,
		team.name,
		team.abbreviation if team.has("abbreviation") else "",
		team.league_level if team.has("league_level") else "nfl",
		team.conference if team.has("conference") else "",
		team.division if team.has("division") else "",
		team.offensive_scheme if team.has("offensive_scheme") else "",
		team.defensive_scheme if team.has("defensive_scheme") else "",
		team.cap_limit if team.has("cap_limit") else 0.0,
		1 if (team.get("is_user_controlled") if team.has("is_user_controlled") else false) else 0
	]

	_db.query_with_bindings(sql, params)
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("TeamDAO._save_team_main: %s" % _db.query_result_error)
		return false
	return true

## Save roster entries
func _save_roster_entries(team: Team) -> bool:
	if not team.roster or not team.roster.entries:
		return true

	# Delete existing roster entries for this team
	_db.query_with_bindings("DELETE FROM roster_entry WHERE team_id = ?", [team.id])

	# Insert roster entries
	for entry in team.roster.entries:
		# Handle both Dictionary and RosterEntry resource (roster.entries is Array[Dictionary])
		var entry_dict: Dictionary = entry as Dictionary

		var player_id = entry_dict.get("player_id", "")
		if player_id.is_empty():
			push_warning("TeamDAO._save_roster_entries: Skipping entry with no player_id")
			continue

		# Parse status (handle both string and int)
		var status = 0  # Default: ACTIVE
		if entry_dict.has("status"):
			if entry_dict["status"] is String:
				status = _parse_roster_status(entry_dict["status"])
			else:
				status = int(entry_dict["status"])

		# Insert roster entry
		var entry_sql = """
			INSERT INTO roster_entry (
				team_id, player_id, status, cap_exempt, cap_exempt_reason, ir_eligible_week
			) VALUES (?, ?, ?, ?, ?, ?)
		"""

		var entry_params = [
			team.id,
			player_id,
			status,
			1 if entry_dict.get("cap_exempt", false) else 0,
			entry_dict.get("cap_exempt_reason", ""),
			int(entry_dict.get("ir_eligible_week", 0))
		]

		_db.query_with_bindings(entry_sql, entry_params)

		# Get roster_entry_id for contract insert
		_db.query("SELECT last_insert_rowid() AS id")
		var rowid_result = _db.query_result
		if rowid_result.size() == 0:
			continue

		var roster_entry_id = rowid_result[0]["id"]

		# Save roster contract if present
		if entry_dict.has("contract") or entry_dict.has("roster_contract"):
			var contract = entry_dict.get("contract", entry_dict.get("roster_contract", {}))
			_save_roster_contract(roster_entry_id, contract)

	return true

## Save roster contract for a roster entry
func _save_roster_contract(roster_entry_id: int, contract: Dictionary) -> void:
	var sql = """
		INSERT OR REPLACE INTO roster_contract (
			roster_entry_id, base_salary, signing_bonus_proration,
			guaranteed, incentives, dead_money
		) VALUES (?, ?, ?, ?, ?, ?)
	"""

	var params = [
		roster_entry_id,
		float(contract.get("base_salary", 0.0)),
		float(contract.get("signing_bonus_proration", 0.0)),
		float(contract.get("guaranteed", 0.0)),
		float(contract.get("incentives", 0.0)),
		float(contract.get("dead_money", 0.0))
	]

	_db.query_with_bindings(sql, params)

## Parse roster status string to enum
func _parse_roster_status(status_str: String) -> int:
	match status_str.to_lower():
		"active":
			return 0  # RosterStatus.ACTIVE
		"practice_squad", "practice squad":
			return 1  # RosterStatus.PRACTICE_SQUAD
		"injured_reserve", "injured reserve", "ir":
			return 2  # RosterStatus.INJURED_RESERVE
		"suspended":
			return 3  # RosterStatus.SUSPENDED
		_:
			return 0  # Default to ACTIVE

# =========================
# Private: Load Components
# =========================

## Load main team record
func _load_team_main(team_id: String) -> Team:
	_db.query_with_bindings("SELECT * FROM team WHERE id = ?", [team_id])
	var result = _db.query_result

	if result.size() == 0:
		return null

	var row = result[0]
	var team = Team.new()

	team.id = row["id"]
	team.name = row["name"]
	if row.has("abbreviation"):
		team.abbreviation = row["abbreviation"]
	if row.has("league_level"):
		team.league_level = row["league_level"]
	if row.has("conference"):
		team.conference = row["conference"]
	if row.has("division"):
		team.division = row["division"]
	if row.has("offensive_scheme"):
		team.offensive_scheme = row["offensive_scheme"]
	if row.has("defensive_scheme"):
		team.defensive_scheme = row["defensive_scheme"]
	if row.has("cap_limit"):
		team.cap_limit = float(row["cap_limit"])
	if row.has("is_user_controlled"):
		team.set("is_user_controlled", bool(row["is_user_controlled"]))

	return team

## Load roster entries
## @param team: Team resource to populate
## @param load_players: If true, load full Player objects (requires PlayerDAO)
func _load_roster_entries(team: Team, load_players: bool) -> void:
	var sql = """
		SELECT re.*, rc.base_salary, rc.signing_bonus_proration, rc.guaranteed,
		       rc.incentives, rc.dead_money
		FROM roster_entry re
		LEFT JOIN roster_contract rc ON rc.roster_entry_id = re.id
		WHERE re.team_id = ?
	"""

	_db.query_with_bindings(sql, [team.id])
	var result = _db.query_result

	if not team.roster:
		team.roster = Roster.new()

	team.roster.entries.clear()

	for row in result:
		# Create roster entry dictionary
		var entry = {
			"player_id": row["player_id"],
			"status": _format_roster_status(int(row["status"])),
			"cap_exempt": bool(row["cap_exempt"]),
			"cap_exempt_reason": row["cap_exempt_reason"] if row.has("cap_exempt_reason") else "",
			"ir_eligible_week": int(row["ir_eligible_week"]) if row.has("ir_eligible_week") else 0,
			"contract": {
				"base_salary": float(row["base_salary"]) if row.has("base_salary") and row["base_salary"] != null else 0.0,
				"signing_bonus_proration": float(row["signing_bonus_proration"]) if row.has("signing_bonus_proration") and row["signing_bonus_proration"] != null else 0.0,
				"guaranteed": float(row["guaranteed"]) if row.has("guaranteed") and row["guaranteed"] != null else 0.0,
				"incentives": float(row["incentives"]) if row.has("incentives") and row["incentives"] != null else 0.0,
				"dead_money": float(row["dead_money"]) if row.has("dead_money") and row["dead_money"] != null else 0.0
			}
		}

		# If loading full players, fetch Player object
		if load_players and _player_dao:
			var player = _player_dao.load(row["player_id"])
			if player:
				entry["player"] = player

		team.roster.entries.append(entry)

## Format roster status enum to string
func _format_roster_status(status: int) -> String:
	match status:
		0:
			return "active"
		1:
			return "practice_squad"
		2:
			return "injured_reserve"
		3:
			return "suspended"
		_:
			return "active"
