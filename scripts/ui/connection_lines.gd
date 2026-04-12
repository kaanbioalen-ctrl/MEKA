extends Control
class_name ConnectionLines
## Elliptical galaxy rings and depth-aware connector lines for the upgrade screen.

const RING_THEME: Dictionary = {
	"core":   {"color": Color(0.32, 0.66, 1.0, 0.18), "width": 1.0},
	"inner":  {"color": Color(0.36, 0.78, 1.0, 0.26), "width": 1.5},
	"mid":    {"color": Color(0.48, 0.82, 1.0, 0.22), "width": 1.3},
	"outer":  {"color": Color(0.62, 0.76, 1.0, 0.16), "width": 1.0},
	"player_bg": {"color": Color(0.56, 0.86, 1.0, 0.10), "width": 0.9},
	"black_hole_bg": {"color": Color(0.86, 0.56, 1.0, 0.10), "width": 0.9},
}

var _positions: Dictionary = {}
var _depths: Dictionary = {}
var _connections: Array = []
var _orbit_defs: Array = []
var _time: float = 0.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_data(positions: Dictionary, depths: Dictionary, connections: Array, orbit_defs: Array) -> void:
	_positions = positions
	_depths = depths
	_connections = connections
	_orbit_defs = orbit_defs
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	_draw_core_glow(center)
	_draw_elliptical_rings(center)
	_draw_connections()


func _draw_core_glow(center: Vector2) -> void:
	var pulse := sin(_time * 0.65) * 0.5 + 0.5
	draw_circle(center, 76.0, Color(0.10, 0.28, 0.60, 0.11 + pulse * 0.03))
	draw_circle(center, 42.0, Color(0.22, 0.52, 1.0, 0.08 + pulse * 0.04))


func _draw_elliptical_rings(center: Vector2) -> void:
	for orbit_data_v in _orbit_defs:
		if not (orbit_data_v is Dictionary):
			continue
		var orbit_data := orbit_data_v as Dictionary
		var radius := float(orbit_data.get("radius", 0.0))
		if radius <= 0.0:
			continue
		var flatten := float(orbit_data.get("flatten", 0.65))
		var ring_key := str(orbit_data.get("ring_key", "mid"))
		var theme: Dictionary = RING_THEME.get(ring_key, RING_THEME["mid"])
		var color := theme.get("color", Color(0.48, 0.82, 1.0, 0.22)) as Color
		var width := float(orbit_data.get("width", theme.get("width", 1.2)))
		var alpha_mul := float(orbit_data.get("alpha", color.a))
		var pulse := 0.85 + 0.15 * sin(_time * 0.42 + radius * 0.012)
		var points := _build_ellipse_points(center, radius, flatten, 120)
		draw_polyline(points, Color(color.r, color.g, color.b, alpha_mul * pulse), width, true)


func _draw_connections() -> void:
	for pair_v in _connections:
		if not (pair_v is Array):
			continue
		var pair := pair_v as Array
		if pair.size() < 2:
			continue
		var from_id := str(pair[0])
		var to_id := str(pair[1])
		if not _positions.has(from_id) or not _positions.has(to_id):
			continue
		var from_pos := _positions[from_id] as Vector2
		var to_pos := _positions[to_id] as Vector2
		var from_depth := float(_depths.get(from_id, 0.5))
		var to_depth := float(_depths.get(to_id, 0.5))
		var avg_depth := (from_depth + to_depth) * 0.5
		var is_black_hole_link := from_id.begins_with("bh_") or to_id.begins_with("bh_")
		var style := _get_link_style(is_black_hole_link)
		var dir := (to_pos - from_pos).normalized()
		var tangent := Vector2(-dir.y, dir.x)
		var start_offset := dir * lerpf(18.0, 34.0, from_depth)
		var end_offset := dir * lerpf(18.0, 34.0, to_depth)
		var start := from_pos + start_offset
		var finish := to_pos - end_offset
		var arc_lift := lerpf(12.0, 54.0, avg_depth)
		var chaos_seed := float(from_id.unicode_at(0) + to_id.unicode_at(0) + from_id.length() * 11 + to_id.length() * 7)
		var depth_bend := tangent * sin(_time * 0.55 + float(from_id.length() + to_id.length())) * lerpf(2.0, 8.0, avg_depth)
		var weave_bias := tangent * sin(chaos_seed * 0.17) * lerpf(10.0, 28.0, avg_depth)
		var control_a := start.lerp(finish, 0.33) + Vector2(0.0, (finish.y - start.y) * 0.24 - arc_lift) + depth_bend + weave_bias
		var control_b := start.lerp(finish, 0.66) - Vector2(0.0, (finish.y - start.y) * 0.24 + arc_lift) - depth_bend - weave_bias * 0.8
		var points := _build_curve_points(start, control_a, control_b, finish, 32, chaos_seed, avg_depth, tangent, is_black_hole_link)
		var vein_phase := _time * float(style.get("vein_speed", 2.2)) + float(from_id.length()) * 0.7 + float(to_id.length()) * 0.35
		var vein_pulse := sin(vein_phase) * 0.5 + 0.5
		var base_col := style.get("base_color", Color(0.68, 0.90, 1.0)) as Color
		var glow_col := style.get("glow_color", Color(0.34, 0.68, 1.0)) as Color
		var glow_strength := float(style.get("glow_strength", 1.0))
		var vein_strength := float(style.get("vein_strength", 1.0))
		var pulse_strength := float(style.get("pulse_strength", 1.0))
		var width_mul := float(style.get("width_mul", 1.0))
		var breath_speed := float(style.get("breath_speed", 1.2))
		var glow_color := Color(glow_col.r, glow_col.g, glow_col.b, lerpf(0.022, 0.15, avg_depth) * (0.55 + vein_pulse * 1.10) * glow_strength)
		var main_color := Color(base_col.r, base_col.g, base_col.b, lerpf(0.06, 0.38, avg_depth) * (0.70 + vein_pulse * 0.78) * vein_strength)
		var highlight_color := Color(1.0, 1.0, 1.0, lerpf(0.06, 0.28, avg_depth) * (0.45 + vein_pulse * 1.00) * pulse_strength)
		var width := lerpf(1.1, 2.6, avg_depth) * width_mul
		var breath := sin(_time * breath_speed + float(from_id.length())) * 0.5 + 0.5
		draw_polyline(points, glow_color, width * (2.7 + breath * 0.65), true)
		_draw_vein_body(points, main_color, width, vein_phase)
		_draw_energy_flow(points, avg_depth, width, highlight_color, vein_pulse, is_black_hole_link)


