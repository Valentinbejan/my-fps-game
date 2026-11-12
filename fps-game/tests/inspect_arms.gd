extends SceneTree
func _initialize():call_deferred("inspect")
func inspect():
	var arms=load("res://assets/models/arms.glb").instantiate()
	root.add_child(arms)
	var skeleton=arms.find_child("Skeleton3D",true,false)
	var animation=arms.find_child("AnimationPlayer",true,false)
	for action in ["finger_gun_idle","guard_idle","jab_L"]:
		animation.play(action)
		animation.advance(.12)
		print(action)
		for name in ["hand.R","hand.L"]:
			print(name," ",skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin)
	arms.queue_free()
	await process_frame
	quit()
