class_name Cell
extends Control

## Клетка. Тип не «превращается»: каждая сторона смотрит на ортогонального соседа.

signal tapped(cell: Cell)

const TAP_MAX_MS := 400
const TAP_MAX_MOVE := 24.0

var grid_x: int = 0
var grid_y: int = 0
var tile: int = TileType.EMPTY

# Тип соседа на ортогональном ребре. EMPTY — пусто / край доски. Диагональ не сосед.
var edge_n: int = TileType.EMPTY
var edge_e: int = TileType.EMPTY
var edge_s: int = TileType.EMPTY
var edge_w: int = TileType.EMPTY

# Лаковая вспышка вида: 1 → 0 один раз, ввод живой.
var flash: float = 0.0

var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _last_tap_ms: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	set_process(false)


func has_street_edge() -> bool:
	return tile == TileType.HOUSE and (
		edge_n == TileType.HOUSE
		or edge_e == TileType.HOUSE
		or edge_s == TileType.HOUSE
		or edge_w == TileType.HOUSE
	)


func poke() -> void:
	# Тот же тип — лёгкий тычок, вид не меняется.
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.93, 0.93), 0.05)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)


func start_flash() -> void:
	flash = 1.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if flash <= 0.0:
		flash = 0.0
		set_process(false)
		queue_redraw()
		return
	flash = maxf(0.0, flash - delta / 0.55)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Свайп / пинч / долгий тап — игнор. Только короткий тап.
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
	tapped.emit(self)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_draw_grass(r)
	match tile:
		TileType.HOUSE:
			_draw_house(r)
		TileType.ROAD:
			_draw_road(r)
		TileType.TREE:
			_draw_tree(r)
		TileType.WATER:
			_draw_water(r)


func _lit(base: Color) -> Color:
	if flash <= 0.0:
		return base
	return base.lerp(TileType.FLASH_LIT, clampf(flash, 0.0, 1.0) * 0.72)


func _draw_grass(r: Rect2) -> void:
	# Пустые — трава: сама доска, зеленоватая, с намёком на волокно. Не войд.
	draw_rect(r, TileType.GRASS)
	var rng := RandomNumberGenerator.new()
	rng.seed = grid_x * 17 + grid_y * 31 + 4
	for i in 6:
		var x0 := rng.randf() * r.size.x
		var y0 := rng.randf() * r.size.y
		var x1 := x0 + rng.randf_range(-r.size.x * 0.16, r.size.x * 0.16)
		var y1 := y0 + rng.randf_range(r.size.y * 0.05, r.size.y * 0.14)
		draw_line(Vector2(x0, y0), Vector2(x1, y1), TileType.GRASS_FIBER, 1.2)
	draw_rect(r, TileType.GRASS_SEAM, false, 1.5)


func _draw_house(r: Rect2) -> void:
	# Дом — высокий брусок с треугольной крышей; сверху прямоугольник и конёк.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.11
	var body := Rect2(Vector2(pad, pad - m * 0.08), Vector2(r.size.x - pad * 2.0, r.size.y - pad * 1.7))
	draw_rect(Rect2(body.position + Vector2(2, 4), body.size), TileType.SHADOW)
	draw_rect(body, _lit(TileType.WOOD_PALE))
	draw_rect(body, _lit(TileType.WOOD_MID), false, 2.0)
	var face := Rect2(body.position + Vector2(3, 3), body.size - Vector2(6, 8))
	draw_rect(face, _lit(TileType.WOOD_LIGHT))
	_draw_ridges(body)
	_draw_porches(body)
	_draw_yards(body)


