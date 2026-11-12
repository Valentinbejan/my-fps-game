extends Node3D
# Explosive flare fired by the flare gun. Arcs under gravity, bursts on contact.
const RADIUS = 4.5
var velocity = Vector3.FORWARD
var damage: float = 150.0
var life: float = 0
var exploded: bool = false

func _ready() -> void:
	var model = load("res://assets/models/flare_round.glb").instantiate()
	model.scale = Vector3.ONE*2.2
	add_child(model)
	var light = OmniLight3D.new()
	light.light_color = Color(1,.35,.08)
	light.light_energy = 2.2
	light.omni_range = 5
	add_child(light)

func _physics_process(delta: float) -> void:
	if exploded: return
	life += delta
	velocity.y -= 9.0*delta
	var next = global_position + velocity*delta
	var query = PhysicsRayQueryParameters3D.create(global_position,next,1|4,[Game.player.get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + hit.normal*.12
		explode()
	elif life > 4:
		explode()
	else:
		look_at(next if next.distance_to(global_position) > .001 else next+Vector3.FORWARD, Vector3.UP)
		global_position = next
		if Engine.get_physics_frames() % 3 == 0 and is_instance_valid(Game.level):
			Game.level.burst(global_position,Color(1,.55,.1),1)

func explode() -> void:
	exploded = true
	var center: Vector3 = global_position
	var hits = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var target: Vector3 = enemy.global_position + Vector3.UP
		var distance = center.distance_to(target)
		if distance < RADIUS and Game.clear_line(center,target,[enemy.get_rid()]):
			var falloff = 1.0 - (distance/RADIUS)*.6
			var push: Vector3 = (target-center).normalized()*9 + Vector3.UP*3
			enemy.take_damage(damage*falloff,push,"FIREWORKS")
			hits += 1
	if hits >= 2: Game.score("MULTI BURN",40*hits)
	# The blast throws the player too: a deliberate flare-jump.
	var player = Game.player
	if is_instance_valid(player):
		var eye: Vector3 = player.global_position + Vector3.UP
		var distance = center.distance_to(eye)
		if distance < RADIUS-.5 and Game.clear_line(center,eye):
			var away: Vector3 = (eye-center).normalized()
			player.velocity += away*11 + Vector3.UP*8
			player.slam = false
			if not player.is_on_floor(): Game.score("FLARE JUMP",45)
	Game.level.burst(center,Color(1,.45,.08),22)
	Game.level.burst(center,Color(.9,.12,.04),12)
	Game.shake(.9 if is_instance_valid(player) and player.global_position.distance_to(center) < 9 else .3)
	Game.hitstop(.05)
	Sound.at("slam",center,2)
	Sound.at("shotgun",center,-2)
	var flash = OmniLight3D.new()
	flash.light_color = Color(1,.5,.15)
	flash.light_energy = 7
	flash.omni_range = 9
	flash.position = center
	Game.level.add_child(flash)
	var tween = flash.create_tween()
	tween.tween_property(flash,"light_energy",0.0,.45)
	tween.tween_callback(flash.queue_free)
	queue_free()
