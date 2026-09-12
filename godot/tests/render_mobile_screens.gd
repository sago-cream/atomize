extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")
const SaveManager := preload("res://scripts/core/save_manager.gd")

func _init() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	await create_timer(0.6).timeout
	await process_frame
	RenderingServer.force_draw()
	var output := OS.get_environment("ATOMIZE_CAPTURE_DIR")
	if output.is_empty():
		output = "user://mobile-captures"
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("[Capture] %s" % label)

func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.save_manager = SaveManager.new({"best_score_path": "user://mobile_capture_best.json", "experience_path": "user://mobile_capture_exp.json", "profile_path": "user://mobile_capture_profile.json", "tutorial_complete_path": "user://mobile_capture_tutorial.txt"})
	main.needs_tutorial = false
	main._start_home()
	await _capture("01-home")
	main._start_solo_pregame()
	await _capture("02-solo-start")
	main._start_tutorial_game()
	main._tutorial_handle_action()
	await _capture("03-tutorial")
	main._start_battle_ready()
	main._start_battle_game(false)
	main.set_process(false)
	await _capture("04-battle")
	main._pause_game()
	await _capture("05-pause")
	main._start_home()
	main._start_leaderboard()
	main.leaderboard_entries.clear()
	main.leaderboard_status_text = ""
	for index in range(20):
		main.leaderboard_entries.append({"player_name": "Player %s" % (index + 1), "high_score": 1000 - index * 30})
	main._render_leaderboard()
	await _capture("06-leaderboard")
	main.get_node("LeaderboardScroll").scroll_vertical = 10000
	await _capture("07-leaderboard-end")
	main.realtime_pending_invitation = {"fromName": "A very long player name"}
	main.realtime_online_players.assign([{"name": "Player Two", "player_id": "fixture-player", "status": "lobby"}])
	main.screen = main.Screen.BATTLE_PICKER
	main._build_battle_picker_layout()
	await _capture("08-battle-picker")
	main.get_node("BattlePickerScroll").scroll_vertical = 10000
	await _capture("09-battle-picker-end")
	main.queue_free()
	await process_frame
	quit()
