extends Node
# Renders the first-person viewmodel for every weapon from the game camera and from the side,
# so gun grip offsets can be tuned. Output: validation/vm/<weapon>_<view>.png
var views = ["front","side","top","kick"]
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("F:/my-fps-game/validation/vm/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("F:/my-fps-game/validation/vm")
	Game.start()
	var player = Game.player
	for e in get_tree().get_nodes_in_group("enemies"): e.queue_free()
	player.position = Vector3(-3,.1,3)
	player.rotation.y = PI*.75
	player.set_physics_process(false)
	Game.inventory.add_item("shotgun",1,{"loaded":4})
	Game.inventory.add_item("smg",1,{"loaded":30})
	Game.inventory.add_item("flare",1,{"loaded":1})
	var only = OS.get_cmdline_user_args()
	var side = Camera3D.new()
	player.camera.add_child(side)
	side.fov = 40
	side.near = .002
	for id in ["pistol","shotgun","smg","flare"]:
		if only.size() > 0 and not id in only: continue
		player.weapon.equip(id)
		player.camera.current = true
		for i in 20: await get_tree().process_frame
		await shot(id+"_front")
		player.weapon.kick = .2
		await shot(id+"_kick")
		player.weapon.kick = 0
		# side view: from the right of the viewmodel, looking left
		side.position = Vector3(.32,-.03,-.09)
		side.rotation = Vector3(0,PI/2,0)
		side.current = true
		await shot(id+"_side")
		side.position = Vector3(.04,.3,-.09)
		side.rotation = Vector3(-PI/2,0,0)
		await shot(id+"_top")
	print("VM LAB DONE")
	get_tree().quit()
