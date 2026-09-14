class_name PlayerReticle
extends Control

@export var reticle_color := Color.WHITE
@export_range(0.0, 20.0, 0.5, "suffix:px") var relaxed_gap := 7.0
@export_range(0.0, 20.0, 0.5, "suffix:px") var aiming_gap := 2.0
@export_range(1.0, 20.0, 0.5, "suffix:px") var arm_length := 8.0
@export_range(1.0, 8.0, 0.5, "suffix:px") var line_width := 2.0

var _is_aiming := false


func set_aiming(is_aiming: bool) -> void:
	if _is_aiming == is_aiming:
		return
	_is_aiming = is_aiming
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var gap := aiming_gap if _is_aiming else relaxed_gap

	draw_line(
		center + Vector2(-gap - arm_length, 0.0),
		center + Vector2(-gap, 0.0),
		reticle_color,
		line_width,
	)
	draw_line(
		center + Vector2(gap, 0.0),
		center + Vector2(gap + arm_length, 0.0),
		reticle_color,
		line_width,
	)
	draw_line(
		center + Vector2(0.0, -gap - arm_length),
		center + Vector2(0.0, -gap),
		reticle_color,
		line_width,
	)
	draw_line(
		center + Vector2(0.0, gap),
		center + Vector2(0.0, gap + arm_length),
		reticle_color,
		line_width,
	)
