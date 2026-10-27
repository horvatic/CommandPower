extends AudioStreamPlayer

const TRACK = preload("res://assets/music/iron_horizon.ogg")
const BACKGROUND_VOLUME_DB := -14.0

var muted := false
var volume_percent: float = db_to_linear(BACKGROUND_VOLUME_DB) * 100.0

func _ready() -> void:
	name = "Music"
	stream = TRACK
	stream.loop = true
	_apply_volume()
	play()

func toggle_mute() -> void:
	muted = not muted
	_apply_volume()

func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	_apply_volume()

func _apply_volume() -> void:
	volume_linear = 0.0 if muted else volume_percent / 100.0

func _exit_tree() -> void:
	stop()
	stream = null

func finish() -> void:
	var playback_ref: WeakRef = weakref(get_stream_playback()) if has_stream_playback() else null
	stop()
	stream = null
	# Decoder release runs on the audio thread; wait for it before quitting.
	for attempt: int in range(50):
		if playback_ref == null or playback_ref.get_ref() == null:
			break
		await get_tree().create_timer(0.02).timeout
