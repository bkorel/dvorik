class_name TileType
extends RefCounted

# Пустая клетка — выемка стола, не тип в руке.
const EMPTY := 0
const HOUSE := 1
const ROAD := 2
const TREE := 3
const WATER := 4
const COUNT := 5

# Одна тёплая деревянная семья. Стол — зеленовато-оливковый. Не розовая.
const TABLE := Color(0.45, 0.50, 0.30)
const TABLE_RECESS := Color(0.32, 0.38, 0.22)
const TABLE_RIDGE := Color(0.54, 0.58, 0.36)
const TABLE_GRAIN := Color(0.38, 0.44, 0.26)
const TABLE_EDGE := Color(0.28, 0.32, 0.18)
const WOOD_PALE := Color(0.84, 0.62, 0.38)
const WOOD_LIGHT := Color(0.76, 0.54, 0.32)
const WOOD_MID := Color(0.58, 0.40, 0.22)
const WOOD_DARK := Color(0.40, 0.26, 0.14)
const WOOD_RIDGE := Color(0.28, 0.16, 0.08)
const WOOD_ROOF := Color(0.78, 0.58, 0.16)
const WOOD_ROOF_EDGE := Color(0.58, 0.40, 0.10)
# Совместимость со старыми именами (трава = поверхность стола).
const GRASS := TABLE
const GRASS_FIBER := TABLE_GRAIN
const GRASS_ALT := TABLE_RECESS
const GRASS_SEAM := TABLE_EDGE
const ROAD_COL := Color(0.46, 0.30, 0.16)
const ROAD_GROOVE := Color(0.34, 0.22, 0.10)
const TREE_TRUNK := Color(0.52, 0.36, 0.20)
const TREE_CROWN := Color(0.26, 0.46, 0.20)
const TREE_CROWN_HI := Color(0.42, 0.58, 0.30)
const WATER_COL := Color(0.18, 0.48, 0.72)
const WATER_DEEP := Color(0.10, 0.32, 0.52)
const WATER_GLOSS := Color(0.78, 0.92, 0.98)
const WATER_RIM := Color(0.58, 0.42, 0.24)
const WATER_PUDDLE := Color(0.16, 0.42, 0.62)
const REFLECTION := Color(0.14, 0.10, 0.07, 0.72)
const PATH_SHADE := Color(0.34, 0.20, 0.10)
const PATH_GROOVE := Color(0.24, 0.14, 0.07)
const REED := Color(0.34, 0.42, 0.18)
const YARD_BUSH := Color(0.28, 0.46, 0.20)
const YARD_PEG := Color(0.46, 0.32, 0.16)
const PORCH := Color(0.66, 0.46, 0.26)
const PORCH_EDGE := Color(0.40, 0.26, 0.12)
const FLASH_LIT := Color(1.0, 0.94, 0.48)
const SHADOW := Color(0.10, 0.08, 0.04, 0.32)


static func clamp_id(v: int) -> int:
	if v < EMPTY or v >= COUNT:
		return EMPTY
	return v
