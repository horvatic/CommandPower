extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _key(game: Variant, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_input(event)

func _test_audio_pause(game: Variant) -> void:
	game._process(0.0)
	var worker: Dictionary = game.world.entities[4]
	_check(game.voice.acknowledge(game.world.entities, [worker.id], "select"), "Pause fixture must start an actual unit response")
	_check(game.sfx.on_player_event("construction_started", {"owner": 0, "pos": worker.pos}), "Pause fixture must start an actual construction effect")
	var effect: AudioStreamPlayer = game.sfx._players[0]
	var unit_playback: AudioStreamPlayback = game.voice.get_stream_playback()
	var effect_playback: AudioStreamPlayback = effect.get_stream_playback()
	var music_playback: AudioStreamPlayback = game.music.get_stream_playback()
	_key(game, KEY_SPACE)
	_check(game.voice.stream_paused and effect.stream_paused, "Space pause must suspend existing unit and effect clips instead of cancelling them")
	_check(not game.voice.acknowledge(game.world.entities, [worker.id], "move") and is_same(game.voice.get_stream_playback(), unit_playback), "Paused unit speech must reject new responses without replacing playback")
	await create_timer(0.06).timeout
	var voice_position: float = game.voice.get_playback_position()
	var effect_position: float = effect.get_playback_position()
	await create_timer(0.06).timeout
	_check(is_same(game.voice.get_stream_playback(), unit_playback) and is_same(effect.get_stream_playback(), effect_playback), "Paused gameplay clips must retain their original playback handles")
	_check(absf(game.voice.get_playback_position() - voice_position) < 0.03 and absf(effect.get_playback_position() - effect_position) < 0.03, "Paused clips must stop advancing after the mixer settles")
	_key(game, KEY_SPACE)
	_check(game.voice.playing and effect.playing and not game.voice.stream_paused and not effect.stream_paused, "Space resume must continue the existing unit and effect clips")
	game._show_audio_settings()
	_check(game.voice.stream_paused and effect.stream_paused and is_same(game.voice.get_stream_playback(), unit_playback) and is_same(effect.get_stream_playback(), effect_playback), "Settings pause must preserve active unit and construction sounds")
	game._close_audio_settings()
	_check(game.voice.playing and effect.playing and is_same(effect.get_stream_playback(), effect_playback), "Closing Settings must resume the original gameplay clips")
	_check(game.music.playing and is_same(game.music.get_stream_playback(), music_playback), "Pausing gameplay sounds must preserve uninterrupted music")
	game.world.match_state = "victory"
	game._show_end()
	_check(effect.playing and is_same(effect.get_stream_playback(), effect_playback), "Showing match results must let active effects finish naturally")
	game._restart()

func _run() -> void:
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	_check(is_equal_approx(game.music.volume_db, -14.0) and is_equal_approx(game.voice.volume_db, -3.0), "Audio settings must preserve the existing starting mix")
	var title: Control = game.overlay
	game.audio_button.pressed.emit()
	await process_frame
	_check(game._audio_open and not title.visible and game.overlay != title, "SETTINGS must open a modal while preserving the deployment screen")
	_check(not game.started and not game.paused, "Opening audio settings from deployment must not start or pause a match")
	_check(game.music_volume_slider.min_value == 0 and game.music_volume_slider.max_value == 100 and game.voice_volume_slider.max_value == 100 and game.sfx_volume_slider.min_value == 0 and game.sfx_volume_slider.max_value == 100, "All three sliders must expose the full 0–100 percent range")
	_check(game.music_volume_label.text == "20%" and game.voice_volume_label.text == "71%", "Audio settings must show separate readable percentage values")
	_check(game.sfx_volume_label.text == "50%" and is_equal_approx(game.sfx.volume_percent, 50), "Sound effects must start at a readable 50 percent level")
	_check(game.audio_button.text == "Settings / Pause", "The sidebar must expose the single Settings / Pause control")
	game.settings_controls_tab.pressed.emit()
	_check(game.settings_controls.visible and not game.settings_audio.visible and game.settings_controls_tab.button_pressed, "Controls must be a section inside Settings")
	var control_text := ""
	for label: Node in game.settings_controls.find_children("*", "Label", true, false):
		control_text += label.text + "\n"
	for binding: String in ["cannot be changed", "Left-click / drag", "Shift + select", "Right-click", "E then left-click", "X", "H", "Ctrl + 0–9 / 0–9", "WASD / arrows", "Screen edges / middle drag", "Mouse wheel", "F", "Space", "Esc", "M"]:
		_check(control_text.contains(binding), "Controls must document the fixed binding: " + binding)
	_check(game.settings_controls.find_children("*", "BaseButton", true, false).is_empty() and game.settings_controls.find_children("*", "Range", true, false).is_empty(), "Control bindings must be read-only, without editing widgets")
	game.settings_audio_tab.pressed.emit()
	_check(game.settings_audio.visible and not game.settings_controls.visible and game.settings_audio_tab.button_pressed, "Audio settings must remain available alongside Controls")
	game.sfx_volume_slider.value = 32
	_check(is_equal_approx(game.sfx.volume_percent, 32) and is_equal_approx(game.music.volume_db, -14.0) and is_equal_approx(game.voice.volume_db, -3.0), "Sound effect changes must leave music and unit voice levels independent")
	_check(game.sfx_volume_label.text == "32%", "Sound effects percentage must follow slider changes")
	game.sfx_volume_slider.value = 0
	_check(is_zero_approx(game.sfx.volume_percent), "Zero sound effects must silence that channel")
	game.sfx_volume_slider.value = 100
	_check(is_equal_approx(game.sfx.volume_percent, 100), "Sound effects must support full volume")
	game.sfx_volume_slider.value = 38
	var playback: AudioStreamPlayback = game.music.get_stream_playback()
	game.music_volume_slider.value = 47
	_check(is_equal_approx(game.music.volume_linear, .47) and is_equal_approx(game.voice.volume_db, -3.0), "Music slider changes must apply immediately without changing voices")
	game.voice_volume_slider.value = 13
	_check(is_equal_approx(game.voice.volume_linear, .13) and is_equal_approx(game.music.volume_linear, .47), "Voice slider changes must apply immediately without changing music")
	_check(game.music_volume_label.text == "47%" and game.voice_volume_label.text == "13%", "Percentage readouts must follow slider changes")
	_key(game, KEY_M)
	_check(game.music.muted and is_zero_approx(game.music.volume_linear) and game.music_volume_label.text.contains("muted"), "M must mute music and display the muted status in settings")
	game.music_volume_slider.value = 65
	_check(game.music.muted and is_zero_approx(game.music.volume_linear) and is_equal_approx(game.music.volume_percent, 65), "Changing a muted music slider must retain mute while choosing its restored level")
	_key(game, KEY_M)
	_check(not game.music.muted and is_equal_approx(game.music.volume_linear, .65) and is_equal_approx(game.voice.volume_linear, .13), "Unmuting must restore the chosen music level and leave voices independent")
	_check(is_equal_approx(game.sfx.volume_percent, 38), "Music mute and other volume sliders must not alter sound effects")
	game.voice_volume_slider.value = 0
	_check(is_zero_approx(game.voice.volume_linear) and game.voice_volume_label.text == "0%" and game.music.playing, "Zero voice volume must silence voices without stopping music")
	game.music_volume_slider.value = 0
	_check(is_zero_approx(game.music.volume_linear) and game.music_button.text == "MUSIC OFF", "Zero music volume must silence music and show OFF in Settings")
	game.music_volume_slider.value = 100
	game.voice_volume_slider.value = 100
	_check(is_equal_approx(game.music.volume_db, 0) and is_equal_approx(game.voice.volume_db, 0), "Both channels must be independently adjustable to full volume")
	_check(game.music.get_stream_playback() == playback, "Volume and mute changes must preserve uninterrupted soundtrack playback")
	game.music.set_volume_percent(-4)
	game.voice.set_volume_percent(120)
	_check(is_zero_approx(game.music.volume_percent) and is_equal_approx(game.voice.volume_percent, 100), "Volume APIs must clamp values to 0–100")
	game.sfx.set_volume_percent(-1)
	_check(is_zero_approx(game.sfx.volume_percent), "Sound effects volume must clamp below zero")
	game.sfx.set_volume_percent(101)
	_check(is_equal_approx(game.sfx.volume_percent, 100), "Sound effects volume must clamp above 100")
	game.sfx.set_volume_percent(38)
	game.music_volume_slider.value = 35
	game.voice_volume_slider.value = 60
	# Exercise actual GUI pointer and keyboard delivery, beyond signal callbacks.
	await process_frame
	var slider: HSlider = game.music_volume_slider
	var rect := slider.get_global_rect()
	var point := rect.position + Vector2(rect.size.x * .75, rect.size.y * .5)
	for pressed: bool in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = point
		mouse.global_position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
	await process_frame
	_check(slider.value > 65 and slider.value < 85 and is_equal_approx(game.music.volume_percent, slider.value), "Pointer input must operate the music slider")
	slider.grab_focus()
	var before: float = slider.value
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	root.push_input(arrow, true)
	await process_frame
	_check(slider.value > before, "Focused sliders must support keyboard adjustment")
	_key(game, KEY_ESCAPE)
	_check(not game._audio_open and game.overlay == title and title.visible and not game.started, "Escape must restore the original deployment screen")
	game._start_match()
	await _test_audio_pause(game)
	game.message_timer = 0
	game.last_message = game.world.message
	game._process(.2)
	_check(game.status_label.text.is_empty(), "Expired battlefield status must not display key-binding help")
	game._show_audio_settings()
	_check(game.paused and game._audio_open, "Opening settings during a running match must pause its simulation")
	var elapsed: float = game.world.elapsed
	game._process(.5)
	_check(is_equal_approx(game.world.elapsed, elapsed), "The simulation must remain frozen while audio settings are open")
	game._close_audio_settings()
	_check(not game.paused and not is_instance_valid(game.overlay), "Closing settings must restore a previously running match")
	game.paused = true
	game._show_audio_settings()
	game._close_audio_settings()
	_check(game.paused, "Closing settings must preserve a pre-existing simulation pause")
	game.music.set_volume_percent(42)
	game.voice.set_volume_percent(24)
	game.sfx.set_volume_percent(63)
	game.music.toggle_mute()
	game._show_audio_settings()
	game._restart()
	_check(not game._audio_open and not game.paused and not is_instance_valid(game.overlay), "Restart from settings must clear modal state and begin the new match")
	_check(game.music.muted and is_equal_approx(game.music.volume_percent, 42) and is_equal_approx(game.voice.volume_percent, 24), "Restart must preserve session volumes and music mute")
	_check(is_equal_approx(game.sfx.volume_percent, 63), "Restart must preserve the sound effects level")
	game._toggle_music()
	_check(is_equal_approx(game.music.volume_linear, .42), "Music toggle after restart must restore the chosen level")
	game.world.match_state = "victory"
	game._show_end()
	var results: Control = game.overlay
	game._show_audio_settings()
	game._close_audio_settings()
	_check(game.overlay == results and results.visible and game.world.match_state == "victory", "Audio settings must preserve the results screen and match outcome")
	for size: Vector2i in [Vector2i(1366, 864), Vector2i(1100, 720)]:
		root.size = size
		await process_frame
		game._layout()
		game._show_audio_settings()
		await process_frame
		await process_frame
		var viewport: Rect2 = game.get_viewport_rect()
		var panel: Control = game.music_volume_slider.get_parent().get_parent().get_parent().get_parent()
		_check(viewport.encloses(panel.get_global_rect()), "Audio panel must fit the viewport at %s" % size)
		var scroll: Control = game.audio_button.get_parent().get_parent().get_parent()
		_check(game.audio_button.get_global_rect().end.x <= scroll.get_global_rect().end.x + 1, "Sidebar audio controls must not clip horizontally at %s" % size)
		_check(game.music_volume_slider.size.x >= 230 and game.voice_volume_slider.size.x >= 230 and game.sfx_volume_slider.size.x >= 230, "All three audio sliders must retain usable width at %s" % size)
		game.settings_controls_tab.pressed.emit()
		await process_frame
		await process_frame
		var controls_panel: Control = game.settings_controls.get_parent().get_parent().get_parent()
		_check(viewport.encloses(controls_panel.get_global_rect()), "Controls panel must fit the viewport at %s" % size)
		for label: Node in game.settings_controls.find_children("*", "Label", true, false):
			_check(controls_panel.get_global_rect().encloses(label.get_global_rect()), "Fixed control labels must fit their panel at %s" % size)
		game._close_audio_settings()
		_check(game.overlay.size == game.get_viewport_rect().size, "Closing settings must resize the restored screen to the current viewport at %s" % size)
	playback = null
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d audio settings integration checks" % checks)
	else:
		push_error("FAIL: %d of %d audio settings checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
