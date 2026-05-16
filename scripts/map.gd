extends Node2D

const MarchingSquares = preload("res://scripts/marching_squares.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collisions_root: CollisionObject2D = $StaticBody2D

var image: Image
var texture: ImageTexture
var collision_polygons: Array[CollisionPolygon2D] = []

const STEP := 5
const SAMPLING_GRID_SIZE := 3
const SAMPLING_RADIUS_SCALE := 0.75

func _ready():
	image = sprite.texture.get_image()

	texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	rebuild_collision_fast()


func rebuild_collision_fast():
	var start_usec := Time.get_ticks_usec()

	# Nettoyage
	for c in collision_polygons:
		if is_instance_valid(c):
			c.queue_free()
	collision_polygons.clear()

	var origin := get_image_origin_offset()
	var loops := MarchingSquares.build_loops_from_image_with_sampling(
		image,
		STEP,
		0.5,
		SAMPLING_GRID_SIZE,
		SAMPLING_RADIUS_SCALE
	)

	for loop in loops:
		var col := CollisionPolygon2D.new()
		col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		col.position = origin
		col.polygon = loop
		collisions_root.add_child(col)
		collision_polygons.append(col)

	var elapsed_ms := (Time.get_ticks_usec() - start_usec) / 1000.0
	print("[MapCollision] rebuild=%.3f ms loops=%d polygons=%d" % [elapsed_ms, loops.size(), collision_polygons.size()])


func is_solid(x: int, y: int) -> bool:
	if x < 0 or y < 0:
		return false
	if x >= image.get_width() or y >= image.get_height():
		return false

	return image.get_pixel(x, y).a > 0.5


func get_image_origin_offset() -> Vector2:
	var origin := sprite.offset
	if sprite.centered:
		origin -= Vector2(image.get_width(), image.get_height()) * 0.5
	return origin


func update_collisions_in_rect(_min_x: int, _min_y: int, _max_x: int, _max_y: int):
	rebuild_collision_fast()


func destroy_circle(global_center: Vector2, radius: float):
	var local_center := to_local(global_center) - get_image_origin_offset()
	var min_x := int(floor(local_center.x - radius))
	var max_x := int(ceil(local_center.x + radius))
	var min_y := int(floor(local_center.y - radius))
	var max_y := int(ceil(local_center.y + radius))

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if x < 0 or y < 0:
				continue
			if x >= image.get_width():
				continue
			if y >= image.get_height():
				continue
			var dist = Vector2(x, y).distance_to(local_center)
			if dist <= radius:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	texture.update(image)
	update_collisions_in_rect(min_x, min_y, max_x, max_y)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			destroy_circle(get_global_mouse_position(), 32.0)
