extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
const DATA = preload("res://scripts/catalog.gd")
const SIM = preload("res://scripts/simulation.gd")
const PROJECT = preload("res://scripts/projection.gd")
const ART = preload("res://scripts/faction_sprites.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	_test_difficulty_menu(game)
	_check(game.selected.is_empty(), "A new match must start without a selected battlefield entity")
	game.world.ai_enabled = false
	await process_frame
	game._layout()
	await _test_power_and_full_height_layout(game)
	_test_selection_and_hud(game)
	_test_build_train_and_rally(game)
	_test_global_production(game)
	_test_pause_and_feedback(game)
	_test_edge_scroll_camera(game)
	_test_decorated_window_edges(game)
	_test_native_pointer_sampling(game)
	await _test_expanded_window_edges(game)
	_test_keyboard_camera_and_commands(game)
	_test_isometric_navigation(game)
	_test_isometric_hits_and_orders(game)
	_test_fog_render_state(game)
	_test_hover_picking_and_drag(game)
	_test_faction_picking_and_context(game)
	_test_destruction_visibility_and_pause(game)
	_test_combat_victory_and_restart(game)
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d scene integration checks" % checks)
	else:
		push_error("FAIL: %d of %d scene integration checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _find(game: Variant, owner: int, kind: String) -> Dictionary:
	for e: Dictionary in game.world.entities.values():
		if int(e.owner) == owner and str(e.kind) == kind:
			return e
	return {}

func _button(game: Variant, point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	game._unhandled_input(event)

func _sync_view(game: Variant) -> void:
	game.view.camera_pos = game.camera_pos
	game.view.zoom_level = game.zoom_level

func _center_on(game: Variant, point: Vector2) -> void:
	game.camera_pos = PROJECT.project(point) - Vector2(game.battlefield_size) / float(game.zoom_level) * 0.5
	game._clamp_camera()
	_sync_view(game)

func _click_world(game: Variant, point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	_sync_view(game)
	var local: Vector2 = game.view.world_to_screen(point)
	if not Rect2(Vector2.ZERO, game.battlefield_size).has_point(local):
		_center_on(game, point)
		local = game.view.world_to_screen(point)
	var screen: Vector2 = local + Vector2(game.field_clip.position)
	_button(game, screen, button, true, shift)
	_button(game, screen, button, false, shift)

func _test_power_and_full_height_layout(game: Variant) -> void:
	var initial: Dictionary = game.world.power(0)
	game._refresh_ui()
	_check(game.power_meter.used == int(initial.used) and game.power_meter.supplied == int(initial.produced), "Power meter must reflect current building demand and supply")
	var plant: Dictionary = _find(game, 0, "power")
	var health: float = float(plant.hp)
	var consumer: Dictionary = game.world._spawn("factory", 0, Vector2(950, 520))
	plant.hp = 0.0
	game._refresh_ui()
	var shortage: Dictionary = game.world.power(0)
	_check(game.power_meter.used == int(shortage.used) and game.power_meter.supplied == int(shortage.produced) and game.power_meter.used > game.power_meter.supplied, "Power meter must update when building demand exceeds surviving supply")
	plant.hp = health
	game.world.entities.erase(consumer.id)
	game._refresh_ui()
	_check(game.power_meter.used == int(initial.used) and game.power_meter.supplied == int(initial.produced), "Power meter must recover when supply is restored and demand falls")
	for size: Vector2i in [Vector2i(1366, 864), Vector2i(1100, 720)]:
		root.size = size
		await process_frame
		game._layout()
		await process_frame
		await process_frame
		var viewport: Rect2 = game.get_viewport_rect()
		var meter: Rect2 = game.power_meter.get_global_rect()
		var radar: Rect2 = game.radar.get_global_rect()
		_check(Vector2(game.field_clip.position) == Vector2.ZERO and is_equal_approx(float(game.battlefield_size.y), viewport.size.y), "Battlefield must start at the top and use the full viewport height at %s" % size)
		_check(meter.size.x > 0 and meter.size.y > 0 and viewport.encloses(meter) and viewport.encloses(radar), "Power meter and radar must remain visible inside the viewport at %s" % size)
		_check(not meter.intersects(radar) and meter.position.y < radar.end.y and meter.end.y > radar.position.y, "Power meter must sit beside the radar without overlap at %s" % size)
	root.size = Vector2i(1366, 864)
	await process_frame
	game._layout()
	await process_frame

func _test_selection_and_hud(game: Variant) -> void:
	var worker: Dictionary = _find(game, 0, "worker")
	_click_world(game, worker.pos)
	_check(game.selected == [worker.id], "Mouse click must select a friendly unit")
	var infantry: Dictionary = _find(game, 0, "infantry")
	_click_world(game, infantry.pos, MOUSE_BUTTON_LEFT, true)
	_check(game.selected.has(worker.id) and game.selected.has(infantry.id), "Shift-click must add a friendly unit to selection")
	var first: Vector2 = game.view.world_to_screen(worker.pos)
	var second: Vector2 = game.view.world_to_screen(infantry.pos)
	var selection_start: Vector2 = first.min(second) - Vector2(20, 20) + Vector2(game.field_clip.position)
	var selection_end: Vector2 = first.max(second) + Vector2(20, 20) + Vector2(game.field_clip.position)
	_button(game, selection_start, MOUSE_BUTTON_LEFT, true)
	_button(game, selection_end, MOUSE_BUTTON_LEFT, false)
	_check(game.selected.has(worker.id) and game.selected.has(infantry.id), "Drag selection must use projected unit positions")
	var previous: Array = game.selected.duplicate()
	var previous_order: String = str(worker.order)
	var sidebar_point: Vector2 = Vector2(float(game.battlefield_size.x) + 50.0, 300.0)
	_button(game, sidebar_point, MOUSE_BUTTON_LEFT, true)
	_button(game, sidebar_point, MOUSE_BUTTON_LEFT, false)
	_button(game, sidebar_point, MOUSE_BUTTON_RIGHT, true)
	_check(game.selected == previous and str(worker.order) == previous_order, "HUD clicks must not select or command battlefield entities")
	game._choose_build("barracks")
	var entities_before: int = game.world.entities.size()
	_button(game, sidebar_point, MOUSE_BUTTON_LEFT, true)
	_check(game.world.entities.size() == entities_before and game.build_kind == "barracks", "HUD clicks must not place buildings through the sidebar")
	game.build_kind = ""
	var enemy: Dictionary = game.world._spawn("infantry", 1, Vector2(760, 360))
	game.world._update_fog()
	_click_world(game, enemy.pos)
	_check(not game.selected.has(enemy.id), "Enemy units must not be selectable for command")
	var enemy_order: String = str(enemy.order)
	_click_world(game, Vector2(820, 400), MOUSE_BUTTON_RIGHT)
	_check(str(enemy.order) == enemy_order, "Player right-clicks must not command enemy units")
	game.world.entities.erase(int(enemy.id))
	game.world._rebuild_buckets()

func _test_build_train_and_rally(game: Variant) -> void:
	var hq: Dictionary = _find(game, 0, "hq")
	_click_world(game, hq.pos)
	var funds: int = int(game.world.resources[0].essence)
	game._train("worker")
	_check(hq.queue.size() == 1 and int(game.world.resources[0].essence) == funds - int(DATA.spec("worker").cost), "Selected Command Center must queue a worker through the UI")
	game._cancel_queue()
	_check(hq.queue.is_empty() and int(game.world.resources[0].essence) == funds, "UI cancellation must refund and clear the queued unit")
	var rally: Vector2 = Vector2(820, 370)
	_click_world(game, rally, MOUSE_BUTTON_RIGHT)
	_check(Vector2(hq.rally).distance_to(rally) < 0.01, "Right-clicking ground with a structure selected must set its rally point")
	game._choose_build("barracks")
	_click_world(game, Vector2(736, 320))
	var barracks: Dictionary = _find(game, 0, "barracks")
	_check(not barracks.is_empty() and not bool(barracks.completed), "UI placement must create an unfinished Barracks")
	_check(Vector2(barracks.pos).distance_to(Vector2(736, 320)) < 0.001, "Projected building placement must preserve the preview location in simulation space")
	_check(game.build_kind.is_empty(), "Successful placement must leave placement mode")
	for frame: int in range(500):
		game.world.tick(0.05)
	_check(bool(barracks.completed), "Placed Barracks must complete after worker travel and construction")
	_click_world(game, barracks.pos)
	game._train("infantry")
	game._refresh_ui()
	_check(barracks.queue.size() == 1 and game.queue_label.text.contains("Vanguard"), "Selected Barracks must train and display its infantry queue")
	_check(not game.unit_buttons["infantry"].disabled and game.unit_buttons["tank"].disabled, "Infantry must unlock with a Barracks while tanks require an owned Factory")

func _test_global_production(game: Variant) -> void:
	var hq: Dictionary = _find(game, 0, "hq")
	var barracks: Dictionary = _find(game, 0, "barracks")
	var factory: Dictionary = game.world._spawn("factory", 0, Vector2(950, 520))
	game.world._rebuild_navigation()
	game.world._update_fog()
	game.world.cancel_queue(barracks.id)
	game.world.resources[0].essence = 3000
	game.selected.clear()
	game._refresh_ui()
	for pair: Array in [[hq, "worker"], [barracks, "infantry"], [factory, "tank"]]:
		var building: Dictionary = pair[0]
		var kind: String = pair[1]
		_check(game.unit_buttons[kind].visible and not game.unit_buttons[kind].disabled, "Owned completed producers must unlock visible sidebar units without selection: " + kind)
		game.unit_buttons[kind].pressed.emit()
		_check(building.queue.size() == 1 and game.selected.is_empty(), "Sidebar training must queue the unit without selecting its building: " + kind)
		_check(game.queue_label.text.contains(DATA.title(kind)) and not game.cancel_button.disabled, "Global production must display the latest queue and enable cancellation")
		var funds: int = int(game.world.resources[0].essence)
		game._cancel_queue()
		_check(building.queue.is_empty() and int(game.world.resources[0].essence) == funds + int(DATA.spec(kind).cost), "Global cancellation must clear and refund the queue without selection")
	var enemy_hq: Dictionary = _find(game, 1, "hq")
	game.world.queue_unit(enemy_hq.id, "worker")
	var enemy_queue: int = enemy_hq.queue.size()
	var worker: Dictionary = _find(game, 0, "worker")
	for selection: Array in [[worker.id], [enemy_hq.id], [hq.id, barracks.id, enemy_hq.id]]:
		game.selected = selection
		game._refresh_ui()
		game._train("worker")
		_check(hq.queue.size() == 1 and enemy_hq.queue.size() == enemy_queue, "Mobile, enemy, or mixed selection must permit training only at an owned producer")
		game._cancel_queue()
		_check(hq.queue.is_empty() and enemy_hq.queue.size() == enemy_queue, "Cancellation must never affect an enemy queue")
	game.selected.clear()
	for state: String in ["incomplete", "dead"]:
		factory.completed = state != "incomplete"
		factory.hp = 0.0 if state == "dead" else DATA.spec("factory").hp
		game._refresh_ui()
		var funds: int = int(game.world.resources[0].essence)
		game._train("tank")
		_check(game.unit_buttons.tank.visible and game.unit_buttons.tank.disabled and factory.queue.is_empty() and int(game.world.resources[0].essence) == funds, "Incomplete/dead producers and other building kinds must not unlock tanks: " + state)
	factory.completed = true
	factory.hp = DATA.spec("factory").hp
	_find(game, 0, "power").hp = 0.0
	game._train("tank")
	game._refresh_ui()
	_check(factory.queue.size() == 1 and game.power_label.tooltip_text.contains("LOW POWER") and game.queue_label.text.contains("HALF SPEED") and not game.unit_buttons.tank.disabled, "Low power must explain slower training while allowing global unit production")
	game._cancel_queue()
	_find(game, 0, "power").hp = DATA.spec("power").hp
	var second: Dictionary = game.world._spawn("barracks", 0, Vector2(1100, 520))
	game.world.queue_unit(barracks.id, "infantry")
	game.world.queue_unit(second.id, "infantry")
	barracks.queue[0].remaining = 7.0
	second.queue[0].remaining = 2.0
	game.selected.clear()
	game._train("infantry")
	_check(barracks.queue.size() == 1 and second.queue.size() == 2, "Global training must choose the producer with the shortest remaining queue")
	game._cancel_queue()
	game.selected = [barracks.id]
	game._train("infantry")
	_check(barracks.queue.size() == 2 and second.queue.size() == 1, "An explicitly selected eligible producer must take priority over a shorter queue")
	game._cancel_queue()
	game.world.cancel_queue(barracks.id)
	game.selected.clear()
	game._refresh_ui()
	_check(game.queue_label.text.contains("Vanguard") and not game.cancel_button.disabled, "Global queue display must find another owned queue when the focused producer is empty")
	game._cancel_queue()
	_check(second.queue.is_empty(), "Global cancellation must clear the fallback owned queue")
	game.world.entities.erase(second.id)
	var funds: int = int(game.world.resources[0].essence)
	game.world.resources[0].essence = 0
	game._refresh_ui()
	game._train("worker")
	_check(game.unit_buttons.worker.disabled and hq.queue.is_empty() and int(game.world.resources[0].essence) == 0, "Global training must still enforce Essence costs")
	game.world.resources[0].essence = funds
	game.selected = [barracks.id]
	game._refresh_ui()

func _test_pause_and_feedback(game: Variant) -> void:
	game._toggle_pause()
	var elapsed: float = float(game.world.elapsed)
	game._process(2.0)
	_check(bool(game.paused) and float(game.world.elapsed) == elapsed, "Pause must freeze world simulation")
	var hovering_worker: Dictionary = _find(game, 0, "worker")
	var frozen_hover: Vector2 = ART.hover_offset(hovering_worker, elapsed)
	_check(ART.hover_offset(hovering_worker, float(game.world.elapsed)) == frozen_hover, "Pause must freeze the unit hover clock along with the simulation")
	var funds: int = int(game.world.resources[0].essence)
	game._train("infantry")
	_check(int(game.world.resources[0].essence) == funds, "Paused UI must reject production orders")
	game._toggle_pause()
	game._mark(Vector2(800, 400), false)
	game._process(1.0)
	_check(game.view.command_markers.is_empty(), "Command markers must expire rather than accumulating indefinitely")

func _test_destruction_visibility_and_pause(game: Variant) -> void:
	var unit: Dictionary = game.world._spawn("infantry", 0, Vector2(740, 520))
	unit.hp = 0.0
	game.world.tick(0.05)
	var effect: Dictionary = game.world.destruction_effects.back()
	_check(game.view._destruction_visible(effect), "Friendly death animation must be eligible for the battlefield render pass")
	var hidden: Dictionary = effect.duplicate(true)
	hidden.owner = 1
	hidden.pos = Vector2(2752, 1728)
	_check(not game.view._destruction_visible(hidden), "Enemy destruction outside current vision must not render")
	hidden.pos = Vector2(320, 320)
	hidden.visible_to_player = false
	_check(not game.view._destruction_visible(hidden), "Exploration must not reveal an unobserved enemy death")
	var ttl: float = float(effect.ttl)
	game._toggle_pause()
	game._process(0.5)
	_check(bool(game.paused) and float(effect.ttl) == ttl, "Pause must freeze death animations")
	game._toggle_pause()
	game._process(0.2)
	_check(float(effect.ttl) < ttl, "Resuming must advance death animations with the simulation")
	game.world.destruction_effects.clear()

func _test_combat_victory_and_restart(game: Variant) -> void:
	for id: int in game.world.entities.keys():
		if str(game.world.entities[id].kind) != "hq":
			game.world.entities.erase(id)
	var enemy_hq: Dictionary = _find(game, 1, "hq")
	var attackers: Array = []
	for index: int in range(6):
		var tank: Dictionary = game.world._spawn("tank", 0, Vector2(enemy_hq.pos) + Vector2(-200, -100 + index * 40))
		attackers.append(int(tank.id))
	game.world._rebuild_navigation()
	game.world._rebuild_buckets()
	game.world._update_fog()
	game.world.order_attack(attackers, int(enemy_hq.id))
	for frame: int in range(400):
		game.world.tick(0.05)
	game._process(0.0)
	_check(str(game.world.match_state) == "victory", "A real tank attack must be able to destroy the enemy Command Center")
	_check(not bool(game.end_shown) and not is_instance_valid(game.overlay) and not game._can_issue(), "Victory must stop orders immediately and leave the battlefield visible for the final explosion")
	_check(not game.world.destruction_effects.is_empty() and str(game.world.destruction_effects.back().kind) == "hq", "The decisive Command Center loss must retain its explosion")
	var survivor: Dictionary = game.world.entities[attackers[0]]
	var ended_time: float = float(game.world.elapsed)
	var ended_hover: Vector2 = ART.hover_offset(survivor, ended_time)
	game._process(0.5)
	_check(float(game.world.elapsed) == ended_time and ART.hover_offset(survivor, float(game.world.elapsed)) == ended_hover, "Match completion must freeze hovering as well as combat and movement")
	_check(float(game.world.destruction_effects.back().ttl) < 2.4, "The final explosion must animate while match time remains frozen")
	game._process(2.4)
	_check(bool(game.end_shown) and is_instance_valid(game.overlay) and game.world.destruction_effects.is_empty(), "Results must appear once the final destruction animation finishes")
	game.groups[1] = attackers.duplicate()
	game._restart()
	_check(str(game.world.match_state) == "playing" and float(game.world.elapsed) == 0.0, "Restart must create a fresh playable match")
	_check(int(game.world.resources[0].essence) == 900 and game.groups.is_empty(), "Restart must restore starting Essence and clear old control groups")
	_check(not bool(game.paused) and not bool(game.end_shown) and not is_instance_valid(game.overlay), "Restart must clear pause and result overlays")

func _test_edge_scroll_camera(game: Variant) -> void:
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var saved_pointer_inside: bool = bool(game._mouse_inside_window)
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var origin: Vector2 = Vector2(1000, 700)
	var step: float = 650.0 * 0.1
	game.zoom_level = 1.0
	game._mouse_inside_window = true
	var edges: Array = [
		{"name": "left outer window edge", "point": Vector2(1, viewport_size.y * 0.5), "direction": Vector2.LEFT},
		{"name": "right outer window edge over sidebar", "point": Vector2(viewport_size.x - 1, viewport_size.y * 0.5), "direction": Vector2.RIGHT},
		{"name": "top outer window edge", "point": Vector2(viewport_size.x * 0.5, 1), "direction": Vector2.UP},
		{"name": "bottom outer window edge", "point": Vector2(viewport_size.x * 0.5, viewport_size.y - 1), "direction": Vector2.DOWN},
		{"name": "right battlefield edge beside sidebar", "point": Vector2(float(game.battlefield_size.x) - 1, 400), "direction": Vector2.RIGHT},
		{"name": "top battlefield edge", "point": Vector2(float(game.battlefield_size.x) * 0.5, float(game.field_clip.position.y) + 1), "direction": Vector2.UP}
	]
	for edge: Dictionary in edges:
		game.camera_pos = origin
		game._pan_camera(0.1, edge.point, true)
		_check(Vector2(game.camera_pos).distance_to(origin + Vector2(edge.direction) * step) < 0.001, "Camera must pan at the " + str(edge.name))
	game.camera_pos = origin
	game._pan_camera(0.1, Vector2(1, 1), true)
	var diagonal: Vector2 = Vector2(game.camera_pos) - origin
	_check(diagonal.x < 0.0 and diagonal.y < 0.0 and absf(diagonal.length() - step) < 0.001, "Corner scrolling must move diagonally without exceeding straight-line speed")
	var quiet_points: Array[Vector2] = [
		Vector2(float(game.battlefield_size.x) + 120, 400),
		Vector2(500, 28),
		Vector2(500, 400),
		Vector2(-1, 400),
		Vector2(viewport_size.x, 400),
		Vector2(500, -1),
		Vector2(500, viewport_size.y)
	]
	for point: Vector2 in quiet_points:
		game.camera_pos = origin
		game._pan_camera(0.1, point, true)
		_check(Vector2(game.camera_pos) == origin, "HUD interiors and outside-window positions must not drift the camera: " + str(point))
	for zoom: float in [0.65, 1.6]:
		game.zoom_level = zoom
		game.camera_pos = origin
		game._pan_camera(0.1, Vector2(viewport_size.x - 1, 400), true)
		_check(absf(float(game.camera_pos.x) - origin.x - step / zoom) < 0.001 and absf(float(game.camera_pos.y) - origin.y) < 0.001, "Edge scrolling must retain screen speed at zoom " + str(zoom))
		game.camera_pos = Vector2.ZERO
		game._pan_camera(100.0, Vector2(1, 1), true)
		_check(_camera_inside_map(game), "Camera must stay inside projected bounds and keep its center on the map at upper-left limits, zoom " + str(zoom))
		var low_limit: Vector2 = game.camera_pos
		game._pan_camera(100.0, Vector2(1, 1), true)
		_check(Vector2(game.camera_pos).distance_to(low_limit) < 0.001, "Repeated upper-left overscroll must remain stable at zoom " + str(zoom))
		game.camera_pos = PROJECT.map_bounds().size
		game._pan_camera(100.0, viewport_size - Vector2.ONE, true)
		_check(_camera_inside_map(game), "Camera must stay inside projected bounds and keep its center on the map at lower-right limits, zoom " + str(zoom))
		var high_limit: Vector2 = game.camera_pos
		game._pan_camera(100.0, viewport_size - Vector2.ONE, true)
		_check(Vector2(game.camera_pos).distance_to(high_limit) < 0.001, "Repeated lower-right overscroll must remain stable at zoom " + str(zoom))
	game.zoom_level = 1.0
	var edge_point: Vector2 = Vector2(viewport_size.x - 1, 400)
	game.camera_pos = origin
	game._pan_camera(0.1, edge_point, false)
	_check(Vector2(game.camera_pos) == origin, "Inactive windows must not scroll")
	game._mouse_inside_window = false
	game._pan_camera(0.1, edge_point, true)
	_check(Vector2(game.camera_pos) == origin, "A pointer that left the window must not retain edge scrolling")
	game._mouse_inside_window = true
	game.dragging = true
	game._pan_camera(0.1, edge_point, true)
	_check(Vector2(game.camera_pos) == origin, "Selection drags must suppress automatic edge scrolling")
	game.dragging = false
	game.middle_drag = true
	game._pan_camera(0.1, edge_point, true)
	_check(Vector2(game.camera_pos) == origin, "Middle-mouse camera drags must suppress simultaneous edge scrolling")
	game.middle_drag = false
	game.started = false
	game._pan_camera(0.1, edge_point, true)
	_check(Vector2(game.camera_pos) == origin, "The title state must not pan the battlefield")
	game.started = true
	var modal: Control = Control.new()
	game.ui.add_child(modal)
	game.overlay = modal
	game._pan_camera(0.1, edge_point, true)
	_check(Vector2(game.camera_pos) == origin, "An open overlay must suppress edge scrolling")
	game.overlay = null
	modal.queue_free()
	game.confirm_restart.show()
	game._pan_camera(0.1, edge_point, true)
	_check(Vector2(game.camera_pos) == origin, "Restart confirmation must suppress edge scrolling")
	game.confirm_restart.hide()
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom
	game._mouse_inside_window = saved_pointer_inside

func _test_decorated_window_edges(game: Variant) -> void:
	var client := Rect2(108, 132, 1366, 864)
	var frame := Rect2(100, 100, 1382, 904)
	for sample: Array in [
		[Vector2(100, 564), Vector2.LEFT], [Vector2(791, 100), Vector2.UP],
		[Vector2(1481, 564), Vector2.RIGHT], [Vector2(791, 1003), Vector2.DOWN],
		[Vector2(100, 100), Vector2(-1, -1)], [Vector2(1481, 100), Vector2(1, -1)],
		[Vector2(100, 1003), Vector2(-1, 1)], [Vector2(1481, 1003), Vector2(1, 1)],
		[client.position, Vector2.ZERO], [client.get_center(), Vector2.ZERO],
		[Vector2(99, 564), Vector2.ZERO], [Vector2(791, 99), Vector2.ZERO],
		[Vector2(1482, 564), Vector2.ZERO], [Vector2(791, 1004), Vector2.ZERO]
	]:
		_check(game._frame_edge_scroll_direction(sample[0], client, frame) == sample[1], "Decorated window edges must scroll only inside the frame and outside the client: " + str(sample[0]))
	var saved_inside: bool = bool(game._mouse_inside_window)
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var origin: Vector2 = PROJECT.project(DATA.MAP_SIZE * 0.5) - Vector2(game.battlefield_size) * 0.5
	game._mouse_inside_window = false
	game.zoom_level = 1.0
	for direction: Vector2 in [Vector2.LEFT, Vector2.UP]:
		game.camera_pos = origin
		game._pan_camera(0.1, Vector2(-1, -1), true, direction)
		_check(Vector2(game.camera_pos).distance_to(origin + direction * 65.0) < 0.001, "Window frame fallback must pan while the pointer is outside the client: " + str(direction))
	game.camera_pos = origin
	game._pan_camera(0.1, Vector2(-1, -1), true)
	_check(Vector2(game.camera_pos) == origin, "Leaving the client without a frame fallback must keep edge scrolling stopped")
	game._pan_camera(0.1, Vector2(-1, -1), false, Vector2.LEFT)
	_check(Vector2(game.camera_pos) == origin, "Inactive windows must reject frame edge scrolling")
	game.dragging = true
	game._pan_camera(0.1, Vector2(-1, -1), true, Vector2.LEFT)
	_check(Vector2(game.camera_pos) == origin, "Selection dragging must reject frame edge scrolling")
	game.dragging = false
	game.middle_drag = true
	game._pan_camera(0.1, Vector2(-1, -1), true, Vector2.UP)
	_check(Vector2(game.camera_pos) == origin, "Middle dragging must reject frame edge scrolling")
	game.middle_drag = false
	var modal := Control.new()
	game.ui.add_child(modal)
	game.overlay = modal
	game._pan_camera(0.1, Vector2(-1, -1), true, Vector2.UP)
	_check(Vector2(game.camera_pos) == origin, "Modal overlays must reject frame edge scrolling")
	game.overlay = null
	modal.queue_free()
	game.confirm_restart.show()
	game._pan_camera(0.1, Vector2(-1, -1), true, Vector2.LEFT)
	_check(Vector2(game.camera_pos) == origin, "Restart confirmation must reject frame edge scrolling")
	game.confirm_restart.hide()
	game._mouse_inside_window = true
	game.camera_pos = origin
	game._pan_camera(0.1, Vector2(1, float(game.battlefield_size.y) * 0.5), true, Vector2.UP)
	_check(Vector2(game.camera_pos).distance_to(origin + Vector2.UP * 65.0) < 0.001, "Native top-frame scrolling must override a stale left-edge pointer and inside-client flag")
	game.camera_pos = origin
	game._pan_camera(0.1, Vector2(float(game.battlefield_size.x) * 0.5, 1), true, Vector2.LEFT)
	_check(Vector2(game.camera_pos).distance_to(origin + Vector2.LEFT * 65.0) < 0.001, "Native left-frame scrolling must override a stale top-edge pointer and inside-client flag")
	game._mouse_inside_window = saved_inside
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom

func _test_native_pointer_sampling(game: Variant) -> void:
	var saved_inside: bool = bool(game._mouse_inside_window)
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var viewport_size: Vector2 = game.get_viewport_rect().size
	var stretch: Transform2D = game.get_viewport().get_stretch_transform()
	var client := Rect2(Vector2(108, 132), Vector2(root.size))
	var frame := Rect2(client.position - Vector2(8, 32), client.size + Vector2(16, 40))
	var origin: Vector2 = PROJECT.project(DATA.MAP_SIZE * 0.5) - Vector2(game.battlefield_size) * 0.5
	game.zoom_level = 1.0
	game._mouse_inside_window = false
	for sample: Array in [
		[client.position + Vector2(0, client.size.y * 0.5), Vector2(viewport_size.x - 1, viewport_size.y * 0.5), Vector2.LEFT],
		[client.position + Vector2(client.size.x * 0.5, 0), Vector2(viewport_size.x * 0.5, viewport_size.y - 1), Vector2.UP]
	]:
		var direction: Vector2 = game._native_edge_scroll_direction(sample[0], client, frame, stretch)
		game.camera_pos = origin
		game._pan_camera(0.1, sample[1], true, direction)
		_check(direction == sample[2] and Vector2(game.camera_pos).distance_to(origin + Vector2(sample[2]) * 65.0) < 0.001, "Live native client edges must override stale opposite-edge viewport coordinates and a false inside flag")
	game._mouse_inside_window = true
	for native_pointer: Vector2 in [client.get_center(), frame.position - Vector2.ONE]:
		var direction: Vector2 = game._native_edge_scroll_direction(native_pointer, client, frame, stretch)
		game.camera_pos = origin
		game._pan_camera(0.1, Vector2(1, 1), true, direction)
		_check(direction == Vector2.ZERO and Vector2(game.camera_pos) == origin, "Authoritative native center/outside coordinates must suppress stale viewport edge movement")
	var frame_left := Vector2(client.position.x - 4, client.get_center().y)
	_check(game._native_edge_scroll_direction(frame_left, client, frame, stretch) == Vector2.LEFT and game._native_edge_scroll_direction(frame_left, client, frame, stretch, true) == Vector2.ZERO, "Mouse buttons must suppress native decoration scrolling")
	_check(game._native_edge_scroll_direction(client.position + Vector2(0, client.size.y * 0.5), client, frame, stretch, true) == Vector2.LEFT, "Mouse buttons must preserve native client-edge direction sampling")
	game._mouse_inside_window = saved_inside
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom

func _test_expanded_window_edges(game: Variant) -> void:
	var saved_size: Vector2i = root.size
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var saved_inside: bool = bool(game._mouse_inside_window)
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Runtime viewport scaling must expand to fill different display aspect ratios")
	game.zoom_level = 1.0
	game._mouse_inside_window = true
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(3440, 1440), Vector2i(1280, 1024)]:
		root.size = size
		await process_frame
		game._layout()
		await process_frame
		var viewport: Rect2 = game.get_viewport_rect()
		var stretch: Transform2D = game.get_viewport().get_stretch_transform()
		var inverse: Transform2D = stretch.affine_inverse()
		var physical_size: Vector2 = Vector2(root.size)
		_check((stretch * viewport.position).length() < 1.0 and (stretch * viewport.end).distance_to(physical_size) < 1.5, "Rendered viewport must fill the physical window without black bars at %s" % size)
		var client := Rect2(Vector2(108, 132), physical_size)
		var frame := Rect2(client.position - Vector2(8, 32), client.size + Vector2(16, 40))
		_check(game._native_edge_scroll_direction(client.position + Vector2(15, physical_size.y * 0.5), client, frame, stretch) == Vector2.LEFT and game._native_edge_scroll_direction(client.position + Vector2(physical_size.x * 0.5, 15), client, frame, stretch) == Vector2.UP, "Native client sampling must remove the window position and canvas stretch at %s" % size)
		var origin: Vector2 = PROJECT.project(DATA.MAP_SIZE * 0.5) - Vector2(game.battlefield_size) * 0.5
		var edges: Array = [
			{"name": "left", "direction": Vector2.LEFT, "inside": Vector2(15, physical_size.y * 0.5), "outside": Vector2(17, physical_size.y * 0.5)},
			{"name": "right", "direction": Vector2.RIGHT, "inside": Vector2(physical_size.x - 15, physical_size.y * 0.5), "outside": Vector2(physical_size.x - 17, physical_size.y * 0.5)},
			{"name": "top", "direction": Vector2.UP, "inside": Vector2(physical_size.x * 0.5, 15), "outside": Vector2(physical_size.x * 0.5, 17)},
			{"name": "bottom", "direction": Vector2.DOWN, "inside": Vector2(physical_size.x * 0.5, physical_size.y - 15), "outside": Vector2(physical_size.x * 0.5, physical_size.y - 17)}
		]
		for edge: Dictionary in edges:
			var inside: Vector2 = inverse * Vector2(edge.inside)
			var outside: Vector2 = inverse * Vector2(edge.outside)
			game.camera_pos = origin
			game._pan_camera(0.1, inside, true)
			_check(game._edge_scroll_direction(inside) == Vector2(edge.direction) and Vector2(game.camera_pos).distance_to(origin + Vector2(edge.direction) * 65.0) < 0.001, "The %s screen edge must pan within its 16 physical pixel band at %s" % [edge.name, size])
			game.camera_pos = origin
			game._pan_camera(0.1, outside, true)
			_check(game._edge_scroll_direction(outside) == Vector2.ZERO and Vector2(game.camera_pos).distance_to(origin) < 0.001, "The %s edge must stop panning beyond 16 physical pixels at %s" % [edge.name, size])
		var sidebar_interior := Vector2(float(game.battlefield_size.x) + 1.0 / absf(stretch.get_scale().x), viewport.size.y * 0.5)
		_check(game._edge_scroll_direction(sidebar_interior) == Vector2.ZERO, "Sidebar interior next to the battlefield must not inherit battlefield edge scrolling at %s" % size)
		var scale: Vector2 = stretch.get_scale().abs()
		_check(game._edge_scroll_direction(inverse * Vector2(0, physical_size.y * 0.5)) == Vector2.LEFT and game._edge_scroll_direction(inverse * Vector2(physical_size.x * 0.5, 0)) == Vector2.UP and game._edge_scroll_direction(inverse * Vector2.ZERO) == Vector2(-1, -1), "Exact physical zero must scroll at left, top, and their corner at %s" % size)
		_check(game._edge_scroll_direction(Vector2(-0.0005 / scale.x, viewport.size.y * 0.5)) == Vector2.LEFT and game._edge_scroll_direction(Vector2(viewport.size.x * 0.5, -0.0005 / scale.y)) == Vector2.UP, "Subpixel negative transform roundoff must preserve left/top edge scrolling at %s" % size)
		_check(game._edge_scroll_direction(Vector2(-1.0 / scale.x, viewport.size.y * 0.5)) == Vector2.ZERO and game._edge_scroll_direction(Vector2(viewport.size.x * 0.5, -1.0 / scale.y)) == Vector2.ZERO, "A pointer one physical pixel outside the client must remain rejected at %s" % size)
	root.size = saved_size
	await process_frame
	game._layout()
	await process_frame
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom
	game._mouse_inside_window = saved_inside
	_sync_view(game)

func _test_isometric_navigation(game: Variant) -> void:
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var point: Vector2 = Vector2(1500, 1000)
	_center_on(game, point)
	for zoom: float in [0.65, 1.0, 1.6]:
		game.zoom_level = zoom
		_sync_view(game)
		var screen: Vector2 = game.view.world_to_screen(point)
		_check(Vector2(game.view.screen_to_world(screen)).distance_to(point) < 0.001, "Isometric screen/world transforms must round-trip at zoom " + str(zoom))
	game.zoom_level = 1.0
	_center_on(game, point)
	var cursor: Vector2 = Vector2(400, 300)
	var before: Vector2 = game.view.screen_to_world(cursor)
	_button(game, cursor + Vector2(game.field_clip.position), MOUSE_BUTTON_WHEEL_UP, true)
	_sync_view(game)
	var after: Vector2 = game.view.screen_to_world(cursor)
	_check(before.distance_to(after) < 0.001, "Mouse-wheel zoom must preserve the simulation position under the cursor")
	var radar: Variant = game.radar
	var navigation_point: Vector2 = Vector2(1700, 1100)
	var local: Vector2 = radar.map_world_to_local(navigation_point)
	_check(radar.contains_map_point(local), "Projected radar positions must lie within the map diamond")
	_check(Vector2(radar.map_local_to_world(local)).distance_to(navigation_point) < 0.001, "Radar coordinates must unproject back into simulation space")
	var captured: Array = []
	radar.navigate.connect(func(value: Vector2) -> void: captured.append(value))
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = local
	radar._gui_input(click)
	_check(captured.size() == 1 and Vector2(captured[0]).distance_to(navigation_point) < 0.001, "Radar clicks must emit unprojected simulation coordinates")
	var expected_camera: Vector2 = PROJECT.project(navigation_point) - Vector2(game.battlefield_size) / float(game.zoom_level) * 0.5
	var limit: Vector2 = (PROJECT.map_bounds().size - Vector2(game.battlefield_size) / float(game.zoom_level)).max(Vector2.ZERO)
	expected_camera = expected_camera.clamp(Vector2.ZERO, limit)
	_check(Vector2(game.camera_pos).distance_to(expected_camera) < 0.001, "Radar navigation must center the projected camera on the clicked world point")
	var camera_before: Vector2 = game.camera_pos
	click.position = radar._map_rect().position + Vector2(1, 1)
	_check(not radar.contains_map_point(click.position), "The radar bounding box corner must remain outside the actual map diamond")
	radar._gui_input(click)
	_check(captured.size() == 1 and Vector2(game.camera_pos) == camera_before, "Clicks outside the radar diamond must not navigate")
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom
	_sync_view(game)

func _camera_inside_map(game: Variant) -> bool:
	var camera: Vector2 = game.camera_pos
	var visible_size: Vector2 = Vector2(game.battlefield_size) / float(game.zoom_level)
	var limits: Vector2 = (PROJECT.map_bounds().size - visible_size).max(Vector2.ZERO)
	var center: Vector2 = PROJECT.unproject(camera + visible_size * 0.5)
	return camera.x >= -0.001 and camera.y >= -0.001 and camera.x <= limits.x + 0.001 and camera.y <= limits.y + 0.001 and center.x >= -0.001 and center.y >= -0.001 and center.x <= DATA.MAP_SIZE.x + 0.001 and center.y <= DATA.MAP_SIZE.y + 0.001

func _test_isometric_hits_and_orders(game: Variant) -> void:
	var hq: Dictionary = _find(game, 0, "hq")
	_center_on(game, hq.pos)
	var roof: Vector2 = game.view.world_to_screen(hq.pos) + Vector2(0, -82) * float(game.zoom_level) + Vector2(game.field_clip.position)
	_button(game, roof, MOUSE_BUTTON_LEFT, true)
	_button(game, roof, MOUSE_BUTTON_LEFT, false)
	_check(game.selected == [hq.id], "Raised building bodies must remain clickable above their ground footprints")
	var front: Dictionary = game.world._spawn("infantry", 0, Vector2(960, 710))
	var back: Dictionary = game.world._spawn("infantry", 0, Vector2(950, 700))
	_center_on(game, front.pos)
	var overlap: Vector2 = game.view.world_to_screen(front.pos) + Vector2(0, -18) * float(game.zoom_level) + Vector2(game.field_clip.position)
	_button(game, overlap, MOUSE_BUTTON_LEFT, true)
	_button(game, overlap, MOUSE_BUTTON_LEFT, false)
	_check(game.selected == [front.id], "Overlapping upright sprites must select the frontmost entity rather than the last inserted entity")
	var anchor: Vector2 = game.view.world_to_screen(front.pos) + Vector2(game.field_clip.position)
	_button(game, anchor + Vector2(-4, -32) * float(game.zoom_level), MOUSE_BUTTON_LEFT, true)
	_button(game, anchor + Vector2(4, -25) * float(game.zoom_level), MOUSE_BUTTON_LEFT, false)
	_check(game.selected.has(front.id), "Drag boxes touching a raised sprite body must select its unit even when the ground anchor is outside")
	game.world.entities.erase(int(front.id))
	game.world.entities.erase(int(back.id))
	var worker: Dictionary = _find(game, 0, "worker")
	_click_world(game, worker.pos)
	var move_goal: Vector2 = Vector2(850, 600)
	_click_world(game, move_goal, MOUSE_BUTTON_RIGHT)
	_check(str(worker.order) == "move" and Vector2(worker.goal).distance_to(move_goal) < 0.001, "Isometric right-click move orders must target simulation coordinates")
	var patch: Dictionary = game.world.deposits[0]
	game.world._update_fog()
	_click_world(game, patch.pos, MOUSE_BUTTON_RIGHT)
	_check(str(worker.order) == "gather" and int(worker.target) == int(patch.id), "Isometric right-click harvesting must select the correct Essence patch")
	var raised_crystal: Vector2 = PROJECT.unproject(PROJECT.project(patch.pos) + Vector2(0, -28))
	_click_world(game, raised_crystal, MOUSE_BUTTON_RIGHT)
	_check(str(worker.order) == "gather" and int(worker.target) == int(patch.id), "Right-clicking the raised crystal body must harvest its underlying Essence patch")
	var hidden_patch: Dictionary = game.world.deposits[8]
	_check(not game.world.is_visible(0, hidden_patch.pos), "Remote Essence patches must remain outside player vision")
	var hidden_crystal: Vector2 = PROJECT.unproject(PROJECT.project(hidden_patch.pos) + Vector2(0, -28))
	_click_world(game, hidden_crystal, MOUSE_BUTTON_RIGHT)
	_check(str(worker.order) != "gather" and int(worker.target) != int(hidden_patch.id), "Hidden crystal bodies must not expose a harvesting target through fog")
	var soldier: Dictionary = _find(game, 0, "infantry")
	var enemy: Dictionary = game.world._spawn("worker", 1, Vector2(worker.pos) + Vector2(90, 40))
	game.world._update_fog()
	_click_world(game, soldier.pos)
	_click_world(game, enemy.pos, MOUSE_BUTTON_RIGHT)
	_check(str(soldier.order) == "attack" and int(soldier.target) == int(enemy.id), "Isometric right-click attacks must hit the visible enemy sprite")
	game.world.entities.erase(int(enemy.id))
	game.world._rebuild_buckets()

func _test_fog_render_state(game: Variant) -> void:
	var scenario: Variant = game.world.get_script().new()
	scenario.ai_enabled = false
	var view: Variant = game.view
	view.world = scenario
	view._update_fog_cache()
	var old_cell: Vector2i = Vector2i(10, 10)
	var untouched: Vector2i = Vector2i(90, 3)
	_check(float(view._fog_image.get_pixelv(old_cell).a) < 0.01, "Currently visible terrain must render without a fog overlay")
	_check(float(view._fog_image.get_pixelv(untouched).a) > 0.99, "Unexplored terrain must render opaque fog")
	for entity: Dictionary in scenario.entities.values():
		if int(entity.owner) == 0:
			entity["pos"] = Vector2(entity.pos) + Vector2(1100, 900)
	scenario._update_fog()
	view._update_fog_cache()
	var moved_cell: Vector2i = Vector2i(Vector2(1420, 1220) / DATA.CELL_SIZE)
	var explored_alpha: float = float(view._fog_image.get_pixelv(old_cell).a)
	_check(explored_alpha > 0.1 and explored_alpha < 0.95 and float(view._fog_image.get_pixelv(moved_cell).a) < 0.01, "Visibility changes must darken explored terrain and reveal newly visible terrain")
	scenario.reset()
	view._update_fog_cache()
	_check(float(view._fog_image.get_pixelv(old_cell).a) < 0.01 and float(view._fog_image.get_pixelv(moved_cell).a) > 0.99, "Restart must rebuild fog rather than retaining the previous match's explored areas")
	view.world = game.world
	view._update_fog_cache()

func _key(game: Variant, key: Key, pressed: bool, dispatch_command: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if dispatch_command:
		game._unhandled_input(event)

func _command_button(node: Node, key: String, action: String) -> Button:
	if node is Button and node.text.begins_with(key) and node.text.contains(action):
		return node
	for child: Node in node.get_children():
		var result: Button = _command_button(child, key, action)
		if result != null:
			return result
	return null

func _test_keyboard_camera_and_commands(game: Variant) -> void:
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var saved_inside: bool = bool(game._mouse_inside_window)
	var saved_selected: Array = game.selected.duplicate()
	var origin: Vector2 = Vector2(1800, 900)
	var pointer: Vector2 = Vector2(500, 400)
	var step: float = 650.0 * 0.1
	game.zoom_level = 1.0
	game._mouse_inside_window = false
	for binding: Dictionary in [
		{"key": KEY_W, "arrow": KEY_UP, "direction": Vector2.UP},
		{"key": KEY_A, "arrow": KEY_LEFT, "direction": Vector2.LEFT},
		{"key": KEY_S, "arrow": KEY_DOWN, "direction": Vector2.DOWN},
		{"key": KEY_D, "arrow": KEY_RIGHT, "direction": Vector2.RIGHT}
	]:
		game.camera_pos = origin
		_key(game, binding.key, true)
		game._pan_camera(0.1, pointer, true)
		_key(game, binding.key, false)
		_check(Vector2(game.camera_pos).distance_to(origin + Vector2(binding.direction) * step) < 0.001, "WASD must pan the camera in the matching direction: " + OS.get_keycode_string(binding.key))
		game.camera_pos = origin
		_key(game, binding.key, true)
		_key(game, binding.arrow, true)
		game._pan_camera(0.1, pointer, true)
		_key(game, binding.key, false)
		_key(game, binding.arrow, false)
		_check(Vector2(game.camera_pos).distance_to(origin + Vector2(binding.direction) * step) < 0.001, "Holding WASD and its arrow alias together must not double camera speed")
	game.camera_pos = origin
	_key(game, KEY_W, true)
	_key(game, KEY_D, true)
	game._pan_camera(0.1, pointer, true)
	_key(game, KEY_W, false)
	_key(game, KEY_D, false)
	var diagonal: Vector2 = Vector2(game.camera_pos) - origin
	_check(diagonal.x > 0 and diagonal.y < 0 and absf(diagonal.length() - step) < 0.001, "Diagonal WASD movement must use normalized camera speed")
	game.camera_pos = origin
	_key(game, KEY_A, true)
	_key(game, KEY_D, true)
	game._pan_camera(0.1, pointer, true)
	_key(game, KEY_A, false)
	_key(game, KEY_D, false)
	_check(Vector2(game.camera_pos).distance_to(origin) < 0.001, "Opposing camera keys must cancel rather than drift")
	for zoom: float in [0.65, 1.6]:
		game.zoom_level = zoom
		game.camera_pos = origin
		_key(game, KEY_D, true)
		game._pan_camera(0.1, pointer, true)
		_key(game, KEY_D, false)
		_check(Vector2(game.camera_pos).distance_to(origin + Vector2.RIGHT * step / zoom) < 0.001, "WASD must preserve screen-space speed at zoom " + str(zoom))
	game.zoom_level = 1.0
	game.camera_pos = origin
	_key(game, KEY_D, true)
	game._pan_camera(0.1, pointer, false)
	_check(Vector2(game.camera_pos) == origin, "WASD must not pan an inactive window")
	game._pan_camera(0.1, Vector2(-1, -1), true)
	_check(Vector2(game.camera_pos).distance_to(origin + Vector2.RIGHT * step) < 0.001, "Focused keyboard panning must keep working after the pointer leaves the window")
	game.camera_pos = origin
	var modal: Control = Control.new()
	game.ui.add_child(modal)
	game.overlay = modal
	game._pan_camera(0.1, pointer, true)
	_key(game, KEY_D, false)
	_check(Vector2(game.camera_pos) == origin, "An open overlay must block WASD camera movement")
	game.overlay = null
	modal.queue_free()
	var soldier: Dictionary = _find(game, 0, "infantry")
	game.selected = [soldier.id]
	game.world.order_move(game.selected, Vector2(850, 600))
	game.attack_mode = false
	_key(game, KEY_A, true, true)
	_key(game, KEY_A, false, true)
	_check(not game.attack_mode and str(soldier.order) == "move", "A must pan without enabling attack mode or replacing the selected unit's order")
	_key(game, KEY_S, true, true)
	_key(game, KEY_S, false, true)
	_check(not game.attack_mode and str(soldier.order) == "move", "S must pan without stopping the selected unit")
	_key(game, KEY_E, true, true)
	_key(game, KEY_E, false, true)
	_check(game.attack_mode, "E must activate attack-move after the WASD remap")
	_key(game, KEY_X, true, true)
	_key(game, KEY_X, false, true)
	_check(not game.attack_mode and str(soldier.order) == "idle", "X must stop the selected unit and leave attack mode")
	var attack_button: Button = _command_button(game.ui, "E", "ATTACK")
	var stop_button: Button = _command_button(game.ui, "X", "STOP")
	_check(attack_button == null, "Attack-move must remain a fixed shortcut without a sidebar command button")
	_check(stop_button == null, "Stop must remain a fixed shortcut without a sidebar command button")
	_check(_command_button(game.ui, "H", "HOLD") == null, "Hold must remain a fixed shortcut without a sidebar command button")
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom
	game._mouse_inside_window = saved_inside
	game.selected = saved_selected
	_sync_view(game)

func _test_hover_picking_and_drag(game: Variant) -> void:
	var saved_camera: Vector2 = game.camera_pos
	var saved_zoom: float = float(game.zoom_level)
	var saved_time: float = float(game.world.elapsed)
	var unit: Dictionary = game.world._spawn("infantry", 0, Vector2(960, 710))
	var low_time: float = 0.0
	var high_time: float = 0.0
	var low: float = INF
	var high: float = -INF
	for sample: int in range(261):
		var time: float = float(sample) * 0.01
		var height: float = ART.hover_offset(unit, time).y
		if height < low:
			low = height
			low_time = time
		if height > high:
			high = height
			high_time = time
	game.zoom_level = 1.0
	_center_on(game, unit.pos)
	var top: float = INF
	for point: Vector2 in ART.hit_polygon(unit):
		top = minf(top, point.y)
	var edge_point: Vector2 = PROJECT.project(unit.pos) + Vector2(0, top - 1.5)
	game.world.elapsed = low_time
	_check(game._pick(PROJECT.unproject(edge_point), 0) == unit.id, "Picking must follow a rising unit above its unshifted top silhouette")
	var click: Vector2 = (edge_point - Vector2(game.camera_pos)) * float(game.zoom_level) + Vector2(game.field_clip.position)
	_button(game, click, MOUSE_BUTTON_LEFT, true)
	_button(game, click, MOUSE_BUTTON_LEFT, false)
	_check(game.selected == [unit.id], "Actual mouse selection must hit the bobbing unit's raised top edge")
	var raised_bounds: Rect2 = game._entity_screen_rect(unit)
	game.world.elapsed = high_time
	_check(game._pick(PROJECT.unproject(edge_point), 0) != unit.id, "Picking must stop hitting empty space after a unit bobs below that point")
	var lowered_bounds: Rect2 = game._entity_screen_rect(unit)
	_check(absf(lowered_bounds.position.y - raised_bounds.position.y - (high - low) * float(game.zoom_level)) < 0.001 and lowered_bounds.size == raised_bounds.size, "Drag selection bounds must translate with hover while retaining their dimensions")
	var anchor: Vector2 = game._world_to_screen(unit.pos)
	var drag_start: Vector2 = Vector2(anchor.x - 4, raised_bounds.position.y + 0.2) + Vector2(game.field_clip.position)
	var drag_end: Vector2 = Vector2(anchor.x + 4, raised_bounds.position.y + 1.2) + Vector2(game.field_clip.position)
	game.world.elapsed = low_time
	_button(game, drag_start, MOUSE_BUTTON_LEFT, true)
	_button(game, drag_end, MOUSE_BUTTON_LEFT, false)
	_check(game.selected.has(unit.id), "Drag selection must include the raised portion of a bobbing unit")
	game.world.elapsed = high_time
	_button(game, drag_start, MOUSE_BUTTON_LEFT, true)
	_button(game, drag_end, MOUSE_BUTTON_LEFT, false)
	_check(not game.selected.has(unit.id), "Drag selection must not retain a stale raised-body hit area")
	game.world.entities.erase(int(unit.id))
	game.world._rebuild_buckets()
	game.world.elapsed = saved_time
	game.camera_pos = saved_camera
	game.zoom_level = saved_zoom
	_sync_view(game)

func _test_difficulty_menu(game: Variant) -> void:
	game._show_skirmish()
	var selector: OptionButton = game.difficulty_select
	var labels: Array[String] = []
	for index: int in range(selector.item_count):
		labels.append(selector.get_item_text(index))
	_check(labels == ["Easy", "Normal", "Hard"], "The title screen must offer Easy, Normal, and Hard difficulty choices")
	_check(selector.selected == 1 and str(game.world.ai_difficulty) == "normal" and not game.difficulty_description.text.is_empty(), "A new game must default to Normal with a visible description")
	var descriptions: Array[String] = []
	for index: int in range(3):
		selector.select(index)
		selector.item_selected.emit(index)
		descriptions.append(str(game.difficulty_description.text))
		_check(str(game.world.ai_difficulty) == SIM.AI_LEVELS[index] and not descriptions[index].is_empty(), "Selecting the actual difficulty dropdown must update the game profile and description: " + labels[index])
	_check(descriptions[0] != descriptions[1] and descriptions[1] != descriptions[2] and descriptions[0] != descriptions[2], "Difficulty descriptions must explain distinct behavior for each selection")
	game.world.set_ai_difficulty("easy")
	game._start_match()
	_check(game.started and str(game.world.ai_difficulty) == "hard" and not is_instance_valid(game.overlay), "Deploy must apply the selected dropdown choice before removing the title screen")
	game._restart()
	_check(str(game.world.ai_difficulty) == "hard" and float(game.world.elapsed) == 0.0 and str(game.world.match_state) == "playing", "Restart must retain the selected difficulty in a fresh match")
	game.world.set_ai_difficulty("normal")
	game._restart()

func _test_faction_picking_and_context(game: Variant) -> void:
	var saved_entities: Dictionary = game.world.entities.duplicate()
	var saved_selected: Array = game.selected.duplicate()
	var saved_factions: Array[String] = game.world.player_factions.duplicate()
	game.world.configure_skirmish("humans", "iron_synod")
	game.world.entities.clear()
	var observer: Dictionary = game.world._spawn("tank", 0, Vector2(1000, 600))
	var enemy: Dictionary = game.world._spawn("infantry", 1, Vector2(1200, 600))
	game.world._rebuild_buckets()
	game.world._update_fog()
	var click: Vector2 = PROJECT.unproject(PROJECT.project(enemy.pos) + ART.hover_offset(enemy, game.world.elapsed) + Vector2(0, -20))
	game.selected = [observer.id]
	_check(game.world.is_visible(0, enemy.pos) and game._pick(click, 1) == enemy.id, "A visible Synod unit must be pickable before firing and beyond close range")
	game._issue_context(click)
	_check(str(observer.order) == "attack" and int(observer.target) == int(enemy.id), "A visible Synod unit must accept the normal context attack")
	game.world.visible[0].clear()
	_check(game._pick(click, 1) == -1, "Fog must hide enemy bodies from mouse picking")
	game._issue_context(click)
	_check(str(observer.order) == "move" and int(observer.target) == -1, "Right-clicking an enemy hidden by fog must issue only a ground order")
	game.world._update_fog()
	_check(game._pick(click, 1) == enemy.id, "Restoring terrain vision must make the enemy immediately pickable")
	game.world.entities.clear()
	game.world.entities.merge(saved_entities)
	game.world.player_factions = saved_factions
	game.selected = saved_selected
	game.world._rebuild_buckets()
	game.world._update_fog()
	game._refresh_ui()
