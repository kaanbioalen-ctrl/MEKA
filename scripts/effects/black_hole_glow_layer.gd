class_name BlackHoleGlowLayer
extends Node2D

# ─── Sabitler ────────────────────────────────────────────────────────────────
const AMBIENT_RINGS := 5
const ARC_PER_RING  := 8
const TENDRIL_COUNT := 6

# ─── Durum ───────────────────────────────────────────────────────────────────
var _radius:  float = 46.0
var _level_t: float = 0.0
var _time:    float = 0.0

# ─── Public API ──────────────────────────────────────────────────────────────
func set_radius(r: float) -> void:
	_radius = r
	queue_redraw()


func tick(delta: float, radius: float, level_t: float) -> void:
	_time    += delta
	_level_t  = level_t
	if absf(radius - _radius) > 0.5:
		_radius = radius
	queue_redraw()


func _draw() -> void:
	_draw_ambient_glow()
	_draw_rotating_arcs()
	_draw_gravitational_tendrils()


func _draw_ambient_glow() -> void:
	## Büyük mor/koyu mavi ışıma alanı
	var intensity := 0.035 + 0.018 * _level_t + 0.008 * sin(_time * 0.55)
	for i in AMBIENT_RINGS:
		var t     := float(i) / float(AMBIENT_RINGS - 1)
		var r     := _radius * (1.5 + t * 2.2)
		var alpha := intensity * (1.0 - t * 0.78)
		var color := Color(0.45 + t * 0.15, 0.0, 1.0 - t * 0.35, alpha)
		draw_circle(Vector2.ZERO, r, color)


func _draw_rotating_arcs() -> void:
	## Yavaşça dönen yay parçaları
	for ring in 3:
		var r       := _radius * (1.28 + ring * 0.38)
		var dir     := 1 if ring % 2 == 0 else -1
		var speed   := 0.22 * (1.0 + ring * 0.12)
		var offset  := _time * speed * dir
		var arc_len := TAU / (ARC_PER_RING * 1.5)
		for arc in ARC_PER_RING:
			var start := offset + arc * (TAU / ARC_PER_RING)
			var alpha  := (0.13 - ring * 0.03) * (1.0 + 0.28 * sin(_time + arc * 0.9))
			draw_arc(Vector2.ZERO, r, start, start + arc_len, 16,
				Color(0.55, 0.08, 1.0, alpha), 3.2 - ring * 0.9)


func _draw_gravitational_tendrils() -> void:
	## Kara delikten dışarıya uzanan ince çizgiler (kütleçekim bükülmesi)
	for i in TENDRIL_COUNT:
		var base_angle := TAU * float(i) / float(TENDRIL_COUNT) + _time * 0.12
		var inner := _radius * 1.02
		var outer := _radius * 2.35
		var bend  := 0.06 * sin(_time * 0.6 + i * 1.1)
		var start := Vector2(cos(base_angle), sin(base_angle)) * inner
		var end   := Vector2(cos(base_angle + bend), sin(base_angle + bend)) * outer
		var alpha := 0.05 + 0.03 * sin(_time * 0.75 + i)
		draw_line(start, end, Color(0.65, 0.20, 1.0, alpha), 1.8)
