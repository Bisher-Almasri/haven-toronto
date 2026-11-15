extends CanvasLayer

class HeartsView extends Control:
	var hp := 3
	var max_hp := 3

	func _draw() -> void:
		for i in max_hp:
			var color := Color(0.9, 0.2, 0.25) if i < hp else Color(0.25, 0.1, 0.1, 0.6)
			var points := PackedVector2Array()
			for s in 32:
				var t := TAU * float(s) / 32.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				points.append(Vector2(x, y) * 1.3 + Vector2(28.0 + i * 54.0, 28.0))
			draw_colored_polygon(points, color)
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0.2, 0.05, 0.05), 3.0)


class ClimbView extends Control:
	var progress := 0.0

	func _draw() -> void:
		var rect := Rect2(Vector2(10.0, 10.0), size - Vector2(20.0, 20.0))
		draw_rect(rect, Color(0.1, 0.05, 0.03, 0.55))
		var fill := rect
		fill.size.y *= progress
		fill.position.y = rect.end.y - fill.size.y
		draw_rect(fill, Color(0.95, 0.6, 0.2, 0.9))
		draw_circle(Vector2(size.x * 0.5, rect.end.y - rect.size.y * progress), 9.0, Color(1.0, 0.7, 0.6))
		draw_circle(Vector2(size.x * 0.5, rect.position.y - 2.0), 11.0, Color(1.0, 0.8, 0.2))

var player: Player
var _hearts: HeartsView
var _climb: ClimbView
var _title: Control
var _hint: Label
var _win: Control
var _win_sub: Label
var _fade: ColorRect
var _timer: Label
var _toast: Label
var _toast_tween: Tween
var _pause: Control
var _muted: Label


func _ready() -> void:
	layer = 10

	_hearts = HeartsView.new()
	_hearts.position = Vector2(24.0, 18.0)
	_hearts.size = Vector2(200.0, 60.0)
	add_child(_hearts)

	_climb = ClimbView.new()
	_climb.anchor_left = 1.0
	_climb.anchor_right = 1.0
	_climb.anchor_top = 0.5
	_climb.anchor_bottom = 0.5
	_climb.offset_left = -50.0
	_climb.offset_right = -10.0
	_climb.offset_top = -170.0
	_climb.offset_bottom = 170.0
	add_child(_climb)

	_hint = _make_label("A / D or arrows: move     Space / W: jump     Hold Shift / X: spike ball\nR: restart     M: mute     Esc: pause", 22)
	_hint.add_theme_stylebox_override("normal", _panel_style())
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -18.0
	_hint.visible = false
	add_child(_hint)

	_timer = _make_label("00:00.0", 28)
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer.offset_top = 14.0
	_timer.visible = false
	add_child(_timer)

	_toast = _make_label("", 26)
	_toast.add_theme_stylebox_override("normal", _panel_style())
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 66.0
	_toast.modulate.a = 0.0
	add_child(_toast)

	_muted = _make_label("MUTED", 20)
	_muted.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_muted.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_muted.offset_left = -110.0
	_muted.offset_right = -70.0
	_muted.offset_top = 14.0
	_muted.visible = false
	add_child(_muted)

	_title = _make_overlay("HedgeHog Bounce!", "Press Space to start", 96)
	add_child(_title)
	var credit := _make_label("Made for a game jam with Godot 4   -   all sounds and music generated in code", 18)
	credit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	credit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_bottom = -14.0
	_title.add_child(credit)
	var prompt: Label = _title.get_child(0).get_child(1)
	var blink := create_tween().set_loops()
	blink.tween_property(prompt, "modulate:a", 0.25, 0.7)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.7)

	_win = _make_overlay("Bounced back!", "You made it home to the forest!\nPress Enter or R to play again", 96)
	_win.visible = false
	_win_sub = _win.get_child(0).get_child(1)
	add_child(_win)

	_pause = _make_overlay("Paused", "Esc to resume   -   R to restart   -   M to mute", 80)
	_pause.visible = false
	add_child(_pause)

	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.02, 0.01, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _process(_delta: float) -> void:
	if player:
		_climb.progress = clampf(1.0 - player.global_position.y / 2800.0, 0.0, 1.0)
		_climb.queue_redraw()


func set_hp(hp: int, max_hp: int) -> void:
	_hearts.hp = hp
	_hearts.max_hp = max_hp
	_hearts.queue_redraw()


func skip_title() -> void:
	_title.visible = false


func start_game() -> void:
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: _title.visible = false)
	_hint.visible = true
	_hint.modulate.a = 1.0
	_timer.visible = true
	var hide_hint := create_tween()
	hide_hint.tween_interval(10.0)
	hide_hint.tween_property(_hint, "modulate:a", 0.0, 1.5)


func set_time(seconds: float) -> void:
	_timer.text = format_time(seconds)


static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	return "%02d:%04.1f" % [m, seconds - m * 60]


func show_toast(text: String, seconds := 4.5) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func set_paused(on: bool) -> void:
	_pause.visible = on


func set_muted(on: bool) -> void:
	_muted.visible = on


func show_win(time: float, deaths: int, best: float, new_best: bool) -> void:
	_hint.visible = false
	_toast.modulate.a = 0.0
	var line := "Time %s     Deaths %d     Best %s%s" % [format_time(time), deaths, format_time(best), "  (new!)" if new_best else ""]
	_win_sub.text = "You made it home to the forest!\n%s\nPress Enter or R to play again" % line
	_win.modulate.a = 0.0
	_win.visible = true
	create_tween().tween_property(_win, "modulate:a", 1.0, 0.8)


func fade_to(alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	return tween


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.05, 0.02, 0.62)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.04))
	label.add_theme_constant_override("outline_size", maxi(font_size / 6, 4))
	return label


func _make_overlay(title: String, subtitle: String, title_size: int) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -260.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.add_child(_make_label(title, title_size))
	box.add_child(_make_label(subtitle, 34))
	return root
