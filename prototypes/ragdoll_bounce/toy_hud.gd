class_name ToyHud
extends CanvasLayer

signal again_pressed
signal title_pressed
signal resume_pressed
signal level_pressed(level: int)

const PAUSE_IDLE := 45.0
const WARN_SECONDS := 3.0

static var title_text := "HedgeHog Bounce!"


class CourseBar extends Control:
	var progress := 0.0

	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var track := Rect2(0.0, y - 7.0, w, 14.0)
		draw_rect(Rect2(track.position - Vector2(3.0, 3.0), track.size + Vector2(6.0, 6.0)), ToyUI.INK, true)
		draw_rect(track, Color(0.3, 0.16, 0.08), true)
		draw_rect(Rect2(track.position, Vector2(w * progress, track.size.y)), ToyUI.AMBER, true)
		draw_rect(Rect2(track.position, Vector2(w * progress, 4.0)), Color(1.0, 0.82, 0.45), true)
		var flag := Vector2(w + 4.0, y)
		draw_line(flag, flag + Vector2(0.0, -26.0), ToyUI.INK, 5.0)
		draw_line(flag, flag + Vector2(0.0, -26.0), ToyUI.CREAM, 2.0)
		var cloth := PackedVector2Array([flag + Vector2(2.0, -26.0), flag + Vector2(20.0, -20.0), flag + Vector2(2.0, -13.0)])
		draw_colored_polygon(cloth, ToyUI.GOLD)
		draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[0]]), ToyUI.INK, 2.0)
		var p := Vector2(w * progress, y)
		draw_circle(p, 13.0, ToyUI.INK)
		draw_circle(p, 10.0, Color(0.72, 0.46, 0.28))
		draw_circle(p + Vector2(3.0, 2.0), 6.0, Color(1.0, 0.8, 0.7))
		draw_circle(p + Vector2(5.0, 0.0), 1.5, ToyUI.INK)


var hog: Node
var won := false

var _time: Label
var _kos: Label
var _chain: Label
var _chain_tween: Tween
var _best: Label
var _best_time := 0.0
var _tier := -1
var _tier_disc: ToyUI.MedalDisc
var _tier_box: HBoxContainer
var _tier_name: Label
var _tier_time: Label
var _top_left: PanelContainer
var _top_right: PanelContainer
var _hint: Control
var _muted: Label
var _title: ToyTitle
var _end: Control
var _end_card: Control
var _end_time: Label
var _end_new_best: Label
var _end_disc: ToyUI.MedalDisc
var _end_medal_name: Label
var _end_medal_hint: Label
var _end_kos: Label
var _end_chain: Label
var _end_name_box: Control
var _end_name: Label
var _end_board: RichTextLabel
var _end_prompt: Label
var _hint_tween: Tween
var _pause: Control
var _pause_medals: HBoxContainer
var _pause_level: Label
var _progress: CourseBar
var _fade: ColorRect
var _other_level: Button
var _level := 1
var _pause_idle := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_play_hud()
	_build_title()
	_build_end()
	_build_pause()
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.02, 0.01, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.45)


