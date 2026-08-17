class_name Walkers
extends Node2D

## 2–4 крошечных человека. Идут между точками интереса по walkable-клеткам.
## Не заходят на HOUSE, не лерпят сквозь дом, depth-sort как у клеток.

const CLOTH := [
	TileType.PERSON_CLOTH_A,
	TileType.PERSON_CLOTH_B,
	TileType.PERSON_CLOTH_C,
	TileType.PERSON_CLOTH_D,
]

const PAUSE_MIN := 0.40
const PAUSE_MAX := 0.80
# ~4 клетки за ~3 с → ~0.75 с/шаг.
const STEP_SPEED := 1.35


class PersonView extends Node2D:
	var cloth: Color = TileType.PERSON_CLOTH_A
	var phase: float = 0.0
	var iso_hw: float = 28.0

	func _draw() -> void:
		var bob := sin(phase) * 1.6
		var s := maxf(iso_hw * 0.14, 5.5)
		draw_circle(Vector2(1.5, s * 0.95), s * 0.6, TileType.SHADOW)
		var leg := sin(phase) * s * 0.4
		draw_line(Vector2(-s * 0.28, s * 0.55 + bob), Vector2(-s * 0.4, s * 1.2 + bob + leg), TileType.DOOR, 2.0)
		draw_line(Vector2(s * 0.28, s * 0.55 + bob), Vector2(s * 0.4, s * 1.2 + bob - leg), TileType.DOOR, 2.0)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-s * 0.5, s * 0.1 + bob),
				Vector2(s * 0.5, s * 0.1 + bob),
				Vector2(s * 0.4, s * 0.85 + bob),
				Vector2(-s * 0.4, s * 0.85 + bob),
			]),
			cloth
		)
		draw_circle(Vector2(0.0, -s * 0.2 + bob), s * 0.42, TileType.PERSON_SKIN)


var board: Board
var _people: Array = []
var _rng := RandomNumberGenerator.new()


func setup(b: Board) -> void:
	board = b
	_rng.seed = 77
	z_as_relative = false
	z_index = 0
	set_process(true)
	_respawn()


func _make_view(gp: Vector2i, cloth: Color, phase: float) -> PersonView:
	var node := PersonView.new()
	node.z_as_relative = false
	node.z_index = 100 + Iso.depth_key(gp.x, gp.y)
	node.cloth = cloth
	node.phase = phase
	node.iso_hw = board.iso_hw
	add_child(node)
	return node


func _respawn() -> void:
	for c in get_children():
		c.queue_free()
	_people.clear()
	var spots := board.walkable_cells()
	if spots.is_empty():
		return
	var n := _rng.randi_range(2, 4)
	for i in n:
		var gp: Vector2i = spots[_rng.randi() % spots.size()]
		while board.tile_at(gp) == TileType.HOUSE:
			gp = spots[_rng.randi() % spots.size()]
		var cloth: Color = CLOTH[i % CLOTH.size()]
		var phase := _rng.randf() * TAU
		var node := _make_view(gp, cloth, phase)
		var person := {
			"gp": gp,
			"from": gp,
			"to": gp,
			"t": 1.0,
			"path": [],
			"path_i": 0,
			"pause": _rng.randf_range(0.2, 0.8),
			"last_kind": "",
			"cloth": cloth,
			"phase": phase,
			"node": node,
		}
		_people.append(person)
		_sync_person_visual(person, float(gp.x), float(gp.y))
		_assign_poi(person, spots)


