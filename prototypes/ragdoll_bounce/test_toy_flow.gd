extends SceneTree

# godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy_flow.gd
const SCENE := "res://prototypes/ragdoll_bounce/toy.tscn"
const TEST_SCORES := "user://test_scores.cfg"

var failures := 0


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func game() -> Node:
	return current_scene


func key(keycode: Key, unicode := 0) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.unicode = unicode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func action(name: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = name
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SCORES))
	ToyScores.path = TEST_SCORES
	Toy.level = 1
	ToyScores.enabled = true
	change_scene_to_file(SCENE)
	await frames(10)
	var g := game()
	g.hit_stop_enabled = false
	check(g.state == g.State.TITLE, "boots to the title screen")
	check(not g.hog.active, "hedgehog is frozen on the title screen")
	check(g.hog.global_position.x > -400.0 and g.hog.global_position.x < -100.0, "hedgehog starts close to the hole (x=%.0f)" % g.hog.global_position.x)

	await key(KEY_A, 97)
	await frames(10)
	check(g.state == g.State.PLAYING and g.hog.active, "any key starts the run")
	await frames(60)
	check(g.run_time > 0.8, "timer runs (%.2fs)" % g.run_time)

	g.hog.bounced.emit()
	g.hog.bounced.emit()
	check(g.combo == 2 and g.best_combo == 2, "chained bounces build a combo (x%d)" % g.combo)
	g.hog.knocked_out.emit()
	check(g.combo == 0, "a knock-out breaks the combo")

	await action("restart")
	await frames(10)
	g = game()
	g.hit_stop_enabled = false
	check(g.state == g.State.PLAYING, "R retries straight into play, no title")
	check(g.run_time < 1.0, "timer reset on retry")

	g.run_time = 75.3
	g.hog.kos = 2
	g._on_goal()
	await create_timer(1.7).timeout
	check(g.state == g.State.WON and g.hud.won, "reaching the goal shows the finish screen")
	check(g._entering_name, "an empty table means a top-5 name entry")
	await key(KEY_R, 114)
	await key(KEY_O, 111)
	await key(KEY_Z, 122)
	await key(KEY_BACKSPACE)
	await key(KEY_ENTER)
	var scores := ToyScores.load_scores()
	check(scores.size() == 1 and scores[0]["name"] == "RO", "typed name saved to the leaderboard ('R' did not restart the game): %s" % str(scores))
	check(is_equal_approx(float(scores[0]["time"]), 75.3) and int(scores[0]["kos"]) == 2, "time and KOs recorded")

	await action("ui_accept")
	await frames(10)
	g = game()
	g.hit_stop_enabled = false
	check(g.state == g.State.PLAYING, "Enter on the finish screen replays immediately")

	for t in [50.0, 60.0, 70.0, 80.0]:
		ToyScores.add("BOT", t, 0)
	check(ToyScores.load_scores().size() == ToyScores.MAX, "leaderboard is capped at %d" % ToyScores.MAX)
	check(ToyScores.qualifies(65.0) and not ToyScores.qualifies(95.0), "only faster runs qualify once the table is full")
	check(ToyScores.best() == 50.0, "best time is the fastest entry")

	g.run_time = 99.0
	g._on_goal()
	await create_timer(1.7).timeout
	check(not g._entering_name, "a slow run just shows the table (no name prompt)")
	await key(KEY_ESCAPE)
	await frames(10)
	g = game()
	check(g.state == g.State.TITLE, "Esc on the finish screen returns to the title for the next player")

	# pause menu: Esc pauses, Esc resumes, T goes back to the title
	g = game()
	g.hit_stop_enabled = false
	await key(KEY_A, 97)
	await frames(10)
	check(g.state == g.State.PLAYING, "a run is in progress for the pause test")
	await key(KEY_ESCAPE)
	check(paused and g.hud._pause.visible, "Esc during a run opens the pause menu")
	var frozen: float = g.run_time
	for i in 20:
		await process_frame
	check(is_equal_approx(g.run_time, frozen), "the clock is frozen while paused")
	await key(KEY_ESCAPE)
	check(not paused and not g.hud._pause.visible, "Esc again resumes")
	await key(KEY_ESCAPE)
	await key(KEY_T, 116)
	await frames(10)
	g = game()
	g.hit_stop_enabled = false
	check(not paused and g.state == g.State.TITLE, "T in the pause menu goes back to the title")
	await key(KEY_A, 97)
	await frames(10)
	check(g.state == g.State.PLAYING, "and the title starts a new run")
	g.hud.again_pressed.emit()
	await frames(10)
	g = game()
	g.hit_stop_enabled = false
	check(g.state == g.State.PLAYING and g.run_time < 1.0, "the Retry button restarts straight into play")

	# finishing is quick and the buttons work, even mid name entry
	g.run_time = 40.0
	var finish_start := Time.get_ticks_msec()
	g._on_goal()
	while not g.hud.won and Time.get_ticks_msec() - finish_start < 4000:
		await process_frame
	var finish_wait := (Time.get_ticks_msec() - finish_start) / 1000.0
	check(g.hud.won and finish_wait < 1.4, "finish screen appears %.1fs after the launch" % finish_wait)
	check(g._entering_name, "name entry is open")
	g.hud.again_pressed.emit()
	await frames(10)
	var saved := ToyScores.load_scores()
	check(saved[0]["name"] == "ANON" and is_equal_approx(float(saved[0]["time"]), 40.0), "Play Again while typing saves the run as ANON first: %s" % str(saved[0]))
	g = game()
	g.hit_stop_enabled = false
	check(g.state == g.State.PLAYING, "and then starts a fresh run")
	g.run_time = 99.0
	g._on_goal()
	await create_timer(1.3).timeout
	g.hud.title_pressed.emit()
	await frames(10)
	g = game()
	check(g.state == g.State.TITLE, "the Title button goes back to the title")

	# level select: keys 1/2 on the title, N and the button on the finish screen
	g = game()
	check(g.state == g.State.TITLE and Toy.level == 1, "back on the Level 1 title")
	await key(KEY_2, 50)
	await frames(15)
	g = game()
	g.hit_stop_enabled = false
	check(Toy.level == 2 and g.state == g.State.TITLE and g.world_end > 10000.0, "key 2 on the title opens the long Level 2 (world %.0f px wide)" % g.world_end)
	check(g.world_end > 2.0 * 5900.0, "Level 2 is more than twice as long as Level 1")
	g.hud.level_pressed.emit(1)
	await frames(15)
	g = game()
	g.hit_stop_enabled = false
	check(Toy.level == 1 and g.state == g.State.TITLE, "the Level 1 button on the title switches back")
	await key(KEY_A, 97)
	await frames(10)
	g.run_time = 999.0
	g._on_goal()
	await create_timer(1.3).timeout
	check(g.hud.won and not g._entering_name, "Level 1 finish screen is up (slow run, no name entry)")
	await key(KEY_N, 110)
	await frames(15)
	g = game()
	g.hit_stop_enabled = false
	check(Toy.level == 2 and g.state == g.State.PLAYING, "N on the finish screen jumps straight into Level 2")
	g.run_time = 99.0
	g._on_goal()
	await create_timer(1.3).timeout
	g.hud.level_pressed.emit(1)
	await frames(15)
	g = game()
	g.hit_stop_enabled = false
	check(Toy.level == 1 and g.state == g.State.PLAYING, "the other-level button on Level 2's finish screen returns to Level 1")
	var saved_path := ToyScores.path
	ToyScores.path = ""
	ToyScores.level = 1
	var f1 := ToyScores.file()
	ToyScores.level = 2
	var f2 := ToyScores.file()
	ToyScores.path = saved_path
	check(f1 != f2, "each level keeps its own leaderboard file (%s, %s)" % [f1.get_file(), f2.get_file()])
	Toy.level = 1

	# medals, progress bar, ghost
	check(ToyMedals.medal(1, 9.5) == 3 and ToyMedals.medal(1, 12.0) == 2 and ToyMedals.medal(1, 14.0) == 1 and ToyMedals.medal(1, 20.0) == 0, "medal thresholds: gold 10s, silver 13s, bronze 15s (Level 1)")
	check(ToyMedals.medal(2, 55.0) == 3 and ToyMedals.medal(2, 58.0) == 2 and ToyMedals.medal(2, 70.0) == 1 and ToyMedals.medal(2, 71.0) == 0, "Level 2: gold 55s, silver 1:00, bronze 1:10")
	check(is_equal_approx(ToyMedals.next_target(1, 14.0), 13.0), "a bronze run is told the silver target")
	g = game()
	g.hit_stop_enabled = false
	await key(KEY_A, 97)
	await frames(10)
	g.hog._pending_teleport = Vector2(2000.0, 1000.0)
	await frames(8)
	check(absf(g.hud._progress.progress - 2000.0 / (g.tower_x0 + 1350.0)) < 0.1, "progress bar tracks the hedgehog along the course (%.2f)" % g.hud._progress.progress)
	g.hog._pending_teleport = Vector2(100.0, 1000.0)
	g.hog.active = true
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	check(g._rec.size() > 100 and g._rec.size() % ToyGhost.FLOATS == 0, "a run is recorded for the ghost (%d floats)" % g._rec.size())
	var recorded: int = g._rec.size()
	g.run_time = 5.0
	g._on_goal()
	await create_timer(1.3).timeout
	var saved_ghost := ToyScores.load_ghost()
	check(saved_ghost.size() == recorded, "a record-breaking run saves its ghost (%d floats)" % saved_ghost.size())
	g.hud.again_pressed.emit()
	await frames(15)
	g = game()
	g.hit_stop_enabled = false
	check(g._ghost.sample_count() > 20, "the ghost loads on the next run (%d samples)" % g._ghost.sample_count())
	await frames(40)
	check(g._ghost.visible, "and plays back alongside the hedgehog")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ToyScores.ghost_file()))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SCORES))
	print("---- %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
