extends Node
## Global theme manager for consistent UI theming across the application.
##
## Manages color palettes for dark and light themes, provides theme switching,
## and emits signals when themes change so UI can react.
##
## [b]Usage:[/b]
## [codeblock]
## # Get a color from the active theme
## var bg_color = ThemeManager.get_color("bg_dark")
##
## # Switch themes
## ThemeManager.set_theme("light")
##
## # React to theme changes
## ThemeManager.theme_changed.connect(_on_theme_changed)
## [/codeblock]

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when the active theme changes.
## [param theme_name] The name of the new theme ("dark" or "light")
signal theme_changed(theme_name: String)


# ============================================================================
# CONSTANTS
# ============================================================================

## Available theme names
const THEME_DARK := "dark"
const THEME_LIGHT := "light"

## Default theme at startup
const DEFAULT_THEME := THEME_DARK


# ============================================================================
# STATE
# ============================================================================

## Currently active theme name
var active_theme: String = DEFAULT_THEME


# ============================================================================
# THEME DEFINITIONS
# ============================================================================

## Dark theme color palette
const DARK_THEME := {
	# Background progression (darkest to lightest)
	"bg_darker": Color(0.07, 0.07, 0.08),    # #121215 - Deepest nested panels
	"bg_dark": Color(0.10, 0.10, 0.12),      # #1a1a1f - Dark panels
	"bg_medium": Color(0.15, 0.15, 0.18),    # #252530 - Standard panels
	"bg_light": Color(0.20, 0.20, 0.24),     # #33333d - Light panels
	"bg_lighter": Color(0.25, 0.25, 0.30),   # #404050 - Lighter panels

	# Border colors
	"border_subtle": Color(0.23, 0.23, 0.28),   # #3a3a45 - Subtle borders
	"border_medium": Color(0.29, 0.29, 0.35),   # #4a4a59 - Medium borders
	"border_accent": Color(0.29, 0.42, 0.60),   # #4a6a9a - Accent borders

	# Text colors
	"text_primary": Color(0.90, 0.90, 0.92),    # #e6e6eb - Primary text
	"text_secondary": Color(0.70, 0.70, 0.75),  # #b3b3bf - Secondary text
	"text_disabled": Color(0.45, 0.45, 0.50),   # #73738c - Disabled text

	# Semantic colors
	"primary": Color(0.16, 0.29, 0.48),         # #2a4a7a - Primary blue
	"primary_border": Color(0.20, 0.40, 0.70),  # #3366b3 - Primary border
	"primary_text": Color(0.40, 0.65, 1.00),    # #66a6ff - Primary text/icons

	"secondary": Color(0.29, 0.23, 0.42),       # #4a3a6a - Secondary purple
	"secondary_border": Color(0.45, 0.35, 0.65), # #7359a6 - Secondary border
	"secondary_text": Color(0.65, 0.50, 0.95),  # #a680f2 - Secondary text/icons

	"info": Color(0.16, 0.35, 0.42),            # #2a5a6a - Info teal
	"info_border": Color(0.25, 0.55, 0.65),     # #408ca6 - Info border
	"info_text": Color(0.40, 0.85, 1.00),       # #66d9ff - Info text/icons

	"warning": Color(0.48, 0.35, 0.16),         # #7a5a2a - Warning orange
	"warning_border": Color(0.75, 0.55, 0.25),  # #bf8c40 - Warning border
	"warning_text": Color(1.00, 0.75, 0.40),    # #ffbf66 - Warning text/icons

	"success": Color(0.16, 0.38, 0.19),         # #2a6030 - Success green
	"success_border": Color(0.25, 0.60, 0.30),  # #40994d - Success border
	"success_text": Color(0.40, 0.95, 0.50),    # #66f280 - Success text/icons

	"error": Color(0.48, 0.12, 0.12),           # #7a1f1f - Error red
	"error_border": Color(0.75, 0.20, 0.20),    # #bf3333 - Error border
	"error_text": Color(1.00, 0.40, 0.40),      # #ff6666 - Error text/icons

	# Rating/stat colors (green to red scale)
	"rating_elite": Color(0.00, 1.00, 0.00),    # #00ff00 - 90+ elite
	"rating_great": Color(0.40, 1.00, 0.40),    # #66ff66 - 80-89 great
	"rating_good": Color(0.60, 1.00, 0.60),     # #99ff99 - 70-79 good
	"rating_average": Color(1.00, 1.00, 0.00),  # #ffff00 - 60-69 average
	"rating_below_avg": Color(1.00, 0.67, 0.00), # #ffaa00 - 50-59 below avg
	"rating_poor": Color(1.00, 0.00, 0.00),     # #ff0000 - <50 poor
}

