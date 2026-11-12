extends Control
const INK = Color(.025,.03,.037,.97)
const PAPER = Color(.85,.82,.71)
const MUTED = Color(.46,.49,.47)
const GOLD = Color(.75,.55,.29)
const RED = Color(.66,.09,.10)
var font: Font
var title_font: Font
var menu: Control
var inventory_panel: Control
var storage_list: ItemList
var health_label: Label
var ammo_label: Label
var objective_label: Label
var prompt_label: Label
var toast_label: Label
var toast_time: float = 0
var damage_flash: float = 0
var heal_flash: float = 0
var hit_time: float = 0
var style_action: String = ""
var style_time: float = 0
var room_time: float = 3
var inventory_open: bool = false
var storage_open: bool = false
var selected: int = -1
var dragging: bool = false
var drag_rotated: bool = false
var drag_offset = Vector2i.ZERO
var grid_origin = Vector2(120,200)
var cell_size: float = 82
var info_label: Label
var crt: ColorRect
var storage_index: int = -1
var menu_kind: String = "title"
var recipe_list: ItemList
var recipe_index: int = -1
var rank_flash: float = 0
var note_panel: Control
var note_title: Label
var note_body: Label
const WEAPON_NAMES = {"pistol":"M1911 PISTOL","shotgun":"WARDEN 12 SHOTGUN","smg":"MP5 / STITCHER","flare":"HELLFIRE FLARE GUN"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Consolas","Courier New"])
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia","Times New Roman"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	inventory_panel = Control.new()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inventory_panel)
	inventory_panel.hide()
	health_label = label("",Vector2(52,608),32)
	ammo_label = label("",Vector2(975,608),32)
	objective_label = label("",Vector2(50,65),16)
	prompt_label = label("",Vector2(280,504),18)
	prompt_label.size.x = 720
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = label("",Vector2(250,124),17)
	toast_label.size.x = 780
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Game.message.connect(notify)
	Game.inventory.changed.connect(refresh_inventory)
	build_inventory()
	build_note()

func label(text: String,pos: Vector2,point_size: int = 18,parent: Node = null,color: Color = PAPER) -> Label:
	var node = Label.new()
	node.text = text
	node.position = pos
	node.add_theme_font_size_override("font_size",point_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color.BLACK)
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else self).add_child(node)
	return node

func button(text: String,pos: Vector2,callback: Callable,parent: Node = null,width: float = 290) -> Button:
	var node = Button.new()
	node.text = text
	node.position = pos
	node.size = Vector2(width,44)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(.065,.072,.074,.95)
	normal.border_color = Color(.34,.30,.23)
	normal.set_border_width_all(1)
	normal.content_margin_left = 18
	var hover = normal.duplicate()
	hover.bg_color = Color(.20,.105,.065)
	hover.border_color = GOLD
	node.add_theme_stylebox_override("normal",normal)
	node.add_theme_stylebox_override("hover",hover)
	node.add_theme_stylebox_override("focus",hover)
	node.add_theme_color_override("font_color",PAPER)
	node.pressed.connect(callback)
	(parent if parent else menu).add_child(node)
	return node

func clear_menu() -> void:
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()

func show_title() -> void:
	Game.player.weapon.visible = false
	menu_kind = "title"
	clear_menu()
	menu.show()
	label("A HOUSE THAT FEEDS ON THE LIVING",Vector2(64,127),14,menu,GOLD)
	var title = label("BLOOD\nKEY",Vector2(57,160),94,menu,Color(.85,.79,.65))
	title.add_theme_font_override("font",title_font)
	label("THE HOUSEKEEPER  /  PLAYABLE DEMO",Vector2(65,398),14,menu,MUTED)
	button("ENTER THE MANSION",Vector2(65,454),Game.start)
	button("CONTROLS",Vector2(65,508),show_controls)
	button("QUIT",Vector2(65,562),func():get_tree().quit())
	label("EXPLORE.  CONSERVE.  BLEED.",Vector2(66,658),14,menu,GOLD)

