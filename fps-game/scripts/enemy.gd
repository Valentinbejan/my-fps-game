extends CharacterBody3D
@export var enemy_id: String = "thrall"
@export var arena_member: bool = false
@export var bounds: Rect2 = Rect2(-40,-30,80,50)
var definition: EnemyDefinition
var health: float = 0
var attack_timer: float = 1
var windup: float = 0
var attack_kind: String = ""
var dead: bool = false
var visual: Node3D
var time: float = 0
var hurt_timer: float = 0
var knockback = Vector3.ZERO
var charge_time: float = 0
var charge_direction = Vector3.ZERO
var active: bool = false
var alert_time: float = 0
var phase: float = 0
var charge_hit: bool = false

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1|2|4
	definition = load("res://data/enemies/"+enemy_id+".tres")
	health = definition.health
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	phase = randf()*TAU
	capsule.radius = {"guardian":.65,"swarmer":.3}.get(enemy_id,.35)
	capsule.height = {"guardian":3.1,"swarmer":1.4}.get(enemy_id,2.0)
	shape.shape = capsule
	shape.position.y = capsule.height*.5
	add_child(shape)
	var model_path = definition.model
	if definition.variants.size() > 0: model_path = definition.variants[randi() % definition.variants.size()]
	visual = load(model_path).instantiate()
	add_child(visual)
	prepare_visual(visual)
	var shadow=MeshInstance3D.new()
	var disc=CylinderMesh.new()
	disc.top_radius={"guardian":.6,"swarmer":.34}.get(enemy_id,.38)
	disc.bottom_radius=disc.top_radius
	disc.height=.005
	disc.radial_segments=12
	shadow.mesh=disc
	shadow.position.y=.018
	var dark=StandardMaterial3D.new()
	dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color=Color(.025,.014,.013)
	shadow.material_override=dark
	add_child(shadow)

func prepare_visual(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.get_active_material(i)
			if original is StandardMaterial3D:
				var material = original.duplicate()
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
				node.set_surface_override_material(i,material)
	for child in node.get_children(): prepare_visual(child)

func _physics_process(delta: float) -> void:
	if dead or Game.mode != "playing": return
	time += delta
	hurt_timer = maxf(0,hurt_timer-delta)
	attack_timer -= delta
	var offset: Vector3 = Game.player.global_position-global_position
	var distance = offset.length()
	var sight = Game.clear_line(global_position+Vector3.UP*1.5,Game.player.global_position+Vector3.UP)
	if distance < 15 and sight:
		active = true
		alert_time = 5
	alert_time -= delta
	if alert_time <= 0 and not arena_member: active = false
	if offset.length_squared() > .001:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-offset.x,-offset.z),delta*7)
	if enemy_id == "swarmer": visual.position.y = abs(sin(time*9+phase))*.07
	elif enemy_id == "caster": visual.position.y = .10+sin(time*2)*.1
	else: visual.position.y = abs(sin(time*3))*.05
	visual.rotation.z = sin(time*4)*.035 if active else 0.0
	if hurt_timer > 0: visual.rotation.z += sin(time*80)*.08
	if not is_on_floor(): velocity.y -= 24*delta
	var direction = Vector3(offset.x,0,offset.z).normalized()
	var speed = definition.speed if active and distance>1.5 else 0.0
	if enemy_id == "caster":
		if distance < 5: direction = -direction
		elif distance < 9: speed = 0
	elif enemy_id == "swarmer" and distance > 2.5:
		# Swarmers weave while closing in, so they are harder to line up.
		direction = direction.rotated(Vector3.UP,sin(time*3.2+phase)*.7)
	if windup > 0:
		windup -= delta
		speed = 0
		visual.rotation.x = -.15
		if windup <= 0:
			execute_attack()
			visual.rotation.x = 0
	elif active and attack_timer <= 0 and sight:
		if enemy_id == "thrall" and distance < 2.1:
			attack_kind = "melee"
			windup = .48
		elif enemy_id == "swarmer" and distance < 5.5:
			attack_kind = "lunge"
			windup = .3
		elif enemy_id == "caster":
			attack_kind = "projectile"
			windup = .65
			Sound.at("cast",global_position,-13)
		elif enemy_id == "guardian":
			attack_kind = "melee" if distance < 3 else ("projectile" if int(time)%2==0 else "charge")
			windup = .85
			Game.message.emit("The Housekeeper gathers fire — dash or parry.")
			Sound.at("cast",global_position,-8)
		if windup > 0: attack_timer = definition.attack_interval
	if is_on_wall() and speed > 0:
		direction = (direction+get_wall_normal()*1.5).normalized()
	if charge_time > 0:
		charge_time -= delta
		direction = charge_direction
		speed = 13 if enemy_id != "swarmer" else 11
		if distance < 1.9 and sight and not charge_hit:
			Game.hurt(definition.damage)
			charge_hit = true
			if enemy_id != "swarmer": charge_time = 0
	knockback = knockback.move_toward(Vector3.ZERO,delta*15)
	velocity.x = direction.x*speed+knockback.x
	velocity.z = direction.z*speed+knockback.z
	move_and_slide()
	global_position.x = clampf(global_position.x,bounds.position.x+.6,bounds.end.x-.6)
	global_position.z = clampf(global_position.z,bounds.position.y+.6,bounds.end.y-.6)

func execute_attack() -> void:
	var target = Game.player.global_position+Vector3.UP*1.2
	var origin = global_position+Vector3.UP*(2.1 if enemy_id=="guardian" else 1.5)
	if not Game.clear_line(origin,target): return
	if attack_kind == "melee":
		if global_position.distance_to(Game.player.global_position) < (3.2 if enemy_id=="guardian" else 2.3):
			Game.hurt(definition.damage)
	elif attack_kind == "charge" or attack_kind == "lunge":
		charge_hit = false
		charge_time = .6 if attack_kind == "charge" else .38
		if attack_kind == "lunge" and is_on_floor(): velocity.y = 4.5
		charge_direction = (Game.player.global_position-global_position).normalized()
		charge_direction.y = 0
	else:
		for spread in ([-.13,0,.13] if enemy_id=="guardian" else [0]):
			var projectile = load("res://scripts/projectile.gd").new()
			projectile.shooter = self
			projectile.damage = definition.damage
			projectile.position = origin
			projectile.direction = (target-origin).normalized().rotated(Vector3.UP,spread)
			Game.level.add_child(projectile)

func take_damage(amount: float, force: Vector3, action: String) -> void:
	if dead: return
	health -= amount
	knockback += force*(.3 if enemy_id=="guardian" else 1.0)
	active = true
	alert_time = 5
	hurt_timer = .15
	Game.blood(global_position+Vector3.UP,amount*.35,action)
	Sound.at("hit",global_position,-14)
	if health <= 0:
		dead = true
		remove_from_group("enemies")
		collision_layer = 0
		collision_mask = 0
		Game.kills += 1
		Game.blood(global_position+Vector3.UP,40 if enemy_id != "swarmer" else 25,"KILL")
		Game.hitstop(.09 if enemy_id == "guardian" else .045)
		Game.shake(.2)
		Game.level.burst(global_position+Vector3.UP,Color(.65,.01,.02),18)
		var tween = create_tween()
		tween.tween_property(visual,"rotation:x",-PI/2,.22)
		tween.parallel().tween_property(visual,"position:y",.15,.22)
		tween.tween_interval(5)
		tween.tween_callback(queue_free)
		if enemy_id == "guardian": Game.guardian_defeated()
		elif arena_member: Game.level.call_deferred("check_wave")

