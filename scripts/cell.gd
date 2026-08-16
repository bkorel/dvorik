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
# Какие id открылись в этой вспышке (для усиления path/reeds).
var flash_views: Array = []

var home_pos: Vector2 = Vector2.ZERO
var motion_off: Vector2 = Vector2.ZERO:
	set(v):
		motion_off = v
		position = home_pos + motion_off

var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _last_tap_ms: int = 0
var _motion_tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	set_process(false)


func sync_home(pos: Vector2) -> void:
	home_pos = pos
	position = home_pos + motion_off


func reset_motion() -> void:
	if _motion_tw != null and _motion_tw.is_valid():
		_motion_tw.kill()
	_motion_tw = null
	scale = Vector2.ONE
	motion_off = Vector2.ZERO
	position = home_pos


func has_street_edge() -> bool:
	return tile == TileType.HOUSE and (
		edge_n == TileType.HOUSE
		or edge_e == TileType.HOUSE
		or edge_s == TileType.HOUSE
		or edge_w == TileType.HOUSE
	)


func poke() -> void:
	# Тот же тип — лёгкий тычок, вид не меняется. Без роста.
	_begin_motion()
	pivot_offset = size * 0.5
	_motion_tw.tween_property(self, "scale", Vector2(0.93, 0.93), 0.05)
	_motion_tw.tween_property(self, "scale", Vector2.ONE, 0.08)


