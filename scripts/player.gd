class_name Player
extends CharacterBody2D

signal hp_changed(hp: int, max_hp: int)
signal hurt
signal death_started
signal died
signal bounced
signal rebounded
signal launched
signal launch_finished
signal jumped
signal landed(speed: float)
signal spike_changed(on: bool)

const NEVER := -1000000
const TEX_STAND := preload("res://hedgehog_ingame_stand.png")
const TEX_WALK := [
	preload("res://walking_0.png"),
	preload("res://walking_1.png"),
	preload("res://walking_2.png"),
]
const WALK_ORDER := [0, 1, 2, 1]
const TEX_SPIKE := preload("res://hedgehog_spike.png")
const TEX_DEAD := preload("res://hedgehog_dead.png")

@export_group("Run")
@export var run_speed := 380.0
@export var ground_accel := 3800.0
@export var air_accel := 2500.0
@export var momentum_decay := 300.0

@export_group("Jump")
@export var jump_height := 200.0
@export var apex_time := 0.4
@export var fall_gravity_mult := 1.7
@export var max_fall_speed := 1400.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export_range(0.1, 1.0) var jump_cut := 0.45

@export_group("Animation")
@export var walk_fps := 5.5
@export var step_bob := 3.5
@export var lean := 0.05

@export_group("Spike mode")
@export var spike_speed_mult := 0.5
@export var spike_cooldown := 0.35

@export_group("Health")
@export var max_hp := 3
@export var invuln_time := 1.4
@export var knockback := Vector2(430.0, 650.0)

var hp := 3
var spiked := false
var dead := false
var launching := false
var input_enabled := false
var respawn_point := Vector2.ZERO
var facing := 1.0

var rise_gravity := 0.0
var fall_gravity := 0.0
var jump_velocity := 0.0

var _tick := 0
var _coyote_ticks := 6
var _buffer_ticks := 7
var _last_ground_tick := NEVER
var _last_press_tick := NEVER
var _spike_ready_tick := 0
var _can_cut_jump := false
var _control_lock_ticks := 0
var _steer_lock_ticks := 0
var _recent_fall_ticks := 0
var _invuln_ticks := 0
var _was_on_floor := false
var _walk_time := 0.0
var _trauma := 0.0
var _squash_tween: Tween
var _launch_land := Vector2.ZERO
var _launch_drift_pending := false
var _dust: CPUParticles2D

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	rise_gravity = 2.0 * jump_height / (apex_time * apex_time)
	jump_velocity = -2.0 * jump_height / apex_time
	fall_gravity = rise_gravity * fall_gravity_mult
	_coyote_ticks = _ticks(coyote_time)
	_buffer_ticks = _ticks(jump_buffer)
	hp = max_hp
	respawn_point = global_position
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.explosiveness = 1.0
	_dust.amount = 10
	_dust.lifetime = 0.45
	_dust.direction = Vector2(0, -1)
	_dust.spread = 80.0
	_dust.initial_velocity_min = 40.0
	_dust.initial_velocity_max = 140.0
	_dust.gravity = Vector2(0, 260)
	_dust.scale_amount_min = 2.5
	_dust.scale_amount_max = 5.5
	_dust.color = Color(0.85, 0.7, 0.5, 0.75)
	_dust.show_behind_parent = true
	add_child(_dust)
	_update_visuals(0.0)


func _puff(count := 10) -> void:
	_dust.amount = count
	_dust.restart()
	_dust.emitting = true


