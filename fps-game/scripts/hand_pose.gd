extends SkeletonModifier3D
var grip: Dictionary = {}
var weapon
func _process_modification() -> void:
	var skeleton=get_skeleton()
	if not skeleton or not is_instance_valid(weapon):return
	if weapon.punch_cooldown <= .02:
		for index in grip:
			skeleton.set_bone_pose_rotation(index,grip[index])
