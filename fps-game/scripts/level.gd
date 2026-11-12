extends Node3D
var geometry: Node3D
var entities: Node3D
var mats: Dictionary = {}
var arena_door
var return_door
var side_door
var boss_spawned: bool = false
var particle_count: int = 0
var room_last: String = ""

func _ready() -> void:
	Game.level = self
	make_materials()
	if "--bake" in OS.get_cmdline_user_args() and has_node("Geometry"):
		get_node("Geometry").free()
	if has_node("Geometry"):
		geometry = get_node("Geometry")
	else:
		geometry = Node3D.new()
		geometry.name = "Geometry"
		add_child(geometry)
		build_architecture()
	entities = Node3D.new()
	entities.name = "Gameplay"
	add_child(entities)
	populate()

# --- Asset paths (every model below comes from the downloaded library) ---
const TP = "res://assets/third_party/"
const GM = TP+"valsekamerplant/going-medieval/"
const OF = TP+"valsekamerplant/office/"
const PL = TP+"valsekamerplant/plants/"
const DJ = TP+"daniel-jurys/derelict-furniture/"
const PA = TP+"mcpato/haunted-parish/"
const HI = TP+"mcpato/house-interior/"
const VI = TP+"elbolilloduro/village-interior/"
const AB = TP+"elbolilloduro/abandoned-house/"
const HW = TP+"elbolilloduro/halloween/"
const DH = TP+"doctor-sci3nce/healing-items/"
const DT = TP+"doctor-sci3nce/hand-tools/"
const DW = TP+"doctor-sci3nce/weapon-props/"
const KR = TP+"kkryy/retro-interior/"
const KS = TP+"kkryy/street-furniture/"
const KF = TP+"kkryy/forest/"
const MT = TP+"mcsteeg/trash-and-debris/"
const MF = TP+"mcsteeg/farm-tools/"
const NK = TP+"nicowlas/kitchen/"
const RM = TP+"retroassetslibrary/med-pack/"
const RC = TP+"retroassetslibrary/chainsaw/"
const FT = "res://assets/textures/foxtex/"
const DOOR_H = 3.1

func make_materials() -> void:
	# Architecture shell: simple boxes skinned with downloaded FoxTex textures.
	var textured = {"wood":"res://assets/textures/wood.png","floor":"res://assets/textures/floor.png","stone":"res://assets/textures/stone.png","marble":"res://assets/textures/marble.png","metal":"res://assets/textures/metal.png","brick":"res://assets/textures/brick.png",
		"panel":FT+"panel.png","trim":FT+"beam.png","plaster":FT+"wallpaper_grey.png","plaster_red":FT+"wallpaper_grey.png","dark":FT+"ceiling.png","red":FT+"carpet.png","cream":FT+"tile_light.png","black":FT+"tile_dark.png"}
	var tints = {"plaster":Color(.66,.62,.56),"plaster_red":Color(.7,.5,.46),"dark":Color(.45,.4,.36),"red":Color(.85,.55,.55),"trim":Color(.8,.72,.65)}
	var tiles = {"panel":1.2,"trim":1.0,"plaster":2.5,"plaster_red":2.5,"dark":3.0,"red":1.5,"cream":2.0,"black":2.0}
	for id in textured:
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/psx.gdshader")
		mat.set_shader_parameter("albedo_tex",load(textured[id]))
		mat.set_shader_parameter("tile_size",tiles.get(id,2.0))
		mat.set_shader_parameter("tint",tints.get(id,Color.WHITE))
		mats[id] = mat
	var banner = StandardMaterial3D.new()
	banner.albedo_texture = load(FT+"banner_red.png")
	banner.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	banner.cull_mode = BaseMaterial3D.CULL_DISABLED
	banner.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	banner.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mats["banner"] = banner

func box(label: String, pos: Vector3, size: Vector3, material: String, solid: bool = true, parent: Node = null) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.name = label
	var shape = BoxMesh.new()
	shape.size = size
	shape.subdivide_width = mini(12,int(size.x))
	shape.subdivide_depth = mini(12,int(size.z))
	shape.subdivide_height = mini(8,int(size.y))
	mesh.mesh = shape
	mesh.material_override = mats[material]
	mesh.position = pos
	(parent if parent else geometry).add_child(mesh)
	if solid:
		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var collider = BoxShape3D.new()
		collider.size = size
		col.shape = collider
		body.add_child(col)
		mesh.add_child(body)
	return mesh

func blocker(pos: Vector3, size: Vector3, yaw: float = 0) -> void:
	# Invisible collision that matches a prop's visible blocking volume.
	var body = StaticBody3D.new()
	body.name = "PropCollision"
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = pos + Vector3(0,size.y*.5,0)
	body.rotation.y = yaw
	geometry.add_child(body)

func lamp(pos: Vector3, color: Color, energy: float = 1.6, radius: float = 9) -> void:
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	geometry.add_child(light)

func prop(id: String, pos: Vector3, yaw: float = 0, scale_factor = 1.0, solid: Vector3 = Vector3.ZERO) -> Node3D:
	var path = id if id.begins_with("res://") else "res://assets/models/"+id+".glb"
	var node = load(path).instantiate()
	node.name = path.get_file().get_basename().capitalize()
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale_factor if scale_factor is Vector3 else Vector3.ONE*scale_factor
	geometry.add_child(node)
	prepare_model(node)
	if solid != Vector3.ZERO: blocker(pos,solid,yaw)
	return node

func prepare_model(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.get_active_material(i)
			if original is StandardMaterial3D:
				var mat = original.duplicate()
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
				mat.metallic = 0.0
				mat.roughness = 1.0
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): prepare_model(child)

func sign_text(text: String, pos: Vector3, yaw: float = 0, color: Color = Color(.85,.73,.51), font_size: int = 36) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = .007
	label.modulate = color
	label.outline_size = 3
	label.position = pos
	label.rotation.y = yaw
	label.no_depth_test = false
	geometry.add_child(label)

func banner(pos: Vector3, yaw: float, height: float = 2.8) -> void:
	var mesh = MeshInstance3D.new()
	mesh.name = "FoxTexBanner"
	var quad = QuadMesh.new()
	quad.size = Vector2(height*.5,height)
	mesh.mesh = quad
	mesh.material_override = mats.banner
	mesh.position = pos
	mesh.rotation.y = yaw
	geometry.add_child(mesh)

