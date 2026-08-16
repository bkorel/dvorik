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
	draw_rect(Rect2(Vector2.ZERO, size), TileType.WOOD_DARK)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), TileType.WOOD_MID)
	for i in _btn.size():
		_draw_button(_btn[i], TYPES[i], TYPES[i] == selected)


func _draw_button(rect: Rect2, tile: int, raised: bool) -> void:
	var lift := Vector2(0.0, -rect.size.y * 0.10) if raised else Vector2.ZERO
	var r := Rect2(rect.position + lift, rect.size)
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), TileType.SHADOW)
	draw_rect(r, TileType.WOOD_LIGHT if raised else TileType.WOOD_PALE)
	var inner := r.grow(-r.size.x * 0.16)
	match tile:
		TileType.HOUSE:
			draw_rect(inner, TileType.WOOD_PALE)
			var mid := inner.get_center()
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(inner.position.x + 2.0, inner.position.y + inner.size.y * 0.28),
					Vector2(mid.x, inner.position.y + 2.0),
					Vector2(inner.end.x - 2.0, inner.position.y + inner.size.y * 0.28),
				]),
				TileType.WOOD_DARK
			)
			draw_line(
				Vector2(mid.x, inner.position.y + 3.0),
				Vector2(mid.x, inner.end.y - 3.0),
				TileType.WOOD_RIDGE,
				3.0
			)
		TileType.ROAD:
			var pad := inner.size.y * 0.28
			draw_rect(Rect2(inner.position.x, inner.position.y + pad, inner.size.x, inner.size.y - pad * 2.0), TileType.ROAD_COL)
		TileType.TREE:
			var c := inner.get_center()
			var m := minf(inner.size.x, inner.size.y)
			draw_rect(Rect2(c.x - m * 0.06, c.y, m * 0.12, m * 0.22), TileType.TREE_TRUNK)
			draw_circle(c + Vector2(0.0, -m * 0.08), m * 0.22, TileType.TREE_CROWN)
			draw_circle(c + Vector2(-m * 0.07, -m * 0.14), m * 0.07, TileType.TREE_CROWN_HI)
		TileType.WATER:
			var wc := inner.get_center()
			var wm := minf(inner.size.x, inner.size.y)
			draw_set_transform(wc, 0.0, Vector2(1.25, 0.68))
			draw_circle(Vector2.ZERO, wm * 0.28, TileType.WATER_DEEP)
			draw_circle(Vector2.ZERO, wm * 0.22, TileType.WATER_COL)
			draw_set_transform(wc + Vector2(-wm * 0.08, -wm * 0.06), 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, wm * 0.07, TileType.WATER_GLOSS)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
