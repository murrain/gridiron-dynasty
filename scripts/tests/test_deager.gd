extends RefCounted

func run(t: TestHelpers) -> void:
	var player := {
		"age": 20,
		"stats": {"speed": 80.0, "awareness": 60.0, "bonus": 99.0}
	}
	var stats_cfg := {
		"stats": [
			{"name": "speed", "type": "base"},
			{"name": "awareness", "type": "base", "default": 50},
			{"name": "bonus", "type": "derived"}
		]
	}
	var deage_cfg := {
		"core_stats": ["speed"],
		"secondary_stats": ["awareness"],
		"core_pct_min": 0.9,
		"core_pct_max": 0.9,
		"core_var": 0.0,
		"secondary_pct_min": 0.8,
		"secondary_pct_max": 0.8,
		"secondary_var": 0.0,
		"other_pct_min": 0.5,
		"other_pct_max": 0.5,
		"other_var": 0.0,
		"noise_min": 0.0,
		"noise_max": 0.0,
		"floor": 0.0,
		"ceil": 100.0,
		"only_base_stats": true,
		"keep_existing_defaults": true,
		"target_age": 18
	}

	var deaged := DeAger.de_age(player, {}, deage_cfg, stats_cfg)
	t.assert_eq(deaged.get("age"), 18, "DeAger should update age")
	var stats := deaged.get("stats", {}) as Dictionary
	t.assert_between(float(stats.get("speed")), 70.0, 90.0, "DeAger should scale core stats")
	t.assert_eq(stats.get("awareness"), 60.0, "DeAger should keep existing defaults when configured")
	t.assert_eq(stats.get("bonus"), 99.0, "DeAger should skip derived stats when only_base_stats")

	deage_cfg["keep_existing_defaults"] = false
	var deaged2 := DeAger.de_age(player, {}, deage_cfg, stats_cfg)
	var stats2 := deaged2.get("stats", {}) as Dictionary
	t.assert_eq(stats2.get("awareness"), 50, "DeAger should force defaults when configured")