func wall_segment(a: float, b: float, fixed: float, horizontal: bool, height: float, wall_mat: String = "plaster") -> void:
	if b-a < .05: return
	var middle = (a+b)*.5
	var pos = Vector3(middle,height*.5,fixed) if horizontal else Vector3(fixed,height*.5,middle)
	var size = Vector3(b-a,height,.35) if horizontal else Vector3(.35,height,b-a)
	box("Wall",pos,size,wall_mat)
	pos.y = .78
	size.y = 1.55
	size.z += .05 if horizontal else 0.0
	size.x += 0.0 if horizontal else .05
	box("WalnutPanelling",pos,size,"panel",false)
	for y in [1.58,height-.3]:
		pos.y = y
		size.y = .12
		box("Moulding",pos,size,"trim",false)
	# Going Medieval timber posts on both faces, every four metres.
	var post_scale = Vector3(1,height/3.1,1)
	for t in range(int(ceil(a))+2,int(b)-1,4):
		for face in [-.2,.2]:
			var p = Vector3(t,0,fixed+face) if horizontal else Vector3(fixed+face,0,t)
			prop(GM+"wood_support_beam_metal.glb",p,0.0 if horizontal else PI/2,post_scale)

func wall(a: float,b: float,fixed: float,horizontal: bool,height: float,openings: Array,wall_mat: String = "plaster") -> void:
	openings.sort_custom(func(x,y):return x[0]<y[0])
	var cursor = a
	for opening in openings:
		var left = opening[0]-opening[1]*.5
		var right = opening[0]+opening[1]*.5
		wall_segment(cursor,left,fixed,horizontal,height,wall_mat)
		var pos = Vector3(opening[0],(height+DOOR_H)*.5,fixed) if horizontal else Vector3(fixed,(height+DOOR_H)*.5,opening[0])
		box("DoorLintel",pos,Vector3(opening[1],height-DOOR_H,.36) if horizontal else Vector3(.36,height-DOOR_H,opening[1]),wall_mat)
		cursor = right
	wall_segment(cursor,b,fixed,horizontal,height,wall_mat)

func room(rect: Rect2, height: float, openings: Dictionary, floor_mat: String = "floor", wall_mat: String = "plaster") -> void:
	var x = rect.position.x
	var z = rect.position.y
	var ex = rect.end.x
	var ez = rect.end.y
	box("Foundation",Vector3((x+ex)/2,-.25,(z+ez)/2),Vector3(rect.size.x,.5,rect.size.y),floor_mat)
	box("Ceiling",Vector3((x+ex)/2,height+.2,(z+ez)/2),Vector3(rect.size.x,.4,rect.size.y),"dark")
	wall(x,ex,z,true,height,openings.get("north",[]),wall_mat)
	wall(x,ex,ez,true,height,openings.get("south",[]),wall_mat)
	wall(z,ez,x,false,height,openings.get("west",[]),wall_mat)
	wall(z,ez,ex,false,height,openings.get("east",[]),wall_mat)

func archway(pos: Vector3, yaw: float, width: float = 3.0) -> void:
	# A doorless opening still gets the Going Medieval stone door frame.
	prop(GM+"door_frame.glb",pos,yaw,width/2.38)

func build_architecture() -> void:
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.025,.028,.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.47,.52,.65)
	env.ambient_light_energy = .85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(.035,.045,.062)
	env.fog_light_energy = .65
	env.fog_density = .009
	world.environment = env
	geometry.add_child(world)
	room(Rect2(-8,-8,16,16),8,{"west":[[-4,3],[5,3]],"east":[[-5,3],[3,3.4]],"south":[[0,3.2],[5,3]]},"stone","plaster_red")
	room(Rect2(-22,2,14,6),4.6,{"east":[[5,3]],"north":[[-19,3]]})
	room(Rect2(-30,-14,16,16),6,{"south":[[-19,3]],"east":[[-4,3]],"north":[[-22,3]]})
	room(Rect2(-14,-5.5,6,3),4.6,{"west":[[-4,3]],"east":[[-4,3]]})
	room(Rect2(-30,-24,16,10),5,{"south":[[-22,3]]},"brick")
	room(Rect2(8,-14,24,22),9,{"west":[[-5,3],[3,3.4]],"south":[[22,3]]},"stone")
	room(Rect2(2,8,30,10),4.6,{"north":[[5,3],[22,3]]},"floor")
	wall(8,18,17,false,4.6,[[13,3]])
	for p in [[Vector3(-8,0,5),PI/2],[Vector3(-19,0,2),0.0],[Vector3(-14,0,-4),PI/2]]:
		archway(p[0],p[1])
	build_entrance()
	build_west_wing()
	build_armory()
	build_ritual_hall()
	build_east_wing()

