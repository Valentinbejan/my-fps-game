extends StaticBody3D
@export var key_id: String = ""
@export var title: String = "DOOR"
@export var kind: String = "normal"
@export var width: float = 3.0
var opened: bool = false
var sealed: bool = false
var visual: Node3D
var collider: CollisionShape3D
var leaves: Array = []

func _ready() -> void:
	collision_layer = 1|8
	collision_mask = 0
	add_to_group("doors")
	collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(width,3.8,.38)
	collider.shape = shape
	collider.position.y = 1.9
	add_child(collider)
	# Visual: the Going Medieval stone double door (valsekamerplant), split into a
	# static frame and two hinged leaves so the door can swing open.
	visual = Node3D.new()
	add_child(visual)
	var s = width/2.38
	var base = "res://assets/third_party/valsekamerplant/going-medieval/"
	var frame = load(base+"door_frame.glb").instantiate()
	frame.scale = Vector3.ONE*s
	visual.add_child(frame)
	var colour = Color.WHITE
	if key_id == "crimson_key": colour = Color(1,.45,.42)
	elif key_id == "iron_key": colour = Color(.78,.84,.95)
	for side in [-1,1]:
		var hinge = Node3D.new()
		hinge.position = Vector3(side*1.04*s,0,0)
		visual.add_child(hinge)
		var leaf
		if kind == "exit":
			# The front gate uses McPato's gothic parish door for each leaf.
			leaf = load("res://assets/third_party/mcpato/haunted-parish/door_gothic.glb").instantiate()
			leaf.scale = Vector3(1.04*s/1.49,.88*s,1)
			leaf.position = Vector3(-side*1.04*s*.5,0,0)
		else:
			leaf = load(base+("door_leaf_left.glb" if side < 0 else "door_leaf_right.glb")).instantiate()
			leaf.scale = Vector3.ONE*s
		hinge.add_child(leaf)
		leaves.append(hinge)
		tint(leaf,colour)
	prepare(visual)

func prepare(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.get_surface_override_material(i) if node.get_surface_override_material(i) else node.get_active_material(i)
			if original is StandardMaterial3D:
				var mat = original.duplicate()
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): prepare(child)

func tint(node: Node, colour: Color) -> void:
	if colour == Color.WHITE: return
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.get_active_material(i)
			if original is StandardMaterial3D:
				var mat = original.duplicate()
				mat.albedo_color = mat.albedo_color*colour
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): tint(child,colour)

func get_prompt() -> String:
	if kind == "exit":
		return "[E] LEAVE THE MANSION" if Game.guardian_dead else "EXIT SEALED — THE GUARDIAN HOLDS THE HOUSE"
	if opened: return ""
	if sealed: return "SEALED — END THE RITUAL"
	if kind == "shortcut" and Game.player.global_position.x > global_position.x:
		return "BARRED FROM THE LIBRARY SIDE"
	if key_id != "" and not Game.inventory.has_item(key_id):
		return title + " — REQUIRES " + Game.inventory.definitions[key_id].title
	return "[E] " + ("UNLOCK " if key_id != "" else "OPEN ") + title

func interact() -> void:
	if kind == "exit":
		if Game.guardian_dead: Game.win()
		else: Game.message.emit("The house will not let you leave while its guardian lives.")
		return
	if opened or sealed: return
	if kind == "shortcut" and Game.player.global_position.x > global_position.x:
		Game.message.emit("A bar holds this door from the library side.")
		return
	if key_id != "" and not Game.inventory.has_item(key_id):
		Game.message.emit("You need the " + Game.inventory.definitions[key_id].title + ".")
		return
	open()
	if kind == "shortcut": Game.message.emit("Shortcut opened. The entrance is just beyond.")
	if key_id == "iron_key": Game.set_objective("Take the shotgun and Crimson Crest from the armory.")

func open() -> void:
	opened = true
	collider.set_deferred("disabled",true)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(leaves[0],"rotation:y",1.8,.7).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(leaves[1],"rotation:y",-1.8,.7).set_trans(Tween.TRANS_CUBIC)
	Sound.at("door",global_position,-10)

func set_seal(value: bool) -> void:
	sealed = value
	if value:
		opened = false
		collider.set_deferred("disabled",false)
		for hinge in leaves: hinge.rotation.y = 0
	else:
		open()