func show_play() -> void:
	Game.player.weapon.visible = true
	menu.hide()
	menu_kind = ""
	inventory_panel.hide()
	inventory_open = false

func show_pause() -> void:
	menu_kind = "pause"
	Game.mode = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_menu()
	menu.show()
	label("THE HOUSE WAITS",Vector2(458,155),32,menu)
	button("RESUME",Vector2(480,250),resume)
	button("CRT FILTER  [F6]",Vector2(480,307),toggle_crt)
	button("CONTROLS",Vector2(480,364),show_controls)
	button("RESTART DEMO",Vector2(480,421),Game.restart)
	button("QUIT",Vector2(480,478),func():get_tree().quit())

func resume() -> void:
	Game.mode = "playing"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	show_play()

func show_controls() -> void:
	var return_to = "title" if Game.mode == "title" else "pause"
	clear_menu()
	menu_kind = "controls"
	label("HUNTER'S FIELD NOTES",Vector2(265,118),34,menu)
	label("W A S D     Move             MOUSE       Aim\nSPACE       Jump / wall kick SHIFT       Ground / air dash\nCTRL        Slide / slam     F           Punch / parry\nLEFT CLICK  Fire             R           Reload\n1 2 3 4     Weapon / wheel   E           Interact / read\nTAB         Inventory        ESC         Pause\nF6          CRT filter       R (drag)    Rotate item",Vector2(267,200),20,menu)
	label("Blood heals at close range. Parry an ember just before impact.\nThree dash charges regenerate. Walls give you another jump.\nCraft herbs into medicine and black powder into ammunition.\nThe flare blast throws you too: fire at your feet to leap.",Vector2(267,424),17,menu,GOLD)
	button("BACK",Vector2(480,558),func():
		if return_to == "title": show_title()
		else: show_pause())

func show_end(won: bool) -> void:
	Game.player.weapon.visible = false
	menu_kind = "end"
	inventory_open = false
	inventory_panel.hide()
	clear_menu()
	menu.show()
	label("THE HOUSE LETS GO" if won else "THE HOUSE KEEPS YOU",Vector2(345,182),44,menu,GOLD if won else Color(.85,.24,.2))
	label("YOU ESCAPED" if won else "YOUR BLOOD JOINS THE WALLS",Vector2(437,261),20,menu)
	var seconds = int(Game.elapsed)
	label("TIME       %02d:%02d\nKILLS      %d\nPARRIES    %d\nBEST STYLE %s" % [int(seconds/60.0),seconds%60,Game.kills,Game.parries,["D","C","B","A","S","SS","SSS"][Game.highest_rank]],Vector2(490,328),20,menu)
	button("HUNT AGAIN",Vector2(480,493),Game.restart)
	button("QUIT",Vector2(480,550),func():get_tree().quit())

func build_inventory() -> void:
	label("FIELD INVENTORY",Vector2(120,99),32,inventory_panel)
	label("5 x 4  /  DRAG TO MOVE  /  R TO ROTATE",Vector2(121,151),15,inventory_panel,GOLD)
	info_label = label("Select an item.",Vector2(577,215),19,inventory_panel)
	info_label.size = Vector2(570,130)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("USE",Vector2(120,558),use_selected,inventory_panel,118)
	button("DROP",Vector2(248,558),drop_selected,inventory_panel,118)
	button("STORE",Vector2(376,558),store_selected,inventory_panel,154)
	button("RETURN  [TAB]",Vector2(577,558),close_inventory,inventory_panel,300)
	recipe_list = ItemList.new()
	recipe_list.position = Vector2(887,367)
	recipe_list.size = Vector2(300,165)
	recipe_list.add_theme_font_size_override("font_size",15)
	recipe_list.item_selected.connect(func(index): recipe_index=index)
	recipe_list.item_activated.connect(func(index): recipe_index=index; craft())
	inventory_panel.add_child(recipe_list)
	button("CRAFT SELECTED",Vector2(887,558),craft,inventory_panel,300)
	storage_list = ItemList.new()
	storage_list.position = Vector2(577,367)
	storage_list.size = Vector2(300,165)
	storage_list.add_theme_font_size_override("font_size",17)
	storage_list.item_selected.connect(func(index): storage_index=index)
	storage_list.item_activated.connect(func(index): Game.inventory.retrieve(index))
	inventory_panel.add_child(storage_list)
	button("RETRIEVE SELECTED",Vector2(577,610),retrieve,inventory_panel,300)
	label("Double-click a recipe to craft it.",Vector2(887,621),13,inventory_panel,MUTED)

