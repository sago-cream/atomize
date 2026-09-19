extends Control

# Mirrors useBattleAnimations.ts support effects in logical viewport points.
var kind := ""
var source := Vector2.ZERO
var target := Vector2.ZERO
var amount := 0
var elapsed := 0.0
var particles: Dictionary = {}

func configure(effect_kind: String, from: Vector2, to: Vector2, value: int) -> void:
	kind = effect_kind
	source = from
	target = to
	amount = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	advance(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	advance(elapsed)
	if elapsed > duration():
		queue_free()

func duration() -> float:
	return 1.265 if kind == "heal" else (0.78 if kind == "perfect" else 0.62)

func advance(seconds: float) -> void:
	for particle in particles.values():
		particle.visible = false
	for sample in sample_particles(kind, source, target, amount, seconds):
		var id: int = sample.id
		var particle: Panel = particles.get(id)
		if particle == null:
			particle = Panel.new()
			particle.name = sample.name
			particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			particle.set_meta("shape", sample.shape)
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(2048)
			style.corner_detail = 32
			var color := Color("#c43a3a") if str(sample.shape).begins_with("fault") else Color("#d4a017")
			if sample.shape == "perfect-orbit":
				color = Color("#e8b825")
			style.bg_color = color
			if sample.shape in ["heal-ring", "perfect-halo"]:
				style.bg_color = Color.TRANSPARENT
				style.border_color = color
				style.set_border_width_all(2)
			elif sample.shape == "fault-shard":
				style.border_color = Color(1, 1, 1, 0.28)
				style.set_border_width_all(2)
			elif sample.shape in ["heal", "fault-glow"]:
				style.shadow_color = Color(color, 0.14 if sample.shape == "heal" else 0.6)
				style.shadow_size = 8
			particle.add_theme_stylebox_override("panel", style)
			add_child(particle, true)
			particles[id] = particle
		particle.visible = true
		particle.size = sample.size
		particle.position = sample.center - sample.size / 2.0
		particle.pivot_offset = sample.size / 2.0
		particle.rotation = sample.get("rotation", 0.0)
		particle.modulate.a = sample.opacity

static func _sample(id: int, name: String, shape: String, center: Vector2, size: Vector2, opacity: float, rotation: float = 0.0) -> Dictionary:
	return {"id": id, "name": name, "shape": shape, "center": center, "size": size, "opacity": opacity, "rotation": rotation}

static func _ease(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a * (1.0 - t) * (1.0 - t) + b * 2.0 * (1.0 - t) * t + c * t * t

static func _burst(center: Vector2, seconds: float, count: int, base_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if seconds < 0.0 or seconds > 0.28:
		return result
	var t := clampf(seconds / 0.28, 0.0, 1.0)
	var eased := _ease(t)
	result.append(_sample(base_id, "FaultGlow", "fault-glow", center, Vector2.ONE * 34.0 * (0.28 + eased * 1.22), (1.0 - t) * 0.68))
	for index in range(count):
		var angle := TAU * index / count + 0.18
		var point := center + Vector2.from_angle(angle) * (18.0 + (index % 3) * 7.0) * eased
		result.append(_sample(base_id + 1 + index, "FaultShard", "fault-shard", point, Vector2(10 + (index % 2) * 4, 4), (1.0 - t) * 0.94, angle))
	return result

static func sample_particles(effect_kind: String, from: Vector2, to: Vector2, value: int, seconds: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if effect_kind == "heal":
		var severity := 3 if value > 20 else (2 if value > 12 else (1 if value > 5 else 0))
		var count: int = [5, 7, 9, 12][severity]
		var direction := (to - from).normalized()
		var tangent := Vector2(-direction.y, direction.x)
		var control := (from + to) / 2.0 - Vector2(0, 48 + severity * 16)
		var pulse_t := clampf(seconds / 0.52, 0.0, 1.0)
		if pulse_t < 1.0:
			var base := 36.0 + severity * 12.0
			result.append(_sample(1, "HealPulse", "heal", to, Vector2.ONE * base * (0.32 + _ease(pulse_t) * 1.14), (1.0 - pulse_t) * 0.74))
			result.append(_sample(2, "HealRing", "heal-ring", to, Vector2.ONE * base * (0.32 + _ease(pulse_t) * 1.28), (1.0 - pulse_t) * 0.86))
		for index in range(count):
			var delay := index * 0.055
			var t := clampf((seconds - delay) / maxf(0.22, 0.66 - delay * 0.25), 0.0, 1.0)
			if t <= 0.0 or t >= 1.0:
				continue
			var lane := tangent * (-1.0 if index % 2 == 0 else 1.0) * (6 + (index % 4) * 3)
			var a := from + lane * 0.2 - direction * (index % 3) * 4.0
			var b := control + lane * 1.2 - Vector2(0, (index % 3) * 8)
			var c := to + lane * 0.18 - Vector2(0, (index % 2) * 4)
			result.append(_sample(10 + index, "HealMote", "heal", _bezier(a, b, c, _ease(t)), Vector2.ONE * (6 + (index % 3) * 2 + severity), minf(1.0, t * 5.0) * (1.0 - t * 0.9)))
	elif effect_kind == "perfect":
		var t := clampf(seconds / 0.78, 0.0, 1.0)
		if t >= 1.0:
			return result
		result.append(_sample(1, "PerfectHalo", "perfect-halo", from, Vector2.ONE * 58.0 * (0.36 + _ease(t) * 1.74), (1.0 - t) * 0.88))
		for index in range(8):
			var p := clampf(seconds / (0.78 * (0.72 + (index % 2) * 0.08)), 0.0, 1.0)
			if p >= 1.0:
				continue
			var angle := TAU * index / 8.0 + p * 1.15
			var radius := 18.0 + (54.0 + (index % 3) * 4.0 - 18.0) * p
			result.append(_sample(10 + index, "PerfectOrbitMote", "perfect-orbit", from + Vector2.from_angle(angle) * radius, Vector2.ONE * (6 + (index % 2) * 2) * (1.0 - p * 0.58), 1.0 - p))
	elif effect_kind == "fault":
		var severity := 3 if value > 30 else (2 if value > 15 else (1 if value > 5 else 0))
		result.append_array(_burst(from, seconds, 5, 100))
		if seconds <= 0.34:
			var t := clampf(seconds / 0.34, 0.0, 1.0)
			var control := (from + to) / 2.0 + Vector2(28.0 if to.x >= from.x else -28.0, -40.0 - severity * 8.0)
			var accelerated := t * t
			var tangent := (control - from) * 2.0 * (1.0 - accelerated) + (to - control) * 2.0 * accelerated
			result.append(_sample(1, "FaultRicochet", "fault-shard", _bezier(from, control, to, accelerated), Vector2(20 + severity * 4, 6 + severity), minf(1.0, t * 5.0) * (1.0 - t * 0.95), tangent.angle()))
		result.append_array(_burst(to, seconds - 0.34 * 0.8, 6 + severity * 2, 300))
	elif effect_kind == "fault-burst":
		result.append_array(_burst(from, seconds, value, 100))
	return result
