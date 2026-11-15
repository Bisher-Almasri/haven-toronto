class_name ToyTitle
extends Control

signal level_chosen(level: int)

const BG := preload("res://overworld_bg.webp")
const HOG := preload("res://hedgehog_standing_1.png")
const BALL := preload("res://hedgehog_spike.png")
const SHROOM := preload("res://mushrooms.png")
const LEAF_ORANGE := preload("res://leaf_orange.png")
const LEAF_RED := preload("res://leaf_red.png")
const OUTLINE := preload("res://shaders/sprite_outline.gdshader")

const LEAVES := [Color(0.93, 0.45, 0.10), Color(0.78, 0.22, 0.10), Color(0.98, 0.72, 0.15), Color(0.62, 0.30, 0.10)]
const GROUND_TOP := 0.855


class Ground extends Control:
	func _draw() -> void:
		var top := size.y * ToyTitle.GROUND_TOP
		draw_rect(Rect2(0.0, top, size.x, size.y - top), Color(0.30, 0.17, 0.09))
		draw_rect(Rect2(0.0, top, size.x, 8.0), Color(0.46, 0.29, 0.15))
		draw_rect(Rect2(0.0, top - 2.0, size.x, 3.0), Color(0.14, 0.07, 0.04))
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var x := -10.0
		while x < size.x + 10.0:
			var color: Color = ToyTitle.LEAVES[rng.randi() % ToyTitle.LEAVES.size()]
			draw_circle(Vector2(x, top + rng.randf_range(-3.0, 5.0)), rng.randf_range(8.0, 15.0), color)
			x += 11.0
		for i in 40:
			draw_circle(Vector2(rng.randf_range(0.0, size.x), rng.randf_range(top + 24.0, size.y)), rng.randf_range(3.0, 7.0), Color(0.2, 0.11, 0.06))


class BounceStage extends Control:
	const GRAVITY := 1300.0
	const BOUNCE := 150.0
	var LAUNCH := sqrt(2.0 * GRAVITY * BOUNCE)

	var mushroom: Sprite2D
	var hog: Sprite2D
	var ball: Sprite2D
	var _h := 0.0
	var _vh := 0.0
	var _squash := 0.0
	var _time := 0.0
	var _spin := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mushroom = _sprite(SHROOM, Vector2(-64.0, -128.0))
		hog = _sprite(HOG, Vector2(-64.0, -121.0))
		ball = _sprite(BALL, Vector2(-54.0, -65.5))
		ball.visible = false
		restart()

	func _sprite(texture: Texture2D, offset: Vector2) -> Sprite2D:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.offset = offset
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var material := ShaderMaterial.new()
		material.shader = OUTLINE
		material.set_shader_parameter("outline_px", 1.6)
		sprite.material = material
		add_child(sprite)
		return sprite

	func restart() -> void:
		_h = 60.0
		_vh = 0.0
		_squash = 0.0

	func _draw() -> void:
		var s := size.y / 720.0
		var base := Vector2(size.x * 0.5, size.y * ToyTitle.GROUND_TOP + 10.0 * s)
		draw_set_transform(base + Vector2(0.0, 6.0 * s), 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, 150.0 * s, Color(0.1, 0.04, 0.02, 0.35))

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_time += delta
		var s := size.y / 720.0
		_vh -= GRAVITY * delta
		_h += _vh * delta
		if _h <= 0.0 and _vh < 0.0:
			_h = 0.0
			_vh = LAUNCH
			_squash = 1.0
		_squash = maxf(_squash - delta * 3.2, 0.0)

		var base := Vector2(size.x * 0.5, size.y * ToyTitle.GROUND_TOP + 10.0 * s)
		var shroom_scale := 1.4 * s
		var squash_y := 1.0 - 0.30 * _squash
		var squash_x := 1.0 + 0.20 * _squash
		mushroom.position = base
		mushroom.scale = Vector2(shroom_scale * squash_x, shroom_scale * squash_y)
		var cap_top := base.y - 125.0 * shroom_scale * squash_y

		var hog_scale := 1.4 * s
		var feet := Vector2(base.x, cap_top - _h * s)
		var curled := _vh < 150.0 and _h > 4.0
		hog.visible = not curled
		ball.visible = curled
		if curled:
			_spin += delta * 11.0
			var ball_scale := 1.15 * hog_scale
			ball.scale = Vector2(ball_scale, ball_scale)
			ball.position = feet + Vector2(0.0, -42.0 * hog_scale)
			ball.rotation = _spin
		else:
			var stretch := clampf(absf(_vh) / 1500.0, 0.0, 0.2)
			hog.scale = Vector2(hog_scale * (1.0 - stretch * 0.5), hog_scale * (1.0 + stretch))
			hog.position = feet
			hog.rotation = sin(_time * 2.2) * 0.04
			_spin = 0.0


