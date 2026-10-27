extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)

func _select(game: Variant, ids: Array) -> void:
	game.selected = ids
	game._refresh_ui()

# Exercise GUI press/release routing while the normal periodic HUD refresh runs.
# Emitting Button.pressed directly cannot detect clicks cancelled mid-press.
func _click_through_refresh(game: Variant, button: Button) -> void:
	await process_frame
	await process_frame
	var center: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = center
	click.global_position = center
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	root.push_input(click, true)
	_check(button.is_pressed(), "GUI mouse press must reach the building action")
	game._process(0.2)
	_check(button.is_pressed(), "An enabled building action must retain its pending click through a HUD refresh")
	click = click.duplicate()
	click.pressed = false
	click.button_mask = 0
	root.push_input(click, true)

func _test_first_click(game: Variant) -> void:
	var power: Dictionary = game.world.entities[2]
	power.hp = float(power.maxhp) * 0.5
	game.world.resources[0].essence = 100
	_select(game, [int(power.id)])
	await _click_through_refresh(game, game.repair_button)
	_check(power.repairing, "One real click spanning a HUD refresh must start Repair")
	await _click_through_refresh(game, game.repair_button)
	_check(not power.repairing, "One real click spanning a HUD refresh must stop Repair")
	var funds: int = game.world.resources[0].essence
	var refund: int = game.world.sell_refund(0, int(power.id))
	await _click_through_refresh(game, game.sell_button)
	_check(not game.world.entities.has(int(power.id)) and game.world.resources[0].essence == funds + refund, "One real click spanning a HUD refresh must sell a building exactly once")
	_select(game, [1])
	await _click_through_refresh(game, game.sell_button)
	_check(game.confirm_sell.visible and game.world.entities.has(1), "One real Sell click must open the Command Center confirmation")
	game.confirm_sell.get_cancel_button().pressed.emit()
	await process_frame

