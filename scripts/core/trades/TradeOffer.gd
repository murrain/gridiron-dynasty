# res://scripts/core/trades/TradeOffer.gd
extends RefCounted
class_name TradeOffer

## Trade offer schema for dictionary-based scaffolding.
## {
##   "from_team_id": "...",
##   "to_team_id": "...",
##   "send": { "players": [player_ids], "picks": [pick_ids] },
##   "receive": { "players": [player_ids], "picks": [pick_ids] }
## }
##
## Team roster inputs should map team_id -> Array of player_ids.
## Pick ownership inputs should map pick_id -> team_id.

static func build(
	from_team_id: String,
	to_team_id: String,
	send: Dictionary,
	receive: Dictionary
) -> Dictionary:
	return {
		"from_team_id": from_team_id,
		"to_team_id": to_team_id,
		"send": _normalize_bundle(send),
		"receive": _normalize_bundle(receive)
	}

static func empty_bundle() -> Dictionary:
	return {
		"players": [],
		"picks": []
	}

static func validate_offer(
	offer: Dictionary,
	team_rosters: Dictionary,
	pick_owners: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var from_team_id := String(offer.get("from_team_id", ""))
	var to_team_id := String(offer.get("to_team_id", ""))

	if from_team_id == "":
		errors.append("from_team_id is required")
	elif not team_rosters.has(from_team_id):
		errors.append("from_team_id not found: %s" % from_team_id)

	if to_team_id == "":
		errors.append("to_team_id is required")
	elif not team_rosters.has(to_team_id):
		errors.append("to_team_id not found: %s" % to_team_id)

	_validate_bundle_ids(
		String(offer.get("from_team_id", "")),
		offer.get("send", {}),
		team_rosters,
		pick_owners,
		errors
	)
	_validate_bundle_ids(
		String(offer.get("to_team_id", "")),
		offer.get("receive", {}),
		team_rosters,
		pick_owners,
		errors
	)

	return {
		"ok": errors.is_empty(),
		"errors": errors
	}

static func _normalize_bundle(bundle: Dictionary) -> Dictionary:
	var players := (bundle.get("players", []) as Array).duplicate()
	var picks := (bundle.get("picks", []) as Array).duplicate()
	return {
		"players": players,
		"picks": picks
	}

static func _validate_bundle_ids(
	team_id: String,
	bundle: Dictionary,
	team_rosters: Dictionary,
	pick_owners: Dictionary,
	errors: Array[String]
) -> void:
	if team_id == "":
		return

	var roster: Array = team_rosters.get(team_id, [])
	var players: Array = bundle.get("players", []) as Array
	for player_id in players:
		var id := String(player_id)
		if id == "":
			errors.append("player_id is required")
			continue
		if not roster.has(id):
			errors.append("player_id %s not on team %s" % [id, team_id])

	var picks: Array = bundle.get("picks", []) as Array
	for pick_id in picks:
		var id := String(pick_id)
		if id == "":
			errors.append("pick_id is required")
			continue
		if not pick_owners.has(id):
			errors.append("pick_id not found: %s" % id)
			continue
		if String(pick_owners.get(id, "")) != team_id:
			errors.append("pick_id %s not owned by team %s" % [id, team_id])
