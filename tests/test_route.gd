extends SceneTree

# Route reachability: godot --headless --path . --script res://tests/test_route.gd [-- hop_index]
# For each hop on the climb, brute-forces simple input timings (run, jump after k frames,
# hold or tap) and reports how many succeed. A hop with 0 successes is unreachable.

var main: Node
var player: Player
var failures := 0

# [label, start platform, start x, target platform, target-top y]
const HOPS := [
	["ShaftExit -> A1", "ShaftExit", 2150.0, "A1"],
	["A1 -> A2", "A1", 1840.0, "A2"],
	["A2 -> A3", "A2", 1480.0, "A3"],
	["A3 -> B1 (mushroom A)", "A3", 920.0, "B1"],
	["B1 -> B2", "B1", 1630.0, "B2"],
	["B2 -> B3", "B2", 1380.0, "B3"],
	["B3 -> B4", "B3", 880.0, "B4"],
	["B4 -> B5", "B4", 1430.0, "B5"],
	["B5 -> MasterLedge (mushroom B)", "B5", 1600.0, "MasterLedge"],
]


func plat(n: String) -> Platform:
	return main.get_node("World/Platforms/" + n)


func hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "spike"]:
		Input.action_release(a)


func _initialize() -> void:
	var only := -1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		only = int(args[0])
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	player = main.get_node("World/Player")
	for b in main.get_node("World/Enemies").get_children():
		b.queue_free()
	await physics_frame
	await physics_frame
	main.start_game()
	for i in 30:
		await physics_frame
	for i in HOPS.size():
		if only < 0 or only == i:
			await try_hop(HOPS[i])
	print("---- %d unreachable hop(s)" % failures)
	quit(1 if failures > 0 else 0)


func try_hop(hop: Array) -> void:
	var src := plat(hop[1])
	var dst := plat(hop[3])
	var dst_top := dst.global_position.y
	var dst_x0 := dst.global_position.x
	var dst_x1 := dst_x0 + dst.size.x
	var dir := signf((dst_x0 + dst_x1) * 0.5 - float(hop[2]))
	var wins := 0
	var total := 0
	for k in range(0, 41, 4):
		for hold_frames in [200, 14, 6]:
			total += 1
			player.global_position = Vector2(hop[2], src.global_position.y)
			player.velocity = Vector2.ZERO
			player._invuln_ticks = 0
			release_all()
			for i in 6:
				await physics_frame
			var ok := false
			var seen_air := false
			for f in 150:
				hold("move_right", dir > 0.0)
				hold("move_left", dir < 0.0)
				hold("jump", f >= k and f < k + hold_frames)
				await physics_frame
				if not player.is_on_floor():
					seen_air = true
				if hop[3] == "MasterLedge" and player.launching:
					ok = true
					break
				if seen_air and player.is_on_floor() and absf(player.global_position.y - dst_top) < 2.0 \
						and player.global_position.x > dst_x0 and player.global_position.x < dst_x1:
					ok = true
					break
			if ok:
				wins += 1
	release_all()
	var result := "OK  " if wins > 0 else "FAIL"
	if wins == 0:
		failures += 1
	print("%s %s: %d / %d timings succeed" % [result, hop[0], wins, total])
