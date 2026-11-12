extends Node
# Visual review: renders fixed camera positions through every room into validation/art/tour.
var views = {
	"01_entrance_hall": [Vector3(0,1.6,6.8),Vector3(0,2.2,-6)],
	"02_entrance_storage": [Vector3(3,1.6,5),Vector3(-6,1.2,-1)],
	"03_entrance_east": [Vector3(-3,1.6,4),Vector3(7,1.4,-2)],
	"04_entrance_from_landing": [Vector3(0,4.6,-7.2),Vector3(0,1,6)],
	"05_west_corridor": [Vector3(-9,1.6,5),Vector3(-22,1.2,5)],
	"06_library_study": [Vector3(-19,1.6,0.5),Vector3(-23,1.2,-10)],
	"07_library_west": [Vector3(-15.5,1.6,-2.5),Vector3(-29,1.5,-8)],
	"08_armory": [Vector3(-22,1.6,-15.2),Vector3(-22,1.2,-23)],
	"09_armory_side": [Vector3(-15.5,1.6,-15.3),Vector3(-29,1,-22)],
	"10_ritual_hall": [Vector3(10,1.6,6.5),Vector3(20,2,-10)],
	"11_ritual_balcony": [Vector3(20,4.8,-9.2),Vector3(20,1,5)],
	"12_ritual_stairs": [Vector3(22,1.6,6.5),Vector3(29,2,-6)],
	"13_servants_hall": [Vector3(3.5,1.6,9),Vector3(14,1,16)],
	"14_storeroom": [Vector3(18.5,1.6,9.5),Vector3(30,1,16)],
	"15_enemies": [Vector3(0,1.6,3.5),Vector3(0,1.3,0)],
	"16_statue_stairs": [Vector3(-3.5,1.6,-1.5),Vector3(-6,1.4,-5.8)],
	"17_armory_rack": [Vector3(-22,1.6,-19),Vector3(-22,1.4,-24)],
	"18_ritual_altar": [Vector3(20,1.9,-3.5),Vector3(20,1,-11)],
	"19_front_gate": [Vector3(0,1.6,2),Vector3(0,1.5,8)],
	"21_library_north": [Vector3(-22,1.6,-6.5),Vector3(-22,1.4,-14)],
	"22_library_rows": [Vector3(-21,1.6,-7.4),Vector3(-26,1.2,-7.4)],
	"23_entrance_west_close": [Vector3(-3,1.6,1),Vector3(-7.5,1,0)],
	"24_entrance_east_close": [Vector3(3,1.6,0),Vector3(7.5,1,-1.6)],
	"25_corridor_back": [Vector3(-20,1.6,5),Vector3(-9,1.2,5)],
	"26_servants_close": [Vector3(9,1.6,13.5),Vector3(12,.8,9)],
	"20_library_desk": [Vector3(-19.6,1.7,-5.6),Vector3(-19.6,.9,-9)],
}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("F:/my-fps-game/validation/art/tour")
	Game.start()
	var player = Game.player
	player.set_physics_process(false)
	player.weapon.visible = false
	Game.ui.visible = false
	for e in get_tree().get_nodes_in_group("enemies"): e.queue_free()
	for d in get_tree().get_nodes_in_group("doors"):
		if d.kind != "exit": d.open()
	var x = -3.0
	for id in ["thrall","caster","swarmer","guardian"]:
		var e = Game.level.enemy(id,Vector3(x,.1,-0.5),Rect2(-8,-8,16,16))
		e.set_physics_process(false)
		var off = Vector3(0,0,3.5) - e.position
		e.visual.rotation.y = atan2(-off.x,-off.z)
		x += 2.0
	await get_tree().create_timer(1.0).timeout
	var cam = player.camera
	var only = OS.get_cmdline_user_args()
	for key in views:
		if only.size() > 0 and not only.has(key): continue
		var v = views[key]
		player.global_position = v[0] - Vector3(0,1.6,0)
		cam.global_position = v[0]
		cam.look_at(v[1],Vector3.UP)
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("F:/my-fps-game/validation/art/tour/"+key+".png")
	print("TOUR DONE")
	get_tree().quit()