func build_entrance() -> void:
	# Checkerboard floor and carpet runner (FoxTex marble and cushion textures).
	for x in range(-7,8,2):
		for z in range(-7,8,2):
			box("MarbleTile",Vector3(x,.012,z),Vector3(1.96,.02,1.96),"cream" if (x+z)%4==0 else "black",false)
	box("EntranceRunner",Vector3(0,.045,1.4),Vector3(3.1,.025,12),"red",false)
	# Grand stair: two Going Medieval timber flights side by side, over a smooth ramp collider.
	stairs(Vector3(-2.7,0,-1.0),5.4,5.4,3.35)
	prop(GM+"stairs_wood_wood_large.glb",Vector3(0,0,-3.75),0,Vector3(2.51,1.03,1.12))
	box("UpperLanding",Vector3(0,2.85,-7.15),Vector3(14,.3,1.7),"floor")
	for x in [-4.85,4.85]:
		prop(AB+"banister.glb",Vector3(x,3.0,-6.35),0,Vector3(.83,1,1))
		blocker(Vector3(x,3.0,-6.3),Vector3(4.3,1.1,.2))
	for x in [-6,6]:
		prop(PA+"statue_mary.glb",Vector3(x,0,-5.8),0,1.1,Vector3(1.1,2.6,1.1))
		prop(HW+"candle_cluster.glb",Vector3(x,0,-4.55),randf()*TAU,1.2)
		lamp(Vector3(x,3,-5),Color(.28,.48,1),2,10)
	# Chandelier (McPato House Interior).
	prop(HI+"chandelier.glb",Vector3(0,5.7,0),0,2.4)
	lamp(Vector3(0,5.4,0),Color(1,.62,.3),1.3,11)
	# Storage corner by the west wall: the chest itself is the storage entity.
	prop(HI+"floor_lamp.glb",Vector3(-7,0,2.6),0,1.0)
	lamp(Vector3(-6.8,1.9,2.4),Color(1,.66,.35),1.4,6)
	prop(VI+"wing_armchair.glb",Vector3(-6.6,0,-1.4),PI/2,1.1,Vector3(1,1.2,1))
	prop(HI+"potted_palm.glb",Vector3(-7.1,0,7.1),0,1.0)
	prop(PL+"calathea.glb",Vector3(-2.6,0,7.3),0,1.2)
	prop(PL+"sanseveria.glb",Vector3(2.6,0,7.3),0,1.0)
	prop(HI+"wall_clock.glb",Vector3(-7.79,2.6,1),0,1.4)
	# East seating between the ritual doors.
	prop(VI+"sofa.glb",Vector3(7.15,0,-1.6),-PI/2,1.0,Vector3(1.1,1,2.8))
	prop(VI+"round_table.glb",Vector3(5.4,0,-1.6),0,.75,Vector3(1,.7,1))
	prop(VI+"table_lamp.glb",Vector3(5.4,.68,-1.5),0,.9)
	prop(HI+"mirror_frame.glb",Vector3(7.79,2.9,-1.6),-PI/2,2.4)
	prop(HI+"coat_rack.glb",Vector3(-1.9,0,7.35),0,1.0)
	prop(HI+"dresser.glb",Vector3(7.28,0,5.9),0,1.0,Vector3(.95,1,2.2))
	prop(PA+"portrait_woman.glb",Vector3(7.55,1.01,5.4),-PI/2,2.2)
	prop(PA+"portrait_man.glb",Vector3(7.55,1.01,6.4),-PI/2,2.2)
	prop(PA+"amphora.glb",Vector3(-3.4,0,-1.4),0,1.4)
	prop(HI+"vase_tall.glb",Vector3(3.4,0,-1.4),0,1.2)
	for x in [-2.2,2.2]:
		prop(TP+"valsekamerplant/fences/plaster_wall_column_fancy.glb",Vector3(x,0,7.6),0,Vector3(1.2,1.6,1.2))
	prop(PL+"pot3.glb",Vector3(-6,0,-3.6),0,1.3)
	prop(PA+"candle_pillar.glb",Vector3(5.2,.68,-1.9),0,1.2)
	prop(AB+"trash_scatter_b.glb",Vector3(6,.01,5.8),.7,.6)
	for x in [-4.7,4.7]:
		window(Vector3(x,3.9,-7.8),0,1.7)
	sign_text("WEST WING",Vector3(-7.73,3.6,5),PI/2)
	sign_text("RITUAL HALL",Vector3(7.73,3.8,3),-PI/2)
	sign_text("THE HOUSE REMEMBERS",Vector3(0,5.9,-7.75),0,Color(.65,.54,.37),42)
	sign_text("EXIT",Vector3(0,3.6,7.7),PI)
	lamp(Vector3(0,6,1),Color(.65,.63,.56),2.1,15)

