class_name Cell
extends Control

## Клетка. Тип не «превращается»: каждая сторона смотрит на ортогонального соседа.

signal tapped(cell: Cell)

const TAP_MAX_MS := 400
const TAP_MAX_MOVE := 24.0

var grid_x: int = 0
var grid_y: int = 0
var tile: int = TileType.EMPTY

# Слияние домов по ортогональному ребру. Диагональ не сосед.
var merge_n: bool = false
var merge_e: bool = false
var merge_s: bool = false
var merge_w: bool = false

# Вспышка улочки: 1 → 0 один раз, ввод живой.
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
	return merge_n or merge_e or merge_s or merge_w


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
	if merge_n:
		draw_line(Vector2(mid.x, 0.0), Vector2(mid.x, mid.y), col, w)
	if merge_s:
		draw_line(Vector2(mid.x, mid.y), Vector2(mid.x, size.y), col, w)
	if merge_w:
		draw_line(Vector2(0.0, mid.y), Vector2(mid.x, mid.y), col, w)
	if merge_e:
		draw_line(Vector2(mid.x, mid.y), Vector2(size.x, mid.y), col, w)
	# Шапка общего конька на затронутом ребре.
	if merge_n:
		draw_circle(Vector2(mid.x, 0.0), w * 0.65, col)
	if merge_s:
		draw_circle(Vector2(mid.x, size.y), w * 0.65, col)
	if merge_w:
		draw_circle(Vector2(0.0, mid.y), w * 0.65, col)
	if merge_e:
		draw_circle(Vector2(size.x, mid.y), w * 0.65, col)


func _draw_road(r: Rect2) -> void:
	# Дорога — плоская рейка от края до края.
	var m := minf(r.size.x, r.size.y)
	var pad := m * 0.20
	var body := Rect2(0.0, pad, r.size.x, r.size.y - pad * 2.0)
	draw_rect(Rect2(body.position + Vector2(0, 3), body.size), TileType.SHADOW)
	draw_rect(body, TileType.ROAD_COL)
	var y1 := body.position.y + body.size.y * 0.32
	var y2 := body.position.y + body.size.y * 0.68
	draw_line(Vector2(0.0, y1), Vector2(r.size.x, y1), TileType.ROAD_GROOVE, 1.6)
	draw_line(Vector2(0.0, y2), Vector2(r.size.x, y2), TileType.ROAD_GROOVE, 1.6)


func _draw_tree(r: Rect2) -> void:
	# Дерево — колышек с кроной; выше дороги, ниже конька.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center()
	draw_circle(c + Vector2(2, 6), m * 0.10, TileType.SHADOW)
	var trunk := Rect2(c.x - m * 0.07, c.y + m * 0.02, m * 0.14, m * 0.24)
	draw_rect(trunk, TileType.TREE_TRUNK)
	draw_circle(c + Vector2(0.0, -m * 0.10), m * 0.24, TileType.TREE_CROWN)
	draw_circle(c + Vector2(-m * 0.08, -m * 0.16), m * 0.09, TileType.TREE_CROWN_HI)


func _draw_water(r: Rect2) -> void:
	# Вода — синяя лужа-фишка, глянцевая, с бликом, самая низкая.
	var m := minf(r.size.x, r.size.y)
	var c := r.get_center() + Vector2(0.0, m * 0.04)
	draw_set_transform(c + Vector2(2, 3), 0.0, Vector2(1.28, 0.70))
	draw_circle(Vector2.ZERO, m * 0.28, TileType.SHADOW)
	draw_set_transform(c, 0.0, Vector2(1.28, 0.70))
	draw_circle(Vector2.ZERO, m * 0.28, TileType.WATER_DEEP)
	draw_circle(Vector2.ZERO, m * 0.23, TileType.WATER_COL)
	draw_set_transform(c + Vector2(-m * 0.10, -m * 0.07), 0.0, Vector2(1.05, 0.50))
	draw_circle(Vector2.ZERO, m * 0.07, TileType.WATER_GLOSS)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
