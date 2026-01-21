extends GdUnitTestSuite

## Unit tests for ThemeManager autoload
##
## Tests theme switching, color retrieval, and signal emission.


# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

func before_test() -> void:
	# Reset to dark theme before each test
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
	var monitor := monitor_signals(ThemeManager)

	ThemeManager.set_theme("invalid_theme")

	# Should stay on dark theme
	assert_str(ThemeManager.active_theme).is_equal(ThemeManager.THEME_DARK)
	# Should not emit signal for invalid theme
	assert_int(monitor.signal_count(ThemeManager.theme_changed)).is_equal(0)


# ============================================================================
# COLOR RETRIEVAL TESTS
# ============================================================================

func test_get_color_returns_valid_color_from_dark_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var bg_dark := ThemeManager.get_color("bg_dark")

	assert_object(bg_dark).is_instanceof(Color)
	assert_float(bg_dark.r).is_not_equal(1.0)  # Should not be fallback (magenta)


func test_get_color_returns_valid_color_from_light_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	var bg_dark := ThemeManager.get_color("bg_dark")

	assert_object(bg_dark).is_instanceof(Color)
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

	assert_object(result).is_equal(fallback)


func test_get_all_colors_returns_dict() -> void:
	var colors := ThemeManager.get_all_colors()

	assert_object(colors).is_instanceof(Dictionary)
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
	var monitor := monitor_signals(ThemeManager)

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	assert_int(monitor.signal_count(ThemeManager.theme_changed)).is_equal(1)


func test_theme_changed_signal_includes_theme_name() -> void:
	var monitor := monitor_signals(ThemeManager)

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)

	assert_array(monitor.get_signal_emissions(ThemeManager.theme_changed)) \
		.contains([ThemeManager.THEME_LIGHT])


func test_theme_changed_signal_does_not_emit_if_same_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var monitor := monitor_signals(ThemeManager)

	# Try to set to dark again (already active)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	# Should not emit signal
	assert_int(monitor.signal_count(ThemeManager.theme_changed)).is_equal(0)


func test_toggle_emits_theme_changed_signal() -> void:
	var monitor := monitor_signals(ThemeManager)

	ThemeManager.toggle_theme()

	assert_int(monitor.signal_count(ThemeManager.theme_changed)).is_equal(1)


# ============================================================================
# INTEGRATION WITH PANELSTYLES
# ============================================================================

func test_panel_styles_can_get_colors_from_theme_manager() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)

	var color := PanelStyles.get_color("bg_dark")

	assert_object(color).is_instanceof(Color)
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


func test_stat_queries_colors_change_with_theme() -> void:
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var dark_elite := StatQueries.get_stat_color_hex(95.0)

	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	var light_elite := StatQueries.get_stat_color_hex(95.0)

	# Elite colors should differ between themes
	assert_bool(dark_elite == light_elite).is_false()
