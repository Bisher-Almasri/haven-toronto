class_name ToyGhost
extends Node2D

# One sample every STEP physics frames: x, y, rotation, curled (0/1), facing.
const STEP := 2
const FLOATS := 5
const TEX_STAND := preload("res://hedgehog_ingame_stand.png")
const TEX_SPIKE := preload("res://hedgehog_spike.png")

var rec := PackedFloat32Array()
var _sprite: Sprite2D


func _ready() -> void:
	z_index = -1
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	modulate = Color(0.75, 0.9, 1.0, 0.42)
	visible = false


func sample_count() -> int:
	return rec.size() / FLOATS


func show_at(frame: int) -> void:
	var n := sample_count()
	var i := frame / STEP
	if n < 2 or i >= n - 1:
		visible = false
		return
	visible = true
	var a := i * FLOATS
	var b := a + FLOATS
	var f := float(frame % STEP) / float(STEP)
	global_position = Vector2(lerpf(rec[a], rec[b], f), lerpf(rec[a + 1], rec[b + 1], f))
	var rot := lerp_angle(rec[a + 2], rec[b + 2], f)
	var facing := rec[a + 4]
	if rec[a + 3] > 0.5:
		_sprite.texture = TEX_SPIKE
		_sprite.offset = Vector2(10.0, -1.5)
		_sprite.position = Vector2.ZERO
		_sprite.scale = Vector2(0.67, 0.67)
		rotation = rot
	else:
		_sprite.texture = TEX_STAND
		_sprite.offset = Vector2(8.0, -63.0)
		_sprite.position = Vector2(0.0, ToyHog.RADIUS)
		_sprite.scale = Vector2(0.6 * facing, 0.6)
		rotation = 0.0
