extends AudioStreamPlayer

signal announced(event: String, clip_path: String)

const EVENTS := ["production_started", "unit_under_attack", "building_under_attack", "unit_lost", "building_constructed", "construction_started", "unit_ready", "building_lost", "insufficient_essence", "low_power", "power_restored", "training_cancelled", "cannot_build_here", "exit_blocked", "victory", "defeat", "draw"]
const TERMINAL := ["victory", "defeat", "draw"]
const MAX_PENDING := 4
const PRIORITY := {"unit_under_attack": 50, "building_under_attack": 55, "unit_lost": 65, "building_lost": 75, "low_power": 40, "building_constructed": 30, "unit_ready": 25}

var can_play: Callable
var can_start: Callable
var volume_percent := db_to_linear(-3.0) * 100.0
var _streams: Dictionary = {}
var _pending: Array[Dictionary] = []
var _last_event_at: Dictionary = {}
var _clock := 0.0
var _current_event := ""
var _current_priority := -1
var _terminal := false

func _ready() -> void:
	name = "Announcer"
	max_polyphony = 1
	set_volume_percent(volume_percent)
	for event: String in EVENTS:
		_streams[event] = load("res://assets/announcer/%s.ogg" % event)
	finished.connect(_on_finished)

func set_volume_percent(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	volume_linear = volume_percent / 100.0
	if is_zero_approx(volume_percent):
		cancel()

func _allowed() -> bool:
	return not can_play.is_valid() or bool(can_play.call())

func _can_start() -> bool:
	return not can_start.is_valid() or bool(can_start.call())

func _process(delta: float) -> void:
	var allowed := _allowed()
	stream_paused = not allowed
	if not allowed:
		return
	_clock += delta
	if not playing and not _pending.is_empty():
		_play_next()

func blocks_unit_voice() -> bool:
	return not _current_event.is_empty() or not _pending.is_empty()

func _cooldown(event: String) -> float:
	if event in ["unit_under_attack", "building_under_attack"]:
		return 10.0
	if event in ["unit_lost", "building_lost"]:
		return 3.0
	if event in ["low_power", "power_restored", "exit_blocked"]:
		return 5.0
	return 1.0

func on_player_event(event: String, details: Dictionary = {}) -> bool:
	if not EVENTS.has(event) or int(details.get("owner", 0)) != 0 or not _allowed():
		return false
	if TERMINAL.has(event):
		if _terminal:
			return false
		_terminal = true
		_pending.clear()
		if is_zero_approx(volume_percent):
			return false
		if not playing and _can_start():
			return _play_event(event, 100)
		# Results discard stale queued chatter, but never cut off active speech.
		_pending.append({"event": event, "priority": 100, "expires": INF})
		return true
	if _terminal or is_zero_approx(volume_percent):
		return false
	if _clock - float(_last_event_at.get(event, -100.0)) < _cooldown(event):
		return false
	for item: Dictionary in _pending:
		if str(item.event) == event:
			return false
	var priority: int = int(PRIORITY.get(event, 10))
	if not playing and _pending.is_empty() and _can_start():
		_last_event_at[event] = _clock
		return _play_event(event, priority)
	if _pending.size() >= MAX_PENDING:
		var lowest := -1
		var minimum := priority
		for index: int in range(_pending.size()):
			if int(_pending[index].priority) < minimum:
				minimum = int(_pending[index].priority)
				lowest = index
		if lowest < 0:
			return false
		_pending.remove_at(lowest)
	_pending.append({"event": event, "priority": priority, "expires": _clock + (12.0 if priority >= 50 else 8.0)})
	_last_event_at[event] = _clock
	return true

func _play_event(event: String, priority: int) -> bool:
	if playing or not _can_start():
		return false
	var clip: AudioStream = _streams.get(event)
	if clip == null:
		return false
	stream_paused = false
	stream = clip
	stream.loop = false
	_current_event = event
	_current_priority = priority
	play()
	announced.emit(event, "res://assets/announcer/%s.ogg" % event)
	return true

func _on_finished() -> void:
	_current_event = ""
	_current_priority = -1
	_play_next()

func _play_next() -> void:
	if not _allowed() or playing or not _can_start():
		return
	_pending = _pending.filter(func(item: Dictionary) -> bool: return float(item.expires) > _clock)
	if _pending.is_empty():
		return
	var best := 0
	for index: int in range(1, _pending.size()):
		if int(_pending[index].priority) > int(_pending[best].priority):
			best = index
	var item: Dictionary = _pending.pop_at(best)
	_play_event(str(item.event), int(item.priority))

func cancel() -> void:
	stop()
	stream = null
	stream_paused = false
	_pending.clear()
	_last_event_at.clear()
	_clock = 0.0
	_current_event = ""
	_current_priority = -1
	_terminal = false

func _exit_tree() -> void:
	cancel()

func finish() -> void:
	var playback_ref: WeakRef = weakref(get_stream_playback()) if has_stream_playback() else null
	cancel()
	for attempt: int in range(50):
		if playback_ref == null or playback_ref.get_ref() == null:
			break
		await get_tree().create_timer(0.02).timeout