func build_west_wing() -> void:
	# West corridor: a lane down the middle, furniture pushed to the walls.
	for x in [-12,-17]:
		window(Vector3(x,1.1,7.8),PI,1.25)
	prop(HI+"cabinet.glb",Vector3(-10.4,0,7.45),PI,1.0,Vector3(.95,.95,.8))
	prop(PA+"candle_pillar.glb",Vector3(-10.4,.95,7.45),0,1.4)
	prop(AB+"vanity.glb",Vector3(-14.6,0,7.6),-PI/2,1.0)
	prop(PA+"candle_pillar.glb",Vector3(-14.9,.8,7.55),0,1.2)
	prop(VI+"wooden_chair.glb",Vector3(-18.6,0,7.3),PI+.4,1.0)
	prop(AB+"armchair_fallen.glb",Vector3(-21,0,3.2),.8,.9)
	prop(AB+"trash_scatter.glb",Vector3(-16,.01,6.6),.3,.7)
	prop(HI+"laundry_basket.glb",Vector3(-9.3,0,2.6),.2,.8)
	prop(HI+"broom.glb",Vector3(-12.6,0,2.35),0,1.0)
	prop(KR+"bucket.glb",Vector3(-13.2,0,2.5),0,.45)
	prop(HI+"mirror_frame.glb",Vector3(-15.5,2.4,2.2),0,1.8)
	prop(VI+"wardrobe_open.glb",Vector3(-11.2,0,2.45),0,1.0,Vector3(1.4,2,.5))
	prop(VI+"trash_can.glb",Vector3(-9.6,0,7.4),0,.8)
	prop(KR+"alarm_clock.glb",Vector3(-10.2,.95,7.5),PI,.3)
	prop(VI+"bottle.glb",Vector3(-14.4,.8,7.7),0,1.0)
	prop(MT+"news_stack.glb",Vector3(-18.2,.01,3.1),.8,.4)
	prop(GM+"door_wood_rounded.glb",Vector3(-15,0,2.2),0,1.3)
	prop(GM+"door_wood_rounded.glb",Vector3(-13,0,7.8),PI,1.3)
	prop(AB+"armchair_toppled.glb",Vector3(-20.6,0,6.6),2.2,.9)
	for x in [-12,-17]:
		prop(GM+"stone_windowsil.glb",Vector3(x,1.05,7.7),PI,1.3)
	for x in [-11,-16,-21]:
		lamp(Vector3(x,2.4,5.3),Color(1,.39,.17),1.3,7)
	# Library: bookcases give the room its rhythm; the crest waits on a lit desk.
	for x in [-27.3,-25.8,-18.3,-16.8]:
		prop(HI+"bookcase_books.glb",Vector3(x,0,-13.4),-PI/2,1.15,Vector3(1.5,2.6,.8))
	var west = [[-11.5,"bookcase_a"],[-9.7,"bookcase_b"],[-7.9,"bookcase_a"],[-3.4,"bookcase_b"]]
	for entry in west:
		prop(VI+entry[1]+".glb",Vector3(-29.45,0,entry[0]),PI/2,1.0,Vector3(.8,1.9,1.7))
	for z in [-6.2,-1.6]:
		prop(OF+"book_case.glb",Vector3(-29.6,0,z),PI/2,Vector3(.8,1,1.2),Vector3(.6,2.5,1.6))
		prop(OF+"books.glb",Vector3(-29.55,2.5,z),PI/2,1.0)
	prop(OF+"desk1_alt3_weathered.glb",Vector3(-19.6,0,-8.6),PI,1.0,Vector3(2.4,.9,1.5))
	prop(OF+"circular_desklamp.glb",Vector3(-20.5,.89,-8.9),.4,1.2)
	prop(OF+"paper_stack.glb",Vector3(-18.9,.89,-8.8),.3,1.0)
	prop(OF+"books_alt.glb",Vector3(-18.6,.89,-9.2),.1,1.0)
	prop(VI+"carved_chair.glb",Vector3(-19.6,0,-10),0,1.0)
	lamp(Vector3(-19.6,2.7,-8.6),Color(1,.53,.22),1.9,7)
	prop(OF+"armchair_red.glb",Vector3(-17.2,0,-11.2),PI,1.0,Vector3(1.3,1.1,1.3))
	prop(OF+"armchair_red.glb",Vector3(-15.1,0,-11.2),PI,1.0,Vector3(1.3,1.1,1.3))
	prop(VI+"round_table.glb",Vector3(-16.15,0,-12.8),0,.7)
	prop(VI+"table_lamp.glb",Vector3(-16.3,.64,-12.8),0,.8)
	lamp(Vector3(-16.2,1.6,-12.2),Color(1,.64,.36),1.0,5)
	prop(AB+"floor_lamp_old.glb",Vector3(-21.3,0,-9.9),0,1.0)
	prop(PL+"Bird_of_paradise_cluster_1.glb",Vector3(-15,0,1.2),0,1.0)
	prop(PL+"calathea.glb",Vector3(-29.1,0,1.3),0,1.1)
	prop(HI+"mirror_frame.glb",Vector3(-14.21,2.8,-9.5),PI/2,2.0)
	prop(HI+"vase_floral.glb",Vector3(-14.6,0,-1.2),0,1.6)
	prop(AB+"worn_armchair.glb",Vector3(-26.8,0,-.8),-.6,1.0)
	prop(VI+"armchair_round.glb",Vector3(-23.6,0,-.9),.5,1.0)
	# Fireplace chimney breast on the south wall.
	prop(GM+"chimney_large.glb",Vector3(-25.2,0,1.2),PI,Vector3(1.1,.74,1))
	blocker(Vector3(-25.2,0,1.2),Vector3(1.3,6,1.2))
	lamp(Vector3(-25.2,.8,0.2),Color(1,.45,.15),1.6,6)
	# Second study table, a freestanding shelf row and a sitting corner.
	prop(HI+"desk.glb",Vector3(-25.5,0,-3.8),PI/2,1.0,Vector3(1,1,2.2))
	prop(VI+"desk_lamp.glb",Vector3(-25.5,1.0,-4.6),0,.8)
	prop(OF+"paper_stack_large.glb",Vector3(-25.4,1.0,-3.6),.2,1.0)
	prop(OF+"mug.glb",Vector3(-25.3,1.0,-3.0),0,1.0)
	prop(HI+"radio.glb",Vector3(-25.6,1.0,-2.8),PI/2,.7)
	prop(VI+"wooden_chair.glb",Vector3(-24.4,0,-3.8),-PI/2,1.0)
	lamp(Vector3(-25.5,2.2,-3.8),Color(1,.6,.3),1.2,6)
	for z in [-9.4,-5.4]:
		prop(OF+"book_case_with_back.glb",Vector3(-24.5,0,z-.26),PI,Vector3(1,.9,1),Vector3(2,2.3,1))
		prop(OF+"book_case_with_back.glb",Vector3(-24.5,0,z+.26),0,Vector3(1,.9,1))
		prop(OF+"books_alt2.glb",Vector3(-24.2,2.26,z),0,1.0)
		prop(OF+"books.glb",Vector3(-25,2.26,z),0,1.0)
	prop(OF+"couch_large_red.glb",Vector3(-14.8,0,-6.2),-PI/2,1.0,Vector3(1.3,1,3.1))
	prop(VI+"sideboard.glb",Vector3(-14.5,0,-2.3),-PI/2,1.0,Vector3(.7,1,1.7))
	prop(PA+"amphora.glb",Vector3(-14.5,1.05,-2.6),0,1.0)
	prop(OF+"wall_clock.glb",Vector3(-14.2,3,-6.2),-PI/2,1.0)
	lamp(Vector3(-20,3.2,-10),Color(1,.6,.35),1.4,9)
	lamp(Vector3(-26,3.2,-4),Color(1,.6,.35),1.2,8)
	for x in [-18,-26]:
		lamp(Vector3(x,3.8,-6),Color(.58,.68,1),1.9,11)
	sign_text("ARMORY  /  IRON SEAL",Vector3(-22,4.1,-13.72))
	sign_text("LIBRARY",Vector3(-19,3.4,1.73),PI)
	sign_text("F  /  PARRY THE EMBER",Vector3(-29.1,3.9,-7),PI/2,Color(.55,.77,.66),30)

