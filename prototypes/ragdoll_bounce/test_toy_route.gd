extends SceneTree

# A bot plays a whole level with real key presses, hazards live, no teleporting after the start.
# godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy_route.gd -- <level> <start delay frames>
const CAVE := 1100.0
const MAX_FRAMES := 14400

var level: Node
var hog: ToyHog
var beetles: Array = []
var master: ToyMushroom
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
	Toy.level = which
	level = load("res://prototypes/ragdoll_bounce/toy.tscn").instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	hog = level.hog
	level.hit_stop_enabled = false
	var x0: float = level.tower_x0
	var mushrooms: Array = []
	for c in level.get_children():
		if c is ToyBeetle:
			beetles.append(c)
		elif c is ToyMushroom:
			if c.master:
				master = c
			else:
				mushrooms.append(c)
	mushrooms.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	var tower: Array = mushrooms.filter(func(m: Node2D) -> bool: return m.global_position.x > x0 + 100.0 and m.global_position.x < x0 + 1000.0)
	tower.append(master)
	zones.append([x0 - 100.0, x0 + 1640.0, tower])
	if which == 2:
		zones.append([2900.0, 3600.0, mushrooms.filter(func(m: Node2D) -> bool: return m.global_position.x == 3250.0)])
		zones.append([7550.0, 9350.0, mushrooms.filter(func(m: Node2D) -> bool: return m.global_position.x > 7700.0 and m.global_position.x < 9200.0)])
	for z in zones:
		targets.append(0)
	for i in 90:
		await physics_frame
	level.start_run()
	hog._pending_teleport = Vector2(100.0, CAVE - 40.0)
	hog._pending_velocity = Vector2.ZERO
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
			var bucket := int(hog.global_position.x / 100.0) * 100
			ko_spots[bucket] = int(ko_spots.get(bucket, 0)) + 1
		if hog.bounce_count != last_bounces:
			last_bounces = hog.bounce_count
			if zone >= 0 and targets[zone] < zones[zone][2].size():
				var aimed: Node2D = zones[zone][2][targets[zone]]
				if absf(hog.global_position.x - aimed.global_position.x) < 110.0:
					targets[zone] += 1
	for a in ["move_left", "move_right", "jump", "spike"]:
		hold(a, false)
	var won: bool = level.state == level.State.WON
	if not ko_spots.is_empty():
		print("knock-outs by x: ", ko_spots)
	print("%s  level %d delay %3d: %s in %.1fs, KOs %d, bounces %d (furthest x=%.0f of %.0f)" % ["WIN " if won else "FAIL", which, delay, "finished" if won else "did not finish", frame / 60.0, hog.kos, hog.bounce_count, best_x, level.world_end])
	quit(0 if won else 1)


func _zone_of(x: float) -> int:
	for i in zones.size():
		if x >= zones[i][0] and x <= zones[i][1] and hog.global_position.y > CAVE - 700.0:
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
			if dx > -80.0 and dx < 260.0 and absf(b.global_position.y - hog.global_position.y) < 120.0:
				curl = true
	hold("spike", curl)
	if zone < 0 or targets[zone] >= zones[zone][2].size() and zone != zones.size() - 1 and false:
		_walk()
		return
	var chain: Array = zones[zone][2]
	if targets[zone] >= chain.size():
		_walk()
		return
	var goal: Node2D = chain[targets[zone]]
	var dx := goal.global_position.x - x
	hold("move_right", dx > 30.0)
	hold("move_left", dx < -30.0)
	_jump_phase = (_jump_phase + 1) % 24
	hold("jump", _jump_phase < 14)


func _walk() -> void:
	hold("move_right", true)
	hold("move_left", false)
	var blocked := hog.grounded and absf(hog.linear_velocity.x) < 60.0
	_stuck = _stuck + 1 if blocked else 0
	hold("jump", _stuck > 8 and (_stuck / 10) % 2 == 0)
