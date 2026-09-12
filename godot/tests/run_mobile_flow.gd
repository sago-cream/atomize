extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const SaveManager := preload("res://scripts/core/save_manager.gd")
const Layout := preload("res://scripts/screens/game_layout.gd")
var main: Control
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _settle(seconds: float = 0.4) -> void:
	await create_timer(seconds).timeout
	await process_frame

func _touch(button: Control, index: int, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	event.canceled = canceled
	event.position = button.get_global_rect().get_center()
	root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(320, 568)
	main = MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.save_manager = SaveManager.new({
		"best_score_path": "user://mobile_flow_best.json", "experience_path": "user://mobile_flow_exp.json",
		"profile_path": "user://mobile_flow_profile.json", "tutorial_complete_path": "user://mobile_flow_tutorial.txt",
	})
	main._start_solo_game()
	main.set_process(false)
	await _settle()
	_expect(main.target_label.modulate.a > 0.9, "A timed puzzle is still hidden after 400 ms")
	var blob_id: int = main.target_blob_panel.get_instance_id()
	main._pause_game()
	await _settle()
	var resume: Button = main.get_node("PauseOverlay/DialogPanel").get_child(2).get_child(0)
	var physical_height: float = resume.size.y * root.get_final_transform().get_scale().y
	print("[Mobile] compact viewport %s; pause target %.1f px" % [main.get_viewport_rect().size, physical_height])
	_expect(physical_height >= 44.0, "Pause actions shrink below 44 pixels on a 320×568 screen")
	main._resume_game()
	_expect(main.target_blob_panel.get_instance_id() == blob_id, "Resume rebuilds the puzzle and restarts its hidden reveal")
	await _settle()
	_touch(main.prime_grid.get_child(0), 0, true)
	_touch(main.prime_grid.get_child(1), 1, true)
	_expect(main.prime_queue == [2, 3], "Overlapping thumb presses do not queue exactly 2, 3")
	_touch(main.prime_grid.get_child(0), 0, false)
	_touch(main.prime_grid.get_child(1), 1, false)
	_expect(main.prime_queue == [2, 3], "Finger release repeated a factor")
	main._pause_game()
	_touch(main.prime_grid.get_child(0), 2, true)
	_touch(main.prime_grid.get_child(0), 2, false, true)
	_expect(main.prime_queue == [2, 3], "Touch passed through the pause modal")
	main._resume_game()
	main.prime_queue.clear()
	main._play_sfx("prime")
	var clip: AudioStreamWAV = main.sfx_clips["prime"]
	_expect(clip.get_length() > 0.07 and clip.get_length() < 0.2 and clip.data.count(0) < clip.data.size(), "Finite sound clip is empty, silent or incorrectly timed")
	await _settle(0.5)
	_expect(main.sfx_players.all(func(player): return not player.playing), "Short effects leave audio players running after the sound ends")
	main._start_tutorial_game()
	await _settle()
	main._tutorial_handle_action()
	await _settle()
	var card: Control = main.get_node("TutorialCoachOverlay").get_child(0)
	_expect(not card.get_global_rect().intersects(main.enemy_avatar_panel.get_global_rect()), "Tutorial text covers the opponent's compound")
	_expect(not main.target_blob_panel.get_global_rect().intersects(main.enemy_avatar_panel.get_global_rect()), "Compact compounds overlap and conceal a number")
	_expect(main._battle_source_anchor(main._battle_opponent_player_id()).is_equal_approx(main.enemy_avatar_panel.get_global_rect().get_center()), "CPU attack origin is a hardcoded screen coordinate")
	main._handle_back_navigation()
	_expect(main.screen == main.Screen.PAUSED, "Android Back abandons the tutorial instead of pausing")
	main._resume_game()
	await _interruptions()
	await _rapid_feedback()
	await _lists()
	await _viewport_sizes()
	var transient: Tween = main._make_control_tween(main, "lifetime-probe")
	transient.tween_interval(10.0)
	var tween_ref: WeakRef = weakref(transient)
	main._clear_control_tweens()
	transient = null
	await process_frame
	_expect(tween_ref.get_ref() == null, "Killed control tween retains itself through its finished callback")
	main._start_home()
	for player in main.sfx_players:
		player.stop()
		player.stream = null
	main.queue_free()
	await process_frame
	for failure in failures:
		printerr("[Error] %s" % failure)
	if failures.is_empty():
		print("[Success] Mobile flow: compact targets, multitouch, audio lifetime, pause, tutorial geometry.")
	quit(0 if failures.is_empty() else 1)

func _interruptions() -> void:
	main._start_solo_game()
	main.set_process(true)
	main._queue_prime(2)
	main._submit_queue()
	var before: Dictionary = main.solo_state.duplicate(true)
	main._throttle_background_app()
	var clock_before: float = main.solo_time_left
	await _settle(0.3)
	main._restore_foreground_app()
	_expect(main.screen == main.Screen.PAUSED and paused, "Returning from the background resumes play before the user is ready")
	_expect(main.solo_state == before and main.solo_time_left == clock_before, "A background interruption consumes time or resolves a factor")
	main._resume_game()
	_expect(not paused, "Resume leaves the SceneTree paused")
	main._start_battle_ready()
	main._start_battle_game(false)
	main.set_process(false)
	var source: String = main._battle_local_player_id()
	var target: String = main._battle_opponent_player_id()
	main._play_battle_event_feedback({"id": 100, "type": "attack", "sourcePlayerId": source, "targetPlayerId": target, "sourceHp": 1000, "targetHp": 975, "damage": 25, "regen": 0})
	main._pause_game()
	var hp_before: int = main.battle_display_bot_hp
	await _settle(1.5)
	_expect(main.battle_display_bot_hp == hp_before and main.battle_feedback_active, "A delayed attack callback advances a paused fight")
	main._resume_game()
	await _settle(1.5)
	_expect(main.battle_display_bot_hp == 975, "Paused attack fails to finish after Resume")
	main._start_home()
	main.set_process(true)

func _lists() -> void:
	main._start_leaderboard()
	main.leaderboard_entries.clear()
	for index in range(20):
		main.leaderboard_entries.append({"player_name": "Player %s" % index, "high_score": 1000 - index})
	main._render_leaderboard()
	await _settle()
	var scroll := main.get_node("LeaderboardScroll") as ScrollContainer
	scroll.scroll_vertical = 10000
	await process_frame
	_expect(scroll.scroll_vertical > 0, "Leaderboard rows below the screen cannot be reached")
	_expect(main.leaderboard_rows_root.get_child(20).get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "Last leaderboard entry remains clipped after scrolling")
	main.realtime_pending_invitation = {"fromName": "Very long invited player name"}
	main.screen = main.Screen.BATTLE_PICKER
	main._build_battle_picker_layout()
	await _settle()
	var picker := main.get_node("BattlePickerScroll") as ScrollContainer
	picker.scroll_vertical = 10000
	await process_frame
	_expect(picker.scroll_vertical > 0, "An invitation pushes the online section off screen without scrolling")
	_expect(picker.get_global_rect().end.y <= main.get_viewport_rect().end.y, "Picker scroll extends below the phone screen")
	main.realtime_pending_invitation.clear()

func _rapid_feedback() -> void:
	main._start_battle_ready()
	main._start_battle_game(false)
	main.set_process(false)
	var source: String = main._battle_local_player_id()
	var target: String = main._battle_opponent_player_id()
	for index in range(12):
		main._play_battle_event_feedback({"id": 200 + index, "type": "attack", "sourcePlayerId": source, "targetPlayerId": target, "sourceHp": 1000, "targetHp": 990 - index * 10, "damage": 10, "regen": 0})
	_expect(main.battle_feedback_queue.size() <= 2, "Rapid taps build an unbounded visual backlog")
	await _settle(3.0)
	_expect(main.battle_display_bot_hp == 880 and main.battle_feedback_queue.is_empty(), "Rapid damage never catches up or an older hit restores HP")
	main._start_home()
	main.set_process(true)

func _viewport_sizes() -> void:
	for window_size in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(430, 932), Vector2i(768, 1024)]:
		root.size = window_size
		await process_frame
		main._start_solo_game()
		main.set_process(false)
		await _settle(0.6)
		var screen_rect := main.get_viewport_rect()
		for button in main.prime_grid.get_children():
			var physical: Vector2 = button.size * root.get_final_transform().get_scale()
			_expect(physical.x >= 44.0 and physical.y >= 44.0, "Actual keypad hit size is below 44 pixels at %s" % window_size)
			_expect(screen_rect.encloses(button.get_global_rect()), "Container sizing pushes a key offscreen at %s" % window_size)
		main._start_home()
		for step in main.TUTORIAL_LESSONS:
			if main.TUTORIAL_LESSONS[step].get("position", "") != "top":
				continue
			main.tutorial_step = step
			var coach_height: float = main._tutorial_coach_metrics().height + 16.0
			var layout := Layout.measure(main.get_viewport_rect().size, {"top": 24.0, "bottom": 20.0}, true, coach_height)
			_expect(not layout.self_blob.intersects(layout.enemy_blob) and layout.self_blob.end.y <= layout.player_hp.position.y, "Safe-area tutorial geometry obscures a compound at %s, step %s" % [window_size, step])
	main.set_process(true)