func build_armory() -> void:
	# Two workbenches (Going Medieval market tables) hold the supplies.
	for x in [-27,-17]:
		prop(GM+"table.glb",Vector3(x,.88,-20),0,1.0,Vector3(3.1,.9,1.4))
		lamp(Vector3(x,3,-20),Color(.55,.83,.63),1.8,8)
	prop(DT+"toolbox_full.glb",Vector3(-28.2,.88,-19.9),.2,1.0)
	prop(DW+"colt_python.glb",Vector3(-25.7,.9,-20.4),1.2,1.0)
	prop(RC+"chainsaw.glb",Vector3(-15.9,1.06,-20.1),.5,.03)
	var tilted1 = prop(DT+"pipe_wrench.glb",Vector3(-18.4,.9,-20.4),0,Vector3(1,1,1))
	tilted1.rotation.x = -PI/2
	# Rifle rack on the back wall.
	for i in 3:
		var rifle = prop([DW+"fal_rifle.glb",DW+"akm_rifle.glb",DW+"fal_rifle.glb"][i],Vector3(-23.3+i*1.2,.75,-23.7),0,1.0)
		rifle.rotation.z = PI/2
	prop(GM+"wood_support_beam.glb",Vector3(-22.1,2.3,-23.7),0,Vector3(2,1,1))
	prop(DT+"hammer.glb",Vector3(-20.2,1.6,-23.75),0,1.2)
	prop(DT+"back_saw.glb",Vector3(-19.4,1.7,-23.75),0,1.2)
	# Lockers, tools and a crate stack in the corners.
	for x in [-29.3,-28.3]:
		prop(KR+"metal_locker.glb",Vector3(x,0,-23.4),-PI/2,Vector3(1,.95,1),Vector3(.85,2.3,.8))
	var tilted2 = prop(MF+"axe.glb",Vector3(-29.6,0,-17.2),0,.4)
	tilted2.rotation.z = .12
	var tilted3 = prop(MF+"pitchfork.glb",Vector3(-29.6,0,-16.4),0,.4)
	tilted3.rotation.z = .1
	prop(KR+"scythe.glb",Vector3(-29.5,0,-15.5),PI/2,.9)
	for p in [Vector3(-20.6,0,-23.4),Vector3(-20.6,.24,-23.4),Vector3(-19.7,0,-23.4)]:
		prop(GM+"crate.glb",p,PI/2,1.0)
	prop(GM+"jutesack_closed.glb",Vector3(-18.6,0,-23.3),.4,1.0)
	prop(KS+"gas_mask.glb",Vector3(-20.6,.5,-23.4),.4,.22)
	var tilted4 = prop(KS+"crowbar.glb",Vector3(-21.4,0,-23.6),0,1.0)
	tilted4.rotation.x = .2
	# Medical shelf.
	prop(OF+"file_cabinet_large_shelf_fancy.glb",Vector3(-14.4,0,-21.6),-PI/2,1.0,Vector3(.4,.7,1.45))
	prop(RM+"Med_1.glb",Vector3(-14.4,.72,-22.1),PI/2,.01)
	prop(DH+"health_kit.glb",Vector3(-14.35,.72,-21.3),0,1.3)
	prop(DH+"pill_bottle.glb",Vector3(-14.35,.72,-20.9),0,1.0)
	prop(RM+"Med_12.glb",Vector3(-14.45,.78,-21.6),0,.01)
	prop(DH+"bandage.glb",Vector3(-14.4,0,-20.4),0,1.0)
	prop(RM+"Med_2.glb",Vector3(-14.5,0,-22.6),-PI/2,.01)
	prop(RM+"Med_9.glb",Vector3(-14.45,.72,-22.4),0,.01)
	prop(RM+"Med_3.glb",Vector3(-14.45,.72,-20.8),0,.01)
	prop(RM+"Med_16.glb",Vector3(-14.35,1.4,-21.6),-PI/2,.01)
	prop(GM+"wood_support_corner.glb",Vector3(-29.4,0,-23.4),0,Vector3(1,1.6,1))
	prop(GM+"wood_support_corner.glb",Vector3(-14.6,0,-23.4),-PI/2,Vector3(1,1.6,1))
	for x in [-27,-17]:
		prop(HI+"mirror_frame.glb",Vector3(x,3.2,-23.8),0,2.0)
	sign_text("TAKE WHAT YOU CAN CARRY",Vector3(-22,3.9,-23.7))
	lamp(Vector3(-22,4,-18),Color(.7,.6,.4),1.7,12)

func build_ritual_hall() -> void:
	box("RitualRunner",Vector3(20,.02,-3),Vector3(6,.025,18),"red",false)
	for x in [12,28]:
		for z in [-10,-3,5]:
			box("ColumnBase",Vector3(x,.25,z),Vector3(1.4,.5,1.4),"stone")
			box("Column",Vector3(x,4,z),Vector3(.8,8,.8),"brick")
			box("ColumnCapital",Vector3(x,7.5,z),Vector3(1.3,.3,1.3),"trim",false)
			lamp(Vector3(x,3,z),Color(.9,.12,.07),2.4,9)
			prop(PA+"candle_pillar.glb",Vector3(x+.45,.5,z+.45),0,1.6)
			prop(KF+"bracket_fungus.glb",Vector3(x+(.42 if x < 20 else -.42),2.4+randf(),z),(PI/2 if x < 20 else -PI/2),2.5)
	# Timber ritual stair in two flights up to the balcony.
	stairs(Vector3(27,0,5),3.2,12.3,3.5)
	prop(GM+"stairs_wood_wood_large.glb",Vector3(28.6,0,1.93),0,Vector3(1.49,.54,1.28))
	prop(GM+"stairs_wood_wood_large.glb",Vector3(28.6,1.75,-4.22),0,Vector3(1.49,.54,1.28))
	box("RitualBalcony",Vector3(23,3.05,-9),Vector3(16,.3,4),"stone")
	for x in [18.2,23.4]:
		prop(AB+"banister.glb",Vector3(x,3.2,-7.05),0,1.0)
	blocker(Vector3(20.8,3.2,-7),Vector3(10.6,1.1,.2))
	for x in [16.5,25.5]:
		prop(GM+"vine_hanging.glb",Vector3(x,2.9,-6.95),0,1.2)
	prop(GM+"vine_hanging_alt.glb",Vector3(29.5,2.9,-6.95),0,1.0)
	# The altar and seal: the Housekeeper's arena focal point.
	prop(PA+"ritual_disc.glb",Vector3(20,0,-10),0,1.2)
	prop(PA+"altar_stone.glb",Vector3(20,.18,-10),0,1.25,Vector3(2.6,1.5,1.9))
	prop(HW+"severed_head.glb",Vector3(19.6,1.62,-10),.6,1.3)
	prop(PA+"wine_bottle.glb",Vector3(20.8,1.62,-10.2),0,1.0)
	for p in [Vector3(17.4,.16,-11.9),Vector3(22.6,.16,-11.9),Vector3(17,.16,-8.2),Vector3(23,.16,-8.2)]:
		prop(HW+"candle_cluster.glb",p,randf()*TAU,1.3)
	var cross = prop(PA+"cross_wood.glb",Vector3(20,5.6,-13.75),0,2.2)
	cross.rotation.z = PI
	prop(HW+"body_bag.glb",Vector3(13.6,0,-12.6),.6,1.0)
	prop(HW+"body_wrapped.glb",Vector3(26.2,0,-13),-.3,1.0)
	prop(HW+"coffin.glb",Vector3(10.6,0,-11.6),.25,1.0)
	prop(HW+"tomb_cross.glb",Vector3(30.4,0,-12.6),PI/2,1.0,Vector3(1.8,1.3,.95))
	prop(HW+"severed_leg.glb",Vector3(15.8,0,6.4),1.1,1.0)
	prop(HW+"severed_arm.glb",Vector3(24.3,0,-5.6),.3,1.0)
	prop(AB+"trash_scatter.glb",Vector3(11,.01,-1),1.2,.7)
	# Stone cover blocks (Going Medieval) where the old boxes stood.
	for z in [-4,2]:
		for x in [15.5,24.5]:
			prop(GM+"stone_square_half_1m.glb",Vector3(x,0,z),0,Vector3(.8,1.3,.65),Vector3(1.6,1.3,1.3))
	prop(DJ+"vase.glb",Vector3(15.1,1.3,2.1),0,1.3)
	# The rift: a pale dead tree splitting the floor, graves and a railed seal.
	prop(HW+"dead_tree_pale.glb",Vector3(12.8,0,-12.2),.4,.6)
	for p in [Vector3(9.4,0,-4.5),Vector3(9.4,0,-2.2)]:
		prop(HW+"gravestone.glb",p,PI/2,1.0)
	for p in [[Vector3(17.2,0,-10),PI/2],[Vector3(22.8,0,-10),PI/2]]:
		prop(HW+"iron_fence.glb",p[0],p[1],Vector3(.5,.45,1))
	prop(HW+"broken_wall.glb",Vector3(30.2,0,-4),PI/2,.8)
	prop(KF+"log.glb",Vector3(11.4,0,-10.6),1.1,1.4)
	prop(KF+"stump.glb",Vector3(14.2,0,-11),0,2.0)
	for p in [Vector3(9.3,0,-6.2),Vector3(9.3,0,-.6)]:
		prop(TP+"valsekamerplant/fences/drystone_column_capped.glb",p,0,1.0)
		prop(PA+"candle_pillar.glb",p+Vector3(0,.95,0),0,1.4)
	prop(TP+"valsekamerplant/fences/metalfence_one_side_topbar.glb",Vector3(15.1,3.2,-9),PI/2,Vector3(1.4,.7,1))
	blocker(Vector3(15.1,3.2,-9),Vector3(.2,1.1,4))
	for x in [16.2,29.8]:
		prop(GM+"stone_square_half_2m.glb",Vector3(x,0,-9.8),0,Vector3(.35,1.5,.35))
	for x in [12,28]:
		prop(GM+"vine_corner.glb",Vector3(x,0,-2.6),0,1.0)
	for z in [-10,-3,4]:
		banner(Vector3(8.2,5.2,z),PI/2,3.0)
		window(Vector3(31.8,3.4,z),PI,1.0,true)
	sign_text("OFFER THE HOUSE ITS KEEPER",Vector3(20,7.6,-13.7),0,Color(.9,.3,.18),42)
	lamp(Vector3(20,6,-2),Color(.35,.45,.8),2,15)

