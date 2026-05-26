extends RigidBody2D


signal angle_changed(angle_degrees: float, facing_right: bool)
signal aim_angles_changed(
	vehicle_angle_degrees: float,
	current_angle_degrees: float,
	max_custom_angle_degrees: float,
	facing_right: bool
)

const DEFAULT_SUSPENSION_STIFFNESS := 90.0
const DEFAULT_SUSPENSION_DAMPING := 9.0
const DEFAULT_MAX_SUSPENSION_FORCE := 200.0


@export_group("Wheels")
@export var wheel_assembly_prefix: String = "WheelAssembly"
@export var wheel_node_name: String = "Wheel"
@export var wheel_target_angular_speed: float = 30.0
@export var wheel_motor_torque: float = 7000.0
@export var wheel_max_motor_torque: float = 7000.0
@export var wheel_direction: float = 1.0
@export var freeze_hull_without_input: bool = true
@export var hull_freeze_delay: float = 0.5
@export var min_grounded_wheels_to_freeze: int = 2
@export var wheel_idle_brake_enabled: bool = true
@export var wheel_idle_brake_torque: float = 2000.0
@export var map_collision_wheel_wake_size: Vector2 = Vector2(24.0, 24.0)

@export_group("Aim")
@export var aim_angle_adjustment_speed: float = 45.0
@export var max_custom_aim_angle_degrees: float = 20.0

@export_group("Hull")
@export var hull_angular_damp_when_grounded: float = 20.0

var _wheels: Array[RigidBody2D] = []
var _wheel_rest_positions: Dictionary = {}
var _wheel_assemblies_by_wheel: Dictionary = {}
var _idle_time: float = 0.0
var _hull_frozen: bool = false
var _facing_right: bool = true
var custom_aim_angle_degrees: float = 0.0


func _ready() -> void:
	_collect_wheels()
	_facing_right = not $Sprite2D.flip_h
	call_deferred("_connect_destructible_maps")
	call_deferred("_emit_current_angle")


func _physics_process(delta: float) -> void:
	if _wheels.is_empty():
		_collect_wheels()


	_update_custom_aim_angle(delta)

	var input_axis: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(input_axis):
		_facing_right = input_axis > 0.0
	$Sprite2D.flip_h = not _facing_right
	var target_speed: float = input_axis * wheel_target_angular_speed * wheel_direction
	var has_input: bool = not is_zero_approx(input_axis)
	var grounded_wheel_count: int = _get_grounded_wheel_count()
	var can_freeze_hull: bool = grounded_wheel_count >= min_grounded_wheels_to_freeze
	if has_input:
		_idle_time = 0.0
		if _hull_frozen:
			_set_hull_frozen(false)
	elif can_freeze_hull:
		_idle_time += delta
	else:
		_idle_time = 0.0

	var should_freeze_hull: bool = freeze_hull_without_input and not has_input and can_freeze_hull and _idle_time >= hull_freeze_delay
	var idle_brake_ratio: float = clampf(_idle_time / maxf(hull_freeze_delay, 0.001), 0.0, 1.0)
	if should_freeze_hull and not _hull_frozen:
		_set_hull_frozen(true)

	for wheel in _wheels:
		if has_input:
			var speed_error: float = target_speed - wheel.angular_velocity
			var torque: float = clampf(speed_error * wheel_motor_torque, -wheel_max_motor_torque, wheel_max_motor_torque)
			wheel.apply_torque(torque)
		elif wheel_idle_brake_enabled:
			var brake_torque: float = -wheel.angular_velocity * wheel_idle_brake_torque * idle_brake_ratio
			wheel.apply_torque(brake_torque)
		if not _hull_frozen and _is_wheel_suspension_enabled(wheel):
			_apply_wheel_suspension(wheel)

	angular_damp = hull_angular_damp_when_grounded
	_emit_current_angle()


func _collect_wheels() -> void:
	_wheels.clear()
	_wheel_rest_positions.clear()
	_wheel_assemblies_by_wheel.clear()
	for child in get_children():
		if child is Node2D and child.name.begins_with(wheel_assembly_prefix):
			var assembly: Node2D = child as Node2D
			var wheel: RigidBody2D = null
			if assembly.has_method("get_wheel"):
				wheel = assembly.call("get_wheel") as RigidBody2D
			else:
				wheel = assembly.get_node_or_null(wheel_node_name) as RigidBody2D
			if wheel == null:
				push_warning("%s is missing a RigidBody2D child named %s" % [assembly.name, wheel_node_name])
				continue
			_wheels.append(wheel)
			_wheel_rest_positions[wheel] = to_local(wheel.global_position)
			_wheel_assemblies_by_wheel[wheel] = assembly
	_wheels.sort_custom(func(a: RigidBody2D, b: RigidBody2D) -> bool: return str(a.get_path()).naturalnocasecmp_to(str(b.get_path())) < 0)


func _set_hull_frozen(value: bool) -> void:
	_hull_frozen = value
	if value:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		for wheel in _wheels:
			wheel.linear_velocity = Vector2.ZERO
			wheel.angular_velocity = 0.0
	freeze = value


func _connect_destructible_maps() -> void:
	var callback := Callable(self, "_on_map_collisions_changed")
	for map in get_tree().get_nodes_in_group("destructible_maps"):
		if map.has_signal(&"collisions_changed") and not map.is_connected(&"collisions_changed", callback):
			map.connect(&"collisions_changed", callback)


