class_name TileType
extends RefCounted

# Пустая клетка — трава доски, не тип в руке.
const EMPTY := 0
const HOUSE := 1
const ROAD := 2
const TREE := 3
const WATER := 4
const COUNT := 5

# Одна тёплая деревянная палитра. Не розовая.
const TABLE := Color(0.50, 0.34, 0.18)
const WOOD_PALE := Color(0.80, 0.60, 0.36)
const WOOD_LIGHT := Color(0.72, 0.50, 0.28)
const WOOD_MID := Color(0.58, 0.38, 0.20)
const WOOD_DARK := Color(0.38, 0.24, 0.12)
const WOOD_RIDGE := Color(0.26, 0.15, 0.07)
const GRASS := Color(0.45, 0.58, 0.30)
const GRASS_FIBER := Color(0.36, 0.49, 0.23)
const GRASS_ALT := Color(0.40, 0.54, 0.26)
const GRASS_SEAM := Color(0.38, 0.50, 0.25)
const ROAD_COL := Color(0.52, 0.35, 0.18)
const ROAD_GROOVE := Color(0.40, 0.26, 0.12)
const TREE_TRUNK := Color(0.44, 0.28, 0.14)
const TREE_CROWN := Color(0.28, 0.45, 0.20)
const TREE_CROWN_HI := Color(0.38, 0.54, 0.26)
const WATER_COL := Color(0.20, 0.43, 0.58)
const WATER_DEEP := Color(0.13, 0.30, 0.46)
const WATER_GLOSS := Color(0.75, 0.88, 0.94)
const FLASH_LIT := Color(1.0, 0.94, 0.48)
const SHADOW := Color(0.12, 0.07, 0.04, 0.28)


static func clamp_id(v: int) -> int:
	if v < EMPTY or v >= COUNT:
		return EMPTY
	return v
