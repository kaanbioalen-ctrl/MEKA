extends Node2D
class_name StormFlowLayer

var _radius:     float = 240.0
var _density:    float = 70.0
var _flow_speed: float = 220.0
var _intensity:  float = 0.0
var _alpha:      float = 0.0
var _streaks:    Array[Dictionary] = []


func _ready() -> void:
	set_process(true)


func set_storm_params(radius: float, density: float, flow_speed: float, intensity: float, alpha: float, _direction: Vector2) -> void:
	_radius     = maxf(32.0, radius)
	_density    = maxf(8.0, density)
	_flow_speed = maxf(10.0, flow_speed)
	_intensity  = clampf(intensity, 0.0, 4.0)
	_alpha      = clampf(alpha, 0.0, 1.0)
	_ensure_streak_count()
	queue_redraw()


func _process(delta: float) -> void:
	if _streaks.is_empty() and _alpha <= 0.0:
		return

	for streak in _streaks:
		var pos: Vector2 = streak["pos"] as Vector2
		var dist: float  = pos.length()

		if dist < 0.001:
			streak["pos"] = _spawn_position()
			continue

		# Orbital rotation — inner parts spin faster (real vortex physics)
		var lin_spd:  float = _flow_speed * float(streak["speed_mult"]) * 0.28
		var ang_spd:  float = lin_spd / maxf(dist, 18.0)
		var cur_ang:  float = atan2(pos.y, pos.x)
		cur_ang += ang_spd * delta

		# Gentle inward spiral
		dist -= _flow_speed * 0.018 * delta
		if dist < _radius * 0.06:
			streak["pos"] = _spawn_position()
			continue

		if dist > _radius + 110.0:
			streak["pos"] = _spawn_position()
		else:
			streak["pos"] = Vector2(cos(cur_ang), sin(cur_ang)) * dist

	queue_redraw()


func _draw() -> void:
	for streak in _streaks:
		var pos: Vector2 = streak["pos"] as Vector2
		var dist: float  = pos.length()
		if dist < 0.001:
			continue
		var length: float = float(streak["length"])
		var width:  float = float(streak["width"])
		var color:  Color = streak["color"] as Color
		color.a *= _alpha
		# Draw streak along tangent direction (shows orbital motion)
		var tangent := Vector2(-pos.y, pos.x).normalized()
		draw_line(pos, pos - tangent * length, color, width)


func _ensure_streak_count() -> void:
	var target_count: int = int(round(_density))
	while _streaks.size() < target_count:
		_streaks.append(_make_streak())
	while _streaks.size() > target_count:
		_streaks.pop_back()


func _make_streak() -> Dictionary:
	return {
		"pos":        _spawn_position(),
		"length":     randf_range(18.0, 52.0),
		"width":      randf_range(0.8, 2.4),
		"speed_mult": randf_range(0.8, 1.35),
		"color":      Color(0.0, 1.0, 0.0, randf_range(0.018, 0.042)),
	}


func _spawn_position() -> Vector2:
	var angle: float = randf() * TAU
	var dist:  float = sqrt(randf()) * (_radius + 90.0)
	return Vector2.RIGHT.rotated(angle) * dist
