class_name PanelStyles
## Centralized panel styling system for consistent UI theming.
##
## Provides color palette, spacing constants, and style creation utilities
## for ReactivePanel and ReactivePanelContainer instances.
##
## [b]Usage:[/b]
## [codeblock]
## # Create a style for a variant
## var style = PanelStyles.create_style("primary", 0)
## panel.add_theme_stylebox_override("panel", style)
##
## # Get a color from the palette
## var bg_color = PanelStyles.COLORS["bg_dark"]
##
## # Get standard spacing
## var padding = PanelStyles.SPACING["md"]
## [/codeblock]
##
## [b]Variants:[/b]
## - [b]default:[/b] Standard dark panel (medium background, subtle border)
## - [b]primary:[/b] Primary accent panel (blue tones)
## - [b]secondary:[/b] Secondary accent panel (purple tones)
## - [b]info:[/b] Informational panel (teal tones)
## - [b]warning:[/b] Warning/caution panel (orange tones)
## - [b]success:[/b] Success/positive panel (green tones)
## - [b]error:[/b] Error/danger panel (red tones)
## - [b]nested:[/b] Auto-darkening nested panel (darker = more nested)
## - [b]transparent:[/b] Transparent panel (no background, no border)
##
## [b]Nesting Behavior:[/b]
## The "nested" variant automatically darkens based on nesting depth:
## - Depth 0: [code]bg_medium[/code] (#252530)
## - Depth 1: [code]bg_dark[/code] (#1a1a1f)
## - Depth 2+: [code]bg_darker[/code] (#121215)


# ============================================================================
# COLOR PALETTE
# ============================================================================

## Color palette for consistent theming across all panels.
##
## [b]Background colors:[/b] Dark theme progression from dark to light
## [br][b]Border colors:[/b] Subtle to accent borders
## [br][b]Accent colors:[/b] Semantic colors for variants
const COLORS := {
	# Background progression (darkest to lightest)
	"bg_darker": Color(0.07, 0.07, 0.08),    # #121215 - Deepest nested panels
	"bg_dark": Color(0.10, 0.10, 0.12),      # #1a1a1f - Dark panels
	"bg_medium": Color(0.15, 0.15, 0.18),    # #252530 - Standard panels
	"bg_light": Color(0.20, 0.20, 0.24),     # #33333d - Light panels

	# Border colors
	"border_subtle": Color(0.23, 0.23, 0.28),   # #3a3a45 - Subtle borders
	"border_medium": Color(0.29, 0.29, 0.35),   # #4a4a59 - Medium borders
	"border_accent": Color(0.29, 0.42, 0.60),   # #4a6a9a - Accent borders

	# Semantic colors
	"primary": Color(0.16, 0.29, 0.48),      # #2a4a7a - Primary blue
	"primary_border": Color(0.20, 0.40, 0.70),  # #3366b3 - Primary border

	"secondary": Color(0.29, 0.23, 0.42),    # #4a3a6a - Secondary purple
	"secondary_border": Color(0.45, 0.35, 0.65),  # #7359a6 - Secondary border

	"info": Color(0.16, 0.35, 0.42),         # #2a5a6a - Info teal
	"info_border": Color(0.25, 0.55, 0.65),  # #408ca6 - Info border

	"warning": Color(0.48, 0.35, 0.16),      # #7a5a2a - Warning orange
	"warning_border": Color(0.75, 0.55, 0.25),  # #bf8c40 - Warning border

	"success": Color(0.16, 0.38, 0.19),      # #2a6030 - Success green
	"success_border": Color(0.25, 0.60, 0.30),  # #40994d - Success border

	"error": Color(0.48, 0.12, 0.12),        # #7a1f1f - Error red
	"error_border": Color(0.75, 0.20, 0.20),    # #bf3333 - Error border
}


# ============================================================================
# SPACING CONSTANTS
# ============================================================================

## Standard spacing values in pixels for consistent layout.
##
## Use these constants for margins, padding, and gaps:
## [codeblock]
## style.set_content_margin_all(PanelStyles.SPACING["md"])
## vbox.add_theme_constant_override("separation", PanelStyles.SPACING["sm"])
## [/codeblock]
const SPACING := {
	"xs": 4,   # Extra small: tight spacing
	"sm": 8,   # Small: compact spacing
	"md": 12,  # Medium: standard spacing
	"lg": 16,  # Large: generous spacing
	"xl": 24,  # Extra large: wide spacing
}


# ============================================================================
# CORNER RADIUS CONSTANTS
# ============================================================================

## Standard corner radius values for consistent panel rounding.
const CORNER_RADIUS := {
	"none": 0,      # No rounding (sharp corners)
	"subtle": 2,    # Subtle rounding
	"small": 4,     # Small rounding (default)
	"medium": 6,    # Medium rounding
	"large": 8,     # Large rounding
	"xl": 12,       # Extra large rounding
}


# ============================================================================
# STYLE CREATION
# ============================================================================

