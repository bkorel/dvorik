class_name Cell
extends Control

## Клетка. Тип не «превращается»: каждая сторона смотрит на ортогонального соседа.
## Рисуется изометрическим объёмом; ввод ловит Board.

signal tapped(cell: Cell)

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
var flash_views: Array = []

# Геометрия ромба в локальных координатах (центр верхней грани).
var iso_c: Vector2 = Vector2.ZERO
var iso_hw: float = 20.0
var iso_hh: float = 10.0
var iso_th: float = 8.0

# Пруд: одна кувшинка / одна утка на всё поле — флаги с Board.
var show_lily: bool = false
var show_duck: bool = false

var home_pos: Vector2 = Vector2.ZERO
var motion_off: Vector2 = Vector2.ZERO:
	set(v):
		motion_off = v
		position = home_pos + motion_off

var _motion_tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_begin_motion()
	pivot_offset = size * 0.5
	_motion_tw.tween_property(self, "scale", Vector2(0.93, 0.93), 0.05)
	_motion_tw.tween_property(self, "scale", Vector2.ONE, 0.08)


func grow() -> void:
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


func _draw() -> void:
	if iso_hw <= 0.0 or iso_hh <= 0.0:
		return
	# Землю рисует Board ниже всех фишек — иначе соседняя трава
	# перекрывает стены дома и стыки дорог (на телефоне: «скелет» и штампы).
	match tile:
		TileType.HOUSE:
			_draw_house()
		TileType.ROAD:
			_draw_road()
		TileType.TREE:
			_draw_tree()
		TileType.WATER:
			_draw_water()


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


func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	# На мобильном GL Compatibility надёжнее треугольники, не сырой quad.
	if pts.size() == 3:
		draw_colored_polygon(pts, col)
		return
	if pts.size() == 4:
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2]]), col)
		draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[3]]), col)
		return
	draw_colored_polygon(pts, col)


func _draw_earth() -> void:
	# Земля рисуется с Board (см. Board._draw_earth_cell).
	pass


func _draw_house() -> void:
	# Непрозрачный объём как фишка палитры: стены, дверь, 2 окна, крыша, труба.
	var c := iso_c
	var hw := iso_hw * 0.74
	var hh := iso_hh * 0.74
	var wall_h := maxf(iso_th * 2.8, iso_hw * 0.85)
	var base := c + Vector2(0.0, iso_th * 0.02)
	var tn := base + Vector2(0.0, -hh)
	var te := base + Vector2(hw, 0.0)
	var ts := base + Vector2(0.0, hh)
	var tw := base + Vector2(-hw, 0.0)
	var bn := tn + Vector2(0.0, wall_h)
	var be := te + Vector2(0.0, wall_h)
	var bs := ts + Vector2(0.0, wall_h)
	var bw := tw + Vector2(0.0, wall_h)
	_poly(Iso.diamond(base + Vector2(4.0, wall_h + 3.0), hw * 1.08, hh * 1.08), TileType.SHADOW)
	# Крышка стен (под крышей) — закрывает «дырку» сверху.
	_poly(Iso.diamond(base, hw * 0.98, hh * 0.98), _lit(TileType.WALL_DARK))
	# Все четыре грани — непрозрачные.
	_poly(PackedVector2Array([tn, tw, bw, bn]), _lit(TileType.WALL_DARK))
	_poly(PackedVector2Array([tn, te, be, bn]), _lit(TileType.WALL_SIDE))
	_poly(PackedVector2Array([tw, ts, bs, bw]), _lit(TileType.WALL_SIDE))
	_poly(PackedVector2Array([te, ts, bs, be]), _lit(TileType.WALL_FRONT))
	# Дверь на SE.
	var d0 := ts.lerp(te, 0.16).lerp(bs.lerp(be, 0.16), 0.08)
	var d1 := ts.lerp(te, 0.55).lerp(bs.lerp(be, 0.55), 0.08)
	var d2 := ts.lerp(te, 0.55).lerp(bs.lerp(be, 0.55), 0.94)
	var d3 := ts.lerp(te, 0.16).lerp(bs.lerp(be, 0.16), 0.94)
	_poly(PackedVector2Array([d0, d1, d2, d3]), _lit(TileType.DOOR))
	draw_circle(d1.lerp(d2, 0.40) + (d0 - d1) * 0.15, 2.4, _lit(TileType.DOOR_EDGE))
	# Два окна.
	_window_on_face(tw, ts, bw, bs, 0.40, 0.28, hw * 0.24)
	_window_on_face(te, ts, be, bs, 0.45, 0.26, hw * 0.22)
	var ridge_h := wall_h * 0.62
	var peak := tn + Vector2(0.0, -ridge_h)
	if has_street_edge():
		_draw_street_roofs(base, hw, hh, wall_h, peak)
	else:
		_poly(PackedVector2Array([peak, tn, te]), _lit(TileType.ROOF_LIT))
		_poly(PackedVector2Array([peak, tn, tw]), _lit(TileType.ROOF_SHADE))
		draw_line(peak, tn, _lit(TileType.ROOF_RIDGE), 2.4)
		var ch := peak + Vector2(hw * 0.30, ridge_h * 0.20)
		draw_rect(Rect2(ch.x - 3.0, ch.y - 12.0, 6.0, 14.0), _lit(TileType.CHIMNEY))
		draw_rect(Rect2(ch.x - 4.0, ch.y - 14.0, 8.0, 3.4), _lit(TileType.CHIMNEY_TOP))
	_draw_porches(base, hw, hh)
	_draw_yards(base, hw, hh)


