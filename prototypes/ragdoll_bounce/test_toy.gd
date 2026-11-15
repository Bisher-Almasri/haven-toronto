extends SceneTree

# godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy.gd
const CAVE := 1100.0
var failures := 0
var level: Node
var hog: ToyHog


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


func place(pos: Vector2, vel := Vector2.ZERO) -> void:
	hog._pending_teleport = pos
	hog._pending_velocity = vel
	await frames(3)


func find(type_name: String) -> Array:
	var out := []
	for c in level.get_children():
		if c.get_script() and c.get_script().get_global_name() == type_name:
			out.append(c)
	return out


func _initialize() -> void:
	ToyScores.enabled = false
	level = load("res://prototypes/ragdoll_bounce/toy.tscn").instantiate()
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
	check(absf(hog.global_position.y - (0.0 - ToyHog.RADIUS)) < 4.0, "resting height matches the circle radius (y=%.1f)" % hog.global_position.y)

	# walk off the forest ledge, fall ~1100 px, get caught by the landing mushroom
	hold("move_right", true)
	var caught := false
	for i in 900:
		await physics_frame
		if hog.global_position.y > CAVE - 80.0 and hog.global_position.y < CAVE + 5.0 and hog.linear_velocity.y < 0.0:
			caught = true
			hold("move_right", false)
			break
	hold("move_right", false)
	check(caught, "walks off the forest ledge and is caught by the cave mushroom (pos %s)" % hog.global_position)
	check(not hog.ko, "survives the long fall (no KO)")
	hold("move_left", true)
	await frames(80)
	hold("move_left", false)
	await frames(80)
	check(hog.grounded and hog.global_position.y > CAVE - 40.0, "settles on the cave floor (pos %s)" % hog.global_position)

	# basic movement on the flat cave floor
	await place(Vector2(-300, CAVE - 32.0))
	await frames(40)
	hold("move_right", true)
	await frames(90)
	var run_speed := hog.linear_velocity.x
	check(run_speed > 340.0 and run_speed < 470.0, "plush runs at ~440 px/s (got %.0f)" % run_speed)
	hold("move_right", false)
	await frames(45)
	check(absf(hog.linear_velocity.x) < 30.0, "plush stops quickly when input released (vx=%.0f)" % hog.linear_velocity.x)
	await place(Vector2(-300, CAVE - 32.0))
	await frames(40)
	var start_y := hog.global_position.y
	hold("jump", true)
	var top := start_y
	for i in 60:
		await physics_frame
		top = minf(top, hog.global_position.y)
	hold("jump", false)
	var held := start_y - top
	check(held > 180.0 and held < 260.0, "jump height %.0f px (hold)" % held)
	await frames(60)
	start_y = hog.global_position.y
	hold("jump", true)
	await frames(2)
	hold("jump", false)
	top = start_y
	for i in 60:
		await physics_frame
		top = minf(top, hog.global_position.y)
	check(start_y - top < held * 0.6 and start_y - top > 20.0, "tap hop (%.0f) is shorter than a held jump (%.0f)" % [start_y - top, held])
	await frames(40)

	hold("spike", true)
	await frames(5)
	check(hog.curled, "holding spike curls into a ball")
	hold("spike", false)
	await frames(10)

	# the ramp: plush can walk over the plateau without help
	await place(Vector2(700, CAVE - 32.0))
	await frames(30)
	hold("move_right", true)
	var top_x := 0.0
	var plateau := false
	for i in 400:
		await physics_frame
		if hog.global_position.y < CAVE - 240.0 and hog.global_position.x > 1250.0:
			plateau = true
			break
	hold("move_right", false)
	check(plateau, "plush climbs the ramp onto the plateau (pos %s)" % hog.global_position)

	# boulder shower triggers once and cleans itself up
	var boulders := get_nodes_in_group(&"boulders")
	check(boulders.size() == 4, "four boulders wait above the downhill")
	var released := false
	for i in 120:
		await physics_frame
		for b in boulders:
			if is_instance_valid(b) and not b.freeze:
				released = true
	check(released, "crossing the plateau releases the boulders")
	await frames(60 * 9)
	var gone := true
	for b in boulders:
		if is_instance_valid(b):
			gone = false
	check(gone, "boulders are cleared away after the shower")
	await place(Vector2(0, CAVE - 32.0))
	await frames(40)

	# mushroom bounce on the landing pad
	var mushrooms := find("ToyMushroom")
	var pad: ToyMushroom = null
	for m in mushrooms:
		if m.global_position.x == 360.0:
			pad = m
	var cap_top := pad.global_position.y - pad._total_height()
	await place(Vector2(pad.global_position.x, cap_top - 180.0))
	var apex := 1e9
	var bounced := false
	for i in 200:
		await physics_frame
		if hog.linear_velocity.y < -200.0:
			bounced = true
		apex = minf(apex, hog.global_position.y)
		if bounced and hog.linear_velocity.y > 0.0:
			break
	check(bounced, "falling onto a mushroom bounces the hog")
	check(cap_top - apex > 250.0, "mushroom bounce rises %.0f px above the cap" % (cap_top - apex))
	await frames(100)

	# beetle: plush is KO'd, spike ball kills it
	var beetle: ToyBeetle = find("ToyBeetle")[0]
	beetle.speed = 0.0
	await place(beetle.global_position + Vector2(-40, -ToyHog.RADIUS - 4.0))
	await frames(40)
	check(hog.ko, "plush hog touching a beetle is knocked out")
	await frames(100)
	hold("spike", true)
	await frames(5)
	await place(beetle.global_position + Vector2(-30, -ToyHog.RADIUS - 4.0))
	await frames(20)
	check(not is_instance_valid(beetle) or beetle._dying, "spike ball kills the beetle")
	check(not hog.ko, "no KO while curled")
	hold("spike", false)
	await frames(30)

	# checkpoint mushroom on the far side of the pit, then thorns knock out and respawn there
	var cp: ToyMushroom = null
	for m in mushrooms:
		if m.global_position.x == 2780.0:
			cp = m
	await place(cp.global_position + Vector2(0, -_cp_height(cp) - 60.0))
	await frames(30)
	check(hog.respawn_point.distance_to(cp.global_position) < 200.0, "touching a checkpoint mushroom stores the respawn point")
	var thorns: ToyThorns = find("ToyThorns")[0]
	await place(thorns.global_position + Vector2(0, -60))
	await frames(30)
	check(hog.ko, "plush hog touching thorns is knocked out")
	await frames(90)
	check(not hog.ko, "hog respawns after the KO timer")
	check(absf(hog.global_position.x - cp.global_position.x) < 120.0 and hog.global_position.y < cp.global_position.y + 20.0, "respawns at the checkpoint (%s)" % hog.global_position)
	hold("spike", true)
	await frames(5)
	await place(thorns.global_position + Vector2(0, -60))
	await frames(20)
	check(not hog.ko, "spike ball is immune to thorns")
	hold("spike", false)
	await place(Vector2(-300, CAVE - 32.0))
	await frames(60)

	# seesaw tilts under weight
	var seesaw: ToySeesaw = find("ToySeesaw")[0]
	var plank: RigidBody2D = seesaw.get_child(1)
	var rest_rot := plank.rotation
	await place(seesaw.global_position + Vector2(150, -60))
	await frames(120)
	check(absf(plank.rotation - rest_rot) > 0.1, "seesaw tips under the hog's weight (rot %.2f)" % plank.rotation)
	check(hog.global_position.y < seesaw.global_position.y + 120.0, "hog stays on the seesaw instead of falling through (y=%.0f)" % hog.global_position.y)
	await place(Vector2(-300, CAVE - 32.0))
	await frames(30)

	# pendulum swings
	var pend: ToyPendulum = find("ToyPendulum")[0]
	var swinger: RigidBody2D = pend.get_child(1)
	var min_r := 9.0
	var max_r := -9.0
	for i in 240:
		await physics_frame
		min_r = minf(min_r, swinger.rotation)
		max_r = maxf(max_r, swinger.rotation)
	check(max_r - min_r > 1.0, "pendulum swings over the seesaw (%.2f to %.2f rad)" % [min_r, max_r])

	# master mushroom launches into the forest and the goal triggers
	var master: ToyMushroom = null
	for m in mushrooms:
		if m.master:
			master = m
	var cap := master.global_position.y - master._total_height()
	await place(Vector2(master.global_position.x, cap - 240.0))
	var reached := false
	var peak_y := 1e9
	for i in 480:
		await physics_frame
		peak_y = minf(peak_y, hog.global_position.y)
		if level.hud.won:
			reached = true
			break
	check(reached, "master mushroom launches the hog home and the goal triggers (pos %s)" % hog.global_position)
	check(peak_y < -300.0, "launch clears the forest floor (apex y=%.0f)" % peak_y)
	await frames(300)
	check(not hog.ko and absf(hog.global_position.y + ToyHog.RADIUS) < 6.0 and hog.global_position.x > 4650.0, "hog is standing on the home forest (pos %s)" % hog.global_position)

	# pendulum rope collision: freeze it hanging and run the hog into it at increasing speeds
	var rope: RigidBody2D = pend.get_child(1)
	rope.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	rope.freeze = true
	PhysicsServer2D.body_set_state(rope.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, pend.global_position))
	await frames(3)
	var saved_gravity := hog.gravity_scale
	hog.gravity_scale = 0.0
	for speed in [440.0, 1500.0, 3000.0]:
		hog._pending_teleport = pend.global_position + Vector2(-300.0, 200.0)
		hog._pending_velocity = Vector2(speed, 0.0)
		hog._ballistic = true
		await frames(3)
		var crossed := false
		for i in 120:
			await physics_frame
			if hog.global_position.x > pend.global_position.x + 40.0:
				crossed = true
				break
		check(not crossed, "rope blocks a hog moving at %d px/s" % int(speed))
	hog.gravity_scale = saved_gravity


func _cp_height(m: ToyMushroom) -> float:
	return m._total_height()
