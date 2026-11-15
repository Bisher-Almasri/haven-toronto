extends SceneTree

# Headless playtest: godot --headless --path . --script res://tests/test_game.gd
# Exits 0 when every check passes, 1 otherwise.

const FLOOR_Y := 2800.0

var failures := 0
var main: Node
var player: Player


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


func teleport(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player._invuln_ticks = 0
	await frames(2)


func node_pos(path: String) -> Vector2:
	return main.get_node("World/" + path).global_position


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.persist_best = false
	root.add_child(main)
	player = main.get_node("World/Player")
	await frames(2)
	await run()
	print("---- %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func run() -> void:
	# --- title
	check(player.is_on_floor(), "starts standing on the overworld grass")
	check(not player.input_enabled, "input locked on the title screen")
	main.start_game()
	await frames(30)
	check(player.input_enabled, "input unlocked after start")

	# --- fall into hole A (a long way down)
	hold("move_right", true)
	var fell := false
	for i in 600:
		await physics_frame
		if player.global_position.x > 520.0:
			hold("move_right", false)
		if player.global_position.y > FLOOR_Y - 50.0 and player.is_on_floor():
			fell = true
			break
	hold("move_right", false)
	check(fell, "walks into hole A and lands on the cave floor (y=%.0f, x=%.0f)" % [player.global_position.y, player.global_position.x])
	check(player.hp == player.max_hp, "no damage from the fall")
	await frames(20)

	# --- jump height and tap hop
	await teleport(Vector2(300, FLOOR_Y))
	await frames(10)
	var start_y := player.global_position.y
	hold("jump", true)
	await frames(1)
	var min_y := start_y
	for i in 60:
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
	hold("jump", false)
	var height := start_y - min_y
	check(height > 175.0 and height < 205.0, "full jump height %.0f px (target ~192)" % height)
	await frames(60)
	start_y = player.global_position.y
	hold("jump", true)
	await frames(2)
	hold("jump", false)
	min_y = start_y
	for i in 60:
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
	var hop := start_y - min_y
	check(hop < height * 0.6 and hop > 20.0, "tap hop %.0f px is shorter than full jump" % hop)
	await frames(40)

	# --- one-way ledge: rise through from below, stand on top (B4 top)
	var b4: Vector2 = node_pos("Platforms/B4")
	await teleport(Vector2(b4.x + 128.0, b4.y + 60.0))
	player.velocity.y = -900.0
	await frames(90)
	check(absf(player.global_position.y - b4.y) < 2.0 and player.is_on_floor(), "rises through one-way ledge B4 and stands on it (y=%.0f)" % player.global_position.y)

	# --- mushroom bounce
	var mush: Mushroom = main.get_node("World/Mushrooms/MushroomA")
	var cap_top := mush.global_position.y - mush._total_height()
	await teleport(Vector2(mush.global_position.x, cap_top - 130.0))
	var apex_y := 99999.0
	var bounced := false
	for i in 150:
		await physics_frame
		if player.velocity.y < -200.0:
			bounced = true
		apex_y = minf(apex_y, player.global_position.y)
		if bounced and player.velocity.y > 0.0:
			break
	var rise := cap_top - apex_y
	check(bounced, "falling onto mushroom A bounces the hedgehog")
	check(rise > 420.0 and rise < 470.0, "mushroom A bounce apex %.0f px above the cap (target 460, no hold)" % rise)
	await frames(120)
	await teleport(Vector2(mush.global_position.x, cap_top - 130.0))
	hold("jump", true)
	var apex_hold := 99999.0
	for i in 160:
		await physics_frame
		apex_hold = minf(apex_hold, player.global_position.y)
		if i > 20 and player.velocity.y > 0.0 and apex_hold < cap_top - 100.0:
			break
	hold("jump", false)
	check(cap_top - apex_hold > rise * 1.15, "holding jump gives a higher mushroom bounce (%.0f vs %.0f)" % [cap_top - apex_hold, rise])
	await frames(120)

	# --- beetle hurts a normal hedgehog and bounces him back
	var beetle: Beetle = main.get_node("World/Enemies/BeetleFloorA")
	await teleport(Vector2(beetle.global_position.x - 30.0, FLOOR_Y - 2.0))
	var hp_before := player.hp
	await frames(5)
	check(player.hp == hp_before - 1, "touching a beetle costs 1 heart")
	check(player.velocity.y < -200.0 or not player.is_on_floor(), "hit knocks the hedgehog back")
	await frames(10)
	check(player.hp == hp_before - 1, "invulnerability frames prevent double hits")
	await frames(150)

	# --- spike mode: rolling into a beetle kills it, no damage, no jump
	var hp_now := player.hp
	await teleport(Vector2(300, FLOOR_Y))
	await frames(100)
	hold("spike", true)
	await frames(3)
	check(player.spiked, "holding spike curls the hedgehog into a ball")
	await teleport(Vector2(beetle.global_position.x - 20.0, FLOOR_Y - 2.0))
	await frames(10)
	check(not is_instance_valid(beetle) or beetle._dying, "spike mode kills the beetle")
	await frames(30)
	check(not is_instance_valid(beetle), "dead beetle is removed from the level")
	check(player.hp == hp_now, "no damage while spiked")
	var y0 := player.global_position.y
	hold("jump", true)
	await frames(10)
	check(player.global_position.y >= y0 - 1.0, "cannot jump while in spike mode")
	hold("jump", false)
	hold("spike", false)
	await frames(60)

	# --- spike-drop pogo: curl mid-air, land on a beetle, bounce back up
	var beetle2: Beetle = main.get_node("World/Enemies/BeetleFloorB")
	beetle2.speed = 0.0
	await teleport(Vector2(beetle2.global_position.x, FLOOR_Y - 150.0))
	hold("spike", true)
	var best_up := 0.0
	var killed := false
	for i in 90:
		await physics_frame
		if not is_instance_valid(beetle2) or beetle2._dying:
			killed = true
		best_up = maxf(best_up, -player.velocity.y)
	hold("spike", false)
	check(killed, "spike-drop kills the beetle from above")
	check(best_up > 1000.0, "and bounces the hedgehog back up (peak up-speed %.0f)" % best_up)
	check(player.hp == hp_now, "no damage taken from the pogo")
	await frames(120)

	# --- springy root wall kicks the hedgehog back (single wall)
	var wall: BounceRoot = main.get_node("World/SpringRoots/SpringWallRight")
	await teleport(Vector2(wall.global_position.x - 80.0, FLOOR_Y))
	await frames(5)
	hold("move_right", true)
	var kicked := false
	for i in 60:
		await physics_frame
		if player.velocity.x < -500.0 and player.velocity.y < -800.0:
			kicked = true
			break
	hold("move_right", false)
	check(kicked, "walking into a springy wall flings the hedgehog up and back")
	await frames(120)

	# --- ricochet shaft: three kicks up to the shaft exit ledge
	var exit_ledge: Vector2 = node_pos("Platforms/ShaftExit")
	for mode in ["holding toward the next wall", "letting go after the first kick"]:
		await teleport(Vector2(wall.global_position.x - 230.0, FLOOR_Y))
		await frames(5)
		hold("move_right", true)
		var kicks := 0
		var last_vx := 0.0
		var landed := false
		for i in 600:
			await physics_frame
			if absf(player.velocity.x) > 600.0 and absf(last_vx) <= 600.0:
				kicks += 1
			last_vx = player.velocity.x
			if mode.begins_with("holding"):
				hold("move_left", player.velocity.x < 0.0)
				hold("move_right", player.velocity.x >= 0.0)
			elif kicks >= 1:
				hold("move_left", false)
				hold("move_right", false)
			if i > 60 and player.is_on_floor() and absf(player.global_position.y - exit_ledge.y) < 2.0:
				landed = true
				break
		hold("move_left", false)
		hold("move_right", false)
		check(kicks >= 3 and landed, "ricochet shaft (%s): %d kicks, lands on the exit ledge (x=%.0f, y=%.0f)" % [mode, kicks, player.global_position.x, player.global_position.y])
		await frames(30)

	# --- checkpoint, death and respawn
	var cp: Checkpoint = main.get_node("World/Checkpoints/CheckpointB1")
	await teleport(cp.global_position + Vector2(0, -4))
	await frames(5)
	check(player.respawn_point.distance_to(cp.global_position) < 4.0, "touching a checkpoint stores the respawn point")
	var beetle_b: Beetle = main.get_node("World/Enemies/BeetleB2")
	for i in 3:
		player._invuln_ticks = 0
		await teleport(beetle_b.global_position + Vector2(-10, -2))
		await frames(3)
	check(player.dead, "three hits kill the hedgehog")
	await frames(60 * 3)
	check(not player.dead and player.hp == player.max_hp, "respawns with full health")
	check(player.global_position.distance_to(cp.global_position) < 40.0, "respawns at the last checkpoint (%s)" % player.global_position)

	# --- master mushroom launch and landing in the forest
	await teleport(Vector2(1960, 300))
	var launched := false
	for i in 400:
		await physics_frame
		if player.launching:
			launched = true
		if launched and not player.launching:
			break
	check(launched, "master mushroom launches the hedgehog")
	check(main.state == main.State.WON, "game reaches the win state")
	var in_zone := player.global_position.x > 2110.0 and player.global_position.x < 2540.0
	check(absf(player.global_position.y) < 2.0 and in_zone, "lands on the forest grass beyond hole B (x=%.0f, y=%.0f)" % [player.global_position.x, player.global_position.y])
