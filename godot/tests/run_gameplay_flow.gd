extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const PhoneMain := preload("res://tests/support/phone_main.gd")
const SaveManager := preload("res://scripts/core/save_manager.gd")
const Layout := preload("res://scripts/screens/game_layout.gd")
var failures: Array[String] = []
var main: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(320, 568) if "--compact" in OS.get_cmdline_user_args() else Vector2i(390, 844)
	Engine.time_scale = 2.0
	main = MAIN.instantiate()
	main.set_script(PhoneMain)
	if "--compact" in OS.get_cmdline_user_args():
		main.test_safe_insets = {"left": 0.0, "top": 20.0, "right": 0.0, "bottom": 0.0}
	print("[Gameplay] Touch flow at %s with safe insets %s" % [root.size, main.test_safe_insets])
	root.add_child(main)
	await process_frame
	main.save_manager = SaveManager.new({
		"best_score_path": "user://gameplay_flow_best.json",
		"experience_path": "user://gameplay_flow_exp.json",
		"profile_path": "user://gameplay_flow_profile.json",
		"tutorial_complete_path": "user://gameplay_flow_tutorial.txt",
	})
	_validate_layouts()
	await _attack_effect_parity()
	await _support_effect_parity()
	await _tutorial()
	await _battle_ordering()
	await _result_timing()
	await _solo_touch_flow()
	await _solo_clock()
	for player in main.sfx_players:
		player.stop()
		player.stream = null
	await _settle(0.8)
	main.queue_free()
	await process_frame
	for failure in failures:
		printerr("[Error] %s" % failure)
	if failures.is_empty():
		print("[Success] Gameplay flow: full tutorial, CPU reveal gates, ordered HP, solo timer, responsive layouts.")
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _settle(seconds: float = 3.3) -> void:
	await create_timer(seconds).timeout
	await process_frame

func _step(expected: int, description: String) -> void:
	_expect(main.tutorial_step == expected, "Tutorial stalled at %s: expected %s, got %s" % [description, expected, main.tutorial_step])

func _attack_effect_parity() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/generated/attack-fixtures.json"))
	_expect(fixtures is Array and not fixtures.is_empty(), "Web attack fixtures are missing")
	if not fixtures is Array:
		return
	main._start_battle_ready()
	main._start_battle_game(false)
	main.set_process(false)
	await _settle(1.0)
	for fixture in fixtures:
		var enemy: bool = fixture.side == "enemy"
		var source := Vector2(160, 170 if enemy else 330)
		var target := Vector2(160, 450 if enemy else 70)
		var fill: String = main.THEME_PANEL_PARTICLE_SECONDARY if enemy else main.THEME_PANEL_PARTICLE_PRIMARY
		var ring: String = main.THEME_PANEL_PARTICLE_RING_SECONDARY if enemy else main.THEME_PANEL_PARTICLE_RING_PRIMARY
		var ball: String = main.THEME_PANEL_ATTACK_BALL_SECONDARY if enemy else main.THEME_PANEL_ATTACK_BALL_PRIMARY
		var previous_nodes := main.get_children()
		var previous_tweens := get_processed_tweens()
		main._spawn_attack_particles(source, target, fill, ring, ball, int(fixture.damage))
		for tween in get_processed_tweens():
			if tween not in previous_tweens:
				tween.pause()
				tween.custom_step(float(fixture.elapsedMs) / 1000.0)
		var particles: Array[Dictionary] = []
		for node in main.get_children():
			if node in previous_nodes:
				continue
			if node is Control and node.modulate.a > 0.00001 and not node.is_queued_for_deletion():
				var shape := "ball" if node.theme_type_variation == ball else ("ring" if node.theme_type_variation == ring else "circle")
				particles.append({"shape": shape, "center": node.position + node.size / 2.0, "size": node.size.x * node.scale.x, "opacity": node.modulate.a})
			node.queue_free()
		var label := "%s damage=%s at %s ms" % [fixture.side, fixture.damage, fixture.elapsedMs]
		_expect(particles.size() == fixture.particles.size(), "Attack particle count differs from web: %s (%s vs %s)" % [label, particles.size(), fixture.particles.size()])
		for index in range(mini(particles.size(), fixture.particles.size())):
			var actual: Dictionary = particles[index]
			var expected: Dictionary = fixture.particles[index]
			_expect(actual.shape == expected.shape and actual.center.distance_to(Vector2(expected.x, expected.y)) < 0.05 and absf(actual.size - expected.size) < 0.05 and absf(actual.opacity - expected.opacity) < 0.005, "Attack particle geometry/opacity differs from web: %s, particle %s" % [label, index])
		await process_frame
	main.set_process(true)
	print("[Gameplay] Compared %s attack frames with the web animation across all four damage tiers and both directions." % fixtures.size())

