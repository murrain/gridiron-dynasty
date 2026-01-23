extends GdUnitTestSuite
class_name TestDatabaseQueryBuilderGdUnit4

## GdUnit4 tests for DatabaseQueryBuilder - SQL query construction
##
## Tests:
##   - Query building (SELECT, FROM, WHERE, ORDER BY, LIMIT)
##   - JOINs (INNER, LEFT, RIGHT)
##   - Parameter binding and SQL injection prevention
##   - Complex queries with multiple clauses
##   - Validation and error handling

const DatabaseQueryBuilder = preload("res://scripts/core/database/DatabaseQueryBuilder.gd")


# =============================================================================
# BASIC QUERY BUILDING TESTS
# =============================================================================

func test_simple_select_query() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id", "name"]).from("player").build()

	assert_str(result["sql"]).contains("SELECT id, name")
	assert_str(result["sql"]).contains("FROM player")


func test_select_all_columns() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select_all().from("team").build()

	assert_str(result["sql"]).contains("SELECT *")
	assert_str(result["sql"]).contains("FROM team")


func test_select_with_table_alias() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["p.id", "p.name"]).from("player", "p").build()

	assert_str(result["sql"]).contains("FROM player AS p")


func test_build_returns_empty_without_from_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).build()

	assert_str(result["sql"]).is_empty()


# =============================================================================
# WHERE CLAUSE TESTS
# =============================================================================

func test_where_clause_with_parameter_binding() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id", "name"]).from("player").where("age", ">=", 21).build()

	assert_str(result["sql"]).contains("WHERE age >= $1")
	assert_array(result["params"]).contains([21])


func test_multiple_where_clauses() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player") \
		.where("position", "=", "QB") \
		.where("age", ">=", 21) \
		.build()

	assert_str(result["sql"]).contains("WHERE position = $1 AND age >= $2")
	assert_int(result["params"].size()).is_equal(2)
	assert_str(String(result["params"][0])).is_equal("QB")
	assert_int(int(result["params"][1])).is_equal(21)


func test_or_where_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player") \
		.where("position", "=", "QB") \
		.or_where("position", "=", "RB") \
		.build()

	assert_str(result["sql"]).contains("position = $1 OR position = $2")


func test_where_in_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player") \
		.where_in("position", ["QB", "RB", "WR"]) \
		.build()

	assert_str(result["sql"]).contains("WHERE position IN ($1, $2, $3)")
	assert_int(result["params"].size()).is_equal(3)


func test_where_null_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").where_null("team_id").build()

	assert_str(result["sql"]).contains("WHERE team_id IS NULL")


func test_where_not_null_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").where_not_null("team_id").build()

	assert_str(result["sql"]).contains("WHERE team_id IS NOT NULL")


func test_where_between_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").where_between("age", 18, 30).build()

	assert_str(result["sql"]).contains("WHERE age BETWEEN $1 AND $2")
	assert_int(result["params"].size()).is_equal(2)
	assert_int(int(result["params"][0])).is_equal(18)
	assert_int(int(result["params"][1])).is_equal(30)


# =============================================================================
# JOIN TESTS
# =============================================================================

func test_inner_join() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["p.id", "s.tackles"]) \
		.from("player", "p") \
		.join("stats", "p.id", "s.player_id", "s") \
		.build()

	assert_str(result["sql"]).contains("INNER JOIN stats AS s ON p.id = s.player_id")


func test_left_join() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["p.id", "t.name"]) \
		.from("player", "p") \
		.left_join("team", "p.team_id", "t.id", "t") \
		.build()

	assert_str(result["sql"]).contains("LEFT JOIN team AS t ON p.team_id = t.id")


func test_right_join() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["t.id", "p.name"]) \
		.from("team", "t") \
		.right_join("player", "t.id", "p.team_id", "p") \
		.build()

	assert_str(result["sql"]).contains("RIGHT JOIN player AS p ON t.id = p.team_id")


func test_multiple_joins() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["p.name", "t.name", "s.tackles"]) \
		.from("player", "p") \
		.join("team", "p.team_id", "t.id", "t") \
		.join("stats", "p.id", "s.player_id", "s") \
		.build()

	assert_str(result["sql"]).contains("INNER JOIN team")
	assert_str(result["sql"]).contains("INNER JOIN stats")


# =============================================================================
# ORDER BY TESTS
# =============================================================================

func test_order_by_ascending() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id", "name"]).from("player").order_by("age", "ASC").build()

	assert_str(result["sql"]).contains("ORDER BY age ASC")


func test_order_by_descending() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id", "name"]).from("player").order_by("rating", "DESC").build()

	assert_str(result["sql"]).contains("ORDER BY rating DESC")


func test_multiple_order_by_clauses() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player") \
		.order_by("position", "ASC") \
		.order_by("rating", "DESC") \
		.build()

	assert_str(result["sql"]).contains("ORDER BY position ASC, rating DESC")


# =============================================================================
# GROUP BY AND HAVING TESTS
# =============================================================================

func test_group_by_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["position", "COUNT(*)"]) \
		.from("player") \
		.group_by(["position"]) \
		.build()

	assert_str(result["sql"]).contains("GROUP BY position")


func test_group_by_with_having() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["position", "COUNT(*)"]) \
		.from("player") \
		.group_by(["position"]) \
		.having("COUNT(*)", ">", 5) \
		.build()

	assert_str(result["sql"]).contains("GROUP BY position")
	assert_str(result["sql"]).contains("HAVING COUNT(*) > $1")


# =============================================================================
# LIMIT AND OFFSET TESTS
# =============================================================================

