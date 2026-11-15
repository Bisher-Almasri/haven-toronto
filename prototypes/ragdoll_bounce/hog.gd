class_name ToyHog
extends RigidBody2D

signal knocked_out
signal bounced
signal big_hit(strength: float)
signal jumped
signal launched
signal respawned
signal curl_changed(on: bool)

# ---- tuning: one-line retunes ----
const RADIUS := 28.0
const GRAVITY_SCALE := 1.7
const RUN_SPEED := 440.0
const GROUND_ACCEL := 2600.0
const GROUND_BRAKE := 1500.0
const AIR_ACCEL := 1500.0
const TURN_BOOST := 1.6
const JUMP_SPEED := 880.0
const JUMP_CUT := 0.45
const ROLL_ACCEL := 70.0
const ROLL_MAX := 24.0
const BOUNCE_CURLED := 0.8
const BOUNCE_PLUSH := 0.3
const PUMP_SPEED := 1100.0
const COYOTE_FRAMES := 6
const BUFFER_FRAMES := 8
const KO_TIME := 1.0

const TEX_STAND := preload("res://hedgehog_ingame_stand.png")
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
var respawn_point := Vector2.ZERO
var kos := 0
var bounce_count := 0
var facing := 1.0
var last_ground_normal := Vector2.UP

var _mat := PhysicsMaterial.new()
var _pending_teleport: Variant = null
var _pending_velocity := Vector2.ZERO
var _jump_buffer_until := -1
var _last_ground_frame := -1000
var _can_cut := false
var _jump_held := false
var _dir := 0.0
var _pump_pressed := false
var _pump_ready := true
var _pulse := 0.0
var _grace_until := 0
var _ballistic := false
var _drift_pending := false
var _drift_target := Vector2.ZERO
var _drift_y := -90.0
var _match_spin := false
var _vis_rot := 0.0
var _walk_time := 0.0
var _visual: Node2D
var _sprite: Sprite2D


func _ready() -> void:
	mass = 1.0
	gravity_scale = GRAVITY_SCALE
	collision_layer = 2
	collision_mask = 1 | 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 6
	can_sleep = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.05
	angular_damp = 6.0
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	_mat.friction = 0.9
	_mat.bounce = BOUNCE_PLUSH
	physics_material_override = _mat

	_visual = Node2D.new()
	_visual.top_level = true
	add_child(_visual)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sprite_outline.gdshader")
	_sprite.material = material
	_visual.add_child(_sprite)
	respawn_point = global_position
	_update_visual(0.0)


func gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity")) * GRAVITY_SCALE


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


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _pending_teleport != null:
		state.transform = Transform2D(0.0, _pending_teleport as Vector2)
		state.linear_velocity = _pending_velocity
		state.angular_velocity = 0.0
		_pending_teleport = null
		return

	var frame := Engine.get_physics_frames()
	grounded = false
	var impact := 0.0
	for i in state.get_contact_count():
		var n := state.get_contact_local_normal(i)
		if n.y > 0.55:
			n = -n
		if n.y < -0.55:
			grounded = true
			last_ground_normal = n
		impact = maxf(impact, state.get_contact_impulse(i).length())
	if grounded:
		_last_ground_frame = frame
		_pump_ready = true
	if impact > 350.0:
		_pulse = minf(impact / 2500.0, 0.25)
		if impact > 900.0:
			big_hit.emit(minf(impact / 2500.0, 1.0))

	var dt := state.step
	var v := state.linear_velocity
	var w := state.angular_velocity

	if _match_spin:
		_match_spin = false
		if grounded:
			var tangent_now := Vector2(-last_ground_normal.y, last_ground_normal.x)
			w = v.dot(tangent_now) / RADIUS
	if _ballistic:
		if _drift_pending and state.transform.origin.y < _drift_y:
			_drift_pending = false
			var up_speed := -v.y
			var t_up := up_speed / gravity()
			var apex := state.transform.origin.y - up_speed * up_speed / (2.0 * gravity())
			var t_down := sqrt(2.0 * maxf(_drift_target.y - apex, 1.0) / gravity())
			v.x = (_drift_target.x - state.transform.origin.x) / (t_up + t_down)
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
			v.y = maxf(v.y, 0.0) + PUMP_SPEED
			_pump_ready = false
			_pulse = 0.2
	else:
		var along := v.x
		var tangent := Vector2.RIGHT
		if grounded:
			tangent = Vector2(-last_ground_normal.y, last_ground_normal.x)
			along = v.dot(tangent)
		if _dir != 0.0:
			facing = signf(_dir)
			along = _drive(along, _dir, GROUND_ACCEL if grounded else AIR_ACCEL, dt)
		elif grounded:
			along = move_toward(along, 0.0, GROUND_BRAKE * dt)
			if absf(along) < 20.0:
				along = 0.0
		if grounded:
			v = tangent * along + last_ground_normal * v.dot(last_ground_normal)
		else:
			v.x = along

		var coyote_ok := frame - _last_ground_frame <= COYOTE_FRAMES
		if frame <= _jump_buffer_until and coyote_ok:
			v.y = -JUMP_SPEED
			_jump_buffer_until = -1
			_last_ground_frame = -1000
			_can_cut = true
			_pulse = 0.12
			jumped.emit()
		if _can_cut:
			if v.y >= 0.0:
				_can_cut = false
			elif not _jump_held:
				v.y *= JUMP_CUT
				_can_cut = false
	_pump_pressed = false

	state.linear_velocity = v
	state.angular_velocity = w