func _support_effect_parity() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/generated/support-effect-fixtures.json"))
	_expect(fixtures is Array and not fixtures.is_empty(), "Web support-effect fixtures are missing")
	if not fixtures is Array:
		return
	for fixture in fixtures:
		var enemy: bool = fixture.side == "enemy"
		var effect: Control = main._spawn_support_effect(fixture.kind, Vector2(160, 170 if enemy else 330), Vector2(160, 70 if enemy else 450), int(fixture.amount))
		effect.set_process(false)
		effect.advance(float(fixture.elapsedMs) / 1000.0)
		var actual: Array[Control] = []
		for child in effect.get_children():
			if child.visible and child.modulate.a > 0.00001:
				actual.append(child)
		var expected: Array = fixture.particles.filter(func(p): return p.opacity > 0.00001)
		var context := "%s/%s amount=%s at %s ms" % [fixture.kind, fixture.side, fixture.amount, fixture.elapsedMs]
		_expect(actual.size() == expected.size(), "Support particle count differs from web: " + context)
		for index in range(mini(actual.size(), expected.size())):
			var particle := actual[index]
			var reference: Dictionary = expected[index]
			_expect(particle.get_meta("shape") == reference.shape, "Support shape differs: " + context)
			_expect((particle.position + particle.size / 2.0).distance_to(Vector2(reference.x, reference.y)) < 0.05, "Support path differs: " + context)
			_expect(particle.size.distance_to(Vector2(reference.get("width", reference.size), reference.get("height", reference.size))) < 0.05, "Support size differs: " + context)
			_expect(absf(particle.modulate.a - reference.opacity) < 0.005, "Support opacity differs: " + context)
			_expect(absf(particle.rotation - deg_to_rad(reference.get("rotation", 0.0))) < 0.005, "Support rotation differs: " + context)
		effect.queue_free()
		await process_frame
	print("[Success] %s support-effect frames match the web heal, fault and perfect-clear animations." % fixtures.size())

func _tap(button: Button) -> void:
	_expect(button.is_visible_in_tree() and not button.disabled, "Touch target is hidden or disabled: %s" % button.text)
	var point := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = down
		event.position = root.get_final_transform() * point
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func _tap_prime(prime: int) -> void:
	for button in main.prime_grid.get_children():
		if button.text == str(prime):
			await _tap(button)
			return
	_expect(false, "Missing prime button: %s" % prime)

func _expect_battle_display() -> void:
	_expect(main.battle_display_player_hp == int(main._battle_local_player().hp), "Player HP display differs from the match state at step %s" % main.tutorial_step)
	_expect(main.battle_display_bot_hp == int(main._battle_opponent_player().hp), "Enemy HP display differs from the match state at step %s" % main.tutorial_step)
	_expect(int(main.target_label.text) == int(main._battle_local_player().stage.remainingValue), "Displayed compound differs from its remaining factors")

func _send(primes: Array) -> void:
	for prime in primes:
		await _tap_prime(prime)
	_expect(main.battle_prime_queue == primes, "Touch input did not produce the requested queue at step %s" % main.tutorial_step)
	await _tap(main.submit_button)
	await _settle()
	_expect_battle_display()

func _tap_tutorial_action() -> void:
	await _settle(0.4)
	var overlay := main.get_node("TutorialCoachOverlay")
	var buttons := overlay.find_children("*", "Button", true, false)
	_expect(not buttons.is_empty(), "Tutorial action is missing")
	if buttons.is_empty():
		return
	var button: Button = buttons[0]
	var point := button.get_global_rect().get_center()
	_expect(not main.get_node("PrimeControls").visible, "Blocked keypad remains visible beneath the coach")
	var previous_step: int = main.tutorial_step
	var previous_ack: bool = main.tutorial_enemy_turn_acknowledged
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = down
		event.position = root.get_final_transform() * point
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		if down:
			_expect(main.tutorial_step != previous_step or main.tutorial_enemy_turn_acknowledged != previous_ack, "Tutorial action did not respond on touch down")
		await _settle(0.15)

