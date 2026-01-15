## GdUnit4 tests for the universal Modifier system
extends GdUnitTestSuite

const Modifier = preload("res://scripts/core/modifiers/Modifier.gd")
const ModifierRegistry = preload("res://scripts/core/modifiers/ModifierRegistry.gd")
const SchemeFitModifier = preload("res://scripts/core/modifiers/evaluation/SchemeFitModifier.gd")
const CoachMindsetModifier = preload("res://scripts/core/modifiers/evaluation/CoachMindsetModifier.gd")
const PositionNeedModifier = preload("res://scripts/core/modifiers/evaluation/PositionNeedModifier.gd")
const InjuryModifier = preload("res://scripts/core/modifiers/player/InjuryModifier.gd")


# =============================================================================
# MODIFIER BASE CLASS TESTS
# =============================================================================

func test_modifier_result_apply_to() -> void:
	var result := Modifier.ModifierResult.new(1.2, 5.0)  # 20% boost + 5 flat
	var value := 100.0
	var final := result.apply_to(value)
	assert_float(final).is_equal(125.0)  # (100 * 1.2) + 5 = 125


func test_modifier_result_is_neutral() -> void:
	var neutral := Modifier.ModifierResult.new(1.0, 0.0)
	assert_bool(neutral.is_neutral()).is_true()

	var non_neutral := Modifier.ModifierResult.new(1.1, 0.0)
	assert_bool(non_neutral.is_neutral()).is_false()


func test_modifier_contexts() -> void:
	var mod := Modifier.new()
	# Base modifier applies to ALWAYS context
	assert_bool(mod.applies_to_context(Modifier.Context.ALWAYS)).is_true()


# =============================================================================
# MODIFIER REGISTRY TESTS
# =============================================================================

func test_registry_register_global() -> void:
	var registry := ModifierRegistry.new()
	var mod := SchemeFitModifier.new()

	registry.register_global(mod)

	var modifiers := registry.get_global_modifiers()
	assert_int(modifiers.size()).is_equal(1)
	assert_str(modifiers[0].get_id()).is_equal("scheme_fit")


func test_registry_unregister_global() -> void:
	var registry := ModifierRegistry.new()
	registry.register_global(SchemeFitModifier.new())

	var success := registry.unregister_global("scheme_fit")
	assert_bool(success).is_true()
	assert_int(registry.get_global_modifiers().size()).is_equal(0)


func test_registry_attach_to_entity() -> void:
	var registry := ModifierRegistry.new()
	var injury := InjuryModifier.new(
		InjuryModifier.Severity.MINOR,
		InjuryModifier.BodyPart.HAND,
		7
	)

	registry.attach("player", "player_123", injury)

	var mods := registry.get_entity_modifiers("player", "player_123")
	assert_int(mods.size()).is_equal(1)
	assert_str(mods[0].get_display_name()).contains("Hand")


func test_registry_detach_from_entity() -> void:
	var registry := ModifierRegistry.new()
	var injury := InjuryModifier.new(
		InjuryModifier.Severity.MODERATE,
		InjuryModifier.BodyPart.LEG,
		14
	)
	registry.attach("player", "player_456", injury)

	var success := registry.detach("player", "player_456", injury.get_id())
	assert_bool(success).is_true()
	assert_int(registry.get_entity_modifiers("player", "player_456").size()).is_equal(0)


func test_registry_get_modifiers_filters_by_target_and_context() -> void:
	var registry := ModifierRegistry.new()
	registry.register_global(SchemeFitModifier.new())
	registry.register_global(CoachMindsetModifier.new())
	registry.register_global(PositionNeedModifier.new())

	# All three should apply to TEAM_EVALUATION + DRAFT
	var draft_mods := registry.get_modifiers(
		Modifier.Target.TEAM_EVALUATION,
		Modifier.Context.DRAFT
	)
	assert_int(draft_mods.size()).is_equal(3)

	# None should apply to PLAYER_PERFORMANCE + DRAFT
	var perf_mods := registry.get_modifiers(
		Modifier.Target.PLAYER_PERFORMANCE,
		Modifier.Context.DRAFT
	)
	assert_int(perf_mods.size()).is_equal(0)


func test_registry_evaluate_combines_modifiers() -> void:
	var registry := ModifierRegistry.new()

	# Create a simple test modifier that returns 1.1x
	var test_mod := _TestMultiplierModifier.new(1.1)
	registry.register_global(test_mod)

	# Create another that returns 1.2x
	var test_mod2 := _TestMultiplierModifier.new(1.2)
	registry.register_global(test_mod2)

	var result := registry.evaluate(
		Modifier.Target.TEAM_EVALUATION,
		Modifier.Context.DRAFT,
		{}
	)

	# 1.1 * 1.2 = 1.32
	assert_float(result.multiplier).is_equal_approx(1.32, 0.01)
	assert_int(result.applied.size()).is_equal(2)


