tool
extends StaticBody

export(int, "Normal", "Goal", "Head", "Tail") var mode: int = 0 setget set_mode
export var normal_material: Material
export var goal_material: Material
export var head_material: Material
export var tail_material: Material
onready var mesh := $Mesh as MeshInstance

func _ready():
	set_mode(mode)

func set_mode(new_mode):
	mode = new_mode
	if mesh != null:
		match mode:
			0: mesh.set_surface_material(0, normal_material)
			1: mesh.set_surface_material(0, goal_material)
			2: mesh.set_surface_material(0, head_material)
			3: mesh.set_surface_material(0, tail_material)
		