func _build_play_hud() -> void:
	_top_left = ToyUI.panel(ToyUI.WOOD, ToyUI.WOOD_EDGE, 16, Vector2(16.0, 8.0))
	_top_left.position = Vector2(16.0, 14.0)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left.add_child(left)
	_time = ToyUI.num("0:00.0", 50)
	_time.custom_minimum_size = Vector2(190.0, 0.0)
	left.add_child(_time)
	_tier_box = HBoxContainer.new()
	_tier_box.add_theme_constant_override("separation", 8)
	_tier_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_tier_box)
	_tier_disc = ToyUI.MedalDisc.new(24.0, 3)
	_tier_box.add_child(_tier_disc)
	_tier_name = ToyUI.label("", 22)
	_tier_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tier_box.add_child(_tier_name)
	_tier_time = ToyUI.num("", 20)
	_tier_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tier_box.add_child(_tier_time)
	add_child(_top_left)

	_progress = CourseBar.new()
	_progress.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_progress.offset_left = -230.0
	_progress.offset_right = 230.0
	_progress.offset_top = 8.0
	_progress.offset_bottom = 68.0
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	_top_right = ToyUI.panel(ToyUI.WOOD, ToyUI.WOOD_EDGE, 16, Vector2(16.0, 8.0))
	_top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.offset_right = -16.0
	_top_right.offset_top = 14.0
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_right.add_child(right)
	_best = ToyUI.num("", 22, ToyUI.GOLD)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_best)
	_kos = ToyUI.num("KOS 0", 22)
	_kos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_kos)
	_muted = ToyUI.label("muted", 18, ToyUI.HOT)
	_muted.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_muted.visible = false
	right.add_child(_muted)
	add_child(_top_right)

	_chain = ToyUI.label("", 44, ToyUI.GOLD)
	_chain.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chain.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chain.offset_left = -200.0
	_chain.offset_right = 200.0
	_chain.offset_top = 84.0
	_chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chain.pivot_offset = Vector2(200.0, 24.0)
	_chain.modulate.a = 0.0
	_chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chain)

	var hint_holder := CenterContainer.new()
	hint_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_holder.offset_bottom = -14.0
	hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_holder.modulate.a = 0.0
	add_child(hint_holder)
	_hint = hint_holder
	var card := ToyUI.panel(Color(0.17, 0.08, 0.04, 0.8), ToyUI.WOOD_EDGE, 16, Vector2(20.0, 9.0))
	hint_holder.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rows)
	var main := HBoxContainer.new()
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 34)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(main)
	main.add_child(ToyUI.key_hint(["A", "D"], "MOVE", 19))
	main.add_child(ToyUI.key_hint(["SPACE"], "JUMP", 19))
	main.add_child(ToyUI.key_hint(["SHIFT"], "HOLD: SPIKE BALL = ARMOR", 19))
	var slam := HBoxContainer.new()
	slam.alignment = BoxContainer.ALIGNMENT_CENTER
	slam.add_theme_constant_override("separation", 34)
	slam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(slam)
	slam.add_child(ToyUI.key_hint(["SPACE"], "IN AIR, CURLED: SLAM", 19))
	slam.add_child(ToyUI.key_hint(["R"], "RETRY", 19))
	slam.add_child(ToyUI.key_hint(["ESC"], "MENU", 19))
	var more := HBoxContainer.new()
	more.alignment = BoxContainer.ALIGNMENT_CENTER
	more.add_theme_constant_override("separation", 34)
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(more)
	more.add_child(ToyUI.key_hint(["F"], "FULLSCREEN", 16))
	more.add_child(ToyUI.key_hint(["M"], "MUTE", 16))
	_refresh_tier(0.0, true)


func _build_title() -> void:
	var title := ToyTitle.new()
	title.setup(title_text)
	title.level_chosen.connect(func(n: int) -> void: level_pressed.emit(n))
	_title = title
	add_child(title)


