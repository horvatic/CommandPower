extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
const ANNOUNCER = preload("res://scripts/announcer.gd")
const VOICE = preload("res://scripts/unit_voice.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_production_and_rejections()
	_test_construction()
	_test_damage_and_losses()
	_test_blocked_exit()
	_test_power_and_reset()
	_test_outcomes()
	await _test_ready_speech_handoff()
	if failures == 0:
		print("PASS: %d announcer event checks" % checks)
	else:
		push_error("FAIL: %d of %d announcer event checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _fresh() -> Variant:
	var world: Variant = SIM.new()
	world.ai_enabled = false
	for owner: int in range(2):
		var workers: Array = []
		for entity: Dictionary in world.entities.values():
			if int(entity.owner) == owner and str(entity.kind) == "worker":
				workers.append(entity.id)
		world.order_stop(workers, true)
	return world

func _events(world: Variant) -> Array:
	var events: Array = []
	world.player_event.connect(func(event: String, details: Dictionary) -> void: events.append({"event": event, "details": details}))
	return events

func _find(world: Variant, owner: int, kind: String) -> Dictionary:
	for entity: Dictionary in world.entities.values():
		if int(entity.owner) == owner and str(entity.kind) == kind:
			return entity
	return {}

func _advance(world: Variant, seconds: float) -> void:
	for step: int in range(roundi(seconds / .05)):
		world.tick(.05)

func _count(events: Array, key: String) -> int:
	var result := 0
	for event: Dictionary in events:
		if str(event.event) == key:
			result += 1
	return result

func _test_production_and_rejections() -> void:
	var world: Variant = _fresh()
	var events: Array = _events(world)
	var hq: Dictionary = _find(world, 0, "hq")
	var enemy_hq: Dictionary = _find(world, 1, "hq")
	_check(events.is_empty(), "The starting match must not announce seeded entities")
	_check(world.queue_unit(hq.id, "worker") and _count(events, "production_started") == 1, "Accepted production must announce building units once")
	_check(int(events[0].details.owner) == 0 and int(events[0].details.id) == int(hq.id) and str(events[0].details.kind) == "hq", "Production event details must identify the owned producer")
	_check(not world.queue_unit(hq.id, "tank") and _count(events, "production_started") == 1, "An invalid production class must not announce accepted production")
	world.queue_unit(enemy_hq.id, "worker")
	_check(_count(events, "production_started") == 1, "Enemy production must not leak into player announcements")
	_check(world.cancel_queue(hq.id) and _count(events, "training_cancelled") == 1, "Successful training cancellation must announce once")
	_check(not world.cancel_queue(hq.id) and _count(events, "training_cancelled") == 1, "Empty-queue cancellation must remain silent")
	world.cancel_queue(enemy_hq.id)
	_check(_count(events, "training_cancelled") == 1, "Enemy cancellation must remain silent")
	world.resources[0].essence = 0
	_check(not world.queue_unit(hq.id, "worker") and _count(events, "insufficient_essence") == 1, "Unaffordable valid production must announce insufficient essence")
	world.resources[0].essence = 900
	world.queue_unit(hq.id, "worker")
	_advance(world, 6.1)
	_check(_count(events, "unit_ready") == 1 and hq.queue.is_empty(), "A unit-ready event must follow actual unit creation")
	_advance(world, 1)
	_check(_count(events, "unit_ready") == 1, "Completed production must not repeat its ready announcement")
	var ready: Dictionary = {}
	for event: Dictionary in events:
		if event.event == "unit_ready": ready = event.details
	_check(world.entities.has(int(ready.get("id", -1))) and str(ready.get("kind", "")) == "worker", "Unit-ready details must identify the actual spawned unit")

func _test_construction() -> void:
	var world: Variant = _fresh()
	var events: Array = _events(world)
	_check(not world.start_build(0, "power", Vector2(-50, -50)) and _count(events, "cannot_build_here") == 1, "Invalid placement must announce rejection without claiming construction")
	world.resources[0].essence = 0
	world.start_build(0, "barracks", Vector2(736, 320))
	_check(_count(events, "insufficient_essence") == 1 and _count(events, "cannot_build_here") == 1, "An unaffordable building must emit only the matching rejection reason")
	world.resources[0].essence = 900
	_check(world.start_build(0, "barracks", Vector2(736, 320)) and _count(events, "construction_started") == 1, "Accepted placement must announce construction start")
	var barracks: Dictionary = _find(world, 0, "barracks")
	_check(not barracks.completed and _count(events, "building_constructed") == 0, "Incomplete structures must not announce completion")
	_advance(world, 25)
	_check(barracks.completed and _count(events, "building_constructed") == 1, "Actual worker construction must announce completion once")
	var completed: Dictionary = {}
	for event: Dictionary in events:
		if event.event == "building_constructed": completed = event.details
	_check(int(completed.get("id", -1)) == int(barracks.id) and bool(completed.get("completed", false)) and Vector2(completed.pos) == Vector2(barracks.pos), "Construction audio details must contain the completed building and its location")
	_advance(world, 1)
	_check(_count(events, "building_constructed") == 1, "Finished buildings must not repeat completion announcements")
	var enemy_site: Vector2 = DATA.MAP_SIZE - Vector2(736, 320)
	world.start_build(1, "barracks", enemy_site)
	_advance(world, 25)
	_check(_count(events, "construction_started") == 1 and _count(events, "building_constructed") == 1, "Enemy base construction must never leak into owned-building audio")

func _test_damage_and_losses() -> void:
	var world: Variant = _fresh()
	var events: Array = _events(world)
	var victim: Dictionary = world._spawn("infantry", 0, Vector2(900, 600))
	var enemy: Dictionary = world._spawn("infantry", 1, Vector2(1000, 600))
	world._rebuild_buckets()
	world._update_fog()
	world.order_attack([enemy.id], victim.id)
	var hp: float = victim.hp
	world._combat_unit(enemy, .05)
	_check(victim.hp < hp and _count(events, "unit_under_attack") == 1, "A real hit on an owned mobile unit must announce unit under attack")
	world._combat_unit(enemy, .05)
	_check(_count(events, "unit_under_attack") == 1, "A weapon still cooling down must not emit another damage announcement")
	world._combat_unit(victim, .05)
	_check(_count(events, "unit_under_attack") == 1, "Damage to enemy units must not announce player danger")
	var structure: Dictionary = world._spawn("power", 0, Vector2(1000, 690))
	world._update_fog()
	enemy.cooldown_left = 0
	world.order_attack([enemy.id], structure.id)
	world._combat_unit(enemy, .05)
	_check(_count(events, "building_under_attack") == 1, "A real hit on an owned structure must use building under attack")
	var snapshot: Dictionary = events[-1].details
	structure.pos = Vector2(1050, 690)
	_check(Vector2(snapshot.pos) == Vector2(1000, 690), "Event details must snapshot the event location rather than retaining a mutable entity")
	victim.hp = 0
	structure.hp = 0
	enemy.hp = 0
	world.tick(.05)
	_check(_count(events, "unit_lost") == 1 and _count(events, "building_lost") == 1, "Actual owned removals must distinguish unit and building losses")
	_check(not world.entities.has(victim.id) and not world.entities.has(structure.id), "Loss notifications must correspond to actual entity removal")
	world.tick(.05)
	_check(_count(events, "unit_lost") == 1 and _count(events, "building_lost") == 1, "Losses must not repeat and enemy loss must remain silent")

func _test_blocked_exit() -> void:
	var world: Variant = _fresh()
	var events: Array = _events(world)
	var hq: Dictionary = _find(world, 0, "hq")
	world.queue_unit(hq.id, "worker")
	world.obstacles.append(Rect2(Vector2(hq.pos) - Vector2(180, 180), Vector2(360, 360)))
	world._rebuild_navigation()
	_advance(world, 7)
	_check(_count(events, "exit_blocked") == 1 and _count(events, "unit_ready") == 0, "Blocked production must warn once without claiming a unit spawned")
	_advance(world, 2)
	_check(_count(events, "exit_blocked") == 1, "A blocked queue head must not repeat the exit warning each simulation step")
	world.cancel_queue(hq.id)
	world.queue_unit(hq.id, "worker")
	_advance(world, 7)
	_check(_count(events, "exit_blocked") == 2, "A new completed queue head must be able to announce its own blocked exit")
	world.obstacles.pop_back()
	world._rebuild_navigation()
	world.tick(.05)
	_check(_count(events, "unit_ready") == 1 and hq.queue.is_empty(), "Unblocking the exit must announce only the unit that actually spawns")

func _test_power_and_reset() -> void:
	var world: Variant = _fresh()
	var events: Array = _events(world)
	world.tick(.05)
	_check(_count(events, "low_power") == 0 and _count(events, "power_restored") == 0, "The default match must not announce a false initial power transition")
	world._spawn("factory", 0, Vector2(800, 600))
	_find(world, 0, "power").hp = 0
	world.tick(.05)
	_check(_count(events, "low_power") == 1, "A real supply loss below demand must announce low power")
	world.tick(.05)
	_check(_count(events, "low_power") == 1, "Remaining in low power must not repeat the transition announcement")
	world._spawn("power", 0, Vector2(900, 800))
	world.tick(.05)
	_check(_count(events, "power_restored") == 1, "Restoring sufficient supply must announce the transition once")
	_find(world, 1, "power").hp = 0
	world.tick(.05)
	_check(_count(events, "low_power") == 1 and _count(events, "power_restored") == 1, "Enemy power changes must not leak into player notices")
	events.clear()
	world.reset()
	_check(events.is_empty(), "Reset must seed entities and power state silently")
	world.ai_enabled = false
	world.tick(.05)
	_check(events.is_empty(), "The first post-reset step must not replay earlier power or loss events")

func _test_outcomes() -> void:
	for outcome: String in ["victory", "defeat", "draw"]:
		var world: Variant = _fresh()
		var events: Array = _events(world)
		if outcome != "victory": _find(world, 0, "hq").hp = 0
		if outcome != "defeat": _find(world, 1, "hq").hp = 0
		world.tick(.05)
		_check(world.match_state == outcome and _count(events, outcome) == 1, "The actual %s result must emit its matching announcement" % outcome)
		var count: int = events.size()
		world.tick(.5)
		world.start_build(0, "power", Vector2(736, 320))
		_check(events.size() == count, "Ended matches must not repeat outcomes or announce rejected construction")

func _test_ready_speech_handoff() -> void:
	var world: Variant = _fresh()
	var announcer: Variant = ANNOUNCER.new()
	var voice: Variant = VOICE.new()
	root.add_child(announcer)
	root.add_child(voice)
	announcer.set_process(false)
	announcer.can_start = func() -> bool: return not voice.playing
	voice.can_play = func() -> bool: return not announcer.blocks_unit_voice()
	world.player_event.connect(announcer.on_player_event)
	var announced: Array[String] = []
	announcer.announced.connect(func(event: String, _path: String) -> void:
		announced.append(event)
		_check(not voice.playing, "Simulation event handoff must never overlap a unit recording"))
	var hq: Dictionary = _find(world, 0, "hq")
	var worker: Dictionary = _find(world, 0, "worker")
	world.queue_unit(hq.id, "worker")
	announcer.cancel()
	announced.clear()
	_check(voice.acknowledge(world.entities, [worker.id], "select"), "The real-production speech fixture must begin with an active unit recording")
	voice.seek(.15)
	var stream: AudioStream = voice.stream
	var position: float = voice.get_playback_position()
	var entities_before: int = world.entities.size()
	hq.queue[0].remaining = 0
	world._produce(hq, .05)
	_check(world.entities.size() == entities_before + 1 and hq.queue.is_empty(), "Ready-channel handoff must be triggered by actual unit creation")
	_check(voice.playing and voice.stream == stream and is_equal_approx(voice.get_playback_position(), position), "Unit-ready delivery must preserve the playing unit clip and position")
	_check(announced.is_empty() and not announcer.playing and announcer._pending.size() == 1 and announcer._pending[0].event == "unit_ready", "Simulation unit-ready notifications must queue until the shared speech channel becomes free")
	announcer._process(0)
	_check(not announcer.playing and voice.playing, "Polling a simulation-driven announcement must not interrupt the current unit clip")
	voice.stop()
	announcer._process(0)
	_check(announced == ["unit_ready"] and announcer.playing, "Unit-ready must play after unit speech completes")
	stream = announcer.stream
	position = announcer.get_playback_position()
	world._player_notice(0, "unit_under_attack", worker)
	world._player_notice(0, "unit_lost", worker)
	_check(announcer.playing and announcer.stream == stream and is_equal_approx(announcer.get_playback_position(), position) and announced == ["unit_ready"], "Real simulation warnings must preserve the active ready announcement")
	announcer.stop()
	announcer._on_finished()
	_check(announced[-1] == "unit_lost", "Queued simulation warnings must retain priority after the active recording finishes")
	await announcer.finish()
	await voice.finish()
	announcer.queue_free()
	voice.queue_free()
	await process_frame
