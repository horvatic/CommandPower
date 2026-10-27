extends RefCounted

# Offline, original models for the prerendered sprite atlas. No gameplay code.
const DATA = preload("res://scripts/catalog.gd")
static var _materials: Dictionary = {}

static func material(key: String, color: Color, metal: float = 0.15, glow: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color.WHITE
	result.metallic = metal
	result.roughness = 0.83
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	var image := Image.create(64,64,false,Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(key.hash())
	for y: int in range(64):
		for x: int in range(64):
			var wear: float = rng.randf_range(-0.09,0.07)
			if y % 16 == 0 or x % 23 == 0: wear -= 0.12
			if rng.randf() < 0.035: wear += 0.13
			image.set_pixel(x,y,color.lightened(wear) if wear >= 0 else color.darkened(-wear))
	result.albedo_texture = ImageTexture.create_from_image(image)
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	_materials[key] = result
	return result

static func palette(style: String) -> Dictionary:
	var colors: Array = {
		"humans": ["6d715a","969982","3c4540","a99b6e","4d9c8c"],
		"iron_synod": ["4e485a","7a7183","252a30","867d91","a75d91"],
		"kharuun": ["6b7546","a3a96a","4b4130","b7a06b","acc174"],
		"heavenly_host": ["c8c7ac","ece8cf","747e7b","b49d64","e1cf8b"],
		"infernal_legion": ["4e4040","8a6656","25292b","a48a67","c3693d"],
		"veyr": ["56727e","abc6c1","354356","8f8fa6","74b6c5"]
	}.get(style,["6d715a","969982","3c4540","a99b6e","4d9c8c"])
	return {"armor":material(style+"armor",Color(colors[0]),.35),"edge":material(style+"edge",Color(colors[1]),.45),"dark":material(style+"dark",Color(colors[2]),.25),"trim":material(style+"trim",Color(colors[3]),.5),"energy":material(style+"energy",Color(colors[4]),.25,.65),"glass":material(style+"glass",Color("223a3e"),.7),"rubber":material("rubber",Color("242b2a"),.03),"concrete":material("concrete",Color("626359"),.02)}

static func build(style: String, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = style+"_"+kind
	var p: Dictionary = palette(style)
	if kind in ["outpost", "sentry", "bastion", "workshop", "sanctum", "arsenal", "reactor", "relay"]:
		_expanded_building(root, style, kind, p)
	elif kind not in ["worker", "infantry", "tank", "hq", "power", "refinery", "barracks", "factory"]:
		_expanded_unit(root, style, kind, p)
	elif bool(DATA.spec(kind).building):
		if style=="humans": _human_building(root,kind,p)
		elif style=="iron_synod": _synod_building(root,kind,p)
		else: _other_building(root,style,kind,p)
	elif style=="humans": _human_unit(root,kind,p)
	elif style=="iron_synod": _synod_unit(root,kind,p)
	else: _other_unit(root,style,kind,p)
	return root

static func _mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, bevel: float = 0.0) -> MeshInstance3D:
	if bevel <= 0.01:
		var shape := BoxMesh.new()
		shape.size = size
		return _mesh(parent,shape,pos,mat)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius: float = minf(bevel,minf(size.x,minf(size.y,size.z))*.22)
	var rings: Array[PackedVector3Array] = []
	for level: int in range(4):
		var y: float = [-size.y*.5,-size.y*.5+radius,size.y*.5-radius,size.y*.5][level]
		var inset: float = radius if level==0 or level==3 else 0.0
		var x: float = size.x*.5-inset
		var z: float = size.z*.5-inset
		var cut: float = radius*.6
		rings.append(PackedVector3Array([Vector3(-x+cut,y,-z),Vector3(x-cut,y,-z),Vector3(x,y,-z+cut),Vector3(x,y,z-cut),Vector3(x-cut,y,z),Vector3(-x+cut,y,z),Vector3(-x,y,z-cut),Vector3(-x,y,-z+cut)]))
	for level: int in range(3):
		for i: int in range(8):
			_quad(st,rings[level][i],rings[level][(i+1)%8],rings[level+1][(i+1)%8],rings[level+1][i])
	for i: int in range(8):
		_tri(st,Vector3(0,size.y*.5,0),rings[3][i],rings[3][(i+1)%8],Vector3.UP)
		_tri(st,Vector3(0,-size.y*.5,0),rings[0][i],rings[0][(i+1)%8],Vector3.DOWN)
	return _mesh(parent,st.commit(),pos,mat)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c+d)*.25)<0: normal = -normal
	_tri(st,a,b,c,normal)
	_tri(st,a,c,d,normal)

static func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3) -> void:
	for entry: Array in [[a,Vector2(0,0)],[b,Vector2(1,0)],[c,Vector2(1,1)]]:
		st.set_normal(normal)
		st.set_uv(entry[1])
		st.add_vertex(entry[0])

static func _sphere(parent: Node3D,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 1
	shape.height = 2
	shape.radial_segments = 16
	shape.rings = 8
	var node: MeshInstance3D = _mesh(parent,shape,pos,mat)
	node.scale = size*.5
	return node

static func _cylinder(parent: Node3D,pos: Vector3,radius: float,height: float,mat: Material,top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top<0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	shape.rings = 1
	return _mesh(parent,shape,pos,mat)

static func _rod(parent: Node3D,a: Vector3,b: Vector3,radius: float,mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = _cylinder(parent,(a+b)*.5,radius,a.distance_to(b),mat)
	var direction: Vector3 = (b-a).normalized()
	var up: Vector3 = Vector3.RIGHT if absf(direction.dot(Vector3.UP))>.98 else Vector3.UP
	node.basis = Basis.looking_at(direction,up) * Basis(Vector3.RIGHT,PI*.5)
	return node

static func _vent(parent: Node3D,pos: Vector3,width: float,depth: float,p: Dictionary) -> void:
	_box(parent,pos,Vector3(width,1,depth),p.dark)
	for i: int in range(6):
		_box(parent,pos+Vector3(0,.8,-depth*.4+depth*.16*i),Vector3(width*.88,.6,.6),p.edge)

static func _fan(parent: Node3D,pos: Vector3,radius: float,p: Dictionary) -> void:
	_cylinder(parent,pos,radius,1.4,p.dark)
	for i: int in range(4):
		var node: MeshInstance3D = _box(parent,pos+Vector3(0,1,0),Vector3(radius*1.6,.6,1.4),p.armor)
		node.rotation.y = float(i)*PI*.5+.3
	_cylinder(parent,pos+Vector3(0,1.5,0),radius*.17,1.2,p.edge)

static func _window(parent: Node3D,pos: Vector3,width: float,p: Dictionary) -> void:
	_box(parent,pos,Vector3(width,2.8,.9),p.dark)
	_box(parent,pos+Vector3(0,0,.55),Vector3(width*.78,1.6,.3),p.glass)
	for side: float in [-1.0,1.0]:
		_box(parent,pos+Vector3(side*width*.35,0,.8),Vector3(.5,2,.4),p.edge)

static func _human_unit(root: Node3D,kind: String,p: Dictionary) -> void:
	# Static hover vehicles conceal the operator's legs and need no locomotion cycle.
	if kind=="infantry":
		# Open command saddle: the operator's exposed head and upper body remain
		# above the low cockpit rim in every directional frame. Legs stay inside.
		var skin: StandardMaterial3D = material("human_operator_skin",Color("c6a17b"),.02)
		_box(root,Vector3(0,10,0),Vector3(14,5,25),p.dark,1.7)
		_box(root,Vector3(0,11,13),Vector3(8,3,10),p.armor,1)
		_box(root,Vector3(0,13,0),Vector3(17,3.5,22),p.armor,1.6)
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*7.5,16,-1),Vector3(2,4,13),p.armor,.6)
		_box(root,Vector3(0,16,-7),Vector3(11,5,3),p.armor,.7)
		_box(root,Vector3(0,17,-2),Vector3(7,3,6),p.dark,.7)
		_box(root,Vector3(0,21,-4),Vector3(7,7,2),p.dark,.7)
		_box(root,Vector3(0,23.5,-1),Vector3(6.5,8,4.5),p.armor,1)
		_box(root,Vector3(0,26.5,1.4),Vector3(4.8,1,1.2),p.trim,.2)
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*4,24,-.5),Vector3(2.7,3.2,4.2),p.armor,.6)
			_rod(root,Vector3(side*4,23,1),Vector3(side*3.5,20.5,5),1.1,p.armor)
			_sphere(root,Vector3(side*3.4,20.3,5.7),Vector3(2,2,2),skin)
		_box(root,Vector3(0,19.2,5),Vector3(8,2,4),p.dark,.5)
		_box(root,Vector3(0,20.3,5.2),Vector3(4.8,.3,1.5),p.glass)
		_sphere(root,Vector3(0,29.8,-.5),Vector3(6.1,6.5,5.8),skin)
		_box(root,Vector3(0,29.6,2.5),Vector3(3.5,3.3,.7),skin,.2)
		_box(root,Vector3(0,33,-.8),Vector3(7,2.6,6.8),p.armor,.8)
		_box(root,Vector3(0,31,-3.1),Vector3(6.5,3.5,1.4),p.armor,.4)
		_box(root,Vector3(0,31.8,2.7),Vector3(6.6,.7,1.8),p.dark,.2)
		_box(root,Vector3(0,30.1,3),Vector3(3.3,.4,.3),p.dark)
		# The light weapon is fixed to the vehicle, separate from the seated person.
		_box(root,Vector3(8.4,16.2,4),Vector3(3.2,3.5,6),p.dark,.5)
		_rod(root,Vector3(8.4,16.2,6),Vector3(8.4,16.2,16),.75,p.edge)
		_box(root,Vector3(-6.4,16.3,6.5),Vector3(.7,.8,.7),p.energy)
		_vent(root,Vector3(0,15.2,-7.5),7,3,p)
		return
	var tank: bool = kind=="tank"
	if tank:
		# One swept armored hull above a recessed lift keel, without tread pods.
		_paladin_hull(root,p)
		_box(root,Vector3(0,15.8,6),Vector3(17,1.2,12),p.edge,.5)
		_cylinder(root,Vector3(0,17,-2),8.5,2,p.dark)
		_box(root,Vector3(0,22,-2),Vector3(21,9,18),p.armor,1.8)
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*12,17,5),Vector3(5,3,11),p.edge,.7)
		_box(root,Vector3(0,22.5,10),Vector3(6.5,4,11),p.armor,1)
		_rod(root,Vector3(0,22,10),Vector3(0,22,29),1.1,p.edge)
		_box(root,Vector3(0,22,30),Vector3(4,3,3),p.dark,.4)
		_cylinder(root,Vector3(-3,25,-4),3.6,1.2,p.dark)
		_cylinder(root,Vector3(-3,26,-4),2.6,.6,p.edge)
		_vent(root,Vector3(0,18,-10),13,7,p)
		for side: float in [-1.0,1.0]:
			# Small inset lift slots and rear thrusters read as machinery, not belts.
			_box(root,Vector3(side*15.4,8.8,-1),Vector3(.7,1.4,12),p.dark,.2)
			_box(root,Vector3(side*15.8,8.8,-1),Vector3(.3,.55,8),p.energy)
			_box(root,Vector3(side*9,11,-18),Vector3(7,3,2),p.dark,.5)
			_box(root,Vector3(side*9,11,-19.1),Vector3(4,.8,.25),p.energy)
			_box(root,Vector3(side*10,15,7),Vector3(3,.7,5),p.armor,.3)
			_box(root,Vector3(side*10,15.5,10),Vector3(2,.5,1),p.trim)
			_box(root,Vector3(side*9,21,0),Vector3(1,3,10),p.dark,.2)
			_box(root,Vector3(side*9.8,21,1),Vector3(.5,1.2,5),p.energy)
		_rod(root,Vector3(6,24,-7),Vector3(6,33,-7),.35,p.edge)
	else:
		# Squat continuous utility barge, open cargo well and asymmetric harvesting crane.
		_box(root,Vector3(0,10,0),Vector3(27,7,27),p.armor,2.1)
		_box(root,Vector3(0,6.5,0),Vector3(23,1.5,24),p.dark,.8)
		_box(root,Vector3(-6,17,7),Vector3(11,10,10),p.armor,1)
		_window(root,Vector3(-6,19,12.2),8,p)
		_box(root,Vector3(1,14,-6),Vector3(19,2,13),p.dark,.5)
		for x: float in [-9.0,11.0]:
			_box(root,Vector3(x,18,-6),Vector3(2,8,15),p.trim,.3)
		_box(root,Vector3(1,18,-13),Vector3(21,8,2),p.armor,.4)
		_box(root,Vector3(1,18,1),Vector3(21,8,2),p.armor,.4)
		_rod(root,Vector3(11,14,5),Vector3(14,25,7),1.5,p.trim)
		_rod(root,Vector3(14,25,7),Vector3(14,24,16),1.1,p.edge)
		_rod(root,Vector3(14,24,16),Vector3(14,16,17),.7,p.dark)
		_box(root,Vector3(14,15,17),Vector3(6,2,5),p.dark,.5)
		_box(root,Vector3(-11,13,-7),Vector3(1,2,8),p.energy,.2)

