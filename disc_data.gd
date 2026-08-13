class_name DiscData
extends Resource

# Arbitrary disc characteristics
@export var mass: float = 0.175
@export var diameter: float = 0.21

# How strongly the disc rolls toward anhyzer at high speed.
# 0.0 = neutral
# Higher values = more understable
@export var high_speed_turn: float = 0.0


func get_area() -> float:
	var radius = diameter / 2.0
	return PI * radius * radius
