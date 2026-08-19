class_name DiscData
extends Resource

# Physical disc characteristics
@export var mass: float = 0.175
@export var diameter: float = 0.21

# Aerodynamic characteristics of this disc mold.
@export var aerodynamics: AerodynamicData

# Resistance to rotation around an axis through the disc's diameter.
@export_range(0.0, 0.01, 0.000001)
var radial_moment_of_inertia: float = 0.0

# Resistance to rotation around the disc's central spin axis.
@export_range(0.0, 0.01, 0.000001)
var spin_moment_of_inertia: float = 0.0

# Temporary prototype stability value.
# TODO: Remove once aerodynamic moment + gyroscopic precession are implemented.
@export var high_speed_turn: float = 0.0


func get_area() -> float:
	var radius = diameter / 2.0
	return PI * radius * radius