## Light theme color palette
const LIGHT_THEME := {
	# Background progression (lightest to darker)
	"bg_darker": Color(0.85, 0.85, 0.88),    # #d9d9e0 - Deepest nested panels
	"bg_dark": Color(0.90, 0.90, 0.92),      # #e6e6eb - Dark panels
	"bg_medium": Color(0.95, 0.95, 0.96),    # #f2f2f5 - Standard panels
	"bg_light": Color(0.98, 0.98, 0.99),     # #fafafc - Light panels
	"bg_lighter": Color(1.00, 1.00, 1.00),   # #ffffff - Lighter panels

	# Border colors
	"border_subtle": Color(0.80, 0.80, 0.83),   # #ccccD4 - Subtle borders
	"border_medium": Color(0.70, 0.70, 0.75),   # #b3b3bf - Medium borders
	"border_accent": Color(0.30, 0.50, 0.80),   # #4d80cc - Accent borders

	# Text colors
	"text_primary": Color(0.10, 0.10, 0.12),    # #1a1a1f - Primary text
	"text_secondary": Color(0.30, 0.30, 0.35),  # #4d4d59 - Secondary text
	"text_disabled": Color(0.55, 0.55, 0.60),   # #8c8c99 - Disabled text

	# Semantic colors (lighter versions for light theme)
	"primary": Color(0.85, 0.90, 0.98),         # #d9e6fa - Primary blue bg
	"primary_border": Color(0.30, 0.50, 0.85),  # #4d80d9 - Primary border
	"primary_text": Color(0.15, 0.35, 0.70),    # #2659b3 - Primary text/icons

	"secondary": Color(0.92, 0.88, 0.98),       # #ebe0fa - Secondary purple bg
	"secondary_border": Color(0.50, 0.35, 0.75), # #8059bf - Secondary border
	"secondary_text": Color(0.35, 0.20, 0.65),  # #5933a6 - Secondary text/icons

	"info": Color(0.85, 0.95, 0.98),            # #d9f2fa - Info teal bg
	"info_border": Color(0.25, 0.60, 0.80),     # #4099cc - Info border
	"info_text": Color(0.10, 0.45, 0.65),       # #1a73a6 - Info text/icons

	"warning": Color(0.98, 0.92, 0.85),         # #faebd9 - Warning orange bg
	"warning_border": Color(0.80, 0.55, 0.20),  # #cc8c33 - Warning border
	"warning_text": Color(0.65, 0.40, 0.10),    # #a6661a - Warning text/icons

	"success": Color(0.85, 0.96, 0.88),         # #d9f5e0 - Success green bg
	"success_border": Color(0.25, 0.70, 0.35),  # #40b359 - Success border
	"success_text": Color(0.10, 0.50, 0.20),    # #1a8033 - Success text/icons

	"error": Color(0.98, 0.85, 0.85),           # #fad9d9 - Error red bg
	"error_border": Color(0.85, 0.25, 0.25),    # #d94040 - Error border
	"error_text": Color(0.70, 0.10, 0.10),      # #b31a1a - Error text/icons

	# Rating/stat colors (same vibrant colors work in light mode)
	"rating_elite": Color(0.00, 0.80, 0.00),    # #00cc00 - 90+ elite
	"rating_great": Color(0.30, 0.90, 0.30),    # #4de64d - 80-89 great
	"rating_good": Color(0.50, 0.95, 0.50),     # #80f280 - 70-79 good
	"rating_average": Color(0.90, 0.90, 0.00),  # #e6e600 - 60-69 average
	"rating_below_avg": Color(0.95, 0.60, 0.00), # #f29900 - 50-59 below avg
	"rating_poor": Color(0.90, 0.00, 0.00),     # #e60000 - <50 poor
}


# ============================================================================
# PUBLIC API
# ============================================================================

## Get a color from the active theme.
##
## [param color_name] The color key (e.g., "bg_dark", "primary", "text_primary")
## [param fallback] Optional fallback color if key not found
##
## [b]Returns:[/b] The color from the active theme, or fallback if not found.
func get_color(color_name: String, fallback: Color = Color.MAGENTA) -> Color:
	var theme_dict := _get_active_theme_dict()

	if theme_dict.has(color_name):
		return theme_dict[color_name]

	push_warning("ThemeManager: Color '%s' not found in theme '%s', using fallback" % [color_name, active_theme])
	return fallback


## Get the entire color dictionary for the active theme.
##
## [b]Returns:[/b] Dictionary of all colors in the active theme.
func get_all_colors() -> Dictionary:
	return _get_active_theme_dict()


## Set the active theme by name.
##
## [param theme_name] The theme to activate ("dark" or "light")
##
## Emits [signal theme_changed] if the theme actually changes.
func set_theme(theme_name: String) -> void:
	if theme_name != THEME_DARK and theme_name != THEME_LIGHT:
		push_error("ThemeManager: Unknown theme '%s', keeping current theme" % theme_name)
		return

	if active_theme == theme_name:
		return  # No change

	active_theme = theme_name
	theme_changed.emit(theme_name)

	print("ThemeManager: Switched to '%s' theme" % theme_name)


## Toggle between dark and light themes.
func toggle_theme() -> void:
	var new_theme := THEME_LIGHT if active_theme == THEME_DARK else THEME_DARK
	set_theme(new_theme)


## Check if dark theme is active.
##
## [b]Returns:[/b] true if dark theme is active.
func is_dark_theme() -> bool:
	return active_theme == THEME_DARK


## Check if light theme is active.
##
## [b]Returns:[/b] true if light theme is active.
func is_light_theme() -> bool:
	return active_theme == THEME_LIGHT


# ============================================================================
# INTERNAL HELPERS
# ============================================================================

## Get the color dictionary for the active theme.
func _get_active_theme_dict() -> Dictionary:
	if active_theme == THEME_LIGHT:
		return LIGHT_THEME
	return DARK_THEME


## Initialize on ready
func _ready() -> void:
	# Could load user preference here from Config or settings file
	# For now, just use the default
	print("ThemeManager: Initialized with '%s' theme" % active_theme)
