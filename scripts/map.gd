extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collisions_root: CollisionObject2D = $StaticBody2D

var image: Image
var texture: ImageTexture
var collision_cells: Dictionary = {}

const STEP := 4

func _ready():
	image = sprite.texture.get_image()

	texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	rebuild_collision_fast()


func rebuild_collision_fast():
	# Nettoyage
	for c in collision_cells.values():
		if is_instance_valid(c):
			c.queue_free()
	collision_cells.clear()

	var w := image.get_width()
	var h := image.get_height()

	for y in range(0, h, STEP):
		for x in range(0, w, STEP):
			update_cell_collision(x, y)


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


func update_cell_collision(cell_x: int, cell_y: int):
	var key := Vector2i(cell_x, cell_y)
	var has_shape := collision_cells.has(key)
	var solid := is_solid(cell_x, cell_y)

	if solid and not has_shape:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(STEP, STEP)

		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = get_image_origin_offset() + Vector2(cell_x + STEP * 0.5, cell_y + STEP * 0.5)

		collisions_root.add_child(col)
		collision_cells[key] = col
	elif not solid and has_shape:
		var col: CollisionShape2D = collision_cells[key]
		if is_instance_valid(col):
			col.queue_free()
		collision_cells.erase(key)


func update_collisions_in_rect(min_x: int, min_y: int, max_x: int, max_y: int):
	if image.is_empty():
		return

	var w := image.get_width()
	var h := image.get_height()

	var start_x := maxi(0, int(floor(min_x / float(STEP))) * STEP)
	var start_y := maxi(0, int(floor(min_y / float(STEP))) * STEP)
	var end_x := mini(w - 1, int(floor(max_x / float(STEP))) * STEP)
	var end_y := mini(h - 1, int(floor(max_y / float(STEP))) * STEP)

	for y in range(start_y, end_y + 1, STEP):
		for x in range(start_x, end_x + 1, STEP):
			update_cell_collision(x, y)


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