static func _paladin_hull(root: Node3D,p: Dictionary) -> void:
	var outline := PackedVector2Array([Vector2(-.65,-1),Vector2(.65,-1),Vector2(1,-.65),Vector2(1,.45),Vector2(.5,1),Vector2(-.5,1),Vector2(-1,.45),Vector2(-1,-.65)])
	var rings: Array[PackedVector3Array] = []
	for profile: Vector3 in [Vector3(12.5,7,14.5),Vector3(17,10,18),Vector3(14,15,16)]:
		var ring := PackedVector3Array()
		for point: Vector2 in outline:
			ring.append(Vector3(point.x*profile.x,profile.y,point.y*profile.z))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level: int in range(2):
		for index: int in range(8):
			_quad(surface,rings[level][index],rings[level][(index+1)%8],rings[level+1][(index+1)%8],rings[level+1][index])
	for index: int in range(8):
		_tri(surface,Vector3(0,15,0),rings[2][index],rings[2][(index+1)%8],Vector3.UP)
		_tri(surface,Vector3(0,7,0),rings[0][index],rings[0][(index+1)%8],Vector3.DOWN)
	_mesh(root,surface.commit(),Vector3.ZERO,p.armor)
	_box(root,Vector3(0,6.7,-1),Vector3(22,1.6,25),p.dark,1)

