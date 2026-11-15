extends SceneTree

# Screenshots for visual review: godot --path . --script res://tests/shots.gd
# Needs a real window (not --headless). Writes PNGs to OUT.

const OUT := "/private/var/folders/8l/lft66k717zz52l7lh2y7pkdw0000gn/T/opencode/shots/"

var main: Node
var player: Player


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")


func put(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.camera.reset_smoothing()
	await frames(30)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	player = main.get_node("World/Player")
	await frames(20)
	await shot("01_title")
	main.start_game()
	await frames(40)
	await shot("02_overworld")
	await put(Vector2(640, 2800))
	await shot("03_cave_floor")
	await put(Vector2(2380, 2800))
	await shot("04_shaft")
	await put(Vector2(2090, 2040))
	await shot("05_shaft_exit")
	await put(Vector2(1180, 1680))
	await shot("06_mushroom_a")
	await put(Vector2(1000, 1050))
	await shot("07_b_section")
	await put(Vector2(1790, 430))
	await shot("08_master")
	await put(Vector2(2260, 0))
	await shot("09_forest")
	await put(Vector2(1040, 2800))
	await frames(30)
	await shot("09b_beetle_tip")
	main.run_time = 143.7
	main.deaths = 3
	main.hud.set_time(main.run_time)
	main.persist_best = false
	main._set_paused(true)
	await shot("09c_pause")
	main._set_paused(false)
	main._win()
	await frames(80)
	await shot("10_win")
	quit(0)
