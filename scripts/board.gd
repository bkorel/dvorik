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
var _knock: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knock = AudioStreamPlayer.new()
	_knock.stream = DvorikKnock.make_stream()
	_knock.volume_db = -6.0
	add_child(_knock)
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
		cell.size = Vector2(cell_s, cell_s)
		cell.pivot_offset = cell.size * 0.5
		cell.sync_home(Vector2(ox + float(cell.grid_x) * cell_s, oy + float(cell.grid_y) * cell_s))
		cell.queue_redraw()
	queue_redraw()


func _draw() -> void:
	# Каменная плита вокруг сетки — холодный тёмный камень.
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var side := minf(size.x, size.y)
	var ox := (size.x - side) * 0.5
	var oy := (size.y - side) * 0.5
	var frame := Rect2(Vector2(ox, oy), Vector2(side, side)).grow(side * 0.022)
	draw_rect(frame, TileType.TABLE_EDGE)
	draw_rect(frame.grow(-side * 0.010), TileType.TABLE)
	# Холодная зернистость плиты.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 28:
		var p := Vector2(
			frame.position.x + rng.randf() * frame.size.x,
			frame.position.y + rng.randf() * frame.size.y
		)
		var a := Color(TileType.TABLE_GRAIN.r, TileType.TABLE_GRAIN.g, TileType.TABLE_GRAIN.b, 0.38)
		draw_circle(p, rng.randf_range(0.7, 1.8), a)
	TileArt.stone_grain(self, frame, 1, 1, 0.45)
	# Слегка скошенный верхний кант — плита читается как крыша двора.
	var bevel := side * 0.012
	var hi := Color(0.42, 0.43, 0.46, 0.22)
	var sh := Color(0.04, 0.04, 0.05, 0.40)
	draw_line(frame.position, Vector2(frame.end.x, frame.position.y), hi, bevel)
	draw_line(frame.position, Vector2(frame.position.x, frame.end.y), hi, bevel * 0.7)
	draw_line(Vector2(frame.position.x, frame.end.y), frame.end, sh, bevel)
	draw_line(Vector2(frame.end.x, frame.position.y), frame.end, sh, bevel * 0.7)


func bind_palette(palette: Palette) -> void:
	# тап клетки ставит то, что сейчас в руке
	set_meta("palette", palette)


func _on_cell_tapped(cell: Cell) -> void:
	if not has_meta("palette"):
		return
	var palette: Palette = get_meta("palette")
	try_place(cell.grid_x, cell.grid_y, palette.selected)


func try_place(x: int, y: int, tile: int) -> void:
	var gp := Vector2i(x, y)
	var cell := _cell_at(gp)
	# тот же тип — тычок без смены вида, сейв не трогаем
	if cell.tile == tile:
		cell.poke()
		return
	var was_empty := cell.tile == TileType.EMPTY
	cell.tile = tile
	cell.queue_redraw()
	if was_empty:
		cell.grow()
	else:
		_relay_neighbors(gp)
	_play_knock()
	_refresh_edges(gp)
	_maybe_discover_views()
	_save()


func _relay_neighbors(gp: Vector2i) -> void:
	# Соседи слегка сдвигаются от переложенной фишки и щёлкают на место.
	for d in ORTHO:
		var n: Vector2i = gp + d
		if not _in_bounds(n):
			continue
		var neighbor := _cell_at(n)
		if neighbor.tile == TileType.EMPTY:
			continue
		neighbor.nudge(Vector2(d))


func _play_knock() -> void:
	if _knock == null or _knock.stream == null:
		return
	_knock.stop()
	_knock.play()


func _refresh_edges(gp: Vector2i) -> void:
	_update_joins(gp)
	for d in ORTHO:
		var n: Vector2i = gp + d
		if _in_bounds(n):
			_update_joins(n)


func _update_joins(gp: Vector2i) -> void:
	var cell := _cell_at(gp)
	# На каждом ортогональном ребре — тип соседа. Клетка не меняет свой тип.
	cell.edge_n = _neighbor_tile(gp + Vector2i(0, -1))
	cell.edge_e = _neighbor_tile(gp + Vector2i(1, 0))
	cell.edge_s = _neighbor_tile(gp + Vector2i(0, 1))
	cell.edge_w = _neighbor_tile(gp + Vector2i(-1, 0))
	cell.queue_redraw()


func _neighbor_tile(gp: Vector2i) -> int:
	if not _in_bounds(gp):
		return TileType.EMPTY
	return _cell_at(gp).tile


func _maybe_discover_views() -> void:
	# Любой новый id вида — одна лаковая вспышка на затронутых фишках (обе стороны пары).
	var fresh: Array = []
	var flash_map: Dictionary = {}
	for cell in _cells:
		if cell.tile == TileType.EMPTY:
			continue
		for nt in [cell.edge_n, cell.edge_e, cell.edge_s, cell.edge_w]:
			var vid := DvorikSave.view_for(cell.tile, nt)
			if vid.is_empty():
				continue
			if vid in _found:
				continue
			if vid not in fresh:
				fresh.append(vid)
			var id: int = cell.get_instance_id()
			if not flash_map.has(id):
				flash_map[id] = {"cell": cell, "views": []}
			var views: Array = flash_map[id]["views"]
			if vid not in views:
				views.append(vid)
	if fresh.is_empty():
		return
	for vid in fresh:
		_found.append(vid)
	for entry in flash_map.values():
		var c: Cell = entry["cell"]
		c.start_flash(entry["views"])


func _load() -> void:
	var data := DvorikSave.load_or_default()
	var grid: Array = data["grid"]
	_found = data["found"].duplicate()
	for i in _cells.size():
		_cells[i].tile = int(grid[i])
		_cells[i].flash = 0.0
		_cells[i].flash_views.clear()
		_cells[i].set_process(false)
		_cells[i].reset_motion()
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