static func _synod_unit(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="worker":
		# Open crescent utility shell wraps a distinct upright cargo reservoir.
		_sphere(root,Vector3(0,12,-3),Vector3(23,10,24),p.dark)
		for side: float in [-1.0,1.0]:
			_sphere(root,Vector3(side*9,16,-4),Vector3(8,10,22),p.armor)
			_rod(root,Vector3(side*9,15,3),Vector3(side*12,12,12),1.4,p.edge)
			_rod(root,Vector3(side*12,12,12),Vector3(side*8,10,16),.9,p.trim)
		_sphere(root,Vector3(0,20,-7),Vector3(11,19,11),p.armor)
		for y: float in [14.0,20.0,26.0]: _cylinder(root,Vector3(0,y,-7),5.8,1.1,p.edge)
		_sphere(root,Vector3(0,28,-7),Vector3(6,4,6),p.energy)
		_box(root,Vector3(0,13,6),Vector3(10,4,9),p.dark,1)
		return
	if kind=="infantry":
		# Tall single armored sentinel; its tapered lower shell never splits into legs.
		_cylinder(root,Vector3(0,12,0),2,11,p.dark,5)
		_sphere(root,Vector3(0,21,0),Vector3(13,18,11),p.dark)
		_box(root,Vector3(0,23,2),Vector3(12,12,8),p.armor,1.8)
		_sphere(root,Vector3(0,31,0),Vector3(7,6,7),p.edge)
		_box(root,Vector3(0,31,3.8),Vector3(5,1.3,.6),p.energy)
		for side: float in [-1.0,1.0]:
			_sphere(root,Vector3(side*7,24,-1),Vector3(6,7,8),p.armor)
			_rod(root,Vector3(side*4,29,-3),Vector3(side*6,35,-6),.6,p.edge)
		_sphere(root,Vector3(8,21,6),Vector3(6,6,12),p.armor)
		_rod(root,Vector3(8,21,8),Vector3(8,21,18),1.3,p.dark)
		_sphere(root,Vector3(8,21,18),Vector3(2,2,1),p.energy)
		return
	# Wide living assault hull, turret and crystalline shoulder armor.
	_sphere(root,Vector3(0,13,0),Vector3(36,16,35),p.dark)
	_sphere(root,Vector3(0,18,-2),Vector3(32,13,28),p.armor)
	for side: float in [-1.0,1.0]:
		_sphere(root,Vector3(side*16,16,-2),Vector3(9,11,27),p.armor)
		var shard: MeshInstance3D = _prism(root,Vector3(side*14,26,-8),3.8,17,p.edge,5)
		shard.rotation.z = -side*.35
		for z: float in [-10.0,0.0,10.0]:
			_rod(root,Vector3(side*9,22,z-3),Vector3(side*18,17,z+1),1,p.trim)
	_sphere(root,Vector3(0,25,0),Vector3(18,12,19),p.dark)
	_box(root,Vector3(0,27,2),Vector3(15,6,16),p.armor,2)
	_sphere(root,Vector3(0,27,13),Vector3(9,8,17),p.armor)
	_rod(root,Vector3(0,27,16),Vector3(0,27,29),1.8,p.dark)
	_ring(root,Vector3(0,27,29),2.8,.7,p.edge,true)
	_sphere(root,Vector3(0,27,29),Vector3(2.4,2.4,1),p.energy)

static func _human_building(root: Node3D,kind: String,p: Dictionary) -> void:
	var size: Vector2 = Vector2(DATA.spec(kind).size)*.87
	_box(root,Vector3(0,2,0),Vector3(size.x,4,size.y),p.concrete,1.4)
	if kind=="hq":
		# Asymmetric control tower and low communications wings.
		_box(root,Vector3(-16,13,0),Vector3(68,22,53),p.armor,2)
		_box(root,Vector3(31,10,3),Vector3(27,16,48),p.armor,1.8)
		_box(root,Vector3(-18,33,-8),Vector3(29,27,27),p.dark,2)
		_box(root,Vector3(-18,41,-8),Vector3(38,11,33),p.armor,2)
		for x: float in [-30.0,-18.0,-6.0]:
			_window(root,Vector3(x,41,9),9,p)
		_box(root,Vector3(-18,48,-8),Vector3(42,3,37),p.edge,1)
		_rod(root,Vector3(-29,49,-18),Vector3(-29,59,-18),.6,p.edge)
		var dish: MeshInstance3D = _cylinder(root,Vector3(30,25,-5),10,2,p.dark)
		dish.rotation.z = -.65
		_cylinder(root,Vector3(30,20,-5),2,12,p.trim)
		_vent(root,Vector3(-2,25,2),17,20,p)
		_box(root,Vector3(0,10,28),Vector3(16,14,2),p.dark)
		_box(root,Vector3(0,18,29),Vector3(19,1.5,1),p.energy)
		for x: float in [-38.0,34.0]:
			_window(root,Vector3(x,13,28),14,p)
	elif kind=="power":
		# Exposed twin finned reactor stacks, with no enclosing hall.
		_box(root,Vector3(0,7,0),Vector3(46,8,43),p.dark,2)
		for x: float in [-13.0,13.0]:
			_cylinder(root,Vector3(x,27,-4),9,37,p.armor)
			for y: float in [13.0,20.0,27.0,34.0,41.0]:
				_cylinder(root,Vector3(x,y,-4),11,2,p.edge)
			_cylinder(root,Vector3(x,47,-4),8,3,p.dark)
			_cylinder(root,Vector3(x,15,-4),11.2,1.2,p.energy)
			_rod(root,Vector3(x,20,3),Vector3(x,8,20),2.3,p.dark)
		_box(root,Vector3(0,9,18),Vector3(43,9,9),p.armor,1)
		_vent(root,Vector3(0,14,18),18,6,p)
	elif kind=="refinery":
		# Tall storage vessels flank a visibly open vehicle intake.
		_box(root,Vector3(-24,16,-14),Vector3(29,25,35),p.armor,2)
		_fan(root,Vector3(-24,29,-15),9,p)
		for z: float in [-19.0,9.0]:
			_cylinder(root,Vector3(20,22,z),12,35,p.armor)
			_cylinder(root,Vector3(20,40,z),11.5,2,p.edge)
			for y: float in [9.0,26.0]:
				_cylinder(root,Vector3(20,y,z),12.5,1.5,p.dark)
			_rod(root,Vector3(-8,22,z),Vector3(20,22,z),2,p.dark)
		_box(root,Vector3(-8,5,28),Vector3(44,4,28),p.dark,.6)
		for x: float in [-31.0,15.0]:
			_box(root,Vector3(x,10,28),Vector3(4,13,28),p.armor,.7)
		for i: int in range(7):
			_box(root,Vector3(-24+i*5,7.5,32),Vector3(2.7,.6,17),p.trim)
		_window(root,Vector3(-24,21,4),16,p)
	elif kind=="barracks":
		# Low segmented training hall; deliberately no central tower.
		_box(root,Vector3(0,11,-2),Vector3(76,17,35),p.armor,2)
		for x: float in [-25.0,0.0,25.0]:
			_box(root,Vector3(x,21,-2),Vector3(22,4,38),p.edge,.7)
			_vent(root,Vector3(x,23.5,-7),14,13,p)
		for x: float in [-25.0,25.0]:
			_window(root,Vector3(x,13,16),13,p)
		_box(root,Vector3(0,10,17),Vector3(12,14,2),p.dark)
		_box(root,Vector3(0,18,18),Vector3(15,1,1),p.energy)
		for x: float in [-25.0,25.0]:
			_box(root,Vector3(x,5,22),Vector3(13,6,7),p.dark,.6)
			_box(root,Vector3(x,8,22),Vector3(11,1,5),p.trim)
	else:
		# Open-sided machine hall with a prominent bridge crane.
		_box(root,Vector3(0,5,0),Vector3(96,6,65),p.dark,1.4)
		_box(root,Vector3(-33,19,-6),Vector3(26,29,51),p.armor,2)
		_box(root,Vector3(36,15,-8),Vector3(18,22,47),p.armor,1.3)
		_box(root,Vector3(3,37,-14),Vector3(90,8,28),p.edge,1.8)
		_box(root,Vector3(3,19,2),Vector3(40,26,1),p.dark)
		for y: int in range(8):
			_box(root,Vector3(3,8+y*3,3),Vector3(38,.7,.8),p.armor)
		for x: float in [-21.0,27.0]:
			_box(root,Vector3(x,19,23),Vector3(5,34,5),p.edge,.6)
		_box(root,Vector3(3,41,23),Vector3(61,6,7),p.trim,.8)
		_box(root,Vector3(10,36,23),Vector3(10,5,10),p.dark,.7)
		_rod(root,Vector3(10,34,23),Vector3(10,22,23),.6,p.dark)
		_rod(root,Vector3(10,22,23),Vector3(14,20,23),.6,p.trim)
		_fan(root,Vector3(-33,34,-9),9,p)
		for x: int in range(8):
			_box(root,Vector3(-15+x*5,8.5,24),Vector3(2,1,16),p.trim)

static func _synod_building(root: Node3D,kind: String,p: Dictionary) -> void:
	var size: Vector2 = Vector2(DATA.spec(kind).size)*.8
	_box(root,Vector3(0,2,0),Vector3(size.x,4,size.y),p.dark,3)
	if kind=="hq":
		# Central neural brain raised above four organic buttresses.
		_sphere(root,Vector3(0,24,-4),Vector3(59,39,45),p.armor)
		_sphere(root,Vector3(0,43,-4),Vector3(26,14,23),p.edge)
		_sphere(root,Vector3(0,47,0),Vector3(12,7,11),p.energy)
		for side: float in [-1.0,1.0]:
			for z: float in [-21.0,21.0]:
				_sphere(root,Vector3(side*39,8,z),Vector3(20,12,18),p.dark)
				_rod(root,Vector3(side*14,33,z*.45),Vector3(side*40,7,z),3.5,p.edge)
			_rod(root,Vector3(side*18,34,-9),Vector3(side*26,56,-15),1.1,p.edge)
			_sphere(root,Vector3(side*26,56,-15),Vector3(4,4,4),p.energy)
		_sphere(root,Vector3(0,9,25),Vector3(25,13,16),p.dark)
	elif kind=="power":
		# A single tall reactor spine ringed by three exposed coils.
		_cylinder(root,Vector3(0,26,0),7,47,p.dark)
		for y: float in [13.0,25.0,37.0]:
			_ring(root,Vector3(0,y,0),17,3,p.armor)
			_ring(root,Vector3(0,y+2,0),15.5,1,p.edge)
		_sphere(root,Vector3(0,49,0),Vector3(15,13,15),p.energy)
		for i: int in range(3):
			var angle: float = TAU*float(i)/3
			var pos := Vector3(cos(angle)*21,7,sin(angle)*21)
			_sphere(root,pos,Vector3(12,10,12),p.armor)
			_rod(root,pos,Vector3(0,23,0),2.5,p.edge)
	elif kind=="refinery":
		# Bulbous digestion vats and a wide, low intake mouth.
		for x: float in [-23.0,23.0]:
			_sphere(root,Vector3(x,22,-16),Vector3(30,38,28),p.armor)
			_cylinder(root,Vector3(x,17,-16),15.5,3,p.dark)
			_sphere(root,Vector3(x,39,-15),Vector3(7,5,7),p.energy)
			_rod(root,Vector3(x,29,-10),Vector3(0,15,19),3,p.edge)
		_sphere(root,Vector3(0,10,24),Vector3(52,16,29),p.dark)
		_box(root,Vector3(0,9,36),Vector3(32,10,2),p.rubber,.7)
		for x: float in [-18.0,-9.0,0.0,9.0,18.0]:
			_rod(root,Vector3(x,15,30),Vector3(x,17,38),.9,p.trim)
	elif kind=="barracks":
		# Separate augmentation capsules expose gaps between each bay.
		_sphere(root,Vector3(0,7,-6),Vector3(75,9,20),p.dark)
		for x: float in [-27.0,-9.0,9.0,27.0]:
			_sphere(root,Vector3(x,16,2),Vector3(13,24,20),p.armor)
			_rod(root,Vector3(x,7,-12),Vector3(x,25,-3),1.6,p.edge)
			_sphere(root,Vector3(x,16,11),Vector3(4,11,3),p.energy)
			_sphere(root,Vector3(x,7,12),Vector3(14,5,12),p.dark)
	else:
		# An open ribcage cradle, not a larger sealed barracks shell.
		_box(root,Vector3(0,5,0),Vector3(91,6,61),p.dark,2)
		for x: float in [-35.0,-18.0,0.0,18.0,35.0]:
			_arch(root,Vector3(x,6,-4),48,31,2.7,p.armor,true)
			_sphere(root,Vector3(x,7,25),Vector3(9,8,9),p.edge)
		_sphere(root,Vector3(0,9,3),Vector3(47,9,30),p.dark)
		for side: float in [-1.0,1.0]:
			_rod(root,Vector3(side*44,8,-22),Vector3(side*39,42,-13),3,p.edge)
			_rod(root,Vector3(side*39,42,-13),Vector3(side*17,35,0),2,p.armor)
			_sphere(root,Vector3(side*17,35,0),Vector3(5,5,5),p.energy)

static func _other_unit(root: Node3D,style: String,kind: String,p: Dictionary) -> void:
	match style:
		"kharuun": _plant_mobile(root,kind,p)
		"heavenly_host": _host_mobile(root,kind,p)
		"infernal_legion": _infernal_mobile(root,kind,p)
		_: _veyr_mobile(root,kind,p)

static func _plant_mobile(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="worker":
		# Hanging gourd basket and two short collecting vines, without root-legs.
		_sphere(root,Vector3(0,14,0),Vector3(18,17,18),p.dark)
		_sphere(root,Vector3(0,15,0),Vector3(16,15,16),p.trim)
		for i: int in range(6):
			var a: float = TAU*float(i)/6
			_rod(root,Vector3(cos(a)*6,7,sin(a)*6),Vector3(cos(a)*9,19,sin(a)*9),1,p.armor)
		_ring(root,Vector3(0,21,0),8.5,1.6,p.dark)
		_sphere(root,Vector3(0,21,0),Vector3(10,2,10),p.energy)
		_leaf(root,Vector3(-4,25,-2),Vector3(16,3,8),p,.45)
		for side: float in [-1.0,1.0]:
			_rod(root,Vector3(side*7,19,4),Vector3(side*12,15,9),1.1,p.dark)
			_leaf(root,Vector3(side*12,15,10),Vector3(7,2,5),p,side*.7)
	elif kind=="infantry":
		# An upright bark shield, branch crest and fixed forward thorn weapon.
		_cylinder(root,Vector3(0,15,0),2,17,p.dark,5.5)
		var shield: MeshInstance3D = _box(root,Vector3(0,22,2),Vector3(13,18,7),p.armor,2)
		shield.rotation.z = -.12
		for x: float in [-4.0,0.0,4.0]: _rod(root,Vector3(x,14,6),Vector3(x,30,5),.8,p.dark)
		_sphere(root,Vector3(0,30,0),Vector3(7,6,7),p.dark)
		_sphere(root,Vector3(0,30,4),Vector3(3,1.5,1),p.energy)
		for x: float in [-6.0,0.0,6.0]:
			var thorn: MeshInstance3D = _prism(root,Vector3(x,31,-2),2,9,p.trim,5)
			thorn.rotation.z = -x*.06
		_rod(root,Vector3(7,22,3),Vector3(9,22,15),1.8,p.dark)
		_prism(root,Vector3(9,24,14),2,6,p.trim,5)
	else:
		# Horizontal pinecone artillery: overlapping seed armor and an open trumpet.
		_sphere(root,Vector3(0,16,-2),Vector3(30,20,34),p.dark)
		for z: float in [-12.0,-3.0,6.0]:
			for side: float in [-1.0,1.0]:
				var scale_plate: MeshInstance3D = _sphere(root,Vector3(side*10,21,z),Vector3(13,5,13),p.armor)
				scale_plate.rotation.z = side*.35
			_prism(root,Vector3(0,28,z),3,10,p.trim,5)
		var trumpet: MeshInstance3D = _cylinder(root,Vector3(0,24,18),4.5,20,p.armor,8)
		trumpet.rotation.x = PI*.5
		var mouth: MeshInstance3D = _cylinder(root,Vector3(0,24,28.1),6.3,1,p.dark)
		mouth.rotation.x = PI*.5
		_sphere(root,Vector3(0,24,28.6),Vector3(5,5,1),p.trim)
		for side: float in [-1.0,1.0]:
			_leaf(root,Vector3(side*16,16,-8),Vector3(10,3,23),p,side*.4)

static func _host_mobile(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="worker":
		# Bell-shaped floating robe with tool staff; no frontline wing silhouette.
		_cylinder(root,Vector3(0,14,0),8,17,p.armor,3.5)
		_ring(root,Vector3(0,6,0),7.5,1,p.trim)
		_sphere(root,Vector3(0,25,0),Vector3(6,7,6),p.edge)
		_box(root,Vector3(0,20,4),Vector3(5,7,1),p.trim,.3)
		_ring(root,Vector3(0,31,0),5,1,p.trim)
		_rod(root,Vector3(8,10,3),Vector3(8,28,3),.7,p.trim)
		_ring(root,Vector3(8,29,3),2.3,.6,p.edge,true)
		_box(root,Vector3(-7,19,3),Vector3(4,6,3),p.edge,.4)
		_box(root,Vector3(-7,22.5,3),Vector3(5,.8,4),p.trim)
	elif kind=="infantry":
		# Armored tapered spirit, tall shield and fixed swept wings.
		_cylinder(root,Vector3(0,13,0),1,15,p.dark,4.5)
		_box(root,Vector3(0,23,0),Vector3(10,13,7),p.armor,1.4)
		_sphere(root,Vector3(0,32,0),Vector3(6,6,6),p.edge)
		_ring(root,Vector3(0,36,0),5.2,.8,p.trim)
		for side: float in [-1.0,1.0]:
			for feather: int in range(4):
				var wing: MeshInstance3D = _box(root,Vector3(side*(7+feather*2.4),25+feather*1.1,-4),Vector3(2.5,12-feather,2),p.edge,.4)
				wing.rotation.z = -side*(.5+feather*.08)
		_box(root,Vector3(-7,21,6),Vector3(7,14,2),p.trim,.8)
		_box(root,Vector3(-7,22,7.2),Vector3(4,10,.5),p.armor,.2)
		_rod(root,Vector3(8,10,4),Vector3(8,32,4),.7,p.trim)
		_prism(root,Vector3(8,34,4),1.7,5,p.edge,4)
	else:
		# A broad reliquary construct with heavy fixed wing shoulders, not a giant person.
		_prism(root,Vector3(0,12,0),14,10,p.dark,6,17)
		_box(root,Vector3(0,21,0),Vector3(27,12,24),p.armor,2)
		_box(root,Vector3(0,29,-2),Vector3(18,9,16),p.edge,1)
		_prism(root,Vector3(0,37,-2),7,10,p.trim,4)
		_sphere(root,Vector3(0,26,12),Vector3(10,10,4),p.energy)
		_ring(root,Vector3(0,27,15),7.5,1.3,p.trim,true)
		for side: float in [-1.0,1.0]:
			for feather: int in range(4):
				var wing: MeshInstance3D = _box(root,Vector3(side*(16+feather*2.6),27+feather*1.5,-3),Vector3(3,17-feather*2,5),p.armor,.5)
				wing.rotation.z = -side*.6
			_box(root,Vector3(side*15,22,8),Vector3(7,8,10),p.trim,.8)

static func _infernal_mobile(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="worker":
		# Compact ash urn and suspended tool tongs; no armored soldier body.
		_sphere(root,Vector3(0,14,0),Vector3(18,17,16),p.dark)
		_cylinder(root,Vector3(0,20,0),8,5,p.armor,6)
		_ring(root,Vector3(0,23,0),6,1.3,p.trim)
		_cylinder(root,Vector3(0,23,0),3.8,1,p.energy)
		for side: float in [-1.0,1.0]:
			var horn: MeshInstance3D = _prism(root,Vector3(side*6,24,-3),1.5,7,p.trim,5)
			horn.rotation.z = -side*.5
			_rod(root,Vector3(side*7,18,3),Vector3(side*11,14,10),1.2,p.armor)
			_rod(root,Vector3(side*11,14,10),Vector3(side*7,12,14),.7,p.trim)
	elif kind=="infantry":
		# Narrow blade-bearing fiend tapering to one suspended spirit point.
		_cylinder(root,Vector3(0,12,0),0,14,p.dark,4.5)
		_box(root,Vector3(0,22,0),Vector3(10,13,7),p.armor,1.6)
		_sphere(root,Vector3(0,31,0),Vector3(6,7,6),p.dark)
		for side: float in [-1.0,1.0]:
			var horn: MeshInstance3D = _prism(root,Vector3(side*4,34,-1),1.6,9,p.trim,5)
			horn.rotation.z = -side*.45
			_prism(root,Vector3(side*7,25,0),2.7,8,p.dark,5)
			_sphere(root,Vector3(side*1.8,32,3),Vector3(1.1,1,.6),p.energy)
		var blade: MeshInstance3D = _box(root,Vector3(10,23,7),Vector3(2.5,20,3.5),p.trim,.5)
		blade.rotation.z = -.25
		_box(root,Vector3(10,16,7),Vector3(8,1.5,3),p.dark,.3)
		_box(root,Vector3(0,22,4),Vector3(1.5,8,.6),p.energy)
	else:
		# Huge jaw and armored shoulders above a single hovering furnace hull.
		_sphere(root,Vector3(0,12,0),Vector3(34,13,30),p.dark)
		_box(root,Vector3(0,23,-2),Vector3(25,18,20),p.armor,2.4)
		_sphere(root,Vector3(0,33,6),Vector3(18,13,16),p.dark)
		_box(root,Vector3(0,29,13),Vector3(17,6,9),p.trim,1)
		_box(root,Vector3(0,33,14),Vector3(12,3,1),p.dark)
		for side: float in [-1.0,1.0]:
			_sphere(root,Vector3(side*17,24,-1),Vector3(12,13,17),p.armor)
			var horn: MeshInstance3D = _prism(root,Vector3(side*10,39,1),3.2,16,p.trim,5)
			horn.rotation.z = -side*.45
			_prism(root,Vector3(side*19,30,-4),3,10,p.dark,5)
			_sphere(root,Vector3(side*4,35,13),Vector3(2.5,1.8,1),p.energy)
		_box(root,Vector3(0,21,10),Vector3(12,8,1),p.dark,.6)
		for x: float in [-4.0,0.0,4.0]: _box(root,Vector3(x,21,11),Vector3(1.4,6,.5),p.energy)

static func _veyr_mobile(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="worker":
		# Asymmetric tool crystal with a separate collection ring.
		_prism(root,Vector3(-3,18,-2),6,18,p.armor,5)
		_prism(root,Vector3(-3,9,-2),0,8,p.edge,5,6)
		var tool: MeshInstance3D = _prism(root,Vector3(7,15,5),3,12,p.trim,4)
		tool.rotation.z = -.6
		_ring(root,Vector3(7,21,5),4.5,.8,p.edge,true)
		_prism(root,Vector3(-9,14,2),2,8,p.edge,4)
		_sphere(root,Vector3(7,21,5),Vector3(3,3,3),p.energy)
	elif kind=="infantry":
		# Tall flat shield prism with split lateral fins and a focused emitter.
		var shield: MeshInstance3D = _prism(root,Vector3(0,23,0),8,27,p.armor,4)
		shield.scale = Vector3(1,1,.5)
		var lower: MeshInstance3D = _prism(root,Vector3(0,10,0),0,12,p.edge,4,8)
		lower.scale = Vector3(1,1,.5)
		for side: float in [-1.0,1.0]:
			var fin: MeshInstance3D = _prism(root,Vector3(side*10,22,-1),2.5,16,p.trim,4)
			fin.rotation.z = -side*.25
		_rod(root,Vector3(5,22,3),Vector3(7,22,15),1,p.dark)
		_prism(root,Vector3(7,22,15),2,4,p.energy,4)
	else:
		# Low broad monolith vessel with a protected core and a forward resonator.
		_prism(root,Vector3(0,12,0),20,12,p.dark,6,17)
		_prism(root,Vector3(0,19,-2),15,8,p.armor,6,12)
		_prism(root,Vector3(0,28,-3),8,20,p.edge,5)
		for side: float in [-1.0,1.0]:
			var shoulder: MeshInstance3D = _prism(root,Vector3(side*15,20,-3),5,17,p.armor,4)
			shoulder.rotation.z = -side*.2
			_rod(root,Vector3(side*13,17,2),Vector3(side*9,21,14),1,p.trim)
		var emitter: MeshInstance3D = _prism(root,Vector3(0,23,17),4,19,p.trim,6,2)
		emitter.rotation.x = PI*.5
		_sphere(root,Vector3(0,23,27),Vector3(4,4,1),p.energy)

static func _other_building(root: Node3D,style: String,kind: String,p: Dictionary) -> void:
	match style:
		"kharuun": _kharuun_building(root,kind,p)
		"heavenly_host": _host_building(root,kind,p)
		"infernal_legion": _infernal_building(root,kind,p)
		_: _veyr_building(root,kind,p)

# These forms are baked once; none of the architectural detail runs per frame.
static func _ring(root: Node3D,pos: Vector3,radius: float,thickness: float,mat: Material,vertical: bool = false) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-thickness
	mesh.outer_radius = radius
	mesh.rings = 20
	mesh.ring_segments = 6
	var node: MeshInstance3D = _mesh(root,mesh,pos,mat)
	if vertical: node.rotation.x = PI*.5

static func _prism(root: Node3D,pos: Vector3,radius: float,height: float,mat: Material,segments: int = 5,top: float = 0.0) -> MeshInstance3D:
	var node: MeshInstance3D = _cylinder(root,pos,radius,height,mat,top)
	node.mesh.radial_segments = segments
	return node

static func _arch(root: Node3D,pos: Vector3,width: float,height: float,thickness: float,mat: Material,across_z: bool = false) -> void:
	var previous: Vector3
	for i: int in range(9):
		var angle: float = PI*float(i)/8
		var point := Vector3(cos(angle)*width*.5,sin(angle)*height,0)
		if across_z: point = Vector3(0,point.y,point.x)
		if i>0: _rod(root,pos+previous,pos+point,thickness,mat)
		previous = point

static func _leaf(root: Node3D,pos: Vector3,size: Vector3,p: Dictionary,angle: float = 0.0) -> void:
	var leaf: MeshInstance3D = _sphere(root,pos,size,p.armor)
	leaf.rotation.y = angle
	_rod(root,pos-Vector3(size.x*.3,0,0).rotated(Vector3.UP,angle),pos+Vector3(size.x*.3,0,0).rotated(Vector3.UP,angle),.6,p.edge)

static func _kharuun_building(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="hq":
		# A hollow command tree with wide roots and a broken crown.
		_cylinder(root,Vector3(0,23,-4),21,42,p.dark,13)
		_sphere(root,Vector3(0,10,17),Vector3(25,18,10),p.dark)
		for i: int in range(6):
			var angle: float = TAU*float(i)/6
			var end := Vector3(cos(angle)*47,3,sin(angle)*32)
			_rod(root,Vector3(0,23,-4),end,5,p.armor)
			var crown := Vector3(cos(angle)*20,44+float(i%2)*5,sin(angle)*16-4)
			_rod(root,Vector3(0,31,-4),crown,3.8,p.dark)
			_leaf(root,crown,Vector3(31,6,18),p,angle)
		_sphere(root,Vector3(0,43,-4),Vector3(12,9,12),p.energy)
	elif kind=="power":
		# Tall open solar flower; its petal outline reads without animation.
		_cylinder(root,Vector3(0,19,0),5,34,p.dark,3)
		for i: int in range(7):
			var angle: float = TAU*float(i)/7
			var point := Vector3(cos(angle)*15,38,sin(angle)*15)
			_rod(root,Vector3(0,27,0),point,2.2,p.dark)
			_leaf(root,point,Vector3(23,5,11),p,angle)
			_rod(root,Vector3(0,9,0),Vector3(cos(angle)*23,2,sin(angle)*23),2.4,p.armor)
		_sphere(root,Vector3(0,40,0),Vector3(14,13,14),p.trim)
		_sphere(root,Vector3(0,44,0),Vector3(8,4,8),p.energy)
	elif kind=="refinery":
		# Three sap bladders connect to an open collecting trough.
		for entry: Vector3 in [Vector3(-24,18,-15),Vector3(3,24,-19),Vector3(27,16,-7)]:
			_sphere(root,entry,Vector3(25,entry.y*1.6,24),p.armor)
			_ring(root,entry-Vector3(0,4,0),12.5,1.4,p.dark)
			_rod(root,entry,Vector3(-2,9,22),2.3,p.dark)
			_sphere(root,entry+Vector3(0,entry.y*.6,0),Vector3(5,5,5),p.energy)
		_sphere(root,Vector3(-2,5,24),Vector3(46,9,24),p.dark)
		for side: float in [-1.0,1.0]:
			_rod(root,Vector3(side*23,4,10),Vector3(side*19,12,35),3,p.armor)
		_sphere(root,Vector3(-2,8,22),Vector3(27,3,15),p.energy)
	elif kind=="barracks":
		# A low seed nursery, two rows of individual growth pods.
		for x: float in [-27.0,-9.0,9.0,27.0]:
			for z: float in [-10.0,10.0]:
				_sphere(root,Vector3(x,10,z),Vector3(14,17,13),p.dark)
				_sphere(root,Vector3(x,13,z),Vector3(11,12,10),p.armor)
			_rod(root,Vector3(x,2,0),Vector3(x,20,-6),1.8,p.dark)
			_leaf(root,Vector3(x,22,-6),Vector3(23,4,26),p,.2)
		_rod(root,Vector3(-36,3,0),Vector3(36,3,0),3,p.dark)
	else:
		# Massive open seed-forge log, with arching growth ribs.
		for z: float in [-23.0,-6.0,13.0]:
			_arch(root,Vector3(0,5,z),81,31,5,p.dark)
			_arch(root,Vector3(0,7,z),75,30,2,p.armor)
		for side: float in [-1.0,1.0]:
			_rod(root,Vector3(side*43,4,-30),Vector3(side*43,5,29),4,p.armor)
			_leaf(root,Vector3(side*31,29,-15),Vector3(25,5,25),p,side*.5)
		_sphere(root,Vector3(0,10,0),Vector3(44,13,40),p.armor)
		_sphere(root,Vector3(0,17,0),Vector3(19,5,21),p.trim)
		for x: float in [-14.0,14.0]:
			_rod(root,Vector3(x,5,18),Vector3(x,5,36),2,p.dark)

static func _host_building(root: Node3D,kind: String,p: Dictionary) -> void:
	var size: Vector2 = Vector2(DATA.spec(kind).size)*.8
	_box(root,Vector3(0,2,0),Vector3(size.x,4,size.y),p.dark,1)
	if kind=="hq":
		# Stepped cathedral with one dominant central spire.
		_box(root,Vector3(0,9,0),Vector3(83,12,55),p.armor,1)
		_box(root,Vector3(0,23,-8),Vector3(38,30,30),p.edge,1)
		_prism(root,Vector3(0,47,-8),16,22,p.trim,4)
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*32,18,0),Vector3(15,25,32),p.armor,.7)
			_prism(root,Vector3(side*32,34,0),11,12,p.trim,4)
			_window(root,Vector3(side*32,20,16.5),7,p)
		_arch(root,Vector3(0,5,29),18,23,2,p.trim)
		_box(root,Vector3(0,14,28),Vector3(13,18,1),p.dark)
	elif kind=="power":
		# Bare radiant halo suspended between two narrow pylons.
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*20,21,0),Vector3(7,37,10),p.edge,.6)
			_prism(root,Vector3(side*20,43,0),6,9,p.trim,4)
		_ring(root,Vector3(0,29,0),17,2.4,p.trim,true)
		_sphere(root,Vector3(0,29,0),Vector3(12,12,12),p.energy)
		_cylinder(root,Vector3(0,6,0),14,5,p.armor)
	elif kind=="refinery":
		# Open ceremonial receiving chalices with channelled troughs.
		for x: float in [-22.0,22.0]:
			_cylinder(root,Vector3(x,12,-10),6,17,p.trim)
			_cylinder(root,Vector3(x,23,-10),11,10,p.armor,17)
			_ring(root,Vector3(x,28,-10),17,2,p.edge)
			_cylinder(root,Vector3(x,28,-10),13,1,p.energy)
			_rod(root,Vector3(x,17,-4),Vector3(0,7,24),1.8,p.trim)
		_box(root,Vector3(0,5,23),Vector3(44,4,28),p.edge,.5)
		_box(root,Vector3(0,7.5,23),Vector3(32,1,23),p.dark)
		for x: float in [-20.0,20.0]:
			_box(root,Vector3(x,10,24),Vector3(4,10,28),p.armor,.5)
	elif kind=="barracks":
		# Low colonnaded hall and a broad arched entrance.
		_box(root,Vector3(0,23,-3),Vector3(75,5,31),p.edge,.8)
		for x: float in [-32.0,-16.0,16.0,32.0]:
			_cylinder(root,Vector3(x,13,9),3,20,p.armor)
			_box(root,Vector3(x,4,9),Vector3(8,4,8),p.trim,.3)
		_box(root,Vector3(0,12,-15),Vector3(69,19,5),p.armor,.5)
		_arch(root,Vector3(0,4,12),20,17,2,p.trim)
		for x: float in [-28.0,28.0]:
			_prism(root,Vector3(x,29,-4),7,8,p.trim,4)
	else:
		# A winged heavy forge spans a broad assembly plinth.
		_box(root,Vector3(0,7,0),Vector3(87,10,58),p.armor,1.8)
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*36,22,-6),Vector3(12,27,30),p.edge,.7)
			var wing: MeshInstance3D = _box(root,Vector3(side*30,39,-7),Vector3(42,6,19),p.armor,1)
			wing.rotation.z = side*.3
			for i: int in range(4):
				_box(root,Vector3(side*(25+i*6),37+i*1.7,-6),Vector3(3,2,23-i*3),p.trim,.2)
		_arch(root,Vector3(0,11,8),56,31,3,p.trim)
		_box(root,Vector3(0,12,6),Vector3(41,2,32),p.dark)
		_cylinder(root,Vector3(0,15,-4),11,4,p.edge)
		_sphere(root,Vector3(0,19,-4),Vector3(10,6,10),p.energy)

