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
	z_index = 80
	set_process(true)
	_respawn()


func _respawn() -> void:
	_people.clear()
	var n := 2 + _rng.randi() % 3
	var spots := board.walkable_cells()
	if spots.is_empty():
		spots = [Board.START_HOUSE]
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
	# Если текущая цель пропала — переназначаем.
	var spots := board.walkable_cells()
	if spots.is_empty():
		spots = [Board.START_HOUSE]
	for p in _people:
		if not _is_walkable(p["to"], spots):
			p["to"] = spots[_rng.randi() % spots.size()]
			p["from"] = p["gp"]
			p["t"] = 0.0


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
		spots = [Board.START_HOUSE]
	for p in _people:
		p["t"] = minf(1.0, float(p["t"]) + delta * 0.55)
		p["phase"] = float(p["phase"]) + delta * 6.0
		if float(p["t"]) >= 1.0:
			p["gp"] = p["to"]
			p["from"] = p["to"]
			var next := _pick_next(p["gp"], spots)
			p["to"] = next
			p["t"] = 0.0
		else:
			# Интерполяция позиции сетки для отрисовки.
			pass
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
	var bob := sin(phase) * 1.2
	var s := maxf(board.iso_hw * 0.09, 3.5)
	draw_circle(p + Vector2(1.2, s * 0.9), s * 0.55, TileType.SHADOW)
	# Ноги.
	var leg := sin(phase) * s * 0.35
	draw_line(p + Vector2(-s * 0.25, s * 0.55 + bob), p + Vector2(-s * 0.35, s * 1.1 + bob + leg), TileType.DOOR, 1.5)
	draw_line(p + Vector2(s * 0.25, s * 0.55 + bob), p + Vector2(s * 0.35, s * 1.1 + bob - leg), TileType.DOOR, 1.5)
	# Тело.
	draw_colored_polygon(
		PackedVector2Array([
			p + Vector2(-s * 0.45, s * 0.15 + bob),
			p + Vector2(s * 0.45, s * 0.15 + bob),
			p + Vector2(s * 0.35, s * 0.75 + bob),
			p + Vector2(-s * 0.35, s * 0.75 + bob),
		]),
		cloth
	)
	# Голова.
	draw_circle(p + Vector2(0.0, -s * 0.15 + bob), s * 0.38, TileType.PERSON_SKIN)
