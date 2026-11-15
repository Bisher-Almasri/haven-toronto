class_name Intro3D
extends Node3D

## Level 1 opening cutscene: the hedgehog strolls home, Terry the fox steps out from behind the big
## tree and drops him down his trapped fox hole. The real hedgehog stays hidden at the start the whole
## time (this uses a puppet), so the run clock and the first fall are exactly the same as on a retry.
## SPACE / click = next line, R or ESC = skip.

signal done

const FOX := preload("res://terry_green_emerald.png")
const FOX_REGION := Rect2(250.0, 570.0, 900.0, 1000.0)
const FOX_FEET := 460.0
const FOX_PIXEL := 0.0018
const HOLE_L := -1.0
const HOLE_R := 4.2
const FLOOR_Y := 0.02
const CAVE_FLOOR := -11.0
const Z_BACK := -6.0
const Z_FRONT := 1.0
const PLANKS := 6
const PLANK_H := 0.3
const HOG_SCALE := 0.6
const HOG_X := 0.8
const GRAVITY := 16.0
const TYPE_CPS := 46.0
const GRACE := 0.6
const BAR := 0.11
const TERRY_NAME := "TERRY"

var camera: Cam3D
var audio: GameAudio
var skipped := false
## Milestones in the order they happened (the test reads it).
var beats: Array[String] = []

var _t := 0.0
var _ended := false
var _advance := false
var _stage: Node3D
var _hog: Node3D
var _hog_sprite: Sprite3D
var _hog_outline := ShaderMaterial.new()
var _pose := "stand"
var _facing := 1.0
var _walking := false
var _walk_time := 0.0
var _blink_in := 1.5
var _blink_left := 0.0
var _spin := 0.0
var _spinning := false
var _squash := Vector2.ONE
var _falling := false
var _fall_v := Vector2.ZERO
var _landed := false
var _follow_hog := false
var _terry: Node3D
var _terry_sprite: Sprite3D
var _tpop := Vector2.ONE
var _planks: Array[Dictionary] = []
var _cover_shake := 0.0

var _ui: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _box: PanelContainer
var _who: Label
var _line: Label
var _arrow: Label
var _plate: PanelContainer
var _flash: ColorRect
var _fade: ColorRect
var _card: Control
var _box_tween: Tween


func _ready() -> void:
	_build_stage()
	_build_ui()
	camera.cine_to(Vector3(-0.2, 0.5, 0.0), 1.05, 4.0, true)
	_run()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if _ended or _t < GRACE or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key and (key.keycode == KEY_F or key.keycode == KEY_F11 or key.keycode == KEY_M):
		return
	get_viewport().set_input_as_handled()
	if (key and key.keycode == KEY_ESCAPE) or event.is_action_pressed("restart"):
		skip()
	elif key or event is InputEventMouseButton or event is InputEventJoypadButton:
		_advance = true


func skip() -> void:
	skipped = true


func _process(delta: float) -> void:
	_t += delta
	_update_hog(delta)
	_update_terry()
	_update_planks(delta)
	if _follow_hog:
		camera.cine_focus = Vector3(_hog.position.x, _hog.position.y - 0.8, 0.0)


# ---------------------------------------------------------------- the story

func _run() -> void:
	await _story()
	_end()


