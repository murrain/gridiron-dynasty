extends GdUnitTestSuite

## Unit tests for ThemeManager autoload
##
## Tests theme switching, color retrieval, and signal emission.


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_test() -> void:
	# Reset to dark theme before each test
	# Check if ThemeManager autoload is valid before using
	if is_instance_valid(ThemeManager):
		ThemeManager.set_theme(ThemeManager.THEME_DARK)


# ============================================================================
# BASIC FUNCTIONALITY TESTS
# ============================================================================

func test_default_theme_is_dark() -> void:
	assert_bool(ThemeManager.is_dark_theme()).is_true()
	assert_bool(ThemeManager.is_light_theme()).is_false()


func test_can_switch_to_light_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	assert_bool(ThemeManager.is_light_theme()).is_true()
	assert_bool(ThemeManager.is_dark_theme()).is_false()
	assert_str(ThemeManager.active_theme).is_equal(ThemeManager.THEME_LIGHT)


func test_can_switch_back_to_dark_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	assert_bool(ThemeManager.is_dark_theme()).is_true()
	assert_bool(ThemeManager.is_light_theme()).is_false()
	assert_str(ThemeManager.active_theme).is_equal(ThemeManager.THEME_DARK)


func test_toggle_theme_switches_from_dark_to_light() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	ThemeManager.toggle_theme()

	assert_str(ThemeManager.active_theme).is_equal(ThemeManager.THEME_LIGHT)


func test_toggle_theme_switches_from_light_to_dark() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	ThemeManager.toggle_theme()

	assert_str(ThemeManager.active_theme).is_equal(ThemeManager.THEME_DARK)


func test_invalid_theme_name_shows_error() -> void:
	# Test that invalid theme keeps current theme
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	ThemeManager.set_theme("invalid_theme")

	# Should stay on dark theme
	assert_str(ThemeManager.active_theme).is_equal(ThemeManager.THEME_DARK)


# ============================================================================
# COLOR RETRIEVAL TESTS
# ============================================================================

func test_get_color_returns_valid_color_from_dark_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var bg_dark := ThemeManager.get_color("bg_dark")

	# Verify it's a Color type (TYPE_COLOR = 20 in Godot)
	assert_int(typeof(bg_dark)).is_equal(TYPE_COLOR)
	assert_float(bg_dark.r).is_not_equal(1.0)  # Should not be fallback (magenta)


func test_get_color_returns_valid_color_from_light_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	var bg_dark := ThemeManager.get_color("bg_dark")

	# Verify it's a Color type
	assert_int(typeof(bg_dark)).is_equal(TYPE_COLOR)
	assert_float(bg_dark.r).is_not_equal(1.0)  # Should not be fallback


func test_get_color_returns_different_colors_per_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var dark_bg := ThemeManager.get_color("bg_dark")

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	var light_bg := ThemeManager.get_color("bg_dark")

	# Dark and light themes should have different values for bg_dark
	assert_bool(dark_bg == light_bg).is_false()


func test_get_color_returns_fallback_for_missing_key() -> void:
	var fallback := Color.YELLOW
	var result := ThemeManager.get_color("nonexistent_key", fallback)

	# Colors are value types, compare directly
	assert_bool(result == fallback).is_true()


func test_get_all_colors_returns_dict() -> void:
	var colors := ThemeManager.get_all_colors()

	# Verify it's a Dictionary type
	assert_int(typeof(colors)).is_equal(TYPE_DICTIONARY)
	assert_int(colors.size()).is_greater(0)


func test_get_all_colors_contains_expected_keys() -> void:
	var colors := ThemeManager.get_all_colors()

	# Check for some expected color keys
	assert_bool(colors.has("bg_dark")).is_true()
	assert_bool(colors.has("bg_medium")).is_true()
	assert_bool(colors.has("primary")).is_true()
	assert_bool(colors.has("border_subtle")).is_true()