func _run() -> void:
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	_check(not game.building_actions.visible, "Building actions must start hidden on the title screen")
	game._start_match()
	await _test_first_click(game)
	game._restart()
	var power: Dictionary = game.world.entities[2]
	var hq: Dictionary = game.world.entities[1]
	var enemy: Dictionary = game.world.entities[10]
	var worker: Dictionary = game.world.entities[4]
	for ids: Array in [[], [int(worker.id)], [int(enemy.id)], [int(power.id), int(hq.id)], [99999]]:
		_select(game, ids)
		_check(not game.building_actions.visible and game._selected_building().is_empty(), "Only one valid owned building may expose repair/sell actions: " + str(ids))
		var funds: int = game.world.resources[0].essence
		game._repair_selected()
		game._sell_selected()
		_check(game.world.resources[0].essence == funds and game.world.entities.has(int(power.id)) and game.world.entities.has(int(enemy.id)), "Invalid selections must not charge or remove buildings")
	_select(game, [int(power.id)])
	_check(game.building_actions.visible and game.repair_button.disabled and not game.sell_button.disabled, "A healthy owned building must expose Sell and disable Repair")
	power.hp = 0.0
	game._refresh_ui()
	_check(not game.building_actions.visible, "A dead building must never accept repair or sale")
	power.hp = float(power.maxhp) * .5
	game.world.resources[0].essence = 100
	game._refresh_ui()
	_check(not game.repair_button.disabled and game.repair_button.tooltip_text.contains("Essence"), "Damaged building repair must be enabled with a visible price explanation")
	var before_hp: float = power.hp
	game.repair_button.pressed.emit()
	_check(power.repairing and game.repair_button.text == "STOP REPAIR" and game.selection_detail.text.contains("REPAIRING"), "Repair button must start paid repair and display its active status")
	game._process(1.0)
	game._refresh_ui()
	_check(float(power.hp) > before_hp and int(game.world.resources[0].essence) < 100, "Actual simulation ticks must increase HP and spend repair funds")
	_check(game.selection_detail.text.contains(str(ceili(power.hp))) and game.essence_label.text == str(game.world.resources[0].essence), "HP and Essence indicators must follow repair progress")
	game.repair_button.pressed.emit()
	_check(not power.repairing and game.repair_button.text == "REPAIR", "Repair button must toggle active repair off")
	game.world.resources[0].essence = 0
	game.repair_button.pressed.emit()
	_check(power.repairing and game.selection_detail.text.contains("REPAIR WAITING: NEED ESSENCE") and not game.repair_button.disabled, "Zero-fund repair must wait visibly and remain stoppable")
	before_hp = power.hp
	game._process(.5)
	_check(is_equal_approx(float(power.hp), before_hp), "Waiting repair must not grant free health")
	game.world.resources[0].essence = 10
	game._process(1.0)
	_check(float(power.hp) > before_hp and int(game.world.resources[0].essence) < 10, "Waiting repair must resume when Essence becomes available")
	game.repair_button.pressed.emit()
	var incomplete: Dictionary = game.world._spawn("barracks", 0, Vector2(900, 700), false)
	_select(game, [int(incomplete.id)])
	_check(game.building_actions.visible and game.repair_button.disabled and not game.sell_button.disabled, "Incomplete structures may be sold but cannot be repaired")
	game._repair_selected()
	_check(not incomplete.repairing, "Direct repair callback must reject incomplete construction")
	var refund: int = game.world.sell_refund(0, int(incomplete.id))
	var funds: int = game.world.resources[0].essence
	game.sell_button.pressed.emit()
	_check(not game.world.entities.has(int(incomplete.id)) and int(game.world.resources[0].essence) == funds + refund, "Sell button must remove unfinished construction for its displayed salvage")
	_check(game.selected.is_empty() and not game.building_actions.visible, "Sold structures must leave selection and hide building actions")

	# Production prices are paid through the real queue API and shown in the sale total.
	var producer: Dictionary = game.world._spawn("barracks", 0, Vector2(900, 700))
	game.world.resources[0].essence = 1000
	_check(game.world.queue_unit(int(producer.id), "infantry") and game.world.queue_unit(int(producer.id), "infantry"), "Sale fixture must contain two paid production orders")
	producer.hp = float(producer.maxhp) * .5
	var queued_cost: int = int(game.world.spec_for("infantry", 0).cost) * 2
	refund = game.world.sell_refund(0, int(producer.id)) + queued_cost
	game.production_focus = int(producer.id)
	_select(game, [int(producer.id)])
	_check(game.sell_button.text == "SELL +%d ESS" % refund and game.sell_button.tooltip_text.contains("%d Essence refunded" % queued_cost), "Sale must display health-scaled salvage plus exact paid queue refunds")
	funds = game.world.resources[0].essence
	game.sell_button.pressed.emit()
	_check(not game.world.entities.has(int(producer.id)) and game.production_focus == -1 and game.selected.is_empty(), "Selling a producer must clear its selected/focused identity")
	_check(int(game.world.resources[0].essence) == funds + refund and producer.queue.is_empty(), "Producer sale must refund salvage and every queued unit once")
	game.sell_button.pressed.emit()
	_check(int(game.world.resources[0].essence) == funds + refund, "A repeated sale callback must never duplicate a refund")

	_select(game, [int(power.id)])
	for gate: String in ["paused", "settings", "end", "not_started"]:
		if gate == "paused": game.paused = true
		if gate == "settings": game._show_audio_settings()
		if gate == "end": game.world.match_state = "victory"
		if gate == "not_started": game.started = false
		game._refresh_ui()
		var repairing: bool = power.repairing
		funds = game.world.resources[0].essence
		before_hp = power.hp
		_check(game.repair_button.disabled and game.sell_button.disabled, "Building controls must be disabled during " + gate)
		game._repair_selected()
		game._sell_selected()
		_check(game.world.entities.has(int(power.id)) and power.repairing == repairing and power.hp == before_hp and int(game.world.resources[0].essence) == funds, "Direct repair/sell callbacks must respect " + gate)
		if gate == "paused": game.paused = false
		if gate == "settings": game._close_audio_settings()
		if gate == "end": game.world.match_state = "playing"
		if gate == "not_started": game.started = true

	# The non-rebuildable Command Center requires an explicit defeat warning.
	_select(game, [int(hq.id)])
	_check(game.sell_button.tooltip_text.contains("defeat") and game.sell_button.tooltip_text.contains("Confirmation"), "Command Center sale must warn about defeat before activation")
	funds = game.world.resources[0].essence
	game.sell_button.pressed.emit()
	await process_frame
	_check(game.confirm_sell.visible and game._sell_target == int(hq.id) and game.world.entities.has(int(hq.id)), "Command Center sale must wait for confirmation")
	_check(game.confirm_sell.dialog_text.contains("defeat") and not game._can_issue(), "Confirmation must explain the consequence and block orders")
	_check(game.repair_button.disabled and game.sell_button.disabled, "Confirmation must disable building actions")
	var elapsed: float = game.world.elapsed
	var camera: Vector2 = game.camera_pos
	game._process(.5)
	game._pan_camera(.5, Vector2.ZERO, true, Vector2.RIGHT)
	game._command("A")
	_check(game.world.elapsed == elapsed and game.camera_pos == camera and not game.attack_mode, "Sale confirmation must freeze simulation, camera scrolling, and orders")
	game.confirm_sell.get_cancel_button().pressed.emit()
	await process_frame
	_check(not game.confirm_sell.visible and game._sell_target == -1 and game.world.entities.has(int(hq.id)) and game.world.resources[0].essence == funds, "Cancelling sale must retain the Command Center and all funds")
	game._refresh_ui()
	_check(game._can_issue() and not game.sell_button.disabled, "Cancelled sale must restore ordinary match controls")
	game.sell_button.pressed.emit()
	game.confirm_sell.get_ok_button().pressed.emit()
	await process_frame
	_check(not game.confirm_sell.visible and game._sell_target == -1 and not game.world.entities.has(int(hq.id)) and game.world.match_state == "defeat", "Confirmed Command Center sale must resolve immediately as defeat")
	_check(not game._can_issue() and game.selected.is_empty(), "Confirmed defeat must remove selection and stop further orders")

	game._restart()
	_check(game.world.match_state == "playing" and not game.confirm_sell.visible and game._sell_target == -1, "Restart must begin with a clean sale-confirmation state")
	_select(game, [1])
	game.sell_button.pressed.emit()
	game._restart()
	_check(not game.confirm_sell.visible and game._sell_target == -1 and game._can_issue(), "Restart during pending confirmation must discard the old sale target")
	game._confirm_building_sale()
	_check(game.world.entities.has(1) and game.world.match_state == "playing", "A stale confirmation after restart must not sell the new match's Command Center")

	for size: Vector2i in [Vector2i(1366, 864), Vector2i(1100, 720)]:
		root.size = size
		await process_frame
		game._layout()
		var building: Dictionary = game.world.entities[2]
		building.hp = float(building.maxhp) * .5
		_select(game, [2])
		await process_frame
		await process_frame
		var viewport: Rect2 = game.get_viewport_rect()
		for button: Button in [game.repair_button, game.sell_button]:
			_check(viewport.encloses(button.get_global_rect()) and game.sidebar.get_global_rect().encloses(button.get_global_rect()), "Building action must fit sidebar and viewport at %s" % size)
			var width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			_check(width + button.get_theme_stylebox("normal").get_minimum_size().x <= button.size.x, "Building action text must fit without clipping at %s" % size)
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	print("%s: %d building actions UI checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