func _window_on_face(top_a: Vector2, top_b: Vector2, bot_a: Vector2, bot_b: Vector2, across: float, up: float, s: float) -> void:
	var top := top_a.lerp(top_b, across)
	var bot := bot_a.lerp(bot_b, across)
	var mid := top.lerp(bot, up)
	var along := (top_b - top_a)
	if along.length_squared() < 0.01:
		return
	var tangent := along.normalized() * s
	var down_v := bot - top
	if down_v.length_squared() < 0.01:
		return
	var down := down_v.normalized() * s * 0.9
	var p0 := mid - tangent * 0.55 - down * 0.1
	var p1 := mid + tangent * 0.55 - down * 0.1
	var p2 := mid + tangent * 0.55 + down * 0.9
	var p3 := mid - tangent * 0.55 + down * 0.9
	_poly(PackedVector2Array([p0, p1, p2, p3]), _lit(TileType.WINDOW_FRAME))
	var ctr := (p0 + p1 + p2 + p3) * 0.25
	_poly(PackedVector2Array([
		p0.lerp(ctr, 0.30),
		p1.lerp(ctr, 0.30),
		p2.lerp(ctr, 0.30),
		p3.lerp(ctr, 0.30),
	]), _lit(TileType.WINDOW))
	draw_line(p0.lerp(ctr, 0.30).lerp(p1.lerp(ctr, 0.30), 0.5), p3.lerp(ctr, 0.30).lerp(p2.lerp(ctr, 0.30), 0.5), _lit(TileType.WINDOW_FRAME), 1.1)
	draw_line(p0.lerp(ctr, 0.30).lerp(p3.lerp(ctr, 0.30), 0.5), p1.lerp(ctr, 0.30).lerp(p2.lerp(ctr, 0.30), 0.5), _lit(TileType.WINDOW_FRAME), 1.1)


func _window_at(p: Vector2, s: float) -> void:
	# Совместимость; основное окно — _window_on_face.
	var r := Rect2(p.x - s, p.y - s * 0.7, s * 2.0, s * 1.4)
	draw_rect(r.grow(1.2), _lit(TileType.WINDOW_FRAME))
	draw_rect(r, _lit(TileType.WINDOW))


