class_name TileType
extends RefCounted

# Пустая клетка — выемка в каменной плите, не тип в руке.
const EMPTY := 0
const HOUSE := 1
const ROAD := 2
const TREE := 3
const WATER := 4
const COUNT := 5

# Холодный камень. Одно живое зелёное — крона. Один блеск — масло.
const TABLE := Color(0.22, 0.23, 0.26)
const TABLE_RECESS := Color(0.11, 0.12, 0.14)
const TABLE_RIDGE := Color(0.30, 0.31, 0.34)
const TABLE_GRAIN := Color(0.18, 0.19, 0.22)
const TABLE_EDGE := Color(0.14, 0.15, 0.17)
const STONE_PALE := Color(0.42, 0.43, 0.46)
const STONE_LIGHT := Color(0.34, 0.35, 0.38)
const STONE_MID := Color(0.26, 0.27, 0.30)
const STONE_DARK := Color(0.16, 0.17, 0.19)
const STONE_FACE := Color(0.28, 0.29, 0.32)
const ROOF_SLAB := Color(0.10, 0.11, 0.13)
const ROOF_EDGE := Color(0.06, 0.07, 0.08)
const ROOF_SHEEN := Color(0.20, 0.21, 0.24)
# Совместимость со старыми именами.
const GRASS := TABLE
const GRASS_FIBER := TABLE_GRAIN
const GRASS_ALT := TABLE_RECESS
const GRASS_SEAM := TABLE_EDGE
const WOOD_PALE := STONE_PALE
const WOOD_LIGHT := STONE_LIGHT
const WOOD_MID := STONE_MID
const WOOD_DARK := STONE_DARK
const WOOD_RIDGE := ROOF_EDGE
const WOOD_ROOF := ROOF_SLAB
const WOOD_ROOF_EDGE := ROOF_EDGE
const ROAD_COL := Color(0.24, 0.25, 0.28)
const ROAD_GROOVE := Color(0.08, 0.09, 0.11)
const ROAD_SEAM := Color(0.16, 0.17, 0.19)
const TREE_TRUNK := Color(0.14, 0.12, 0.10)
const TREE_CROWN := Color(0.16, 0.28, 0.14)
const TREE_CROWN_HI := Color(0.24, 0.38, 0.20)
const TREE_CROWN_LO := Color(0.10, 0.18, 0.09)
const WATER_COL := Color(0.05, 0.06, 0.07)
const WATER_DEEP := Color(0.02, 0.02, 0.03)
const WATER_GLOSS := Color(0.55, 0.58, 0.60)
const WATER_RIM := Color(0.30, 0.31, 0.34)
const WATER_PUDDLE := Color(0.06, 0.07, 0.08)
const REFLECTION := Color(0.04, 0.04, 0.05, 0.78)
const PATH_SHADE := Color(0.18, 0.19, 0.21)
const PATH_GROOVE := Color(0.06, 0.07, 0.08)
const REED := Color(0.18, 0.30, 0.15)
const YARD_BUSH := Color(0.14, 0.26, 0.12)
const YARD_PEG := Color(0.20, 0.18, 0.16)
const PORCH := Color(0.32, 0.33, 0.36)
const PORCH_EDGE := Color(0.18, 0.19, 0.21)
const FLASH_LIT := Color(0.78, 0.80, 0.82)
const SHADOW := Color(0.02, 0.02, 0.03, 0.45)


static func clamp_id(v: int) -> int:
	if v < EMPTY or v >= COUNT:
		return EMPTY
	return v
