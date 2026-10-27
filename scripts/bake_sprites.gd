extends SceneTree

# Bake original lit 3D miniatures into the fixed isometric sprite atlases.
# .tools/godot --path . --audio-driver Dummy --script res://scripts/bake_sprites.gd
# Then .tools/godot --headless --editor --path . --import
# -- --sample writes two-faction samples under /tmp instead of changing game assets.
# -- --units-only preserves the existing buildings atlas.
# -- --buildings-only preserves the existing unit atlas.
# -- --human-units updates only the Prospector and Vanguard facing cells.
# -- --human-tank updates only the Paladin Tank facing cells.
const ART = preload("res://scripts/faction_sprites.gd")
const MODELS = preload("res://scripts/sprite_models_3d.gd")
const PIXELS_PER_UNIT: float = 1.41421356237
var sample := false
var units_only := false
var buildings_only := false
var human_units := false
var human_tank := false
var expansion := false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--expansion": expansion=true
		if argument=="--sample": sample=true
		if argument=="--units-only": units_only=true
		if argument=="--buildings-only": buildings_only=true
		if argument=="--human-units":
			human_units=true
			units_only=true
		if argument=="--human-tank":
			human_tank=true
			units_only=true
	if buildings_only and units_only:
		push_error("Use --buildings-only without --units-only, --human-units, or --human-tank.")
		quit(1)
		return
	if (human_units or human_tank) and (sample or (human_units and human_tank)):
		push_error("Use one targeted Human bake option without --sample to update the existing atlas.")
		quit(1)
		return
	_run.call_deferred()

func _make_stage(cell: Vector2,anchor: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.size = Vector2i(cell)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var scene := Node3D.new()
	viewport.add_child(scene)
	root.add_child(viewport)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0,0,0,0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a3b0b6")
	environment.ambient_light_energy = .55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment
	scene.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d1")
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-50,-25,0)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 350
	key.shadow_bias = .04
	key.shadow_normal_bias = .5
	scene.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = cell.y / PIXELS_PER_UNIT
	camera.position = Vector3(110,89.8146,110)
	scene.add_child(camera)
	camera.look_at(Vector3.ZERO,Vector3.UP)
	camera.v_offset = (anchor.y-cell.y*.5) / PIXELS_PER_UNIT
	camera.near = .1
	camera.far = 500
	camera.current = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(260,260)
	ground.mesh = plane
	ground.position.y = -.15
	# Hover silhouettes need a soft detached shadow, not the catcher's opaque patch.
	ground.visible = cell != ART.UNIT_CELL
	var catcher := StandardMaterial3D.new()
	catcher.shadow_to_opacity = true
	catcher.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	catcher.albedo_color = Color(0,0,0,.35)
	catcher.roughness = 1
	ground.material_override = catcher
	scene.add_child(ground)
	return {"viewport":viewport,"scene":scene,"ground":ground}

func _render(stage: Dictionary) -> Image:
	await process_frame
	await process_frame
	# Readback must also work when the bake window is inactive or occluded.
	RenderingServer.force_draw(false)
	return stage.viewport.get_texture().get_image()

func _ground_shadow(image: Image,anchor: Vector2,kind: String) -> Image:
	var result := Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var radii: Vector2
	if bool(ART.DATA.spec(kind).building):
		var size: Vector2 = Vector2(ART.DATA.spec(kind).size)
		radii = Vector2((size.x+size.y)*.48,(size.x+size.y)*.23)
	else:
		radii = Vector2(33,12) if kind=="tank" else (Vector2(23,8) if kind=="worker" else Vector2(10,4))
	var center: Vector2 = anchor+Vector2(5,5)
	for y: int in range(maxi(0,floori(center.y-radii.y)),mini(image.get_height(),ceili(center.y+radii.y)+1)):
		for x: int in range(maxi(0,floori(center.x-radii.x)),mini(image.get_width(),ceili(center.x+radii.x)+1)):
			var distance: float = ((Vector2(x,y)-center)/radii).length()
			if distance<1:
				result.set_pixel(x,y,Color(.025,.03,.035,pow(1.0-distance,.6)*.36))
	result.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
	return result

