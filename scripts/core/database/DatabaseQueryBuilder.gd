class_name DatabaseQueryBuilder
extends RefCounted

## Type-safe SQL query builder with parameterized queries
##
## Provides a fluent interface for building SELECT queries with:
## - JOIN support (INNER, LEFT, RIGHT)
## - WHERE clause building with parameterized values
## - ORDER BY and LIMIT support
## - SQL injection prevention via parameter binding
##
## Usage:
##   var builder = DatabaseQueryBuilder.new()
##   var query = builder.select(["id", "name"]).from("player") \
##       .where("position", "=", "QB") \
##       .where("age", ">=", 21) \
##       .order_by("age", "DESC") \
##       .limit(10) \
##       .build()
##   # query.sql = "SELECT id, name FROM player WHERE position = $1 AND age >= $2 ORDER BY age DESC LIMIT 10"
##   # query.params = ["QB", 21]
##
## RNG: This class does NOT consume RNG. All operations are pure query construction.

# Valid SQL comparison operators for WHERE clauses
const VALID_OPERATORS := ["=", "!=", "<>", "<", "<=", ">", ">=", "LIKE", "IN", "NOT IN", "IS", "IS NOT"]

# Valid SQL join types
const VALID_JOIN_TYPES := ["INNER", "LEFT", "RIGHT", "CROSS"]

# Query components
var _select_columns: Array[String] = []
var _from_table: String = ""
var _table_alias: String = ""
var _joins: Array[Dictionary] = []
var _where_clauses: Array[Dictionary] = []
var _order_by_clauses: Array[Dictionary] = []
var _limit_value: int = -1
var _offset_value: int = -1
var _group_by_columns: Array[String] = []
var _having_clauses: Array[Dictionary] = []

# Parameter tracking for binding
var _parameters: Array = []
var _param_index: int = 0


## Reset builder to initial state for reuse
func reset() -> DatabaseQueryBuilder:
	_select_columns.clear()
	_from_table = ""
	_table_alias = ""
	_joins.clear()
	_where_clauses.clear()
	_order_by_clauses.clear()
	_limit_value = -1
	_offset_value = -1
	_group_by_columns.clear()
	_having_clauses.clear()
	_parameters.clear()
	_param_index = 0
	return self


# =========================
# SELECT Clause
# =========================

## Set columns to select
## @param columns: Array of column names (use "*" for all, "table.column" for qualified)
## @return: Self for method chaining
func select(columns: Array) -> DatabaseQueryBuilder:
	_select_columns.clear()
	for col in columns:
		if col is String and not col.is_empty():
			_select_columns.append(col)
	return self


## Add additional columns to select
## @param columns: Array of column names to add
## @return: Self for method chaining
func select_also(columns: Array) -> DatabaseQueryBuilder:
	for col in columns:
		if col is String and not col.is_empty() and col not in _select_columns:
			_select_columns.append(col)
	return self


## Select all columns
## @return: Self for method chaining
func select_all() -> DatabaseQueryBuilder:
	_select_columns.clear()
	_select_columns.append("*")
	return self


# =========================
# FROM Clause
# =========================

## Set the main table to query from
## @param table: Table name
## @param alias: Optional table alias
## @return: Self for method chaining
func from(table: String, alias: String = "") -> DatabaseQueryBuilder:
	_from_table = _sanitize_identifier(table)
	_table_alias = _sanitize_identifier(alias) if not alias.is_empty() else ""
	return self


# =========================
# JOIN Clauses
# =========================

## Add an INNER JOIN
## @param table: Table to join
## @param on_left: Left side of ON condition (e.g., "player.id")
## @param on_right: Right side of ON condition (e.g., "player_stats.player_id")
## @param alias: Optional table alias
## @return: Self for method chaining
func join(table: String, on_left: String, on_right: String, alias: String = "") -> DatabaseQueryBuilder:
	return _add_join("INNER", table, on_left, on_right, alias)


