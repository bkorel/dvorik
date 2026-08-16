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
	# Постановка на пустую: рука сажает фишку на плиту (короткий settle, не падение с неба).
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
	# Лунка-выемка в каменной плите: тёмный пол, холодный кант.
	var m := minf(r.size.x, r.size.y)
	var inset := m * 0.05
	var slot := r.grow(-inset)
	draw_rect(r, TileType.TABLE_RIDGE)
	_draw_round_rect(slot.grow(1.8), TileType.TABLE_EDGE, m * 0.10)
	_draw_round_rect(slot, TileType.TABLE_RECESS, m * 0.09)
	# Холодная зернистость камня внутри лунки.
	var rng := RandomNumberGenerator.new()
	rng.seed = grid_x * 17 + grid_y * 31 + 4
	var grit := Color(TileType.TABLE_GRAIN.r, TileType.TABLE_GRAIN.g, TileType.TABLE_GRAIN.b, 0.40)
	for i in 6:
		var p := Vector2(
			slot.position.x + rng.randf() * slot.size.x,
			slot.position.y + rng.randf() * slot.size.y
		)
		draw_circle(p, rng.randf_range(0.6, 1.4), grit)
	# Светлый кант сверху-слева, тень снизу-справа.
	var hi := Color(0.55, 0.56, 0.58, 0.16)
	var sh := Color(0.02, 0.02, 0.03, 0.35)
	draw_line(Vector2(slot.position.x, slot.position.y), Vector2(slot.end.x, slot.position.y), hi, 1.8)
	draw_line(Vector2(slot.position.x, slot.position.y), Vector2(slot.position.x, slot.end.y), hi, 1.4)
	draw_line(Vector2(slot.position.x, slot.end.y), Vector2(slot.end.x, slot.end.y), sh, 2.2)
	draw_line(Vector2(slot.end.x, slot.position.y), Vector2(slot.end.x, slot.end.y), sh, 1.6)


func _draw_round_rect(rect: Rect2, col: Color, rad: float) -> void:
	var rr := mini(rad, mini(rect.size.x, rect.size.y) * 0.45)
	draw_circle(rect.position + Vector2(rr, rr), rr, col)
	draw_circle(Vector2(rect.end.x - rr, rect.position.y + rr), rr, col)
	draw_circle(Vector2(rect.position.x + rr, rect.end.y - rr), rr, col)
	draw_circle(rect.end - Vector2(rr, rr), rr, col)
	draw_rect(Rect2(rect.position.x + rr, rect.position.y, rect.size.x - rr * 2.0, rect.size.y), col)
	draw_rect(Rect2(rect.position.x, rect.position.y + rr, rect.size.x, rect.size.y - rr * 2.0), col)


func _house_body_rect(r: Rect2) -> Rect2:
	# Улица: стены к общему ребру без щели пола между домами.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.16
	var x0 := pad
	var y0 := pad + m * 0.10
	var x1 := r.size.x - pad
	var y1 := r.size.y - pad * 0.85
	if edge_w == TileType.HOUSE:
		x0 = 0.0
	if edge_e == TileType.HOUSE:
		x1 = r.size.x
	if edge_n == TileType.HOUSE:
		y0 = m * 0.06
	if edge_s == TileType.HOUSE:
		y1 = r.size.y
	return Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))


func _draw_house(r: Rect2) -> void:
	# Низкий каменный объём + тёмная плита крыши (¾ сверху). Не изба и не квадрат с палкой.
	var m := minf(r.size.x, r.size.y)
	var body := _house_body_rect(r)
	var face_h := m * 0.14
	var roof_h := m * 0.22
	# Тень вниз-вправо.
	_draw_round_rect(Rect2(body.position + Vector2(m * 0.04, m * 0.05), body.size), TileType.SHADOW, m * 0.04)
	# Передняя грань чуть светлее — объём читается с лёгкого ¾.
	var face := Rect2(
		Vector2(body.position.x, body.end.y - face_h),
		Vector2(body.size.x, face_h)
	)
	var wall := Rect2(body.position, Vector2(body.size.x, body.size.y - face_h))
	_draw_round_rect(wall, _lit(TileType.STONE_MID), m * 0.03)
	draw_rect(face, _lit(TileType.STONE_FACE))
	draw_line(Vector2(face.position.x, face.position.y), Vector2(face.end.x, face.position.y), _lit(TileType.STONE_DARK), 1.4)
	_draw_stone_speck(wall, grid_x * 3 + grid_y)
	_draw_roof_slab(body, roof_h, m)
	_draw_porches(body)
	_draw_yards(body)