func _draw_ridges(body: Rect2) -> void:
	# Одинокий дом рисует себя. Дом+дом — общий конёк на общем ребре. Три в ряд — тот же конёк длиннее.
	var col := _lit(TileType.WOOD_RIDGE)
	var w := maxf(3.5, minf(size.x, size.y) * 0.075)
	var mid := body.get_center()
	var inset := 4.0
	if not has_street_edge():
		var peak := Vector2(mid.x, body.position.y - size.y * 0.02)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(body.position.x + 2.0, body.position.y + inset + 4.0),
				peak,
				Vector2(body.end.x - 2.0, body.position.y + inset + 4.0),
			]),
			_lit(TileType.WOOD_DARK)
		)
		draw_line(Vector2(mid.x, peak.y), Vector2(mid.x, body.end.y - inset), col, w)
		return
	if edge_n == TileType.HOUSE:
		draw_line(Vector2(mid.x, 0.0), Vector2(mid.x, mid.y), col, w)
	if edge_s == TileType.HOUSE:
		draw_line(Vector2(mid.x, mid.y), Vector2(mid.x, size.y), col, w)
	if edge_w == TileType.HOUSE:
		draw_line(Vector2(0.0, mid.y), Vector2(mid.x, mid.y), col, w)
	if edge_e == TileType.HOUSE:
		draw_line(Vector2(mid.x, mid.y), Vector2(size.x, mid.y), col, w)
	# Шапка общего конька на затронутом ребре.
	if edge_n == TileType.HOUSE:
		draw_circle(Vector2(mid.x, 0.0), w * 0.65, col)
	if edge_s == TileType.HOUSE:
		draw_circle(Vector2(mid.x, size.y), w * 0.65, col)
	if edge_w == TileType.HOUSE:
		draw_circle(Vector2(0.0, mid.y), w * 0.65, col)
	if edge_e == TileType.HOUSE:
		draw_circle(Vector2(size.x, mid.y), w * 0.65, col)


func _draw_porches(body: Rect2) -> void:
	# house+road: маленький порожек у дома к рейке.
	var m := minf(size.x, size.y)
	var thick := m * 0.10
	var span := m * 0.34
	var col := _lit(TileType.PORCH)
	var edge := _lit(TileType.PORCH_EDGE)
	if edge_n == TileType.ROAD:
		var pr := Rect2(body.get_center().x - span * 0.5, 1.0, span, thick)
		draw_rect(pr, col)
		draw_rect(pr, edge, false, 1.4)
	if edge_s == TileType.ROAD:
		var pr2 := Rect2(body.get_center().x - span * 0.5, size.y - thick - 1.0, span, thick)
		draw_rect(pr2, col)
		draw_rect(pr2, edge, false, 1.4)
	if edge_w == TileType.ROAD:
		var pr3 := Rect2(1.0, body.get_center().y - span * 0.5, thick, span)
		draw_rect(pr3, col)
		draw_rect(pr3, edge, false, 1.4)
	if edge_e == TileType.ROAD:
		var pr4 := Rect2(size.x - thick - 1.0, body.get_center().y - span * 0.5, thick, span)
		draw_rect(pr4, col)
		draw_rect(pr4, edge, false, 1.4)


func _draw_yards(body: Rect2) -> void:
	# house+tree: куст-колышек у стены дома. Пруд/роща на воде/деревьях не мешают.
	var m := minf(size.x, size.y)
	var peg_r := m * 0.045
	var bush_r := m * 0.09
	if edge_n == TileType.TREE:
		_yard_at(Vector2(body.get_center().x, body.position.y + m * 0.02), peg_r, bush_r)
	if edge_s == TileType.TREE:
		_yard_at(Vector2(body.get_center().x, body.end.y - m * 0.02), peg_r, bush_r)
	if edge_w == TileType.TREE:
		_yard_at(Vector2(body.position.x + m * 0.02, body.get_center().y), peg_r, bush_r)
	if edge_e == TileType.TREE:
		_yard_at(Vector2(body.end.x - m * 0.02, body.get_center().y), peg_r, bush_r)


func _yard_at(p: Vector2, peg_r: float, bush_r: float) -> void:
	draw_rect(Rect2(p.x - peg_r * 0.55, p.y - peg_r * 0.2, peg_r * 1.1, peg_r * 1.6), _lit(TileType.YARD_PEG))
	draw_circle(p + Vector2(0.0, -bush_r * 0.35), bush_r, _lit(TileType.YARD_BUSH))


