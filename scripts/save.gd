class_name DvorikSave
extends RefCounted

# Один дворик, один файл. Сетка + список открытых видов.
const PATH := "user://dvorik.save"
const VIEW_STREET := "street"
const GRID := 8
const SLOT_COUNT := 64


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
