extends StaticBody3D
# A readable lore page. Lies flat on whatever surface it was placed on.
@export var title: String = "NOTE"
@export_multiline var body: String = ""
var read: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group("notes")
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(.5,.25,.5)
	shape.shape = box
	add_child(shape)
	var model = load("res://assets/models/note.glb").instantiate()
	model.scale = Vector3.ONE*1.3
	add_child(model)
	var glow = OmniLight3D.new()
	glow.light_color = Color(.9,.8,.55)
	glow.light_energy = .35
	glow.omni_range = 1.2
	glow.position.y = .3
	add_child(glow)

func get_prompt() -> String:
	return "[E] READ " + title

func interact() -> void:
	read = true
	Sound.cue("pickup",-16,.7)
	Game.ui.show_note(title,body)