func _build_end() -> void:
	_end = Control.new()
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.04, 0.02, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(center)
	var card := ToyUI.panel(Color(0.15, 0.07, 0.03, 0.96), ToyUI.GOLD, 22, Vector2(36.0, 20.0))
	card.custom_minimum_size = Vector2(800.0, 0.0)
	center.add_child(card)
	_end_card = card
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var head := ToyUI.label("BOUNCED BACK!", 64, ToyUI.CREAM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	box.add_child(_divider())

	var result := HBoxContainer.new()
	result.alignment = BoxContainer.ALIGNMENT_CENTER
	result.add_theme_constant_override("separation", 30)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(result)
	_end_disc = ToyUI.MedalDisc.new(104.0, 0)
	result.add_child(_end_disc)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(mid)
	_end_time = ToyUI.num("", 64)
	mid.add_child(_end_time)
	_end_medal_name = ToyUI.label("", 32)
	mid.add_child(_end_medal_name)
	_end_medal_hint = ToyUI.num("", 18, Color(0.85, 0.75, 0.6))
	mid.add_child(_end_medal_hint)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(side)
	_end_new_best = ToyUI.label("NEW BEST!", 30, ToyUI.GOLD)
	side.add_child(_end_new_best)
	_end_kos = ToyUI.num("", 24)
	side.add_child(_end_kos)
	_end_chain = ToyUI.num("", 24)
	side.add_child(_end_chain)
	box.add_child(_divider())

	_end_board = ToyUI.rich(22, true)
	_end_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_end_board)

	var name_holder := CenterContainer.new()
	name_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_holder)
	_end_name_box = ToyUI.panel(Color(0.08, 0.03, 0.01, 0.9), ToyUI.AMBER, 12, Vector2(26.0, 6.0))
	_end_name_box.custom_minimum_size = Vector2(420.0, 0.0)
	_end_name = ToyUI.num("", 38, ToyUI.CREAM)
	_end_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_name_box.add_child(_end_name)
	name_holder.add_child(_end_name_box)
	_end_prompt = ToyUI.num("", 18, Color(0.85, 0.75, 0.6))
	_end_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_prompt)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	row.add_child(ToyUI.button("PLAY AGAIN", func() -> void: again_pressed.emit(), Vector2(230.0, 56.0), 24, "ENTER", true))
	_other_level = ToyUI.button("", func() -> void: level_pressed.emit(ToyLevels.next_of(_level)), Vector2(230.0, 56.0), 24, "N")
	row.add_child(_other_level)
	row.add_child(ToyUI.button("TITLE", func() -> void: title_pressed.emit(), Vector2(160.0, 56.0), 24, "ESC"))
	add_child(_end)


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = ToyUI.WOOD_EDGE
	line.custom_minimum_size = Vector2(0.0, 3.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.04, 0.02, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(center)
	var card := ToyUI.panel(Color(0.15, 0.07, 0.03, 0.96), ToyUI.WOOD_EDGE, 22, Vector2(44.0, 24.0))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var head := ToyUI.label("PAUSED", 72)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	_pause_level = ToyUI.num("", 22, ToyUI.GOLD)
	_pause_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_pause_level)
	_pause_medals = HBoxContainer.new()
	_pause_medals.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_medals.add_theme_constant_override("separation", 22)
	_pause_medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pause_medals)
	box.add_child(_divider())
	var btn := Vector2(340.0, 58.0)
	box.add_child(ToyUI.button("RESUME", func() -> void: resume_pressed.emit(), btn, 28, "ESC", true))
	box.add_child(ToyUI.button("RETRY", func() -> void: again_pressed.emit(), btn, 28, "R"))
	box.add_child(ToyUI.button("BACK TO TITLE", func() -> void: title_pressed.emit(), btn, 28, "T"))
	add_child(_pause)


func show_pause(on: bool) -> void:
	_pause.visible = on
	_pause_idle = 0.0


func _input(event: InputEvent) -> void:
	if not _pause.visible:
		return
	_pause_idle = 0.0
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE and key.keycode != KEY_R and key.keycode != KEY_T:
		return
	get_viewport().set_input_as_handled()
	match key.keycode:
		KEY_ESCAPE:
			resume_pressed.emit()
		KEY_R:
			again_pressed.emit()
		KEY_T:
			title_pressed.emit()


func _process(delta: float) -> void:
	if _pause.visible:
		_pause_idle += delta
		if _pause_idle > PAUSE_IDLE:
			title_pressed.emit()


func set_muted(on: bool) -> void:
	_muted.visible = on


func set_time(seconds: float) -> void:
	_time.text = ToyScores.format_time(seconds)
	_refresh_tier(seconds)


## The medal the run can still earn, and how close its cut-off is.
func _refresh_tier(seconds: float, force := false) -> void:
	var tier := ToyMedals.medal(_level, seconds)
	if tier != _tier or force:
		var promoted := _tier != -1 and not force
		_tier = tier
		_tier_disc.tier = tier
		_tier_name.text = ToyMedals.NAMES[tier]
		_tier_time.text = ToyScores.format_time(ToyMedals.tier_time(_level, tier)) if tier > 0 else ""
		for l in [_tier_name, _tier_time]:
			l.add_theme_color_override("font_color", ToyUI.tier_color(tier))
		if promoted:
			_tier_disc.pop()
	if tier > 0:
		var left := ToyMedals.tier_time(_level, tier) - seconds
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.016)
		_tier_box.modulate = Color.WHITE.lerp(ToyUI.HOT, pulse) if left < WARN_SECONDS else Color.WHITE
	else:
		_tier_box.modulate = Color(0.8, 0.7, 0.6)


func set_progress(value: float) -> void:
	_progress.progress = value
	_progress.queue_redraw()