func _draw_road(r: Rect2) -> void:
	# Дорога — плоская рейка от края до края.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.20
	var body := Rect2(0.0, pad, r.size.x, r.size.y - pad * 2.0)
	var shaded := (
		edge_n == TileType.TREE
		or edge_e == TileType.TREE
		or edge_s == TileType.TREE
		or edge_w == TileType.TREE
	)
	var plank := TileType.PATH_SHADE if shaded else TileType.ROAD_COL
	var groove := TileType.PATH_GROOVE if shaded else TileType.ROAD_GROOVE
	draw_rect(Rect2(body.position + Vector2(0, 3), body.size), TileType.SHADOW)
	draw_rect(body, _lit(plank))
	var y1 := body.position.y + body.size.y * 0.32
	var y2 := body.position.y + body.size.y * 0.68
	draw_line(Vector2(0.0, y1), Vector2(r.size.x, y1), _lit(groove), 1.6)
	draw_line(Vector2(0.0, y2), Vector2(r.size.x, y2), _lit(groove), 1.6)
	_draw_puddles(body)


func _draw_puddles(body: Rect2) -> void:
	# road+water: одно синее пятно на рейке (не мост).
	var m := minf(size.x, size.y)
	var rad := m * 0.11
	if edge_n == TileType.WATER:
		_puddle_at(Vector2(body.get_center().x, body.position.y + rad * 0.9), rad)
	if edge_s == TileType.WATER:
		_puddle_at(Vector2(body.get_center().x, body.end.y - rad * 0.9), rad)
	if edge_w == TileType.WATER:
		_puddle_at(Vector2(body.position.x + rad * 1.1, body.get_center().y), rad)
	if edge_e == TileType.WATER:
		_puddle_at(Vector2(body.end.x - rad * 1.1, body.get_center().y), rad)


func _puddle_at(c: Vector2, rad: float) -> void:
	draw_set_transform(c, 0.0, Vector2(1.35, 0.62))
	draw_circle(Vector2.ZERO, rad, _lit(TileType.WATER_DEEP))
	draw_circle(Vector2.ZERO, rad * 0.72, _lit(TileType.WATER_PUDDLE))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tree(r: Rect2) -> void:
	# Дерево — колышек с кроной; выше дороги, ниже конька.
	# tree+tree: кроны почти сошлись — сдвиг/растяг к соседу; ряд длиннее.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center()
	var pull := Vector2.ZERO
	var stretch := 1.0
	if edge_n == TileType.TREE:
		pull.y -= m * 0.16
		stretch = maxf(stretch, 1.22)
	if edge_s == TileType.TREE:
		pull.y += m * 0.16
		stretch = maxf(stretch, 1.22)
	if edge_w == TileType.TREE:
		pull.x -= m * 0.16
		stretch = maxf(stretch, 1.22)
	if edge_e == TileType.TREE:
		pull.x += m * 0.16
		stretch = maxf(stretch, 1.22)
	var crown_c := c + pull + Vector2(0.0, -m * 0.10)
	draw_circle(c + Vector2(2, 6), m * 0.10, TileType.SHADOW)
	var trunk := Rect2(c.x - m * 0.07, c.y + m * 0.02, m * 0.14, m * 0.24)
	draw_rect(trunk, _lit(TileType.TREE_TRUNK))
	draw_set_transform(crown_c, 0.0, Vector2(stretch, stretch * 0.92))
	draw_circle(Vector2.ZERO, m * 0.24, _lit(TileType.TREE_CROWN))
	draw_set_transform(crown_c + Vector2(-m * 0.08, -m * 0.06), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, m * 0.09, _lit(TileType.TREE_CROWN_HI))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Мостик кроны к соседу — «почти сошлись».
	var bridge_r := m * 0.14
	if edge_n == TileType.TREE:
		draw_circle(Vector2(c.x, 0.0), bridge_r, _lit(TileType.TREE_CROWN))
	if edge_s == TileType.TREE:
		draw_circle(Vector2(c.x, size.y), bridge_r, _lit(TileType.TREE_CROWN))
	if edge_w == TileType.TREE:
		draw_circle(Vector2(0.0, c.y - m * 0.08), bridge_r, _lit(TileType.TREE_CROWN))
	if edge_e == TileType.TREE:
		draw_circle(Vector2(size.x, c.y - m * 0.08), bridge_r, _lit(TileType.TREE_CROWN))


