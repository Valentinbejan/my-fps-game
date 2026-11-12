extends StaticBody3D
# Storage: a chest of drawers from Elbolilloduro's village interior pack.
func _ready() -> void:
	collision_layer = 1|8
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.25,1,.75)
	shape.shape = box
	shape.position.y = .5
	add_child(shape)
	var model = load("res://assets/third_party/elbolilloduro/village-interior/chest_of_drawers.glb").instantiate()
	add_child(model)
	Game.level.prepare_model(model)
	darken(model)

func get_prompt() -> String:
	return "[E] OPEN STORAGE"

func interact() -> void:
	Sound.cue("door",-18)
	Game.ui.open_inventory(true)

func darken(node: Node) -> void:
	# The village-interior chest ships near-white; stain it to match the house's wood.
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat = node.get_surface_override_material(i)
			if mat is StandardMaterial3D: mat.albedo_color = mat.albedo_color*Color(.62,.47,.36)
	for child in node.get_children(): darken(child)
