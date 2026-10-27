extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
const PROJ = preload("res://scripts/projection.gd")
var failures := 0
var checks := 0
var heard: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _find(game: Variant, owner: int, kind: String) -> Dictionary:
	for entity: Dictionary in game.world.entities.values():
		if int(entity.owner) == owner and str(entity.kind) == kind:
			return entity
	return {}

func _key(game: Variant, key: Key, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.ctrl_pressed = ctrl
	game._unhandled_input(event)

func _button(game: Variant, point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	game._unhandled_input(event)

func _wait_for_input_interval() -> void:
	# The audio throttle uses wall time; the first SceneTree delta can include
	# resource loading before a newly created timer starts.
	var ready_at: int = Time.get_ticks_usec() + 270000
	while Time.get_ticks_usec() < ready_at:
		await create_timer(.02).timeout

func _click(game: Variant, point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	game.camera_pos = PROJ.project(point) - Vector2(game.battlefield_size) / float(game.zoom_level) * .5
	game._clamp_camera()
	game.view.camera_pos = game.camera_pos
	game.view.zoom_level = game.zoom_level
	var screen: Vector2 = game.view.world_to_screen(point) + Vector2(game.field_clip.position)
	_button(game, screen, button, true, shift)
	_button(game, screen, button, false, shift)

func _test_banks() -> void:
	for folder: String in ["human", "synod", "kharuun", "host", "infernal", "veyr"]:
		var complete := true
		for role: String in ["worker", "infantry", "tank"]:
			var actions: Array = ["select", "move"] if role == "worker" else ["select", "move", "attack"]
			for action: String in actions:
				for variant: int in range(1, 4):
					var path := "res://assets/voices/%s/%s_%s_%d.ogg" % [folder, role, action, variant]
					var clip: AudioStream = load(path)
					complete = complete and clip is AudioStreamOggVorbis and clip.get_length() > .05 and clip.get_length() < 12.0
		_check(complete, "%s must include three select/move variants for all roles and attack variants for combat units" % folder)

func _run() -> void:
	_test_banks()
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	game.voice.acknowledged.connect(func(id: int, action: String, path: String) -> void: heard.append({"id": id, "action": action, "path": path}))
	_check(not game.voice.playing, "Deployment screen must not trigger unit acknowledgments")
	game._start_match()
	_check(heard.is_empty(), "Automatically selecting the starting Command Center must remain silent")
	var worker: Dictionary = _find(game, 0, "worker")
	var soldier: Dictionary = _find(game, 0, "infantry")
	var hq: Dictionary = _find(game, 0, "hq")
	var enemy: Dictionary = _find(game, 1, "worker")
	_click(game, worker.pos)
	_check(heard.size() == 1 and int(heard[-1].id) == int(worker.id) and str(heard[-1].action) == "select", "Clicking a friendly worker must play one selection acknowledgment")
	_check(game.voice.playing and game.voice.max_polyphony == 1, "Unit acknowledgments must use one audible voice player")
	_check(str(heard[-1].path).ends_with("human/worker_select_1.ogg"), "A Human worker must use its own selection bank")
	_click(game, worker.pos)
	_check(heard.size() == 1, "Rapid repeated selection must not stack or restart voice lines")
	var selection_clip: AudioStream = game.voice.stream
	await _wait_for_input_interval()
	_click(game, Vector2(850, 600), MOUSE_BUTTON_RIGHT)
	_check(heard.size() == 1 and is_same(game.voice.stream, selection_clip) and game.voice.playing and str(worker.order) == "move", "A ground move must execute while the active selection response finishes unchanged")
	# New movement acknowledgments are available after natural clip completion.
	var deadline: int = Time.get_ticks_usec() + int((game.voice.stream.get_length() + 1.0) * 1000000)
	while game.voice.playing and Time.get_ticks_usec() < deadline:
		await create_timer(0.02).timeout
	_check(not game.voice.playing, "Selection response must reach its natural end")
	_click(game, Vector2(850, 600), MOUSE_BUTTON_RIGHT)
	_check(heard.size() == 2 and str(heard[-1].action) == "move" and str(heard[-1].path).contains("worker_move_"), "An idle unit voice channel must use the selected unit role's movement bank")
	await _wait_for_input_interval()
	_click(game, Vector2(880, 620), MOUSE_BUTTON_RIGHT)
	_check(heard.size() == 2, "Repeated move commands must not interrupt an active movement acknowledgment")
	game.voice.cancel()
	_click(game, worker.pos)
	_check(str(heard[-1].path).ends_with("worker_select_2.ogg"), "Repeated selections must rotate to a different line")
	game.voice.cancel()
	_click(game, worker.pos)
	_check(str(heard[-1].path).ends_with("worker_select_3.ogg"), "Selection must rotate through all three lines")
	game.voice.cancel()
	_click(game, worker.pos)
	_check(str(heard[-1].path).ends_with("worker_select_1.ogg"), "Line rotation must wrap without an immediate repeat")
	game.voice.cancel()
	var before: int = heard.size()
	_click(game, soldier.pos, MOUSE_BUTTON_LEFT, true)
	_check(heard.size() == before + 1 and int(heard[-1].id) == int(soldier.id), "Shift-adding a unit must acknowledge the added unit once")
	game.voice.cancel()
	before = heard.size()
	_click(game, soldier.pos, MOUSE_BUTTON_LEFT, true)
	_check(heard.size() == before, "Shift-removing a unit must not play a selection acknowledgment")
	game.voice.cancel()
	var rect: Rect2 = game._entity_screen_rect(worker).merge(game._entity_screen_rect(soldier)).grow(4)
	game.drag_start = rect.position
	before = heard.size()
	game._select(rect.end, false)
	_check(game.selected.size() >= 2 and heard.size() == before + 1, "Drag-selecting multiple units must speak once for the group")
	game.voice.cancel()
	game.groups[1] = [hq.id, worker.id, soldier.id]
	before = heard.size()
	_key(game, KEY_1)
	_check(heard.size() == before + 1 and int(heard[-1].id) == int(worker.id), "Control-group recall must skip structures and acknowledge one owned mobile unit")
	game.voice.cancel()
	before = heard.size()
	_key(game, KEY_2, true)
	_check(heard.size() == before, "Assigning a control group must not trigger a selection line")
	_click(game, hq.pos)
	_check(heard.size() == before, "Selecting a building must remain silent")
	game.selected = [hq.id]
	game._issue_context(Vector2(850, 600))
	_check(heard.size() == before, "Setting a producer rally point must not play a unit movement line")
	_click(game, enemy.pos)
	game._acknowledge([enemy.id], "select")
	_check(heard.size() == before, "Enemy selection or an unowned group entry must never speak")
	game.world.order_move([enemy.id], Vector2(2400, 1400))
	_check(heard.size() == before, "AI or simulation-issued orders must not trigger player acknowledgments")
	game.selected = [enemy.id, worker.id]
	game.voice.cancel()
	game._issue_context(Vector2(900, 650))
	_check(heard.size() == before, "An owned unit with an old move order must not speak when the simulation rejects its foreign-leading group")
	game.selected = [worker.id, soldier.id]
	game.voice.cancel()
	game._issue_context(Vector2(900, 650))
	_check(heard.size() == before + 1, "A move order for a mixed unit group must play only one line")
	game.voice.cancel()
	game.selected = [soldier.id]
	before = heard.size()
	_key(game, KEY_E)
	_click(game, Vector2(860, 660))
	_check(str(soldier.order) == "attack_move" and heard.size() == before + 1 and str(heard[-1].action) == "attack", "Accepted combat attack-move commands must play an attack acknowledgment")
	game.voice.cancel()
	before = heard.size()
	game._issue_context(game.world.deposits[0].pos)
	_check(heard.size() == before, "A gather command rejected for a combat unit must remain silent")
	game.selected = [worker.id]
	game._issue_context(game.world.deposits[0].pos)
	_check(heard.size() == before + 1 and str(worker.order) == "gather", "A worker sent to harvest must acknowledge its accepted movement order")
	game.voice.cancel()
	before = heard.size()
	game._issue_context(Vector2(-40, -40))
	_check(heard.size() == before, "Clicks outside the simulation map must not play movement acknowledgments")
	game.paused = true
	game._issue_context(Vector2(850, 600))
	_click(game, worker.pos)
	_check(heard.size() == before, "Paused selection and command input must remain silent")
	game.paused = false
	_button(game, Vector2(game.battlefield_size.x + 80, 300), MOUSE_BUTTON_LEFT, true)
	_button(game, Vector2(game.battlefield_size.x + 80, 300), MOUSE_BUTTON_LEFT, false)
	_check(heard.size() == before, "HUD clicks must not trigger battlefield voice lines")
	game.world.match_state = "victory"
	game._issue_context(Vector2(850, 600))
	game._acknowledge([worker.id], "select")
	_check(heard.size() == before, "Match-end state must reject new unit acknowledgments")
	game.world.match_state = "playing"
	for style: String in ["humans", "iron_synod", "kharuun", "heavenly_host", "infernal_legion", "veyr"]:
		game.voice.cancel()
		worker.faction = style
		before = heard.size()
		game._acknowledge([worker.id], "select")
		var folder: String = {"humans": "human", "iron_synod": "synod", "kharuun": "kharuun", "heavenly_host": "host", "infernal_legion": "infernal", "veyr": "veyr"}[style]
		_check(heard.size() == before + 1 and str(heard[-1].path).contains("/%s/worker_select_" % folder), "Explicit %s style must resolve its own audio family" % style)
	worker.erase("faction")
	game.voice.cancel()
	before = heard.size()
	worker.hp = 0
	game._acknowledge([worker.id], "select")
	_check(heard.size() == before, "Destroyed units must not acknowledge orders")
	worker.hp = worker.maxhp
	worker.completed = false
	game._acknowledge([worker.id], "select")
	_check(heard.size() == before, "Incomplete entities must not acknowledge orders")
	worker.completed = true
	game._acknowledge([worker.id], "select")
	game._restart()
	_check(not game.voice.playing and game.voice.stream == null, "Restart must stop stale acknowledgments")
	await _test_attack(game)
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d unit voice integration checks" % checks)
	else:
		push_error("FAIL: %d of %d unit voice checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _test_attack(game: Variant) -> void:
	game.world.ai_enabled = false
	var soldier: Dictionary = _find(game, 0, "infantry")
	var worker: Dictionary = _find(game, 0, "worker")
	var enemy: Dictionary = game.world._spawn("tank", 1, soldier.pos + Vector2(110, 30))
	game.world._rebuild_buckets()
	game.world._update_fog()
	game.selected = [soldier.id]
	game.voice._next_variant["human/infantry_attack"] = 1
	game.voice.cancel()
	var before: int = heard.size()
	_click(game, enemy.pos, MOUSE_BUTTON_RIGHT)
	_check(heard.size() == before + 1 and str(soldier.order) == "attack" and str(heard[-1].path).ends_with("infantry_attack_1.ogg"), "Right-clicking a visible enemy must acknowledge an accepted attack")
	game.voice.cancel()
	before = heard.size()
	game.selected = [worker.id, soldier.id]
	game.attack_mode = true
	_click(game, enemy.pos)
	_check(heard.size() == before + 1 and int(heard[-1].id) == int(soldier.id) and str(heard[-1].path).ends_with("infantry_attack_2.ogg"), "Explicit attack on an enemy must skip unarmed workers and speak once for the group")
	game.voice.cancel()
	before = heard.size()
	game.selected = [worker.id]
	_click(game, enemy.pos, MOUSE_BUTTON_RIGHT)
	_check(heard.size() == before, "Unarmed workers must not acknowledge rejected attack commands")
	game.selected = [soldier.id]
	game.voice.cancel()
	game._acknowledge([soldier.id], "move")
	var movement_clip: AudioStream = game.voice.stream
	await _wait_for_input_interval()
	before = heard.size()
	_click(game, enemy.pos, MOUSE_BUTTON_RIGHT)
	_check(heard.size() == before and str(soldier.order) == "attack" and is_same(game.voice.stream, movement_clip) and game.voice.playing, "Accepted attacks must execute without interrupting an active movement response")
	await _wait_for_input_interval()
	before = heard.size()
	_click(game, enemy.pos, MOUSE_BUTTON_RIGHT)
	_check(heard.size() == before, "Repeated attack commands must let the active attack response finish")
	game.voice.cancel()
	before = heard.size()
	enemy.pos = Vector2(2700, 1800)
	game.world._update_fog()
	game._acknowledge_attack([soldier.id], enemy.pos, "attack", int(enemy.id))
	_check(heard.size() == before, "A stale attack target hidden by fog must never trigger an attack response")
	enemy.pos = soldier.pos + Vector2(110, 30)
	game.world._update_fog()
	game.selected = [enemy.id, soldier.id]
	before = heard.size()
	_click(game, enemy.pos, MOUSE_BUTTON_RIGHT)
	_check(heard.size() == before, "A foreign-leading group rejected by order validation must not replay an old attack")
	game.selected = [soldier.id]
	game.paused = true
	game._issue_context(enemy.pos)
	_check(heard.size() == before, "Paused attack input must remain silent")
	game.paused = false
	game.world.match_state = "victory"
	game._issue_context(enemy.pos)
	_check(heard.size() == before, "Match-end attack input must remain silent")
	game.world.match_state = "playing"
	for style: String in ["humans", "iron_synod", "kharuun", "heavenly_host", "infernal_legion", "veyr"]:
		game.voice.cancel()
		soldier.faction = style
		before = heard.size()
		game._acknowledge([soldier.id], "attack")
		_check(heard.size() == before + 1 and str(heard[-1].path).contains("_attack_"), "%s combat units must have attack responses" % style)
	soldier.erase("faction")
	var tank: Dictionary = game.world._spawn("tank", 0, worker.pos + Vector2(70, 70))
	game.voice.cancel()
	before = heard.size()
	game._acknowledge([tank.id], "attack")
	_check(heard.size() == before + 1 and str(heard[-1].path).ends_with("tank_attack_1.ogg"), "Tanks must use their own attack voice bank")
	game.voice.cancel()
	game.selected = [worker.id]
	game.attack_mode = true
	before = heard.size()
	_click(game, Vector2(850, 600))
	_check(heard.size() == before + 1 and str(heard[-1].action) == "move", "Unarmed worker attack-move must retain its movement acknowledgment")