func _draw_street_roofs(base: Vector2, hw: float, hh: float, wall_h: float, _peak: Vector2) -> void:
	# Два дома рядом: два объёма крыш. На общем ребре — стык коньков, не одна планка.
	var ridge_h := wall_h * 0.48
	var tn := base + Vector2(0.0, -hh)
	var tl := base + Vector2(-hw, 0.0)
	var tr := base + Vector2(hw, 0.0)
	var peak_a := tn + Vector2(-hw * 0.28, -ridge_h)
	var peak_b := tn + Vector2(hw * 0.28, -ridge_h)
	if edge_n == TileType.HOUSE or edge_w == TileType.HOUSE:
		peak_a = tn + Vector2(-hw * 0.12, -ridge_h * 0.9)
	if edge_e == TileType.HOUSE or edge_s == TileType.HOUSE:
		peak_b = tn + Vector2(hw * 0.12, -ridge_h * 0.9)
	_poly(PackedVector2Array([peak_a, tn, tl]), _lit(TileType.ROOF_SHADE))
	_poly(PackedVector2Array([peak_a, tn, base]), _lit(TileType.ROOF_LIT))
	_poly(PackedVector2Array([peak_b, tn, tr]), _lit(TileType.ROOF_LIT))
	_poly(PackedVector2Array([peak_b, tn, base]), _lit(TileType.ROOF_SHADE))
	draw_line(peak_a, tn, _lit(TileType.ROOF_RIDGE), 1.8)
	draw_line(peak_b, tn, _lit(TileType.ROOF_RIDGE), 1.8)
	if edge_n == TileType.HOUSE:
		draw_line(peak_a, peak_a + Vector2(iso_hw * 0.35, -iso_hh * 0.2), _lit(TileType.ROOF_RIDGE), 2.2)
	if edge_e == TileType.HOUSE:
		draw_line(peak_b, peak_b + Vector2(iso_hw * 0.35, iso_hh * 0.2), _lit(TileType.ROOF_RIDGE), 2.2)
	if edge_s == TileType.HOUSE:
		draw_line(peak_b, peak_b + Vector2(-iso_hw * 0.35, iso_hh * 0.2), _lit(TileType.ROOF_RIDGE), 2.2)
	if edge_w == TileType.HOUSE:
		draw_line(peak_a, peak_a + Vector2(-iso_hw * 0.35, -iso_hh * 0.2), _lit(TileType.ROOF_RIDGE), 2.2)
	var ch := peak_b + Vector2(4.0, 4.0)
	draw_rect(Rect2(ch.x - 2.2, ch.y - 9.0, 4.5, 11.0), _lit(TileType.CHIMNEY))
	draw_rect(Rect2(ch.x - 3.2, ch.y - 11.0, 6.5, 2.8), _lit(TileType.CHIMNEY_TOP))


func _draw_porches(base: Vector2, hw: float, hh: float) -> void:
	var col := _lit(TileType.PORCH)
	var edge := _lit(TileType.PORCH_EDGE)
	var thick := Vector2(hw * 0.22, hh * 0.22)
	if edge_n == TileType.ROAD:
		var m := Iso.edge_mid(base, hw, hh, "n")
		_poly(Iso.diamond(m, thick.x, thick.y), col)
		draw_polyline(Iso.diamond(m, thick.x, thick.y), edge, 1.2, true)
	if edge_e == TileType.ROAD:
		var m2 := Iso.edge_mid(base, hw, hh, "e")
		_poly(Iso.diamond(m2, thick.x, thick.y), col)
		draw_polyline(Iso.diamond(m2, thick.x, thick.y), edge, 1.2, true)
	if edge_s == TileType.ROAD:
		var m3 := Iso.edge_mid(base, hw, hh, "s")
		_poly(Iso.diamond(m3, thick.x, thick.y), col)
		draw_polyline(Iso.diamond(m3, thick.x, thick.y), edge, 1.2, true)
	if edge_w == TileType.ROAD:
		var m4 := Iso.edge_mid(base, hw, hh, "w")
		_poly(Iso.diamond(m4, thick.x, thick.y), col)
		draw_polyline(Iso.diamond(m4, thick.x, thick.y), edge, 1.2, true)


func _draw_yards(base: Vector2, hw: float, hh: float) -> void:
	var peg_r := iso_hw * 0.04
	var bush_r := iso_hw * 0.09
	if edge_n == TileType.TREE:
		_yard_at(Iso.edge_mid(base, hw, hh, "n"), peg_r, bush_r)
	if edge_e == TileType.TREE:
		_yard_at(Iso.edge_mid(base, hw, hh, "e"), peg_r, bush_r)
	if edge_s == TileType.TREE:
		_yard_at(Iso.edge_mid(base, hw, hh, "s"), peg_r, bush_r)
	if edge_w == TileType.TREE:
		_yard_at(Iso.edge_mid(base, hw, hh, "w"), peg_r, bush_r)


func _yard_at(p: Vector2, peg_r: float, bush_r: float) -> void:
	draw_rect(Rect2(p.x - peg_r * 0.55, p.y - peg_r * 0.2, peg_r * 1.1, peg_r * 1.6), _lit(TileType.YARD_PEG))
	draw_circle(p + Vector2(0.0, -bush_r * 0.35), bush_r, _lit(TileType.YARD_BUSH))