func _draw_vein_body(points: PackedVector2Array, color: Color, width: float, phase: float) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var t := float(i) / float(maxi(points.size() - 2, 1))
		var pulse := sin(phase + t * TAU * 2.2) * 0.5 + 0.5
		var alpha := color.a * (0.18 + pulse * 0.82)
		var seg_width := width * (0.72 + pulse * 0.42)
		var strand_shift := (b - a).normalized().orthogonal() * sin(phase * 0.85 + t * TAU * 4.0) * width * 0.18
		draw_line(a - strand_shift, b - strand_shift, Color(color.r, color.g, color.b, alpha * 0.46), seg_width * 0.62, true)
		draw_line(a + strand_shift, b + strand_shift, Color(color.r, color.g, color.b, alpha), seg_width, true)


func _draw_energy_flow(points: PackedVector2Array, depth: float, width: float, color: Color, vein_pulse: float, is_black_hole_link: bool) -> void:
	if points.size() < 2:
		return
	var flow_speed := lerpf(0.16, 0.36, depth)
	if is_black_hole_link:
		flow_speed *= 0.92
	var pulse_t := fposmod(_time * flow_speed, 1.0)
	var secondary_t := fposmod(pulse_t + 0.38, 1.0)
	var tertiary_t := fposmod(pulse_t + 0.68, 1.0)
	_draw_flow_pulse(points, pulse_t, width * (1.0 + vein_pulse * 0.30), color, 1.0)
	_draw_flow_pulse(points, secondary_t, width * 0.82, Color(color.r, color.g, color.b, color.a * 0.55), 0.72)
	_draw_flow_pulse(points, tertiary_t, width * 0.62, Color(color.r, color.g, color.b, color.a * (0.18 + vein_pulse * 0.20)), 0.46)


func _draw_flow_pulse(points: PackedVector2Array, t: float, width: float, color: Color, stretch: float) -> void:
	var pulse_pos := _sample_polyline(points, t)
	draw_circle(pulse_pos, width * (2.2 + stretch * 0.4), Color(color.r, color.g, color.b, color.a * 0.16))
	draw_circle(pulse_pos, width * (1.0 + stretch * 0.22), Color(color.r, color.g, color.b, color.a * 0.35))
	draw_circle(pulse_pos, width * 0.72, color)


func _get_link_style(is_black_hole_link: bool) -> Dictionary:
	if is_black_hole_link:
		return {
			"base_color": Color(0.98, 0.56, 0.86),
			"glow_color": Color(0.74, 0.28, 0.62),
			"glow_strength": 1.0,
			"vein_strength": 1.0,
			"pulse_strength": 1.0,
			"width_mul": 1.0,
			"vein_speed": 2.0,
			"breath_speed": 1.2,
		}
	return {
		"base_color": Color(0.76, 0.96, 1.0),
		"glow_color": Color(0.34, 0.82, 1.0),
		"glow_strength": 1.18,
		"vein_strength": 1.16,
		"pulse_strength": 1.20,
		"width_mul": 0.54,
		"vein_speed": 2.6,
		"breath_speed": 1.55,
	}


func _build_ellipse_points(center: Vector2, radius: float, flatten: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(steps, 24)
	for i in range(count + 1):
		var angle := (float(i) / float(count)) * TAU
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * flatten))
	return points


func _build_curve_points(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, steps: int, seed: float, depth: float, tangent: Vector2, is_black_hole_link: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(steps, 10)
	for i in range(count + 1):
		var t := float(i) / float(count)
		var point := start.bezier_interpolate(control_a, control_b, finish, t)
		var chaos_wave := sin(seed * 0.13 + t * TAU * 2.2 + _time * (0.42 if is_black_hole_link else 0.58))
		var micro_wave := sin(seed * 0.29 + t * TAU * 5.4 - _time * 0.76)
		var noise_strength := lerpf(2.0, 11.0, depth)
		point += tangent * chaos_wave * noise_strength
		point += tangent * micro_wave * noise_strength * 0.34
		points.append(point)
	return points


func _sample_polyline(points: PackedVector2Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var scaled := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var idx := mini(int(floor(scaled)), points.size() - 2)
	var local_t := scaled - float(idx)
	return points[idx].lerp(points[idx + 1], local_t)