func _draw_water(r: Rect2) -> void:
	# Вода — синяя лужа-фишка. water+water = одно пятно, вытянутое к соседу.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center() + Vector2(0.0, m * 0.04)
	var pull := Vector2.ZERO
	var sx := 1.28
	var sy := 0.70
	if edge_n == TileType.WATER:
		pull.y -= m * 0.18
		sy = maxf(sy, 1.15)
	if edge_s == TileType.WATER:
		pull.y += m * 0.18
		sy = maxf(sy, 1.15)
	if edge_w == TileType.WATER:
		pull.x -= m * 0.18
		sx = maxf(sx, 1.55)
	if edge_e == TileType.WATER:
		pull.x += m * 0.18
		sx = maxf(sx, 1.55)
	var pc := c + pull
	draw_set_transform(pc + Vector2(2, 3), 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, m * 0.28, TileType.SHADOW)
	draw_set_transform(pc, 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, m * 0.28, _lit(TileType.WATER_DEEP))
	draw_circle(Vector2.ZERO, m * 0.23, _lit(TileType.WATER_COL))
	draw_set_transform(pc + Vector2(-m * 0.10, -m * 0.07), 0.0, Vector2(1.05, 0.50))
	draw_circle(Vector2.ZERO, m * 0.07, _lit(TileType.WATER_GLOSS))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Смыкание пятна на общем ребре.
	var join_r := m * 0.20
	if edge_n == TileType.WATER:
		draw_set_transform(Vector2(c.x, 0.0), 0.0, Vector2(1.2, 0.7))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	if edge_s == TileType.WATER:
		draw_set_transform(Vector2(c.x, size.y), 0.0, Vector2(1.2, 0.7))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	if edge_w == TileType.WATER:
		draw_set_transform(Vector2(0.0, c.y), 0.0, Vector2(0.7, 1.1))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	if edge_e == TileType.WATER:
		draw_set_transform(Vector2(size.x, c.y), 0.0, Vector2(0.7, 1.1))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_reflections(c, m)
	_draw_reeds(c, m)


func _draw_reflections(c: Vector2, m: float) -> void:
	# house+water: тёмный силуэт крыши на воде, не зеркало.
	var col := _lit(TileType.REFLECTION)
	if edge_n == TileType.HOUSE:
		_roof_silhouette(Vector2(c.x, m * 0.18), m, col)
	if edge_s == TileType.HOUSE:
		_roof_silhouette(Vector2(c.x, size.y - m * 0.18), m, col)
	if edge_w == TileType.HOUSE:
		_roof_silhouette(Vector2(m * 0.22, c.y), m, col)
	if edge_e == TileType.HOUSE:
		_roof_silhouette(Vector2(size.x - m * 0.22, c.y), m, col)


func _roof_silhouette(p: Vector2, m: float, col: Color) -> void:
	var hw := m * 0.16
	var hh := m * 0.11
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(p.x - hw, p.y + hh * 0.35),
			Vector2(p.x, p.y - hh),
			Vector2(p.x + hw, p.y + hh * 0.35),
		]),
		col
	)
	draw_rect(Rect2(p.x - hw * 0.55, p.y + hh * 0.25, hw * 1.1, hh * 0.55), col)


func _draw_reeds(c: Vector2, m: float) -> void:
	# water+tree: два прутика у края лужи.
	if edge_n == TileType.TREE:
		_reeds_at(Vector2(c.x, m * 0.08), Vector2(0, -1), m)
	if edge_s == TileType.TREE:
		_reeds_at(Vector2(c.x, size.y - m * 0.08), Vector2(0, 1), m)
	if edge_w == TileType.TREE:
		_reeds_at(Vector2(m * 0.08, c.y), Vector2(-1, 0), m)
	if edge_e == TileType.TREE:
		_reeds_at(Vector2(size.x - m * 0.08, c.y), Vector2(1, 0), m)


func _reeds_at(base: Vector2, outward: Vector2, m: float) -> void:
	var col := _lit(TileType.REED)
	var perp := Vector2(-outward.y, outward.x)
	var len1 := m * 0.16
	var len2 := m * 0.13
	var a := base + perp * m * 0.04
	var b := base - perp * m * 0.05
	draw_line(a, a + outward * len1 + perp * m * 0.02, col, 2.0)
	draw_line(b, b + outward * len2 - perp * m * 0.015, col, 1.7)
