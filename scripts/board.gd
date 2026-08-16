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

const TAP_MAX_MS := 400
const TAP_MAX_MOVE := 24.0

var _cells: Array[Cell] = []
var _found: Array = []
var _knock: AudioStreamPlayer
var _walkers: Walkers

var iso_hw: float = 28.0
var iso_hh: float = 14.0
var iso_th: float = 10.0
var iso_origin: Vector2 = Vector2.ZERO

var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _last_tap_ms: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_knock = AudioStreamPlayer.new()
	_knock.stream = DvorikKnock.make_stream()
	_knock.volume_db = -6.0
	add_child(_knock)
	_build()
	_walkers = Walkers.new()
	add_child(_walkers)
	_load()
	_walkers.setup(self)
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
	if size.x <= 1.0 or size.y <= 1.0:
		return
	# Весь 8×8 на одном экране, без скролла.
	var pad := minf(size.x, size.y) * 0.04
	var usable_w := size.x - pad * 2.0
	var usable_h := size.y - pad * 2.0
	# Ширина поля ≈ (GRID-1)*2*hw? span x = (GRID-1)*hw*2 для углов (0,G-1) и (G-1,0)
	# x range: -(G-1)*hw .. +(G-1)*hw → 2*(G-1)*hw
	# y range: 0 .. 2*(G-1)*hh плюс толщина и крыши
	var span_cells := float(GRID - 1)
	var roof_room := usable_h * 0.10
	var th_room := usable_h * 0.06
	var hw_by_w := usable_w / (2.0 * span_cells)
	var hh_by_h := (usable_h - roof_room - th_room) / (2.0 * span_cells)
	iso_hw = minf(hw_by_w, hh_by_h * 2.05)
	iso_hh = iso_hw * 0.50
	iso_th = iso_hw * 0.32
	var field_w := 2.0 * span_cells * iso_hw
	var field_h := 2.0 * span_cells * iso_hh
	iso_origin = Vector2(
		size.x * 0.5,
		pad + roof_room + (usable_h - roof_room - th_room - field_h) * 0.35
	)
	var cell_w := iso_hw * 2.4
	var cell_h := iso_hh * 2.4 + iso_th * 3.8 + iso_hw * 0.9
	for cell in _cells:
		var local_c := Iso.grid_to_screen(cell.grid_x, cell.grid_y, iso_hw, iso_hh)
		var top_left := iso_origin + local_c - Vector2(cell_w * 0.5, cell_h * 0.42)
		cell.size = Vector2(cell_w, cell_h)
		cell.pivot_offset = cell.size * 0.5
		cell.iso_hw = iso_hw
		cell.iso_hh = iso_hh
		cell.iso_th = iso_th
		cell.iso_c = Vector2(cell_w * 0.5, cell_h * 0.42)
		cell.z_index = Iso.depth_key(cell.grid_x, cell.grid_y)
		cell.sync_home(top_left)
		cell.queue_redraw()
	_update_pond_props()
	if _walkers != null:
		_walkers.queue_redraw()
	queue_redraw()


func grid_to_board_pos(gx: float, gy: float) -> Vector2:
	return iso_origin + Iso.grid_to_screen(gx, gy, iso_hw, iso_hh)


func _draw() -> void:
	# Мягкий воздух двора — не плоская схема.
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := TileType.SKY_TOP
	var bot := TileType.SKY_BOT
	for i in 8:
		var t := float(i) / 7.0
		var y0 := size.y * t
		var y1 := size.y * (float(i + 1) / 7.0)
		draw_rect(Rect2(0.0, y0, size.x, y1 - y0 + 1.0), top.lerp(bot, t))


func bind_palette(palette: Palette) -> void:
	set_meta("palette", palette)