func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - 1.8 * delta, 0.0)
		var amount := 20.0 * _trauma * _trauma
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_tick += 1
	if dead:
		_physics_dead(delta)
		return
	if launching:
		_physics_launch(delta)
		return

	var on_floor := is_on_floor()
	if on_floor and velocity.y >= 0.0:
		_last_ground_tick = _tick

	var hurt_locked := _control_lock_ticks > 0
	if hurt_locked:
		_control_lock_ticks -= 1
	var steer_locked := _steer_lock_ticks > 0
	if steer_locked:
		_steer_lock_ticks -= 1
	if _invuln_ticks > 0:
		_invuln_ticks -= 1
	var can_control := input_enabled and not hurt_locked

	var want_spike := can_control and Input.is_action_pressed("spike") and _tick >= _spike_ready_tick
	if spiked and not want_spike:
		_spike_ready_tick = _tick + _ticks(spike_cooldown)
	if want_spike != spiked:
		spike_changed.emit(want_spike)
	spiked = want_spike

	var jump_held := input_enabled and Input.is_action_pressed("jump")
	if can_control and Input.is_action_just_pressed("jump"):
		_last_press_tick = _tick
	var press_ok := _tick - _last_press_tick <= _buffer_ticks
	var ground_ok := _tick - _last_ground_tick <= _coyote_ticks
	if press_ok and ground_ok and not spiked and not hurt_locked:
		velocity.y = jump_velocity
		_last_press_tick = NEVER
		_last_ground_tick = NEVER
		_can_cut_jump = true
		if not jump_held:
			velocity.y *= jump_cut
			_can_cut_jump = false
		_squash(Vector2(0.8, 1.25))
		_puff(6)
		jumped.emit()
	if _can_cut_jump:
		if velocity.y >= 0.0:
			_can_cut_jump = false
		elif not jump_held:
			velocity.y *= jump_cut
			_can_cut_jump = false

	var gravity := fall_gravity if velocity.y > 0.0 else rise_gravity
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	if not hurt_locked and not steer_locked:
		var dir := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
		var top_speed := run_speed * (spike_speed_mult if spiked else 1.0)
		var accel := ground_accel if on_floor else air_accel
		var over_speed := absf(velocity.x) > top_speed
		if dir != 0.0:
			facing = signf(dir)
			if over_speed and signf(velocity.x) == dir:
				velocity.x = move_toward(velocity.x, dir * top_speed, momentum_decay * delta)
			else:
				velocity.x = move_toward(velocity.x, dir * top_speed, accel * delta)
		elif over_speed:
			velocity.x = move_toward(velocity.x, 0.0, (momentum_decay if not on_floor else accel) * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, accel * delta * (1.0 if on_floor else 0.4))

	var pre_vy := velocity.y
	if pre_vy > 350.0:
		_recent_fall_ticks = 4
	elif _recent_fall_ticks > 0:
		_recent_fall_ticks -= 1
	move_and_slide()

	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor and pre_vy > 350.0:
		_squash(Vector2(1.3, 0.7))
		_puff(12)
		landed.emit(pre_vy)
	_was_on_floor = on_floor_now

	_update_visuals(delta)


func _physics_dead(delta: float) -> void:
	velocity.y = minf(velocity.y + fall_gravity * delta, max_fall_speed)
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	move_and_slide()
	_update_visuals(delta)


func _physics_launch(delta: float) -> void:
	var gravity := rise_gravity if velocity.y < 0.0 else fall_gravity
	velocity.y += gravity * delta
	if _launch_drift_pending and global_position.y < _launch_land.y - 90.0:
		_begin_drift()
	if velocity.y >= 0.0 and collision_mask == 0:
		collision_mask = 1
	move_and_slide()
	if collision_mask == 1 and is_on_floor():
		launching = false
		velocity = Vector2.ZERO
		_squash(Vector2(1.3, 0.7))
		launch_finished.emit()
	_update_visuals(delta)


func _begin_drift() -> void:
	_launch_drift_pending = false
	var up_speed := -velocity.y
	var t_up := up_speed / rise_gravity
	var apex_y := global_position.y - up_speed * up_speed / (2.0 * rise_gravity)
	var t_down := sqrt(2.0 * maxf(_launch_land.y - apex_y, 1.0) / fall_gravity)
	velocity.x = (_launch_land.x - global_position.x) / (t_up + t_down)
	facing = signf(velocity.x) if velocity.x != 0.0 else facing


func recently_fell() -> bool:
	return _recent_fall_ticks > 0


func bounce(height: float) -> void:
	_recent_fall_ticks = 0
	var boost := 1.0
	if input_enabled and (Input.is_action_pressed("jump") or _tick - _last_press_tick <= _buffer_ticks):
		boost = 1.25
	velocity.y = -sqrt(2.0 * rise_gravity * height * boost)
	_can_cut_jump = false
	_last_ground_tick = NEVER
	_last_press_tick = NEVER
	_squash(Vector2(0.75, 1.35))
	bounced.emit()


func rebound(kick: Vector2) -> void:
	velocity = kick
	facing = signf(kick.x) if kick.x != 0.0 else facing
	_steer_lock_ticks = _ticks(0.3)
	_can_cut_jump = false
	_last_ground_tick = NEVER
	_last_press_tick = NEVER
	_squash(Vector2(0.65, 1.3))
	add_trauma(0.2)
	rebounded.emit()


