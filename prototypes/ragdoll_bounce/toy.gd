class_name Toy
extends Node2D

enum State { TITLE, PLAYING, WON }

# World layout: the autumn forest is at y = 0 and above; the cave is 1100 px below it.
const CAVE := 1100.0
const BOTTOM := 2400.0
const TRUNK := Color(0.36, 0.21, 0.11)
# mushroom tower: [x offset from the tower start, pillar top relative to CAVE]
const TOWER := [[150.0, -40.0], [400.0, -170.0], [650.0, -300.0], [900.0, -430.0]]
const SUMMIT := -470.0
# the bounce chasm in level 2: [x, island top relative to CAVE]
const CHASM := [[7800.0, 40.0], [8120.0, -60.0], [8440.0, 40.0], [8760.0, -100.0], [9080.0, 40.0]]
const IDLE_PLAYING := 60.0
const IDLE_WON := 40.0
const NAME_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."

static var skip_title := false
static var level := 1

var state := State.TITLE
var run_time := 0.0
var combo := 0
var best_combo := 0
var tower_x0 := 3000.0
var world_end := 5900.0
var hole_b := Vector2(3250.0, 4650.0)
var hog: ToyHog
var camera: ToyCamera
var hud: ToyHud
var audio: GameAudio

var _ground_time := 0.0
var _last_input := 0.0
var _entering_name := false
var _name := ""
var _end_ready := false
var _confetti_node: CPUParticles2D
var _lamps: Array = []
var _master_glow: Sprite2D
var _ghost: ToyGhost
var _trail: CPUParticles2D
var _rec := PackedFloat32Array()
var _frame := 0
var _prev_best := 0.0
var hit_stop_enabled := true
var _hit_stopping := false


func _ready() -> void:
	Engine.time_scale = 1.0
	ToyScores.level = level
	tower_x0 = 3000.0 if level == 1 else 11450.0
	world_end = tower_x0 + 2900.0
	hole_b = Vector2(tower_x0 + 250.0, tower_x0 + 1650.0)
	_build_backdrop()
	_build_sky()
	_build_beams()
	_build_terrain()
	_build_gadgets()
	_build_hog()
	_build_ui()
	_build_audio()
	_build_fx()
	_last_input = Time.get_ticks_msec() * 0.001
	if skip_title:
		skip_title = false
		start_run()
	else:
		hud.show_title(ToyScores.load_scores())


func start_run() -> void:
	if state != State.TITLE:
		return
	state = State.PLAYING
	run_time = 0.0
	_frame = 0
	_rec = PackedFloat32Array()
	hog.active = true
	hud.hide_title()
	hud.set_best(ToyScores.best())
	hud.show_hint(14.0)
	audio.play("start")


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	run_time += delta
	hud.set_time(run_time)
	hud.set_progress(clampf(hog.global_position.x / (tower_x0 + 1350.0), 0.0, 1.0))
	if _frame % ToyGhost.STEP == 0:
		_rec.append_array(PackedFloat32Array([hog.global_position.x, hog.global_position.y, hog.rotation, 1.0 if hog.curled else 0.0, hog.facing]))
	_frame += 1
	if _ghost:
		_ghost.show_at(_frame)
	if hog.grounded:
		_ground_time += delta
		if _ground_time > 0.45:
			combo = 0
	else:
		_ground_time = 0.0


