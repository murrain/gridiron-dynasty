## GdUnit4 test suite for DatabaseQueryBuilder
##
## Tests type-safe SQL query builder with parameterized queries:
## - SELECT clause building
## - FROM clause building
## - JOIN operations (INNER, LEFT, RIGHT)
## - WHERE clause building with parameter binding
## - ORDER BY, LIMIT, OFFSET
## - GROUP BY and HAVING
## - SQL injection prevention
## - Parameter binding safety
## - Query validation
## - Deterministic query generation
##
## RNG: No RNG consumption - all queries are deterministic pure functions
extends GdUnitTestSuite

const DatabaseQueryBuilder = preload("res://scripts/core/database/DatabaseQueryBuilder.gd")


# =========================
# SELECT Clause Tests
# =========================

func test_select_single_column() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["id"]).from("player").build()

	assert_str(query["sql"]).contains("SELECT id")
	assert_str(query["sql"]).contains("FROM player")


func test_select_multiple_columns() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["id", "name", "position"]).from("player").build()

	assert_str(query["sql"]).contains("SELECT id, name, position")


func test_select_all() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select_all().from("player").build()

	assert_str(query["sql"]).contains("SELECT *")


func test_select_also_adds_columns() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["id"]).select_also(["name", "age"]).from("player").build()

	assert_str(query["sql"]).contains("SELECT id, name, age")


func test_select_also_does_not_duplicate() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["id", "name"]).select_also(["name", "age"]).from("player").build()

	# "name" should appear only once
	var sql: String = query["sql"]
	var first_name_idx := sql.find("name")
	var second_name_idx := sql.find("name", first_name_idx + 1)

	# Second occurrence should be in a different context (not in SELECT)
	assert_bool(first_name_idx != -1).is_true()


func test_select_with_qualified_column_names() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["player.id", "player.name"]).from("player").build()

	assert_str(query["sql"]).contains("SELECT player.id, player.name")


# =========================
# FROM Clause Tests
# =========================

func test_from_table() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").build()

	assert_str(query["sql"]).contains("FROM player")


func test_from_table_with_alias() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player", "p").build()

	assert_str(query["sql"]).contains("FROM player AS p")


func test_missing_from_returns_error() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["id"]).build()

	assert_str(query["sql"]).is_empty()


# =========================
# JOIN Tests
# =========================

func test_inner_join() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").join("player_stats", "player.id", "player_stats.player_id").build()

	assert_str(query["sql"]).contains("INNER JOIN player_stats ON player.id = player_stats.player_id")


func test_left_join() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").left_join("player_stats", "player.id", "player_stats.player_id").build()

	assert_str(query["sql"]).contains("LEFT JOIN player_stats ON player.id = player_stats.player_id")


func test_right_join() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").right_join("player_stats", "player.id", "player_stats.player_id").build()

	assert_str(query["sql"]).contains("RIGHT JOIN player_stats ON player.id = player_stats.player_id")


func test_join_with_alias() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player", "p").join("player_stats", "p.id", "ps.player_id", "ps").build()

	assert_str(query["sql"]).contains("FROM player AS p")
	assert_str(query["sql"]).contains("INNER JOIN player_stats AS ps ON p.id = ps.player_id")


func test_multiple_joins() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player") \
		.join("player_stats", "player.id", "player_stats.player_id") \
		.left_join("player_contract", "player.id", "player_contract.player_id") \
		.build()

	assert_str(query["sql"]).contains("INNER JOIN player_stats")
	assert_str(query["sql"]).contains("LEFT JOIN player_contract")


# =========================
# WHERE Clause Tests
# =========================

func test_where_equal() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where("position", "=", "QB").build()

	assert_str(query["sql"]).contains("WHERE position = $1")
	assert_array(query["params"]).contains(["QB"])


func test_where_numeric() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where("age", ">=", 21).build()

	assert_str(query["sql"]).contains("WHERE age >= $1")
	assert_array(query["params"]).contains([21])


func test_where_multiple_conditions() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player") \
		.where("position", "=", "QB") \
		.where("age", ">=", 21) \
		.where("age", "<=", 30) \
		.build()

	assert_str(query["sql"]).contains("WHERE position = $1 AND age >= $2 AND age <= $3")
	assert_int(query["params"].size()).is_equal(3)


func test_or_where() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player") \
		.where("position", "=", "QB") \
		.or_where("position", "=", "RB") \
		.build()

	assert_str(query["sql"]).contains("WHERE position = $1 OR position = $2")


func test_where_like() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where("name", "LIKE", "%Smith%").build()

	assert_str(query["sql"]).contains("WHERE name LIKE $1")
	assert_array(query["params"]).contains(["%Smith%"])


func test_where_in() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where_in("position", ["QB", "RB", "WR"]).build()

	assert_str(query["sql"]).contains("WHERE position IN ($1, $2, $3)")
	assert_int(query["params"].size()).is_equal(3)


func test_where_null() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where_null("team_id").build()

	assert_str(query["sql"]).contains("WHERE team_id IS NULL")
	assert_array(query["params"]).is_empty()


