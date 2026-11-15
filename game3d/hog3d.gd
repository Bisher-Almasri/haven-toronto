class_name Hog3D
extends RigidBody3D

signal knocked_out
signal bounced
signal big_hit(strength: float)
signal jumped
signal launched
signal respawned
signal curl_changed(on: bool)
signal chain_changed(count: int)

# Same tuning as the 2D hedgehog, in metres (100 px = 1 m).
const RADIUS := 0.28
const GRAVITY_SCALE := 1.7
const RUN_SPEED := 4.4
const GROUND_ACCEL := 26.0
const GROUND_BRAKE := 15.0
const AIR_ACCEL := 15.0
const TURN_BOOST := 1.6
const JUMP_SPEED := 8.8
const JUMP_CUT := 0.45
const ROLL_ACCEL := 70.0
const ROLL_MAX := 24.0
const BOUNCE_CURLED := 0.88
const BOUNCE_PLUSH := 0.3
const PUMP_SPEED := 11.0
const COYOTE_FRAMES := 6
const BUFFER_FRAMES := 8
const KO_TIME := 1.0
const CHAIN_RESET_FRAMES := 27
const CHAIN_BONUS := 0.05
const CHAIN_BONUS_MAX := 5
const CURLED_BOUNCE_BONUS := 0.12

const TEX_STAND := preload("res://FINAL_GOOD_ingame_standing_1.png")
const TEX_BLINK := preload("res://Final_good_igame_standing_2_blink.png")
const BLINK_TIME := 0.14
const TEX_WALK := [
	preload("res://walking_0.png"),
	preload("res://walking_1.png"),
	preload("res://walking_2.png"),
]
const WALK_ORDER := [0, 1, 2, 1]
const TEX_SPIKE := preload("res://hedgehog_spike.png")
const TEX_DEAD := preload("res://hedgehog_dead.png")

var curled := false
var ko := false
var grounded := false
var active := true
var respawn_point := Vector3.ZERO
var kos := 0
var bounce_count := 0
var chain := 0
var facing := 1.0
var last_ground_normal := Vector3.UP

var _mat := PhysicsMaterial.new()
var _pending_teleport: Variant = null
var _pending_velocity := Vector3.ZERO
var _jump_buffer_until := -1
var _last_ground_frame := -1000
var _ground_frames := 0
var _can_cut := false
var _jump_held := false
var _dir := 0.0
var _pump_pressed := false
var _pump_ready := true
var _pulse := 0.0
var _grace_until := 0
var _ballistic := false
var _drift_pending := false
var _drift_target := Vector3.ZERO
var _drift_y := 0.9
var _match_spin := false
var _vis_rot := 0.0
var _walk_time := 0.0
var _blink_in := 2.5
var _blink_left := 0.0
var _visual: Node3D
var _sprite: Sprite3D
var _outline := ShaderMaterial.new()
var _lantern: OmniLight3D


func _ready() -> void:
	add_to_group("hog")
	mass = 1.0
	gravity_scale = GRAVITY_SCALE
	collision_layer = 2
	collision_mask = 1 | 4
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	can_sleep = false
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.05
	angular_damp = 6.0
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	_mat.friction = 0.9
	_mat.bounce = BOUNCE_PLUSH
	physics_material_override = _mat

	_visual = Node3D.new()
	_visual.top_level = true
	add_child(_visual)
	_sprite = Sprite3D.new()
	_sprite.pixel_size = 0.01
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_outline.shader = load("res://shaders/sprite_outline_3d.gdshader")
	_sprite.material_override = _outline
	_visual.add_child(_sprite)
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.82, 0.55)
	_lantern.light_energy = 0.75
	_lantern.omni_range = 7.0
	_lantern.light_specular = 0.0
	_lantern.top_level = true
	add_child(_lantern)
	respawn_point = global_position
	_update_visual(0.0)


func gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity")) * GRAVITY_SCALE


