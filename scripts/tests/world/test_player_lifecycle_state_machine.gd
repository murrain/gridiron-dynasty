extends GutTest

## Tests for PlayerLifecycleStateMachine
##
## Verifies:
## - Valid transitions are allowed
## - Invalid transitions are rejected
## - Lifecycle path is correct
## - Phase mapping is complete
## - Reachability analysis works

const Player = preload("res://scripts/core/models/Player.gd")
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

## Test that valid transitions are allowed
func test_can_transition_valid_paths():
	# HIGH_SCHOOL -> COLLEGE
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.HIGH_SCHOOL,
			Player.PlayerStage.COLLEGE
		),
		"HIGH_SCHOOL should transition to COLLEGE"
	)

	# COLLEGE -> DRAFT_ELIGIBLE
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.COLLEGE,
			Player.PlayerStage.DRAFT_ELIGIBLE
		),
		"COLLEGE should transition to DRAFT_ELIGIBLE"
	)

	# DRAFT_ELIGIBLE -> NFL_ROOKIE
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.DRAFT_ELIGIBLE,
			Player.PlayerStage.NFL_ROOKIE
		),
		"DRAFT_ELIGIBLE should transition to NFL_ROOKIE"
	)

	# NFL_ROOKIE -> NFL_VETERAN
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.NFL_ROOKIE,
			Player.PlayerStage.NFL_VETERAN
		),
		"NFL_ROOKIE should transition to NFL_VETERAN"
	)

	# NFL_VETERAN -> RETIRED
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.NFL_VETERAN,
			Player.PlayerStage.RETIRED
		),
		"NFL_VETERAN should transition to RETIRED"
	)

## Test that invalid transitions are rejected
func test_can_transition_invalid_paths():
	# Cannot skip stages
	assert_false(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.HIGH_SCHOOL,
			Player.PlayerStage.DRAFT_ELIGIBLE
		),
		"Cannot skip from HIGH_SCHOOL to DRAFT_ELIGIBLE"
	)

	# Cannot go backwards
	assert_false(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.NFL_VETERAN,
			Player.PlayerStage.NFL_ROOKIE
		),
		"Cannot go backwards from NFL_VETERAN to NFL_ROOKIE"
	)

	# Cannot leave retirement
	assert_false(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.RETIRED,
			Player.PlayerStage.NFL_VETERAN
		),
		"Cannot leave RETIRED stage"
	)

## Test free agent transitions
func test_free_agent_transitions():
	# DRAFT_ELIGIBLE -> NFL_FREE_AGENT (undrafted)
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.DRAFT_ELIGIBLE,
			Player.PlayerStage.NFL_FREE_AGENT
		),
		"DRAFT_ELIGIBLE can become NFL_FREE_AGENT"
	)

	# NFL_FREE_AGENT -> NFL_VETERAN (sign as veteran)
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.NFL_FREE_AGENT,
			Player.PlayerStage.NFL_VETERAN
		),
		"NFL_FREE_AGENT can sign as NFL_VETERAN"
	)

	# NFL_VETERAN -> NFL_FREE_AGENT (contract expires)
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.NFL_VETERAN,
			Player.PlayerStage.NFL_FREE_AGENT
		),
		"NFL_VETERAN can become NFL_FREE_AGENT"
	)

## Test college year-to-year progression
func test_college_self_transition():
	# COLLEGE -> COLLEGE (stay in college another year)
	assert_true(
		PlayerLifecycleStateMachine.can_transition(
			Player.PlayerStage.COLLEGE,
			Player.PlayerStage.COLLEGE
		),
		"COLLEGE can stay COLLEGE (year-to-year)"
	)

## Test transition_player validates and updates stage
func test_transition_player_success():
	var player := Player.new()
	player.first_name = "Test"
	player.last_name = "Player"
	player.stage = Player.PlayerStage.HIGH_SCHOOL

	var success := PlayerLifecycleStateMachine.transition_player(
		player,
		Player.PlayerStage.COLLEGE,
		"college_recruiting"
	)

	assert_true(success, "Transition should succeed")
	assert_eq(player.stage, Player.PlayerStage.COLLEGE, "Stage should be updated to COLLEGE")

## Test transition_player rejects invalid transitions
func test_transition_player_rejects_invalid():
	var player := Player.new()
	player.first_name = "Test"
	player.last_name = "Player"
	player.stage = Player.PlayerStage.HIGH_SCHOOL

	var success := PlayerLifecycleStateMachine.transition_player(
		player,
		Player.PlayerStage.NFL_ROOKIE,  # Invalid: skipping stages
		"test_phase"
	)

	assert_false(success, "Invalid transition should fail")
	assert_eq(player.stage, Player.PlayerStage.HIGH_SCHOOL, "Stage should remain unchanged")