func build_note() -> void:
	note_panel = Control.new()
	note_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note_panel)
	note_panel.hide()
	note_title = label("",Vector2(340,150),26,note_panel,Color(.22,.14,.08))
	note_body = label("",Vector2(340,210),19,note_panel,Color(.16,.11,.07))
	note_body.size = Vector2(600,330)
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for node in [note_title,note_body]:
		node.add_theme_color_override("font_shadow_color",Color(0,0,0,0))
	label("[E] / [ESC]  PUT IT DOWN",Vector2(340,560),14,note_panel,Color(.4,.28,.16))

func show_note(title: String,body: String) -> void:
	if Game.mode != "playing": return
	note_title.text = title
	note_body.text = body
	note_panel.show()
	Game.mode = "reading"
	get_tree().paused = true

func close_note() -> void:
	note_panel.hide()
	Game.mode = "playing"
	get_tree().paused = false

func open_inventory(storage: bool = false) -> void:
	if Game.mode != "playing": return
	inventory_open = true
	storage_open = storage
	dragging = false
	selected = -1
	Game.mode = "inventory"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inventory_panel.show()
	refresh_inventory()

func close_inventory() -> void:
	dragging = false
	inventory_open = false
	inventory_panel.hide()
	resume()

func refresh_inventory() -> void:
	if not storage_list: return
	storage_list.clear()
	storage_index = -1
	if storage_open:
		for item in Game.inventory.storage:
			storage_list.add_item(Game.inventory.definitions[item.id].title+"  x"+str(item.count))
		if Game.inventory.storage.is_empty(): storage_list.add_item("Chest empty. Select an item, STORE.")
	else:
		storage_list.add_item("Storage: entrance chest.")
	recipe_list.clear()
	for i in InventoryModel.RECIPES.size():
		recipe_list.add_item(InventoryModel.RECIPES[i].label+("" if Game.inventory.can_craft(i) else "  (need)"))
		recipe_list.set_item_custom_fg_color(i,PAPER if Game.inventory.can_craft(i) else MUTED)
	if recipe_index >= 0 and recipe_index < InventoryModel.RECIPES.size(): recipe_list.select(recipe_index)
	var item = Game.inventory.get_item(selected)
	if item.is_empty():
		info_label.text = "Select an item.\n\nItems you drop remain in the mansion."
	else:
		var def = Game.inventory.definitions[item.id]
		info_label.text = def.title+"\n\n"+def.description
	queue_redraw()

func use_selected() -> void:
	var item = Game.inventory.get_item(selected)
	if item.is_empty(): return
	if item.id in ["pistol","shotgun","smg","flare"]:
		Game.player.weapon.equip(item.id)
		notify("Equipped " + Game.inventory.definitions[item.id].title)
	elif item.id == "powder":
		notify("Craft black powder into ammunition: pick a recipe on the right.")
	elif item.id in ["herb","medicine"]:
		if Game.health >= 100:
			notify("Already at full health.")
			return
		Game.heal(25 if item.id=="herb" else 65)
		Game.inventory.remove_item(selected)
		selected = -1
		Sound.cue("pickup",-12)
	refresh_inventory()

