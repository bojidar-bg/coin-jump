extends RigidBody

const Platform = preload("res://Platform.gd")
export var camera_holder_path := @"../CameraOrigin"
export var shadow_path := @"../Shadow"
export var power_bar_path := @"../PowerProgress"
export var power_bar_fill_path := @"../PowerProgress/PowerFill"
const reset_height = -48.0
const camera_smoothing = 3.0
const camera_rotation_vertical_limit = PI * 1 / 3
const camera_rotation_sustain = Vector2(9.0, 4.0)
const camera_rotation_attack = 0.25
const camera_rotation_release = 0.1
const mouse_rotation_sensitivity = Vector2(0.01, 0.005)
const charge_hold_time = 0.6
const charging_time = 2.0
const charged_impulse = Vector3(0.0, 18.0, -12.0)
const stable_time = 0.7
const max_zoom_distance = 20.0
const zoom_easing = -1
var power_level := 0.0
var power_overflow := false
var camera_rotation_speed := Vector2(0.0, 0.0)
var camera_rotation := Vector2(0.0, deg2rad(-28.559))
var mouse_rotation_input := 0.0
var camera_rotation_target = null
var stable_since := 0.0
onready var camera_holder := get_node(camera_holder_path) as Spatial
onready var shadow := get_node(shadow_path) as Spatial
onready var power_bar := get_node(power_bar_path) as Control
onready var power_bar_fill := get_node(power_bar_fill_path) as Control
onready var heads := $Heads as RayCast
onready var tails := $Tails as RayCast
onready var last_stable_position := global_transform.origin
onready var last_stable_rotation := rotation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not OS.has_meta("_started"):
		OS.set_meta("_started", true)
		OS.window_maximized = true
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("turn_back"):
		camera_rotation_target = camera_rotation.x + PI * sign(randf() - 0.5)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation -= event.relative * mouse_rotation_sensitivity
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("release_mouse") or event.is_action_pressed("turn_left") or event.is_action_pressed("turn_right"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("respawn"):
		yield(get_tree(), "physics_frame")
		die()

func _physics_process(delta: float) -> void:
	camera_holder.translation = camera_holder.translation.linear_interpolate(
		translation,
		delta * camera_smoothing)
	camera_holder.scale = Vector3(1, 1, 1) * (1 + ease(camera_holder.translation.distance_to(translation) / max_zoom_distance, zoom_easing))
	
	var input := Vector2(
		Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right"),
		Input.get_action_strength("turn_down") - Input.get_action_strength("turn_up")
	)
	
	if camera_rotation_target != null:
		input.x += 0.1 * sign(camera_rotation_target - camera_rotation.x)
		if abs(camera_rotation_target - camera_rotation.x) < abs(camera_rotation_speed.x * camera_rotation_release / 2):
			camera_rotation_target = null
		
	var decel = camera_rotation_sustain / camera_rotation_release * delta
	var accel = camera_rotation_sustain / camera_rotation_attack * delta
	
	if input.x == 0:
		camera_rotation_speed.x += clamp(-camera_rotation_speed.x, -decel.x, decel.x)
	else:
		camera_rotation_speed.x = clamp(camera_rotation_speed.x + accel.x * sign(input.x), -camera_rotation_sustain.x, camera_rotation_sustain.x)
	
	if input.y == 0:
		camera_rotation_speed.y += clamp(-camera_rotation_speed.y, -decel.y, decel.y)
	else:
		camera_rotation_speed.y = clamp(camera_rotation_speed.y + accel.y * sign(input.y), -camera_rotation_sustain.y, camera_rotation_sustain.y)
	
	camera_rotation += camera_rotation_speed * delta
	camera_rotation.y = clamp(camera_rotation.y, -camera_rotation_vertical_limit, camera_rotation_vertical_limit)
	camera_holder.rotation = Vector3(camera_rotation.y, camera_rotation.x, 0)
	
	if Input.is_action_pressed("power"):
		if not power_overflow:
			power_level += delta / charging_time
			if power_level > 1.0 + charge_hold_time / charging_time:
				power_overflow = true
				power_level = 0.0
			update_power()
	else:
		if not power_overflow and power_level > 0.0:
			var camera_basis = Basis().rotated(Vector3.UP, camera_rotation.x)
			#angular_velocity += Vector3(power_level * charged_angular_velocity, 0, 0)
			apply_impulse(
				camera_basis * Vector3(0, 0, 0.5),
				camera_basis * charged_impulse * clamp(power_level, 0, 1)
			)
			power_level = 0
			update_power()
		power_overflow = false
	
	var is_stable = false
	if stable_since > stable_time:
		is_stable = true
	if heads.is_colliding() and is_pointing_down(heads):
		stable_since += delta
		if heads.get_collider() is Platform:
			var collider = heads.get_collider() as Platform
			if collider.mode == 1 and stable_since > stable_time:
				win()
			elif collider.mode == 3:
				die()
	elif tails.is_colliding() and is_pointing_down(tails):
		stable_since += delta
		if tails.get_collider() is Platform:
			var collider = tails.get_collider() as Platform
			if collider.mode == 1 and stable_since > stable_time:
				win()
			elif collider.mode == 2:
				die()
	else:
		stable_since = 0.0
	update_stability_and_shadow()

	if stable_since > stable_time and get_colliding_bodies().size() > 0:
		last_stable_position = global_transform.origin
		last_stable_rotation = rotation
	
	if global_transform.origin.y < reset_height:
		die()

func update_power():
	var particles := $Particles as Particles
	if power_level <= 0:
		power_bar.visible = false
		particles.emitting = false
	else:
		power_bar.visible = true
		power_bar.modulate.a = pow(clamp(power_level, 0, 1), 0.2)
		power_bar_fill.anchor_right = clamp(power_level, 0, 1)
		power_bar_fill.anchor_left = clamp((power_level - 1) / (charge_hold_time / charging_time), 0, 1)
		
		particles.emitting = true
		var mesh := particles.draw_pass_1 as PrimitiveMesh
		var material := mesh.material as SpatialMaterial
		var grayscale_color := pow(clamp(power_level, 0, 1), 0.2)
		material.albedo_color = Color(grayscale_color, grayscale_color, grayscale_color)
		particles.speed_scale = 0.8 + pow(clamp(power_level, 0, 1), 0.8)
		particles.process_material.scale = 0.6 + pow(clamp(power_level, 0, 1), 0.3) * 0.4

func update_stability_and_shadow():
	var shadow_ray = Vector3(0, -100, 0)
	var result = get_world().direct_space_state.intersect_ray(global_transform.origin, global_transform.origin + shadow_ray, [self], collision_mask, true, false)
	var ray_basis = Basis()
	
	if not result.empty():
		shadow.global_transform.origin = result.position + Vector3(0, 0.01, 0)
		var x = result.normal.cross(Vector3.FORWARD)
		var z = result.normal.cross(Vector3.LEFT)
		ray_basis = Basis(x.normalized(), result.normal, z.normalized())
	else:
		shadow.global_transform.origin = global_transform.origin + shadow_ray
	
	var stability := $StabilityOverlay as MeshInstance
	var material := stability.get_surface_material(0) as ShaderMaterial
	material.set_shader_param("texture_offset", clamp(stable_since / stable_time, 0, 1))
	stability.visible = stable_since > 0
	
	shadow.global_transform.basis = ray_basis
	stability.global_transform.basis = ray_basis

func is_pointing_down(r: RayCast):
	return r.global_transform.basis.xform(r.cast_to).normalized().dot(Vector3(0, -1, 0)) > 0.7

func die():
	global_transform.origin = last_stable_position
	rotation = last_stable_rotation
	linear_velocity = Vector3()
	angular_velocity = Vector3()
	power_level = 0.0
	stable_since = stable_time
	update_power()
	update_stability_and_shadow()

func win():
	get_parent().go_to_next_level()
