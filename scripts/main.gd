extends Control

@onready var board: Board = $Board
@onready var palette: Palette = $Palette


func _ready() -> void:
	board.bind_palette(palette)
