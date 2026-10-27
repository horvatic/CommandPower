extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _key(game: Variant, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_input(event)

func _assert_sidebar(game: Variant) -> void:
	var settings_count := 0
	for button: Node in game.sidebar.find_children("*", "Button", true, false):
		_check(button.text not in ["E  ATTACK", "X  STOP", "H  HOLD", "RESTART", "MUSIC ON", "MUSIC OFF", "SETTINGS", "MAIN MENU", "II"], "Removed controls must not remain in sidebar: " + button.text)
		if button.text == "Settings / Pause":
			settings_count += 1
	_check(settings_count == 1 and game.audio_button.text == "Settings / Pause", "Battlefield must expose one Settings / Pause button")

func _assert_paused(game: Variant, expected_overlay: Control) -> void:
	var elapsed: float = game.world.elapsed
	var essence: int = int(game.world.resources[0].essence)
	game._process(1.0)
	game._train("worker")
	game._command("A")
	_check(game._audio_open and game.paused and game.overlay == expected_overlay, "Settings and confirmations must preserve the paused menu")
	_check(is_equal_approx(game.world.elapsed, elapsed) and int(game.world.resources[0].essence) == essence and not game._can_issue() and not game.attack_mode, "Settings must freeze simulation and reject production/battlefield commands")

func _run() -> void:
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	_assert_sidebar(game)
	game._show_audio_settings()
	_check(game.settings_done_button.text == "DONE" and not game.settings_restart_button.is_visible_in_tree() and not game.settings_main_menu_button.is_visible_in_tree(), "Title Settings must close normally and hide match actions")
	_check(game.settings_audio.is_ancestor_of(game.music_button) and game.music_button.is_visible_in_tree(), "Music toggle must be available inside Settings Audio")
	game.settings_done_button.pressed.emit()
	_check(not game._audio_open and not game.started and game.menu_screen == "title", "Done from title Settings must restore the title screen")

	game._start_match()
	game._process(.2)
	game.audio_button.pressed.emit()
	await process_frame
	var settings: Control = game.overlay
	_check(game._audio_open and game.paused and game.settings_done_button.text == "RESUME", "Unified button must open Settings and pause the active match")
	_check(game.overlay.is_ancestor_of(game.settings_restart_button) and game.overlay.is_ancestor_of(game.settings_main_menu_button), "Restart and Main Menu must belong to Settings")
	_check(game.settings_restart_button.visible and game.settings_main_menu_button.visible, "Match Settings must expose Restart and Main Menu")
	_assert_paused(game, settings)
	var muted: bool = game.music.muted
	game.music_button.pressed.emit()
	_check(game.music.muted != muted and game.music_button.text == ("MUSIC OFF" if game.music.muted else "MUSIC ON"), "Moved music control must toggle mute with readable status")
	game.settings_controls_tab.pressed.emit()
	_check(game.settings_controls.visible and game.settings_restart_button.is_visible_in_tree() and game.settings_main_menu_button.is_visible_in_tree() and game.settings_done_button.is_visible_in_tree(), "Match actions and Resume must remain available from Controls")

	game.settings_restart_button.pressed.emit()
	await process_frame
	_check(game.confirm_restart.visible, "Restart in Settings must require confirmation")
	_assert_paused(game, settings)
	game.confirm_restart.get_cancel_button().pressed.emit()
	await process_frame
	_check(not game.confirm_restart.visible and game.overlay == settings and game.settings_controls.visible, "Cancelled restart must retain the same Settings tab")
	_assert_paused(game, settings)
	game.settings_main_menu_button.pressed.emit()
	await process_frame
	_check(game.confirm_leave.visible, "Main Menu in active-match Settings must require confirmation")
	_assert_paused(game, settings)
	game.confirm_leave.get_cancel_button().pressed.emit()
	await process_frame
	_check(not game.confirm_leave.visible and game.overlay == settings and game.settings_controls.visible, "Cancelled leave must return to the same Settings tab")
	_assert_paused(game, settings)
	game.settings_done_button.pressed.emit()
	_check(not game._audio_open and not game.paused and not is_instance_valid(game.overlay) and game._can_issue(), "Resume must close Settings and restore battlefield commands")
	var elapsed: float = game.world.elapsed
	game._process(.2)
	_check(game.world.elapsed > elapsed, "Resume must restart simulation time")

	_key(game, KEY_SPACE)
	_check(game.paused and game.audio_button.text == "Settings / Pause", "Space must preserve fixed pause behavior without replacing the unified label")
	game.audio_button.pressed.emit()
	game.settings_done_button.pressed.emit()
	_check(not game.paused and not game._audio_open and game._can_issue(), "Resume must also resume a match that was paused before opening Settings")
	_key(game, KEY_SPACE)
	game.audio_button.pressed.emit()
	_key(game, KEY_ESCAPE)
	_check(game.paused and not game._audio_open, "Escape from Settings must retain a pre-existing pause")
	_key(game, KEY_SPACE)
	_check(not game.paused, "Fixed Space shortcut must still resume the match")

	var infantry: Dictionary = {}
	for entity: Dictionary in game.world.entities.values():
		if entity.owner == 0 and entity.kind == "infantry": infantry = entity
	game.selected = [int(infantry.id)]
	_key(game, KEY_E)
	_check(game.attack_mode, "E must retain attack-move after removing its sidebar button")
	_key(game, KEY_X)
	_check(not game.attack_mode and infantry.order == "idle", "X must retain Stop after removing its sidebar button")
	_key(game, KEY_H)
	_check(infantry.order == "hold", "H must retain Hold after removing its sidebar button")

	game.music.set_volume_percent(37)
	var previous_mute: bool = game.music.muted
	game.audio_button.pressed.emit()
	game.settings_restart_button.pressed.emit()
	game.confirm_restart.get_ok_button().pressed.emit()
	await process_frame
	_check(not game._audio_open and not game.paused and game.started and game.world.match_state == "playing" and not is_instance_valid(game.overlay), "Confirmed Settings restart must create an unpaused match without stale overlays")
	_check(not game.confirm_restart.visible and not game.confirm_leave.visible and game.world.elapsed == 0.0, "Restart must clear confirmations and match time")
	_check(is_equal_approx(game.music.volume_percent, 37) and game.music.muted == previous_mute, "Settings restart must preserve session audio choices")
	_assert_sidebar(game)

	game.audio_button.pressed.emit()
	game.settings_main_menu_button.pressed.emit()
	game.confirm_leave.get_ok_button().pressed.emit()
	await process_frame
	_check(game.menu_screen == "title" and not game.started and not game.paused and not game._audio_open and is_instance_valid(game.overlay), "Confirmed Main Menu must replace Settings with the title screen")
	_check(not game.confirm_restart.visible and not game.confirm_leave.visible and game._audio_previous_overlay == null, "Leaving must clear confirmations and saved Settings overlays")

	game._start_match()
	for size: Vector2i in [Vector2i(1366, 864), Vector2i(1100, 720)]:
		root.size = size
		await process_frame
		game._layout()
		game.audio_button.pressed.emit()
		await process_frame
		for controls: bool in [false, true]:
			game._show_settings_tab(controls)
			await process_frame
			await process_frame
			var panel: Control = game.settings_audio.get_parent().get_parent().get_parent()
			_check(game.get_viewport_rect().encloses(panel.get_global_rect()), "Settings panel must fit viewport for tab %s at %s" % [controls, size])
			for button: Button in [game.settings_restart_button, game.settings_main_menu_button, game.settings_done_button]:
				_check(button.is_visible_in_tree() and panel.get_global_rect().encloses(button.get_global_rect()), "Moved match action must fit both Settings tabs at %s: %s" % [size, button.text])
		game.settings_done_button.pressed.emit()
		_check(game.audio_button.text == "Settings / Pause", "Unified sidebar label must survive settings refresh at %s" % size)
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	print("%s: %d pause menu checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
