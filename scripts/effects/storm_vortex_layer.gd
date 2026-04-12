extends Node2D
class_name StormVortexLayer

const ARM_COUNT    := 3
const ARM_SEGMENTS := 56
const ARM_TURNS    := 1.55
const NEBULA_COUNT := 80
const ROT_SPEED    := 1.15

# Pure #00FF00
const C_CORE  := Color(0.0, 1.0, 0.0, 1.0)
const C_GLOW  := Color(0.0, 1.0, 0.0, 1.0)
const C_WHITE := Color(0.0, 1.0, 0.0, 1.0)

var _radius: float = 240.0
var _alpha:  float = 0.0
var _angle:  float = 0.0
var _time:   float = 0.0

var _arm_jitter: Array = []
var _nebula:     Array = []
var _tendril:    Array = []


func _ready() -> void:
	_build_arm_jitter()
	_build_nebula()
	_build_tendrils()
	set_process(true)


func set_storm_params(radius: float, alpha: float) -> void:
	_radius = maxf(48.0, radius)
	_alpha  = clampf(alpha, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_time  += delta
	_angle += delta * ROT_SPEED
	if _alpha > 0.001:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.001:
		return
	_draw_nebula()
	_draw_outer_rings()
	_draw_tendrils()
	_draw_arms()
	_draw_center()


# ── Pre-compute ──────────────────────────────────────────────────────────────

func _build_arm_jitter() -> void:
	_arm_jitter.clear()
	for _arm in range(ARM_COUNT):
		var row: Array = []
		for i in range(ARM_SEGMENTS + 1):
			var t: float = float(i) / float(ARM_SEGMENTS)
			var scale: float = 0.0 if i == 0 else lerpf(4.0, 18.0, t)
			row.append(randf_range(-scale, scale))
		_arm_jitter.append(row)


func _build_nebula() -> void:
	_nebula.clear()
	for _i in range(NEBULA_COUNT):
		_nebula.append({
			"angle":      randf() * TAU,
			"dist_n":     sqrt(randf()),
			"size_n":     randf_range(0.05, 0.18),
			"phase":      randf() * TAU,
			"pulse_spd":  randf_range(0.5, 1.6),
			"alpha_mult": randf_range(0.3, 0.85),
		})


func _build_tendrils() -> void:
	_tendril.clear()
	var count := 18
	for i in range(count):
		_tendril.append({
			"angle_offset": float(i) / float(count) * TAU,
			"length_n":     randf_range(0.12, 0.30),
			"width":        randf_range(1.0, 2.5),
			"phase":        randf() * TAU,
			"pulse_spd":    randf_range(1.2, 3.0),
			"jitter":       randf_range(-0.08, 0.08),
		})


# ── Draw ─────────────────────────────────────────────────────────────────────

func _draw_center() -> void:
	var cr: float = _radius * 0.13
	draw_circle(Vector2.ZERO, cr * 0.34, Color(C_CORE.r, C_CORE.g, C_CORE.b, _alpha * 0.285))
	draw_circle(Vector2.ZERO, cr * 0.74, Color(C_CORE.r, C_CORE.g, C_CORE.b, _alpha * 0.042))
	var rim_seg := 48
	for i in range(rim_seg):
		var a: float = float(i) / float(rim_seg) * TAU + (_angle * 1.8)
		var pulse: float = sin(_time * 5.5 + a * 3.0) * 0.5 + 0.5
		var pos := Vector2(cos(a), sin(a)) * (cr * 1.06)
		draw_circle(pos, 4.2, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, _alpha * lerpf(0.054, 0.165, pulse)))
	draw_circle(Vector2.ZERO, cr * 1.35, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, _alpha * 0.030))
	draw_circle(Vector2.ZERO, cr * 1.65, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, _alpha * 0.015))


func _draw_nebula() -> void:
	for nd in _nebula:
		var angle: float = float(nd["angle"]) + _angle * 0.15
		var dist:  float = float(nd["dist_n"]) * _radius
		var pos   := Vector2(cos(angle), sin(angle)) * dist
		var size:  float = float(nd["size_n"]) * _radius
		var pulse: float = sin(_time * float(nd["pulse_spd"]) + float(nd["phase"])) * 0.5 + 0.5
		var a:     float = _alpha * float(nd["alpha_mult"]) * lerpf(0.012, 0.039, pulse)
		draw_circle(pos, size, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, a))