func _physics_process(_delta: float) -> void:
	var live := active and not ko
	_dir = Input.get_axis("move_left", "move_right") if live else 0.0
	_jump_held = live and Input.is_action_pressed("jump")
	if live and Input.is_action_just_pressed("jump"):
		_jump_buffer_until = Engine.get_physics_frames() + BUFFER_FRAMES
		_pump_pressed = true
	var want_curl := live and Input.is_action_pressed("spike")
	if want_curl != curled:
		_match_spin = want_curl
		curled = want_curl
		curl_changed.emit(curled)
		_mat.bounce = BOUNCE_CURLED if curled else BOUNCE_PLUSH
		angular_damp = 0.4 if curled else 6.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport != null:
		state.transform = Transform3D(Basis.IDENTITY, _pending_teleport as Vector3)
		state.linear_velocity = _pending_velocity
		state.angular_velocity = Vector3.ZERO
		_pending_teleport = null
		return

	var frame := Engine.get_physics_frames()
	var origin := state.transform.origin
	grounded = false
	var impact := 0.0
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		n.z = 0.0
		if n.length() > 0.1:
			n = n.normalized()
			if absf(n.y) > 0.55 and state.get_contact_local_position(i).y < origin.y:
				grounded = true
				last_ground_normal = n if n.y > 0.0 else -n
		impact = maxf(impact, state.get_contact_impulse(i).length())
	if grounded:
		_last_ground_frame = frame
		_pump_ready = true
		_ground_frames += 1
		if _ground_frames > CHAIN_RESET_FRAMES:
			_set_chain(0)
	else:
		_ground_frames = 0
	if impact > 3.5:
		_pulse = minf(impact / 25.0, 0.25)
		if impact > 9.0:
			big_hit.emit(minf(impact / 25.0, 1.0))

	var dt := state.step
	var v := state.linear_velocity
	v.z = 0.0
	# 2D convention: positive spin = rolling to the right
	var w := -state.angular_velocity.z
	var up_normal := last_ground_normal
	var tangent_now := Vector3(up_normal.y, -up_normal.x, 0.0)

	if _match_spin:
		_match_spin = false
		if grounded:
			w = v.dot(tangent_now) / RADIUS
	if _ballistic:
		if _drift_pending and origin.y > _drift_y:
			_drift_pending = false
			var up_speed := v.y
			var t_up := up_speed / gravity()
			var apex := origin.y + up_speed * up_speed / (2.0 * gravity())
			var t_down := sqrt(2.0 * maxf(apex - _drift_target.y, 0.01) / gravity())
			v.x = (_drift_target.x - origin.x) / (t_up + t_down)
			facing = signf(v.x) if v.x != 0.0 else facing
		if grounded:
			_ballistic = false
	elif ko:
		pass
	elif curled:
		if _dir != 0.0:
			w = move_toward(w, _dir * ROLL_MAX, ROLL_ACCEL * dt)
			facing = signf(_dir)
			if not grounded:
				v.x = move_toward(v.x, _dir * RUN_SPEED, AIR_ACCEL * 0.5 * dt)
		if _pump_pressed and not grounded and _pump_ready:
			v.y = minf(v.y, 0.0) - PUMP_SPEED
			_pump_ready = false
			_pulse = 0.2
	else:
		var along := v.x
		var tangent := Vector3.RIGHT
		if grounded:
			tangent = tangent_now
			along = v.dot(tangent)
		if _dir != 0.0:
			facing = signf(_dir)
			along = _drive(along, _dir, GROUND_ACCEL if grounded else AIR_ACCEL, dt)
		elif grounded:
			along = move_toward(along, 0.0, GROUND_BRAKE * dt)
			if absf(along) < 0.2:
				along = 0.0
		if grounded:
			v = tangent * along + up_normal * v.dot(up_normal)
		else:
			v.x = along

		var coyote_ok := frame - _last_ground_frame <= COYOTE_FRAMES
		if frame <= _jump_buffer_until and coyote_ok:
			v.y = JUMP_SPEED
			_jump_buffer_until = -1
			_last_ground_frame = -1000
			_can_cut = true
			_pulse = 0.12
			jumped.emit()
		if _can_cut:
			if v.y <= 0.0:
				_can_cut = false
			elif not _jump_held:
				v.y *= JUMP_CUT
				_can_cut = false
	_pump_pressed = false

	state.linear_velocity = v
	state.angular_velocity = Vector3(0.0, 0.0, -w)


func _drive(along: float, dir: float, accel: float, dt: float) -> float:
	if signf(along) == dir and absf(along) >= RUN_SPEED:
		return along
	var boost := TURN_BOOST if signf(along) == -dir else 1.0
	return move_toward(along, dir * RUN_SPEED, accel * boost * dt)


## A spike ball gets a bigger mushroom bounce than a plush hedgehog, and every bounce in a row
## (no resting on the ground in between) throws it a little higher still.
func bounce_bonus() -> float:
	if not curled:
		return 1.0
	return 1.0 + CURLED_BOUNCE_BONUS + CHAIN_BONUS * minf(chain, CHAIN_BONUS_MAX)


func bounce_up(height: float, bonus := 1.0) -> void:
	var boost := 1.3 if Input.is_action_pressed("jump") and active else 1.0
	linear_velocity.y = sqrt(2.0 * gravity() * height * boost * bonus)
	_can_cut = false
	_ground_frames = 0
	_pulse = 0.25 + 0.03 * minf(chain, CHAIN_BONUS_MAX)
	bounce_count += 1
	_set_chain(chain + 1)
	bounced.emit()