func _process(_delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	for entry in _lamps:
		var lamp: Sprite2D = entry[1]
		lamp.visible = entry[0].active
		lamp.modulate.a = 0.7 + 0.3 * pulse
	if _master_glow:
		_master_glow.modulate.a = 0.7 + 0.3 * pulse
	if _trail:
		_trail.global_position = hog.global_position
		_trail.emitting = state == State.PLAYING and hog.curled and hog.linear_velocity.length() > 250.0
	if is_instance_valid(_confetti_node):
		_confetti_node.global_position = hog.global_position
	var now := Time.get_ticks_msec() * 0.001
	if Input.is_anything_pressed():
		_last_input = now
	var idle := now - _last_input
	if (state == State.PLAYING and idle > IDLE_PLAYING) or (state == State.WON and idle > IDLE_WON):
		_restart(false)


func _input(event: InputEvent) -> void:
	if event.is_pressed():
		_last_input = Time.get_ticks_msec() * 0.001
	var key := event as InputEventKey
	if state == State.WON and _entering_name and key and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			_on_title()
		else:
			_name_key(key)
		get_viewport().set_input_as_handled()
		return
	if key and key.pressed and not key.echo and (key.keycode == KEY_F or key.keycode == KEY_F11):
		_toggle_fullscreen()
		return
	if key and key.pressed and not key.echo and key.keycode == KEY_M:
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		hud.set_muted(AudioServer.is_bus_mute(0))
		return
	if not event.is_pressed() or event.is_echo():
		return
	match state:
		State.TITLE:
			if key and (key.keycode == KEY_1 or key.keycode == KEY_2):
				_on_level_pressed(1 if key.keycode == KEY_1 else 2)
			elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
				if not (key and key.keycode == KEY_ESCAPE):
					start_run()
		State.PLAYING:
			if event.is_action_pressed("restart"):
				_restart(true)
			elif key and key.keycode == KEY_ESCAPE:
				_set_paused(true)
		State.WON:
			if _end_ready and not _entering_name:
				if key and key.keycode == KEY_ESCAPE:
					_restart(false)
				elif key and key.keycode == KEY_N:
					_on_level_pressed(3 - level)
				elif event.is_action_pressed("restart") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
					_restart(true)


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _restart(quick: bool) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	skip_title = quick
	get_tree().reload_current_scene()


func _name_key(key: InputEventKey) -> void:
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_submit_name()
	elif key.keycode == KEY_BACKSPACE:
		_name = _name.substr(0, maxi(_name.length() - 1, 0))
	elif key.unicode >= 32 and _name.length() < 10:
		var c := String.chr(key.unicode).to_upper()
		if NAME_CHARS.contains(c):
			_name += c
	hud.set_name_text(_name)


func _set_paused(on: bool) -> void:
	if state != State.PLAYING:
		return
	get_tree().paused = on
	hud.show_pause(on)
	audio.play("pause", 1.0 if on else 1.4)


func _on_again() -> void:
	if state == State.WON and _entering_name:
		_submit_name()
	_restart(true)


func _on_level_pressed(n: int) -> void:
	if state == State.WON:
		if _entering_name:
			_submit_name()
		level = n
		_restart(true)
	elif state == State.TITLE and n != level:
		level = n
		_restart(false)


func _on_title() -> void:
	if state == State.WON and _entering_name:
		_submit_name()
	_restart(false)


func _submit_name() -> void:
	var rank := ToyScores.add(_name if _name != "" else "ANON", run_time, hog.kos)
	_entering_name = false
	hud.show_board(ToyScores.load_scores(), rank)
	audio.play("checkpoint")


func _poly(node_name: String, pts: Array, grass := true, fill := Color(0.34, 0.20, 0.11)) -> void:
	var terrain := ToyTerrain.new()
	terrain.name = node_name
	terrain.points = PackedVector2Array(pts)
	terrain.grass = grass
	terrain.fill = fill
	add_child(terrain)


func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	add_child(layer)
	var backdrop := ToyBackdrop.new()
	backdrop.level = level
	backdrop.world_end = world_end
	layer.add_child(backdrop)


func _build_beams() -> void:
	# sunlight falling through the two holes in the forest floor
	for hole in [Vector2(-100.0, 420.0), hole_b]:
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([Vector2(hole.x, 130), Vector2(hole.y, 130), Vector2(hole.y + 260.0, 1500), Vector2(hole.x - 260.0, 1500)])
		var top := Color(1.0, 0.82, 0.45, 0.28)
		var bottom := Color(1.0, 0.82, 0.45, 0.0)
		beam.vertex_colors = PackedColorArray([top, top, bottom, bottom])
		add_child(beam)


func _glow(parent: Node2D, local_pos: Vector2, radius: float, color: Color) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(color.r, color.g, color.b, color.a), Color(color.r, color.g, color.b, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = local_pos
	sprite.scale = Vector2.ONE * radius / 128.0
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	sprite.z_index = -1
	parent.add_child(sprite)
	return sprite


func _build_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float strength = 0.6;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.8));
	COLOR = vec4(0.05, 0.02, 0.01, smoothstep(0.32, 0.85, d) * strength);
}"""
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	layer.add_child(rect)


func _build_sky() -> void:
	var fill := Polygon2D.new()
	fill.color = Color(0.93, 0.5, 0.1)
	fill.polygon = PackedVector2Array([Vector2(-900, -2600), Vector2(world_end + 700.0, -2600), Vector2(world_end + 700.0, 0), Vector2(-900, 0)])
	add_child(fill)
	var texture: Texture2D = load("res://overworld_bg.webp")
	for i in int((world_end + 1500.0) / 1280.0) + 1:
		var sky := Sprite2D.new()
		sky.texture = texture
		sky.centered = false
		sky.flip_h = i % 2 == 1
		sky.modulate = Color(0.9, 0.82, 0.8)
		sky.position = Vector2(-760.0 + i * 1280.0, -720.0)
		add_child(sky)


func _ground(node_name: String, surface: Array, grass := true) -> void:
	var pts := PackedVector2Array(surface)
	pts.append(Vector2(pts[pts.size() - 1].x, BOTTOM))
	pts.append(Vector2(pts[0].x, BOTTOM))
	_poly(node_name, Array(pts), grass)


func _pit_floor(node_name: String, x0: float, x1: float, depth := 720.0) -> void:
	_poly(node_name, [Vector2(x0, CAVE + depth), Vector2(x1, CAVE + depth), Vector2(x1, BOTTOM), Vector2(x0, BOTTOM)], false)


func _pillar(x: float, top_rel: float) -> void:
	var top := CAVE + top_rel
	_poly("Pillar%d" % int(x), [Vector2(x - 55, top), Vector2(x + 55, top), Vector2(x + 55, CAVE + 780), Vector2(x - 55, CAVE + 780)])


func _build_terrain() -> void:
	var c := CAVE
	_poly("WallLeft", [Vector2(-760, -900), Vector2(-600, -900), Vector2(-600, BOTTOM), Vector2(-760, BOTTOM)], false)
	_poly("WallRight", [Vector2(world_end, -900), Vector2(world_end + 160, -900), Vector2(world_end + 160, BOTTOM), Vector2(world_end, BOTTOM)], false)
	# the forest: where the run starts and ends
	_poly("ForestStart", [Vector2(-760, 0), Vector2(-100, 0), Vector2(-100, 130), Vector2(-760, 130)])
	_poly("ForestAbove", [Vector2(420, 0), Vector2(hole_b.x, 0), Vector2(hole_b.x, 130), Vector2(420, 130)])
	_poly("ForestHome", [Vector2(hole_b.y, 0), Vector2(world_end, 0), Vector2(world_end, 130), Vector2(hole_b.y, 130)])
	_poly("BigTree", [Vector2(420, -1500), Vector2(560, -1500), Vector2(560, 130), Vector2(420, 130)], false, TRUNK)
	if level == 1:
		_terrain_level_1()
	else:
		_terrain_level_2()
	# the shared finale: a mushroom tower and the summit under the exit hole
	var x0 := tower_x0
	_poly("CaveMid", [Vector2(x0 - 350, c + 40), Vector2(x0, c + 40), Vector2(x0, BOTTOM), Vector2(x0 - 350, BOTTOM)])
	_poly("TowerFloor", [Vector2(x0, c + 780), Vector2(world_end, c + 780), Vector2(world_end, BOTTOM), Vector2(x0, BOTTOM)], false)
	for p in TOWER:
		_pillar(x0 + float(p[0]), float(p[1]))
	_poly("Summit", [Vector2(x0 + 1050, c + SUMMIT), Vector2(x0 + 1650, c + SUMMIT), Vector2(x0 + 1650, BOTTOM), Vector2(x0 + 1050, BOTTOM)])


func _terrain_level_1() -> void:
	var c := CAVE
	# flat landing, hill with a plateau, run-out, thorn pit
	_poly("CaveStart", [
		Vector2(-600, c), Vector2(800, c), Vector2(1250, c - 240), Vector2(1450, c - 240),
		Vector2(1950, c + 40), Vector2(2250, c + 40), Vector2(2250, BOTTOM), Vector2(-600, BOTTOM)])
	_pit_floor("PitFloor", 2250, 2650)


func _terrain_level_2() -> void:
	var c := CAVE
	# 1. rolling hills with beetle plateaus
	_ground("G0", [Vector2(-600, c), Vector2(800, c), Vector2(1100, c - 130), Vector2(1350, c - 130), Vector2(1700, c + 30),
		Vector2(2000, c + 30), Vector2(2250, c - 100), Vector2(2450, c - 100), Vector2(2800, c + 40), Vector2(3000, c + 40)])
	# 2. thorn pits: a bounce pillar, then two seesaw bridges
	_pit_floor("PitA", 3000, 3500)
	_pillar(3250, 40.0)
	_ground("G1", [Vector2(3500, c + 40), Vector2(3800, c + 40)])
	_pit_floor("PitB", 3800, 4200)
	_ground("G2", [Vector2(4200, c + 40), Vector2(4600, c + 40)])
	_pit_floor("PitC", 4600, 5000)
	# 3. boulder canyon: up the ramp, over the plateau, down the long hill
	_ground("G3", [Vector2(5000, c + 40), Vector2(5400, c + 40), Vector2(6000, c - 300), Vector2(6300, c - 300),
		Vector2(7000, c + 40), Vector2(7600, c + 40)])
	# 4. the bounce chasm: islands over thorns
	_poly("ChasmFloor", [Vector2(7600, c + 780), Vector2(9300, c + 780), Vector2(9300, BOTTOM), Vector2(7600, BOTTOM)], false)
	for island in CHASM:
		_pillar(float(island[0]), float(island[1]))
	_ground("G4", [Vector2(9300, c + 40), Vector2(9900, c + 40)])
	# 5. pendulum alley: two seesaw bridges under swinging chestnuts
	_pit_floor("PitD", 9900, 10300)
	_ground("G5", [Vector2(10300, c + 40), Vector2(10700, c + 40)])
	_pit_floor("PitE", 10700, 11100)


func _mushroom(pos: Vector2, width: float, height: float, checkpoint := false) -> ToyMushroom:
	var m := ToyMushroom.new()
	m.position = pos
	m.cap_width = width
	m.bounce_height = height
	m.checkpoint = checkpoint
	m.activated.connect(func() -> void: audio.play("checkpoint"))
	add_child(m)
	if checkpoint:
		var lamp := _glow(m, Vector2(0.0, -width * 0.4), width * 1.5, Color(1.0, 0.85, 0.4, 0.5))
		lamp.visible = false
		_lamps.append([m, lamp])
	return m


func _beetles(list: Array) -> void:
	for beetle in list:
		var b := ToyBeetle.new()
		b.position = Vector2(beetle[0], beetle[1])
		b.patrol_range = beetle[2]
		b.killed.connect(_on_beetle_killed)
		add_child(b)


func _seesaw(x: float, pendulum_angle := 0.0) -> void:
	var seesaw := ToySeesaw.new()
	seesaw.position = Vector2(x, CAVE + 50.0)
	add_child(seesaw)
	if pendulum_angle != 0.0:
		var pendulum := ToyPendulum.new()
		pendulum.position = Vector2(x, CAVE - 660.0)
		pendulum.length = 520.0
		pendulum.start_angle = pendulum_angle
		add_child(pendulum)


func _thorns(x: float, y: float, width: float, spikes := true) -> void:
	var thorns := ToyThorns.new()
	thorns.position = Vector2(x, y)
	thorns.width = width
	thorns.draw_spikes = spikes
	add_child(thorns)


# boulder shower: frozen up in the dark until the hedgehog crosses the trigger
func _boulder_shower(xs: Array, trigger: Vector2) -> void:
	for x in xs:
		var boulder := ToyBoulder.new()
		boulder.position = Vector2(x, CAVE - 900.0)
		boulder.freeze = true
		boulder.add_to_group("boulders")
		add_child(boulder)
	var shower := ToyTrigger.new()
	shower.position = trigger
	shower.size = Vector2(60, 300)
	shower.fired.connect(_release_boulders)
	add_child(shower)


func _build_gadgets() -> void:
	var c := CAVE
	var x0 := tower_x0
	_mushroom(Vector2(360, c), 180.0, 380.0, true)
	if level == 1:
		_gadgets_level_1()
	else:
		_gadgets_level_2()
	# the shared finale
	_mushroom(Vector2(x0 - 220, c + 40), 96.0, 420.0, true)
	for i in TOWER.size():
		var p: Array = TOWER[i]
		_mushroom(Vector2(x0 + float(p[0]), c + float(p[1])), 110.0, 420.0, i == 1)
	_mushroom(Vector2(x0 + 1130, c + SUMMIT), 96.0, 420.0, true)
	var master := _mushroom(Vector2(x0 + 1350, c + SUMMIT), 210.0, 0.0)
	master.master = true
	master.launch_apex_y = -420.0
	master.drift_start_y = -90.0
	master.landing_position = Vector2(x0 + 2300.0, -ToyHog.RADIUS)
	_master_glow = _glow(master, Vector2(0.0, -140.0), 420.0, Color(1.0, 0.8, 0.3, 0.3))
	_thorns(x0 + 1375.0, c + 780.0, 2850.0)

	var kill := ToyThorns.new()
	kill.position = Vector2(2000, 2800)
	kill.width = 30000.0
	kill.draw_spikes = false
	add_child(kill)

	var goal := ToyGoal.new()
	goal.position = Vector2(x0 + 2300.0, -90)
	goal.size = Vector2(800, 160)
	goal.reached.connect(_on_goal)
	add_child(goal)


func _gadgets_level_1() -> void:
	var c := CAVE
	_beetles([[740.0, c, 50.0], [2100.0, c + 40.0, 100.0], [2830.0, c + 40.0, 60.0]])
	_seesaw(2450, 0.8)
	_boulder_shower([1560.0, 1680.0, 1800.0, 1920.0], Vector2(1400, c - 380))
	_thorns(2450.0, c + 720.0, 400.0)


func _gadgets_level_2() -> void:
	var c := CAVE
	_beetles([
		[1230.0, c - 130.0, 60.0], [1850.0, c + 30.0, 90.0], [2350.0, c - 100.0, 50.0],
		[4400.0, c + 40.0, 80.0], [7300.0, c + 40.0, 120.0], [9600.0, c + 40.0, 80.0],
		[10500.0, c + 40.0, 100.0], [11350.0, c + 40.0, 40.0]])
	# pit A: one pillar to bounce off
	_mushroom(Vector2(3250, c + 40), 110.0, 420.0)
	_thorns(3250.0, c + 720.0, 500.0)
	_mushroom(Vector2(3650, c + 40), 96.0, 420.0, true)
	_seesaw(4000)
	_thorns(4000.0, c + 720.0, 400.0)
	_seesaw(4800, 0.8)
	_thorns(4800.0, c + 720.0, 400.0)
	_mushroom(Vector2(5150, c + 40), 96.0, 420.0, true)
	_boulder_shower([6400.0, 6520.0, 6640.0, 6760.0, 6880.0, 7000.0], Vector2(6150, c - 440))
	_mushroom(Vector2(7500, c + 40), 96.0, 420.0, true)
	# the bounce chasm
	for i in CHASM.size():
		var island: Array = CHASM[i]
		_mushroom(Vector2(float(island[0]), c + float(island[1])), 110.0, 420.0, i == 2)
	_thorns(8450.0, c + 780.0, 1700.0)
	_mushroom(Vector2(9400, c + 40), 96.0, 420.0, true)
	# pendulum alley
	_seesaw(10100, 0.8)
	_thorns(10100.0, c + 720.0, 400.0)
	_mushroom(Vector2(10600, c + 40), 96.0, 420.0, true)
	_seesaw(10900, -0.8)
	_thorns(10900.0, c + 720.0, 400.0)


func _release_boulders() -> void:
	var boulders := get_tree().get_nodes_in_group("boulders")
	for boulder: ToyBoulder in boulders:
		boulder.freeze = false
	await get_tree().create_timer(8.0).timeout
	for boulder in boulders:
		if is_instance_valid(boulder):
			boulder.queue_free()


func _build_hog() -> void:
	hog = ToyHog.new()
	hog.position = Vector2(-260, -ToyHog.RADIUS - 4.0)
	hog.active = false
	add_child(hog)
	camera = ToyCamera.new()
	camera.target = hog
	add_child(camera)
	camera.limit_right = int(world_end)
	camera.global_position = hog.global_position
	camera.make_current()
	_ghost = ToyGhost.new()
	_ghost.rec = ToyScores.load_ghost()
	add_child(_ghost)
	_trail = CPUParticles2D.new()
	_trail.emitting = false
	_trail.amount = 36
	_trail.lifetime = 0.5
	_trail.local_coords = false
	_trail.gravity = Vector2.ZERO
	_trail.initial_velocity_min = 10.0
	_trail.initial_velocity_max = 50.0
	_trail.spread = 180.0
	_trail.scale_amount_min = 4.0
	_trail.scale_amount_max = 9.0
	var trail_ramp := Gradient.new()
	trail_ramp.colors = PackedColorArray([Color(1.0, 0.75, 0.3, 0.7), Color(0.9, 0.4, 0.15, 0.0)])
	trail_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	_trail.color_ramp = trail_ramp
	_trail.z_index = -1
	add_child(_trail)
	hog.big_hit.connect(func(strength: float) -> void: camera.shake(strength * 0.5))
	hog.knocked_out.connect(_on_knocked_out)
	hog.bounced.connect(_on_bounced)
	hog.launched.connect(_on_launched)
	hog.jumped.connect(func() -> void: audio.play("jump"))
	hog.curl_changed.connect(func(on: bool) -> void: audio.play("curl" if on else "uncurl"))
	hog.respawned.connect(func() -> void: audio.play("bounce", 1.2, -4.0))
	hog.big_hit.connect(func(strength: float) -> void: audio.play("land", 1.0, strength * 4.0 - 4.0))


func _build_ui() -> void:
	hud = ToyHud.new()
	hud.hog = hog
	add_child(hud)
	hud.set_level(level)
	hud.level_pressed.connect(_on_level_pressed)
	hud.again_pressed.connect(_on_again)
	hud.title_pressed.connect(_on_title)
	hud.resume_pressed.connect(func() -> void: _set_paused(false))
	hud.set_muted(AudioServer.is_bus_mute(0))


func _build_audio() -> void:
	audio = GameAudio.new()
	add_child(audio)


func _on_bounced() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	_ground_time = 0.0
	camera.shake(0.2)
	audio.play("bounce", 1.0 + 0.07 * minf(combo - 1, 8))


func _on_launched() -> void:
	camera.shake(0.6)
	audio.play("launch")
	_on_goal()


func _ko_stars() -> void:
	var stars := CPUParticles2D.new()
	stars.position = hog.global_position + Vector2(0.0, -40.0)
	stars.emitting = true
	stars.one_shot = true
	stars.explosiveness = 1.0
	stars.amount = 9
	stars.lifetime = 0.9
	stars.direction = Vector2(0.0, -1.0)
	stars.spread = 70.0
	stars.initial_velocity_min = 140.0
	stars.initial_velocity_max = 300.0
	stars.gravity = Vector2(0.0, 520.0)
	stars.angular_velocity_min = -540.0
	stars.angular_velocity_max = 540.0
	stars.scale_amount_min = 6.0
	stars.scale_amount_max = 11.0
	stars.color = Color(1.0, 0.9, 0.3)
	stars.finished.connect(stars.queue_free)
	add_child(stars)


func _on_knocked_out() -> void:
	_ko_stars()
	combo = 0
	camera.shake(0.6)
	audio.play("hurt")
	audio.play("die", 1.2, -6.0)
	hud.set_kos(hog.kos)
	_hit_stop(0.09)


func _on_beetle_killed() -> void:
	audio.play("squish")
	_hit_stop(0.05)


func _hit_stop(seconds: float) -> void:
	if _hit_stopping or not hit_stop_enabled:
		return
	_hit_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stopping = false


func _on_goal() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	hog.active = false
	camera.shake(0.7)
	_confetti()
	_prev_best = ToyScores.best()
	if _prev_best <= 0.0 or run_time < _prev_best:
		ToyScores.save_ghost(_rec)
	_entering_name = ToyScores.qualifies(run_time)
	_name = ""
	_end_ready = false
	await get_tree().create_timer(1.0).timeout
	if state != State.WON:
		return
	_end_ready = true
	audio.play("win")
	hud.show_end(run_time, hog.kos, best_combo, _entering_name, ToyScores.load_scores())


func _confetti() -> void:
	var leaves := CPUParticles2D.new()
	leaves.emitting = true
	leaves.one_shot = true
	leaves.explosiveness = 0.0
	leaves.amount = 110
	leaves.lifetime = 2.0
	leaves.direction = Vector2(0, -1)
	leaves.spread = 75.0
	leaves.initial_velocity_min = 350.0
	leaves.initial_velocity_max = 900.0
	leaves.gravity = Vector2(0, 500)
	leaves.angular_velocity_min = -360.0
	leaves.angular_velocity_max = 360.0
	leaves.scale_amount_min = 6.0
	leaves.scale_amount_max = 13.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.98, 0.72, 0.15), Color(0.93, 0.45, 0.10), Color(0.78, 0.22, 0.10)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	leaves.color_initial_ramp = ramp
	add_child(leaves)
	_confetti_node = leaves
	leaves.global_position = hog.global_position
	leaves.finished.connect(leaves.queue_free)