class LevelCard extends PanelContainer:
	signal chosen

	var selected := false:
		set(value):
			selected = value
			_restyle()
	var _hover := false

	func _init(level: int) -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0.0, 78.0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var key := ToyUI.keycap(str(level), 26)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		info.add_child(ToyUI.label(ToyLevels.title_of(level), 30))

		var medals := HBoxContainer.new()
		medals.add_theme_constant_override("separation", 16)
		medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(medals)
		for tier in [3, 2, 1]:
			var group := HBoxContainer.new()
			group.add_theme_constant_override("separation", 5)
			group.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_child(ToyUI.MedalDisc.new(18.0, tier))
			var t := ToyUI.num(ToyScores.format_time(ToyMedals.tier_time(level, tier)), 18, ToyUI.tier_color(tier))
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			group.add_child(t)
			medals.add_child(group)
		var tag := ToyUI.panel(Color(0.5, 0.26, 0.08, 0.9), ToyUI.INK, 10, Vector2(10.0, 0.0))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(ToyUI.label(ToyLevels.LENGTHS.get(level, ""), 18, ToyUI.GOLD))
		row.add_child(tag)
		mouse_entered.connect(func() -> void:
			_hover = true
			_restyle())
		mouse_exited.connect(func() -> void:
			_hover = false
			_restyle())
		_restyle()

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit()

	func _restyle() -> void:
		var bg := Color(0.17, 0.08, 0.04, 0.9) if selected else Color(0.17, 0.08, 0.04, 0.62)
		if _hover and not selected:
			bg = Color(0.3, 0.15, 0.06, 0.82)
		var edge := ToyUI.GOLD if selected else (ToyUI.AMBER if _hover else Color(0.3, 0.16, 0.07))
		add_theme_stylebox_override("panel", ToyUI.panel_style(bg, edge, 14, Vector2(14.0, 8.0)))
		modulate = Color.WHITE if selected or _hover else Color(0.82, 0.78, 0.74)


var board: RichTextLabel
var board_title: Label

var _bg: TextureRect
var _stage: BounceStage
var _leaf_emitters: Array[CPUParticles2D] = []
var _title_rich: RichTextLabel
var _cards := {}
var _level := 1


