class_name InventoryModel
extends RefCounted
signal changed
const WIDTH = 5
const HEIGHT = 4
var items: Array[Dictionary] = []
var storage: Array[Dictionary] = []
var definitions: Dictionary = {}
var next_uid: int = 1

func _init() -> void:
	for id in ["pistol", "shotgun", "smg", "flare", "bullets", "shells", "flares", "powder", "herb", "medicine", "iron_key", "crimson_key"]:
		definitions[id] = load("res://data/items/" + id + ".tres")

func dimensions(item: Dictionary) -> Vector2i:
	var dim: Vector2i = definitions[item.id].size
	return Vector2i(dim.y, dim.x) if item.rotated else dim

func fits(item: Dictionary, cell: Vector2i, rotated: bool, ignore_uid: int = -1) -> bool:
	var probe = item.duplicate()
	probe.rotated = rotated
	var dim = dimensions(probe)
	var rect = Rect2i(cell, dim)
	if cell.x < 0 or cell.y < 0 or cell.x + dim.x > WIDTH or cell.y + dim.y > HEIGHT:
		return false
	for other in items:
		if other.uid != ignore_uid and rect.intersects(Rect2i(other.cell, dimensions(other))):
			return false
	return true

func find_space(item: Dictionary) -> Vector2i:
	for y in HEIGHT:
		for x in WIDTH:
			if fits(item, Vector2i(x, y), item.rotated):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

# Atomic pickup: failure never partially merges or consumes a world item.
func add_item(id: String, count: int = 1, extra: Dictionary = {}) -> bool:
	if not definitions.has(id) or count <= 0:
		return false
	var snapshot = items.duplicate(true)
	var saved_uid = next_uid
	var remaining = count
	for item in items:
		if item.id == id and definitions[id].stack_limit > 1:
			var transfer = mini(remaining, definitions[id].stack_limit - item.count)
			item.count += transfer
			remaining -= transfer
	while remaining > 0:
		var item = {"uid": next_uid, "id": id, "count": mini(remaining, definitions[id].stack_limit), "cell": Vector2i.ZERO, "rotated": false, "loaded": int(extra.get("loaded", 0))}
		var cell = find_space(item)
		if cell.x < 0:
			item.rotated = true
			cell = find_space(item)
		if cell.x < 0:
			items = snapshot
			next_uid = saved_uid
			return false
		item.cell = cell
		items.append(item)
		next_uid += 1
		remaining -= item.count
	changed.emit()
	return true

func count_item(id: String) -> int:
	var total = 0
	for item in items:
		if item.id == id:
			total += item.count
	return total

func has_item(id: String) -> bool:
	return count_item(id) > 0

func get_item(uid: int) -> Dictionary:
	for item in items:
		if item.uid == uid:
			return item
	return {}

func weapon_item(id: String) -> Dictionary:
	for item in items:
		if item.id == id:
			return item
	return {}

func consume(id: String, amount: int = 1) -> bool:
	if count_item(id) < amount:
		return false
	for i in range(items.size() - 1, -1, -1):
		if items[i].id == id:
			var take = mini(amount, items[i].count)
			items[i].count -= take
			amount -= take
			if items[i].count == 0:
				items.remove_at(i)
			if amount == 0:
				break
	changed.emit()
	return true

func move_item(uid: int, cell: Vector2i, rotated: bool) -> bool:
	var item = get_item(uid)
	if item.is_empty() or not fits(item, cell, rotated, uid):
		return false
	item.cell = cell
	item.rotated = rotated
	changed.emit()
	return true

func remove_item(uid: int) -> Dictionary:
	for i in items.size():
		if items[i].uid == uid:
			var item = items[i].duplicate(true)
			items.remove_at(i)
			changed.emit()
			return item
	return {}

func store_item(uid: int) -> void:
	var item = remove_item(uid)
	if not item.is_empty():
		storage.append(item)
		changed.emit()

func retrieve(index: int) -> bool:
	if index < 0 or index >= storage.size():
		return false
	var item = storage[index]
	if add_item(item.id, item.count, item):
		storage.remove_at(index)
		changed.emit()
		return true
	return false

const RECIPES = [
	{"label": "2 HERBS  >  MEDICINE", "needs": {"herb": 2}, "gives": {"medicine": 1}},
	{"label": "1 POWDER  >  15 x 9MM", "needs": {"powder": 1}, "gives": {"bullets": 15}},
	{"label": "2 POWDER  >  6 SHELLS", "needs": {"powder": 2}, "gives": {"shells": 6}},
	{"label": "3 POWDER  >  1 FLARE", "needs": {"powder": 3}, "gives": {"flares": 1}},
]

func can_craft(index: int) -> bool:
	if index < 0 or index >= RECIPES.size():
		return false
	for id in RECIPES[index].needs:
		if count_item(id) < RECIPES[index].needs[id]:
			return false
	return true

# Atomic: ingredients are only spent if every product fits in the grid.
func craft_recipe(index: int) -> bool:
	if not can_craft(index):
		return false
	var snapshot = items.duplicate(true)
	var saved_uid = next_uid
	var recipe = RECIPES[index]
	for id in recipe.needs:
		consume(id, recipe.needs[id])
	for id in recipe.gives:
		if not add_item(id, recipe.gives[id]):
			items = snapshot
			next_uid = saved_uid
			changed.emit()
			return false
	return true

func craft() -> bool:
	return craft_recipe(0)

