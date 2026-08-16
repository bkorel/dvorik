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
	# Та же оливковая древесина, что у стола.
	draw_rect(Rect2(Vector2.ZERO, size), TileType.TABLE_EDGE)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), TileType.TABLE)
	for i in _btn.size():
		_draw_button(_btn[i], TYPES[i], TYPES[i] == selected)


func _draw_button(rect: Rect2, tile: int, raised: bool) -> void:
	var lift := Vector2(0.0, -rect.size.y * 0.10) if raised else Vector2.ZERO
	var r := Rect2(rect.position + lift, rect.size)
	var m := minf(r.size.x, r.size.y)
	# Выемка-кнопка; выбранная — приподнята.
	draw_rect(Rect2(r.position + Vector2(m * 0.04, m * 0.06), r.size), TileType.SHADOW)
	draw_rect(r, TileType.TABLE_RIDGE if raised else TileType.TABLE_RECESS)
	var well := r.grow(-m * 0.08)
	draw_rect(well, TileType.TABLE if raised else TileType.TABLE_RECESS)
	var inner := r.grow(-r.size.x * 0.16)
	match tile:
		TileType.HOUSE:
			var body := Rect2(inner.position.x, inner.position.y + inner.size.y * 0.22, inner.size.x, inner.size.y * 0.62)
			draw_rect(Rect2(body.position + Vector2(2, 3), body.size), TileType.SHADOW)
			draw_rect(body, TileType.WOOD_PALE)
			var mid := inner.get_center()
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(inner.position.x + 2.0, inner.position.y + inner.size.y * 0.32),
					Vector2(mid.x, inner.position.y + 2.0),
					Vector2(inner.end.x - 2.0, inner.position.y + inner.size.y * 0.32),
				]),
				TileType.WOOD_ROOF
			)
		TileType.ROAD:
			var pad := inner.size.y * 0.30
			var plank := Rect2(inner.position.x, inner.position.y + pad, inner.size.x, inner.size.y - pad * 2.0)
			draw_rect(Rect2(plank.position + Vector2(2, 3), plank.size), TileType.SHADOW)
			draw_rect(plank, TileType.ROAD_COL)
			var y1 := plank.position.y + plank.size.y * 0.35
			draw_line(Vector2(plank.position.x, y1), Vector2(plank.end.x, y1), TileType.ROAD_GROOVE, 1.5)
		TileType.TREE:
			var c := inner.get_center()
			var tm := minf(inner.size.x, inner.size.y)
			draw_circle(c + Vector2(tm * 0.04, tm * 0.06), tm * 0.10, TileType.SHADOW)
			draw_rect(Rect2(c.x - tm * 0.06, c.y, tm * 0.12, tm * 0.24), TileType.TREE_TRUNK)
			draw_circle(c + Vector2(0.0, -tm * 0.08), tm * 0.24, TileType.TREE_CROWN)
			draw_circle(c + Vector2(-tm * 0.08, -tm * 0.14), tm * 0.08, TileType.TREE_CROWN_HI)
		TileType.WATER:
			var wc := inner.get_center()
			var wm := minf(inner.size.x, inner.size.y)
			draw_circle(wc + Vector2(wm * 0.04, wm * 0.05), wm * 0.28, TileType.SHADOW)
			draw_circle(wc, wm * 0.28, TileType.WATER_RIM)
			draw_circle(wc, wm * 0.20, TileType.WATER_COL)
			draw_circle(wc + Vector2(-wm * 0.08, -wm * 0.08), wm * 0.06, TileType.WATER_GLOSS)
