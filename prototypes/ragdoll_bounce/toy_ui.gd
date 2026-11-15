class_name ToyUI

# Shared look for every screen: title, HUD, pause and finish.

const FONT := preload("res://augiepixel.ttf")

const INK := Color(0.20, 0.08, 0.03)
const CREAM := Color(1.0, 0.94, 0.75)
const GOLD := Color(1.0, 0.82, 0.28)
const SILVER := Color(0.84, 0.88, 0.92)
const BRONZE := Color(0.82, 0.54, 0.30)
const AMBER := Color(0.98, 0.62, 0.18)
const WOOD := Color(0.17, 0.08, 0.04, 0.88)
const WOOD_EDGE := Color(0.46, 0.25, 0.10)
const HOT := Color(1.0, 0.48, 0.36)


class MedalDisc extends Control:
	var tier := 0:
		set(value):
			tier = value
			queue_redraw()

	func _init(disc_size := 40.0, medal_tier := 0) -> void:
		custom_minimum_size = Vector2(disc_size, disc_size * 1.25)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tier = medal_tier
		resized.connect(func() -> void: pivot_offset = size * 0.5)

	func pop(delay := 0.0) -> void:
		scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var w := size.x
		var r := w * 0.5 - 2.0
		var center := Vector2(w * 0.5, size.y - w * 0.5)
		var base := ToyUI.tier_color(tier)
		if tier == 0:
			draw_arc(center, r - 2.0, 0.0, TAU, 28, Color(0.7, 0.6, 0.5, 0.55), 3.0)
			return
		var ribbon := Color(0.78, 0.2, 0.16) if tier != 2 else Color(0.25, 0.45, 0.78)
		var rw := w * 0.26
		for side in [-1.0, 1.0]:
			var x: float = center.x + side * w * 0.17
			var pts := PackedVector2Array([Vector2(x - rw * 0.5, 0.0), Vector2(x + rw * 0.5, 0.0), Vector2(x + rw * 0.5 + side * 3.0, center.y), Vector2(x - rw * 0.5 + side * 3.0, center.y)])
			draw_colored_polygon(pts, ribbon)
			draw_polyline(PackedVector2Array([pts[0], pts[3], pts[2], pts[1]]), ToyUI.INK, 2.0)
		draw_circle(center, r + 2.0, ToyUI.INK)
		draw_circle(center, r, base.darkened(0.22))
		draw_circle(center, r * 0.84, base)
		draw_arc(center, r * 0.62, 0.0, TAU, 24, base.darkened(0.3), maxf(w * 0.04, 1.5))
		draw_arc(center, r * 0.9, PI * 1.05, PI * 1.6, 12, Color(1, 1, 1, 0.75), maxf(w * 0.05, 2.0))
		var star := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + i * PI / 5.0
			var rad := r * (0.46 if i % 2 == 0 else 0.2)
			star.append(center + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(star, base.lightened(0.45))
		draw_polyline(star + PackedVector2Array([star[0]]), base.darkened(0.45), 1.5)


static var _num_font: FontVariation


## The pixel font draws 1 like 2, so anything with digits uses a clear bold font.
static func num_font() -> Font:
	if _num_font == null:
		_num_font = FontVariation.new()
		_num_font.base_font = ThemeDB.fallback_font
		_num_font.variation_embolden = 0.5
	return _num_font


static func tier_color(tier: int) -> Color:
	match tier:
		3:
			return GOLD
		2:
			return SILVER
		1:
			return BRONZE
	return Color(0.7, 0.6, 0.5)


static func panel_style(bg := WOOD, edge := WOOD_EDGE, radius := 16, pad := Vector2(22.0, 12.0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(3)
	sb.border_color = edge
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	sb.shadow_color = Color(0.05, 0.02, 0.0, 0.4)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0.0, 4.0)
	return sb


static func panel(bg := WOOD, edge := WOOD_EDGE, radius := 16, pad := Vector2(22.0, 12.0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, edge, radius, pad))
	return p


static func label(text: String, size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(size / 6, 3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func num(text: String, size: int, color := CREAM) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", num_font())
	return l


static func rich(size: int, numeric := false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["normal_font", "bold_font"]:
		r.add_theme_font_override(key, num_font() if numeric else FONT)
	for key in ["normal_font_size", "bold_font_size"]:
		r.add_theme_font_size_override(key, size)
	r.add_theme_color_override("default_color", CREAM)
	r.add_theme_color_override("font_outline_color", INK)
	r.add_theme_constant_override("outline_size", maxi(size / 6, 3))
	return r


static func keycap(text: String, size := 18) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.95, 0.8)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 5
	sb.border_color = Color(0.6, 0.38, 0.18)
	sb.content_margin_left = 9.0
	sb.content_margin_right = 9.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 0.0
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", sb)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", num_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(l)
	return cap


## A key hint: one or more key caps followed by what they do.
static func key_hint(keys: Array, text: String, size := 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in keys:
		row.add_child(keycap(str(key), size))
	var l := label(text, size)
	l.add_theme_constant_override("outline_size", 3)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


static func button(text: String, on_press: Callable, min_size := Vector2(240.0, 58.0), font_size := 26, key := "", primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 4)
	var fills := {
		"normal": Color(0.62, 0.32, 0.11) if not primary else Color(0.86, 0.46, 0.12),
		"hover": Color(0.82, 0.44, 0.13) if not primary else Color(1.0, 0.6, 0.18),
		"pressed": Color(0.98, 0.72, 0.28)}
	for state in fills:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fills[state]
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 3 if state == "pressed" else 7
		sb.border_color = INK
		sb.content_margin_top = 4.0 if state == "pressed" else 0.0
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(on_press)
	if key != "":
		var cap := keycap(key, 14)
		cap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		cap.offset_right = -10.0
		cap.offset_top = -12.0
		b.add_child(cap)
	return b


static func scores_bbcode(scores: Array, highlight := -1) -> String:
	if scores.is_empty():
		return "No times yet. Be the first!"
	var out := "[table=4]"
	for i in scores.size():
		var entry: Dictionary = scores[i]
		var color := tier_color(3 - i).to_html(false) if i < 3 else "ffeec0"
		if i == highlight:
			color = "ffffff"
		var mark := "  <" if i == highlight else ""
		out += "[cell padding=12,1,12,1][color=#%s]%d.[/color][/cell]" % [color, i + 1]
		out += "[cell padding=12,1,12,1][color=#%s]%s[/color][/cell]" % [color, str(entry["name"])]
		out += "[cell padding=12,1,12,1][color=#%s]%s%s[/color][/cell]" % [color, ToyScores.format_time(float(entry["time"])), mark]
		out += "[cell padding=12,1,12,1][color=#c9a67f]%d KO[/color][/cell]" % int(entry["kos"])
	return out + "[/table]"
