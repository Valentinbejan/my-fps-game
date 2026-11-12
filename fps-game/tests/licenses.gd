extends SceneTree
func _initialize():
	var file=FileAccess.open("F:/my-fps-game/builds/BloodKey/GODOT-LICENSE.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	file.close()
	file=FileAccess.open("F:/my-fps-game/builds/BloodKey/GODOT-THIRD-PARTY.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"components":Engine.get_copyright_info(),"licenses":Engine.get_license_info()},"\t"))
	file.close()
	quit()
