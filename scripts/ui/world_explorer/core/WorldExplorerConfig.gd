extends Resource
class_name WorldExplorerConfig

## Configuration resource for WorldExplorer UI
## Can be customized in the editor or via code

## Auto-scroll detail panel to bottom when content updates
@export var auto_scroll_detail: bool = false

## Show debug information in header
@export var show_debug_info: bool = false

## Default split position for sidebar vs detail panel
@export var default_split_offset: int = 400

## Maximum search results to display
@export var max_search_results: int = 100

## Enable keyboard shortcuts
@export var enable_shortcuts: bool = true

## Default colors for rating tiers (hex strings)
@export var color_elite: String = "#00ff00"      # 90+
@export var color_great: String = "#66ff66"      # 80-89
@export var color_good: String = "#99ff99"       # 70-79
@export var color_average: String = "#ffff00"    # 60-69
@export var color_below_avg: String = "#ffaa00"  # 50-59
@export var color_poor: String = "#ff0000"       # <50

func _init() -> void:
	# Default values set via @export
	pass

## Get color for a rating value
func get_rating_color(rating: float) -> String:
	if rating >= 90.0: return color_elite
	if rating >= 80.0: return color_great
	if rating >= 70.0: return color_good
	if rating >= 60.0: return color_average
	if rating >= 50.0: return color_below_avg
	return color_poor

## Get Color object for rating value
func get_rating_color_obj(rating: float) -> Color:
	return Color(get_rating_color(rating))
