class_name TileType
extends RefCounted

# Пустая клетка — земля с толщиной, не тип в руке.
const EMPTY := 0
const HOUSE := 1
const ROAD := 2
const TREE := 3
const WATER := 4
const COUNT := 5

# Двор на воздухе: трава/земля, не схема и не серый слот.
const SKY_TOP := Color(0.62, 0.78, 0.88)
const SKY_BOT := Color(0.78, 0.86, 0.72)
const EARTH_TOP := Color(0.42, 0.58, 0.30)
const EARTH_TOP_ALT := Color(0.38, 0.54, 0.28)
const EARTH_LEFT := Color(0.36, 0.42, 0.22)
const EARTH_RIGHT := Color(0.28, 0.34, 0.18)
const EARTH_EDGE := Color(0.32, 0.46, 0.24)

# Дом — тёплый объём со стенами и крышей.
const WALL_FRONT := Color(0.86, 0.72, 0.52)
const WALL_SIDE := Color(0.72, 0.58, 0.40)
const WALL_DARK := Color(0.58, 0.44, 0.30)
const ROOF_LIT := Color(0.78, 0.42, 0.28)
const ROOF_SHADE := Color(0.58, 0.30, 0.20)
const ROOF_RIDGE := Color(0.42, 0.20, 0.14)
const DOOR := Color(0.40, 0.26, 0.14)
const DOOR_EDGE := Color(0.28, 0.16, 0.08)
const WINDOW := Color(0.55, 0.78, 0.90)
const WINDOW_FRAME := Color(0.34, 0.24, 0.14)
const CHIMNEY := Color(0.48, 0.34, 0.28)
const CHIMNEY_TOP := Color(0.34, 0.24, 0.20)

# Совместимость со старыми именами (стол → земля).
const TABLE := EARTH_TOP
const TABLE_RECESS := EARTH_LEFT
const TABLE_RIDGE := EARTH_EDGE
const TABLE_GRAIN := Color(0.34, 0.48, 0.24)
const TABLE_EDGE := EARTH_RIGHT
const WOOD_PALE := WALL_FRONT
const WOOD_LIGHT := WALL_SIDE
const WOOD_MID := WALL_DARK
const WOOD_DARK := DOOR
const WOOD_RIDGE := ROOF_RIDGE
const WOOD_ROOF := ROOF_LIT
const WOOD_ROOF_EDGE := ROOF_SHADE
const GRASS := EARTH_TOP
const GRASS_FIBER := TABLE_GRAIN
const GRASS_ALT := EARTH_TOP_ALT
const GRASS_SEAM := EARTH_EDGE

const ROAD_COL := Color(0.58, 0.52, 0.44)
const ROAD_LIT := Color(0.68, 0.62, 0.52)
const ROAD_SHADE := Color(0.42, 0.38, 0.32)
const ROAD_GROOVE := Color(0.34, 0.30, 0.26)
const TREE_TRUNK := Color(0.48, 0.32, 0.18)
const TREE_TRUNK_DARK := Color(0.34, 0.22, 0.12)
const TREE_CROWN := Color(0.24, 0.50, 0.22)
const TREE_CROWN_MID := Color(0.18, 0.40, 0.18)
const TREE_CROWN_HI := Color(0.40, 0.62, 0.30)
const BUSH := Color(0.22, 0.44, 0.20)
const MUSHROOM_CAP := Color(0.78, 0.28, 0.22)
const MUSHROOM_STEM := Color(0.88, 0.82, 0.70)
const WATER_COL := Color(0.16, 0.42, 0.58)
const WATER_DEEP := Color(0.08, 0.24, 0.36)
const WATER_GLOSS := Color(0.72, 0.90, 0.96)
const WATER_RIM := Color(0.22, 0.40, 0.36)
const WATER_PUDDLE := Color(0.14, 0.38, 0.52)
const LILY_PAD := Color(0.28, 0.52, 0.24)
const LILY_FLOWER := Color(0.92, 0.88, 0.92)
const DUCK_BODY := Color(0.82, 0.62, 0.18)
const DUCK_HEAD := Color(0.18, 0.28, 0.22)
const DUCK_BILL := Color(0.86, 0.48, 0.16)
const PERSON_SKIN := Color(0.90, 0.72, 0.55)
const PERSON_CLOTH_A := Color(0.42, 0.48, 0.62)
const PERSON_CLOTH_B := Color(0.62, 0.38, 0.32)
const PERSON_CLOTH_C := Color(0.36, 0.52, 0.40)
const PERSON_CLOTH_D := Color(0.55, 0.45, 0.30)
const REFLECTION := Color(0.12, 0.10, 0.08, 0.55)
const PATH_SHADE := Color(0.40, 0.36, 0.30)
const PATH_GROOVE := Color(0.28, 0.24, 0.20)
const REED := Color(0.34, 0.48, 0.22)
const YARD_BUSH := Color(0.26, 0.48, 0.22)
const YARD_PEG := Color(0.46, 0.32, 0.16)
const PORCH := Color(0.72, 0.58, 0.40)
const PORCH_EDGE := Color(0.48, 0.34, 0.22)
const FLASH_LIT := Color(1.0, 0.94, 0.48)
const SHADOW := Color(0.08, 0.10, 0.06, 0.28)
const PALETTE_SHELF := Color(0.34, 0.40, 0.28)
const PALETTE_WELL := Color(0.26, 0.32, 0.20)


static func clamp_id(v: int) -> int:
	if v < EMPTY or v >= COUNT:
		return EMPTY
	return v


static func person_cloth(i: int) -> Color:
	match i % 4:
		0:
			return PERSON_CLOTH_A
		1:
			return PERSON_CLOTH_B
		2:
			return PERSON_CLOTH_C
		_:
			return PERSON_CLOTH_D
