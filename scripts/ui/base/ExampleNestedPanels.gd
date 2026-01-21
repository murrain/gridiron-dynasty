extends Control
## Example demonstration of nested ReactivePanelContainer styling.
##
## This example shows how to use the built-in theme/style system for
## ReactivePanel and ReactivePanelContainer to create visually hierarchical
## nested panel layouts.
##
## [b]Features Demonstrated:[/b]
## - Multiple style variants (default, primary, secondary, info, warning, nested)
## - Automatic nesting depth detection
## - Auto-indenting of nested panels
## - Manual style changes via set_style_variant()
##
## [b]Usage:[/b]
## 1. Attach this script to a Control node in the scene tree
## 2. Run the scene to see the example panels
## 3. Modify the exported variables to experiment with different configurations
##
## [b]Example Hierarchy:[/b]
## [codeblock]
## Control (this script)
## └── VBoxContainer
##     ├── ParentPanel (default style)
##     │   └── ChildPanel (nested style, auto-indented 8px)
##     │       └── GrandchildPanel (nested style, auto-indented 16px)
##     ├── PrimaryPanel (primary style)
##     │   └── InfoPanel (info style, nested)
##     └── WarningPanel (warning style)
## [/codeblock]


## Whether to build the example panels on ready
@export var auto_build_example: bool = true

## Spacing between example sections
@export var section_spacing: int = 16


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	if auto_build_example:
		_build_example_panels()


# ============================================================================
# EXAMPLE BUILDERS
# ============================================================================

## Build the complete example panel hierarchy.
func _build_example_panels() -> void:
	# Create main container
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", section_spacing)
	add_child(main_vbox)

	# Add title
	var title := Label.new()
	title.text = "ReactivePanel Style System Examples"
	title.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(title)

	# Example 1: Nested panels with auto-darkening
	_add_section_title(main_vbox, "1. Nested Panels (Auto-Darkening)")
	_build_nested_example(main_vbox)

	# Example 2: Accent variants
	_add_section_title(main_vbox, "2. Accent Variants")
	_build_accent_variants_example(main_vbox)

	# Example 3: Mixed nesting with accents
	_add_section_title(main_vbox, "3. Mixed Nesting with Accents")
	_build_mixed_nesting_example(main_vbox)

	# Example 4: Manual style changes
	_add_section_title(main_vbox, "4. Dynamic Style Changes")
	_build_dynamic_style_example(main_vbox)


## Add a section title label.
func _add_section_title(container: VBoxContainer, title_text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)


## Example 1: Nested panels with automatic depth-based darkening.
func _build_nested_example(container: VBoxContainer) -> void:
	# Parent panel (depth 0)
	var parent := ReactivePanelContainer.new()
	parent.style_variant = "nested"
	parent.custom_minimum_size = Vector2(0, 150)
	container.add_child(parent)

	var parent_vbox := VBoxContainer.new()
	parent.add_child(parent_vbox)

	var parent_label := Label.new()
	parent_label.text = "Parent Panel (Depth 0) - Medium Background"
	parent_vbox.add_child(parent_label)

	# Child panel (depth 1)
	var child := ReactivePanelContainer.new()
	child.style_variant = "nested"
	child.custom_minimum_size = Vector2(0, 80)
	parent_vbox.add_child(child)

	var child_vbox := VBoxContainer.new()
	child.add_child(child_vbox)

	var child_label := Label.new()
	child_label.text = "Child Panel (Depth 1) - Dark Background - Auto-indented 8px"
	child_vbox.add_child(child_label)

	# Grandchild panel (depth 2)
	var grandchild := ReactivePanelContainer.new()
	grandchild.style_variant = "nested"
	grandchild.custom_minimum_size = Vector2(0, 40)
	child_vbox.add_child(grandchild)

	var grandchild_label := Label.new()
	grandchild_label.text = "Grandchild Panel (Depth 2) - Darker Background - Auto-indented 16px"
	grandchild.add_child(grandchild_label)


## Example 2: Different accent variants.
func _build_accent_variants_example(container: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	container.add_child(hbox)

	# Create panels with different accent variants
	var variants := ["default", "primary", "secondary", "info", "warning", "success", "error"]

	for variant in variants:
		var panel := ReactivePanelContainer.new()
		panel.style_variant = variant
		panel.custom_minimum_size = Vector2(120, 80)
		panel.auto_indent_nested = false  # Disable auto-indent for horizontal layout
		hbox.add_child(panel)

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		var label := Label.new()
		label.text = variant.capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)


## Example 3: Mixed nesting with different accent styles.
func _build_mixed_nesting_example(container: VBoxContainer) -> void:
	# Primary parent
	var primary_panel := ReactivePanelContainer.new()
	primary_panel.style_variant = "primary"
	primary_panel.custom_minimum_size = Vector2(0, 120)
	container.add_child(primary_panel)

	var primary_vbox := VBoxContainer.new()
	primary_panel.add_child(primary_vbox)

	var primary_label := Label.new()
	primary_label.text = "Primary Panel"
	primary_vbox.add_child(primary_label)

	# Info child
	var info_panel := ReactivePanelContainer.new()
	info_panel.style_variant = "info"
	info_panel.custom_minimum_size = Vector2(0, 60)
	primary_vbox.add_child(info_panel)

	var info_label := Label.new()
	info_label.text = "Info Panel (nested inside Primary) - Auto-indented"
	info_panel.add_child(info_label)


## Example 4: Dynamic style changes with buttons.
func _build_dynamic_style_example(container: VBoxContainer) -> void:
	var panel := ReactivePanelContainer.new()
	panel.style_variant = "default"
	panel.custom_minimum_size = Vector2(0, 100)
	container.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "Click buttons to change style"
	vbox.add_child(label)

	# Button row
	var button_hbox := HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(button_hbox)

	var variants := ["default", "primary", "warning", "success", "error"]
	for variant in variants:
		var button := Button.new()
		button.text = variant.capitalize()
		button.pressed.connect(_on_style_button_pressed.bind(panel, variant))
		button_hbox.add_child(button)


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_style_button_pressed(panel: ReactivePanelContainer, variant: String) -> void:
	panel.set_style_variant(variant)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Create a simple example panel with a label.
static func create_example_panel(
	variant: String,
	label_text: String,
	min_size: Vector2 = Vector2(0, 60)
) -> ReactivePanelContainer:
	var panel := ReactivePanelContainer.new()
	panel.style_variant = variant
	panel.custom_minimum_size = min_size

	var label := Label.new()
	label.text = label_text
	panel.add_child(label)

	return panel
