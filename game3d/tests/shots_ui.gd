extends SceneTree

# Renders every UI screen in a real window and saves PNGs.
# godot --path . --script res://game3d/tests/shots_ui.gd -- <out dir>

var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	ToyScores.enabled = false
	Game3D.level = 1
	game = load("res://game3d/game3d.tscn").instantiate()
	root.add_child(game)
	for i in 60:
		await process_frame
	_save(out, "title")
	game.hud.set_best(11.4)
	game.start_run()
	for i in 60:
		await process_frame
	game.hud.set_time(7.3)
	game.hud.set_kos(2)
	game.hud.set_progress(0.45)
	for i in 30:
		await process_frame
	_save(out, "play")
	game.hud.show_pause(true)
	for i in 10:
		await process_frame
	_save(out, "pause")
	game.hud.show_pause(false)
	var scores := [{"name": "BISHER", "time": 11.4, "kos": 1}, {"name": "ANON", "time": 12.8, "kos": 0}, {"name": "ZED", "time": 14.9, "kos": 3}]
	game.hud.show_end(11.4, 2, 5, false, scores)
	for i in 60:
		await process_frame
	_save(out, "end")
	quit()


func _save(out: String, label: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, label])
	print("saved ", label)
