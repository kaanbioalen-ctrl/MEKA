extends Node2D
## Roket patlama görseli — player_overload_burst.gd'e benzer pattern.

const PARTICLE_COUNT_MIN: int   = 16
const PARTICLE_COUNT_MAX: int   = 28
const PARTICLE_LIFETIME:  float = 0.7

var _radius:    float = 80.0
var _particles: Array = []
var _elapsed:   float = 0.0
var _shockwave: float = 0.0


func setup(radius: float) -> void:
	_radius = radius
	_spawn_particles()


func _spawn_particles() -> void:
	var count := randi_range(PARTICLE_COUNT_MIN, PARTICLE_COUNT_MAX)
	for i in count:
		var angle  := randf() * TAU
		var speed  := randf_range(120.0, _radius * 3.5)
		var size   := randf_range(2.0, 5.5)
		var life   := randf_range(0.4, PARTICLE_LIFETIME)
		_particles.append({
			"pos":   Vector2.ZERO,
			"vel":   Vector2(cos(angle), sin(angle)) * speed,
			"size":  size,
			"life":  life,
			"t":     0.0
		})


func _process(delta: float) -> void:
	_elapsed    += delta
	_shockwave  += delta * 2.5   # 0 → 1 patlama yarıçapı ölçeği

	var all_dead := true
	for p in _particles:
		p["t"] += delta
		if p["t"] < p["life"]:
			all_dead = false
			p["vel"] *= 0.94
			p["pos"] += p["vel"] * delta

	if all_dead and _elapsed > 0.1:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	# Şok dalgası halkası
	var sw_r  := _radius * clampf(_shockwave, 0.0, 1.0)
	var sw_a  := clampf(1.0 - _shockwave, 0.0, 1.0) * 0.7
	if sw_a > 0.01:
		draw_arc(Vector2.ZERO, sw_r, 0.0, TAU, 48,
			Color(1.0, 0.6, 0.2, sw_a), 3.5, true)
		draw_arc(Vector2.ZERO, sw_r * 0.85, 0.0, TAU, 48,
			Color(1.0, 0.3, 0.05, sw_a * 0.5), 2.0, true)

	# Parçacıklar
	for p in _particles:
		var t_ratio: float   = float(p["t"]) / maxf(0.001, float(p["life"]))
		if t_ratio >= 1.0:
			continue
		var a:   float   = (1.0 - t_ratio) * 0.9
		var sz:  float   = float(p["size"]) * (1.0 - t_ratio * 0.6)
		var pos: Vector2 = p["pos"]
		# Core
		draw_circle(pos, sz,       Color(1.00, 0.80, 0.30, a))
		# Glow
		draw_circle(pos, sz + 2.0, Color(1.00, 0.40, 0.08, a * 0.40))
