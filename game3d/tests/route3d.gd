extends SceneTree

# A bot plays a whole level with real key presses, hazards live, no teleporting after the start.
# godot --headless --path . --script res://game3d/tests/route3d.gd -- <level> <start delay frames>
const CAVE := -11.0
const MAX_FRAMES := 14400 # 4 minutes

var level: Node
var hog: Hog3D
var beetles: Array = []
var brambles: Array = []
var master: Gadgets3D.Shroom
# bounce zones: [x_from, x_to, [mushrooms to chain through, in order]]
var zones: Array = []
var targets: Array = []
var debug := false
var _jump_phase := 0
var _stuck := 0
var _progress_x := 0.0


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
	debug = args.size() > 2
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
		elif c is Gadgets3D.Bramble:
			brambles.append(c)
		elif c is Gadgets3D.Shroom:
			if c.master:
				master = c
			else:
				mushrooms.append(c)
	mushrooms.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	var tower: Array = mushrooms.filter(func(m: Node3D) -> bool: return m.global_position.x > x0 + 1.0 and m.global_position.x < x0 + 10.0)
	tower.append(master)
	zones.append([x0 - 1.0, x0 + 16.4, tower])
	for zone: Array in level.bounce_zones:
		var from_x: float = zone[0] * 0.01
		var to_x: float = zone[1] * 0.01
		zones.append([from_x, to_x, mushrooms.filter(func(m: Node3D) -> bool: return m.global_position.x > from_x and m.global_position.x < to_x)])
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
		if debug and (frame % 120 == 0 or hog.ko and frame % 6 == 0):
			print("ko %s stuck %d jump %s t=%.0fs pos (%.2f, %.2f) vel (%.2f, %.2f) curled %s grounded %s zone %d" % [hog.ko, _stuck, Input.is_action_pressed("jump"), frame / 60.0, hog.global_position.x, hog.global_position.y, hog.linear_velocity.x, hog.linear_velocity.y, hog.curled, hog.grounded, zone])
			if frame % 1200 == 0:
				for n in level.find_children("*", "RigidBody3D", true, false):
					if absf(n.global_position.x - hog.global_position.x) < 6.0:
						print("   near: ", n.name, n.get_class(), n.global_position, n.rotation.z if not (n is Hog3D) else "", " frozen" if n.freeze else "")
				print("   ko ", hog.ko, " active ", hog.active, " pendulum/seesaw count ", level.find_children("*", "HingeJoint3D", true, false).size())
		best_x = maxf(best_x, hog.global_position.x)
		if hog.kos != last_kos:
			last_kos = hog.kos
			var bucket := int(hog.global_position.x)
			ko_spots[bucket] = int(ko_spots.get(bucket, 0)) + 1
		if hog.bounce_count != last_bounces:
			last_bounces = hog.bounce_count
			if debug:
				print("BOUNCE at (%.2f, %.2f) zone %d target %d  t=%.1f" % [hog.global_position.x, hog.global_position.y, zone, targets[zone] if zone >= 0 else -1, frame / 60.0])
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
			if dx > -0.8 and dx < 1.8 and absf(b.global_position.y - hog.global_position.y) < 1.2:
				curl = true
	for b in brambles:
		var dx: float = b.global_position.x - x
		if dx > -1.0 and dx < 1.8:
			curl = true
	for shower in level._showers:
		for b in shower["boulders"]:
			if is_instance_valid(b) and not b.freeze and absf(b.global_position.x - x) < 6.0 and b.global_position.y - hog.global_position.y < 12.0:
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
	# no progress for a few frames: jump and hold it (a full hop clears a seesaw end that rests tilted up)
	var x := hog.global_position.x
	if x > _progress_x + 0.05:
		_progress_x = x
		_stuck = 0
	else:
		_stuck += 1
	hold("jump", _stuck > 12 and _stuck % 45 < 35)
