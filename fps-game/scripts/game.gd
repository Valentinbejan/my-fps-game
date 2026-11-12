extends Node
signal health_changed
signal objective_changed
signal style_changed
signal message(text: String)
var player
var level
var ui
var inventory: InventoryModel
var mode: String = "title"
var objective: String = "Search the west wing for a way through."
var health: float = 100.0
var style: float = 0.0
var last_style_action: String = ""
var repeat_count: int = 0
var kills: int = 0
var parries: int = 0
var elapsed: float = 0.0
var guardian_dead: bool = false
var arena_started: bool = false
var autostart: bool = false
var room_name: String = "ENTRANCE HALL"
var highest_rank: int = 0
var crt_enabled: bool = true
var fps_samples: Array[float] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bindings = {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"dash":KEY_SHIFT,"slide":KEY_CTRL,"punch":KEY_F,"interact":KEY_E,"reload":KEY_R,"pistol":KEY_1,"shotgun":KEY_2,"smg":KEY_3,"flare":KEY_4,"inventory":KEY_TAB,"pause":KEY_ESCAPE,"crt":KEY_F6}
	for action in bindings:
		InputMap.add_action(action)
		var event = InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action,event)
	InputMap.add_action("fire")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire",mouse)
	autostart = "--autoplay" in OS.get_cmdline_user_args()

func reset() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(Sound.ritual): Sound.combat(false)
	inventory = InventoryModel.new()
	inventory.add_item("pistol",1,{"loaded":12})
	inventory.add_item("bullets",30)
	inventory.add_item("herb")
	health = 100
	style = 0
	kills = 0
	parries = 0
	elapsed = 0
	highest_rank = 0
	last_style_action = ""
	repeat_count = 0
	guardian_dead = false
	arena_started = false
	objective = "Search the west wing. Find the Iron Crest."
	room_name = "ENTRANCE HALL"
	fps_samples.clear()

func _process(delta: float) -> void:
	if mode == "playing" and not get_tree().paused:
		elapsed += delta
		style = maxf(0, style - delta * 4)
		if Engine.get_frames_drawn() % 60 == 0:
			fps_samples.append(Engine.get_frames_per_second())

func start() -> void:
	mode = "playing"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sound.title(false)
	ui.show_play()
	message.emit("The west wing remembers. Find the Iron Crest.")

func restart() -> void:
	autostart = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func hurt(amount: float) -> void:
	if mode != "playing" or health <= 0 or (is_instance_valid(player) and player.dash_time > 0):
		return
	health = maxf(0,health - amount)
	shake(.3)
	style *= .65
	health_changed.emit()
	Sound.cue("hit",-5)
	if is_instance_valid(ui): ui.damage_flash = .65
	if health <= 0:
		mode = "dead"
		Engine.time_scale = 1.0
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.show_end(false)

func heal(amount: float) -> void:
	health = minf(100,health+amount)
	health_changed.emit()

func score(action: String, amount: float) -> void:
	var rank_before = rank_index()
	if action == last_style_action:
		repeat_count += 1
	else:
		repeat_count = 0
	last_style_action = action
	style = minf(1200,style + amount / (1.0 + repeat_count * .35))
	highest_rank = maxi(highest_rank,rank_index())
	style_changed.emit()
	if is_instance_valid(ui):
		ui.style_action = action
		ui.style_time = 2
		if rank_index() > rank_before:
			ui.rank_flash = 1.3
			Sound.cue("parry",-15,.7+rank_index()*.12)

# Brief freeze-frame on heavy hits. Uses a real-time timer so it always recovers.
func hitstop(duration: float) -> void:
	if Engine.time_scale < 1.0 or mode != "playing": return
	Engine.time_scale = .05
	await get_tree().create_timer(duration,true,false,true).timeout
	Engine.time_scale = 1.0

func shake(amount: float) -> void:
	if is_instance_valid(player): player.shake = maxf(player.shake,amount)

func rank_index() -> int:
	var result = 0
	for threshold in [50,140,270,450,700,1000]:
		if style >= threshold: result += 1
	return result

func rank_name() -> String:
	return ["D","C","B","A","S","SS","SSS"][rank_index()]

func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit()
	message.emit(text)

func acquired(id: String) -> void:
	if id == "smg":
		message.emit("The Stitcher. Thirty rounds of 9mm; it drinks pistol ammunition.")
	elif id == "flare":
		message.emit("A flare gun. Fire at your feet to leap; fire at a crowd to burn it.")
	elif id == "powder":
		message.emit("Black powder. Craft it into ammunition from the inventory (TAB).")
	if id == "iron_key":
		set_objective("Iron Crest found. Open the armory north of the library.")
	elif id == "crimson_key":
		set_objective("Return to the entrance. Unlock the eastern ritual hall.")

func guardian_defeated() -> void:
	guardian_dead = true
	Sound.combat(false)
	set_objective("The house releases you. Return to the entrance and escape.")
	level.release_arena()

func win() -> void:
	if not guardian_dead: return
	mode = "won"
	Engine.time_scale = 1.0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_end(true)

func clear_line(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var query = PhysicsRayQueryParameters3D.create(from,to,1,exclude)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func blood(at: Vector3, amount: float, action: String) -> void:
	score(action,amount)
	if is_instance_valid(player) and player.global_position.distance_to(at) < 3.5 and clear_line(player.global_position+Vector3.UP,at):
		heal(minf(14,amount*.22))
		if is_instance_valid(ui): ui.heal_flash = .25
	if is_instance_valid(level): level.burst(at,Color(.65,.015,.025),9+rank_index()*3)