static func _infernal_building(root: Node3D,kind: String,p: Dictionary) -> void:
	var size: Vector2 = Vector2(DATA.spec(kind).size)*.78
	_box(root,Vector3(0,2,0),Vector3(size.x,4,size.y),p.dark,1)
	if kind=="hq":
		# Tiered black keep with a high horned crown.
		_box(root,Vector3(0,12,0),Vector3(75,20,51),p.armor,1)
		_box(root,Vector3(0,31,-7),Vector3(39,22,32),p.dark,1)
		for side: float in [-1.0,1.0]:
			_box(root,Vector3(side*35,18,-3),Vector3(18,30,27),p.armor,.8)
			var horn: MeshInstance3D = _prism(root,Vector3(side*20,46,-7),6,25,p.trim,6)
			horn.rotation.z = -side*.3
		_box(root,Vector3(0,14,26),Vector3(19,23,2),p.dark)
		_prism(root,Vector3(0,28,26),8,9,p.energy,3)
	elif kind=="power":
		# Exposed furnace chimney; the glowing slit is inside the casing.
		_prism(root,Vector3(0,24,0),16,39,p.armor,6,12)
		_prism(root,Vector3(0,44,0),13,6,p.trim,6,15)
		_cylinder(root,Vector3(0,47,0),10,1,p.dark)
		_cylinder(root,Vector3(0,47.6,0),6,1,p.energy)
		_box(root,Vector3(0,21,14),Vector3(7,19,1),p.dark)
		_box(root,Vector3(0,21,14.7),Vector3(3,14,.4),p.energy)
		for side: float in [-1.0,1.0]:
			_rod(root,Vector3(side*23,4,0),Vector3(side*12,28,0),3,p.dark)
	elif kind=="refinery":
		# Broad iron cauldrons and a feeding trough, not a horned keep.
		for x: float in [-22.0,22.0]:
			_sphere(root,Vector3(x,16,-13),Vector3(30,24,29),p.armor)
			_ring(root,Vector3(x,25,-13),14,2.4,p.trim)
			_cylinder(root,Vector3(x,25,-13),11,1,p.dark)
			_cylinder(root,Vector3(x,25.8,-13),7,1,p.energy)
			for side: float in [-1.0,1.0]:
				_rod(root,Vector3(x+side*12,10,-13),Vector3(x+side*15,3,-13),2,p.dark)
		_box(root,Vector3(0,6,23),Vector3(46,6,25),p.dark,.7)
		for x: float in [-23.0,23.0]:
			_box(root,Vector3(x,12,23),Vector3(4,12,28),p.armor,.5)
			_rod(root,Vector3(x,20,-4),Vector3(x,10,19),2,p.trim)
	elif kind=="barracks":
		# Low serrated den with four separate hatch doors.
		_box(root,Vector3(0,11,-2),Vector3(76,18,31),p.armor,1.2)
		for x: float in [-27.0,-9.0,9.0,27.0]:
			_box(root,Vector3(x,10,14),Vector3(11,13,2),p.dark)
			_prism(root,Vector3(x,24,-1),7,12,p.trim,3)
			_box(root,Vector3(x,17,15),Vector3(9,1,.5),p.energy)
		for x: float in [-38.0,38.0]:
			_prism(root,Vector3(x,15,9),4,21,p.dark,4)
	else:
		# A huge open anvil forge, with articulated crane arms.
		_box(root,Vector3(0,6,0),Vector3(92,8,61),p.dark,1.2)
		_box(root,Vector3(0,18,-4),Vector3(34,20,28),p.armor,1)
		_box(root,Vector3(0,30,-4),Vector3(66,7,34),p.trim,1)
		_box(root,Vector3(0,34,-4),Vector3(41,1,22),p.dark)
		for side: float in [-1.0,1.0]:
			_rod(root,Vector3(side*42,5,-21),Vector3(side*39,43,-15),3,p.armor)
			_rod(root,Vector3(side*39,43,-15),Vector3(side*15,41,4),2.2,p.trim)
			_rod(root,Vector3(side*15,41,4),Vector3(side*15,31,4),.8,p.dark)
			_box(root,Vector3(side*34,8,23),Vector3(11,4,19),p.armor,.7)
		_box(root,Vector3(0,10,25),Vector3(35,3,12),p.dark)
		_box(root,Vector3(0,12,25),Vector3(25,1,6),p.energy)

