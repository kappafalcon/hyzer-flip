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

# Constant no-wobble spin loss while airborne, in radians per second squared.
@export_range(0.0, 50.0, 0.1, "suffix:rad/s²")
var spin_decay_rate: float = 0.0

# Dimensionless aerodynamic spin damping. It scales aerodynamic torque
# amplitude and the current spin rate, so spin loss naturally decreases as
# airspeed falls. A negative value dissipates spin.
@export_range(-0.001, 0.0, 0.0000001)
var aerodynamic_spin_damping: float = 0.0

func get_area() -> float:
	var radius = diameter / 2.0
	return PI * radius * radius


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if mass <= 0.0 or not is_finite(mass):
		errors.append("Disc mass must be finite and positive.")
	if diameter <= 0.0 or not is_finite(diameter):
		errors.append("Disc diameter must be finite and positive.")
	if radial_moment_of_inertia <= 0.0 or spin_moment_of_inertia <= 0.0:
		errors.append("Disc moments of inertia must be positive.")
	if spin_decay_rate < 0.0 or not is_finite(spin_decay_rate):
		errors.append("Disc spin decay rate must be finite and non-negative.")
	if aerodynamic_spin_damping > 0.0 or not is_finite(aerodynamic_spin_damping):
		errors.append("Aerodynamic spin damping must be finite and non-positive.")
	if aerodynamics == null:
		errors.append("Disc data requires aerodynamic data.")
	elif not aerodynamics.is_valid():
		errors.append_array(aerodynamics.validate())
	return errors


func is_valid() -> bool:
	return validate().is_empty()
