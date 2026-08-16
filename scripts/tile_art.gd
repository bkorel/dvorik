class_name TileArt
extends RefCounted

## Общие помощники отрисовки камня: зернистая текстура + скругление
## только «открытых» углов (для слияния соседних фишек в одно пятно).

const OVERLAY_SIZE := 160

static var _overlay_tex: ImageTexture


static func overlay_texture() -> ImageTexture:
	if _overlay_tex == null:
		_build_overlay()
	return _overlay_tex


static func _build_overlay() -> void:
	var big := FastNoiseLite.new()
	big.seed = 913
	big.frequency = 0.035
	var fine := FastNoiseLite.new()
	fine.seed = 271
	fine.frequency = 0.16
	var img := Image.create(OVERLAY_SIZE, OVERLAY_SIZE, false, Image.FORMAT_RGBA8)
	for y in OVERLAY_SIZE:
		for x in OVERLAY_SIZE:
			var n := big.get_noise_2d(x, y) * 0.65 + fine.get_noise_2d(x, y) * 0.35
			var a := clampf(absf(n) * 0.5, 0.0, 0.38)
			var v := 1.0 if n > 0.0 else 0.0
			img.set_pixel(x, y, Color(v, v, v, a))
	_overlay_tex = ImageTexture.create_from_image(img)


static func overlay_region(seed_x: int, seed_y: int, w: float, h: float) -> Rect2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_x * 92821 + seed_y * 6883 + 5
	var ww := clampf(w, 1.0, float(OVERLAY_SIZE))
	var hh := clampf(h, 1.0, float(OVERLAY_SIZE))
	var mx := maxf(float(OVERLAY_SIZE) - ww, 0.0)
	var my := maxf(float(OVERLAY_SIZE) - hh, 0.0)
	return Rect2(rng.randf() * mx, rng.randf() * my, ww, hh)


## Каменная зернистость поверх плоской заливки — иначе стены/полы читаются
## как гладкая пластиковая схема.
static func stone_grain(ci: CanvasItem, rect: Rect2, seed_x: int, seed_y: int, strength: float = 1.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tex := overlay_texture()
	var src := overlay_region(seed_x, seed_y, rect.size.x, rect.size.y)
	ci.draw_texture_rect_region(tex, rect, src, Color(1.0, 1.0, 1.0, strength))


## Прямоугольник со скруглением ТОЛЬКО указанных углов. На стороне, где
## сосед того же типа, угол остаётся прямым — фишки сливаются в одно пятно
## без шва и без «талии» между ними.
static func round_rect_sel(ci: CanvasItem, rect: Rect2, col: Color, rad: float, tl: bool, tr: bool, bl: bool, br: bool) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var rr := minf(rad, minf(rect.size.x, rect.size.y) * 0.5)
	if rr <= 0.01:
		ci.draw_rect(rect, col)
		return
	var p := rect.position
	var e := rect.end
	ci.draw_rect(Rect2(p.x + rr, p.y, maxf(e.x - p.x - rr * 2.0, 0.0), e.y - p.y), col)
	ci.draw_rect(Rect2(p.x, p.y + rr, e.x - p.x, maxf(e.y - p.y - rr * 2.0, 0.0)), col)
	if tl:
		ci.draw_circle(Vector2(p.x + rr, p.y + rr), rr, col)
	else:
		ci.draw_rect(Rect2(p.x, p.y, rr, rr), col)
	if tr:
		ci.draw_circle(Vector2(e.x - rr, p.y + rr), rr, col)
	else:
		ci.draw_rect(Rect2(e.x - rr, p.y, rr, rr), col)
	if bl:
		ci.draw_circle(Vector2(p.x + rr, e.y - rr), rr, col)
	else:
		ci.draw_rect(Rect2(p.x, e.y - rr, rr, rr), col)
	if br:
		ci.draw_circle(Vector2(e.x - rr, e.y - rr), rr, col)
	else:
		ci.draw_rect(Rect2(e.x - rr, e.y - rr, rr, rr), col)
