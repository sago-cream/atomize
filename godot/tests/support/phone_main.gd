extends "res://scripts/screens/main.gd"

# Logical insets for a notched phone, including its home indicator.
var test_safe_insets := {"left": 0.0, "top": 39.0, "right": 0.0, "bottom": 28.0}

func _safe_area_insets() -> Dictionary:
	return test_safe_insets

var test_pixel_ratio := 1.0

func _display_pixel_ratio() -> float:
	return test_pixel_ratio