func build_east_wing() -> void:
	sign_text("EAST WING",Vector3(5,3.6,7.73),PI)
	sign_text("SERVANTS' HALL",Vector3(5,3.5,8.27),0,Color(.8,.7,.5),30)
	sign_text("STOREROOM",Vector3(16.8,3.6,13),-PI/2,Color(.85,.3,.2),30)
	sign_text("THEY SLEPT HERE. THEY STILL DO.",Vector3(9.5,3.6,17.78),PI,Color(.55,.2,.16),26)
	# Servants' hall: mattresses and an old bed, a long table laid for a meal nobody ate.
	prop(AB+"old_bed.glb",Vector3(4.3,0,16.3),PI/2,1.0,Vector3(1.4,.8,2.5))
	for x in [7.0,9.8,12.6]:
		prop(DJ+"mattress.glb",Vector3(x,0,16.6),PI/2+randf_range(-.08,.08))
	prop(VI+"cloth_table.glb",Vector3(12,0,11.5),0,1.0,Vector3(2.1,.85,1.2))
	for p in [[Vector3(10.9,0,10.5),PI],[Vector3(13.1,0,10.5),PI],[Vector3(10.9,0,12.5),0.0],[Vector3(12,0,12.6),.25]]:
		prop(HI+"dining_chair.glb",p[0],p[1],1.0)
	for p in [[NK+"dirty_plate.glb",Vector3(11.2,.84,11.2)],[NK+"clean_plate.glb",Vector3(12.8,.84,11.8)],[NK+"bowl_01.glb",Vector3(11.4,.9,11.8)],[NK+"empty_glass.glb",Vector3(12.6,.9,11.2)],[NK+"beer_bottle.glb",Vector3(10.6,.99,11.6)],[NK+"fork.glb",Vector3(11.7,.85,11.1)],[NK+"knife_block.glb",Vector3(10.4,1.0,11.9)]]:
		prop(p[0],p[1],randf()*TAU,1.0)
	prop(PA+"candle_pillar.glb",Vector3(10.3,.84,11.2),0,1.3)
	prop(DJ+"shelf.glb",Vector3(2.45,0,11.5),PI,1.0,Vector3(.4,1.6,1))
	prop(VI+"radio_old.glb",Vector3(2.5,1.6,11.3),PI/2,1.0)
	prop(DJ+"couch.glb",Vector3(15.6,0,16.5),-PI/2-.2,1.0)
	prop(DJ+"vase.glb",Vector3(2.5,1.62,11.8))
	prop(HI+"laundry_basket.glb",Vector3(3.2,0,9.2),.3,.9)
	prop(HI+"dresser.glb",Vector3(9.2,0,8.78),PI/2,1.0,Vector3(.95,1,2.2))
	prop(HI+"wine_bottle.glb",Vector3(8.6,1.0,8.8),0,.8)
	prop(OF+"mug.glb",Vector3(9.5,1.0,8.8),0,1.0)
	prop(HI+"dining_table.glb",Vector3(12.5,0,8.95),0,.85,Vector3(2.1,.7,1.3))
	prop(NK+"glass_of_water.glb",Vector3(12.1,.72,8.8),0,1.0)
	prop(NK+"spoon.glb",Vector3(12.8,.69,9.0),.4,1.0)
	prop(AB+"bathtub.glb",Vector3(14.6,0,9.1),0,1.0,Vector3(2,.9,1))
	prop(VI+"iron_bed.glb",Vector3(4.3,0,12.6),PI/2,1.0,Vector3(2.5,1,1.7))
	prop(HI+"broom.glb",Vector3(16.5,0,9.2),0,1.0)
	prop(NK+"pan.glb",Vector3(6.2,.05,9.4),.8,1.0)
	prop(KS+"bottles.glb",Vector3(16.3,0,15),0,.45)
	prop(AB+"trash_scatter_b.glb",Vector3(8.5,.01,13.6),.9,.6)
	for x in [5,11]:
		lamp(Vector3(x,3.4,13),Color(1,.62,.3),1.4,8)
	# Storeroom: barrels, crates, sacks and the flare gun on a crate stack.
	for p in [Vector3(30.4,0,16.4),Vector3(29,0,16.6),Vector3(30.6,0,9.6)]:
		prop(GM+"barrel.glb",p,randf()*TAU,1.0,Vector3(1.0,1.2,1.0))
	prop(GM+"barrel_small.glb",Vector3(18.3,0,16.8),.4,1.0)
	for p in [Vector3(26,0,16.6),Vector3(26,.24,16.6),Vector3(24.9,0,16.7),Vector3(19,0,9.2)]:
		prop(GM+"crate.glb",p,PI/2,1.0)
	blocker(Vector3(25.6,0,16.6),Vector3(2,.5,.6))
	for p in [Vector3(22.4,0,17.3),Vector3(21.5,0,17.3)]:
		prop(GM+"jutesack_closed.glb",p,randf()*TAU,1.0)
	prop(GM+"jutesack_open.glb",Vector3(20.2,0,9.1),.5,1.0)
	prop(GM+"terracotta_vase.glb",Vector3(31.2,0,11.4),0,.9)
	prop(GM+"terracotta_vase_small.glb",Vector3(31.3,0,12.2),0,.9)
	prop(GM+"backet.glb",Vector3(27.8,0,9.1),0,.7)
	prop(MF+"wheelbarrow.glb",Vector3(23.5,0,9.6),PI/2,.4)
	var tilted5 = prop(KR+"shovel.glb",Vector3(31.6,0,15),0,1.0)
	tilted5.rotation.z = .15
	prop(KR+"metal_locker.glb",Vector3(18,0,11.2),0,Vector3(1,.95,1),Vector3(.85,2.3,.85))
	prop(DJ+"shelf.glb",Vector3(31.55,0,13),0,1.0,Vector3(.4,1.6,1))
	for p in [[MT+"tin.glb",Vector3(27.5,.48,16.6)],[MT+"can_crushed.glb",Vector3(21,0,12.4)],[MT+"paper_bag.glb",Vector3(30.2,1.62,13.2)],[MT+"litter.glb",Vector3(24.5,.01,12.8)],[KS+"old_lock.glb",Vector3(18.3,1.1,11.6)]]:
		prop(p[0],p[1],randf()*TAU,.4)
	prop(DT+"toolbox_full.glb",Vector3(20.6,0,17.2),.4,1.0)
	prop(GM+"barrel_open.glb",Vector3(27.6,0,13.8),0,1.0,Vector3(1,1.2,1))
	prop(GM+"crate_angled.glb",Vector3(19.4,0,15.6),.6,1.0)
	for p in [[MF+"hatchet.glb",Vector3(31.6,.2,10.6)],[MF+"hoe.glb",Vector3(31.6,0,14.2)],[MF+"rake.glb",Vector3(31.65,0,15.6)]]:
		var tool = prop(p[0],p[1],PI/2,.4)
		tool.rotation.z = .12
	prop(MF+"wood_bucket.glb",Vector3(21.4,0,9.2),0,.4)
	prop(RM+"Med_13.glb",Vector3(31.45,1.62,12.7),0,.01)
	prop(RM+"Med_14.glb",Vector3(31.45,1.62,13.3),0,.01)
	prop(RM+"Med_18.glb",Vector3(31.5,.85,13),0,.01)
	lamp(Vector3(24,3.4,13),Color(.45,.85,.35),1.6,9)
	lamp(Vector3(29,3.2,16),Color(1,.45,.2),.9,5)
	for x in [6.5,12.5,26]:
		window(Vector3(x,1.1,17.8),PI,1.25)

