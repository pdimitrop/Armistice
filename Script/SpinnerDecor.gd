extends Control

@export var spin_speed: float = 0.8
@export var arc_span: float = PI * 0.45
@export var ring_width: float = 2.0
@export var arc_color: Color = Color(1.0, 1.0, 1.0, 0.07)

var _angle: float = 0.0

func _process(delta: float) -> void:
	_angle += spin_speed * delta
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size / 2.0
	
	var radius: float = min(size.x, size.y) / 2.0 - 3.0
	draw_arc(center, radius, _angle, _angle + arc_span, 64, arc_color, ring_width, true)
	
	draw_arc(center, radius, _angle + PI, _angle + PI + arc_span, 64, arc_color, ring_width, true)
