extends Control


const DEFAULT_LINE_LENGTH := 23.0


@onready var angle_line: Line2D = $Panel/Angle
@onready var angle_label: Label = $Panel/Label


var _line_origin: Vector2 = Vector2.ZERO
var _line_length: float = DEFAULT_LINE_LENGTH


func _ready() -> void:
	if angle_line.points.size() > 0:
		_line_origin = angle_line.points[0]
	if angle_line.points.size() > 1:
		_line_length = _line_origin.distance_to(angle_line.points[1])
	update_player_angle(0.0, true)


func update_player_angle(angle_degrees: float, facing_right: bool) -> void:
	var base_direction: Vector2 = Vector2.RIGHT if facing_right else Vector2.LEFT
	var visual_angle_degrees: float = -angle_degrees if facing_right else angle_degrees
	var direction: Vector2 = base_direction.rotated(deg_to_rad(visual_angle_degrees))
	angle_line.points = PackedVector2Array([
		_line_origin,
		_line_origin + direction * _line_length,
	])
	angle_label.text = "%d°" % int(round(angle_degrees))