## Test get_lifecycle_path returns correct sequence
func test_get_lifecycle_path():
	var path := PlayerLifecycleStateMachine.get_lifecycle_path()

	assert_eq(path.size(), 6, "Path should have 6 stages")
	assert_eq(path[0], Player.PlayerStage.HIGH_SCHOOL)
	assert_eq(path[1], Player.PlayerStage.COLLEGE)
	assert_eq(path[2], Player.PlayerStage.DRAFT_ELIGIBLE)
	assert_eq(path[3], Player.PlayerStage.NFL_ROOKIE)
	assert_eq(path[4], Player.PlayerStage.NFL_VETERAN)
	assert_eq(path[5], Player.PlayerStage.RETIRED)

## Test get_valid_next_stages returns correct options
func test_get_valid_next_stages():
	# HIGH_SCHOOL has one option
	var hs_next := PlayerLifecycleStateMachine.get_valid_next_stages(Player.PlayerStage.HIGH_SCHOOL)
	assert_eq(hs_next.size(), 1, "HIGH_SCHOOL should have 1 next stage")
	assert_true(Player.PlayerStage.COLLEGE in hs_next)

	# COLLEGE has two options
	var college_next := PlayerLifecycleStateMachine.get_valid_next_stages(Player.PlayerStage.COLLEGE)
	assert_eq(college_next.size(), 2, "COLLEGE should have 2 next stages")
	assert_true(Player.PlayerStage.DRAFT_ELIGIBLE in college_next)
	assert_true(Player.PlayerStage.COLLEGE in college_next)

	# NFL_ROOKIE has three options
	var rookie_next := PlayerLifecycleStateMachine.get_valid_next_stages(Player.PlayerStage.NFL_ROOKIE)
	assert_eq(rookie_next.size(), 3, "NFL_ROOKIE should have 3 next stages")
	assert_true(Player.PlayerStage.NFL_VETERAN in rookie_next)
	assert_true(Player.PlayerStage.NFL_FREE_AGENT in rookie_next)
	assert_true(Player.PlayerStage.RETIRED in rookie_next)

	# RETIRED has no options
	var retired_next := PlayerLifecycleStateMachine.get_valid_next_stages(Player.PlayerStage.RETIRED)
	assert_eq(retired_next.size(), 0, "RETIRED should have no next stages")

## Test is_terminal_stage identifies retired
func test_is_terminal_stage():
	assert_true(
		PlayerLifecycleStateMachine.is_terminal_stage(Player.PlayerStage.RETIRED),
		"RETIRED should be terminal"
	)
	assert_false(
		PlayerLifecycleStateMachine.is_terminal_stage(Player.PlayerStage.HIGH_SCHOOL),
		"HIGH_SCHOOL should not be terminal"
	)
	assert_false(
		PlayerLifecycleStateMachine.is_terminal_stage(Player.PlayerStage.NFL_VETERAN),
		"NFL_VETERAN should not be terminal"
	)

## Test get_reachable_stages finds all possible future stages
func test_get_reachable_stages():
	# From HIGH_SCHOOL, can reach everything except HIGH_SCHOOL
	var reachable := PlayerLifecycleStateMachine.get_reachable_stages(Player.PlayerStage.HIGH_SCHOOL)
	assert_true(Player.PlayerStage.COLLEGE in reachable)
	assert_true(Player.PlayerStage.DRAFT_ELIGIBLE in reachable)
	assert_true(Player.PlayerStage.NFL_ROOKIE in reachable)
	assert_true(Player.PlayerStage.NFL_VETERAN in reachable)
	assert_true(Player.PlayerStage.NFL_FREE_AGENT in reachable)
	assert_true(Player.PlayerStage.RETIRED in reachable)

	# From NFL_VETERAN, can only reach NFL_FREE_AGENT and RETIRED
	var veteran_reachable := PlayerLifecycleStateMachine.get_reachable_stages(Player.PlayerStage.NFL_VETERAN)
	assert_true(Player.PlayerStage.NFL_FREE_AGENT in veteran_reachable)
	assert_true(Player.PlayerStage.RETIRED in veteran_reachable)
	# Should be able to reach NFL_VETERAN and NFL_ROOKIE through free agency
	assert_true(Player.PlayerStage.NFL_VETERAN in veteran_reachable or Player.PlayerStage.NFL_ROOKIE in veteran_reachable)

	# From RETIRED, cannot reach anything
	var retired_reachable := PlayerLifecycleStateMachine.get_reachable_stages(Player.PlayerStage.RETIRED)
	assert_eq(retired_reachable.size(), 0, "Cannot reach any stage from RETIRED")

