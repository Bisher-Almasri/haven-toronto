extends SceneTree

# A bot plays a whole level with real key presses, hazards live, no teleporting after the start.
# godot --headless --path . --script res://game3d/tests/route3d.gd -- <level> <start delay frames>
const CAVE := -11.0
const MAX_FRAMES := 14400

var level: Node
var hog: Hog3D
var beetles: Array = []
var master: Gadgets3D.Shroom
# bounce zones: [x_from, x_to, [mushrooms to chain through, in order]]
var zones: Array = []
var targets: Array = []
var _jump_phase := 0
var _stuck := 0


func hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _initialize() -> void:
	ToyScores.enabled = false
	var args := OS.get_cmdline_user_args()
	var which := int(args[0]) if args.size() > 0 else 1
	var delay := int(args[1]) if args.size() > 1 else 0
	Game3D.level = which
	level = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	hog = level.hog
	level.hit_stop_enabled = false
	var x0: float = level.tower_x0 * 0.01
	var mushrooms: Array = []
	for c in level.get_children():
		if c is Gadgets3D.Bug:
			beetles.append(c)
		elif c is Gadgets3D.Shroom:
			if c.master:
				master = c
			else:
				mushrooms.append(c)
	mushrooms.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	var tower: Array = mushrooms.filter(func(m: Node3D) -> bool: return m.global_position.x > x0 + 1.0 and m.global_position.x < x0 + 10.0)
	tower.append(master)
	zones.append([x0 - 1.0, x0 + 16.4, tower])
	if which == 2:
		zones.append([29.0, 36.0, mushrooms.filter(func(m: Node3D) -> bool: return is_equal_approx(m.global_position.x, 32.5))])
		zones.append([75.5, 93.5, mushrooms.filter(func(m: Node3D) -> bool: return m.global_position.x > 77.0 and m.global_position.x < 92.0)])
	for z in zones:
		targets.append(0)
	for i in 90:
		await physics_frame
	level.start_run()
	hog._pending_teleport = Vector3(1.0, CAVE + 0.4, 0.0)
	hog._pending_velocity = Vector3.ZERO
	for i in 60 + delay:
		await physics_frame

	var last_bounces := hog.bounce_count
	var last_kos := 0
	var ko_spots := {}
	var frame := 0
	var best_x := 0.0
	while frame < MAX_FRAMES and level.state != level.State.WON:
		frame += 1
		var zone := _zone_of(hog.global_position.x)
		_drive(zone)
		await physics_frame
		best_x = maxf(best_x, hog.global_position.x)
		if hog.kos != last_kos:
			last_kos = hog.kos
			var bucket := int(hog.global_position.x)
			ko_spots[bucket] = int(ko_spots.get(bucket, 0)) + 1
		if hog.bounce_count != last_bounces:
			last_bounces = hog.bounce_count
			if zone >= 0 and targets[zone] < zones[zone][2].size():
				var aimed: Node3D = zones[zone][2][targets[zone]]
				if absf(hog.global_position.x - aimed.global_position.x) < 1.1:
					targets[zone] += 1
	for a in ["move_left", "move_right", "jump", "spike"]:
		hold(a, false)
	var won: bool = level.state == level.State.WON
	if not ko_spots.is_empty():
		print("knock-outs by x (m): ", ko_spots)
	print("%s  level %d delay %3d: %s in %.1fs, KOs %d, bounces %d (furthest x=%.1f of %.1f)" % ["WIN " if won else "FAIL", which, delay, "finished" if won else "did not finish", frame / 60.0, hog.kos, hog.bounce_count, best_x, level.world_end * 0.01])
	quit(0 if won else 1)


func _zone_of(x: float) -> int:
	for i in zones.size():
		if x >= zones[i][0] and x <= zones[i][1] and hog.global_position.y < CAVE + 7.0:
			return i
	return -1


func _drive(zone: int) -> void:
	if hog.ko:
		for a in ["move_left", "move_right", "jump", "spike"]:
			hold(a, false)
		return
	var x := hog.global_position.x
	var curl := false
	for b in beetles:
		if is_instance_valid(b) and not b._dying:
			var dx: float = b.global_position.x - x
			if dx > -0.8 and dx < 2.6 and absf(b.global_position.y - hog.global_position.y) < 1.2:
				curl = true
	hold("spike", curl)
	if zone < 0:
		_walk()
		return
	var chain: Array = zones[zone][2]
	if targets[zone] >= chain.size():
		_walk()
		return
	var goal: Node3D = chain[targets[zone]]
	var dx := goal.global_position.x - x
	hold("move_right", dx > 0.3)
	hold("move_left", dx < -0.3)
	_jump_phase = (_jump_phase + 1) % 24
	hold("jump", _jump_phase < 14)


func _walk() -> void:
	hold("move_right", true)
	hold("move_left", false)
	var blocked := hog.grounded and absf(hog.linear_velocity.x) < 0.6
	_stuck = _stuck + 1 if blocked else 0
	hold("jump", _stuck > 8 and (_stuck / 10) % 2 == 0)
