class_name Palette
extends Control

# дом уже выбран — рука никогда не пустая
var selected: int = TileType.HOUSE

const TYPES: Array[int] = [
	TileType.HOUSE,
	TileType.ROAD,
	TileType.TREE,
	TileType.WATER,
]

const TAP_MAX_MS := 400
const TAP_MAX_MOVE := 24.0

var _btn: Array[Rect2] = []
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_btn.clear()
	var n := 4
	var pad := size.y * 0.12
	var gap := size.x * 0.035
	var inner_w := size.x - pad * 2.0
	var btn_h := size.y - pad * 2.0
	if inner_w <= 0.0 or btn_h <= 0.0:
		queue_redraw()
		return
	var side := minf((inner_w - gap * float(n - 1)) / float(n), btn_h)
	var y := (size.y - side) * 0.5
	var x0 := pad + (inner_w - (side * float(n) + gap * float(n - 1))) * 0.5
	for i in n:
		_btn.append(Rect2(x0 + float(i) * (side + gap), y, side, side))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
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
	var local := pos
	for i in _btn.size():
		if _btn[i].grow(_btn[i].size.x * 0.08).has_point(local):
			selected = TYPES[i]
			queue_redraw()
			return


func _draw() -> void:
	if size.x <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), TileType.PALETTE_SHELF)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), TileType.EARTH_TOP_ALT)
	for i in _btn.size():
		_draw_button(_btn[i], TYPES[i], TYPES[i] == selected)


func _draw_button(rect: Rect2, tile: int, raised: bool) -> void:
	# Объёмные фишки; выбранная заметно выше и чуть крупнее.
	var lift_y := -rect.size.y * 0.38 if raised else 0.0
	var scale := 1.16 if raised else 1.0
	var side := rect.size.x * scale
	var r := Rect2(
		rect.get_center().x - side * 0.5,
		rect.get_center().y - side * 0.5 + lift_y,
		side,
		side
	)
	var m := minf(r.size.x, r.size.y)
	# Тень остаётся у основания слота — виден зазор.
	var shadow := Rect2(rect.position.x + m * 0.1, rect.end.y - m * 0.16, rect.size.x - m * 0.2, m * 0.12)
	draw_rect(shadow, TileType.SHADOW)
	draw_rect(r, TileType.PALETTE_WELL)
	var well := r.grow(-m * 0.08)
	draw_rect(well, TileType.EARTH_TOP if raised else TileType.EARTH_LEFT)
	var inner := r.grow(-r.size.x * 0.12)
	match tile:
		TileType.HOUSE:
			_chip_house(inner)
		TileType.ROAD:
			_chip_road(inner)
		TileType.TREE:
			_chip_tree(inner)
		TileType.WATER:
			_chip_water(inner)


func _chip_house(inner: Rect2) -> void:
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.10)
	var hw := inner.size.x * 0.30
	var hh := inner.size.y * 0.15
	var wall := inner.size.y * 0.30
	var base := c
	var foot := c + Vector2(0, wall)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-hw, 0), base + Vector2(0, hh), foot + Vector2(0, hh), foot + Vector2(-hw, 0)
	]), TileType.WALL_SIDE)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(hw, 0), base + Vector2(0, hh), foot + Vector2(0, hh), foot + Vector2(hw, 0)
	]), TileType.WALL_FRONT)
	var peak := base + Vector2(0, -hh - wall * 0.55)
	draw_colored_polygon(PackedVector2Array([peak, base + Vector2(0, -hh), base + Vector2(hw, 0)]), TileType.ROOF_LIT)
	draw_colored_polygon(PackedVector2Array([peak, base + Vector2(0, -hh), base + Vector2(-hw, 0)]), TileType.ROOF_SHADE)
	draw_rect(Rect2(c.x + hw * 0.12, peak.y + 1.0, 4.5, 10.0), TileType.CHIMNEY)
	draw_rect(Rect2(c.x + 1.5, c.y + wall * 0.05, 7.0, 8.0), TileType.WINDOW)
	draw_rect(Rect2(c.x - hw * 0.55, c.y + wall * 0.2, 6.0, 10.0), TileType.DOOR)


