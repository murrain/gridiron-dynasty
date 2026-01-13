extends SceneTree
## Test script to verify draft order calculation and rookie contract AAV

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func _init() -> void:
	print("=== Testing Draft Order and Rookie Contracts ===\n")
	run_test()
	quit()

func run_test() -> void:
	# Bootstrap a world and simulate 3 years
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run()

	var world_state: Dictionary = result.get("world_state", {})
	var current_year := int(result.get("start_year", 0))

	print("Bootstrap complete - Current year: %d\n" % current_year)

	# Test 1: Verify season records exist
	print("=== Test 1: Season Records ===")
	var season_records: Dictionary = world_state.get("season_records", {})
	print("Season records years: %s" % str(season_records.keys()))

	for year in season_records.keys():
		var records: Dictionary = season_records[year]
		print("\nYear %d standings (sample):" % year)
		var teams_sorted := []
		for team_id in records.keys():
			var record: Dictionary = records[team_id]
			teams_sorted.append({
				"id": team_id,
				"wins": record.get("wins", 0),
				"losses": record.get("losses", 0),
				"sos": record.get("strength_of_schedule", 0.0)
			})

		# Sort by wins (descending) to show best and worst
		teams_sorted.sort_custom(func(a, b): return a["wins"] > b["wins"])

		# Show top 3 and bottom 3
		for i in range(min(3, teams_sorted.size())):
			var t = teams_sorted[i]
			print("  %s: %d-%d (SOS: %.3f)" % [t["id"], t["wins"], t["losses"], t["sos"]])
		if teams_sorted.size() > 6:
			print("  ...")
		for i in range(max(0, teams_sorted.size() - 3), teams_sorted.size()):
			var t = teams_sorted[i]
			print("  %s: %d-%d (SOS: %.3f)" % [t["id"], t["wins"], t["losses"], t["sos"]])

	# Test 2: Verify draft picks and contract AAV
	print("\n=== Test 2: Draft Picks and Rookie Contracts ===")
	var draft_history: Dictionary = world_state.get("draft_history", {})

	for year in draft_history.keys():
		var picks: Array = draft_history[year]
		print("\nYear %d draft (first 5 picks):" % year)

		for i in range(min(5, picks.size())):
			var pick: Dictionary = picks[i]
			var player: Dictionary = pick.get("player", {})
			var contract: Dictionary = player.get("contract", {})
			var team_id := String(pick.get("team_id", ""))
			var overall_pick := int(pick.get("overall_pick", 0))
			var player_name := "%s %s" % [player.get("first_name", ""), player.get("last_name", "")]
			var position := String(player.get("position", ""))

			var aav := float(contract.get("annual_value", 0.0))
			var base_salary := float(contract.get("base_salary", 0.0))
			var signing_bonus := float(contract.get("signing_bonus", 0.0))

			print("  Pick %d: %s (%s) to %s" % [overall_pick, player_name, position, team_id])
			print("    AAV: $%.2fM | Base: $%.2fM | Bonus: $%.2fM" % [aav, base_salary, signing_bonus])

	# Test 3: Verify draft order changes between years
	print("\n=== Test 3: Draft Order Variance ===")
	if draft_history.size() >= 2:
		var years_sorted := draft_history.keys()
		years_sorted.sort()

		var year1: int = years_sorted[0]
		var year2: int = years_sorted[1]

		var picks1: Array = draft_history[year1]
		var picks2: Array = draft_history[year2]

		print("\nFirst 5 picks comparison:")
		print("Year %d first 5 teams: " % year1)
		for i in range(min(5, picks1.size())):
			print("  Pick %d: %s" % [i+1, picks1[i].get("team_id", "")])

		print("\nYear %d first 5 teams: " % year2)
		for i in range(min(5, picks2.size())):
			print("  Pick %d: %s" % [i+1, picks2[i].get("team_id", "")])

		# Check if order changed
		var order_changed := false
		for i in range(min(5, picks1.size(), picks2.size())):
			if picks1[i].get("team_id", "") != picks2[i].get("team_id", ""):
				order_changed = true
				break

		if order_changed:
			print("\n✅ PASS: Draft order varies between years")
		else:
			print("\n⚠️  WARNING: Draft order appears identical (may be expected for year 0-1)")

	# Test 4: Verify AAV values are non-zero
	print("\n=== Test 4: AAV Validation ===")
	var all_aav_valid := true
	var aav_samples := []

	for year in draft_history.keys():
		var picks: Array = draft_history[year]
		for pick in picks:
			var player: Dictionary = pick.get("player", {})
			var contract: Dictionary = player.get("contract", {})
			var aav := float(contract.get("annual_value", 0.0))

			if aav <= 0.0:
				all_aav_valid = false
				print("❌ FAIL: Found zero AAV for pick %d in year %d" % [pick.get("overall_pick", 0), year])

			# Collect samples for summary
			if pick.get("overall_pick", 0) in [1, 32, 64, 96, 128]:  # Sample key picks
				aav_samples.append({
					"year": year,
					"pick": pick.get("overall_pick", 0),
					"aav": aav
				})

	if all_aav_valid:
		print("✅ PASS: All rookie contracts have non-zero AAV")

	print("\nAAV samples (key picks):")
	for sample in aav_samples:
		print("  Year %d, Pick %d: $%.2fM" % [sample["year"], sample["pick"], sample["aav"]])

	print("\n=== All Tests Complete ===")