## Add a LEFT JOIN
## @param table: Table to join
## @param on_left: Left side of ON condition
## @param on_right: Right side of ON condition
## @param alias: Optional table alias
## @return: Self for method chaining
func left_join(table: String, on_left: String, on_right: String, alias: String = "") -> DatabaseQueryBuilder:
	return _add_join("LEFT", table, on_left, on_right, alias)


## Add a RIGHT JOIN
## @param table: Table to join
## @param on_left: Left side of ON condition
## @param on_right: Right side of ON condition
## @param alias: Optional table alias
## @return: Self for method chaining
func right_join(table: String, on_left: String, on_right: String, alias: String = "") -> DatabaseQueryBuilder:
	return _add_join("RIGHT", table, on_left, on_right, alias)


## Internal: Add a join of specified type
func _add_join(join_type: String, table: String, on_left: String, on_right: String, alias: String) -> DatabaseQueryBuilder:
	if join_type not in VALID_JOIN_TYPES:
		push_error("DatabaseQueryBuilder: Invalid join type '%s'" % join_type)
		return self

	_joins.append({
		"type": join_type,
		"table": _sanitize_identifier(table),
		"alias": _sanitize_identifier(alias) if not alias.is_empty() else "",
		"on_left": _sanitize_column(on_left),
		"on_right": _sanitize_column(on_right)
	})
	return self


# =========================
# WHERE Clauses
# =========================

## Add a WHERE condition with parameterized value
## @param column: Column name (supports "table.column" format)
## @param operator: Comparison operator (=, !=, <, <=, >, >=, LIKE, IN, etc.)
## @param value: Value to compare against (will be parameterized)
## @return: Self for method chaining
func where(column: String, operator: String, value: Variant) -> DatabaseQueryBuilder:
	var op := operator.to_upper().strip_edges()
	if op not in VALID_OPERATORS:
		push_error("DatabaseQueryBuilder: Invalid operator '%s'" % operator)
		return self

	_param_index += 1
	_parameters.append(value)

	_where_clauses.append({
		"column": _sanitize_column(column),
		"operator": op,
		"param_index": _param_index,
		"conjunction": "AND"
	})
	return self


## Add a WHERE condition with OR conjunction
## @param column: Column name
## @param operator: Comparison operator
## @param value: Value to compare against
## @return: Self for method chaining
func or_where(column: String, operator: String, value: Variant) -> DatabaseQueryBuilder:
	var op := operator.to_upper().strip_edges()
	if op not in VALID_OPERATORS:
		push_error("DatabaseQueryBuilder: Invalid operator '%s'" % operator)
		return self

	_param_index += 1
	_parameters.append(value)

	_where_clauses.append({
		"column": _sanitize_column(column),
		"operator": op,
		"param_index": _param_index,
		"conjunction": "OR"
	})
	return self


## Add a WHERE IN condition with multiple values
## @param column: Column name
## @param values: Array of values to match against
## @return: Self for method chaining
func where_in(column: String, values: Array) -> DatabaseQueryBuilder:
	if values.is_empty():
		push_warning("DatabaseQueryBuilder: where_in called with empty values array")
		return self

	# Create multiple parameters for IN clause
	var param_indices: Array[int] = []
	for val in values:
		_param_index += 1
		_parameters.append(val)
		param_indices.append(_param_index)

	_where_clauses.append({
		"column": _sanitize_column(column),
		"operator": "IN",
		"param_indices": param_indices,
		"conjunction": "AND"
	})
	return self


## Add a WHERE IS NULL condition
## @param column: Column name
## @return: Self for method chaining
func where_null(column: String) -> DatabaseQueryBuilder:
	_where_clauses.append({
		"column": _sanitize_column(column),
		"operator": "IS",
		"is_null": true,
		"conjunction": "AND"
	})
	return self


## Add a WHERE IS NOT NULL condition
## @param column: Column name
## @return: Self for method chaining
func where_not_null(column: String) -> DatabaseQueryBuilder:
	_where_clauses.append({
		"column": _sanitize_column(column),
		"operator": "IS NOT",
		"is_null": true,
		"conjunction": "AND"
	})
	return self


