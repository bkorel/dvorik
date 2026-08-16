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
const TABLE := Color(0.26, 0.27, 0.30)
const TABLE_RECESS := Color(0.10, 0.11, 0.13)
const TABLE_RIDGE := Color(0.36, 0.37, 0.40)
const TABLE_GRAIN := Color(0.20, 0.21, 0.24)
const TABLE_EDGE := Color(0.16, 0.17, 0.19)
const STONE_PALE := Color(0.52, 0.53, 0.56)
const STONE_LIGHT := Color(0.44, 0.45, 0.48)
const STONE_MID := Color(0.38, 0.39, 0.42)
const STONE_DARK := Color(0.22, 0.23, 0.26)
const STONE_FACE := Color(0.46, 0.47, 0.50)
const ROOF_SLAB := Color(0.12, 0.13, 0.15)
const ROOF_EDGE := Color(0.07, 0.08, 0.09)
const ROOF_SHEEN := Color(0.28, 0.29, 0.32)
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
const ROAD_COL := Color(0.32, 0.33, 0.36)
const ROAD_GROOVE := Color(0.08, 0.09, 0.11)
const ROAD_SEAM := Color(0.18, 0.19, 0.22)
const TREE_TRUNK := Color(0.18, 0.15, 0.12)
const TREE_CROWN := Color(0.18, 0.34, 0.16)
const TREE_CROWN_HI := Color(0.28, 0.44, 0.22)
const TREE_CROWN_LO := Color(0.12, 0.22, 0.10)
const WATER_COL := Color(0.04, 0.045, 0.05)
const WATER_DEEP := Color(0.015, 0.015, 0.02)
const WATER_GLOSS := Color(0.62, 0.64, 0.66)
const WATER_RIM := Color(0.40, 0.41, 0.44)
const WATER_PUDDLE := Color(0.05, 0.055, 0.06)
const REFLECTION := Color(0.03, 0.03, 0.04, 0.78)
const PATH_SHADE := Color(0.24, 0.25, 0.27)
const PATH_GROOVE := Color(0.06, 0.07, 0.08)
const REED := Color(0.20, 0.34, 0.16)
const YARD_BUSH := Color(0.16, 0.30, 0.14)
const YARD_PEG := Color(0.24, 0.20, 0.16)
const PORCH := Color(0.42, 0.43, 0.46)
const PORCH_EDGE := Color(0.22, 0.23, 0.26)
const FLASH_LIT := Color(0.82, 0.84, 0.86)
const SHADOW := Color(0.02, 0.02, 0.03, 0.50)


static func clamp_id(v: int) -> int:
	if v < EMPTY or v >= COUNT:
		return EMPTY
	return v
