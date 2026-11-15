extends SceneTree

# Menu/flow checks: godot --headless --path . --script res://tests/test_flow.gd

var failures := 0


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func tap(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func game() -> Node:
	return current_scene


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await frames(30)
	check(game().state == game().State.TITLE, "boots to the title screen")
	game().persist_best = false
	game().best_time = 0.0

	await tap("jump")
	await frames(20)
	check(game().state == game().State.PLAYING, "Space on the title starts the game")
	check(game().player.input_enabled, "player can move after start")

	await frames(60)
	check(game().run_time > 0.5, "run timer advances while playing (%.2fs)" % game().run_time)

	await tap("pause")
	check(paused, "Esc pauses")
	var frozen: float = game().run_time
	await frames(30)
	check(is_equal_approx(game().run_time, frozen), "timer is frozen while paused")
	await tap("pause")
	check(not paused, "Esc again resumes")

	var was_muted := AudioServer.is_bus_mute(0)
	await tap("mute")
	check(AudioServer.is_bus_mute(0) != was_muted, "M toggles mute")
	await tap("mute")
	check(AudioServer.is_bus_mute(0) == was_muted, "M toggles mute back")

	await tap("restart")
	await frames(10)
	check(game().state == game().State.PLAYING, "R restarts straight into play (title skipped)")
	check(game().run_time < 1.0, "timer resets on restart")

	var g := game()
	g.run_time = 90.0
	g.deaths = 2
	g._win()
	check(g.state == g.State.WON, "win state reached")
	check(g.best_time == 90.0, "best time recorded")
	g.hud.set_time(90.0)
	await frames(5)
	await tap("ui_accept")
	await frames(10)
	check(game().state == game().State.PLAYING and game().deaths == 0, "Enter on the win screen replays instantly")

	print("---- %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