func drop_selected() -> void:
	var item = Game.inventory.remove_item(selected)
	if not item.is_empty():
		Game.level.drop_item(item)
		selected = -1
		notify("Item dropped at your feet.")
	refresh_inventory()

func store_selected() -> void:
	if not storage_open:
		notify("Use the entrance chest to store items.")
		return
	Game.inventory.store_item(selected)
	selected = -1
	refresh_inventory()

func retrieve() -> void:
	if storage_open and storage_index >= 0:
		if not Game.inventory.retrieve(storage_index): notify("No space to retrieve that item.")

func craft() -> void:
	if recipe_index < 0:
		notify("Select a recipe first.")
		return
	var recipe = InventoryModel.RECIPES[recipe_index]
	if Game.inventory.craft_recipe(recipe_index):
		notify("Crafted: " + recipe.label.replace("  "," "))
		Sound.cue("reload",-10)
	elif not Game.inventory.can_craft(recipe_index):
		notify("Missing ingredients for " + recipe.label.replace("  "," ") + ".")
	else:
		notify("No room in the grid for the result.")

func toggle_crt() -> void:
	Game.crt_enabled = not Game.crt_enabled
	crt.material.set_shader_parameter("crt_enabled",Game.crt_enabled)
	notify("CRT filter " + ("ON" if Game.crt_enabled else "OFF"))

func notify(text: String) -> void:
	toast_label.text = text
	toast_time = 4

func _input(event: InputEvent) -> void:
	if Game.mode == "reading":
		if event.is_action_pressed("interact") or event.is_action_pressed("pause") or (event is InputEventMouseButton and event.pressed):
			close_note()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("crt"):
		toggle_crt()
	if event.is_action_pressed("pause"):
		if inventory_open: close_inventory()
		elif Game.mode == "playing": show_pause()
		elif Game.mode == "paused": resume()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("inventory"):
		if inventory_open: close_inventory()
		elif Game.mode == "playing": open_inventory()
		get_viewport().set_input_as_handled()
	if not inventory_open: return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R and dragging:
		drag_rotated = not drag_rotated
		drag_offset = Vector2i.ZERO
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse = get_global_transform().affine_inverse() * event.position
		if event.pressed and Rect2(grid_origin,Vector2(cell_size*5,cell_size*4)).has_point(mouse):
			var cell = Vector2i((mouse-grid_origin)/cell_size)
			selected = -1
			for item in Game.inventory.items:
				if Rect2i(item.cell,Game.inventory.dimensions(item)).has_point(cell):
					selected = item.uid
					drag_rotated = item.rotated
					drag_offset = cell - item.cell
					dragging = true
					break
			refresh_inventory()
			get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			var cell = Vector2i(((mouse-grid_origin)/cell_size).floor())-drag_offset
			if not Game.inventory.move_item(selected,cell,drag_rotated):
				notify("That item does not fit there.")
			dragging = false
			refresh_inventory()

func _process(delta: float) -> void:
	toast_time = maxf(0,toast_time-delta)
	damage_flash = maxf(0,damage_flash-delta)
	heal_flash = maxf(0,heal_flash-delta)
	hit_time = maxf(0,hit_time-delta)
	style_time = maxf(0,style_time-delta)
	room_time = maxf(0,room_time-delta)
	rank_flash = maxf(0,rank_flash-delta)
	var playing = Game.mode == "playing"
	health_label.visible = playing
	ammo_label.visible = playing
	objective_label.visible = playing
	prompt_label.visible = playing
	toast_label.visible = toast_time > 0 and Game.mode != "title"
	if playing and is_instance_valid(Game.player):
		health_label.text = "%03d" % int(Game.health)
		objective_label.text = Game.objective
		prompt_label.text = Game.player.prompt
		var weapon = Game.player.weapon
		var item = Game.inventory.weapon_item(weapon.current)
		ammo_label.text = "-- / --" if item.is_empty() else "%02d / %02d" % [item.loaded,Game.inventory.count_item(weapon.definition.ammo_id)]
	queue_redraw()

