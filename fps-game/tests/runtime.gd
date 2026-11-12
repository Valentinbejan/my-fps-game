extends Node
var failures: Array[String] = []
var checks: int = 0
var main
var player
var level
var visual: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
	get_tree().create_timer(120,true).timeout.connect(func():push_error("Validation watchdog expired"); get_tree().quit(1))

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",label)
	else:
		failures.append(label)
		push_error("FAIL: "+label)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func capture(name: String) -> void:
	if not visual: return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("F:/my-fps-game/validation/"+name+".png")

func walk_to(point: Vector3,max_frames: int = 350) -> bool:
	Input.action_press("forward")
	for i in max_frames:
		var offset: Vector3 = point-player.global_position
		offset.y = 0
		if offset.length() < .45:
			Input.action_release("forward")
			await frames(4)
			return true
		player.rotation.y = atan2(-offset.x,-offset.z)
		await get_tree().physics_frame
	Input.action_release("forward")
	print("WALK BLOCKED ",player.global_position," -> ",point)
	return false

func get_pickup(id: String):
	for node in get_tree().get_nodes_in_group("pickups"):
		if node.item_id==id and not node.taken: return node
	return null

func get_door(kind: String):
	for node in get_tree().get_nodes_in_group("doors"):
		if node.kind==kind: return node
	return null

func aim_at(pos: Vector3) -> void:
	var offset = pos-player.camera.global_position
	player.rotation.y = atan2(-offset.x,-offset.z)
	player.camera.rotation.x = atan2(offset.y,Vector2(offset.x,offset.z).length())