func test_dark_theme_has_all_required_colors() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var colors := ThemeManager.get_all_colors()

	# Background colors
	assert_bool(colors.has("bg_darker")).is_true()
	assert_bool(colors.has("bg_dark")).is_true()
	assert_bool(colors.has("bg_medium")).is_true()
	assert_bool(colors.has("bg_light")).is_true()

	# Border colors
	assert_bool(colors.has("border_subtle")).is_true()
	assert_bool(colors.has("border_medium")).is_true()
	assert_bool(colors.has("border_accent")).is_true()

	# Semantic colors
	assert_bool(colors.has("primary")).is_true()
	assert_bool(colors.has("secondary")).is_true()
	assert_bool(colors.has("info")).is_true()
	assert_bool(colors.has("warning")).is_true()
	assert_bool(colors.has("success")).is_true()
	assert_bool(colors.has("error")).is_true()

	# Rating colors
	assert_bool(colors.has("rating_elite")).is_true()
	assert_bool(colors.has("rating_poor")).is_true()


func test_light_theme_has_all_required_colors() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	var colors := ThemeManager.get_all_colors()

	# Same structure as dark theme
	assert_bool(colors.has("bg_darker")).is_true()
	assert_bool(colors.has("bg_dark")).is_true()
	assert_bool(colors.has("primary")).is_true()
	assert_bool(colors.has("rating_elite")).is_true()


# ============================================================================
# SIGNAL TESTS
# ============================================================================

func test_theme_changed_signal_emits_on_switch() -> void:
	# Register ThemeManager for signal monitoring - use false to prevent auto-free of autoload
	monitor_signals(ThemeManager, false)

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	# Use GdUnit4's assert_signal API - verify signal was emitted with expected arg
	await assert_signal(ThemeManager).wait_until(100).is_emitted("theme_changed", [ThemeManager.THEME_LIGHT])


func test_theme_changed_signal_includes_theme_name() -> void:
	# Register ThemeManager for signal monitoring
	monitor_signals(ThemeManager, false)

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	# Verify signal was emitted with the theme name
	await assert_signal(ThemeManager).wait_until(100).is_emitted("theme_changed", [ThemeManager.THEME_LIGHT])


func test_theme_changed_signal_does_not_emit_if_same_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	# Register ThemeManager for signal monitoring after setting initial theme
	monitor_signals(ThemeManager, false)

	# Try to set to dark again (already active)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	# Should not emit signal - wait a short time to verify no emission
	await assert_signal(ThemeManager).wait_until(50).is_not_emitted("theme_changed")


func test_toggle_emits_theme_changed_signal() -> void:
	# Ensure we start in a known state
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	# Register ThemeManager for signal monitoring before toggle
	monitor_signals(ThemeManager, false)

	# Toggle theme (should switch to light)
	ThemeManager.toggle_theme()

	# Verify theme_changed was emitted (with light theme argument)
	await assert_signal(ThemeManager).wait_until(200).is_emitted("theme_changed", [ThemeManager.THEME_LIGHT])


# ============================================================================
# INTEGRATION WITH PANELSTYLES
# ============================================================================

func test_panel_styles_can_get_colors_from_theme_manager() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var color := PanelStyles.get_color("bg_dark")

	# Verify it's a Color type
	assert_int(typeof(color)).is_equal(TYPE_COLOR)
	assert_float(color.r).is_not_equal(1.0)  # Not fallback


func test_panel_styles_colors_change_with_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var dark_color := PanelStyles.get_color("bg_dark")

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	var light_color := PanelStyles.get_color("bg_dark")

	# Colors should be different
	assert_bool(dark_color == light_color).is_false()


# ============================================================================
# INTEGRATION WITH STATQUERIES
# ============================================================================

func test_stat_queries_can_get_rating_colors() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var elite_color_hex := StatQueries.get_stat_color_hex(95.0)
	var poor_color_hex := StatQueries.get_stat_color_hex(30.0)

	# Should return valid hex colors
	assert_str(elite_color_hex).starts_with("#")
	assert_str(poor_color_hex).starts_with("#")
	assert_bool(elite_color_hex == poor_color_hex).is_false()


func test_stat_queries_colors_consistent_across_themes() -> void:
	# Note: Rating colors are intentionally the SAME in both themes
	# because they need high contrast for readability
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var dark_elite := StatQueries.get_stat_color_hex(95.0)

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	var light_elite := StatQueries.get_stat_color_hex(95.0)

	# Rating colors should be consistent across themes for visual stability
	assert_bool(dark_elite == light_elite).is_true()
