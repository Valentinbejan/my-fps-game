extends Node3D
var current: String = "pistol"
var definition: WeaponDefinition
var cooldown: float = 0
var reload_timer: float = 0
var parry_timer: float = 0
var punch_cooldown: float = 0
var kick: float = 0
var gun: Node3D
var arms: Node3D
var left_arm_mesh: Node3D
var animation: AnimationPlayer
var muzzle: OmniLight3D
var flash_timer: float = 0
const ORDER = ["pistol", "shotgun", "smg", "flare"]
var base_offset: Vector3 = Vector3(.20,-.17,-.44)

# The whole viewmodel is shrunk toward the camera: it looks identical on screen,
# but its geometry stays inside the player's capsule, so it never clips into walls
# and keeps normal depth testing (no inside-out rendering).
const VIEW_SCALE = .25

func aim_basis() -> Basis:
	return get_parent().global_basis.orthonormalized()

const ARMS_REST = Vector3(0,-1.48,-.20)
var mount: BoneAttachment3D
var hand_rest: Transform3D = Transform3D.IDENTITY
var hand_ready: bool = false
var settle_frames: int = 0

func _ready() -> void:
	scale = Vector3.ONE*VIEW_SCALE
	gun = Node3D.new()
	arms = load("res://assets/models/arms.glb").instantiate()
	add_child(arms)
	arms.position = ARMS_REST
	arms.scale = Vector3.ONE*.8
	arms.rotation.y = PI
	prepare_materials(arms)
	left_arm_mesh = arms.find_child("ArmLeft",true,false)
	if left_arm_mesh: left_arm_mesh.visible = false
	animation = find_animation(arms)
	if animation and animation.has_animation("grab_R"):
		var skeleton = arms.find_child("Skeleton3D",true,false)
		animation.play("grab_R")
		animation.advance(animation.current_animation_length)
		var modifier = load("res://scripts/hand_pose.gd").new()
		modifier.weapon = self
		for index in skeleton.get_bone_count():
			var bone_name: String = skeleton.get_bone_name(index)
			if bone_name.ends_with(".R") and (bone_name.begins_with("f_") or bone_name.begins_with("thumb")):
				modifier.grip[index] = skeleton.get_bone_pose_rotation(index)
		skeleton.add_child(modifier)
		animation.play("finger_gun_idle")
		animation.advance(0)
		# Guns ride on the right hand bone so they follow the idle sway, recoil and reload dip.
		var hand = skeleton.find_bone("hand.R")
		if hand >= 0:
			mount = BoneAttachment3D.new()
			mount.bone_name = "hand.R"
			skeleton.add_child(mount)
			mount.add_child(gun)
	if not gun.get_parent(): add_child(gun)
	# Arms are displayed during punch, with the supplied jab animation.
	arms.visible = true
	muzzle = OmniLight3D.new()
	muzzle.light_color = Color(1,.65,.22)
	muzzle.omni_range = 5
	muzzle.position = Vector3(.2,-.12,-.7)
	muzzle.light_energy = 0
	add_child(muzzle)
	equip("pistol")
	Game.inventory.changed.connect(check_loadout)

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found = find_animation(child)
		if found: return found
	return null

func prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original = node.get_active_material(i)
			if original is StandardMaterial3D:
				var mat = original.duplicate()
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				node.set_surface_override_material(i,mat)
	for child in node.get_children(): prepare_materials(child)

func check_loadout() -> void:
	if current == "" or not Game.inventory.has_item(current):
		var fallback = ""
		for id in ORDER:
			if Game.inventory.has_item(id):
				fallback = id
				break
		if fallback != current: equip(fallback)

func owned() -> Array:
	var result = []
	for id in ORDER:
		if Game.inventory.has_item(id): result.append(id)
	return result

func cycle(step: int) -> void:
	var list = owned()
	if list.is_empty(): return
	var index = list.find(current)
	equip(list[(index + step + list.size()) % list.size()])