func refresh_walkable() -> void:
	var spots := board.walkable_cells()
	if spots.is_empty():
		return
	for p in _people:
		if board.tile_at(p["gp"]) == TileType.HOUSE or not _is_walkable(p["gp"], spots):
			p["gp"] = spots[_rng.randi() % spots.size()]
			p["from"] = p["gp"]
			p["to"] = p["gp"]
			p["t"] = 1.0
			p["path"] = []
			p["path_i"] = 0
			p["pause"] = 0.3
		elif not _is_walkable(p["to"], spots):
			p["path"] = []
			p["path_i"] = 0
			p["pause"] = 0.15
			p["t"] = 1.0
			p["from"] = p["gp"]
			p["to"] = p["gp"]
		_assign_poi(p, spots)
	while _people.size() < 2 and not spots.is_empty():
		var gp: Vector2i = spots[_rng.randi() % spots.size()]
		var cloth: Color = CLOTH[_people.size() % CLOTH.size()]
		var phase := _rng.randf() * TAU
		var node := _make_view(gp, cloth, phase)
		var person := {
			"gp": gp,
			"from": gp,
			"to": gp,
			"t": 1.0,
			"path": [],
			"path_i": 0,
			"pause": 0.4,
			"last_kind": "",
			"cloth": cloth,
			"phase": phase,
			"node": node,
		}
		_people.append(person)
		_sync_person_visual(person, float(gp.x), float(gp.y))
		_assign_poi(person, spots)


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
		return
	for p in _people:
		p["phase"] = float(p["phase"]) + delta * 7.0
		if float(p["pause"]) > 0.0:
			p["pause"] = float(p["pause"]) - delta
			_sync_person_visual(p, float(p["gp"].x), float(p["gp"].y))
			continue
		var path: Array = p["path"]
		if path.is_empty():
			_assign_poi(p, spots)
			path = p["path"]
			if path.is_empty():
				_sync_person_visual(p, float(p["gp"].x), float(p["gp"].y))
				continue
		p["t"] = minf(1.0, float(p["t"]) + delta * STEP_SPEED)
		var a: Vector2i = p["from"]
		var b: Vector2i = p["to"]
		if board.tile_at(a) == TileType.HOUSE or board.tile_at(b) == TileType.HOUSE:
			p["from"] = p["gp"]
			p["to"] = p["gp"]
			p["path"] = []
			p["t"] = 1.0
			p["pause"] = 0.2
			_sync_person_visual(p, float(p["gp"].x), float(p["gp"].y))
			continue
		var t: float = float(p["t"])
		t = t * t * (3.0 - 2.0 * t)
		var g := Vector2(a).lerp(Vector2(b), t)
		_sync_person_visual(p, g.x, g.y)
		if float(p["t"]) >= 1.0:
			p["gp"] = b
			p["from"] = b
			var pi: int = int(p["path_i"]) + 1
			p["path_i"] = pi
			if pi >= path.size():
				p["path"] = []
				p["path_i"] = 0
				p["pause"] = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
				p["t"] = 1.0
			else:
				var nxt: Vector2i = path[pi]
				if board.tile_at(nxt) == TileType.HOUSE or not _is_walkable(nxt, spots):
					p["path"] = []
					p["path_i"] = 0
					p["pause"] = 0.25
					p["to"] = b
				else:
					p["to"] = nxt
					p["t"] = 0.0