func grow() -> void:
	# Постановка на пустую: рука сажает фишку на стол (короткий settle, не падение с неба).
	_begin_motion()
	pivot_offset = size * 0.5
	scale = Vector2(0.78, 0.78)
	motion_off = Vector2(0.0, -size.y * 0.055)
	_motion_tw.set_parallel(true)
	_motion_tw.tween_property(self, "scale", Vector2(1.04, 1.04), 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tw.tween_property(self, "motion_off", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tw.set_parallel(false)
	_motion_tw.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func nudge(dir: Vector2) -> void:
	# Сосед слегка сдвигается и щёлкает на место.
	_begin_motion()
	pivot_offset = size * 0.5
	var amp := minf(size.x, size.y) * 0.09
	var target := Vector2.ZERO
	if dir.length_squared() > 0.0001:
		target = dir.normalized() * amp
	_motion_tw.tween_property(self, "motion_off", target, 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tw.tween_property(self, "motion_off", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _begin_motion() -> void:
	if _motion_tw != null and _motion_tw.is_valid():
		_motion_tw.kill()
	scale = Vector2.ONE
	motion_off = Vector2.ZERO
	_motion_tw = create_tween()


func start_flash(views: Array = []) -> void:
	flash = 1.0
	for v in views:
		var s := str(v)
		if s not in flash_views:
			flash_views.append(s)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if flash <= 0.0:
		flash = 0.0
		flash_views.clear()
		set_process(false)
		queue_redraw()
		return
	flash = maxf(0.0, flash - delta / 0.55)
	queue_redraw()


func _flashing(view_id: String) -> bool:
	return flash > 0.0 and view_id in flash_views


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
	_draw_slot(r)
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


func _flash_a(mult: float = 0.65) -> float:
	return clampf(flash, 0.0, 1.0) * mult


func _sheen(a: float) -> Color:
	return Color(TileType.FLASH_LIT.r, TileType.FLASH_LIT.g, TileType.FLASH_LIT.b, a)


func _has_neighbor(t: int) -> bool:
	return edge_n == t or edge_e == t or edge_s == t or edge_w == t


func _draw_slot(r: Rect2) -> void:
	# Выемка с закруглёнными углами: свет сверху-слева, тень снизу-справа.
	var m := minf(r.size.x, r.size.y)
	var inset := m * 0.06
	var slot := r.grow(-inset)
	draw_rect(r, TileType.TABLE_RIDGE)
	_draw_round_rect(slot.grow(1.5), TileType.TABLE_EDGE, m * 0.12)
	_draw_round_rect(slot, TileType.TABLE_RECESS, m * 0.11)
	# Волокно внутри выемки.
	var rng := RandomNumberGenerator.new()
	rng.seed = grid_x * 17 + grid_y * 31 + 4
	var fiber := Color(TileType.TABLE_GRAIN.r, TileType.TABLE_GRAIN.g, TileType.TABLE_GRAIN.b, 0.45)
	for i in 5:
		var y0 := slot.position.y + rng.randf() * slot.size.y
		draw_line(
			Vector2(slot.position.x + 2.0, y0),
			Vector2(slot.end.x - 2.0, y0 + rng.randf_range(-1.0, 1.0)),
			fiber,
			1.1
		)
	# Блик по верхнему краю гребня, тень по нижнему.
	var hi := Color(1.0, 1.0, 0.85, 0.14)
	var sh := Color(0.05, 0.04, 0.02, 0.22)
	draw_line(Vector2(slot.position.x, slot.position.y), Vector2(slot.end.x, slot.position.y), hi, 2.0)
	draw_line(Vector2(slot.position.x, slot.end.y), Vector2(slot.end.x, slot.end.y), sh, 2.2)


func _draw_round_rect(rect: Rect2, col: Color, rad: float) -> void:
	var rr := mini(rad, mini(rect.size.x, rect.size.y) * 0.45)
	draw_circle(rect.position + Vector2(rr, rr), rr, col)
	draw_circle(Vector2(rect.end.x - rr, rect.position.y + rr), rr, col)
	draw_circle(Vector2(rect.position.x + rr, rect.end.y - rr), rr, col)
	draw_circle(rect.end - Vector2(rr, rr), rr, col)
	draw_rect(Rect2(rect.position.x + rr, rect.position.y, rect.size.x - rr * 2.0, rect.size.y), col)
	draw_rect(Rect2(rect.position.x, rect.position.y + rr, rect.size.x, rect.size.y - rr * 2.0), col)


func _draw_house(r: Rect2) -> void:
	# Один дом = одна клетка: брусок + треугольная горчичная крыша сверху.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.14
	var body := Rect2(Vector2(pad, pad + m * 0.06), Vector2(r.size.x - pad * 2.0, r.size.y - pad * 2.05))
	# Тень фишки вниз-вправо.
	_draw_round_rect(Rect2(body.position + Vector2(m * 0.04, m * 0.05), body.size), TileType.SHADOW, m * 0.06)
	_draw_round_rect(body, _lit(TileType.WOOD_PALE), m * 0.05)
	_draw_round_rect(body.grow(-m * 0.03), _lit(TileType.WOOD_LIGHT), m * 0.04)
	_draw_wood_grain(body, grid_x * 3 + grid_y)
	_draw_ridges(body)
	_draw_porches(body)
	_draw_yards(body)


func _draw_wood_grain(body: Rect2, grain_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = grain_seed + 99
	var g := Color(TileType.WOOD_MID.r, TileType.WOOD_MID.g, TileType.WOOD_MID.b, 0.35)
	for i in 4:
		var y := body.position.y + body.size.y * (0.2 + float(i) * 0.18)
		draw_line(Vector2(body.position.x + 2.0, y), Vector2(body.end.x - 2.0, y + rng.randf_range(-1.0, 1.0)), g, 1.0)


func _draw_ridges(body: Rect2) -> void:
	# Одинокий дом — горчичный треугольник. Дом+дом — общий конёк на ребре.
	var col := _lit(TileType.WOOD_RIDGE)
	var w := maxf(3.5, minf(size.x, size.y) * 0.075)
	var mid := body.get_center()
	var inset := 4.0
	if not has_street_edge():
		var peak := Vector2(mid.x, body.position.y - size.y * 0.02)
		var roof := PackedVector2Array([
			Vector2(body.position.x + 1.0, body.position.y + inset + 5.0),
			peak,
			Vector2(body.end.x - 1.0, body.position.y + inset + 5.0),
		])
		# Тень крыши.
		draw_colored_polygon(
			PackedVector2Array([
				roof[0] + Vector2(2, 3),
				roof[1] + Vector2(2, 3),
				roof[2] + Vector2(2, 3),
			]),
			TileType.SHADOW
		)
		draw_colored_polygon(roof, _lit(TileType.WOOD_ROOF))
		draw_line(roof[0], roof[1], _lit(TileType.WOOD_ROOF_EDGE), 1.6)
		draw_line(roof[1], roof[2], _lit(TileType.WOOD_ROOF_EDGE), 1.6)
		draw_line(Vector2(mid.x, peak.y), Vector2(mid.x, body.end.y - inset), col, w * 0.55)
		return
	if edge_n == TileType.HOUSE:
		draw_line(Vector2(mid.x, 0.0), Vector2(mid.x, mid.y), col, w)
	if edge_s == TileType.HOUSE:
		draw_line(Vector2(mid.x, mid.y), Vector2(mid.x, size.y), col, w)
	if edge_w == TileType.HOUSE:
		draw_line(Vector2(0.0, mid.y), Vector2(mid.x, mid.y), col, w)
	if edge_e == TileType.HOUSE:
		draw_line(Vector2(mid.x, mid.y), Vector2(size.x, mid.y), col, w)
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
	# house+tree: куст-колышек у стены дома.
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
	# Дорога — плоская тёмная рейка-планка в выемке.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.22
	var body := Rect2(m * 0.06, pad, r.size.x - m * 0.12, r.size.y - pad * 2.0)
	var shaded := _has_neighbor(TileType.TREE)
	var plank := TileType.PATH_SHADE if shaded else TileType.ROAD_COL
	var groove := TileType.PATH_GROOVE if shaded else TileType.ROAD_GROOVE
	_draw_round_rect(Rect2(body.position + Vector2(m * 0.03, m * 0.04), body.size), TileType.SHADOW, m * 0.04)
	_draw_round_rect(body, _lit(plank), m * 0.04)
	var y1 := body.position.y + body.size.y * 0.32
	var y2 := body.position.y + body.size.y * 0.68
	draw_line(Vector2(body.position.x + 2.0, y1), Vector2(body.end.x - 2.0, y1), _lit(groove), 1.6)
	draw_line(Vector2(body.position.x + 2.0, y2), Vector2(body.end.x - 2.0, y2), _lit(groove), 1.6)
	# Светлый торец планки сверху-слева.
	draw_line(
		Vector2(body.position.x + 2.0, body.position.y + 2.0),
		Vector2(body.end.x - 2.0, body.position.y + 2.0),
		Color(1.0, 0.95, 0.8, 0.18),
		1.5
	)
	_draw_puddles(body)
	if _flashing(DvorikSave.VIEW_PATH) and shaded:
		draw_rect(body, _sheen(_flash_a(0.72)))
		draw_line(Vector2(body.position.x, y1), Vector2(body.end.x, y1), _sheen(_flash_a(0.85)), 2.4)
		draw_line(Vector2(body.position.x, y2), Vector2(body.end.x, y2), _sheen(_flash_a(0.85)), 2.4)


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
	# Дерево — зелёный шар на колышке; лак и блик сверху-слева.
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
	draw_circle(c + Vector2(m * 0.04, m * 0.07), m * 0.11, TileType.SHADOW)
	var trunk := Rect2(c.x - m * 0.065, c.y + m * 0.00, m * 0.13, m * 0.26)
	_draw_round_rect(trunk, _lit(TileType.TREE_TRUNK), m * 0.03)
	draw_set_transform(crown_c, 0.0, Vector2(stretch, stretch * 0.92))
	draw_circle(Vector2.ZERO, m * 0.25, _lit(TileType.TREE_CROWN))
	draw_set_transform(crown_c + Vector2(-m * 0.09, -m * 0.08), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, m * 0.08, _lit(TileType.TREE_CROWN_HI))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bridge_r := m * 0.14
	if edge_n == TileType.TREE:
		draw_circle(Vector2(c.x, 0.0), bridge_r, _lit(TileType.TREE_CROWN))
	if edge_s == TileType.TREE:
		draw_circle(Vector2(c.x, size.y), bridge_r, _lit(TileType.TREE_CROWN))
	if edge_w == TileType.TREE:
		draw_circle(Vector2(0.0, c.y - m * 0.08), bridge_r, _lit(TileType.TREE_CROWN))
	if edge_e == TileType.TREE:
		draw_circle(Vector2(size.x, c.y - m * 0.08), bridge_r, _lit(TileType.TREE_CROWN))
	if _flashing(DvorikSave.VIEW_PATH) or _flashing(DvorikSave.VIEW_REEDS):
		draw_set_transform(crown_c, 0.0, Vector2(stretch, stretch * 0.92))
		draw_circle(Vector2.ZERO, m * 0.26, _sheen(_flash_a(0.70)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(trunk.position - Vector2(1, 1), trunk.size + Vector2(2, 2)), _sheen(_flash_a(0.55)))


func _draw_water(r: Rect2) -> void:
	# Вода — круглая фишка: деревянный ободок + глянцевая синяя лужа.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center() + Vector2(0.0, m * 0.02)
	var pull := Vector2.ZERO
	var sx := 1.0
	var sy := 1.0
	if edge_n == TileType.WATER:
		pull.y -= m * 0.18
		sy = maxf(sy, 1.15)
	if edge_s == TileType.WATER:
		pull.y += m * 0.18
		sy = maxf(sy, 1.15)
	if edge_w == TileType.WATER:
		pull.x -= m * 0.18
		sx = maxf(sx, 1.35)
	if edge_e == TileType.WATER:
		pull.x += m * 0.18
		sx = maxf(sx, 1.35)
	var pc := c + pull
	var rad := m * 0.30
	draw_set_transform(pc + Vector2(m * 0.04, m * 0.05), 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, rad, TileType.SHADOW)
	draw_set_transform(pc, 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, rad, _lit(TileType.WATER_RIM))
	draw_circle(Vector2.ZERO, rad * 0.78, _lit(TileType.WATER_DEEP))
	draw_circle(Vector2.ZERO, rad * 0.68, _lit(TileType.WATER_COL))
	draw_set_transform(pc + Vector2(-m * 0.10, -m * 0.09), 0.0, Vector2(1.05, 0.55))
	draw_circle(Vector2.ZERO, m * 0.07, _lit(TileType.WATER_GLOSS))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var join_r := m * 0.20
	if edge_n == TileType.WATER:
		draw_set_transform(Vector2(c.x, 0.0), 0.0, Vector2(1.15, 0.75))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	if edge_s == TileType.WATER:
		draw_set_transform(Vector2(c.x, size.y), 0.0, Vector2(1.15, 0.75))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	if edge_w == TileType.WATER:
		draw_set_transform(Vector2(0.0, c.y), 0.0, Vector2(0.75, 1.1))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	if edge_e == TileType.WATER:
		draw_set_transform(Vector2(size.x, c.y), 0.0, Vector2(0.75, 1.1))
		draw_circle(Vector2.ZERO, join_r, _lit(TileType.WATER_COL))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_reflections(c, m)
	_draw_reeds(c, m)
	if _flashing(DvorikSave.VIEW_REEDS):
		draw_set_transform(pc, 0.0, Vector2(sx, sy))
		draw_circle(Vector2.ZERO, rad * 1.05, _sheen(_flash_a(0.55)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	var tip_a := a + outward * len1 + perp * m * 0.02
	var tip_b := b + outward * len2 - perp * m * 0.015
	if _flashing(DvorikSave.VIEW_REEDS):
		var glow := _sheen(_flash_a(0.90))
		draw_line(a, tip_a, glow, 5.0)
		draw_line(b, tip_b, glow, 4.5)
	draw_line(a, tip_a, col, 2.0)
	draw_line(b, tip_b, col, 1.7)