static func _veyr_building(root: Node3D,kind: String,p: Dictionary) -> void:
	if kind=="hq":
		# A tiered citadel with one dominant crystal, not five equal shards.
		_prism(root,Vector3(0,5,0),43,8,p.dark,6,39)
		_prism(root,Vector3(0,16,-5),26,19,p.armor,6,20)
		_prism(root,Vector3(0,39,-5),16,39,p.edge,5)
		for side: float in [-1.0,1.0]:
			_prism(root,Vector3(side*31,18,7),12,25,p.armor,4)
			_rod(root,Vector3(side*27,14,8),Vector3(side*10,29,-3),1.3,p.trim)
		_prism(root,Vector3(0,18,25),8,14,p.energy,4)
	elif kind=="power":
		# A suspended spindle enclosed by a fine resonance ring.
		_prism(root,Vector3(0,5,0),22,7,p.dark,6,19)
		_ring(root,Vector3(0,29,0),20,2,p.trim,true)
		_prism(root,Vector3(0,34,0),9,24,p.edge,5)
		var lower: MeshInstance3D = _prism(root,Vector3(0,18,0),9,10,p.armor,5)
		lower.rotation.z = PI
		_prism(root,Vector3(0,29,0),5,12,p.energy,5)
		for side: float in [-1.0,1.0]:
			_prism(root,Vector3(side*20,14,0),4,20,p.armor,4)
	elif kind=="refinery":
		# Low hexagonal collecting basin and three storage shards.
		_prism(root,Vector3(0,6,14),28,9,p.armor,6,29)
		_prism(root,Vector3(0,11,14),23,1,p.dark,6,23)
		_prism(root,Vector3(0,11.8,14),17,1,p.energy,6,17)
		for x: float in [-25.0,0.0,25.0]:
			_prism(root,Vector3(x,19,-19),10,28,p.edge,5)
			_rod(root,Vector3(x,15,-12),Vector3(x*.6,9,10),1.5,p.trim)
	elif kind=="barracks":
		# Long parallel crystal racks around a central deployment channel.
		_box(root,Vector3(0,4,0),Vector3(76,5,40),p.dark,1)
		for x: float in [-27.0,-9.0,9.0,27.0]:
			for z: float in [-12.0,12.0]:
				_prism(root,Vector3(x,15,z),6,22,p.armor,4)
				_prism(root,Vector3(x,24,z),3,7,p.edge,4)
		_box(root,Vector3(0,7,0),Vector3(68,1,5),p.trim)
	else:
		# Huge horizontal crystal arch over an open assembly cradle.
		_prism(root,Vector3(0,5,0),46,7,p.dark,6,43)
		for side: float in [-1.0,1.0]:
			_prism(root,Vector3(side*34,20,-7),13,32,p.armor,4,8)
			var beam: MeshInstance3D = _prism(root,Vector3(side*18,39,-7),9,39,p.edge,4,7)
			beam.rotation.z = side*1.08
			_prism(root,Vector3(side*31,12,22),8,16,p.armor,4)
		_box(root,Vector3(0,11,0),Vector3(41,4,30),p.trim,1)
		_prism(root,Vector3(0,21,0),9,16,p.energy,5)
		_box(root,Vector3(0,8,28),Vector3(32,2,15),p.armor,.7)