func text_at(text: String,pos: Vector2,point_size: int,color: Color = PAPER) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,color)

func draw_item(item: Dictionary,pos: Vector2,rotated: bool,alpha: float = 1) -> void:
	var def = Game.inventory.definitions[item.id]
	var probe = item.duplicate()
	probe.rotated = rotated
	var dimensions = Vector2(Game.inventory.dimensions(probe))*cell_size-Vector2(6,6)
	var rect = Rect2(pos+Vector2(3,3),dimensions)
	var color: Color = def.tint
	color.a = alpha
	draw_rect(rect,Color(color.r*.19,color.g*.19,color.b*.19,.96*alpha))
	draw_rect(rect,color, false,1.5)
	var center = rect.get_center()
	# Simple legible inventory silhouettes, independent of weapon rendering.
	if item.id in ["pistol","shotgun","smg","flare"]:
		var length = minf(dimensions.x-20,90)
		draw_rect(Rect2(center-Vector2(length/2,12),Vector2(length,8)),color)
		draw_line(center+Vector2(-length*.28,-5),center+Vector2(-length*.35,12),color,7)
	elif item.id.ends_with("key"):
		draw_arc(center+Vector2(0,-10),10,0,TAU,12,color,3)
		draw_line(center,center+Vector2(0,24),color,3)
		draw_line(center+Vector2(0,18),center+Vector2(9,18),color,3)
	elif item.id == "powder":
		draw_rect(Rect2(center-Vector2(12,14),Vector2(24,26)),color)
		draw_line(center+Vector2(-12,-14),center+Vector2(12,-14),Color(.1,.1,.1,alpha),3)
	elif item.id in ["herb","medicine"]:
		draw_line(center+Vector2(0,14),center-Vector2(0,14),color,2)
		for side in [-1,1]:
			draw_line(center,center+Vector2(side*13,-10),color,5)
	else:
		for x in [-10,0,10]:draw_rect(Rect2(center+Vector2(x-2,-12),Vector2(5,19)),color)
	text_at(def.glyph,rect.position+Vector2(7,dimensions.y-8),12,color)
	if item.count > 1: text_at(str(item.count),rect.position+Vector2(dimensions.x-26,17),14,color)

