extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
const AUDIO = preload("res://scripts/weapon_audio.gd")
const PROJ = preload("res://scripts/projection.gd")

class ViewStub extends RefCounted:
	var viewport_size := Vector2(1000, 700)
	var camera_pos := Vector2.ZERO
	func world_to_screen(point: Vector2) -> Vector2:
		return PROJ.project(point) - camera_pos

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _wait_real(seconds: float) -> void:
	var deadline: int = Time.get_ticks_usec() + int(seconds * 1000000)
	while Time.get_ticks_usec() < deadline:
		await process_frame

func _test_pause_and_busy_pool(audio: Variant, shooter: Dictionary, target: Vector2) -> void:
	audio.cancel()
	var details: Dictionary = {"owner": 0, "pos": shooter.pos}
	_check(audio.on_player_event("construction_started", details), "Construction must start a finite effect on an idle channel")
	var player: AudioStreamPlayer = audio._players[0]
	var stream: AudioStream = player.stream
	var playback: AudioStreamPlayback = player.get_stream_playback()
	await _wait_real(.04)
	audio.set_paused(true)
	_check(player.stream_paused and player.has_stream_playback() and is_same(player.stream, stream) and is_same(player.get_stream_playback(), playback), "Pause must suspend the active effect without replacing its stream or decoder")
	_check(not audio.on_weapon_fired(shooter, target) and not audio.on_player_event("building_constructed", details), "Paused effects must reject both new weapon and construction events")
	# Let the audio thread consume its already queued mix buffer before comparing.
	await _wait_real(.12)
	var position: float = playback.get_playback_position()
	await _wait_real(.08)
	_check(is_equal_approx(playback.get_playback_position(), position), "An existing effect must retain its playback position while paused")
	audio.set_volume_percent(23)
	_check(player.stream_paused and is_equal_approx(player.volume_linear, .23) and is_same(player.get_stream_playback(), playback), "Volume adjustments must apply to paused effects without replacing playback")
	audio.set_paused(false)
	await _wait_real(.12)
	_check(not player.stream_paused and player.playing and is_same(player.stream, stream) and is_same(player.get_stream_playback(), playback) and player.get_playback_position() > position, "Resume must continue the same effect and decoder from its held position")
	audio.set_paused(true)
	audio.cancel()
	var cleared: bool = not audio._paused
	for channel: AudioStreamPlayer in audio._players:
		cleared = cleared and not channel.stream_paused and not channel.playing and channel.stream == null
	_check(cleared, "Intentional cancellation must stop all effects and clear paused channel state for a fresh match")
	audio.set_volume_percent(50)
	var accepted := 0
	for index: int in range(AUDIO.MAX_VOICES):
		if audio.on_player_event("construction_started" if index % 2 == 0 else "building_constructed", details):
			accepted += 1
	_check(accepted == AUDIO.MAX_VOICES, "Concurrent construction events must fill idle channels without stealing any existing effect")
	var streams: Array[AudioStream] = []
	var playbacks: Array[AudioStreamPlayback] = []
	for channel: AudioStreamPlayer in audio._players:
		streams.append(channel.stream)
		playbacks.append(channel.get_stream_playback())
	_check(not audio.on_player_event("construction_started", details) and not audio.on_player_event("building_constructed", details) and not audio.on_weapon_fired(shooter, target), "A saturated effects pool must drop excess construction and shots")
	var unchanged := true
	for index: int in range(AUDIO.MAX_VOICES):
		var channel: AudioStreamPlayer = audio._players[index]
		unchanged = unchanged and channel.playing and is_same(channel.stream, streams[index]) and is_same(channel.get_stream_playback(), playbacks[index])
	_check(unchanged, "New events must never restart or replace effects that are already playing")
	audio.cancel()

