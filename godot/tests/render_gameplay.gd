extends SceneTree

const MAIN := preload("res://scenes/Main.tscn")

func _init() -> void:
	call_deferred("_run")

func _capture(_main: Control, label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var output := OS.get_environment("ATOMIZE_CAPTURE_DIR")
	if output.is_empty():
		output = "user://gameplay-captures"
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("[Capture] %s" % label)

func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main._start_tutorial_game()
	await create_timer(3.4).timeout
	await _capture(main, "tutorial-intro")
	main._tutorial_handle_action()
	await create_timer(0.4).timeout
	await _capture(main, "tutorial-prime")
	main._queue_battle_prime(2)
	await create_timer(0.4).timeout
	await _capture(main, "tutorial-queue")
	main._queue_battle_prime(3)
	main._submit_battle_queue()
	await create_timer(0.9).timeout
	await _capture(main, "tutorial-attack")
	await create_timer(3.0).timeout
	await _capture(main, "tutorial-result")
	main._start_home()
	main._start_solo_game()
	await create_timer(2.3).timeout
	await _capture(main, "solo")
	main._pause_game()
	await create_timer(0.5).timeout
	await _capture(main, "pause")
	main.queue_free()
	await process_frame
	quit()
