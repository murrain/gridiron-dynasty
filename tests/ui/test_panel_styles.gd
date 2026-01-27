extends "res://tests/GutTest.gd"
## Unit tests for the ReactivePanel style system.
##
## Tests PanelStyles utility class, ReactivePanel styling,
## ReactivePanelContainer styling, and nesting behavior.


# ============================================================================
# PANELSTYLES TESTS
# ============================================================================

func test_panel_styles_colors_defined() -> void:
	# Verify all required colors are defined
	assert_true(PanelStyles.COLORS.has("bg_darker"))
	assert_true(PanelStyles.COLORS.has("bg_dark"))
	assert_true(PanelStyles.COLORS.has("bg_medium"))
	assert_true(PanelStyles.COLORS.has("bg_light"))
	assert_true(PanelStyles.COLORS.has("primary"))
	assert_true(PanelStyles.COLORS.has("secondary"))
	assert_true(PanelStyles.COLORS.has("info"))
	assert_true(PanelStyles.COLORS.has("warning"))
	assert_true(PanelStyles.COLORS.has("success"))
	assert_true(PanelStyles.COLORS.has("error"))


func test_panel_styles_spacing_defined() -> void:
	# Verify all spacing constants are defined
	assert_true(PanelStyles.SPACING.has("xs"))
	assert_true(PanelStyles.SPACING.has("sm"))
	assert_true(PanelStyles.SPACING.has("md"))
	assert_true(PanelStyles.SPACING.has("lg"))
	assert_true(PanelStyles.SPACING.has("xl"))

	# Verify values are in correct order
	assert_true(PanelStyles.SPACING["xs"] < PanelStyles.SPACING["sm"])
	assert_true(PanelStyles.SPACING["sm"] < PanelStyles.SPACING["md"])
	assert_true(PanelStyles.SPACING["md"] < PanelStyles.SPACING["lg"])
	assert_true(PanelStyles.SPACING["lg"] < PanelStyles.SPACING["xl"])


func test_panel_styles_create_default_style() -> void:
	var style := PanelStyles.create_style("default", 0)

	assert_not_null(style)
	assert_true(style is StyleBoxFlat)
	# Use get_color to get theme-aware color (COLORS is deprecated)
	assert_eq(style.bg_color, PanelStyles.get_color("bg_medium"))


func test_panel_styles_create_primary_style() -> void:
	var style := PanelStyles.create_style("primary", 0)

	assert_not_null(style)
	# Use get_color to get theme-aware colors (COLORS is deprecated)
	assert_eq(style.bg_color, PanelStyles.get_color("primary"))
	assert_eq(style.border_color, PanelStyles.get_color("primary_border"))


func test_panel_styles_create_nested_style_depth_0() -> void:
	var style := PanelStyles.create_style("nested", 0)

	assert_not_null(style)
	# Use get_color to get theme-aware colors (COLORS is deprecated)
	assert_eq(style.bg_color, PanelStyles.get_color("bg_medium"))


func test_panel_styles_create_nested_style_depth_1() -> void:
	var style := PanelStyles.create_style("nested", 1)

	assert_not_null(style)
	# Use get_color to get theme-aware colors (COLORS is deprecated)
	assert_eq(style.bg_color, PanelStyles.get_color("bg_dark"))


func test_panel_styles_create_nested_style_depth_2() -> void:
	var style := PanelStyles.create_style("nested", 2)

	assert_not_null(style)
	# Use get_color to get theme-aware colors (COLORS is deprecated)
	assert_eq(style.bg_color, PanelStyles.get_color("bg_darker"))


func test_panel_styles_create_transparent_style() -> void:
	var style := PanelStyles.create_style("transparent", 0)

	assert_not_null(style)
	assert_eq(style.bg_color, Color(0, 0, 0, 0))  # Fully transparent


func test_panel_styles_custom_config() -> void:
	var custom_color := Color(1, 0, 0)  # Red
	var style := PanelStyles.create_style("default", 0, {
		"bg_color": custom_color,
		"padding": 16,
		"corner_radius": 10
	})

	assert_not_null(style)
	assert_eq(style.bg_color, custom_color)


func test_panel_styles_get_color() -> void:
	# get_color returns the current theme's color, verify it returns a valid Color
	var color := PanelStyles.get_color("bg_dark")
	# Verify it's a Color type and matches the theme's value
	assert_true(color is Color)
	assert_eq(color, ThemeManager.get_color("bg_dark"))


func test_panel_styles_get_color_fallback() -> void:
	var fallback := Color.RED
	var color := PanelStyles.get_color("nonexistent_color", fallback)
	assert_eq(color, fallback)


func test_panel_styles_get_spacing() -> void:
	var spacing := PanelStyles.get_spacing("md")
	assert_eq(spacing, 12)


func test_panel_styles_get_spacing_fallback() -> void:
	var fallback := 99
	var spacing := PanelStyles.get_spacing("nonexistent_spacing", fallback)
	assert_eq(spacing, fallback)


# ============================================================================
# REACTIVEPANELCONTAINER TESTS
# ============================================================================

func test_reactive_panel_container_default_style_variant() -> void:
	var panel := ReactivePanelContainer.new()
	add_child_autofree(panel)

	assert_eq(panel.style_variant, "default")


func test_reactive_panel_container_auto_apply_style_enabled() -> void:
	var panel := ReactivePanelContainer.new()
	add_child_autofree(panel)

	assert_true(panel.auto_apply_style)


