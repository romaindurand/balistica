extends Node2D


@export_group("Nodes")
@export var wheel_path: NodePath = ^"Wheel"
@export var joint_path: NodePath = ^"WheelJoint"

@export_group("Suspension")
@export var suspension_enabled: bool = false
@export var suspension_stiffness: float = 90.0
@export var suspension_damping: float = 9.0
@export var max_suspension_force: float = 200.0


func get_wheel() -> RigidBody2D:
	return get_node_or_null(wheel_path) as RigidBody2D


func get_joint() -> GrooveJoint2D:
	return get_node_or_null(joint_path) as GrooveJoint2D