func _draw_road() -> void:
	# Нештамп: сплошная поверхность + рукава к соседям. Бока только на открытых рёбрах.
	var c := iso_c + Vector2(0.0, -iso_th * 0.10)
	var hw := iso_hw * 0.90
	var hh := iso_hh * 0.90
	var th := iso_th * 0.45
	var shaded := _has_neighbor(TileType.TREE)
	var col := _lit(TileType.PATH_SHADE if shaded else TileType.ROAD_COL)
	var lit := _lit(TileType.ROAD_LIT if not shaded else TileType.PATH_SHADE)
	var groove := _lit(TileType.PATH_GROOVE if shaded else TileType.ROAD_GROOVE)
	var depth_col := col.darkened(0.16)
	var join_n := edge_n == TileType.ROAD
	var join_e := edge_e == TileType.ROAD
	var join_s := edge_s == TileType.ROAD
	var join_w := edge_w == TileType.ROAD
	# Чуть раздуваем к соседям-дорогам — шов пропадает.
	var sx := 1.0
	var sy := 1.0
	if join_n or join_e:
		sx = maxf(sx, 1.08)
		sy = maxf(sy, 1.08)
	if join_s or join_w:
		sx = maxf(sx, 1.08)
		sy = maxf(sy, 1.08)
	var top := Iso.diamond(c, hw * sx, hh * sy)
	var bot := Iso.diamond(c + Vector2(0.0, th), hw * sx, hh * sy)
	# Бока только там, где нет дороги-соседа (иначе «штампы»).
	if not join_w and not join_s:
		_poly(PackedVector2Array([top[3], top[2], bot[2], bot[3]]), _lit(TileType.ROAD_SHADE))
	elif not join_s:
		# Частичный бок — рисуем тонкую кромку у переднего ребра.
		draw_line(top[2], bot[2], _lit(TileType.ROAD_SHADE), 2.0)
	if not join_e and not join_s:
		_poly(PackedVector2Array([top[2], top[1], bot[1], bot[2]]), groove)
	_poly(top, col)
	# Мосты одного цвета через общие рёбра.
	if join_n:
		_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "n"), hw * 0.50, hh * 0.50), col)
	if join_e:
		_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "e"), hw * 0.50, hh * 0.50), col)
	if join_s:
		_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "s"), hw * 0.50, hh * 0.50), col)
	if join_w:
		_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "w"), hw * 0.50, hh * 0.50), col)
	var links: Array[String] = []
	if join_n:
		links.append("n")
	if join_e:
		links.append("e")
	if join_s:
		links.append("s")
	if join_w:
		links.append("w")
	if links.is_empty():
		# Одинокая: полоса уходит в глубину.
		_road_strip(c + Vector2(-hw * 0.22, hh * 0.30), c + Vector2(hw * 0.45, -hh * 0.35), hw * 0.20, depth_col, lit, groove)
	else:
		# Узел + рукава: N/W уже и темнее (вглубь), E/S шире.
		_poly(Iso.diamond(c, hw * 0.18, hh * 0.18), lit)
		for e in links:
			var into_depth := e == "n" or e == "w"
			_road_strip(
				c,
				Iso.edge_mid(c, hw, hh, e),
				hw * (0.17 if into_depth else 0.28),
				depth_col if into_depth else lit,
				lit,
				groove
			)
	_draw_puddles(c, hw, hh)
	if _flashing(DvorikSave.VIEW_PATH) and shaded:
		_poly(Iso.diamond(c, hw * 0.40, hh * 0.40), _sheen(_flash_a(0.55)))


