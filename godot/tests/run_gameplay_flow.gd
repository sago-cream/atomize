extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const SaveManager := preload("res://scripts/core/save_manager.gd")
const Layout := preload("res://scripts/screens/game_layout.gd")
var failures: Array[String] = []
var main: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 2.0
	main = MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.save_manager = SaveManager.new({
		"best_score_path": "user://gameplay_flow_best.json",
		"experience_path": "user://gameplay_flow_exp.json",
		"profile_path": "user://gameplay_flow_profile.json",
		"tutorial_complete_path": "user://gameplay_flow_tutorial.txt",
	})
	_validate_layouts()
	await _tutorial()
	await _battle_ordering()
	await _result_timing()
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

func _send(primes: Array) -> void:
	for prime in primes:
		main._queue_battle_prime(prime)
	main._submit_battle_queue()
	await _settle()

func _tutorial() -> void:
	main._start_tutorial_game()
	_expect(not main._can_apply_bot_turn(main._battle_opponent_player()), "CPU can act while its compound is revealing")
	await _settle()
	main._tutorial_handle_action()
	_step(main.TutorialStep.STAGE_ONE_PRIME, "first factor")
	_expect(main.prime_grid.get_child(0).has_theme_stylebox_override("normal"), "Tutorial is missing the prime highlight")
	main._queue_battle_prime(2)
	main._queue_battle_prime(3)
	main._submit_battle_queue()
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
	main._tutorial_handle_action()
	await _send([2, 3])
	_step(main.TutorialStep.STAGE_TWO_RESULT, "partial clear")
	_expect(int(main._battle_local_player().stage.remainingValue) == 13, "Partial factoring lost the remaining 13")
	main._tutorial_handle_action()
	await _send([13])
	_step(main.TutorialStep.ENEMY_TURN, "enemy demonstration")
	main._tutorial_handle_action()
	await _settle(4.8)
	_step(main.TutorialStep.ENEMY_ATTACK, "enemy hit")
	_expect(main.battle_display_player_hp < 1000, "Enemy demonstration did not land")
	main._tutorial_handle_action()
	main._tutorial_handle_action()
	await _send([2, 7])
	_step(main.TutorialStep.PERFECT_SOLVE_RESULT, "perfect heal")
	main._tutorial_handle_action()
	var identity: int = main.target_blob_panel.stage_index
	await _send([2])
	_step(main.TutorialStep.WRONG_PRIME_RESULT, "wrong factor")
	_expect(main.target_blob_panel.stage_index == identity and main.target_blob_panel.reveal_left == 0.0, "Wrong factor restarted the unchanged blob reveal")
	main._tutorial_handle_action()
	main._tutorial_handle_action()
	await _send([3, 7, 2])
	_step(main.TutorialStep.OVERFLOW_RESULT, "overflow")
	_expect(int(main._battle_local_player().stage.remainingValue) == 1, "Overflow should preserve the solved 1")
	main._tutorial_handle_action()
	await _send([])
	_step(main.TutorialStep.SUMMARY, "clear solved 1")
	main._tutorial_handle_action()
	_expect(main.screen == main.Screen.BATTLE_GAME and main.tutorial_step == main.TutorialStep.DONE, "Keep playing must continue the tutorial fight")
	_expect(not main._tutorial_is_submit_locked(), "Practice fight still locks Submit")
	_expect(main._can_apply_bot_turn(main._battle_opponent_player()), "Practice fight never releases the CPU")
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
