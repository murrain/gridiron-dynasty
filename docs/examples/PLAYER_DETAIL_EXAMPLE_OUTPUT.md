# Player Detail View - Example Output

This document shows example BBCode output from the Phase 1 enhanced PlayerDetailFormatter.

## Complete Player Example

### Input Data
```gdscript
{
	"name": "John Smith",
	"position": "QB",
	"age": 22,
	"stats": {
		"throw_power": 85.0,
		"throw_accuracy": 80.0,
		"speed": 75.0,
		"awareness": 78.0,
		"decision_making": 76.0
	},
	"potential": {
		"throw_power": 90.0,
		"throw_accuracy": 88.0,
		"speed": 78.0,
		"awareness": 85.0,
		"decision_making": 82.0
	},
	"physicals": {
		"height_in": 76.0,
		"weight_lb": 225.0
	},
	"combine": {
		"forty_sec": 4.65,
		"vertical_in": 32.0,
		"broad_in": 115.0,
		"bench_225_reps": 15
	},
	"wear": {
		"snaps": 2500,
		"collisions": 850,
		"injury_count": 2
	},
	"development_report": [
		{"year": 2021, "context": "College Year 1", "changes": {"throw_power": 3, "awareness": 2}},
		{"year": 2022, "context": "College Year 2", "changes": {"throw_power": 4, "speed": 2}},
		{"year": 2023, "context": "College Year 3", "changes": {"throw_accuracy": 5, "decision_making": 3}},
		{"year": 2024, "context": "College Year 4", "changes": {"awareness": 4, "speed": 1}}
	],
	"nfl_team_id": "KC"
}
```

### Rendered Output (BBCode → Rich Text)

---

<div align="center">
<h2>John Smith</h2>
<h3>QB • Age 22</h3>
<div style="background-color: #66ff66; display: inline-block; padding: 4px 8px;">
<b>80 Overall</b>
</div>
</div>

**Physical Attributes**

| | |
|---|---|
| Height: | 6' 4" |
| Weight: | 225 lbs |

**Core Stats**

| | | |
|---|---|---|
| Throw Power: | <span style="color: #00ff00">85</span> | ████████████████████░ |
| Throw Accuracy: | <span style="color: #66ff66">80</span> | ████████████████░░░░░ |
| Awareness: | <span style="color: #66ff66">78</span> | ███████████████░░░░░░ |
| Decision Making: | <span style="color: #99ff99">76</span> | ███████████████░░░░░░ |

**All Stats**

| | | | |
|---|---|---|---|
| Awareness: | <span style="color: #66ff66">78</span> | Decision Making: | <span style="color: #99ff99">76</span> |
| Speed: | <span style="color: #99ff99">75</span> | Throw Accuracy: | <span style="color: #66ff66">80</span> |
| Throw Power: | <span style="color: #00ff00">85</span> | | |

**Career Info**

Team: Kansas City Chiefs

**Potential Ratings**

| | | |
|---|---|---|
| Awareness: | <span style="color: #66ff66">78</span> → <span style="color: #00ff00">85</span> | <span style="color: #00ff00">+7</span> |
| Decision Making: | <span style="color: #99ff99">76</span> → <span style="color: #66ff66">82</span> | <span style="color: #00ff00">+6</span> |
| Speed: | <span style="color: #99ff99">75</span> → <span style="color: #66ff66">78</span> | <span style="color: #00ff00">+3</span> |
| Throw Accuracy: | <span style="color: #66ff66">80</span> → <span style="color: #00ff00">88</span> | <span style="color: #00ff00">+8</span> |
| Throw Power: | <span style="color: #00ff00">85</span> → <span style="color: #00ff00">90</span> | <span style="color: #00ff00">+5</span> |

**Combine Metrics**

| | |
|---|---|
| 40-Yard Dash: | 4.65 sec |
| Vertical Jump: | 32.0 in |
| Broad Jump: | 115 in |
| Bench Press (225): | 15 reps |

**Career Wear & Injuries**

Career Snaps: 2,500 | Collisions: 850 | Injuries: <span style="color: #ffff00">2</span>

**Development History**

Year 2024: +4 awareness, +1 speed (College Year 4)<br>
Year 2023: +5 throw accuracy, +3 decision making (College Year 3)<br>
Year 2022: +4 throw power, +2 speed (College Year 2)<br>
Year 2021: +3 throw power, +2 awareness (College Year 1)

---

## Minimal Player Example (Missing Optional Data)

### Input Data
```gdscript
{
	"name": "Jane Doe",
	"position": "WR",
	"age": 19,
	"stats": {
		"speed": 85.0,
		"catching": 78.0,
		"route_running": 75.0
	},
	"physicals": {
		"height_in": 70.0,
		"weight_lb": 180.0
	}
}
```

### Rendered Output

---

<div align="center">
<h2>Jane Doe</h2>
<h3>WR • Age 19</h3>
<div style="background-color: #66ff66; display: inline-block; padding: 4px 8px;">
<b>79 Overall</b>
</div>
</div>

**Physical Attributes**

| | |
|---|---|
| Height: | 5' 10" |
| Weight: | 180 lbs |

**Core Stats**

| | | |
|---|---|---|
| Speed: | <span style="color: #00ff00">85</span> | █████████████████░░░░ |
| Route Running: | <span style="color: #99ff99">75</span> | ███████████████░░░░░░ |
| Catching: | <span style="color: #66ff66">78</span> | ███████████████░░░░░░ |
| Awareness: | <span style="color: #ff0000">0</span> | ░░░░░░░░░░░░░░░░░░░░░ |

**All Stats**