func _draw_stone_speck(body: Rect2, grain_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = grain_seed + 99
	var g := Color(TileType.STONE_DARK.r, TileType.STONE_DARK.g, TileType.STONE_DARK.b, 0.35)
	for i in 5:
		var p := Vector2(
			body.position.x + rng.randf() * body.size.x,
			body.position.y + rng.randf() * body.size.y * 0.85
		)
		draw_circle(p, rng.randf_range(0.5, 1.2), g)


func _draw_roof_slab(body: Rect2, roof_h: float, m: float) -> void:
	# Плита крыши: слегка смещена вверх-влево, чтобы читалась как верх. На улице — одна общая.
	var skew := m * 0.05
	var top_y := body.position.y - roof_h * 0.55
	var x0 := body.position.x
	var x1 := body.end.x
	if edge_w == TileType.HOUSE:
		x0 = 0.0
		skew = 0.0
	if edge_e == TileType.HOUSE:
		x1 = size.x
	if edge_n == TileType.HOUSE:
		top_y = -roof_h * 0.15
	# Тень плиты.
	var shadow_poly := PackedVector2Array([
		Vector2(x0 + 2.0, top_y + roof_h + 3.0),
		Vector2(x0 + skew + 2.0, top_y + 3.0),
		Vector2(x1 + skew + 2.0, top_y + 3.0),
		Vector2(x1 + 2.0, top_y + roof_h + 3.0),
	])
	draw_colored_polygon(shadow_poly, TileType.SHADOW)
	var roof := PackedVector2Array([
		Vector2(x0, top_y + roof_h),
		Vector2(x0 + skew, top_y),
		Vector2(x1 + skew, top_y),
		Vector2(x1, top_y + roof_h),
	])
	draw_colored_polygon(roof, _lit(TileType.ROOF_SLAB))
	# Передний кант плиты.
	draw_line(roof[0], roof[3], _lit(TileType.ROOF_EDGE), 2.2)
	draw_line(roof[1], roof[2], _lit(TileType.ROOF_SHEEN), 1.6)
	# На стыке домов — непрерывный конёк без щели пола.
	if edge_n == TileType.HOUSE:
		draw_rect(Rect2(x0, 0.0, x1 - x0, maxf(2.0, roof_h * 0.35)), _lit(TileType.ROOF_SLAB))
	if edge_s == TileType.HOUSE:
		draw_rect(Rect2(x0, size.y - roof_h * 0.25, x1 - x0, roof_h * 0.25 + 1.0), _lit(TileType.ROOF_SLAB))
	if edge_w == TileType.HOUSE:
		draw_rect(Rect2(0.0, top_y, maxf(2.0, m * 0.08), roof_h + _face_bridge()), _lit(TileType.ROOF_SLAB))
	if edge_e == TileType.HOUSE:
		draw_rect(Rect2(size.x - m * 0.08, top_y, m * 0.08 + 1.0, roof_h + _face_bridge()), _lit(TileType.ROOF_SLAB))


func _face_bridge() -> float:
	return minf(size.x, size.y) * 0.08


func _draw_porches(body: Rect2) -> void:
	# house+road: каменный порожек к шву.
	var m := minf(size.x, size.y)
	var thick := m * 0.09
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
	# house+tree: тёмный куст у стены.
	var m := minf(size.x, size.y)
	var peg_r := m * 0.04
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
	# Шов / ряд плит от края до края лунки.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.18
	var body := Rect2(0.0, pad, r.size.x, r.size.y - pad * 2.0)
	var shaded := _has_neighbor(TileType.TREE)
	var plank := TileType.PATH_SHADE if shaded else TileType.ROAD_COL
	var groove := TileType.PATH_GROOVE if shaded else TileType.ROAD_GROOVE
	_draw_round_rect(Rect2(body.position + Vector2(m * 0.02, m * 0.03), body.size), TileType.SHADOW, m * 0.03)
	_draw_round_rect(body, _lit(plank), m * 0.03)
	# Швы плит — короткие поперечные.
	var seam := _lit(TileType.ROAD_SEAM)
	var n_slabs := 3
	for i in range(1, n_slabs):
		var x := body.position.x + body.size.x * (float(i) / float(n_slabs))
		draw_line(Vector2(x, body.position.y + 2.0), Vector2(x, body.end.y - 2.0), seam, 1.4)
	var y_mid := body.get_center().y
	draw_line(Vector2(body.position.x, y_mid), Vector2(body.end.x, y_mid), _lit(groove), 2.0)
	# Холодный блик по верхнему краю шва.
	draw_line(
		Vector2(body.position.x + 1.0, body.position.y + 2.0),
		Vector2(body.end.x - 1.0, body.position.y + 2.0),
		Color(0.55, 0.56, 0.58, 0.14),
		1.4
	)
	_draw_puddles(body)
	if _flashing(DvorikSave.VIEW_PATH) and shaded:
		draw_rect(body, _sheen(_flash_a(0.72)))
		draw_line(Vector2(body.position.x, y_mid), Vector2(body.end.x, y_mid), _sheen(_flash_a(0.85)), 2.4)


func _draw_puddles(body: Rect2) -> void:
	# road+water: тёмное масляное пятно на шве.
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
	# Живой тёмный ясень/сосна. Кроны рощи сплетены.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center()
	var pull := Vector2.ZERO
	var stretch := 1.0
	if edge_n == TileType.TREE:
		pull.y -= m * 0.18
		stretch = maxf(stretch, 1.28)
	if edge_s == TileType.TREE:
		pull.y += m * 0.18
		stretch = maxf(stretch, 1.28)
	if edge_w == TileType.TREE:
		pull.x -= m * 0.18
		stretch = maxf(stretch, 1.28)
	if edge_e == TileType.TREE:
		pull.x += m * 0.18
		stretch = maxf(stretch, 1.28)
	var crown_c := c + pull + Vector2(0.0, -m * 0.12)
	draw_circle(c + Vector2(m * 0.04, m * 0.08), m * 0.10, TileType.SHADOW)
	var trunk := Rect2(c.x - m * 0.05, c.y - m * 0.02, m * 0.10, m * 0.28)
	_draw_round_rect(trunk, _lit(TileType.TREE_TRUNK), m * 0.02)
	# Многослойная крона — живая, не скелет.
	draw_set_transform(crown_c, 0.0, Vector2(stretch, stretch * 0.90))
	draw_circle(Vector2.ZERO, m * 0.26, _lit(TileType.TREE_CROWN_LO))
	draw_circle(Vector2(-m * 0.08, -m * 0.04), m * 0.18, _lit(TileType.TREE_CROWN))
	draw_circle(Vector2(m * 0.09, -m * 0.02), m * 0.16, _lit(TileType.TREE_CROWN))
	draw_circle(Vector2(0.0, -m * 0.10), m * 0.14, _lit(TileType.TREE_CROWN_HI))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bridge_r := m * 0.16
	if edge_n == TileType.TREE:
		_grove_bridge(Vector2(c.x, 0.0), bridge_r)
	if edge_s == TileType.TREE:
		_grove_bridge(Vector2(c.x, size.y), bridge_r)
	if edge_w == TileType.TREE:
		_grove_bridge(Vector2(0.0, c.y - m * 0.10), bridge_r)
	if edge_e == TileType.TREE:
		_grove_bridge(Vector2(size.x, c.y - m * 0.10), bridge_r)
	if _flashing(DvorikSave.VIEW_PATH) or _flashing(DvorikSave.VIEW_REEDS):
		draw_set_transform(crown_c, 0.0, Vector2(stretch, stretch * 0.90))
		draw_circle(Vector2.ZERO, m * 0.27, _sheen(_flash_a(0.70)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(trunk.position - Vector2(1, 1), trunk.size + Vector2(2, 2)), _sheen(_flash_a(0.55)))


func _grove_bridge(p: Vector2, rad: float) -> void:
	draw_circle(p, rad, _lit(TileType.TREE_CROWN))
	draw_circle(p + Vector2(-rad * 0.35, -rad * 0.15), rad * 0.55, _lit(TileType.TREE_CROWN_HI))
	draw_circle(p + Vector2(rad * 0.30, rad * 0.10), rad * 0.50, _lit(TileType.TREE_CROWN_LO))


func _draw_water(r: Rect2) -> void:
	# Круглая чаша: каменный обод + чёрное масло с тусклым бликом. Не синяя монета.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center() + Vector2(0.0, m * 0.02)
	var pull := Vector2.ZERO
	var sx := 1.0
	var sy := 1.0
	if edge_n == TileType.WATER:
		pull.y -= m * 0.22
		sy = maxf(sy, 1.22)
	if edge_s == TileType.WATER:
		pull.y += m * 0.22
		sy = maxf(sy, 1.22)
	if edge_w == TileType.WATER:
		pull.x -= m * 0.22
		sx = maxf(sx, 1.45)
	if edge_e == TileType.WATER:
		pull.x += m * 0.22
		sx = maxf(sx, 1.45)
	var pc := c + pull
	var rad := m * 0.31
	draw_set_transform(pc + Vector2(m * 0.04, m * 0.05), 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, rad, TileType.SHADOW)
	draw_set_transform(pc, 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, rad, _lit(TileType.WATER_RIM))
	draw_circle(Vector2.ZERO, rad * 0.78, _lit(TileType.WATER_DEEP))
	draw_circle(Vector2.ZERO, rad * 0.68, _lit(TileType.WATER_COL))
	# Тусклый блик масла — один.
	draw_set_transform(pc + Vector2(-m * 0.09, -m * 0.10), 0.0, Vector2(1.15, 0.45))
	draw_circle(Vector2.ZERO, m * 0.06, _lit(TileType.WATER_GLOSS))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Пруд: одна тёмная лужа, не две чаши.
	var join_r := m * 0.22
	var oil := _lit(TileType.WATER_COL)
	if edge_n == TileType.WATER:
		draw_set_transform(Vector2(c.x, 0.0), 0.0, Vector2(1.25, 0.85))
		draw_circle(Vector2.ZERO, join_r, oil)
		draw_circle(Vector2.ZERO, join_r * 0.72, _lit(TileType.WATER_DEEP))
	if edge_s == TileType.WATER:
		draw_set_transform(Vector2(c.x, size.y), 0.0, Vector2(1.25, 0.85))
		draw_circle(Vector2.ZERO, join_r, oil)
		draw_circle(Vector2.ZERO, join_r * 0.72, _lit(TileType.WATER_DEEP))
	if edge_w == TileType.WATER:
		draw_set_transform(Vector2(0.0, c.y), 0.0, Vector2(0.85, 1.2))
		draw_circle(Vector2.ZERO, join_r, oil)
		draw_circle(Vector2.ZERO, join_r * 0.72, _lit(TileType.WATER_DEEP))
	if edge_e == TileType.WATER:
		draw_set_transform(Vector2(size.x, c.y), 0.0, Vector2(0.85, 1.2))
		draw_circle(Vector2.ZERO, join_r, oil)
		draw_circle(Vector2.ZERO, join_r * 0.72, _lit(TileType.WATER_DEEP))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_reflections(c, m)
	_draw_reeds(c, m)
	if _flashing(DvorikSave.VIEW_REEDS):
		draw_set_transform(pc, 0.0, Vector2(sx, sy))
		draw_circle(Vector2.ZERO, rad * 1.05, _sheen(_flash_a(0.55)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_reflections(c: Vector2, m: float) -> void:
	# house+water: силуэт плиты крыши на масле.
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
	var hw := m * 0.18
	var hh := m * 0.08
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(p.x - hw, p.y + hh * 0.4),
			Vector2(p.x - hw * 0.85, p.y - hh),
			Vector2(p.x + hw * 0.85, p.y - hh),
			Vector2(p.x + hw, p.y + hh * 0.4),
		]),
		col
	)


func _draw_reeds(c: Vector2, m: float) -> void:
	# water+tree: два прутика у края чаши.
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