func _road_strip(a: Vector2, b: Vector2, half_w: float, col: Color, lit: Color, groove: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized() * half_w
	# Чуть сплющить по Y, чтобы полоса лежала на ромбе.
	n = Vector2(n.x, n.y * 0.72)
	var pts := PackedVector2Array([a + n, b + n, b - n, a - n])
	_poly(pts, col)
	# Светлая кромка «в глубину».
	draw_line(a + n * 0.35, b + n * 0.35, lit, 1.4)
	draw_line(a, b, groove, 1.1)


func _draw_puddles(c: Vector2, hw: float, hh: float) -> void:
	var rad := iso_hw * 0.10
	if edge_n == TileType.WATER:
		_puddle_at(Iso.edge_mid(c, hw, hh, "n"), rad)
	if edge_e == TileType.WATER:
		_puddle_at(Iso.edge_mid(c, hw, hh, "e"), rad)
	if edge_s == TileType.WATER:
		_puddle_at(Iso.edge_mid(c, hw, hh, "s"), rad)
	if edge_w == TileType.WATER:
		_puddle_at(Iso.edge_mid(c, hw, hh, "w"), rad)


func _puddle_at(p: Vector2, rad: float) -> void:
	draw_set_transform(p, 0.0, Vector2(1.35, 0.62))
	draw_circle(Vector2.ZERO, rad, _lit(TileType.WATER_DEEP))
	draw_circle(Vector2.ZERO, rad * 0.72, _lit(TileType.WATER_PUDDLE))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tree() -> void:
	var c := iso_c + Vector2(0.0, -iso_th * 0.2)
	var m := iso_hw
	var pull := Vector2.ZERO
	var stretch := 1.0
	var grove := _has_neighbor(TileType.TREE)
	if edge_n == TileType.TREE:
		pull += Vector2(m * 0.18, -m * 0.10)
		stretch = maxf(stretch, 1.18)
	if edge_e == TileType.TREE:
		pull += Vector2(m * 0.18, m * 0.10)
		stretch = maxf(stretch, 1.18)
	if edge_s == TileType.TREE:
		pull += Vector2(-m * 0.18, m * 0.10)
		stretch = maxf(stretch, 1.18)
	if edge_w == TileType.TREE:
		pull += Vector2(-m * 0.18, -m * 0.10)
		stretch = maxf(stretch, 1.18)
	var trunk_top := c + Vector2(0.0, -m * 0.05)
	var trunk_bot := c + Vector2(0.0, m * 0.22)
	# Ствол — объём, не палка с кругом.
	_poly(PackedVector2Array([
		trunk_bot + Vector2(-m * 0.06, 0),
		trunk_bot + Vector2(m * 0.07, 0),
		trunk_top + Vector2(m * 0.05, 0),
		trunk_top + Vector2(-m * 0.04, 0),
	]), _lit(TileType.TREE_TRUNK))
	draw_line(trunk_bot + Vector2(-m * 0.02, 0), trunk_top + Vector2(-m * 0.01, 0), _lit(TileType.TREE_TRUNK_DARK), 2.0)
	var crown := c + pull + Vector2(0.0, -m * 0.28)
	draw_set_transform(crown + Vector2(m * 0.04, m * 0.06), 0.0, Vector2(stretch, stretch * 0.72))
	draw_circle(Vector2.ZERO, m * 0.28, TileType.SHADOW)
	draw_set_transform(crown, 0.0, Vector2(stretch, stretch * 0.78))
	draw_circle(Vector2.ZERO, m * 0.30, _lit(TileType.TREE_CROWN_MID))
	draw_set_transform(crown + Vector2(-m * 0.08, -m * 0.06), 0.0, Vector2(stretch * 0.85, stretch * 0.7))
	draw_circle(Vector2.ZERO, m * 0.22, _lit(TileType.TREE_CROWN))
	draw_set_transform(crown + Vector2(m * 0.06, -m * 0.10), 0.0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, m * 0.12, _lit(TileType.TREE_CROWN_HI))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Роща: сплетённые кроны на рёбрах.
	var br := m * 0.16
	if edge_n == TileType.TREE:
		draw_set_transform(Iso.edge_mid(c, iso_hw * 0.9, iso_hh * 0.9, "n") + Vector2(0, -m * 0.2), 0.0, Vector2(1.2, 0.75))
		draw_circle(Vector2.ZERO, br, _lit(TileType.TREE_CROWN))
	if edge_e == TileType.TREE:
		draw_set_transform(Iso.edge_mid(c, iso_hw * 0.9, iso_hh * 0.9, "e") + Vector2(0, -m * 0.2), 0.0, Vector2(1.2, 0.75))
		draw_circle(Vector2.ZERO, br, _lit(TileType.TREE_CROWN))
	if edge_s == TileType.TREE:
		draw_set_transform(Iso.edge_mid(c, iso_hw * 0.9, iso_hh * 0.9, "s") + Vector2(0, -m * 0.2), 0.0, Vector2(1.2, 0.75))
		draw_circle(Vector2.ZERO, br, _lit(TileType.TREE_CROWN))
	if edge_w == TileType.TREE:
		draw_set_transform(Iso.edge_mid(c, iso_hw * 0.9, iso_hh * 0.9, "w") + Vector2(0, -m * 0.2), 0.0, Vector2(1.2, 0.75))
		draw_circle(Vector2.ZERO, br, _lit(TileType.TREE_CROWN))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if grove:
		# Куст и гриб у ног.
		var bush_p := trunk_bot + Vector2(-m * 0.18, m * 0.02)
		draw_set_transform(bush_p, 0.0, Vector2(1.2, 0.75))
		draw_circle(Vector2.ZERO, m * 0.08, _lit(TileType.BUSH))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var mush := trunk_bot + Vector2(m * 0.16, m * 0.01)
		draw_rect(Rect2(mush.x - 1.2, mush.y - 4.0, 2.4, 5.0), _lit(TileType.MUSHROOM_STEM))
		draw_set_transform(mush + Vector2(0, -5.0), 0.0, Vector2(1.3, 0.7))
		draw_circle(Vector2.ZERO, m * 0.055, _lit(TileType.MUSHROOM_CAP))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flashing(DvorikSave.VIEW_PATH) or _flashing(DvorikSave.VIEW_REEDS) or _flashing(DvorikSave.VIEW_GROVE):
		draw_set_transform(crown, 0.0, Vector2(stretch, stretch * 0.78))
		draw_circle(Vector2.ZERO, m * 0.32, _sheen(_flash_a(0.55)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_water() -> void:
	# Пруд = одно тёмное зеркало. На стыке с водой — мост без обода.
	var c := iso_c + Vector2(0.0, -iso_th * 0.05)
	var hw := iso_hw * 0.98
	var hh := iso_hh * 0.98
	var open_n := edge_n != TileType.WATER
	var open_e := edge_e != TileType.WATER
	var open_s := edge_s != TileType.WATER
	var open_w := edge_w != TileType.WATER
	var pond := not (open_n and open_e and open_s and open_w)
	var deep := _lit(TileType.WATER_DEEP)
	var body := _lit(TileType.WATER_COL)
	if pond:
		_poly(Iso.diamond(c, hw * 1.06, hh * 1.06), deep)
		if not open_n:
			_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "n"), hw * 0.48, hh * 0.48), deep)
		if not open_e:
			_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "e"), hw * 0.48, hh * 0.48), deep)
		if not open_s:
			_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "s"), hw * 0.48, hh * 0.48), deep)
		if not open_w:
			_poly(Iso.diamond(Iso.edge_mid(c, hw, hh, "w"), hw * 0.48, hh * 0.48), deep)
		_poly(Iso.diamond(c + Vector2(0.0, hh * 0.04), hw * 0.70, hh * 0.70), body)
	else:
		_poly(Iso.diamond(c, hw * 0.92, hh * 0.92), _lit(TileType.WATER_RIM))
		_poly(Iso.diamond(c, hw * 0.78, hh * 0.78), deep)
		_poly(Iso.diamond(c + Vector2(0.0, hh * 0.03), hw * 0.62, hh * 0.62), body)
	# Обод только с открытых сторон — не между двумя водами.
	if pond:
		_water_open_rim(c, hw * 0.92, hh * 0.92, open_n, open_e, open_s, open_w)
	# Блик: на пруду один тихий, чтобы не дробить пятно.
	if show_lily or not pond:
		draw_set_transform(c + Vector2(-hw * 0.18, -hh * 0.12), 0.0, Vector2(1.35, 0.42))
		draw_circle(Vector2.ZERO, iso_hw * (0.07 if pond else 0.08), _lit(TileType.WATER_GLOSS))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_reflections(c, hw, hh)
	_draw_reeds(c, hw, hh)
	if show_lily:
		_draw_lily(c + Vector2(hw * 0.20, hh * 0.02))
	if show_duck:
		_draw_duck(c + Vector2(-hw * 0.02, hh * 0.08))
	if _flashing(DvorikSave.VIEW_POND) or _flashing(DvorikSave.VIEW_REEDS):
		_poly(Iso.diamond(c, hw * 1.05, hh * 1.05), _sheen(_flash_a(0.45)))