func _tutorial() -> void:
	main._start_tutorial_game()
	_expect(not main._can_apply_bot_turn(main._battle_opponent_player()), "CPU can act while its compound is revealing")
	await _settle()
	await _tap_tutorial_action()
	_step(main.TutorialStep.STAGE_ONE_PRIME, "first factor")
	_expect(main.get_node("PrimeControls").visible, "Keypad did not return for the next interactive lesson")
	_expect(main.prime_grid.get_child(0).has_theme_stylebox_override("normal"), "Tutorial is missing the prime highlight")
	_expect(not main.enemy_avatar_panel.visible, "Enemy compound distracts from the first lesson")
	await _tap_prime(2)
	await _settle(0.4)
	var highlight: Control = main.get_node("TutorialCoachOverlay/TutorialHighlight")
	_expect(highlight.get_global_rect().end.y + 8.0 < main.get_node("PrimeControls").get_global_rect().position.y, "Queue highlight touches the keypad")
	_expect(highlight.size.x < main.get_viewport_rect().size.x / 2.0, "Queue highlight frames the entire empty row")
	await _tap_prime(3)
	await _tap(main.submit_button)
	_expect(main.battle_resolving_queue == [3], "Submitted queue should expose its remaining factor")
	_expect(main.tutorial_step != main.TutorialStep.STAGE_ONE_RESULT, "Coach advanced before the attack landed")
	await _settle(0.35)
	var echo_values: Array[int] = []
	for child in main.get_children():
		if str(child.name).begins_with("FactorEcho") and child.get_child_count() > 0:
			echo_values.append(int(child.get_child(0).text))
	echo_values.sort()
	_expect(echo_values == [2, 3], "Clearing 6 did not split into its actual factors")
	await _settle()
	_step(main.TutorialStep.STAGE_ONE_RESULT, "first clear")
	await _tap_tutorial_action()
	await _send([2, 3])
	_step(main.TutorialStep.STAGE_TWO_RESULT, "partial clear")
	_expect(main.get_node("TutorialCoachOverlay").get_node_or_null("TutorialHighlight") == null, "Partial clear highlights the covered Send button")
	_expect(is_equal_approx(main.enemy_hp_bar.position.x, main.player_hp_bar.position.x) and is_equal_approx(main.enemy_hp_bar.size.x, main.player_hp_bar.size.x), "Battle HP bars are not balanced")
	_expect(int(main._battle_local_player().stage.remainingValue) == 13, "Partial factoring lost the remaining 13")
	await _tap_tutorial_action()
	await _send([13])
	_step(main.TutorialStep.ENEMY_TURN, "enemy demonstration")
	_expect(main.enemy_avatar_panel.visible, "Enemy compound is missing when introduced")
	await _tap_tutorial_action()
	await _settle(4.8)
	_step(main.TutorialStep.ENEMY_ATTACK, "enemy hit")
	_expect(main.battle_display_player_hp < 1000, "Enemy demonstration did not land")
	await _tap_tutorial_action()
	await _tap_tutorial_action()
	var hp_before_heal: int = main._battle_local_player().hp
	var effects_during_explanation: Array[bool] = []
	var watch_heal := func(node: Node):
		if node.name == "BattleSupportEffect" and main.tutorial_step == main.TutorialStep.PERFECT_SOLVE_RESULT:
			effects_during_explanation.append(true)
	main.child_entered_tree.connect(watch_heal)
	await _send([2, 7])
	main.child_entered_tree.disconnect(watch_heal)
	_step(main.TutorialStep.PERFECT_SOLVE_RESULT, "perfect heal")
	_expect(main.tutorial_healed_hp > 0 and main.battle_display_player_hp == hp_before_heal + main.tutorial_healed_hp, "Perfect-clear lesson does not restore the displayed HP")
	_expect(not effects_during_explanation.is_empty(), "Heal effect is missing while the explanation is visible")
	_expect(main._tutorial_lesson_body({}).contains(str(main.tutorial_healed_hp)), "Heal explanation omits the recovered HP")
	await _tap_tutorial_action()
	var identity: int = main.target_blob_panel.stage_index
	await _tap_prime(2)
	await _tap(main.submit_button)
	_expect(main.result_label.visible and main.result_label.text == "Miss", "Wrong factor does not show immediate Miss feedback")
	await _settle(0.8)
	_expect(not main.result_label.visible and main.battle_result_text.is_empty(), "Miss lingers without further input")
	await _settle()
	_step(main.TutorialStep.WRONG_PRIME_RESULT, "wrong factor")
	_expect(main.target_blob_panel.stage_index == identity and main.target_blob_panel.reveal_left == 0.0, "Wrong factor restarted the unchanged blob reveal")
	await _tap_tutorial_action()
	await _tap_tutorial_action()
	await _send([3, 7, 2])
	_step(main.TutorialStep.OVERFLOW_RESULT, "overflow")
	_expect(not main.result_label.visible, "Overflow Miss remains visible throughout its explanation")
	_expect(int(main._battle_local_player().stage.remainingValue) == 1, "Overflow should preserve the solved 1")
	await _tap_tutorial_action()
	await _send([])
	_step(main.TutorialStep.SUMMARY, "clear solved 1")
	_expect(not main.result_label.visible, "Clearing the solved compound leaves stale Miss feedback")
	await _tap_tutorial_action()
	_expect(main.screen == main.Screen.BATTLE_GAME and main.tutorial_step == main.TutorialStep.DONE, "Keep playing must continue the tutorial fight")
	_expect(not main._tutorial_is_submit_locked(), "Practice fight still locks Submit")
	_expect(main._can_apply_bot_turn(main._battle_opponent_player()), "Practice fight never releases the CPU")
	await _send(main._battle_local_player().stage.remainingFactors.duplicate())
	_expect(main.get_node_or_null("BattleOverOverlay") != null and main.battle_display_bot_hp == 0, "Practice match cannot reach a visible victory")
	var rematch: Button = main.get_node("BattleOverOverlay").find_children("*", "Button", true, false)[0]
	await _tap(rematch)
	await _settle(0.4)
	_expect(main.screen == main.Screen.BATTLE_READY and not main.tutorial_active, "Rematch keeps tutorial restrictions")
	main._start_home()
	await process_frame

