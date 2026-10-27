extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
const DATA = preload("res://scripts/catalog.gd")
const MAPS = preload("res://scripts/skirmish_maps.gd")
const SIM = preload("res://scripts/simulation.gd")
const PROJECT = preload("res://scripts/projection.gd")
const ART = preload("res://scripts/faction_sprites.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		var result := _find_button(child, text)
		if result != null:
			return result
	return null

func _press(game: Variant, text: String) -> void:
	var button := _find_button(game.overlay, text)
	_check(button != null, "Menu must expose %s" % text)
	if button != null:
		button.pressed.emit()

func _select(selector: OptionButton, index: int) -> void:
	selector.select(index)
	selector.item_selected.emit(index)

func _check_menu_frozen(game: Variant) -> void:
	var elapsed: float = game.world.elapsed
	var essence: int = int(game.world.resources[0].essence)
	game._process(0.5)
	game._train("worker")
	game._choose_build("power")
	_check(is_equal_approx(game.world.elapsed, elapsed) and int(game.world.resources[0].essence) == essence, "Menus must freeze simulation and reject production orders")
	_check(not game._can_issue() and game.build_kind.is_empty(), "Menus must reject battlefield placement")

func _run() -> void:
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	_check(game.menu_screen == "title" and not game.started, "Startup must open the title screen without deploying")
	_check_menu_frozen(game)
	_press(game, "SKIRMISH")
	_check(game.menu_screen == "skirmish" and not game.started, "Skirmish button must open setup without deploying")
	_check(game.player_faction_select.item_count == 6 and game.enemy_faction_select.item_count == 6, "Both commanders must offer all six playable faction choices")
	for index: int in range(DATA.FACTIONS.size()):
		_check(game.player_faction_select.get_item_text(index) == DATA.faction_name(DATA.FACTIONS[index]) and game.enemy_faction_select.get_item_text(index) == DATA.faction_name(DATA.FACTIONS[index]), "Both selectors must show full faction names")
	_check_menu_frozen(game)
	_press(game, "BACK TO TITLE")
	_check(game.menu_screen == "title" and not game.started, "Returning from setup must restore title")
	for index: int in range(DATA.FACTIONS.size()):
		game._show_skirmish()
		_select(game.player_faction_select, index)
		_select(game.enemy_faction_select, (index + 1) % DATA.FACTIONS.size())
		_select(game.difficulty_select, 2)
		_check(game.player_faction_description.text.contains(str(DATA.FACTION_STYLES[DATA.FACTIONS[index]])), "Setup must explain the selected faction gameplay style")
		_press(game, "START SKIRMISH")
		var faction: String = DATA.FACTIONS[index]
		_check(game.started and game.menu_screen == "battle" and not is_instance_valid(game.overlay), "Deploy must enter the battlefield and remove menus")
		_check(game.world.faction_for(0) == faction and game.world.faction_for(1) == DATA.FACTIONS[(index + 1) % DATA.FACTIONS.size()] and game.world.ai_difficulty == "hard", "Deployment must apply both commander choices and difficulty")
		_check(game.faction_label.text.to_lower().contains(DATA.faction_name(faction).to_lower()), "HUD must identify the selected faction")
		for kind: String in ["worker", "infantry", "tank"]:
			var button: Button = game.unit_buttons[kind]
			_check(button.text.contains(DATA.faction_title(kind, faction)) and button.tooltip_text.contains(DATA.faction_title(kind, faction)), "Production labels and tooltips must follow the selected faction")
			var definition: Dictionary = game.world.spec_for(kind, 0)
			_check(button.text.contains(str(definition.cost) + " ESS") and button.tooltip_text.contains("%d essence / %s seconds" % [definition.cost, definition.time]), "Each faction production button must show its actual cost and train time")
			if kind != "worker":
				game.world._spawn(str(DATA.UNIT_PRODUCERS[kind]), 0, Vector2(850, 700))
			game.world.resources[0]["essence"] = int(definition.cost) - 1
			game._refresh_ui()
			_check(button.disabled, "Faction production must be disabled below its actual cost")
			game.world.resources[0]["essence"] = int(definition.cost)
			game._refresh_ui()
			_check(not button.disabled, "Faction production must become available at its actual cost")
			game._train(kind)
			_check(int(game.world.resources[0].essence) == 0, "Sidebar production must charge the displayed faction cost")
			var icon: AtlasTexture = button.icon as AtlasTexture
			_check(icon != null and icon.region.position.y >= index * ART.UNIT_CELL.y and icon.region.end.y <= (index + 1) * ART.UNIT_CELL.y, "Production thumbnails must use the selected faction atlas row")
		game.world.tick(0.2)
		game._restart()
		_check(game.world.faction_for(0) == faction and game.world.ai_difficulty == "hard" and is_zero_approx(game.world.elapsed), "Restart must retain setup choices and reset match time")
		game._show_title()
		await process_frame
	game._show_skirmish()
	_select(game.player_faction_select, 3)
	_select(game.enemy_faction_select, 3)
	game._start_match()
	_check(game.world.faction_for(0) == "heavenly_host" and game.world.faction_for(1) == "heavenly_host", "Mirror-faction skirmishes must remain valid")
	game.audio_button.pressed.emit()
	var main_menu := _find_button(game.overlay, "MAIN MENU")
	_check(main_menu != null, "Settings / Pause must expose a return to the title screen")
	if main_menu != null:
		main_menu.pressed.emit()
		var elapsed: float = game.world.elapsed
		game._process(0.5)
		_check(game.confirm_leave.visible and game.started and not game._can_issue() and is_equal_approx(game.world.elapsed, elapsed), "Leaving a running match must request confirmation and suspend simulation and orders")
		game.confirm_leave.hide()
		_check(game.started and game._audio_open and game.paused and not game._can_issue(), "Cancelling the leave prompt must retain the paused match Settings")
		main_menu.pressed.emit()
		game.confirm_leave.confirmed.emit()
		_check(game.menu_screen == "title" and not game.started, "Confirmed leave must return to title")
		game._show_skirmish()
		game._start_match()
	game.world.match_state = "victory"
	game._show_end()
	_press(game, "NEW SKIRMISH")
	_check(game.menu_screen == "skirmish" and not game.started, "Results must open setup for a new skirmish")
	_check_menu_frozen(game)
	_check(game.map_select.item_count == 4, "Setup must offer the original map plus three different map sizes")
	_check(game.player_color_select.item_count == 8 and game.enemy_color_select.item_count == 8, "Both commanders must have eight army colors")
	for index: int in range(MAPS.MAPS.size()):
		game._show_skirmish()
		_select(game.map_select, index)
		_select(game.player_faction_select, 0)
		_select(game.enemy_faction_select, 0)
		_select(game.player_color_select, 2)
		_select(game.enemy_color_select, 2)
		_check(game.player_color_select.selected != game.enemy_color_select.selected and game.enemy_color_select.selected == 2, "Picking a duplicate AI color must keep the new choice and reassign the player color")
		_select(game.player_color_select, 2)
		_check(game.player_color_select.selected == 2 and game.enemy_color_select.selected != 2, "Picking a duplicate player color must keep the new choice and reassign the AI color")
		_select(game.enemy_color_select, 4)
		var id: String = str(MAPS.MAPS.keys()[index])
		_check(game.map_description.text.contains(str(MAPS.MAPS[id].description)), "Map description must follow selection")
		game._start_match()
		_check(game.world.map_id == id and game.world.map_size == MAPS.MAPS[id].size, "Deploy must apply selected map dimensions")
		_check(game.world.color_for(0) == SIM.PLAYER_COLORS[2] and game.world.color_for(1) == SIM.PLAYER_COLORS[4], "Deploy must apply independent army colors to mirror factions")
		for entity: Dictionary in game.world.entities.values():
			_check(entity.team_color == game.world.color_for(entity.owner), "All starting units and buildings must use their commander's color")
		var point: Vector2 = game.world.map_size - Vector2(256, 256)
		_check(game._screen_to_world(game._world_to_screen(point)).distance_to(point) < 0.001, "Battlefield picking must round-trip for every map size")
		_check(game.radar.map_local_to_world(game.radar.map_world_to_local(point)).distance_to(point) < 0.001, "Radar picking must round-trip for every map size")
		game.camera_pos = Vector2(99999, 99999)
		game._clamp_camera()
		var bounds: Rect2 = PROJECT.map_bounds(game.world.map_size)
		_check(bounds.has_point(game.camera_pos), "Camera must clamp to the selected map")
		game.world.elapsed = 5.0
		game._restart()
		_check(game.world.map_id == id and game.world.color_for(0) == SIM.PLAYER_COLORS[2] and game.world.color_for(1) == SIM.PLAYER_COLORS[4] and is_zero_approx(game.world.elapsed), "Restart must retain map and colors while resetting match time")
		game._show_skirmish()
		_check(game.map_select.selected == index and game.player_color_select.selected == 2 and game.enemy_color_select.selected == 4, "Reopening setup must retain deployed map and army colors")
		await process_frame
	for size: Vector2i in [Vector2i(1366, 864), Vector2i(1100, 720)]:
		root.size = size
		await process_frame
		game._layout()
		game._show_skirmish()
		await process_frame
		await process_frame
		var bounds: Rect2 = game.get_viewport_rect()
		_check(bounds.encloses(game.player_faction_select.get_global_rect()) and bounds.encloses(game.enemy_faction_select.get_global_rect()) and bounds.encloses(game.difficulty_select.get_global_rect()), "Skirmish selectors must fit the viewport at %s" % size)
		for selector: OptionButton in [game.map_select, game.player_color_select, game.enemy_color_select]:
			_check(bounds.encloses(selector.get_global_rect()), "Map and color selectors must fit the viewport at %s" % size)
		for text: String in ["START SKIRMISH", "BACK TO TITLE"]:
			_check(bounds.encloses(_find_button(game.overlay, text).get_global_rect()), "Setup actions must fit the viewport at %s" % size)
		game._show_title()
		await process_frame
		await process_frame
		var skirmish := _find_button(game.overlay, "SKIRMISH")
		_check(skirmish != null and bounds.encloses(skirmish.get_global_rect()), "Title controls must fit the viewport at %s" % size)
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	print("%s: %d skirmish menu integration checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