func _chip_road(inner: Rect2) -> void:
	# Объёмная плита с поворотом в глубину — не плоская полоска.
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.06)
	var hw := inner.size.x * 0.34
	var hh := inner.size.y * 0.17
	var th := inner.size.y * 0.10
	var top := Iso.diamond(c, hw, hh)
	var bot := Iso.diamond(c + Vector2(0, th), hw, hh)
	draw_colored_polygon(PackedVector2Array([top[3], top[2], bot[2], bot[3]]), TileType.ROAD_SHADE)
	draw_colored_polygon(PackedVector2Array([top[2], top[1], bot[1], bot[2]]), TileType.ROAD_GROOVE)
	draw_colored_polygon(top, TileType.ROAD_COL)
	# Поворот: рукав вглубь + рукав вбок.
	var mid := c
	var a := Iso.edge_mid(c, hw * 0.9, hh * 0.9, "n")
	var b := Iso.edge_mid(c, hw * 0.9, hh * 0.9, "e")
	_chip_strip(mid, a, hw * 0.16, TileType.ROAD_SHADE)
	_chip_strip(mid, b, hw * 0.18, TileType.ROAD_LIT)


func _chip_strip(a: Vector2, b: Vector2, half_w: float, col: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized() * half_w
	n = Vector2(n.x, n.y * 0.7)
	draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), col)


func _chip_tree(inner: Rect2) -> void:
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.08)
	var m := minf(inner.size.x, inner.size.y)
	# Ствол объёмом.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-m * 0.06, m * 0.22),
		c + Vector2(m * 0.07, m * 0.22),
		c + Vector2(m * 0.05, -m * 0.02),
		c + Vector2(-m * 0.04, -m * 0.02),
	]), TileType.TREE_TRUNK)
	draw_line(c + Vector2(-m * 0.02, m * 0.2), c + Vector2(-m * 0.01, 0), TileType.TREE_TRUNK_DARK, 2.0)
	# Крона слоями, не кружок на палке.
	draw_set_transform(c + Vector2(m * 0.04, m * 0.02), 0.0, Vector2(1.15, 0.75))
	draw_circle(Vector2.ZERO, m * 0.20, TileType.SHADOW)
	draw_set_transform(c + Vector2(0, -m * 0.16), 0.0, Vector2(1.2, 0.85))
	draw_circle(Vector2.ZERO, m * 0.22, TileType.TREE_CROWN_MID)
	draw_set_transform(c + Vector2(-m * 0.08, -m * 0.22), 0.0, Vector2(1.05, 0.8))
	draw_circle(Vector2.ZERO, m * 0.16, TileType.TREE_CROWN)
	draw_set_transform(c + Vector2(m * 0.07, -m * 0.26), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, m * 0.09, TileType.TREE_CROWN_HI)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _chip_water(inner: Rect2) -> void:
	var c := inner.get_center() + Vector2(0, inner.size.y * 0.04)
	var hw := inner.size.x * 0.34
	var hh := inner.size.y * 0.17
	var th := inner.size.y * 0.09
	var top := Iso.diamond(c, hw, hh)
	var bot := Iso.diamond(c + Vector2(0, th), hw, hh)
	draw_colored_polygon(PackedVector2Array([top[3], top[2], bot[2], bot[3]]), TileType.WATER_RIM)
	draw_colored_polygon(PackedVector2Array([top[2], top[1], bot[1], bot[2]]), Color(0.06, 0.18, 0.28))
	draw_colored_polygon(top, TileType.WATER_DEEP)
	draw_colored_polygon(Iso.diamond(c + Vector2(0, 2), hw * 0.62, hh * 0.62), TileType.WATER_COL)
	draw_circle(c + Vector2(-hw * 0.18, -hh * 0.15), hw * 0.12, TileType.WATER_GLOSS)