func launch(apex_y: float, land_pos: Vector2) -> void:
	launching = true
	spiked = false
	_launch_land = land_pos
	_launch_drift_pending = true
	collision_mask = 0
	var rise := maxf(global_position.y - apex_y, 1.0)
	velocity = Vector2(0.0, -sqrt(2.0 * rise_gravity * rise))
	camera.position_smoothing_speed = 14.0
	add_trauma(0.7)
	_squash(Vector2(0.7, 1.5))
	launched.emit()


func take_hit(from_x: float) -> void:
	if dead or launching or spiked or _invuln_ticks > 0:
		return
	hp -= 1
	hp_changed.emit(hp, max_hp)
	hurt.emit()
	_flash()
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	if hp <= 0:
		_die(away)
		return
	velocity = Vector2(away * knockback.x, -knockback.y)
	_control_lock_ticks = _ticks(0.3)
	_invuln_ticks = _ticks(invuln_time)
	_can_cut_jump = false
	_last_ground_tick = NEVER
	_squash(Vector2(1.3, 0.75))


func _die(away: float) -> void:
	dead = true
	death_started.emit()
	spiked = false
	collision_mask = 0
	velocity = Vector2(away * 160.0, -700.0)
	get_tree().create_timer(1.3).timeout.connect(func() -> void: died.emit())


func respawn() -> void:
	dead = false
	launching = false
	hp = max_hp
	collision_mask = 1
	global_position = respawn_point
	velocity = Vector2.ZERO
	_control_lock_ticks = 0
	_steer_lock_ticks = 0
	_invuln_ticks = _ticks(1.0)
	_last_ground_tick = NEVER
	camera.position_smoothing_speed = 8.0
	camera.reset_smoothing()
	hp_changed.emit(hp, max_hp)
	_update_visuals(0.0)


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _flash() -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("flash", 1.0)
	create_tween().tween_property(material, "shader_parameter/flash", 0.0, 0.3)


func _squash(target: Vector2) -> void:
	if _squash_tween:
		_squash_tween.kill()
	visual.scale = target
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_visuals(delta: float) -> void:
	sprite.modulate.a = 1.0
	var target_lean := 0.0
	var bob := 0.0
	if dead:
		sprite.texture = TEX_DEAD
		sprite.offset = Vector2(6.0, -38.0)
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		sprite.scale = Vector2(0.6 * facing, 0.6)
		visual.position.y = 0.0
		visual.rotation = 0.0
		queue_redraw()
		return

	if spiked or launching:
		sprite.texture = TEX_SPIKE
		sprite.offset = Vector2(10.0, -1.5)
		sprite.position = Vector2(0.0, -27.5)
		sprite.scale = Vector2(0.65, 0.65)
		sprite.rotation += (velocity.x if not launching else 900.0) * delta / 27.5
	else:
		sprite.offset = Vector2(8.0, -63.0)
		sprite.position = Vector2.ZERO
		sprite.rotation = 0.0
		var breathe := 1.0 + 0.012 * sin(Time.get_ticks_msec() * 0.004)
		sprite.scale = Vector2(0.6 * facing, 0.6 * breathe)
		if is_on_floor() and absf(velocity.x) > 20.0:
			var pace := clampf(absf(velocity.x) / run_speed, 0.5, 1.0)
			_walk_time += delta * walk_fps * pace
			sprite.texture = TEX_WALK[WALK_ORDER[int(_walk_time) % WALK_ORDER.size()]]
			bob = -step_bob * pow(sin(_walk_time * PI * 0.5), 2.0)
			target_lean = lean * facing
		else:
			sprite.texture = TEX_STAND

	visual.position.y = lerpf(visual.position.y, bob, minf(delta * 20.0, 1.0)) if delta > 0.0 else bob
	visual.rotation = lerpf(visual.rotation, target_lean, minf(delta * 10.0, 1.0)) if delta > 0.0 else target_lean

	if _invuln_ticks > 0 and (_invuln_ticks / 4) % 2 == 0:
		sprite.modulate.a = 0.35
	queue_redraw()


func _draw() -> void:
	if dead or launching or not is_on_floor():
		return
	var radius := 26.0 if spiked else 24.0
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		points.append(Vector2(cos(a) * radius, sin(a) * 5.0 + 1.0))
	draw_colored_polygon(points, Color(0.1, 0.04, 0.02, 0.28))