## "BOUNCE x3": pops on every bounce in a chain (from the second on) and fades when it ends.
func set_chain(count: int) -> void:
	if _chain_tween:
		_chain_tween.kill()
	if count < 2:
		_chain_tween = create_tween()
		_chain_tween.tween_property(_chain, "modulate:a", 0.0, 0.25)
		return
	_chain.text = "BOUNCE x%d" % count
	_chain.modulate = Color.WHITE.lerp(ToyUI.HOT, minf((count - 2) / 6.0, 1.0))
	_chain.scale = Vector2.ONE * 1.35
	_chain_tween = create_tween()
	_chain_tween.tween_property(_chain, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_kos(count: int) -> void:
	_kos.text = "KOS %d" % count


func set_best(seconds: float) -> void:
	_best_time = seconds
	_best.text = "BEST %s" % ToyScores.format_time(seconds) if seconds > 0.0 else ""
	_best.visible = seconds > 0.0


func _set_play_hud(on: bool) -> void:
	_top_left.visible = on
	_top_right.visible = on
	_progress.visible = on


func set_level(level: int) -> void:
	_level = level
	_title.set_level(level)
	_other_level.text = "NEXT LEVEL" if level < ToyLevels.count else "LEVEL 1"
	_refresh_tier(0.0, true)
	_pause_level.text = ToyLevels.name_of(level)
	for child in _pause_medals.get_children():
		child.queue_free()
	for tier in [3, 2, 1]:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 6)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(ToyUI.MedalDisc.new(22.0, tier))
		var t := ToyUI.num(ToyScores.format_time(ToyMedals.tier_time(level, tier)), 22, ToyUI.tier_color(tier))
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(t)
		_pause_medals.add_child(group)


func show_title(scores: Array) -> void:
	_set_play_hud(false)
	_title.set_board(scores)
	_title.restart()
	_title.modulate.a = 1.0
	_title.visible = true


func hide_title(show_hud := true) -> void:
	_set_play_hud(show_hud)
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _title.visible = false)


func show_hint(seconds: float) -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.3)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


func show_end(time: float, kos: int, best_combo: int, entering: bool, scores: Array) -> void:
	if won:
		return
	won = true
	_hint.modulate.a = 0.0
	var tier := ToyMedals.medal(_level, time)
	_end_time.text = ToyScores.format_time(time)
	_end_disc.tier = tier
	_end_disc.pop(0.3)
	_end_medal_name.text = ToyMedals.NAMES[tier]
	_end_medal_name.add_theme_color_override("font_color", ToyUI.tier_color(tier))
	if tier == 3:
		_end_medal_hint.text = "PERFECT RUN!"
	elif tier == 0:
		_end_medal_hint.text = "BRONZE IS %s" % ToyScores.format_time(ToyMedals.tier_time(_level, 1))
	else:
		_end_medal_hint.text = "%s FASTER FOR %s" % [ToyScores.format_time(time - ToyMedals.tier_time(_level, tier + 1)), ToyMedals.NAMES[tier + 1]]
	_end_new_best.visible = _best_time <= 0.0 or time < _best_time
	_end_kos.text = "KOS  %d" % kos
	_end_chain.text = "BEST CHAIN  x%d" % best_combo
	_end_card.add_theme_stylebox_override("panel", ToyUI.panel_style(Color(0.15, 0.07, 0.03, 0.96), ToyUI.tier_color(tier) if tier > 0 else ToyUI.WOOD_EDGE, 22, Vector2(36.0, 20.0)))
	if entering:
		_end_board.text = "[center][color=#ffd23f]NEW TOP 5!  TYPE YOUR NAME[/color][/center]"
		set_name_text("")
		_end_prompt.text = "PRESS ENTER TO SAVE"
		_end_prompt.visible = true
	else:
		_end_name_box.visible = false
		_end_prompt.visible = false
		_end_board.text = _board_text(scores)
	_end.modulate.a = 0.0
	_end.visible = true
	create_tween().tween_property(_end, "modulate:a", 1.0, 0.5)


func set_name_text(name_text: String) -> void:
	_end_name_box.visible = true
	_end_name.text = "%s_" % name_text


func show_board(scores: Array, rank: int) -> void:
	_end_name_box.visible = false
	_end_prompt.visible = false
	_end_board.text = _board_text(scores, rank)


func _board_text(scores: Array, highlight := -1) -> String:
	return "[center][color=#ffd23f]BEST TIMES[/color]\n%s[/center]" % ToyUI.scores_bbcode(scores, highlight)
