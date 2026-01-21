extends Node
## Global theme manager for consistent UI theming across the application.
##
## Design Philosophy (Solarized-inspired):
## - SHARED accent colors between dark/light themes (semantic colors stay constant)
## - BASE colors swap roles: dark bg ↔ light bg, light text ↔ dark text
## - Minimizes color definitions while maximizing theme consistency
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
# SHARED COLOR PALETTE (Solarized-inspired)
# ============================================================================
# These colors are IDENTICAL in both dark and light themes.
# Only base colors (backgrounds, text) swap roles.

## Accent colors - SHARED between themes (like Solarized)
const ACCENT := {
	# Primary blues
	"blue": Color(0.15, 0.55, 0.82),           # #268bd2 - Primary actions
	"blue_dim": Color(0.10, 0.40, 0.65),       # #1a66a6 - Subdued blue

	# Secondary
	"violet": Color(0.42, 0.44, 0.77),         # #6c71c4 - Secondary actions
	"magenta": Color(0.83, 0.21, 0.51),        # #d33682 - Highlights

	# Semantic
	"cyan": Color(0.16, 0.63, 0.60),           # #2aa198 - Info/links
	"green": Color(0.52, 0.60, 0.00),          # #859900 - Success
	"yellow": Color(0.71, 0.54, 0.00),         # #b58900 - Warning
	"orange": Color(0.80, 0.29, 0.09),         # #cb4b16 - Alert
	"red": Color(0.86, 0.20, 0.18),            # #dc322f - Error/danger
}

## Rating colors - SHARED between themes (high visibility required)
const RATINGS := {
	"elite": Color(0.00, 0.80, 0.20),          # #00cc33 - 90+ elite
	"great": Color(0.40, 0.85, 0.40),          # #66d966 - 80-89 great
	"good": Color(0.60, 0.90, 0.40),           # #99e666 - 70-79 good
	"average": Color(0.90, 0.85, 0.20),        # #e6d933 - 60-69 average
	"below_avg": Color(0.95, 0.60, 0.15),      # #f29926 - 50-59 below avg
	"poor": Color(0.90, 0.25, 0.20),           # #e64033 - <50 poor
}

# ============================================================================
# BASE COLORS (Swap roles between dark/light)
# ============================================================================

## Base monotone scale - used differently per theme
## Inspired by Solarized base03 → base3
const BASE := {
	# Dark end of spectrum
	"base03": Color(0.00, 0.17, 0.21),         # #002b36 - Darkest
	"base02": Color(0.03, 0.21, 0.26),         # #073642
	"base01": Color(0.35, 0.43, 0.46),         # #586e75 - Dark content
	"base00": Color(0.40, 0.48, 0.51),         # #657b83 - Body text (dark)
	# Light end of spectrum
	"base0": Color(0.51, 0.58, 0.59),          # #839496 - Body text (light)
	"base1": Color(0.58, 0.63, 0.63),          # #93a1a1 - Light content
	"base2": Color(0.93, 0.91, 0.84),          # #eee8d5
	"base3": Color(0.99, 0.96, 0.89),          # #fdf6e3 - Lightest
}


# ============================================================================
# THEME DEFINITIONS (Assembled from shared palette)
# ============================================================================

