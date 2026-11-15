extends Node2D

enum State { TITLE, PLAYING, WON }

const GROUND_Y := 0.0
const BEST_PATH := "user://best.cfg"
const TIPS := [
	{"group": "beetles", "range": 620.0, "text": "Beetles bite! Hold SHIFT / X to curl into a spike ball and squish them."},
	{"group": "mushrooms", "range": 480.0, "text": "Land on mushrooms to bounce. Hold Jump for extra height!"},
	{"group": "roots", "range": 520.0, "text": "Springy roots fling you away. Ricochet between the walls to climb!"},
	{"group": "master", "range": 700.0, "text": "The big glowing mushroom is your way home!"},
]

static var skip_title := false

var state := State.TITLE
var run_time := 0.0
var deaths := 0
var best_time := 0.0
var persist_best := true

var _tips_shown := {}
var _tip_clock := 0.0
var _tip_free_at := 0.0
var _hit_stopping := false

@onready var player: Player = $World/Player
@onready var hud = $HUD
@onready var audio := GameAudio.new()


func _ready() -> void:
	Engine.time_scale = 1.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	$World.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Backdrop.process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_action("pause", [KEY_ESCAPE, KEY_P])
	_ensure_action("mute", [KEY_M])
	add_child(audio)
	best_time = _load_best()

	hud.player = player
	player.input_enabled = false
	player.hp_changed.connect(hud.set_hp)
	player.died.connect(_on_player_died)
	player.death_started.connect(_on_death_started)
	player.hurt.connect(_on_hurt)
	player.jumped.connect(func() -> void: audio.play("jump"))
	player.landed.connect(func(speed: float) -> void: audio.play("land", 1.0, clampf((speed - 350.0) / 600.0, 0.0, 1.0) * 3.0 - 3.0))
	player.bounced.connect(func() -> void: audio.play("bounce"))
	player.rebounded.connect(func() -> void: audio.play("rebound"))
	player.launched.connect(func() -> void: audio.play("launch"))
	player.spike_changed.connect(func(on: bool) -> void: audio.play("curl" if on else "uncurl"))
	hud.set_hp(player.hp, player.max_hp)
	hud.set_muted(AudioServer.is_bus_mute(0))

	for beetle: Beetle in $World/Enemies.get_children():
		beetle.add_to_group("beetles")
		beetle.killed.connect(_on_beetle_killed)
	for root in $World/SpringRoots.get_children():
		root.add_to_group("roots")
	for mushroom: Mushroom in $World/Mushrooms.get_children():
		mushroom.add_to_group("master" if mushroom.master else "mushrooms")
	for checkpoint: Checkpoint in $World/Checkpoints.get_children():
		checkpoint.activated.connect(func() -> void: audio.play("checkpoint"))

	if skip_title:
		skip_title = false
		hud.skip_title()
		start_game(false)


func _ensure_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		hud.set_muted(AudioServer.is_bus_mute(0))
	elif event.is_action_pressed("pause") and state == State.PLAYING:
		_set_paused(not get_tree().paused)
	elif event.is_action_pressed("restart") and state != State.TITLE:
		_restart()
	elif state == State.TITLE and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		start_game()
	elif state == State.WON and event.is_action_pressed("ui_accept"):
		_restart()


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	skip_title = true
	get_tree().reload_current_scene()


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	hud.set_paused(on)
	audio.set_music_ducked(on)
	audio.play("pause", 1.0 if on else 1.4)


func start_game(announce := true) -> void:
	state = State.PLAYING
	hud.start_game()
	if announce:
		audio.play("start")
	await get_tree().create_timer(0.2).timeout
	player.input_enabled = true


func _physics_process(delta: float) -> void:
	if state == State.PLAYING:
		if not get_tree().paused:
			run_time += delta
			hud.set_time(run_time)
			_tip_clock += delta
			if _tip_clock >= 0.3:
				_tip_clock = 0.0
				_check_tips()
		if player.launching and player.global_position.y < GROUND_Y - 60.0:
			_win()


func _win() -> void:
	state = State.WON
	player.input_enabled = false
	var new_best := best_time <= 0.0 or run_time < best_time
	if new_best:
		best_time = run_time
		if persist_best:
			_save_best()
	hud.set_time(run_time)
	hud.show_win(run_time, deaths, best_time, new_best)
	audio.play("win")


func _check_tips() -> void:
	if player.dead or Time.get_ticks_msec() * 0.001 < _tip_free_at:
		return
	for tip: Dictionary in TIPS:
		var group: String = tip["group"]
		if _tips_shown.has(group):
			continue
		for node: Node2D in get_tree().get_nodes_in_group(group):
			var pos := node.global_position
			if node is BounceRoot:
				pos += node.size * 0.5
			var offset := pos - player.global_position
			if absf(offset.x) < float(tip["range"]) and absf(offset.y) < 380.0:
				_tips_shown[group] = true
				hud.show_toast(tip["text"])
				_tip_free_at = Time.get_ticks_msec() * 0.001 + 6.0
				return


func _on_hurt() -> void:
	audio.play("hurt")
	_hit_stop(0.08)


func _on_death_started() -> void:
	deaths += 1
	audio.play("die")


func _on_beetle_killed() -> void:
	audio.play("squish")
	_hit_stop(0.05)


func _hit_stop(seconds: float) -> void:
	if _hit_stopping:
		return
	_hit_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stopping = false


func _on_player_died() -> void:
	await hud.fade_to(1.0, 0.3).finished
	player.respawn()
	await hud.fade_to(0.0, 0.3).finished


func _load_best() -> float:
	var config := ConfigFile.new()
	if config.load(BEST_PATH) == OK:
		return float(config.get_value("run", "best", 0.0))
	return 0.0


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("run", "best", best_time)
	config.save(BEST_PATH)