func test_registry_apply_modifiers_convenience() -> void:
	var registry := ModifierRegistry.new()
	registry.register_global(_TestMultiplierModifier.new(1.5))

	var final := registry.apply_modifiers(
		100.0,
		Modifier.Target.TEAM_EVALUATION,
		Modifier.Context.DRAFT,
		{}
	)

	assert_float(final).is_equal(150.0)


func test_registry_modifier_priority_ordering() -> void:
	var registry := ModifierRegistry.new()

	# Register out of order
	var high_priority := _TestMultiplierModifier.new(1.1)
	high_priority._priority = 10
	var low_priority := _TestMultiplierModifier.new(1.2)
	low_priority._priority = 100

	registry.register_global(low_priority)
	registry.register_global(high_priority)

	var mods := registry.get_global_modifiers()
	assert_int(mods[0].get_priority()).is_equal(10)  # High priority first
	assert_int(mods[1].get_priority()).is_equal(100)


func test_registry_disable_modifier() -> void:
	var registry := ModifierRegistry.new()
	var mod := _TestMultiplierModifier.new(2.0)
	registry.register_global(mod)

	registry.disable_modifier("test_multiplier")

	var result := registry.evaluate(
		Modifier.Target.TEAM_EVALUATION,
		Modifier.Context.DRAFT,
		{}
	)

	# Disabled modifier should not apply
	assert_float(result.multiplier).is_equal(1.0)
	assert_int(result.skipped.size()).is_equal(1)


func test_registry_tick_expires_temporary_modifiers() -> void:
	var registry := ModifierRegistry.new()
	var injury := InjuryModifier.new(
		InjuryModifier.Severity.MINOR,
		InjuryModifier.BodyPart.LEG,
		3  # 3 days
	)
	registry.attach("player", "player_789", injury)

	# Tick 2 days - should still be active
	registry.tick(2)
	var mods := registry.get_entity_modifiers("player", "player_789")
	assert_int(mods.size()).is_equal(1)

	# Tick 2 more days - should expire and be removed
	registry.tick(2)
	mods = registry.get_entity_modifiers("player", "player_789")
	assert_int(mods.size()).is_equal(0)


# =============================================================================
# SCHEME FIT MODIFIER TESTS
# =============================================================================

func test_scheme_fit_modifier_not_applicable_to_special_teams() -> void:
	var mod := SchemeFitModifier.new()

	var kicker_context := {"position": "K"}
	assert_bool(mod.is_applicable(kicker_context)).is_false()

	var punter_context := {"position": "P"}
	assert_bool(mod.is_applicable(punter_context)).is_false()


func test_scheme_fit_modifier_applicable_to_regular_positions() -> void:
	var mod := SchemeFitModifier.new()

	assert_bool(mod.is_applicable({"position": "QB"})).is_true()
	assert_bool(mod.is_applicable({"position": "EDGE"})).is_true()
	assert_bool(mod.is_applicable({"position": "WR"})).is_true()


# =============================================================================
# COACH MINDSET MODIFIER TESTS
# =============================================================================

func test_coach_mindset_not_applicable_without_specialty() -> void:
	var mod := CoachMindsetModifier.new()

	assert_bool(mod.is_applicable({"coach": {}})).is_false()
	assert_bool(mod.is_applicable({"coach": {"specialty_position": ""}})).is_false()


func test_coach_mindset_defensive_coach_boosts_defense() -> void:
	var mod := CoachMindsetModifier.new()

	var context := {
		"position": "EDGE",
		"base_rating": 70.0,
		"phase": "draft",
		"coach": {"specialty_position": "Defense"}
	}

	var result := mod.calculate(context)
	assert_float(result.multiplier).is_greater(1.0)


func test_coach_mindset_defensive_coach_penalizes_offense() -> void:
	var mod := CoachMindsetModifier.new()

	var context := {
		"position": "WR",
		"base_rating": 70.0,
		"phase": "draft",
		"coach": {"specialty_position": "Defense"}
	}

	var result := mod.calculate(context)
	assert_float(result.multiplier).is_less(1.0)


func test_coach_mindset_fa_is_dampened() -> void:
	var mod := CoachMindsetModifier.new()

	var draft_context := {
		"position": "EDGE",
		"base_rating": 70.0,
		"phase": "draft",
		"coach": {"specialty_position": "Defense"}
	}
	var draft_result := mod.calculate(draft_context)

	var fa_context := draft_context.duplicate()
	fa_context["phase"] = "free_agency"
	var fa_result := mod.calculate(fa_context)

	# FA effect should be smaller (closer to 1.0)
	assert_float(abs(fa_result.multiplier - 1.0)).is_less(abs(draft_result.multiplier - 1.0))


