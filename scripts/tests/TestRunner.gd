extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

const TEST_SCRIPTS := [
	"res://scripts/tests/test_rand.gd",
	"res://scripts/tests/test_threadpool.gd",
	"res://scripts/tests/test_core_utilities.gd",
	"res://scripts/tests/test_config.gd",
	"res://scripts/tests/test_config_loader.gd",
	"res://scripts/tests/test_helpers.gd",
	"res://scripts/tests/test_deager.gd",
	"res://scripts/tests/test_stathelpers.gd",
	"res://scripts/tests/test_combine_calculator.gd",
	"res://scripts/tests/test_player_model.gd",
	"res://scripts/tests/test_high_school_assignment.gd",
	"res://scripts/tests/test_player_lifecycle.gd",
	"res://scripts/tests/test_player_lifecycle_reports.gd",
	"res://scripts/tests/test_parallel_lifecycle.gd",
	"res://scripts/tests/test_copy_optimization.gd",
	"res://scripts/tests/test_world_calendar.gd",
	"res://scripts/tests/test_high_school_generator.gd",
	"res://scripts/tests/test_high_school_season.gd",
	"res://scripts/tests/test_player_generator.gd",
	"res://scripts/tests/test_recruit_rater.gd",
	"res://scripts/tests/test_scout_runtime.gd",
	"res://scripts/tests/test_scout_model.gd",
	"res://scripts/tests/test_scout_factory.gd",
	"res://scripts/tests/test_score_cache.gd",
	"res://scripts/tests/test_class_generator.gd",
	"res://scripts/tests/test_draft_class_generator.gd",
	"res://scripts/tests/test_college_recruiting.gd",
	"res://scripts/tests/test_college_season.gd",
	"res://scripts/tests/test_nfl_team_generator.gd",
	"res://scripts/tests/test_nfl_draft.gd",
	"res://scripts/tests/test_nfl_season.gd",
	"res://scripts/tests/test_advance_world_year_helpers.gd",
	"res://scripts/tests/test_college_eligibility_filter.gd",
	"res://scripts/tests/test_hs_to_college_filter_integration.gd",
	"res://scripts/tests/test_pipeline_seed_helpers.gd",
	"res://scripts/tests/test_world_history_preview.gd",
	"res://scripts/tests/test_valuation_helpers.gd",
	"res://scripts/tests/test_value_curve.gd",
	"res://scripts/tests/test_replacement_level.gd",
	"res://scripts/tests/test_positional_scarcity.gd",
	"res://scripts/tests/test_team_impact.gd",
	"res://scripts/tests/test_player_value.gd",
	"res://scripts/tests/test_contract_valuation.gd",
	"res://scripts/tests/test_market_supply.gd",
	"res://scripts/tests/test_cap_accounting.gd",
	"res://scripts/tests/test_cap_validation_flow.gd",
	"res://scripts/tests/test_trade_valuation.gd",
	"res://scripts/tests/test_phase4_scaffolding.gd",
	"res://scripts/tests/test_bootstrap_game_world.gd"
]

func _init() -> void:
	var total_failures: Array = []
	for path in TEST_SCRIPTS:
		var script = load(path)
		if script == null:
			total_failures.append("Failed to load %s" % path)
			continue
		var test_instance = script.new()
		var helper = TestHelpers.new()
		test_instance.run(helper)
		for failure in helper.failures:
			total_failures.append("%s: %s" % [path, failure])

	if total_failures.is_empty():
		print("All tests passed (%d)." % TEST_SCRIPTS.size())
		quit(0)
		return

	print("Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
