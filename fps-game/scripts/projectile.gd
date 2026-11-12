extends Node3D
var direction = Vector3.FORWARD
var speed: float = 8.0
var damage: float = 10.0
var shooter
var reflected: bool = false
var life: float = 0
var visual: MeshInstance3D

func _ready() -> void:
	add_to_group("projectiles")
	visual = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = .18
	mesh.height = .36
	mesh.radial_segments = 8
	mesh.rings = 4
	visual.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1,.24,.04)
	visual.material_override = mat
	add_child(visual)
	var light = OmniLight3D.new()
	light.light_color = Color(1,.13,.03)
	light.light_energy = .6
	light.omni_range = 2
	add_child(light)

func _physics_process(delta: float) -> void:
	life += delta
	if life > 8:
		queue_free()
		return
	var next = global_position+direction*speed*delta
	var mask = 1|4 if reflected else 1|2
	var query = PhysicsRayQueryParameters3D.create(global_position,next,mask)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if reflected and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(110,direction*8,"RETURN TO SENDER")
		elif hit.collider == Game.player:
			Game.hurt(damage)
		Game.level.burst(hit.position,Color(1,.32,.04),5)
		queue_free()
	else:
		global_position = next

func reflect() -> void:
	reflected = true
	speed = 24
	if is_instance_valid(shooter):
		direction = (shooter.global_position+Vector3.UP*1.3-global_position).normalized()
	else:
		direction = -Game.player.camera.global_basis.z
	visual.material_override.albedo_color = Color(.4,1,.85)