func _draw() -> void:
	if Game.mode == "playing":
		draw_rect(Rect2(32,575,280,106),INK)
		draw_rect(Rect2(955,575,293,106),INK)
		draw_line(Vector2(32,575),Vector2(312,575),RED,3)
		draw_line(Vector2(955,575),Vector2(1248,575),GOLD,3)
		text_at("VITALITY / BLOOD",Vector2(52,599),13,MUTED)
		text_at("100",Vector2(137,643),13,MUTED)
		draw_rect(Rect2(52,657,232,5),Color(.18,.09,.09))
		draw_rect(Rect2(52,657,232*Game.health/100.0,5),RED)
		var weapon = Game.player.weapon
		text_at(WEAPON_NAMES.get(weapon.current,"BARE HANDS"),Vector2(977,599),13,GOLD)
		for i in weapon.ORDER.size():
			var id = weapon.ORDER[i]
			var owned = Game.inventory.has_item(id)
			var colour = GOLD if id == weapon.current else (PAPER if owned else Color(.25,.26,.26))
			text_at(str(i+1),Vector2(1160+i*20,599),13,colour)
		text_at("RELOADING" if weapon.reload_timer>0 else "R  RELOAD    F  PARRY",Vector2(977,663),13,MUTED)
		for i in 3:
			draw_rect(Rect2(581+i*42,647,32,6),GOLD if i<Game.player.dash_charges else Color(.22,.23,.23))
		text_at("DASH",Vector2(618,680),12,MUTED)
		draw_line(Vector2(635,360),Vector2(645,360),PAPER,1)
		draw_line(Vector2(640,355),Vector2(640,365),PAPER,1)
		if hit_time>0:
			for v in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				draw_line(Vector2(640,360)+v*8,Vector2(640,360)+v*15,GOLD,2)
		text_at("BLOOD KEY / THE HOUSEKEEPER",Vector2(50,45),13,GOLD)
		text_at(Game.room_name,Vector2(973,45),14,MUTED)
		if Game.style > 8:
			text_at(Game.rank_name(),Vector2(1160,221),54,GOLD)
			text_at(style_action if style_time>0 else "KEEP MOVING",Vector2(1000,253),13,PAPER)
			draw_rect(Rect2(1010,267,210*minf(1,Game.style/1000),3),RED)
		if rank_flash > 0:
			var grow = 1.0 + rank_flash*.6
			var colour = Color(GOLD.r,GOLD.g,GOLD.b,minf(1,rank_flash*1.5))
			text_at(Game.rank_name()+"!",Vector2(1100-grow*20,330),int(40*grow),colour)
			text_at(["","CRUEL","BRUTAL","ATROCIOUS","SADISTIC","SSSHOWSTOPPER","SSSUPREME"][Game.rank_index()],Vector2(1040,360),15,colour)
		if room_time>0:
			text_at(Game.room_name,Vector2(496,178),18,Color(.8,.75,.62,minf(1,room_time)))
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.enemy_id == "guardian" and not enemy.dead:
				text_at("THE HOUSEKEEPER",Vector2(517,94),18,GOLD)
				draw_rect(Rect2(390,105,500,6),Color(.14,.03,.03))
				draw_rect(Rect2(390,105,500*enemy.health/enemy.definition.health,6),RED)
		if damage_flash>0:draw_rect(Rect2(Vector2.ZERO,size),Color(.55,0,0,damage_flash*.32))
		if heal_flash>0:draw_rect(Rect2(Vector2.ZERO,size),Color(.1,.5,.3,heal_flash*.22))
	if menu.visible:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.01,.02,.45))
		if menu_kind == "title":
			draw_rect(Rect2(28,80,423,614),Color(.025,.025,.027,.93))
			draw_line(Vector2(65,108),Vector2(350,108),GOLD,1)
			draw_line(Vector2(65,436),Vector2(355,436),Color(.32,.25,.16),1)
		else:
			draw_rect(Rect2(230,85,820,570),INK)
			draw_rect(Rect2(230,85,820,570),GOLD,false,1)
	if Game.mode == "reading":
		draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.55))
		draw_rect(Rect2(300,110,680,490),Color(.78,.72,.58))
		draw_rect(Rect2(300,110,680,490),Color(.35,.25,.15),false,3)
		draw_line(Vector2(340,195),Vector2(940,195),Color(.45,.3,.18),1)
	if inventory_open:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.012,.018,.021,.96))
		draw_line(Vector2(120,177),Vector2(1187,177),GOLD,1)
		for y in 4:
			for x in 5:
				var rect = Rect2(grid_origin+Vector2(x,y)*cell_size,Vector2.ONE*(cell_size-1))
				draw_rect(rect,Color(.055,.065,.068))
				draw_rect(rect,Color(.18,.20,.19),false,1)
		for item in Game.inventory.items:
			draw_item(item,grid_origin+Vector2(item.cell)*cell_size,item.rotated,.4 if dragging and selected==item.uid else 1.0)
			if item.uid==selected:
				draw_rect(Rect2(grid_origin+Vector2(item.cell)*cell_size,Vector2(Game.inventory.dimensions(item))*cell_size),GOLD,false,2)
		if dragging:
			var item = Game.inventory.get_item(selected)
			if not item.is_empty():
				draw_item(item,get_local_mouse_position()-Vector2(drag_offset)*cell_size-Vector2(20,20),drag_rotated,.8)
		text_at("STORAGE CHEST" if storage_open else "SUPPLIES",Vector2(577,349),15,GOLD)
		text_at("CRAFTING",Vector2(887,349),15,GOLD)

