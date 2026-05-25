extends Node2D

const MarchingSquaresScene = preload("res://scripts/marching_squares.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collisions_root: CollisionObject2D = $StaticBody2D

var image: Image
var texture: ImageTexture
var collision_polygons: Array[CollisionPolygon2D] = []
var collision_chunks: Dictionary = {}

const STEP := 5
const COLLISION_CHUNK_SIZE := 128
const COLLISION_CHUNK_MARGIN := STEP * 2
const SAMPLING_GRID_SIZE := 3
const SAMPLING_RADIUS_SCALE := 0.75

func _ready():
	image = sprite.texture.get_image()

	texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	rebuild_collision_fast()


func rebuild_collision_fast():
	_clear_all_collision_polygons()

	var max_chunk_x := int(ceil(image.get_width() / float(COLLISION_CHUNK_SIZE))) - 1
	var max_chunk_y := int(ceil(image.get_height() / float(COLLISION_CHUNK_SIZE))) - 1

	for chunk_y in range(max_chunk_y + 1):
		for chunk_x in range(max_chunk_x + 1):
			_rebuild_collision_chunk(Vector2i(chunk_x, chunk_y))


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
	var chunk_min := _image_position_to_chunk(Vector2i(_min_x - COLLISION_CHUNK_MARGIN, _min_y - COLLISION_CHUNK_MARGIN))
	var chunk_max := _image_position_to_chunk(Vector2i(_max_x + COLLISION_CHUNK_MARGIN, _max_y + COLLISION_CHUNK_MARGIN))
	var max_chunk := _image_position_to_chunk(Vector2i(image.get_width() - 1, image.get_height() - 1))
	chunk_min = Vector2i(clampi(chunk_min.x, 0, max_chunk.x), clampi(chunk_min.y, 0, max_chunk.y))
	chunk_max = Vector2i(clampi(chunk_max.x, 0, max_chunk.x), clampi(chunk_max.y, 0, max_chunk.y))

	for chunk_y in range(chunk_min.y, chunk_max.y + 1):
		for chunk_x in range(chunk_min.x, chunk_max.x + 1):
			_rebuild_collision_chunk(Vector2i(chunk_x, chunk_y))


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


func _clear_all_collision_polygons():
	for c in collision_polygons:
		if is_instance_valid(c):
			c.queue_free()
	collision_polygons.clear()
	collision_chunks.clear()


func _image_position_to_chunk(image_position: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(image_position.x / float(COLLISION_CHUNK_SIZE))),
		int(floor(image_position.y / float(COLLISION_CHUNK_SIZE)))
	)


func _get_chunk_sample_rect(chunk: Vector2i) -> Rect2i:
	var chunk_origin := chunk * COLLISION_CHUNK_SIZE
	var min_x := clampi(chunk_origin.x - COLLISION_CHUNK_MARGIN, 0, image.get_width())
	var min_y := clampi(chunk_origin.y - COLLISION_CHUNK_MARGIN, 0, image.get_height())
	var max_x := clampi(chunk_origin.x + COLLISION_CHUNK_SIZE + COLLISION_CHUNK_MARGIN, 0, image.get_width())
	var max_y := clampi(chunk_origin.y + COLLISION_CHUNK_SIZE + COLLISION_CHUNK_MARGIN, 0, image.get_height())
	return Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)


func _remove_collision_chunk(chunk: Vector2i):
	if not collision_chunks.has(chunk):
		return

	var chunk_polygons: Array = collision_chunks[chunk]
	for col in chunk_polygons:
		collision_polygons.erase(col)
		if is_instance_valid(col):
			col.queue_free()
	collision_chunks.erase(chunk)


func _rebuild_collision_chunk(chunk: Vector2i):
	_remove_collision_chunk(chunk)

	var sample_rect := _get_chunk_sample_rect(chunk)
	if sample_rect.size.x <= 0 or sample_rect.size.y <= 0:
		collision_chunks[chunk] = []
		return

	var chunk_image := image.get_region(sample_rect)
	var loops := MarchingSquaresScene.build_loops_from_image_with_sampling(
		chunk_image,
		STEP,
		0.5,
		SAMPLING_GRID_SIZE,
		SAMPLING_RADIUS_SCALE
	)

	var origin := get_image_origin_offset() + Vector2(sample_rect.position)
	var chunk_polygons: Array[CollisionPolygon2D] = []
	for loop in loops:
		var col := CollisionPolygon2D.new()
		col.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		col.position = origin
		col.polygon = loop
		collisions_root.add_child(col)
		collision_polygons.append(col)
		chunk_polygons.append(col)
	collision_chunks[chunk] = chunk_polygons

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			destroy_circle(get_global_mouse_position(), 32.0)