func _on_map_collisions_changed(changed_global_rect: Rect2) -> void:
	if not _hull_frozen:
		return
	if not _changed_rect_overlaps_wheel_support(changed_global_rect):
		return

	_idle_time = 0.0
	_set_hull_frozen(false)


func _changed_rect_overlaps_wheel_support(changed_global_rect: Rect2) -> bool:
	if _wheels.is_empty():
		_collect_wheels()

	for wheel in _wheels:
		if is_instance_valid(wheel) and changed_global_rect.intersects(_get_wheel_collision_wake_rect(wheel)):
			return true
	return false


func _get_wheel_collision_wake_rect(wheel: RigidBody2D) -> Rect2:
	return Rect2(wheel.global_position - map_collision_wheel_wake_size * 0.5, map_collision_wheel_wake_size)


func _get_grounded_wheel_count() -> int:
	var grounded_count: int = 0
	for wheel in _wheels:
		if _is_wheel_grounded(wheel):
			grounded_count += 1
	return grounded_count


func _is_wheel_grounded(wheel: RigidBody2D) -> bool:
	return wheel.get_colliding_bodies().size() > 0


func _apply_wheel_suspension(wheel: RigidBody2D) -> void:
	if not _wheel_rest_positions.has(wheel):
		return

	var rest_position: Vector2 = _wheel_rest_positions[wheel]
	var assembly: Node = _wheel_assemblies_by_wheel.get(wheel) as Node
	var stiffness: float = _get_float_setting(assembly, &"suspension_stiffness", DEFAULT_SUSPENSION_STIFFNESS)
	var damping: float = _get_float_setting(assembly, &"suspension_damping", DEFAULT_SUSPENSION_DAMPING)
	var max_force: float = _get_float_setting(assembly, &"max_suspension_force", DEFAULT_MAX_SUSPENSION_FORCE)
	var current_position: Vector2 = to_local(wheel.global_position)
	var compression: float = rest_position.y - current_position.y
	var relative_velocity: Vector2 = wheel.linear_velocity - linear_velocity
	var local_relative_velocity: Vector2 = global_transform.basis_xform_inv(relative_velocity)
	var force_amount: float = compression * stiffness - local_relative_velocity.y * damping
	force_amount = clampf(force_amount, -max_force, max_force)

	var force: Vector2 = global_transform.y * force_amount
	wheel.apply_central_force(force)
	apply_force(-force, wheel.global_position - global_position)


func _is_wheel_suspension_enabled(wheel: RigidBody2D) -> bool:
	var assembly: Node = _wheel_assemblies_by_wheel.get(wheel) as Node
	if assembly == null:
		return false
	return bool(assembly.get(&"suspension_enabled"))


func _get_float_setting(source: Node, property_name: StringName, fallback: float) -> float:
	if source == null:
		return fallback

	var value: Variant = source.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func is_facing_right() -> bool:
	return _facing_right


func get_signed_aim_angle_degrees() -> float:
	var reference_direction: Vector2 = Vector2.RIGHT if _facing_right else Vector2.LEFT
	var forward_direction: Vector2 = global_transform.x if _facing_right else -global_transform.x
	var signed_angle: float = rad_to_deg(reference_direction.angle_to(forward_direction))
	if _facing_right:
		signed_angle = -signed_angle
	return signed_angle


func get_total_aim_angle_degrees() -> float:
	return get_signed_aim_angle_degrees() + custom_aim_angle_degrees


func _update_custom_aim_angle(delta: float) -> void:
	var aim_axis: float = Input.get_axis("aim_down", "aim_up")
	if is_zero_approx(aim_axis):
		return

	var aim_limits := _get_custom_aim_angle_limits()
	custom_aim_angle_degrees = clampf(
		custom_aim_angle_degrees + aim_axis * aim_angle_adjustment_speed * delta,
		aim_limits.x,
		aim_limits.y
	)


func _get_custom_aim_angle_limits() -> Vector2:
	var fallback_max_angle := absf(max_custom_aim_angle_degrees)
	var min_angle := -fallback_max_angle
	var max_angle := fallback_max_angle
	var aim_node := get_node_or_null("Aim")

	if aim_node != null:
		var min_value: Variant = aim_node.get(&"min_custom_angle_degrees")
		var max_value: Variant = aim_node.get(&"max_custom_angle_degrees")
		if typeof(min_value) == TYPE_FLOAT or typeof(min_value) == TYPE_INT:
			min_angle = float(min_value)
		if typeof(max_value) == TYPE_FLOAT or typeof(max_value) == TYPE_INT:
			max_angle = float(max_value)

	if min_angle > max_angle:
		var swap := min_angle
		min_angle = max_angle
		max_angle = swap

	return Vector2(min_angle, max_angle)


func _emit_current_angle() -> void:
	var vehicle_angle_degrees: float = get_signed_aim_angle_degrees()
	var current_angle_degrees: float = vehicle_angle_degrees + custom_aim_angle_degrees
	var aim_limits := _get_custom_aim_angle_limits()
	var max_custom_angle_degrees: float = maxf(absf(aim_limits.x), absf(aim_limits.y))
	angle_changed.emit(current_angle_degrees, _facing_right)
	aim_angles_changed.emit(
		vehicle_angle_degrees,
		current_angle_degrees,
		max_custom_angle_degrees,
		_facing_right
	)
