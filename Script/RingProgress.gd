@tool
extends Control

@export var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

@export var track_color: Color = Color(1.0, 1.0, 1.0, 0.1)
@export var fill_color: Color = Color("#3ddc84")
@export var glow_color: Color = Color("#3ddc8488")
@export var ring_width: float = 12.0

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - ring_width

	draw_arc(center, radius, 0.0, TAU, 128, track_color, ring_width, true)

	if value <= 0.0:
		return

	var start_angle: float = -PI / 2.0
	var end_angle: float = start_angle + TAU * value
	draw_arc(center, radius, start_angle, end_angle, 128, fill_color, ring_width, true)

	draw_arc(center, radius, start_angle, end_angle, 128, glow_color, ring_width + 8.0, true)

	var tip: Vector2 = center + Vector2(cos(end_angle), sin(end_angle)) * radius
	draw_circle(tip, ring_width / 2.0, fill_color)
