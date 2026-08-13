class_name FlightState
extends RefCounted

var velocity: Vector3
var spin_rate: float
var orientation: Basis


func _init(
	initial_velocity: Vector3,
	initial_spin_rate: float,
	initial_orientation: Basis,
):
	velocity = initial_velocity
	spin_rate = initial_spin_rate
	orientation = initial_orientation