func _story() -> void:
	beats.append("start")
	_bars(true)
	await _wait(0.5)
	_walk_to(HOG_X, 1.7)
	camera.cine_to(Vector3(-0.1, 0.5, 0.0), 1.05, 1.2)
	await _say("", "Autumn in Red Leaf Forest. A little hedgehog is heading home before the snow.")
	await _say("", "But he is not alone...")
	await _until(func() -> bool: return not _walking)
	if skipped:
		return
	beats.append("walked")

	# Terry slides out from behind the big tree
	_hide_box()
	_sfx("rustle")
	_emote("?", _hog, Color(1.0, 0.94, 0.75))
	camera.cine_to(Vector3(3.3, 0.55, 0.0), 1.2, 3.0)
	var slide := create_tween()
	slide.tween_property(_terry, "position:x", 7.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	slide.tween_property(_terry, "position:z", 0.3, 0.25)
	await _wait(1.2)
	_sfx("sting")
	camera.shake(0.45)
	_flash_red()
	_pop_terry()
	_nameplate()
	beats.append("terry")
	await _wait(1.3)

	await _say(TERRY_NAME, "Hello, hedgehog. I'm Terry. I've been waiting for you since July.")
	await _say(TERRY_NAME, "I dug you a little something. Spikes! Thorns! Boulders!")
	await _say(TERRY_NAME, "And some mushrooms I don't remember planting.")
	_emote("!", _hog, Color(1.0, 0.82, 0.28))
	_hop(_hog, 0.25)
	await _say(TERRY_NAME, "Nobody gets home past Terry!")
	if skipped:
		return

	# stomp: the leaf-covered trap cracks, then drops
	_hide_box()
	_hop(_terry, 0.5)
	await _wait(0.34)
	_sfx("crack")
	camera.shake(0.6)
	_cover_shake = 1.0
	_emote("!!", _hog, Color(1.0, 0.48, 0.36))
	await _wait(0.9)
	beats.append("collapse")
	_collapse()
	await _say(TERRY_NAME, "Welcome to my FOX HOLE!")
	await _until(func() -> bool: return _landed)
	if skipped:
		return
	_hide_box()
	beats.append("landed")
	await _wait(0.9)

	# the laugh from above, then up the shaft to Terry at the rim
	_sfx("laugh")
	_place_terry_on_rim()
	_follow_hog = false
	camera.cine_to(Vector3(-0.7, 0.6, 0.0), 1.25, 1.5)
	await _say(TERRY_NAME, "HAHAHAHAHA!")
	await _wait(0.4)
	beats.append("rim")
	await _say(TERRY_NAME, "Enjoy the traps, hedgehog. They're very sharp. I sharpened them myself.")
	if skipped:
		return

	# the payoff: hedgehogs curl up, and balls bounce
	_hide_box()
	camera.cine_to(Vector3(HOG_X, CAVE_FLOOR + 0.6, 0.0), 1.4, 1.6)
	await _wait(1.2)
	_pose = "stand"
	await _say("", "But Terry forgot one thing.")
	_bounce_show()
	await _say("", "Hedgehogs curl into balls. And balls... BOUNCE!")
	await _wait(0.5)
	beats.append("bounce")
	_hide_box()
	if skipped:
		return
	await _level_card()


func _end() -> void:
	if _ended:
		return
	_ended = true
	beats.append("end")
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.25 if skipped else 0.5)
	await out.finished
	_card.visible = false
	set_process(false)
	_stage.queue_free()
	camera.cine = false
	done.emit()
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.4)
	await back.finished
	queue_free()


func _level_card() -> void:
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.6)
	await out.finished
	if skipped:
		return
	_ui_bars_off()
	_card.visible = true
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * 0.9
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.4)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sfx("start")
	beats.append("card")
	await _wait(1.8, true)


# ---------------------------------------------------------------- helpers

