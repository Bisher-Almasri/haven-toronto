class_name Ghost3D
extends Node3D

# One sample every STEP physics frames: x, y, rotation, curled (0/1), facing.
const STEP := 2
const FLOATS := 5

var rec := PackedFloat32Array()
var _sprite: Sprite3D


func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.pixel_size = 0.01
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.modulate = Color(0.75, 0.9, 1.0, 0.42)
	add_child(_sprite)
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
	global_position = Vector3(lerpf(rec[a], rec[b], f), lerpf(rec[a + 1], rec[b + 1], f), 0.1)
	if rec[a + 3] > 0.5:
		_sprite.texture = Hog3D.TEX_SPIKE
		_sprite.offset = Vector2(10.0, 1.5)
		_sprite.position = Vector3.ZERO
		_sprite.scale = Vector3(0.67, 0.67, 1.0)
		rotation.z = lerp_angle(rec[a + 2], rec[b + 2], f)
	else:
		_sprite.texture = Hog3D.TEX_STAND
		_sprite.offset = Vector2(8.0, 63.0)
		_sprite.position = Vector3(0.0, -Hog3D.RADIUS, 0.0)
		_sprite.scale = Vector3(0.6 * rec[a + 4], 0.6, 1.0)
		rotation.z = 0.0