func _water_open_rim(c: Vector2, hw: float, hh: float, open_n: bool, open_e: bool, open_s: bool, open_w: bool) -> void:
	var rim := _lit(TileType.WATER_RIM)
	var n := c + Vector2(0.0, -hh)
	var e := c + Vector2(hw, 0.0)
	var s := c + Vector2(0.0, hh)
	var w := c + Vector2(-hw, 0.0)
	# Рёбра ромба: N-E, E-S, S-W, W-N соответствуют соседям n, e, s, w.
	if open_n:
		draw_line(n, e, rim, 2.2)
	if open_e:
		draw_line(e, s, rim, 2.2)
	if open_s:
		draw_line(s, w, rim, 2.2)
	if open_w:
		draw_line(w, n, rim, 2.2)



func _draw_lily(p: Vector2) -> void:
	draw_set_transform(p, 0.0, Vector2(1.55, 0.75))
	draw_circle(Vector2.ZERO, iso_hw * 0.11, _lit(TileType.LILY_PAD))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(p + Vector2(1.5, -3.0), iso_hw * 0.045, _lit(TileType.LILY_FLOWER))


func _draw_duck(p: Vector2) -> void:
	var s := iso_hw * 0.095
	draw_set_transform(p, 0.0, Vector2(1.25, 0.85))
	draw_circle(Vector2.ZERO, s, _lit(TileType.DUCK_BODY))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(p + Vector2(s * 0.95, -s * 0.55), s * 0.58, _lit(TileType.DUCK_HEAD))
	draw_circle(p + Vector2(s * 1.45, -s * 0.4), s * 0.28, _lit(TileType.DUCK_BILL))


