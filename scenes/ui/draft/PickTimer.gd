## PickTimer - Countdown timer for user's draft pick
##
## ARCHITECTURAL PATTERN: UI Component
##
## Displays a countdown timer when it's the user's turn to pick.
## Emits signal when time expires for auto-pick functionality.
## Can be disabled via settings.
##
## Design Philosophy:
##   - Purely presentational countdown
##   - Emits signal on expiry - parent handles auto-pick logic
##   - No RNG usage
##   - Visual urgency indicators (color changes at thresholds)
##   - Configurable duration
##
## Integration Points:
##   - DraftDayUI: Starts timer when user's pick, connects to auto_pick signal
##
## Usage:
##   timer.time_expired.connect(_on_auto_pick_requested)
##   timer.start_timer(300.0)  # 5 minutes
##
extends HBoxContainer
class_name PickTimer

## Emitted when timer expires
signal time_expired()

## Emitted every second with remaining time
signal time_updated(seconds_remaining: float)

## Timer configuration
const DEFAULT_TIME_SECONDS := 300.0  # 5 minutes default
const WARNING_THRESHOLD := 60.0      # Yellow at 1 minute
const DANGER_THRESHOLD := 30.0       # Red at 30 seconds
const CRITICAL_THRESHOLD := 10.0     # Flashing at 10 seconds

## Color constants
const COLOR_NORMAL := Color(0.9, 0.9, 0.9)    # White
const COLOR_WARNING := Color(0.9, 0.9, 0.2)   # Yellow
const COLOR_DANGER := Color(0.9, 0.3, 0.2)    # Red
const COLOR_CRITICAL := Color(1.0, 0.1, 0.1)  # Bright red

## UI References
var _timer_label: Label
var _icon_label: Label
var _toggle_button: Button

## State
var _time_remaining: float = 0.0
var _is_running: bool = false
var _is_enabled: bool = true
var _flash_state: bool = false

## Internal timer for countdown
var _countdown_timer: Timer
var _flash_timer: Timer


func _ready() -> void:
	_setup_ui()
	_setup_timers()


## Setup the UI structure
func _setup_ui() -> void:
	# Timer icon
	_icon_label = Label.new()
	_icon_label.text = "[Timer]"
	_icon_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_icon_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	add_child(spacer)

	# Timer display
	_timer_label = Label.new()
	_timer_label.text = "5:00"
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.custom_minimum_size = Vector2(80, 0)
	add_child(_timer_label)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(10, 0)
	add_child(spacer2)

	# Enable/Disable toggle
	_toggle_button = Button.new()
	_toggle_button.text = "Disable Timer"
	_toggle_button.tooltip_text = "Toggle pick timer on/off"
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)


## Setup internal timers
func _setup_timers() -> void:
	# Countdown timer (1 second intervals)
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.one_shot = false
	_countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(_countdown_timer)

	# Flash timer for critical warning
	_flash_timer = Timer.new()
	_flash_timer.wait_time = 0.5
	_flash_timer.one_shot = false
	_flash_timer.timeout.connect(_on_flash_tick)
	add_child(_flash_timer)


## Start the countdown timer
## @param duration: Time in seconds (default 300 = 5 minutes)
func start_timer(duration: float = DEFAULT_TIME_SECONDS) -> void:
	if not _is_enabled:
		_timer_label.text = "--:--"
		return

	_time_remaining = duration
	_is_running = true
	_update_display()
	_countdown_timer.start()
	_flash_timer.stop()
	_flash_state = false


## Stop the timer
func stop_timer() -> void:
	_is_running = false
	_countdown_timer.stop()
	_flash_timer.stop()
	_flash_state = false


## Pause the timer
func pause_timer() -> void:
	_countdown_timer.stop()
	_flash_timer.stop()


## Resume the timer
func resume_timer() -> void:
	if _is_running and _is_enabled:
		_countdown_timer.start()
		if _time_remaining <= CRITICAL_THRESHOLD:
			_flash_timer.start()


## Add time to the timer (e.g., for bonus time features)
## @param seconds: Seconds to add
func add_time(seconds: float) -> void:
	_time_remaining += seconds
	_update_display()


## Get remaining time in seconds
func get_remaining_time() -> float:
	return _time_remaining


## Check if timer is running
func is_running() -> bool:
	return _is_running


## Enable/disable the timer feature
func set_enabled(enabled: bool) -> void:
	_is_enabled = enabled
	_toggle_button.text = "Disable Timer" if enabled else "Enable Timer"

	if not enabled:
		stop_timer()
		_timer_label.text = "--:--"
		_timer_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		_timer_label.add_theme_color_override("font_color", COLOR_NORMAL)


## Check if timer is enabled
func is_timer_enabled() -> bool:
	return _is_enabled


## Handle countdown tick
func _on_countdown_tick() -> void:
	if not _is_running or not _is_enabled:
		return

	_time_remaining -= 1.0

	if _time_remaining <= 0:
		_time_remaining = 0
		stop_timer()
		time_expired.emit()
	else:
		_update_display()
		time_updated.emit(_time_remaining)

		# Start flash timer at critical threshold
		if _time_remaining <= CRITICAL_THRESHOLD and not _flash_timer.is_stopped():
			pass  # Already flashing
		elif _time_remaining <= CRITICAL_THRESHOLD:
			_flash_timer.start()


## Handle flash tick for critical warning
func _on_flash_tick() -> void:
	_flash_state = not _flash_state

	if _flash_state:
		_timer_label.add_theme_color_override("font_color", COLOR_CRITICAL)
	else:
		_timer_label.add_theme_color_override("font_color", Color(0.3, 0.1, 0.1))


## Handle toggle button press
func _on_toggle_pressed() -> void:
	set_enabled(not _is_enabled)


## Update the timer display
func _update_display() -> void:
	var minutes := int(_time_remaining) / 60
	var seconds := int(_time_remaining) % 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]

	# Update color based on time remaining
	if _time_remaining <= CRITICAL_THRESHOLD:
		# Flashing handled by flash timer
		if not _flash_timer.is_stopped():
			return
		_timer_label.add_theme_color_override("font_color", COLOR_CRITICAL)
	elif _time_remaining <= DANGER_THRESHOLD:
		_flash_timer.stop()
		_timer_label.add_theme_color_override("font_color", COLOR_DANGER)
	elif _time_remaining <= WARNING_THRESHOLD:
		_flash_timer.stop()
		_timer_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		_flash_timer.stop()
		_timer_label.add_theme_color_override("font_color", COLOR_NORMAL)


## Format time for display (static utility)
static func format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [mins, secs]