func _run() -> void:
	if expansion:
		await _run_expansion()
		return
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	var rows: int = 2 if sample else ART.STYLES.size()
	var modes: Array = [true] if buildings_only else ([false] if units_only else [false,true])
	for building_mode: bool in modes:
		var cell: Vector2 = ART.BUILDING_CELL if building_mode else ART.UNIT_CELL
		var anchor: Vector2 = ART.BUILDING_ANCHOR if building_mode else ART.UNIT_ANCHOR
		var kinds: Array = ART.BUILDING_KINDS if building_mode else ART.UNIT_KINDS
		var columns: int = kinds.size() if building_mode else kinds.size()*8
		var output := Image.create(int(cell.x)*columns,int(cell.y)*rows,false,Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		if human_units or human_tank:
			output = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/units.png"))
			if output == null or output.get_size()!=Vector2i(3072,768):
				push_error("Targeted bake requires the existing 3072x768 unit atlas.")
				quit(1)
				return
			output.convert(Image.FORMAT_RGBA8)
		var stage: Dictionary = _make_stage(cell,anchor)
		for row: int in range(rows):
			if (human_units or human_tank) and row!=0: continue
			for index: int in range(kinds.size()):
				if human_units and kinds[index] not in ["worker","infantry"]: continue
				if human_tank and kinds[index]!="tank": continue
				var model: Node3D = MODELS.build(ART.STYLES[row],kinds[index])
				stage.scene.add_child(model)
				var facing_count: int = 1 if building_mode else 8
				for facing: int in range(facing_count):
					if not building_mode:
						model.rotation.y = PI*.5-float(facing)*TAU/8.0
					var image: Image = await _render(stage)
					# A shadow catcher must not turn the transparent frame into a plane.
					if image.get_pixel(0,0).a>.01 or image.get_pixel(image.get_width()-1,image.get_height()-1).a>.01:
						stage.ground.visible = false
						image = await _render(stage)
					image = _ground_shadow(image,anchor,kinds[index])
					var column: int = index if building_mode else index*8+facing
					output.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(int(cell.x)*column,int(cell.y)*row))
				model.free()
			print("BAKE_ROW ",ART.STYLES[row]," buildings=",building_mode)
		stage.viewport.queue_free()
		var filename: String = "buildings.png" if building_mode else "units.png"
		var path: String = "/tmp/commandpower-3d-"+filename if sample else "res://assets/sprites/"+filename
		var error: Error = output.save_png(path)
		if error!=OK:
			push_error("3D sprite bake failed: "+path)
			quit(error)
			return
		print("BAKED_3D ",path," ",output.get_width(),"x",output.get_height())
	quit()

# New faction rows are separate textures so no atlas exceeds hardware limits.
# --expansion never changes a pixel in the original three-unit/five-building atlases.
func _run_expansion() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	if not buildings_only:
		var stage: Dictionary = _make_stage(ART.UNIT_CELL, ART.UNIT_ANCHOR)
		for style: String in ART.STYLES:
			var output := Image.create(1024, ART.EXPANSION_UNIT_KINDS.size() * 128, false, Image.FORMAT_RGBA8)
			output.fill(Color.TRANSPARENT)
			for row: int in range(ART.EXPANSION_UNIT_KINDS.size()):
				var kind: String = ART.EXPANSION_UNIT_KINDS[row]
				var model: Node3D = MODELS.build(style, kind)
				stage.scene.add_child(model)
				for facing: int in range(8):
					model.rotation.y = PI * .5 - float(facing) * TAU / 8.0
					var frame: Image = await _render(stage)
					frame = _ground_shadow(frame, ART.UNIT_ANCHOR, kind)
					output.blit_rect(frame, Rect2i(0, 0, 128, 128), Vector2i(facing * 128, row * 128))
				model.free()
				print("BAKE_EXPANSION_UNIT ", style, " ", kind)
			var path: String = "res://assets/sprites/units_%s.png" % style
			var error: Error = output.save_png(path)
			if error != OK:
				push_error("Expansion unit bake failed: " + path)
				quit(error)
				return
			print("BAKED_EXPANSION ", path, " ", output.get_width(), "x", output.get_height())
		stage.viewport.queue_free()
	if not units_only:
		var stage: Dictionary = _make_stage(ART.BUILDING_CELL, ART.BUILDING_ANCHOR)
		var output := Image.create(ART.EXPANSION_BUILDING_KINDS.size() * 320, ART.STYLES.size() * 256, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		for row: int in range(ART.STYLES.size()):
			var style: String = ART.STYLES[row]
			for column: int in range(ART.EXPANSION_BUILDING_KINDS.size()):
				var kind: String = ART.EXPANSION_BUILDING_KINDS[column]
				var model: Node3D = MODELS.build(style, kind)
				stage.scene.add_child(model)
				var frame: Image = await _render(stage)
				if frame.get_pixel(0, 0).a > .01:
					stage.ground.visible = false
					frame = await _render(stage)
				frame = _ground_shadow(frame, ART.BUILDING_ANCHOR, kind)
				output.blit_rect(frame, Rect2i(0, 0, 320, 256), Vector2i(column * 320, row * 256))
				model.free()
				print("BAKE_EXPANSION_BUILDING ", style, " ", kind)
		var path: String = "res://assets/sprites/expansion_buildings.png"
		var error: Error = output.save_png(path)
		if error != OK:
			push_error("Expansion building bake failed: " + path)
			quit(error)
			return
		print("BAKED_EXPANSION ", path, " ", output.get_width(), "x", output.get_height())
		stage.viewport.queue_free()
	quit()
