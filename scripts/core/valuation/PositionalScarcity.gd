class_name PositionalScarcity

## Positional Scarcity Factor
##
## Calculates supply/demand multipliers for player positions based on:
## - Starter slots needed per team (demand)
## - Number of above-replacement players available (supply)
##
## If supply < demand, scarcity > 1.0 (premium)
## If supply > demand, scarcity < 1.0 (discount)

# How many starters needed per team × 32 teams = total demand
static var STARTER_SLOTS: Dictionary = {
	"QB": 1,    # 32 total needed
	"RB": 1,    # 32 (ignoring committees for simplicity)
	"WR": 3,    # 96
	"TE": 1,    # 32
	"OL": 5,    # 160
	"DL": 2,    # 64
	"EDGE": 2,  # 64
	"LB": 3,    # 96
	"CB": 2,    # 64
	"S": 2,     # 64
	"K": 1,     # 32
	"P": 1      # 32
}

## Compute scarcity multiplier for a position based on supply vs demand
##
## @param position: Position code (e.g., "QB", "WR")
## @param players_above_replacement: Number of players above replacement level at this position
## @param config: Configuration dictionary with optional keys:
##   - scarcity_min: Minimum multiplier (default 0.7)
##   - scarcity_max: Maximum multiplier (default 1.5)
## @return: Scarcity multiplier (clamped between min and max)
static func compute_scarcity_multiplier(
	position: String,
	players_above_replacement: int,
	config: Dictionary
) -> float:
	var slots := STARTER_SLOTS.get(position, 1) * 32
	var supply := float(players_above_replacement)
	var demand := float(slots)

	# Scarcity = demand / supply (clamped)
	# If supply < demand, scarcity > 1.0 (premium)
	# If supply > demand, scarcity < 1.0 (discount)
	var ratio := demand / max(supply, 1.0)
	var min_mult := float(config.get("scarcity_min", 0.7))
	var max_mult := float(config.get("scarcity_max", 1.5))
	return clamp(ratio, min_mult, max_mult)