# Expansion silhouettes are original role-specific assemblies. All float above ground;
# branches, fixed wings and arms are equipment, never a walking/wing-flapping rig.
static func _expanded_unit(root: Node3D, style: String, kind: String, p: Dictionary) -> void:
	var profiles: Dictionary = {
		"scout": Vector3(15, 11, 28), "skirmisher": Vector3(22, 15, 25), "sniper": Vector3(17, 17, 27),
		"shock": Vector3(28, 19, 25), "breacher": Vector3(32, 17, 30), "guardian": Vector3(31, 27, 24),
		"medic": Vector3(20, 24, 20), "mechanic": Vector3(29, 18, 24), "lancer": Vector3(23, 20, 29),
		"suppressor": Vector3(32, 17, 28), "artillery": Vector3(33, 17, 39), "mortar": Vector3(29, 20, 27),
		"raider": Vector3(25, 13, 35), "destroyer": Vector3(35, 20, 33), "juggernaut": Vector3(39, 25, 36),
		"disruptor": Vector3(25, 27, 24), "siege_tank": Vector3(37, 19, 40), "commander": Vector3(29, 27, 29)
	}
	var dimensions: Vector3 = profiles[kind]
	var w: float = dimensions.x
	var h: float = dimensions.y
	var l: float = dimensions.z
	var y: float = 10.0
	var support: bool = kind in ["medic", "mechanic", "disruptor", "commander"]
	match style:
		"humans":
			# Closed industrial hover hulls: angular bow, recessed keel, visible panels.
			_box(root, Vector3(0, y, 0), Vector3(w, 8, l), p.armor, 2.0)
			_box(root, Vector3(0, y - 4.8, -1), Vector3(w * .76, 2.0, l * .78), p.dark, .7)
			_box(root, Vector3(0, y + 5, l * .27), Vector3(w * .72, 3.0, l * .28), p.edge, .8)
			_box(root, Vector3(0, y + 7, -l * .13), Vector3(w * .51, h * .45, l * .36), p.armor, 1.3)
			_window(root, Vector3(0, y + h * .3, l * .055), w * .33, p)
			_vent(root, Vector3(0, y + 4.5, -l * .34), w * .48, l * .22, p)
			for side: float in [-1.0, 1.0]:
				_box(root, Vector3(side * w * .38, y - 2, -l * .1), Vector3(1, 1.2, l * .35), p.energy)
				_box(root, Vector3(side * w * .25, y, -l * .51), Vector3(w * .16, 3, 2), p.dark, .5)
				_box(root, Vector3(side * w * .25, y, -l * .55), Vector3(w * .1, 1, .3), p.energy)
			if kind in ["guardian", "breacher", "juggernaut"]:
				for side: float in [-1.0, 1.0]:
					_box(root, Vector3(side * w * .41, 17, l * .2), Vector3(4, 12, l * .53), p.armor, .8)
		"iron_synod":
			# A living armored core, split crescent carapace and exposed neural conduits.
			_sphere(root, Vector3(0, 14, 0), Vector3(w * .78, h * .9, l * .88), p.dark)
			for side: float in [-1.0, 1.0]:
				_sphere(root, Vector3(side * w * .3, 16, -l * .08), Vector3(w * .48, h * .6, l * .93), p.armor)
				_box(root, Vector3(side * w * .29, 18, l * .21), Vector3(w * .2, 3.0, l * .37), p.edge, 1)
				for rib: int in range(3):
					var z: float = -l * .3 + rib * l * .23
					_rod(root, Vector3(side * w * .1, 22, z), Vector3(side * w * .4, 16, z + 2), .9, p.trim)
			_sphere(root, Vector3(0, 20, -l * .12), Vector3(w * .28, h * .47, l * .34), p.energy)
			for i: int in range(3):
				_rod(root, Vector3(-4 + i * 4, 23, -l * .2), Vector3(-4 + i * 4, 28 + i % 2 * 3, -l * .3), .7, p.edge)
		"kharuun":
			# Levitating seed masses and layered bark: no mobile roots acting as legs.
			_sphere(root, Vector3(0, 14, 0), Vector3(w * .8, h * .8, l * .86), p.dark)
			for layer: int in range(3):
				var z: float = -l * .3 + layer * l * .26
				_sphere(root, Vector3(0, 16 + layer % 2 * 2, z), Vector3(w * (.85 - layer * .06), h * .52, l * .48), p.armor)
				for side: float in [-1.0, 1.0]:
					_leaf(root, Vector3(side * w * .32, 16, z), Vector3(w * .34, 3.5, l * .42), p, side * .45)
			_sphere(root, Vector3(0, 22, 0), Vector3(w * .3, 9, l * .3), p.energy)
			if kind in ["guardian", "breacher", "juggernaut"]:
				for side: float in [-1.0, 1.0]:
					_box(root, Vector3(side * w * .34, 19, 2), Vector3(5, 15, l * .55), p.dark, 1)
					_leaf(root, Vector3(side * w * .36, 25, 2), Vector3(5, 2, l * .6), p, side * .15)
		"heavenly_host":
			# Suspended reliquaries / tapered robes with rigid gilded wings and halos.
			_prism(root, Vector3(0, 15, 0), w * .33, 19, p.dark, 6, w * .09)
			_box(root, Vector3(0, 23, -1), Vector3(w * .66, h * .45, l * .57), p.armor, 2)
			_prism(root, Vector3(0, 28, 1), w * .18, 8, p.edge, 5, 1)
			_ring(root, Vector3(0, 34, -1), w * .34, .7, p.trim)
			for side: float in [-1.0, 1.0]:
				var wing: MeshInstance3D = _box(root, Vector3(side * w * .44, 24, -l * .16), Vector3(w * .3, 3.5, l * .58), p.edge, 1)
				wing.rotation.z = side * .37
				for feather: int in range(3):
					_box(root, Vector3(side * w * (.4 + feather * .065), 23 - feather, -l * .3 + feather * 3), Vector3(2.2, 1.8, l * .35), p.trim, .3)
			_sphere(root, Vector3(0, 23, l * .28), Vector3(4, 5, 3), p.energy)
		"infernal_legion":
			# Legless furnace spirits suspended in asymmetric obsidian war harnesses.
			_prism(root, Vector3(0, 13, 0), w * .29, 17, p.dark, 5, w * .06)
			_sphere(root, Vector3(0, 23, -1), Vector3(w * .8, h * .62, l * .68), p.armor)
			_prism(root, Vector3(0, 28, l * .16), w * .17, 12, p.dark, 5, 2)
			_box(root, Vector3(0, 20, l * .32), Vector3(w * .35, 5, 2), p.energy, .5)
			for side: float in [-1.0, 1.0]:
				_rod(root, Vector3(side * w * .27, 29, 0), Vector3(side * w * .39, 37, -4), 1.5, p.trim)
				_rod(root, Vector3(side * w * .39, 37, -4), Vector3(side * w * .25, 40, -7), .75, p.edge)
				_box(root, Vector3(side * w * .34, 21, -3), Vector3(w * .22, 8, l * .55), p.dark, 1)
				for slit: int in range(3):
					_box(root, Vector3(side * w * .46, 19 + slit * 2, -3), Vector3(.5, .7, l * .25), p.energy)
		"veyr":
			# Open geometric lattice: individual suspended facets, not a recolored hull.
			_prism(root, Vector3(0, 18, 0), w * .29, h * 1.3, p.armor, 6, 1)
			_prism(root, Vector3(0, 21, l * .12), w * .16, h * .8, p.edge, 5, 0)
			for side: float in [-1.0, 1.0]:
				_prism(root, Vector3(side * w * .36, 15, -l * .14), w * .16, h * .8, p.dark, 4, 0)
				_prism(root, Vector3(side * w * .3, 24, -l * .1), w * .1, h * .66, p.edge, 5, 0)
				_rod(root, Vector3(0, 15, 0), Vector3(side * w * .34, 15, -l * .14), .55, p.trim)
			_prism(root, Vector3(0, 12, -l * .39), w * .14, h * .5, p.armor, 4, 0)
			_sphere(root, Vector3(0, 18, l * .25), Vector3(4, 6, 3), p.energy)
	# Each role changes its equipment topology as well as its body dimensions.
	var mount := Vector3(0, 25 if support else 22, l * .2)
	match kind:
		"scout":
			_exp_sensor(root, style, Vector3(0, 25, -5), 5, p)
			_exp_gun(root, style, Vector3(0, 17, 7), 9, 1, p)
		"skirmisher":
			for side: float in [-1.0, 1.0]: _exp_gun(root, style, Vector3(side * w * .31, 21, 6), 10, 1, p)
		"sniper":
			_exp_gun(root, style, mount, 24, 1, p)
			_exp_sensor(root, style, Vector3(-5, 26, -7), 3.3, p)
		"shock":
			_exp_coil(root, style, Vector3(0, 26, 9), 7, p)
			for side: float in [-1.0, 1.0]: _exp_gun(root, style, Vector3(side * w * .34, 21, 7), 10, 2, p)
		"breacher":
			for side: float in [-1.0, 1.0]:
				_exp_shield(root, style, Vector3(side * w * .32, 19, 12), 8, 15, p)
			_exp_gun(root, style, Vector3(0, 24, 11), 13, 3, p)
		"guardian":
			_exp_shield(root, style, Vector3(0, 23, 15), w * .76, 23, p)
			_exp_coil(root, style, Vector3(0, 29, -5), 6, p)
		"medic":
			_exp_coil(root, style, Vector3(0, 27, 1), 8, p)
			for side: float in [-1.0, 1.0]:
				_exp_vial(root, style, Vector3(side * 8, 24, -5), 3, 10, p)
				_rod(root, Vector3(side * 8, 19, 3), Vector3(side * 14, 23, 11), .7, p.edge)
		"mechanic":
			for side: float in [-1.0, 1.0]:
				_rod(root, Vector3(side * 10, 18, 0), Vector3(side * 15, 27, 8), 1.3, p.trim)
				_rod(root, Vector3(side * 15, 27, 8), Vector3(side * 11, 25, 17), 1, p.edge)
				_box(root, Vector3(side * 11, 24, 17), Vector3(4, 2, 5), p.dark, .3)
			_exp_vial(root, style, Vector3(0, 24, -7), 5, 9, p)
		"lancer":
			_exp_gun(root, style, mount, 21, 2, p)
			for side: float in [-1.0, 1.0]: _exp_vial(root, style, Vector3(side * 8, 21, -7), 2.5, 8, p)
		"suppressor":
			for side: float in [-1.0, 1.0]: _exp_gun(root, style, Vector3(side * 10, 23, 8), 14, 4, p)
			_exp_vial(root, style, Vector3(0, 22, -6), 5, 9, p)
		"artillery":
			_exp_gun(root, style, Vector3(0, 27, 4), 24, 1, p)
			_box(root, Vector3(0, 19, -11), Vector3(16, 7, 10), p.dark, 1)
			_exp_sensor(root, style, Vector3(-10, 26, -10), 4, p)
		"mortar":
			for side: float in [-1.0, 1.0]:
				var tube: Node3D = Node3D.new()
				root.add_child(tube)
				tube.position = Vector3(side * 6, 22, 0)
				tube.rotation.x = -.7
				_exp_gun(tube, style, Vector3.ZERO, 16, 1, p)
		"raider":
			_exp_gun(root, style, Vector3(0, 19, 12), 13, 2, p)
			for side: float in [-1.0, 1.0]:
				var fin := _box(root, Vector3(side * 11, 15, -11), Vector3(3, 3, 14), p.edge, .5)
				fin.rotation.y = side * .37
		"destroyer":
			for side: float in [-1.0, 1.0]: _exp_gun(root, style, Vector3(side * 9, 25, 6), 18, 2, p)
			_exp_shield(root, style, Vector3(0, 19, 16), 18, 8, p)
		"juggernaut":
			for side: float in [-1.0, 1.0]:
				_exp_gun(root, style, Vector3(side * 11, 28, 7), 16, 3, p)
				_exp_shield(root, style, Vector3(side * 16, 24, -3), 8, 18, p)
			_exp_vial(root, style, Vector3(0, 29, -9), 5, 8, p)
		"disruptor":
			_exp_coil(root, style, Vector3(0, 30, 0), 10, p)
			_exp_sensor(root, style, Vector3(0, 28, 10), 5, p)
		"siege_tank":
			_exp_gun(root, style, Vector3(0, 26, 4), 25, 3, p)
			for side: float in [-1.0, 1.0]: _exp_vial(root, style, Vector3(side * 12, 23, -11), 4, 7, p)
		"commander":
			_exp_sensor(root, style, Vector3(0, 32, -5), 8, p)
			_exp_coil(root, style, Vector3(0, 28, 8), 7, p)
			for side: float in [-1.0, 1.0]:
				_rod(root, Vector3(side * 9, 21, -7), Vector3(side * 11, 34, -9), .6, p.trim)
				_box(root, Vector3(side * 11, 31, -9), Vector3(5, 6, 1), p.edge, .3)

