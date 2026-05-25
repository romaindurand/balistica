extends RigidBody2D


@export var explosion_radius: float = 32.0


var _has_exploded := false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 1)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _has_exploded:
		return

	for contact_index in range(state.get_contact_count()):
		var body := state.get_contact_collider_object(contact_index) as Node
		if body != null and _try_explode_on(body):
			return


func _on_body_entered(body: Node) -> void:
	if _has_exploded:
		return

	_try_explode_on(body)


func _try_explode_on(body: Node) -> bool:
	var destructible_map := _find_destructible_map(body)
	if destructible_map == null:
		return false

	_has_exploded = true
	var impact_position := global_position
	destructible_map.call_deferred("destroy_circle", impact_position, explosion_radius)
	queue_free()
	return true


func _find_destructible_map(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("destroy_circle"):
			return current
		current = current.get_parent()
	return null
