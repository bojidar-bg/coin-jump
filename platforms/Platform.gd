tool
extends StaticBody

const shape_cache = {}
const snap = 1

export var size: Vector3 = Vector3(15, 1, 15) setget set_size
onready var mesh_instance := $Mesh as MeshInstance
onready var collision_instance := $Collision as CollisionShape

func _ready():
	update_mesh()

func _land(_side, _stable):
	return true

func set_size(new_size):
	size = new_size
	update_mesh()

func update_mesh():
	if collision_instance != null:
		if shape_cache.get(size) != null and shape_cache.get(size).get_ref() != null:
			collision_instance.shape = shape_cache[size].get_ref()
		else:
			var new_shape = BoxShape.new()
			new_shape.extents = size / 2
			collision_instance.shape = new_shape
			shape_cache[size] = weakref(new_shape)
	if mesh_instance != null:
		mesh_instance.scale = size
