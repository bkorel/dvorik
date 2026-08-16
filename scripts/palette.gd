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
	_draw_shelf()
	for i in _btn.size():
		_draw_toy(_btn[i], TYPES[i], TYPES[i] == selected)


func _draw_shelf() -> void:
	# Сплошной каменный карниз — игрушки просто стоят на нём, без рамок-иконок.
	draw_rect(Rect2(Vector2.ZERO, size), TileType.TABLE_EDGE)
	var shelf := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(shelf, TileType.TABLE)
	var lip_h := size.y * 0.16
	draw_rect(Rect2(shelf.position.x, shelf.position.y, shelf.size.x, lip_h), TileType.STONE_LIGHT)
	draw_line(Vector2(shelf.position.x, shelf.position.y + 1.0), Vector2(shelf.end.x, shelf.position.y + 1.0), Color(0.62, 0.64, 0.67, 0.35), 1.4)
	draw_line(Vector2(shelf.position.x, shelf.position.y + lip_h), Vector2(shelf.end.x, shelf.position.y + lip_h), TileType.STONE_DARK, 2.0)
	TileArt.stone_grain(self, shelf, 3, 9, 0.7)


func _draw_toy(rect: Rect2, tile: int, raised: bool) -> void:
	# Выбранный камень заметно крупнее, поднят высоко над карнизом; тень
	# остаётся у основания — виден явный отрыв, не смена цвета кнопки.
	var scale_bump := 1.16 if raised else 1.0
	var lift := rect.size.y * 0.42 if raised else 0.0
	var base_size := rect.size * scale_bump
	var r := Rect2(rect.get_center() - base_size * 0.5 - Vector2(0.0, lift), base_size)
	var m := minf(r.size.x, r.size.y)
	# Тень всегда у основания слота: у поднятого камня — маленькая и далеко
	# под ним (виден отрыв), у стоящего — широкая и прямо под ним.
	var shadow_y := rect.end.y - rect.size.y * 0.05
	var shadow_w := m * (0.24 if raised else 0.46)
	draw_set_transform(Vector2(rect.get_center().x, shadow_y), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, shadow_w, Color(0.02, 0.02, 0.03, 0.55 if raised else 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var inner := r.grow(-r.size.x * 0.10)
	match tile:
		TileType.HOUSE:
			_toy_house(inner, m)
		TileType.ROAD:
			_toy_road(inner, m)
		TileType.TREE:
			_toy_tree(inner, m)
		TileType.WATER:
			_toy_water(inner, m)


func _toy_house(inner: Rect2, m: float) -> void:
	# Тот же низкий каменный объём + тёмная плита крыши, что и на доске.
	var roof_h := inner.size.y * 0.42
	var wall := Rect2(inner.position.x, inner.position.y + roof_h, inner.size.x, inner.size.y - roof_h)
	draw_rect(Rect2(wall.position + Vector2(1.5, 2.0), wall.size), TileType.SHADOW)
	draw_rect(wall, TileType.STONE_MID)
	var face_h := wall.size.y * 0.34
	draw_rect(Rect2(wall.position.x, wall.end.y - face_h, wall.size.x, face_h), TileType.STONE_FACE)
	draw_line(Vector2(wall.position.x, wall.end.y - face_h), Vector2(wall.end.x, wall.end.y - face_h), TileType.STONE_DARK, 1.2)
	var door_w := m * 0.15
	draw_rect(Rect2(wall.get_center().x - door_w * 0.5, wall.end.y - face_h * 0.95, door_w, face_h * 0.95), TileType.STONE_DARK)
	var roof := Rect2(inner.position.x - m * 0.055, inner.position.y, inner.size.x + m * 0.11, roof_h)
	draw_rect(Rect2(roof.position + Vector2(1.5, 2.0), roof.size), TileType.SHADOW)
	draw_rect(roof, TileType.ROOF_SLAB)
	draw_line(Vector2(roof.position.x, roof.position.y + 1.0), Vector2(roof.end.x, roof.position.y + 1.0), TileType.ROOF_SHEEN, 1.4)
	draw_line(Vector2(roof.position.x, roof.end.y), Vector2(roof.end.x, roof.end.y), TileType.ROOF_EDGE, 2.0)
	TileArt.stone_grain(self, wall, 41, 42, 0.6)


func _toy_road(inner: Rect2, m: float) -> void:
	# Та же плита с одним швом, что и на доске.
	var pad_y := inner.size.y * 0.26
	var plate := Rect2(inner.position.x - m * 0.06, inner.position.y + pad_y, inner.size.x + m * 0.12, inner.size.y - pad_y * 2.0)
	draw_rect(Rect2(plate.position + Vector2(0.0, 1.5), plate.size), TileType.SHADOW)
	draw_rect(plate, TileType.ROAD_COL)
	draw_line(Vector2(plate.position.x + 1.0, plate.get_center().y), Vector2(plate.end.x - 1.0, plate.get_center().y), TileType.ROAD_GROOVE, 2.0)
	draw_line(Vector2(plate.position.x, plate.position.y + 1.0), Vector2(plate.end.x, plate.position.y + 1.0), Color(0.60, 0.61, 0.64, 0.22), 1.2)
	TileArt.stone_grain(self, plate, 43, 44, 0.6)


func _toy_tree(inner: Rect2, m: float) -> void:
	# Живая тёмная крона — как на доске, без изменений силуэта.
	var c := inner.get_center()
	draw_circle(c + Vector2(m * 0.04, m * 0.06), m * 0.10, TileType.SHADOW)
	draw_rect(Rect2(c.x - m * 0.05, c.y, m * 0.10, m * 0.26), TileType.TREE_TRUNK)
	draw_circle(c + Vector2(0.0, -m * 0.10), m * 0.25, TileType.TREE_CROWN_LO)
	draw_circle(c + Vector2(-m * 0.08, -m * 0.13), m * 0.16, TileType.TREE_CROWN)
	draw_circle(c + Vector2(m * 0.07, -m * 0.15), m * 0.12, TileType.TREE_CROWN_HI)


func _toy_water(inner: Rect2, m: float) -> void:
	# Та же чаша с чёрным маслом и тусклым бликом, что и на доске.
	var c := inner.get_center()
	var rad := minf(inner.size.x, inner.size.y) * 0.5
	draw_circle(c + Vector2(m * 0.04, m * 0.05), rad, TileType.SHADOW)
	draw_circle(c, rad, TileType.WATER_RIM)
	draw_circle(c, rad * 0.78, TileType.WATER_DEEP)
	draw_circle(c, rad * 0.66, TileType.WATER_COL)
	draw_set_transform(c + Vector2(-rad * 0.28, -rad * 0.30), 0.0, Vector2(1.1, 0.48))
	draw_circle(Vector2.ZERO, m * 0.055, TileType.WATER_GLOSS)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