func _battle_ordering() -> void:
	main._start_battle_ready()
	main._start_battle_game(false)
	main.set_process(false)
	var source_id: String = main._battle_local_player_id()
	var target_id: String = main._battle_opponent_player_id()
	var attack := {"id": 100, "type": "attack", "sourcePlayerId": source_id, "targetPlayerId": target_id, "sourceHp": 1000, "targetHp": 990, "damage": 10, "regen": 0}
	main._play_battle_event_feedback(attack)
	main._play_battle_event_feedback(attack)
	_expect(main.battle_feedback_queue.is_empty(), "Repeated lastEvent spawned a duplicate attack")
	var response := {"id": 101, "type": "attack", "sourcePlayerId": target_id, "targetPlayerId": source_id, "sourceHp": 990, "targetHp": 985, "damage": 15, "regen": 0}
	main._play_battle_event_feedback(response)
	_expect(main.battle_display_bot_hp == 1000, "Enemy HP changed before projectile impact")
	await _settle(2.6)
	_expect(main.battle_display_bot_hp == 990 and main.battle_display_player_hp == 985, "Overlapping events dropped an HP change")
	var stale := attack.duplicate(true)
	stale.id = 102
	stale.targetHp = 980
	main._play_battle_event_feedback(stale)
	main._start_home()
	main._start_battle_ready()
	main._start_battle_game(false)
	await _settle(1.4)
	_expect(main.battle_display_bot_hp == 1000, "Previous match callback changed the new match HP")
	main.set_process(true)
	main._start_home()
	await process_frame

func _result_timing() -> void:
	main._start_battle_ready()
	main._start_battle_game(false)
	main.set_process(false)
	var source: String = main._battle_local_player_id()
	var target: String = main._battle_opponent_player_id()
	var snapshot: Dictionary = main.battle_snapshot.duplicate(true)
	for player in snapshot.players:
		player.hp = 1000 if player.id == source else 0
	var event := {"id": 200, "type": "finish", "cause": "attack", "sourcePlayerId": source, "winnerPlayerId": source, "loserPlayerId": target, "winnerHp": 1000, "loserHp": 0, "damage": 1000, "regen": 0}
	snapshot.status = "finished"
	snapshot.lastEvent = event
	main.battle_snapshot = snapshot
	main._play_battle_event_feedback(event)
	await _settle(1.0)
	_expect(main.get_node_or_null("BattleOverOverlay") == null, "Result covered the final HP drain")
	await _settle(2.2)
	_expect(main.get_node_or_null("BattleOverOverlay") != null, "Result never appeared after zero-HP hold")
	main.set_process(true)
	main._start_home()
	await process_frame