func _draw_reflections(c: Vector2, hw: float, hh: float) -> void:
	var col := _lit(TileType.REFLECTION)
	if edge_n == TileType.HOUSE:
		_roof_silhouette(Iso.edge_mid(c, hw, hh, "n"), col)
	if edge_e == TileType.HOUSE:
		_roof_silhouette(Iso.edge_mid(c, hw, hh, "e"), col)
	if edge_s == TileType.HOUSE:
		_roof_silhouette(Iso.edge_mid(c, hw, hh, "s"), col)
	if edge_w == TileType.HOUSE:
		_roof_silhouette(Iso.edge_mid(c, hw, hh, "w"), col)


func _roof_silhouette(p: Vector2, col: Color) -> void:
	var hw := iso_hw * 0.12
	var hh := iso_hh * 0.14
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(p.x - hw, p.y + hh * 0.35),
			Vector2(p.x, p.y - hh),
			Vector2(p.x + hw, p.y + hh * 0.35),
		]),
		col
	)
	draw_rect(Rect2(p.x - hw * 0.55, p.y + hh * 0.25, hw * 1.1, hh * 0.55), col)


func _draw_reeds(c: Vector2, hw: float, hh: float) -> void:
	if edge_n == TileType.TREE:
		_reeds_at(Iso.edge_mid(c, hw, hh, "n"), Vector2(0.4, -1.0))
	if edge_e == TileType.TREE:
		_reeds_at(Iso.edge_mid(c, hw, hh, "e"), Vector2(1.0, 0.2))
	if edge_s == TileType.TREE:
		_reeds_at(Iso.edge_mid(c, hw, hh, "s"), Vector2(-0.3, 1.0))
	if edge_w == TileType.TREE:
		_reeds_at(Iso.edge_mid(c, hw, hh, "w"), Vector2(-1.0, -0.2))


func _reeds_at(base: Vector2, outward: Vector2) -> void:
	var col := _lit(TileType.REED)
	var o := outward.normalized()
	var perp := Vector2(-o.y, o.x)
	var m := iso_hw
	var a := base + perp * m * 0.05
	var b := base - perp * m * 0.06
	var tip_a := a + o * m * 0.26 + perp * m * 0.03
	var tip_b := b + o * m * 0.22 - perp * m * 0.02
	var tip_c := base + o * m * 0.20
	if _flashing(DvorikSave.VIEW_REEDS):
		var glow := _sheen(_flash_a(0.90))
		draw_line(a, tip_a, glow, 5.5)
		draw_line(b, tip_b, glow, 5.0)
	draw_line(a, tip_a, col, 2.6)
	draw_line(b, tip_b, col, 2.2)
	draw_line(base, tip_c, col, 1.8)
