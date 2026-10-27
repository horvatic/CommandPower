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

func _music_key(game: Variant, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	event.echo = echo
	game._unhandled_input(event)

func _run() -> void:
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.ai_enabled = false
	_check(not game.started and game.music.playing, "Music must autoplay on the deployment screen")
	_check(game.music.stream is AudioStreamOggVorbis and game.music.stream.get_length() >= 300.0, "The bundled soundtrack must load as a compressed track lasting at least five minutes")
	_check(game.music.stream.loop, "Background music must loop")
	_check(game.music.volume_db < -6.0 and not game.music.muted, "Music must start at a background listening level")
	var playback: AudioStreamPlayback = game.music.get_stream_playback()
	_music_key(game)
	_check(game.music.muted and is_zero_approx(game.music.volume_linear), "M must mute music while the deployment screen is open")
	game._show_audio_settings()
	_check(game.music_button.text == "MUSIC OFF" and game.music_button.tooltip_text.contains("Unmute"), "Settings must display the muted state and available action")
	game._close_audio_settings()
	_music_key(game, true)
	_check(game.music.muted, "Held M must not repeatedly toggle music")
	game._start_match()
	game._toggle_pause()
	_check(game.paused and game.music.playing and game.music.muted, "Simulation pause must preserve music playback and mute state")
	game._restart()
	_check(game.music.muted and game.music.playing and game.music.get_stream_playback() == playback, "Restart must preserve mute and uninterrupted playback")
	game._show_audio_settings()
	game.music_button.pressed.emit()
	_check(not game.music.muted and game.music.volume_db < -6.0 and game.music.volume_db > -60.0, "The Settings control must restore background music")
	_check(game.music_button.text == "MUSIC ON" and game.music_button.tooltip_text.contains("Mute"), "Settings must display the unmuted state")
	game._close_audio_settings()
	game.world.match_state = "victory"
	game._show_end()
	_music_key(game)
	_check(game.music.muted and game.music.playing, "Music controls must remain available after a match ends")
	game.music.seek(game.music.stream.get_length() - 0.2)
	await create_timer(0.05).timeout
	_check(game.music.get_playback_position() > game.music.stream.get_length() - 1.0, "Music playback must seek to the track ending for the loop check")
	await create_timer(0.6).timeout
	_check(game.music.playing and game.music.get_playback_position() < 2.0, "Music must wrap to the beginning without stopping")
	playback = null
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d music integration checks" % checks)
	else:
		push_error("FAIL: %d of %d music checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
