extends SceneTree

const SCENE = preload("res://scenes/main.tscn")
var failures := 0
var checks := 0
var heard: Array[String] = []
var built_sounds: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _find(game: Variant, kind: String) -> Dictionary:
	for entity: Dictionary in game.world.entities.values():
		if int(entity.owner) == 0 and str(entity.kind) == kind:
			return entity
	return {}

func _complete_announcement(game: Variant) -> void:
	# Deterministic equivalent of the audio backend completing a recording.
	game.announcer.stop()
	game.announcer._on_finished()

func _test_unit_ready_preserves_speech(game: Variant) -> void:
	game._restart()
	game.world.ai_enabled = false
	var worker: Dictionary = _find(game, "worker")
	var hq: Dictionary = _find(game, "hq")
	_check(game.world.queue_unit(hq.id, "worker"), "The speech regression fixture must use an actual production order")
	_complete_announcement(game)
	game.announcer.cancel()
	game.voice.acknowledge(game.world.entities, [worker.id], "move")
	game.voice.seek(.15)
	var stream: AudioStream = game.voice.stream
	var position: float = game.voice.get_playback_position()
	var entity_count: int = game.world.entities.size()
	var before: int = heard.size()
	hq.queue[0].remaining = 0
	game.world._produce(hq, .05)
	_check(game.world.entities.size() == entity_count + 1 and hq.queue.is_empty(), "Production completion must create a real unit")
	_check(game.voice.playing and game.voice.stream == stream and is_equal_approx(game.voice.get_playback_position(), position), "Actual unit creation must preserve the active unit recording and playback position")
	_check(heard.size() == before and not game.announcer.playing and game.announcer._pending.size() == 1 and game.announcer._pending[0].event == "unit_ready", "The actual unit-ready event must wait behind unit speech")
	game.voice.stop()
	game.announcer._process(0)
	_check(heard.size() == before + 1 and heard[-1] == "unit_ready" and not game.voice.playing, "Unit-ready playback may begin only after unit speech completes")
	game.announcer.cancel()
	game.voice.cancel()
	game.voice.acknowledge(game.world.entities, [worker.id], "select")
	stream = game.voice.stream
	position = game.voice.get_playback_position()
	game.world.match_state = "defeat"
	_check(game.announcer.on_player_event("defeat", {"owner": 0}), "A final result must be accepted while a unit speaks")
	_check(game.voice.playing and game.voice.stream == stream and is_equal_approx(game.voice.get_playback_position(), position) and not game.announcer.playing, "Match results must also wait for active unit recordings")
	game.announcer._clock += 100
	game.voice.stop()
	game.announcer._process(0)
	_check(game.announcer.playing and heard[-1] == "defeat" and not game.voice.playing, "Delayed results must remain queued until unit speech finishes")

