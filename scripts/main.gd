extends Node2D

const DATA = preload("res://scripts/catalog.gd")
const MAPS = preload("res://scripts/skirmish_maps.gd")
const SIM = preload("res://scripts/simulation.gd")
const VIEW = preload("res://scripts/battlefield_view.gd")
const RADAR = preload("res://scripts/minimap.gd")
const POWER_METER = preload("res://scripts/power_meter.gd")
const PROJ = preload("res://scripts/projection.gd")
const ART = preload("res://scripts/faction_sprites.gd")
const SKIN = preload("res://scripts/ui_skin.gd")
const MUSIC = preload("res://scripts/music_player.gd")
const VOICE = preload("res://scripts/unit_voice.gd")
const WEAPON_AUDIO = preload("res://scripts/weapon_audio.gd")
const ANNOUNCER = preload("res://scripts/announcer.gd")
const SIDEBAR := 310.0
const EDGE_SCROLL_MARGIN := 16.0
const INK := Color("d5e3df")
const MUTED := Color("809891")
const ACCENT := Color("6be4c4")

var world = SIM.new()
var view = VIEW.new()
var radar = RADAR.new()
var power_meter = POWER_METER.new()
var music = MUSIC.new()
var voice = VOICE.new()
var sfx = WEAPON_AUDIO.new()
var announcer = ANNOUNCER.new()
var selected: Array = []
var groups: Dictionary = {}
var camera_pos := Vector2.ZERO
var zoom_level := 1.0
var battlefield_size := Vector2.ZERO
var build_kind := ""
var attack_mode := false
var dragging := false
var drag_start := Vector2.ZERO
var middle_drag := false
var _mouse_inside_window := true
var paused := false
var started := false
var ui_timer := 0.0
var message_timer := 0.0
var last_message := ""
var end_shown := false
var overlay: Control
var ui := Control.new()
var field_clip := Control.new()
var sidebar := PanelContainer.new()
var essence_label: Label
var power_label: Label
var selection_label: Label
var selection_detail: Label
var production_label: Label
var production_focus := -1
var queue_label: Label
var status_label: Label
var objective_label: Label
var music_button: Button
var audio_button: Button
var settings_restart_button: Button
var settings_main_menu_button: Button
var settings_done_button: Button
var music_volume_slider: HSlider
var voice_volume_slider: HSlider
var sfx_volume_slider: HSlider
var music_volume_label: Label
var voice_volume_label: Label
var sfx_volume_label: Label
var settings_audio: VBoxContainer
var settings_controls: VBoxContainer
var settings_audio_tab: Button
var settings_controls_tab: Button
var _audio_open := false
var _audio_was_paused := false
var _audio_previous_overlay: Control
var cancel_button: Button
var building_actions: HBoxContainer
var repair_button: Button
var sell_button: Button
var confirm_sell := ConfirmationDialog.new()
var _sell_target := -1
var build_buttons: Dictionary = {}
var unit_buttons: Dictionary = {}
var unit_page: int = 0
var building_page: int = 0
var unit_page_label: Label
var building_page_label: Label
const CATALOG_PAGE_SIZE: int = 6
var confirm_restart := ConfirmationDialog.new()
var confirm_leave := ConfirmationDialog.new()
var menu_screen := "title"
var faction_label: Label
var player_faction_select: OptionButton
var enemy_faction_select: OptionButton
var player_faction_description: Label
var enemy_faction_description: Label
var map_select: OptionButton
var map_description: Label
var player_color_select: OptionButton
var enemy_color_select: OptionButton
var difficulty_select: OptionButton
var difficulty_description: Label
var smoke_frames := 0
var capture_path := ""
var capture_frames := 0
var benchmark := false
var benchmark_units := 0
var benchmark_frames := 0
var benchmark_times: Array[float] = []
var _quitting := false

func _ready() -> void:
	get_window().title = "CommandPower — The Silent Wells"
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_quit)
	add_child(music)
	add_child(voice)
	add_child(sfx)
	add_child(announcer)
	announcer.can_play = func() -> bool: return started and not paused and not _quitting
	announcer.set_volume_percent(voice.volume_percent)
	voice.volume_changed.connect(announcer.set_volume_percent)
	voice.can_play = func() -> bool: return started and not paused and not announcer.blocks_unit_voice() and not _quitting
	announcer.can_start = func() -> bool: return not voice.playing
	sfx.world = world
	sfx.view = view
	sfx.can_play = func() -> bool: return started and not paused and world.match_state == "playing" and not _quitting
	world.weapon_fired.connect(sfx.on_weapon_fired)
	world.player_event.connect(_on_player_event)
	_make_theme()
	_build_ui()
	_layout()
	_home_camera()
	view.world = world
	radar.world = world
	field_clip.add_child(view)
	get_viewport().size_changed.connect(_layout)
	get_window().mouse_entered.connect(func() -> void: _mouse_inside_window = true)
	get_window().mouse_exited.connect(func() -> void: _mouse_inside_window = false)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--smoke":
			smoke_frames = 120
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		if argument == "--benchmark":
			benchmark = true
		if argument.begins_with("--benchmark-units="):
			benchmark_units = maxi(0, argument.trim_prefix("--benchmark-units=").to_int())
	if smoke_frames > 0 or not capture_path.is_empty() or benchmark:
		_start_match()
		if benchmark and benchmark_units > 0:
			_setup_benchmark()
	else:
		_show_title()
	_refresh_ui()

func _make_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", Color("d5d3c5"))
	theme.set_color("font_color", "Button", Color("d5d3c5"))
	theme.set_color("font_hover_color", "Button", Color("fff0ce"))
	theme.set_color("font_disabled_color", "Button", Color("526963"))
	theme.set_constant("h_separation", "BoxContainer", 7)
	theme.set_constant("v_separation", "BoxContainer", 7)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		if state == "focus":
			var focus := StyleBoxFlat.new()
			focus.bg_color = Color.TRANSPARENT
			focus.border_color = Color("c2ad75")
			focus.set_border_width_all(1)
			theme.set_stylebox(state, "Button", focus)
		else:
			theme.set_stylebox(state, "Button", SKIN.plate(state))
	theme.set_stylebox("panel", "PanelContainer", SKIN.plate())
	ui.theme = theme
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