## Dark theme - dark backgrounds, light text
const DARK_THEME := {
	# Backgrounds (using dark end of BASE)
	"bg_darker": BASE["base03"],
	"bg_dark": BASE["base02"],
	"bg_medium": Color(0.07, 0.25, 0.30),      # Slightly lighter than base02
	"bg_light": Color(0.10, 0.28, 0.33),
	"bg_lighter": Color(0.13, 0.31, 0.36),

	# Borders
	"border_subtle": BASE["base01"],
	"border_medium": Color(0.30, 0.38, 0.42),
	"border_accent": ACCENT["blue"],

	# Text (using light end of BASE)
	"text_primary": BASE["base1"],
	"text_secondary": BASE["base0"],
	"text_disabled": BASE["base01"],

	# Semantic colors - backgrounds muted, text/borders use accent
	"primary": Color(ACCENT["blue"].r * 0.3, ACCENT["blue"].g * 0.3, ACCENT["blue"].b * 0.3),
	"primary_border": ACCENT["blue"],
	"primary_text": ACCENT["blue"],

	"secondary": Color(ACCENT["violet"].r * 0.3, ACCENT["violet"].g * 0.3, ACCENT["violet"].b * 0.3),
	"secondary_border": ACCENT["violet"],
	"secondary_text": ACCENT["violet"],

	"info": Color(ACCENT["cyan"].r * 0.25, ACCENT["cyan"].g * 0.25, ACCENT["cyan"].b * 0.25),
	"info_border": ACCENT["cyan"],
	"info_text": ACCENT["cyan"],

	"warning": Color(ACCENT["yellow"].r * 0.3, ACCENT["yellow"].g * 0.3, ACCENT["yellow"].b * 0.3),
	"warning_border": ACCENT["yellow"],
	"warning_text": ACCENT["yellow"],

	"success": Color(ACCENT["green"].r * 0.25, ACCENT["green"].g * 0.25, ACCENT["green"].b * 0.25),
	"success_border": ACCENT["green"],
	"success_text": ACCENT["green"],

	"error": Color(ACCENT["red"].r * 0.25, ACCENT["red"].g * 0.25, ACCENT["red"].b * 0.25),
	"error_border": ACCENT["red"],
	"error_text": ACCENT["red"],

	# Ratings - direct from shared palette
	"rating_elite": RATINGS["elite"],
	"rating_great": RATINGS["great"],
	"rating_good": RATINGS["good"],
	"rating_average": RATINGS["average"],
	"rating_below_avg": RATINGS["below_avg"],
	"rating_poor": RATINGS["poor"],
}

## Light theme - light backgrounds, dark text (BASE colors swap roles)
const LIGHT_THEME := {
	# Backgrounds (using light end of BASE - SWAPPED from dark theme)
	"bg_darker": BASE["base2"],
	"bg_dark": BASE["base2"],
	"bg_medium": BASE["base3"],
	"bg_light": Color(0.99, 0.97, 0.91),
	"bg_lighter": Color(1.00, 0.98, 0.94),

	# Borders
	"border_subtle": BASE["base1"],
	"border_medium": BASE["base0"],
	"border_accent": ACCENT["blue"],

	# Text (using dark end of BASE - SWAPPED from dark theme)
	"text_primary": BASE["base00"],
	"text_secondary": BASE["base01"],
	"text_disabled": BASE["base1"],

	# Semantic colors - light backgrounds, same accent colors for text/borders
	"primary": Color(0.90, 0.94, 0.98),        # Very light blue tint
	"primary_border": ACCENT["blue_dim"],
	"primary_text": ACCENT["blue_dim"],

	"secondary": Color(0.94, 0.92, 0.98),      # Very light violet tint
	"secondary_border": ACCENT["violet"],
	"secondary_text": ACCENT["violet"],

	"info": Color(0.90, 0.96, 0.96),           # Very light cyan tint
	"info_border": ACCENT["cyan"],
	"info_text": ACCENT["cyan"],

	"warning": Color(0.98, 0.95, 0.88),        # Very light yellow tint
	"warning_border": ACCENT["yellow"],
	"warning_text": ACCENT["yellow"],

	"success": Color(0.94, 0.96, 0.88),        # Very light green tint
	"success_border": ACCENT["green"],
	"success_text": ACCENT["green"],

	"error": Color(0.98, 0.90, 0.90),          # Very light red tint
	"error_border": ACCENT["red"],
	"error_text": ACCENT["red"],

	# Ratings - SAME as dark theme (high visibility colors work in both)
	"rating_elite": RATINGS["elite"],
	"rating_great": RATINGS["great"],
	"rating_good": RATINGS["good"],
	"rating_average": RATINGS["average"],
	"rating_below_avg": RATINGS["below_avg"],
	"rating_poor": RATINGS["poor"],
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
