extends SceneTree

# godot --headless --path . --script res://game3d/tests/test_intro.gd
# The Level 1 cutscene: plays from the title, can be skipped, plays through to the end, hands over cleanly,
# and does not play on a retry, on other levels, or when start_run() is called directly.

var failures := 0
var game: Game3D


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func press(keycode: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)


func fresh(level: int, skip_title: bool) -> void:
	if game:
		game.free()
		await frames(2)
	Engine.time_scale = 1.0
	Game3D.level = level
	Game3D.skip_title = skip_title
	game = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(game)
	await frames(5)


func _initialize() -> void:
	ToyScores.enabled = false
	await run()
	print("---- %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func run() -> void:
	# 1. the title starts the cutscene on level 1, with the real hedgehog hidden and the clock stopped
	await fresh(1, false)
	check(game.state == Game3D.State.TITLE, "level 1 opens on the title")
	await press(KEY_ENTER)
	check(game.state == Game3D.State.INTRO, "any key on the title starts the cutscene")
	var intro := game.get_node_or_null("Intro") as Intro3D
	check(intro != null, "the cutscene node exists")
	check(not game.hog.visible, "the real hedgehog is hidden while the puppet acts")
	await frames(20)
	check(game.run_time == 0.0, "the run clock does not tick during the cutscene")

	# 2. ESC skips (after the short grace period) and hands over to a normal run
	await get_root().get_tree().create_timer(1.0).timeout
	await press(KEY_ESCAPE)
	for i in 120:
		await process_frame
		if game.state == Game3D.State.PLAYING:
			break
	check(game.state == Game3D.State.PLAYING, "ESC skips to the run")
	check(game.hog.visible, "the hedgehog is back")
	check(not game.camera.cine, "the camera follows the hedgehog again")
	check(absf(game.hog.global_position.x - Game3D.START_X) < 0.3 and game.hog.global_position.y < -10.0, "the hedgehog starts in the cave where he landed (%s)" % game.hog.global_position)
	check(game.run_time < 0.5, "the clock starts from zero (%.2f)" % game.run_time)
	await frames(60)
	check(not is_instance_valid(game.get_node_or_null("Intro")), "the cutscene cleans itself up")

	# 3. playing it all the way through, fast: every story beat happens in order
	await fresh(1, false)
	Engine.time_scale = 6.0
	await press(KEY_ENTER)
	intro = game.get_node("Intro") as Intro3D
	var hog_low := 0.0
	var planks_gone := false
	for i in 60 * 60:
		await process_frame
		if not is_instance_valid(intro) or game.state == Game3D.State.PLAYING:
			break
		hog_low = minf(hog_low, intro._hog.position.y)
		planks_gone = planks_gone or (intro._planks.all(func(p: Dictionary) -> bool: return not (p["node"] as Node3D).visible))
	Engine.time_scale = 1.0
	var beats: Array[String] = ["start", "walked", "terry", "collapse", "landed", "rim", "bounce", "card", "end"]
	check(game.state == Game3D.State.PLAYING, "the cutscene hands over to the run")
	check(not intro.skipped and intro.beats == beats, "all beats played in order: %s" % [intro.beats])
	check(hog_low <= Intro3D.CAVE_FLOOR + 0.01, "the hedgehog fell all the way to the cave floor (%.2f)" % hog_low)
	check(planks_gone, "the trap cover fell away")
	check(game.hog.visible and absf(game.hog.global_position.x - Game3D.START_X) < 0.3, "the real hedgehog waits in the cave")

	# 4. no cutscene on a retry, on other levels, or via start_run()
	await fresh(1, true)
	check(game.state == Game3D.State.PLAYING, "a retry on level 1 skips the cutscene")
	await fresh(2, false)
	await press(KEY_ENTER)
	check(game.state == Game3D.State.PLAYING, "level 2 starts straight away")
	await fresh(1, false)
	game.start_run()
	check(game.state == Game3D.State.PLAYING and game.get_node_or_null("Intro") == null, "start_run() does not play the cutscene")