func _assign_poi(p: Dictionary, spots: Array) -> void:
	var pois := board.points_of_interest()
	if pois.is_empty():
		p["path"] = []
		return
	var start: Vector2i = p["gp"]
	if board.tile_at(start) == TileType.HOUSE or not _is_walkable(start, spots):
		start = spots[_rng.randi() % spots.size()]
		p["gp"] = start
		p["from"] = start
		p["to"] = start
	var last_kind: String = str(p["last_kind"])
	var want_away := board.field_has_pond_or_grove()
	var candidates: Array = []
	if want_away:
		# Пока на поле есть пруд/роща — не выбирать HOUSE снова.
		_collect_pois(candidates, pois, start, last_kind, ["POND", "GROVE"], true)
		if candidates.is_empty():
			_collect_pois(candidates, pois, start, last_kind, ["POND", "GROVE"], false)
		if candidates.is_empty():
			_collect_pois(candidates, pois, start, last_kind, ["ROAD"], true)
		if candidates.is_empty():
			_collect_pois(candidates, pois, start, last_kind, ["ROAD"], false)
	else:
		_collect_pois(candidates, pois, start, last_kind, ["HOUSE", "ROAD", "POND", "GROVE"], true)
		if candidates.is_empty():
			_collect_pois(candidates, pois, start, last_kind, ["HOUSE", "ROAD", "POND", "GROVE"], false)
	if candidates.is_empty():
		var opts: Array[Vector2i] = []
		for d in Board.ORTHO:
			var n: Vector2i = start + d
			if _is_walkable(n, spots) and board.tile_at(n) != TileType.HOUSE:
				opts.append(n)
		if opts.is_empty():
			p["path"] = []
			p["pause"] = PAUSE_MAX
			return
		var dest: Vector2i = opts[_rng.randi() % opts.size()]
		p["path"] = [dest]
		p["path_i"] = 0
		p["from"] = start
		p["to"] = dest
		p["t"] = 0.0
		p["last_kind"] = "HOUSE"
		return
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	for poi3 in candidates:
		var goal: Vector2i = poi3["gp"]
		if not _is_walkable(goal, spots):
			continue
		if board.tile_at(goal) == TileType.HOUSE:
			continue
		var path := _bfs(start, goal, spots)
		if path.is_empty():
			continue
		p["path"] = path
		p["path_i"] = 0
		p["from"] = start
		p["to"] = path[0]
		p["t"] = 0.0
		p["last_kind"] = str(poi3["kind"])
		return
	# Не залипать у дома: короткий шаг к любому walkable, затем снова POI.
	var step_opts: Array[Vector2i] = []
	for d2 in Board.ORTHO:
		var n2: Vector2i = start + d2
		if _is_walkable(n2, spots) and board.tile_at(n2) != TileType.HOUSE:
			step_opts.append(n2)
	if not step_opts.is_empty():
		var step: Vector2i = step_opts[_rng.randi() % step_opts.size()]
		p["path"] = [step]
		p["path_i"] = 0
		p["from"] = start
		p["to"] = step
		p["t"] = 0.0
		return
	p["path"] = []
	p["pause"] = PAUSE_MIN


func _collect_pois(
	out: Array, pois: Array, start: Vector2i, last_kind: String,
	kinds: Array, require_new_kind: bool
) -> void:
	for poi in pois:
		var kind := str(poi["kind"])
		if kind not in kinds:
			continue
		if Vector2i(poi["gp"]) == start:
			continue
		if require_new_kind and last_kind != "" and kind == last_kind:
			continue
		out.append(poi)


func _bfs(start: Vector2i, goal: Vector2i, spots: Array) -> Array:
	if start == goal:
		return []
	var spot_set: Dictionary = {}
	for s in spots:
		spot_set[s] = true
	var q: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var seen: Dictionary = {start: true}
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		if cur == goal:
			break
		for d in Board.ORTHO:
			var n: Vector2i = cur + d
			if seen.has(n):
				continue
			if not spot_set.has(n):
				continue
			if board.tile_at(n) == TileType.HOUSE:
				continue
			seen[n] = true
			came[n] = cur
			q.append(n)
	if not came.has(goal) and start != goal:
		return []
	var path: Array = []
	var walk: Vector2i = goal
	while walk != start:
		path.push_front(walk)
		if not came.has(walk):
			return []
		walk = came[walk]
	return path


func _sync_person_visual(p: Dictionary, gx: float, gy: float) -> void:
	var node: PersonView = p["node"]
	if node == null or not is_instance_valid(node):
		return
	var ix := int(round(gx))
	var iy := int(round(gy))
	node.z_index = 100 + Iso.depth_key(ix, iy)
	node.position = _person_screen(gx, gy, ix, iy)
	node.cloth = p["cloth"]
	node.phase = float(p["phase"])
	node.iso_hw = board.iso_hw
	node.queue_redraw()


func _person_screen(gx: float, gy: float, ix: int, iy: int) -> Vector2:
	var screen := board.grid_to_board_pos(gx, gy)
	screen += Vector2(0.0, -board.iso_th * 0.18)
	var push := Vector2.ZERO
	for d in Board.ORTHO:
		var n := Vector2i(ix, iy) + d
		if board.tile_at(n) == TileType.HOUSE:
			push -= Vector2(d)
	if push.length_squared() > 0.01:
		push = push.normalized()
		screen += Iso.grid_to_screen(push.x * 0.32, push.y * 0.32, board.iso_hw, board.iso_hh)
	return screen
