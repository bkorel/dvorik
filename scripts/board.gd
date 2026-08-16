class_name Board
extends Control

const GRID := 8
const START_HOUSE := Vector2i(3, 3)
const ORTHO: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var _cells: Array[Cell] = []
var _found: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_load()
	resized.connect(_relayout)
	_relayout()


func _build() -> void:
	for y in GRID:
		for x in GRID:
			var cell := Cell.new()
			cell.grid_x = x
			cell.grid_y = y
			cell.tapped.connect(_on_cell_tapped)
			add_child(cell)
			_cells.append(cell)


func _relayout() -> void:
	var side := minf(size.x, size.y)
	var cell_s := side / float(GRID)
	var ox := (size.x - side) * 0.5
	var oy := (size.y - side) * 0.5
	for cell in _cells:
		cell.position = Vector2(ox + float(cell.grid_x) * cell_s, oy + float(cell.grid_y) * cell_s)
		cell.size = Vector2(cell_s, cell_s)
		cell.pivot_offset = cell.size * 0.5
		cell.queue_redraw()


func bind_palette(palette: Palette) -> void:
	# тап клетки ставит то, что сейчас в руке
	set_meta("palette", palette)


func _on_cell_tapped(cell: Cell) -> void:
	if not has_meta("palette"):
		return
	var palette: Palette = get_meta("palette")
	try_place(cell.grid_x, cell.grid_y, palette.selected)


func try_place(x: int, y: int, tile: int) -> void:
	var cell := _cell_at(Vector2i(x, y))
	# тот же тип — тычок без смены вида, сейв не трогаем
	if cell.tile == tile:
		cell.poke()
		return
	cell.tile = tile
	cell.queue_redraw()
	_refresh_edges(Vector2i(x, y))
	_maybe_discover_street()
	_save()


func _refresh_edges(gp: Vector2i) -> void:
	_update_joins(gp)
	for d in ORTHO:
		var n: Vector2i = gp + d
		if _in_bounds(n):
			_update_joins(n)


func _update_joins(gp: Vector2i) -> void:
	var cell := _cell_at(gp)
	# неделя 1: только дом+дом. клетка не выбирает «кем я стала».
	var n := false
	var e := false
	var s := false
	var w := false
	if cell.tile == TileType.HOUSE:
		n = _is_house(gp + Vector2i(0, -1))
		e = _is_house(gp + Vector2i(1, 0))
		s = _is_house(gp + Vector2i(0, 1))
		w = _is_house(gp + Vector2i(-1, 0))
	cell.merge_n = n
	cell.merge_e = e
	cell.merge_s = s
	cell.merge_w = w
	cell.queue_redraw()


func _is_house(gp: Vector2i) -> bool:
	return _in_bounds(gp) and _cell_at(gp).tile == TileType.HOUSE


func _maybe_discover_street() -> void:
	if DvorikSave.VIEW_STREET in _found:
		return
	var any_street := false
	for cell in _cells:
		if cell.has_street_edge():
			any_street = true
			break
	if not any_street:
		return
	_found.append(DvorikSave.VIEW_STREET)
	for cell in _cells:
		if cell.has_street_edge():
			cell.start_flash()


func _load() -> void:
	var data := DvorikSave.load_or_default()
	var grid: Array = data["grid"]
	_found = data["found"].duplicate()
	for i in _cells.size():
		_cells[i].tile = int(grid[i])
		_cells[i].flash = 0.0
		_cells[i].set_process(false)
	for y in GRID:
		for x in GRID:
			_update_joins(Vector2i(x, y))


func _save() -> void:
	var grid: Array = []
	grid.resize(64)
	for i in _cells.size():
		grid[i] = _cells[i].tile
	DvorikSave.write_now(grid, _found)


func _cell_at(gp: Vector2i) -> Cell:
	return _cells[gp.y * GRID + gp.x]


func _in_bounds(gp: Vector2i) -> bool:
	return gp.x >= 0 and gp.y >= 0 and gp.x < GRID and gp.y < GRID
