extends Node2D
class_name StormGlowLayer

const RING_COUNT: int = 3
const ARC_COUNT: int = 12
const ARC_SEGMENTS: int = 6

var _radius: float = 240.0
var _alpha: float = 0.0
var _intensity: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	set_process(true)


func set_storm_params(radius: float, alpha: float, intensity: float) -> void:
	_radius = maxf(32.0, radius)
	_alpha = clampf(alpha, 0.0, 1.0)
	_intensity = clampf(intensity, 0.0, 4.0)
	queue_redraw()


func _process(delta: float) -> void:
	if _alpha <= 0.001:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.001:
		return

	var pulse := sin(_time * 3.4) * 0.5 + 0.5
	var inner_alpha := _alpha * lerpf(0.05, 0.1, pulse)
	var mid_alpha := _alpha * lerpf(0.035, 0.065, pulse)
	var outer_alpha := _alpha * lerpf(0.015, 0.03, pulse)
	var core_color := Color(0.18, 1.0, 0.72, inner_alpha)
	var mid_color := Color(0.06, 0.95, 0.55, mid_alpha)
	var outer_color := Color(0.02, 0.7, 0.34, outer_alpha)

	draw_circle(Vector2.ZERO, _radius * 0.34, core_color)
	draw_circle(Vector2.ZERO, _radius * 0.62, mid_color)
	draw_circle(Vector2.ZERO, _radius * 0.92, outer_color)
	_draw_ring_arcs()


func _draw_ring_arcs() -> void:
	for ring_index in range(RING_COUNT):
		var ring_t := float(ring_index + 1) / float(RING_COUNT + 1)
		var ring_radius := _radius * lerpf(0.36, 0.98, ring_t)
		var ring_width := lerpf(3.0, 1.2, ring_t)
		var base_alpha := _alpha * lerpf(0.12, 0.045, ring_t) * minf(1.0, 0.7 + (_intensity * 0.18))
		var rotation := (_time * lerpf(0.8, 1.35, ring_t)) * (1.0 if ring_index % 2 == 0 else -1.0)

		for arc_index in range(ARC_COUNT):
			var arc_phase := float(arc_index) / float(ARC_COUNT)
			var arc_pulse := sin((_time * 4.2) + (arc_phase * TAU * 2.0) + float(ring_index)) * 0.5 + 0.5
			var start_angle := arc_phase * TAU + rotation
			var arc_span := lerpf(0.12, 0.28, arc_pulse)
			var color := Color(0.64, 1.0, 0.88, base_alpha * lerpf(0.45, 1.0, arc_pulse))
			_draw_arc_segment(ring_radius, start_angle, start_angle + arc_span, ring_width, color)


func _draw_arc_segment(radius: float, start_angle: float, end_angle: float, width: float, color: Color) -> void:
	var prev := Vector2(cos(start_angle), sin(start_angle)) * radius
	for step in range(1, ARC_SEGMENTS + 1):
		var t := float(step) / float(ARC_SEGMENTS)
		var angle := lerpf(start_angle, end_angle, t)
		var next := Vector2(cos(angle), sin(angle)) * radius
		draw_line(prev, next, color, width)
		prev = next
