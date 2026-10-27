extends SceneTree

const THEMES := {"synod": "cybernetic resonance", "kharuun": "living grove", "host": "celestial choir", "infernal": "abyssal growl", "veyr": "crystal resonance"}
const REVISION := "wordless-factions-2026-10-26"
var checks := 0
var failures := 0

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var revision: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voices/faction_theme_revision.json"))
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/voices/manifest.json"))
	_check(str(revision.revision) == REVISION and revision.themes == THEMES, "The faction revision must define five distinct wordless sound themes")
	_check(revision.preserved_hashes.size() == 276 and revision.changed_hashes.size() == 804 and revision.previous_hashes.size() == 804 and revision.current_nonhuman_hashes.size() == 900, "The revision must cover 276 preserved and 804 replaced recordings")
	for path: String in revision.preserved_hashes:
		_check(FileAccess.get_sha256("res://assets/voices/" + path) == str(revision.preserved_hashes[path]), "Human dialogue and original wordless recordings must remain unchanged: " + path)
	for path: String in revision.changed_hashes:
		_check(FileAccess.get_sha256("res://assets/voices/" + path) == str(revision.changed_hashes[path]) and str(revision.changed_hashes[path]) != str(revision.previous_hashes.get(path, "")), "Every former non-Human speech recording must be replaced: " + path)
	var counts: Dictionary = {}
	var roles: Dictionary = {}
	var paths: Dictionary = {}
	var humans := 0
	for entry: Dictionary in manifest:
		var path: String = str(entry.path)
		var family: String = str(entry.family)
		_check(not paths.has(path), "Every acknowledgment must have a unique runtime path: " + path)
		paths[path] = true
		if family == "human":
			humans += 1
			_check(not str(entry.get("text", "")).is_empty() and revision.preserved_hashes.has(path), "Only Human units retain protected spoken dialogue: " + path)
			continue
		counts[family] = int(counts.get(family, 0)) + 1
		if not roles.has(family):
			roles[family] = {}
		roles[family][str(entry.role)] = true
		_check(THEMES.has(family) and str(entry.get("audio_theme", "")) == str(THEMES.get(family, "")), "Every non-Human unit must follow its faction sound theme: " + path)
		_check(entry.get("text") == null and str(entry.get("synthesis", "")) == "procedural" and str(entry.get("voice_revision", "")) == REVISION, "Non-Human responses must be procedural and wordless: " + path)
		_check(not entry.has("voice_model") and not entry.has("voice_speaker") and not entry.has("voice_accent") and not entry.has("voice_register") and not entry.has("pitch_shifts"), "Non-Human cues must not retain speech-cast metadata: " + path)
		_check(FileAccess.get_sha256("res://assets/voices/" + path) == str(revision.current_nonhuman_hashes.get(path, "")), "Every non-Human recording must match the wordless revision: " + path)
		if family == "host" and str(entry.role) == "infantry":
			_check(revision.preserved_hashes.has(path), "Seraph Guard's reference choir must be preserved: " + path)
	_check(humans == 180 and counts.size() == 5 and manifest.size() == 1080, "All six faction acknowledgment banks must remain complete")
	for family: String in THEMES:
		_check(int(counts.get(family, 0)) == 180 and roles.get(family, {}).size() == 21, "Every non-Human faction needs 180 cues across all 21 roles: " + family)
	print("%s: %d wordless faction audio checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