func _unhandled_input(event: InputEvent) -> void:
	if Game.mode != "playing": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: cycle(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: cycle(-1)

func equip(id: String) -> void:
	if id != "" and not Game.inventory.has_item(id): return
	var changed = current != id
	current = id
	reload_timer = 0
	for child in gun.get_children(): child.queue_free()
	if id == "":
		definition = null
		return
	definition = load("res://data/weapons/"+id+".tres")
	var model = load(definition.model).instantiate()
	gun.add_child(model)
	prepare_materials(model)
	base_offset = definition.view_offset
	# view_offset is where the gun sits relative to the camera in the rest pose;
	# convert it into the hand bone's space once, then let the bone carry it.
	fit_gun()
	muzzle.position = base_offset + Vector3(0,.05,-.3)
	if changed: Game.score("QUICK SWITCH",8)

# Place the gun so that, with the arms at rest, it sits at view_offset in camera space.
func fit_gun() -> void:
	var desired = Transform3D(Basis.IDENTITY, base_offset)
	gun.transform = hand_rest.affine_inverse() * desired if mount and hand_ready else desired

func _process(delta: float) -> void:
	if mount and not hand_ready:
		# Measure the hand once the idle pose has actually been applied to the skeleton.
		settle_frames += 1
		if settle_frames >= 3:
			hand_rest = global_transform.affine_inverse() * mount.global_transform
			hand_ready = true
			fit_gun()
	if Game.mode != "playing": return
	cooldown = maxf(0,cooldown-delta)
	punch_cooldown = maxf(0,punch_cooldown-delta)
	parry_timer = maxf(0,parry_timer-delta)
	flash_timer = maxf(0,flash_timer-delta)
	muzzle.light_energy = 2.2 if flash_timer > 0 else 0.0
	kick = move_toward(kick,0,delta*.9)
	var dip = .25*sin((reload_timer/definition.reload_time)*PI) if reload_timer>0 and definition else 0.0
	arms.position = ARMS_REST + Vector3(0,-dip,kick*.35)
	arms.rotation.x = -kick*.3
	arms.visible = true
	if left_arm_mesh: left_arm_mesh.visible = punch_cooldown > .02
	gun.visible = punch_cooldown <= .18 and current != ""
	if animation and punch_cooldown <= .02 and animation.current_animation != "finger_gun_idle":
		animation.play("finger_gun_idle")
	for id in ORDER:
		if Input.is_action_just_pressed(id): equip(id)
	if Input.is_action_just_pressed("punch"): punch()
	if parry_timer > 0: try_parry()
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0: finish_reload()
	elif Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_pressed("fire") and cooldown <= 0 and reload_timer <= 0:
		fire()

func fire() -> void:
	if not definition: return
	var item = Game.inventory.weapon_item(current)
	if item.is_empty(): return
	if item.loaded <= 0:
		reload()
		cooldown = .25
		return
	item.loaded -= 1
	cooldown = definition.interval
	kick = definition.kick
	flash_timer = .05
	Sound.cue(definition.sound,-8,definition.pitch*randf_range(.96,1.04))
	if definition.projectile:
		launch_flare()
		Game.shake(.35)
		return
	if current == "shotgun": Game.shake(.25)
	for i in definition.pellets:
		var direction = -aim_basis().z
		direction += aim_basis().x*randf_range(-definition.spread,definition.spread)
		direction += aim_basis().y*randf_range(-definition.spread,definition.spread)
		var query = PhysicsRayQueryParameters3D.create(global_position,global_position+direction.normalized()*70,1|4,[Game.player.get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider.has_method("take_damage"):
				var action = current.to_upper() if Game.player.is_on_floor() else "AIR SHOT"
				hit.collider.take_damage(definition.damage,direction*3,action)
				Game.ui.hit_time = .12
			else:
				Game.level.burst(hit.position,Color(.65,.47,.26),2)

func launch_flare() -> void:
	var flare = load("res://scripts/flare_round.gd").new()
	flare.damage = definition.damage
	flare.position = global_position - aim_basis().z*.3 + aim_basis().y*-.05
	flare.velocity = -aim_basis().z*27 + Game.player.velocity*.35
	Game.level.add_child(flare)

func reload() -> void:
	if not definition: return
	var item = Game.inventory.weapon_item(current)
	if item.is_empty() or item.loaded >= definition.magazine: return
	if Game.inventory.count_item(definition.ammo_id) == 0:
		Game.message.emit("No reserve ammunition. F to punch / parry.")
		return
	reload_timer = definition.reload_time
	Sound.cue("reload",-13)

func finish_reload() -> void:
	if not definition: return
	var item = Game.inventory.weapon_item(current)
	if item.is_empty(): return
	var amount = mini(definition.magazine-item.loaded,Game.inventory.count_item(definition.ammo_id))
	item.loaded += amount
	Game.inventory.consume(definition.ammo_id,amount)

func punch() -> void:
	if punch_cooldown > 0: return
	punch_cooldown = .5
	parry_timer = .22
	Sound.cue("dash",-14,1.5)
	if animation and animation.has_animation("jab_L"): animation.play("jab_L")
	var query = PhysicsRayQueryParameters3D.create(global_position,global_position-aim_basis().z*2.7,1|4,[Game.player.get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(30,-aim_basis().z*7,"PUNCH")
		Game.ui.hit_time = .15

func try_parry() -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		var offset: Vector3 = projectile.global_position-global_position
		if not projectile.reflected and offset.length() < 2.8 and offset.normalized().dot(-aim_basis().z) > .35 and Game.clear_line(global_position,projectile.global_position):
			projectile.reflect()
			parry_timer = 0
			Game.parries += 1
			Game.score("PARRY",110)
			Game.heal(8)
			Game.ui.hit_time = .3
			Sound.cue("parry",-7)
			break

