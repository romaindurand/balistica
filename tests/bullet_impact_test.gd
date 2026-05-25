extends SceneTree

const BulletScene := preload("res://scenes/bullet.tscn")


class FakeMap:
	extends Node2D

	var destroyed_centers: Array[Vector2] = []
	var destroyed_radii: Array[float] = []

	func destroy_circle(global_center: Vector2, radius: float) -> void:
		destroyed_centers.append(global_center)
		destroyed_radii.append(radius)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := FakeMap.new()
	var map_body := StaticBody2D.new()
	map.add_child(map_body)

	var bullet := BulletScene.instantiate()
	bullet.global_position = Vector2(12.0, 34.0)
	bullet.explosion_radius = 24.0

	root.add_child(map)
	root.add_child(bullet)

	bullet._on_body_entered(map_body)

	if not _expect(bullet.is_queued_for_deletion(), "bullet should be queued for deletion after impact"):
		return

	await process_frame

	if not _expect(map.destroyed_centers.size() == 1, "map should receive exactly one destruction center"):
		return
	if not _expect(map.destroyed_centers[0] == Vector2(12.0, 34.0), "destruction center should match bullet position"):
		return
	if not _expect(map.destroyed_radii.size() == 1, "map should receive exactly one destruction radius"):
		return
	if not _expect(map.destroyed_radii[0] == 24.0, "destruction radius should match bullet explosion radius"):
		return

	quit(0)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true

	printerr("TEST FAILED: %s" % message)
	quit(1)
	return false
