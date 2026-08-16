class_name DvorikSave
extends RefCounted

# Один дворик, один файл. Сетка + список открытых видов.
const PATH := "user://dvorik.save"
const GRID := 8
const SLOT_COUNT := 64

# Стабильные id видов. Не переименовывать — уже в found у игроков.
const VIEW_STREET := "street"
const VIEW_PORCH := "porch"
const VIEW_POND := "pond"
const VIEW_GROVE := "grove"
const VIEW_REFLECTION := "reflection"
const VIEW_YARD := "yard"
const VIEW_PUDDLE := "puddle"
const VIEW_PATH := "path"
const VIEW_REEDS := "reeds"


## Вид пары двух типов по ортогональному ребру. Пусто — нет пары.
static func view_for(a: int, b: int) -> String:
	if a == TileType.EMPTY or b == TileType.EMPTY:
		return ""
	var lo := mini(a, b)
	var hi := maxi(a, b)
	if lo == TileType.HOUSE and hi == TileType.HOUSE:
		return VIEW_STREET
	if lo == TileType.HOUSE and hi == TileType.ROAD:
		return VIEW_PORCH
	if lo == TileType.HOUSE and hi == TileType.TREE:
		return VIEW_YARD
	if lo == TileType.HOUSE and hi == TileType.WATER:
		return VIEW_REFLECTION
	if lo == TileType.ROAD and hi == TileType.TREE:
		return VIEW_PATH
	if lo == TileType.ROAD and hi == TileType.WATER:
		return VIEW_PUDDLE
	if lo == TileType.TREE and hi == TileType.TREE:
		return VIEW_GROVE
	if lo == TileType.TREE and hi == TileType.WATER:
		return VIEW_REEDS
	if lo == TileType.WATER and hi == TileType.WATER:
		return VIEW_POND
	return ""


static func default_data() -> Dictionary:
	var cells: Array = []
	cells.resize(SLOT_COUNT)
	cells.fill(TileType.EMPTY)
	# Центр стартового дома: (3,3) в 0-индексе.
	cells[index_of(3, 3)] = TileType.HOUSE
	return {"grid": cells, "found": []}


static func index_of(x: int, y: int) -> int:
	return y * GRID + x


static func load_or_default() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return default_data()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return default_data()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_data()
	var data: Dictionary = parsed
	var raw: Array = data.get("grid", data.get("cells", []))
	var cells: Array = []
	cells.resize(SLOT_COUNT)
	cells.fill(TileType.EMPTY)
	for i in mini(SLOT_COUNT, raw.size()):
		cells[i] = TileType.clamp_id(int(raw[i]))
	var views: Array = []
	for v in data.get("found", data.get("unlocked_views", [])):
		views.append(str(v))
	return {"grid": cells, "found": views}


static func write_now(cells: Array, found: Array) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	var payload := {
		"v": 1,
		"grid": cells.duplicate(),
		"found": found.duplicate(),
	}
	file.store_string(JSON.stringify(payload))
