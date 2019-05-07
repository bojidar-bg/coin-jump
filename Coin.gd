extends RigidBody

const Platform = preload("res://Platform.gd")
export var camera_holder_path := @"../CameraOrigin"
const reset_height = -48.0
const camera_smoothing = 3.0
const camera_rotation_acceleration = PI / 4
const camera_rotation_damp = 0.999
const charging_time = 2.2
const charged_impulse = Vector3(0.0, 18.0, -12.0)
const stable_time = 0.7
var power_level := 0.0
var power_overflow := false
var camera_rotation_velocity := 0.0
var stable_since := 0.0
onready var camera_holder = get_node(camera_holder_path)
onready var heads = $Heads as RayCast
onready var tails = $Tails as RayCast
onready var last_stable_position = global_transform.origin
onready var last_stable_rotation = rotation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_stability()
	update_particles()

func _physics_process(delta: float) -> void:
	var camera_current_pos = camera_holder.global_transform.origin
	camera_holder.global_transform.origin = camera_current_pos.linear_interpolate(
		global_transform.origin,
		delta * camera_smoothing)
	
	var input_rotation = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	camera_rotation_velocity += camera_rotation_acceleration * delta * input_rotation
	camera_holder.global_rotate(Vector3(0, 1, 0), camera_rotation_velocity)
	camera_rotation_velocity *= pow(1 - camera_rotation_damp, delta)
	
	if Input.is_action_pressed("power"):
		if not power_overflow:
			power_level += delta / charging_time
			if power_level > 1.0:
				power_overflow = true
				power_level = 0.0
			update_particles()
	else:
		if not power_overflow and power_level > 0.0:
			var camera_basis = camera_holder.global_transform.basis
			#angular_velocity += Vector3(power_level * charged_angular_velocity, 0, 0)
			apply_impulse(
				camera_basis * Vector3(0, 0, 0.5),
				camera_basis * charged_impulse * power_level
			)
			power_level = 0
			update_particles()
		power_overflow = false
	
	var is_stable = false
	if stable_since > stable_time:
		is_stable = true
	if heads.is_colliding() and heads.get_collider() is Platform and is_pointing_down(heads):
		stable_since += delta
		var collider = heads.get_collider() as Platform
		if collider.mode == 1 and stable_since > stable_time:
			win()
		elif collider.mode == 3:
			die()
	elif tails.is_colliding() and tails.get_collider() is Platform and is_pointing_down(tails):
		stable_since += delta
		var collider = tails.get_collider() as Platform
		if collider.mode == 1 and stable_since > stable_time:
			win()
		elif collider.mode == 2:
			die()
	else:
		stable_since = 0.0
	update_stability()

	if stable_since > stable_time and get_colliding_bodies().size() > 0:
		last_stable_position = global_transform.origin
		last_stable_rotation = rotation
	
	if global_transform.origin.y < reset_height:
		die()

func update_particles():
	var particles := $Particles as Particles
	if power_level == 0:
		particles.emitting = false
	else:
		particles.emitting = true
		var mesh := particles.draw_pass_1 as PrimitiveMesh
		var material := mesh.material as SpatialMaterial
		var grayscale_color := pow(power_level, 0.5)
		material.albedo_color = Color(grayscale_color, grayscale_color, grayscale_color)
		particles.speed_scale = 0.8 + pow(power_level, 0.8)

func update_stability():
	var stability := $StabilityOverlay as MeshInstance
	var material := stability.get_surface_material(0) as ShaderMaterial
	material.set_shader_param("texture_offset", clamp(stable_since / stable_time, 0, 1))
	stability.global_transform.basis = Basis().scaled(stability.global_transform.basis.get_scale())

func is_pointing_down(r: RayCast):
	return r.global_transform.basis.xform(r.cast_to).normalized().dot(Vector3(0, -1, 0)) > 0.7

func die():
	global_transform.origin = last_stable_position
	rotation = last_stable_rotation
	linear_velocity = Vector3()
	angular_velocity = Vector3()

func win():
	get_parent().go_to_next_level()
