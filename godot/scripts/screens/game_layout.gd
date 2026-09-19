extends RefCounted

# Logical phone coordinates shared by gameplay and floating tutorial overlays.
static func measure(viewport: Vector2, insets: Dictionary, battle: bool) -> Dictionary:
	var padding := 8.0 if battle else 12.0
	var left := maxf(padding, float(insets.get("left", 0.0)))
	var right := maxf(padding, float(insets.get("right", 0.0)))
	var top := maxf(padding, float(insets.get("top", 0.0)))
	var bottom := maxf(padding, float(insets.get("bottom", 0.0)))
	var available := viewport.x - left - right
	var gap := 5.0 if viewport.x <= 480.0 else 6.0
	var cluster_limit := maxf(160.0, minf(352.0, viewport.y - top - bottom - 380.0))
	var controls_width := minf(available, (4.0 * cluster_limit + gap) / 3.0)
	var key := (controls_width - gap * 3.0) / 4.0
	var controls_height := key * 3.0 + gap * 2.0
	var controls := Rect2(Vector2(left + (available - controls_width) / 2.0, viewport.y - bottom - controls_height), Vector2(controls_width, controls_height))
	var queue := Rect2(left, controls.position.y - 65.6 - (0.0 if battle else 8.0), available, 65.6)
	var board_width := minf(available, 512.0)
	var board_left := left + (available - board_width) / 2.0
	var player_hp := Rect2(board_left, queue.position.y - 8.0 - 32.5, board_width, 32.5)
	var enemy_hp := Rect2(board_left, top, board_width, 56.0)
	var enemy_size := minf(board_width * 0.35, 144.0)
	var self_size := minf(board_width * 0.55, 240.0)
	var self_scale := 0.78
	var enemy_scale := 0.44
	var font_size := 86.4
	var max_blob := 344.0
	if viewport.x <= 768.0:
		enemy_size = minf(board_width * 0.32, 120.0)
		self_size = minf(board_width * 0.52, 208.0)
		self_scale = 0.72
		enemy_scale = 0.39
		font_size = 78.4
		max_blob = 283.2
	if viewport.y <= 780.0:
		enemy_size = minf(board_width * 0.28, 104.0)
		self_size = minf(board_width * 0.48, 192.0)
	if viewport.x <= 480.0:
		enemy_size = minf(board_width * 0.28, 96.0)
		self_size = minf(board_width * 0.48, 176.0)
		self_scale = 0.66
		enemy_scale = 0.35
		font_size = 70.4
		max_blob = 264.0
	elif viewport.x >= 900.0:
		font_size = 100.8
		max_blob = 304.0
	var pair_height := enemy_size + self_size + 8.0
	var board_top := enemy_hp.end.y
	var pair_available := maxf(60.0, player_hp.position.y - board_top - 16.0)
	if pair_height > pair_available:
		var fit := (pair_available - 8.0) / (enemy_size + self_size)
		enemy_size *= fit
		self_size *= fit
		pair_height = enemy_size + self_size + 8.0
	var pair_top := board_top + (player_hp.position.y - board_top - pair_height) / 2.0
	var enemy_blob_size := minf(enemy_size, max_blob * enemy_scale)
	var self_blob_size := minf(self_size, max_blob * self_scale)
	var center_x := board_left + board_width / 2.0
	var enemy_blob := Rect2(center_x - enemy_blob_size / 2.0, pair_top + (enemy_size - enemy_blob_size) / 2.0, enemy_blob_size, enemy_blob_size)
	var self_blob := Rect2(center_x - self_blob_size / 2.0, pair_top + enemy_size + 8.0 + (self_size - self_blob_size) / 2.0, self_blob_size, self_blob_size)
	var solo_top := top + 44.0 + 12.0
	var solo_bottom := queue.position.y - 12.0
	var solo_max := 297.6 if viewport.x <= 480.0 else (304.0 if viewport.x >= 900.0 else 344.0)
	var solo_size := maxf(44.0, minf(available, minf(solo_max, solo_bottom - solo_top - 16.0)))
	return {
		"controls": controls, "queue": queue, "key": key, "gap": gap,
		"enemy_hp": enemy_hp, "player_hp": player_hp,
		"enemy_blob": enemy_blob, "self_blob": self_blob,
		"solo_blob": Rect2(center_x - solo_size / 2.0, solo_top + (solo_bottom - solo_top - solo_size) / 2.0, solo_size, solo_size),
		"self_font": minf(font_size * self_scale, self_blob_size * 0.38), "enemy_font": minf(font_size * enemy_scale, enemy_blob_size * 0.38),
		"solo_font": font_size, "top": top,
	}
