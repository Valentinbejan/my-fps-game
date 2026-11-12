extends CharacterBody3D
const MOVE_SPEED = 7.5
const GRAVITY = 24.0
var camera: Camera3D
var weapon
var dash_time: float = 0
var dash_charges: int = 3
var dash_regen: float = 0
var dash_direction = Vector3.ZERO
var slide_time: float = 0
var slam: bool = false
var wall_cooldown: float = 0
var coyote: float = 0
var jump_buffer: float = 0
var bob: float = 0
var steps: float = 0
var target
var prompt: String = ""
var sensitivity: float = .0022
var shake: float = 0

func _ready() -> void:
	Game.player = self
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = .35
	floor_max_angle = deg_to_rad(48)
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = .88
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = 1.6
	camera.fov = 88
	camera.near = .008
	camera.far = 90
	add_child(camera)
	camera.current = true
	weapon = load("res://scripts/weapon.gd").new()
	camera.add_child(weapon)

func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "playing" or get_tree().paused: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x*sensitivity)
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*sensitivity,-1.48,1.48)
	if event.is_action_pressed("interact") and is_instance_valid(target):
		target.interact()

func _physics_process(delta: float) -> void:
	if Game.mode != "playing": return
	wall_cooldown = maxf(0,wall_cooldown-delta)
	coyote = .12 if is_on_floor() else maxf(0,coyote-delta)
	jump_buffer = .12 if Input.is_action_just_pressed("jump") else maxf(0,jump_buffer-delta)
	dash_time = maxf(0,dash_time-delta)
	slide_time = maxf(0,slide_time-delta)
	if dash_charges < 3:
		dash_regen += delta
		if dash_regen > 1.15:
			dash_charges += 1
			dash_regen = 0
	var input_dir = Input.get_vector("left","right","forward","back")
	var direction = (transform.basis*Vector3(input_dir.x,0,input_dir.y)).normalized()
	if Input.is_action_just_pressed("dash") and dash_charges > 0:
		dash_charges -= 1
		dash_time = .18
		dash_direction = direction if direction.length() > .1 else -transform.basis.z
		slam = false
		Sound.cue("dash",-11)
	if Input.is_action_just_pressed("slide"):
		if is_on_floor():
			slide_time = .7
			dash_direction = direction if direction.length() > .1 else -transform.basis.z
		else:
			slam = true
			velocity.y = -28
	if jump_buffer > 0:
		if coyote > 0:
			velocity.y = 9
			coyote = 0
			jump_buffer = 0
			slide_time = 0
		elif is_on_wall() and wall_cooldown <= 0:
			velocity = get_wall_normal()*9 + Vector3.UP*9
			wall_cooldown = .25
			jump_buffer = 0
			slam = false
			Game.score("WALL KICK",8)
	if dash_time > 0:
		velocity = dash_direction*23
	elif slide_time > 0 and is_on_floor():
		velocity.x = dash_direction.x*12
		velocity.z = dash_direction.z*12
	else:
		var accel = 40 if is_on_floor() else 13
		if wall_cooldown <= .12:
			velocity.x = move_toward(velocity.x,direction.x*MOVE_SPEED,accel*delta)
			velocity.z = move_toward(velocity.z,direction.z*MOVE_SPEED,accel*delta)
		if not is_on_floor(): velocity.y -= GRAVITY*delta
	var was_slam = slam
	move_and_slide()
	if was_slam and is_on_floor():
		slam = false
		velocity.y = 5.5
		Sound.cue("slam",-4)
		weapon.kick = .14
		Game.shake(.45)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(global_position) < 4.5 and Game.clear_line(global_position+Vector3.UP,enemy.global_position+Vector3.UP):
				enemy.take_damage(45,Vector3.UP*5,"SLAM")
		Game.level.burst(global_position+Vector3.UP*.15,Color(.8,.28,.12),18)
	var moving = Vector2(velocity.x,velocity.z).length()
	bob += delta*moving*1.8
	camera.position.y = lerpf(camera.position.y,1.05 if slide_time > 0 else 1.6,delta*12)
	camera.position.x = sin(bob)*.017 if is_on_floor() else 0.0
	camera.fov = lerpf(camera.fov,96.0 if dash_time > 0 else 88.0,delta*9)
	shake = move_toward(shake,0,delta*2.8)
	camera.h_offset = randf_range(-1,1)*shake*.06
	camera.v_offset = randf_range(-1,1)*shake*.06
	if is_on_floor() and moving > 1:
		steps += delta
		if steps > .37:
			steps = 0
			Sound.cue("step",-22,randf_range(.85,1.15))
	update_target()
	if global_position.y < -8:
		global_position = Vector3(0,1,5)
		Game.hurt(15)

func update_target() -> void:
	prompt = ""
	target = null
	var start = camera.global_position
	var query = PhysicsRayQueryParameters3D.create(start,start-camera.global_basis.z*3.3,1|8,[get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("interact"):
		target = hit.collider
		prompt = target.get_prompt()