func run() -> void:
	visual = "--visual-checks" in OS.get_cmdline_user_args()
	main = get_parent().get_node("BloodKey")
	player = Game.player
	level = Game.level
	Game.start()
	await frames(6)
	if Game.has_meta("validation_restart"):
		checks=Game.get_meta("validation_checks")
		failures.assign(Game.get_meta("validation_failures"))
		check(Game.health==100 and not Game.guardian_dead and not Game.inventory.has_item("shotgun"),"Restart resets health, progress and inventory")
		check(get_tree().get_nodes_in_group("enemies").size()==8 and not level.arena_door.opened,"Restart rebuilds enemies and locked doors")
		check(player.position.distance_to(Vector3(0,0,5.5))<.3,"Restart returns player to entrance")
		await frames(8)
		print("VALIDATION: ",checks-failures.size(),"/",checks," passed; failures: ",failures)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	# Model resources and pause-state smoke checks. Player spawns 0.1 m up; allow it to settle.
	await frames(10)
	check(player.is_on_floor(),"Player starts on a solid floor")
	check(get_tree().get_nodes_in_group("enemies").size()==8,"Eight exploration enemies spawn, including three swarmers")
	await capture("entrance")
	Game.ui.show_pause()
	var pause_pos: Vector3 = player.position
	await frames(8)
	check(player.position==pause_pos,"Pause suspends player simulation")
	Game.ui.resume()
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	# Inventory tests: no mutation on failed pickup, rotation, storage, crafting.
	var inv = InventoryModel.new()
	check(inv.add_item("shotgun",1,{"loaded":3}),"Multi-cell weapon pickup")
	check(inv.move_item(inv.items[0].uid,Vector2i(4,0),true),"Shotgun rotates into a four-cell column")
	check(not inv.move_item(inv.items[0].uid,Vector2i(4,1),true),"Reject out-of-bounds rotation")
	check(inv.add_item("pistol"),"Second weapon fits")
	check(not inv.move_item(inv.items[1].uid,Vector2i(4,0),false),"Reject overlap without losing item")
	var uid = inv.items[0].uid
	inv.store_item(uid)
	check(inv.storage.size()==1 and not inv.has_item("shotgun"),"Storage removes the carried weapon")
	check(inv.retrieve(0) and inv.weapon_item("shotgun").loaded==3,"Retrieval preserves magazine ammunition")
	inv = InventoryModel.new()
	inv.add_item("bullets",35)
	for i in 19: inv.add_item("herb")
	var snapshot = inv.items.duplicate(true)
	check(not inv.add_item("bullets",3) and inv.items==snapshot,"Full-grid pickup rolls back partial ammo stacking")
	check(inv.craft() and inv.count_item("herb")==17 and inv.has_item("medicine"),"Two herbs craft into one medicine")
	inv = InventoryModel.new()
	inv.add_item("powder",3)
	inv.add_item("powder",3)
	check(inv.craft_recipe(3) and inv.count_item("flares")==1 and inv.count_item("powder")==3,"Three powder craft into one flare")
	check(inv.craft_recipe(2) and inv.count_item("shells")==6 and inv.count_item("powder")==1,"Two powder craft into six shells")
	check(inv.craft_recipe(1) and inv.count_item("bullets")==15 and not inv.has_item("powder"),"One powder crafts fifteen 9mm rounds")
	check(not inv.craft_recipe(1),"Crafting without ingredients is rejected")
	inv = null
	Game.ui.open_inventory(true)
	await capture("inventory")
	check(get_tree().paused,"Inventory pauses combat")
	Game.ui.close_inventory()
	# Active AI and projectile collision, without bypassing attack logic.
	var caster = level.enemy("caster",Vector3(0,.1,1),Rect2(-8,-8,16,16))
	caster.active = true
	caster.attack_timer = 0
	await frames(125)
	check(Game.health<100,"Active caster telegraphs and damages player with projectile")
	caster.queue_free()
	for shot in get_tree().get_nodes_in_group("projectiles"): shot.queue_free()
	await frames(2)
	Game.health=100
	var blocked_caster = level.enemy("caster",Vector3(10,.1,0),Rect2(8,-14,24,22))
	blocked_caster.active=true
	blocked_caster.attack_timer=0
	player.position=Vector3(6,.1,0)
	await frames(170)
	check(Game.health==100,"Caster cannot damage player through separating wall")
	check(blocked_caster.position.x>=8.6,"Enemy remains inside its room")
	blocked_caster.queue_free()
	player.position=Vector3(0,.1,5)
	player.velocity=Vector3.ZERO
	await frames(3)
	# UI drag preserves the grabbed cell and applies rotation on release.
	Game.ui.open_inventory()
	var mouse=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.position=Game.ui.grid_origin+Vector2(123,40)
	mouse.pressed=true
	Game.ui._input(mouse)
	mouse.pressed=false
	Game.ui._input(mouse)
	check(Game.inventory.weapon_item("pistol").cell==Vector2i.ZERO,"Clicking second weapon cell does not move it")
	mouse.position=Game.ui.grid_origin+Vector2(20,20)
	mouse.pressed=true
	Game.ui._input(mouse)
	var rotate=InputEventKey.new()
	rotate.pressed=true
	rotate.physical_keycode=KEY_R
	Game.ui._input(rotate)
	mouse.position=Game.ui.grid_origin+Vector2(20,184)
	mouse.pressed=false
	Game.ui._input(mouse)
	check(Game.inventory.weapon_item("pistol").rotated,"Inventory UI rotates dragged weapon")
	Game.inventory.move_item(Game.inventory.weapon_item("pistol").uid,Vector2i.ZERO,false)
	Game.ui.close_inventory()
	# Input-driven movement checks.
	player.rotation = Vector3.ZERO
	var start: Vector3 = player.position
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	await frames(8)
	check(player.position.distance_to(start)>1.5 and player.dash_charges==2,"Ground dash moves and consumes one charge")
	await frames(24)
	player.position = Vector3(0,.1,5)
	player.velocity = Vector3.ZERO
	await frames(6)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(6)
	check(player.position.y>.6,"Jump lifts the player")
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	check(player.dash_time>0 and not player.is_on_floor(),"Air dash is available")
	await frames(12)
	Input.action_press("slide")
	await frames(2)
	Input.action_release("slide")
	check(player.slam,"Airborne CTRL starts slam")
	await frames(35)
	check(not player.slam,"Slam resolves on floor contact")
	player.position = Vector3(-7.43,1.2,0)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	Input.action_press("left")
	await frames(5)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	Input.action_release("left")
	await frames(2)
	check(player.wall_cooldown>0 and player.velocity.y>0,"Wall contact permits wall kick")
	player.position = Vector3(0,.1,5)
	player.velocity = Vector3.ZERO
	await frames(12)
	Input.action_press("slide")
	await frames(2)
	Input.action_release("slide")
	check(player.slide_time>0,"Ground CTRL starts slide")
	await frames(50)
	player.position = Vector3(0,.1,5)
	player.velocity = Vector3.ZERO
	await frames(6)
	check(await walk_to(Vector3(0,0,-7)),"Entrance stairs reach upper landing")
	check(player.position.y>2.8,"Entrance landing supports player")
	player.position=Vector3(0,.1,5)
	player.velocity=Vector3.ZERO
	await frames(6)
	# Actual world topology: follow the complete route through physical openings.
	level.arena_door.interact()
	check(not level.arena_door.opened,"Crimson lock rejects player without key")
	var armory
	for door in get_tree().get_nodes_in_group("doors"):
		if door.key_id=="iron_key": armory=door
	armory.interact()
	check(not armory.opened,"Iron lock rejects player without key")
	get_door("shortcut").interact()
	check(not get_door("shortcut").opened,"Shortcut cannot open from hub side")
	check(await walk_to(Vector3(-11,0,5)),"Walk from entrance through west opening")
	check(await walk_to(Vector3(-19,0,5)),"Traverse west corridor")
	check(await walk_to(Vector3(-19,0,-4)),"Enter library from corridor")
	await capture("library")
	check(await walk_to(Vector3(-19.6,0,-6.9)),"Reach library study desk")
	aim_at(get_pickup("iron_key").global_position)
	await frames(2)
	player.update_target()
	check(player.target==get_pickup("iron_key"),"Interaction ray targets the Iron Key")
	get_pickup("iron_key").interact()
	check(Game.inventory.has_item("iron_key"),"Collect Iron Key")
	armory.interact()
	await frames(45)
	check(armory.opened,"Iron Key opens armory")
	check(await walk_to(Vector3(-22,0,-6.5)) and await walk_to(Vector3(-22,0,-17)),"Pass unlocked armory door")
	await capture("armory")
	get_pickup("shotgun").interact()
	get_pickup("shells").interact()
	get_pickup("crimson_key").interact()
	check(Game.inventory.has_item("shotgun") and Game.inventory.has_item("crimson_key"),"Collect shotgun and Crimson Key")
	player.weapon.equip("shotgun")
	check(player.weapon.current=="shotgun","Instant weapon switch")
	var item = Game.inventory.weapon_item("shotgun")
	item.loaded = 0
	player.weapon.reload()
	await frames(100)
	check(item.loaded==4 and Game.inventory.count_item("shells")==4,"Reload transfers correct reserve count")
	var removed = Game.inventory.remove_item(item.uid)
	level.drop_item(removed)
	await frames(2)
	get_pickup("shotgun").interact()
	check(Game.inventory.weapon_item("shotgun").loaded==4,"Dropped weapon retains loaded magazine")
	check(await walk_to(Vector3(-22,0,-5)),"Backtrack from armory into library")
	check(await walk_to(Vector3(-16,0,-4)),"Reach shortcut vestibule")
	get_door("shortcut").interact()
	await frames(45)
	check(await walk_to(Vector3(-5,0,-4)),"Shortcut provides passable route to entrance")
	# Close-range healing, raycast weapon damage, projectile reflection, occlusion.
	var target = level.enemy("thrall",Vector3(-4,.1,0),Rect2(-8,-8,16,16))
	target.set_physics_process(false)
	player.position=Vector3(-4,.1,2.2)
	player.velocity=Vector3.ZERO
	aim_at(target.position+Vector3.UP*1.3)
	await frames(3)
	Game.health=60
	player.weapon.equip("pistol")
	player.weapon.cooldown=0
	player.weapon.fire()
	check(target.health<target.definition.health,"Pistol ray hits enemy")
	check(Game.health>60,"Close-range damage heals through blood")
	Game.health=70
	player.dash_time=.1
	Game.hurt(10)
	check(Game.health==70,"Dash protects from damage")
	player.dash_time=0
	var projectile=load("res://scripts/projectile.gd").new()
	projectile.shooter=target
	projectile.position=player.camera.global_position-player.camera.global_basis.z*1.8
	projectile.direction=player.camera.global_basis.z
	level.add_child(projectile)
	player.weapon.punch_cooldown=0
	player.weapon.punch()
	player.weapon.try_parry()
	check(projectile.reflected and Game.parries>0,"Punch window reflects incoming projectile")
	await capture("parry")
	await frames(12)
	check(target.dead,"Reflected projectile kills target")
	check(not Game.clear_line(Vector3(7,1,0),Vector3(9,1,0)),"Architecture blocks line of sight through walls")
	# GAME.MD additions: east wing, SMG, swarmer lunge, storeroom, flare gun.
	Game.health=100
	player.position=Vector3(5,.1,5)
	player.velocity=Vector3.ZERO
	await frames(3)
	var wing_door
	for door in get_tree().get_nodes_in_group("doors"):
		if door.title=="EAST WING": wing_door=door
	wing_door.interact()
	await frames(45)
	check(wing_door.opened,"East wing door opens from the entrance")
	check(await walk_to(Vector3(5,0,10)),"Walk into the servants' hall")
	check(Game.room_name=="SERVANTS' HALL","Servants' hall is named on entry")
	check(not Game.arena_started,"East wing does not trigger the ritual")
	check(await walk_to(Vector3(9,0,13.2)),"Cross the servants' hall")
	await capture("servants_hall")
	get_pickup("smg").interact()
	check(Game.inventory.weapon_item("smg").loaded==30,"Collect loaded SMG")
	var store_door
	for door in get_tree().get_nodes_in_group("doors"):
		if door.title=="STOREROOM": store_door=door
	check(store_door.key_id=="crimson_key","Storeroom is locked with the Crimson Key")
	store_door.interact()
	await frames(45)
	check(store_door.opened,"Crimson Key opens the storeroom")
	check(await walk_to(Vector3(20,0,13)),"Enter the storeroom")
	check(await walk_to(Vector3(24,0,14.5)),"Reach the flare gun")
	await capture("storeroom")
	get_pickup("flare").interact()
	get_pickup("flares").interact()
	check(Game.inventory.has_item("flare") and Game.inventory.count_item("flares")==2,"Collect flare gun and flares")
	var notes = get_tree().get_nodes_in_group("notes")
	check(notes.size()==3,"Three lore notes are placed")
	notes[0].interact()
	check(Game.mode=="reading" and get_tree().paused,"Reading a note pauses the game")
	Game.ui.close_note()
	check(Game.mode=="playing" and not get_tree().paused,"Closing a note resumes play")
	# SMG empties quickly and damages.
	player.position=Vector3(0,.1,4)
	player.velocity=Vector3.ZERO
	var dummy = level.enemy("guardian",Vector3(0,.1,-1),Rect2(-8,-8,16,16))
	dummy.set_physics_process(false)
	aim_at(dummy.position+Vector3.UP*1.5)
	await frames(3)
	player.weapon.equip("smg")
	await capture("smg_view")
	for i in 10:
		player.weapon.cooldown=0
		player.weapon.fire()
	check(Game.inventory.weapon_item("smg").loaded==20 and dummy.health<dummy.definition.health,"SMG fires ten rounds into a target")
	dummy.queue_free()
	# Swarmer telegraphs a lunge and hits.
	Game.health=100
	var swarmer = level.enemy("swarmer",Vector3(0,.1,.5),Rect2(-8,-8,16,16))
	swarmer.active=true
	swarmer.attack_timer=0
	player.position=Vector3(0,.1,4)
	await frames(70)
	check(Game.health<100,"Swarmer lunge damages the player")
	swarmer.take_damage(999,Vector3.ZERO,"TEST")
	await frames(5)
	Game.health=100
	# Flare: splash damage to a group, and a flare-jump.
	var group = []
	for x in [-1.2,1.2]:
		var t = level.enemy("thrall",Vector3(x,.1,-2),Rect2(-8,-8,16,16))
		t.set_physics_process(false)
		group.append(t)
	player.position=Vector3(0,.1,5)
	player.velocity=Vector3.ZERO
	await frames(3)
	player.weapon.equip("flare")
	aim_at(Vector3(0,.4,-2))
	await frames(2)
	await capture("flare_view")
	player.weapon.cooldown=0
	player.weapon.fire()
	await frames(40)
	check(group[0].health<90 and group[1].health<90,"Flare blast damages several enemies")
	for t in group:
		if is_instance_valid(t) and not t.dead: t.take_damage(999,Vector3.ZERO,"TEST")
	player.weapon.finish_reload()
	player.position=Vector3(0,.1,3)
	player.velocity=Vector3.ZERO
	await frames(4)
	player.rotation=Vector3.ZERO
	player.camera.rotation.x=-1.45
	await frames(2)
	player.weapon.cooldown=0
	var before_y = player.position.y
	player.weapon.fire()
	await frames(8)
	check(player.velocity.y>2 or player.position.y>before_y+.4,"Flare at the feet launches the player")
	player.camera.rotation.x=0
	await frames(40)
	player.weapon.equip("pistol")
	Game.health=100
	player.position=Vector3(5,.1,3)
	player.velocity=Vector3.ZERO
	level.arena_door.interact()
	await frames(45)
	check(await walk_to(Vector3(11,0,3)),"Crimson Key gives access to ritual hall")
	check(Game.arena_started and level.arena_door.sealed and level.side_door.sealed,"Arena seals both entrances after entry")
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	player.position=Vector3(12,.1,6)
	aim_at(Vector3(20,2,-5))
	await capture("ritual_hall")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.arena_member: enemy.take_damage(999,Vector3.ZERO,"TEST")
	await frames(3)
	var boss
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.enemy_id=="guardian": boss=enemy
	check(is_instance_valid(boss),"Guardian spawns only after arena wave")
	boss.set_physics_process(false)
	player.position=Vector3(20,.1,-2)
	aim_at(boss.position+Vector3.UP*2)
	await capture("guardian")
	boss.take_damage(999,Vector3.ZERO,"TEST")
	await frames(45)
	check(Game.guardian_dead and level.return_door.opened and level.arena_door.opened and level.side_door.opened,"Guardian defeat opens every return path")
	# Stairs must connect to actual balcony, with no gap at the top.
	player.position=Vector3(28.5,.1,5.5)
	player.velocity=Vector3.ZERO
	check(await walk_to(Vector3(28.5,0,-8)),"Ritual stairs reach balcony")
	check(player.position.y>3,"Balcony supports player above arena")
	player.position=Vector3(12,.1,-5)
	player.velocity=Vector3.ZERO
	check(await walk_to(Vector3(5,0,-5)),"Return passage is traversable")
	player.position=Vector3(0,.1,6)
	get_door("exit").interact()
	check(Game.mode=="won","Exit produces completion screen")
	await capture("ending")
	get_tree().paused=false
	Game.mode="playing"
	Game.health=10
	player.dash_time=0
	Game.hurt(20)
	check(Game.mode=="dead" and get_tree().paused,"Death pauses simulation and shows retry screen")
	Game.set_meta("validation_restart",true)
	Game.set_meta("validation_checks",checks)
	Game.set_meta("validation_failures",failures)
	Game.restart()
