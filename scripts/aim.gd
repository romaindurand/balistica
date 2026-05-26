extends Node2D


const DEFAULT_LINE_LENGTH := 40.0


@export var aim_line_length: float = DEFAULT_LINE_LENGTH
@export var min_custom_angle_degrees: float = -20.0
@export var max_custom_angle_degrees: float = 20.0

@onready var upper_limit_line: Line2D = $UpperLimit
@onready var lower_limit_line: Line2D = $LowerLimit
@onready var current_aim_line: Line2D = $CurrentAim


var _upper_limit_origin: Vector2 = Vector2.ZERO
var _lower_limit_origin: Vector2 = Vector2.ZERO
var _current_aim_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	_upper_limit_origin = _get_line_origin(upper_limit_line)
	_lower_limit_origin = _get_line_origin(lower_limit_line)
	_current_aim_origin = _get_line_origin(current_aim_line)
	update_aim_angles(0.0, 0.0, 20.0, true)


func update_aim_angles(
	vehicle_angle_degrees: float,
	current_angle_degrees: float,
	_max_custom_angle_degrees: float,
	facing_right: bool
) -> void:
	var custom_angle_degrees: float = current_angle_degrees - vehicle_angle_degrees
	_redraw_line(
		upper_limit_line,
		_upper_limit_origin,
		aim_line_length,
		max_custom_angle_degrees,
		facing_right
	)
	_redraw_line(
		lower_limit_line,
		_lower_limit_origin,
		aim_line_length,
		min_custom_angle_degrees,
		facing_right
	)
	_redraw_line(
		current_aim_line,
		_current_aim_origin,
		aim_line_length,
		custom_angle_degrees,
		facing_right
	)


func _redraw_line(
	line: Line2D,
	origin: Vector2,
	length: float,
	angle_degrees: float,
	facing_right: bool
) -> void:
	var base_direction: Vector2 = Vector2.RIGHT if facing_right else Vector2.LEFT
	var visual_angle_degrees: float = -angle_degrees if facing_right else angle_degrees
	var direction: Vector2 = base_direction.rotated(deg_to_rad(visual_angle_degrees))
	line.points = PackedVector2Array([
		origin,
		origin + direction * length,
	])


func _get_line_origin(line: Line2D) -> Vector2:
	if line.points.size() > 0:
		return line.points[0]
	return Vector2.ZERO
