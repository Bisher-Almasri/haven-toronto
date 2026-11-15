extends SceneTree

# Renders the Level 1 cutscene in a real window and saves PNGs at the given times (seconds).
# godot --path . --script res://game3d/tests/shots_intro.gd -- <out dir> <t1,t2,...>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var times: Array = []
	for t in (args[1] if args.size() > 1 else "2,5,8,12,16,20,24,28,32").split(","):
		times.append(float(t))
	ToyScores.enabled = false
	Game3D.level = 1
	Game3D.skip_title = false
	var game: Node = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(game)
	for i in 20:
		await process_frame
	game.play_intro()
	var start := Time.get_ticks_msec() * 0.001
	for t: float in times:
		while Time.get_ticks_msec() * 0.001 - start < t:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/t%02d.png" % [out, int(t)])
		print("saved t=", t, " state=", game.state)
	quit()