func window(pos: Vector3, yaw: float, s: float = 1.6, gothic: bool = false) -> void:
	if gothic:
		prop(PA+"window_gothic.glb",pos,yaw,2.2)
		lamp(pos+Vector3(-1.2,2,0),Color(.25,.43,.8),1.3,7)
	else:
		prop(GM+"window_rounded.glb",pos,yaw,s)
		lamp(pos+Vector3(0,1.2*s,1).rotated(Vector3.UP,yaw),Color(.25,.43,.8),1.3,7)

func stairs(origin: Vector3,width: float,length: float,height: float) -> void:
	# Collision only: a smooth ramp under the visible stair model.
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var wedge = ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([Vector3(0,0,0),Vector3(width,0,0),Vector3(0,0,-length),Vector3(width,0,-length),Vector3(0,height,-length),Vector3(width,height,-length)])
	shape.shape = wedge
	body.add_child(shape)
	body.position = origin
	geometry.add_child(body)

func door(label: String,pos: Vector3,yaw: float,key: String,kind: String = "normal",width: float = 3.0):
	var node = load("res://scripts/door.gd").new()
	node.name = label.replace(" ","")
	node.title = label
	node.key_id = key
	node.kind = kind
	node.width = width
	node.position = pos
	node.rotation.y = yaw
	entities.add_child(node)
	return node

func pickup(id: String,pos: Vector3,count: int = 1,loaded: int = 0):
	var node = load("res://scripts/pickup.gd").new()
	node.item_id = id
	node.amount = count
	node.loaded = loaded
	node.position = pos
	entities.add_child(node)
	return node

func note(title: String,pos: Vector3,body: String):
	var node = load("res://scripts/note.gd").new()
	node.title = title
	node.body = body
	node.position = pos
	node.rotation.y = randf_range(-.4,.4)
	entities.add_child(node)
	return node

func enemy(id: String,pos: Vector3,rect: Rect2,arena: bool = false):
	var node = load("res://scripts/enemy.gd").new()
	node.enemy_id = id
	node.position = pos
	node.bounds = rect
	node.arena_member = arena
	entities.add_child(node)
	return node

