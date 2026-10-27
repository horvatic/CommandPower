extends Node

signal shot_played(kind: String, clip_path: String)
signal construction_played(event: String, clip_path: String)

const DATA = preload("res://scripts/catalog.gd")
const ROLES := ["infantry", "tank"]
const MAX_VOICES := 12
const MIN_ROLE_INTERVAL_USEC := 35000
const DEFAULT_VOLUME_PERCENT := 50.0

var world = null
var view = null
var can_play: Callable
var volume_percent := DEFAULT_VOLUME_PERCENT
var _paused := false
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_variant: Dictionary = {}
var _last_shot_usec: Dictionary = {}

func _ready() -> void:
	name = "WeaponAudio"
	for role: String in ROLES:
		for variant: int in range(1, 4):
			var path := "res://assets/sfx/laser_%s_%d.ogg" % [role, variant]
			_streams[path] = load(path)
	for event: String in ["construction_start", "construction_complete"]:
		var path := "res://assets/sfx/%s.ogg" % event
		_streams[path] = load(path)
	for index: int in range(MAX_VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_linear = volume_percent / 100.0
		player.max_polyphony = 1
		player.stream_paused = _paused
		add_child(player)
		_players.append(player)

func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	for player: AudioStreamPlayer in _players:
		player.volume_linear = volume_percent / 100.0

func set_paused(value: bool) -> void:
	_paused = value
	for player: AudioStreamPlayer in _players:
		player.stream_paused = value

func on_weapon_fired(shooter: Dictionary, _target_position: Vector2) -> bool:
	if _paused or world == null or view == null or str(world.match_state) != "playing":
		return false
	if can_play.is_valid() and not bool(can_play.call()):
		return false
	var kind: String = str(shooter.get("kind", ""))
	var definition: Dictionary = DATA.spec(kind, str(shooter.get("faction", "")))
	if definition.is_empty() or float(definition.damage) <= 0.0 or float(shooter.get("hp", 0.0)) <= 0.0:
		return false
	var origin: Vector2 = Vector2(shooter.get("pos", Vector2.ZERO))
	# Own units are always rendered. Enemy shots never reveal a hidden source,
	# even if their target is visible on the other side of a fog boundary.
	if int(shooter.get("owner", -1)) != 0 and not world.can_see_entity(0, shooter):
		return false
	if not Rect2(Vector2.ZERO, Vector2(view.viewport_size)).has_point(view.world_to_screen(origin)):
		return false
	if is_zero_approx(volume_percent):
		return false
	var audio_role: String = "tank" if bool(definition.building) or float(definition.radius) >= 15.0 else "infantry"
	var now: int = Time.get_ticks_usec()
	if now - int(_last_shot_usec.get(audio_role, -MIN_ROLE_INTERVAL_USEC)) < MIN_ROLE_INTERVAL_USEC:
		return false
	var player: AudioStreamPlayer = null
	for candidate: AudioStreamPlayer in _players:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		return false
	var variant: int = int(_next_variant.get(audio_role, 1))
	var path := "res://assets/sfx/laser_%s_%d.ogg" % [audio_role, variant]
	var clip: AudioStream = _streams.get(path)
	if clip == null:
		return false
	player.stream = clip
	player.stream.loop = false
	player.play()
	_next_variant[audio_role] = variant % 3 + 1
	_last_shot_usec[audio_role] = now
	shot_played.emit(kind, path)
	return true

func cancel() -> void:
	_paused = false
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream_paused = false
		player.stream = null
	_last_shot_usec.clear()

func on_player_event(event: String, details: Dictionary) -> bool:
	if event not in ["construction_started", "building_constructed"] or int(details.get("owner", -1)) != 0:
		return false
	if _paused or world == null or view == null or str(world.match_state) != "playing" or is_zero_approx(volume_percent):
		return false
	if can_play.is_valid() and not bool(can_play.call()):
		return false
	if not details.has("pos") or not Rect2(Vector2.ZERO, Vector2(view.viewport_size)).has_point(view.world_to_screen(Vector2(details.pos))):
		return false
	var suffix := "construction_start" if event == "construction_started" else "construction_complete"
	var path := "res://assets/sfx/%s.ogg" % suffix
	var clip: AudioStream = _streams.get(path)
	if clip == null:
		return false
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = clip
			player.stream.loop = false
			player.play()
			construction_played.emit(event, path)
			return true
	return false

func _exit_tree() -> void:
	cancel()

func finish() -> void:
	var pending: Array[WeakRef] = []
	for player: AudioStreamPlayer in _players:
		if player.has_stream_playback():
			pending.append(weakref(player.get_stream_playback()))
	cancel()
	for attempt: int in range(50):
		var remaining := false
		for playback: WeakRef in pending:
			if playback.get_ref() != null:
				remaining = true
				break
		if not remaining:
			break
		await get_tree().create_timer(0.02).timeout
