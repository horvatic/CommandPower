extends AudioStreamPlayer

signal acknowledged(entity_id: int, action: String, clip_path: String)
signal volume_changed(value: float)

const ART = preload("res://scripts/faction_sprites.gd")
const DATA = preload("res://scripts/catalog.gd")
const FOLDERS := {"humans": "human", "iron_synod": "synod", "kharuun": "kharuun", "heavenly_host": "host", "infernal_legion": "infernal", "veyr": "veyr"}
const ROLES = DATA.UNIT_KINDS
const ACTIONS := ["select", "move", "attack"]
const MIN_INTERVAL_USEC := 250000
const VOICE_VOLUME_DB := -3.0

var _streams: Dictionary = {}
var _next_variant: Dictionary = {}
var _last_started_usec: int = -MIN_INTERVAL_USEC
var _last_action := ""
var volume_percent: float = db_to_linear(VOICE_VOLUME_DB) * 100.0
var can_play: Callable

func _ready() -> void:
	name = "UnitVoice"
	set_volume_percent(volume_percent)
	max_polyphony = 1

func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	volume_linear = volume_percent / 100.0
	volume_changed.emit(volume_percent)

func acknowledge(entities: Dictionary, ids: Array, action: String) -> bool:
	if can_play.is_valid() and not bool(can_play.call()):
		return false
	if not ACTIONS.has(action):
		return false
	var now: int = Time.get_ticks_usec()
	if now - _last_started_usec < MIN_INTERVAL_USEC:
		return false
	# Let every response finish; newer orders still execute without replacing it.
	if playing or stream_paused:
		return false
	for id: int in ids:
		if not entities.has(id):
			continue
		var entity: Dictionary = entities[id]
		var role: String = str(entity.get("kind", ""))
		if int(entity.get("owner", -1)) != 0 or not ROLES.has(role) or not bool(entity.get("completed", false)) or float(entity.get("hp", 0)) <= 0:
			continue
		if action == "attack" and float(DATA.spec(role, ART.style_for(entity)).damage) <= 0.0:
			continue
		var family: String = ART.style_for(entity)
		var key: String = "%s/%s_%s" % [FOLDERS[family], role, action]
		var variant: int = int(_next_variant.get(key, 1))
		var path: String = "res://assets/voices/%s_%d.ogg" % [key, variant]
		if not _streams.has(path):
			_streams[path] = load(path)
		var clip: AudioStream = _streams[path]
		if clip == null:
			return false
		stream = clip
		stream.loop = false
		play()
		_next_variant[key] = variant % 3 + 1
		_last_started_usec = now
		_last_action = action
		acknowledged.emit(id, action, path)
		return true
	return false

func cancel() -> void:
	stop()
	stream = null
	stream_paused = false
	_last_started_usec = -MIN_INTERVAL_USEC
	_last_action = ""

func _exit_tree() -> void:
	cancel()

func finish() -> void:
	var playback_ref: WeakRef = weakref(get_stream_playback()) if has_stream_playback() else null
	cancel()
	for attempt: int in range(50):
		if playback_ref == null or playback_ref.get_ref() == null:
			break
		await get_tree().create_timer(0.02).timeout