## Add a WHERE BETWEEN condition
## @param column: Column name
## @param min_value: Minimum value (inclusive)
## @param max_value: Maximum value (inclusive)
## @return: Self for method chaining
func where_between(column: String, min_value: Variant, max_value: Variant) -> DatabaseQueryBuilder:
	_param_index += 1
	var min_idx := _param_index
	_parameters.append(min_value)

	_param_index += 1
	var max_idx := _param_index
	_parameters.append(max_value)

	_where_clauses.append({
		"column": _sanitize_column(column),
		"operator": "BETWEEN",
		"min_param_index": min_idx,
		"max_param_index": max_idx,
		"conjunction": "AND"
	})
	return self


# =========================
# ORDER BY Clause
# =========================

## Add an ORDER BY clause
## @param column: Column name to order by
## @param direction: "ASC" or "DESC" (default: "ASC")
## @return: Self for method chaining
func order_by(column: String, direction: String = "ASC") -> DatabaseQueryBuilder:
	var dir := direction.to_upper().strip_edges()
	if dir not in ["ASC", "DESC"]:
		dir = "ASC"

	_order_by_clauses.append({
		"column": _sanitize_column(column),
		"direction": dir
	})
	return self


# =========================
# GROUP BY Clause
# =========================

## Add GROUP BY columns
## @param columns: Array of column names to group by
## @return: Self for method chaining
func group_by(columns: Array) -> DatabaseQueryBuilder:
	for col in columns:
		if col is String and not col.is_empty():
			_group_by_columns.append(_sanitize_column(col))
	return self


# =========================
# HAVING Clause
# =========================

## Add a HAVING condition (for use with GROUP BY)
## @param column: Column name or aggregate function
## @param operator: Comparison operator
## @param value: Value to compare against
## @return: Self for method chaining
func having(column: String, operator: String, value: Variant) -> DatabaseQueryBuilder:
	var op := operator.to_upper().strip_edges()
	if op not in VALID_OPERATORS:
		push_error("DatabaseQueryBuilder: Invalid operator '%s'" % operator)
		return self

	_param_index += 1
	_parameters.append(value)

	_having_clauses.append({
		"column": _sanitize_column(column),
		"operator": op,
		"param_index": _param_index
	})
	return self


# =========================
# LIMIT and OFFSET
# =========================

## Set maximum number of rows to return
## @param count: Maximum row count
## @return: Self for method chaining
func limit(count: int) -> DatabaseQueryBuilder:
	_limit_value = max(0, count)
	return self


## Set row offset for pagination
## @param count: Number of rows to skip
## @return: Self for method chaining
func offset(count: int) -> DatabaseQueryBuilder:
	_offset_value = max(0, count)
	return self


# =========================
# Build Query
# =========================

## Build the final SQL query with parameters
## @return: Dictionary with "sql" (String) and "params" (Array)
func build() -> Dictionary:
	if _from_table.is_empty():
		push_error("DatabaseQueryBuilder: FROM table is required")
		return {"sql": "", "params": []}

	var parts: Array[String] = []

	# SELECT
	if _select_columns.is_empty():
		parts.append("SELECT *")
	else:
		parts.append("SELECT " + ", ".join(_select_columns))

	# FROM
	var from_part := "FROM " + _from_table
	if not _table_alias.is_empty():
		from_part += " AS " + _table_alias
	parts.append(from_part)

	# JOINs
	for j in _joins:
		var join_str := "%s JOIN %s" % [j["type"], j["table"]]
		if not j["alias"].is_empty():
			join_str += " AS " + j["alias"]
		join_str += " ON %s = %s" % [j["on_left"], j["on_right"]]
		parts.append(join_str)

	# WHERE
	if not _where_clauses.is_empty():
		var where_parts: Array[String] = []
		for i in range(_where_clauses.size()):
			var w := _where_clauses[i]
			var clause_str := ""

			if w.has("is_null"):
				clause_str = "%s %s NULL" % [w["column"], w["operator"]]
			elif w["operator"] == "IN":
				var placeholders: Array[String] = []
				for idx in w["param_indices"]:
					placeholders.append("$%d" % idx)
				clause_str = "%s IN (%s)" % [w["column"], ", ".join(placeholders)]
			elif w["operator"] == "BETWEEN":
				clause_str = "%s BETWEEN $%d AND $%d" % [w["column"], w["min_param_index"], w["max_param_index"]]
			else:
				clause_str = "%s %s $%d" % [w["column"], w["operator"], w["param_index"]]

			if i == 0:
				where_parts.append(clause_str)
			else:
				where_parts.append("%s %s" % [w["conjunction"], clause_str])

		parts.append("WHERE " + " ".join(where_parts))

	# GROUP BY
	if not _group_by_columns.is_empty():
		parts.append("GROUP BY " + ", ".join(_group_by_columns))

	# HAVING
	if not _having_clauses.is_empty():
		var having_parts: Array[String] = []
		for h in _having_clauses:
			having_parts.append("%s %s $%d" % [h["column"], h["operator"], h["param_index"]])
		parts.append("HAVING " + " AND ".join(having_parts))

	# ORDER BY
	if not _order_by_clauses.is_empty():
		var order_parts: Array[String] = []
		for o in _order_by_clauses:
			order_parts.append("%s %s" % [o["column"], o["direction"]])
		parts.append("ORDER BY " + ", ".join(order_parts))

	# LIMIT
	if _limit_value >= 0:
		parts.append("LIMIT %d" % _limit_value)

	# OFFSET
	if _offset_value >= 0:
		parts.append("OFFSET %d" % _offset_value)

	return {
		"sql": " ".join(parts),
		"params": _parameters.duplicate()
	}


