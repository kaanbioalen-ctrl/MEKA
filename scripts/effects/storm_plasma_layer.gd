extends Node2D
class_name StormPlasmaLayer

var _radius: float = 240.0
var _density: float = 42.0
var _flow_speed: float = 160.0
var _intensity: float = 0.0
var _alpha: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _motes: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	set_process(true)


func set_storm_params(radius: float, density: float, flow_speed: float, intensity: float, alpha: float, direction: Vector2) -> void:
	_radius = maxf(24.0, radius)
	_density = maxf(6.0, density)
	_flow_speed = maxf(8.0, flow_speed)
	_intensity = clampf(intensity, 0.0, 4.0)
	_alpha = clampf(alpha, 0.0, 1.0)
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_ensure_mote_count()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _motes.is_empty() and _alpha <= 0.0:
		return
	var flow: Vector2 = _direction * _flow_speed * maxf(0.25, _intensity) * delta
	for mote in _motes:
		var pos: Vector2 = mote["pos"] as Vector2
		var swirl_speed: float = float(mote["swirl_speed"])
		var swirl_amp: float = float(mote["swirl_amp"])
		pos += flow * float(mote["speed_mult"])
		pos += _direction.orthogonal() * sin((_time * swirl_speed) + float(mote["phase"])) * swirl_amp * delta
		if pos.length() > _radius + 110.0:
			pos = _spawn_position()
		mote["pos"] = pos
	queue_redraw()


func _draw() -> void:
	for mote in _motes:
		var pos: Vector2 = mote["pos"] as Vector2
		var size: float = float(mote["size"])
		var pulse: float = sin((_time * float(mote["pulse_speed"])) + float(mote["phase"])) * 0.5 + 0.5
		var color: Color = mote["color"] as Color
		color.a *= _alpha * lerpf(0.105, 0.30, pulse)
		draw_circle(pos, size * (0.7 + pulse * 0.5), color)


func _ensure_mote_count() -> void:
	var target_count: int = int(round(_density))
	while _motes.size() < target_count:
		_motes.append(_make_mote())
	while _motes.size() > target_count:
		_motes.pop_back()


func _make_mote() -> Dictionary:
	var palette: Array[Color] = [
		Color(0.0,  1.0,  0.61, 0.063),
		Color(0.0,  0.92, 0.50, 0.054),
		Color(0.12, 1.0,  0.72, 0.060),
	]
	return {
		"pos": _spawn_position(),
		"size": randf_range(1.4, 4.8),
		"speed_mult": randf_range(0.6, 1.45),
		"swirl_speed": randf_range(1.0, 4.0),
		"swirl_amp": randf_range(12.0, 42.0),
		"pulse_speed": randf_range(1.6, 5.4),
		"phase": randf() * TAU,
		"color": palette[randi() % palette.size()],
	}


func _spawn_position() -> Vector2:
	var angle: float = randf() * TAU
	var dist: float = sqrt(randf()) * (_radius + 72.0)
	return Vector2.RIGHT.rotated(angle) * dist
