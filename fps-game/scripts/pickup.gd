extends StaticBody3D
@export var item_id: String = "herb"
@export var amount: int = 1
@export var loaded: int = 0
var visual: Node3D
var time: float = 0
var taken: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group("pickups")
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = .48
	shape.shape = sphere
	add_child(shape)
	var definition = Game.inventory.definitions[item_id]
	visual = load(definition.model).instantiate()
	visual.scale = Vector3.ONE*definition.model_scale
	add_child(visual)
	tint(visual,definition.model_tint)
	if item_id in ["pistol","shotgun","smg","flare"]: visual.rotation.z = PI/2
	var glow = OmniLight3D.new()
	glow.light_color = definition.tint
	glow.light_energy = .6
	glow.omni_range = 1.7
	add_child(glow)

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

func _process(delta: float) -> void:
	time += delta
	visual.position.y = sin(time*2)*.065
	visual.rotation.y += delta*.45

func get_prompt() -> String:
	return "[E] TAKE " + Game.inventory.definitions[item_id].title + (" x"+str(amount) if amount>1 else "")

func interact() -> void:
	if taken: return
	if Game.inventory.add_item(item_id,amount,{"loaded":loaded}):
		taken = true
		Game.message.emit("Collected " + Game.inventory.definitions[item_id].title)
		Game.acquired(item_id)
		Sound.cue("pickup",-9)
		queue_free()
	else:
		Game.message.emit("Inventory full. TAB to rearrange or drop an item.")

func take_damage(_amount: float, _force: Vector3, _action: String) -> void:
	pass

