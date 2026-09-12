extends Panel

# Short arrivals preserve the rhythm without hiding an actionable puzzle.
const REVEAL_SECONDS := 0.24
var value_label: Label
var stage_index := -1
var previous_value := -1
var reveal_left := 0.0
var reveal_duration := 0.0
var reveal_delay := 0.0
var base_font_size := 48.0
var solo := false
var conceal_factors := false
var reduced_motion := false
var idle_elapsed := 0.0
var echo_count := 0
var value_tween: Tween
var motion_tween: Tween

func configure(label: Label, font_size: float, is_solo: bool, conceal: bool, reduce_motion: bool) -> void:
	value_label = label
	base_font_size = font_size
	solo = is_solo
	conceal_factors = conceal
	reduced_motion = reduce_motion
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not solo:
		var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style != null:
			style.shadow_size = 0
			add_theme_stylebox_override("panel", style)

func sync_value(identity: int, value: int) -> void:
	if stage_index == identity and previous_value == value:
		return
	var changed_stage := stage_index != identity
	var old_value := previous_value
	stage_index = identity
	previous_value = value
	if is_instance_valid(value_tween):
		value_tween.kill()
	if changed_stage:
		if old_value > 1 and not conceal_factors:
			var factors := _factorize_value(old_value)
			for index in range(factors.size()):
				_spawn_echo(factors[index], index, true)
		reveal_delay = 0.0
		reveal_duration = REVEAL_SECONDS
		reveal_left = reveal_duration
		_set_value(value)
	elif old_value > value and value > 1:
		_spawn_echo(int(old_value / value), echo_count, false)
		echo_count += 1
		value_tween = create_tween()
		value_tween.tween_interval(0.09 if not reduced_motion else 0.0)
		value_tween.tween_callback(_set_value.bind(value))
		impact()
	else:
		_set_value(value)
		impact()
	_process(0.0)

func _set_value(value: int) -> void:
	if not is_instance_valid(value_label):
		return
	value_label.text = str(value)
	var digits := str(value).length()
	var digit_scale := 1.0
	if digits >= 7:
		digit_scale = 0.48
	elif digits == 6:
		digit_scale = 0.58
	elif digits == 5:
		digit_scale = 0.70
	elif digits == 4:
		digit_scale = 0.82
	value_label.label_settings.font_size = int(round(base_font_size * digit_scale))

func refresh_font(font_size: float) -> void:
	base_font_size = font_size
	_set_value(previous_value)

func _process(delta: float) -> void:
	if not is_instance_valid(value_label):
		return
	reveal_left = maxf(0.0, reveal_left - delta)
	pivot_offset = size / 2.0
	if reveal_left > 0.0 and not reduced_motion:
		var elapsed := reveal_duration - reveal_left
		var progress := clampf(elapsed / reveal_duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		scale = Vector2.ONE * lerpf(0.92, 1.0, eased)
		modulate.a = 1.0
		value_label.modulate.a = 1.0
		return
	modulate.a = 1.0
	value_label.modulate.a = 1.0
	if is_instance_valid(motion_tween) and motion_tween.is_running():
		return
	idle_elapsed += delta
	scale = Vector2.ONE if reduced_motion else Vector2.ONE * (1.0 + sin(idle_elapsed * TAU / 6.6) * 0.012)

func cancel_reveal() -> void:
	reveal_left = 0.0
	scale = Vector2.ONE
	modulate.a = 1.0
	value_label.modulate.a = 1.0

func impact() -> void:
	if reduced_motion or reveal_left > 0.0:
		return
	if is_instance_valid(motion_tween):
		motion_tween.kill()
	scale = Vector2.ONE * 0.88
	motion_tween = create_tween()
	motion_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "scale", Vector2.ONE * 1.04, 0.29)
	motion_tween.tween_property(self, "scale", Vector2.ONE, 0.23)

func _spawn_echo(value: int, index: int, cleared: bool) -> void:
	if reduced_motion:
		return
	var echo := Panel.new()
	echo.name = "FactorEcho"
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visual_scale := 1.0 if solo else base_font_size / 70.4
	var diameter := (75.2 if cleared else 80.8) * visual_scale
	echo.size = Vector2.ONE * diameter
	echo.pivot_offset = echo.size / 2.0
	echo.position = position + size / 2.0 - echo.size / 2.0
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style != null:
		style.shadow_size = 0
		style.bg_color = Color("#168aad") if solo else (Color("#34a0a4").lerp(Color.WHITE, 0.18) if cleared else Color("#34a0a4"))
		echo.add_theme_stylebox_override("panel", style)
	get_parent().add_child(echo, true)
	if not conceal_factors:
		var label := Label.new()
		label.text = str(value)
		label.label_settings = value_label.label_settings.duplicate()
		label.label_settings.font_size = int(minf(26.0, diameter * 0.42))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		echo.add_child(label)
	var angles := [-58.0, -26.0, 18.0, 52.0]
	var angle := deg_to_rad(angles[index % angles.size()])
	var distance := (7.9 + float(index % 4) * 0.6) if cleared else (7.6 + float(index % 3) * 0.7)
	var offset := Vector2(sin(angle), -cos(angle)) * distance * 16.0 * visual_scale * 1.24
	echo.scale = Vector2.ONE * 0.32
	var tween := echo.create_tween().set_parallel(true)
	tween.tween_property(echo, "position", echo.position + offset, 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(echo, "scale", Vector2.ONE, 0.2)
	tween.tween_property(echo, "modulate:a", 0.0, 0.23).set_delay(0.59)
	tween.chain().tween_callback(echo.queue_free)

func pulse(peak: float, seconds: float) -> void:
	if reduced_motion or reveal_left > 0.0:
		return
	if is_instance_valid(motion_tween):
		motion_tween.kill()
	motion_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "scale", Vector2.ONE * peak, seconds)
	motion_tween.tween_property(self, "scale", Vector2.ONE, seconds)

func _factorize_value(value: int) -> Array[int]:
	var factors: Array[int] = []
	var remaining := value
	var divisor := 2
	while divisor * divisor <= remaining:
		while remaining % divisor == 0:
			factors.append(divisor)
			remaining = int(remaining / divisor)
		divisor += 1 if divisor == 2 else 2
	if remaining > 1:
		factors.append(remaining)
	return factors