func test_limit_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").limit(10).build()

	assert_str(result["sql"]).contains("LIMIT 10")


func test_offset_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").offset(20).build()

	assert_str(result["sql"]).contains("OFFSET 20")


func test_limit_and_offset() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").limit(10).offset(20).build()

	assert_str(result["sql"]).contains("LIMIT 10")
	assert_str(result["sql"]).contains("OFFSET 20")


# =============================================================================
# COMPLEX QUERY TESTS
# =============================================================================

func test_complex_query_with_all_clauses() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["p.id", "p.name", "t.name", "s.tackles"]) \
		.from("player", "p") \
		.join("team", "p.team_id", "t.id", "t") \
		.join("stats", "p.id", "s.player_id", "s") \
		.where("p.position", "=", "LB") \
		.where("s.tackles", ">", 100) \
		.order_by("s.tackles", "DESC") \
		.limit(10) \
		.build()

	assert_str(result["sql"]).contains("SELECT p.id, p.name, t.name, s.tackles")
	assert_str(result["sql"]).contains("FROM player AS p")
	assert_str(result["sql"]).contains("INNER JOIN team AS t")
	assert_str(result["sql"]).contains("WHERE p.position = $1 AND s.tackles > $2")
	assert_str(result["sql"]).contains("ORDER BY s.tackles DESC")
	assert_str(result["sql"]).contains("LIMIT 10")


func test_query_builder_method_chaining() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder \
		.select(["id", "name"]) \
		.from("player") \
		.where("age", ">=", 21) \
		.where("position", "=", "QB") \
		.order_by("rating", "DESC") \
		.limit(5) \
		.build()

	assert_str(result["sql"]).is_not_empty()
	assert_int(result["params"].size()).is_equal(2)


# =============================================================================
# SQL INJECTION PREVENTION TESTS
# =============================================================================

func test_sanitize_identifier_removes_dangerous_characters() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player'; DROP TABLE player;--").build()

	# Should sanitize the table name
	assert_str(result["sql"]).does_not_contain("DROP TABLE")


func test_where_clause_uses_parameter_binding() -> void:
	var builder := DatabaseQueryBuilder.new()
	var malicious_value := "'; DROP TABLE player; --"
	var result := builder.select(["id"]).from("player").where("name", "=", malicious_value).build()

	# Should use parameter binding, not direct injection
	assert_str(result["sql"]).does_not_contain("DROP TABLE")
	assert_str(result["sql"]).contains("$1")
	assert_str(String(result["params"][0])).is_equal(malicious_value)


# =============================================================================
# RESET AND REUSE TESTS
# =============================================================================

func test_reset_clears_all_query_components() -> void:
	var builder := DatabaseQueryBuilder.new()

	# Build a complex query
	builder.select(["id", "name"]).from("player").where("age", ">", 25).order_by("name").limit(10)

	# Reset
	builder.reset()

	# Build a new simple query
	var result := builder.select(["id"]).from("team").build()

	assert_str(result["sql"]).is_equal("SELECT id FROM team")
	assert_int(result["params"].size()).is_equal(0)


func test_builder_can_be_reused_after_reset() -> void:
	var builder := DatabaseQueryBuilder.new()

	# First query
	var result1 := builder.select(["id"]).from("player").where("age", ">", 25).build()
	assert_int(result1["params"].size()).is_equal(1)

	# Reset and build second query
	builder.reset()
	var result2 := builder.select(["name"]).from("team").where("division", "=", "AFC").build()

	assert_str(result2["sql"]).does_not_contain("player")
	assert_str(result2["sql"]).contains("team")
	assert_int(result2["params"].size()).is_equal(1)
	assert_str(String(result2["params"][0])).is_equal("AFC")


# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_validate_detects_missing_from_clause() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["id", "name"])

	var errors := builder.validate()

	assert_int(errors.size()).is_greater(0)
	assert_str(errors[0]).contains("FROM table is required")


func test_is_valid_returns_false_for_incomplete_query() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["id"])

	assert_bool(builder.is_valid()).is_false()


func test_is_valid_returns_true_for_complete_query() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["id", "name"]).from("player")

	assert_bool(builder.is_valid()).is_true()


# =============================================================================
# EDGE CASES
# =============================================================================

func test_where_in_with_empty_array() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id"]).from("player").where_in("position", []).build()

	# Should not add WHERE IN clause
	assert_str(result["sql"]).does_not_contain("IN")


func test_select_also_adds_columns_without_duplicates() -> void:
	var builder := DatabaseQueryBuilder.new()
	var result := builder.select(["id", "name"]).select_also(["age", "name"]).from("player").build()

	# "name" should not be duplicated
	var sql: String = result["sql"]
	var name_count := 0
	var pos := 0
	while true:
		pos = sql.find("name", pos)
		if pos == -1:
			break
		name_count += 1
		pos += 1

	assert_int(name_count).is_equal(1)


func test_to_sql_returns_only_sql_string() -> void:
	var builder := DatabaseQueryBuilder.new()
	var sql := builder.select(["id"]).from("player").where("age", ">", 25).to_sql()

	assert_str(sql).is_not_empty()
	assert_str(sql).contains("SELECT")


func test_get_params_returns_parameter_array() -> void:
	var builder := DatabaseQueryBuilder.new()
	builder.select(["id"]).from("player").where("age", ">", 25).where("position", "=", "QB")

	var params := builder.get_params()

	assert_int(params.size()).is_equal(2)
	assert_int(int(params[0])).is_equal(25)
	assert_str(String(params[1])).is_equal("QB")