func _sfx(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not skipped and audio:
		audio.play(sound, pitch, volume_db)


func _wait(seconds: float, interruptible := false) -> void:
	var left := seconds
	if interruptible:
		_advance = false
	while left > 0.0 and not skipped and not (interruptible and _advance):
		await get_tree().process_frame
		left -= get_process_delta_time()
	_advance = false


func _until(cond: Callable) -> void:
	while not skipped and not cond.call():
		await get_tree().process_frame


func _say(who: String, text: String) -> void:
	if skipped:
		return
	_who.text = who
	_who.visible = who != ""
	_who.add_theme_color_override("font_color", ToyUI.HOT if who == TERRY_NAME else ToyUI.GOLD)
	_line.text = text
	_line.visible_characters = 0
	_line.add_theme_color_override("font_color", ToyUI.CREAM if who != "" else Color(1.0, 0.9, 0.7))
	_arrow.visible = false
	_show_box()
	if who == TERRY_NAME:
		_pop_terry()
	var count := text.length()
	var typed := 0.0
	var last := 0
	_advance = false
	while last < count and not skipped:
		await get_tree().process_frame
		typed += get_process_delta_time() * TYPE_CPS
		if _advance:
			typed = float(count)
			_advance = false
		var shown := mini(int(typed), count)
		if shown > last and shown % 2 == 0:
			_sfx("blip", 0.6 if who == TERRY_NAME else 1.25, -6.0)
		last = shown
		_line.visible_characters = shown
	_line.visible_characters = -1
	_arrow.visible = true
	var hold := 0.4 + count * 0.016
	while hold > 0.0 and not skipped and not _advance:
		await get_tree().process_frame
		hold -= get_process_delta_time()
	_advance = false


func _walk_to(x: float, speed: float) -> void:
	_walking = true
	_pose = "walk"
	var tw := create_tween()
	tw.tween_property(_hog, "position:x", x, absf(x - _hog.position.x) / speed)
	tw.tween_callback(func() -> void:
		_walking = false
		_pose = "stand")


func _hop(node: Node3D, height: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "position:y", node.position.y + height, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", node.position.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _pop_terry() -> void:
	_tpop = Vector2(1.1, 0.9)
	create_tween().tween_property(self, "_tpop", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _emote(text: String, at: Node3D, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = ToyUI.num_font()
	l.font_size = 110
	l.pixel_size = 0.006
	l.outline_size = 28
	l.outline_modulate = ToyUI.INK
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.position = Vector3(0.15, 1.0, 0.7)
	l.scale = Vector3.ZERO
	at.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.25, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func _flash_red() -> void:
	_flash.color = Color(0.8, 0.1, 0.05, 0.4)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


func _place_terry_on_rim() -> void:
	_terry.position = Vector3(-1.9, 0.0, 0.3)
	_terry_sprite.flip_h = false
	_terry_sprite.rotation.z = -0.1


func _collapse() -> void:
	_sfx("whoosh", 1.0, -3.0)
	for p in _planks:
		var node: Node3D = p["node"]
		p["delay"] = absf(node.position.x - HOG_X) * 0.08 + randf() * 0.05
		p["v"] = Vector2(randf_range(-0.6, 0.6), 0.0)
		p["w"] = randf_range(2.0, 5.0) * (1.0 if randf() < 0.5 else -1.0)
		p["falling"] = true
	_cover_shake = 0.0
	var leaves := Models3D.burst(70, 1.3, 0.13, Color(0.98, 0.62, 0.2, 0.9), 1.5, 5.0, 90.0, -5.0)
	leaves.position = Vector3(1.6, 0.3, 0.8)
	leaves.finished.connect(leaves.queue_free)
	_stage.add_child(leaves)
	leaves.emitting = true
	var dust := Models3D.burst(30, 1.0, 0.26, Color(0.45, 0.28, 0.14, 0.55), 0.6, 2.5, 90.0, -1.0)
	dust.position = Vector3(1.6, 0.0, 0.8)
	dust.finished.connect(dust.queue_free)
	_stage.add_child(dust)
	dust.emitting = true
	camera.shake(0.7)
	get_tree().create_timer(0.14).timeout.connect(_start_fall)


func _start_fall() -> void:
	if skipped:
		return
	_pose = "curl"
	_spinning = true
	_falling = true
	_fall_v = Vector2(0.15, 0.0)
	_follow_hog = true
	camera.cine_to(_hog.position, 1.25, 9.0)


func _land() -> void:
	_falling = false
	_landed = true
	_follow_hog = false
	_spinning = false
	_sfx("land")
	_sfx("hurt", 1.0, -3.0)
	camera.shake(0.8)
	camera.cine_to(Vector3(_hog.position.x, CAVE_FLOOR + 0.4, 0.0), 1.4, 5.0)
	var dust := Models3D.burst(26, 0.9, 0.22, Color(0.5, 0.32, 0.18, 0.6), 0.8, 3.2, 80.0, -1.5)
	dust.position = _hog.position + Vector3(0.0, 0.1, 0.8)
	dust.finished.connect(dust.queue_free)
	_stage.add_child(dust)
	dust.emitting = true
	_pose = "dead"
	_squash = Vector2(1.35, 0.65)
	create_tween().tween_property(self, "_squash", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var stars := Models3D.burst(9, 1.2, 0.12, Color(1.0, 0.9, 0.3), 1.4, 3.0, 70.0, -5.0)
	stars.position = _hog.position + Vector3(0.0, 0.5, 0.9)
	stars.finished.connect(stars.queue_free)
	_stage.add_child(stars)
	stars.emitting = true


func _bounce_show() -> void:
	_pose = "curl"
	_spinning = true
	var tw := create_tween()
	for i in 3:
		var h := 1.2 + 0.5 * i
		tw.tween_property(_hog, "position:y", CAVE_FLOOR + h, 0.3 + 0.04 * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_hog, "position:y", CAVE_FLOOR, 0.3 + 0.04 * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_bounce_land.bind(i))


func _bounce_land(i: int) -> void:
	_sfx("bounce", 0.9 + 0.2 * i)
	camera.shake(0.2)
	var leaves := Models3D.burst(10 + 4 * i, 0.7, 0.13, Color(0.98, 0.62, 0.2, 0.9), 1.5, 3.5, 75.0, -6.0)
	leaves.position = _hog.position + Vector3(0.0, 0.1, 0.8)
	leaves.finished.connect(leaves.queue_free)
	_stage.add_child(leaves)
	leaves.emitting = true


# ---------------------------------------------------------------- per-frame animation

func _update_hog(delta: float) -> void:
	var tex: Texture2D = Hog3D.TEX_STAND
	var offset := Vector2(8.0, 63.0)
	var lift := 0.0
	var sprite_scale := Vector3(HOG_SCALE * _facing, HOG_SCALE, 1.0)
	var rot := 0.0
	match _pose:
		"walk":
			_walk_time += delta * 5.5
			tex = Hog3D.TEX_WALK[Hog3D.WALK_ORDER[int(_walk_time) % Hog3D.WALK_ORDER.size()]]
		"curl":
			if _spinning:
				_spin -= 11.0 * delta
			tex = Hog3D.TEX_SPIKE
			offset = Vector2(10.0, 1.5)
			lift = Hog3D.RADIUS
			sprite_scale = Vector3(0.67, 0.67, 1.0)
			rot = _spin
		"dead":
			tex = Hog3D.TEX_DEAD
			offset = Vector2(6.0, 38.0)
		_:
			_blink_in -= delta
			if _blink_in <= 0.0:
				_blink_left = Hog3D.BLINK_TIME
				_blink_in = randf_range(1.5, 3.5)
			_blink_left = maxf(_blink_left - delta, 0.0)
			tex = Hog3D.TEX_BLINK if _blink_left > 0.0 else Hog3D.TEX_STAND
	if _falling:
		_fall_v.y -= GRAVITY * delta
		_hog.position.x += _fall_v.x * delta
		_hog.position.y += _fall_v.y * delta
		if _hog.position.y <= CAVE_FLOOR:
			_hog.position.y = CAVE_FLOOR
			_land()
	_hog_sprite.texture = tex
	_hog_sprite.offset = offset
	_hog_sprite.position = Vector3(0.0, lift, 0.0)
	_hog_sprite.scale = sprite_scale * Vector3(_squash.x, _squash.y, 1.0)
	_hog_sprite.rotation.z = rot
	_hog_outline.set_shader_parameter("tex", tex)


func _update_terry() -> void:
	var breathe := sin(_t * 3.0) * 0.012
	_terry_sprite.scale = Vector3(_tpop.x * (1.0 - breathe), _tpop.y * (1.0 + breathe), 1.0)


func _update_planks(delta: float) -> void:
	for p in _planks:
		var node: Node3D = p["node"]
		if p["falling"]:
			if not node.visible:
				continue
			p["delay"] -= delta
			if p["delay"] > 0.0:
				continue
			var v: Vector2 = p["v"]
			v.y -= GRAVITY * delta
			p["v"] = v
			node.position.x += v.x * delta
			node.position.y += v.y * delta
			node.rotation.z += float(p["w"]) * delta
			if node.position.y < CAVE_FLOOR + 0.3:
				node.visible = false
		elif _cover_shake > 0.0:
			node.position.y = -PLANK_H * 0.5 + randf_range(-1.0, 1.0) * 0.035 * _cover_shake
			node.rotation.z = randf_range(-1.0, 1.0) * 0.012 * _cover_shake


# ---------------------------------------------------------------- stage

func _build_stage() -> void:
	_stage = Node3D.new()
	_stage.name = "IntroStage"
	add_child(_stage)

	_hog = Node3D.new()
	_hog.position = Vector3(-4.6, FLOOR_Y, 0.3)
	_stage.add_child(_hog)
	_hog_sprite = Sprite3D.new()
	_hog_sprite.pixel_size = 0.01
	_hog_sprite.shaded = false
	_hog_sprite.double_sided = true
	_hog_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hog_outline.shader = load("res://shaders/sprite_outline_3d.gdshader")
	_hog_sprite.material_override = _hog_outline
	_hog.add_child(_hog_sprite)

	_terry = Node3D.new()
	_terry.position = Vector3(4.9, FLOOR_Y, -1.6)
	_stage.add_child(_terry)
	_terry_sprite = Sprite3D.new()
	_terry_sprite.texture = FOX
	_terry_sprite.region_enabled = true
	_terry_sprite.region_rect = FOX_REGION
	_terry_sprite.offset = Vector2(0.0, FOX_FEET)
	_terry_sprite.pixel_size = FOX_PIXEL
	_terry_sprite.shaded = false
	_terry_sprite.double_sided = true
	_terry_sprite.flip_h = true
	_terry_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/sprite_outline_3d.gdshader")
	outline.set_shader_parameter("tex", FOX)
	outline.set_shader_parameter("outline_px", 8.0)
	_terry_sprite.material_override = outline
	_terry.add_child(_terry_sprite)

	_build_cover()


## Six leafy planks laid over the hole so the forest floor looks whole until Terry springs the trap.
func _build_cover() -> void:
	var width := (HOLE_R - HOLE_L) / PLANKS
	var z_mid := (Z_BACK + Z_FRONT) * 0.5
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.34, 0.2, 0.11)
	body.roughness = 1.0
	var leaf := StandardMaterial3D.new()
	leaf.albedo_texture = Terrain3D.leaf_texture()
	leaf.vertex_color_use_as_albedo = true
	leaf.albedo_color = Color(0.72, 0.62, 0.55)
	leaf.roughness = 1.0
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for i in PLANKS:
		var cx := HOLE_L + width * (i + 0.5)
		var plank := Node3D.new()
		plank.position = Vector3(cx, -PLANK_H * 0.5, z_mid)
		_stage.add_child(plank)
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width + 0.03, PLANK_H, Z_FRONT - Z_BACK)
		box.mesh = mesh
		box.material_override = body
		plank.add_child(box)
		var top := MeshInstance3D.new()
		top.mesh = _plank_top(cx, width + 0.03, z_mid)
		top.material_override = leaf
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top.position = Vector3(0.0, PLANK_H * 0.5 + FLOOR_Y - 0.01, 0.0)
		plank.add_child(top)
		_planks.append({"node": plank, "falling": false, "delay": 0.0, "v": Vector2.ZERO, "w": 0.0})


## The same leaf floor (and the same fade into shadow at the back) as Terrain3D's top surface.
func _plank_top(cx: float, width: float, z_mid: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := [[Z_BACK, 0.08], [Z_BACK + 1.4, 0.32], [Z_BACK + 3.4, 1.0], [Z_FRONT, 1.0]]
	var x0 := -width * 0.5
	var x1 := width * 0.5
	for r in 3:
		var z0: float = rows[r][0]
		var z1: float = rows[r + 1][0]
		var c0: float = rows[r][1]
		var c1: float = rows[r + 1][1]
		var corners := [Vector3(x0, 0.0, z0 - z_mid), Vector3(x1, 0.0, z0 - z_mid), Vector3(x1, 0.0, z1 - z_mid), Vector3(x0, 0.0, z1 - z_mid)]
		var uvs := [Vector2(cx + x0, z0), Vector2(cx + x1, z0), Vector2(cx + x1, z1), Vector2(cx + x0, z1)]
		var shades := [c0, c0, c1, c1]
		for k in [0, 1, 2, 0, 2, 3]:
			var sh: float = shades[k]
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k] * 0.25)
			st.set_color(Color(sh, sh * 0.9, sh * 0.82))
			st.add_vertex(corners[k])
	return st.commit()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.8, 0.1, 0.05, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_bar_top = _bar(Control.PRESET_TOP_WIDE)
	_bar_bottom = _bar(Control.PRESET_BOTTOM_WIDE)
	root.add_child(_bar_top)
	root.add_child(_bar_bottom)

	_box = ToyUI.panel(Color(0.12, 0.05, 0.02, 0.92), ToyUI.WOOD_EDGE, 18, Vector2(28.0, 14.0))
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -94.0
	_box.custom_minimum_size = Vector2(980.0, 0.0)
	_box.modulate.a = 0.0
	root.add_child(_box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(rows)
	_who = ToyUI.label("", 28, ToyUI.HOT)
	rows.add_child(_who)
	_line = ToyUI.label("", 30)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(920.0, 0.0)
	rows.add_child(_line)
	_arrow = ToyUI.label("v", 22, ToyUI.GOLD)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow.visible = false
	rows.add_child(_arrow)

	_plate = ToyUI.panel(Color(0.12, 0.05, 0.02, 0.92), ToyUI.HOT, 14, Vector2(24.0, 10.0))
	_plate.position = Vector2(-460.0, 110.0)
	var plate_rows := VBoxContainer.new()
	plate_rows.add_theme_constant_override("separation", 0)
	plate_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(plate_rows)
	plate_rows.add_child(ToyUI.label(TERRY_NAME, 54, ToyUI.HOT))
	plate_rows.add_child(ToyUI.label("the fox. evil genius. (his words)", 20, ToyUI.CREAM))
	root.add_child(_plate)

	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 22)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -22.0
	hint.offset_bottom = -22.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(ToyUI.key_hint(["SPACE"], "NEXT", 15))
	hint.add_child(ToyUI.key_hint(["ESC"], "SKIP", 15))
	root.add_child(hint)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.05, 0.02, 0.01, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	root.add_child(_card)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	var lvl := ToyUI.num("LEVEL %d" % Game3D.level, 36, ToyUI.AMBER)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(lvl)
	var title := ToyUI.label(ToyLevels.title_of(Game3D.level).to_upper(), 88)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var sub := ToyUI.label("bounce your way home!", 34, ToyUI.GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(sub)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size * 0.5)


func _bar(preset: Control.LayoutPreset) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0.03, 0.01, 0.0)
	bar.set_anchors_preset(preset)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preset == Control.PRESET_TOP_WIDE:
		bar.anchor_bottom = 0.0
	else:
		bar.anchor_top = 1.0
	return bar


func _bars(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "anchor_bottom", BAR if on else 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bar_bottom, "anchor_top", 1.0 - BAR if on else 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _ui_bars_off() -> void:
	_bar_top.anchor_bottom = 0.0
	_bar_bottom.anchor_top = 1.0
	_box.modulate.a = 0.0
	_plate.modulate.a = 0.0


func _show_box() -> void:
	_fade_box(1.0, 0.15)


func _hide_box() -> void:
	_fade_box(0.0, 0.2)


func _fade_box(alpha: float, seconds: float) -> void:
	if _box_tween:
		_box_tween.kill()
	_box_tween = create_tween()
	_box_tween.tween_property(_box, "modulate:a", alpha, seconds)


func _nameplate() -> void:
	_plate.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_plate, "position:x", 40.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(_plate, "position:x", -560.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