## Build query and return just the SQL string (for debugging)
## @return: SQL string with parameter placeholders
func to_sql() -> String:
	return build()["sql"]


## Get current parameter list
## @return: Array of parameter values
func get_params() -> Array:
	return _parameters.duplicate()


# =========================
# Sanitization (SQL Injection Prevention)
# =========================

## Sanitize a table or column identifier
## Removes or escapes potentially dangerous characters
## @param identifier: Raw identifier string
## @return: Sanitized identifier
func _sanitize_identifier(identifier: String) -> String:
	if identifier.is_empty():
		return ""

	# Remove any characters that aren't alphanumeric, underscore, or period
	# Period is allowed for table.column notation
	var result := ""
	for c in identifier:
		if c.is_valid_identifier() or c == "." or c == "_":
			result += c

	# Prevent starting with a number
	if not result.is_empty() and result[0].is_valid_int():
		result = "_" + result

	return result


## Sanitize a column name (allows table.column notation)
## @param column: Raw column string
## @return: Sanitized column string
func _sanitize_column(column: String) -> String:
	# Handle table.column notation
	if "." in column:
		var parts := column.split(".")
		if parts.size() == 2:
			return _sanitize_identifier(parts[0]) + "." + _sanitize_identifier(parts[1])

	# Handle aggregate functions (e.g., COUNT(*), SUM(column))
	if "(" in column and ")" in column:
		# Extract function name and argument
		var paren_start := column.find("(")
		var paren_end := column.rfind(")")
		if paren_start > 0 and paren_end > paren_start:
			var func_name := _sanitize_identifier(column.substr(0, paren_start).to_upper())
			var arg := column.substr(paren_start + 1, paren_end - paren_start - 1)
			# Allow common aggregate functions
			if func_name in ["COUNT", "SUM", "AVG", "MIN", "MAX"]:
				if arg == "*":
					return func_name + "(*)"
				else:
					return func_name + "(" + _sanitize_identifier(arg) + ")"

	return _sanitize_identifier(column)


# =========================
# Validation Methods
# =========================

## Validate that the query is well-formed
## @return: Array of validation error messages (empty if valid)
func validate() -> Array[String]:
	var errors: Array[String] = []

	if _from_table.is_empty():
		errors.append("FROM table is required")

	if _select_columns.is_empty():
		errors.append("SELECT columns are required (or use select_all())")

	for w in _where_clauses:
		if w.has("param_index") and w["param_index"] > _parameters.size():
			errors.append("WHERE clause references invalid parameter index")

	return errors


## Check if query is valid
## @return: true if query has no validation errors
func is_valid() -> bool:
	return validate().is_empty()