func _solo_touch_flow() -> void:
	main._start_solo_game()
	main.set_process(false)
	main.solo_state.currentStage = main._create_stage_state(0, [2, 23])
	main._render_solo()
	await _settle(0.4)
	var time_before: float = main.solo_time_left
	await _tap_prime(23)
	await _tap(main.submit_button)
	main._process(0.14)
	_expect(int(main.solo_state.currentStage.remainingValue) == 2, "Solo partial touch input did not preserve the remaining factor")
	await _tap_prime(2)
	await _tap(main.submit_button)
	main._process(0.14)
	_expect(is_equal_approx(main.solo_time_left, time_before - 0.28 + 0.2), "Solo time bonus uses a different prime than the submitted finishing queue")
	main.solo_state.currentStage = main._create_stage_state(1, [2, 3])
	main._render_solo()
	time_before = main.solo_time_left
	await _tap_prime(5)
	await _tap(main.backspace_button)
	_expect(main.prime_queue.is_empty(), "Solo backspace touch did not remove the factor")
	await _tap_prime(5)
	await _tap(main.submit_button)
	main._process(0.14)
	_expect(is_equal_approx(main.solo_time_left, time_before - 1.14), "Solo wrong factor did not deduct one second")
	_expect(int(main.solo_state.currentStage.remainingValue) == 6, "Solo wrong factor changes the compound")
	time_before = main.solo_time_left
	await _tap_prime(2)
	await _tap_prime(3)
	await _tap(main.submit_button)
	main._process(0.14)
	main._process(0.14)
	_expect(is_equal_approx(main.solo_time_left, time_before - 0.28 + 0.8), "Solo perfect clear does not grant its double time bonus")
	_expect(int(main.score_label.text) == int(main.solo_state.score), "Solo score label differs from the score")
	main.set_process(true)
	main._start_home()

func _solo_clock() -> void:
	main._start_solo_game()
	main.set_process(false)
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_2
	shortcut.physical_keycode = KEY_2
	shortcut.shift_pressed = true
	shortcut.pressed = true
	main._handle_game_keyboard_input(shortcut)
	_expect(main.prime_queue == [23], "Shift+2 does not queue 23 like the web")
	main._handle_keyboard_digit("1")
	_expect(main.queue_label.get_child_count() == 3, "Pending keyboard digit is missing from the queue")
	main._handle_keyboard_digit("3")
	_expect(main.prime_queue == [23, 13], "Two-digit prime entry differs from the web")
	_expect(main.prime_grid.get_child(0).action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS and main.submit_button.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS, "Touch controls wait for release")
	main.resolving_queue.assign([2, 3, 5])
	main.solo_time_left = 0.05
	main._process(0.1)
	_expect(main.screen == main.Screen.GAME_OVER, "Solo clock stops while a queue resolves")
	main.set_process(true)

func _validate_layouts() -> void:
	for viewport in [Vector2(320, 568), Vector2(390, 844), Vector2(430, 932), Vector2(768, 1024), Vector2(1024, 768)]:
		for battle in [false, true]:
			var layout := Layout.measure(viewport, {"top": 24.0, "bottom": 20.0}, battle)
			var controls: Rect2 = layout.controls
			var queue: Rect2 = layout.queue
			_expect(controls.position.x >= 0.0 and controls.end.x <= viewport.x, "Keypad exceeds viewport %s" % viewport)
			_expect(controls.end.y <= viewport.y - 20.0, "Keypad ignores bottom safe area")
			_expect(queue.end.y <= controls.position.y, "Queue overlaps keys at %s" % viewport)
			_expect(float(layout.key) >= 44.0, "Touch target too small at %s" % viewport)
			if battle:
				_expect(layout.self_blob.end.y <= layout.player_hp.position.y, "Blob overlaps HP at %s" % viewport)
			else:
				_expect(layout.solo_blob.end.y <= queue.position.y, "Solo blob overlaps queue at %s" % viewport)