| | | | |
|---|---|---|---|
| Catching: | <span style="color: #66ff66">78</span> | Route Running: | <span style="color: #99ff99">75</span> |
| Speed: | <span style="color: #00ff00">85</span> | | |

**Career Info**

<span style="color: #999999; font-style: italic">No career information available</span>

---

*Note: No optional sections (Potential, Combine, Wear, Development) appear because the player data doesn't include those fields.*

## Veteran Player with High Wear Example

### Input Data
```gdscript
{
	"name": "Mike Johnson",
	"position": "RB",
	"age": 31,
	"stats": {
		"speed": 72.0,
		"strength": 85.0,
		"vision": 88.0,
		"agility": 75.0
	},
	"physicals": {
		"height_in": 71.0,
		"weight_lb": 210.0
	},
	"wear": {
		"snaps": 8750,
		"collisions": 3240,
		"injury_count": 6
	}
}
```

### Rendered Output (Wear Section)

**Career Wear & Injuries**

Career Snaps: 8,750 | Collisions: 3,240 | Injuries: <span style="color: #ff0000">6</span>

---

*Note: High injury count (6) displays in red, indicating significant injury history.*

## Prospect with Long Development History

### Input Data
```gdscript
{
	"name": "Sam Williams",
	"position": "LB",
	"age": 22,
	"stats": {
		"speed": 80.0,
		"tackling": 82.0,
		"awareness": 76.0,
		"coverage": 74.0
	},
	"development_report": [
		{"year": 2018, "context": "HS Year 1", "changes": {"speed": 2, "tackling": 3}},
		{"year": 2019, "context": "HS Year 2", "changes": {"speed": 3, "awareness": 2}},
		{"year": 2020, "context": "HS Year 3", "changes": {"tackling": 4, "coverage": 2}},
		{"year": 2021, "context": "College Year 1", "changes": {"awareness": 3, "coverage": 3}},
		{"year": 2022, "context": "College Year 2", "changes": {"speed": 2, "tackling": 3}},
		{"year": 2023, "context": "College Year 3", "changes": {"awareness": 4, "coverage": 2}},
		{"year": 2024, "context": "College Year 4", "changes": {"tackling": 3, "coverage": 3}},
		{"year": 2025, "context": "NFL Rookie", "changes": {"awareness": 2, "speed": 1}}
	]
}
```

### Rendered Output (Development Section)

**Development History**

Year 2025: +2 awareness, +1 speed (NFL Rookie)<br>
Year 2024: +3 tackling, +3 coverage (College Year 4)<br>
Year 2023: +4 awareness, +2 coverage (College Year 3)<br>
Year 2022: +2 speed, +3 tackling (College Year 2)<br>
Year 2021: +3 awareness, +3 coverage (College Year 1)<br>
<span style="color: #999999; font-style: italic">(+3 older entries)</span>

---

*Note: Only shows last 5 entries, with note indicating 3 older entries exist.*

## Color Coding Reference

### Rating Colors (StatQueries.get_stat_color_hex)
- **Elite** (90+): <span style="color: #00ff00">#00ff00</span> (bright green)
- **Great** (80-89): <span style="color: #66ff66">#66ff66</span> (light green)
- **Good** (70-79): <span style="color: #99ff99">#99ff99</span> (pale green)
- **Average** (60-69): <span style="color: #ffff00">#ffff00</span> (yellow)
- **Below Avg** (50-59): <span style="color: #ffaa00">#ffaa00</span> (orange)
- **Poor** (<50): <span style="color: #ff0000">#ff0000</span> (red)

### Delta Colors (Potential Section)
- **Positive**: <span style="color: #00ff00">#00ff00</span> (green)
- **Negative**: <span style="color: #ff0000">#ff0000</span> (red)
- **Zero**: <span style="color: #ffff00">#ffff00</span> (yellow)

### Injury Count Colors (Wear Section)
- **0-1**: <span style="color: #00ff00">#00ff00</span> (green)
- **2**: <span style="color: #ffff00">#ffff00</span> (yellow)
- **3-4**: <span style="color: #ffaa00">#ffaa00</span> (orange)
- **5+**: <span style="color: #ff0000">#ff0000</span> (red)

## BBCode Format Details

All sections use BBCode tags that RichTextLabel can render:

- `[b]...[/b]` - Bold text
- `[i]...[/i]` - Italic text
- `[color=#RRGGBB]...[/color]` - Colored text
- `[bgcolor=#RRGGBB]...[/bgcolor]` - Background color
- `[table=N]...[/table]` - N-column table
- `[cell]...[/cell]` - Table cell
- `[center]...[/center]` - Centered text
- `[font_size=N]...[/font_size]` - Font size
- `→` - Unicode arrow character (U+2192)
- `★` - Unicode star character (U+2605)

## Layout Specifications

### Section Spacing
- Each major section followed by `\n\n` (blank line)
- Within sections, single `\n` between rows
- No extra spacing between table rows

### Table Formats
- **2-column**: Used for physical attributes, combine metrics
- **3-column**: Used for core stats (with progress bar), potential ratings
- **4-column**: Used for all stats (compact grid)

### Number Formatting
- Ratings: Whole numbers (e.g., `85`)
- Percentages: One decimal (e.g., `85.0%`)
- Measurements: Match precision (e.g., `4.65 sec`, `32.0 in`)
- Large numbers: Thousand separators (e.g., `2,500`)

### Text Casing
- Section headers: Title Case (e.g., "Potential Ratings")
- Stat names: Title Case with spaces (e.g., "Throw Power")
- Context strings: As provided (e.g., "College Year 2")