func _label(text: String, font_size: int = 14, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(text: String, callback: Callable, height: float = 32.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _heading(text: String) -> Label:
	return _label(text, 11, Color("c4b476"))

func _build_ui() -> void:
	field_clip.clip_contents = true
	field_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(field_clip)
	ui.add_child(sidebar)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	sidebar.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)
	var faction_row := HBoxContainer.new()
	var faction := VBoxContainer.new()
	faction.add_theme_constant_override("separation", 1)
	faction_label = _label("HUMANS", 17, ACCENT)
	faction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction.add_child(faction_label)
	faction.add_child(_label("FRONTIER COMMAND  //  01", 10, MUTED))
	faction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_row.add_child(faction)
	column.add_child(faction_row)
	objective_label = _label("DESTROY ENEMY COMMAND", 11, Color("d7c78d"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size.y = 34
	column.add_child(objective_label)
	var radar_row := HBoxContainer.new()
	radar_row.add_theme_constant_override("separation", 5)
	radar_row.add_child(power_meter)
	radar.custom_minimum_size = Vector2(240, 144)
	radar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar.navigate.connect(func(point: Vector2) -> void:
		camera_pos = PROJ.project(point, world.map_size) - battlefield_size / zoom_level / 2.0
		_clamp_camera())
	radar_row.add_child(radar)
	column.add_child(radar_row)
	var economy := HBoxContainer.new()
	var currency := VBoxContainer.new()
	currency.add_theme_constant_override("separation", 0)
	currency.add_child(_heading("SPIRITUAL ESSENCE"))
	essence_label = _label("900", 28, Color("dec68b"))
	currency.add_child(essence_label)
	currency.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	economy.add_child(currency)
	var power_column := VBoxContainer.new()
	power_column.add_theme_constant_override("separation", 3)
	power_column.add_child(_heading("POWER"))
	power_label = _label("35 / 120", 15, ACCENT)
	power_label.mouse_filter = Control.MOUSE_FILTER_PASS
	power_column.add_child(power_label)
	economy.add_child(power_column)
	column.add_child(economy)
	column.add_child(HSeparator.new())
	selection_label = _label("FIELD COMMAND", 15)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(selection_label)
	selection_detail = _label("Select units or a structure", 11, MUTED)
	selection_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_detail.custom_minimum_size.y = 32
	column.add_child(selection_detail)
	building_actions = HBoxContainer.new()
	repair_button = _button("REPAIR", _repair_selected, 30)
	sell_button = _button("SELL", _sell_selected, 30)
	for button: Button in [repair_button, sell_button]:
		button.add_theme_font_size_override("font_size", 11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		building_actions.add_child(button)
	building_actions.hide()
	column.add_child(building_actions)
	column.add_child(_catalog_pager(true))
	var buildings := GridContainer.new()
	buildings.columns = 2
	buildings.add_theme_constant_override("h_separation", 5)
	buildings.add_theme_constant_override("v_separation", 5)
	for kind: String in DATA.BUILDING_KINDS:
		if kind == "hq":
			continue
		var button := _catalog_button(kind)
		button.pressed.connect(_choose_build.bind(kind))
		buildings.add_child(button)
		build_buttons[kind] = button
	column.add_child(buildings)
	column.add_child(_catalog_pager(false))
	var troops := GridContainer.new()
	troops.columns = 2
	troops.add_theme_constant_override("h_separation", 5)
	troops.add_theme_constant_override("v_separation", 5)
	for kind: String in DATA.UNIT_KINDS:
		var button := _catalog_button(kind)
		button.pressed.connect(_train.bind(kind))
		troops.add_child(button)
		unit_buttons[kind] = button
	column.add_child(troops)
	queue_label = _label("QUEUE  /  EMPTY", 11, MUTED)
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_label.custom_minimum_size.y = 30
	column.add_child(queue_label)
	cancel_button = _button("CANCEL LAST QUEUED UNIT", _cancel_queue, 28)
	cancel_button.add_theme_font_size_override("font_size", 10)
	column.add_child(cancel_button)
	audio_button = _button("Settings / Pause", _show_audio_settings, 36)
	audio_button.tooltip_text = "Pause and open settings, controls, restart, or main menu"
	column.add_child(audio_button)
	status_label = _label("", 12, Color("e8d7a1"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 45
	column.add_child(status_label)
	confirm_restart.title = "Restart skirmish"
	confirm_restart.dialog_text = "Restart this skirmish from the beginning?"
	confirm_restart.confirmed.connect(_restart)
	ui.add_child(confirm_restart)
	confirm_leave.title = "Leave skirmish"
	confirm_leave.dialog_text = "Leave this match and return to the title screen? Match progress will be lost."
	confirm_leave.confirmed.connect(_show_title)
	ui.add_child(confirm_leave)
	confirm_sell.title = "Sell Command Center"
	confirm_sell.ok_button_text = "Sell and accept defeat"
	confirm_sell.confirmed.connect(_confirm_building_sale)
	confirm_sell.canceled.connect(func() -> void: _sell_target = -1)
	ui.add_child(confirm_sell)

func _catalog_button(kind: String) -> Button:
	var spec: Dictionary = world.spec_for(kind, 0)
	var button := Button.new()
	button.text = world.entity_title(kind, 0) + "\n" + str(spec.cost) + " ESS"
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(130, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.icon = _catalog_icon(kind)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 27)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _catalog_tooltip(kind)
	return button

func _catalog_tooltip(kind: String) -> String:
	var spec: Dictionary = world.spec_for(kind, 0)
	var text: String = "%s — %d essence / %s seconds" % [world.entity_title(kind, 0), spec.cost, spec.time]
	if bool(spec.building):
		text += "\n" + _building_power_text(kind) + " when completed"
	var needed: Array = DATA.requirements(kind, world.faction_for(0)).duplicate()
	if DATA.UNIT_PRODUCERS.has(kind):
		needed.push_front(DATA.UNIT_PRODUCERS[kind])
	if not needed.is_empty():
		var names := PackedStringArray()
		for requirement: String in needed:
			names.append(world.entity_title(requirement, 0))
		text += "\nRequires a completed friendly " + ", ".join(names)
	if not bool(spec.building) or float(spec.damage) > 0.0:
		text += _unit_stats_text(spec)
	if not str(spec.get("role_description", "")).is_empty():
		text += "\n" + str(spec.role_description)
	return text

func _catalog_pager(building: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _heading("CONSTRUCTION" if building else "PRODUCTION")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if building:
		building_page_label = label
	else:
		unit_page_label = label
		production_label = label
	row.add_child(label)
	for direction: int in [-1, 1]:
		var button := _button("<" if direction < 0 else ">", _change_catalog_page.bind(building, direction), 24)
		button.custom_minimum_size.x = 28
		button.tooltip_text = "Previous buildings" if building and direction < 0 else ("Next buildings" if building else ("Previous units" if direction < 0 else "Next units"))
		row.add_child(button)
	return row

func _change_catalog_page(building: bool, direction: int) -> void:
	var count: int = build_buttons.size() if building else unit_buttons.size()
	var pages: int = maxi(1, ceili(float(count) / CATALOG_PAGE_SIZE))
	if building:
		building_page = posmod(building_page + direction, pages)
	else:
		unit_page = posmod(unit_page + direction, pages)
	_refresh_ui()

func _refresh_catalog_pages() -> void:
	for building: bool in [true, false]:
		var buttons: Dictionary = build_buttons if building else unit_buttons
		var page: int = building_page if building else unit_page
		var index: int = 0
		for button: Button in buttons.values():
			button.visible = index / CATALOG_PAGE_SIZE == page
			index += 1
		var label: Label = building_page_label if building else unit_page_label
		label.text = "%s  %d/%d" % ["CONSTRUCTION" if building else "PRODUCTION", page + 1, maxi(1, ceili(float(buttons.size()) / CATALOG_PAGE_SIZE))]

func _unit_stats_text(spec: Dictionary) -> String:
	var text: String = "\n%s HP / %s armor / %s damage / %s s cooldown\n%s range / %s speed" % [spec.hp, spec.armor, spec.damage, spec.cooldown, spec.range, spec.speed]
	for field: String in ["pierce", "splash", "min_range", "heal", "ward", "regen", "lifesteal"]:
		if float(spec.get(field, 0.0)) > 0.0:
			var labels: Dictionary = {"pierce": "Armor piercing", "splash": "Area radius", "min_range": "Minimum range", "heal": "Healing per second", "ward": "Ward armor", "regen": "Regeneration per second", "lifesteal": "Life drain fraction"}
			text += "\n%s: %s" % [labels[field], spec[field]]
	if float(spec.get("slow", 1.0)) < 1.0:
		text += "\nSlows targets to %d%% speed for %s seconds" % [float(spec.slow) * 100.0, spec.slow_time]
	return text

func _building_power_text(kind: String) -> String:
	var spec: Dictionary = world.spec_for(kind, 0)
	var supply: int = int(spec.get("power_supply", DATA.POWER_SUPPLY.get(kind, 0)))
	var demand: int = int(spec.get("power_demand", DATA.POWER_DEMAND.get(kind, 0)))
	return "Supplies %d power" % supply if supply > 0 else "Uses %d power" % demand

func _catalog_icon(kind: String, faction: String = "") -> Texture2D:
	return ART.icon_texture(kind, world.faction_for(0) if faction.is_empty() else faction)

func _layout() -> void:
	var dimensions: Vector2 = get_viewport_rect().size
	ui.size = dimensions
	battlefield_size = Vector2(dimensions.x - SIDEBAR, dimensions.y)
	field_clip.position = Vector2.ZERO
	field_clip.size = battlefield_size
	sidebar.position = Vector2(battlefield_size.x, 0)
	sidebar.size = Vector2(SIDEBAR, dimensions.y)
	view.viewport_size = battlefield_size
	if is_instance_valid(overlay):
		overlay.size = dimensions
	_clamp_camera()

func _start_match() -> void:
	confirm_sell.hide()
	_sell_target = -1
	if _audio_open:
		_close_audio_settings()
	if is_instance_valid(player_faction_select) and is_instance_valid(enemy_faction_select):
		if not world.configure_skirmish(DATA.FACTIONS[player_faction_select.selected], DATA.FACTIONS[enemy_faction_select.selected]):
			return
	if is_instance_valid(difficulty_select):
		_on_difficulty_selected(difficulty_select.selected)
	if is_instance_valid(map_select):
		if not world.configure_map(str(MAPS.MAPS.keys()[map_select.selected])):
			return
	if is_instance_valid(player_color_select) and is_instance_valid(enemy_color_select):
		if not world.configure_colors(SIM.PLAYER_COLORS[player_color_select.selected], SIM.PLAYER_COLORS[enemy_color_select.selected]):
			return
	_clear_menu_selectors()
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	announcer.cancel()
	voice.cancel()
	sfx.cancel()
	world.reset()
	get_window().title = "CommandPower — " + str(MAPS.MAPS[world.map_id].name)
	unit_page = 0
	building_page = 0
	selected.clear()
	groups.clear()
	build_kind = ""
	attack_mode = false
	dragging = false
	middle_drag = false
	end_shown = false
	zoom_level = 1.0
	production_focus = -1
	view.command_markers.clear()
	started = true
	paused = false
	menu_screen = "battle"
	sidebar.show()
	_home_camera()
	_refresh_faction_ui()
	_notify("Train units from the sidebar. Build Barracks for frontline units and a Factory for heavy units.", 10.0)
	_refresh_ui()

func _clear_menu_selectors() -> void:
	map_select = null
	map_description = null
	player_color_select = null
	enemy_color_select = null
	player_faction_select = null
	enemy_faction_select = null
	player_faction_description = null
	enemy_faction_description = null
	difficulty_select = null
	difficulty_description = null

func _refresh_faction_ui() -> void:
	faction_label.text = DATA.faction_name(world.faction_for(0)).to_upper()
	for kind: String in unit_buttons:
		var button: Button = unit_buttons[kind]
		var spec: Dictionary = world.spec_for(kind, 0)
		button.text = world.entity_title(kind, 0) + "\n" + str(spec.cost) + " ESS"
		button.tooltip_text = _catalog_tooltip(kind)
		button.icon = _catalog_icon(kind)
	for kind: String in build_buttons:
		build_buttons[kind].icon = _catalog_icon(kind)
		build_buttons[kind].text = world.entity_title(kind, 0) + "\n" + str(world.spec_for(kind, 0).cost) + " ESS"
		build_buttons[kind].tooltip_text = _catalog_tooltip(kind)

func _restart() -> void:
	_start_match()

func _on_player_event(event: String, details: Dictionary) -> void:
	if not started or _quitting:
		return
	announcer.on_player_event(event, details)
	sfx.on_player_event(event, details)

func _toggle_music() -> void:
	music.toggle_mute()
	_refresh_audio_controls()

func _refresh_audio_controls() -> void:
	if is_instance_valid(music_button):
		music_button.text = "MUSIC OFF" if music.muted or is_zero_approx(music.volume_percent) else "MUSIC ON"
		music_button.tooltip_text = "Unmute music [M]" if music.muted else "Mute music [M]"
		if not music.muted and is_zero_approx(music.volume_percent):
			music_button.tooltip_text = "Music volume is 0% — adjust the Music slider"
	if is_instance_valid(music_volume_label):
		music_volume_label.text = "%d%%" % roundi(music.volume_percent) + (" · muted" if music.muted else "")
	if is_instance_valid(voice_volume_label):
		voice_volume_label.text = "%d%%" % roundi(voice.volume_percent)
	if is_instance_valid(sfx_volume_label):
		sfx_volume_label.text = "%d%%" % roundi(sfx.volume_percent)

func _show_audio_settings() -> void:
	if _audio_open or _quitting:
		return
	_audio_was_paused = paused
	_audio_previous_overlay = overlay if is_instance_valid(overlay) else null
	if is_instance_valid(_audio_previous_overlay):
		_audio_previous_overlay.hide()
	if started and world.match_state == "playing":
		paused = true
		_sync_audio_pause()
	_audio_open = true
	var card := _overlay_card(false)
	card.add_child(_label("SETTINGS / PAUSE" if started and world.match_state == "playing" else "SETTINGS", 28, ACCENT))
	var tabs := HBoxContainer.new()
	settings_audio_tab = _button("AUDIO", _show_settings_tab.bind(false), 36)
	settings_controls_tab = _button("CONTROLS", _show_settings_tab.bind(true), 36)
	for tab: Button in [settings_audio_tab, settings_controls_tab]:
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_ALL
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
	card.add_child(tabs)
	settings_audio = VBoxContainer.new()
	settings_audio.add_theme_constant_override("separation", 15)
	card.add_child(settings_audio)
	settings_audio.add_child(_label("Adjust music, unit voices, and sound effects independently.", 15))
	music_volume_label = _label("", 14)
	voice_volume_label = _label("", 14)
	sfx_volume_label = _label("", 14)
	music_volume_slider = _volume_row(settings_audio, "Music", music.volume_percent, music_volume_label, func(value: float) -> void:
		music.set_volume_percent(value)
		_refresh_audio_controls())
	voice_volume_slider = _volume_row(settings_audio, "Unit voices", voice.volume_percent, voice_volume_label, func(value: float) -> void:
		voice.set_volume_percent(value)
		_refresh_audio_controls())
	sfx_volume_slider = _volume_row(settings_audio, "Sound effects", sfx.volume_percent, sfx_volume_label, func(value: float) -> void:
		sfx.set_volume_percent(value)
		_refresh_audio_controls())
	settings_audio.add_child(_label("M toggles music mute. Volumes last for this session.", 13, MUTED))
	music_button = _button("MUSIC ON", _toggle_music, 36)
	music_button.focus_mode = Control.FOCUS_ALL
	settings_audio.add_child(music_button)
	settings_controls = VBoxContainer.new()
	settings_controls.add_theme_constant_override("separation", 12)
	card.add_child(settings_controls)
	settings_controls.add_child(_label("CONTROLS", 20, ACCENT))
	settings_controls.add_child(_label("These controls are fixed and cannot be changed.", 14, MUTED))
	var bindings := GridContainer.new()
	bindings.columns = 2
	bindings.add_theme_constant_override("h_separation", 24)
	bindings.add_theme_constant_override("v_separation", 8)
	for binding: Array in [
		["Left-click / drag", "Select / box-select"],
		["Shift + select", "Add to selection"],
		["Right-click", "Move, attack, harvest, or set rally point"],
		["E then left-click", "Attack-move"],
		["X", "Stop"],
		["H", "Hold position"],
		["Ctrl + 0–9 / 0–9", "Assign / recall control group"],
		["WASD / arrows", "Pan camera"],
		["Screen edges / middle drag", "Pan camera"],
		["Mouse wheel", "Zoom"],
		["F", "Focus selection"],
		["Space", "Pause / resume"],
		["Esc", "Cancel order mode / close settings / pause"],
		["M", "Toggle music mute"]
	]:
		bindings.add_child(_label(binding[0], 13))
		var action := _label(binding[1], 13)
		action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.custom_minimum_size.x = 290
		bindings.add_child(action)
	settings_controls.add_child(bindings)
	_show_settings_tab(false)
	var session_actions := HBoxContainer.new()
	session_actions.visible = started
	settings_restart_button = _button("RESTART", func() -> void: confirm_restart.popup_centered(), 36)
	settings_main_menu_button = _button("MAIN MENU", func() -> void:
		if world.match_state == "playing":
			confirm_leave.popup_centered()
		else:
			_show_title(), 36)
	for button: Button in [settings_restart_button, settings_main_menu_button]:
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		session_actions.add_child(button)
	card.add_child(session_actions)
	settings_done_button = _button("RESUME" if started and world.match_state == "playing" else "DONE", _resume_from_settings, 38)
	settings_done_button.focus_mode = Control.FOCUS_ALL
	card.add_child(settings_done_button)
	_refresh_audio_controls()
	music_volume_slider.grab_focus.call_deferred()
	_refresh_ui()

func _show_settings_tab(controls: bool) -> void:
	settings_audio.visible = not controls
	settings_controls.visible = controls
	settings_audio_tab.set_pressed_no_signal(not controls)
	settings_controls_tab.set_pressed_no_signal(controls)


func _volume_row(card: VBoxContainer, title: String, value: float, readout: Label, changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var label := _label(title, 15)
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size = Vector2(230, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.tooltip_text = title + " volume (0–100%)"
	slider.value_changed.connect(changed)
	row.add_child(slider)
	readout.custom_minimum_size.x = 110
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	card.add_child(row)
	return slider

func _close_audio_settings() -> void:
	if not _audio_open:
		return
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = _audio_previous_overlay if is_instance_valid(_audio_previous_overlay) else null
	_audio_previous_overlay = null
	if is_instance_valid(overlay):
		overlay.size = get_viewport_rect().size
		overlay.show()
	paused = _audio_was_paused
	_sync_audio_pause()
	_audio_open = false
	music_volume_slider = null
	voice_volume_slider = null
	sfx_volume_slider = null
	music_volume_label = null
	voice_volume_label = null
	sfx_volume_label = null
	music_button = null
	settings_restart_button = null
	settings_main_menu_button = null
	settings_done_button = null
	_refresh_ui()

func _resume_from_settings() -> void:
	if started and world.match_state == "playing":
		_audio_was_paused = false
	_close_audio_settings()

func _sync_audio_pause() -> void:
	voice.stream_paused = paused
	announcer.stream_paused = paused
	sfx.set_paused(paused)

func _toggle_pause() -> void:
	if not started or world.match_state != "playing" or is_instance_valid(overlay):
		return
	paused = not paused
	_sync_audio_pause()
	_notify("SIMULATION PAUSED — Space to resume" if paused else "Simulation resumed")

func _choose_build(kind: String) -> void:
	if not _can_issue():
		return
	build_kind = kind
	attack_mode = false
	_notify("Place " + world.entity_title(kind, 0) + ". Right-click or Esc cancels.", 8.0)

func _train(kind: String) -> void:
	if not _can_issue():
		return
	var producer: Dictionary = _producer_for_unit(kind)
	if producer.is_empty():
		_notify("Requires a completed friendly " + world.entity_title(str(DATA.UNIT_PRODUCERS.get(kind, "production building")), 0) + " and its listed prerequisites")
		return
	if world.queue_unit(int(producer.id), kind):
		production_focus = int(producer.id)
		_notify(world.entity_title(kind, 0) + " added to production queue")
	else:
		_notify(world.message)
	_refresh_ui()

func _producer_for_unit(kind: String) -> Dictionary:
	var chosen: Dictionary = _selected_producer()
	if not chosen.is_empty() and world.can_produce(int(chosen.id), kind):
		return chosen
	chosen = {}
	var shortest := INF
	for entity: Dictionary in world.entities.values():
		if int(entity.owner) != 0 or not world.can_produce(int(entity.id), kind):
			continue
		var remaining := 0.0
		for item: Dictionary in entity.queue:
			remaining += float(item.remaining)
		if remaining < shortest:
			shortest = remaining
			chosen = entity
	return chosen

func _selected_producer() -> Dictionary:
	if selected.size() != 1 or not world.entities.has(selected[0]):
		return {}
	var entity: Dictionary = world.entities[selected[0]]
	if int(entity.owner) != 0 or not bool(entity.completed) or float(entity.hp) <= 0.0:
		return {}
	if not DATA.UNIT_PRODUCERS.values().has(str(entity.kind)):
		return {}
	return entity

func _queue_producer() -> Dictionary:
	var candidates: Array = selected.duplicate() if selected.size() == 1 else []
	candidates.append(production_focus)
	candidates.append_array(world.entities.keys())
	for id: int in candidates:
		var entity: Dictionary = world.entities.get(id, {})
		if entity.is_empty() or int(entity.owner) != 0 or not bool(entity.completed) or float(entity.hp) <= 0.0:
			continue
		if not entity.queue.is_empty():
			return entity
	return {}

func _cancel_queue() -> void:
	if not _can_issue():
		return
	var producer: Dictionary = _queue_producer()
	if not producer.is_empty() and world.cancel_queue(int(producer.id)):
		_notify("Last queued unit cancelled; full Essence cost refunded")
		_refresh_ui()

func _selected_building() -> Dictionary:
	if selected.size() != 1 or not world.can_sell(0, int(selected[0])):
		return {}
	return world.entities[selected[0]]

func _repair_selected() -> void:
	if not _can_issue():
		return
	var building: Dictionary = _selected_building()
	if not building.is_empty() and world.toggle_repair(0, int(building.id)):
		_notify(world.message)
		_refresh_ui()

func _sell_selected() -> void:
	if not _can_issue():
		return
	var building: Dictionary = _selected_building()
	if building.is_empty():
		return
	if str(building.kind) == "hq":
		_sell_target = int(building.id)
		confirm_sell.dialog_text = "Selling your Command Center ends this match in defeat. Sell it for %d Essence (plus full refunds for queued units)?" % world.sell_refund(0, _sell_target)
		confirm_sell.popup_centered()
		_refresh_ui()
	else:
		_sell_building(int(building.id))

func _confirm_building_sale() -> void:
	confirm_sell.hide()
	var target: int = _sell_target
	_sell_target = -1
	if _can_issue():
		_sell_building(target)

func _sell_building(id: int) -> void:
	if world.sell_building(0, id):
		selected.erase(id)
		if production_focus == id:
			production_focus = -1
		_notify(world.message)
		_refresh_ui()

func _command(action: String) -> void:
	if not _can_issue():
		return
	build_kind = ""
	if action == "A":
		attack_mode = true
		_notify("ATTACK MOVE — click a destination", 8.0)
	else:
		attack_mode = false
		world.order_stop(selected, action == "H")
		_notify("Hold position" if action == "H" else "Orders stopped")

func _can_issue() -> bool:
	return started and not paused and world.match_state == "playing" and not is_instance_valid(overlay) and not confirm_leave.visible and not confirm_sell.visible

func _process(delta: float) -> void:
	if started and not paused and not confirm_leave.visible and not confirm_sell.visible and world.match_state == "playing":
		world.tick(delta)
		if world.message != last_message and not world.message.is_empty():
			last_message = world.message
			_notify(last_message)
	elif started and not paused and not confirm_leave.visible and not confirm_sell.visible and world.match_state != "playing":
		# Finish the decisive blast without advancing gameplay or the hover clock.
		world.advance_destruction_effects(delta)
	if started and world.match_state != "playing" and not end_shown and world.destruction_effects.is_empty():
		end_shown = true
		_show_end()
	selected = selected.filter(func(id: int) -> bool: return world.entities.has(id) and world.entities[id].owner == 0)
	var pointer: Vector2 = get_viewport().get_mouse_position()
	_pan_camera(delta, pointer, get_window().has_focus(), _camera_edge_scroll_direction(pointer))
	var mouse: Vector2 = pointer - field_clip.position
	view.camera_pos = camera_pos
	view.zoom_level = zoom_level
	view.selected = selected
	view.build_kind = build_kind
	view.cursor_world = _screen_to_world(mouse)
	view.dragging = dragging
	view.drag_start = drag_start
	view.drag_end = mouse
	view.attack_mode = attack_mode
	for index: int in range(view.command_markers.size() - 1, -1, -1):
		view.command_markers[index]["ttl"] = float(view.command_markers[index].ttl) - delta
		if float(view.command_markers[index].ttl) <= 0.0:
			view.command_markers.remove_at(index)
	view.queue_redraw()
	ui_timer += delta
	message_timer -= delta
	if ui_timer > 0.15:
		ui_timer = 0.0
		_refresh_ui()
	if message_timer <= 0 and started:
		status_label.text = ""
	if smoke_frames > 0:
		smoke_frames -= 1
		if smoke_frames == 0:
			print("COMMANDPOWER_SMOKE_OK entities=", world.entities.size())
			_quit()
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 20:
			_capture.call_deferred()
	if benchmark:
		benchmark_frames += 1
		if benchmark_frames > 60:
			benchmark_times.append(delta)
		if benchmark_frames == 360:
			var total := 0.0
			for value: float in benchmark_times: total += value
			benchmark_times.sort()
			print("COMMANDPOWER_RENDER_BENCHMARK fps=", float(benchmark_times.size()) / total, " p95_ms=", benchmark_times[int(benchmark_times.size() * 0.95)] * 1000.0, " entities=", world.entities.size(), " requested_combat_units=", benchmark_units)
			_quit()

func _setup_benchmark() -> void:
	world.ai_enabled = false
	var armies: Array = [[], []]
	for index: int in range(benchmark_units):
		var owner: int = index % 2
		var slot: int = index / 2
		var point := Vector2(900.0 + float(slot % 12) * 32.0, 1200.0 + float(slot / 12) * 32.0)
		if owner == 1: point.x = world.map_size.x - point.x
		var entity: Dictionary = world._spawn("tank" if slot % 5 == 0 else "infantry", owner, point)
		armies[owner].append(entity.id)
	world._rebuild_buckets()
	world._update_fog()
	world.order_move(armies[0], Vector2(1630, 1340), true)
	world.order_move(armies[1], Vector2(1440, 1340), true)
	zoom_level = 0.8
	camera_pos = PROJ.project(Vector2(1500, 1340), world.map_size) - battlefield_size / zoom_level / 2.0
	selected = armies[0].duplicate()
	_clamp_camera()

func _refresh_ui() -> void:
	essence_label.text = str(int(world.resources[0].essence))
	var power: Dictionary = world.power(0)
	power_meter.set_power(int(power.used), int(power.produced))
	power_label.text = str(int(power.used)) + " / " + str(int(power.produced))
	power_label.add_theme_color_override("font_color", Color("ff9f78") if power.used > power.produced else ACCENT)
	power_label.tooltip_text = "Power used / supplied: %d / %d\n%s" % [power.used, power.produced, "LOW POWER: training at half speed; powered defenses and support offline" if power.used > power.produced else "Sufficient power: unit training at full speed"]
	objective_label.text = "PAUSED" if paused else "%s / %02d:%02d\nDestroy enemy Command Center" % [DATA.faction_name(world.faction_for(1)), int(world.elapsed) / 60, int(world.elapsed) % 60]
	var first: Dictionary = {}
	if not selected.is_empty() and world.entities.has(selected[0]):
		first = world.entities[selected[0]]
	if selected.size() > 1:
		selection_label.text = str(selected.size()) + " UNITS SELECTED"
		selection_detail.text = "Right-click to move, attack, or harvest."
	elif not first.is_empty():
		selection_label.text = world.entity_title(first.kind, 0).to_upper()
		selection_detail.text = "%d / %d HP" % [ceili(first.hp), ceili(first.maxhp)]
		if not first.completed:
			selection_detail.text += "  /  BUILDING %d%%" % int(first.build_progress * 100)
		elif DATA.spec(str(first.kind)).building:
			selection_detail.text += "  /  " + _building_power_text(str(first.kind))
		elif first.kind == "worker":
			selection_detail.text += "  /  CARGO %d" % int(first.cargo)
		else:
			selection_detail.text += "  /  " + str(first.order).to_upper()
	else:
		selection_label.text = "FIELD COMMAND"
		selection_detail.text = "Drag to select units. Right-click to issue orders."
	var building: Dictionary = _selected_building()
	building_actions.visible = not building.is_empty()
	# A transient disable cancels BaseButton mouse presses before release.
	repair_button.disabled = building.is_empty() or not _can_issue() or not world.can_repair(0, int(building.id))
	sell_button.disabled = building.is_empty() or not _can_issue()
	if not building.is_empty():
		var repairing: bool = bool(building.repairing)
		repair_button.text = "STOP REPAIR" if repairing else "REPAIR"
		var repair_cost: int = ceili((float(building.maxhp) - float(building.hp)) / float(building.maxhp) * float(world.entity_spec(building).cost) * SIM.REPAIR_COST_FRACTION)
		repair_button.tooltip_text = "Toggle repair: 2%% maximum HP per second, paid in 1 Essence pulses.\nRepair remaining damage: %d Essence. Waits when funds run out.\nRequires a completed, damaged friendly building; no worker needed." % repair_cost
		if repairing:
			selection_detail.text += " / " + ("REPAIRING" if int(world.resources[0].essence) > 0 else "REPAIR WAITING: NEED ESSENCE")
		var salvage: int = world.sell_refund(0, int(building.id))
		var queue_refund := 0
		for item: Dictionary in building.queue:
			queue_refund += int(item.cost)
		sell_button.text = "SELL +%d ESS" % (salvage + queue_refund)
		sell_button.tooltip_text = "Sell immediately: %d Essence salvage (half cost, scaled by health).\nQueued units cancelled: %d Essence refunded." % [salvage, queue_refund]
		if str(building.kind) == "hq":
			sell_button.tooltip_text += "\nWARNING: selling your Command Center ends the match in defeat. Confirmation required."
	var player_essence: float = float(world.resources[0].essence)
	for kind: String in build_buttons:
		build_buttons[kind].disabled = not _can_issue() or not world.has_requirements(0, kind) or player_essence < world.spec_for(kind, 0).cost
	for kind: String in unit_buttons:
		var allowed: bool = not _producer_for_unit(kind).is_empty()
		unit_buttons[kind].disabled = not _can_issue() or not allowed or player_essence < world.spec_for(kind, 0).cost
	var producer: Dictionary = _queue_producer()
	queue_label.text = "QUEUE  /  EMPTY"
	if power.used > power.produced:
		queue_label.text += "  /  LOW POWER: HALF SPEED"
	cancel_button.disabled = true
	if not producer.is_empty() and not producer.queue.is_empty():
		var item: Dictionary = producer.queue[0]
		queue_label.text = "%s  %d%% / %s\n%d unit(s) queued%s" % [world.entity_title(item.kind, 0), int(100.0 * (1.0 - item.remaining / item.total)), world.entity_title(str(producer.kind), 0), producer.queue.size(), " / LOW POWER: HALF SPEED" if power.used > power.produced else ""]
		cancel_button.disabled = not _can_issue()
	_refresh_catalog_pages()
	radar.camera_pos = camera_pos
	radar.camera_view = battlefield_size
	radar.zoom_level = zoom_level
	radar.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if confirm_sell.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_music()
			return
		if event.keycode == KEY_ESCAPE:
			if _audio_open:
				_close_audio_settings()
			elif not build_kind.is_empty() or attack_mode:
				build_kind = ""
				attack_mode = false
			elif is_instance_valid(overlay) and started and not end_shown:
				overlay.queue_free()
				overlay = null
				paused = false
				_sync_audio_pause()
			else:
				_toggle_pause()
			return
		if event.keycode == KEY_SPACE:
			_toggle_pause()
			return
		if not _can_issue(): return
		match event.keycode:
			KEY_E: _command("A")
			KEY_X: _command("S")
			KEY_H: _command("H")
			KEY_F: _focus_selected()
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var number: int = event.keycode - KEY_0
			if event.ctrl_pressed:
				groups[number] = selected.duplicate()
				_notify("Control group " + str(number) + " assigned")
			elif groups.has(number):
				selected = groups[number].filter(func(id: int) -> bool: return world.entities.has(id))
				_acknowledge(selected, "select")
			_refresh_ui()
	if event is InputEventMouseMotion:
		if middle_drag:
			camera_pos -= event.relative / zoom_level
			_clamp_camera()
	if not event is InputEventMouseButton: return
	var local: Vector2 = event.position - field_clip.position
	var inside := Rect2(Vector2.ZERO, battlefield_size).has_point(local)
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		middle_drag = event.pressed and inside
		return
	if not inside or not started or is_instance_valid(overlay):
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: dragging = false
		return
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var before: Vector2 = camera_pos + local / zoom_level
		zoom_level = clampf(zoom_level * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.65, 1.6)
		camera_pos = before - local / zoom_level
		_clamp_camera()
		return
	if not _can_issue(): return
	var point: Vector2 = _screen_to_world(local)
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not build_kind.is_empty() or attack_mode:
			build_kind = ""
			attack_mode = false
			return
		_issue_context(point)
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not build_kind.is_empty():
				if world.start_build(0, build_kind, point):
					_notify(world.entity_title(build_kind, 0) + " construction ordered")
					if not event.shift_pressed: build_kind = ""
				else:
					_notify(world.message)
				_refresh_ui()
				return
			if attack_mode:
				var target := _pick(point, 1)
				if target >= 0:
					world.order_attack(selected, target)
					_acknowledge_attack(selected, point, "attack", target)
				else:
					world.order_move(selected, point, true)
					_acknowledge_attack_move(selected, point)
				_mark(point, true)
				attack_mode = false
				return
			dragging = true
			drag_start = local
		else:
			if dragging:
				_select(local, event.shift_pressed)
				dragging = false

func _select(end: Vector2, additive: bool) -> void:
	var found: Array = []
	var added: Array = []
	if drag_start.distance_to(end) > 7.0:
		var rect := Rect2(drag_start, end - drag_start).abs()
		for entity: Dictionary in world.entities.values():
			if entity.owner == 0 and not DATA.spec(entity.kind).building and rect.intersects(_entity_screen_rect(entity)):
				found.append(entity.id)
	else:
		var id := _pick(_screen_to_world(end), 0)
		if id >= 0: found.append(id)
	if not additive: selected.clear()
	for id: int in found:
		if additive and selected.has(id): selected.erase(id)
		elif not selected.has(id):
			selected.append(id)
			added.append(id)
	_acknowledge(added, "select")
	_refresh_ui()

func _acknowledge(ids: Array, action: String) -> void:
	if _can_issue() and not _quitting:
		voice.acknowledge(world.entities, ids, action)

func _acknowledge_move(ids: Array, point: Vector2, order: String, target: int = -1) -> void:
	if not Rect2(Vector2.ZERO, world.map_size).has_point(point):
		return
	var accepted: Array = []
	for id: int in world._valid_order_ids(ids):
		var entity: Dictionary = world.entities[id]
		if str(entity.order) == order and (target < 0 or int(entity.target) == target):
			accepted.append(id)
	_acknowledge(accepted, "move")

func _acknowledge_attack(ids: Array, point: Vector2, order: String, target: int = -1) -> void:
	if not Rect2(Vector2.ZERO, world.map_size).has_point(point):
		return
	if target >= 0:
		if not world.entities.has(target):
			return
		var enemy: Dictionary = world.entities[target]
		if int(enemy.owner) == 0 or float(enemy.hp) <= 0.0 or not world.can_see_entity(0, enemy):
			return
	var accepted: Array = []
	for id: int in world._valid_order_ids(ids):
		var entity: Dictionary = world.entities[id]
		if int(entity.owner) == 0 and float(DATA.spec(str(entity.kind)).damage) > 0.0 and str(entity.order) == order and (target < 0 or int(entity.target) == target):
			accepted.append(id)
	_acknowledge(accepted, "attack")

func _acknowledge_attack_move(ids: Array, point: Vector2) -> void:
	var combatants: Array = []
	for id: int in world._valid_order_ids(ids):
		if float(DATA.spec(str(world.entities[id].kind)).damage) > 0.0:
			combatants.append(id)
	if combatants.is_empty():
		_acknowledge_move(ids, point, "attack_move")
	else:
		_acknowledge_attack(combatants, point, "attack_move")

func _pick(point: Vector2, owner: int = -1) -> int:
	var best := -1
	var depth := -INF
	var projected: Vector2 = PROJ.project(point, world.map_size)
	for entity: Dictionary in world.entities.values():
		if owner >= 0 and entity.owner != owner: continue
		if entity.owner != 0 and not world.can_see_entity(0, entity): continue
		var relative: Vector2 = projected - PROJ.project(entity.pos, world.map_size) - ART.hover_offset(entity, float(world.elapsed))
		var hit := Geometry2D.is_point_in_polygon(relative, ART.hit_polygon(entity))
		var candidate: float = entity.pos.x + entity.pos.y
		if hit and candidate >= depth:
			best = entity.id
			depth = candidate
	return best

func _world_to_screen(point: Vector2) -> Vector2:
	return (PROJ.project(point, world.map_size) - camera_pos) * zoom_level

func _screen_to_world(point: Vector2) -> Vector2:
	return PROJ.unproject(point / zoom_level + camera_pos, world.map_size)

func _entity_screen_rect(entity: Dictionary) -> Rect2:
	var anchor: Vector2 = _world_to_screen(entity.pos) + ART.hover_offset(entity, float(world.elapsed)) * zoom_level
	var polygon: PackedVector2Array = ART.hit_polygon(entity)
	var bounds := Rect2(anchor + polygon[0] * zoom_level, Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(anchor + point * zoom_level)
	return bounds

func _issue_context(point: Vector2) -> void:
	if selected.is_empty() or not _can_issue(): return
	var enemy := _pick(point, 1)
	if enemy >= 0:
		world.order_attack(selected, enemy)
		_acknowledge_attack(selected, point, "attack", enemy)
		_mark(point, true)
		return
	var deposit_id := -1
	var deposit_distance := INF
	var projected: Vector2 = PROJ.project(point, world.map_size)
	for deposit: Dictionary in world.deposits:
		if not world.is_visible(0, deposit.pos): continue
		var relative: Vector2 = projected - PROJ.project(deposit.pos, world.map_size)
		var distance: float = (relative + Vector2(0, 10)).length_squared()
		if Rect2(Vector2(-32, -36), Vector2(64, 54)).has_point(relative) and distance < deposit_distance:
			deposit_id = deposit.id
			deposit_distance = distance
	if deposit_id >= 0:
		world.order_gather(selected, deposit_id)
		_acknowledge_move(selected, point, "gather", deposit_id)
		_mark(point, false)
		return
	var mobile: Array = []
	for id: int in selected:
		if not world.entities.has(id): continue
		var entity: Dictionary = world.entities[id]
		if DATA.spec(entity.kind).building:
			entity.rally = point
		else:
			mobile.append(id)
	if not mobile.is_empty():
		world.order_move(mobile, point)
		_acknowledge_move(mobile, point, "move")
	_mark(point, false)

func _mark(point: Vector2, attack: bool) -> void:
	view.command_markers.append({"pos": point, "ttl": 0.8, "color": Color("ff9b72") if attack else ACCENT})

func _focus_selected() -> void:
	var center := Vector2.ZERO
	var count := 0
	for id: int in selected:
		if world.entities.has(id):
			center += world.entities[id].pos
			count += 1
	if count > 0:
		camera_pos = PROJ.project(center / count, world.map_size) - battlefield_size / zoom_level / 2.0
		_clamp_camera()

func _home_camera() -> void:
	camera_pos = PROJ.project(Vector2(460, 420), world.map_size) - battlefield_size / zoom_level / 2.0
	_clamp_camera()

func _edge_scroll_direction(pointer: Vector2) -> Vector2:
	var dimensions: Vector2 = get_viewport_rect().size
	# Mouse positions use viewport units; keep the edge band 16 display pixels
	# wide when fullscreen or window resizing scales the canvas.
	var scale: Vector2 = get_viewport().get_stretch_transform().get_scale().abs()
	scale = scale.max(Vector2(.001, .001))
	# Fractional scaling can put an exact top/left pixel just below zero.
	var tolerance := Vector2.ONE * .001 / scale
	if pointer.x < -tolerance.x or pointer.y < -tolerance.y or pointer.x >= dimensions.x or pointer.y >= dimensions.y:
		return Vector2.ZERO
	pointer = pointer.max(Vector2.ZERO)
	var margin := Vector2.ONE * EDGE_SCROLL_MARGIN / scale
	var in_battlefield := Rect2(field_clip.position, battlefield_size).has_point(pointer)
	var direction := Vector2.ZERO
	if pointer.x < margin.x:
		direction.x = -1.0
	elif pointer.x >= dimensions.x - margin.x or (in_battlefield and pointer.x >= battlefield_size.x - margin.x):
		direction.x = 1.0
	if pointer.y < margin.y:
		direction.y = -1.0
	elif pointer.y >= dimensions.y - margin.y:
		direction.y = 1.0
	return direction

func _frame_edge_scroll_direction(screen_pointer: Vector2, client: Rect2, frame: Rect2) -> Vector2:
	if not frame.has_point(screen_pointer) or client.has_point(screen_pointer):
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if screen_pointer.x < client.position.x:
		direction.x = -1
	elif screen_pointer.x >= client.end.x:
		direction.x = 1
	if screen_pointer.y < client.position.y:
		direction.y = -1
	elif screen_pointer.y >= client.end.y:
		direction.y = 1
	return direction

func _native_edge_scroll_direction(screen_pointer: Vector2, client: Rect2, frame: Rect2, stretch: Transform2D, buttons_pressed: bool = false) -> Vector2:
	if client.has_point(screen_pointer):
		var pointer: Vector2 = stretch.affine_inverse() * (screen_pointer - client.position)
		return _edge_scroll_direction(pointer)
	if buttons_pressed:
		return Vector2.ZERO
	return _frame_edge_scroll_direction(screen_pointer, client, frame)

func _camera_edge_scroll_direction(viewport_pointer: Vector2) -> Vector2:
	if DisplayServer.get_name() == "headless":
		return _edge_scroll_direction(viewport_pointer) if _mouse_inside_window else Vector2.ZERO
	# Use one live native sample for both client and frame edges. Enter/exit
	# signals and viewport mouse positions can remain stale across window moves.
	var window_id: int = get_window().get_window_id()
	var client := Rect2(Vector2(DisplayServer.window_get_position(window_id)), Vector2(DisplayServer.window_get_size(window_id)))
	var frame := Rect2(Vector2(DisplayServer.window_get_position_with_decorations(window_id)), Vector2(DisplayServer.window_get_size_with_decorations(window_id)))
	return _native_edge_scroll_direction(Vector2(DisplayServer.mouse_get_position()), client, frame, get_viewport().get_stretch_transform(), DisplayServer.mouse_get_button_state() != 0)

func _pan_camera(delta: float, pointer: Vector2, window_active: bool = true, edge_direction: Variant = null) -> void:
	if not window_active or not started or is_instance_valid(overlay) or confirm_restart.visible or confirm_leave.visible or confirm_sell.visible or dragging or middle_drag:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): direction.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): direction.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): direction.y += 1
	if edge_direction != null:
		direction += Vector2(edge_direction)
	elif _mouse_inside_window:
		direction += _edge_scroll_direction(pointer)
	camera_pos += direction.limit_length() * 650.0 * delta / zoom_level
	_clamp_camera()

func _clamp_camera() -> void:
	camera_pos = PROJ.clamp_camera(camera_pos, battlefield_size / zoom_level, world.map_size)

func _notify(text: String, duration: float = 4.0) -> void:
	if text.is_empty(): return
	status_label.text = text
	message_timer = duration

func _overlay_card(replace_overlay: bool = true) -> VBoxContainer:
	if replace_overlay and _audio_open:
		_close_audio_settings()
	if replace_overlay and is_instance_valid(overlay): overlay.queue_free()
	overlay = Control.new()
	overlay.size = get_viewport_rect().size
	ui.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.04, 0.87)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation", 15)
	margin.add_child(column)
	return column

func _enter_menu(screen: String) -> VBoxContainer:
	if _audio_open:
		_close_audio_settings()
	announcer.cancel()
	voice.cancel()
	sfx.cancel()
	started = false
	paused = false
	menu_screen = screen
	selected.clear()
	build_kind = ""
	attack_mode = false
	dragging = false
	middle_drag = false
	confirm_leave.hide()
	confirm_restart.hide()
	confirm_sell.hide()
	_sell_target = -1
	sidebar.hide()
	_clear_menu_selectors()
	return _overlay_card()

func _show_title() -> void:
	var card := _enter_menu("title")
	card.add_child(_heading("REAL-TIME STRATEGY   /   35,000 AD"))
	card.add_child(_label("COMMAND / POWER", 37, ACCENT))
	card.add_child(_label("THE SILENT WELLS", 20, Color("d7c78d")))
	var story := _label("Heaven and Hell are sealed. The souls of the dead wander Limbo. Across the galaxy, rival civilizations harvest spiritual essence to fuel their wars.", 15)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(story)
	var lineup := HBoxContainer.new()
	lineup.alignment = BoxContainer.ALIGNMENT_CENTER
	for faction: String in DATA.FACTIONS:
		var portrait := TextureRect.new()
		portrait.texture = _catalog_icon("tank", faction)
		portrait.custom_minimum_size = Vector2(76, 72)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.tooltip_text = DATA.faction_name(faction)
		lineup.add_child(portrait)
	card.add_child(lineup)
	card.add_child(_button("SKIRMISH", _show_skirmish, 48))
	card.add_child(_button("SETTINGS", _show_audio_settings, 36))
	card.add_child(_button("QUIT", _quit, 36))
	card.add_child(_label("Five factions. Two rival Aetherbound hosts. One galaxy at war.", 12, MUTED))

func _faction_selector(card: VBoxContainer, heading: String, selected_faction: String) -> OptionButton:
	var row := HBoxContainer.new()
	var label := _heading(heading)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(350, 38)
	for faction: String in DATA.FACTIONS:
		selector.add_item(DATA.faction_name(faction))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		selector.add_theme_stylebox_override(state, ui.theme.get_stylebox(state, "Button"))
	selector.select(DATA.FACTIONS.find(selected_faction))
	row.add_child(selector)
	card.add_child(row)
	return selector

func _setup_selector(card: VBoxContainer, heading: String, width: float) -> OptionButton:
	var row := HBoxContainer.new()
	var label := _heading(heading)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(width, 38)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		selector.add_theme_stylebox_override(state, ui.theme.get_stylebox(state, "Button"))
	row.add_child(selector)
	card.add_child(row)
	return selector

func _color_selector(row: HBoxContainer, hint: String, color: Color) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(169, 38)
	selector.tooltip_text = hint
	for index: int in range(SIM.PLAYER_COLORS.size()):
		var swatch := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		swatch.fill(SIM.PLAYER_COLORS[index])
		selector.add_icon_item(ImageTexture.create_from_image(swatch), ("You: " if hint.begins_with("Your") else "AI: ") + SIM.PLAYER_COLOR_NAMES[index])
	selector.select(SIM.PLAYER_COLORS.find(color))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		selector.add_theme_stylebox_override(state, ui.theme.get_stylebox(state, "Button"))
	row.add_child(selector)
	return selector

func _on_color_selected(player_changed: bool) -> void:
	if player_color_select.selected == enemy_color_select.selected:
		var other: OptionButton = enemy_color_select if player_changed else player_color_select
		other.select((other.selected + 1) % SIM.PLAYER_COLORS.size())

func _on_map_selected(index: int) -> void:
	var map: Dictionary = MAPS.MAPS[MAPS.MAPS.keys()[index]]
	map_description.text = "%s %d wells. Each side starts with 900 essence and equal forces. Destroy the enemy Command Center." % [map.description, map.wells.size()]

func _show_skirmish() -> void:
	var card := _enter_menu("skirmish")
	card.add_theme_constant_override("separation", 8)
	card.add_child(_heading("SINGLE PLAYER   /   ONE COMMANDER VS AI"))
	card.add_child(_label("CREATE SKIRMISH", 30, ACCENT))
	map_select = _setup_selector(card, "BATTLEFIELD", 350)
	for map: Dictionary in MAPS.MAPS.values():
		var tiles: Vector2i = Vector2i(Vector2(map.size) / DATA.CELL_SIZE)
		map_select.add_item("%s — %s / %d × %d" % [map.name, map.label, tiles.x, tiles.y])
	map_select.select(MAPS.MAPS.keys().find(world.map_id))
	map_description = _label("", 13, MUTED)
	map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(map_description)
	map_select.item_selected.connect(_on_map_selected)
	_on_map_selected(map_select.selected)
	player_faction_select = _faction_selector(card, "YOUR FACTION", world.faction_for(0))
	player_faction_description = _label("", 13)
	player_faction_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(player_faction_description)
	enemy_faction_select = _faction_selector(card, "AI FACTION", world.faction_for(1))
	enemy_faction_description = _label("", 13)
	enemy_faction_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(enemy_faction_description)
	player_faction_select.item_selected.connect(func(_index: int) -> void: _refresh_skirmish_descriptions())
	enemy_faction_select.item_selected.connect(func(_index: int) -> void: _refresh_skirmish_descriptions())
	_refresh_skirmish_descriptions()
	var color_row := HBoxContainer.new()
	var color_heading := _heading("ARMY COLORS")
	color_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_row.add_child(color_heading)
	player_color_select = _color_selector(color_row, "Your army color", world.color_for(0))
	enemy_color_select = _color_selector(color_row, "AI army color", world.color_for(1))
	card.add_child(color_row)
	player_color_select.item_selected.connect(func(_index: int) -> void: _on_color_selected(true))
	enemy_color_select.item_selected.connect(func(_index: int) -> void: _on_color_selected(false))
	var difficulty_row := HBoxContainer.new()
	var difficulty_label := _heading("AI DIFFICULTY")
	difficulty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_row.add_child(difficulty_label)
	difficulty_select = OptionButton.new()
	difficulty_select.custom_minimum_size = Vector2(350, 38)
	for level: String in SIM.AI_LEVELS:
		difficulty_select.add_item(level.capitalize())
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		difficulty_select.add_theme_stylebox_override(state, ui.theme.get_stylebox(state, "Button"))
	difficulty_select.select(SIM.AI_LEVELS.find(world.ai_difficulty))
	difficulty_select.item_selected.connect(_on_difficulty_selected)
	difficulty_row.add_child(difficulty_select)
	card.add_child(difficulty_row)
	difficulty_description = _label("", 13, MUTED)
	difficulty_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(difficulty_description)
	_on_difficulty_selected(difficulty_select.selected)
	card.add_child(_button("START SKIRMISH", _start_match, 44))
	card.add_child(_button("BACK TO TITLE", _show_title, 32))

func _refresh_skirmish_descriptions() -> void:
	for entry: Array in [[player_faction_select, player_faction_description], [enemy_faction_select, enemy_faction_description]]:
		var faction: String = DATA.FACTIONS[entry[0].selected]
		entry[1].text = "%s\n21 units / 13 buildings · distinct specialists and support" % DATA.FACTION_STYLES[faction]

func _on_difficulty_selected(index: int) -> void:
	if index < 0 or index >= SIM.AI_LEVELS.size():
		return
	world.set_ai_difficulty(SIM.AI_LEVELS[index])
	if is_instance_valid(difficulty_description):
		var descriptions: Dictionary = {
			"easy": "Slower expansion and later attacks. Same faction rules and starting resources.",
			"normal": "Balanced expansion and steady attacks. Same faction rules and starting resources.",
			"hard": "Faster expansion and earlier, frequent attacks. Same faction rules and starting resources."
		}
		difficulty_description.text = descriptions[world.ai_difficulty]

func _show_help() -> void:
	_show_audio_settings()
	if _audio_open:
		_show_settings_tab(true)

func _show_end() -> void:
	menu_screen = "results"
	var card := _overlay_card()
	var won: bool = world.match_state == "victory"
	card.add_child(_heading("OPERATION COMPLETE"))
	card.add_child(_label(str(world.match_state).to_upper(), 42, ACCENT if won else Color("ed947d")))
	var summary := "%s Command has fallen. The wells are secured." % DATA.faction_name(world.faction_for(1)) if won else "Your Command Center has fallen. %s holds the field." % DATA.faction_name(world.faction_for(1))
	if world.match_state == "draw": summary = "Both Command Centers have fallen."
	card.add_child(_label(summary, 15))
	card.add_child(_label("Elapsed time  %02d:%02d" % [int(world.elapsed) / 60, int(world.elapsed) % 60], 13, MUTED))
	card.add_child(_button("NEW SKIRMISH", _show_skirmish, 44))
	card.add_child(_button("TITLE SCREEN", _show_title, 32))
	card.add_child(_button("SETTINGS", _show_audio_settings, 32))
	card.add_child(_button("QUIT", _quit, 32))

func _quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	set_process(false)
	await announcer.finish()
	await sfx.finish()
	await voice.finish()
	await music.finish()
	get_tree().quit(exit_code)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	print("COMMANDPOWER_CAPTURE ", capture_path, " error=", error)
	_quit(error)
