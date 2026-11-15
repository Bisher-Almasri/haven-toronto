extends SceneTree

const OUT := "/private/var/folders/8l/lft66k717zz52l7lh2y7pkdw0000gn/T/opencode/toy/"
const C := 1100.0
var level: Node
var hog: ToyHog

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func shot(n: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")

func put(p: Vector2) -> void:
	hog._pending_teleport = p
	hog._pending_velocity = Vector2.ZERO
	await frames(3)
	level.camera.global_position = p
	await frames(40)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var scenario := args[0]
	if args.size() > 1:
		Toy.level = int(args[1])
	ToyScores.path = "user://shots_scores_%s.cfg" % scenario
	for e in [["MAYA", 71.2, 1], ["LIAM", 84.0, 3], ["SOPHIE", 96.5, 0]]:
		ToyScores.add(e[0], e[1], e[2])
	level = load("res://prototypes/ragdoll_bounce/toy.tscn").instantiate()
	root.add_child(level)
	await frames(2)
	hog = level.hog
	level.hit_stop_enabled = false
	await frames(30)
	if scenario == "title":
		pass
	else:
		level.start_run()
		await frames(20)
	if scenario == "combo":
		await put(Vector2(3180, C + 120))
		level.hud.show_hint(0.0)
		level.hud.set_kos(2)
	elif scenario.begins_with("at"):
		var parts := scenario.substr(2).split("_")
		await put(Vector2(float(parts[0]), float(parts[1])))
		level.hud.show_hint(0.0)
		if parts.size() > 2:
			level._release_boulders()
	elif scenario == "pause":
		await put(Vector2(1000, 1000))
		level._set_paused(true)
	elif scenario == "ko":
		await put(Vector2(3180, C + 120))
		level._on_knocked_out()
	elif scenario == "win" or scenario == "board":
		level.run_time = 69.4
		level.hog.kos = 1
		level._on_goal()
		await create_timer(1.8).timeout
		if scenario == "board":
			level._name = "ZED"
			level._submit_name()
	await create_timer(0.6).timeout
	await shot(scenario)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ToyScores.path))
	quit(0)