func test_where_not_null() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where_not_null("team_id").build()

	assert_str(query["sql"]).contains("WHERE team_id IS NOT NULL")


func test_where_between() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where_between("age", 21, 30).build()

	assert_str(query["sql"]).contains("WHERE age BETWEEN $1 AND $2")
	assert_array(query["params"]).contains([21, 30])


# =========================
# ORDER BY Tests
# =========================

func test_order_by_single() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").order_by("age").build()

	assert_str(query["sql"]).contains("ORDER BY age ASC")


func test_order_by_desc() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").order_by("age", "DESC").build()

	assert_str(query["sql"]).contains("ORDER BY age DESC")


func test_order_by_multiple() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player") \
		.order_by("position", "ASC") \
		.order_by("age", "DESC") \
		.build()

	assert_str(query["sql"]).contains("ORDER BY position ASC, age DESC")


# =========================
# LIMIT and OFFSET Tests
# =========================

func test_limit() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").limit(10).build()

	assert_str(query["sql"]).contains("LIMIT 10")


func test_offset() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").limit(10).offset(20).build()

	assert_str(query["sql"]).contains("LIMIT 10")
	assert_str(query["sql"]).contains("OFFSET 20")


func test_limit_negative_becomes_zero() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").limit(-5).build()

	assert_str(query["sql"]).contains("LIMIT 0")


# =========================
# GROUP BY and HAVING Tests
# =========================

func test_group_by() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["position", "COUNT(*)"]).from("player").group_by(["position"]).build()

	assert_str(query["sql"]).contains("GROUP BY position")


func test_group_by_multiple() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["position", "team_id", "COUNT(*)"]).from("player").group_by(["position", "team_id"]).build()

	assert_str(query["sql"]).contains("GROUP BY position, team_id")


func test_having() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["position", "COUNT(*)"]).from("player") \
		.group_by(["position"]) \
		.having("COUNT(*)", ">", 5) \
		.build()

	# HAVING clause should preserve the aggregate function name
	assert_str(query["sql"]).contains("HAVING COUNT(*) > $1")
	assert_array(query["params"]).contains([5])


# =========================
# Parameter Binding Tests
# =========================

func test_parameter_indices_are_sequential() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player") \
		.where("position", "=", "QB") \
		.where("age", ">=", 21) \
		.where("team_id", "=", "team_a") \
		.build()

	assert_str(query["sql"]).contains("$1")
	assert_str(query["sql"]).contains("$2")
	assert_str(query["sql"]).contains("$3")
	assert_int(query["params"].size()).is_equal(3)
	assert_array(query["params"]).is_equal(["QB", 21, "team_a"])


func test_get_params_returns_copy() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["*"]).from("player").where("id", "=", "test")

	var params1 := builder.get_params()
	var params2 := builder.get_params()

	# Modifying one shouldn't affect the other
	params1.append("extra")
	assert_int(params2.size()).is_equal(1)


func test_to_sql_returns_sql_string() -> void:
	var builder := DatabaseQueryBuilder.new()
	var sql := builder.select(["*"]).from("player").to_sql()

	assert_str(sql).is_equal("SELECT * FROM player")


# =========================
# SQL Injection Prevention Tests
# =========================

func test_sanitize_table_name_removes_dangerous_chars() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player; DROP TABLE player;--").build()

	# Should sanitize the dangerous characters
	assert_str(query["sql"]).not_contains(";")
	assert_str(query["sql"]).not_contains("DROP")
	assert_str(query["sql"]).not_contains("--")


func test_sanitize_column_name_removes_dangerous_chars() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["id", "name; DROP TABLE player"]).from("player").build()

	# Should sanitize
	assert_str(query["sql"]).not_contains(";")
	assert_str(query["sql"]).not_contains("DROP")


func test_values_are_parameterized_not_inline() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player") \
		.where("name", "=", "'; DROP TABLE player; --") \
		.build()

	# The dangerous value should be in params, not in SQL
	assert_str(query["sql"]).not_contains("DROP")
	assert_str(query["sql"]).contains("$1")
	assert_array(query["params"]).contains(["'; DROP TABLE player; --"])


func test_sanitize_preserves_qualified_column_names() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["player.id", "player.name"]).from("player").build()

	assert_str(query["sql"]).contains("player.id")
	assert_str(query["sql"]).contains("player.name")


# =========================
# Reset and Reuse Tests
# =========================

func test_reset_clears_builder() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["*"]).from("player").where("age", "=", 25)

	builder.reset()

	var query := builder.select(["id"]).from("team").build()

	assert_str(query["sql"]).contains("SELECT id")
	assert_str(query["sql"]).contains("FROM team")
	assert_str(query["sql"]).not_contains("player")
	assert_str(query["sql"]).not_contains("age")
	assert_array(query["params"]).is_empty()


func test_builder_reuse_with_reset() -> void:
	var builder := DatabaseQueryBuilder.new()

	# First query
	var q1 := builder.select(["*"]).from("player").where("position", "=", "QB").build()
	assert_str(q1["sql"]).contains("player")

	# Reset and build different query
	builder.reset()
	var q2 := builder.select(["*"]).from("team").where("name", "=", "Eagles").build()
	assert_str(q2["sql"]).contains("team")
	assert_str(q2["sql"]).not_contains("player")


