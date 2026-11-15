extends SceneTree

# Boulders crush a plush hedgehog but a spike ball bounces off them, brambles stop plush only,
# bounce chains lift you higher, and a boulder shower resets after a KO.
# godot --headless --path . --script res://game3d/tests/test_hazards3d.gd
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


func reset_hog() -> void:
	for a in ["move_left", "move_right", "jump", "spike"]:
		hold(a, false)
	hog._grace_until = 0
	if hog.ko:
		await frames(90)
	hog._grace_until = 0


func drop_boulder(x: float, y: float) -> Gadgets3D.Boulder:
	var b := Gadgets3D.Boulder.new()
	b.position = Vector3(x, y, 0.0)
	level.add_child(b)
	return b


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
	# a falling boulder crushes a plush hedgehog
	await place(Vector3(-3.0, CAVE + 0.32, 0.0))
	await frames(30)
	hog._grace_until = 0
	var kos := hog.kos
	var boulder := drop_boulder(-3.0, CAVE + 7.0)
	await frames(100)
	check(hog.kos == kos + 1, "falling boulder crushes plush hedgehog (kos %d)" % hog.kos)
	boulder.queue_free()
	await reset_hog()

	# ...but a spike ball bounces off it
	await place(Vector3(-3.0, CAVE + 0.32, 0.0))
	hold("spike", true)
	await frames(30)
	hog._grace_until = 0
	kos = hog.kos
	var chain := hog.chain
	boulder = drop_boulder(-3.0, CAVE + 7.0)
	var peak := -100.0
	for i in 100:
		await physics_frame
		peak = maxf(peak, hog.global_position.y)
	check(hog.kos == kos, "spike ball is not hurt by a falling boulder")
	check(hog.chain > chain, "spike ball rebounds off the boulder (chain %d)" % hog.chain)
	check(peak > CAVE + 1.5, "the rebound throws the spike ball up (peak %.2f)" % peak)
	boulder.queue_free()
	hold("spike", false)
	await reset_hog()
	await frames(60)

	# a boulder that is merely touched does not hurt
	await place(Vector3(-3.0, CAVE + 0.32, 0.0))
	var rest := drop_boulder(-2.2, CAVE + 0.5)
	await frames(90)
	hog._grace_until = 0
	kos = hog.kos
	hold("move_right", true)
	await frames(60)
	hold("move_right", false)
	check(hog.kos == kos, "touching a resting boulder is harmless")
	rest.queue_free()
	await reset_hog()

	# bramble: plush is knocked out, a spike ball rolls through
	var bramble_x := 21.5
	var ground := -(Game3D.CAVE + 40.0) * Game3D.S
	await place(Vector3(bramble_x - 2.0, ground + 0.32, 0.0))
	await frames(40)
	hog._grace_until = 0
	kos = hog.kos
	hold("move_right", true)
	await frames(120)
	hold("move_right", false)
	check(hog.kos > kos, "plush hedgehog is knocked out by the bramble (kos %d)" % hog.kos)
	await reset_hog()
	await place(Vector3(bramble_x - 2.0, ground + 0.32, 0.0))
	hold("spike", true)
	await frames(20)
	hog._grace_until = 0
	kos = hog.kos
	hold("move_right", true)
	await frames(120)
	hold("move_right", false)
	hold("spike", false)
	check(hog.kos == kos and hog.global_position.x > bramble_x + 0.8, "spike ball rolls straight through the bramble (x=%.2f)" % hog.global_position.x)
	await reset_hog()

	# bounce chains and the spike ball bounce higher
	hog.curled = false
	hog.chain = 4
	var plain := hog.bounce_bonus()
	hog.chain = 0
	hog.curled = true
	var curled := hog.bounce_bonus()
	hog.chain = 4
	var chained := hog.bounce_bonus()
	hog.curled = false
	hog.chain = 0
	check(plain == 1.0 and curled > plain and chained > curled, "bounce bonus: plush %.2f < spike %.2f < spike + chain %.2f" % [plain, curled, chained])

	# dying on the way to the boulder shower sets it up again
	var shower: Dictionary = level._showers[0]
	level._release_boulders(shower)
	await frames(30)
	var released: int = shower["boulders"].filter(func(b: Node) -> bool: return is_instance_valid(b) and not b.freeze).size()
	check(released > 0, "the shower is released (%d boulders falling)" % released)
	hog.respawn_point = Vector3(13.2, CAVE + 2.0, 0.0)
	level._on_hog_respawned()
	await frames(2)
	var armed: int = shower["boulders"].filter(func(b: Node) -> bool: return is_instance_valid(b) and b.freeze).size()
	check(armed == shower["xs"].size(), "a respawn before the shower re-arms it (%d/%d boulders waiting)" % [armed, shower["xs"].size()])

	# the real shower on the hill: walking through as plush gets you crushed, rolling through does not
	for curled_run in [false, true]:
		await reset_hog()
		level._load_shower(level._showers[0])
		await frames(5)
		var plateau := -(Game3D.CAVE - 240.0) * Game3D.S
		await place(Vector3(13.0, plateau + 0.32, 0.0))
		await frames(30)
		hog._grace_until = 0
		kos = hog.kos
		hold("spike", curled_run)
		hold("move_right", true)
		await frames(420)
		hold("move_right", false)
		hold("spike", false)
		if curled_run:
			check(hog.kos == kos and hog.global_position.x > 19.0, "rolling through the boulder shower is safe (x=%.1f)" % hog.global_position.x)
		else:
			check(hog.kos > kos, "walking through the boulder shower as plush gets you crushed (kos %d)" % (hog.kos - kos))
