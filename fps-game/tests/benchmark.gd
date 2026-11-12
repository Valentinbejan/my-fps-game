extends Node
var clock: float=0
var samples: Dictionary={"entrance":[],"library":[],"arena":[]}
var previous_us: int=0
var phase: int=-1
var fps_peak: float=0
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("begin")
func begin():
	Game.start()
	Game.player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	Game.level.start_arena()
	Game.level.enemy("guardian",Vector3(20,.1,-6),Rect2(8,-14,24,22),true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	previous_us=Time.get_ticks_usec()
func _process(delta):
	if previous_us==0:return
	var now=Time.get_ticks_usec()
	var ms=(now-previous_us)/1000.0
	previous_us=now
	clock+=delta
	var next_phase=mini(2,int(clock/4))
	if next_phase!=phase:
		phase=next_phase
		Game.player.position=[Vector3(0,.1,5),Vector3(-20,.1,-2),Vector3(20,.1,5)][phase]
		Game.player.rotation=Vector3.ZERO
		Game.player.camera.rotation=Vector3.ZERO
	Game.health=100
	Game.player.rotation.y=sin(clock*.7)*.45
	if fmod(clock,4)>1:samples[["entrance","library","arena"][phase]].append(ms)
	if clock>=12:
		set_process(false)
		var report={"renderer":RenderingServer.get_video_adapter_name(),"resolution":str(get_viewport().get_visible_rect().size),"mode":"uncapped; 1 second warm-up and 3 seconds measured per room","rooms":{}}
		for room in samples:
			var values=samples[room]
			values.sort()
			var total=0.0
			for value in values:total+=value
			report.rooms[room]={"frames":values.size(),"mean_fps":snappedf(1000/(total/values.size()),.1),"p99_frame_ms":snappedf(values[mini(values.size()-1,int(values.size()*.99))],.01)}
		var file=FileAccess.open("F:/my-fps-game/validation/performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
		print("PERFORMANCE ",JSON.stringify(report))
		get_tree().quit()
