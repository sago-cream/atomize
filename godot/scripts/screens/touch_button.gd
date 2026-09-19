extends Button

var active_touch := -1
var touch_sequence := 0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == active_touch:
		call_deferred("_release_unhandled_touch", touch_sequence)

func _release_unhandled_touch(sequence: int) -> void:
	if sequence == touch_sequence:
		_cancel_touch()

func _cancel_touch() -> void:
	if active_touch != -1:
		active_touch = -1
		button_up.emit()

# Keep touch releases observable even when an action disables its own button.
# Mouse, keyboard, and accessibility activation still use Button's native path.
func _gui_input(event: InputEvent) -> void:
	# ScrollContainer uses the native button's drag cancellation and emulated
	# mouse events to distinguish a tap from scrolling the surrounding list.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return
		ancestor = ancestor.get_parent()
	if event.device == -1:
		# The OS input path may synthesize mouse events from this same touch.
		# Conversely, desktop mouse input can synthesize a touch: leave that to
		# the native mouse path instead of activating the button twice.
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			accept_event()
		return
	if event is InputEventScreenTouch:
		accept_event()
		if event.pressed:
			if disabled or active_touch != -1:
				return
			active_touch = event.index
			touch_sequence += 1
			button_down.emit()
			if action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS:
				pressed.emit()
		elif event.index == active_touch:
			active_touch = -1
			button_up.emit()
			if not disabled and not event.canceled and Rect2(Vector2.ZERO, size).has_point(event.position) and action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE:
				pressed.emit()
	elif event is InputEventScreenDrag:
		accept_event()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_SCROLL_BEGIN, NOTIFICATION_DRAG_BEGIN]:
		_cancel_touch()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_touch()
