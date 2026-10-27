extends SceneTree
const SCENE = preload("res://scenes/main.tscn")
const DATA = preload("res://scripts/catalog.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func _run() -> void:
	root.size = Vector2i(1100, 720)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	for faction: String in DATA.FACTIONS:
		game.world.configure_skirmish(faction, faction)
		game._start_match()
		_check(game.unit_buttons.size() == 21 and game.build_buttons.size() == 12, "Each side must expose all21 unit types and all12 buildable structures")
		var seen: Dictionary = {}
		for page: int in range(4):
			game.unit_page = page
			game._refresh_ui()
			for kind: String in game.unit_buttons:
				var button: Button = game.unit_buttons[kind]
				if button.visible: seen[kind] = true
				_check(button.icon is AtlasTexture and button.text.contains(DATA.faction_title(kind, faction)), "Every unit card must use its own faction name and baked artwork")
		_check(seen.size() == 21, "Production pages must make every unit reachable")
		seen.clear()
		for page: int in range(2):
			game.building_page = page
			game._refresh_ui()
			for kind: String in game.build_buttons:
				var button: Button = game.build_buttons[kind]
				if button.visible: seen[kind] = true
				_check(button.icon is AtlasTexture and button.text.contains(DATA.faction_title(kind, faction)), "Every building card must use its own faction name and baked artwork")
		_check(seen.size() == 12, "Construction pages must make every building reachable")
		game.unit_page = 0
		game.building_page = 0
		game._change_catalog_page(false, -1)
		game._change_catalog_page(true, -1)
		_check(game.unit_page == 3 and game.building_page == 1, "Catalog paging must wrap without losing entries")
		game.world.resources[0].essence = 10000
		var producer: Dictionary = game.world._spawn("arsenal", 0, Vector2(850, 700))
		game._refresh_ui()
		var button: Button = game.unit_buttons.artillery
		_check(not button.disabled and button.tooltip_text.contains(game.world.entity_title("arsenal", 0)), "A new unit must unlock at its actual named producer")
		var funds: int = int(game.world.resources[0].essence)
		game._train("artillery")
		_check(producer.queue.size() == 1 and int(game.world.resources[0].essence) == funds - int(game.world.spec_for("artillery", 0).cost), "The sidebar must charge the actual new unit's faction price")
		_check(game.queue_label.text.contains(game.world.entity_title("artillery", 0)) and game.queue_label.text.contains(game.world.entity_title("arsenal", 0)), "Queue text must name the faction unit and its producer")
		game._cancel_queue()
		_check(producer.queue.is_empty() and int(game.world.resources[0].essence) == funds, "The sidebar must refund new units exactly once")
		var barracks: Dictionary = game.world._spawn("barracks", 0, Vector2(1100, 700))
		game._refresh_ui()
		_check(game.unit_buttons.sniper.disabled and game.unit_buttons.sniper.tooltip_text.contains(game.world.entity_title("sanctum", 0)), "Additional technology prerequisites must be visible and enforced by sidebar affordance")
		game.world._spawn("sanctum", 0, Vector2(1250, 700))
		game._refresh_ui()
		_check(not game.unit_buttons.sniper.disabled, "Completing the required faction support producer must unlock the specialist")
		game.world.entities.erase(int(barracks.id))
		game._refresh_ui()
		_check(game.unit_buttons.sniper.disabled, "Losing the producer must disable new specialist production")
		if faction in ["iron_synod", "heavenly_host"]:
			var card: Button = game.build_buttons.arsenal
			var font: Font = card.get_theme_font("font")
			var needed_height: float = 3.0 * font.get_height(card.get_theme_font_size("font_size")) + card.get_theme_stylebox("normal").get_minimum_size().y
			_check(card.custom_minimum_size.y >= needed_height, "Long faction structure names plus their cost must fit three text lines without clipping")
		_check(game.unit_buttons.disruptor.tooltip_text.contains("Slows targets") and game.unit_buttons.medic.tooltip_text.contains("Healing per second"), "Ability cards must explain usable support and control stats")
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	print("%s: %d expansion UI checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