## Create a StyleBoxFlat for the specified variant and nesting depth.
##
## [param variant] The style variant: "default", "primary", "secondary", "info",
##                 "warning", "success", "error", "nested", "transparent"
## [param nesting_depth] How deeply nested this panel is (0 = top-level)
## [param custom_config] Optional dictionary to override specific properties:
##                       - [code]padding[/code]: int - Content margin (all sides)
##                       - [code]corner_radius[/code]: int - Corner radius (all corners)
##                       - [code]border_width[/code]: int - Border width (all sides)
##                       - [code]bg_color[/code]: Color - Background color override
##                       - [code]border_color[/code]: Color - Border color override
##
## [b]Returns:[/b] A configured StyleBoxFlat ready to apply to a panel.
##
## [b]Example:[/b]
## [codeblock]
## # Standard primary style
## var style = PanelStyles.create_style("primary", 0)
##
## # Nested panel with auto-darkening
## var nested_style = PanelStyles.create_style("nested", 2)
##
## # Custom configuration
## var custom_style = PanelStyles.create_style("default", 0, {
##     "padding": 16,
##     "corner_radius": 8,
##     "bg_color": Color(0.2, 0.2, 0.25)
## })
## [/codeblock]
static func create_style(
	variant: String,
	nesting_depth: int = 0,
	custom_config: Dictionary = {}
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	# Apply variant-specific styling
	_apply_variant_style(style, variant, nesting_depth)

	# Apply custom overrides
	if custom_config.has("bg_color"):
		style.bg_color = custom_config["bg_color"]

	if custom_config.has("border_color"):
		style.border_color = custom_config["border_color"]

	if custom_config.has("padding"):
		style.set_content_margin_all(custom_config["padding"])

	if custom_config.has("corner_radius"):
		style.set_corner_radius_all(custom_config["corner_radius"])

	if custom_config.has("border_width"):
		style.set_border_width_all(custom_config["border_width"])

	return style


## Apply variant-specific style configuration.
##
## [param style] The StyleBoxFlat to configure
## [param variant] The variant name
## [param nesting_depth] The nesting depth for nested variant
static func _apply_variant_style(
	style: StyleBoxFlat,
	variant: String,
	nesting_depth: int
) -> void:
	match variant:
		"default":
			_apply_default_style(style)

		"primary":
			_apply_accent_style(style, "primary")

		"secondary":
			_apply_accent_style(style, "secondary")

		"info":
			_apply_accent_style(style, "info")

		"warning":
			_apply_accent_style(style, "warning")

		"success":
			_apply_accent_style(style, "success")

		"error":
			_apply_accent_style(style, "error")

		"nested":
			_apply_nested_style(style, nesting_depth)

		"transparent":
			_apply_transparent_style(style)

		_:
			push_warning("PanelStyles: Unknown variant '%s', using default" % variant)
			_apply_default_style(style)


## Apply default panel style.
static func _apply_default_style(style: StyleBoxFlat) -> void:
	style.bg_color = COLORS["bg_medium"]
	style.set_border_width_all(1)
	style.border_color = COLORS["border_subtle"]
	style.set_corner_radius_all(CORNER_RADIUS["small"])
	style.set_content_margin_all(SPACING["md"])


## Apply accent variant style (primary, secondary, info, warning, success, error).
static func _apply_accent_style(style: StyleBoxFlat, accent_name: String) -> void:
	style.bg_color = COLORS[accent_name]
	style.set_border_width_all(1)
	style.border_color = COLORS[accent_name + "_border"]
	style.set_corner_radius_all(CORNER_RADIUS["small"])
	style.set_content_margin_all(SPACING["md"])


## Apply nested panel style with depth-based darkening.
static func _apply_nested_style(style: StyleBoxFlat, depth: int) -> void:
	# Background darkens with depth
	var bg_color: Color
	match depth:
		0:
			bg_color = COLORS["bg_medium"]
		1:
			bg_color = COLORS["bg_dark"]
		_:
			bg_color = COLORS["bg_darker"]

	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = COLORS["border_subtle"]
	style.set_corner_radius_all(CORNER_RADIUS["small"])
	style.set_content_margin_all(SPACING["md"])


## Apply transparent style (no background, no border).
static func _apply_transparent_style(style: StyleBoxFlat) -> void:
	style.bg_color = Color(0, 0, 0, 0)  # Transparent
	style.set_border_width_all(0)  # No border
	style.set_corner_radius_all(CORNER_RADIUS["small"])
	style.set_content_margin_all(SPACING["md"])


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Get a color from the palette by name.
##
## [param color_name] The color key (e.g., "bg_dark", "primary", "border_subtle")
## [param fallback] Optional fallback color if key not found
##
## [b]Returns:[/b] The color, or fallback if not found.
static func get_color(color_name: String, fallback: Color = Color.WHITE) -> Color:
	if COLORS.has(color_name):
		return COLORS[color_name]

	push_warning("PanelStyles: Color '%s' not found, using fallback" % color_name)
	return fallback


## Get a spacing value by name.
##
## [param spacing_name] The spacing key (e.g., "sm", "md", "lg")
## [param fallback] Optional fallback value if key not found
##
## [b]Returns:[/b] The spacing value in pixels.
static func get_spacing(spacing_name: String, fallback: int = 8) -> int:
	if SPACING.has(spacing_name):
		return SPACING[spacing_name]

	push_warning("PanelStyles: Spacing '%s' not found, using fallback" % spacing_name)
	return fallback


## Get a corner radius value by name.
##
## [param radius_name] The radius key (e.g., "small", "medium", "large")
## [param fallback] Optional fallback value if key not found
##
## [b]Returns:[/b] The corner radius in pixels.
static func get_corner_radius(radius_name: String, fallback: int = 4) -> int:
	if CORNER_RADIUS.has(radius_name):
		return CORNER_RADIUS[radius_name]

	push_warning("PanelStyles: Corner radius '%s' not found, using fallback" % radius_name)
	return fallback
