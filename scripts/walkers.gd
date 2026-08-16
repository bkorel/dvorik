class_name Walkers
extends Node2D

## 2–4 крошечных человека. Ходят по дорогам и вдоль домов. Не заходят внутрь.

const CLOTH := [
	TileType.PERSON_CLOTH_A,
	TileType.PERSON_CLOTH_B,
	TileType.PERSON_CLOTH_C,
	TileType.PERSON_CLOTH_D,
]

var board: Board
var _people: Array = []
var _rng := RandomNumberGenerator.new()


func setup(b: Board) -> void:
	board = b
	_rng.seed = 77
	z_as_relative = false
	z_index = 200
	set_process(true)
	_respawn()


func _respawn() -> void:
	_people.clear()
	var n := 3
	var spots := board.walkable_cells()
	if spots.is_empty():
		# Не ставим на дом — любая соседняя клетка уже отфильтрована board.
		spots = board.walkable_cells()
	if spots.is_empty():
		return
	for i in n:
		var gp: Vector2i = spots[_rng.randi() % spots.size()]
		_people.append({
			"gp": gp,
			"from": gp,
			"to": gp,
			"t": 1.0,
			"cloth": CLOTH[i % CLOTH.size()],
			"phase": _rng.randf() * TAU,
		})
	queue_redraw()


func refresh_walkable() -> void:
	var spots := board.walkable_cells()
	if spots.is_empty():
		return
	for p in _people:
		if not _is_walkable(p["to"], spots):
			p["to"] = spots[_rng.randi() % spots.size()]
			p["from"] = p["gp"]
			p["t"] = 0.0
	# Если людей меньше минимума после загрузки — добрать.
	while _people.size() < 2 and not spots.is_empty():
		var gp: Vector2i = spots[_rng.randi() % spots.size()]
		_people.append({
			"gp": gp,
			"from": gp,
			"to": gp,
			"t": 1.0,
			"cloth": CLOTH[_people.size() % CLOTH.size()],
			"phase": _rng.randf() * TAU,
		})


func _is_walkable(gp: Vector2i, spots: Array) -> bool:
	for s in spots:
		if s == gp:
			return true
	return false


func _process(delta: float) -> void:
	if board == null:
		return
	var spots := board.walkable_cells()
	if spots.is_empty():
		queue_redraw()
		return
	for p in _people:
		p["t"] = minf(1.0, float(p["t"]) + delta * 0.7)
		p["phase"] = float(p["phase"]) + delta * 7.0
		if float(p["t"]) >= 1.0:
			p["gp"] = p["to"]
			p["from"] = p["to"]
			var next := _pick_next(p["gp"], spots)
			p["to"] = next
			p["t"] = 0.0
	queue_redraw()


func _pick_next(gp: Vector2i, spots: Array) -> Vector2i:
	var opts: Array[Vector2i] = []
	for d in Board.ORTHO:
		var n: Vector2i = gp + d
		if _is_walkable(n, spots):
			opts.append(n)
	# Иногда топчемся на месте у дома.
	if opts.is_empty() or _rng.randf() < 0.12:
		return gp
	return opts[_rng.randi() % opts.size()]


func _draw() -> void:
	if board == null:
		return
	for p in _people:
		var a: Vector2i = p["from"]
		var b: Vector2i = p["to"]
		var t: float = float(p["t"])
		t = t * t * (3.0 - 2.0 * t)
		var ga := Vector2(a)
		var gb := Vector2(b)
		var g := ga.lerp(gb, t)
		var screen := board.grid_to_board_pos(g.x, g.y)
		# Чуть выше поверхности земли.
		screen += Vector2(0.0, -board.iso_th * 0.6)
		_draw_person(screen, p["cloth"], float(p["phase"]))


func _draw_person(p: Vector2, cloth: Color, phase: float) -> void:
	var bob := sin(phase) * 1.6
	var s := maxf(board.iso_hw * 0.14, 5.5)
	draw_circle(p + Vector2(1.5, s * 0.95), s * 0.6, TileType.SHADOW)
	var leg := sin(phase) * s * 0.4
	draw_line(p + Vector2(-s * 0.28, s * 0.55 + bob), p + Vector2(-s * 0.4, s * 1.2 + bob + leg), TileType.DOOR, 2.0)
	draw_line(p + Vector2(s * 0.28, s * 0.55 + bob), p + Vector2(s * 0.4, s * 1.2 + bob - leg), TileType.DOOR, 2.0)
	draw_colored_polygon(
		PackedVector2Array([
			p + Vector2(-s * 0.5, s * 0.1 + bob),
			p + Vector2(s * 0.5, s * 0.1 + bob),
			p + Vector2(s * 0.4, s * 0.85 + bob),
			p + Vector2(-s * 0.4, s * 0.85 + bob),
		]),
		cloth
	)
	draw_circle(p + Vector2(0.0, -s * 0.2 + bob), s * 0.42, TileType.PERSON_SKIN)
