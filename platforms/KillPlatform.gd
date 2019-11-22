tool
extends "res://platforms/Platform.gd"

export(int, "Head", "Tail", "Any") var mode: int = 0 setget set_mode
export var head_material: Material
export var tail_material: Material
export var kill_material: Material

func _ready():
	set_mode(mode)

func _land(side, _stable):
	if side != mode:
		return false
	return true

func set_mode(new_mode):
	mode = new_mode
	if mesh_instance != null:
		match mode:
			0: mesh_instance.set_surface_material(0, head_material)
			1: mesh_instance.set_surface_material(0, tail_material)
			2: mesh_instance.set_surface_material(0, kill_material)