func populate() -> void:
	door("ARMORY",Vector3(-22,0,-14),0,"iron_key")
	door("LIBRARY SHORTCUT",Vector3(-8,0,-4),PI/2,"","shortcut")
	door("FRONT GATE",Vector3(0,0,8),0,"","exit",3.2)
	arena_door = door("RITUAL HALL",Vector3(8,0,3),PI/2,"crimson_key","normal",3.4)
	return_door = door("RITUAL RETURN",Vector3(8,0,-5),PI/2,"")
	return_door.sealed = true
	door("EAST WING",Vector3(5,0,8),0,"")
	door("STOREROOM",Vector3(17,0,13),PI/2,"crimson_key")
	side_door = door("RITUAL SIDE DOOR",Vector3(22,0,8),0,"")
	var chest = load("res://scripts/chest.gd").new()
	chest.position = Vector3(-5,0,1)
	entities.add_child(chest)
	pickup("bullets",Vector3(-5,1.3,1),18)
	pickup("herb",Vector3(-12,.55,7))
	pickup("bullets",Vector3(-20,.5,7),24)
	pickup("iron_key",Vector3(-19.6,1.2,-8.5))
	pickup("herb",Vector3(-27,.5,-11))
	pickup("herb",Vector3(-26,.5,-11))
	pickup("bullets",Vector3(-15.9,.95,-12.9),24)
	pickup("shotgun",Vector3(-27,1.2,-20),1,4)
	pickup("shells",Vector3(-26.3,1.15,-19.8),8)
	pickup("crimson_key",Vector3(-17,1.25,-20))
	pickup("medicine",Vector3(-18,1.15,-19.8))
	pickup("shells",Vector3(29,3.7,-9),8)
	pickup("bullets",Vector3(16,3.7,-10),30)
	pickup("herb",Vector3(29,.5,6))
	pickup("powder",Vector3(22,3.6,-10.5))
	# West wing secrets.
	pickup("powder",Vector3(-20.2,.4,7.4))
	pickup("powder",Vector3(-29,.4,1))
	# East wing: the SMG, supplies and the storeroom flare gun.
	pickup("smg",Vector3(12,1.05,11.5),1,30)
	pickup("bullets",Vector3(4.3,.7,16.3),24)
	pickup("powder",Vector3(7,.35,16.6))
	pickup("herb",Vector3(15.4,.8,16.4))
	pickup("flare",Vector3(26,.75,16.6),1,1)
	pickup("flares",Vector3(24.9,.5,16.7),2)
	pickup("shells",Vector3(19,.55,9.2),6)
	pickup("powder",Vector3(31.4,1.75,13))
	note("HUNTER'S CONTRACT",Vector3(-5.5,.96,.9),"Retrieve the Housekeeper's heart, or burn the house around it.\n\nThe family paid in advance. None of them answered the door.\n\nTools left for you: a chest by the stair. Travel light. The house punishes greed.")
	note("SERVANT'S DIARY",Vector3(13.4,.86,11.4),"The Housekeeper says we must sleep in shifts so the house is never alone.\n\nMartha stopped sleeping. Then her antlers came in.\n\nThe master's gun is locked in the storeroom. The crimson crest opens it. I pray nobody ever needs it.")
	note("STOREROOM LEDGER",Vector3(19.9,.02,10.1),"Flares: two left. DO NOT fire indoors.\n\nBlack powder keeps in the sacks. One sack makes a box of pistol rounds, two make shells.\n\nThe side door opens straight onto the ritual floor. Keep it shut when they are singing.")
	enemy("thrall",Vector3(-14,.1,4),Rect2(-22,2,14,6))
	enemy("thrall",Vector3(-20,.1,6),Rect2(-22,2,14,6))
	enemy("caster",Vector3(-25,.1,-7),Rect2(-30,-14,16,16))
	enemy("thrall",Vector3(-18,.1,-10),Rect2(-30,-14,16,16))
	var wing = Rect2(2,8,15,10)
	for p in [Vector3(9,.1,15),Vector3(13,.1,14.5),Vector3(6,.1,12.5)]:
		enemy("swarmer",p,wing)
	enemy("thrall",Vector3(24,.1,12),Rect2(17,8,15,10))

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(Game.player) or Game.mode != "playing": return
	var p: Vector3 = Game.player.global_position
	if p.x > 10 and p.z < 7.8 and not Game.arena_started:
		start_arena()
	var current_room = "ENTRANCE HALL"
	if p.z > 8.2 and p.x > 2:
		current_room = "SERVANTS' HALL" if p.x < 17 else "STOREROOM"
	elif p.x < -8:
		current_room = "WEST CORRIDOR" if p.z > 2 else ("ARMORY" if p.z < -14 else "THE LIBRARY")
	elif p.x > 8:
		current_room = "RITUAL HALL" if p.y < 2.9 else "RITUAL BALCONY"
	elif p.y > 2.6:
		current_room = "UPPER LANDING"
	if current_room != room_last:
		room_last = current_room
		Game.room_name = current_room
		if is_instance_valid(Game.ui): Game.ui.room_time = 3.5

func start_arena() -> void:
	Game.arena_started = true
	arena_door.set_seal(true)
	side_door.set_seal(true)
	Game.set_objective("The ritual begins. Defeat the house's servants.")
	Sound.combat(true)
	for pair in [["thrall",Vector3(16,.1,-2)],["thrall",Vector3(24,.1,3)],["caster",Vector3(25,.1,-6)],["caster",Vector3(16,.1,-10)],["swarmer",Vector3(14,.1,4)],["swarmer",Vector3(26,.1,-2)],["swarmer",Vector3(18,.1,-12)]]:
		var node = enemy(pair[0],pair[1],Rect2(8,-14,24,22),true)
		node.active = true

func check_wave() -> void:
	if boss_spawned: return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.arena_member and not node.dead: return
	boss_spawned = true
	var boss = enemy("guardian",Vector3(20,.1,-8),Rect2(8,-14,24,22),true)
	boss.active = true
	Game.set_objective("THE HOUSEKEEPER — break its hold on the mansion.")

func release_arena() -> void:
	arena_door.set_seal(false)
	return_door.set_seal(false)
	side_door.set_seal(false)

func burst(pos: Vector3,color: Color,count: int) -> void:
	if particle_count > 140: return
	for i in count:
		var mesh = MeshInstance3D.new()
		var shape = BoxMesh.new()
		shape.size = Vector3.ONE*randf_range(.035,.10)
		mesh.mesh = shape
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mesh.material_override = mat
		mesh.position = pos
		add_child(mesh)
		particle_count += 1
		var end = pos+Vector3(randf_range(-.7,.7),randf_range(-.8,.4),randf_range(-.7,.7))
		var tween = create_tween()
		tween.tween_property(mesh,"position",end,.25)
		tween.parallel().tween_property(mesh,"scale",Vector3.ONE*.05,.4)
		tween.tween_callback(func(): mesh.queue_free(); particle_count -= 1)

func drop_item(item: Dictionary) -> void:
	var start: Vector3 = Game.player.global_position+Vector3.UP
	var end = start-Game.player.transform.basis.z*1.3
	var query = PhysicsRayQueryParameters3D.create(start,end,1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): end = hit.position+hit.normal*.55
	pickup(item.id,Vector3(end.x,Game.player.global_position.y+.45,end.z),item.count,item.loaded)