static func _exp_gun(root: Node3D, style: String, pos: Vector3, length: float, barrels: int, p: Dictionary) -> void:
	for i: int in range(barrels):
		var q: Vector3 = pos + Vector3((i - (barrels - 1) * .5) * 2.8, 0, 0)
		match style:
			"humans":
				_box(root, q, Vector3(4, 4, 6), p.armor, .6)
				_rod(root, q + Vector3(0, 0, 2), q + Vector3(0, 0, length), .85, p.edge)
				_box(root, q + Vector3(0, 0, length), Vector3(2.8, 2.5, 2), p.dark, .3)
			"iron_synod":
				_sphere(root, q, Vector3(5, 6, 8), p.armor)
				for offset: float in [-1.0, 1.0]:
					_rod(root, q + Vector3(offset, 0, 0), q + Vector3(offset, 0, length), .7, p.edge)
				_sphere(root, q + Vector3(0, 0, length - 2), Vector3(3, 3, 4), p.energy)
			"kharuun":
				_sphere(root, q + Vector3(0, 0, length * .24), Vector3(5.5, 5, length * .8), p.dark)
				_leaf(root, q + Vector3(0, 2, length * .24), Vector3(6, 2, length * .8), p, 0)
				_prism(root, q + Vector3(0, 0, length * .65), 1.5, 6, p.trim, 4, 0).rotation.x = PI * .5
			"heavenly_host":
				_box(root, q + Vector3(0, 0, length * .25), Vector3(3.5, 3.5, length * .7), p.edge, .5)
				_ring(root, q + Vector3(0, 0, length * .65), 2.3, .5, p.trim, true)
				_sphere(root, q + Vector3(0, 0, length * .7), Vector3(2, 2, 4), p.energy)
			"infernal_legion":
				_sphere(root, q + Vector3(0, 0, 3), Vector3(6, 6, 9), p.dark)
				for side: float in [-1.0, 1.0]:
					_rod(root, q + Vector3(side * 2, 2, 1), q + Vector3(side * 1, 1, length), .8, p.trim)
				_sphere(root, q + Vector3(0, 0, 8), Vector3(3, 3, 5), p.energy)
			"veyr":
				var crystal: MeshInstance3D = _prism(root, q + Vector3(0, 0, length * .3), 3, length, p.edge, 5, 0)
				crystal.rotation.x = PI * .5
				_ring(root, q + Vector3(0, 0, 3), 3.5, .6, p.dark, true)

static func _exp_sensor(root: Node3D, style: String, pos: Vector3, radius: float, p: Dictionary) -> void:
	_rod(root, pos - Vector3(0, 5, 0), pos + Vector3(0, 3, 0), .7, p.trim)
	if style == "humans":
		var dish := _cylinder(root, pos + Vector3(0, 3, 0), radius, 1.7, p.edge)
		dish.rotation.x = .8
		_rod(root, pos + Vector3(0, 3, 0), pos + Vector3(0, 4, radius), .35, p.dark)
	elif style == "kharuun":
		for i: int in range(5):
			var angle: float = i * TAU / 5.0
			_leaf(root, pos + Vector3(cos(angle) * radius * .6, 3, sin(angle) * radius * .6), Vector3(radius, 2, radius * .6), p, angle)
		_sphere(root, pos + Vector3(0, 4, 0), Vector3(radius, radius * .7, radius), p.energy)
	elif style == "infernal_legion":
		for side: float in [-1.0, 1.0]:
			_rod(root, pos + Vector3(side * radius * .7, 2, 0), pos + Vector3(side * radius * .45, radius * 1.2, 0), .75, p.trim)
		_sphere(root, pos + Vector3(0, 3, 0), Vector3(radius * .9, radius * .8, radius * .9), p.energy)
	elif style == "veyr":
		for i: int in range(3):
			_prism(root, pos + Vector3((i - 1) * radius * .65, 4, 0), radius * .25, radius * (1.4 if i == 1 else .85), p.edge, 4, 0)
	else:
		_ring(root, pos + Vector3(0, 4, 0), radius, .8, p.trim, true)
		_sphere(root, pos + Vector3(0, 4, 0), Vector3(radius * .6, radius * .6, radius * .6), p.energy)

