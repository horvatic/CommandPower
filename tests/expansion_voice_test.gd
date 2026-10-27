extends SceneTree

const DATA = preload("res://scripts/catalog.gd")
const VOICE = preload("res://scripts/unit_voice.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voices/original_hashes.json"))
	_check(hashes.size() == 144, "The approved base voice manifest must cover all 144 recordings")
	for path: String in hashes:
		_check(FileAccess.get_sha256("res://assets/voices/" + path) == str(hashes[path]), "Approved base recording hash must match: " + path)
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voices/expansion_manifest.json"))
	var entries: Dictionary = {}
	for entry: Dictionary in manifest:
		entries[str(entry.path)] = entry
	_check(entries.size() == manifest.size(), "Every expanded acknowledgment must have its own asset path")
	var voice = VOICE.new()
	root.add_child(voice)
	await process_frame
	var heard: Array = []
	voice.acknowledged.connect(func(id: int, action: String, path: String) -> void: heard.append({"id": id, "action": action, "path": path}))
	var expected := 0
	for faction: String in DATA.FACTIONS:
		for kind: String in DATA.UNIT_KINDS:
			if kind in ["worker", "infantry", "tank"]:
				continue
			var spec: Dictionary = DATA.spec(kind, faction)
			var entity: Dictionary = {"id": 1, "kind": kind, "faction": faction, "owner": 0, "completed": true, "hp": spec.hp}
			var entities: Dictionary = {1: entity}
			var actions: Array = ["select", "move", "attack"] if float(spec.damage) > 0.0 else ["select", "move"]
			for action: String in actions:
				for variant: int in range(1, 4):
					var relative: String = "%s/%s_%s_%d.ogg" % [VOICE.FOLDERS[faction], kind, action, variant]
					var path: String = "res://assets/voices/" + relative
					var clip: AudioStream = load(path)
					_check(clip is AudioStreamOggVorbis and clip.get_length() > 0.1 and clip.get_length() < 15.0, "Every new unit requires a valid acknowledgment variant: " + relative)
					var entry: Dictionary = entries.get(relative, {})
					_check(not entry.is_empty() and str(entry.get("unit", "")) == DATA.faction_title(kind, faction), "Acknowledgment metadata must identify the actual faction unit: " + relative)
					if faction == "humans":
						_check(not str(entry.get("text", "")).is_empty(), "Human units retain their spoken dialogue: " + relative)
					else:
						_check(entry.get("text") == null and str(entry.get("synthesis", "")) == "procedural", "Non-Human units use wordless procedural responses: " + relative)
					voice.cancel()
					var before: int = heard.size()
					_check(voice.acknowledge(entities, [1], action), "Owned expanded units must acknowledge accepted " + action + ": " + relative)
					_check(heard.size() == before + 1 and str(heard[-1].path) == path, "Runtime must select and rotate the unit's own acknowledgment bank: " + relative)
					expected += 1
			if float(spec.damage) <= 0.0:
				voice.cancel()
				_check(not voice.acknowledge(entities, [1], "attack"), "Unarmed support units must not acknowledge attacks")
			voice.cancel()
			entity.owner = 1
			_check(not voice.acknowledge(entities, [1], "select"), "Enemy expanded units must never acknowledge player selection")
			# Yield between banks so the mixer retires cancelled test playback handles.
			await create_timer(0.02).timeout
	_check(expected == manifest.size(), "The expansion manifest must cover every supported action exactly once")
	await voice.finish()
	voice.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("%s: %d expansion voice checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
