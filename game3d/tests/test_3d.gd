extends SceneTree

# godot --headless --path . --script res://game3d/tests/test_3d.gd
const CAVE := -11.0
var failures := 0
var level: Node
var hog: Hog3D


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func place(pos: Vector3, vel := Vector3.ZERO) -> void:
	hog._pending_teleport = pos
	hog._pending_velocity = vel
	await frames(3)


func _initialize() -> void:
	ToyScores.enabled = false
	Game3D.level = 1
	level = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(level)
	await frames(2)
	hog = level.hog
	await frames(60)
	level.hit_stop_enabled = false
	level.start_run()
	await run()
	print("---- %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func run() -> void:
	check(hog.grounded, "hog settles and is grounded on the forest start (pos %s)" % hog.global_position)
	check(absf(hog.global_position.y - Hog3D.RADIUS) < 0.05, "resting height matches the sphere radius (y=%.3f)" % hog.global_position.y)
	check(absf(hog.global_position.z) < 0.001, "hog stays on the z = 0 plane (z=%.4f)" % hog.global_position.z)

	hold("move_right", true)
	var caught := false
	for i in 900:
		await physics_frame
		if hog.bounce_count > 0:
			caught = true
			break
	hold("move_right", false)
	check(caught, "walks off the forest ledge and is caught by the cave mushroom (pos %s)" % hog.global_position)
	check(not hog.ko, "survives the long fall (no KO)")
	hold("move_left", true)
	await frames(200)
	hold("move_left", false)
	await frames(200)
	check(hog.grounded and hog.global_position.y < CAVE + 0.5, "settles on the cave floor (pos %s)" % hog.global_position)

	await place(Vector3(-3.0, CAVE + 0.32, 0.0))
	await frames(40)
	hold("move_right", true)
	await frames(90)
	var run_speed := hog.linear_velocity.x
	check(run_speed > 3.4 and run_speed < 4.7, "plush runs at ~4.4 m/s (got %.2f)" % run_speed)
	hold("move_right", false)
	await frames(45)
	check(absf(hog.linear_velocity.x) < 0.3, "plush stops quickly when input is released (vx=%.2f)" % hog.linear_velocity.x)

	await place(Vector3(-3.0, CAVE + 0.32, 0.0))
	await frames(40)
	var start_y := hog.global_position.y
	hold("jump", true)
	var top := start_y
	for i in 60:
		await physics_frame
		top = maxf(top, hog.global_position.y)
	hold("jump", false)
	var held := top - start_y
	check(held > 1.8 and held < 2.6, "held jump is %.2f m" % held)
	await frames(60)
	start_y = hog.global_position.y
	hold("jump", true)
	await frames(2)
	hold("jump", false)
	top = start_y
	for i in 60:
		await physics_frame
		top = maxf(top, hog.global_position.y)
	check(top - start_y < held * 0.6 and top - start_y > 0.2, "tap hop (%.2f) is shorter than a held jump (%.2f)" % [top - start_y, held])
	await frames(40)

	hold("spike", true)
	await frames(5)
	check(hog.curled, "holding spike curls into a ball")
	hold("move_right", true)
	await frames(60)
	check(hog.linear_velocity.x > 2.0, "curled ball rolls right (vx=%.2f)" % hog.linear_velocity.x)
	hold("move_right", false)
	hold("spike", false)
	await frames(60)

	# the ramp: walk over the hill plateau
	await place(Vector3(7.0, CAVE + 0.32, 0.0))
	await frames(30)
	hold("move_right", true)
	var peak := -100.0
	for i in 240:
		await physics_frame
		peak = maxf(peak, hog.global_position.y)
	hold("move_right", false)
	check(peak > CAVE + 2.0, "plush climbs the hill (peak y=%.2f, plateau is %.2f)" % [peak, CAVE + 2.4])

	# mushroom bounce on the cave catch mushroom
	await place(Vector3(3.6, CAVE + 3.0, 0.0))
	var bounces := hog.bounce_count
	await frames(60)
	check(hog.bounce_count > bounces, "falling onto a mushroom bounces the hog")

	# thorns
	var pit_x := 24.5
	await place(Vector3(pit_x, CAVE - 3.0, 0.0))
	var kos := hog.kos
	await frames(120)
	check(hog.kos > kos, "plush falling onto the thorns is knocked out (kos %d)" % hog.kos)
	await frames(120)
	check(not hog.ko, "knocked-out hog respawns from the checkpoint (pos %s)" % hog.global_position)
	hog._grace_until = 0
	hold("spike", true)
	await frames(4)
	await place(Vector3(pit_x, CAVE - 5.0, 0.0))
	kos = hog.kos
	await frames(40)
	hold("spike", false)
	check(hog.kos == kos, "curled hog shrugs off the thorns")

	# the beetle patrolling at x = 7.4
	var bugs := level.find_children("*", "Area3D", true, false).filter(func(n: Node) -> bool: return n is Gadgets3D.Bug)
	check(bugs.size() == 3, "level 1 has 3 beetles (got %d)" % bugs.size())
	print("---- done")