func _run() -> void:
	root.size = Vector2i(1366, 864)
	var game: Variant = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.announcer.set_process(false)
	game.world.ai_enabled = false
	for event: String in game.announcer.EVENTS:
		var clip: AudioStream = game.announcer._streams[event]
		_check(clip is AudioStreamOggVorbis and clip.get_length() > .1 and clip.get_length() < 6, "%s must have a complete, compressed announcer recording" % event)
	game.announcer.announced.connect(func(event: String, _path: String) -> void:
		heard.append(event)
		_check(not game.voice.playing, "Announcer playback must never overlap an active unit recording"))
	game.sfx.construction_played.connect(func(event: String, _path: String) -> void: built_sounds.append(event))
	_check(not game.announcer.playing and heard.is_empty(), "Deployment must not start unsolicited event announcements")
	game._start_match()
	var worker: Dictionary = _find(game, "worker")
	game.voice.acknowledge(game.world.entities, [worker.id], "select")
	_check(game.voice.playing, "A selected unit may speak before a notification")
	game.voice.seek(.15)
	var unit_stream: AudioStream = game.voice.stream
	var unit_position: float = game.voice.get_playback_position()
	_check(game.announcer.on_player_event("production_started", {"owner": 0}), "A player production action must accept its announcement")
	_check(heard.is_empty() and game.voice.playing and not game.announcer.playing and game.announcer._pending.size() == 1, "Notifications must queue behind active unit speech")
	_check(game.voice.stream == unit_stream and is_equal_approx(game.voice.get_playback_position(), unit_position), "Queued announcements must preserve the active unit stream and playback position")
	_check(not game.voice.acknowledge(game.world.entities, [worker.id], "move"), "Pending announcements must block additional unit acknowledgments")
	game.announcer._process(0)
	_check(not game.announcer.playing and game.voice.playing, "Queue polling must respect the occupied speech channel")
	_check(not game.announcer.on_player_event("production_started", {"owner": 0}), "Repeated queue clicks must not repeat the same announcement immediately")
	_check(not game.announcer.on_player_event("unit_ready", {"owner": 1}), "Enemy production notifications must never be announced")
	_check(not game.announcer.on_player_event("unknown_event", {"owner": 0}), "Unknown events must remain silent")
	# Let a real clip finish so queue handoff is checked alongside deterministic completions.
	var deadline: int = Time.get_ticks_usec() + int((unit_stream.get_length() + 1.0) * 1000000)
	while game.voice.playing and Time.get_ticks_usec() < deadline:
		await create_timer(.02).timeout
	_check(not game.voice.playing and game.voice.stream == unit_stream, "Unit speech must reach its natural end before the notification starts")
	game.announcer._process(0)
	_check(heard == ["production_started"] and game.announcer.playing, "The queued announcement must start once unit speech finishes")
	_check(not game.voice.acknowledge(game.world.entities, [worker.id], "select"), "Unit acknowledgments must wait while an announcement plays")
	var announcement_stream: AudioStream = game.announcer.stream
	game.announcer.seek(.15)
	var announcement_position: float = game.announcer.get_playback_position()
	game.announcer.on_player_event("unit_ready", {"owner": 0})
	game.announcer.on_player_event("construction_started", {"owner": 0})
	game.announcer.on_player_event("training_cancelled", {"owner": 0})
	game.announcer.on_player_event("cannot_build_here", {"owner": 0})
	_check(game.announcer._pending.size() == 4, "The announcement queue must have a small, bounded capacity")
	_check(not game.announcer.on_player_event("insufficient_essence", {"owner": 0}) and game.announcer._pending.size() == 4, "A full queue must drop redundant-priority routine chatter")
	_check(game.announcer.on_player_event("unit_under_attack", {"owner": 0}) and heard[-1] == "production_started", "Attack warnings must queue without interrupting routine speech")
	_check(not game.announcer.on_player_event("unit_under_attack", {"owner": 0}), "Continuous fire must coalesce unit-under-attack warnings")
	_check(game.announcer.on_player_event("unit_lost", {"owner": 0}) and heard[-1] == "production_started", "A loss warning must wait for the current announcement to finish")
	_check(game.announcer.playing and game.announcer.stream == announcement_stream and is_equal_approx(game.announcer.get_playback_position(), announcement_position), "Higher-priority warnings must preserve the active announcement stream and playback position")
	_check(not game.announcer.on_player_event("unit_lost", {"owner": 0}), "Rapid losses must not create a chorus of repeated loss lines")
	_complete_announcement(game)
	_check(heard[-1] == "unit_lost", "The highest-priority pending warning must play after natural completion")
	_complete_announcement(game)
	_check(heard[-1] == "unit_under_attack", "Attack warnings must remain ahead of queued routine notifications")
	_complete_announcement(game)
	_check(heard[-1] == "unit_ready", "Routine notifications must resume after higher-priority warnings finish")
	game.announcer.cancel()
	game.announcer.on_player_event("production_started", {"owner": 0})
	game.announcer.on_player_event("unit_ready", {"owner": 0})
	game.paused = true
	var clock: float = game.announcer._clock
	game.announcer._process(5)
	_check(game.announcer.stream_paused and is_equal_approx(game.announcer._clock, clock), "Pause must freeze current announcer playback and queued notification age")
	_check(not game.announcer.on_player_event("unit_lost", {"owner": 0}) and game.announcer._pending.size() == 1, "Paused events must not add new queued warnings")
	game.paused = false
	game.announcer._process(0)
	_check(not game.announcer.stream_paused, "Resuming must restore announcer playback")
	game.announcer._clock += 9
	game.announcer.stop()
	game.announcer._on_finished()
	_check(game.announcer._pending.is_empty() and not game.announcer.blocks_unit_voice(), "Old routine notifications must expire instead of playing late")
	game.announcer.cancel()
	game.announcer.on_player_event("production_started", {"owner": 0})
	game.announcer.on_player_event("unit_ready", {"owner": 0})
	announcement_stream = game.announcer.stream
	game.announcer.seek(.15)
	announcement_position = game.announcer.get_playback_position()
	game.world.match_state = "victory"
	_check(game.announcer.on_player_event("victory", {"owner": 0}) and heard[-1] == "production_started", "The final-state announcement must queue after the simulation ends without interrupting active speech")
	_check(game.announcer.playing and game.announcer.stream == announcement_stream and is_equal_approx(game.announcer.get_playback_position(), announcement_position), "Match results must preserve active announcement playback")
	_check(game.announcer._pending.size() == 1 and game.announcer._pending[0].event == "victory" and not game.announcer.on_player_event("unit_lost", {"owner": 0}), "Match results must replace pending routine chatter and suppress stale combat events")
	game.announcer._clock += 100
	_complete_announcement(game)
	_check(heard[-1] == "victory" and game.announcer.playing and game.announcer._pending.is_empty(), "A queued result must survive notification expiry and play after active speech finishes")
	_check(not game.announcer.on_player_event("victory", {"owner": 0}), "A queued or active match result must not repeat")
	game._restart()
	_check(not game.announcer.playing and game.announcer._pending.is_empty(), "Restart must clear current and queued announcements")
	game._show_audio_settings()
	game.voice_volume_slider.value = 26
	_check(is_equal_approx(game.voice.volume_linear, .26) and is_equal_approx(game.announcer.volume_linear, .26), "The existing voice slider must control unit and announcer volume together")
	_check(is_equal_approx(game.sfx.volume_percent, 50) and is_equal_approx(game.music.volume_db, -14), "Voice volume must leave effects and music unchanged")
	game._close_audio_settings()
	game.announcer.on_player_event("unit_ready", {"owner": 0})
	game.voice.set_volume_percent(0)
	_check(is_zero_approx(game.announcer.volume_linear) and not game.announcer.playing and game.announcer._pending.is_empty(), "Zero voice volume must silence and clear event announcements")
	_check(not game.announcer.on_player_event("unit_ready", {"owner": 0}), "Muted announcements must not build an inaudible backlog")
	game.voice.set_volume_percent(44)
	game._restart()
	_check(is_equal_approx(game.announcer.volume_percent, 44), "Announcer volume must survive match restart with the unit voice setting")
	var site := Vector2(736, 320)
	game.camera_pos = game.PROJ.project(site) - game.battlefield_size / 2
	game._clamp_camera()
	game.view.camera_pos = game.camera_pos
	game.view.zoom_level = game.zoom_level
	game.sfx.cancel()
	var before: int = built_sounds.size()
	_check(game.world.start_build(0, "barracks", site), "A valid owned construction request must still use the normal simulation API")
	_check(built_sounds.size() == before + 1 and built_sounds[-1] == "construction_started", "Accepted, on-screen construction must play its construction effect")
	_check(not game.world.start_build(0, "barracks", site) and built_sounds.size() == before + 1, "A rejected overlapping placement must not replay construction effects")
	_check(not game.sfx.on_player_event("construction_started", {"owner": 1, "pos": site}), "Enemy construction must not reveal itself through audio")
	_check(not game.sfx.on_player_event("construction_started", {"owner": 0, "pos": Vector2(2600, 1700)}), "Off-screen construction must not play local sound effects")
	var building: Dictionary = _find(game, "barracks")
	var builder: Dictionary = game.world.entities[int(building.builder)]
	builder.pos = site + Vector2(-62, 0)
	building.build_progress = .9999
	game.world._construct(building, .05)
	_check(bool(building.completed) and built_sounds.size() == before + 2 and built_sounds[-1] == "building_constructed", "Actual construction completion must play a distinct completion effect")
	game.paused = true
	_check(not game.sfx.on_player_event("construction_started", {"owner": 0, "pos": site}), "Paused construction audio requests must stay silent")
	game.paused = false
	game.sfx.set_volume_percent(0)
	_check(not game.sfx.on_player_event("construction_started", {"owner": 0, "pos": site}), "The sound effects slider must also silence construction sounds")
	_test_unit_ready_preserves_speech(game)
	await game.announcer.finish()
	await game.sfx.finish()
	await game.voice.finish()
	await game.music.finish()
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d announcer integration checks" % checks)
	else:
		push_error("FAIL: %d of %d announcer checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