func _draw_outer_rings() -> void:
	# 3 dış halka — bazıları ters döner, haritada görünür
	var rings: Array = [
		{"r_n": 0.80, "width": 2.8, "alpha": 0.060, "dashes": 22, "rot_mult":  1.0,  "gap": 0.50},
		{"r_n": 0.98, "width": 1.8, "alpha": 0.039, "dashes": 30, "rot_mult": -0.65, "gap": 0.55},
		{"r_n": 1.15, "width": 1.2, "alpha": 0.024, "dashes": 40, "rot_mult":  0.45, "gap": 0.55},
	]
	for ring in rings:
		var r:       float = float(ring["r_n"])   * _radius
		var base_a:  float = _alpha * float(ring["alpha"])
		var dashes:  int   = int(ring["dashes"])
		var rot_off: float = _angle * float(ring["rot_mult"])
		var gap:     float = float(ring["gap"])
		var w:       float = float(ring["width"])
		var arc_len: float = TAU / float(dashes) * gap
		var arc_steps := 7
		for j in range(dashes):
			var start_a: float = float(j) / float(dashes) * TAU + rot_off
			var pulse:   float = sin(_time * 1.6 + float(j) * 0.7) * 0.5 + 0.5
			var a:       float = base_a * lerpf(0.55, 1.0, pulse)
			var prev := Vector2(cos(start_a), sin(start_a)) * r
			for k in range(1, arc_steps + 1):
				var arc_a := start_a + arc_len * float(k) / float(arc_steps)
				var nxt   := Vector2(cos(arc_a), sin(arc_a)) * r
				draw_line(prev, nxt, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, a), w)
				prev = nxt


func _draw_tendrils() -> void:
	# Dışa uzanan enerji kolları — vortex kenarından çıkar ve döner
	for td in _tendril:
		var base_a:    float = float(td["angle_offset"]) + _angle * 1.4
		var jitter:    float = float(td["jitter"])
		var angle:     float = base_a + jitter
		var length:    float = float(td["length_n"]) * _radius
		var pulse:     float = sin(_time * float(td["pulse_spd"]) + float(td["phase"])) * 0.5 + 0.5
		var a:         float = _alpha * lerpf(0.024, 0.066, pulse)
		var inner_pos  := Vector2(cos(angle), sin(angle)) * (_radius * 0.78)
		var outer_pos  := Vector2(cos(angle), sin(angle)) * (_radius * 0.78 + length)
		# Glow pass
		draw_line(inner_pos, outer_pos, Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, a * 0.5), float(td["width"]) * 5.0)
		# Core pass
		draw_line(inner_pos, outer_pos, Color(C_CORE.r, C_CORE.g, C_CORE.b, a),        float(td["width"]))


func _draw_arms() -> void:
	for arm_idx in range(ARM_COUNT):
		var arm_offset: float = float(arm_idx) / float(ARM_COUNT) * TAU
		var jitter_row: Array = _arm_jitter[arm_idx]

		var pts := PackedVector2Array()
		pts.resize(ARM_SEGMENTS + 1)
		for i in range(ARM_SEGMENTS + 1):
			var t:     float = float(i) / float(ARM_SEGMENTS)
			var angle: float = arm_offset + (_angle * 1.9) + t * ARM_TURNS * TAU
			var dist:  float = t * _radius
			var perp  := Vector2(-sin(angle), cos(angle))
			pts[i] = Vector2(cos(angle), sin(angle)) * dist + perp * float(jitter_row[i])

		# Pass 1 — wide outer glow
		for i in range(ARM_SEGMENTS):
			var t: float = float(i) / float(ARM_SEGMENTS - 1)
			var a: float = _alpha * 0.027 * sin(t * PI) * lerpf(1.0, 0.5, t)
			draw_line(pts[i], pts[i + 1], Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, a), 32.0)

		# Pass 2 — medium glow
		for i in range(ARM_SEGMENTS):
			var t: float = float(i) / float(ARM_SEGMENTS - 1)
			var a: float = _alpha * 0.066 * sin(t * PI)
			draw_line(pts[i], pts[i + 1], Color(C_GLOW.r, C_GLOW.g, C_GLOW.b, a), 10.0)

		# Pass 3 — bright electric core
		for i in range(ARM_SEGMENTS):
			var t:     float = float(i) / float(ARM_SEGMENTS - 1)
			var pulse: float = sin(_time * 9.0 + t * 14.0 + float(arm_idx) * 2.4) * 0.5 + 0.5
			var a:     float = _alpha * lerpf(0.12, 0.216, pulse) * sin(t * PI)
			draw_line(pts[i], pts[i + 1], Color(C_CORE.r, C_CORE.g, C_CORE.b, a), 2.0)
