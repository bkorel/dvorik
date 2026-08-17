class_name Iso
extends RefCounted

## Изометрия ¾: клетка — ромб с толщиной. Сетка (gx, gy) → экран.


static func grid_to_screen(gx: float, gy: float, hw: float, hh: float) -> Vector2:
	return Vector2((gx - gy) * hw, (gx + gy) * hh)


static func screen_to_grid(p: Vector2, hw: float, hh: float) -> Vector2:
	# Обратная к grid_to_screen.
	var gx := (p.x / hw + p.y / hh) * 0.5
	var gy := (p.y / hh - p.x / hw) * 0.5
	return Vector2(gx, gy)


static func diamond(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(0.0, -hh),
		c + Vector2(hw, 0.0),
		c + Vector2(0.0, hh),
		c + Vector2(-hw, 0.0),
	])


static func edge_mid(c: Vector2, hw: float, hh: float, edge: String) -> Vector2:
	# Середина общего ребра с ортогональным соседом сетки.
	# N→экран NE, E→SE, S→SW, W→NW.
	match edge:
		"n":
			return c + Vector2(hw * 0.5, -hh * 0.5)
		"e":
			return c + Vector2(hw * 0.5, hh * 0.5)
		"s":
			return c + Vector2(-hw * 0.5, hh * 0.5)
		"w":
			return c + Vector2(-hw * 0.5, -hh * 0.5)
	return c


static func depth_key(gx: int, gy: int) -> int:
	return gx + gy