func setup(title_text: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	_bg = TextureRect.new()
	_bg.texture = BG
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.resized.connect(func() -> void: _bg.pivot_offset = _bg.size * 0.5)
	add_child(_bg)
	var drift := create_tween().set_loops()
	drift.tween_property(_bg, "scale", Vector2(1.07, 1.07), 11.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_bg, "scale", Vector2.ONE, 11.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	glow.colors = PackedColorArray([Color(1.0, 0.7, 0.2, 0.0), Color(0.3, 0.12, 0.03, 0.0), Color(0.12, 0.04, 0.01, 0.62)])
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = glow
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.width = 256
	glow_texture.height = 256
	var vignette := TextureRect.new()
	vignette.texture = glow_texture
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	_build_leaves()

	var ground := Ground.new()
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_stage = BounceStage.new()
	_stage.anchor_right = 0.5
	_stage.anchor_bottom = 1.0
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_build_title_text(title_text)
	_build_menu()
	_build_prompt()
	visibility_changed.connect(func() -> void:
		for leaves in _leaf_emitters:
			leaves.emitting = is_visible_in_tree())


func restart() -> void:
	if _stage:
		_stage.restart()


func set_level(level: int) -> void:
	_level = level
	for n in _cards:
		var card: LevelCard = _cards[n]
		card.selected = n == level
	board_title.text = "BEST TIMES  -  LEVEL %d" % level


func set_board(scores: Array) -> void:
	board.text = "[center]%s[/center]" % ToyUI.scores_bbcode(scores)


func _build_leaves() -> void:
	for texture in [LEAF_ORANGE, LEAF_RED]:
		var leaves := CPUParticles2D.new()
		leaves.texture = texture
		leaves.amount = 20
		leaves.lifetime = 9.0
		leaves.preprocess = 9.0
		leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		leaves.emission_rect_extents = Vector2(700.0, 8.0)
		leaves.position = Vector2(640.0, -40.0)
		leaves.direction = Vector2(0.25, 1.0)
		leaves.spread = 25.0
		leaves.initial_velocity_min = 40.0
		leaves.initial_velocity_max = 90.0
		leaves.gravity = Vector2(18.0, 30.0)
		leaves.angle_min = 0.0
		leaves.angle_max = 360.0
		leaves.angular_velocity_min = -90.0
		leaves.angular_velocity_max = 90.0
		leaves.scale_amount_min = 0.22
		leaves.scale_amount_max = 0.42
		leaves.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(leaves)
		_leaf_emitters.append(leaves)
	resized.connect(func() -> void:
		for leaves in _leaf_emitters:
			leaves.position = Vector2(size.x * 0.5, -40.0)
			leaves.emission_rect_extents = Vector2(size.x * 0.55, 8.0))


func _build_title_text(title_text: String) -> void:
	var words := title_text.split(" ")
	var bb := "[center][color=#fff0bf]%s[/color]" % words[0]
	if words.size() > 1:
		bb += " [wave amp=22 freq=5][color=#ffcc40]%s[/color][/wave]" % words[1]
	if words.size() > 2:
		bb += " [font_size=48][color=#ffffff]%s[/color][/font_size]" % " ".join(words.slice(2))
	bb += "[/center]"
	_title_rich = ToyUI.rich(116)
	_title_rich.text = bb
	_title_rich.add_theme_constant_override("outline_size", 18)
	_title_rich.add_theme_color_override("font_shadow_color", Color(0.12, 0.04, 0.01, 0.55))
	_title_rich.add_theme_constant_override("shadow_offset_x", 0)
	_title_rich.add_theme_constant_override("shadow_offset_y", 8)
	_title_rich.add_theme_constant_override("shadow_outline_size", 18)
	_title_rich.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_rich.anchor_left = 0.0
	_title_rich.anchor_right = 1.0
	_title_rich.offset_left = 20.0
	_title_rich.offset_right = -20.0
	_title_rich.offset_top = 22.0
	add_child(_title_rich)

	var holder := CenterContainer.new()
	holder.anchor_right = 1.0
	holder.offset_top = 148.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var pill := ToyUI.panel(Color(0.17, 0.08, 0.04, 0.78), ToyUI.WOOD_EDGE, 22, Vector2(24.0, 4.0))
	pill.add_child(ToyUI.label("Bounce your way home. Fastest time wins the table!", 26, ToyUI.GOLD))
	holder.add_child(pill)


func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.55
	box.anchor_right = 0.96
	box.anchor_top = 0.285
	box.anchor_bottom = 0.84
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	for n in [1, 2]:
		var card := LevelCard.new(n)
		card.chosen.connect(func() -> void: level_chosen.emit(n))
		box.add_child(card)
		_cards[n] = card

	var panel := ToyUI.panel(Color(0.17, 0.08, 0.04, 0.82), ToyUI.WOOD_EDGE, 14, Vector2(16.0, 10.0))
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	board_title = ToyUI.num("", 20, ToyUI.GOLD)
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(board_title)
	board = ToyUI.rich(22, true)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(board)
	set_level(_level)


func _build_prompt() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.875
	box.anchor_bottom = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var prompt := ToyUI.label("PRESS ANY KEY TO PLAY", 44, ToyUI.GOLD)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prompt)
	var blink := create_tween().set_loops()
	blink.tween_property(prompt, "modulate:a", 0.45, 0.6)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.6)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 40)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(keys)
	keys.add_child(ToyUI.key_hint(["1", "2"], "LEVEL", 16))
	keys.add_child(ToyUI.key_hint(["F"], "FULLSCREEN", 16))
	keys.add_child(ToyUI.key_hint(["M"], "MUTE", 16))