static func _exp_shield(root: Node3D, style: String, pos: Vector3, width: float, height: float, p: Dictionary) -> void:
	if style in ["humans", "iron_synod"]:
		_box(root, pos, Vector3(width, height, 3), p.armor, 1.2)
		_box(root, pos + Vector3(0, 0, 1.8), Vector3(width * .65, height * .65, .7), p.edge, .7)
	elif style == "kharuun":
		_sphere(root, pos, Vector3(width, height, 5), p.dark)
		_leaf(root, pos + Vector3(0, 2, 2), Vector3(width * .85, height * .75, 2), p, 0)
	elif style == "veyr":
		_prism(root, pos, width * .5, height, p.armor, 4, width * .3)
	else:
		_box(root, pos, Vector3(width, height, 3.5), p.dark, 1)
		_box(root, pos + Vector3(0, 0, 2), Vector3(width * .75, height * .72, 1), p.armor, 1)
		_rod(root, pos + Vector3(0, -height * .3, 2.8), pos + Vector3(0, height * .3, 2.8), .65, p.trim)

static func _exp_vial(root: Node3D, style: String, pos: Vector3, radius: float, height: float, p: Dictionary) -> void:
	if style == "kharuun":
		_sphere(root, pos, Vector3(radius * 2.2, height, radius * 2), p.energy)
		for side: float in [-1.0, 1.0]: _leaf(root, pos + Vector3(side * radius * .6, 0, 0), Vector3(radius, 2, height), p, side * .3)
	elif style == "veyr":
		_prism(root, pos, radius, height * 1.3, p.energy, 4, 0)
	else:
		_cylinder(root, pos, radius, height, p.dark)
		_cylinder(root, pos, radius * .72, height * .75, p.energy)
		for side: float in [-1.0, 1.0]: _cylinder(root, pos + Vector3(0, side * height * .4, 0), radius * 1.03, 1.2, p.edge)

static func _exp_coil(root: Node3D, style: String, pos: Vector3, radius: float, p: Dictionary) -> void:
	if style == "kharuun":
		for i: int in range(6):
			var angle: float = i * TAU / 6.0
			_leaf(root, pos + Vector3(cos(angle) * radius * .55, 0, sin(angle) * radius * .55), Vector3(radius * .9, 2.5, radius * .7), p, angle)
		_sphere(root, pos + Vector3(0, 2, 0), Vector3(radius, 7, radius), p.energy)
	elif style == "infernal_legion":
		for i: int in range(3):
			var angle: float = i * TAU / 3.0
			_rod(root, pos + Vector3(cos(angle) * radius, -2, sin(angle) * radius), pos + Vector3(cos(angle) * radius * .5, 7, sin(angle) * radius * .5), 1, p.trim)
		_sphere(root, pos, Vector3(radius * 1.2, 8, radius * 1.2), p.energy)
	elif style == "veyr":
		for side: float in [-1.0, 1.0]:
			var shard := _prism(root, pos + Vector3(side * radius * .65, 0, 0), radius * .28, radius * 1.5, p.edge, 4, 0)
			shard.rotation.z = side * .6
		_ring(root, pos, radius, .65, p.trim, true)
	else:
		_ring(root, pos, radius, 1.0, p.edge, true)
		_ring(root, pos, radius * .65, .7, p.trim, true)
		_sphere(root, pos, Vector3(radius * .75, radius * .75, radius * .75), p.energy)

static func _expanded_building(root: Node3D, style: String, kind: String, p: Dictionary) -> void:
	var small: bool = kind in ["outpost", "sentry", "bastion", "relay"]
	var w: float = 43 if small else 73
	var d: float = 38 if small else 62
	# Faction-specific foundations and wall assemblies make each culture legible.
	match style:
		"humans":
			_box(root, Vector3(0, 3, 0), Vector3(w + 10, 6, d + 10), p.concrete, 1)
			_box(root, Vector3(0, 12, 0), Vector3(w, 18, d), p.armor, 2)
			for side: float in [-1.0, 1.0]:
				_box(root, Vector3(side * w * .43, 13, 0), Vector3(5, 20, d + 3), p.dark, .7)
				_vent(root, Vector3(side * w * .31, 22, -d * .28), 8, 12, p)
			_window(root, Vector3(0, 15, d * .505), w * .35, p)
		"iron_synod":
			_sphere(root, Vector3(0, 6, 0), Vector3(w + 12, 12, d + 10), p.dark)
			_sphere(root, Vector3(0, 18, -4), Vector3(w * .9, 28, d * .94), p.armor)
			for side: float in [-1.0, 1.0]:
				for i: int in range(4):
					var z: float = -d * .37 + i * d * .23
					_rod(root, Vector3(side * w * .15, 28, z), Vector3(side * w * .5, 7, z), 2.3, p.edge)
				_sphere(root, Vector3(side * w * .3, 12, d * .36), Vector3(12, 15, 12), p.energy)
		"kharuun":
			_sphere(root, Vector3(0, 4, 0), Vector3(w + 13, 10, d + 9), p.dark)
			for i: int in range(5):
				var angle: float = i * TAU / 5.0
				var q := Vector3(cos(angle) * w * .25, 12, sin(angle) * d * .25)
				_sphere(root, q, Vector3(w * .55, 23, d * .55), p.armor)
				_leaf(root, q + Vector3(0, 12, 0), Vector3(w * .4, 3.0, d * .45), p, angle)
			_sphere(root, Vector3(0, 23, 0), Vector3(w * .44, 16, d * .44), p.dark)
		"heavenly_host":
			_box(root, Vector3(0, 3, 0), Vector3(w + 10, 6, d + 10), p.dark, 1)
			_box(root, Vector3(0, 13, 0), Vector3(w, 20, d), p.armor, 2)
			for side: float in [-1.0, 1.0]:
				_prism(root, Vector3(side * w * .4, 23, -d * .25), 5, 32, p.edge, 6, 2)
				_arch(root, Vector3(0, 7, d * .49), w * .67, 27, 2, p.trim)
			_box(root, Vector3(0, 24, -d * .22), Vector3(w * .75, 3, d * .5), p.edge, 1)
		"infernal_legion":
			_prism(root, Vector3(0, 5, 0), w * .7, 10, p.dark, 6, w * .6)
			_box(root, Vector3(0, 16, 0), Vector3(w * .88, 25, d * .85), p.dark, 1)
			for side: float in [-1.0, 1.0]:
				_prism(root, Vector3(side * w * .4, 17, -d * .2), 7, 30, p.armor, 4, 1)
				_rod(root, Vector3(side * w * .4, 30, -d * .2), Vector3(side * w * .3, 42, -d * .3), 2, p.trim)
				for vent: int in range(3): _box(root, Vector3(side * w * .46, 12 + vent * 3, 1), Vector3(1, 1.2, d * .45), p.energy)
		"veyr":
			_prism(root, Vector3(0, 4, 0), w * .7, 8, p.dark, 6, w * .6)
			for i: int in range(4):
				var angle: float = PI * .25 + i * PI * .5
				var q := Vector3(cos(angle) * w * .32, 16, sin(angle) * d * .32)
				_prism(root, q, w * .2, 27, p.armor, 5, 1)
				_rod(root, q, Vector3(0, 16, 0), .85, p.trim)
			_prism(root, Vector3(0, 17, 0), w * .27, 27, p.edge, 6, 2)
	match kind:
		"outpost":
			_exp_sensor(root, style, Vector3(0, 40, 0), 13, p)
			for side: float in [-1.0, 1.0]: _rod(root, Vector3(side * 10, 20, -8), Vector3(side * 10, 43, -8), 1, p.trim)
		"sentry":
			_cylinder(root, Vector3(0, 29, 0), 12, 7, p.dark)
			for side: float in [-1.0, 1.0]: _exp_gun(root, style, Vector3(side * 6, 34, 4), 20, 3, p)
			_exp_sensor(root, style, Vector3(0, 39, -8), 5, p)
		"bastion":
			_exp_shield(root, style, Vector3(0, 30, 12), 31, 20, p)
			_exp_gun(root, style, Vector3(0, 40, 4), 28, 2, p)
			for side: float in [-1.0, 1.0]: _exp_vial(root, style, Vector3(side * 15, 28, -9), 5, 18, p)
		"workshop":
			for side: float in [-1.0, 1.0]:
				_rod(root, Vector3(side * 26, 15, 0), Vector3(side * 26, 46, -9), 2, p.trim)
				_rod(root, Vector3(side * 26, 46, -9), Vector3(side * 11, 46, 9), 1.5, p.edge)
				_exp_vial(root, style, Vector3(side * 22, 31, -17), 7, 17, p)
			_box(root, Vector3(0, 8, 21), Vector3(31, 2, 19), p.dark, .5)
			_exp_coil(root, style, Vector3(0, 35, -12), 12, p)
		"sanctum":
			_exp_coil(root, style, Vector3(0, 45, 0), 20, p)
			for side: float in [-1.0, 1.0]:
				_exp_vial(root, style, Vector3(side * 26, 31, -8), 6, 25, p)
				_exp_sensor(root, style, Vector3(side * 24, 42, 14), 6, p)
		"arsenal":
			for side: float in [-1.0, 1.0]:
				_box(root, Vector3(side * 24, 28, -8), Vector3(17, 18, 30), p.armor, 1)
				for rack: int in range(3): _exp_gun(root, style, Vector3(side * 24 + (rack - 1) * 4, 39, -10), 24, 1, p)
			_box(root, Vector3(0, 10, 23), Vector3(28, 3, 24), p.dark, .5)
			_exp_sensor(root, style, Vector3(0, 39, -19), 9, p)
		"reactor":
			for side: float in [-1.0, 1.0]:
				_exp_vial(root, style, Vector3(side * 20, 38, 0), 12, 42, p)
				_exp_coil(root, style, Vector3(side * 20, 47, 0), 11, p)
			_rod(root, Vector3(-20, 47, 0), Vector3(20, 47, 0), 2.2, p.trim)
			_exp_vial(root, style, Vector3(0, 30, 20), 7, 19, p)
		"relay":
			_exp_coil(root, style, Vector3(0, 41, 0), 16, p)
			for i: int in range(3):
				var angle: float = i * TAU / 3.0
				_exp_sensor(root, style, Vector3(cos(angle) * 18, 37, sin(angle) * 18), 6, p)
