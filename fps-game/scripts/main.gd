extends Node3D
func _enter_tree() -> void:
	Game.reset()

func _ready() -> void:
	Game.ui = $UI/HUD
	Game.ui.crt = $Retro/Filter
	Game.ui.crt.material.set_shader_parameter("crt_enabled",Game.crt_enabled)
	if Game.autostart:
		Game.start()
	else:
		Game.mode = "title"
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Game.ui.show_title()
		Sound.title(true)
	if "--bake" in OS.get_cmdline_user_args():
		bake_geometry()
	if "--capture" in OS.get_cmdline_user_args():
		capture()

func bake_geometry() -> void:
	var root = Node3D.new()
	root.name = "Mansion"
	var geo = Game.level.geometry.duplicate()
	root.add_child(geo)
	set_owners(geo,root)
	root.set_script(load("res://scripts/level.gd"))
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed,"res://scenes/mansion.tscn")
	root.free()
	print("BAKED mansion.tscn")

func set_owners(node: Node,root: Node) -> void:
	node.scene_file_path = ""
	node.owner = root
	for child in node.get_children(): set_owners(child,root)

func capture() -> void:
	await get_tree().create_timer(2.0,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../validation/" + ("title" if Game.mode == "title" else "gameplay") + ".png")
	print("CAPTURE saved")



