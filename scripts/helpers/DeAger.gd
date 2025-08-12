# res://helpers/DeAger.gd
extends Node
class_name DeAger

## Adjusts a player's data to "de-age" them, e.g., scaling down experience or stats.
##
## @param player       Dictionary representing a player
## @param positions    Dictionary of position data
## @param deage_cfg    Configuration dictionary for how to de-age
##
## @return Dictionary  A modified copy of the player with adjusted stats
static func de_age(player: Dictionary, positions: Dictionary, deage_cfg: Dictionary) -> Dictionary:
	var new_player := player.duplicate(true)

	# Example placeholder: reduce all stats by the configured percentage
	if deage_cfg.has("stat_reduction_pct"):
		var reduction := float(deage_cfg["stat_reduction_pct"])
		if new_player.has("stats"):
			for stat in new_player["stats"].keys():
				new_player["stats"][stat] = new_player["stats"][stat] * (1.0 - reduction)

	# Placeholder: reset age if configured
	if deage_cfg.has("target_age"):
		new_player["age"] = int(deage_cfg["target_age"])

	return new_player