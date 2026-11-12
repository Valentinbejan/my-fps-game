extends Node
var clips: Dictionary = {}
var ambient: AudioStreamPlayer
var ritual: AudioStreamPlayer
var title_music: AudioStreamPlayer

func _ready() -> void:
	for id in ["pistol","shotgun","hit","step","dash","parry","pickup","door","reload","slam","cast"]:
		clips[id] = load("res://assets/audio/" + id + ".wav")
	# Music: Crow Shade, "Mind's Eye" horror pack (CC BY, credit Crow Shade).
	var music = "res://assets/third_party/crow-shade/music/"
	clips["ambient"] = load(music+"veil_of_night.ogg")
	clips["ritual"] = load(music+"somethings_wrong.ogg")
	for id in ["ambient", "ritual"]:
		clips[id].loop = true
	ambient = AudioStreamPlayer.new()
	ambient.stream = clips.ambient
	ambient.volume_db = -14
	add_child(ambient)
	ambient.play()
	title_music = AudioStreamPlayer.new()
	title_music.stream = load(music+"midnight_dreams.ogg")
	title_music.volume_db = -12
	title_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(title_music)
	ritual = AudioStreamPlayer.new()
	ritual.stream = clips.ritual
	ritual.volume_db = -80
	add_child(ritual)
	ritual.play()

func cue(id: String, volume: float = -8.0, pitch: float = 1.0) -> void:
	if not clips.has(id):
		return
	var audio = AudioStreamPlayer.new()
	audio.stream = clips[id]
	audio.volume_db = volume
	audio.pitch_scale = pitch
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func at(id: String, pos: Vector3, volume: float = -4.0) -> void:
	if not clips.has(id):
		return
	var audio = AudioStreamPlayer3D.new()
	audio.stream = clips[id]
	audio.position = pos
	audio.volume_db = volume
	audio.max_distance = 24
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func combat(active: bool) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ritual, "volume_db", -11.0 if active else -80.0, 1.2)
	tween.tween_property(ambient, "volume_db", -40.0 if active else -14.0, 1.2)

# Title screen plays "Midnight Dreams"; gameplay crossfades to the exploration loop.
func title(active: bool) -> void:
	if active:
		ambient.volume_db = -80
		if not title_music.playing: title_music.play()
	else:
		title_music.stop()
		create_tween().tween_property(ambient,"volume_db",-14.0,1.5)
