extends Node2D
class_name LightningArc

@export_range(0.02, 1.0, 0.01) var lifetime: float = 0.18
@export_range(2.0, 12.0, 0.1) var core_width: float = 2.8
@export_range(4.0, 24.0, 0.1) var glow_width: float = 11.0
@export_range(2, 32, 1) var segment_count: int = 10
@export_range(0.0, 120.0, 1.0) var jaggedness: float = 32.0
@export var core_color: Color = Color(0.0, 1.0, 0.0, 0.186)
@export var glow_color: Color = Color(0.0, 1.0, 0.0, 0.084)

var _time_left: float = 0.0

@onready var glow_line: Line2D = $GlowLine
@onready var core_line: Line2D = $CoreLine


func _ready() -> void:
	_time_left = lifetime


func configure(start_pos: Vector2, end_pos: Vector2, next_lifetime: float, intensity: float) -> void:
	global_position = start_pos
	lifetime = maxf(0.02, next_lifetime)
	_time_left = lifetime
	var local_end: Vector2 = end_pos - start_pos
	var points: PackedVector2Array = _build_arc_points(local_end, intensity)
	if glow_line != null:
		glow_line.points = points
		glow_line.width = glow_width * lerpf(0.9, 1.35, intensity)
		glow_line.default_color = glow_color
	if core_line != null:
		core_line.points = points
		core_line.width = core_width * lerpf(0.9, 1.2, intensity)
		core_line.default_color = core_color


func _process(delta: float) -> void:
	_time_left = maxf(0.0, _time_left - delta)
	var fade: float = 0.0
	if lifetime > 0.0:
		fade = _time_left / lifetime
	modulate.a = fade
	if _time_left <= 0.0:
		queue_free()


func _build_arc_points(local_end: Vector2, intensity: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var dir: Vector2 = local_end.normalized()
	var normal: Vector2 = dir.orthogonal()
	for index in range(1, segment_count):
		var t: float = float(index) / float(segment_count)
		var base_point: Vector2 = local_end * t
		var offset_scale: float = sin(t * PI) * jaggedness * lerpf(0.8, 1.35, intensity)
		var offset: Vector2 = normal * randf_range(-offset_scale, offset_scale)
		points.append(base_point + offset)
	points.append(local_end)
	return points
