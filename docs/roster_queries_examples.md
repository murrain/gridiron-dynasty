# RosterQueries Usage Examples

The `RosterQueries` utility class provides static functions for analyzing roster composition, position groups, depth charts, and player distribution metrics.

## Position Groups

Group players into offense, defense, and special teams:

```gdscript
# Get roster from TeamQueries
var roster = TeamQueries.get_nfl_roster(world_state, team_id)

# Group by position categories
var groups = RosterQueries.get_position_groups(roster)

print("Offense: %d players" % groups["offense"].size())
print("Defense: %d players" % groups["defense"].size())
print("Special Teams: %d players" % groups["special_teams"].size())
```

**Position Mappings:**
- Offense: QB, RB, WR, TE, OL
- Defense: DL, EDGE, LB, CB, S
- Special Teams: K, P

## Position Strength

Calculate average rating for a specific position:

```gdscript
var qb_strength = RosterQueries.calculate_position_strength(roster, "QB")
var cb_strength = RosterQueries.calculate_position_strength(roster, "CB")

print("QB Average Rating: %.1f" % qb_strength)
print("CB Average Rating: %.1f" % cb_strength)

# Identify weak position groups
var all_positions = ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
for pos in all_positions:
    var strength = RosterQueries.calculate_position_strength(roster, pos)
    if strength < 60.0:
        print("WARNING: %s is weak (%.1f)" % [pos, strength])
```

## Position Depth

Count players at each position:

```gdscript
var depth = RosterQueries.analyze_position_depth(roster)

# Display depth chart
for position in depth.keys():
    var count = depth[position]
    print("%s: %d players" % [position, count])

# Identify gaps
if depth.get("QB", 0) < 3:
    print("Need more QBs!")
if depth.get("OL", 0) < 8:
    print("Need more offensive linemen!")
```

## Age Distribution

Analyze team age demographics:

```gdscript
var age_dist = RosterQueries.get_age_distribution(roster)

print("Youngest: %d" % age_dist["min"])
print("Oldest: %d" % age_dist["max"])
print("Average Age: %.1f" % age_dist["avg"])
print("Median Age: %.1f" % age_dist["median"])

# Determine team maturity
if age_dist["avg"] < 23.0:
    print("Young team - high potential")
elif age_dist["avg"] > 27.0:
    print("Veteran team - win-now window")
```

## Experience Distribution

Analyze experience levels (college or NFL):

### College Teams

```gdscript
var college_roster = TeamQueries.get_college_roster(world_state, college_id)
var exp_dist = RosterQueries.get_experience_distribution(college_roster, "college")

print("Freshmen: %d" % exp_dist.get("freshmen", 0))
print("Sophomores: %d" % exp_dist.get("sophomores", 0))
print("Juniors: %d" % exp_dist.get("juniors", 0))
print("Seniors: %d" % exp_dist.get("seniors", 0))
print("Fifth Year: %d" % exp_dist.get("fifth_year", 0))

# Calculate team experience level
var experienced = exp_dist.get("juniors", 0) + exp_dist.get("seniors", 0) + exp_dist.get("fifth_year", 0)
var total = college_roster.size()
var experience_pct = float(experienced) / float(total) * 100.0
print("Experience Level: %.1f%%" % experience_pct)
```

### NFL Teams

```gdscript
var nfl_roster = TeamQueries.get_nfl_roster(world_state, team_id)
var exp_dist = RosterQueries.get_experience_distribution(nfl_roster, "nfl")

print("Rookies: %d" % exp_dist.get("rookies", 0))
print("Year 2: %d" % exp_dist.get("year_2", 0))
print("Year 3: %d" % exp_dist.get("year_3", 0))
print("Year 4: %d" % exp_dist.get("year_4", 0))
print("Year 5+: %d" % exp_dist.get("year_5_plus", 0))

# Calculate rookie percentage
var rookie_pct = float(exp_dist.get("rookies", 0)) / float(nfl_roster.size()) * 100.0
print("Rookie Percentage: %.1f%%" % rookie_pct)
```

## Complete Team Analysis

Combine all metrics for comprehensive team evaluation:

```gdscript
func analyze_team(world_state: Dictionary, team_id: String, level: String) -> void:
    var roster: Array
    match level:
        "nfl":
            roster = TeamQueries.get_nfl_roster(world_state, team_id)
        "college":
            roster = TeamQueries.get_college_roster(world_state, team_id)

    if roster.is_empty():
        print("No players on roster")
        return

    print("\n=== TEAM ANALYSIS ===\n")

    # Size
    print("Roster Size: %d\n" % roster.size())

    # Position Groups
    var groups = RosterQueries.get_position_groups(roster)
    print("Position Groups:")
    print("  Offense: %d" % groups["offense"].size())
    print("  Defense: %d" % groups["defense"].size())
    print("  Special Teams: %d\n" % groups["special_teams"].size())

    # Age
    var age_dist = RosterQueries.get_age_distribution(roster)
    print("Age Distribution:")
    print("  Range: %d - %d" % [age_dist["min"], age_dist["max"]])
    print("  Average: %.1f" % age_dist["avg"])
    print("  Median: %.1f\n" % age_dist["median"])

    # Experience
    var exp_dist = RosterQueries.get_experience_distribution(roster, level)
    print("Experience Distribution:")
    for exp_level in exp_dist.keys():
        print("  %s: %d" % [exp_level, exp_dist[exp_level]])
    print()

    # Position Strengths
    print("Position Strengths:")
    var depth = RosterQueries.analyze_position_depth(roster)
    for position in depth.keys():
        var strength = RosterQueries.calculate_position_strength(roster, position)
        var count = depth[position]
        print("  %s: %.1f avg (%d players)" % [position, strength, count])
```

## Performance Notes

- `get_position_groups()`: O(N) - Linear scan of roster
- `calculate_position_strength()`: O(N) - Linear scan of roster
- `analyze_position_depth()`: O(N) - Linear scan of roster
- `get_age_distribution()`: O(N log N) - Requires sorting for median
- `get_experience_distribution()`: O(N) - Linear scan of roster

All functions handle empty rosters gracefully by returning zero values or empty collections.
