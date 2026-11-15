extends SceneTree

# Renders the 3D game in a real window and saves PNGs.
# godot --path . --script res://game3d/tests/shots3d.gd -- <level> <out dir> <x_m,y_m;x_m,y_m...>
# Each point teleports the hog there, waits a moment, then saves a screenshot.

var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var which := int(args[0]) if args.size() > 0 else 1
	var out := args[1] if args.size() > 1 else "/tmp"
	var points: Array = []
	if args.size() > 2:
		for chunk in args[2].split(";"):
			var xy := chunk.split(",")
			points.append(Vector2(float(xy[0]), float(xy[1])))
	ToyScores.enabled = false
	Game3D.level = which
	Game3D.skip_title = OS.get_environment("TITLE") == ""
	game = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	_save(out, "start")
	var n := 0
	for p: Vector2 in points:
		var hog: Hog3D = game.hog
		hog.global_position = Vector3(p.x, p.y, 0.0)
		hog.linear_velocity = Vector3.ZERO
		for i in 4:
			await physics_frame
		game.camera.snap()
		for i in 50:
			await process_frame
		_save(out, "p%d" % n)
		n += 1
	quit()


func _save(out: String, label: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, label])
	print("saved ", label, " ", img.get_size())
