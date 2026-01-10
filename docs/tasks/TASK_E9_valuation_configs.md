# Task E9: Consolidate Valuation Configuration

**Track**: Player Valuation (Track E)
**Dependencies**: None (can be done in parallel with E5-E8)
**Status**: Not started
**Estimated Effort**: 0.5 days

## Goal

Consolidate all valuation-related configuration values into well-documented JSON files, ensuring no magic numbers remain in the code.

## Current State

Valuation config files exist but may be incomplete:
- `configs/sports/american_football/valuation.json`
- `configs/sports/american_football/contract_valuation.json`

## Implementation

### Files to Update

1. **`configs/sports/american_football/valuation.json`**
2. **`configs/sports/american_football/contract_valuation.json`**

### Required Configuration Sections

#### valuation.json

```json
{
  "version": 1,

  "value_curve": {
    "curve_type": "tiered_exponential",
    "tiers": [
      {"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
      {"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
      {"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
      {"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
      {"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
    ],
    "elite_threshold": 92,
    "elite_multiplier_boost": 1.5
  },

  "replacement_levels": {
    "_comment": "Baseline talent available at league minimum cost by position",
    "QB": 55.0,
    "RB": 62.0,
    "WR": 58.0,
    "TE": 56.0,
    "OL": 54.0,
    "DL": 57.0,
    "EDGE": 52.0,
    "LB": 58.0,
    "CB": 53.0,
    "S": 57.0,
    "K": 65.0,
    "P": 65.0
  },

  "scarcity": {
    "_comment": "Supply/demand multipliers for positional scarcity",
    "scarcity_min": 0.7,
    "scarcity_max": 1.5,
    "starter_slots": {
      "QB": 1,
      "RB": 1,
      "WR": 3,
      "TE": 1,
      "OL": 5,
      "DL": 2,
      "EDGE": 2,
      "LB": 3,
      "CB": 2,
      "S": 2,
      "K": 1,
      "P": 1
    }
  },

  "team_impact": {
    "_comment": "Depth and positional importance for team-specific value",
    "no_backup_multiplier": 1.4,
    "thin_depth_multiplier": 1.15,
    "position_win_impacts": {
      "QB": 2.5,
      "EDGE": 1.4,
      "CB": 1.3,
      "WR": 1.2,
      "OL": 1.1,
      "DL": 1.1,
      "LB": 1.0,
      "S": 0.95,
      "TE": 0.9,
      "RB": 0.8,
      "K": 0.5,
      "P": 0.4
    }
  },

  "market": {
    "_comment": "Contract range variance for negotiation",
    "range_spread_pct": 0.15
  }
}
```

#### contract_valuation.json

```json
{
  "version": 2,
  "_comment": "Contract generation and valuation settings",

  "age_multipliers": {
    "_comment": "Age impact on contract value (peak years = 1.0)",
    "22": 0.85,
    "23": 0.90,
    "24": 0.95,
    "25": 1.00,
    "26": 1.00,
    "27": 1.00,
    "28": 0.95,
    "29": 0.90,
    "30": 0.80,
    "31": 0.70,
    "32": 0.60,
    "33": 0.50,
    "34+": 0.40
  },

  "contract_lengths": {
    "_comment": "Typical contract lengths by player quality",
    "elite": {"min": 4, "max": 6},
    "starter": {"min": 3, "max": 5},
    "backup": {"min": 1, "max": 3},
    "minimum": {"min": 1, "max": 1}
  },

  "guarantees": {
    "_comment": "Guaranteed money percentage by tier",
    "elite": 0.70,
    "starter": 0.50,
    "backup": 0.25,
    "minimum": 0.10
  },

  "rookie_scale": {
    "_comment": "Rookie contract values by draft pick (overrides market value)",
    "enabled": true,
    "round_1_apy": 8.0,
    "round_2_apy": 3.0,
    "round_3_apy": 1.5,
    "round_4_apy": 1.0,
    "round_5_apy": 0.8,
    "round_6_apy": 0.7,
    "round_7_apy": 0.6,
    "years": 4
  }
}
```

## Configuration Validation

Add a validation function in `PlayerValue.gd` to check config completeness:

```gdscript
static func validate_config(config: Dictionary) -> Array:
    var errors: Array = []

    # Check required sections exist
    var required := ["value_curve", "replacement_levels", "scarcity", "team_impact", "market"]
    for section in required:
        if not config.has(section):
            errors.append("Missing config section: %s" % section)

    # Check value_curve tiers
    if config.has("value_curve"):
        var tiers := config.value_curve.get("tiers", [])
        if tiers.size() < 3:
            errors.append("value_curve.tiers must have at least 3 tiers")

    # Check replacement_levels has all positions
    if config.has("replacement_levels"):
        var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
        for pos in positions:
            if not config.replacement_levels.has(pos):
                errors.append("Missing replacement_level for position: %s" % pos)

    return errors
```

## Test Coverage

Add config validation test in `test_player_value.gd`:

```gdscript
func _test_config_validation(t):
    var config := Config.get_config("valuation")
    var errors := PlayerValue.validate_config(config)
    t.assert_true(errors.is_empty(), "Config validation failed: %s" % str(errors))
```

## Acceptance Criteria

- [ ] All valuation config consolidated in `valuation.json`
- [ ] All contract config consolidated in `contract_valuation.json`
- [ ] Every config value has a `_comment` field explaining its purpose
- [ ] Config validation function catches missing sections
- [ ] No magic numbers remain in PlayerValue, ContractValuation, or related files
- [ ] All tests pass using config values

## Files to Modify

- `configs/sports/american_football/valuation.json`
- `configs/sports/american_football/contract_valuation.json`

## Files to Add Validation

- `scripts/core/valuation/PlayerValue.gd` (add validate_config method)

## Next Task

After completing E9, proceed to **TASK_E10_valuation_tests.md** to add comprehensive test coverage for the complete valuation system.