func _run() -> void:
	for role: String in ["infantry", "tank"]:
		for variant: int in range(1, 4):
			var clip: AudioStream = load("res://assets/sfx/laser_%s_%d.ogg" % [role, variant])
			_check(clip is AudioStreamOggVorbis and clip.get_length() > .05 and clip.get_length() < 2, "%s laser variant %d must be a short compressed firing effect" % [role, variant])
	var world: Variant = SIM.new()
	world.ai_enabled = false
	var shooter: Dictionary = world._spawn("infantry", 0, Vector2(900, 1200))
	var enemy: Dictionary = world._spawn("infantry", 1, Vector2(1000, 1200))
	shooter.order = "hold"
	enemy.order = "hold"
	enemy.cooldown_left = 999.0
	world._rebuild_buckets()
	world._update_fog()
	var events: Array = []
	world.weapon_fired.connect(func(unit: Dictionary, target: Vector2) -> void: events.append({"id": unit.id, "target": target}))
	var before_hp: float = enemy.hp
	world.tick(.05)
	_check(events.size() == 1 and int(events[0].id) == int(shooter.id) and Vector2(events[0].target) == Vector2(enemy.pos), "An actual simulated shot must emit exactly one firing event with its source and target")
	_check(is_equal_approx(enemy.hp, before_hp - maxf(1.0, float(world.entity_spec(shooter).damage) - float(world.entity_spec(enemy).armor))), "The firing notification must preserve immediate faction damage after target armor")
	world.tick(.70)
	_check(events.size() == 1, "Weapon cooldown and lingering tracers must not emit repeated firing sounds")
	world.tick(.15)
	_check(events.size() == 2, "The next cooldown-complete shot must emit its own event")
	world.match_state = "victory"
	world.tick(2)
	_check(events.size() == 2, "Stopped match simulation must not emit firing events")
	world.match_state = "playing"
	var view := ViewStub.new()
	view.camera_pos = PROJ.project(shooter.pos) - Vector2(500, 350)
	var enabled: Array = [true]
	var audio: Variant = AUDIO.new()
	audio.world = world
	audio.view = view
	audio.can_play = func() -> bool: return bool(enabled[0])
	root.add_child(audio)
	var played: Array = []
	audio.shot_played.connect(func(kind: String, path: String) -> void: played.append({"kind": kind, "path": path}))
	_check(is_equal_approx(audio.volume_percent, 50.0) and audio._players.size() == AUDIO.MAX_VOICES, "Sound effects must start at 50 percent with a bounded preallocated voice pool")
	_check(audio.on_weapon_fired(shooter, enemy.pos) and played.size() == 1 and str(played[-1].path).ends_with("laser_infantry_1.ogg"), "A visible on-screen infantry shot must play its infantry laser bank")
	_check(not audio.on_weapon_fired(shooter, enemy.pos) and played.size() == 1, "A dense same-role volley must be coalesced to prevent audio stacking")
	await _wait_real(.04)
	_check(audio.on_weapon_fired(shooter, enemy.pos) and str(played[-1].path).ends_with("laser_infantry_2.ogg"), "A later shot must rotate to the next laser variant")
	audio.cancel()
	var tank: Dictionary = world._spawn("tank", 0, shooter.pos)
	_check(audio.on_weapon_fired(tank, enemy.pos) and str(played[-1].path).ends_with("laser_tank_1.ogg"), "Tank fire must use its distinct heavy laser bank")
	await _test_pause_and_busy_pool(audio, shooter, enemy.pos)
	audio.set_volume_percent(23)
	var correct_volume := true
	for player: AudioStreamPlayer in audio._players:
		correct_volume = correct_volume and is_equal_approx(player.volume_linear, .23)
	_check(correct_volume, "Sound-effects volume changes must apply to every active and idle shot player")
	audio.set_volume_percent(0)
	var before: int = played.size()
	audio.cancel()
	_check(not audio.on_weapon_fired(shooter, enemy.pos) and played.size() == before, "Zero sound-effects volume must suppress playback without queuing stale shots")
	audio.set_volume_percent(200)
	_check(is_equal_approx(audio.volume_percent, 100), "Sound-effects volume must clamp to 100 percent")
	audio.set_volume_percent(-3)
	_check(is_zero_approx(audio.volume_percent), "Sound-effects volume must clamp to zero")
	audio.set_volume_percent(50)
	enabled[0] = false
	_check(not audio.on_weapon_fired(shooter, enemy.pos), "Paused or inactive main-scene state must suppress new firing sounds")
	enabled[0] = true
	view.camera_pos += Vector2(4000, 0)
	_check(not audio.on_weapon_fired(shooter, enemy.pos), "Off-screen shots must not play distant combat audio")
	view.camera_pos -= Vector2(4000, 0)
	world.visible[0].clear()
	_check(not audio.on_weapon_fired(enemy, shooter.pos), "An enemy firing from fog must remain silent even when its target is visible")
	world._update_fog()
	_check(audio.on_weapon_fired(enemy, shooter.pos), "A currently visible on-screen enemy shot must be audible")
	audio.cancel()
	enemy.pos = Vector2(shooter.pos) + Vector2(200, 0)
	world._rebuild_buckets()
	world._update_fog()
	_check(world.is_visible(0, enemy.pos) and audio.on_weapon_fired(enemy, shooter.pos), "A visible Synod enemy beyond close range must play its shot audio normally")
	audio.cancel()
	world.match_state = "defeat"
	_check(not audio.on_weapon_fired(shooter, enemy.pos), "Match results must suppress new shot playback")
	world.match_state = "playing"
	var worker: Dictionary = world._spawn("worker", 0, shooter.pos)
	_check(not audio.on_weapon_fired(worker, enemy.pos), "Unarmed workers must not have firing effects")
	# A rapid barrage of the longer tank clips fills the available voices before
	# the first shot ends, without changing the simulated weapon cadence.
	for index: int in range(AUDIO.MAX_VOICES + 3):
		await _wait_real(.038)
		audio.on_weapon_fired(tank, enemy.pos)
	var active := 0
	for player: AudioStreamPlayer in audio._players:
		if player.playing:
			active += 1
	_check(active == AUDIO.MAX_VOICES and audio.get_child_count() == AUDIO.MAX_VOICES, "Dense overlapping fire must remain within the fixed voice budget")
	_check(not audio.on_weapon_fired(shooter, enemy.pos), "A full sound pool must drop extra audio rather than queue or replace gameplay shots")
	await audio.finish()
	var stopped := true
	for player: AudioStreamPlayer in audio._players:
		stopped = stopped and not player.playing and player.stream == null
	_check(stopped, "Finishing or restarting must stop and release all shot players")
	audio.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: %d weapon audio checks" % checks)
	else:
		push_error("FAIL: %d of %d weapon audio checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
