extends Node2D

@export var layer_color: Color = Color(0.2, 0.95, 1.0, 1.0)
@export_range(2.0, 128.0, 0.5) var base_radius: float = 12.0
@export_range(0.0, 1.0, 0.01) var alpha: float = 0.4
@export_range(0.0, 16.0, 0.1) var pulse_amount: float = 1.0
@export_range(0.0, 8.0, 0.05) var pulse_speed: float = 1.2
@export var draw_highlight: bool = false

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta * pulse_speed
	queue_redraw()


func _draw() -> void:
	var pulse := sin(_time) * pulse_amount
	var color := layer_color
	color.a = alpha
	draw_circle(Vector2.ZERO, maxf(0.5, base_radius + pulse), color)

	if draw_highlight:
		draw_circle(Vector2(-base_radius * 0.25, -base_radius * 0.25), base_radius * 0.35, Color(1.0, 1.0, 1.0, 0.65))