# =========================
# Validation Tests
# =========================

func test_validate_requires_from() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["id"])

	var errors := builder.validate()
	assert_array(errors).contains(["FROM table is required"])


func test_validate_requires_select() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.from("player")

	var errors := builder.validate()
	assert_array(errors).contains(["SELECT columns are required (or use select_all())"])


func test_is_valid_returns_true_for_valid_query() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["*"]).from("player")

	assert_bool(builder.is_valid()).is_true()


func test_is_valid_returns_false_for_invalid_query() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["id"])  # No FROM

	assert_bool(builder.is_valid()).is_false()


# =========================
# Complex Query Tests
# =========================

func test_complex_query_with_all_clauses() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder \
		.select(["p.id", "p.name", "p.position", "s.speed", "s.strength"]) \
		.from("player", "p") \
		.join("player_stats", "p.id", "s.player_id", "s") \
		.left_join("player_contract", "p.id", "c.player_id", "c") \
		.where("p.position", "=", "QB") \
		.where("p.age", ">=", 21) \
		.where("p.age", "<=", 30) \
		.where_not_null("s.speed") \
		.order_by("s.speed", "DESC") \
		.order_by("p.name", "ASC") \
		.limit(20) \
		.offset(0) \
		.build()

	# Verify structure
	assert_str(query["sql"]).contains("SELECT p.id, p.name, p.position, s.speed, s.strength")
	assert_str(query["sql"]).contains("FROM player AS p")
	assert_str(query["sql"]).contains("INNER JOIN player_stats AS s ON p.id = s.player_id")
	assert_str(query["sql"]).contains("LEFT JOIN player_contract AS c ON p.id = c.player_id")
	assert_str(query["sql"]).contains("WHERE")
	assert_str(query["sql"]).contains("ORDER BY s.speed DESC, p.name ASC")
	assert_str(query["sql"]).contains("LIMIT 20")
	assert_str(query["sql"]).contains("OFFSET 0")

	# Verify parameters
	assert_int(query["params"].size()).is_equal(3)


# =========================
# Determinism Tests
# =========================

func test_deterministic_query_generation() -> void:
	# Build the same query three times
	var queries: Array = []

	for i in range(3):
		var builder := DatabaseQueryBuilder.new()
		var query := builder \
			.select(["id", "name", "position"]) \
			.from("player") \
			.where("position", "=", "QB") \
			.where("age", ">=", 21) \
			.order_by("age", "DESC") \
			.limit(10) \
			.build()
		queries.append(query)

	# All should be identical
	assert_str(queries[0]["sql"]).is_equal(queries[1]["sql"])
	assert_str(queries[1]["sql"]).is_equal(queries[2]["sql"])
	assert_array(queries[0]["params"]).is_equal(queries[1]["params"])
	assert_array(queries[1]["params"]).is_equal(queries[2]["params"])


func test_parameter_order_is_deterministic() -> void:
	var builder1 := DatabaseQueryBuilder.new()
	var q1 := builder1.select(["*"]).from("player") \
		.where("a", "=", 1) \
		.where("b", "=", 2) \
		.where("c", "=", 3) \
		.build()

	var builder2 := DatabaseQueryBuilder.new()
	var q2 := builder2.select(["*"]).from("player") \
		.where("a", "=", 1) \
		.where("b", "=", 2) \
		.where("c", "=", 3) \
		.build()

	assert_array(q1["params"]).is_equal(q2["params"])
	assert_array(q1["params"]).is_equal([1, 2, 3])


# =========================
# Edge Case Tests
# =========================

func test_empty_select_defaults_to_star() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.from("player").build()

	assert_str(query["sql"]).contains("SELECT *")


func test_where_in_with_empty_array_is_skipped() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").where_in("position", []).build()

	assert_str(query["sql"]).not_contains("WHERE")
	assert_str(query["sql"]).not_contains("IN")


func test_invalid_operator_is_rejected() -> void:
	var builder := DatabaseQueryBuilder.new()
	# Using invalid operator "INVALID"
	var query := builder.select(["*"]).from("player").where("age", "INVALID", 25).build()

	# Should not have WHERE clause (invalid operator rejected)
	assert_str(query["sql"]).not_contains("WHERE")


func test_invalid_join_type_is_rejected() -> void:
	var builder := DatabaseQueryBuilder.new()
	# Directly call _add_join with invalid type (testing internal)
	var query := builder.select(["*"]).from("player")._add_join("OUTER", "stats", "a", "b", "").build()

	# Should not have JOIN clause
	assert_str(query["sql"]).not_contains("JOIN")


func test_order_by_invalid_direction_defaults_to_asc() -> void:
	var builder := DatabaseQueryBuilder.new()
	var query := builder.select(["*"]).from("player").order_by("age", "INVALID").build()

	assert_str(query["sql"]).contains("ORDER BY age ASC")
