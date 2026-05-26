extends SceneTree

const AimScene := preload("res://scenes/aim.tscn")
const PlayerScene := preload("res://scenes/player.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _test_aim_exposes_custom_min_and_max_angles():
		return
	if not await _test_player_uses_aim_instance_angle_limits():
		return

	quit(0)


func _test_aim_exposes_custom_min_and_max_angles() -> bool:
	var aim := AimScene.instantiate()
	root.add_child(aim)
	await process_frame

	if not _expect(aim.get("min_custom_angle_degrees") != null, "Aim should expose min_custom_angle_degrees"):
		return false
	if not _expect(aim.get("max_custom_angle_degrees") != null, "Aim should expose max_custom_angle_degrees"):
		return false

	aim.queue_free()
	return true


func _test_player_uses_aim_instance_angle_limits() -> bool:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	var aim := player.get_node("Aim")
	aim.set("min_custom_angle_degrees", -10.0)
	aim.set("max_custom_angle_degrees", 35.0)

	player.custom_aim_angle_degrees = 30.0
	Input.action_press("aim_up")
	player._update_custom_aim_angle(1.0)
	Input.action_release("aim_up")
	if not _expect(is_equal_approx(player.custom_aim_angle_degrees, 35.0), "player should clamp aim up to Aim max angle"):
		return false

	player.custom_aim_angle_degrees = -5.0
	Input.action_press("aim_down")
	player._update_custom_aim_angle(1.0)
	Input.action_release("aim_down")
	if not _expect(is_equal_approx(player.custom_aim_angle_degrees, -10.0), "player should clamp aim down to Aim min angle"):
		return false

	player.queue_free()
	return true


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true

	printerr("TEST FAILED: %s" % message)
	quit(1)
	return false