# =============================================================================
# POSITION NEED MODIFIER TESTS
# =============================================================================

func test_position_need_blocks_at_cap() -> void:
	var mod := PositionNeedModifier.new()

	var context := {
		"position": "QB",
		"roster": {
			"by_position": {
				"QB": ["qb1", "qb2", "qb3"]  # At cap of 3
			}
		},
		"phase": "draft"
	}

	var result := mod.calculate(context)
	assert_float(result.multiplier).is_equal(0.0)
	assert_bool(result.details.get("blocked", false)).is_true()


func test_position_need_boosts_critical_need() -> void:
	var mod := PositionNeedModifier.new()

	var context := {
		"position": "WR",
		"roster": {
			"by_position": {}  # No WRs
		},
		"phase": "free_agency"  # FA doesn't dampen need
	}

	var result := mod.calculate(context)
	assert_float(result.multiplier).is_greater(1.0)


func test_position_need_penalizes_overstocked() -> void:
	var mod := PositionNeedModifier.new()

	var context := {
		"position": "RB",
		"roster": {
			"by_position": {
				"RB": ["rb1", "rb2", "rb3", "rb4"]  # 4 RBs, above ideal of ~3
			}
		},
		"phase": "free_agency"
	}

	var result := mod.calculate(context)
	assert_float(result.multiplier).is_less(1.0)


# =============================================================================
# INJURY MODIFIER TESTS
# =============================================================================

func test_injury_modifier_affects_relevant_stats() -> void:
	var injury := InjuryModifier.new(
		InjuryModifier.Severity.MODERATE,
		InjuryModifier.BodyPart.HAND,
		14
	)

	# Hand injury should affect catching
	var catching_result := injury.calculate({"stat": "catching"})
	assert_float(catching_result.multiplier).is_less(1.0)

	# Hand injury shouldn't significantly affect speed
	var speed_result := injury.calculate({"stat": "speed"})
	assert_float(speed_result.multiplier).is_equal(1.0)


func test_injury_modifier_severity_scales_penalty() -> void:
	var minor := InjuryModifier.new(
		InjuryModifier.Severity.MINOR,
		InjuryModifier.BodyPart.LEG,
		7
	)
	var severe := InjuryModifier.new(
		InjuryModifier.Severity.SEVERE,
		InjuryModifier.BodyPart.LEG,
		60
	)

	var minor_speed := minor.calculate({"stat": "speed"})
	var severe_speed := severe.calculate({"stat": "speed"})

	# Severe should have larger penalty (smaller multiplier)
	assert_float(severe_speed.multiplier).is_less(minor_speed.multiplier)


func test_injury_modifier_heals_over_time() -> void:
	var injury := InjuryModifier.new(
		InjuryModifier.Severity.MINOR,
		InjuryModifier.BodyPart.ARM,
		5
	)

	assert_bool(injury.is_active()).is_true()

	injury.on_tick(3)
	assert_bool(injury.is_active()).is_true()
	assert_int(injury.get_duration()).is_equal(2)

	injury.on_tick(3)
	assert_bool(injury.is_active()).is_false()


func test_injury_modifier_serialization() -> void:
	var injury := InjuryModifier.new(
		InjuryModifier.Severity.MAJOR,
		InjuryModifier.BodyPart.KNEE,
		30
	)

	var dict := injury.to_dict()
	assert_str(dict.get("type", "")).is_equal("injury")
	assert_int(dict.get("severity", 0)).is_equal(InjuryModifier.Severity.MAJOR)
	assert_int(dict.get("body_part", 0)).is_equal(InjuryModifier.BodyPart.KNEE)


func test_injury_modifier_create_from_config() -> void:
	var config := {
		"severity": "moderate",
		"body_part": "shoulder",
		"duration_days": 21
	}

	var injury := InjuryModifier.create_from_config(config)
	assert_str(injury.get_display_name()).contains("Shoulder")
	assert_int(injury.get_duration()).is_equal(21)


# =============================================================================
# HELPER CLASSES
# =============================================================================

## Test modifier that just returns a fixed multiplier
class _TestMultiplierModifier extends Modifier:
	var _mult: float = 1.0
	var _priority: int = 50

	func _init(mult: float = 1.0) -> void:
		_mult = mult

	func get_id() -> String:
		return "test_multiplier"

	func get_target() -> Target:
		return Target.TEAM_EVALUATION

	func get_contexts() -> Array:
		return [Context.DRAFT, Context.FREE_AGENCY]

	func get_priority() -> int:
		return _priority

	func calculate(context_data: Dictionary) -> ModifierResult:
		return ModifierResult.new(_mult, 0.0, "Test multiplier")