## Test get_transition_phase returns correct phase IDs
func test_get_transition_phase():
	# HIGH_SCHOOL -> COLLEGE
	var phase := PlayerLifecycleStateMachine.get_transition_phase(
		Player.PlayerStage.HIGH_SCHOOL,
		Player.PlayerStage.COLLEGE
	)
	assert_eq(phase, "college_recruiting", "HIGH_SCHOOL -> COLLEGE should use college_recruiting phase")

	# DRAFT_ELIGIBLE -> NFL_ROOKIE
	phase = PlayerLifecycleStateMachine.get_transition_phase(
		Player.PlayerStage.DRAFT_ELIGIBLE,
		Player.PlayerStage.NFL_ROOKIE
	)
	assert_eq(phase, "nfl_draft", "DRAFT_ELIGIBLE -> NFL_ROOKIE should use nfl_draft phase")

	# NFL_VETERAN -> RETIRED
	phase = PlayerLifecycleStateMachine.get_transition_phase(
		Player.PlayerStage.NFL_VETERAN,
		Player.PlayerStage.RETIRED
	)
	assert_eq(phase, "retirement", "NFL_VETERAN -> RETIRED should use retirement phase")

## Test validate_transition_phase checks phase consistency
func test_validate_transition_phase():
	# Correct phase
	assert_true(
		PlayerLifecycleStateMachine.validate_transition_phase(
			Player.PlayerStage.DRAFT_ELIGIBLE,
			Player.PlayerStage.NFL_ROOKIE,
			"nfl_draft"
		),
		"Should validate when using correct phase"
	)

	# Wrong phase (should warn but still return false)
	assert_false(
		PlayerLifecycleStateMachine.validate_transition_phase(
			Player.PlayerStage.DRAFT_ELIGIBLE,
			Player.PlayerStage.NFL_ROOKIE,
			"wrong_phase"
		),
		"Should not validate when using wrong phase"
	)

## Test full lifecycle progression
func test_full_lifecycle_progression():
	var player := Player.new()
	player.first_name = "Full"
	player.last_name = "Career"
	player.stage = Player.PlayerStage.HIGH_SCHOOL

	# HIGH_SCHOOL -> COLLEGE
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.COLLEGE, "college_recruiting")
	)
	assert_eq(player.stage, Player.PlayerStage.COLLEGE)

	# COLLEGE -> DRAFT_ELIGIBLE
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.DRAFT_ELIGIBLE, "pre_draft")
	)
	assert_eq(player.stage, Player.PlayerStage.DRAFT_ELIGIBLE)

	# DRAFT_ELIGIBLE -> NFL_ROOKIE
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_ROOKIE, "nfl_draft")
	)
	assert_eq(player.stage, Player.PlayerStage.NFL_ROOKIE)

	# NFL_ROOKIE -> NFL_VETERAN
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_VETERAN, "nfl_season_end")
	)
	assert_eq(player.stage, Player.PlayerStage.NFL_VETERAN)

	# NFL_VETERAN -> RETIRED
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.RETIRED, "retirement")
	)
	assert_eq(player.stage, Player.PlayerStage.RETIRED)

	# Cannot transition from RETIRED
	assert_false(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_VETERAN, "invalid")
	)
	assert_eq(player.stage, Player.PlayerStage.RETIRED)

## Test undrafted free agent path
func test_undrafted_free_agent_path():
	var player := Player.new()
	player.first_name = "UDFA"
	player.last_name = "Journey"
	player.stage = Player.PlayerStage.DRAFT_ELIGIBLE

	# DRAFT_ELIGIBLE -> NFL_FREE_AGENT (goes undrafted)
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_FREE_AGENT, "post_draft_udfa")
	)
	assert_eq(player.stage, Player.PlayerStage.NFL_FREE_AGENT)

	# NFL_FREE_AGENT -> NFL_VETERAN (signs contract)
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_VETERAN, "free_agency")
	)
	assert_eq(player.stage, Player.PlayerStage.NFL_VETERAN)

	# NFL_VETERAN -> NFL_FREE_AGENT (contract expires)
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_FREE_AGENT, "nfl_contract_expiry")
	)
	assert_eq(player.stage, Player.PlayerStage.NFL_FREE_AGENT)

	# NFL_FREE_AGENT -> RETIRED
	assert_true(
		PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.RETIRED, "retirement")
	)
	assert_eq(player.stage, Player.PlayerStage.RETIRED)