func _gui_input(event: InputEvent) -> void:
	# Один палец. Свайп / пинч / долгий тап — игнор.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index != 0:
			_pressing = false
			return
		if st.pressed:
			_begin_press(st.position)
		elif _pressing:
			_finish_press(st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index != 0:
			_pressing = false
			return
		if _pressing and sd.position.distance_to(_press_pos) > TAP_MAX_MOVE:
			_pressing = false
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_press(mb.position)
		elif _pressing:
			_finish_press(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing and mm.position.distance_to(_press_pos) > TAP_MAX_MOVE:
			_pressing = false


func _begin_press(pos: Vector2) -> void:
	_pressing = true
	_press_pos = pos
	_press_ms = Time.get_ticks_msec()


func _finish_press(pos: Vector2) -> void:
	_pressing = false
	if Time.get_ticks_msec() - _press_ms > TAP_MAX_MS:
		return
	if pos.distance_to(_press_pos) > TAP_MAX_MOVE:
		return
	if Time.get_ticks_msec() - _last_tap_ms < 80:
		return
	_last_tap_ms = Time.get_ticks_msec()
	var gp := _pick_cell(pos)
	if gp.x < 0:
		return
	_on_cell_tapped(_cell_at(gp))


func _pick_cell(local_pos: Vector2) -> Vector2i:
	# Обратная изометрия + проверка ромба верхней грани.
	var g := Iso.screen_to_grid(local_pos - iso_origin, iso_hw, iso_hh)
	var candidates: Array[Vector2i] = []
	var base := Vector2i(roundi(g.x), roundi(g.y))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var gp := base + Vector2i(dx, dy)
			if _in_bounds(gp) and _point_in_cell(local_pos, gp):
				candidates.append(gp)
	if candidates.is_empty():
		# Мягкий fallback по ближайшему центру.
		var best := Vector2i(-1, -1)
		var best_d := 1e12
		for cell in _cells:
			var c := grid_to_board_pos(cell.grid_x, cell.grid_y)
			var d := local_pos.distance_squared_to(c)
			if d < best_d:
				best_d = d
				best = Vector2i(cell.grid_x, cell.grid_y)
		if best.x >= 0 and local_pos.distance_to(grid_to_board_pos(best.x, best.y)) < iso_hw * 1.35:
			return best
		return Vector2i(-1, -1)
	# Ближе к камере (больше gx+gy) побеждает при перекрытии.
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Iso.depth_key(a.x, a.y) > Iso.depth_key(b.x, b.y)
	)
	return candidates[0]


func _point_in_cell(local_pos: Vector2, gp: Vector2i) -> bool:
	var c := grid_to_board_pos(gp.x, gp.y)
	var p := local_pos - c
	# Ромб: |x|/hw + |y|/hh <= 1, плюс немного вниз на толщину/домик.
	var in_top := absf(p.x) / iso_hw + absf(p.y) / iso_hh <= 1.12
	var in_vol := absf(p.x) / iso_hw + absf(p.y - iso_th * 0.5) / (iso_hh + iso_th) <= 1.25
	return in_top or (p.y > 0.0 and in_vol)


func _on_cell_tapped(cell: Cell) -> void:
	if not has_meta("palette"):
		return
	var palette: Palette = get_meta("palette")
	try_place(cell.grid_x, cell.grid_y, palette.selected)


func try_place(x: int, y: int, tile: int) -> void:
	var gp := Vector2i(x, y)
	var cell := _cell_at(gp)
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
	_update_pond_props()
	if _walkers != null:
		_walkers.refresh_walkable()
	_save()


func _relay_neighbors(gp: Vector2i) -> void:
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


func _update_pond_props() -> void:
	var waters: Array[Cell] = []
	for cell in _cells:
		cell.show_lily = false
		cell.show_duck = false
		if cell.tile == TileType.WATER:
			waters.append(cell)
	if waters.is_empty():
		return
	# Одна кувшинка на пруд (первая вода).
	waters[0].show_lily = true
	waters[0].queue_redraw()
	# Утка — когда воды ≥ 2, на клетке с соседом-водой (или второй).
	if waters.size() >= 2:
		var duck_cell: Cell = waters[1]
		for w in waters:
			if w.edge_n == TileType.WATER or w.edge_e == TileType.WATER \
					or w.edge_s == TileType.WATER or w.edge_w == TileType.WATER:
				duck_cell = w
				break
		duck_cell.show_duck = true
		duck_cell.queue_redraw()


func walkable_cells() -> Array:
	# Дорога или клетка ортогонально у дома. В дома не заходят.
	var roads := false
	var out: Array = []
	for cell in _cells:
		if cell.tile == TileType.ROAD:
			roads = true
			out.append(Vector2i(cell.grid_x, cell.grid_y))
	if roads:
		for cell in _cells:
			if cell.tile != TileType.EMPTY:
				continue
			if cell.edge_n == TileType.HOUSE or cell.edge_e == TileType.HOUSE \
					or cell.edge_s == TileType.HOUSE or cell.edge_w == TileType.HOUSE:
				var gp := Vector2i(cell.grid_x, cell.grid_y)
				if gp not in out:
					out.append(gp)
		return out
	# Нет дорог — толкутся у стартового дома (не на клетке дома).
	var near: Array = []
	for d in ORTHO:
		var n: Vector2i = START_HOUSE + d
		if _in_bounds(n) and _cell_at(n).tile != TileType.HOUSE:
			near.append(n)
	for d2 in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n2: Vector2i = START_HOUSE + d2
		if _in_bounds(n2) and _cell_at(n2).tile != TileType.HOUSE:
			near.append(n2)
	if near.is_empty():
		# Любая пустая рядом по Манхэттену.
		for cell in _cells:
			if cell.tile == TileType.HOUSE:
				continue
			var gp := Vector2i(cell.grid_x, cell.grid_y)
			if absi(gp.x - START_HOUSE.x) + absi(gp.y - START_HOUSE.y) <= 2:
				near.append(gp)
	return near


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
	_update_pond_props()


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