## A spike ball that gets hit (by a boulder, say) rebounds off it instead of being hurt.
func shove_back(from_pos: Vector3, strength: float) -> void:
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	var push := clampf(strength, 4.0, 14.0)
	linear_velocity = Vector3(away * push * 0.8, maxf(linear_velocity.y, 0.0) + push * 0.75, 0.0)
	angular_velocity = Vector3(0.0, 0.0, -away * 14.0)
	_ground_frames = 0
	_pulse = 0.3
	bounce_count += 1
	_set_chain(chain + 1)
	bounced.emit()


func _set_chain(value: int) -> void:
	if value == chain:
		return
	chain = value
	chain_changed.emit(chain)


## target and apex_y are world metres (y up).
func launch_to(target: Vector3, apex_y: float, drift_y := 0.9) -> void:
	var rise := maxf(apex_y - global_position.y, 0.01)
	linear_velocity = Vector3(0.0, sqrt(2.0 * gravity() * rise), 0.0)
	_drift_target = target
	_drift_y = drift_y
	_drift_pending = true
	_ballistic = true
	_can_cut = false
	_pulse = 0.3
	bounce_count += 1
	launched.emit()


func knock_out(from_pos: Vector3) -> void:
	if ko or Engine.get_physics_frames() < _grace_until:
		return
	ko = true
	curled = false
	kos += 1
	_set_chain(0)
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	linear_velocity = Vector3(away * 3.5, 6.5, 0.0)
	angular_velocity = Vector3(0.0, 0.0, -away * 9.0)
	_mat.bounce = 0.45
	angular_damp = 0.3
	knocked_out.emit()
	get_tree().create_timer(KO_TIME).timeout.connect(respawn)


func respawn() -> void:
	if not ko:
		return
	ko = false
	_grace_until = Engine.get_physics_frames() + 45
	_mat.bounce = BOUNCE_PLUSH
	angular_damp = 6.0
	_pending_teleport = respawn_point
	_pending_velocity = Vector3(0.0, sqrt(2.0 * gravity() * 3.8), 0.0)
	respawned.emit()


func _process(delta: float) -> void:
	_update_visual(delta)


# The 2D art, drawn with the old offsets (y flipped: Sprite3D has y up).
func _update_visual(delta: float) -> void:
	_visual.global_position = global_position + Vector3(0.0, 0.0, 0.3)
	_lantern.global_position = global_position + Vector3(0.0, 0.5, 1.2)
	_pulse = maxf(_pulse - delta * 1.2, 0.0)
	var rot_z := rotation.z
	if ko:
		_sprite.texture = TEX_DEAD
		_sprite.offset = Vector2(6.0, 38.0)
		_sprite.position = Vector3(0.0, -RADIUS, 0.0)
		_sprite.scale = Vector3(0.6 * facing, 0.6, 1.0)
		_vis_rot = rot_z
	elif curled:
		_sprite.texture = TEX_SPIKE
		_sprite.offset = Vector2(10.0, 1.5)
		_sprite.position = Vector3.ZERO
		_sprite.scale = Vector3(0.67, 0.67, 1.0)
		_vis_rot = rot_z
	else:
		_sprite.offset = Vector2(8.0, 63.0)
		_sprite.position = Vector3(0.0, -RADIUS, 0.0)
		_sprite.scale = Vector3(0.6 * facing, 0.6, 1.0)
		if grounded and absf(linear_velocity.x) > 0.3:
			_walk_time += delta * 5.5 * clampf(absf(linear_velocity.x) / RUN_SPEED, 0.5, 1.0)
			_sprite.texture = TEX_WALK[WALK_ORDER[int(_walk_time) % WALK_ORDER.size()]]
		else:
			_blink_in -= delta
			if _blink_in <= 0.0:
				_blink_left = BLINK_TIME
				_blink_in = randf_range(2.5, 5.0)
			_blink_left = maxf(_blink_left - delta, 0.0)
			_sprite.texture = TEX_BLINK if _blink_left > 0.0 else TEX_STAND
		if grounded:
			var lean := clampf(-linear_velocity.x / RUN_SPEED * 0.12, -0.15, 0.15)
			_vis_rot = lerp_angle(_vis_rot, lean, minf(delta * 14.0, 1.0))
		else:
			_vis_rot = lerp_angle(_vis_rot, rot_z, minf(delta * 12.0, 1.0))
	_outline.set_shader_parameter("tex", _sprite.texture)
	_visual.basis = Basis(Vector3.BACK, _vis_rot).scaled(Vector3.ONE * (1.0 + _pulse))