func test_reactive_panel_container_auto_indent_enabled() -> void:
	var panel := ReactivePanelContainer.new()
	add_child_autofree(panel)

	assert_true(panel.auto_indent_nested)


func test_reactive_panel_container_nest_indent_default() -> void:
	var panel := ReactivePanelContainer.new()
	add_child_autofree(panel)

	assert_eq(panel.nest_indent, 8)


func test_reactive_panel_container_set_style_variant() -> void:
	var panel := ReactivePanelContainer.new()
	panel.auto_apply_style = false  # Prevent auto-apply
	add_child_autofree(panel)

	panel.set_style_variant("primary")

	assert_eq(panel.style_variant, "primary")


func test_reactive_panel_container_nesting_depth_flat() -> void:
	var parent := Control.new()
	add_child_autofree(parent)

	var panel := ReactivePanelContainer.new()
	parent.add_child(panel)

	await get_tree().process_frame

	assert_eq(panel._get_nesting_depth(), 0)


func test_reactive_panel_container_nesting_depth_1() -> void:
	var parent := ReactivePanelContainer.new()
	add_child_autofree(parent)

	var child := ReactivePanelContainer.new()
	parent.add_child(child)

	await get_tree().process_frame

	assert_eq(child._get_nesting_depth(), 1)


func test_reactive_panel_container_nesting_depth_2() -> void:
	var parent := ReactivePanelContainer.new()
	add_child_autofree(parent)

	var child := ReactivePanelContainer.new()
	parent.add_child(child)

	var grandchild := ReactivePanelContainer.new()
	child.add_child(grandchild)

	await get_tree().process_frame

	assert_eq(grandchild._get_nesting_depth(), 2)


func test_reactive_panel_container_is_nested_false() -> void:
	var parent := Control.new()
	add_child_autofree(parent)

	var panel := ReactivePanelContainer.new()
	parent.add_child(panel)

	await get_tree().process_frame

	assert_false(panel._is_nested())


func test_reactive_panel_container_is_nested_true() -> void:
	var parent := ReactivePanelContainer.new()
	add_child_autofree(parent)

	var child := ReactivePanelContainer.new()
	parent.add_child(child)

	await get_tree().process_frame

	assert_true(child._is_nested())


func test_reactive_panel_container_mixed_nesting_reactive_panel() -> void:
	# Child can detect ReactivePanel parent
	var parent := ReactivePanel.new()
	add_child_autofree(parent)

	var child := ReactivePanelContainer.new()
	parent.add_child(child)

	await get_tree().process_frame

	assert_true(child._is_nested())
	assert_eq(child._get_nesting_depth(), 1)


# ============================================================================
# REACTIVEPANEL TESTS
# ============================================================================

func test_reactive_panel_default_style_variant() -> void:
	var panel := ReactivePanel.new()
	add_child_autofree(panel)

	assert_eq(panel.style_variant, "default")


func test_reactive_panel_nesting_depth() -> void:
	var parent := ReactivePanel.new()
	add_child_autofree(parent)

	var child := ReactivePanel.new()
	parent.add_child(child)

	await get_tree().process_frame

	assert_eq(child._get_nesting_depth(), 1)


func test_reactive_panel_mixed_nesting_reactive_panel_container() -> void:
	# Child can detect ReactivePanelContainer parent
	var parent := ReactivePanelContainer.new()
	add_child_autofree(parent)

	var child := ReactivePanel.new()
	parent.add_child(child)

	await get_tree().process_frame

	assert_true(child._is_nested())
	assert_eq(child._get_nesting_depth(), 1)


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_all_variants_create_valid_styles() -> void:
	var variants := ["default", "primary", "secondary", "info", "warning", "success", "error", "nested", "transparent"]

	for variant in variants:
		var style := PanelStyles.create_style(variant, 0)
		assert_not_null(style, "Variant '%s' should create a valid style" % variant)
		assert_true(style is StyleBoxFlat, "Variant '%s' should be StyleBoxFlat" % variant)


func test_nested_variant_darkens_with_depth() -> void:
	var depth_0 := PanelStyles.create_style("nested", 0)
	var depth_1 := PanelStyles.create_style("nested", 1)
	var depth_2 := PanelStyles.create_style("nested", 2)

	# Each depth should be darker (lower lightness)
	var color_0 := depth_0.bg_color
	var color_1 := depth_1.bg_color
	var color_2 := depth_2.bg_color

	# Verify depth 1 is darker than depth 0
	assert_true(color_1.v < color_0.v, "Depth 1 should be darker than depth 0")

	# Verify depth 2 is darker than depth 1
	assert_true(color_2.v < color_1.v, "Depth 2 should be darker than depth 1")


func test_panel_applies_style_on_ready() -> void:
	var panel := ReactivePanelContainer.new()
	panel.style_variant = "primary"
	panel.auto_apply_style = true
	add_child_autofree(panel)

	await get_tree().process_frame

	# Verify the theme override was applied
	var has_override := panel.has_theme_stylebox_override("panel")
	assert_true(has_override, "Panel should have theme stylebox override after ready")


func test_panel_does_not_apply_style_when_disabled() -> void:
	var panel := ReactivePanelContainer.new()
	panel.style_variant = "primary"
	panel.auto_apply_style = false
	add_child_autofree(panel)

	await get_tree().process_frame

	# Verify no theme override was applied
	var has_override := panel.has_theme_stylebox_override("panel")
	assert_false(has_override, "Panel should not have theme override when auto_apply_style is false")