func _drive(along: float, dir: float, accel: float, dt: float) -> float:
	if signf(along) == dir and absf(along) >= RUN_SPEED:
		return along
	var boost := TURN_BOOST if signf(along) == -dir else 1.0
	return move_toward(along, dir * RUN_SPEED, accel * boost * dt)


func bounce_up(height: float) -> void:
	var boost := 1.3 if Input.is_action_pressed("jump") and active else 1.0
	linear_velocity.y = -sqrt(2.0 * gravity() * height * boost)
	_can_cut = false
	_pulse = 0.25
	bounce_count += 1
	bounced.emit()


func launch_to(target: Vector2, apex_y: float, drift_y := -90.0) -> void:
	var rise := maxf(global_position.y - apex_y, 1.0)
	linear_velocity = Vector2(0.0, -sqrt(2.0 * gravity() * rise))
	_drift_target = target
	_drift_y = drift_y
	_drift_pending = true
	_ballistic = true
	_can_cut = false
	_pulse = 0.3
	bounce_count += 1
	launched.emit()


func knock_out(from_pos: Vector2) -> void:
	if ko or Engine.get_physics_frames() < _grace_until:
		return
	ko = true
	curled = false
	kos += 1
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	linear_velocity = Vector2(away * 350.0, -650.0)
	angular_velocity = away * 9.0
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
	_pending_velocity = Vector2(0.0, -sqrt(2.0 * gravity() * 380.0))
	respawned.emit()


func _process(delta: float) -> void:
	_update_visual(delta)


func _update_visual(delta: float) -> void:
	_visual.global_position = global_position
	_pulse = maxf(_pulse - delta * 1.2, 0.0)
	_visual.scale = Vector2.ONE * (1.0 + _pulse)
	_sprite.modulate.a = 1.0
	if ko:
		_sprite.texture = TEX_DEAD
		_sprite.offset = Vector2(6.0, -38.0)
		_sprite.position = Vector2(0.0, RADIUS)
		_sprite.scale = Vector2(0.6 * facing, 0.6)
		_vis_rot = rotation
	elif curled:
		_sprite.texture = TEX_SPIKE
		_sprite.offset = Vector2(10.0, -1.5)
		_sprite.position = Vector2.ZERO
		_sprite.scale = Vector2(0.67, 0.67)
		_vis_rot = rotation
	else:
		_sprite.offset = Vector2(8.0, -63.0)
		_sprite.position = Vector2(0.0, RADIUS)
		_sprite.scale = Vector2(0.6 * facing, 0.6)
		if grounded and absf(linear_velocity.x) > 30.0:
			_walk_time += delta * 5.5 * clampf(absf(linear_velocity.x) / RUN_SPEED, 0.5, 1.0)
			_sprite.texture = TEX_WALK[WALK_ORDER[int(_walk_time) % WALK_ORDER.size()]]
		else:
			_sprite.texture = TEX_STAND
		if grounded:
			var lean := clampf(linear_velocity.x / RUN_SPEED * 0.12, -0.15, 0.15)
			_vis_rot = lerp_angle(_vis_rot, lean, minf(delta * 14.0, 1.0))
		else:
			_vis_rot = lerp_angle(_vis_rot, rotation, minf(delta * 12.0, 1.0))
	_visual.rotation = _vis_rot
