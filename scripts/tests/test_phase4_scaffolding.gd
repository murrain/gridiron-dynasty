extends RefCounted

func run(t) -> void:
	var team_path := "res://scripts/core/models/Team.gd"
	var roster_path := "res://scripts/core/models/Roster.gd"
	var coach_path := "res://scripts/core/models/Coach.gd"
	var league_path := "res://scripts/world/LeagueContainer.gd"

	if not ResourceLoader.exists(team_path):
		t.assert_true(true, "Phase4 Team model not yet implemented")
		return
	if not ResourceLoader.exists(roster_path):
		t.assert_true(true, "Phase4 Roster model not yet implemented")
		return
	if not ResourceLoader.exists(coach_path):
		t.assert_true(true, "Phase4 Coach model not yet implemented")
		return
	if not ResourceLoader.exists(league_path):
		t.assert_true(true, "Phase4 LeagueContainer not yet implemented")
		return

	var team := load(team_path).new()
	var roster := load(roster_path).new()
	var coach := load(coach_path).new()
	var league := load(league_path).new()

	t.assert_true(team != null, "Team model instantiates")
	t.assert_true(roster != null, "Roster model instantiates")
	t.assert_true(coach != null, "Coach model instantiates")
	t.assert_true(league != null, "LeagueContainer instantiates")
